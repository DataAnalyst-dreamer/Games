## 대사 진행 컨트롤러(⑪-1, `docs/specs/dialogue-system-v1.md`, D-145 6번째 단계).
## `UiRoot`의 상시 자식(process_mode는 부모의 ALWAYS를 상속) — 진입 경로는
## `"npc_dialogue_ui"` 그룹 메서드 2개뿐이다(D-260):
##   1) `open_npc_dialogue(npc_id)` — giver 잡담. `quest_npc.gd.talk()` 바로 다음 줄에서
##      호출되므로(같은 프레임, 시그널 연결 순서에 기대지 않는다) `QuestSystem`이 이미
##      이번 interact를 반영한 최신 상태를 읽는다.
##   2) `open_dialogue_resource(resource, title, extra_state)` — 몽실이류 분기(`QuestObject`
##      가 자기 자신을 `extra_state`로 넘긴다, D-262).
##
## `DialogueManager.show_dialogue_balloon_scene()`(공식 경로)를 쓰지 않고
## `DialogueResource.get_next_dialogue_line()`을 직접 await한다(D-250 대안 A —
## `dialogue_started` 시그널은 절대 발생하지 않음을 감수).
##
## 플레이어 입력 차단(D-257): 대사 시작 시 `player.dialogue_active=true`, 정상 종료
## (END_OF_DIALOGUE)나 재진입으로 이전 재생이 폐기될 때(D-259) `false`로 되돌리는 책임을
## 이 컨트롤러가 진다 — `SmokeDialogueFlow`의 "플레이어 입력 복원" 단언이 검증하는 대상.
##
## 재진입 규칙(D-259): 재생 중 재진입하면 이전 재생을 버리고 새로 계산한 title부터
## 다시 시작한다. `_gen`(재생 세대) 필드로 `await` 복귀 시 낡은 결과를 폐기한다.
##
## 방문 횟수(D-242, §3.3): `visit_count(npc_id)` — `<npc_id>_everyday` 3줄 로테이션 재현용,
## 세션 내 비저장 헬퍼(재시작 시 0으로 리셋, §6).
class_name NpcDialogueController
extends Node

const _DIALOGUE_DIR := "res://dialogue/"
const _SELECT_PRIORITY: Array[String] = ["complete_ready", "available", "active"]
const _STATE_SUFFIX := {
	"available": "offer",
	"active": "active",
	"complete_ready": "ready",
	"completed": "done",
}

## D-254/D-259 게이트 조회 대상. GUT에서 씬 트리 없이 떼어 테스트할 수 있도록
## (§9.6) 필드로 직접 주입한다 — `UiRoot`를 타입으로 못 박으면 순환 참조 우려가
## 있어 느슨하게 `Node`로 두고 `is_quest_npc_open()`/`quest_npc_just_closed`만 조회한다.
var ui_root: Node = null
## `player.dialogue_active`(D-257) 세터 대상. 위와 동일한 이유로 필드 주입.
var player: Node = null

var balloon: DialogueBalloon

var _visits: Dictionary = {}
var _gen: int = 0
## D-263: 대사가 실제로 재생 중인지(패널 열림 여부와 무관) — `_process()`가 이 값과
## `ui_root.is_quest_npc_open()`을 합쳐 `balloon.visible`을 매 프레임 계산한다.
var _dialogue_in_progress: bool = false


func _ready() -> void:
	add_to_group(&"npc_dialogue_ui")
	var scene: PackedScene = load("res://scenes/ui/DialogueBalloon.tscn")
	balloon = scene.instantiate()
	balloon.controller = self
	add_child(balloon)


func _process(_delta: float) -> void:
	if not is_instance_valid(balloon):
		return
	var panel_open: bool = ui_root != null and bool(ui_root.call("is_quest_npc_open"))
	balloon.visible = _dialogue_in_progress and not panel_open


## giver 잡담 진입점(D-260).
func open_npc_dialogue(npc_id: StringName) -> void:
	var title := _resolve_title(String(npc_id))
	var path := "%snpc_%s.dialogue" % [_DIALOGUE_DIR, npc_id]
	var res: DialogueResource = load(path) if ResourceLoader.exists(path) else null
	_play(res, title, [], String(npc_id))


## 몽실이류 분기 진입점(D-262). `extra_state`(대개 호출한 `QuestObject` 자신)를
## `extra_game_states`로 함께 주입해 `.dialogue`의 `do` 절이 접두어 없이 그 공개
## 함수를 호출할 수 있게 한다(§3.3과 동일한 self-injection 패턴).
func open_dialogue_resource(resource: DialogueResource, title: String, extra_state: Object = null) -> void:
	var extra: Array = [extra_state] if extra_state != null else []
	_play(resource, title, extra, "")


func visit_count(npc_id: String) -> int:
	return _visits.get(npc_id, 0)


func is_dialogue_open() -> bool:
	return _dialogue_in_progress


## §4.4 D-254/D-259 공유 게이트. true = 대사 풍선이 이번 ui_confirm/interact/ui_cancel
## 입력을 처리해도 된다. false = `QuestNpcPanel`이 열려 있거나(D-254) 방금(1프레임)
## 닫혔으므로(D-259) 대사 쪽은 이번 입력을 넘기고 자기 줄을 그대로 둔다.
func try_consume_ui_confirm() -> bool:
	if ui_root == null:
		return true
	if bool(ui_root.call("is_quest_npc_open")):
		return false
	if bool(ui_root.get("quest_npc_just_closed")):
		return false
	return true


## npc_id/퀘스트 상태 → title 매핑(D-261, D-244). `quest_npc.gd._refresh_marker()`와
## 동일한 전체 스캔 — giver별 퀘스트 목록을 하드코딩하지 않는다.
func _resolve_title(npc_id: String) -> String:
	var quests: Dictionary = Data.table("quests")
	var by_state: Dictionary = {}
	for quest_id: String in quests.keys():
		if String((quests[quest_id] as Dictionary).get("giver", "")) != npc_id:
			continue
		var state := QuestSystem.get_state(quest_id)
		if state in _SELECT_PRIORITY and not by_state.has(state):
			by_state[state] = quest_id
	for state in _SELECT_PRIORITY:
		if by_state.has(state):
			return "%s_%s" % [by_state[state], _STATE_SUFFIX[state]]
	return "%s_everyday" % npc_id


func _play(res: DialogueResource, title: String, extra_states: Array, npc_id: String) -> void:
	_gen += 1
	var my_gen := _gen
	if res == null:
		push_warning("[NpcDialogueController] 대사 리소스를 찾을 수 없음 (title=%s)" % title)
		return
	if player != null:
		player.set("dialogue_active", true)
	_dialogue_in_progress = true
	var extra_game_states: Array = [self] + extra_states
	var line: DialogueLine = await res.get_next_dialogue_line(title, extra_game_states)
	while line != null:
		if my_gen != _gen:
			return # D-259: 재진입한 새 재생이 이미 이 자리를 대신하고 있다.
		balloon.show_line(line)
		var next_id: String
		if line.responses.size() > 0:
			balloon.show_responses(line.responses)
			var response: DialogueResponse = await balloon.response_chosen
			next_id = response.next_id
		else:
			var skip_all: bool = await balloon.advanced
			# D-241: ui_cancel로 잡담 전체 스킵 — DMConstants.ID_END와 동일한 종료 경로를 탄다.
			next_id = String(DMConstants.ID_END) if skip_all else line.next_id
		if my_gen != _gen:
			return
		line = await res.get_next_dialogue_line(next_id, extra_game_states)
	if my_gen != _gen:
		return
	_dialogue_in_progress = false
	if not npc_id.is_empty():
		_visits[npc_id] = visit_count(npc_id) + 1
	if player != null:
		player.set("dialogue_active", false)
