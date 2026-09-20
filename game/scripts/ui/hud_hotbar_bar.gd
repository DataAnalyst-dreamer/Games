## 핫바(9칸) 등록 미리보기 줄(M4-2, D-181~D-183). 스킬 패널/인벤토리 그리드에서
## 포커스 항목이 이미 몇 번에 등록돼 있는지 보여준다 — HUD 하단의 실제 핫바 표시줄
## (hud_skill_slots.gd, stage/m4-1이 9칸으로 확장 중)과는 다른 노드다: 이건 두 등록
## 화면(skill_panel_tab.gd/inventory_menu.gd)에 각각 하나씩 붙는 소형 미리보기다.
##
## GameState.hotbar/Events.hotbar_changed는 stage/m4-1(로직, 미병합) 소유 — get()/
## 신호 존재 여부로 방어한다(skill_panel_tab.gd의 기존 관례와 동일).
class_name HudHotbarBar
extends HBoxContainer

const SLOT_COUNT := 9

var _cells: Array[Label] = []
var _hotbar: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	for i in SLOT_COUNT:
		var cell := Label.new()
		cell.text = str(i + 1)
		cell.custom_minimum_size = Vector2(14, 14)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(cell)
		_cells.append(cell)

	var hotbar_variant: Variant = GameState.get("hotbar")
	_hotbar = hotbar_variant if typeof(hotbar_variant) == TYPE_ARRAY else []
	Events.hotbar_changed.connect(_on_hotbar_changed)
	_redraw(-1)


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
