## 헤드리스 대사 진행 스모크(D-243/D-265 대체 게이트, §9.4/§10). `res://dialogue/_smoke_test.dialogue`
## 를 `NpcDialogueController.open_dialogue_resource()`로 실제 재생해 시작→줄→선택지→
## (선택지 do절의 QuestSystem.accept() 실호출로 퀘스트 active 전환 확인)→종료→
## player.dialogue_active가 컨트롤러에 의해 복원됐는지까지 순회한다.
##
## 렌더 확인은 하지 않는다 — 실제 프레임은 흘려보내되(SmokeMetrics와 같은 관례) 타이핑
## 완료/선택지 확정은 balloon 신호를 직접 트리거해 결정적으로 진행시킨다(SmokeMetrics가
## InputEventAction을 직접 만들어 state_machine.handle_input()을 호출하는 것과 같은 패턴
## — 실제 하드웨어 입력 시뮬레이션 대신 production 코드가 듣는 신호를 직접 튕긴다).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeDialogueFlow.tscn --quit-after 300
extends Node

class FakePlayer extends Node:
	var dialogue_active: bool = false

enum Phase { WAIT_LINE, WAIT_RESPONSES, WAIT_END, DONE }

const QUEST_ID := "quest_main_a1_01_arrival"

var _controller: NpcDialogueController
var _player: FakePlayer
var _phase: int = Phase.WAIT_LINE
var _elapsed: float = 0.0


func _ready() -> void:
	print("=== SMOKE DIALOGUE FLOW: 시작->줄->선택지->퀘스트 수락->종료->입력 복원 ===")
	_player = FakePlayer.new()
	add_child(_player)
	_controller = NpcDialogueController.new()
	_controller.player = _player
	add_child(_controller)
	var res: DialogueResource = load("res://dialogue/_smoke_test.dialogue")
	if res == null:
		print("[FAIL] _smoke_test.dialogue 로드 실패")
		_finish(false)
		return
	_controller.open_dialogue_resource(res, "start")


func _process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	_elapsed += delta
	if _elapsed > 10.0:
		print("[FAIL] 10초 초과 (phase=%d)" % _phase)
		_finish(false)
		return
	match _phase:
		Phase.WAIT_LINE:
			_process_wait_line()
		Phase.WAIT_RESPONSES:
			_process_wait_responses()
		Phase.WAIT_END:
			_process_wait_end()


func _process_wait_line() -> void:
	var balloon: DialogueBalloon = _controller.balloon
	if balloon.dialogue_label.dialogue_line == null:
		return
	print("[LINE] text=\"%s\" responses=%d dialogue_active=%s (기대 true)" \
		% [balloon.dialogue_label.dialogue_line.text, balloon.dialogue_label.dialogue_line.responses.size(), _player.dialogue_active])
	balloon.skip_typing()
	_phase = Phase.WAIT_RESPONSES


func _process_wait_responses() -> void:
	var balloon: DialogueBalloon = _controller.balloon
	if not balloon.responses_menu.visible:
		return
	var responses: Array = balloon.responses_menu.responses
	print("[CHOICE] '%s' 선택 (accept do절 포함)" % responses[0].text)
	balloon.response_chosen.emit(responses[0])
	_phase = Phase.WAIT_END


func _process_wait_end() -> void:
	if _controller.is_dialogue_open():
		return
	var quest_state := QuestSystem.get_state(QUEST_ID)
	var quest_ok: bool = quest_state == "active"
	var input_ok: bool = not _player.dialogue_active
	print("[CHECK] 퀘스트 active 전환(do QuestSystem.accept 반영): %s (실제 state=%s)" % [str(quest_ok), quest_state])
	print("[CHECK] player.dialogue_active 복원(false): %s (실제=%s)" % [str(input_ok), _player.dialogue_active])
	_finish(quest_ok and input_ok)


func _finish(ok: bool) -> void:
	_phase = Phase.DONE
	if ok:
		print("[PASS] 대사 진행 스모크 통과")
	else:
		print("[FAIL] 대사 진행 스모크 실패")
	print("=== SMOKE DIALOGUE FLOW 종료 ===")
	get_tree().quit(0 if ok else 1)
