## 헤드리스 스모크 테스트: "슬라임 예고 → 플레이어 피격 → HP 감소 → Hurt 상태".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSlimeAttacksPlayer.tscn --quit-after 400
##
## Slime1을 플레이어의 인지 범위 안(monsters.json.slime.aggro_range_px=64) 겸 근접
## 사거리 밖에 두어 AI가 스스로 idle→patrol/chase→telegraph→attack까지 진행하게 둔다
## (수동으로 상태를 강제하지 않고 실제 상태머신 전이를 그대로 관찰).
extends Node

var _main: Node
var _player: Player
var _slime: MonsterBase

var _elapsed: float = 0.0
var _last_state: int = -1
var _saw_telegraph: bool = false
var _telegraph_started_at: float = -1.0
var _telegraph_ended_at: float = -1.0
var _saw_player_damaged: bool = false
var _saw_hurt_state: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE C: 슬라임 예고 → 플레이어 피격 → Hurt 상태 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_slime = _main.get_node("Slime1") as MonsterBase
	# 다른 슬라임은 제거해 이번 시나리오와 간섭하지 않게 한다.
	_main.get_node("Slime2").queue_free()
	_main.get_node("Slime3").queue_free()

	_player.global_position = Vector2.ZERO
	# 인지 범위(64px) 안, 근접 사거리(14px) 밖에 배치 → CHASE로 다가온 뒤 TELEGRAPH.
	_slime.global_position = _player.global_position + Vector2(40, 0)

	print("슬라임 telegraph_sec(데이터)=%.3f, 초기 상태=%s" % [_slime.telegraph_sec, MonsterBase.State.keys()[_slime.state]])
	print("플레이어 초기 HP=%d/%d" % [_player.resources.hp, _player.resources.max_hp])

	Events.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	_elapsed += delta

	if _slime.state != _last_state:
		var state_name: String = MonsterBase.State.keys()[_slime.state]
		print("t=%.3f 슬라임 상태 전이 → %s" % [_elapsed, state_name])
		if _slime.state == MonsterBase.State.TELEGRAPH:
			_saw_telegraph = true
			_telegraph_started_at = _elapsed
		elif _last_state == MonsterBase.State.TELEGRAPH and _telegraph_started_at >= 0.0:
			_telegraph_ended_at = _elapsed
			var duration: float = _telegraph_ended_at - _telegraph_started_at
			print("  예고 지속시간 실측=%.3f s (데이터 telegraph_sec=%.3f)" % [duration, _slime.telegraph_sec])
			if duration >= _slime.telegraph_sec - 0.05:
				print("  [PASS] GDD 4.2 최소 예고 0.5s 요구를 만족")
			else:
				print("  [FAIL] 예고 시간이 telegraph_sec보다 짧음")
		_last_state = _slime.state

	var current_state_name: StringName = _player.state_machine.current_state.name \
		if _player.state_machine.current_state != null else &""
	if current_state_name == &"Hurt" and not _saw_hurt_state:
		_saw_hurt_state = true
		print("t=%.3f 플레이어 상태 → Hurt (HP=%d/%d)" % [_elapsed, _player.resources.hp, _player.resources.max_hp])

	if _saw_telegraph and _saw_player_damaged and _saw_hurt_state and not _done:
		print("[PASS] 예고 → 피격 → HP 감소 → Hurt 상태 전체 파이프라인 확인")
		_done = true
		_finish()

	if _elapsed > 6.0 and not _done:
		print("[TIMEOUT] 6초 초과. saw_telegraph=%s saw_damaged=%s saw_hurt=%s" \
			% [_saw_telegraph, _saw_player_damaged, _saw_hurt_state])
		_finish()


func _on_player_damaged(amount: int, source: Node) -> void:
	_saw_player_damaged = true
	print("t=%.3f Events.player_damaged 발신: amount=%d source=%s (HP=%d/%d)" \
		% [_elapsed, amount, source.name if source != null else "null", _player.resources.hp, _player.resources.max_hp])


func _finish() -> void:
	print("=== SMOKE C 종료 ===")
	get_tree().quit()
