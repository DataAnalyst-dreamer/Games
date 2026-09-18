## ProgressionCalc(순수 경험치/레벨 계산, M3-1 F1-2) 단위 테스트 + exp_curve.csv/
## monsters.json.exp_reward 실데이터 로드 확인.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const CalcScript := preload("res://scripts/systems/progression_calc.gd")
const DataScript := preload("res://scripts/core/data.gd")

var _data: Node


func before_each() -> void:
	_data = DataScript.new()
	add_child_autofree(_data)


# --- 순수 계산(주입한 곡선/테이블만 사용, Data 의존 없음) ---

func _make_curve(levels: int, formula: Callable) -> Dictionary:
	var curve: Dictionary = {}
	for level in range(1, levels + 1):
		var exp_to_next: int = 0 if level == levels else int(formula.call(level))
		curve[str(level)] = {"exp_to_next": exp_to_next, "hp_bonus": 8, "stamina_bonus": 0, "atk_bonus": 1}
	return curve


func test_exp_for_level_monotonic_non_decreasing_and_max_level_zero() -> void:
	var curve := _make_curve(50, func(l: int) -> int: return int(round(20.0 * pow(l, 1.5))))
	var prev := 0
	for level in range(1, 50):
		var need: int = CalcScript.exp_for_level(level, curve)
		assert_gt(need, 0, "만렙 미만은 항상 exp_to_next > 0 이어야 한다(level=%d)" % level)
		assert_true(need >= prev, "단조 비감소 위반: level=%d need=%d prev=%d" % [level, need, prev])
		prev = need
	assert_eq(CalcScript.exp_for_level(50, curve), 0, "만렙(50)의 exp_to_next는 0")


func test_exp_for_level_missing_row_returns_zero() -> void:
	assert_eq(CalcScript.exp_for_level(999, {}), 0)


func test_exp_reward_for_monster_known_missing_field_and_unknown_id() -> void:
	var monsters := {"slime": {"exp_reward": 5}, "no_reward_field": {}}
	assert_eq(CalcScript.exp_reward_for_monster("slime", monsters), 5)
	assert_eq(CalcScript.exp_reward_for_monster("no_reward_field", monsters), 0, "필드 없으면 0")
	assert_eq(CalcScript.exp_reward_for_monster("ghost", monsters), 0, "몬스터 자체가 없어도 0")


func test_apply_exp_boundary_below_and_exact() -> void:
	var curve := {
		"1": {"exp_to_next": 20, "hp_bonus": 8, "atk_bonus": 1},
		"2": {"exp_to_next": 57, "hp_bonus": 8, "atk_bonus": 1},
	}
	var below: Dictionary = CalcScript.apply_exp(0, 1, 19, curve, 50)
	assert_eq(int(below["level"]), 1, "요구치 미만이면 레벨 유지")
	assert_eq(int(below["exp"]), 19)
	assert_eq((below["level_ups"] as Array).size(), 0)

	var exact: Dictionary = CalcScript.apply_exp(0, 1, 20, curve, 50)
	assert_eq(int(exact["level"]), 2, "정확히 도달하면 레벨업")
	assert_eq(int(exact["exp"]), 0)
	assert_eq((exact["level_ups"] as Array).size(), 1)
	var gains: Dictionary = (exact["level_ups"] as Array)[0].get("stat_gains", {})
	assert_eq(int(gains.get("max_hp", -1)), 8)
	assert_eq(float(gains.get("attack", -1.0)), 1.0)


func test_apply_exp_multiple_levels_at_once() -> void:
	var curve := {
		"1": {"exp_to_next": 20, "hp_bonus": 8, "atk_bonus": 1},
		"2": {"exp_to_next": 57, "hp_bonus": 8, "atk_bonus": 1},
		"3": {"exp_to_next": 104, "hp_bonus": 8, "atk_bonus": 1},
	}
	var result: Dictionary = CalcScript.apply_exp(0, 1, 20 + 57 + 10, curve, 50)
	assert_eq(int(result["level"]), 3, "한 번에 두 레벨 상승")
	assert_eq(int(result["exp"]), 10, "남은 경험치는 레벨3 진행분")
	var ups: Array = result["level_ups"]
	assert_eq(ups.size(), 2)
	assert_eq(int((ups[0] as Dictionary)["new_level"]), 2)
	assert_eq(int((ups[1] as Dictionary)["new_level"]), 3)


func test_apply_exp_caps_at_max_level_and_drops_overflow() -> void:
	var curve := {"50": {"exp_to_next": 0, "hp_bonus": 8, "atk_bonus": 1}}
	var at_cap: Dictionary = CalcScript.apply_exp(0, 50, 999, curve, 50)
	assert_eq(int(at_cap["level"]), 50)
	assert_eq(int(at_cap["exp"]), 0, "만렙 초과분은 버려진다(D-152)")
	assert_eq((at_cap["level_ups"] as Array).size(), 0)


func test_stat_gains_for_level_maps_curve_columns_and_skips_zero_stamina() -> void:
	var curve := {"5": {"exp_to_next": 224, "hp_bonus": 8, "atk_bonus": 1, "stamina_bonus": 0}}
	var gains: Dictionary = CalcScript.stat_gains_for_level(5, curve)
	assert_eq(int(gains.get("max_hp", -1)), 8)
	assert_eq(float(gains.get("attack", -1.0)), 1.0)
	assert_false(gains.has("stamina"), "stamina_bonus=0이면 payload 키를 만들지 않는다")


# --- 실데이터(game/data/exp_curve.csv, monsters.json) 통합 확인 ---

func test_real_exp_curve_loads_with_no_validation_errors() -> void:
	assert_true(_data.tables.has("exp_curve"), "exp_curve.csv 가 로드되어야 한다")
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])
	assert_eq((_data.table("exp_curve") as Dictionary).size(), 50, "레벨 1~50, 50행")


func test_real_exp_curve_level1_to_2_is_20_per_director_design() -> void:
	# D-148 설계 의도: "슬라임 4마리(exp_reward=5) = 레벨 2" -> 1->2 요구치는 정확히 20.
	assert_eq(CalcScript.exp_for_level(1, _data.table("exp_curve")), 20)


func test_real_monsters_all_have_exp_reward() -> void:
	var monsters: Dictionary = _data.table("monsters")
	for monster_id: String in monsters:
		if monster_id.begins_with("_"):
			continue
		var entry: Dictionary = monsters[monster_id]
		assert_true(entry.has("exp_reward"), "monsters.%s: exp_reward 필드 누락" % monster_id)
		assert_gt(int(entry.get("exp_reward", 0)), 0, "monsters.%s: exp_reward는 양수여야 한다" % monster_id)


# --- 세이브 라운드트립(GameState.to_dict()/from_dict()) ---

func test_game_state_level_exp_round_trips_through_save_dict() -> void:
	var gs: Node = load("res://scripts/core/game_state.gd").new()
	gs.level = 7
	gs.exp = 123
	gs.stat_points = 9
	gs.skill_points = 3
	gs.level_stat_bonus = {"max_hp": 48, "attack": 6.0}
	var saved: Dictionary = gs.to_dict()

	var restored: Node = load("res://scripts/core/game_state.gd").new()
	restored.from_dict(saved)
	assert_eq(restored.level, 7)
	assert_eq(restored.exp, 123)
	assert_eq(restored.stat_points, 9)
	assert_eq(restored.skill_points, 3)
	assert_eq(int(restored.level_stat_bonus.get("max_hp", -1)), 48)
	assert_eq(float(restored.level_stat_bonus.get("attack", -1.0)), 6.0)
	gs.free()
	restored.free()
