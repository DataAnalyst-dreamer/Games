## obj_montsil_rabbit.dialogue 파싱 검증(§9.3, D-262). 렌더 없이 get_next_dialogue_line()
## 한 번으로 결정적 검증 — QuestNpcPanel(워크스트림 B 소유, 미수정)과 무관하다.
##
## (편차, 계획서 대비) 실제 "active" 상태를 만들려면 `quest_main_a1_06_echocave` 완료가
## 선행돼야 해(prerequisites, act1_hartland.json) 이 테스트가 검증하는 리소스 파싱
## 결과(translation_key/responses.size())와는 무관한 부담이라 생략했다 — 상태 가드
## (`QuestSystem.get_state(...) == "active"`)는 `quest_object.gd`가 이미 책임진다(D-262).
extends GutTest


func test_montsil_encounter_line_has_two_release_capture_responses() -> void:
	var res: DialogueResource = load("res://dialogue/obj_montsil_rabbit.dialogue")
	assert_not_null(res)
	if res == null:
		return
	var line: DialogueLine = await res.get_next_dialogue_line("start")
	assert_eq(line.translation_key, "quest_side_heartland_montsil_encounter")
	assert_eq(line.responses.size(), 2)
