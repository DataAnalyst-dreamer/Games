## 헤드리스 스모크 테스트: "히트스톱 중 공격 입력 → 다음 타로 연결"(QA 리뷰 Major-2 회귀
## 방지, docs/qa/review-m1-1-m1-2.md).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeHitstopComboInput.tscn --quit-after 120
##
## 시나리오: 플레이어 1타가 슬라임에 적중해 히트스톱(combat.json hitstop.normal_sec=0.05s)이
## 걸리는 바로 그 프레임에 실제 "attack" InputEvent를 Input.parse_input_event()로 흘려
## Player._unhandled_input()이 여전히 호출되는지 확인한다. 수정 전(hit_feel.gd가 Player
## 노드 전체를 process_mode=DISABLED로 얼림)에는 이 이벤트가 통째로 유실되어 콤보가
## 1타에서 멈췄다 — 수정 후(스프라이트/무기만 얼림)에는 2타로 정상 연결되어야 한다.
extends Node

var _player: Player
var _slime: MonsterBase

var _elapsed: float = 0.0
var _hit_landed_at: float = -1.0
var _input_sent: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 히트스톱 중 공격 입력 → 콤보 연결(QA Major-2) ===")
	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	_player = player_scene.instantiate()
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT

	var slime_scene: PackedScene = load("res://scenes/entities/monsters/Slime.tscn")
	_slime = slime_scene.instantiate()
	add_child(_slime)
	# 플레이어 히트박스(위치 오프셋 10px, 반경 8px) 사거리 안, 슬라임 인지 범위 밖에 두어
	# 슬라임이 스스로 움직이지 않게 한다(이 테스트는 슬라임 AI가 아니라 플레이어 콤보/
	# 히트스톱 상호작용만 본다).
	_slime.global_position = Vector2(16, 0)

	Events.hit_landed.connect(_on_hit_landed)

	print("hitstop.normal_sec=%.3f, combo.input_buffer_sec=%.3f" \
		% [float(Data.get_value("combat", "hitstop.normal_sec")), float(Data.get_value("combat", "combo.input_buffer_sec"))])
	_player.state_machine.transition_to(&"Attack", {})


func _process(delta: float) -> void:
	_elapsed += delta

	if _hit_landed_at >= 0.0 and not _input_sent:
		_input_sent = true
		print("t=%.4f 1타 적중(히트스톱 진행 중으로 추정) — 이 프레임에 attack 입력 주입" % _elapsed)
		var ev := InputEventAction.new()
		ev.action = &"attack"
		ev.pressed = true
		Input.parse_input_event(ev)

	if _input_sent and not _done:
		# Attack 상태 스크립트에 class_name이 없어(공용 상태 패턴) 정적 타입 대신 Variant로
		# 받아 동적으로 .combo에 접근한다.
		var attack_state = _player.state_machine.states.get(&"Attack")
		var combo = attack_state.combo if attack_state != null else null
		if combo != null and combo.hit_index >= 2:
			print("t=%.4f [PASS] 콤보가 2타로 연결됨(hit_index=%d) — 히트스톱 중에도 입력이 유실되지 않았다" \
				% [_elapsed, combo.hit_index])
			_finish()
		elif _elapsed > _hit_landed_at + 0.5:
			print("t=%.4f [FAIL] 0.5s 동안 콤보가 2타로 연결되지 않음(hit_index=%s) — 입력 유실 회귀 의심" \
				% [_elapsed, combo.hit_index if combo != null else "?"])
			_finish()

	if _elapsed > 3.0 and not _done:
		print("[TIMEOUT] hit_landed_at=%.4f input_sent=%s" % [_hit_landed_at, _input_sent])
		_finish()


func _on_hit_landed(_attacker: Node, _target: Node, _damage: int, _is_advantage: bool, _is_critical: bool) -> void:
	if _hit_landed_at < 0.0:
		_hit_landed_at = _elapsed


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
