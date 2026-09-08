## HudMath(scripts/ui/hud_math.gd) 순수 계산 함수 테스트(F7-1 태스크 6:
## "HP 퍼센트→바 값·경고 임계 계산 순수 함수").
extends GutTest

const HudMathScript := preload("res://scripts/ui/hud_math.gd")


func test_ratio_normal_range() -> void:
	assert_almost_eq(HudMathScript.ratio(50.0, 100.0), 0.5, 0.0001)


func test_ratio_clamps_to_0_1_and_avoids_division_by_zero() -> void:
	assert_eq(HudMathScript.ratio(10.0, 0.0), 0.0, "max<=0이면 0으로 나눗셈 방지")
	assert_eq(HudMathScript.ratio(150.0, 100.0), 1.0, "초과분은 1.0으로 클램프")
	assert_eq(HudMathScript.ratio(-10.0, 100.0), 0.0, "음수는 0으로 클램프")


func test_is_hp_critical_true_at_and_below_25_percent() -> void:
	assert_true(HudMathScript.is_hp_critical(25.0, 100.0), "정확히 25%는 경고 대상(F7-1 예외 규칙)")
	assert_true(HudMathScript.is_hp_critical(1.0, 100.0))
	assert_false(HudMathScript.is_hp_critical(26.0, 100.0))


func test_is_hp_critical_false_when_dead() -> void:
	assert_false(HudMathScript.is_hp_critical(0.0, 100.0),
		"HP 0(사망)은 점멸 대상이 아니라 별도 사망 처리로 넘어가야 한다")


func test_is_stamina_low_matches_debug_hud_threshold() -> void:
	assert_true(HudMathScript.is_stamina_low(24.0, 100.0))
	assert_false(HudMathScript.is_stamina_low(25.0, 100.0))


func test_is_stamina_empty() -> void:
	assert_true(HudMathScript.is_stamina_empty(0.0))
	assert_true(HudMathScript.is_stamina_empty(-0.001))
	assert_false(HudMathScript.is_stamina_empty(0.001))
