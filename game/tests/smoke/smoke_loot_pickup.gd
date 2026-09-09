## 헤드리스 스모크 테스트: "슬라임 처치 → 드랍 스폰(LootSpawner) → 자동 획득
## (ItemDrop.body_entered) → GameState.inventory/gold 반영" 전체 파이프라인(M2-1, F3-1).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeLootPickup.tscn --quit-after 600
##
## 킬 타이밍은 SmokePlayerKillsSlime 시나리오 A(Slime1, 2타 사망)를 그대로 재사용한다.
extends Node

const OFFSET := Vector2(12, 0)

var _main: Node
var _player: Player
var _slime: MonsterBase

var _elapsed: float = 0.0
var _target_hit: int = 0
var _died: bool = false
var _gold_before: int = 0
var _finished: bool = false


func _ready() -> void:
	print("=== SMOKE LOOT PICKUP: 슬라임 처치 -> 드랍 스폰 -> 자동 획득 -> 인벤토리 반영 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_slime = _main.get_node("Slime1") as MonsterBase
	# 다른 몬스터는 간섭 방지를 위해 제거(SmokeMetrics와 동일 패턴).
	for name_ in ["Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1"]:
		var n: Node = _main.get_node(name_)
		if n != null:
			n.queue_free()

	_slime.set_physics_process(false)
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_slime.global_position = _player.global_position + OFFSET

	_gold_before = GameState.gold
	print("[SETUP] 슬라임 초기 HP=%d, 시작 골드=%d, 시작 인벤토리 슬롯=%d" \
		% [_slime.hp, _gold_before, GameState.inventory.slot_count()])

	Events.enemy_died.connect(_on_enemy_died)

	_press_attack()
	print("t=%.3f 1타 입력" % _elapsed)
	_target_hit = 2


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta

	if not _died:
		if is_instance_valid(_slime) and _slime.hp > 0:
			_slime.global_position = _player.global_position + OFFSET
		var attack_state = _player.state_machine.states.get(&"Attack")
		if attack_state != null and attack_state.combo != null and _player.state_machine.current_state == attack_state:
			var combo: ComboState = attack_state.combo
			if _target_hit > 0 and _target_hit <= combo.max_hits and combo.hit_index == _target_hit - 1 \
					and (combo.is_in_buffer_window() or combo.is_in_grace_window()):
				_press_attack()
				print("t=%.3f %d타 입력 (HP=%d)" % [_elapsed, _target_hit, _slime.hp])
				_target_hit += 1
	else:
		# 사망 후: LootSpawner가 스폰한 ItemDrop을 찾아 플레이어를 그 위로 옮겨 자동 획득을
		# 강제로 확정시킨다(산개 반경 안에 이미 있을 수도 있지만, 결정적 검증을 위해 직접 겹친다).
		var drop: ItemDrop = _find_item_drop()
		if drop != null and is_instance_valid(drop):
			_player.global_position = drop.global_position

	if _elapsed > 8.0 and not _finished:
		print("[TIMEOUT] 8초 초과 (died=%s)" % str(_died))
		_finish()


func _find_item_drop() -> ItemDrop:
	for child: Node in _main.get_children():
		if child is ItemDrop:
			return child
	return null


func _press_attack() -> void:
	var evt := InputEventAction.new()
	evt.action = "attack"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _on_enemy_died(enemy: Node2D, killer: Node) -> void:
	if enemy != _slime or _died:
		return
	_died = true
	print("[PASS] enemy_died 발신 확인: killer=%s (t=%.3f)" % [killer.name, _elapsed])
	# 골드는 즉시 지급(F3-1) — 아이템 자동 획득을 기다리지 않고 바로 확인 가능.
	print("[CHECK] 골드 변화: %d -> %d" % [_gold_before, GameState.gold])
	# 아이템 자동 획득까지는 한두 프레임 걸릴 수 있어(스폰 → 이동 → 겹침 판정) 매 프레임
	# 폴링하다가 인벤토리가 바뀌면 곧바로 끝낸다(_process()의 else 분기가 담당).
	await get_tree().create_timer(0.5).timeout
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var gold_ok: bool = GameState.gold > _gold_before
	var inventory_ok: bool = GameState.inventory.slot_count() > 0
	print("[CHECK] 골드 획득(즉시): %s (골드=%d)" % [str(gold_ok), GameState.gold])
	print("[CHECK] 인벤토리 슬롯 >0 (자동 획득): %s (슬롯=%d)" % [str(inventory_ok), GameState.inventory.slot_count()])
	if inventory_ok:
		var slot: Dictionary = GameState.inventory.slots[0]
		print("  획득 아이템: item_id=%s grade=%s quantity=%s" \
			% [slot.get("item_id"), slot.get("grade"), slot.get("quantity")])
	if _died and gold_ok and inventory_ok:
		print("[PASS] 드랍 생성 -> 자동 획득 -> 인벤토리/골드 반영 전체 파이프라인 확인")
	else:
		print("[FAIL] died=%s gold_ok=%s inventory_ok=%s" % [str(_died), str(gold_ok), str(inventory_ok)])
	print("=== SMOKE LOOT PICKUP 종료 ===")
	get_tree().quit()
