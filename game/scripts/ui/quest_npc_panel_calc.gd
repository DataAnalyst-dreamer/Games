## quest_npc_panel.gd(D-258) 순수 계산 — 이 npc_id가 giver인 퀘스트 중 패널에 띄울
## 후보 1개를 고른다. Data/QuestSystem 싱글턴을 직접 참조하지 않고 전부 인자로 받아
## GUT에서 격리 테스트한다(quest_log_ui_calc.gd와 같은 관례).
##
## 우선순위(D-244, quest_npc.gd._refresh_marker()의 표식 우선순위와 동일 기준을 공유해야
## "표식은 ?인데 패널은 진행 중 퀘스트"라는 불일치를 피한다): 완료 보고 가능
## (complete_ready) > 수주 가능(available) > 진행 중(active). 같은 상태 안에서는
## quest_defs 등장 순서(데이터 파일 순서) 그대로 첫 항목을 쓴다.
class_name QuestNpcPanelCalc
extends RefCounted

const PRIORITY := ["complete_ready", "available", "active"]


## quest_defs: {quest_id: quest_def Dictionary}(Data.table("quests")와 같은 모양).
## states: {quest_id: String}(각 quest_id에 대한 QuestSystem.get_state() 결과).
## 반환: 후보 quest_id, 없으면 "".
static func candidate_quest_id(npc_id: String, quest_defs: Dictionary, states: Dictionary) -> String:
	var first_by_state := {"complete_ready": "", "available": "", "active": ""}
	for quest_id: String in quest_defs.keys():
		var qdef: Dictionary = quest_defs[quest_id]
		if String(qdef.get("giver", "")) != npc_id:
			continue
		var state: String = String(states.get(quest_id, "locked"))
		if first_by_state.has(state) and String(first_by_state[state]).is_empty():
			first_by_state[state] = quest_id
	for state: String in PRIORITY:
		if not String(first_by_state[state]).is_empty():
			return first_by_state[state]
	return ""
