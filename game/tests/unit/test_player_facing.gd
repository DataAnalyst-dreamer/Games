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


# --- D-128: 시간 기반 디바운스(최소 축 유지 시간) ------------------------------------
# 배경: 크기 기반 완충(bias)만으로는 실제 키보드 입력(대각선 두 키가 정확히 같은
# 프레임에 눌리지 않는 경우)에서 잔여 흔들림이 남는다는 2차 재테스트 재현 보고에 따른
# 추가 방어선. resolve_facing()에 elapsed_since_last_switch/min_switch_interval_sec을
# 추가했다 — 두 값이 기본값(매우 큰 값 / 0)일 때는 위 기존 테스트들과 동일하게 동작해야
# 한다(이미 위 테스트들이 3-인자 호출로 이를 검증한다).

const MIN_INTERVAL := 0.1


func test_debounce_default_params_do_not_block_switch() -> void:
	# 4번째·5번째 인자를 생략한 기존 호출부는 디바운스가 걸리지 않아야 한다(하위 호환).
	var result: Vector2 = FacingCalcScript.resolve_facing(Vector2.DOWN, Vector2(1.0, 0.0), BIAS)
	assert_eq(result, Vector2.RIGHT)


func test_debounce_holds_axis_within_min_interval() -> void:
	# 마지막 축 전환 후 0.02초밖에 지나지 않았다면, 크기 조건(명확한 수평 우세)을
	# 만족해도 축 전환을 보류하고 현재 축(DOWN, 수직)을 유지해야 한다.
	var result: Vector2 = FacingCalcScript.resolve_facing(
		Vector2.DOWN, Vector2(1.0, 0.0), BIAS, 0.02, MIN_INTERVAL)
	assert_eq(result, Vector2.DOWN,
		"최근 축 전환 후 최소 유지시간 이내면 크기 조건을 만족해도 축을 유지해야 한다")


func test_debounce_releases_axis_after_min_interval() -> void:
	# 최소 유지시간(0.1초)이 지나면 동일한 크기 조건에서 축 전환이 다시 허용돼야 한다
	# (디바운스가 영구 고정이 아님을 확인).
	var result: Vector2 = FacingCalcScript.resolve_facing(
		Vector2.DOWN, Vector2(1.0, 0.0), BIAS, 0.2, MIN_INTERVAL)
	assert_eq(result, Vector2.RIGHT,
		"최소 유지시간이 지나면 명확한 축 전환이 허용돼야 한다")


func test_debounce_does_not_block_same_axis_sign_change() -> void:
	# 축 전환이 아니라 같은 축 내 부호 변경(RIGHT→LEFT)은 디바운스와 무관하게 즉시
	# 반영돼야 한다 — "축"만 디바운스 대상이지, 방향 반전 자체를 막으면 안 된다.
	var result: Vector2 = FacingCalcScript.resolve_facing(
		Vector2.RIGHT, Vector2(-1.0, 0.0), BIAS, 0.0, MIN_INTERVAL)
	assert_eq(result, Vector2.LEFT)


func test_fast_frame_diagonal_jitter_kept_stable_within_debounce_window() -> void:
	# D-128 요구사항 원문: "빠른 프레임 간격으로 대각선 근처 입력이 흔들려도(예: 0.03초
	# 간격으로 축이 살짝 넘어가는 입력을 연속 투입) 디바운스 구간 내에는 축이 유지된다."
	var facing: Vector2 = Vector2.DOWN
	var elapsed_since_switch: float = 1e9
	var frame_dt := 0.03

	# 1) 명확한 수평 우세 입력으로 DOWN → RIGHT 최초 전환(디바운스 없이 허용되어야 함).
	facing = FacingCalcScript.resolve_facing(
		facing, Vector2(1.0, 0.3), BIAS, elapsed_since_switch, MIN_INTERVAL)
	assert_eq(facing, Vector2.RIGHT, "전제조건: 최초 전환은 허용되어야 한다")
	elapsed_since_switch = 0.0

	# 2) 곧바로 0.03초 간격으로 반대 축(수직) 우세 입력이 3프레임 연속 들어와도(실제
	# 키보드 대각선 잔여 흔들림 재현) 디바운스 구간(0.1초) 안에서는 축이 유지돼야 한다.
	for i in range(3):
		elapsed_since_switch += frame_dt
		facing = FacingCalcScript.resolve_facing(
			facing, Vector2(0.3, 1.0), BIAS, elapsed_since_switch, MIN_INTERVAL)
		assert_eq(facing, Vector2.RIGHT,
			"디바운스 구간(0.1s) 이내의 축 반전 시도는 무시되어야 한다(frame %d, elapsed=%.3f)" \
				% [i, elapsed_since_switch])

	# 3) 디바운스 구간을 넘어서면(누적 0.12s ≥ 0.1s) 동일한 수직 우세 입력이 실제로
	# 축을 전환시켜야 한다 — 디바운스가 영구 고정이 아님을 재확인.
	elapsed_since_switch += frame_dt
	facing = FacingCalcScript.resolve_facing(
		facing, Vector2(0.3, 1.0), BIAS, elapsed_since_switch, MIN_INTERVAL)
	# 입력 y성분이 양수(Godot 2D는 아래로 갈수록 y가 커짐)이므로 DOWN이 기대값이다.
	assert_eq(facing, Vector2.DOWN, "디바운스 구간을 넘으면 명확한 축 전환은 허용돼야 한다")


func test_player_set_facing_integration_respects_min_interval() -> void:
	# 순수 로직뿐 아니라 Player.set_facing()이 실제로 elapsed 누적을
	# Tuning.FACING_AXIS_SWITCH_MIN_INTERVAL_SEC과 함께 넘기는지도 통합 검증한다.
	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player: Player = player_scene.instantiate()
	add_child_autofree(player)
	player.facing = Vector2.DOWN

	player.set_facing(Vector2(1.0, 0.3)) # 명확한 수평 우세 → RIGHT로 전환.
	assert_eq(player.facing, Vector2.RIGHT)

	# 물리 프레임 1틱(약 0.016초)만 흐른 뒤 반대 축 우세 입력이 들어와도, 디바운스
	# 구간(기본 0.1초) 이내이므로 축이 유지돼야 한다.
	player._physics_process(1.0 / 60.0)
	player.set_facing(Vector2(0.3, 1.0))
	assert_eq(player.facing, Vector2.RIGHT,
		"Player 통합 경로에서도 디바운스 구간 내 축 전환은 무시되어야 한다")

	# 디바운스 구간을 확실히 넘길 만큼 물리 프레임을 흘려보내면 전환이 허용돼야 한다.
	for i in range(10):
		player._physics_process(1.0 / 60.0)
	player.set_facing(Vector2(0.3, 1.0))
	# 입력 y성분이 양수(Godot 2D는 아래로 갈수록 y가 커짐)이므로 DOWN이 기대값이다.
	assert_eq(player.facing, Vector2.DOWN,
		"디바운스 구간을 넘기면 명확한 축 전환은 여전히 허용돼야 한다")
