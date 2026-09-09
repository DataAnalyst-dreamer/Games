## 헤드리스 스모크 테스트: "고블린 정찰병 호루라기 → 아군(뿔토끼) 강제 CHASE".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeGoblinWhistle.tscn --quit-after 400
##
## Main.tscn의 GoblinScout1(220,-80)과 HornRabbit1(150,-30)은 기본 배치만으로도 서로
## whistle_range_px(140) 이내다. 플레이어를 GoblinScout1의 aggro_range_px(110) 안으로
## 이동시켜 CHASE를 유도하면, 쿨다운이 처음부터 0(준비됨)이라 곧바로 WHISTLE 시전 →
## 완료 시 아직 플레이어를 인지하지 못한(IDLE/PATROL) HornRabbit1이 강제로 CHASE
## 상태가 되어야 한다(elite-and-farming-m2.md §1-1-1).
extends Node

var _main: Node
var _player: Player
var _scout: MonsterBase
var _rabbit: MonsterBase

var _elapsed: float = 0.0
var _last_scout_state: int = -1
var _saw_whistle: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 고블린 정찰병 호루라기 → 아군 CHASE 강제 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_scout = _main.get_node("GoblinScout1") as MonsterBase
	_rabbit = _main.get_node("HornRabbit1") as MonsterBase
	for n in ["Slime1", "Slime2", "Slime3", "HornRabbit2", "Mushroom1", "GoblinScout2",
			"EliteGoblinCaptain1", "EliteBunchiSpawn1"]:
		var other := _main.get_node(n)
		if other != null:
			other.queue_free()

	print("scout aggro_range_px=%.1f whistle_range_px=%.1f whistle_cooldown_sec=%.1f pool=%s" \
		% [_scout.aggro_range_px, _scout.whistle_range_px, _scout.whistle_cooldown_sec, str(_scout.whistle_summon_pool)])
	print("초기 거리 scout<->rabbit=%.1f (whistle_range_px 이내여야 함)" \
		% _scout.global_position.distance_to(_rabbit.global_position))

	# aggro_range_px(110) 안, melee_range_px(90) 밖 — 정찰병 자신의 예고/공격보다 먼저
	# 호루라기 시전을 관찰할 여유를 준다.
	_player.global_position = _scout.global_position + Vector2(-100, 0)


func _process(delta: float) -> void:
	_elapsed += delta

	if _scout.state != _last_scout_state:
		print("t=%.3f scout 상태 전이 -> %s" % [_elapsed, MonsterBase.State.keys()[_scout.state]])
		if _scout.state == MonsterBase.State.WHISTLE:
			_saw_whistle = true
		_last_scout_state = _scout.state

	if _saw_whistle and _rabbit.state == MonsterBase.State.CHASE and not _done:
		print("t=%.3f [PASS] 호루라기 시전 확인 + HornRabbit1이 CHASE로 강제 전이됨" % _elapsed)
		_finish()
		return

	if _elapsed > 8.0 and not _done:
		print("[TIMEOUT] saw_whistle=%s rabbit_state=%s" \
			% [_saw_whistle, MonsterBase.State.keys()[_rabbit.state]])
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
