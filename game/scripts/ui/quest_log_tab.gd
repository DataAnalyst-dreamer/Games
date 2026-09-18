## 퀘스트 로그(F5-1/F5-2, M3-2, D-153~D-156). InventoryMenu의 "quest" 탭 실제 구현 —
## `inventory_menu.gd`가 이미 500줄 상한을 넘겨(D-145) 여기 로직을 전부 옮기지 않고,
## 이 파일 하나로 분리했다(hud.gd/hud_progress.gd와 같은 분리 원칙).
##
## 게임패드 우선(docs/ui/wireframes.md §0.1): 좌/우로 메인·사이드·의뢰 탭 전환, 상/하로
## 목록 이동, 확인으로 추적 대상 토글. 마우스 클릭은 이번 범위에서 다루지 않는다(다른
## 화면 placeholder 탭과 동일하게 패드/키보드만 완주 가능하면 충분 — inventory_menu.gd의
## 그리드 포커스도 같은 원칙).
##
## 표시·정렬 계산은 전부 QuestLogUiCalc(순수 함수)에 위임하고, 여기서는 Data/QuestSystem
## 조회 + 노드 갱신만 한다.
class_name QuestLogTab
extends Control

const TABS := QuestLogUiCalc.TABS
const TAB_LABEL_KEYS := {
	"main": &"ui.quest_log.tab.main",
	"side": &"ui.quest_log.tab.side",
	"daily": &"ui.quest_log.tab.daily",
}
const STATE_LABEL_KEYS := {
	"active": &"ui.quest_log.state.active",
	"complete_ready": &"ui.quest_log.state.complete_ready",
	"completed": &"ui.quest_log.state.completed",
}

var _sub_tab_bar: HBoxContainer
var _sub_tab_buttons: Dictionary = {} # tab_id -> Button
var _list_box: VBoxContainer
var _empty_hint: Label
var _detail_title: Label
var _detail_state: Label
var _detail_objectives: VBoxContainer
var _detail_track_hint: Label

var _tab_index: int = 0
var _focus_index: int = 0
var _tab_lists: Dictionary = {"main": [], "side": [], "daily": []}
var _list_labels: Array = [] # Array[Label], 현재 탭에 그려진 항목(포커스 하이라이트용)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	_sub_tab_bar = HBoxContainer.new()
	_sub_tab_bar.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_sub_tab_bar)
	for tab_id: String in TABS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		_sub_tab_bar.add_child(button)
		_sub_tab_buttons[tab_id] = button

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(200, 0)
	body.add_child(list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_box)

	_empty_hint = Label.new()
	_empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_hint.visible = false
	body.add_child(_empty_hint)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_box)
	_detail_title = Label.new()
	detail_box.add_child(_detail_title)
	_detail_state = Label.new()
	detail_box.add_child(_detail_state)
	_detail_objectives = VBoxContainer.new()
	detail_box.add_child(_detail_objectives)
	_detail_track_hint = Label.new()
	_detail_track_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_track_hint)

	_apply_theme_colors()


func _apply_theme_colors() -> void:
	if theme == null:
		return
	for tab_id: String in TABS:
		(_sub_tab_buttons[tab_id] as Button).add_theme_color_override(
			"font_color", theme.get_color(&"tab_inactive", &"Inventory"))


## InventoryMenu._apply_tab_visibility()가 "quest" 탭으로 전환될 때마다 호출한다 —
## 열려 있는 동안 놓친 변화가 있을 수 있어 매번 전체 새로고침한다(가벼운 목록이라
## 캐시 없이도 충분).
func open() -> void:
	if not Events.quest_accepted.is_connected(_on_quest_signal):
		Events.quest_accepted.connect(_on_quest_signal)
		Events.quest_objective_updated.connect(_on_quest_signal)
		Events.quest_completed.connect(_on_quest_signal)
		Events.quest_tracked_changed.connect(_on_quest_signal)
	_rebuild_lists()
	_tab_index = QuestLogUiCalc.first_non_empty_tab(_tab_lists)
	_focus_index = 0
	_refresh_tab_bar()
	_refresh_list()
	_refresh_detail()


func close() -> void:
	if Events.quest_accepted.is_connected(_on_quest_signal):
		Events.quest_accepted.disconnect(_on_quest_signal)
		Events.quest_objective_updated.disconnect(_on_quest_signal)
		Events.quest_completed.disconnect(_on_quest_signal)
		Events.quest_tracked_changed.disconnect(_on_quest_signal)


func _on_quest_signal(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	if not visible:
		return
	_rebuild_lists()
	_focus_index = QuestLogUiCalc.clamp_focus_index(_focus_index, _current_list().size())
	_refresh_list()
	_refresh_detail()


func _rebuild_lists() -> void:
	var quest_defs: Dictionary = Data.table("quests")
	var states: Dictionary = {}
	for quest_id: String in quest_defs.keys():
		states[quest_id] = QuestSystem.get_state(quest_id)
	_tab_lists = QuestLogUiCalc.build_tab_lists(quest_defs, states)


func _current_list() -> Array:
	return _tab_lists.get(TABS[_tab_index], []) as Array


# --- 입력(InventoryMenu._process가 "quest" 탭일 때만 위임 호출) ---

func handle_input(_delta: float) -> void:
	if Input.is_action_just_pressed(&"move_left"):
		_change_sub_tab(-1)
	elif Input.is_action_just_pressed(&"move_right"):
		_change_sub_tab(1)
	elif Input.is_action_just_pressed(&"move_up"):
		_move_focus(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		_move_focus(1)
	elif Input.is_action_just_pressed(&"ui_confirm"):
		_toggle_tracking()


func _change_sub_tab(delta: int) -> void:
	_tab_index = QuestLogUiCalc.wrap_tab_index(_tab_index, delta)
	_focus_index = 0
	_refresh_tab_bar()
	_refresh_list()
	_refresh_detail()


func _move_focus(delta: int) -> void:
	var list_size: int = _current_list().size()
	if list_size <= 0:
		return
	_focus_index = QuestLogUiCalc.clamp_focus_index(wrapi(_focus_index + delta, 0, list_size), list_size)
	_refresh_list()
	_refresh_detail()


func _toggle_tracking() -> void:
	var list: Array = _current_list()
	if _focus_index >= list.size():
		return
	var quest_id: String = String(list[_focus_index])
	if QuestSystem.get_tracked() == quest_id:
		QuestSystem.set_tracked("") # 해제 -> 자동 우선순위로 복귀.
	else:
		QuestSystem.set_tracked(quest_id)
	_refresh_list()
	_refresh_detail()


# --- 표시 갱신 ---

func _refresh_tab_bar() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory") if theme != null else Color.WHITE
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory") if theme != null else Color.GRAY
	for i in TABS.size():
		var button: Button = _sub_tab_buttons[TABS[i]]
		button.text = tr(TAB_LABEL_KEYS[TABS[i]])
		button.add_theme_color_override("font_color", active_color if i == _tab_index else inactive_color)


func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_list_labels.clear()

	var list: Array = _current_list()
	_empty_hint.visible = list.is_empty()
	if list.is_empty():
		_empty_hint.text = tr(&"ui.quest_log.empty")
		return

	var focus_color: Color = theme.get_color(&"focus", &"Inventory") if theme != null else Color.YELLOW
	var default_color: Color = theme.get_color(&"neutral", &"Inventory") if theme != null else Color.WHITE
	var tracked_id: String = QuestSystem.get_tracked()
	for i in list.size():
		var quest_id: String = String(list[i])
		var qdef: Dictionary = Data.get_value("quests", quest_id, {})
		var label := Label.new()
		var title: String = tr(StringName(String(qdef.get("title_key", quest_id))))
		var mark: String = (tr(&"ui.quest_log.tracking_mark") + " ") if quest_id == tracked_id else ""
		label.text = mark + title
		label.add_theme_color_override("font_color", focus_color if i == _focus_index else default_color)
		_list_box.add_child(label)
		_list_labels.append(label)


func _refresh_detail() -> void:
	for child in _detail_objectives.get_children():
		child.queue_free()

	var list: Array = _current_list()
	if list.is_empty() or _focus_index >= list.size():
		_detail_title.text = ""
		_detail_state.text = ""
		_detail_track_hint.text = ""
		return

	var quest_id: String = String(list[_focus_index])
	var qdef: Dictionary = Data.get_value("quests", quest_id, {})
	var state: String = QuestSystem.get_state(quest_id)
	_detail_title.text = tr(StringName(String(qdef.get("title_key", quest_id))))
	_detail_state.text = tr(STATE_LABEL_KEYS.get(state, &"ui.quest_log.state.active"))

	var objectives: Array = qdef.get("objectives", [])
	var progress: Dictionary = QuestSystem.get_objective_progress(quest_id)
	var current_index: int = int(progress.get("objective_index", objectives.size()))
	for idx in objectives.size():
		var obj: Dictionary = objectives[idx]
		var obj_label: String = String(obj.get("id", "obj_%d" % idx))
		var status: String = QuestLogUiCalc.objective_status(idx, current_index)
		var line := Label.new()
		var prefix: String = {"done": "[x] ", "current": "> ", "pending": "[ ] "}.get(status, "")
		if status == "current" and int(progress.get("target", 1)) > 1:
			line.text = prefix + QuestLogUiCalc.format_objective_line(
				obj_label, int(progress.get("current", 0)), int(progress.get("target", 1)))
		else:
			line.text = prefix + obj_label
		_detail_objectives.add_child(line)

	var tracked_id: String = QuestSystem.get_tracked()
	_detail_track_hint.text = tr(&"ui.quest_log.tracking_on") if quest_id == tracked_id \
		else tr(&"ui.quest_log.track_hint")
