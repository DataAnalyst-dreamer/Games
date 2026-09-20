## 미니맵 v1(M5-2, D-172 후속). 게이트5 피드백 "미니맵은 아직 아무것도 안 나온다" 대응 —
## D-172에서 "미니맵은 후속"으로 미뤄둔 것을 실제 지형이 보이는 형태로 구현한다.
##
## hud_progress.gd/hud_quest_tracker.gd와 동일 분리 원칙(Root의 형제 자손 Node, hud.gd는
## 전혀 건드리지 않는다). Hud.tscn의 TopRight/MinimapFrame 안에 SubViewport+전용
## Camera2D(월드 그대로 축소 렌더)를 두고, 이 Control(같은 자리 오버레이)이 그 위에
## 마커만 얇게 그린다.
##
## 렌더 공유의 핵심: SubViewport는 기본적으로 메인 뷰포트의 World2D를 공유하지
## 않는다(own_world_2d 같은 토글은 3D에만 있고 2D는 없음 — Godot 4.4.1 실측: 대입 안
## 하면 회색 배경만 나옴). _ready()에서 world_2d를 명시적으로 같은 참조로 대입해야
## TileMapLayer/몬스터/NPC가 그대로 보인다.
##
## 좌표 변환·clamp는 minimap_calc.gd(순수)에, 추적 목표 월드 위치 조회는
## quest_target_locator.gd(hud_quest_tracker.gd와 공유)에 위임한다 — 이 스크립트는
## "언제 갱신하고 무엇을 그릴지"만 담당한다.
class_name HudMinimap
extends Control

## MinimapFrame 안 표시 영역 크기(px, Hud.tscn 레이아웃과 일치 — MinimapViewport 노드의
## size와도 같은 값이어야 한다). SubViewportContainer가 매 프레임 자식 크기를 자신의
## rect와 동기화하지만, _ready() 시점 레이스를 피하려고 실제 값을 여기 고정해 둔다.
const MINIMAP_SIZE := Vector2(56.0, 32.0)
const PLAYER_DOT_RADIUS := 2.0
const LANDMARK_DOT_RADIUS := 1.5
const TRACKED_DOT_RADIUS := 2.0

@onready var _viewport: SubViewport = get_node("../MinimapViewportContainer/MinimapViewport")
@onready var _camera: Camera2D = get_node("../MinimapViewportContainer/MinimapViewport/MinimapCamera")

var _player: Node2D
var _timer: float = 0.0
var _tracked_target: Variant = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.world_2d = get_viewport().world_2d
	_camera.zoom = MinimapCalc.compute_zoom(Tuning.MINIMAP_VIEW_RADIUS_PX, MINIMAP_SIZE)
	_camera.make_current()
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return # 미니맵 토글(M키)로 숨겨진 동안은 카메라 이동·렌더·다시그리기를 쉰다.
	_timer += delta
	if _timer < Tuning.MINIMAP_UPDATE_INTERVAL_SEC:
		return
	_timer = 0.0
	_refresh()


## 카메라 위치·추적 목표·SubViewport 렌더를 한 번에 갱신한다(같은 주기로 묶어야
## "터레인은 새 위치, 마커는 헌 위치" 같은 어긋남이 안 생긴다). force_refresh()로도
## 외부(스모크)에서 호출 가능.
func _refresh() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		return
	_camera.global_position = _player.global_position
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_tracked_target = QuestTargetLocator.find_tracked_target_position()
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var center: Vector2 = _camera.global_position
	var zoom: Vector2 = _camera.zoom

	draw_circle(MINIMAP_SIZE * 0.5, PLAYER_DOT_RADIUS, get_theme_color(&"text_default", &"HUD"))

	for w in get_tree().get_nodes_in_group(&"waystones"):
		_draw_landmark_if_on_screen(w.global_position, center, zoom, get_theme_color(&"minimap_waystone", &"HUD"))

	for n in get_tree().get_nodes_in_group(&"quest_markers"):
		if not n.marker_visible():
			continue
		var symbol: String = n.marker_text()
		if symbol != "!" and symbol != "?":
			continue # ▼(현재 추적 목표)는 아래 _tracked_target 경로가 이미 그린다 — 중복 방지.
		var color_key: StringName = &"quest_marker_available" if symbol == "!" else &"quest_marker_complete"
		_draw_landmark_if_on_screen(n.global_position, center, zoom, get_theme_color(color_key, &"HUD"))

	if _tracked_target != null:
		var result: Dictionary = MinimapCalc.world_to_local(center, MINIMAP_SIZE, zoom, _tracked_target as Vector2, Tuning.MINIMAP_EDGE_MARGIN_PX)
		draw_circle(result["pos"] as Vector2, TRACKED_DOT_RADIUS, get_theme_color(&"quest_marker_objective", &"HUD"))


## 랜드마크(비석/NPC !·?)는 추적 목표와 달리 미니맵 밖이면 그냥 숨긴다(클램프 안 함) —
## 지시 범위: "미니맵 밖의 추적 목표는 테두리에 점으로"만 명시, 나머지는 스코프 최소화.
func _draw_landmark_if_on_screen(world_pos: Vector2, center: Vector2, zoom: Vector2, color: Color) -> void:
	var result: Dictionary = MinimapCalc.world_to_local(center, MINIMAP_SIZE, zoom, world_pos, 0.0)
	if not bool(result.get("on_screen", false)):
		return
	draw_circle(result["pos"] as Vector2, LANDMARK_DOT_RADIUS, color)


# --- 테스트 보조용 (스모크에서 직접 확인) ---

func force_refresh() -> void:
	_refresh()


func tracked_target() -> Variant:
	return _tracked_target


func camera_global_position() -> Vector2:
	return _camera.global_position


func minimap_texture_image() -> Image:
	return _viewport.get_texture().get_image()
