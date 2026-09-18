## 퀘스트 "장소 도달"(reach) 트리거 볼륨(F5-1/F5-2, M2-8).
##
## 플레이어가 판정 범위 안에 들어오면 Events.location_reached(location_id)를 emit한다 —
## QuestSystem은 이 신호 하나만 구독해 reach형 목표를 자동으로 진행시킨다
## (docs/specs/quest-system-m2.md §4). Waystone/BlacksmithNpc(scripts/world/*.gd)와
## 동일하게 "판정 범위 + 신호 1개"만 다루는 얇은 스크립트다.
##
## one_shot은 최초 방문 알림을 세션당 한 번으로 제한하되, 나중에 활성화된 reach
## 목표를 소모하지 않는다. 현재 목표마다 한 번 추가로 통지할 수 있다. 수주·목표 전환·
## 로드 때 이미 안에 있는 플레이어도 확인한다. false면 매 재진입 알림을 유지한다.
class_name QuestTrigger
extends Area2D

@export var location_id: StringName = &""
## true: 최초 방문 및 활성 reach 목표별 1회. false: 재진입마다 emit.
@export var one_shot: bool = true

var _fired: bool = false
var _delivered_objectives: Dictionary = {}
var _recheck_frames := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	Events.quest_accepted.connect(_on_quest_accepted)
	Events.quest_objective_updated.connect(_on_objective_updated)
	Events.load_completed.connect(_on_load_completed)
	set_physics_process(false)


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	_emit_location(false)


func _emit_location(recheck_only: bool) -> void:
	var keys := QuestSystem.get_active_reach_objective_keys(location_id)
	var pending := false
	for key in keys:
		if not _delivered_objectives.has(key): pending = true
	if not pending and (recheck_only or (one_shot and _fired)):
		return
	_fired = true
	# Mark before emit: objective signals may synchronously request a later recheck.
	for key in keys: _delivered_objectives[key] = true
	Events.location_reached.emit(location_id)


func _on_quest_accepted(quest_id: StringName) -> void:
	# A repeatable quest's new acceptance is a new visit opportunity.
	for key: String in _delivered_objectives.keys():
		if key.begins_with(String(quest_id) + ":"):
			_delivered_objectives.erase(key)
	_schedule_recheck()


func _on_objective_updated(_quest: StringName, _objective: StringName, _current: int, _target: int) -> void:
	_schedule_recheck()


func _on_load_completed(_slot: int, _kind: StringName, ok: bool) -> void:
	if not ok: return
	_delivered_objectives.clear()
	_schedule_recheck()


func _schedule_recheck() -> void:
	# QuestSystem emits progress before advancing the index; load also moves the player.
	# Wait for physics overlap refresh instead of recursively emitting inside those signals.
	_recheck_frames = 2
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_recheck_frames -= 1
	if _recheck_frames > 0: return
	set_physics_process(false)
	for body in get_overlapping_bodies():
		if body is Player:
			_emit_location(true)
			return
