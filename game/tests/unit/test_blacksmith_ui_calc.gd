## BlacksmithUiCalc(scripts/ui/blacksmith_ui_calc.gd) 테스트 — 대장간 화면(M2-5)의
## 탭별 목록 필터, 홀드 진행도, 확인 필요 여부 판정. 순수 RefCounted라 Node 없이
## 직접 테스트한다(InventoryUiCalc 테스트와 동일 패턴).
extends GutTest

const CalcScript := preload("res://scripts/ui/blacksmith_ui_calc.gd")

const ITEMS_TABLE := {
	"weapon_common_1": {"category": "weapon", "affix_slot_count": 0, "grade": "common"},
	"weapon_rare_1": {"category": "weapon", "affix_slot_count": 2, "grade": "rare"},
	"weapon_epic_1": {"category": "weapon", "affix_slot_count": 3, "grade": "epic"},
	"ring_rare_1": {"category": "ring", "affix_slot_count": 2, "grade": "rare"},
	"enhance_stone": {"category": "material", "affix_slot_count": 0, "grade": "common"},
}

const BLUEPRINTS_TABLE := {
	"_comment": "무시되어야 함",
	"bp_a": {"result_item_id": "weapon_rare_1"},
	"bp_b": {"result_item_id": "weapon_common_1"},
}


# --- is_high_risk_level (경계값 +6/+7, D-90) ---

func test_is_high_risk_level_below_seven_is_false() -> void:
	assert_false(CalcScript.is_high_risk_level(6))


func test_is_high_risk_level_seven_and_above_is_true() -> void:
	assert_true(CalcScript.is_high_risk_level(7))
	assert_true(CalcScript.is_high_risk_level(10))


# --- refine_available (재련 3회 소진 경계값) ---

func test_refine_available_true_while_attempts_remain() -> void:
	assert_true(CalcScript.refine_available(3))
	assert_true(CalcScript.refine_available(1))


func test_refine_available_false_when_exhausted() -> void:
	assert_false(CalcScript.refine_available(0))


# --- afford (골드/재료 부족 케이스) ---

func test_afford_true_when_gold_and_items_sufficient() -> void:
	var ok: bool = CalcScript.afford(100, {"enhance_stone": 3}, 200, {"enhance_stone": 5})
	assert_true(ok)


func test_afford_false_when_gold_insufficient() -> void:
	var ok: bool = CalcScript.afford(500, {}, 100, {})
	assert_false(ok)


func test_afford_false_when_item_insufficient() -> void:
	var ok: bool = CalcScript.afford(0, {"enhance_stone": 5}, 100, {"enhance_stone": 2})
	assert_false(ok)


func test_afford_true_with_zero_cost() -> void:
	assert_true(CalcScript.afford(0, {}, 0, {}))


# --- salvage_has_epic_or_above (분해 등급 혼합 시 영웅 판정, D-100) ---

func test_salvage_has_epic_or_above_false_for_low_grades() -> void:
	var items := [{"grade": "common"}, {"grade": "rare"}]
	assert_false(CalcScript.salvage_has_epic_or_above(items))


func test_salvage_has_epic_or_above_true_when_mixed_with_epic() -> void:
	var items := [{"grade": "common"}, {"grade": "epic"}, {"grade": "rare"}]
	assert_true(CalcScript.salvage_has_epic_or_above(items))


func test_salvage_has_epic_or_above_true_for_legendary_and_relic() -> void:
	assert_true(CalcScript.salvage_has_epic_or_above([{"grade": "legendary"}]))
	assert_true(CalcScript.salvage_has_epic_or_above([{"grade": "relic"}]))


func test_salvage_has_epic_or_above_false_for_empty() -> void:
	assert_false(CalcScript.salvage_has_epic_or_above([]))


# --- filter_enhance_indices ---

func test_filter_enhance_indices_excludes_non_gear() -> void:
	var slots := [
		{"item_id": "weapon_common_1", "grade": "common"},
		{"item_id": "enhance_stone", "grade": "common"},
	]
	assert_eq(CalcScript.filter_enhance_indices(slots, ITEMS_TABLE, ""), [0])


func test_filter_enhance_indices_applies_grade_filter() -> void:
	var slots := [
		{"item_id": "weapon_common_1", "grade": "common"},
		{"item_id": "weapon_rare_1", "grade": "rare"},
	]
	assert_eq(CalcScript.filter_enhance_indices(slots, ITEMS_TABLE, "rare"), [1])


# --- filter_refine_indices (affix_slot_count>0만) ---

func test_filter_refine_indices_excludes_zero_affix_slots() -> void:
	var slots := [
		{"item_id": "weapon_common_1", "grade": "common"},
		{"item_id": "weapon_rare_1", "grade": "rare"},
	]
	assert_eq(CalcScript.filter_refine_indices(slots, ITEMS_TABLE, ""), [1])


# --- filter_salvage_indices (장착/잠금 제외, D-88) ---

func test_filter_salvage_indices_excludes_locked_and_equipped() -> void:
	var slots := [
		{"item_id": "weapon_rare_1", "grade": "rare", "uid": "u1", "locked": false},
		{"item_id": "weapon_epic_1", "grade": "epic", "uid": "u2", "locked": true},
		{"item_id": "ring_rare_1", "grade": "rare", "uid": "u3", "locked": false},
	]
	var result: Array[int] = CalcScript.filter_salvage_indices(slots, ITEMS_TABLE, ["u3"], "")
	assert_eq(result, [0])


func test_filter_salvage_indices_grade_filter() -> void:
	var slots := [
		{"item_id": "weapon_rare_1", "grade": "rare", "uid": "u1", "locked": false},
		{"item_id": "weapon_epic_1", "grade": "epic", "uid": "u2", "locked": false},
	]
	var result: Array[int] = CalcScript.filter_salvage_indices(slots, ITEMS_TABLE, [], "epic")
	assert_eq(result, [1])


# --- filter_craft_indices (결과물 등급 기준, _comment 무시) ---

func test_filter_craft_indices_ignores_comment_key() -> void:
	var ids := BLUEPRINTS_TABLE.keys().filter(func(k): return not String(k).begins_with("_"))
	var result: Array = CalcScript.filter_craft_indices(ids, BLUEPRINTS_TABLE, ITEMS_TABLE, "")
	assert_eq(result.size(), 2)


func test_filter_craft_indices_grade_filter_by_result_item() -> void:
	var ids := ["bp_a", "bp_b"]
	var result: Array = CalcScript.filter_craft_indices(ids, BLUEPRINTS_TABLE, ITEMS_TABLE, "common")
	assert_eq(result, ["bp_b"])


# --- hold_progress ---

func test_hold_progress_zero_at_start() -> void:
	assert_eq(CalcScript.hold_progress(0.0), 0.0)


func test_hold_progress_half_at_half_threshold() -> void:
	assert_almost_eq(CalcScript.hold_progress(0.4, 0.8), 0.5, 0.001)


func test_hold_progress_clamped_at_one() -> void:
	assert_eq(CalcScript.hold_progress(2.0, 0.8), 1.0)


func test_hold_progress_default_threshold_is_point_eight() -> void:
	assert_almost_eq(CalcScript.hold_progress(0.8), 1.0, 0.001)
