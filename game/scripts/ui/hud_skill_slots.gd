## HUD 하단 스킬 슬롯 2개(Q/R) 아이콘·쿨타임 오버레이(M3-4, F1-3). `hud_progress.gd`와
## 동일 분리 원칙 — hud.gd가 이미 466/500줄(D-145 상한)이라 hud.gd를 전혀 건드리지 않고
## Hud.tscn의 형제 노드로 새 스크립트를 붙였다(NodePath는 하드코딩, hud_progress.gd
## 클래스 주석의 "여러 겹 인스턴싱 시 @export NodePath가 깨진 사례" 이유 그대로 재사용).
##
## `Events.skills_changed/skill_cast/skill_ready`는 stage/m3-3(로직) 병합 전이라 UI가
## 먼저 선언했다(exp_changed/level_up 선례, D-165 방침과 동일 — 병합 후 디렉터가 정리).
## 아이콘은 skills.json 전부 icon:null이라(D-161) 계열 첫 글자(B/G/T)로 대체한다.
class_name HudSkillSlots
extends Node

const SLOT_PATHS := ["../BottomCenter/SkillSlot1", "../BottomCenter/SkillSlot2"]

var _icon_labels: Array[Label] = []
var _overlays: Array[ColorRect] = []
var _tweens: Array[Tween] = [null, null]
var _slots: Array = ["", ""]


func _ready() -> void:
	for path in SLOT_PATHS:
		var panel: Panel = get_node(path)
		var icon := Label.new()
		icon.name = "IconLabel"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		panel.move_child(icon, 0) # 키 힌트(Q/R) 라벨보다 뒤(아래)에 그려지게.
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

	var slots_variant: Variant = GameState.get("skill_slots")
	_apply_slots(slots_variant if typeof(slots_variant) == TYPE_ARRAY and (slots_variant as Array).size() >= 2 else ["", ""])

	Events.skills_changed.connect(_on_skills_changed)
	Events.skill_cast.connect(_on_skill_cast)
	Events.skill_ready.connect(_on_skill_ready)


func _on_skills_changed(_learned: Array, slots: Array, _skill_points: int) -> void:
	_apply_slots(slots)


func _apply_slots(slots: Array) -> void:
	_slots = slots
	for i in _icon_labels.size():
		var skill_id: String = String(slots[i]) if i < slots.size() else ""
		var series: String = String(Data.get_value("skills", "%s.series" % skill_id, ""))
		_icon_labels[i].text = series.left(1).to_upper() if not series.is_empty() else ""


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
