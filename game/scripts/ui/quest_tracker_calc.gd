## 추적 목표 화면 가장자리 화살표 계산(F5-1 확장, M4-2, D-181~D-183). Node/카메라
## 의존 없는 순수 함수만 담아 GUT에서 직접 검증한다(hud_math.gd/quest_log_ui_calc.gd와
## 동일 관례 — Data/QuestSystem/카메라 조회는 전부 호출부(hud_quest_tracker.gd)가 하고,
## 여기는 좌표 계산만 한다).
class_name QuestTrackerCalc
extends RefCounted


## target_world가 카메라 뷰포트 안이면 on_screen=true(호출부는 이때 화살표를 그리지
## 않는다 — 표식(▼)만으로 충분). 밖이면 화면 중심~target 방향 직선이 (여백을 뺀)
## 뷰포트 사각형과 만나는 점을 screen_pos로, 그 방향각(도, 0=오른쪽·시계방향 증가,
## Control.rotation과 같은 부호)을 angle_deg로 반환한다. distance_px는 카메라 중심
## 기준 world 실거리(줌 반영 전) — "m" 환산은 distance_meters()가 별도로 한다.
static func edge_arrow(camera_center: Vector2, viewport_size: Vector2, zoom: Vector2, target_world: Vector2, margin_px: float) -> Dictionary:
	var effective_zoom: Vector2 = zoom if zoom.x > 0.0 and zoom.y > 0.0 else Vector2.ONE
	var offset_world: Vector2 = target_world - camera_center
	var distance_px: float = offset_world.length()
	var half_screen_world: Vector2 = (viewport_size * 0.5) / effective_zoom
	var on_screen: bool = absf(offset_world.x) <= half_screen_world.x and absf(offset_world.y) <= half_screen_world.y
	if on_screen:
		return {
			"on_screen": true,
			"screen_pos": viewport_size * 0.5 + offset_world * effective_zoom,
			"angle_deg": 0.0,
			"distance_px": distance_px,
		}

	var center: Vector2 = viewport_size * 0.5
	var half_extent: Vector2 = Vector2(maxf(center.x - margin_px, 1.0), maxf(center.y - margin_px, 1.0))
	var direction: Vector2 = offset_world.normalized() if distance_px > 0.0 else Vector2.RIGHT
	var scale_x: float = (half_extent.x / absf(direction.x)) if direction.x != 0.0 else INF
	var scale_y: float = (half_extent.y / absf(direction.y)) if direction.y != 0.0 else INF
	var scale: float = minf(scale_x, scale_y)
	return {
		"on_screen": false,
		"screen_pos": center + direction * scale,
		"angle_deg": rad_to_deg(direction.angle()),
		"distance_px": distance_px,
	}


## world px 거리 -> "m" 표시용 환산. GDD에 공식 px-미터 비율이 없어 tuning.gd의
## TILE_SIZE_PROTOTYPE(32px/타일, D-206)을 "1타일=1m" 가정으로 재사용한다(ponytail: 추정치,
## game-designer가 실제 스케일을 확정하면 tile_size_px 인자만 교체하면 된다).
static func distance_meters(distance_px: float, tile_size_px: float) -> float:
	if tile_size_px <= 0.0:
		return 0.0
	return distance_px / tile_size_px
