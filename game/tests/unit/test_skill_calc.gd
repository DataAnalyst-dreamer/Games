## SkillCalc(순수 학습/장착/시전 조건 계산, M3-3) 단위 테스트. 테이블은 dict로 직접
## 주입한다 — 실제 skills.json 연동은 test_progression.gd가 맡는다.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const CalcScript := preload("res://scripts/systems/skill_calc.gd")


func _make_table() -> Dictionary:
	return {
		"skill_a": {"cost_sp": 1, "cooldown_sec": 4.0, "stamina_cost": 15.0, "damage_mult": 1.8, "requires": []},
		"skill_b": {"cost_sp": 2, "cooldown_sec": 2.0, "stamina_cost": 10.0, "damage_mult": 1.0, "requires": ["skill_a"]},
	}


func test_can_learn_requires_points_and_prereq() -> void:
	var table := _make_table()
	assert_true(CalcScript.can_learn("skill_a", [], 1, table), "포인트 충분 + 선행 없음")
	assert_false(CalcScript.can_learn("skill_a", [], 0, table), "포인트 부족")
	assert_false(CalcScript.can_learn("skill_a", ["skill_a"], 1, table), "이미 배움")
	assert_false(CalcScript.can_learn("skill_b", [], 2, table), "선행(skill_a) 미충족")
	assert_true(CalcScript.can_learn("skill_b", ["skill_a"], 2, table), "선행 충족")
	assert_false(CalcScript.can_learn("ghost", [], 99, table), "존재하지 않는 id")


func test_can_equip_requires_learned_or_empty() -> void:
	assert_true(CalcScript.can_equip("skill_a", ["skill_a"]))
	assert_false(CalcScript.can_equip("skill_a", []))
	assert_true(CalcScript.can_equip("", []), "빈 문자열(해제)은 항상 허용")


func test_can_cast_checks_cooldown_and_stamina() -> void:
	var table := _make_table()
	assert_true(CalcScript.can_cast("skill_a", table, 15.0, 0.0))
	assert_false(CalcScript.can_cast("skill_a", table, 14.9, 0.0), "스태미나 부족")
	assert_false(CalcScript.can_cast("skill_a", table, 15.0, 0.1), "쿨타임 중")
	assert_false(CalcScript.can_cast("ghost", table, 999.0, 0.0), "존재하지 않는 id")


func test_damage_for_uses_damage_mult() -> void:
	var entry: Dictionary = {"damage_mult": 1.8}
	assert_eq(CalcScript.damage_for(entry, 10.0), 18)
	assert_eq(CalcScript.damage_for({"damage_mult": 0.0}, 999.0), 0, "자기 버프 스킬은 0")


func test_effective_cooldown_applies_multiplier() -> void:
	assert_almost_eq(CalcScript.effective_cooldown(4.0, 0.8), 3.2, 0.0001)
