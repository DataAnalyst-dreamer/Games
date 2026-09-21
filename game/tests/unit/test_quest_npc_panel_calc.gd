## QuestNpcPanelCalc(scripts/ui/quest_npc_panel_calc.gd) 테스트(D-258). 합성 데이터로
## giver 매칭·상태 우선순위(D-244)·테이블 순서 tie-break·매칭 없음을 확인하고,
## 실제 game/data/quests/ 테이블을 로드해 giver!="system"인 모든 NPC가 실제로 후보를
## 받을 수 있는지(회귀 가드) 검증한다.
extends GutTest


# --- 합성 데이터 ---

func test_picks_giver_match_only() -> void:
	var defs := {"q1": {"giver": "teo"}, "q2": {"giver": "dami"}}
	var states := {"q1": "available", "q2": "available"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("dami", defs, states), "q2")


func test_no_match_returns_empty() -> void:
	var defs := {"q1": {"giver": "teo"}}
	var states := {"q1": "available"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("dami", defs, states), "")


func test_excludes_locked_and_completed() -> void:
	var defs := {"q1": {"giver": "teo"}, "q2": {"giver": "teo"}}
	var states := {"q1": "locked", "q2": "completed"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("teo", defs, states), "",
		"locked/completed는 후보가 아니다")


func test_complete_ready_wins_over_earlier_active() -> void:
	# q1(active)이 테이블 순서상 앞이어도 q2(complete_ready)가 이긴다(D-244).
	var defs := {"q1": {"giver": "teo"}, "q2": {"giver": "teo"}}
	var states := {"q1": "active", "q2": "complete_ready"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("teo", defs, states), "q2")


func test_available_wins_over_active() -> void:
	var defs := {"q1": {"giver": "teo"}, "q2": {"giver": "teo"}}
	var states := {"q1": "active", "q2": "available"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("teo", defs, states), "q2")


func test_same_state_keeps_table_order() -> void:
	var defs := {"q1": {"giver": "teo"}, "q2": {"giver": "teo"}}
	var states := {"q1": "available", "q2": "available"}
	assert_eq(QuestNpcPanelCalc.candidate_quest_id("teo", defs, states), "q1")


# --- 실제 quests 테이블 커버리지(D-258: "테이블의 모든 퀘스트가 지원되는지") ---

func test_every_real_giver_gets_a_candidate_when_available() -> void:
	var quest_defs: Dictionary = Data.table("quests")
	assert_false(quest_defs.is_empty(), "game/data/quests/ 테이블이 비어있으면 이 테스트는 의미가 없다")
	var givers := {}
	for quest_id: String in quest_defs.keys():
		var giver := String((quest_defs[quest_id] as Dictionary).get("giver", ""))
		if giver.is_empty() or giver == "system":
			continue
		givers[giver] = true
	assert_gt(givers.size(), 0, "giver!=system인 퀘스트가 최소 1개는 있어야 한다")
	for giver: String in givers.keys():
		var states := {}
		for quest_id: String in quest_defs.keys():
			if String((quest_defs[quest_id] as Dictionary).get("giver", "")) == giver:
				states[quest_id] = "available"
		var candidate := QuestNpcPanelCalc.candidate_quest_id(giver, quest_defs, states)
		assert_false(candidate.is_empty(), "giver=%s는 available 상태에서 후보를 받아야 한다" % giver)
		assert_eq(String((quest_defs[candidate] as Dictionary).get("giver", "")), giver,
			"반환된 후보의 giver가 일치해야 한다")
