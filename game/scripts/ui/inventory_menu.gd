## 인벤토리·장비 전체화면 메뉴(F7-2, F3-2, M2-2). 열기/닫기와 `get_tree().paused`
## 자체는 이 스크립트가 아니라 부모 `UiRoot`(ui_root.gd)가 한 곳에서만 결정한다
## (D-24) — 이 스크립트는 "열려 있는 동안 무엇을 보여주고 어떻게 반응할지"만 담당하고,
## `close_requested` 시그널로 "닫아 달라"고 요청만 한다.
##
## 게임패드 우선(docs/ui/wireframes.md §0.1): 포커스는 이 스크립트가 직접 인덱스/슬롯명으로
## 추적한다(Godot Control 포커스 체인을 쓰지 않음 — Tab 키가 이미 `menu` 액션과 겹쳐 있어
## ui_focus_next와 충돌 여지를 없애기 위함). 실제 이동 계산은 InventoryFocusCalc(순수 함수)에
## 위임하고, 필터·비교 델타 계산은 InventoryUiCalc(순수 함수)에 위임한다.
class_name InventoryMenu
extends Control

signal close_requested()

const CELL_SCENE := preload("res://scenes/ui/InventoryCell.tscn")
const EQUIP_CELL_SPACING := 30.0
const GRID_COLS := 8
## D-88(M2-5): Y 홀드로 "즐겨찾기 잠금"을 토글한다(가역 마킹 0.5초 — 대장간 분해 탭의
## 비가역 확정 홀드 0.8초와 의도적으로 다른 시간 상수, docs/ui/blacksmith.md §8 결정1).
## 예전에는 같은 Y 홀드가 소비자가 없던 "분해 표시(marked_discard)" placeholder였다 —
## 실제 분해 UI(BlacksmithMenu 분해 탭)가 생긴 이번 스테이지에서 잠금 토글로 대체했다
## (완료 보고 "설계 대비 변경점" 참고).
const LOCK_HOLD_SEC := 0.5

const TABS: Array[String] = ["inventory", "skill", "codex", "quest"]
const TAB_LABEL_KEYS := {
	"inventory": &"ui.inv.tab.inventory",
	"skill": &"ui.inv.tab.skill",
	"codex": &"ui.inv.tab.codex",
	"quest": &"ui.inv.tab.quest",
}

## 인덱스0 = "전체"(빈 문자열), 1.. = Data.ITEM_GRADES 순서 그대로.
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

const COSTUME_SLOTS := [
	{"name": "hat", "category": "costume_hat"},
	{"name": "outfit", "category": "costume_outfit"},
	{"name": "backpack", "category": "costume_backpack"},
]

@onready var backdrop: Panel = $Backdrop
@onready var tab_bar: HBoxContainer = $TabBar
@onready var gold_label: Label = $GoldLabel
@onready var inventory_tab: Control = $ContentArea/InventoryTab
@onready var placeholder_tab: Control = $ContentArea/PlaceholderTab
@onready var placeholder_label: Label = $ContentArea/PlaceholderTab/PlaceholderLabel
@onready var equip_area: Control = $ContentArea/InventoryTab/LeftPanel/EquipArea
@onready var costume_header: Label = $ContentArea/InventoryTab/LeftPanel/CostumeHeader
@onready var costume_area: Control = $ContentArea/InventoryTab/LeftPanel/CostumeArea
@onready var attack_label: Label = $ContentArea/InventoryTab/LeftPanel/StatsSummary/AttackLabel
@onready var defense_label: Label = $ContentArea/InventoryTab/LeftPanel/StatsSummary/DefenseLabel
@onready var max_hp_label: Label = $ContentArea/InventoryTab/LeftPanel/StatsSummary/MaxHpLabel
@onready var speed_label: Label = $ContentArea/InventoryTab/LeftPanel/StatsSummary/SpeedLabel
@onready var filter_row: HBoxContainer = $ContentArea/InventoryTab/RightPanel/FilterRow
@onready var sort_button: Button = $ContentArea/InventoryTab/RightPanel/FilterRow/SortButton
@onready var grid_scroll: ScrollContainer = $ContentArea/InventoryTab/RightPanel/GridScroll
@onready var grid_container: GridContainer = $ContentArea/InventoryTab/RightPanel/GridScroll/GridContainer
@onready var empty_hint: Label = $ContentArea/InventoryTab/RightPanel/EmptyHint
@onready var compare_tooltip: Panel = $ContentArea/InventoryTab/RightPanel/CompareTooltip
@onready var header_label: Label = $ContentArea/InventoryTab/RightPanel/CompareTooltip/TooltipMargin/TooltipVBox/HeaderLabel
@onready var enhance_label: Label = $ContentArea/InventoryTab/RightPanel/CompareTooltip/TooltipMargin/TooltipVBox/EnhanceLabel
@onready var stat_rows: VBoxContainer = $ContentArea/InventoryTab/RightPanel/CompareTooltip/TooltipMargin/TooltipVBox/StatRows
@onready var affix_note_label: Label = $ContentArea/InventoryTab/RightPanel/CompareTooltip/TooltipMargin/TooltipVBox/AffixNoteLabel
@onready var guide_bar: Label = $GuideBar

var _tab_index: int = 0
var _grade_filter_index: int = 0

## "equip" | "grid" — Godot 포커스 체인 대신 직접 추적(클래스 주석 참고).
var _focus_area: String = "grid"
var _focus_equip_slot: String = "weapon"
var _focus_grid_index: int = 0

var _equip_cells: Dictionary = {} # slot_name -> InventoryCell
var _grid_cells: Array = [] # Array[InventoryCell], 화면에 그려진 순서
var _visible_indices: Array[int] = [] # grid cell 위치 -> GameState.inventory.slots 인덱스

var _tab_buttons: Dictionary = {} # tab_id -> Button
var _filter_buttons: Array = [] # Array[Button], GRADE_FILTERS와 같은 순서

var _lock_hold_time: float = 0.0
var _lock_hold_triggered: bool = false

var _last_input_was_pad: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme_frames()
	_build_tabs()
	_build_filter_chips()
	_build_equip_cells()
	_build_costume_cells()
	costume_header.text = tr(&"ui.inv.costume_header")
	sort_button.text = tr(&"ui.inv.sort_button")
	sort_button.pressed.connect(_on_sort_pressed)
	Events.inventory_changed.connect(_on_inventory_changed)
	Events.gold_changed.connect(_on_gold_changed)
	_update_guide_bar()


## UiRoot가 호출한다(단일 소스: 열림/닫힘·paused는 UiRoot 책임, 여기는 표시 갱신만).
func open_menu() -> void:
	visible = true
	_focus_area = "grid"
	_focus_grid_index = 0
	_apply_tab_visibility()
	_rebuild_grid()
	_refresh_equip_cells()
	_refresh_stats()
	_refresh_gold()
	_refresh_focus_visuals()
	_refresh_tooltip()


func close_menu() -> void:
	visible = false


func is_open() -> bool:
	return visible


# --- 공개 API(스모크/자동화 테스트 등에서 실제 조작과 같은 경로로 재사용) ---

func set_grade_filter(grade: String) -> void:
	var idx: int = GRADE_FILTERS.find(grade)
	_grade_filter_index = maxi(idx, 0)
	_focus_grid_index = 0
	_rebuild_grid()
	_update_filter_chips()


func visible_item_count() -> int:
	return _visible_indices.size()


func focus_grid_at(index: int) -> void:
	_focus_area = "grid"
	_focus_grid_index = clampi(index, 0, maxi(_grid_cells.size() - 1, 0))
	_refresh_focus_visuals()
	_refresh_tooltip()


func confirm() -> void:
	_handle_confirm()


func _apply_theme_frames() -> void:
	backdrop.add_theme_stylebox_override("panel", theme.get_stylebox(&"backdrop", &"Inventory"))
	compare_tooltip.add_theme_stylebox_override("panel", theme.get_stylebox(&"wood_frame", &"HUD"))


# --- 탭 ---

func _build_tabs() -> void:
	for tab_id: String in TABS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
		tab_bar.add_child(button)
		_tab_buttons[tab_id] = button
	_update_tab_labels()


func _on_tab_pressed(tab_id: String) -> void:
	_tab_index = TABS.find(tab_id)
	_apply_tab_visibility()


func _change_tab(delta: int) -> void:
	_tab_index = wrapi(_tab_index + delta, 0, TABS.size())
	_apply_tab_visibility()


func _apply_tab_visibility() -> void:
	var is_inventory: bool = TABS[_tab_index] == "inventory"
	inventory_tab.visible = is_inventory
	placeholder_tab.visible = not is_inventory
	if not is_inventory:
		placeholder_label.text = tr(&"ui.inv.placeholder_tab")
	else:
		_refresh_focus_visuals()
		_refresh_tooltip()
	_update_tab_labels()


func _update_tab_labels() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory")
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory")
	for i in TABS.size():
		var tab_id: String = TABS[i]
		var button: Button = _tab_buttons[tab_id]
		button.text = tr(TAB_LABEL_KEYS[tab_id])
		button.add_theme_color_override("font_color", active_color if i == _tab_index else inactive_color)


# --- 등급 필터 ---

func _build_filter_chips() -> void:
	for grade: String in GRADE_FILTERS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		var idx: int = _filter_buttons.size()
		button.pressed.connect(_on_filter_pressed.bind(idx))
		filter_row.add_child(button)
		filter_row.move_child(button, filter_row.get_child_count() - 2) # SortButton 앞에 삽입
		_filter_buttons.append(button)
	_update_filter_chips()


func _on_filter_pressed(index: int) -> void:
	_grade_filter_index = index
	_focus_grid_index = 0
	_rebuild_grid()
	_update_filter_chips()


func _change_filter(delta: int) -> void:
	_grade_filter_index = wrapi(_grade_filter_index + delta, 0, GRADE_FILTERS.size())
	_focus_grid_index = 0
	_rebuild_grid()
	_update_filter_chips()


func _update_filter_chips() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory")
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory")
	for i in GRADE_FILTERS.size():
		var button: Button = _filter_buttons[i]
		button.text = tr(GRADE_FILTER_KEYS[GRADE_FILTERS[i]])
		button.add_theme_color_override("font_color", active_color if i == _grade_filter_index else inactive_color)


# --- 장비/치장 슬롯(좌패널) ---

func _build_equip_cells() -> void:
	for slot_name: String in Equipment.SLOT_NAMES:
		var cell: InventoryCell = CELL_SCENE.instantiate()
		var pos: Vector2i = InventoryFocusCalc.EQUIP_POSITIONS[slot_name]
		equip_area.add_child(cell)
		cell.position = Vector2(pos.x * EQUIP_CELL_SPACING, pos.y * EQUIP_CELL_SPACING)
		cell.gui_input.connect(_on_equip_cell_gui_input.bind(slot_name))
		_equip_cells[slot_name] = cell


func _build_costume_cells() -> void:
	for i in COSTUME_SLOTS.size():
		var entry: Dictionary = COSTUME_SLOTS[i]
		var cell: InventoryCell = CELL_SCENE.instantiate()
		costume_area.add_child(cell)
		cell.position = Vector2(i * EQUIP_CELL_SPACING, 0)
		cell.set_caption(tr(StringName("ui.inv.slot.%s" % String(entry["category"]))))
		cell.set_disabled(true)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE # 치장은 placeholder(비상호작용, 남은 이슈 참고)


func _refresh_equip_cells() -> void:
	for slot_name: String in Equipment.SLOT_NAMES:
		var cell: InventoryCell = _equip_cells[slot_name]
		var item: Dictionary = GameState.equipment.slots.get(slot_name, {})
		if item.is_empty():
			cell.clear()
			var category: String = Equipment.SLOT_CATEGORY[slot_name]
			cell.set_caption(tr(StringName("ui.inv.slot.%s" % category)))
		else:
			var item_def: Dictionary = Data.get_value("items", String(item.get("item_id", "")), {})
			var grade_enum: Rarity.Grade = Rarity.from_string(String(item.get("grade", item_def.get("grade", "common"))))
			cell.set_item(Rarity.color_of(grade_enum, theme), Rarity.icon_of(grade_enum),
				int(item.get("quantity", 1)), int(item.get("enhance_level", 0)))


func _on_equip_cell_gui_input(event: InputEvent, slot_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focus_area = "equip"
		_focus_equip_slot = slot_name
		_refresh_focus_visuals()
		_refresh_tooltip()
		_handle_confirm()


# --- 스탯 요약 ---

func _refresh_stats() -> void:
	var stats: Dictionary = Equipment.compute_stats(GameState.equipment.slots, Data.table("items"), Data.table("enhance"))
	attack_label.text = "%s %d" % [tr(&"ui.inv.stat.attack"), int(round(float(stats.get("attack", 0.0))))]
	defense_label.text = "%s %d" % [tr(&"ui.inv.stat.defense"), int(round(float(stats.get("defense", 0.0))))]
	max_hp_label.text = "%s +%d" % [tr(&"ui.inv.stat.max_hp"), int(stats.get("max_hp", 0))]
	speed_label.text = "%s %+.0f%%" % [tr(&"ui.inv.stat.speed_pct"), float(stats.get("speed_pct", 0.0)) * 100.0]


func _refresh_gold() -> void:
	gold_label.text = "%s %d" % [tr(&"ui.inv.gold_label"), GameState.gold]


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	if visible:
		_refresh_gold()


# --- 가방 격자(우패널) ---

func _rebuild_grid() -> void:
	for cell: InventoryCell in _grid_cells:
		cell.queue_free()
	_grid_cells.clear()

	var slots: Array = GameState.inventory.slots
	var grade_filter: String = GRADE_FILTERS[_grade_filter_index]
	_visible_indices = InventoryUiCalc.filter_indices(slots, grade_filter)

	var total_cells: int = _visible_indices.size()
	var is_all: bool = grade_filter == ""
	if is_all:
		total_cells = GameState.inventory.capacity()

	for i in total_cells:
		var cell: InventoryCell = CELL_SCENE.instantiate()
		grid_container.add_child(cell)
		if i < _visible_indices.size():
			_paint_cell_with_slot(cell, slots[_visible_indices[i]])
		else:
			cell.clear()
		cell.gui_input.connect(_on_grid_cell_gui_input.bind(i))
		_grid_cells.append(cell)

	if is_all and GameState.inventory.slot_count() == 0:
		empty_hint.visible = true
		empty_hint.text = tr(&"ui.inv.empty_grid")
	elif not is_all and _visible_indices.is_empty():
		empty_hint.visible = true
		empty_hint.text = tr(&"ui.inv.filter_empty")
	else:
		empty_hint.visible = false

	_clamp_grid_focus()
	_refresh_focus_visuals()
	_refresh_tooltip()


func _paint_cell_with_slot(cell: InventoryCell, slot: Dictionary) -> void:
	var item_def: Dictionary = Data.get_value("items", String(slot.get("item_id", "")), {})
	var grade_enum: Rarity.Grade = Rarity.from_string(String(slot.get("grade", item_def.get("grade", "common"))))
	cell.set_item(Rarity.color_of(grade_enum, theme), Rarity.icon_of(grade_enum),
		int(slot.get("quantity", 1)), int(slot.get("enhance_level", 0)))
	cell.set_locked_marked(bool(slot.get("locked", false)))


func _on_grid_cell_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focus_area = "grid"
		_focus_grid_index = index
		_refresh_focus_visuals()
		_refresh_tooltip()
		_handle_confirm()


func _clamp_grid_focus() -> void:
	_focus_grid_index = clampi(_focus_grid_index, 0, maxi(_grid_cells.size() - 1, 0))


func _on_sort_pressed() -> void:
	GameState.inventory.sort_slots(Data.table("items"))
	_focus_grid_index = 0
	Events.inventory_changed.emit()


func _on_inventory_changed() -> void:
	if not visible:
		return
	_rebuild_grid()
	_refresh_equip_cells()
	_refresh_stats()


# --- 포커스 이동(격자 ↔ 장비 슬롯) ---

func _target_slot_for_category(category: String) -> String:
	if category == "ring":
		if not GameState.equipment.is_equipped("ring1"):
			return "ring1"
		if not GameState.equipment.is_equipped("ring2"):
			return "ring2"
		return "ring1" # D-12: 둘 다 찼으면 ring1을 교체(선택 팝업 미구현, 남은 이슈 참고)
	return category


func _move_focus(dir: Vector2i) -> void:
	if _focus_area == "equip":
		if dir == Vector2i(1, 0) and InventoryFocusCalc.is_equip_rightmost(_focus_equip_slot):
			_focus_area = "grid"
			_focus_grid_index = InventoryFocusCalc.grid_enter_index_from_equip()
		else:
			_focus_equip_slot = InventoryFocusCalc.equip_neighbor(_focus_equip_slot, dir)
	else:
		if dir == Vector2i(-1, 0) and InventoryFocusCalc.grid_is_leftmost_col(_focus_grid_index, GRID_COLS):
			_focus_area = "equip"
			_focus_equip_slot = InventoryFocusCalc.equip_enter_slot_from_grid()
		else:
			var total: int = maxi(_grid_cells.size(), 1)
			_focus_grid_index = InventoryFocusCalc.grid_neighbor(_focus_grid_index, GRID_COLS, total, dir)
	_refresh_focus_visuals()
	_refresh_tooltip()
	_ensure_grid_focus_visible()


func _ensure_grid_focus_visible() -> void:
	if _focus_area != "grid" or _focus_grid_index >= _grid_cells.size():
		return
	grid_scroll.ensure_control_visible(_grid_cells[_focus_grid_index])


func _refresh_focus_visuals() -> void:
	for slot_name: String in _equip_cells:
		var cell: InventoryCell = _equip_cells[slot_name]
		cell.set_focused(_focus_area == "equip" and slot_name == _focus_equip_slot)
	for i in _grid_cells.size():
		(_grid_cells[i] as InventoryCell).set_focused(_focus_area == "grid" and i == _focus_grid_index)


# --- 결정(A) : 장착/해제/사용 ---

func _handle_confirm() -> void:
	if TABS[_tab_index] != "inventory":
		return
	if _focus_area == "grid":
		_confirm_grid_item()
	else:
		_confirm_equip_slot()


func _confirm_grid_item() -> void:
	if _focus_grid_index >= _visible_indices.size():
		return
	var slot_index: int = _visible_indices[_focus_grid_index]
	var slot: Dictionary = GameState.inventory.slots[slot_index]
	var item_def: Dictionary = Data.get_value("items", String(slot.get("item_id", "")), {})
	var category: String = String(item_def.get("category", ""))
	if Data.EQUIP_CATEGORIES.has(category):
		GameState.equip_from_slot(slot_index, _target_slot_for_category(category))
	elif category == "consumable":
		GameState.use_item(slot_index)
	# 그 외(재료/치장)는 A로 할 동작이 없음 — 치장 장착은 placeholder(남은 이슈 참고).


func _confirm_equip_slot() -> void:
	if GameState.equipment.is_equipped(_focus_equip_slot):
		GameState.unequip_item(_focus_equip_slot)


# --- 즐겨찾기 잠금 토글(Y 홀드 0.5s, D-88) ---

func _update_lock_hold(delta: float) -> void:
	if TABS[_tab_index] != "inventory" or _focus_area != "grid" or Input.is_action_pressed(&"ui_mark_discard") == false:
		_lock_hold_time = 0.0
		_lock_hold_triggered = false
		return
	_lock_hold_time += delta
	if _lock_hold_time >= LOCK_HOLD_SEC and not _lock_hold_triggered:
		_lock_hold_triggered = true
		_toggle_locked()


func _toggle_locked() -> void:
	if _focus_grid_index >= _visible_indices.size():
		return
	var slot_index: int = _visible_indices[_focus_grid_index]
	var slot: Dictionary = GameState.inventory.slots[slot_index]
	GameState.inventory.set_locked(String(slot.get("uid", "")), not bool(slot.get("locked", false)))
	_rebuild_grid()


# --- 비교 툴팁 ---

func _refresh_tooltip() -> void:
	if TABS[_tab_index] != "inventory" or _focus_area != "grid" or _focus_grid_index >= _visible_indices.size():
		compare_tooltip.visible = false
		return

	var slot_index: int = _visible_indices[_focus_grid_index]
	var slot: Dictionary = GameState.inventory.slots[slot_index]
	var item_def: Dictionary = Data.get_value("items", String(slot.get("item_id", "")), {})
	var category: String = String(item_def.get("category", ""))
	var grade_enum: Rarity.Grade = Rarity.from_string(String(slot.get("grade", item_def.get("grade", "common"))))
	var grade_color: Color = Rarity.color_of(grade_enum, theme)
	var name_key: String = String(item_def.get("name_key", slot.get("item_id", "")))

	header_label.text = "%s %s" % [Rarity.icon_of(grade_enum), tr(StringName(name_key))]
	header_label.add_theme_color_override("font_color", grade_color)

	for child in stat_rows.get_children():
		child.queue_free()

	if not Data.EQUIP_CATEGORIES.has(category):
		enhance_label.visible = false
		affix_note_label.visible = true
		affix_note_label.text = "%s x%d" % [tr(&"ui.inv.qty_prefix"), int(slot.get("quantity", 1))]
		compare_tooltip.visible = true
		return

	var enhance_level: int = int(slot.get("enhance_level", 0))
	var refine_left: int = int(slot.get("refine_left", 0))
	var refine_max: int = int(Data.get_value("enhance", "refine.max_attempts", 3))
	enhance_label.visible = true
	enhance_label.text = "+%d   %s %d/%d" % [enhance_level, tr(&"ui.inv.compare.refine"), refine_left, refine_max]

	var target_slot: String = _target_slot_for_category(category)
	var equipped_item: Dictionary = GameState.equipment.slots.get(target_slot, {})
	var equipped_def: Dictionary = Data.get_value("items", String(equipped_item.get("item_id", "")), {})

	var rows: Array[Dictionary] = InventoryUiCalc.compare_rows(slot, item_def, equipped_item, equipped_def, Data.table("enhance"))
	var colorblind: bool = Settings.colorblind_mode
	for row: Dictionary in rows:
		var stat_key: String = String(row.get("stat_key", ""))
		var delta_fmt: Dictionary = InventoryUiCalc.format_delta(float(row.get("delta", 0.0)), colorblind, 0)
		var color: Color = theme.get_color(StringName(String(delta_fmt.get("color_token", "neutral"))), &"Inventory")
		var value_text: String = "%d" % int(round(float(row.get("candidate_value", 0.0))))
		var suffix: String = ""
		if bool(row.get("is_new", false)) and not is_equal_approx(float(row.get("candidate_value", 0.0)), 0.0):
			suffix = " (%s)" % tr(&"ui.inv.compare.new_affix")
		var label := Label.new()
		label.text = "%s %s (%s)%s" % [tr(StringName("ui.inv.stat.%s" % stat_key)), value_text, String(delta_fmt.get("text", "")), suffix]
		label.add_theme_color_override("font_color", color)
		stat_rows.add_child(label)

	affix_note_label.visible = rows.is_empty()
	if rows.is_empty():
		affix_note_label.text = tr(&"ui.inv.compare.no_affix")

	compare_tooltip.visible = true


# --- 하단 입력 가이드 바 ---

func _update_guide_bar() -> void:
	var pad: bool = _last_input_was_pad
	var confirm_k: String = "A" if pad else "Enter"
	var close_k: String = "B" if pad else "Backspace"
	var tab_k: String = "LB/RB" if pad else "Q/E"
	var filter_k: String = "LT/RT" if pad else "Z/C"
	var sort_k: String = "X" if pad else "Space"
	var mark_k: String = "Y" if pad else "X"
	guide_bar.text = "(%s)%s  (%s)%s  (%s)%s  (%s)%s  (%s)%s  (%s)%s" % [
		confirm_k, tr(&"ui.inv.guide.confirm"),
		sort_k, tr(&"ui.inv.guide.sort"),
		mark_k, tr(&"ui.inv.guide.mark"),
		tab_k, tr(&"ui.inv.guide.tab"),
		filter_k, tr(&"ui.inv.guide.filter"),
		close_k, tr(&"ui.inv.guide.close"),
	]


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
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return

	if Input.is_action_just_pressed(&"ui_close"):
		close_requested.emit()
		return

	if Input.is_action_just_pressed(&"ui_tab_prev"):
		_change_tab(-1)
	elif Input.is_action_just_pressed(&"ui_tab_next"):
		_change_tab(1)

	if TABS[_tab_index] != "inventory":
		return

	if Input.is_action_just_pressed(&"ui_filter_prev"):
		_change_filter(-1)
	elif Input.is_action_just_pressed(&"ui_filter_next"):
		_change_filter(1)

	if Input.is_action_just_pressed(&"ui_sort"):
		_on_sort_pressed()

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

	_update_lock_hold(delta)
