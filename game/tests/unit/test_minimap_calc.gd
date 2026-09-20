## MinimapCalc(scripts/systems/minimap_calc.gd) 테스트(M5-2). world_to_local()의 실제
## clamp 수식은 QuestTrackerCalc.edge_arrow() 위임이라 test_quest_tracker_calc.gd가 이미
## 검증했다(중복 방지) — 여기는 compute_zoom()과 위임 계약(반환 shape)만 확인한다.
extends GutTest

const VIEWPORT := Vector2(56, 32)


func test_compute_zoom_uses_smaller_viewport_dimension() -> void:
	var zoom: Vector2 = MinimapCalc.compute_zoom(100.0, VIEWPORT)
	assert_almost_eq(zoom.x, 32.0 / 200.0, 0.001)
	assert_eq(zoom.x, zoom.y)


func test_compute_zoom_zero_radius_falls_back_to_one() -> void:
	assert_eq(MinimapCalc.compute_zoom(0.0, VIEWPORT), Vector2.ONE)


func test_world_to_local_center_target_is_on_screen_center() -> void:
	var result: Dictionary = MinimapCalc.world_to_local(Vector2(100, 100), VIEWPORT, Vector2.ONE, Vector2(100, 100), 3.0)
	assert_true(result["on_screen"])
	var pos: Vector2 = result["pos"]
	assert_almost_eq(pos.x, VIEWPORT.x * 0.5, 0.01)
	assert_almost_eq(pos.y, VIEWPORT.y * 0.5, 0.01)


func test_world_to_local_far_target_is_clamped_off_screen() -> void:
	var result: Dictionary = MinimapCalc.world_to_local(Vector2.ZERO, VIEWPORT, Vector2.ONE, Vector2(500, 0), 3.0)
	assert_false(result["on_screen"])
	var pos: Vector2 = result["pos"]
	assert_almost_eq(pos.x, VIEWPORT.x - 3.0, 0.5) # 목표가 오른쪽(+x)이라 오른쪽 여백으로 clamp.
	assert_almost_eq(pos.y, VIEWPORT.y * 0.5, 0.5)
