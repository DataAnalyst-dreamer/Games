## world_objects.json 로드 + QuestLayoutSpawner 인스턴스화 테스트(F5-1/F5-2, M2-8).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
##
## 세 가지를 확인한다:
## 1) world_objects.json이 스키마대로 로드되고(id 유일·kind별 개수) Data 검증 에러가 없다
##    (test_data.gd와 동일하게 새 Data 인스턴스로 디스크에서 다시 읽는다).
## 2) act1_hartland.json이 참조하는 모든 location:/object:/npc: id(+giver)가
##    world_objects.json에 실존한다 — Data._validate_quests()가 이미 하는 검사를
##    이 테스트에서도 명시적으로 재확인한다(지시사항 5 "퀘스트가 참조하는 id 커버리지").
## 3) QuestLayoutSpawner가 실제로 3종 공통 씬(QuestTrigger/QuestObject/QuestNpc)을
##    world_objects.json 그대로 인스턴스화하는지(개수·타입·좌표·export 값).
extends GutTest

const DataScript := preload("res://scripts/core/data.gd")
const SpawnerScript := preload("res://scripts/world/quest_layout_spawner.gd")

var _data: Node


func before_each() -> void:
	_data = DataScript.new()
	add_child_autofree(_data)


# --- 1) world_objects.json 스키마 ---

func test_world_objects_table_loads_with_no_validation_errors() -> void:
	assert_true(_data.tables.has("world_objects"), "world_objects.json 이 로드되어야 한다")
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])


func test_world_objects_counts_match_hartland_quest_layout() -> void:
	var entries: Dictionary = _data.table("world_objects")
	var by_kind: Dictionary = {"location": 0, "object": 0, "npc": 0}
	for object_id: String in entries:
		if object_id.begins_with("_"):
			continue
		var kind: String = String((entries[object_id] as Dictionary).get("kind", ""))
		by_kind[kind] = by_kind.get(kind, 0) + 1
		assert_eq(String((entries[object_id] as Dictionary).get("id", "")), object_id,
			"world_objects.%s: id 필드값이 키와 일치해야 한다" % object_id)

	assert_eq(by_kind["location"], 7, "hartland.md _todo_ids.locations 7개")
	assert_eq(by_kind["object"], 5, "hartland.md _todo_ids.objects 5개")
	assert_eq(by_kind["npc"], 5, "npc:dami/meru/pinto/rozel/teo 5인")


func test_expected_ids_present() -> void:
	var entries: Dictionary = _data.table("world_objects")
	var expected_locations := [
		"bridgeport_dock", "heartland_dandelion_village", "heartland_dandelion_village_square",
		"heartland_ward_stone", "heartland_echo_cave_entrance", "heartland_pasture_boundary",
		"heartland_hilltop_waypoint",
	]
	var expected_objects := [
		"cargo_pile", "ward_stone_dandelion", "echo_cave_puzzle_01", "montsil_rabbit", "waypoint_stone_01",
	]
	var expected_npcs := ["teo", "meru", "pinto", "rozel", "dami"]
	for id_ in expected_locations + expected_objects + expected_npcs:
		assert_true(entries.has(id_), "world_objects에 '%s' 가 있어야 한다" % id_)


# --- 2) act1_hartland.json이 참조하는 id 전부 실존 ---

func test_act1_hartland_quest_references_resolve_in_world_objects() -> void:
	var quests: Dictionary = _data.table("quests")
	var world_objects: Dictionary = _data.table("world_objects")
	var checked := 0
	for quest_id: String in quests:
		if quest_id.begins_with("_"):
			continue
		var quest: Dictionary = quests[quest_id]
		if String(quest.get("region", "")) != "heartland":
			continue
		for objective: Dictionary in (quest.get("objectives", []) as Array):
			var target: String = String(objective.get("target", ""))
			for prefix in ["location:", "object:", "npc:"]:
				if target.begins_with(prefix):
					var ref_id: String = target.substr(prefix.length())
					assert_true(world_objects.has(ref_id),
						"quests.%s objective target '%s' 가 world_objects에 있어야 한다" % [quest_id, target])
					checked += 1
		var giver: String = String(quest.get("giver", ""))
		if not giver.is_empty() and giver != "system":
			assert_true(world_objects.has(giver),
				"quests.%s giver '%s' 가 world_objects(npc)에 있어야 한다" % [quest_id, giver])
			checked += 1
	assert_gt(checked, 0, "실제로 검사한 참조가 1건 이상 있어야 한다(회귀 방지)")


func test_todo_ids_locations_and_objects_emptied() -> void:
	# M2-8: level-designer가 world_objects.json으로 채웠으니 act1_hartland.json의
	# _todo_ids.locations/.objects는 비어 있어야 한다(quest_todo_ids는 카테고리별 합집합).
	assert_eq((_data.quest_todo_ids.get("locations", []) as Array).size(), 0)
	assert_eq((_data.quest_todo_ids.get("objects", []) as Array).size(), 0)


# --- 3) QuestLayoutSpawner 인스턴스화 ---

func test_spawner_instantiates_all_entries_with_correct_kind_and_position() -> void:
	var spawner := SpawnerScript.new()
	add_child_autofree(spawner)
	# _ready()가 이미 spawn_all()을 호출했지만, 이 테스트의 Data는 오토로드가 아니라
	# 방금 만든 _data 인스턴스이므로(Data 오토로드는 그대로 살아있는 실제 싱글턴을
	# 스포너가 참조) 실제 게임과 동일하게 오토로드 Data.table("world_objects")를 쓴다.
	var entries: Dictionary = Data.table("world_objects")
	var real_entry_count := 0
	for object_id: String in entries:
		if not object_id.begins_with("_"):
			real_entry_count += 1
	assert_eq(spawner.spawned_by_id.size(), real_entry_count,
		"world_objects.json 항목 수(메타 _키 제외)만큼 자식이 스폰되어야 한다")

	var ward_stone: Node = spawner.spawned_by_id.get("heartland_ward_stone")
	assert_not_null(ward_stone, "heartland_ward_stone 트리거가 스폰되어야 한다")
	assert_true(ward_stone is QuestTrigger)
	assert_eq(String(ward_stone.location_id), "heartland_ward_stone")
	assert_eq(ward_stone.position, Vector2(-40, -100))

	var montsil: Node = spawner.spawned_by_id.get("montsil_rabbit")
	assert_not_null(montsil, "montsil_rabbit 오브젝트가 스폰되어야 한다")
	assert_true(montsil is QuestObject)
	assert_eq(String(montsil.object_id), "montsil_rabbit")
	assert_true(bool(montsil.one_shot))
	assert_true(bool(montsil.vanish_on_complete))
	assert_eq(String(montsil.branch_quest_id), "quest_side_heartland_montsil")
	assert_eq(String(montsil.branch_choice_id), "release")

	var teo: Node = spawner.spawned_by_id.get("teo")
	assert_not_null(teo, "teo NPC가 스폰되어야 한다")
	assert_true(teo is QuestNpc)
	assert_eq(String(teo.npc_id), "teo")
	assert_not_null(teo.sprite_texture, "teo에게 스프라이트 텍스처가 배정되어야 한다")


func test_spawner_spawn_all_is_idempotent() -> void:
	var spawner := SpawnerScript.new()
	add_child_autofree(spawner)
	var first_count: int = spawner.spawned_by_id.size()
	spawner.spawn_all()
	# spawn_all()은 이전 자식을 queue_free()로 지운다 — 실제 트리 반영은 다음 프레임
	# 이후라 spawned_by_id(동기 갱신)로 비교하고, get_child_count()는 한 프레임을
	# 기다린 뒤에도 부풀어 있지 않은지 별도로 확인한다.
	assert_eq(spawner.spawned_by_id.size(), first_count, "재호출해도 자식이 중복 누적되면 안 된다")
	await get_tree().process_frame
	assert_eq(spawner.get_child_count(), first_count, "queue_free 처리 후 실제 자식 수도 중복 누적되면 안 된다")
