## RollCalc(scripts/systems/roll_calc.gd) 순수 로직 테스트.
## 수치 근거: docs/specs/combat-tuning-m1.md §2 (iframes=0.3s, duration=0.45s, distance=48px).
extends GutTest

const RollCalcScript := preload("res://scripts/systems/roll_calc.gd")

const IFRAMES_SEC := 0.3
const DURATION_SEC := 0.45
const DISTANCE_PX := 48.0


func test_invulnerable_from_start() -> void:
	assert_true(RollCalcScript.is_invulnerable(0.0, IFRAMES_SEC), "구르기 시작(0s)은 무적 구간")


func test_invulnerable_just_before_iframe_end() -> void:
	assert_true(RollCalcScript.is_invulnerable(0.299, IFRAMES_SEC), "0.299s는 아직 무적 구간(0~0.3s)")


func test_not_invulnerable_at_iframe_end() -> void:
	assert_false(RollCalcScript.is_invulnerable(0.3, IFRAMES_SEC), "0.3s는 무적 구간 종료(배타적 상한)")


func test_not_invulnerable_during_recovery() -> void:
	# 0.3~0.45s는 후딜레이(착지 경직) 구간 — GDD 4.1 무적은 0.3초로 확정.
	assert_false(RollCalcScript.is_invulnerable(0.35, IFRAMES_SEC))
	assert_false(RollCalcScript.is_invulnerable(0.449, IFRAMES_SEC))


func test_not_finished_before_full_duration() -> void:
	assert_false(RollCalcScript.is_finished(0.449, DURATION_SEC), "전체 지속시간(0.45s) 이전엔 안 끝남")


func test_finished_at_full_duration() -> void:
	assert_true(RollCalcScript.is_finished(DURATION_SEC, DURATION_SEC), "0.45s 도달 시 종료(경계 포함)")
	assert_true(RollCalcScript.is_finished(0.5, DURATION_SEC))


func test_average_speed_matches_distance_over_duration() -> void:
	# combat-tuning-m1.md §2-3: 48px / 0.45s ≈ 106.667px/s.
	var speed := RollCalcScript.average_speed_px_s(DISTANCE_PX, DURATION_SEC)
	assert_almost_eq(speed, 106.6667, 0.001)


func test_average_speed_zero_when_duration_non_positive() -> void:
	assert_eq(RollCalcScript.average_speed_px_s(DISTANCE_PX, 0.0), 0.0)
	assert_eq(RollCalcScript.average_speed_px_s(DISTANCE_PX, -0.1), 0.0)


func test_iframe_ratio_is_two_thirds_of_total_duration() -> void:
	# combat-tuning-m1.md §2-1: 무적 0.3s / 전체 0.45s = 66.7%.
	assert_almost_eq(IFRAMES_SEC / DURATION_SEC, 0.6667, 0.001)
