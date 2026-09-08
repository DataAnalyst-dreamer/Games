## 플레이어 상태머신.
##
## 자식 노드 중 PlayerState 를 모두 수집해 이름으로 등록하고, 현재 상태에 입력/프레임 콜백을 위임한다.
## 상태 추가 절차: scripts/player/states/ 에 PlayerState 상속 스크립트 작성 → StateMachine 자식 노드로 추가.
class_name PlayerStateMachine
extends Node

## 시작 상태. 비워두면 첫 번째 자식 상태를 사용한다.
@export var initial_state: PlayerState

var current_state: PlayerState
var states: Dictionary[StringName, PlayerState] = {}

## 디버그/HUD 용: 상태가 바뀔 때마다 알린다.
signal state_changed(previous: StringName, next: StringName)


func _ready() -> void:
	# owner(Player)의 @onready 가 끝난 뒤 상태를 초기화한다.
	await owner.ready
	var player := owner as Player
	assert(player != null, "PlayerStateMachine 은 Player 씬의 자식이어야 한다")
	for child in get_children():
		var state := child as PlayerState
		if state == null:
			continue
		state.player = player
		states[state.name] = state
		state.finished.connect(_on_state_finished)
	if initial_state == null and not states.is_empty():
		initial_state = states.values()[0]
	if initial_state != null:
		current_state = initial_state
		current_state.enter(&"")
		state_changed.emit(&"", current_state.name)


func transition_to(next_name: StringName, data: Dictionary = {}) -> void:
	if not states.has(next_name):
		push_error("[PlayerStateMachine] 존재하지 않는 상태: %s" % next_name)
		return
	if current_state != null and current_state.name == next_name:
		return
	var previous_name: StringName = current_state.name if current_state != null else &""
	if current_state != null:
		current_state.exit()
	current_state = states[next_name]
	current_state.enter(previous_name, data)
	state_changed.emit(previous_name, next_name)


func handle_input(event: InputEvent) -> void:
	if current_state != null:
		current_state.handle_input(event)


func update(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func _on_state_finished(next_name: StringName, data: Dictionary) -> void:
	transition_to(next_name, data)
