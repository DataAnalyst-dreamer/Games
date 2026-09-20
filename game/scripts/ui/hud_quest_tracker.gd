## 추적 목표 화면 가장자리 화살표(F5-1 확장, M4-2, D-181~D-183). "표식은 잘 나오는데
## 어디 있는지 따라갈 방법이 없다"는 피드백 대응 — 화면 안이면 기존 ▼ 표식만으로
## 충분하니 이 노드는 화면 밖일 때만 화살표를 띄운다.
##
## hud_progress.gd/hud_skill_slots.gd와 동일 분리 원칙(Root의 형제 Node, hud.gd는
## 전혀 건드리지 않는다 — Hud.tscn에 노드 1개만 추가). 좌표 계산은 quest_tracker_calc.gd
## (순수 함수)에 위임하고, 여기서는 카메라·퀘스트 상태 조회 + Label 갱신만 한다.
##
## 대상 위치 조회(world_objects.json 기반)는 M5-2(미니맵)와 공유하기 위해
## quest_target_locator.gd(QuestTargetLocator.find_tracked_target_position())로 뺐다 —
## kill(몬스터) 목표는 world_objects에 없어 위치가 없으므로 자동으로 화살표가 뜨지
## 않는다(요구사항 그대로).
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
	var target: Variant = QuestTargetLocator.find_tracked_target_position()
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
