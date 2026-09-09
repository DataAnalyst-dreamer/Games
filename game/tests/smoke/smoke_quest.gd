## 헤드리스 스모크 테스트: 퀘스트 시스템 MQ01~MQ03을 실제 게임 신호로 진행(F5-1/F5-2,
## M2-7).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuest.tscn --quit-after 600
##
## GUT 유닛 테스트(test_quest_system.gd)는 QuestSystem 내부 필드(_completed 등)를 직접
## 조작해 선행 조건 체인을 건너뛰지만, 이 스모크는 실제 Main.tscn 플레이어/몬스터와
## 자동로드 싱글턴 QuestSystem을 그대로 써서 MQ01(talk+interact) -> MQ02(reach+talk) ->
## MQ03(kill×4, 실제 몬스터를 실제 히트박스로 처치)까지 순서대로 처음부터 끝까지
## 진행한다. talk/interact/reach는 아직 실제 트리거(NPC 대화/오브젝트 상호작용/장소
## 진입)가 레벨에 없어(_todo_ids.locations/.objects, level-designer 몫) Events를 직접
## emit해 "실제로 그 일이 일어났다"를 시뮬레이션하지만, kill만은 실제 HornRabbit 씬을
## 스폰해 Hitbox로 처치함으로써 monster_base.gd -> Events.monster_died -> QuestSystem
## 경로 전체가 진짜로 동작하는지 검증한다.
extends Node

const LETHAL_DAMAGE := 999

var _main: Node
var _player: Player

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE QUEST: MQ01~MQ03 실제 신호 진행(F5-1/F5-2) ===")
	QuestSystem.reset()
	_spawn_main()

	_run_mq01()
	_run_mq02()
	_run_mq03()

	print("=== SMOKE QUEST 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _spawn_main() -> void:
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	# 기존 몬스터가 우연히 horn_rabbit을 처치해 MQ03 카운트를 흐트러뜨리지 않도록 정리
	# (smoke_save_load.gd와 동일 패턴).
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


func _run_mq01() -> void:
	print("--- MQ01: quest_main_a1_01_arrival ---")
	_check("MQ01 초기 상태 available", QuestSystem.get_state("quest_main_a1_01_arrival") == "available")
	var accept_result: Dictionary = QuestSystem.accept("quest_main_a1_01_arrival")
	_check("MQ01 수주 성공", accept_result.get("ok", false))
	_check("MQ01 active", QuestSystem.get_state("quest_main_a1_01_arrival") == "active")

	Events.npc_talked.emit(&"teo") # obj_01: talk npc:teo
	_check("MQ01 obj_01(talk teo) 진행", QuestSystem.get_active_objective_index("quest_main_a1_01_arrival") == 1)

	Events.object_interacted.emit(&"cargo_pile") # obj_02: interact object:cargo_pile
	_check("MQ01 목표 완료 -> complete_ready(giver=teo, NPC라 자동완결 안 됨)",
		QuestSystem.get_state("quest_main_a1_01_arrival") == "complete_ready")

	var advance_result: Dictionary = QuestSystem.advance("quest_main_a1_01_arrival")
	_check("MQ01 턴인(advance) 성공", advance_result.get("ok", false))
	_check("MQ01 completed", QuestSystem.get_state("quest_main_a1_01_arrival") == "completed")


func _run_mq02() -> void:
	print("--- MQ02: quest_main_a1_02_firstlook ---")
	_check("MQ01 완료로 MQ02 available", QuestSystem.get_state("quest_main_a1_02_firstlook") == "available")
	QuestSystem.accept("quest_main_a1_02_firstlook")

	Events.location_reached.emit(&"heartland_dandelion_village") # obj_01: reach
	_check("MQ02 obj_01(reach village) 진행", QuestSystem.get_active_objective_index("quest_main_a1_02_firstlook") == 1)

	Events.npc_talked.emit(&"meru") # obj_02: talk npc:meru
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
		rabbit.set_physics_process(false) # AI가 스스로 움직이며 상태를 흔들지 않도록.

		var hitbox := Hitbox.new()
		hitbox.damage = LETHAL_DAMAGE
		add_child(hitbox)
		hitbox.activate()
		var hit_ok: bool = hitbox.try_hit(rabbit.hurtbox)
		hitbox.queue_free()

		_check("뿔토끼 #%d 실제 히트박스로 처치(Events.monster_died 경로)" % (i + 1), hit_ok)
		rabbit.queue_free()

	_check("MQ03 4마리 처치 후 giver=system이라 자동 완결(complete_ready 거치지 않고 completed)",
		QuestSystem.get_state("quest_main_a1_03_shadowfall") == "completed")
	_check("보상 반영: 골드 10 지급(누계는 다른 테스트 영향 배제 못하므로 최소 10 이상만 확인)",
		GameState.gold >= 10)
