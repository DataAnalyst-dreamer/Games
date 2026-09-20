## 퀘스트 로그 화면(M3-2, D-153) 순수 계산. InventoryMenu "quest" 탭 구현인
## quest_log_tab.gd가 사용한다. Data/QuestSystem 싱글턴을 직접 참조하지 않고 전부
## 인자로 받아 GUT에서 격리 테스트한다(inventory_ui_calc.gd·inventory_focus_calc.gd와
## 같은 관례 — docs/ui/quest-log.md §2 참고).
class_name QuestLogUiCalc
extends RefCounted

const TABS: Array[String] = ["main", "side", "daily"]
const TYPE_TO_TAB := {"main": "main", "side": "side", "daily_template": "daily"}
## 로그에는 "이미 손댄" 퀘스트만 뜬다 — locked/available(아직 수주 전)은 목록에 없다.
## 데모에서 "목표가 안 보였다"는 피드백의 핵심 원인 중 하나가 이 구분 자체의 부재였으므로
## (완료 보고 참고), 상태는 아래 3개로 명시 고정한다.
const VISIBLE_STATES := ["active", "complete_ready", "completed"]


## quest_defs: {quest_id: quest_def Dictionary}(Data.table("quests")와 같은 모양).
## states: {quest_id: String}(각 quest_id에 대한 QuestSystem.get_state() 결과).
## 반환: {"main": Array[String], "side": Array[String], "daily": Array[String]} —
## quest_defs 등장 순서를 유지한다(정렬 기준 없음, 데이터 파일 순서 = 스토리 순서).
static func build_tab_lists(quest_defs: Dictionary, states: Dictionary) -> Dictionary:
	var result := {"main": [], "side": [], "daily": []}
	for quest_id: String in quest_defs.keys():
		var qdef: Dictionary = quest_defs[quest_id]
		var tab_id: String = String(TYPE_TO_TAB.get(String(qdef.get("type", "")), ""))
		if tab_id.is_empty():
			continue
		var state: String = String(states.get(quest_id, "locked"))
		if state in VISIBLE_STATES:
			(result[tab_id] as Array).append(quest_id)
	return result


## 처음 열었을 때 보여줄 탭 인덱스 — 비어있지 않은 첫 탭(보통 "main", MQ01 온보딩
## 자동수주 덕에 항상 최소 1개는 있다). 전부 비면 0("main")으로 둔다.
static func first_non_empty_tab(tab_lists: Dictionary) -> int:
	for i in TABS.size():
		if not (tab_lists.get(TABS[i], []) as Array).is_empty():
			return i
	return 0


## 탭 전환(delta=-1/+1)을 순환 적용.
static func wrap_tab_index(index: int, delta: int) -> int:
	return wrapi(index + delta, 0, TABS.size())


## 리스트 길이가 바뀐 뒤(탭 전환 등) 포커스 인덱스를 범위 안으로 되돌린다.
static func clamp_focus_index(index: int, list_size: int) -> int:
	if list_size <= 0:
		return 0
	return clampi(index, 0, list_size - 1)


## 목표 한 줄 표시 문자열. required<=1(talk/reach/interact 등 카운트 없는 목표)이면
## current를 0/1로 넘겨받아 "완료 여부"만 의미 있게 쓴다(QuestSystem의 기존 HUD 표시
## 규칙과 동일 — docs/specs/quest-system-m2.md §5).
static func format_objective_line(label: String, current: int, target: int) -> String:
	return "%s (%d/%d)" % [label, current, target]


## 목표 인덱스별 상태: idx < current_index면 "done", idx == current_index면 "current",
## 그 외(아직 도달 안 함)는 "pending".
static func objective_status(idx: int, current_index: int) -> String:
	if idx < current_index:
		return "done"
	if idx == current_index:
		return "current"
	return "pending"
