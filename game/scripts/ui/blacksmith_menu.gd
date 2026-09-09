## 대장간 전체화면 팝업(F3-3/F3-4, M2-5). 강화/재련/분해/제작 4탭 — 열기/닫기와
## `get_tree().paused`(D-24) 자체는 이 스크립트가 아니라 `UiRoot`(ui_root.gd) 한 곳에서만
## 결정한다(InventoryMenu와 동일 원칙) — 이 스크립트는 "열려 있는 동안 무엇을 보여주고
## 어떻게 반응할지"만 담당하고 `close_requested`로 "닫아 달라"고 요청만 한다.
##
## 게임패드 우선: 포커스는 인덱스로 직접 추적한다(Godot Control 포커스 체인 미사용,
## InventoryMenu와 동일 이유). 좌측 목록 이동은 InventoryFocusCalc.grid_neighbor(cols=1)를
## 재사용하고, 탭별 목록 필터·홀드 진행도·확인 필요 여부는 BlacksmithUiCalc(순수 함수)에
## 위임한다. 실제 강화/재련/분해/제작 실행은 전부 GameState.blacksmith_*()(scripts/systems/
## blacksmith.gd 래퍼)만 호출한다 — 이 스크립트는 수치를 직접 계산/차감하지 않는다.
##
## 입력 모델(docs/ui/blacksmith.md §2/§3): 좌측 목록에서 커서를 움직이면 우측 상세가
## 자동 갱신되고, 강화/제작 탭은 A(ui_confirm)가 곧 "그 항목을 실행"이다(별도 선택
## 단계 없음). 재련 탭만 예외로, 우측에 옵션 줄 하위 목록이 있어 목록→줄로 포커스
## 영역을 오른쪽으로 넘겨야(move_right) A가 그 줄을 굴린다(InventoryMenu의 격자↔장비
## 포커스 전환과 같은 패턴). 분해 탭은 A가 체크 토글, Y 0.8초 홀드가 실제 실행이다.
class_name BlacksmithMenu
extends Control

signal close_requested()

const CELL_SCENE := preload("res://scenes/ui/InventoryCell.tscn")
const ROW_HEIGHT := 28.0

const TABS: Array[StringName] = [&"enhance", &"refine", &"salvage", &"craft"]
const TAB_LABEL_KEYS := {
	&"enhance": &"ui.smith.tab.enhance",
	&"refine": &"ui.smith.tab.refine",
	&"salvage": &"ui.smith.tab.salvage",
	&"craft": &"ui.smith.tab.craft",
}

## 인덱스0 = "전체"(빈 문자열), 1.. = Data.ITEM_GRADES 순서 그대로(InventoryMenu와 동일).
const GRADE_FILTERS: Array[String] = ["", "common", "uncommon", "rare", "epic", "legendary", "relic"]
const GRADE_FILTER_KEYS := {
	"": &"ui.inv.filter.all",
	"common": &"ui.inv.filter.common",
	"uncommon": &"ui.inv.filter.uncommon",
	"rare": &"ui.inv.filter.rare",
	"epic": &"ui.inv.filter.epic",
	"legendary": &"ui.inv.filter.legendary",
	"relic": &"ui.inv.filter.relic",
}

@onready var backdrop: Panel = $Backdrop
@onready var tab_bar: HBoxContainer = $TabBar
@onready var gold_label: Label = $GoldLabel
@onready var filter_row: HBoxContainer = $ContentArea/Body/LeftPanel/FilterRow
@onready var list_scroll: ScrollContainer = $ContentArea/Body/LeftPanel/ListScroll
@onready var list_container: VBoxContainer = $ContentArea/Body/LeftPanel/ListScroll/ListContainer
@onready var empty_hint: Label = $ContentArea/Body/LeftPanel/EmptyHint

@onready var enhance_panel: VBoxContainer = $ContentArea/Body/RightPanel/EnhancePanel
@onready var enhance_name_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/NameLabel
@onready var enhance_level_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/LevelLabel
@onready var enhance_rate_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/RateLabel
@onready var enhance_stat_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/StatLabel
@onready var enhance_cost_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/CostLabel
@onready var enhance_warning_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/WarningLabel
@onready var enhance_action_label: Label = $ContentArea/Body/RightPanel/EnhancePanel/ActionLabel

@onready var refine_panel: VBoxContainer = $ContentArea/Body/RightPanel/RefinePanel
@onready var refine_name_label: Label = $ContentArea/Body/RightPanel/RefinePanel/NameLabel
@onready var refine_remaining_label: Label = $ContentArea/Body/RightPanel/RefinePanel/RemainingLabel
@onready var refine_affix_container: VBoxContainer = $ContentArea/Body/RightPanel/RefinePanel/AffixContainer
@onready var refine_cost_label: Label = $ContentArea/Body/RightPanel/RefinePanel/CostLabel
@onready var refine_action_label: Label = $ContentArea/Body/RightPanel/RefinePanel/ActionLabel

@onready var salvage_panel: VBoxContainer = $ContentArea/Body/RightPanel/SalvagePanel
@onready var salvage_yield_label: Label = $ContentArea/Body/RightPanel/SalvagePanel/YieldHeaderLabel
@onready var salvage_yield_container: VBoxContainer = $ContentArea/Body/RightPanel/SalvagePanel/YieldContainer
@onready var salvage_selected_label: Label = $ContentArea/Body/RightPanel/SalvagePanel/SelectedLabel
@onready var salvage_hold_label: Label = $ContentArea/Body/RightPanel/SalvagePanel/HoldLabel
@onready var salvage_hold_bar: ProgressBar = $ContentArea/Body/RightPanel/SalvagePanel/HoldBar

@onready var craft_panel: VBoxContainer = $ContentArea/Body/RightPanel/CraftPanel
@onready var craft_name_label: Label = $ContentArea/Body/RightPanel/CraftPanel/NameLabel
@onready var craft_grade_note_label: Label = $ContentArea/Body/RightPanel/CraftPanel/GradeNoteLabel
@onready var craft_materials_label: Label = $ContentArea/Body/RightPanel/CraftPanel/MaterialsHeaderLabel
@onready var craft_materials_container: VBoxContainer = $ContentArea/Body/RightPanel/CraftPanel/MaterialsContainer
@onready var craft_cost_label: Label = $ContentArea/Body/RightPanel/CraftPanel/CostLabel
@onready var craft_action_label: Label = $ContentArea/Body/RightPanel/CraftPanel/ActionLabel

@onready var guide_bar: Label = $GuideBar

@onready var refine_compare_popup: Panel = $RefineComparePopup
@onready var refine_compare_title: Label = $RefineComparePopup/Margin/VBox/TitleLabel
@onready var refine_old_panel: Panel = $RefineComparePopup/Margin/VBox/Choices/OldPanel
@onready var refine_old_label: Label = $RefineComparePopup/Margin/VBox/Choices/OldPanel/Label
@onready var refine_new_panel: Panel = $RefineComparePopup/Margin/VBox/Choices/NewPanel
@onready var refine_new_label: Label = $RefineComparePopup/Margin/VBox/Choices/NewPanel/Label
@onready var refine_compare_hint: Label = $RefineComparePopup/Margin/VBox/HintLabel

@onready var salvage_confirm_popup: Panel = $SalvageConfirmPopup
@onready var salvage_confirm_title: Label = $SalvageConfirmPopup/Margin/VBox/TitleLabel
@onready var salvage_confirm_body: Label = $SalvageConfirmPopup/Margin/VBox/BodyLabel
@onready var salvage_confirm_hint: Label = $SalvageConfirmPopup/Margin/VBox/HintLabel

@onready var result_flash: ColorRect = $ResultFlash
@onready var result_toast: Label = $ResultToast

var _tab_index: int = 0
var _grade_filter_index: int = 0
var _tab_buttons: Dictionary = {}
var _filter_buttons: Array = []

var _list_entries: Array = [] ## enhance/refine/salvage = Array[Dictionary](ItemInstance), craft = Array[String](blueprint_id)
var _row_panels: Array = [] ## Array[Panel], list_container 자식과 같은 순서
var _row_cells: Array = [] ## Array[InventoryCell]
var _focus_index: int = 0

## 재련 탭 전용 하위 포커스(목록 ↔ 옵션 줄, InventoryMenu의 격자↔장비 전환과 동일 패턴).
var _refine_focus_on_affix: bool = false
var _refine_affix_focus: int = 0

var _salvage_selected_uids: Array[String] = []
var _hold_time: float = 0.0
var _hold_triggered: bool = false

## "" | "refine_compare" | "salvage_confirm" — 팝업이 열려 있으면 뒤 화면 입력을 막는다.
var _popup_open: String = ""
var _refine_pending_uid: String = ""
var _refine_choice_is_new: bool = true

var _last_input_was_pad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme_frames()
	_build_tabs()
	_build_filter_chips()
	Events.gold_changed.connect(_on_gold_changed)
	Events.inventory_changed.connect(_on_inventory_changed)
	result_flash.visible = false
	result_toast.visible = false
	refine_compare_popup.visible = false
	salvage_confirm_popup.visible = false
	_update_guide_bar()


## UiRoot가 호출한다(단일 소스: 열림/닫힘·paused는 UiRoot 책임, 여기는 표시 갱신만).
func open_menu() -> void:
	visible = true
	_tab_index = 0
	_grade_filter_index = 0
	_focus_index = 0
	_salvage_selected_uids.clear()
	_popup_open = ""
	_apply_tab_visibility()
	_refresh_gold()
	_rebuild_list()


func close_menu() -> void:
	visible = false


func is_open() -> bool:
	return visible


# --- 공개 API(스모크/자동화 테스트 등에서 실제 조작과 같은 경로로 재사용, InventoryMenu와 동일 원칙) ---

func set_tab(tab_id: StringName) -> void:
	var idx: int = TABS.find(tab_id)
	if idx != -1:
		_tab_index = idx
		_apply_tab_visibility()


func current_tab() -> StringName:
	return TABS[_tab_index]


func focus_at(index: int) -> void:
	_focus_index = clampi(index, 0, maxi(_row_panels.size() - 1, 0))
	_refine_focus_on_affix = false
	_refresh_focus_visuals()
	_refresh_detail_panel()


func list_count() -> int:
	return _list_entries.size()


## 현재 포커스된 항목의 식별자 — 강화/재련/분해 탭은 uid, 제작 탭은 blueprint_id.
## 스모크/자동화 테스트가 "지금 뭐가 선택돼 있는지" 검증할 때 쓴다.
func focused_entry_id() -> String:
	if _focus_index >= _list_entries.size():
		return ""
	if TABS[_tab_index] == &"craft":
		return String(_list_entries[_focus_index])
	return String((_list_entries[_focus_index] as Dictionary).get("uid", ""))


func find_entry_index(id: String) -> int:
	for i in _list_entries.size():
		var entry: Variant = _list_entries[i]
		var entry_id: String = String(entry) if TABS[_tab_index] == &"craft" else String((entry as Dictionary).get("uid", ""))
		if entry_id == id:
			return i
	return -1


func confirm() -> void:
	_handle_confirm()


func has_popup_open() -> bool:
	return _popup_open != ""


## 분해 탭 전체선택(X) — 스모크/테스트가 홀드 없이 선택 상태만 만들 때 사용.
func select_all_salvage() -> void:
	_toggle_select_all_salvage()


## 분해 Y 0.8초 홀드가 끝난 시점과 정확히 같은 코드 경로(영웅 확인 팝업 판정 포함) —
## 실제 홀드 타이밍을 기다리지 않고 테스트가 같은 결과를 재현할 때 쓴다.
func trigger_salvage_hold_complete() -> void:
	_on_salvage_hold_complete()


func confirm_salvage_popup() -> void:
	if _popup_open == "salvage_confirm":
		_execute_salvage()


## 재련 탭 포커스를 좌측 목록에서 우측 옵션 줄로 넘긴다(move_right와 동일 경로) —
## 스모크가 실제 입력을 흉내 내지 않고도 같은 판정 함수를 거치게 한다.
func enter_refine_affix_focus(affix_index: int = 0) -> void:
	if _current_affix_count() > 0:
		_refine_focus_on_affix = true
		_refine_affix_focus = clampi(affix_index, 0, _current_affix_count() - 1)
		_refresh_focus_visuals()
		_refresh_detail_panel()


func set_refine_choice_and_confirm(keep_new: bool) -> void:
	if _popup_open == "refine_compare":
		_refine_choice_is_new = keep_new
		_confirm_refine_choice()


func _apply_theme_frames() -> void:
	backdrop.add_theme_stylebox_override("panel", theme.get_stylebox(&"backdrop", &"Inventory"))
	refine_compare_popup.add_theme_stylebox_override("panel", theme.get_stylebox(&"wood_frame", &"HUD"))
	salvage_confirm_popup.add_theme_stylebox_override("panel", theme.get_stylebox(&"wood_frame", &"HUD"))
	refine_old_panel.add_theme_stylebox_override("panel", theme.get_stylebox(&"slot_cell", &"HUD"))
	refine_new_panel.add_theme_stylebox_override("panel", theme.get_stylebox(&"slot_cell", &"HUD"))


# --- 탭(강화/재련/분해/제작) ---

func _build_tabs() -> void:
	for tab_id: StringName in TABS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
		tab_bar.add_child(button)
		_tab_buttons[tab_id] = button
	_update_tab_labels()


func _on_tab_pressed(tab_id: StringName) -> void:
	_tab_index = TABS.find(tab_id)
	_apply_tab_visibility()


func _change_tab(delta: int) -> void:
	_tab_index = wrapi(_tab_index + delta, 0, TABS.size())
	_apply_tab_visibility()


func _apply_tab_visibility() -> void:
	_focus_index = 0
	_refine_focus_on_affix = false
	_salvage_selected_uids.clear()
	_popup_open = ""
	refine_compare_popup.visible = false
	salvage_confirm_popup.visible = false
	enhance_panel.visible = TABS[_tab_index] == &"enhance"
	refine_panel.visible = TABS[_tab_index] == &"refine"
	salvage_panel.visible = TABS[_tab_index] == &"salvage"
	craft_panel.visible = TABS[_tab_index] == &"craft"
	_update_tab_labels()
	_rebuild_list()
	_update_guide_bar()


func _update_tab_labels() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory")
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory")
	for i in TABS.size():
		var button: Button = _tab_buttons[TABS[i]]
		button.text = tr(TAB_LABEL_KEYS[TABS[i]])
		button.add_theme_color_override("font_color", active_color if i == _tab_index else inactive_color)


# --- 등급 필터(InventoryMenu와 동일 컴포넌트) ---

func _build_filter_chips() -> void:
	for grade: String in GRADE_FILTERS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		var idx: int = _filter_buttons.size()
		button.pressed.connect(_on_filter_pressed.bind(idx))
		filter_row.add_child(button)
		_filter_buttons.append(button)
	_update_filter_chips()


func _on_filter_pressed(index: int) -> void:
	_grade_filter_index = index
	_focus_index = 0
	_rebuild_list()
	_update_filter_chips()


func _change_filter(delta: int) -> void:
	_grade_filter_index = wrapi(_grade_filter_index + delta, 0, GRADE_FILTERS.size())
	_focus_index = 0
	_rebuild_list()
	_update_filter_chips()


func _update_filter_chips() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory")
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory")
	for i in GRADE_FILTERS.size():
		var button: Button = _filter_buttons[i]
		button.text = tr(GRADE_FILTER_KEYS[GRADE_FILTERS[i]])
		button.add_theme_color_override("font_color", active_color if i == _grade_filter_index else inactive_color)


# --- 골드 표시 ---

func _refresh_gold() -> void:
	gold_label.text = "%s %d" % [tr(&"ui.smith.gold_label"), GameState.gold]


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	if visible:
		_refresh_gold()
		_refresh_detail_panel()


func _on_inventory_changed() -> void:
	if not visible or _popup_open != "":
		return
	_rebuild_list()


# --- 좌측 목록(탭 공용) ---

## 인벤토리 + 장착 슬롯을 합친 장비 목록(강화/재련 탭은 장착 중인 장비도 벗지 않고
## 다룰 수 있어야 한다 — docs/ui/blacksmith.md §1.1 "[E]" 배지). 분해 탭은 이 함수를
## 쓰지 않고 인벤토리만 본다(장착 중인 장비는 애초에 inventory.slots에 없다).
func _combined_gear() -> Array:
	var out: Array = []
	for slot: Dictionary in GameState.inventory.slots:
		out.append(slot)
	for slot_name: String in Equipment.SLOT_NAMES:
		var item: Dictionary = GameState.equipment.slots.get(slot_name, {})
		if not item.is_empty():
			out.append(item)
	return out


func _is_equipped_uid(uid: String) -> bool:
	for slot_name: String in Equipment.SLOT_NAMES:
		var item: Dictionary = GameState.equipment.slots.get(slot_name, {})
		if not item.is_empty() and String(item.get("uid", "")) == uid:
			return true
	return false


func _material_quantity(item_id: String) -> int:
	var total: int = 0
	for slot: Dictionary in GameState.inventory.slots:
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 1))
	return total


func _rebuild_list() -> void:
	for panel: Panel in _row_panels:
		panel.queue_free()
	_row_panels.clear()
	_row_cells.clear()

	var items_table: Dictionary = Data.table("items")
	var grade_filter: String = GRADE_FILTERS[_grade_filter_index]
	match TABS[_tab_index]:
		&"enhance":
			var gear: Array = _combined_gear()
			var idxs: Array[int] = BlacksmithUiCalc.filter_enhance_indices(gear, items_table, grade_filter)
			_list_entries = idxs.map(func(i: int) -> Dictionary: return gear[i])
		&"refine":
			var gear2: Array = _combined_gear()
			var idxs2: Array[int] = BlacksmithUiCalc.filter_refine_indices(gear2, items_table, grade_filter)
			_list_entries = idxs2.map(func(i: int) -> Dictionary: return gear2[i])
		&"salvage":
			var slots: Array = GameState.inventory.slots
			var idxs3: Array[int] = BlacksmithUiCalc.filter_salvage_indices(slots, items_table, [], grade_filter)
			_list_entries = idxs3.map(func(i: int) -> Dictionary: return slots[i])
		&"craft":
			var bp_table: Dictionary = Data.table("blueprints")
			var ids: Array = bp_table.keys().filter(func(k: Variant) -> bool: return not String(k).begins_with("_"))
			_list_entries = BlacksmithUiCalc.filter_craft_indices(ids, bp_table, items_table, grade_filter)

	for entry: Variant in _list_entries:
		_build_row(entry)

	empty_hint.visible = _list_entries.is_empty()
	if _list_entries.is_empty():
		empty_hint.text = tr(&"ui.smith.salvage.empty" if TABS[_tab_index] == &"salvage" \
			else (&"ui.smith.craft.blueprint_list_empty" if TABS[_tab_index] == &"craft" else &"ui.smith.equip_list.empty"))

	_focus_index = clampi(_focus_index, 0, maxi(_row_panels.size() - 1, 0))
	_refresh_focus_visuals()
	_refresh_detail_panel()


## 행을 만들어 즉시 list_container에 추가한다(반환하지 않고 여기서 직접 add_child) —
## InventoryCell은 @onready 변수를 _ready()에서 채우므로, 트리에 들어가기 전에
## set_item()을 호출하면 그 변수들이 전부 null이라 즉시 실패한다. 그래서 "만들고 →
## 트리에 넣고(→_ready 실행) → 그 다음에 채운다" 순서를 이 함수 하나로 강제한다.
func _build_row(entry: Variant) -> void:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	row.add_child(hbox)

	var cell: InventoryCell = CELL_SCENE.instantiate()
	hbox.add_child(cell)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	list_container.add_child(row) # cell._ready()가 여기서 실행되어 @onready 참조가 채워진다.

	var row_index: int = _row_panels.size()
	if TABS[_tab_index] == &"craft":
		var bp: Dictionary = Data.table("blueprints").get(String(entry), {})
		var result_def: Dictionary = Data.get_value("items", String(bp.get("result_item_id", "")), {})
		var grade_enum: Rarity.Grade = Rarity.from_string(String(result_def.get("grade", "common")))
		var grade_color: Color = Rarity.color_of(grade_enum, theme)
		cell.set_item(grade_color, Rarity.icon_of(grade_enum), 1, 0)
		label.text = "%s %s" % [Rarity.icon_of(grade_enum), tr(StringName(String(bp.get("name_key", entry))))]
		label.add_theme_color_override("font_color", grade_color)
	else:
		var item_inst: Dictionary = entry
		var item_def: Dictionary = Data.get_value("items", String(item_inst.get("item_id", "")), {})
		var grade_enum2: Rarity.Grade = Rarity.from_string(String(item_inst.get("grade", item_def.get("grade", "common"))))
		var grade_color2: Color = Rarity.color_of(grade_enum2, theme)
		cell.set_item(grade_color2, Rarity.icon_of(grade_enum2), int(item_inst.get("quantity", 1)), int(item_inst.get("enhance_level", 0)))
		cell.set_equipped_badge(_is_equipped_uid(String(item_inst.get("uid", ""))))
		var name_text: String = "%s %s +%d" % [
			Rarity.icon_of(grade_enum2), tr(StringName(String(item_def.get("name_key", item_inst.get("item_id", ""))))),
			int(item_inst.get("enhance_level", 0)),
		]
		if TABS[_tab_index] == &"salvage":
			var checked: bool = _salvage_selected_uids.has(String(item_inst.get("uid", "")))
			name_text = "%s %s" % ["[x]" if checked else "[ ]", name_text]
		label.text = name_text
		label.add_theme_color_override("font_color", grade_color2)

	row.gui_input.connect(_on_row_gui_input.bind(row_index))
	_row_panels.append(row)
	_row_cells.append(cell)


func _on_row_gui_input(event: InputEvent, row_index: int) -> void:
	if _popup_open != "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focus_index = row_index
		_refine_focus_on_affix = false
		_refresh_focus_visuals()
		_refresh_detail_panel()
		match TABS[_tab_index]:
			&"enhance":
				_execute_enhance()
			&"salvage":
				_toggle_salvage_checked()
			&"craft":
				_execute_craft()
			# refine 탭은 목록 클릭이 곧 실행이 아니다(옵션 줄 선택이 먼저 필요) — 포커스만 옮긴다.


func _refresh_focus_visuals() -> void:
	var focus_style: StyleBox = theme.get_stylebox(&"focus_highlight", &"Inventory")
	var empty_style := StyleBoxEmpty.new()
	var list_has_focus: bool = not (TABS[_tab_index] == &"refine" and _refine_focus_on_affix)
	for i in _row_panels.size():
		(_row_panels[i] as Panel).add_theme_stylebox_override(
			"panel", focus_style if (list_has_focus and i == _focus_index) else empty_style)
		(_row_cells[i] as InventoryCell).set_focused(list_has_focus and i == _focus_index)
	if _focus_index < _row_panels.size():
		list_scroll.ensure_control_visible(_row_panels[_focus_index])


# --- 포커스 이동 ---

func _current_item() -> Dictionary:
	if TABS[_tab_index] == &"craft" or _focus_index >= _list_entries.size():
		return {}
	return _list_entries[_focus_index]


func _current_affix_count() -> int:
	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		return 0
	return (item_inst.get("affixes", []) as Array).size()


func _move_focus(dir: Vector2i) -> void:
	var is_refine: bool = TABS[_tab_index] == &"refine"
	if is_refine and _refine_focus_on_affix:
		if dir.x < 0:
			_refine_focus_on_affix = false
		elif dir.y != 0:
			var total: int = maxi(_current_affix_count(), 1)
			_refine_affix_focus = InventoryFocusCalc.grid_neighbor(_refine_affix_focus, 1, total, dir)
		_refresh_focus_visuals()
		_refresh_detail_panel()
		return

	if is_refine and dir.x > 0 and _current_affix_count() > 0:
		_refine_focus_on_affix = true
		_refine_affix_focus = 0
		_refresh_focus_visuals()
		_refresh_detail_panel()
		return

	var total_list: int = maxi(_row_panels.size(), 1)
	_focus_index = InventoryFocusCalc.grid_neighbor(_focus_index, 1, total_list, dir)
	_refresh_focus_visuals()
	_refresh_detail_panel()


# --- 상세 패널 갱신(탭별) ---

func _refresh_detail_panel() -> void:
	match TABS[_tab_index]:
		&"enhance": _refresh_enhance_panel()
		&"refine": _refresh_refine_panel()
		&"salvage": _refresh_salvage_panel()
		&"craft": _refresh_craft_panel()


func _stat_line(item_def: Dictionary, level: int, level_next: int) -> String:
	var enhance_table: Dictionary = Data.table("enhance")
	var cur: float = InventoryUiCalc.base_stat_value(item_def, level, enhance_table)
	var nxt: float = InventoryUiCalc.base_stat_value(item_def, level_next, enhance_table)
	var stat_key: String = InventoryUiCalc.base_stat_key(String(item_def.get("category", "")))
	if stat_key == "":
		return ""
	var delta_fmt: Dictionary = InventoryUiCalc.format_delta(nxt - cur, Settings.colorblind_mode, 0)
	return "%s %d → %d (%s)" % [tr(StringName("ui.inv.stat.%s" % stat_key)), int(round(cur)), int(round(nxt)), String(delta_fmt.get("text", ""))]


func _refresh_enhance_panel() -> void:
	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		enhance_name_label.text = tr(&"ui.smith.equip_list.empty")
		enhance_level_label.text = ""
		enhance_rate_label.text = ""
		enhance_stat_label.text = ""
		enhance_cost_label.text = ""
		enhance_action_label.text = ""
		return

	var uid: String = String(item_inst.get("uid", ""))
	var item_def: Dictionary = Data.get_value("items", String(item_inst.get("item_id", "")), {})
	var grade_enum: Rarity.Grade = Rarity.from_string(String(item_inst.get("grade", item_def.get("grade", "common"))))
	enhance_name_label.text = "%s %s" % [Rarity.icon_of(grade_enum), tr(StringName(String(item_def.get("name_key", item_inst.get("item_id", "")))))]
	enhance_name_label.add_theme_color_override("font_color", Rarity.color_of(grade_enum, theme))

	var preview: Dictionary = GameState.get_enhance_preview(uid)
	var level: int = int(item_inst.get("enhance_level", 0))
	var maxed: bool = bool(preview.get("maxed", false))

	if maxed:
		enhance_level_label.text = "+%d (MAX)" % level
		enhance_rate_label.text = ""
		enhance_stat_label.text = ""
		enhance_cost_label.text = ""
		enhance_action_label.text = tr(&"ui.smith.enhance.button_max")
		enhance_action_label.add_theme_color_override("font_color", theme.get_color(&"disabled", &"Inventory"))
		enhance_warning_label.text = tr(&"ui.smith.enhance.warning_no_ceiling")
		enhance_warning_label.add_theme_color_override("font_color", theme.get_color(&"warning", &"Inventory"))
		return

	var level_next: int = int(preview.get("level_next", level + 1))
	enhance_level_label.text = "+%d  →  +%d" % [level, level_next]
	enhance_rate_label.text = "%s %d%%" % [tr(&"ui.smith.enhance.success_rate_label"), int(round(float(preview.get("success_rate", 0.0)) * 100.0))]
	enhance_stat_label.text = _stat_line(item_def, level, level_next)

	var cost_gold: int = int(preview.get("cost_gold", 0))
	var cost_items: Dictionary = preview.get("cost_items", {})
	var have_items: Dictionary = {}
	for item_id: String in cost_items:
		have_items[item_id] = _material_quantity(item_id)
	var afford: bool = BlacksmithUiCalc.afford(cost_gold, cost_items, GameState.gold, have_items)

	var cost_lines: Array[String] = ["%s %d (%s %d)" % [tr(&"ui.smith.gold_label"), cost_gold, tr(&"ui.smith.have_label"), GameState.gold]]
	for item_id2: String in cost_items:
		cost_lines.append("%s x%d (%s %d)" % [tr(&"ui.smith.enhance.stone_unit"), int(cost_items[item_id2]), tr(&"ui.smith.have_label"), int(have_items.get(item_id2, 0))])
	enhance_cost_label.text = "%s\n%s" % [tr(&"ui.smith.enhance.cost_label"), "\n".join(cost_lines)]
	enhance_cost_label.add_theme_color_override("font_color", theme.get_color(&"positive" if afford else &"negative", &"Inventory"))

	enhance_action_label.text = tr(&"ui.smith.enhance.button") if afford else tr(&"ui.smith.enhance.insufficient")
	enhance_action_label.add_theme_color_override("font_color", theme.get_color(&"positive" if afford else &"negative", &"Inventory"))

	enhance_warning_label.text = tr(&"ui.smith.enhance.warning_no_ceiling")
	enhance_warning_label.add_theme_color_override(
		"font_color", theme.get_color(&"warning" if BlacksmithUiCalc.is_high_risk_level(level_next) else &"neutral", &"Inventory"))


func _refresh_refine_panel() -> void:
	for child in refine_affix_container.get_children():
		child.queue_free()

	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		refine_name_label.text = tr(&"ui.smith.equip_list.empty")
		refine_remaining_label.text = ""
		refine_cost_label.text = ""
		refine_action_label.text = ""
		return

	var uid: String = String(item_inst.get("uid", ""))
	var item_def: Dictionary = Data.get_value("items", String(item_inst.get("item_id", "")), {})
	var grade_enum: Rarity.Grade = Rarity.from_string(String(item_inst.get("grade", item_def.get("grade", "common"))))
	refine_name_label.text = "%s %s +%d" % [Rarity.icon_of(grade_enum), tr(StringName(String(item_def.get("name_key", item_inst.get("item_id", ""))))), int(item_inst.get("enhance_level", 0))]
	refine_name_label.add_theme_color_override("font_color", Rarity.color_of(grade_enum, theme))

	var cost: Dictionary = GameState.get_refine_cost(uid)
	var refine_left: int = int(cost.get("attempts_left", 0))
	refine_remaining_label.text = "%s %d/%d" % [tr(&"ui.smith.refine.remaining_label"), refine_left, int(Data.get_value("enhance", "refine.max_attempts", 3))]

	var affixes: Array = item_inst.get("affixes", [])
	if affixes.is_empty():
		var hint := Label.new()
		hint.text = tr(&"ui.smith.refine.no_affix_hint")
		refine_affix_container.add_child(hint)
	for i in affixes.size():
		var affix: Dictionary = affixes[i]
		var line := Label.new()
		var stat_key: String = String(affix.get("stat_type", ""))
		var cursor: String = "> " if (_refine_focus_on_affix and i == _refine_affix_focus) else "  "
		line.text = "%s%s +%.1f" % [cursor, tr(StringName("ui.inv.stat.%s" % stat_key)), float(affix.get("value", 0.0))]
		if _refine_focus_on_affix and i == _refine_affix_focus:
			line.add_theme_color_override("font_color", theme.get_color(&"focus", &"Inventory"))
		refine_affix_container.add_child(line)

	if not BlacksmithUiCalc.refine_available(refine_left):
		refine_cost_label.text = tr(&"ui.smith.refine.locked_hint")
		refine_action_label.text = ""
		return

	var stone_id: String = String(cost.get("cost_material_id", "enhance_stone"))
	var cost_gold: int = int(cost.get("cost_gold", 0))
	var cost_qty: int = int(cost.get("cost_material_qty", 0))
	var have_stone: int = _material_quantity(stone_id)
	var afford: bool = BlacksmithUiCalc.afford(cost_gold, {stone_id: cost_qty}, GameState.gold, {stone_id: have_stone})
	refine_cost_label.text = "%s %d (%s %d)   %s x%d (%s %d)" % [
		tr(&"ui.smith.gold_label"), cost_gold, tr(&"ui.smith.have_label"), GameState.gold,
		tr(&"ui.smith.enhance.stone_unit"), cost_qty, tr(&"ui.smith.have_label"), have_stone,
	]
	refine_cost_label.add_theme_color_override("font_color", theme.get_color(&"positive" if afford else &"negative", &"Inventory"))
	refine_action_label.text = tr(&"ui.smith.refine.button") if afford else tr(&"ui.smith.enhance.insufficient")


func _refresh_salvage_panel() -> void:
	for child in salvage_yield_container.get_children():
		child.queue_free()

	salvage_yield_label.text = tr(&"ui.smith.salvage.yield_preview_label")
	var preview: Dictionary = GameState.get_salvage_preview(_salvage_selected_uids)
	var yields: Dictionary = preview.get("yields", {})
	for item_id: String in yields:
		var qty: int = int(yields[item_id])
		if qty <= 0:
			continue
		var item_def: Dictionary = Data.get_value("items", item_id, {})
		var line := Label.new()
		line.text = "%s x%d" % [tr(StringName(String(item_def.get("name_key", item_id)))), qty]
		salvage_yield_container.add_child(line)

	salvage_selected_label.text = "%s %d" % [tr(&"ui.smith.salvage.selected_count_label"), _salvage_selected_uids.size()]
	salvage_hold_label.text = tr(&"ui.smith.salvage.hold_hint")
	salvage_hold_label.visible = not _salvage_selected_uids.is_empty()
	salvage_hold_bar.visible = not _salvage_selected_uids.is_empty()


func _refresh_craft_panel() -> void:
	for child in craft_materials_container.get_children():
		child.queue_free()

	if _list_entries.is_empty() or _focus_index >= _list_entries.size():
		craft_name_label.text = tr(&"ui.smith.craft.blueprint_list_empty")
		craft_grade_note_label.text = ""
		craft_cost_label.text = ""
		craft_action_label.text = ""
		return

	var blueprint_id: String = String(_list_entries[_focus_index])
	var bp: Dictionary = Data.table("blueprints").get(blueprint_id, {})
	var result_def: Dictionary = Data.get_value("items", String(bp.get("result_item_id", "")), {})
	var grade_enum: Rarity.Grade = Rarity.from_string(String(result_def.get("grade", "common")))
	craft_name_label.text = "%s %s" % [Rarity.icon_of(grade_enum), tr(StringName(String(result_def.get("name_key", bp.get("result_item_id", "")))))]
	craft_name_label.add_theme_color_override("font_color", Rarity.color_of(grade_enum, theme))
	craft_grade_note_label.text = tr(&"ui.smith.craft.grade_note_stable")

	var preview: Dictionary = GameState.get_craft_preview(blueprint_id)
	craft_materials_label.text = tr(&"ui.smith.craft.materials_label")
	for mat: Dictionary in (preview.get("materials", []) as Array):
		var mat_id: String = String(mat.get("id", ""))
		var need: int = int(mat.get("need", 0))
		var have: int = int(mat.get("have", 0))
		var mat_def: Dictionary = Data.get_value("items", mat_id, {})
		var line := Label.new()
		line.text = "%s x%d (%s %d)" % [tr(StringName(String(mat_def.get("name_key", mat_id)))), need, tr(&"ui.smith.have_label"), have]
		line.add_theme_color_override("font_color", theme.get_color(&"positive" if have >= need else &"negative", &"Inventory"))
		craft_materials_container.add_child(line)

	var cost_gold: int = int(preview.get("cost_gold", 0))
	var can_craft: bool = bool(preview.get("can_craft", false))
	craft_cost_label.text = "%s %d (%s %d)" % [tr(&"ui.smith.gold_label"), cost_gold, tr(&"ui.smith.have_label"), GameState.gold]
	craft_cost_label.add_theme_color_override("font_color", theme.get_color(&"positive" if can_craft else &"negative", &"Inventory"))
	craft_action_label.text = tr(&"ui.smith.craft.button") if can_craft else tr(&"ui.smith.enhance.insufficient")


# --- 실행(탭별) ---

func _handle_confirm() -> void:
	if _popup_open == "refine_compare":
		_confirm_refine_choice()
		return
	if _popup_open == "salvage_confirm":
		_execute_salvage()
		return
	match TABS[_tab_index]:
		&"enhance": _execute_enhance()
		&"refine":
			if _refine_focus_on_affix:
				_execute_refine_roll(_refine_affix_focus)
		&"salvage": _toggle_salvage_checked()
		&"craft": _execute_craft()


func _execute_enhance() -> void:
	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		return
	var uid: String = String(item_inst.get("uid", ""))
	var preview: Dictionary = GameState.get_enhance_preview(uid)
	if bool(preview.get("maxed", false)):
		return
	var cost_items: Dictionary = preview.get("cost_items", {})
	var have_items: Dictionary = {}
	for item_id: String in cost_items:
		have_items[item_id] = _material_quantity(item_id)
	if not BlacksmithUiCalc.afford(int(preview.get("cost_gold", 0)), cost_items, GameState.gold, have_items):
		return

	var result: Dictionary = GameState.blacksmith_enhance(uid)
	if not result.get("ok", false):
		return
	var success: bool = bool(result.get("success", false))
	_play_result_effect(success)
	if success:
		_show_toast(tr(&"ui.smith.enhance.result_success_title"), true)
		AudioManager.play_sfx(&"blacksmith_enhance_success") # _todo: 강화 성공 전용 SFX 미제작(audio_sfx.json 참고).
	else:
		_show_toast("%s %s" % [tr(&"ui.smith.enhance.result_fail_title"), tr(&"ui.smith.enhance.result_fail_body")], false)
		AudioManager.play_sfx(&"blacksmith_enhance_fail") # _todo: 강화 실패 전용 SFX 미제작.
	_rebuild_list()


func _execute_refine_roll(affix_index: int) -> void:
	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		return
	var uid: String = String(item_inst.get("uid", ""))
	var cost: Dictionary = GameState.get_refine_cost(uid)
	if not bool(cost.get("refinable", false)):
		return
	var stone_id: String = String(cost.get("cost_material_id", "enhance_stone"))
	var have_stone: int = _material_quantity(stone_id)
	if not BlacksmithUiCalc.afford(int(cost.get("cost_gold", 0)), {stone_id: int(cost.get("cost_material_qty", 0))}, GameState.gold, {stone_id: have_stone}):
		return

	var result: Dictionary = GameState.blacksmith_refine(uid, affix_index)
	if not result.get("ok", false):
		return
	_refine_pending_uid = uid
	_refine_choice_is_new = true
	_open_refine_compare_popup(result)
	AudioManager.play_sfx(&"blacksmith_refine_roll") # _todo: 재련 굴림 전용 SFX 미제작.


func _open_refine_compare_popup(result: Dictionary) -> void:
	_popup_open = "refine_compare"
	refine_compare_popup.visible = true
	refine_compare_title.text = tr(&"ui.smith.refine.choice_title")
	var old_affix: Dictionary = result.get("old_affix", {})
	var new_affix: Dictionary = result.get("new_affix", {})
	refine_old_label.text = "%s\n%s +%.1f" % [tr(&"ui.smith.refine.choice_old"), tr(StringName("ui.inv.stat.%s" % String(old_affix.get("stat_type", "")))), float(old_affix.get("value", 0.0))]
	refine_new_label.text = "%s\n%s +%.1f" % [tr(&"ui.smith.refine.choice_new"), tr(StringName("ui.inv.stat.%s" % String(new_affix.get("stat_type", "")))), float(new_affix.get("value", 0.0))]
	_refresh_refine_choice_highlight()
	refine_compare_hint.text = tr(&"ui.smith.refine.confirm_button")


func _refresh_refine_choice_highlight() -> void:
	var focus_style: StyleBox = theme.get_stylebox(&"focus_highlight", &"Inventory")
	var cell_style: StyleBox = theme.get_stylebox(&"slot_cell", &"HUD")
	refine_new_panel.add_theme_stylebox_override("panel", focus_style if _refine_choice_is_new else cell_style)
	refine_old_panel.add_theme_stylebox_override("panel", cell_style if _refine_choice_is_new else focus_style)


func _confirm_refine_choice() -> void:
	var result: Dictionary = GameState.blacksmith_refine_commit(_refine_pending_uid, _refine_choice_is_new)
	_popup_open = ""
	refine_compare_popup.visible = false
	_refine_pending_uid = ""
	_refine_focus_on_affix = false
	if result.get("ok", false):
		_play_result_effect(true)
	_rebuild_list()


func _toggle_salvage_checked() -> void:
	var item_inst: Dictionary = _current_item()
	if item_inst.is_empty():
		return
	var uid: String = String(item_inst.get("uid", ""))
	if _salvage_selected_uids.has(uid):
		_salvage_selected_uids.erase(uid)
	else:
		_salvage_selected_uids.append(uid)
	_rebuild_list()


func _toggle_select_all_salvage() -> void:
	var visible_uids: Array[String] = []
	for entry: Dictionary in _list_entries:
		visible_uids.append(String(entry.get("uid", "")))
	var all_selected: bool = not visible_uids.is_empty() and visible_uids.all(func(u: String) -> bool: return _salvage_selected_uids.has(u))
	if all_selected:
		for u: String in visible_uids:
			_salvage_selected_uids.erase(u)
	else:
		for u2: String in visible_uids:
			if not _salvage_selected_uids.has(u2):
				_salvage_selected_uids.append(u2)
	_rebuild_list()


func _update_salvage_hold(delta: float) -> void:
	var can_hold: bool = TABS[_tab_index] == &"salvage" and _popup_open == "" and not _salvage_selected_uids.is_empty()
	if not can_hold or not Input.is_action_pressed(&"ui_mark_discard"):
		_hold_time = 0.0
		_hold_triggered = false
		salvage_hold_bar.value = 0.0
		return
	_hold_time += delta
	salvage_hold_bar.value = BlacksmithUiCalc.hold_progress(_hold_time) * 100.0
	if _hold_time >= BlacksmithUiCalc.SALVAGE_HOLD_SEC and not _hold_triggered:
		_hold_triggered = true
		_on_salvage_hold_complete()


func _on_salvage_hold_complete() -> void:
	var selected_items: Array = []
	for uid: String in _salvage_selected_uids:
		var idx: int = GameState.inventory.find_by_uid(uid)
		if idx != -1:
			selected_items.append(GameState.inventory.slots[idx])
	if BlacksmithUiCalc.salvage_has_epic_or_above(selected_items):
		_popup_open = "salvage_confirm"
		salvage_confirm_popup.visible = true
		salvage_confirm_title.text = tr(&"ui.smith.salvage.confirm_epic_title")
		salvage_confirm_body.text = tr(&"ui.smith.salvage.confirm_epic_body")
		salvage_confirm_hint.text = "(A) %s   (B) %s" % [tr(&"ui.smith.salvage.button"), tr(&"ui.inv.guide.close")]
	else:
		_execute_salvage()


func _execute_salvage() -> void:
	var uids: Array = _salvage_selected_uids.duplicate()
	var result: Dictionary = GameState.blacksmith_salvage(uids)
	_popup_open = ""
	salvage_confirm_popup.visible = false
	_salvage_selected_uids.clear()
	var ok: bool = bool(result.get("ok", false))
	_play_result_effect(ok)
	_show_toast(tr(&"ui.smith.salvage.result_title"), ok)
	AudioManager.play_sfx(&"blacksmith_salvage_complete") # _todo: 분해 완료 전용 SFX 미제작.
	_rebuild_list()


func _cancel_salvage_confirm() -> void:
	_popup_open = ""
	salvage_confirm_popup.visible = false
	_hold_time = 0.0
	_hold_triggered = false


func _execute_craft() -> void:
	if _list_entries.is_empty() or _focus_index >= _list_entries.size():
		return
	var blueprint_id: String = String(_list_entries[_focus_index])
	var preview: Dictionary = GameState.get_craft_preview(blueprint_id)
	if not bool(preview.get("can_craft", false)):
		return
	var result: Dictionary = GameState.blacksmith_craft(blueprint_id)
	var ok: bool = bool(result.get("ok", false))
	_play_result_effect(ok)
	if ok:
		_show_toast(tr(&"ui.smith.craft.result_title"), true)
	AudioManager.play_sfx(&"blacksmith_craft_complete") # _todo: 제작 완료 전용 SFX 미제작.
	_rebuild_list()


# --- 결과 연출(Settings.effect_flash_enabled, M2-5 신설) ---

func _play_result_effect(success: bool) -> void:
	if not Settings.effect_flash_enabled:
		return
	result_flash.color = Color(0.415686, 0.760784, 0.415686, 0.35) if success else Color(0.847059, 0.294118, 0.294118, 0.35)
	result_flash.modulate.a = 1.0
	result_flash.visible = true
	var tween := create_tween()
	tween.tween_property(result_flash, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void: result_flash.visible = false)


## 결과 텍스트+색은 effect_flash_enabled와 무관하게 항상 보인다(광과민성 대응 —
## "화면 전체 플래시"만 끄고 텍스트 채널은 남긴다, docs/ui/blacksmith.md §4).
func _show_toast(text: String, positive: bool) -> void:
	result_toast.text = text
	result_toast.add_theme_color_override("font_color", theme.get_color(&"positive" if positive else &"negative", &"Inventory"))
	result_toast.modulate.a = 1.0
	result_toast.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void: result_toast.visible = false)


# --- 하단 입력 가이드 바 ---

func _update_guide_bar() -> void:
	var pad: bool = _last_input_was_pad
	var confirm_k: String = "A" if pad else "Enter"
	var close_k: String = "B" if pad else "Backspace"
	var tab_k: String = "LB/RB" if pad else "Q/E"
	var filter_k: String = "LT/RT" if pad else "Z/C"
	var select_all_k: String = "X" if pad else "Space"
	var hold_k: String = "Y" if pad else "X"
	var confirm_label: String = tr(&"ui.smith.guide.execute")
	if TABS[_tab_index] == &"salvage":
		confirm_label = tr(&"ui.smith.guide.toggle_select")
	guide_bar.text = "(%s)%s  (%s)%s  (%s)%s  (%s)%s" % [confirm_k, confirm_label, tab_k, tr(&"ui.inv.guide.tab"), filter_k, tr(&"ui.inv.guide.filter"), close_k, tr(&"ui.inv.guide.close")]
	if TABS[_tab_index] == &"salvage":
		guide_bar.text += "  (%s)%s  (%s)%s" % [select_all_k, tr(&"ui.smith.guide.select_all"), hold_k, tr(&"ui.smith.guide.hold_salvage")]


func _note_pad_input(is_pad: bool) -> void:
	if _last_input_was_pad != is_pad:
		_last_input_was_pad = is_pad
		_update_guide_bar()


# --- 입력 폴링 ---

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
		_on_close_input()
		get_viewport().set_input_as_handled()


## D-91: 전체화면 UI 위에서 pause는 닫기로 처리한다. 팝업이 열려 있으면 팝업만 취소하고
## 대장간 화면 자체는 유지한다(전체 종료는 팝업이 없을 때만).
func _on_close_input() -> void:
	if _popup_open == "salvage_confirm":
		_cancel_salvage_confirm()
		return
	if _popup_open == "refine_compare":
		return # 재련 확정은 취소 불가(비용 이미 지불) — A로만 진행.
	close_requested.emit()


func _process(delta: float) -> void:
	if not visible:
		return

	if Input.is_action_just_pressed(&"ui_close") or Input.is_action_just_pressed(&"pause"):
		_on_close_input()
		return

	if _popup_open == "refine_compare":
		if Input.is_action_just_pressed(&"move_left") or Input.is_action_just_pressed(&"move_right") \
				or Input.is_action_just_pressed(&"ui_compare_lock"):
			_refine_choice_is_new = not _refine_choice_is_new
			_refresh_refine_choice_highlight()
		if Input.is_action_just_pressed(&"ui_confirm"):
			_confirm_refine_choice()
		return

	if _popup_open == "salvage_confirm":
		if Input.is_action_just_pressed(&"ui_confirm"):
			_execute_salvage()
		return

	if Input.is_action_just_pressed(&"ui_tab_prev"):
		_change_tab(-1)
	elif Input.is_action_just_pressed(&"ui_tab_next"):
		_change_tab(1)

	if Input.is_action_just_pressed(&"ui_filter_prev"):
		_change_filter(-1)
	elif Input.is_action_just_pressed(&"ui_filter_next"):
		_change_filter(1)

	if TABS[_tab_index] == &"salvage" and Input.is_action_just_pressed(&"ui_sort"):
		_toggle_select_all_salvage()

	var dir := Vector2i.ZERO
	if Input.is_action_just_pressed(&"move_up"):
		dir = Vector2i(0, -1)
	elif Input.is_action_just_pressed(&"move_down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_just_pressed(&"move_left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_just_pressed(&"move_right"):
		dir = Vector2i(1, 0)
	if dir != Vector2i.ZERO:
		_move_focus(dir)

	if Input.is_action_just_pressed(&"ui_confirm"):
		_handle_confirm()

	if TABS[_tab_index] == &"salvage":
		_update_salvage_hold(delta)
	else:
		_hold_time = 0.0
		_hold_triggered = false
