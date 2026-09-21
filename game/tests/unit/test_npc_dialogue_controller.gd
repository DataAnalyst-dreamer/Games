## NpcDialogueController 입력 중재·재개·재진입 GUT 테스트(§9.6, D-254/D-259/D-265).
##
## 이 리눅스 워크트리에서 smoke_quest_npc_panel.gd 등 3종이 격리 경로 가드로
## 결정론적 quit(1)하기 때문에(D-265) 이 3개가 사실상 유일한 자동 검증 수단이다.
## `UiRoot.tscn`(실제 씬)만 인스턴스화하고 Main.tscn/Player는 필요 없다 — `UiRoot._ready()`
## 가 이미 `NpcDialogueController`를 자식으로 붙여준다(ui_root.gd 참고).
##
## teo(이미 `QuestNpcPanel.SUPPORTED`)만으로 검증한다 — dami 등 나머지 8퀘스트의
## `SUPPORTED` 확장(D-258)은 워크스트림 B 소관이며 이 테스트는 그 완료를 기다리지 않는다.
## `npc_teo.dialogue`(giver 원고)는 이번 단계(⑪-1)에 없어도 된다 — `_gen`은 대사 리소스
## 로드 성공 여부와 무관하게 재생 시도 시점에 증가하므로 재진입 판정에는 영향이 없다.
extends GutTest

var ui: UiRoot
var controller: NpcDialogueController


func before_each() -> void:
	ui = load("res://scenes/ui/UiRoot.tscn").instantiate()
	add_child_autofree(ui)
	controller = ui.npc_dialogue_controller


func test_balloon_yields_input_while_quest_panel_open() -> void:
	ui.open_quest_npc(&"teo")
	assert_true(ui.is_quest_npc_open(), "teo는 항상 메인 퀘스트 체인 중 하나가 열려 있어야 한다")
	var consumed := controller.try_consume_ui_confirm()
	assert_false(consumed, "quest panel open이면 풍선이 ui_confirm을 먹지 않는다")


func test_balloon_resumes_and_yields_one_more_frame_after_panel_closes() -> void:
	ui.open_quest_npc(&"teo")
	ui.close_quest_npc()
	assert_true(ui.quest_npc_just_closed, "닫힌 프레임엔 1프레임 유예 플래그가 선다")
	assert_false(controller.try_consume_ui_confirm(), "그 유예 프레임에도 풍선이 먹지 않는다")


func test_reentrant_talk_restarts_from_resolved_title() -> void:
	controller.open_npc_dialogue(&"teo")
	var gen_before: int = controller._gen
	controller.open_npc_dialogue(&"teo")
	assert_ne(controller._gen, gen_before, "재진입은 새 세대로 이전 await 결과를 무효화한다")
