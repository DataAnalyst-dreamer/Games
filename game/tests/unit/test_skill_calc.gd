## SkillCalc(스킬 트리 v2 순수 계산, M4-4) 단위 테이블 주입 테스트. 실제 skills.json
## 연동은 test_progression.gd / test_progression_v2.gd가 맡는다.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const CalcScript := preload("res://scripts/systems/skill_calc.gd")


## v2 스키마(§4): requires=[{skill, level}], 수치는 levels[] 안, 자원은 sp_cost.
func _make_table() -> Dictionary:
	return {
		"skill_a": {
			"node_type": "active", "max_level": 3, "cost_skill_point_per_level": 1, "requires": [],
			"levels": [
				{"level": 1, "sp_cost": 10.0, "cooldown_sec": 4.5, "damage_mult": 1.6},
				{"level": 2, "sp_cost": 12.0, "cooldown_sec": 4.3, "damage_mult": 1.8},
				{"level": 3, "sp_cost": 14.0, "cooldown_sec": 4.1, "damage_mult": 2.0},
			],
		},
		"skill_b": {
			"node_type": "active", "max_level": 5, "cost_skill_point_per_level": 1,
			"requires": [{"skill": "skill_a", "level": 3}],
			"levels": [{"level": 1, "sp_cost": 6.0, "cooldown_sec": 2.2, "damage_mult": 1.1}],
		},
		"passive_a": {
			"node_type": "passive", "max_level": 5, "cost_skill_point_per_level": 1, "requires": [],
			"passive_stat": "atk_pct",
			"levels": [{"level": 1, "value": 2}, {"level": 2, "value": 4}, {"level": 3, "value": 6}],
		},
		"passive_b": {
			"node_type": "passive", "max_level": 5, "cost_skill_point_per_level": 1, "requires": [],
			"passive_stat": "atk_pct",
			"levels": [{"level": 1, "value": 3}],
		},
	}


func test_level_data_returns_row_or_empty_out_of_range() -> void:
	var table := _make_table()
	assert_eq(float(CalcScript.level_data(table["skill_a"], 2).get("damage_mult", 0.0)), 1.8)
	assert_eq(CalcScript.level_data(table["skill_a"], 0), {}, "0레벨(미습득)은 빈 Dictionary")
	assert_eq(CalcScript.level_data(table["skill_a"], 4), {}, "max_level 초과도 빈 Dictionary")


func test_can_learn_reasons() -> void:
	var table := _make_table()
	assert_true(bool(CalcScript.can_learn("skill_a", {}, 1, table).get("ok")), "1레벨 습득 가능")
	assert_eq(CalcScript.can_learn("skill_a", {}, 0, table).get("reason"), &"no_points")
	assert_eq(CalcScript.can_learn("skill_a", {"skill_a": 3}, 9, table).get("reason"), &"maxed")
	assert_eq(CalcScript.can_learn("skill_b", {"skill_a": 2}, 9, table).get("reason"), &"requires",
		"선행 스킬 레벨 3 미만이면 잠김")
	assert_true(bool(CalcScript.can_learn("skill_b", {"skill_a": 3}, 9, table).get("ok")),
		"선행 레벨 충족 시 해금")
	assert_eq(CalcScript.can_learn("ghost", {}, 9, table).get("reason"), &"unknown")


func test_can_learn_allows_level_up_of_already_learned_node() -> void:
	var table := _make_table()
	var check: Dictionary = CalcScript.can_learn("skill_a", {"skill_a": 1}, 1, table)
	assert_true(bool(check.get("ok")), "이미 배운 노드도 max_level 미만이면 레벨업 가능(v1과 달라진 점)")


func test_can_equip_rejects_unlearned_and_passive_nodes() -> void:
	var table := _make_table()
	assert_true(CalcScript.can_equip("skill_a", {"skill_a": 1}, table))
	assert_false(CalcScript.can_equip("skill_a", {}, table), "미습득")
	assert_false(CalcScript.can_equip("passive_a", {"passive_a": 2}, table), "패시브는 슬롯 장착 불가(§5)")
	assert_true(CalcScript.can_equip("", {}, table), "빈 문자열(해제)은 항상 허용")


func test_can_cast_uses_sp_cost_of_current_level_and_cooldown() -> void:
	var table := _make_table()
	assert_true(CalcScript.can_cast("skill_a", 1, table, 10.0, 0.0))
	assert_false(CalcScript.can_cast("skill_a", 1, table, 9.9, 0.0), "SP 부족")
	assert_false(CalcScript.can_cast("skill_a", 2, table, 10.0, 0.0), "Lv2는 sp_cost 12 필요")
	assert_true(CalcScript.can_cast("skill_a", 2, table, 12.0, 0.0))
	assert_false(CalcScript.can_cast("skill_a", 1, table, 99.0, 0.1), "쿨타임 중")
	assert_false(CalcScript.can_cast("skill_a", 0, table, 99.0, 0.0), "미습득(0레벨)")
	assert_false(CalcScript.can_cast("ghost", 1, table, 99.0, 0.0), "존재하지 않는 id")


func test_damage_for_uses_level_damage_mult() -> void:
	assert_eq(CalcScript.damage_for({"damage_mult": 1.8}, 10.0), 18)
	assert_eq(CalcScript.damage_for({}, 999.0), 0, "damage_mult가 없는 버프/패시브는 0")


func test_effective_cooldown_applies_multiplier() -> void:
	assert_almost_eq(CalcScript.effective_cooldown(4.0, 0.8), 3.2, 0.0001)


func test_passive_totals_sums_same_stat_across_nodes_and_ignores_actives() -> void:
	var table := _make_table()
	var totals: Dictionary = CalcScript.passive_totals(
		{"skill_a": 3, "passive_a": 3, "passive_b": 1}, table)
	assert_almost_eq(float(totals.get("atk_pct", 0.0)), 9.0, 0.0001, "passive_a Lv3(6) + passive_b Lv1(3)")
	assert_eq(totals.size(), 1, "액티브 노드는 패시브 합산에 끼지 않는다")
	assert_eq(CalcScript.passive_totals({}, table), {}, "아무것도 안 배웠으면 빈 합계")
