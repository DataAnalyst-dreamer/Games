## ComboState(scripts/systems/combo_state.gd) 순수 로직 테스트.
## 수치 근거: docs/specs/combat-tuning-m1.md §4 (buffer=0.2s, reset=0.6s, hits=3).
extends GutTest

const ComboStateScript := preload("res://scripts/systems/combo_state.gd")

## 테스트용 고정 파라미터: hit_duration=0.3s, buffer=0.2s(마지막 0.2초가 버퍼 구간),
## reset_after=0.6s, finisher_recovery=0.35s.
func _make_combo() -> ComboState:
	return ComboStateScript.new(3, 0.2, 0.6, 0.3, 0.35)


func test_first_attack_input_starts_hit_1() -> void:
	var combo := _make_combo()
	assert_eq(combo.hit_index, ComboStateScript.IDLE_HIT)
	var started := combo.on_attack_input()
	assert_true(started, "빈 콤보에 공격 입력 시 즉시 1타 시작")
	assert_eq(combo.hit_index, 1)


func test_buffered_input_chains_to_next_hit_at_active_end() -> void:
	# hit_duration=0.3, input_buffer_sec=0.2 → 버퍼 구간은 [0.1, 0.3).
	var combo := _make_combo()
	combo.on_attack_input() # 1타 시작
	combo.update(0.05) # elapsed=0.05, 아직 버퍼 구간 진입 전
	assert_false(combo.is_in_buffer_window())
	combo.update(0.05) # elapsed=0.10 → 버퍼 구간 진입
	assert_true(combo.is_in_buffer_window())
	var buffered := combo.on_attack_input()
	assert_false(buffered, "버퍼링만 되고 즉시 전환은 아님")
	assert_true(combo.buffered)
	var result := combo.update(0.2) # elapsed=0.30 → 활성 구간 종료, 버퍼링되어 있어 2타로
	assert_true(result.advanced)
	assert_eq(combo.hit_index, 2)


func test_no_input_during_buffer_enters_grace_then_resets_after_full_timeout() -> void:
	var combo := _make_combo()
	combo.on_attack_input() # 1타
	var result := combo.update(0.3) # 활성 구간 정확히 종료, 입력 없음 → 유예 구간 진입
	assert_false(result.advanced)
	assert_false(result.reset)
	assert_true(combo.is_in_grace_window())
	result = combo.update(0.6 - 0.3 - 0.001) # reset_after_sec 직전까지
	assert_false(result.reset, "reset_after_sec 도달 전에는 리셋되지 않는다")
	result = combo.update(0.01) # reset_after_sec(누적 elapsed=0.6) 도달
	assert_true(result.reset)
	assert_eq(combo.hit_index, ComboStateScript.IDLE_HIT)


func test_late_input_during_grace_window_chains_immediately() -> void:
	var combo := _make_combo()
	combo.on_attack_input()
	combo.update(0.3) # 유예 구간 진입
	combo.update(0.15) # 유예 구간 중(0.3~0.6)
	var chained := combo.on_attack_input()
	assert_true(chained, "유예 구간 중 입력은 버퍼링이 아니라 즉시 다음 타로 연결")
	assert_eq(combo.hit_index, 2)


func test_third_hit_enters_finisher_recovery_then_resets() -> void:
	var combo := _make_combo()
	combo.on_attack_input() # 1타
	combo.update(0.2)
	combo.on_attack_input() # 버퍼링
	combo.update(0.1) # 2타로 전환(elapsed 리셋)
	assert_eq(combo.hit_index, 2)
	combo.update(0.2)
	combo.on_attack_input() # 버퍼링
	var result := combo.update(0.1) # 3타로 전환
	assert_eq(combo.hit_index, 3)
	result = combo.update(0.3) # 3타 활성 구간 종료 → 피니셔 후딜 진입(다음 타 없음)
	assert_true(result.entered_finisher_recovery)
	assert_false(combo.can_roll_cancel(0.167), "후딜 진입 직후(elapsed=0)에는 아직 캔슬 불가")
	combo.update(0.17)
	assert_true(combo.can_roll_cancel(0.167), "프레임 10(0.167s) 이후 구르기 캔슬 가능(S2-1b)")
	result = combo.update(0.35 - 0.17 + 0.001) # finisher_recovery_sec 도달
	assert_true(result.reset)
	assert_eq(combo.hit_index, ComboStateScript.IDLE_HIT)


func test_attack_input_ignored_during_finisher_recovery() -> void:
	var combo := _make_combo()
	combo.on_attack_input()
	combo.update(0.2); combo.on_attack_input(); combo.update(0.1) # -> hit 2
	combo.update(0.2); combo.on_attack_input(); combo.update(0.1) # -> hit 3
	combo.update(0.3) # -> finisher recovery
	assert_true(combo.in_finisher_recovery)
	var result := combo.on_attack_input()
	assert_false(result, "피니셔 후딜 중 공격 입력은 무시된다")
	assert_true(combo.in_finisher_recovery, "후딜 상태 자체는 유지")


func test_is_active_reflects_combo_or_recovery() -> void:
	var combo := _make_combo()
	assert_false(combo.is_active())
	combo.on_attack_input()
	assert_true(combo.is_active())
	combo.reset()
	assert_false(combo.is_active())
