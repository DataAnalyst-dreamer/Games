## 우편함 팝업(F3-1 D-10, M2-5). 탭이 없는 단일 리스트 팝업 — 대사 없는 필드 오브젝트
## 상호작용으로 연다(docs/ui/blacksmith.md §1.5, D-87 "대사 없는 오브젝트"). 열림/닫힘과
## `get_tree().paused`는 UiRoot가 결정하고(D-24와 동일 원칙을 이 화면에도 적용), 이
## 스크립트는 목록 표시·개별/전체 수령만 담당한다. 실제 수령은 GameState.claim_mail()/
## claim_all_mail()(scripts/systems/mailbox.gd 래퍼)만 호출한다.
class_name MailboxPopup
extends Control

signal close_requested()

@onready var backdrop: Panel = $Backdrop
@onready var title_label: Label = $TitleLabel
@onready var list_scroll: ScrollContainer = $ListScroll
@onready var list_container: VBoxContainer = $ListScroll/ListContainer
@onready var empty_hint: Label = $EmptyHint
@onready var hint_label: Label = $HintLabel
@onready var guide_bar: Label = $GuideBar
@onready var result_toast: Label = $ResultToast

var _row_labels: Array = [] ## Array[Label], list_container 자식과 같은 순서
var _mail_ids: Array = [] ## Array[String], _row_labels와 같은 순서(GameState.mailbox.mails 스냅샷)
var _focus_index: int = 0
var _last_input_was_pad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.add_theme_stylebox_override("panel", theme.get_stylebox(&"backdrop", &"Inventory"))
	title_label.text = tr(&"ui.mail.title")
	hint_label.text = tr(&"ui.mail.no_time_limit_hint")
	result_toast.visible = false
	Events.mail_claimed.connect(_on_mail_claimed)
	_update_guide_bar()


## UiRoot가 호출한다(단일 소스: 열림/닫힘·paused는 UiRoot 책임, 여기는 표시 갱신만).
func open_popup() -> void:
	visible = true
	_focus_index = 0
	_rebuild_list()


func close_popup() -> void:
	visible = false


func is_open() -> bool:
	return visible


# --- 공개 API(스모크/자동화 테스트 등에서 실제 조작과 같은 경로로 재사용) ---

func mail_count() -> int:
	return _mail_ids.size()


func focus_at(index: int) -> void:
	_focus_index = clampi(index, 0, maxi(_row_labels.size() - 1, 0))
	_refresh_focus_visuals()


func claim_focused() -> void:
	_claim_focused()


func claim_all() -> void:
	_claim_all()


func _rebuild_list() -> void:
	for label: Label in _row_labels:
		label.queue_free()
	_row_labels.clear()
	_mail_ids.clear()

	for mail: Dictionary in GameState.mailbox.mails:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.text = _mail_line_text(mail)
		var row_index: int = _row_labels.size()
		label.gui_input.connect(_on_row_gui_input.bind(row_index))
		list_container.add_child(label)
		_row_labels.append(label)
		_mail_ids.append(String(mail.get("id", "")))

	empty_hint.visible = _mail_ids.is_empty()
	empty_hint.text = tr(&"ui.mail.empty")
	_focus_index = clampi(_focus_index, 0, maxi(_row_labels.size() - 1, 0))
	_refresh_focus_visuals()


func _mail_line_text(mail: Dictionary) -> String:
	if mail.has("gold"):
		return "%s %d G   [ (A) %s ]" % [tr(&"ui.smith.gold_label"), int(mail.get("gold", 0)), tr(&"ui.mail.claim_one")]
	var item_id: String = String(mail.get("item_id", ""))
	var item_def: Dictionary = Data.get_value("items", item_id, {})
	var grade_enum: Rarity.Grade = Rarity.from_string(String(mail.get("grade", item_def.get("grade", "common"))))
	var count: int = int(mail.get("count", mail.get("quantity", 1)))
	return "%s %s x%d   [ (A) %s ]" % [
		Rarity.icon_of(grade_enum), tr(StringName(String(item_def.get("name_key", item_id)))), count, tr(&"ui.mail.claim_one"),
	]


func _refresh_focus_visuals() -> void:
	var focus_color: Color = theme.get_color(&"focus", &"Inventory")
	var default_color: Color = theme.get_color(&"text_default", &"HUD") if theme.has_color(&"text_default", &"HUD") else Color(1, 1, 1, 1)
	for i in _row_labels.size():
		(_row_labels[i] as Label).add_theme_color_override("font_color", focus_color if i == _focus_index else default_color)
	if _focus_index < _row_labels.size():
		list_scroll.ensure_control_visible(_row_labels[_focus_index])


func _on_row_gui_input(event: InputEvent, row_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focus_index = row_index
		_refresh_focus_visuals()
		_claim_focused()


func _claim_focused() -> void:
	if _focus_index >= _mail_ids.size():
		return
	var mail_id: String = _mail_ids[_focus_index]
	var result: Dictionary = GameState.claim_mail(mail_id)
	if result.get("ok", false):
		_show_toast(tr(&"ui.mail.claimed_toast"), true)
		AudioManager.play_sfx(&"mailbox_claim_chime")
	else:
		_show_toast(tr(&"ui.mail.claim_failed_full"), false)


func _claim_all() -> void:
	if _mail_ids.is_empty():
		return
	var result: Dictionary = GameState.claim_all_mail()
	var claimed: int = (result.get("claimed", []) as Array).size()
	var failed: int = (result.get("failed", []) as Array).size()
	if failed > 0:
		_show_toast(tr(&"ui.mail.inventory_full_partial_result") % [claimed, failed], claimed > 0)
	else:
		_show_toast(tr(&"ui.mail.claimed_toast"), true)
	if claimed > 0:
		AudioManager.play_sfx(&"mailbox_claim_chime")


func _on_mail_claimed(_mail_id: String, _result: Dictionary) -> void:
	if visible:
		_rebuild_list()


func _show_toast(text: String, positive: bool) -> void:
	result_toast.text = text
	result_toast.add_theme_color_override("font_color", theme.get_color(&"positive" if positive else &"negative", &"Inventory"))
	result_toast.modulate.a = 1.0
	result_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: result_toast.visible = false)


func _update_guide_bar() -> void:
	var pad: bool = _last_input_was_pad
	var confirm_k: String = "A" if pad else "Enter"
	var select_all_k: String = "X" if pad else "Space"
	var close_k: String = "B" if pad else "Backspace"
	guide_bar.text = "(%s)%s  (%s)%s  (%s)%s" % [
		confirm_k, tr(&"ui.mail.claim_one"), select_all_k, tr(&"ui.mail.claim_all"), close_k, tr(&"ui.inv.guide.close"),
	]


func _note_pad_input(is_pad: bool) -> void:
	if _last_input_was_pad != is_pad:
		_last_input_was_pad = is_pad
		_update_guide_bar()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventJoypadButton:
		_note_pad_input(true)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_note_pad_input(true)
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		_note_pad_input(false)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return

	## D-91: 전체화면 UI 위에서 pause는 닫기로 처리한다.
	if Input.is_action_just_pressed(&"ui_close") or Input.is_action_just_pressed(&"pause"):
		close_requested.emit()
		return

	if Input.is_action_just_pressed(&"ui_sort"):
		_claim_all()

	var dir := Vector2i.ZERO
	if Input.is_action_just_pressed(&"move_up"):
		dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed(&"move_down"):
		dir = Vector2i(0, 1)
	if dir != Vector2i.ZERO:
		var total: int = maxi(_row_labels.size(), 1)
		_focus_index = InventoryFocusCalc.grid_neighbor(_focus_index, 1, total, dir)
		_refresh_focus_visuals()

	if Input.is_action_just_pressed(&"ui_confirm"):
		_claim_focused()
