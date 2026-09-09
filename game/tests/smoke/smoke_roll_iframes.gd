## 헤드리스 스모크 테스트: "슬라임 공격 타이밍에 맞춰 구르기 → 무적으로 피해 0".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeRollIframes.tscn --quit-after 400
##
## docs/specs/combat-tuning-m1.md §2-2 계산: 적 예고 시작을 t=0, 적중을 t=T(=telegraph_sec)
## 라 하면 무적 구간 [t0, t0+0.3]이 공격 판정 활성 구간 전체 [T, T+A](A=MONSTER_ATTACK_
## ACTIVE_SEC=0.2)를 다 덮으려면 t0<=T 이고 t0+0.3>=T+A, 즉 t0 in [T+A-0.3, T].
## T=0.5, A=0.2 기준 유효 구간은 [0.4, 0.5](폭 0.1s)로 좁으므로, 프레임 단위 오차에 안전한
## 여유를 두기 위해 그 한가운데인 t0=T-0.05를 쓴다(양쪽에 0.05s씩 여유).
extends Node

var _main: Node
var _player: Player
var _slime: MonsterBase

var _elapsed: float = 0.0
var _last_state: int = -1
var _telegraph_started_at: float = -1.0
var _roll_target_time: float = -1.0
var _roll_pressed: bool = false
var _saw_roll_state: bool = false
var _saw_player_damaged: bool = false
var _initial_hp: int = 0
var _done: bool = false
## 슬라임의 공격 판정이 실제로 활성화된 프레임(state==ATTACK)마다 플레이어가 무적이었는지
## 직접 샘플링한다 — 위치가 우연히 벗어나 안 맞은 것이 아니라 무적 로직 자체가 구간을
## 덮었는지를 기하학적 우연과 무관하게 확인하기 위함.
var _saw_attack_active: bool = false
var _iframe_covered_attack: bool = true


func _ready() -> void:
	print("=== SMOKE D: 슬라임 공격 타이밍에 구르기 → 무적으로 피해 0 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_slime = _main.get_node("Slime1") as MonsterBase
	_main.get_node("Slime2").queue_free()
	_main.get_node("Slime3").queue_free()

	_player.global_position = Vector2.ZERO
	# 인지 범위(64px) 안, 근접 사거리(14px) 밖 → CHASE로 다가온 뒤 TELEGRAPH.
	_slime.global_position = _player.global_position + Vector2(40, 0)

	_initial_hp = _player.resources.hp
	print("슬라임 telegraph_sec(데이터)=%.3f, 플레이어 초기 HP=%d/%d" \
		% [_slime.telegraph_sec, _player.resources.hp, _player.resources.max_hp])

	Events.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_elapsed += delta

	if _slime.state != _last_state:
		if _slime.state == MonsterBase.State.TELEGRAPH:
			_telegraph_started_at = _elapsed
			_roll_target_time = _telegraph_started_at + maxf(_slime.telegraph_sec - 0.05, 0.0)
			print("t=%.3f 슬라임 예고 시작 (구르기 목표 시각=%.3f)" % [_elapsed, _roll_target_time])
		_last_state = _slime.state

	if _telegraph_started_at >= 0.0 and not _roll_pressed and _elapsed >= _roll_target_time:
		_press_roll()
		_roll_pressed = true
		print("t=%.3f 구르기 입력 발사" % _elapsed)

	var current_state_name: StringName = _player.state_machine.current_state.name \
		if _player.state_machine.current_state != null else &""
	if current_state_name == &"Roll" and not _saw_roll_state:
		_saw_roll_state = true
		print("t=%.3f 플레이어 상태 → Roll (hurtbox.invulnerable=%s)" \
			% [_elapsed, str(_player.hurtbox.invulnerable)])

	if _slime.state == MonsterBase.State.ATTACK:
		if not _saw_attack_active:
			_saw_attack_active = true
			print("t=%.3f 슬라임 공격 판정 활성화 (플레이어 hurtbox.invulnerable=%s)" \
				% [_elapsed, str(_player.hurtbox.invulnerable)])
		if not _player.hurtbox.invulnerable:
			_iframe_covered_attack = false

	# 슬라임이 공격 판정을 마치고 회복(CHASE/IDLE)으로 돌아간 뒤에도 잠깐 더 지켜본 다음 종료.
	if _roll_pressed and _slime.state != MonsterBase.State.ATTACK \
			and _elapsed > _roll_target_time + 1.0 and not _done:
		_finish()

	if _elapsed > 6.0 and not _done:
		print("[TIMEOUT] 6초 초과. roll_pressed=%s saw_roll_state=%s saw_damaged=%s" \
			% [_roll_pressed, _saw_roll_state, _saw_player_damaged])
		_finish()


func _press_roll() -> void:
	var evt := InputEventAction.new()
	evt.action = "roll"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _on_player_damaged(amount: int, source: Node) -> void:
	_saw_player_damaged = true
	print("t=%.3f [FAIL] Events.player_damaged 발신: amount=%d (무적 구간에 맞으면 안 됨)" \
		% [_elapsed, amount])


func _finish() -> void:
	print("--- 결과 ---")
	print("Roll 상태 진입 확인=%s, 공격판정 활성 목격=%s, 그 구간 내내 무적 유지=%s, 피격 발생=%s, HP=%d/%d(초기 %d)" \
		% [_saw_roll_state, _saw_attack_active, _iframe_covered_attack, _saw_player_damaged, \
			_player.resources.hp, _player.resources.max_hp, _initial_hp])
	if _saw_roll_state and _saw_attack_active and _iframe_covered_attack \
			and not _saw_player_damaged and _player.resources.hp == _initial_hp:
		print("[PASS] 구르기 무적 구간이 적 공격 판정 활성 구간 전체를 덮어 피해 0")
	else:
		print("[FAIL] 기대: Roll 진입 + 공격 활성 구간 내내 무적 + 무피해. 타이밍/무적 로직 확인 필요")
	print("=== SMOKE D 종료 ===")
	get_tree().quit()
