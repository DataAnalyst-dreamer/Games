## 추적 퀘스트 목표의 월드 좌표 조회(M4-2 hud_quest_tracker.gd에서 M5-2 hud_minimap.gd로
## 공유 확장). world_objects.json(kind: location/object/npc)을 훑어 quest_npc.gd/
## quest_object.gd가 표식(▼) 판정에 쓰는 것과 같은 공개 API(QuestSystem.get_active_
## reach/interact/talk_objective_keys + is_tracked_objective_key)로 현재 추적 목표와
## 일치하는 위치를 찾는다. kill(몬스터) 목표는 world_objects에 없어 위치가 없으므로
## 자동으로 null을 반환한다(요구사항 그대로).
##
## 원래 hud_quest_tracker.gd의 사설 메서드 하나였으나(M4-2) 미니맵(M5-2)도 같은 로직이
## 필요해져 이 파일로 승격했다 — quest_system.gd(이미 D-157 파일 상한 초과)로 옮기지
## 않고 별도 파일로 뺀 것은 코디네이터 지시(복붙 금지 + quest_system.gd 비대화 방지).
## Data/QuestSystem 살아있는 상태에 의존해 순수 함수는 아니다(quest_tracker_calc.gd/
## minimap_calc.gd 같은 순수 calc 파일과는 다른 성격 — 단순 순회 1회분이라 매 호출
## Data.table() 재조회 비용도 무시할 만한 수준, ponytail).
class_name QuestTargetLocator
extends RefCounted


static func find_tracked_target_position() -> Variant:
	if QuestSystem.get_tracked().is_empty():
		return null
	var world_objects: Dictionary = Data.table("world_objects")
	for id: String in world_objects.keys():
		if id.begins_with("_"):
			continue
		var entry: Dictionary = world_objects[id]
		var keys: Array[String] = []
		match String(entry.get("kind", "")):
			"location": keys = QuestSystem.get_active_reach_objective_keys(StringName(id))
			"object": keys = QuestSystem.get_active_interact_objective_keys(StringName(id))
			"npc": keys = QuestSystem.get_active_talk_objective_keys(StringName(id))
			_: continue
		if not QuestSystem.is_tracked_objective_key(keys):
			continue
		var pos: Array = entry.get("position", [])
		if pos.size() >= 2:
			return Vector2(float(pos[0]), float(pos[1]))
	return null
