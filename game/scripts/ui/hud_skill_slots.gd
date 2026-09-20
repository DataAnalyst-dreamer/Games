## HUD 하단 핫바 9칸(스킬·아이템 혼용, M4-1 D-175~D-177) 아이콘·쿨타임·수량 오버레이.
## 옛 스킬 전용 2칸(Q/R)을 GameState.hotbar(9칸, {"kind":"skill"|"item"|"", "id":String})로
## 교체했다 — hud_progress.gd와 동일 분리 원칙(hud.gd 500줄 상한, D-145)으로 Hud.tscn의
## 형제 노드에 그대로 붙인다. 아이콘은 skills.json/items.json 전부 icon:null이라(D-161)
## 계열/이름 첫 글자로 대체한다(pixel-artist TODO). D-177: 소비품 재고 0이어도 슬롯은
## 유지하고 회색(modulate)으로만 표시한다.
class_name HudSkillSlots
extends Node

const SLOT_COUNT := 9
const SLOT_PATHS := [
	"../BottomCenter/HotbarSlot1", "../BottomCenter/HotbarSlot2", "../BottomCenter/HotbarSlot3",
	"../BottomCenter/HotbarSlot4", "../BottomCenter/HotbarSlot5", "../BottomCenter/HotbarSlot6",
	"../BottomCenter/HotbarSlot7", "../BottomCenter/HotbarSlot8", "../BottomCenter/HotbarSlot9",
]
const GREY_OUT := Color(0.5, 0.5, 0.5)

var _panels: Array[Panel] = []
var _icon_labels: Array[Label] = []
var _qty_labels: Array[Label] = []
var _overlays: Array[ColorRect] = []
var _tweens: Array[Tween] = []
var _hotbar: Array = []


func _ready() -> void:
	for path in SLOT_PATHS:
		var panel: Panel = get_node(path)
		_panels.append(panel)

		var icon := Label.new()
		icon.name = "IconLabel"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		panel.move_child(icon, 0) # 키 힌트(1~9) 라벨보다 뒤(아래)에 그려지게.
		_icon_labels.append(icon)

		var overlay := ColorRect.new()
		overlay.name = "CooldownOverlay"
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.anchor_top = 1.0 # 시작은 "쿨타임 없음"(오버레이 높이 0).
		panel.add_child(overlay)
		panel.move_child(overlay, 1)
		_overlays.append(overlay)

		var qty := Label.new()
		qty.name = "QtyLabel"
		qty.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		qty.add_theme_font_size_override("font_size", 8)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(qty)
		_qty_labels.append(qty)

		_tweens.append(null)

	_apply_hotbar(GameState.hotbar if GameState.hotbar.size() == SLOT_COUNT else [])

	Events.hotbar_changed.connect(_apply_hotbar)
	Events.skill_cast.connect(_on_skill_cast)
	Events.skill_ready.connect(_on_skill_ready)
	Events.inventory_changed.connect(_refresh_item_quantities)


func _apply_hotbar(hotbar: Array) -> void:
	_hotbar = hotbar
	for i in SLOT_COUNT:
		var entry: Dictionary = hotbar[i] if i < hotbar.size() else {}
		match String(entry.get("kind", "")):
			"skill":
				var id: String = String(entry.get("id", ""))
				var series: String = String(Data.get_value("skills", "%s.series" % id, ""))
				_icon_labels[i].text = series.left(1).to_upper() if not series.is_empty() else ""
				_qty_labels[i].text = ""
				_panels[i].modulate = Color.WHITE
			"item":
				var id: String = String(entry.get("id", ""))
				_icon_labels[i].text = id.left(1).to_upper() if id != "" else ""
				_update_item_quantity(i, id)
			_:
				_icon_labels[i].text = ""
				_qty_labels[i].text = ""
				_panels[i].modulate = Color.WHITE


## 소비품 사용/획득(Events.inventory_changed)마다 아이템 슬롯 수량만 다시 조회한다
## (스킬 슬롯은 hotbar_changed로만 바뀌므로 여기서 건드릴 필요가 없다).
func _refresh_item_quantities() -> void:
	for i in SLOT_COUNT:
		var entry: Dictionary = _hotbar[i] if i < _hotbar.size() else {}
		if String(entry.get("kind", "")) == "item":
			_update_item_quantity(i, String(entry.get("id", "")))


func _update_item_quantity(i: int, item_id: String) -> void:
	var qty: int = GameState.inventory.count_item(item_id)
	_qty_labels[i].text = str(qty)
	_panels[i].modulate = Color.WHITE if qty > 0 else GREY_OUT


func _on_skill_cast(slot: int, _skill_id: StringName, cooldown_sec: float) -> void:
	if slot < 0 or slot >= _overlays.size() or cooldown_sec <= 0.0:
		return
	_kill_tween(slot)
	var overlay: ColorRect = _overlays[slot]
	overlay.anchor_top = 0.0 # 시전 즉시 전체 덮기.
	var tween := create_tween()
	tween.tween_property(overlay, "anchor_top", 1.0, cooldown_sec).set_trans(Tween.TRANS_LINEAR)
	_tweens[slot] = tween


func _on_skill_ready(slot: int) -> void:
	if slot < 0 or slot >= _overlays.size():
		return
	_kill_tween(slot)
	_overlays[slot].anchor_top = 1.0


func _kill_tween(slot: int) -> void:
	var tween: Tween = _tweens[slot]
	if tween != null and tween.is_valid():
		tween.kill()
	_tweens[slot] = null
