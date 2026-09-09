## 헤드리스 스모크 테스트: "아이템 2개 지급 -> 메뉴 열기(paused 확인) -> 등급 필터 ->
## 장착 -> 스탯 반영 -> 닫기(unpaused)"(F7-2/F3-2, M2-2 태스크 6).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeInventoryMenu.tscn --quit-after 60
extends Node

var _main: Node
var _ui_root: UiRoot
var _player: Player


func _ready() -> void:
	print("=== SMOKE INVENTORY MENU: 지급 -> 열기(paused) -> 필터 -> 장착 -> 스탯 반영 -> 닫기(unpaused) ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_ui_root = _main.get_node("UiRoot") as UiRoot

	# 몬스터가 간섭하지 않도록 치운다(장착 전/후 상태 비교에 다른 요인이 섞이지 않게).
	for monster_name in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1"]:
		var m: Node = _main.get_node_or_null(monster_name)
		if m != null:
			m.queue_free()

	# 1) 아이템 2개 지급 — 서로 다른 등급이라야 필터가 의미 있게 갈린다.
	var weapon_def: Dictionary = Data.get_value("items", "weapon_common_1", {})
	var ring_def: Dictionary = Data.get_value("items", "ring_rare_1", {})
	if weapon_def.is_empty() or ring_def.is_empty():
		print("[FAIL] items.json에 weapon_common_1/ring_rare_1이 없음 — 테이블 확인 필요")
		get_tree().quit()
		return
	GameState.pickup_item({
		"uid": "smoke_inv_weapon", "item_id": "weapon_common_1", "grade": "common",
		"quantity": 1, "affixes": [], "enhance_level": 0, "refine_left": 0,
	}, weapon_def)
	GameState.pickup_item({
		"uid": "smoke_inv_ring", "item_id": "ring_rare_1", "grade": "rare",
		"quantity": 1, "affixes": [], "enhance_level": 0, "refine_left": 3,
	}, ring_def)
	print("지급 완료: 인벤토리 슬롯 수=%d" % GameState.inventory.slot_count())
	var pickup_ok: bool = GameState.inventory.slot_count() == 2

	# 2) 메뉴 열기 — paused 확인(D-24).
	_ui_root.open_menu()
	var open_ok: bool = _ui_root.is_menu_open() and get_tree().paused
	print("메뉴 열림 확인: is_menu_open=%s, tree.paused=%s" % [_ui_root.is_menu_open(), get_tree().paused])

	var menu: InventoryMenu = _ui_root.inventory_menu

	# 3) 등급 필터 — "rare"만 남기면 반지 1개만 보여야 한다.
	menu.set_grade_filter("rare")
	var filter_ok: bool = menu.visible_item_count() == 1
	print("필터(rare) 적용: 보이는 아이템 수=%d (기대 1)" % menu.visible_item_count())

	# 4) 장착 — 필터로 좁힌 rare 반지에 포커스를 맞추고 (A)와 같은 경로(confirm())로 장착.
	menu.focus_grid_at(0)
	menu.confirm()
	var ring_equipped_ok: bool = GameState.equipment.is_equipped("ring1")
	print("반지 장착 확인: ring1 장착됨=%s" % ring_equipped_ok)

	# 5) 필터를 전체로 되돌리고 남은 무기도 장착 -> 스탯 요약(공격력)에 반영되는지 확인.
	menu.set_grade_filter("")
	menu.focus_grid_at(0)
	menu.confirm()
	var weapon_equipped_ok: bool = GameState.equipment.is_equipped("weapon")
	var stats: Dictionary = Equipment.compute_stats(GameState.equipment.slots, Data.table("items"), Data.table("enhance"))
	var attack_reflected_ok: bool = float(stats.get("attack", 0.0)) > 0.0 \
		and menu.attack_label.text.contains(str(int(round(float(stats.get("attack", 0.0))))))
	print("무기 장착 확인: weapon 장착됨=%s, 스탯 라벨=\"%s\" (attack=%.2f)" \
		% [weapon_equipped_ok, menu.attack_label.text, float(stats.get("attack", 0.0))])

	# 6) 닫기 — unpaused 확인(D-24).
	_ui_root.close_menu()
	var close_ok: bool = not _ui_root.is_menu_open() and not get_tree().paused
	print("메뉴 닫힘 확인: is_menu_open=%s, tree.paused=%s" % [_ui_root.is_menu_open(), get_tree().paused])

	print("--- 결과 ---")
	var all_ok: bool = pickup_ok and open_ok and filter_ok and ring_equipped_ok \
		and weapon_equipped_ok and attack_reflected_ok and close_ok
	print(("지급=%s 열기=%s 필터=%s 반지장착=%s 무기장착=%s 스탯반영=%s 닫기=%s") % [
		pickup_ok, open_ok, filter_ok, ring_equipped_ok, weapon_equipped_ok, attack_reflected_ok, close_ok,
	])
	if all_ok:
		print("[PASS] 지급 -> 열기(paused) -> 필터 -> 장착 -> 스탯 반영 -> 닫기(unpaused) 전체 확인")
	else:
		print("[FAIL] 위 결과 중 false가 있음")
	get_tree().quit()
