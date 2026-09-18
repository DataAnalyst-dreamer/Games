## 퀘스트 "상호작용"(interact) 오브젝트(F5-1/F5-2, M2-8).
##
## 판정 범위 안에서 interact 입력을 받으면 Events.object_interacted(object_id)를
## emit한다 — BlacksmithNpc/MailboxNpc/BoardNpc(scripts/world/*.gd)와 동일한 "판정
## 범위 진입 + interact" 패턴. QuestSystem은 이 신호 하나만 구독해 interact형 목표를
## 자동으로 진행시킨다(docs/specs/quest-system-m2.md §4).
##
## 옵션 3종(world_objects.json 데이터로 설정, quest_layout_spawner.gd가 배정):
## - one_shot: true면 첫 발견/현재 활성 목표마다 한 번만 진행 신호를 보내고, Placeholder를
##   PlaceholderUsed로 교체한다("완료 후 스프라이트 교체"). false면 영구 랜드마크
##   취급(민들레 결계석·비석처럼 몇 번을 다시 상호작용해도 항상 같은 모습).
## - vanish_on_complete: true면 one_shot과 별개로 상호작용 직후 노드 자체가 사라진다
##   (`montsil_rabbit` — "상호작용 후 사라지는 오브젝트", 설계 문서 hartland.md ⑩ 참고).
## - branch_quest_id/branch_choice_id: 둘 다 채워져 있으면 상호작용 시
##   QuestSystem.choose_branch(branch_quest_id, branch_choice_id)를 함께 호출한다.
##   선택 UI가 아직 없어(quest-system-m2.md §6) `quest_side_heartland_montsil`은 첫
##   상호작용을 항상 "release"로 확정해 명시적으로 기록해 둔다(D-94 문서화).
class_name QuestObject
extends Area2D

@export var object_id: StringName = &""
@export var one_shot: bool = false
@export var vanish_on_complete: bool = false
@export var branch_quest_id: StringName = &""
@export var branch_choice_id: StringName = &""

@onready var _visual: Node2D = $Placeholder
@onready var _visual_used: Node2D = get_node_or_null("PlaceholderUsed")

var _used: bool = false
var _emitted_objectives: Dictionary = {}
var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Events.quest_accepted.connect(_on_quest_accepted)
	Events.load_completed.connect(_on_load_completed)
	if _visual_used != null:
		_visual_used.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and _player_inside != null and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		interact()
		_activate_shared_waystone()


## D-28: this one named ward is the same physical object as Main's waystone1.
## Keep input consumed for unrelated objects; explicitly invoke only this companion,
## only when the player is inside its own range. Quest progress happens before save.
func _activate_shared_waystone() -> void:
	if object_id != &"ward_stone_dandelion" or _player_inside == null: return
	for node in get_tree().get_nodes_in_group(&"waystones"):
		if node is Waystone and node.waystone_id == &"waystone1" and node.overlaps_body(_player_inside):
			node.activate()
			return


## Events 발신 + 분기 선택 + 상태 전환을 한 곳에 모은 공개 진입점 — 실제 플레이어
## 입력뿐 아니라 스모크 테스트(SmokeQuestLayout)도 이 함수를 직접 호출해 검증한다.
func interact() -> void:
	var observation := observation_key()
	if not observation.is_empty():
		get_tree().call_group("world_observation_hud", "show_world_observation", observation)
	var active_keys := QuestSystem.get_active_interact_objective_keys(object_id)
	var pending := false
	for key in active_keys:
		if not _emitted_objectives.has(key): pending = true
	if one_shot and _used and not pending: return
	for key in active_keys: _emitted_objectives[key] = true
	_used = true
	Events.object_interacted.emit(object_id)
	if not branch_quest_id.is_empty() and not branch_choice_id.is_empty():
		QuestSystem.choose_branch(branch_quest_id, branch_choice_id)
	if vanish_on_complete:
		queue_free()
	elif one_shot:
		_swap_to_used_visual()


## Presentation only; observation itself never emits a quest event.
func observation_key() -> StringName:
	if object_id == &"cargo_pile":
		if not QuestSystem.get_active_interact_objective_keys(object_id).is_empty(): return &"observe.cargo.active"
		if _used: return &"observe.cargo.used"
		if QuestSystem.get_state("quest_main_a1_01_arrival") == "active":
			return &"observe.cargo.active"
		return &"observe.cargo.before"
	if object_id == &"ward_stone_dandelion":
		var state := QuestSystem.get_state("quest_main_a1_04_theshard")
		if state in ["complete_ready", "completed"]: return &"observe.ward.after"
		if state == "active": return &"observe.ward.active"
		return &"observe.ward.before"
	if object_id == &"waypoint_stone_01":
		# interact() observes before emitting the objective event. The completing
		# input still shows active; a subsequent explicit input shows after.
		# This describes investigation, not a new warp activation or saved flag.
		var state := QuestSystem.get_state("quest_side_heartland_waypoint")
		if state in ["complete_ready", "completed"]: return &"observe.waypoint.after"
		if state == "active": return &"observe.waypoint.active"
		return &"observe.waypoint.before"
	return &""


func _on_quest_accepted(quest_id: StringName) -> void:
	for key: String in _emitted_objectives.keys():
		if key.begins_with(String(quest_id) + ":"): _emitted_objectives.erase(key)


func _on_load_completed(_slot: int, _kind: StringName, ok: bool) -> void:
	if ok: _emitted_objectives.clear()
	# Deliberately do not interact: the next explicit player input is required.


func _swap_to_used_visual() -> void:
	if _visual != null:
		_visual.visible = false
	if _visual_used != null:
		_visual_used.visible = true


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
