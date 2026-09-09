## 헤드리스 스모크 테스트: "HP 0 → 사망 연출 → 마지막 상호작용 비석 위치에서 HP 전량 부활"
## (F8-2, D-28).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeDeathRespawn.tscn --quit-after 400
##
## 1) 플레이어를 Main.tscn의 Waystone1 위로 옮기고 실제 Area2D 감지(body_entered)를
##    한 물리 프레임 기다린 뒤 "interact" 입력을 실제 엔진 입력 경로(Input.parse_input_
##    event → Waystone._unhandled_input)로 흘려 비석을 활성화한다.
## 2) 테스트 전용 즉사 히트박스(Hitbox.try_hit, test_hitbox.gd와 동일한 패턴)로 플레이어를
##    죽인다 — 몬스터 AI 타이밍에 의존하지 않고 "사망→부활" 파이프라인만 본다.
## 3) Dead 상태의 대기 타이머가 실제로 흐르는 것을 기다렸다가(엔진의 정상 _process 루프)
##    Player.respawn()이 비석 위치로 텔레포트하고 HP/스태미나를 전량 채우는지 확인한다.
extends Node

const LETHAL_DAMAGE := 9999

var _main: Node
var _player: Player
var _waystone: Waystone

var _elapsed: float = 0.0
var _phase: String = "move_to_waystone"
var _died_at: float = -1.0
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE E: HP 0 → 비석 위치 부활 → HP 전량 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_waystone = _main.get_node("Waystone1") as Waystone
	# 슬라임 AI가 끼어들지 않도록 제거 — 이 테스트는 사망/부활 파이프라인만 본다.
	_main.get_node("Slime1").queue_free()
	_main.get_node("Slime2").queue_free()
	_main.get_node("Slime3").queue_free()

	print("비석 위치=%s, 플레이어 초기 위치=%s, HP=%d/%d" \
		% [_waystone.global_position, _player.global_position, _player.resources.hp, _player.resources.max_hp])

	_player.global_position = _waystone.global_position


func _process(delta: float) -> void:
	_elapsed += delta

	match _phase:
		"move_to_waystone":
			# body_entered는 물리 프레임에 감지되므로 한 프레임 흘려보낸다.
			_phase = "wait_body_entered"
		"wait_body_entered":
			if _waystone._player_inside == _player:
				print("t=%.3f Waystone.body_entered 감지됨" % _elapsed)
				_phase = "press_interact"
			elif _elapsed > 1.0:
				print("[FAIL] 1초 내 body_entered 감지 안 됨")
				_finish()
		"press_interact":
			var evt := InputEventAction.new()
			evt.action = "interact"
			evt.pressed = true
			Input.parse_input_event(evt)
			_phase = "verify_activated"
		"verify_activated":
			if _waystone.is_active:
				print("t=%.3f 비석 활성화 확인 (GameState.last_waystone==waystone: %s)" \
					% [_elapsed, str(GameState.last_waystone == _waystone)])
				_phase = "apply_lethal_hit"
			elif _elapsed > 2.0:
				print("[FAIL] interact 입력 후에도 비석이 활성화되지 않음")
				_finish()
		"apply_lethal_hit":
			_apply_lethal_hit()
			_phase = "wait_dead_state"
		"wait_dead_state":
			var state_name: StringName = _player.state_machine.current_state.name \
				if _player.state_machine.current_state != null else &""
			if state_name == &"Dead":
				_died_at = _elapsed
				print("t=%.3f 플레이어 상태 → Dead (HP=%d)" % [_elapsed, _player.resources.hp])
				_phase = "wait_respawn"
			elif _elapsed > 3.0:
				print("[FAIL] 즉사 히트 후에도 Dead 상태로 전이하지 않음")
				_finish()
		"wait_respawn":
			if not _player.is_dead and _died_at >= 0.0:
				print("t=%.3f 부활 확인 (사망 후 %.3fs, 위치=%s, HP=%d/%d)" \
					% [_elapsed, _elapsed - _died_at, _player.global_position, _player.resources.hp, _player.resources.max_hp])
				_verify_and_finish()
			elif _elapsed - _died_at > 4.0:
				print("[FAIL] 사망 후 4초 내 부활하지 않음")
				_finish()

	if _elapsed > 10.0 and not _done:
		print("[TIMEOUT] 10초 초과 (phase=%s)" % _phase)
		_finish()


func _apply_lethal_hit() -> void:
	var hitbox := Hitbox.new()
	hitbox.team = &"enemy"
	hitbox.damage = LETHAL_DAMAGE
	add_child(hitbox)
	hitbox.activate()
	var hit: bool = hitbox.try_hit(_player.hurtbox)
	print("t=%.3f 즉사 히트박스 적용 (성공=%s, 데미지=%d)" % [_elapsed, str(hit), LETHAL_DAMAGE])
	hitbox.queue_free()


func _verify_and_finish() -> void:
	var pos_ok: bool = _player.global_position.distance_to(_waystone.global_position) < 1.0
	var hp_ok: bool = _player.resources.hp == _player.resources.max_hp
	var stamina_ok: bool = _player.resources.stamina == _player.resources.max_stamina
	var alive_ok: bool = not _player.is_dead
	print("검증: 위치=비석(%s) HP전량(%s) 스태미나전량(%s) 생존(%s)" \
		% [str(pos_ok), str(hp_ok), str(stamina_ok), str(alive_ok)])
	if pos_ok and hp_ok and stamina_ok and alive_ok:
		print("[PASS] 마지막 상호작용 비석 위치에서 HP/스태미나 전량으로 정상 부활(D-28)")
	else:
		print("[FAIL] 부활 위치/자원 회복이 기대와 다름")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE E 종료 ===")
	get_tree().quit()
