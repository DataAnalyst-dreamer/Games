## StatCalc(순수 파생 수치 계산, M3-3) 단위 테스트. 계수는 숫자로 직접 주입한다 —
## stats.json 실측값과의 연동은 test_progression.gd의 Progression.get_derived() 테스트가 맡는다.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const CalcScript := preload("res://scripts/systems/stat_calc.gd")


func test_can_allocate_requires_points_and_valid_key() -> void:
	var keys := ["str", "agi", "dex", "int", "vit", "luk"]
	assert_true(CalcScript.can_allocate("str", 1, keys))
	assert_true(CalcScript.can_allocate("agi", 1, keys), "M4-4: AGI 신규 스탯")
	assert_false(CalcScript.can_allocate("str", 0, keys), "분배 실패: 포인트 없음")
	assert_false(CalcScript.can_allocate("mana", 5, keys), "분배 실패: 잘못된 키")
	assert_false(CalcScript.can_allocate("str", 2, keys, 3), "분배 실패: 체증 비용(3)보다 포인트가 적음")
	assert_true(CalcScript.can_allocate("str", 3, keys, 3))


# --- M4-4 v2(ro-benchmark-progression-v1.md §1~§3) ---

## §2: cost(n->n+1) = floor(n/10)+1, 총 198포인트로 단일 스탯 58까지.
func test_allocation_cost_curve_matches_spec_brackets_and_total() -> void:
	assert_eq(CalcScript.allocation_cost(0), 1)
	assert_eq(CalcScript.allocation_cost(9), 1, "0~9 구간은 1p")
	assert_eq(CalcScript.allocation_cost(10), 2, "10~19 구간은 2p")
	assert_eq(CalcScript.allocation_cost(49), 5, "40~49 구간은 5p")
	assert_eq(CalcScript.allocation_cost(50), 6)
	var spent: int = 0
	var value: int = 0
	while spent + CalcScript.allocation_cost(value) <= 198:
		spent += CalcScript.allocation_cost(value)
		value += 1
	assert_eq(value, 58, "198포인트 몰빵 상한(스펙 §2 검산)")
	assert_eq(spent, 198)


func test_combo_frame_mult_agi_primary_dex_secondary_and_floor() -> void:
	# stats.json worked_examples: AGI 50/DEX 0 -> 0.86, AGI 58 몰빵 -> 0.8376.
	assert_almost_eq(CalcScript.combo_frame_mult(50, 0, 0.0028, 0.0008, 0.65), 0.86, 0.0001)
	assert_almost_eq(CalcScript.combo_frame_mult(58, 0, 0.0028, 0.0008, 0.65), 0.8376, 0.0001)
	assert_almost_eq(CalcScript.combo_frame_mult(0, 100, 0.0028, 0.0008, 0.65), 0.92, 0.0001,
		"DEX는 부계수(0.0008)로만 기여")
	assert_almost_eq(CalcScript.combo_frame_mult(9999, 0, 0.0028, 0.0008, 0.65), 0.65, 0.0001, "floor 하한")
	# D-193: aspd_pct 패시브는 곱연산 — AGI 0에서 10%면 1/1.1.
	assert_almost_eq(CalcScript.combo_frame_mult(0, 0, 0.0028, 0.0008, 0.65, 10.0), 1.0 / 1.1, 0.0001)


func test_roll_iframe_bonus_and_move_speed_have_caps() -> void:
	assert_almost_eq(CalcScript.roll_iframe_bonus(58, 0.001, 0.15), 0.058, 0.0001)
	assert_almost_eq(CalcScript.roll_iframe_bonus(9999, 0.001, 0.15), 0.15, 0.0001, "cap 0.15s")
	assert_almost_eq(CalcScript.move_speed_mult(58, 0.0015, 0.20), 1.087, 0.0001, "AGI 58 -> +8.7%")
	assert_almost_eq(CalcScript.move_speed_mult(9999, 0.0015, 0.20), 1.20, 0.0001, "cap 20%")
	assert_almost_eq(CalcScript.move_speed_mult(0, 0.0015, 0.20, 5.0), 1.05, 0.0001, "패시브 5%는 곱연산")


func test_hitbox_scale_and_post_recovery_match_stats_worked_examples() -> void:
	assert_almost_eq(CalcScript.hitbox_scale_mult(50, 0.0015, 0.30), 1.075, 0.0001)
	assert_almost_eq(CalcScript.hitbox_scale_mult(150, 0.0015, 0.30), 1.225, 0.0001)
	assert_almost_eq(CalcScript.hitbox_scale_mult(9999, 0.0015, 0.30), 1.30, 0.0001, "cap 30%")
	assert_almost_eq(CalcScript.post_recovery_mult(50, 0.0015, 0.70), 0.925, 0.0001)
	assert_almost_eq(CalcScript.post_recovery_mult(9999, 0.0015, 0.70), 0.70, 0.0001, "floor 0.70")


func test_mdef_splits_between_int_and_vit() -> void:
	assert_almost_eq(CalcScript.mdef_value(20, 10, 0.5, 0.5), 15.0, 0.0001)
	assert_almost_eq(CalcScript.magic_attack_bonus(40, 0.15), 6.0, 0.0001)


## §3 worked_examples: INT 0 -> max_sp 20 / 전투중 1.0 / 유휴 2.5,
## INT 58 -> max_sp 136 / 전투중 2.74 / 유휴 6.85.
func test_max_sp_and_sp_regen_match_spec_worked_examples() -> void:
	assert_almost_eq(CalcScript.max_sp(0, 20.0, 2.0), 20.0, 0.0001)
	assert_almost_eq(CalcScript.max_sp(58, 20.0, 2.0), 136.0, 0.0001)
	assert_almost_eq(CalcScript.sp_regen(0, 1.0, 0.03, 2.5, false), 1.0, 0.0001)
	assert_almost_eq(CalcScript.sp_regen(0, 1.0, 0.03, 2.5, true), 2.5, 0.0001, "정지 2초 후 2.5배")
	assert_almost_eq(CalcScript.sp_regen(58, 1.0, 0.03, 2.5, false), 2.74, 0.0001)
	assert_almost_eq(CalcScript.sp_regen(58, 1.0, 0.03, 2.5, true), 6.85, 0.0001)
	assert_almost_eq(CalcScript.sp_regen(0, 1.0, 0.03, 2.5, false, 20.0), 1.2, 0.0001,
		"trick_insight(sp_regen_pct 20%)는 곱연산")


func test_attack_bonus_and_hp_bonus_are_linear() -> void:
	assert_eq(CalcScript.attack_bonus(10, 0.2), 2.0)
	assert_eq(CalcScript.attack_bonus(0, 0.2), 0.0)
	assert_eq(CalcScript.hp_bonus(20, 5.0), 100.0)


func test_defense_value_adds_equip_defense() -> void:
	assert_eq(CalcScript.defense_value(50, 1.0, 10.0), 60.0, "VIT 50*1.0 + 장비 방어력 10")


func test_damage_after_defense_matches_d162_worked_examples() -> void:
	# stats.json vit.defense_formula_examples: defense 50 -> 33.3% 감소, 100 -> 50%, 150 -> 60%.
	assert_eq(CalcScript.damage_after_defense(100.0, 0.0), 100)
	assert_eq(CalcScript.damage_after_defense(100.0, 50.0), 67, "100*100/150 = 66.67 -> 반올림 67")
	assert_eq(CalcScript.damage_after_defense(100.0, 100.0), 50)
	assert_eq(CalcScript.damage_after_defense(100.0, 150.0), 40)


func test_crit_chance_applies_cap() -> void:
	assert_almost_eq(CalcScript.crit_chance(0, 0.05, 0.001, 0.75), 0.05, 0.0001)
	assert_almost_eq(CalcScript.crit_chance(20, 0.05, 0.001, 0.75), 0.07, 0.0001, "LUK 20 -> 5%+2%=7% (stats.json worked_examples)")
	assert_almost_eq(CalcScript.crit_chance(100000, 0.05, 0.001, 0.75), 0.75, 0.0001, "cap 상한")


func test_crit_damage_multiplies_and_rounds() -> void:
	assert_eq(CalcScript.crit_damage(10, 1.5), 15)
	assert_eq(CalcScript.crit_damage(7, 1.5), 11, "10.5 -> round 11")


func test_cooldown_mult_applies_cap() -> void:
	assert_almost_eq(CalcScript.cooldown_mult(0, 0.002, 0.30), 1.0, 0.0001)
	assert_almost_eq(CalcScript.cooldown_mult(100, 0.002, 0.30), 0.8, 0.0001, "INT 100 -> 20% 감소")
	assert_almost_eq(CalcScript.cooldown_mult(1000, 0.002, 0.30), 0.70, 0.0001, "cap 30% 상한")
