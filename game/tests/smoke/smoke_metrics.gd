## 헤드리스 스모크 테스트: "플레이어 공격→슬라임 처치, 구르기 회피" 두 시나리오를 순서대로
## 재생한 뒤 Metrics.summary()가 그 결과를 정확히 집계했는지 확인한다(M1-4).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeMetrics.tscn --quit-after 900
##
## 시나리오 재사용: KILL 단계는 SmokePlayerKillsSlime 시나리오 A(Slime1, 2타 사망)를,
## ROLL 단계는 SmokeRollIframes(예고 시작 T-0.05초에 구르기)를 그대로 이 스크립트 안에
## 순서대로 재현한다 — 별개 몬스터(Slime1/Slime2)를 써서 두 시나리오가 서로 간섭하지
## 않게 한다.
extends Node

enum Phase { KILL, ROLL, DONE }

const OFFSET := Vector2(12, 0) ## 플레이어 기준 대상 위치(오른쪽, 사거리 안).

var _main: Node
var _player: Player
var _slime_kill: MonsterBase ## Slime1: 수동 콤보로 처치 (처치수·TTK 집계 검증용).
var _slime_roll: MonsterBase ## Slime2: AI 활성 → 자연 예고/공격 (구르기 성공률 집계 검증용).

var _phase: int = Phase.KILL
var _elapsed: float = 0.0
var _phase_elapsed: float = 0.0

# KILL 단계
var _target_hit: int = 0

# ROLL 단계
var _last_slime_state: int = -1
var _telegraph_started_at: float = -1.0
var _roll_target_time: float = -1.0
var _roll_pressed: bool = false


func _ready() -> void:
	print("=== SMOKE METRICS: Metrics.summary() 카운터/저장 검증 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_slime_kill = _main.get_node("Slime1") as MonsterBase
	_slime_roll = _main.get_node("Slime2") as MonsterBase
	_main.get_node("Slime3").queue_free()
	_main.get_node("HornRabbit1").queue_free()
	_main.get_node("HornRabbit2").queue_free()
	_main.get_node("Mushroom1").queue_free()

	# KILL 단계와 공간적으로 완전히 분리해 둔다 — AI가 활성 상태라 방치 시 순찰로
	# 조금씩 움직이지만 patrol_radius_px(수십 px) 범위 안이라 이 정도 거리면 간섭 없음.
	_slime_roll.global_position = Vector2(1000, 1000)

	_slime_kill.set_physics_process(false) # KILL 단계는 AI 끄고 피격 반응만 본다.
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_slime_kill.global_position = _player.global_position + OFFSET

	print("[KILL] 슬라임1 초기 HP=%d (TTK 목표 2타)" % _slime_kill.hp)
	Events.enemy_died.connect(_on_enemy_died)

	_press_attack()
	print("[KILL] t=%.3f 1타 입력" % _elapsed)
	_target_hit = 2


func _process(delta: float) -> void:
	_elapsed += delta
	_phase_elapsed += delta

	match _phase:
		Phase.KILL:
			_process_kill_phase()
		Phase.ROLL:
			_process_roll_phase()
		Phase.DONE:
			return

	if _elapsed > 15.0 and _phase != Phase.DONE:
		print("[TIMEOUT] 15초 초과 (phase=%d)" % _phase)
		_finish()


func _process_kill_phase() -> void:
	if is_instance_valid(_slime_kill) and _slime_kill.hp > 0:
		_slime_kill.global_position = _player.global_position + OFFSET

	var attack_state = _player.state_machine.states.get(&"Attack")
	if attack_state != null and attack_state.combo != null and _player.state_machine.current_state == attack_state:
		var combo: ComboState = attack_state.combo
		if _target_hit > 0 and _target_hit <= combo.max_hits and combo.hit_index == _target_hit - 1 \
				and (combo.is_in_buffer_window() or combo.is_in_grace_window()):
			_press_attack()
			print("[KILL] t=%.3f %d타 입력 (HP=%d)" % [_elapsed, _target_hit, _slime_kill.hp])
			_target_hit += 1

	if _phase_elapsed > 4.0:
		print("[KILL][FAIL] 4초 경과에도 사망 신호 없음 (HP=%d) — ROLL 단계로 강제 진행" % _slime_kill.hp)
		_start_roll_phase()


func _process_roll_phase() -> void:
	if _slime_roll.state != _last_slime_state:
		if _slime_roll.state == MonsterBase.State.TELEGRAPH:
			_telegraph_started_at = _phase_elapsed
			_roll_target_time = _telegraph_started_at + maxf(_slime_roll.telegraph_sec - 0.05, 0.0)
			print("[ROLL] t=%.3f 슬라임2 예고 시작 (구르기 목표=%.3f)" % [_phase_elapsed, _roll_target_time])
		_last_slime_state = _slime_roll.state

	if _telegraph_started_at >= 0.0 and not _roll_pressed and _phase_elapsed >= _roll_target_time:
		_press_roll()
		_roll_pressed = true
		print("[ROLL] t=%.3f 구르기 입력 발사" % _phase_elapsed)

	if _roll_pressed and _slime_roll.state != MonsterBase.State.ATTACK \
			and _slime_roll.state != MonsterBase.State.TELEGRAPH \
			and _phase_elapsed > _roll_target_time + 1.0:
		_finish()

	if _phase_elapsed > 8.0:
		print("[ROLL][FAIL] 8초 경과에도 시퀀스가 끝나지 않음 (roll_pressed=%s, state=%d)" \
			% [_roll_pressed, _slime_roll.state])
		_finish()


func _start_roll_phase() -> void:
	_phase = Phase.ROLL
	_phase_elapsed = 0.0

	# KILL 단계에서 진행 중이던 공격 상태를 정리하고 Idle로 되돌린다(SmokePlayerKillsSlime
	# 시나리오 전환과 동일한 패턴).
	var attack_state = _player.state_machine.states.get(&"Attack")
	if attack_state != null and attack_state.combo != null:
		attack_state.combo.reset()
	_player.velocity = Vector2.ZERO
	_player.state_machine.transition_to(&"Idle", {})

	_player.global_position = Vector2(500, 500)
	# 인지 범위(64px) 안, 근접 사거리(14px) 밖 → CHASE로 다가온 뒤 TELEGRAPH(SmokeRollIframes와 동일 배치).
	_slime_roll.global_position = _player.global_position + Vector2(40, 0)
	print("--- [ROLL] 단계 시작. 슬라임2 telegraph_sec(데이터)=%.3f ---" % _slime_roll.telegraph_sec)


func _press_attack() -> void:
	var evt := InputEventAction.new()
	evt.action = "attack"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _press_roll() -> void:
	var evt := InputEventAction.new()
	evt.action = "roll"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _on_enemy_died(enemy: Node2D, killer: Node) -> void:
	if _phase == Phase.KILL and enemy == _slime_kill:
		print("[KILL][PASS] enemy_died 발신 확인: killer=%s (t=%.3f, 남은 HP=%d)" \
			% [killer.name, _elapsed, _slime_kill.hp])
		_start_roll_phase()


func _finish() -> void:
	_phase = Phase.DONE
	var summary: Dictionary = Metrics.summary()
	print("--- Metrics.summary() (저장 전) ---")
	print(JSON.stringify(summary, "  "))

	# 5분 주기/종료 시 저장 로직을 헤드리스에서 즉시 트리거해 user://playtest/*.json이
	# 실제로 생성되는지 확인한다(요청 스펙 §5 "user://playtest/*.json이 실제로 생성되는지").
	Metrics._save_and_print()
	var saved_ok: bool = FileAccess.file_exists(Metrics._session_file_path)
	print("[FILE] 저장 파일 존재=%s 경로=%s" % [str(saved_ok), Metrics._session_file_path])

	var slime_stats: Dictionary = summary.get("monsters", {}).get("slime", {})
	var kill_ok: bool = int(slime_stats.get("kills", 0)) == 1
	var ttk_ok: bool = float(slime_stats.get("avg_ttk_sec", 0.0)) > 0.0
	var roll: Dictionary = summary.get("roll", {})
	var roll_ok: bool = int(roll.get("attempts", 0)) == 1 and int(roll.get("success", 0)) == 1 \
		and int(roll.get("iframe_hits", 0)) == 0

	print("[CHECK] kills(slime)==1: %s (실제=%d)" % [str(kill_ok), int(slime_stats.get("kills", 0))])
	print("[CHECK] avg_ttk_sec>0: %s (실제=%.3f)" % [str(ttk_ok), float(slime_stats.get("avg_ttk_sec", 0.0))])
	print("[CHECK] roll attempts=1 success=1 iframe_hits=0: %s (실제 attempts=%d success=%d iframe_hits=%d)" \
		% [str(roll_ok), int(roll.get("attempts", 0)), int(roll.get("success", 0)), int(roll.get("iframe_hits", 0))])

	if kill_ok and ttk_ok and roll_ok and saved_ok:
		print("[PASS] Metrics 카운터/저장 검증 통과")
	else:
		print("[FAIL] Metrics 카운터 또는 파일 저장 확인 필요")
	print("=== SMOKE METRICS 종료 ===")
	get_tree().quit()
