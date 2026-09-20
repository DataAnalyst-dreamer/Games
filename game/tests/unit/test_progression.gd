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


# --- 실데이터(game/data/skills.json, stats.json.allocation, M3-3) 통합 확인 ---

const SkillCalcScript := preload("res://scripts/systems/skill_calc.gd")
const REAL_SKILL_IDS := [
	"blade_power_slash", "blade_thrust", "guard_shield_bash",
	"guard_iron_wall", "trick_dash_strike", "trick_fleet_step",
]


func test_real_skills_table_has_six_active_skills_with_no_validation_errors() -> void:
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])
	var skills: Dictionary = _data.table("skills")
	for id: String in REAL_SKILL_IDS:
		assert_true(skills.has(id), "skills.json에 %s가 있어야 한다" % id)
		assert_eq(String(skills[id].get("node_type", "")), "active")


func test_real_skills_hitbox_null_iff_damage_mult_zero() -> void:
	# skills-m3.md §2: damage_mult>0이면 hitbox 필수, 0이면(순수 자기 버프) null.
	var skills: Dictionary = _data.table("skills")
	for id: String in REAL_SKILL_IDS:
		var entry: Dictionary = skills[id]
		var has_hitbox: bool = entry.get("hitbox", null) != null
		var has_damage: bool = float(entry.get("damage_mult", 0.0)) > 0.0
		assert_eq(has_hitbox, has_damage, "skills.%s: hitbox 유무와 damage_mult>0 이 일치해야 한다" % id)


func test_real_skill_damage_for_blade_power_slash() -> void:
	var entry: Dictionary = _data.table("skills")["blade_power_slash"]
	assert_eq(SkillCalcScript.damage_for(entry, 10.0), 18, "damage_mult=1.8 * effective_attack 10")


func test_real_stats_allocation_initial_is_all_zero_and_uncapped() -> void:
	# JSON 숫자는 float으로 로드되므로(godot-engineer 관례, D-45 정본 문자열 검증과 동일
	# 이유) 값 비교는 각 키를 float으로 캐스팅해서 한다.
	var allocation: Dictionary = _data.get_value("stats", "allocation", {})
	var initial: Dictionary = allocation.get("initial", {})
	for key: String in ["str", "dex", "int", "vit", "luk"]:
		assert_eq(float(initial.get(key, -1)), 0.0, "allocation.initial.%s" % key)
	assert_null(allocation.get("max_per_stat"), "D-158: 스탯당 상한 없음")


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


## M3-3(D-158~D-162): 5스탯/배운 스킬/슬롯도 동일 라운드트립을 거쳐야 한다. M4-1부터
## skill_slots는 9칸이라(D-175~D-177) 옛 2칸만 채운 배열도 나머지가 빈 문자열로
## 패딩돼야 한다(from_dict의 자체 크기 방어 — 마이그레이션 자체는 Progression 몫).
func test_game_state_stats_and_skills_round_trip_through_save_dict() -> void:
	var gs: Node = load("res://scripts/core/game_state.gd").new()
	gs.stats = {"str": 3, "dex": 1, "int": 0, "vit": 5, "luk": 2}
	var learned: Array[String] = ["blade_power_slash", "blade_thrust"]
	gs.learned_skills = learned
	var slots: Array[String] = ["blade_power_slash", ""]
	gs.skill_slots = slots
	var saved: Dictionary = gs.to_dict()

	var restored: Node = load("res://scripts/core/game_state.gd").new()
	restored.from_dict(saved)
	assert_eq(restored.stats, {"str": 3, "dex": 1, "int": 0, "vit": 5, "luk": 2})
	assert_eq(restored.learned_skills, ["blade_power_slash", "blade_thrust"])
	assert_eq(restored.skill_slots, ["blade_power_slash", "", "", "", "", "", "", "", ""])
	gs.free()
	restored.free()


## M4-1(D-175~D-177) 신설: hotbar 9칸도 세이브 라운드트립을 거쳐야 한다.
func test_game_state_hotbar_round_trips_through_save_dict() -> void:
	var gs: Node = load("res://scripts/core/game_state.gd").new()
	gs.hotbar[0] = {"kind": "skill", "id": "blade_power_slash"}
	gs.hotbar[3] = {"kind": "item", "id": "potion_hp_small"}
	var saved: Dictionary = gs.to_dict()

	var restored: Node = load("res://scripts/core/game_state.gd").new()
	restored.from_dict(saved)
	assert_eq(restored.hotbar.size(), 9)
	assert_eq(restored.hotbar[0], {"kind": "skill", "id": "blade_power_slash"})
	assert_eq(restored.hotbar[3], {"kind": "item", "id": "potion_hp_small"})
	assert_eq(restored.hotbar[1], {"kind": "", "id": ""})
	gs.free()
	restored.free()


## M4-1 옛 세이브(hotbar 필드 자체가 없음) 호환: GameState.from_dict()는 hotbar를
## 의도적으로 빈 배열로 남겨야 한다(마이그레이션 판단 신호 — Progression이 소비).
func test_game_state_from_dict_leaves_hotbar_empty_when_save_predates_it() -> void:
	var restored: Node = load("res://scripts/core/game_state.gd").new()
	restored.from_dict({"skill_slots": ["blade_power_slash", ""]})
	assert_true(restored.hotbar.is_empty(), "hotbar 키가 없는 옛 세이브는 빈 배열이어야 마이그레이션 신호가 된다")
	assert_eq(restored.skill_slots, ["blade_power_slash", "", "", "", "", "", "", "", ""])
	restored.free()
