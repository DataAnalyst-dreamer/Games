## GUT: 성장 시스템 v2 서비스 계층(M4-4, D-167~D-174/D-184~D-194) — 스탯 체증 비용,
## SP 자원(소모·회복·유휴 가속), 스킬 노드 레벨업/선행 게이트, 패시브 합산, 레벨업 payload.
## Progression/GameState는 오토로드 싱글턴이라(주입 불가) 실제 싱글턴을 조작하고
## before_each/after_each로 스냅샷·복원한다(test_hotbar.gd와 동일 관례).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

var _snapshot: Dictionary


func before_each() -> void:
	_snapshot = {
		"stats": GameState.stats.duplicate(),
		"learned": GameState.learned_skills.duplicate(),
		"stat_points": GameState.stat_points,
		"skill_points": GameState.skill_points,
		"sp": GameState.sp,
	}
	GameState.stats = {"str": 0, "agi": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0}
	GameState.learned_skills = {}
	GameState.stat_points = 0
	GameState.skill_points = 0
	Progression.refill_sp()


func after_each() -> void:
	GameState.stats = _snapshot["stats"]
	GameState.learned_skills = _snapshot["learned"]
	GameState.stat_points = _snapshot["stat_points"]
	GameState.skill_points = _snapshot["skill_points"]
	GameState.sp = _snapshot["sp"]


# --- 스탯 분배(체증 비용, §2) ---

func test_allocate_stat_consumes_increasing_cost() -> void:
	GameState.stat_points = 30
	for i in 10:
		assert_true(Progression.allocate_stat("agi"), "0~9 구간은 1p씩")
	assert_eq(GameState.stats["agi"], 10)
	assert_eq(GameState.stat_points, 20, "10회 × 1p")
	assert_eq(Progression.next_stat_cost("agi"), 2, "10~19 구간은 2p")
	assert_true(Progression.allocate_stat("agi"))
	assert_eq(GameState.stat_points, 18)


func test_allocate_stat_fails_without_enough_points_for_current_bracket() -> void:
	GameState.stats["str"] = 10
	GameState.stat_points = 1
	assert_false(Progression.allocate_stat("str"), "비용 2p인데 1p만 있으면 실패")
	assert_eq(GameState.stats["str"], 10)
	assert_eq(GameState.stat_points, 1, "실패 시 포인트는 그대로")


func test_allocate_stat_rejects_unknown_key() -> void:
	GameState.stat_points = 5
	assert_false(Progression.allocate_stat("mana"))


## D-168: 6스탯 전부가 파생치로 연결돼 있어야 한다(AGI/DEX가 실제로 무언가를 바꾸는지).
func test_every_stat_moves_a_derived_value() -> void:
	var before: Dictionary = Progression.get_derived()
	GameState.stats = {"str": 20, "agi": 20, "dex": 20, "int": 20, "vit": 20, "luk": 20}
	var after: Dictionary = Progression.get_derived()
	assert_lt(float(after["combo_frame_mult"]), float(before["combo_frame_mult"]), "AGI/DEX -> 콤보 프레임 단축")
	assert_gt(float(after["roll_iframe_bonus"]), float(before["roll_iframe_bonus"]), "AGI -> 구르기 무적 연장")
	assert_gt(float(after["move_speed_mult"]), float(before["move_speed_mult"]), "AGI -> 이동속도")
	assert_gt(float(after["hitbox_scale"]), float(before["hitbox_scale"]), "DEX -> 히트박스 배율")
	assert_lt(float(after["post_recovery_mult"]), float(before["post_recovery_mult"]), "DEX -> 후딜 단축")
	assert_lt(float(after["cooldown_mult"]), float(before["cooldown_mult"]), "INT -> 쿨다운 감소")
	assert_gt(float(after["max_sp"]), float(before["max_sp"]), "INT -> MaxSP")
	assert_gt(float(after["sp_regen"]), float(before["sp_regen"]), "INT -> SP 회복")
	assert_gt(float(after["matk"]), float(before["matk"]), "INT -> MATK")
	assert_gt(float(after["mdef"]), float(before["mdef"]), "INT/VIT -> MDEF")
	assert_gt(float(after["defense"]), float(before["defense"]), "VIT -> DEF")
	assert_gt(float(after["crit_chance"]), float(before["crit_chance"]), "LUK -> CRIT")


# --- SP 자원(§3, D-169/D-190) ---

func test_max_sp_follows_int_and_refill_fills_to_cap() -> void:
	assert_almost_eq(Progression.max_sp(), 20.0, 0.001, "INT 0 -> 20")
	GameState.stats["int"] = 10
	assert_almost_eq(Progression.max_sp(), 40.0, 0.001, "20 + INT 10 * 2.0")
	Progression.refill_sp()
	assert_almost_eq(GameState.sp, 40.0, 0.001)


func test_spend_sp_fails_when_insufficient_and_emits_on_success() -> void:
	Progression.refill_sp()
	var seen: Array = []
	var cb := func(current: float, max_value: float) -> void: seen.append([current, max_value])
	Events.sp_changed.connect(cb)
	assert_true(Progression.spend_sp(10.0))
	assert_almost_eq(GameState.sp, 10.0, 0.001)
	assert_false(Progression.spend_sp(10.1), "부족하면 소모 없이 실패")
	Events.sp_changed.disconnect(cb)
	assert_almost_eq(GameState.sp, 10.0, 0.001)
	assert_eq(seen.size(), 1, "성공했을 때만 sp_changed")


func test_sp_regen_accelerates_after_idle_delay() -> void:
	GameState.stats["int"] = 0
	Progression.refill_sp()
	GameState.sp = 0.0
	# 마지막 시전 직후(전투 중) 1초: 기본 1.0/s.
	Progression.start_skill_cooldown(99, "blade_power_slash")
	Progression._tick_sp(1.0)
	assert_almost_eq(GameState.sp, 1.0, 0.001, "전투 중 회복은 1.0/s")
	# 유휴 판정선(2초)을 넘긴 뒤 1초: 2.5배.
	Progression._tick_sp(2.0)
	GameState.sp = 0.0
	Progression._tick_sp(1.0)
	assert_almost_eq(GameState.sp, 2.5, 0.001, "정지 2초 후 2.5배 가속")


func test_sp_regen_clamps_to_max() -> void:
	Progression.refill_sp()
	Progression._tick_sp(10.0)
	assert_almost_eq(GameState.sp, Progression.max_sp(), 0.001)


# --- 스킬 트리 v2(§4, D-170/D-186) ---

func test_learn_skill_levels_up_and_respects_prerequisite_levels() -> void:
	GameState.skill_points = 10
	assert_eq(Progression.get_skill_level("blade_power_slash"), 0)
	assert_true(Progression.learn_skill("blade_power_slash"))
	assert_eq(Progression.get_skill_level("blade_power_slash"), 1)
	assert_eq(GameState.skill_points, 9, "노드 레벨당 스킬 포인트 1")

	# blade_followup은 blade_power_slash Lv3이 선행(§4-3).
	assert_eq(Progression.can_learn_skill("blade_followup").get("reason"), &"requires")
	assert_true(Progression.learn_skill("blade_power_slash"))
	assert_true(Progression.learn_skill("blade_power_slash"))
	assert_true(bool(Progression.can_learn_skill("blade_followup").get("ok")), "선행 Lv3 충족 후 해금")
	assert_true(Progression.learn_skill("blade_followup"))


func test_learn_skill_reasons_no_points_and_maxed_and_unknown() -> void:
	GameState.skill_points = 0
	assert_eq(Progression.can_learn_skill("blade_thrust").get("reason"), &"no_points")
	assert_false(Progression.learn_skill("blade_thrust"))
	GameState.skill_points = 99
	GameState.learned_skills["blade_thrust"] = 5
	assert_eq(Progression.can_learn_skill("blade_thrust").get("reason"), &"maxed")
	assert_eq(Progression.can_learn_skill("no_such_skill").get("reason"), &"unknown")


func test_skill_level_data_follows_current_level() -> void:
	GameState.skill_points = 99
	Progression.learn_skill("blade_power_slash")
	var lv1: Dictionary = Progression.skill_level_data("blade_power_slash")
	Progression.learn_skill("blade_power_slash")
	var lv2: Dictionary = Progression.skill_level_data("blade_power_slash")
	assert_gt(float(lv2["damage_mult"]), float(lv1["damage_mult"]), "레벨업하면 배율이 오른다")
	assert_gt(float(lv2["sp_cost"]), float(lv1["sp_cost"]), "SP 소모도 함께 오른다")
	assert_lt(float(lv2["cooldown_sec"]), float(lv1["cooldown_sec"]), "쿨다운은 줄어든다")


func test_passive_bonus_sums_learned_levels_and_affects_derived() -> void:
	GameState.skill_points = 99
	assert_almost_eq(Progression.passive_bonus("atk_pct"), 0.0, 0.001)
	Progression.learn_skill("blade_focus")
	Progression.learn_skill("blade_focus")
	assert_almost_eq(Progression.passive_bonus("atk_pct"), 4.0, 0.001, "blade_focus Lv2 = 4%")
	var crit_before: float = Progression.get_derived()["crit_chance"]
	Progression.learn_skill("trick_insight") # sp_regen_pct 4%
	assert_almost_eq(Progression.passive_bonus("sp_regen_pct"), 4.0, 0.001)
	assert_gt(float(Progression.get_derived()["sp_regen"]), 1.0, "패시브가 SP 회복에 반영")
	assert_almost_eq(float(Progression.get_derived()["crit_chance"]), crit_before, 0.0001,
		"관련 없는 패시브는 다른 파생치를 건드리지 않는다")


func test_grant_skill_points_adds_and_emits() -> void:
	var seen: Array = []
	var cb := func(_learned: Dictionary, _slots: Array, points: int) -> void: seen.append(points)
	Events.skills_changed.connect(cb)
	Progression.grant_skill_points(2)
	Events.skills_changed.disconnect(cb)
	assert_eq(GameState.skill_points, 2, "퀘스트 보상 grant_skill_point:N 경로(D-192)")
	assert_eq(seen, [2])


# --- 버프(§4-2) ---

func test_apply_buff_expires_after_duration() -> void:
	Progression.apply_buff("atk_buff_pct", 10.0, 1.0)
	assert_almost_eq(Progression.buff_pct("atk_buff_pct"), 10.0, 0.001)
	Progression._tick_buffs(0.5)
	assert_almost_eq(Progression.buff_pct("atk_buff_pct"), 10.0, 0.001, "지속시간 중에는 유지")
	Progression._tick_buffs(0.6)
	assert_almost_eq(Progression.buff_pct("atk_buff_pct"), 0.0, 0.001, "만료 후 사라진다")
