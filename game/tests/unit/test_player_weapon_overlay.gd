## D-127 회귀 방지 테스트(2차 재테스트 피드백: "칼(무기 오버레이)이 공격 중이 아닌
## 것으로 보이는 순간에도 캐릭터 몸에 이상하게 붙어있음").
##
## 원인: Player.play_attack_swing()이 만든 tween의 숨김 콜백(tween_callback)에만 의존해
## weapon_pivot.visible을 껐다 — 콤보가 3타까지 빠르게 이어지거나 구르기 캔슬/피격으로
## Attack 상태가 tween 완료 전에 exit()되면, 콜백이 실행되기 전에 다음 상태로 넘어가
## 무기가 계속 보이는 상태로 남을 수 있었다.
##
## 수정: Player.hide_weapon_overlay()가 진행 중인 tween을 kill하고 weapon_pivot.visible을
## 즉시 false로 만들며, Attack 상태 exit()에서 이를 호출한다(PlayerStateMachine.
## transition_to()는 상태를 벗어나는 모든 경로에서 반드시 exit()를 호출하므로, Attack을
## 벗어나는 모든 경우 — 피니셔 완주/구르기 캔슬/피격 — 를 이 한 곳에서 커버한다).
## 추가로 play_attack_swing() 자체도 이전 tween이 살아있으면 kill해 같은 노드에 tween이
## 겹쳐 걸리는 상황 자체를 없앤다.
extends GutTest

const PlayerScene := preload("res://scenes/player/Player.tscn")


func _make_player() -> Player:
	var player: Player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.facing = Vector2.DOWN
	return player


func test_attack_swing_makes_weapon_visible() -> void:
	var player := _make_player()
	player.state_machine.transition_to(&"Attack", {})
	assert_true(player.weapon_pivot.visible, "1타 스윙 시작 시 무기가 보여야 한다")


func test_hurt_transition_mid_swing_hides_weapon_immediately() -> void:
	# 재현 시나리오: 1타 스윙 tween이 아직 끝나지 않은 상태에서 피격 → Hurt 전이.
	var player := _make_player()
	player.state_machine.transition_to(&"Attack", {})
	assert_true(player.weapon_pivot.visible, "전제조건: 스윙 중에는 무기가 보여야 한다")

	player.state_machine.transition_to(&"Hurt", {})

	assert_false(player.weapon_pivot.visible,
		"tween이 끝나기 전에 Hurt로 전이해도 무기는 즉시 숨겨져야 한다")


func test_roll_cancel_mid_swing_hides_weapon_immediately() -> void:
	# 재현 시나리오: 피니셔 후딜 중 구르기 캔슬 → Roll 전이(exit()가 즉시 호출된다).
	var player := _make_player()
	player.state_machine.transition_to(&"Attack", {})
	assert_true(player.weapon_pivot.visible)

	player.state_machine.transition_to(&"Roll", {})

	assert_false(player.weapon_pivot.visible,
		"구르기 캔슬로 Attack을 벗어나도 무기는 즉시 숨겨져야 한다")


func test_fast_three_hit_combo_ends_with_weapon_hidden() -> void:
	# 콤보 1·2·3타를 각 hit_duration_sec보다 훨씬 짧은 간격으로 연속 진행시킨 뒤
	# (매번 play_attack_swing()이 새 tween을 만든다) 피니셔 종료(Idle 전이)까지 가도
	# 최종적으로 무기가 숨겨져야 한다.
	var player := _make_player()
	player.state_machine.transition_to(&"Attack", {})
	var attack_state = player.state_machine.states.get(&"Attack")
	assert_not_null(attack_state, "Attack 상태 노드가 있어야 한다")

	var tween_after_hit1: Tween = player._weapon_tween
	assert_true(player.weapon_pivot.visible)

	# 2타: 실제 입력 버퍼링 타이밍과 무관하게, hit_index만 진행시켜 _start_current_hit()가
	# play_attack_swing()을 다시 호출하는 상황(=이전 tween이 아직 안 끝난 채 재호출)을
	# 재현한다.
	attack_state.combo.hit_index = 2
	attack_state._start_current_hit()
	var tween_after_hit2: Tween = player._weapon_tween
	assert_true(player.weapon_pivot.visible, "2타 스윙 중에도 무기가 보여야 한다")
	assert_ne(tween_after_hit1, tween_after_hit2,
		"매 타마다 새 tween을 만들어야 한다(같은 노드에 tween이 겹치면 안 됨) — " +
		"player._weapon_tween이 항상 '현재' 진행 중인 tween 하나만 가리켜야 kill() 대상이 명확해진다")

	# 3타(피니셔).
	attack_state.combo.hit_index = 3
	attack_state._start_current_hit()
	assert_true(player.weapon_pivot.visible, "피니셔 스윙 중에도 무기가 보여야 한다")

	# 피니셔 후딜 종료로 콤보가 리셋되며 Idle로 전이하는 상황을 재현한다
	# (combo_state.gd: entered_finisher_recovery 이후 update()가 reset()과 함께
	# finished.emit(&"Idle", {})를 트리거).
	player.state_machine.transition_to(&"Idle", {})

	assert_false(player.weapon_pivot.visible,
		"3타를 매우 빠르게 이어도 피니셔 종료 후에는 무기가 숨겨져야 한다")


func test_hide_weapon_overlay_is_idempotent_and_safe_without_tween() -> void:
	var player := _make_player()
	# 공격을 시작하지 않은 상태(= _weapon_tween이 null)에서 호출해도 에러 없이 안전해야
	# 한다(Idle/Move/Guard 등 방어적 호출 지점 대비).
	player.hide_weapon_overlay()
	assert_false(player.weapon_pivot.visible)

	player.state_machine.transition_to(&"Attack", {})
	assert_true(player.weapon_pivot.visible)
	player.hide_weapon_overlay()
	assert_false(player.weapon_pivot.visible)
	# 두 번째 호출도 안전해야 한다.
	player.hide_weapon_overlay()
	assert_false(player.weapon_pivot.visible)
