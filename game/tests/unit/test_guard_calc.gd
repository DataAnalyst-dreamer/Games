## GuardCalc(scripts/systems/guard_calc.gd) 순수 로직 테스트.
## 수치 근거: D-05(저스트 가드 6프레임=0.1초), combat-tuning-m1.md §5-1(칩데미지 20%).
extends GutTest

const GuardCalcScript := preload("res://scripts/systems/guard_calc.gd")

const WINDOW_SEC := 0.1
const CHIP_RATIO := 0.2


func test_frames_to_sec_matches_d05() -> void:
	# D-05: 6프레임 @ 60fps = 0.1초.
	assert_almost_eq(GuardCalcScript.frames_to_sec(6, 60), 0.1, 0.0001)


func test_frames_to_sec_zero_fps_is_safe() -> void:
	assert_eq(GuardCalcScript.frames_to_sec(6, 0), 0.0, "fps<=0은 0으로 안전 처리")


func test_just_guard_window_at_zero_elapsed() -> void:
	assert_true(GuardCalcScript.is_just_guard_window(0.0, WINDOW_SEC), "가드 입력 직후(0s) 맞으면 저스트")


func test_just_guard_window_inclusive_upper_bound() -> void:
	assert_true(GuardCalcScript.is_just_guard_window(0.1, WINDOW_SEC), "정확히 0.1초는 포함(경계 포함)")


func test_not_just_guard_after_window() -> void:
	assert_false(GuardCalcScript.is_just_guard_window(0.101, WINDOW_SEC), "0.1초를 넘기면 저스트 아님")


func test_not_just_guard_for_negative_elapsed() -> void:
	assert_false(GuardCalcScript.is_just_guard_window(-0.01, WINDOW_SEC))


func test_chip_damage_reduces_by_ratio() -> void:
	# combat-tuning-m1.md §5-1: chip_damage_ratio=0.2 → 80% 경감.
	assert_eq(GuardCalcScript.chip_damage(10, CHIP_RATIO), 2)
	assert_eq(GuardCalcScript.chip_damage(15, CHIP_RATIO), 3)


func test_chip_damage_rounds_to_nearest_int() -> void:
	# 8 * 0.2 = 1.6 -> round -> 2 (슬라임 atk=8 기준 실측치).
	assert_eq(GuardCalcScript.chip_damage(8, CHIP_RATIO), 2)


func test_chip_damage_zero_raw_damage_is_zero() -> void:
	assert_eq(GuardCalcScript.chip_damage(0, CHIP_RATIO), 0)
