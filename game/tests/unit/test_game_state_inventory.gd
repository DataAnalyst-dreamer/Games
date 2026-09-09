## GameState(scripts/core/game_state.gd) 인벤토리/골드/우편함/장비 통합 테스트(M2-1,
## F3-1·F3-2, D-10). 자동로드 싱글턴 대신 새 인스턴스를 만들어 격리한다(test_game_state.gd
## 와 동일 패턴) — Events는 전역 공유라 각 테스트가 직접 연결한 콜백은 반드시 해제한다.
extends GutTest

const GameStateScript := preload("res://scripts/core/game_state.gd")

const MATERIAL_DEF := {"category": "material", "stack_max": 99}
const WEAPON_DEF := {"category": "weapon", "base_stats": {"atk_min": 3, "atk_max": 4}}
const RING_DEF := {"category": "ring", "base_stats": {"str": 2}}


func _make_material(item_id: String, qty: int) -> Dictionary:
	return {"uid": "u_%s" % item_id, "item_id": item_id, "grade": "common", "quantity": qty, "affixes": [], "enhance_level": 0, "refine_left": 0}


func _make_equipment(item_id: String, grade: String) -> Dictionary:
	return {"uid": "u_%s" % item_id, "item_id": item_id, "grade": grade, "quantity": 1, "affixes": [], "enhance_level": 0, "refine_left": 0}


func _make_game_state() -> Node:
	var gs := GameStateScript.new()
	add_child_autofree(gs)
	return gs


func test_add_gold_accumulates_and_emits_gold_changed() -> void:
	var gs := _make_game_state()
	var captured: Array = []
	var cb := func(new_amount: int, delta: int) -> void: captured.append([new_amount, delta])
	Events.gold_changed.connect(cb)
	gs.add_gold(30)
	gs.add_gold(5)
	Events.gold_changed.disconnect(cb)

	assert_eq(gs.gold, 35)
	assert_eq(captured, [[30, 30], [35, 5]])


func test_add_gold_zero_is_a_no_op() -> void:
	var gs := _make_game_state()
	var fired := false
	var cb := func(_a: int, _b: int) -> void: fired = true
	Events.gold_changed.connect(cb)
	gs.add_gold(0)
	Events.gold_changed.disconnect(cb)
	assert_false(fired)


func test_pickup_item_adds_to_inventory_and_emits_item_picked_up() -> void:
	var gs := _make_game_state()
	var captured: Array = []
	var cb := func(item_id: StringName, qty: int) -> void: captured.append([item_id, qty])
	Events.item_picked_up.connect(cb)
	gs.pickup_item(_make_material("iron_ore", 3), MATERIAL_DEF)
	Events.item_picked_up.disconnect(cb)

	assert_eq(gs.inventory.slot_count(), 1)
	assert_eq(captured.size(), 1)
	assert_eq(captured[0][0], &"iron_ore")
	assert_eq(captured[0][1], 3)


func test_pickup_item_when_inventory_full_routes_to_mailbox() -> void:
	var gs := _make_game_state()
	for i in gs.inventory.capacity():
		gs.inventory.add_item(_make_equipment("weapon_%d" % i, "common"), WEAPON_DEF)
	assert_true(gs.inventory.is_full())

	var mailed: Array = []
	var picked: Array = []
	var mail_cb := func(item_id: StringName, qty: int) -> void: mailed.append([item_id, qty])
	var pick_cb := func(item_id: StringName, qty: int) -> void: picked.append([item_id, qty])
	Events.item_mailed.connect(mail_cb)
	Events.item_picked_up.connect(pick_cb)
	gs.pickup_item(_make_material("overflow_ore", 1), MATERIAL_DEF)
	Events.item_mailed.disconnect(mail_cb)
	Events.item_picked_up.disconnect(pick_cb)

	assert_eq(mailed.size(), 1, "D-10: 가득 찬 인벤토리는 마을 우편함으로 자동 전송돼야 한다")
	assert_eq(mailed[0][0], &"overflow_ore")
	assert_eq(picked.size(), 0, "우편함으로 갔으면 item_picked_up은 발신되지 않아야 한다")
	assert_eq(gs.mailbox.size(), 1)
	assert_eq(gs.inventory.slot_count(), gs.inventory.capacity(), "우편함행 아이템이 인벤토리 슬롯을 차지하면 안 된다")


func test_equip_item_success_moves_slot_and_returns_true() -> void:
	var gs := _make_game_state()
	var ok: bool = gs.equip_item("weapon", _make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	assert_true(ok)
	assert_eq(String(gs.equipment.slots["weapon"].get("item_id")), "weapon_common_1")


func test_equip_item_wrong_category_rejected() -> void:
	var gs := _make_game_state()
	var ok: bool = gs.equip_item("weapon", _make_equipment("ring_common_1", "common"), RING_DEF)
	assert_false(ok)
	assert_true(gs.equipment.slots["weapon"].is_empty())


func test_equip_item_returns_previous_item_to_inventory() -> void:
	var gs := _make_game_state()
	gs.equip_item("weapon", _make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	gs.equip_item("weapon", _make_equipment("weapon_common_2", "common"), WEAPON_DEF)
	# 이전 무기가 인벤토리로 돌아왔어야 한다(장비는 스택하지 않으므로 슬롯 1개).
	assert_eq(gs.inventory.slot_count(), 1)
	assert_eq(String(gs.inventory.slots[0]["item_id"]), "weapon_common_1")


func test_unequip_item_returns_item_to_inventory() -> void:
	var gs := _make_game_state()
	gs.equip_item("weapon", _make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	var ok: bool = gs.unequip_item("weapon")
	assert_true(ok)
	assert_true(gs.equipment.slots["weapon"].is_empty())
	assert_eq(gs.inventory.slot_count(), 1)


func test_to_dict_from_dict_round_trip() -> void:
	var gs := _make_game_state()
	gs.add_gold(100)
	gs.pickup_item(_make_material("iron_ore", 2), MATERIAL_DEF)
	gs.equip_item("weapon", _make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	var dict: Dictionary = gs.to_dict()

	var restored := _make_game_state()
	restored.from_dict(dict)
	assert_eq(restored.gold, 100)
	assert_eq(restored.inventory.slot_count(), 1)
	assert_eq(String(restored.equipment.slots["weapon"].get("item_id")), "weapon_common_1")
