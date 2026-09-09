## Mailbox(scripts/systems/mailbox.gd) 테스트 — push/claim 큐, D-10(보관 기한 없음:
## 인벤토리가 가득 차도 큐에 남아 재시도 가능), claim_all 일괄 수령(D-85).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const MailboxScript := preload("res://scripts/systems/mailbox.gd")
const InventoryScript := preload("res://scripts/systems/inventory.gd")

const MATERIAL_DEF := {"category": "material", "stack_max": 99}
const ITEMS_TABLE := {"iron_ore": MATERIAL_DEF}


func _make_mailbox() -> Mailbox:
	return MailboxScript.new()


func _make_inventory() -> Inventory:
	return InventoryScript.new()


func test_push_generates_id_when_missing() -> void:
	var mb: Mailbox = _make_mailbox()
	var entry: Dictionary = mb.push({"item_id": "iron_ore", "count": 3, "expires_day": null})
	assert_false(String(entry.get("id", "")).is_empty())
	assert_eq(mb.size(), 1)


func test_push_keeps_provided_id() -> void:
	var mb: Mailbox = _make_mailbox()
	var entry: Dictionary = mb.push({"id": "mail_fixed", "gold": 50})
	assert_eq(entry["id"], "mail_fixed")


func test_claim_not_found_returns_reason() -> void:
	var mb: Mailbox = _make_mailbox()
	var inv: Inventory = _make_inventory()
	var result: Dictionary = mb.claim("no_such_id", inv, ITEMS_TABLE)
	assert_false(result["ok"])
	assert_eq(result["reason"], "not_found")


func test_claim_gold_mail_succeeds_and_removes_from_queue() -> void:
	var mb: Mailbox = _make_mailbox()
	var inv: Inventory = _make_inventory()
	var entry: Dictionary = mb.push({"gold": 120})

	var result: Dictionary = mb.claim(String(entry["id"]), inv, ITEMS_TABLE)

	assert_true(result["ok"])
	assert_eq(result["kind"], "gold")
	assert_eq(result["amount"], 120)
	assert_eq(mb.size(), 0, "수령한 우편은 큐에서 제거돼야 함")


func test_claim_item_mail_adds_to_inventory_and_removes_from_queue() -> void:
	var mb: Mailbox = _make_mailbox()
	var inv: Inventory = _make_inventory()
	var entry: Dictionary = mb.push({"item_id": "iron_ore", "count": 5})

	var result: Dictionary = mb.claim(String(entry["id"]), inv, ITEMS_TABLE)

	assert_true(result["ok"])
	assert_eq(result["kind"], "item")
	assert_eq(result["count"], 5)
	assert_eq(inv.slot_count(), 1)
	assert_eq(int(inv.slots[0]["quantity"]), 5)
	assert_eq(mb.size(), 0)


func test_claim_item_mail_when_inventory_full_leaves_mail_in_queue() -> void:
	# D-10: "보관 기한 없음" — 인벤토리가 가득 차 못 받으면 큐에 남아 나중에 재시도할 수
	# 있어야 한다(마감으로 사라지면 안 됨).
	var mb: Mailbox = _make_mailbox()
	var inv: Inventory = _make_inventory()
	for i in inv.capacity():
		inv.add_item({"uid": "u_%d" % i, "item_id": "iron_ore", "quantity": 99}, MATERIAL_DEF)
	assert_true(inv.is_full())
	var entry: Dictionary = mb.push({"item_id": "iron_ore", "count": 1})

	var result: Dictionary = mb.claim(String(entry["id"]), inv, ITEMS_TABLE)

	assert_false(result["ok"])
	assert_eq(result["reason"], "inventory_full")
	assert_eq(mb.size(), 1, "실패한 우편은 큐에 그대로 남아야 함")


func test_claim_all_reports_claimed_and_failed_separately() -> void:
	var mb: Mailbox = _make_mailbox()
	var inv: Inventory = _make_inventory()
	mb.push({"gold": 10})
	mb.push({"item_id": "iron_ore", "count": 2})
	for i in inv.capacity():
		inv.add_item({"uid": "block_%d" % i, "item_id": "iron_ore", "quantity": 99}, MATERIAL_DEF)
	mb.push({"item_id": "iron_ore", "count": 1}) # 인벤토리가 이미 가득 차 실패할 우편.

	var result: Dictionary = mb.claim_all(inv, ITEMS_TABLE)

	assert_eq((result["claimed"] as Array).size(), 1, "골드 우편만 성공(아이템 우편은 인벤토리가 이미 꽉 참)")
	assert_eq((result["failed"] as Array).size(), 2)
	assert_eq(mb.size(), 2, "실패한 아이템 우편 2건은 큐에 남아야 함")


func test_to_dict_from_dict_round_trip() -> void:
	var mb: Mailbox = _make_mailbox()
	mb.push({"id": "mail_a", "gold": 30})
	var dict: Dictionary = mb.to_dict()

	var restored: Mailbox = _make_mailbox()
	restored.from_dict(dict)

	assert_eq(restored.size(), 1)
	assert_eq(String((restored.mails[0] as Dictionary).get("id", "")), "mail_a")
