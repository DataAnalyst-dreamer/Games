## 핫바(9칸) 등록 미리보기 줄(M4-2, D-181~D-183). 스킬 패널/인벤토리 그리드에서
## 포커스 항목이 이미 몇 번에 등록돼 있는지 보여준다 — HUD 하단의 실제 핫바 표시줄
## (hud_skill_slots.gd, stage/m4-1이 9칸으로 확장 중)과는 다른 노드다: 이건 두 등록
## 화면(skill_panel_tab.gd/inventory_menu.gd)에 각각 하나씩 붙는 소형 미리보기다.
##
## GameState.hotbar/Events.hotbar_changed는 stage/m4-1(로직, 미병합) 소유 — get()/
## 신호 존재 여부로 방어한다(skill_panel_tab.gd의 기존 관례와 동일).
##
## M5-1(마우스): 칸을 Label 대신 Button(flat)으로 그려 클릭을 받는다 — `pressed`만
## 연결하면 되어 gui_input 좌표 파싱보다 코드가 덜 든다(작업 지시 원칙). 클릭하면
## `slot_clicked(i)`만 emit하고, "무엇을 등록할지"는 이 컴포넌트를 붙인 화면
## (inventory_menu.gd/skill_tree_tab.gd)이 자신의 포커스 상태로 판단한다 — 이 컴포넌트는
## 핫바 배열 표시만 책임진다는 기존 원칙을 그대로 유지.
class_name HudHotbarBar
extends HBoxContainer

signal slot_clicked(slot: int)

const SLOT_COUNT := 9

var _cells: Array[Button] = []
var _hotbar: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	for i in SLOT_COUNT:
		var cell := Button.new()
		cell.text = str(i + 1)
		cell.flat = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(14, 14)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		add_child(cell)
		_cells.append(cell)

	var hotbar_variant: Variant = GameState.get("hotbar")
	_hotbar = hotbar_variant if typeof(hotbar_variant) == TYPE_ARRAY else []
	Events.hotbar_changed.connect(_on_hotbar_changed)
	_redraw(-1)


func _on_cell_pressed(slot: int) -> void:
	slot_clicked.emit(slot)


func _on_hotbar_changed(hotbar: Array) -> void:
	_hotbar = hotbar
	_redraw(-1)


## kind+id가 등록된 칸을 강조(focus 색), 나머지는 채워짐/빈칸 구분만.
func highlight_slot(kind: String, id: String) -> void:
	_redraw(HotbarRegisterInput.find_registered_slot(_hotbar, kind, id))


func _redraw(focused_slot: int) -> void:
	var focus_color: Color = theme.get_color(&"focus", &"Inventory") if theme != null else Color.YELLOW
	var default_color: Color = theme.get_color(&"neutral", &"Inventory") if theme != null else Color.WHITE
	var empty_color: Color = theme.get_color(&"disabled", &"Inventory") if theme != null else Color.GRAY
	for i in _cells.size():
		var occupied: bool = i < _hotbar.size() and typeof(_hotbar[i]) == TYPE_DICTIONARY \
			and not String((_hotbar[i] as Dictionary).get("id", "")).is_empty()
		var color := focus_color if i == focused_slot else (default_color if occupied else empty_color)
		_cells[i].add_theme_color_override("font_color", color)
