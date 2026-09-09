## 헤드리스 스모크 테스트: 세이브/로드 전체 파이프라인(F8-1, M2-6).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSaveLoad.tscn --quit-after 600
##
## 흐름:
##  1) 아이템 지급 -> 강화(+2) -> 장착 -> 비석 활성화 -> 피격(HP 변화) -> 이동 -> 저장.
##  2) Main 씬 전체를 새로 인스턴스화(= 앱 재시작 흉내)해 완전히 새 Player/Waystone
##     노드로 상태를 로드 -> 골드/인벤토리/장비 강화 단계/HP/위치/비석 활성화가 전부
##     복원되는지 확인(SaveManager._restore_waystones()가 waystone_id로 새 노드를
##     다시 찾아야 한다).
##  3) 체크섬 손상 시 .bak 자동 복구(F8-1 예외 규칙).
##  4) can_save() 거부(보스방/전투 중/사망 직후) — 이 조건에서는 파일이 쓰이지 않아야 함.
##  5) M2-7 신설: 퀘스트 수주 + 목표 1단계 진행 상태가 저장/로드 라운드트립에서
##     그대로 복원되는지(QuestSystem.to_dict()/from_dict()가 save_manager.gd 페이로드에
##     실제로 실려 있는지) 확인.
extends Node

const SLOT := 1
const STONE_ITEM_ID := "enhance_stone"
const WEAPON_UID := "u_smoke_save_weapon"
const LETHAL_TEST_DAMAGE := 15
const QUEST_ID := "quest_main_a1_01_arrival"

var _main: Node
var _player: Player
var _waystone: Waystone

var _pass_count: int = 0
var _fail_count: int = 0

var _snapshot_gold: int = 0
var _snapshot_hp: int = 0
var _snapshot_position: Vector2 = Vector2.ZERO
var _snapshot_enhance_level: int = 0


func _ready() -> void:
	print("=== SMOKE SAVE/LOAD: 세이브/로드 전체 파이프라인(F8-1) ===")
	SaveManager.delete(SLOT) # 이전 실행 잔여물 제거.
	QuestSystem.reset() # M2-7: 퀘스트 라운드트립도 깨끗한 상태에서 시작.
	_spawn_main()

	await _run_setup_and_save_flow()
	await _run_reload_flow()
	_run_corrupted_backup_flow()
	_run_can_save_rejection_flow()

	SaveManager.delete(SLOT)
	print("=== SMOKE SAVE/LOAD 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _spawn_main() -> void:
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_waystone = _main.get_node("Waystone1") as Waystone
	# 슬라임 등 몬스터 AI가 끼어들어 상태를 흔들지 않도록 제거(smoke_death_respawn.gd와 동일).
	for enemy_name in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1",
			"GoblinScout1", "GoblinScout2", "EliteGoblinCaptain1", "EliteBunchiSpawn1"]:
		var enemy: Node = _main.get_node_or_null(enemy_name)
		if enemy != null:
			enemy.queue_free()


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


# --- 1) 지급/강화/장착/비석 활성화/피격/이동 -> 저장 ---

func _run_setup_and_save_flow() -> void:
	GameState.gold = 0
	GameState.inventory.slots.clear()
	GameState.equipment = Equipment.new()
	GameState.mailbox = Mailbox.new()
	GameState.add_gold(5000)
	GameState.inventory.add_item(
		{"uid": "u_stone", "item_id": STONE_ITEM_ID, "quantity": 50},
		Data.get_value("items", STONE_ITEM_ID, {}))
	var weapon: Dictionary = {
		"uid": WEAPON_UID, "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}],
		"enhance_level": 0, "refine_left": 3, "locked": false,
	}
	GameState.inventory.slots.append(weapon)
	for _i in 2:
		GameState.blacksmith_enhance(WEAPON_UID)
	_check("강화 +2 도달", int(weapon.get("enhance_level", 0)) == 2)

	var weapon_index: int = GameState.inventory.find_by_uid(WEAPON_UID)
	_check("장착 성공", GameState.equip_from_slot(weapon_index, "weapon"))

	# 비석 활성화(오토세이브 트리거 F8-1 겸 last_waystone/activated_waystone_ids 기록).
	_player.global_position = _waystone.global_position
	var waited: float = 0.0
	while _waystone._player_inside != _player and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	var evt := InputEventAction.new()
	evt.action = "interact"
	evt.pressed = true
	Input.parse_input_event(evt)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("비석 활성화됨", _waystone.is_active and GameState.last_waystone == _waystone)

	# 논치명 피격으로 HP 변화(전투 중 저장 잠금 창은 즉시 초기화해 결정적으로 만든다 —
	# 실시간 대기는 IN_COMBAT_SAVE_LOCK_SEC만큼 느려지고 타이밍에 취약해진다).
	var hitbox := Hitbox.new()
	hitbox.team = &"enemy"
	hitbox.damage = LETHAL_TEST_DAMAGE
	add_child(hitbox)
	hitbox.activate()
	hitbox.try_hit(_player.hurtbox)
	hitbox.queue_free()
	GameState._last_combat_activity_sec = -1000.0 # 전투 판정 창 즉시 해제(위 주석 참고).
	_check("피격으로 HP 감소함", _player.resources.hp < _player.resources.max_hp)

	_player.global_position = Vector2(321.0, -87.0)

	# M2-7: 퀘스트 수주 + 목표 1단계(talk teo)까지 진행 후 저장 대상에 포함되는지 본다.
	var accept_result: Dictionary = QuestSystem.accept(QUEST_ID)
	_check("퀘스트 수주 성공(QUEST_ID)", accept_result.get("ok", false))
	Events.npc_talked.emit(&"teo")
	_check("퀘스트 목표 1단계까지 진행됨(저장 전)", QuestSystem.get_active_objective_index(QUEST_ID) == 1)

	_snapshot_gold = GameState.gold
	_snapshot_hp = _player.resources.hp
	_snapshot_position = _player.global_position
	_snapshot_enhance_level = int(weapon.get("enhance_level", 0))

	var save_result: Dictionary = SaveManager.save(SLOT, "manual")
	_check("저장 성공", save_result.get("ok", false))


# --- 2) Main 씬을 완전히 새로 인스턴스화(재시작 흉내) 후 로드 -> 복원 확인 ---

func _run_reload_flow() -> void:
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_spawn_main() # 완전히 새 Player/Waystone1(is_active=false로 초기화된 상태).
	_check("새 Player는 아직 초기 위치", _player.global_position != _snapshot_position)
	_check("새 Waystone1은 아직 비활성 상태", not _waystone.is_active)

	# M2-7: QuestSystem은 GameState/Waystone과 달리 씬 재생성으로는 초기화되지 않는
	# 진짜 프로세스 전역 오토로드라 "앱 재시작 흉내"를 완성하려면 명시적으로 비워야
	# 한다 — 이렇게 해야 아래 로드 검증이 "메모리에 이미 있던 값"이 아니라 실제로
	# 파일에서 복원됐음을 증명한다.
	QuestSystem.reset()
	_check("reset() 직후엔 퀘스트 상태 없음(로드 전 사전 확인)", QuestSystem.get_state(QUEST_ID) == "available")

	var load_result: Dictionary = SaveManager.load(SLOT, "manual")
	_check("로드 성공", load_result.get("ok", false))

	_check("골드 복원", GameState.gold == _snapshot_gold)
	var restored_weapon: Dictionary = GameState.equipment.slots.get("weapon", {})
	_check("장비 강화 단계 복원(+2)", int(restored_weapon.get("enhance_level", -1)) == _snapshot_enhance_level)
	_check("플레이어 위치 복원", _player.global_position.distance_to(_snapshot_position) < 0.5)
	_check("플레이어 HP 복원", _player.resources.hp == _snapshot_hp)
	_check("새 씬의 비석이 waystone_id로 다시 활성화됨", _waystone.is_active)
	_check("GameState.last_waystone이 새 비석 노드로 재연결됨", GameState.last_waystone == _waystone)
	_check("퀘스트 수주 상태 복원됨(QuestSystem.from_dict)", QuestSystem.get_state(QUEST_ID) == "active")
	_check("퀘스트 목표 진행도(1단계) 복원됨", QuestSystem.get_active_objective_index(QUEST_ID) == 1)


# --- 3) 체크섬 손상 -> .bak 자동 복구 ---

func _run_corrupted_backup_flow() -> void:
	GameState.gold = 111
	SaveManager.save(SLOT, "manual") # .bak = 이전(로드로 복원된) 상태.
	GameState.gold = 222
	SaveManager.save(SLOT, "manual") # 본 파일 = gold 222, .bak = gold 111.

	var path := "user://saves/slot%d_manual.json" % SLOT
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	var payload: Dictionary = parsed
	payload["checksum"] = "corrupted_on_purpose"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

	GameState.gold = 999
	var result: Dictionary = SaveManager.load(SLOT, "manual")
	_check("손상된 본 파일 -> .bak 복구로 로드 성공", result.get("ok", false))
	_check("복구된 값은 .bak(직전 저장, gold=111)과 일치", GameState.gold == 111)


# --- 4) can_save() 거부 사유(사망 직후/전투 중/보스방)는 파일을 건드리지 않는다 ---

func _run_can_save_rejection_flow() -> void:
	SaveManager.delete(SLOT)

	GameState.in_boss_encounter = true
	var boss_result: Dictionary = SaveManager.save(SLOT, "manual")
	_check("보스방에서는 저장 거부", not boss_result.get("ok", true) and boss_result.get("reason") == "boss_room")
	_check("보스방 거부 시 파일 생성 안 됨", not FileAccess.file_exists("user://saves/slot%d_manual.json" % SLOT))
	GameState.in_boss_encounter = false

	GameState.play_time_sec = 100.0
	GameState._last_combat_activity_sec = 99.0
	var combat_result: Dictionary = SaveManager.save(SLOT, "manual")
	_check("전투 중에는 저장 거부", not combat_result.get("ok", true) and combat_result.get("reason") == "in_combat")

	_player.is_dead = true
	GameState._last_combat_activity_sec = -1000.0
	var dead_result: Dictionary = SaveManager.save(SLOT, "manual")
	_check("사망 직후에는 저장 거부", not dead_result.get("ok", true) and dead_result.get("reason") == "player_dead")
	_player.is_dead = false
