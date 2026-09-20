## QuestLogUiCalc(scripts/ui/quest_log_ui_calc.gd) 테스트(M3-2, D-153) — 탭 분류,
## 표시 대상 필터링, 탭/포커스 인덱스 계산, 목표 상태 판정. 순수 RefCounted라 Node
## 없이 직접 테스트한다(test_inventory_ui_calc.gd와 같은 관례).
extends GutTest

const QUEST_DEFS := {
	"quest_main_a1_01_arrival": {"type": "main"},
	"quest_main_a1_02_firstlook": {"type": "main"},
	"quest_side_heartland_montsil": {"type": "side"},
	"quest_daily_board": {"type": "daily_template"},
	"quest_main_a1_08_witch_final": {"type": "main"},
}


# --- build_tab_lists ---

func test_build_tab_lists_only_includes_visible_states() -> void:
	var states := {
		"quest_main_a1_01_arrival": "active",
		"quest_main_a1_02_firstlook": "locked",
		"quest_side_heartland_montsil": "available",
		"quest_daily_board": "completed",
		"quest_main_a1_08_witch_final": "complete_ready",
	}
	var result: Dictionary = QuestLogUiCalc.build_tab_lists(QUEST_DEFS, states)
	assert_eq(result["main"], ["quest_main_a1_01_arrival", "quest_main_a1_08_witch_final"])
	assert_eq(result["side"], [])
	assert_eq(result["daily"], ["quest_daily_board"])


func test_build_tab_lists_unknown_type_is_ignored() -> void:
	var defs := {"weird_quest": {"type": "epilogue"}}
	var states := {"weird_quest": "active"}
	var result: Dictionary = QuestLogUiCalc.build_tab_lists(defs, states)
	assert_eq(result["main"], [])
	assert_eq(result["side"], [])
	assert_eq(result["daily"], [])


func test_build_tab_lists_preserves_definition_order() -> void:
	var defs := {"a": {"type": "side"}, "b": {"type": "side"}, "c": {"type": "side"}}
	var states := {"a": "active", "b": "active", "c": "active"}
	var result: Dictionary = QuestLogUiCalc.build_tab_lists(defs, states)
	assert_eq(result["side"], ["a", "b", "c"])


# --- first_non_empty_tab ---

func test_first_non_empty_tab_prefers_main() -> void:
	var tab_lists := {"main": ["m1"], "side": ["s1"], "daily": []}
	assert_eq(QuestLogUiCalc.first_non_empty_tab(tab_lists), 0)


func test_first_non_empty_tab_skips_empty_main() -> void:
	var tab_lists := {"main": [], "side": ["s1"], "daily": []}
	assert_eq(QuestLogUiCalc.first_non_empty_tab(tab_lists), 1)


func test_first_non_empty_tab_all_empty_returns_zero() -> void:
	var tab_lists := {"main": [], "side": [], "daily": []}
	assert_eq(QuestLogUiCalc.first_non_empty_tab(tab_lists), 0)


# --- wrap_tab_index / clamp_focus_index ---

func test_wrap_tab_index_wraps_forward_and_back() -> void:
	assert_eq(QuestLogUiCalc.wrap_tab_index(2, 1), 0)
	assert_eq(QuestLogUiCalc.wrap_tab_index(0, -1), 2)


func test_clamp_focus_index_empty_list_is_zero() -> void:
	assert_eq(QuestLogUiCalc.clamp_focus_index(5, 0), 0)


func test_clamp_focus_index_clamps_to_last_valid_index() -> void:
	assert_eq(QuestLogUiCalc.clamp_focus_index(9, 3), 2)


func test_clamp_focus_index_within_range_unchanged() -> void:
	assert_eq(QuestLogUiCalc.clamp_focus_index(1, 3), 1)


# --- format_objective_line / objective_status ---

func test_format_objective_line() -> void:
	assert_eq(QuestLogUiCalc.format_objective_line("kill goblin", 2, 4), "kill goblin (2/4)")


func test_objective_status_done_current_pending() -> void:
	assert_eq(QuestLogUiCalc.objective_status(0, 2), "done")
	assert_eq(QuestLogUiCalc.objective_status(2, 2), "current")
	assert_eq(QuestLogUiCalc.objective_status(3, 2), "pending")


# --- reward_rows(M4-2, D-181~183) ---

func test_reward_rows_orders_gold_exp_items() -> void:
	var rewards := {"gold": 10, "exp": 15, "items": [{"id": "wool_soft", "qty": 2}]}
	var rows: Array[Dictionary] = QuestLogUiCalc.reward_rows(rewards)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], {"kind": "gold", "amount": 10})
	assert_eq(rows[1], {"kind": "exp", "amount": 15})
	assert_eq(rows[2], {"kind": "item", "item_id": "wool_soft", "qty": 2})


func test_reward_rows_skips_zero_gold_and_exp() -> void:
	var rewards := {"gold": 0, "exp": 0, "items": []}
	assert_eq(QuestLogUiCalc.reward_rows(rewards), [])


func test_reward_rows_skips_items_with_empty_id() -> void:
	var rewards := {"items": [{"id": "", "qty": 1}]}
	assert_eq(QuestLogUiCalc.reward_rows(rewards), [])


func test_reward_rows_item_qty_defaults_to_one() -> void:
	var rewards := {"items": [{"id": "slime_jelly"}]}
	var rows: Array[Dictionary] = QuestLogUiCalc.reward_rows(rewards)
	assert_eq(rows, [{"kind": "item", "item_id": "slime_jelly", "qty": 1}])
