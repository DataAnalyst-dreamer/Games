## 하틀랜드 1막 퀘스트 배치 스포너(M2-8, F5-1/F5-2).
##
## `game/data/world_objects.json`(Data.table("world_objects"))을 읽어 location/
## object/npc 3종 공통 씬(QuestTrigger/QuestObject/QuestNpc.tscn)을 인스턴스화하고
## 좌표를 대입한다 — 좌표를 Main.tscn에 하드코딩하지 않고 데이터 테이블 1곳에서만
## 관리한다(CLAUDE.md "밸런스 수치는 game/data 테이블로만" 원칙을 배치 좌표에도 적용).
##
## Main.tscn에는 이 스크립트를 붙인 노드 1개(HartlandQuestLayer)만 두고, 실제 자식
## 노드(비석/오브젝트/NPC)는 전부 런타임에 이 스크립트가 만든다 — BlacksmithNpc/
## MailboxNpc처럼 씬 파일에 개별로 손으로 배치하지 않는다(지시사항 3).
class_name QuestLayoutSpawner
extends Node2D

## kind -> 이 스크립트가 대입할 export 프로퍼티 이름(각 씬의 <kind>_id export와 매칭).
const ID_PROPERTY_BY_KIND := {
	"location": "location_id",
	"object": "object_id",
	"npc": "npc_id",
}

## 스폰된 노드를 id로 조회할 수 있게 보관(테스트·디버그용).
var spawned_by_id: Dictionary = {}


func _ready() -> void:
	spawn_all()


## 재호출 가능(테스트에서 world_objects.json을 바꾼 뒤 다시 스폰하는 경우 대비) —
## 기존에 스폰된 노드를 먼저 정리한다.
func spawn_all() -> void:
	for child: Node in get_children():
		child.queue_free()
	spawned_by_id.clear()

	var entries: Dictionary = Data.table("world_objects")
	for object_id: String in entries:
		if object_id.begins_with("_"):
			continue
		var entry: Variant = entries[object_id]
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("[QuestLayoutSpawner] world_objects.%s 가 객체가 아님 - 건너뜀" % object_id)
			continue
		_spawn_one(object_id, entry as Dictionary)


func _spawn_one(object_id: String, entry: Dictionary) -> void:
	var kind: String = String(entry.get("kind", ""))
	var scene_path: String = String(entry.get("scene", ""))
	var id_property: Variant = ID_PROPERTY_BY_KIND.get(kind)
	if id_property == null or scene_path.is_empty():
		push_warning("[QuestLayoutSpawner] world_objects.%s: kind '%s' 또는 scene 누락 - 건너뜀" % [object_id, kind])
		return

	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		push_warning("[QuestLayoutSpawner] world_objects.%s: 씬 로드 실패 '%s'" % [object_id, scene_path])
		return

	var instance: Node = packed_scene.instantiate()
	instance.name = object_id.to_pascal_case()
	instance.set(id_property, StringName(object_id))

	var position: Variant = entry.get("position", [0, 0])
	if typeof(position) == TYPE_ARRAY and (position as Array).size() >= 2:
		instance.position = Vector2(float(position[0]), float(position[1]))

	if entry.has("one_shot"):
		instance.set("one_shot", bool(entry["one_shot"]))
	if entry.has("vanish_on_complete"):
		instance.set("vanish_on_complete", bool(entry["vanish_on_complete"]))
	if entry.has("branch_quest_id"):
		instance.set("branch_quest_id", StringName(String(entry["branch_quest_id"])))
	if entry.has("branch_choice_id"):
		instance.set("branch_choice_id", StringName(String(entry["branch_choice_id"])))
	if kind == "npc" and entry.has("sprite"):
		var sprite_path: String = String(entry["sprite"])
		if not sprite_path.is_empty():
			var texture: Texture2D = load(sprite_path)
			if texture != null:
				instance.set("sprite_texture", texture)

	add_child(instance)
	spawned_by_id[object_id] = instance
