## 추적 목표 화면 가장자리 화살표(F5-1 확장, M4-2, D-181~D-183). "표식은 잘 나오는데
## 어디 있는지 따라갈 방법이 없다"는 피드백 대응 — 화면 안이면 기존 ▼ 표식만으로
## 충분하니 이 노드는 화면 밖일 때만 화살표를 띄운다.
##
## hud_progress.gd/hud_skill_slots.gd와 동일 분리 원칙(Root의 형제 Node, hud.gd는
## 전혀 건드리지 않는다 — Hud.tscn에 노드 1개만 추가). 좌표 계산은 quest_tracker_calc.gd
## (순수 함수)에 위임하고, 여기서는 카메라·퀘스트 상태 조회 + Label 갱신만 한다.
##
## 대상 위치 조회: world_objects.json(kind: location/object/npc)을 훑어 quest_npc.gd/
## quest_object.gd가 표식(▼) 판정에 쓰는 것과 같은 공개 API(QuestSystem.get_active_
## reach/interact/talk_objective_keys + is_tracked_objective_key)로 현재 추적 목표와
## 일치하는 항목을 찾는다. kill(몬스터) 목표는 world_objects에 없어 위치가 없으므로
## 자동으로 화살표가 뜨지 않는다(요구사항 그대로).
class_name HudQuestTracker
extends Control

const UPDATE_INTERVAL_SEC := 0.2

var _timer := 0.0
var _arrow: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_arrow = Label.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.pivot_offset = Vector2(8, 8)
	_arrow.visible = false
	if theme != null:
		_arrow.add_theme_color_override("font_color", theme.get_color(&"quest_marker_objective", &"HUD"))
		_arrow.add_theme_font_override("font", theme.default_font)
		_arrow.add_theme_font_size_override("font_size", theme.get_font_size(&"large", &"HUD"))
	add_child(_arrow)


func _process(delta: float) -> void:
	_timer += delta
	if _timer < UPDATE_INTERVAL_SEC:
		return
	_timer = 0.0
	_refresh()


func _refresh() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	var target: Variant = _find_tracked_target_pos()
	if camera == null or target == null:
		_arrow.visible = false
		return

	var result: Dictionary = QuestTrackerCalc.edge_arrow(
		camera.get_screen_center_position(), get_viewport_rect().size, camera.zoom,
		target as Vector2, Tuning.QUEST_ARROW_MARGIN_PX)
	if bool(result.get("on_screen", true)):
		_arrow.visible = false # 화면 안 — 기존 ▼ 표식만으로 충분(요구사항 1).
		return

	_arrow.visible = true
	_arrow.position = (result.get("screen_pos", Vector2.ZERO) as Vector2) - _arrow.pivot_offset
	_arrow.rotation = deg_to_rad(float(result.get("angle_deg", 0.0)) + 90.0) # "▲" 기본 방향이 위쪽이라 90도 보정.
	var meters := QuestTrackerCalc.distance_meters(float(result.get("distance_px", 0.0)), float(Tuning.TILE_SIZE_PROTOTYPE))
	_arrow.text = "▲ %dm" % int(round(meters))


## world_objects.json을 kind별로 훑어 현재 추적 목표와 일치하는 위치를 찾는다. 이
## 조회 자체는 QuestSystem 살아있는 상태에 의존해 순수 함수가 아니다 — quest_npc.gd
## _refresh_marker()와 같은 이유로 quest_tracker_calc.gd에 넣지 않았다(단순 순회 1회분,
## 별도 순수 함수로 뺄 만큼의 분기가 없다 — ponytail).
func _find_tracked_target_pos() -> Variant:
	if QuestSystem.get_tracked().is_empty():
		return null
	var world_objects: Dictionary = Data.table("world_objects")
	for id: String in world_objects.keys():
		if id.begins_with("_"):
			continue
		var entry: Dictionary = world_objects[id]
		var keys: Array[String] = []
		match String(entry.get("kind", "")):
			"location": keys = QuestSystem.get_active_reach_objective_keys(StringName(id))
			"object": keys = QuestSystem.get_active_interact_objective_keys(StringName(id))
			"npc": keys = QuestSystem.get_active_talk_objective_keys(StringName(id))
			_: continue
		if not QuestSystem.is_tracked_objective_key(keys):
			continue
		var pos: Array = entry.get("position", [])
		if pos.size() >= 2:
			return Vector2(float(pos[0]), float(pos[1]))
	return null
