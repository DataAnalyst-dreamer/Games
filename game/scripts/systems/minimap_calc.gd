## 미니맵 좌표 계산(M5-2, D-172 후속). Node/카메라 의존 없는 순수 함수만 담아 GUT에서
## 직접 검증한다(quest_tracker_calc.gd/hud_math.gd와 동일 관례).
##
## world_to_local()은 quest_tracker_calc.gd의 QuestTrackerCalc.edge_arrow()를 그대로
## 위임한다 — 화면 중심 기준 world→local 변환 + 가장자리 clamp 수식이 미니맵에도 그대로
## 성립함을 실측 확인했다(카메라중심/뷰포트크기/줌만 다르게 넘기면 동일, 복붙 금지).
class_name MinimapCalc
extends RefCounted


## 미니맵이 view_radius_px(월드 px) 반경을 보여주도록 하는 균등 줌 배율. 뷰포트의 더
## 짧은 변을 기준으로 잡아 좌우/상하 어느 쪽도 반경 밖을 잘라먹지 않게 한다.
static func compute_zoom(view_radius_px: float, viewport_size: Vector2) -> Vector2:
	if view_radius_px <= 0.0:
		return Vector2.ONE
	var z: float = minf(viewport_size.x, viewport_size.y) / (2.0 * view_radius_px)
	return Vector2(z, z)


## target_world를 미니맵 로컬 좌표(0,0~viewport_size)로 변환. 화면 안이면 그 위치
## 그대로, 밖이면 margin_px만큼 여백을 둔 사각형 가장자리로 clamp된 위치를 pos에 담아
## 반환한다(on_screen로 구분). 호출부는 "화면 밖은 숨김"(랜드마크) 또는 "화면 밖도
## 가장자리에 점으로"(추적 목표) 중 필요한 쪽을 on_screen 값으로 고르면 된다.
static func world_to_local(camera_center: Vector2, viewport_size: Vector2, zoom: Vector2, target_world: Vector2, margin_px: float) -> Dictionary:
	var result: Dictionary = QuestTrackerCalc.edge_arrow(camera_center, viewport_size, zoom, target_world, margin_px)
	return {"pos": result["screen_pos"], "on_screen": result["on_screen"]}
