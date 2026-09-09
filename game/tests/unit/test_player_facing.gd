## FacingCalc(scripts/systems/facing_calc.gd) 순수 로직 테스트 — D-121,
## docs/qa/walk-animation-diagnosis.md §3 "대각선 부근 입력 흔들림에 facing이 프레임마다
## 토글되지 않아야 한다"를 검증한다. Player.tscn 인스턴스화 없이 순수 함수만 테스트한다
## (monster_ai_calc.gd 등 기존 *_calc.gd 테스트와 같은 패턴).
extends GutTest

const FacingCalcScript := preload("res://scripts/systems/facing_calc.gd")

const BIAS := 1.3


func test_zero_input_keeps_current_facing() -> void:
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.DOWN, Vector2.ZERO, BIAS)
	assert_eq(result, Vector2.DOWN)


func test_pure_horizontal_input_switches_from_vertical() -> void:
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.DOWN, Vector2(1.0, 0.0), BIAS)
	assert_eq(result, Vector2.RIGHT)


func test_pure_vertical_input_switches_from_horizontal() -> void:
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.LEFT, Vector2(0.0, -1.0), BIAS)
	assert_eq(result, Vector2.UP)


func test_diagonal_near_45_does_not_flip_axis_from_vertical() -> void:
	# 이전 facing=DOWN(수직축). 대각선 45도 근처(수평이 살짝 더 큼)라도 bias(1.3)를
	# 넘지 못하면 수직축을 유지해야 한다.
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.DOWN, Vector2(0.55, 0.5), BIAS)
	assert_eq(result, Vector2.DOWN, "수평 성분이 bias를 넘지 못하면 수직축을 유지해야 한다")


func test_diagonal_near_45_does_not_flip_axis_from_horizontal() -> void:
	# 이전 facing=RIGHT(수평축). 대각선 45도 근처(수직이 살짝 더 큼)라도 bias를 넘지
	# 못하면 수평축을 유지해야 한다.
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.RIGHT, Vector2(0.5, 0.55), BIAS)
	assert_eq(result, Vector2.RIGHT, "수직 성분이 bias를 넘지 못하면 수평축을 유지해야 한다")


func test_clear_axis_dominance_still_switches() -> void:
	# 반대 축이 bias(1.3)를 명확히 넘으면 전환은 여전히 일어나야 한다(완충이 "고정"은 아님).
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.DOWN, Vector2(1.0, 0.2), BIAS)
	assert_eq(result, Vector2.RIGHT)


func test_no_toggle_across_oscillating_near_diagonal_sequence() -> void:
	# "대각선 45도 근처에서 미세하게 흔들리는 입력을 줘도 facing이 프레임마다 토글되지
	# 않는다"(D-121 요구사항 원문) — 축이 거의 대칭인 입력을 번갈아 줘도 수직축(DOWN/UP)
	# 그룹에서 수평축(LEFT/RIGHT) 그룹으로 넘어가지 않아야 한다.
	var facing: Vector2 = Vector2.DOWN
	var oscillating_inputs: Array[Vector2] = [
		Vector2(0.71, 0.70), Vector2(0.69, 0.72), Vector2(0.72, 0.69),
		Vector2(0.70, 0.71), Vector2(0.68, 0.73), Vector2(0.73, 0.68),
	]
	var toggled_to_horizontal := false
	for input_dir in oscillating_inputs:
		facing = FacingCalcScript.resolve_facing(facing, input_dir, BIAS)
		if facing == Vector2.LEFT or facing == Vector2.RIGHT:
			toggled_to_horizontal = true
	assert_false(toggled_to_horizontal, "대각선 근처 미세 흔들림만으로 수직↔수평 축이 토글되면 안 된다")


func test_diagonal_gamepad_drift_pattern_keeps_stable_facing() -> void:
	# 게임패드 아날로그 드리프트를 흉내낸 수열(부호는 유지한 채 크기만 흔들림)에서도
	# facing이 매 프레임 다른 값으로 바뀌지 않아야 한다(토글 없음 = 안정).
	var facing: Vector2 = Vector2.RIGHT
	var previous_facing: Vector2 = facing
	var toggled := false
	var drift_inputs: Array[Vector2] = [
		Vector2(0.65, 0.60), Vector2(0.60, 0.65), Vector2(0.63, 0.62),
		Vector2(0.61, 0.64), Vector2(0.64, 0.61),
	]
	for input_dir in drift_inputs:
		facing = FacingCalcScript.resolve_facing(facing, input_dir, BIAS)
		if facing != previous_facing:
			toggled = true
		previous_facing = facing
	assert_false(toggled, "완충 구간 안의 흔들림은 facing을 전혀 바꾸지 않아야 한다")
