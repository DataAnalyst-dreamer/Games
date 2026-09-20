## StatCalc(순수 파생 수치 계산, M3-3) 단위 테스트. 계수는 숫자로 직접 주입한다 —
## stats.json 실측값과의 연동은 test_progression.gd의 Progression.get_derived() 테스트가 맡는다.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const CalcScript := preload("res://scripts/systems/stat_calc.gd")


func test_can_allocate_requires_points_and_valid_key() -> void:
	var keys := ["str", "dex", "int", "vit", "luk"]
	assert_true(CalcScript.can_allocate("str", 1, keys))
	assert_false(CalcScript.can_allocate("str", 0, keys), "분배 실패: 포인트 없음")
	assert_false(CalcScript.can_allocate("mana", 5, keys), "분배 실패: 잘못된 키")


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
