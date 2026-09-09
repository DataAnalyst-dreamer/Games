## SaveManager(scripts/core/save_manager.gd) 테스트(F8-1, M2-6). 자동로드 싱글턴 하나뿐인
## 시스템이라(설정처럼) 실제 GameState/SaveManager 전역 상태를 그대로 쓰되, 매 테스트
## 전후로 건드린 필드를 저장/복원한다(test_elite_spawner.gd·test_settings.gd와 동일
## 패턴). 실제 user://saves/ 파일을 쓰므로 TEST_SLOT(=2, 디버그 F5/F9가 쓰는 슬롯1=index0
## 과 겹치지 않는 슬롯)만 사용하고 매 테스트 뒤 SaveManager.delete()로 정리한다.
extends GutTest

const TEST_SLOT := 2
const MATERIAL_DEF := {"category": "material", "stack_max": 99}
const WEAPON_DEF := {"category": "weapon", "grade": "uncommon", "base_stats": {"atk_min": 6, "atk_max": 8}}

var _saved_gold: int
var _saved_inventory_slots: Array
var _saved_equipment_slots: Dictionary
var _saved_mailbox_mails: Array
var _saved_play_time: float
var _saved_elite_respawn: Dictionary
var _saved_last_waystone: Node2D
var _saved_last_waystone_id: StringName
var _saved_activated_ids: Array
var _saved_in_boss: bool
var _saved_death_count: int
var _saved_last_combat: float
var _saved_player: Player


func before_each() -> void:
	_saved_gold = GameState.gold
	_saved_inventory_slots = GameState.inventory.slots.duplicate(true)
	_saved_equipment_slots = GameState.equipment.slots.duplicate(true)
	_saved_mailbox_mails = GameState.mailbox.mails.duplicate(true)
	_saved_play_time = GameState.play_time_sec
	_saved_elite_respawn = GameState.elite_respawn_remaining_sec.duplicate(true)
	_saved_last_waystone = GameState.last_waystone
	_saved_last_waystone_id = GameState.last_waystone_id
	_saved_activated_ids = GameState.activated_waystone_ids.duplicate()
	_saved_in_boss = GameState.in_boss_encounter
	_saved_death_count = GameState.death_count
	_saved_last_combat = GameState._last_combat_activity_sec
	_saved_player = GameState._player

	GameState.gold = 0
	GameState.inventory.slots.clear()
	GameState.equipment = Equipment.new()
	GameState.mailbox = Mailbox.new()
	GameState.play_time_sec = 0.0
	GameState.elite_respawn_remaining_sec.clear()
	GameState.last_waystone = null
	GameState.last_waystone_id = &""
	GameState.activated_waystone_ids.clear()
	GameState.in_boss_encounter = false
	GameState.death_count = 0
	GameState._last_combat_activity_sec = -1000.0
	GameState._player = null


func after_each() -> void:
	GameState.gold = _saved_gold
	GameState.inventory.slots = _saved_inventory_slots
	GameState.equipment.slots = _saved_equipment_slots
	GameState.mailbox.mails = _saved_mailbox_mails
	GameState.play_time_sec = _saved_play_time
	GameState.elite_respawn_remaining_sec = _saved_elite_respawn
	# 다른 테스트 파일이 같은 프로세스 안에서 GameState.last_waystone/_player에 남겨 둔
	# autofree 노드가 이미 해제됐을 수 있다 — Node 타입 프로퍼티에 해제된 참조를 그대로
	# 대입하면 엔진이 "previously freed"로 에러를 낸다(단순 대입도 유효성 검사 대상).
	GameState.last_waystone = _saved_last_waystone if is_instance_valid(_saved_last_waystone) else null
	GameState.last_waystone_id = _saved_last_waystone_id
	GameState.activated_waystone_ids = _saved_activated_ids
	GameState.in_boss_encounter = _saved_in_boss
	GameState.death_count = _saved_death_count
	GameState._last_combat_activity_sec = _saved_last_combat
	GameState._player = _saved_player if is_instance_valid(_saved_player) else null
	SaveManager.delete(TEST_SLOT)


func _weapon_instance(pending: bool = false) -> Dictionary:
	var affixes: Array = [{"stat_type": "atk_pct", "value": 0.1}]
	var item: Dictionary = {
		"uid": "u_weapon_1", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": affixes, "enhance_level": 3, "refine_left": 2, "locked": true,
	}
	if pending:
		item["_pending_affix"] = {
			"affix_index": 0,
			"new_affix": {"stat_type": "atk_pct", "value": 0.2},
			"old_affix": {"stat_type": "atk_pct", "value": 0.1},
		}
	return item


# --- 라운드트립 ---

func test_save_then_load_restores_identical_state() -> void:
	GameState.add_gold(777)
	GameState.pickup_item(
		{"uid": "u_ore", "item_id": "iron_ore", "grade": "common", "quantity": 5, "affixes": [], "enhance_level": 0, "refine_left": 0},
		MATERIAL_DEF)
	GameState.equipment.slots["weapon"] = _weapon_instance()
	GameState.mailbox.push({"gold": 50})
	GameState.play_time_sec = 1234.5
	GameState.elite_respawn_remaining_sec = {"elite_goblin_captain": 900.0}
	GameState.death_count = 3
	GameState.last_waystone_id = &"waystone_village"
	GameState.activated_waystone_ids = ["waystone_village"]

	var save_result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(save_result.get("ok", false), "정상 상태에서는 저장이 성공해야 함")

	# 저장 이후 상태를 완전히 바꿔서 load()가 실제로 되돌리는지 구분 가능하게 한다.
	GameState.gold = 1
	GameState.inventory.slots.clear()
	GameState.equipment = Equipment.new()
	GameState.mailbox = Mailbox.new()
	GameState.play_time_sec = 0.0
	GameState.elite_respawn_remaining_sec.clear()
	GameState.death_count = 0
	GameState.last_waystone_id = &""
	GameState.activated_waystone_ids.clear()

	var load_result: Dictionary = SaveManager.load(TEST_SLOT, "manual")
	assert_true(load_result.get("ok", false), "방금 저장한 슬롯 로드는 성공해야 함")

	assert_eq(GameState.gold, 777)
	assert_eq(GameState.inventory.slot_count(), 1)
	assert_eq(String(GameState.inventory.slots[0].get("item_id", "")), "iron_ore")
	assert_eq(int(GameState.inventory.slots[0].get("quantity", 0)), 5)

	var weapon: Dictionary = GameState.equipment.slots.get("weapon", {})
	assert_eq(String(weapon.get("uid", "")), "u_weapon_1")
	assert_eq(int(weapon.get("enhance_level", -1)), 3)
	assert_eq(int(weapon.get("refine_left", -1)), 2)
	assert_true(bool(weapon.get("locked", false)))
	assert_eq((weapon.get("affixes", []) as Array).size(), 1)

	assert_eq(GameState.mailbox.size(), 1)
	assert_almost_eq(GameState.play_time_sec, 1234.5, 0.001)
	assert_almost_eq(float(GameState.elite_respawn_remaining_sec.get("elite_goblin_captain", 0.0)), 900.0, 0.001)
	assert_eq(GameState.death_count, 3)
	assert_eq(String(GameState.last_waystone_id), "waystone_village")
	assert_true(GameState.activated_waystone_ids.has("waystone_village"))


func test_save_strips_pending_affix_before_writing_to_disk() -> void:
	GameState.equipment.slots["weapon"] = _weapon_instance(true)
	assert_true(GameState.equipment.slots["weapon"].has("_pending_affix"))

	var save_result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(save_result.get("ok", false))

	# 저장 전 강제 정리(auto_resolve_pending)는 인메모리 상태도 함께 바꾼다 — "미commit 시
	# 구 옵션 유지"(D-85)이므로 old_affix(0.1)가 그대로 남아야 한다.
	assert_false(GameState.equipment.slots["weapon"].has("_pending_affix"))
	assert_almost_eq(float(GameState.equipment.slots["weapon"]["affixes"][0]["value"]), 0.1, 0.001)

	# 디스크에 실제로 쓰인 JSON에도 _pending_affix가 없어야 한다(직렬화 대상 자체가 사라짐).
	var text: String = FileAccess.get_file_as_string("user://saves/slot%d_manual.json" % TEST_SLOT)
	assert_false(text.contains("_pending_affix"), "세이브 파일에 _pending_affix가 남으면 안 됨")


# --- 손상 → 백업 복구 ---

func test_load_falls_back_to_backup_on_checksum_mismatch() -> void:
	GameState.add_gold(100)
	var first: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(first.get("ok", false))

	GameState.gold = 999 # 두 번째 저장은 .bak으로 첫 번째 상태(gold=100)를 남긴다.
	var second: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(second.get("ok", false))

	var path := "user://saves/slot%d_manual.json" % TEST_SLOT
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Dictionary = JSON.parse_string(text)
	parsed["checksum"] = "tampered"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()

	GameState.gold = 1
	var load_result: Dictionary = SaveManager.load(TEST_SLOT, "manual")
	assert_true(load_result.get("ok", false), "본 파일이 손상돼도 .bak 복구로 성공해야 함")
	assert_eq(GameState.gold, 100, "백업(.bak)은 첫 번째 저장(gold=100) 상태여야 함")


func test_load_reports_not_found_when_neither_file_nor_backup_exist() -> void:
	var result: Dictionary = SaveManager.load(TEST_SLOT, "manual")
	assert_false(result.get("ok", true))
	assert_eq(String(result.get("reason", "")), "not_found")


# --- can_save() 거부 사유 (F8-1 "사망 직후·전투 중·보스방 저장 불가") ---

func test_save_rejected_in_boss_room() -> void:
	GameState.in_boss_encounter = true
	var result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_false(result.get("ok", true))
	assert_eq(String(result.get("reason", "")), "boss_room")
	assert_false(FileAccess.file_exists("user://saves/slot%d_manual.json" % TEST_SLOT))


func test_save_rejected_during_combat_window() -> void:
	GameState.play_time_sec = 10.0
	GameState._last_combat_activity_sec = 9.0 # Tuning.IN_COMBAT_SAVE_LOCK_SEC(5.0) 이내.
	var result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_false(result.get("ok", true))
	assert_eq(String(result.get("reason", "")), "in_combat")

	GameState.play_time_sec = 20.0 # 10초 경과 -> 전투 판정 창을 벗어남.
	var result2: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(result2.get("ok", false), "전투 판정 창을 벗어나면 저장 가능해야 함")


func test_save_rejected_when_player_is_dead() -> void:
	var fake_player := Player.new()
	fake_player.is_dead = true
	GameState._player = fake_player

	var result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_false(result.get("ok", true))
	assert_eq(String(result.get("reason", "")), "player_dead")

	fake_player.free()


# --- 잘못된 인자 ---

func test_save_and_load_reject_out_of_range_slot() -> void:
	var save_result: Dictionary = SaveManager.save(99, "manual")
	assert_false(save_result.get("ok", true))
	assert_eq(String(save_result.get("reason", "")), "invalid_slot")

	var load_result: Dictionary = SaveManager.load(-1, "manual")
	assert_false(load_result.get("ok", true))
	assert_eq(String(load_result.get("reason", "")), "invalid_slot")


func test_save_rejects_unknown_kind() -> void:
	var result: Dictionary = SaveManager.save(TEST_SLOT, "bogus")
	assert_false(result.get("ok", true))
	assert_eq(String(result.get("reason", "")), "invalid_kind")


# --- 슬롯 목록 메타 ---

func test_list_slots_reports_meta_for_saved_slot_and_null_for_empty_kind() -> void:
	GameState.play_time_sec = 42.0
	var save_result: Dictionary = SaveManager.save(TEST_SLOT, "manual")
	assert_true(save_result.get("ok", false))

	var slots: Array = SaveManager.list_slots()
	assert_eq(slots.size(), 3)
	var entry: Dictionary = slots[TEST_SLOT]
	assert_eq(int(entry["slot"]), TEST_SLOT)
	assert_null(entry["auto"], "오토세이브 파일이 없으면 null이어야 함")
	var meta: Dictionary = entry["manual"]
	assert_almost_eq(float(meta.get("playtime_sec", -1.0)), 42.0, 0.001)
	assert_true(meta.has("saved_at_unix"))
	assert_true(meta.has("region_id"))


func test_delete_removes_manual_auto_and_backup_files() -> void:
	SaveManager.save(TEST_SLOT, "manual")
	SaveManager.save(TEST_SLOT, "manual") # 두 번째 저장으로 .bak도 생성.
	SaveManager.save(TEST_SLOT, "auto")

	SaveManager.delete(TEST_SLOT)

	assert_false(FileAccess.file_exists("user://saves/slot%d_manual.json" % TEST_SLOT))
	assert_false(FileAccess.file_exists("user://saves/slot%d_manual.json.bak" % TEST_SLOT))
	assert_false(FileAccess.file_exists("user://saves/slot%d_auto.json" % TEST_SLOT))
