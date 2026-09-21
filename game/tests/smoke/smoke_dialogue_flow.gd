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

## D-272 회귀 가드용 몽실이 대역. `obj_montsil_rabbit.dialogue`의 응답 do절이
## `resolve_branch_outcome(...)`를 접두어 없이 부르는 대상(QuestObject와 같은 계약,
## D-262) — 여기서는 호출 여부만 기록한다.
class FakeRabbit extends Node:
	var resolved: String = ""
	func resolve_branch_outcome(choice_id: String) -> void:
		resolved = choice_id

enum Phase { WAIT_LINE, WAIT_RESPONSES, WAIT_END, SKIP_RESPONSES, SKIP_REACTION, SKIP_END, DONE }

const QUEST_ID := "quest_main_a1_01_arrival"

var _controller: NpcDialogueController
var _player: FakePlayer
var _phase: int = Phase.WAIT_LINE
var _elapsed: float = 0.0
var _rabbit: FakeRabbit
var _first_ok: bool = false


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
		Phase.SKIP_RESPONSES:
			_process_skip_responses()
		Phase.SKIP_REACTION:
			_process_skip_reaction()
		Phase.SKIP_END:
			_process_skip_end()


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
	_first_ok = quest_ok and input_ok
	_start_skip_case()


## --- D-272 회귀 가드: 선택 직후 전체 스킵해도 do절 변이가 실행되는가 ---
##
## 몽실이(`quest_side_heartland_montsil` obj_03)는 선택 -> 반응 줄 -> `do
## resolve_branch_outcome(...)` -> END 순서라, 스킵이 예전처럼 DMConstants.ID_END로
## 점프하면 분기가 확정되지 않아 퀘스트가 막힌다. D-272는 스킵을 fast-forward로 바꿔
## 텍스트만 건너뛰고 변이는 실행한다 — 그 계약을 실제 .dialogue 파일로 검증한다.
func _start_skip_case() -> void:
	print("--- D-272: 선택 직후 ui_cancel 전체 스킵 -> do절 변이는 실행되는가 ---")
	_elapsed = 0.0
	_rabbit = FakeRabbit.new()
	add_child(_rabbit)
	var res: DialogueResource = load("res://dialogue/obj_montsil_rabbit.dialogue")
	if res == null:
		print("[FAIL] obj_montsil_rabbit.dialogue 로드 실패")
		_finish(false)
		return
	_phase = Phase.SKIP_RESPONSES
	_controller.open_dialogue_resource(res, "start", _rabbit)


func _process_skip_responses() -> void:
	var balloon: DialogueBalloon = _controller.balloon
	if balloon.is_typing():
		balloon.skip_typing()
	if not balloon.responses_menu.visible:
		return
	print("[CHOICE] '%s' 선택" % balloon.responses_menu.responses[0].text)
	balloon.response_chosen.emit(balloon.responses_menu.responses[0])
	_phase = Phase.SKIP_REACTION


func _process_skip_reaction() -> void:
	# 선택 이후의 반응 줄이 뜨면(선택지 메뉴가 내려가면) 확인하지 않고 전체 스킵한다.
	if _controller.balloon.responses_menu.visible:
		return
	print("[SKIP] 반응 줄을 읽지 않고 skip_all()")
	_controller.skip_all()
	_phase = Phase.SKIP_END


func _process_skip_end() -> void:
	if _controller.is_dialogue_open():
		return
	var mutation_ok: bool = _rabbit.resolved == "release"
	var input_ok: bool = not _player.dialogue_active
	print("[CHECK] 스킵해도 do resolve_branch_outcome 실행(D-272): %s (실제='%s')" % [str(mutation_ok), _rabbit.resolved])
	print("[CHECK] 스킵 후 player.dialogue_active 복원(false): %s (실제=%s)" % [str(input_ok), _player.dialogue_active])
	_finish(_first_ok and mutation_ok and input_ok)


func _finish(ok: bool) -> void:
	_phase = Phase.DONE
	if ok:
		print("[PASS] 대사 진행 스모크 통과")
	else:
		print("[FAIL] 대사 진행 스모크 실패")
	print("=== SMOKE DIALOGUE FLOW 종료 ===")
	get_tree().quit(0 if ok else 1)
