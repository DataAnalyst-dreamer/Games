## 헤드리스 스모크 테스트: "버섯돌이 포자 장판(spore_patch) — 무적 중에도 지속 피해 적용".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeMushroomAoE.tscn --quit-after 400
##
## Mushroom1을 플레이어 근접 사거리(melee_range_px=20) 안에 두어 접촉 즉시 피해(atk=12)가
## 들어가는 것을 먼저 확인한 뒤, 플레이어에게 긴 무적(Player.start_iframes)을 강제로 걸고도
## 포자 장판 틱(atk_tick_per_sec=4, Hitbox.ignores_iframes 경로)이 HP를 계속 깎는지
## 확인한다(addendum §2-2, D-61 예정 — "위험 지역에 서 있는 대가"는 무적으로 막을 수 없다).
extends Node

var _main: Node
var _player: Player
var _mushroom: MonsterBase

var _elapsed: float = 0.0
var _last_state: int = -1
var _hp_before_contact: int = 0
var _hp_after_contact: int = -1
var _iframes_forced: bool = false
var _hp_at_iframes_start: int = -1
var _saw_tick_during_iframes: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 버섯돌이 포자 장판(spore_patch) — 무적 중 지속 피해(D-61) ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_mushroom = _main.get_node("Mushroom1") as MonsterBase
	for n in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2"]:
		var other := _main.get_node(n)
		if other != null:
			other.queue_free()

	_player.global_position = _mushroom.global_position + Vector2(10, 0)
	_hp_before_contact = _player.resources.hp

	print("초기 플레이어 HP=%d, 버섯돌이 atk=%d atk_tick_per_sec=%.1f aoe_radius_px=%.1f melee_range_px=%.1f" \
		% [_hp_before_contact, _mushroom.atk, _mushroom.atk_tick_per_sec, _mushroom.aoe_radius_px, _mushroom.melee_range_px])


func _process(delta: float) -> void:
	_elapsed += delta

	if _mushroom.state != _last_state:
		print("t=%.3f 버섯돌이 상태 전이 -> %s" % [_elapsed, MonsterBase.State.keys()[_mushroom.state]])
		_last_state = _mushroom.state

	if _hp_after_contact < 0 and _player.resources.hp < _hp_before_contact:
		_hp_after_contact = _player.resources.hp
		print("t=%.3f 접촉 피해 적용됨: HP %d -> %d" % [_elapsed, _hp_before_contact, _hp_after_contact])

	if _hp_after_contact >= 0 and not _iframes_forced:
		_iframes_forced = true
		_player.start_iframes(3.0)
		_hp_at_iframes_start = _player.resources.hp
		print("t=%.3f 무적 강제 적용(3.0s), HP=%d, hurtbox.invulnerable=%s" \
			% [_elapsed, _hp_at_iframes_start, _player.hurtbox.invulnerable])

	if _iframes_forced and not _saw_tick_during_iframes and _player.resources.hp < _hp_at_iframes_start:
		_saw_tick_during_iframes = true
		print("t=%.3f [PASS] 무적 상태(invulnerable=%s)에서도 장판 틱 피해 적용됨: HP %d -> %d" \
			% [_elapsed, _player.hurtbox.invulnerable, _hp_at_iframes_start, _player.resources.hp])
		_finish()

	if _elapsed > 5.0 and not _done:
		print("[TIMEOUT] hp_after_contact=%s saw_tick_during_iframes=%s" % [_hp_after_contact, _saw_tick_during_iframes])
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
