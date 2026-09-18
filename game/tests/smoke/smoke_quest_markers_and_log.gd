## 헤드리스 스모크 테스트: NPC 머리 위 퀘스트 표식(D-155) + 퀘스트 로그 탭(D-153/D-156).
##
## 실행: godot --headless --fixed-fps 60 --path game res://tests/smoke/SmokeQuestMarkersAndLog.tscn --quit-after 200
##
## smoke_quest.gd(M2-7)와 같은 방식으로 실제 Main.tscn 배치(HartlandQuestLayer)를 써서
## teo NPC 인스턴스를 직접 찾는다. QuestSystem.reset()으로 시작해(smoke_quest.gd와 동일
## 관례) MQ01을 처음부터 끝까지 진행하며 머리 위 표식이 !(수주 가능) -> ?(완료 보고
## 가능) -> !(다음 메인 퀘스트 MQ02 개방)로 바뀌는지 확인하고, 이어서 UiRoot를 통해
## 인벤토리 메뉴의 "quest" 탭을 열어 목록·추적 토글이 QuestSystem과 맞물리는지 본다.
extends Node

const Q1 := "quest_main_a1_01_arrival"

var _main: Node
var _layer: Node
var _teo: QuestNpc
var _ui: UiRoot

var _pass := 0
var _fail := 0


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass += 1
		print("[PASS] %s" % label)
	else:
		_fail += 1
		print("[FAIL] %s" % label)


func _ready() -> void:
	print("=== SMOKE QUEST MARKERS & LOG: 머리 위 표식 + 퀘스트 로그 탭 ===")
	QuestSystem.reset()

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_layer = _main.get_node("HartlandQuestLayer")
	_teo = _layer.spawned_by_id.get("teo") as QuestNpc
	_ui = _main.get_node("UiRoot") as UiRoot

	_check("스포너가 teo를 실제로 배치", _teo != null)
	_check("이 스모크는 current_scene이 아니라 Main이 자기 자신 하위라 온보딩 스킵",
		QuestSystem.get_state(Q1) == "available")

	_check("MQ01 available일 때 teo 표식=!", _teo.marker_visible() and _teo.marker_text() == "!")

	var accept_result: Dictionary = QuestSystem.accept(Q1)
	_check("MQ01 수주 성공", accept_result.get("ok", false))
	_check("수주 직후(available도 complete_ready도 아님)엔 표식 사라짐", not _teo.marker_visible())

	print("--- 퀘스트 로그 탭: active 상태에서 목록·자동 추적 ---")
	_ui.open_menu()
	_check("메뉴 열림", _ui.is_menu_open())
	_ui.inventory_menu.select_tab("quest")
	var log_tab: QuestLogTab = _ui.inventory_menu.quest_log_tab
	_check("quest 탭 표시 전환", log_tab.visible)
	_check("메인 탭에 활성 MQ01 표시", (log_tab._tab_lists.get("main", []) as Array).has(Q1))
	_check("활성 메인 퀘스트가 하나뿐이면 자동 추적 대상이 됨(override 없이도)",
		QuestSystem.get_tracked() == Q1)
	log_tab._toggle_tracking() # focus_index 0 = Q1, 이미 추적 중이므로 해제 시도.
	_check("추적 해제해도 활성 메인이 이거 하나뿐이라 자동 폴백으로 다시 Q1",
		QuestSystem.get_tracked() == Q1)

	print("--- 표식: 완료 보고 가능(?) -> MQ02 개방(!) ---")
	Events.npc_talked.emit(&"teo")
	Events.object_interacted.emit(&"cargo_pile")
	_check("MQ01 complete_ready 도달", QuestSystem.get_state(Q1) == "complete_ready")
	_check("complete_ready일 때 teo 표식=?", _teo.marker_visible() and _teo.marker_text() == "?")

	var advance_result: Dictionary = QuestSystem.advance(Q1)
	_check("MQ01 턴인 성공", advance_result.get("ok", false))
	_check("MQ02 즉시 개방(prerequisites 충족)으로 teo 표식 다시 !",
		_teo.marker_visible() and _teo.marker_text() == "!")

	_check("완료된 MQ01은 여전히 로그(메인 탭)에 completed로 남음",
		(log_tab._tab_lists.get("main", []) as Array).has(Q1))
	_check("활성 퀘스트가 없어졌으니 추적 대상도 빈 문자열로 폴백", QuestSystem.get_tracked() == "")
	QuestSystem.set_tracked(Q1) # 더 이상 활성이 아니므로 가드에 걸려 무시되어야 함.
	_check("완료(비활성) 퀘스트는 수동 추적으로 설정되지 않음", QuestSystem.get_tracked() == "")

	print("=== SMOKE 종료: PASS=%d FAIL=%d ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
