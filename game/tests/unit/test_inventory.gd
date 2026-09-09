## Inventory(scripts/systems/inventory.gd) 테스트 — 40칸(D-11), 스택 규칙, 가득 참,
## 자동 정렬. 순수 RefCounted라 Node 없이 직접 new()해서 테스트한다.
extends GutTest

const InventoryScript := preload("res://scripts/systems/inventory.gd")

const MATERIAL_DEF := {"category": "material", "stack_max": 99}
const CONSUMABLE_DEF := {"category": "consumable", "stack_max": 5}
const WEAPON_DEF := {"category": "weapon"}


func _make_material(item_id: String, qty: int) -> Dictionary:
	return {"uid": "u_%s_%d" % [item_id, qty], "item_id": item_id, "grade": "common", "quantity": qty, "affixes": [], "enhance_level": 0, "refine_left": 0}


func _make_equipment(item_id: String, grade: String) -> Dictionary:
	return {"uid": "u_%s" % item_id, "item_id": item_id, "grade": grade, "quantity": 1, "affixes": [], "enhance_level": 0, "refine_left": 0}


func test_capacity_defaults_to_40() -> void:
	var inv: Inventory = InventoryScript.new()
	assert_eq(inv.capacity(), 40)


func test_backpack_bonus_extends_capacity_up_to_80() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.set_backpack_bonus(40)
	assert_eq(inv.capacity(), 80)
	# D-11 상한(최대 80칸) — 그 이상은 클램프.
	inv.set_backpack_bonus(999)
	assert_eq(inv.capacity(), 80)


func test_add_item_new_slot_for_equipment() -> void:
	var inv: Inventory = InventoryScript.new()
	var result: Inventory.AddResult = inv.add_item(_make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	assert_eq(result, Inventory.AddResult.ADDED)
	assert_eq(inv.slot_count(), 1)


func test_add_item_equipment_never_stacks() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.add_item(_make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	inv.add_item(_make_equipment("weapon_common_1", "common"), WEAPON_DEF)
	assert_eq(inv.slot_count(), 2, "장비는 같은 item_id라도 개체마다 슬롯을 따로 차지해야 한다")


func test_add_item_stacks_materials_into_same_slot() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.add_item(_make_material("iron_ore", 3), MATERIAL_DEF)
	var result: Inventory.AddResult = inv.add_item(_make_material("iron_ore", 4), MATERIAL_DEF)
	assert_eq(result, Inventory.AddResult.STACKED)
	assert_eq(inv.slot_count(), 1)
	assert_eq(int(inv.slots[0]["quantity"]), 7)


func test_add_item_respects_stack_max_and_opens_new_slot() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.add_item(_make_material("potion", 5), CONSUMABLE_DEF) # stack_max=5, 꽉 참
	var result: Inventory.AddResult = inv.add_item(_make_material("potion", 3), CONSUMABLE_DEF)
	assert_eq(result, Inventory.AddResult.ADDED, "기존 슬롯이 가득 차면 새 슬롯을 열어야 한다")
	assert_eq(inv.slot_count(), 2)
	assert_eq(int(inv.slots[0]["quantity"]), 5)
	assert_eq(int(inv.slots[1]["quantity"]), 3)


func test_inventory_full_returns_full_and_does_not_mutate() -> void:
	var inv: Inventory = InventoryScript.new()
	for i in 40:
		inv.add_item(_make_equipment("weapon_%d" % i, "common"), WEAPON_DEF)
	assert_true(inv.is_full())
	var result: Inventory.AddResult = inv.add_item(_make_equipment("overflow_weapon", "common"), WEAPON_DEF)
	assert_eq(result, Inventory.AddResult.FULL)
	assert_eq(inv.slot_count(), 40, "가득 찬 상태에서 add_item()은 인벤토리를 바꾸지 않아야 한다(호출부가 우편함으로 돌림, D-10)")


func test_inventory_full_still_allows_stacking_into_existing_slot() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.add_item(_make_material("iron_ore", 1), MATERIAL_DEF)
	for i in 39:
		inv.add_item(_make_equipment("weapon_%d" % i, "common"), WEAPON_DEF)
	assert_true(inv.is_full())
	var result: Inventory.AddResult = inv.add_item(_make_material("iron_ore", 2), MATERIAL_DEF)
	assert_eq(result, Inventory.AddResult.STACKED, "가득 차 있어도 기존 스택에 합칠 자리가 있으면 성공해야 한다")
	assert_eq(int(inv.slots[0]["quantity"]), 3)


func test_sort_orders_by_grade_then_category_then_id() -> void:
	var inv: Inventory = InventoryScript.new()
	var items_table := {
		"ring_rare_1": {"category": "ring", "grade": "rare"},
		"weapon_common_2": {"category": "weapon", "grade": "common"},
		"weapon_common_1": {"category": "weapon", "grade": "common"},
		"armor_uncommon_1": {"category": "armor", "grade": "uncommon"},
	}
	inv.add_item(_make_equipment("ring_rare_1", "rare"), {"category": "ring"})
	inv.add_item(_make_equipment("weapon_common_2", "common"), {"category": "weapon"})
	inv.add_item(_make_equipment("armor_uncommon_1", "uncommon"), {"category": "armor"})
	inv.add_item(_make_equipment("weapon_common_1", "common"), {"category": "weapon"})

	inv.sort_slots(items_table)

	var ids: Array = []
	for slot: Dictionary in inv.slots:
		ids.append(String(slot["item_id"]))
	assert_eq(ids, ["weapon_common_1", "weapon_common_2", "armor_uncommon_1", "ring_rare_1"],
		"등급(common<uncommon<rare) -> 종류(weapon<armor<ring) -> id 순으로 정렬돼야 한다")


func test_to_dict_from_dict_round_trip() -> void:
	var inv: Inventory = InventoryScript.new()
	inv.set_backpack_bonus(25)
	inv.add_item(_make_material("iron_ore", 5), MATERIAL_DEF)
	var dict: Dictionary = inv.to_dict()

	var restored: Inventory = InventoryScript.new()
	restored.from_dict(dict)
	assert_eq(restored.capacity_bonus, 25)
	assert_eq(restored.slot_count(), 1)
	assert_eq(int(restored.slots[0]["quantity"]), 5)
