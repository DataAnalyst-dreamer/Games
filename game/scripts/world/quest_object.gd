## 퀘스트 "상호작용"(interact) 오브젝트(F5-1/F5-2, M2-8).
##
## 판정 범위 안에서 interact 입력을 받으면 Events.object_interacted(object_id)를
## emit한다 — BlacksmithNpc/MailboxNpc/BoardNpc(scripts/world/*.gd)와 동일한 "판정
## 범위 진입 + interact" 패턴. QuestSystem은 이 신호 하나만 구독해 interact형 목표를
## 자동으로 진행시킨다(docs/specs/quest-system-m2.md §4).
##
## 옵션 3종(world_objects.json 데이터로 설정, quest_layout_spawner.gd가 배정):
## - one_shot: true면 첫 상호작용 이후 재상호작용을 막고, Placeholder를
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
var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _visual_used != null:
		_visual_used.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		interact()


## Events 발신 + 분기 선택 + 상태 전환을 한 곳에 모은 공개 진입점 — 실제 플레이어
## 입력뿐 아니라 스모크 테스트(SmokeQuestLayout)도 이 함수를 직접 호출해 검증한다.
func interact() -> void:
	if one_shot and _used:
		return
	_used = true
	Events.object_interacted.emit(object_id)
	if not branch_quest_id.is_empty() and not branch_choice_id.is_empty():
		QuestSystem.choose_branch(branch_quest_id, branch_choice_id)
	if vanish_on_complete:
		queue_free()
	elif one_shot:
		_swap_to_used_visual()


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
