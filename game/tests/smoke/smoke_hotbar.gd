## 헤드리스 스모크 테스트: M4-1 "핫바 9칸(스킬·아이템 혼용)"(D-175~D-177).
## Progression.assign_hotbar()/clear_hotbar() <-> GameState.hotbar/skill_slots/inventory <->
## 실제 Player 입력(state.gd:try_use_hotbar) 배선 전체를 실제 Main.tscn(Slime3 더미)으로
## 확인한다(순수 검증은 tests/unit/test_hotbar.gd가 맡는다 — 이 스모크는 배선만 본다).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeHotbar.tscn --quit-after 600
extends Node

const SKILL_ID := "blade_power_slash"
const ITEM_ID := "potion_hp_small"

var _player: Player
var _dummy: MonsterBase
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE HOTBAR: 스킬·아이템 혼용 9칸 배정/시전/사용 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)

	_player = main.get_node("Player") as Player
	_dummy = main.get_node("Slime3") as MonsterBase
	_dummy.set_physics_process(false)
	_dummy.hp = 99999
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_dummy.global_position = _player.global_position + Vector2(12, 0)

	await _check_skill_slot()
	_check_item_slot()

	print("=== SMOKE HOTBAR 종료: %s ===" % ("FAIL(%d)" % _fail_count if _fail_count > 0 else "ALL PASS"))
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _press_action(action: String) -> void:
	var evt := InputEventAction.new()
	evt.action = action
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## 스킬 배정(슬롯4=hotbar_5) -> hotbar_5 입력으로 실제 시전(더미 HP 감소) -> 쿨타임 왕복.
func _check_skill_slot() -> void:
	GameState.skill_points += 1
	var learned: bool = Progression.learn_skill(SKILL_ID)
	var assigned: bool = Progression.assign_hotbar(4, "skill", SKILL_ID)
	_check(learned and assigned and GameState.hotbar[4] == {"kind": "skill", "id": SKILL_ID},
		"스킬 배우기 + 핫바 슬롯4(hotbar_5) 배정")

	var hp_before: int = _dummy.hp
	_press_action("hotbar_5")
	await _wait_frames(6) # activate()의 call_deferred + area 재판정이 반영될 시간.
	_check(_dummy.hp < hp_before, "hotbar_5 입력으로 실제 시전(더미 HP 감소, %d -> %d)" % [hp_before, _dummy.hp])
	_check(not Progression.can_cast_skill(4), "시전 직후 슬롯4 쿨타임 중이라 재시전 불가")

	var entry: Dictionary = Data.get_value("skills", SKILL_ID, {})
	await get_tree().create_timer(float(entry.get("cooldown_sec", 0.0)) + 0.2).timeout
	_check(Progression.can_cast_skill(4), "쿨타임 만료 후 재시전 가능")


## 아이템 배정(슬롯6=hotbar_7) -> 재고 2개 -> hotbar_7 두 번 사용 -> 효과 적용 + 수량 감소 ->
## 재고 0 도달해도 슬롯 배정 자체는 유지된다(D-177, 회색 표시는 HUD 몫이라 여기서는 안 봄).
func _check_item_slot() -> void:
	var item_def: Dictionary = Data.get_value("items", ITEM_ID, {})
	GameState.pickup_item({"item_id": ITEM_ID, "quantity": 2}, item_def)
	var assigned: bool = Progression.assign_hotbar(6, "item", ITEM_ID)
	_check(assigned and GameState.hotbar[6] == {"kind": "item", "id": ITEM_ID},
		"소비품 획득(2개) + 핫바 슬롯6(hotbar_7) 배정")

	_player.resources.hp = 1 # heal_hp 효과가 실제로 적용됐는지 눈에 띄게 미리 깎아 둔다.
	_press_action("hotbar_7")
	_check(GameState.inventory.count_item(ITEM_ID) == 1, "1회 사용 후 재고 2 -> 1")
	_check(_player.resources.hp > 1, "heal_hp 효과 실제 적용(HP 회복, actual=%d)" % _player.resources.hp)

	_press_action("hotbar_7")
	_check(GameState.inventory.count_item(ITEM_ID) == 0, "2회 사용 후 재고 1 -> 0")
	_check(GameState.hotbar[6] == {"kind": "item", "id": ITEM_ID},
		"D-177: 재고 0이어도 핫바 슬롯 배정은 그대로 유지된다")

	_press_action("hotbar_7") # 재고 없음 -> 조용히 무시(크래시 없이 통과해야 함).
	_check(GameState.inventory.count_item(ITEM_ID) == 0, "재고 0에서 다시 눌러도 에러 없이 0 유지")
