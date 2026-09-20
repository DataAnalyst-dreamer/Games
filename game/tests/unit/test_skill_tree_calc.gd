## SkillTreeCalc(scripts/ui/skill_tree_calc.gd) 테스트(M4-5, D-161/D-194). tier 배치·
## 잠금 판정·요구 텍스트·핫바 SP 조회를 skills.json v2 구조를 흉내 낸 dict로 검증한다
## (test_skill_calc.gd와 같은 관례 — 실제 game/data/skills.json 연동 확인은 스모크가 맡는다).
extends GutTest

const CalcScript := preload("res://scripts/ui/skill_tree_calc.gd")


func _make_table() -> Dictionary:
	return {
		"_comment": "메타 키, skill_ids()에서 제외되어야 함",
		"a1": {"series": "blade", "node_type": "active", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [{"level": 1, "sp_cost": 10}]},
		"a2": {"series": "blade", "node_type": "active", "requires": [{"skill": "a1", "level": 3}],
			"max_level": 5, "cost_skill_point_per_level": 1, "levels": [{"level": 1, "sp_cost": 14}]},
		"a3": {"series": "blade", "node_type": "passive", "requires": [{"skill": "a2", "level": 3}],
			"max_level": 5, "cost_skill_point_per_level": 1, "levels": [{"level": 1, "value": 2}]},
		"b1": {"series": "guard", "node_type": "active", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [{"level": 1, "sp_cost": 10}]},
	}


func test_skill_ids_excludes_meta_keys() -> void:
	var ids: Array[String] = CalcScript.skill_ids(_make_table())
	assert_false(ids.has("_comment"))
	assert_eq(ids.size(), 4)


func test_node_tier_chain() -> void:
	var table := _make_table()
	assert_eq(CalcScript.node_tier("a1", table), 1, "선행 없음 = T1")
	assert_eq(CalcScript.node_tier("a2", table), 2, "T1 1개 선행 = T2")
	assert_eq(CalcScript.node_tier("a3", table), 3, "T2 1개 선행 = T3")


func test_nodes_for_series_filters_by_series() -> void:
	var table := _make_table()
	assert_eq(CalcScript.nodes_for_series("blade", table), ["a1", "a2", "a3"])
	assert_eq(CalcScript.nodes_for_series("guard", table), ["b1"])


func test_focus_order_is_tier_then_column_order() -> void:
	assert_eq(CalcScript.focus_order("blade", _make_table()), ["a1", "a2", "a3"])


func test_normalize_learned_handles_dictionary() -> void:
	assert_eq(CalcScript.normalize_learned({"a1": 3}), {"a1": 3})


func test_normalize_learned_handles_array_as_level_1() -> void:
	assert_eq(CalcScript.normalize_learned(["a1", "b1"]), {"a1": 1, "b1": 1})


func test_normalize_learned_handles_neither() -> void:
	assert_eq(CalcScript.normalize_learned(null), {})


func test_node_state_learnable_when_fresh_and_points_available() -> void:
	var state: Dictionary = CalcScript.node_state("a1", _make_table(), {}, 1)
	assert_eq(state["state"], "learnable")


func test_node_state_locked_no_points() -> void:
	var state: Dictionary = CalcScript.node_state("a1", _make_table(), {}, 0)
	assert_eq(state["state"], "locked")
	assert_eq(state["reason"], &"no_points")


func test_node_state_locked_requires_not_met() -> void:
	var state: Dictionary = CalcScript.node_state("a2", _make_table(), {}, 99)
	assert_eq(state["state"], "locked")
	assert_eq(state["reason"], &"requires")


func test_node_state_learnable_once_requires_met() -> void:
	var state: Dictionary = CalcScript.node_state("a2", _make_table(), {"a1": 3}, 1)
	assert_eq(state["state"], "learnable")


func test_node_state_maxed() -> void:
	var state: Dictionary = CalcScript.node_state("a1", _make_table(), {"a1": 5}, 99)
	assert_eq(state["state"], "maxed")
	assert_eq(state["reason"], &"maxed")


func test_node_state_unknown_id() -> void:
	var state: Dictionary = CalcScript.node_state("ghost", _make_table(), {}, 99)
	assert_eq(state["state"], "locked")
	assert_eq(state["reason"], &"unknown")


func test_sp_cost_at_zero_when_not_learned() -> void:
	assert_eq(CalcScript.sp_cost_at(_make_table(), "a1", 0), 0.0)


func test_sp_cost_at_reads_level_entry() -> void:
	assert_eq(CalcScript.sp_cost_at(_make_table(), "a2", 1), 14.0)


func test_level_detail_text_excludes_level_key() -> void:
	var text: String = CalcScript.level_detail_text(_make_table()["a1"], 1)
	assert_true(text.contains("sp_cost"))
	assert_false(text.contains("level 1"))
