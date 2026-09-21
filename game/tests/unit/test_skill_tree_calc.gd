## SkillTreeCalc(scripts/ui/skill_tree_calc.gd) 테스트(M4-5, D-161/D-194). tier 배치·
## 잠금 판정·요구 텍스트·핫바 SP 조회를 skills.json v2 구조를 흉내 낸 dict로 검증한다
## (test_skill_calc.gd와 같은 관례 — 실제 game/data/skills.json 연동 확인은 스모크가 맡는다).
extends GutTest

const CalcScript := preload("res://scripts/ui/skill_tree_calc.gd")


func _make_table() -> Dictionary:
	return {
		"_comment": "메타 키, skill_ids()에서 제외되어야 함",
		"a1": {"series": "blade", "node_type": "active", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [
				{"level": 1, "sp_cost": 10, "cooldown_sec": 4.5, "damage_mult": 1.6},
				{"level": 2, "sp_cost": 12, "cooldown_sec": 4.3, "damage_mult": 1.8},
			]},
		"a2": {"series": "blade", "node_type": "active", "requires": [{"skill": "a1", "level": 3}],
			"max_level": 5, "cost_skill_point_per_level": 1, "levels": [{"level": 1, "sp_cost": 14}]},
		"a3": {"series": "blade", "node_type": "passive", "requires": [{"skill": "a2", "level": 3}],
			"max_level": 5, "cost_skill_point_per_level": 1, "passive_stat": "atk_pct",
			"levels": [{"level": 1, "value": 2}, {"level": 2, "value": 4}]},
		"b1": {"series": "guard", "node_type": "active", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [{"level": 1, "sp_cost": 10}]},
	}


## level_detail_rows() 전용 픽스처(tier/series/focus_order 테스트의 _make_table()과
## 분리 — 저 테스트들은 정확히 4개 노드 개수/순서를 검증하므로 여기 섞으면 깨진다).
func _make_detail_table() -> Dictionary:
	return {
		"guard_wall": {"series": "guard", "node_type": "active", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [
				{"level": 1, "sp_cost": 10, "cooldown_sec": 8.0, "damage_mult": 0,
					"self_effect": {"invuln_sec": 0.8}},
				{"level": 2, "sp_cost": 12, "cooldown_sec": 7.6, "damage_mult": 0,
					"self_effect": {"invuln_sec": 0.9}},
			]},
		"buff1": {"series": "blade", "node_type": "buff", "requires": [], "max_level": 5,
			"cost_skill_point_per_level": 1, "levels": [
				{"level": 1, "sp_cost": 18, "cooldown_sec": 25, "self_effect": {"atk_buff_pct": 6, "duration_sec": 5}},
			]},
		"maxed1": {"series": "blade", "node_type": "active", "requires": [], "max_level": 1,
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


# --- level_detail_rows(): D-196 후속(필드명 원문 노출 금지, 다음 레벨 화살표) ---

func test_level_detail_rows_active_has_next_arrow() -> void:
	var rows: Array[Dictionary] = CalcScript.level_detail_rows(_make_table()["a1"], 1)
	var by_field: Dictionary = {}
	for row: Dictionary in rows:
		by_field[row["field"]] = row
	assert_eq(by_field["sp_cost"]["text"], "10")
	assert_eq(by_field["sp_cost"]["next_text"], "12", "레벨2 sp_cost=12로 화살표 대상 채워짐")
	assert_eq(by_field["cooldown_sec"]["text"], "4.5")
	assert_eq(by_field["damage_mult"]["text"], "160", "damage_mult 1.6 -> 퍼센트 160(원문 노출 금지, 배율->%%)")
	assert_eq(by_field["damage_mult"]["next_text"], "180")


func test_level_detail_rows_damage_mult_zero_is_skipped() -> void:
	var rows: Array[Dictionary] = CalcScript.level_detail_rows(_make_detail_table()["guard_wall"], 1)
	var fields := []
	for row: Dictionary in rows: fields.append(row["field"])
	assert_false(fields.has("damage_mult"), "순수 유틸 스킬(damage_mult=0)은 피해 줄 생략")
	assert_true(fields.has("invuln_sec"))


func test_level_detail_rows_self_effect_buff() -> void:
	var rows: Array[Dictionary] = CalcScript.level_detail_rows(_make_detail_table()["buff1"], 1)
	var by_field: Dictionary = {}
	for row: Dictionary in rows: by_field[row["field"]] = row
	assert_eq(by_field["atk_buff_pct"]["text"], "6")
	assert_eq(by_field["duration_sec"]["text"], "5.0")


func test_level_detail_rows_passive_stat() -> void:
	var rows: Array[Dictionary] = CalcScript.level_detail_rows(_make_table()["a3"], 1)
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["field"], "atk_pct")
	assert_eq(rows[0]["text"], "2")
	assert_eq(rows[0]["next_text"], "4")


func test_level_detail_rows_no_next_arrow_when_maxed() -> void:
	var rows: Array[Dictionary] = CalcScript.level_detail_rows(_make_detail_table()["maxed1"], 1)
	assert_eq(rows[0]["next_text"], "", "max_level=1이면 다음 레벨이 없어 화살표도 없음")


# --- assignable_skill_id(M5-1 마우스: 핫바 미리보기 칸 클릭) ---

func test_assignable_skill_id_returns_id_for_learned_active() -> void:
	var table: Dictionary = _make_table()
	assert_eq(CalcScript.assignable_skill_id("a1", table, {"a1": 1}), "a1")


func test_assignable_skill_id_empty_when_not_learned() -> void:
	var table: Dictionary = _make_table()
	assert_eq(CalcScript.assignable_skill_id("a1", table, {}), "")


func test_assignable_skill_id_empty_for_passive_even_if_learned() -> void:
	var table: Dictionary = _make_table()
	assert_eq(CalcScript.assignable_skill_id("a3", table, {"a3": 1}), "")


func test_assignable_skill_id_empty_when_no_focus() -> void:
	assert_eq(CalcScript.assignable_skill_id("", _make_table(), {"a1": 1}), "")
