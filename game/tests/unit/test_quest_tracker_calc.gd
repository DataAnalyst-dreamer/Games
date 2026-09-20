## QuestTrackerCalc(scripts/ui/quest_tracker_calc.gd) 테스트(M4-2, D-181~D-183) —
## 화면 안/밖 판정, 가장자리 clamp 방향, m 환산. 순수 RefCounted라 Node 없이 직접
## 테스트한다(test_hud_math.gd와 같은 관례).
extends GutTest

const VIEWPORT := Vector2(640, 360)
const MARGIN := 24.0


func test_target_at_camera_center_is_on_screen() -> void:
	var result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2(100, 100), VIEWPORT, Vector2.ONE, Vector2(100, 100), MARGIN)
	assert_true(result["on_screen"])


func test_target_slightly_off_center_is_on_screen() -> void:
	var result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2.ZERO, VIEWPORT, Vector2.ONE, Vector2(200, 100), MARGIN)
	assert_true(result["on_screen"])


func test_target_far_right_is_off_screen_and_clamped_to_right_edge() -> void:
	var result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2.ZERO, VIEWPORT, Vector2.ONE, Vector2(2000, 0), MARGIN)
	assert_false(result["on_screen"])
	var screen_pos: Vector2 = result["screen_pos"]
	assert_almost_eq(screen_pos.x, VIEWPORT.x - MARGIN, 0.5)
	assert_almost_eq(screen_pos.y, VIEWPORT.y * 0.5, 0.5)
	assert_almost_eq(float(result["angle_deg"]), 0.0, 0.5)


func test_target_far_below_is_off_screen_and_clamped_to_bottom_edge() -> void:
	var result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2.ZERO, VIEWPORT, Vector2.ONE, Vector2(0, 2000), MARGIN)
	assert_false(result["on_screen"])
	var screen_pos: Vector2 = result["screen_pos"]
	assert_almost_eq(screen_pos.y, VIEWPORT.y - MARGIN, 0.5)
	assert_almost_eq(float(result["angle_deg"]), 90.0, 0.5)


func test_zoom_shrinks_on_screen_half_extent() -> void:
	# 줌 2배면 world 절반 폭이 더 좁아져(화면에 더 가까이 보임) 그만큼 더 가까운 target도
	# 이제 화면 밖으로 판정돼야 한다.
	var far_result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2.ZERO, VIEWPORT, Vector2(2, 2), Vector2(200, 0), MARGIN)
	assert_false(far_result["on_screen"])
	var near_result: Dictionary = QuestTrackerCalc.edge_arrow(Vector2.ZERO, VIEWPORT, Vector2(1, 1), Vector2(200, 0), MARGIN)
	assert_true(near_result["on_screen"])


func test_distance_meters_divides_by_tile_size() -> void:
	assert_almost_eq(QuestTrackerCalc.distance_meters(160.0, 16.0), 10.0, 0.001)


func test_distance_meters_zero_tile_size_is_safe() -> void:
	assert_eq(QuestTrackerCalc.distance_meters(160.0, 0.0), 0.0)
