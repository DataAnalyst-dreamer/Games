## 헤드리스 스모크 테스트: 하틀랜드 1막 퀘스트 배치(F5-1/F5-2, M2-8).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuestLayout.tscn --quit-after 600
##
## smoke_quest.gd(M2-7)는 Events를 직접 emit해 talk/reach/interact를 "시뮬레이션"했다
## (그 시점엔 실제 트리거가 레벨에 없었기 때문). 이 스모크는 M2-8이 만든 실제 배치를
## 그대로 쓴다:
##  1) Main.tscn을 인스턴스화하면 HartlandQuestLayer(quest_layout_spawner.gd)가
##     world_objects.json의 17개 항목(location 7 + object 5 + npc 5)을 실제로
##     스폰하는지 확인.
##  2) location 7개 전부에 대해 플레이어를 QuestTrigger의 실제 좌표로 순간이동시키고
##     물리 프레임을 기다려 Events.location_reached가 진짜 Area2D 겹침 판정으로
##     발신되는지 확인(스포너가 만든 노드를 직접 호출하는 게 아니라 실제 충돌 판정).
##  3) MQ01(talk+interact) -> MQ02(reach+talk) -> MQ03(kill×4)을 실제 QuestNpc/
##     QuestObject 노드의 talk()/interact() 공개 함수 + 실제 몬스터 히트박스로 순서대로
##     완료해, quest_layout_spawner.gd가 만든 배치가 QuestSystem과 실제로 맞물리는지
##     끝까지 검증한다.
extends Node

const LETHAL_DAMAGE := 999
## "heartland_dandelion_village"는 MQ02의 reach 목표가 실사용하므로 이 목록(일반
## 순회 검증 대상)에서는 제외한다 — one_shot=true라 여기서 먼저 소모해 버리면
## MQ02가 영영 진행되지 못한다(둘 다 "실제 물리 판정으로 location_reached가 뜨는지"를
## 확인하지만, 겹치지 않게 역할을 나눈다). 7개 location 전부는 이 목록(6개) + MQ02(1개)
## 로 합쳐 커버한다.
## "heartland_ward_stone"은 hartland.md 4절/quests-act1-hartland.md 그대로 결계석과
## 같은 물리 위치라 world_objects.json에서도 "heartland_dandelion_village_square"와
## 트리거 반경(28px)이 겹친다(의도된 설계 — 광장에 들어서면 둘 다 동시에 반응해야
## 자연스럽다). 그래서 순회 검증에서는 별도 항목으로 두지 않고 village_square를
## 밟을 때 동반 발신되는지 함께 확인한다(COMPANION_LOCATION_IDS).
const OTHER_LOCATION_IDS := [
	"bridgeport_dock", "heartland_dandelion_village_square",
	"heartland_echo_cave_entrance", "heartland_pasture_boundary",
	"heartland_hilltop_waypoint",
]
const COMPANION_LOCATION_IDS := {
	"heartland_dandelion_village_square": ["heartland_ward_stone"],
}

var _main: Node
var _player: Player
var _quest_layer: Node

var _pass_count: int = 0
var _fail_count: int = 0

var _reached_ids: Array = []


func _ready() -> void:
	print("=== SMOKE QUEST LAYOUT: world_objects.json 실배치 + MQ01~MQ03(M2-8) ===")
	QuestSystem.reset()
	_spawn_main()

	var world_object_entries: Dictionary = Data.table("world_objects")
	var real_entry_count := 0
	for object_id: String in world_object_entries:
		if not object_id.begins_with("_"):
			real_entry_count += 1
	_check("HartlandQuestLayer가 world_objects.json 17개(메타 _키 제외)를 전부 스폰",
		_quest_layer.spawned_by_id.size() == real_entry_count)

	Events.location_reached.connect(_on_location_reached)
	await _verify_other_location_triggers()
	Events.location_reached.disconnect(_on_location_reached)

	await _run_mq01()
	await _run_mq02() # 7번째 location(heartland_dandelion_village)은 여기서 실검증.
	_run_mq03()

	print("=== SMOKE QUEST LAYOUT 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _spawn_main() -> void:
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_quest_layer = _main.get_node("HartlandQuestLayer")
	# 기존 몬스터가 우연히 horn_rabbit을 처치해 MQ03 카운트를 흐트러뜨리지 않도록 정리
	# (smoke_quest.gd와 동일 패턴).
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


func _on_location_reached(location_id: StringName) -> void:
	_reached_ids.append(String(location_id))


## location 7개 중 MQ02가 쓰지 않는 6개를 순간이동 + 실제 Area2D 물리 판정으로
## 확인한다(지시사항 5 "플레이어를 각 location으로 순간이동 → location_reached 발신
## 확인"). 나머지 1개(heartland_dandelion_village)는 _run_mq02()가 실제 퀘스트 진행과
## 함께 검증한다.
func _verify_other_location_triggers() -> void:
	print("--- location 6개(MQ02 제외) 실제 트리거 검증 ---")
	for location_id in OTHER_LOCATION_IDS:
		var trigger: QuestTrigger = _quest_layer.spawned_by_id.get(location_id) as QuestTrigger
		_check("트리거 노드 존재: %s" % location_id, trigger != null)
		if trigger == null:
			continue
		_reached_ids.clear()
		_player.global_position = trigger.global_position
		# 순간이동만으로는 물리 서버가 아직 겹침을 계산하지 않았을 수 있어(테스트
		# 인프라 관례, smoke_save_load.gd 참고) 물리 프레임을 몇 번 기다린다.
		for i in 3:
			await get_tree().physics_frame
		_check("location_reached 발신: %s" % location_id, _reached_ids.has(location_id))
		for companion_id: String in (COMPANION_LOCATION_IDS.get(location_id, []) as Array):
			_check("location_reached 동반 발신(물리적으로 같은 장소): %s" % companion_id,
				_reached_ids.has(companion_id))


func _run_mq01() -> void:
	print("--- MQ01: quest_main_a1_01_arrival (실제 QuestNpc/QuestObject) ---")
	_check("MQ01 초기 상태 available", QuestSystem.get_state("quest_main_a1_01_arrival") == "available")
	var accept_result: Dictionary = QuestSystem.accept("quest_main_a1_01_arrival")
	_check("MQ01 수주 성공", accept_result.get("ok", false))

	var teo: QuestNpc = _quest_layer.spawned_by_id.get("teo") as QuestNpc
	_check("teo NPC 존재", teo != null)
	teo.talk() # obj_01: talk npc:teo
	_check("MQ01 obj_01(talk teo) 진행", QuestSystem.get_active_objective_index("quest_main_a1_01_arrival") == 1)

	var cargo_pile: QuestObject = _quest_layer.spawned_by_id.get("cargo_pile") as QuestObject
	_check("cargo_pile 오브젝트 존재", cargo_pile != null)
	cargo_pile.interact() # obj_02: interact object:cargo_pile
	_check("MQ01 목표 완료 -> complete_ready",
		QuestSystem.get_state("quest_main_a1_01_arrival") == "complete_ready")

	var advance_result: Dictionary = QuestSystem.advance("quest_main_a1_01_arrival")
	_check("MQ01 턴인 성공", advance_result.get("ok", false))
	_check("MQ01 completed", QuestSystem.get_state("quest_main_a1_01_arrival") == "completed")
	await get_tree().process_frame


func _run_mq02() -> void:
	print("--- MQ02: quest_main_a1_02_firstlook (실제 위치 이동 + QuestNpc) ---")
	_check("MQ01 완료로 MQ02 available", QuestSystem.get_state("quest_main_a1_02_firstlook") == "available")
	QuestSystem.accept("quest_main_a1_02_firstlook")

	var village_trigger: QuestTrigger = _quest_layer.spawned_by_id.get("heartland_dandelion_village") as QuestTrigger
	_reached_ids.clear()
	Events.location_reached.connect(_on_location_reached)
	_player.global_position = village_trigger.global_position
	for i in 3:
		await get_tree().physics_frame
	Events.location_reached.disconnect(_on_location_reached)
	_check("MQ02 obj_01(reach village) 실제 트리거로 진행",
		QuestSystem.get_active_objective_index("quest_main_a1_02_firstlook") == 1)

	var meru: QuestNpc = _quest_layer.spawned_by_id.get("meru") as QuestNpc
	_check("meru NPC 존재", meru != null)
	meru.talk() # obj_02: talk npc:meru
	_check("MQ02 complete_ready", QuestSystem.get_state("quest_main_a1_02_firstlook") == "complete_ready")

	QuestSystem.advance("quest_main_a1_02_firstlook")
	_check("MQ02 completed", QuestSystem.get_state("quest_main_a1_02_firstlook") == "completed")


func _run_mq03() -> void:
	print("--- MQ03: quest_main_a1_03_shadowfall (실제 몬스터 처치) ---")
	_check("MQ02 완료로 MQ03 available", QuestSystem.get_state("quest_main_a1_03_shadowfall") == "available")
	QuestSystem.accept("quest_main_a1_03_shadowfall")

	var rabbit_scene: PackedScene = load("res://scenes/entities/monsters/HornRabbit.tscn")
	for i in 4:
		var rabbit := rabbit_scene.instantiate() as MonsterBase
		add_child(rabbit)
		rabbit.global_position = Vector2(2000 + i * 40, 2000) # 플레이어/서로 겹치지 않는 먼 곳.
		rabbit.set_physics_process(false)

		var hitbox := Hitbox.new()
		hitbox.damage = LETHAL_DAMAGE
		add_child(hitbox)
		hitbox.activate()
		var hit_ok: bool = hitbox.try_hit(rabbit.hurtbox)
		hitbox.queue_free()

		_check("뿔토끼 #%d 실제 히트박스로 처치" % (i + 1), hit_ok)
		rabbit.queue_free()

	_check("MQ03 4마리 처치 후 자동 완결(giver=system)",
		QuestSystem.get_state("quest_main_a1_03_shadowfall") == "completed")
