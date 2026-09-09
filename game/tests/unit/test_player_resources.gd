## PlayerResources(scripts/player/resources.gd) 순수 로직 테스트: 스태미나 소모/회복/
## 완전 고갈 페널티(D-44: 1.0초), 가드 중 회복 배율 훅, DEX 구르기 경감식(D-45).
extends GutTest

const PlayerResourcesScript := preload("res://scripts/player/resources.gd")

const MAX_STAMINA := 100.0
const REGEN_PER_SEC := 25.0
const REGEN_DELAY_SEC := 0.5
const EXHAUSTED_PENALTY_SEC := 1.0


func _make_resources() -> PlayerResources:
	return PlayerResourcesScript.new(100, MAX_STAMINA, REGEN_PER_SEC, REGEN_DELAY_SEC, EXHAUSTED_PENALTY_SEC)


func test_try_spend_succeeds_when_enough_stamina() -> void:
	var res := _make_resources()
	assert_true(res.try_spend(20.0))
	assert_almost_eq(res.stamina, 80.0, 0.001)


func test_try_spend_fails_when_not_enough_stamina() -> void:
	var res := _make_resources()
	res.stamina = 10.0
	assert_false(res.try_spend(20.0), "부족하면 소모 없이 false(F2-3 예외: 액션 미발동)")
	assert_almost_eq(res.stamina, 10.0, 0.001, "실패 시 잔여 스태미나는 변하지 않아야 한다")


func test_regen_delay_blocks_immediate_recovery() -> void:
	var res := _make_resources()
	res.try_spend(20.0) # stamina=80, _regen_wait=regen_delay_sec(0.5)
	res.tick(0.3) # 아직 대기 중
	assert_almost_eq(res.stamina, 80.0, 0.001, "회복 대기(0.5s) 중에는 회복하지 않는다")


func test_regen_resumes_after_delay() -> void:
	var res := _make_resources()
	res.try_spend(20.0) # stamina=80, 대기 0.5s
	res.tick(0.5) # 대기를 정확히 소진하는 프레임 — 이 프레임엔 아직 회복 없음(return 처리)
	res.tick(1.0) # 다음 프레임부터 회복: 80 + 25*1.0 = 105 -> max 100으로 clamp
	assert_almost_eq(res.stamina, 100.0, 0.001)


func test_regen_multiplier_slows_recovery() -> void:
	var res := _make_resources()
	res.stamina = 50.0
	res.tick(1.0, 0.5) # 회복 25/s * 0.5배 * 1.0s = 12.5
	assert_almost_eq(res.stamina, 62.5, 0.001, "가드 중 회복 배율(제안 0.5)이 반영돼야 한다")


func test_full_depletion_triggers_exhausted_penalty() -> void:
	var res := _make_resources()
	res.stamina = 20.0
	res.try_spend(20.0) # stamina=0 -> exhausted_penalty_sec(1.0) 적용
	res.tick(0.99)
	assert_almost_eq(res.stamina, 0.0, 0.001, "고갈 페널티(1.0s) 동안은 회복 재개 전")
	res.tick(1.0) # 대기(잔여 0.01s)를 정확히 소진하는 프레임 — 이 프레임엔 아직 회복 없음
	assert_almost_eq(res.stamina, 0.0, 0.001)
	res.tick(0.5) # 페널티(D-44: 1.0s) 종료 후 다음 프레임부터 회복 재개
	assert_true(res.stamina > 0.0, "페널티 종료 후에는 회복이 재개된다")


func test_partial_spend_uses_shorter_regen_delay_not_exhausted_penalty() -> void:
	var res := _make_resources()
	res.try_spend(20.0) # stamina=80 (고갈 아님) -> regen_delay_sec(0.5)만 적용
	res.tick(0.5) # 대기 소진
	res.tick(0.1) # 회복 시작(0.1s * 25 = 2.5)
	assert_almost_eq(res.stamina, 82.5, 0.001)


func test_take_damage_reports_death_at_zero_hp() -> void:
	var res := _make_resources()
	assert_false(res.take_damage(50))
	assert_true(res.take_damage(50), "HP가 정확히 0이 되면 사망으로 보고")
	assert_eq(res.hp, 0)


func test_heal_clamps_to_max_hp() -> void:
	var res := _make_resources()
	res.take_damage(90)
	res.heal(1000)
	assert_eq(res.hp, res.max_hp)


func test_roll_cost_with_dex_zero_is_unchanged() -> void:
	# D-45: DEX=0 경로(stats 시스템 미구현 시 기본값).
	assert_almost_eq(PlayerResourcesScript.roll_cost_with_dex(20.0, 0.0), 20.0, 0.001)


func test_roll_cost_with_dex_partial_reduction() -> void:
	# combat-tuning-m1.md §3-3: DEX 150 -> 상한 50% 경감.
	assert_almost_eq(PlayerResourcesScript.roll_cost_with_dex(20.0, 150.0), 10.0, 0.001)


func test_roll_cost_with_dex_caps_at_50_percent() -> void:
	# DEX가 상한(150)을 넘어도 경감률은 50%를 넘지 않는다.
	assert_almost_eq(PlayerResourcesScript.roll_cost_with_dex(20.0, 300.0), 10.0, 0.001)
	assert_almost_eq(PlayerResourcesScript.roll_cost_with_dex(20.0, 900.0), 10.0, 0.001)
