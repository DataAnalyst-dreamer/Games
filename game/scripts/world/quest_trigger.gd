## 퀘스트 "장소 도달"(reach) 트리거 볼륨(F5-1/F5-2, M2-8).
##
## 플레이어가 판정 범위 안에 들어오면 Events.location_reached(location_id)를 emit한다 —
## QuestSystem은 이 신호 하나만 구독해 reach형 목표를 자동으로 진행시킨다
## (docs/specs/quest-system-m2.md §4). Waystone/BlacksmithNpc(scripts/world/*.gd)와
## 동일하게 "판정 범위 + 신호 1개"만 다루는 얇은 스크립트다.
##
## 기본값은 "1회/세션"(one_shot=true) — 같은 장소를 몇 번을 다시 밟아도 두 번째부터는
## emit하지 않는다(QuestSystem이 이미 지난 objective를 다시 세지 않아 안전하긴 하지만,
## 불필요한 신호 스팸을 줄인다). retrigger가 필요한 장소(예: 전망 좋은 언덕처럼 여러 번
## 다시 방문해도 되는 곳)는 one_shot=false로 켜 둔다 — 매번 재진입할 때마다 다시 emit.
class_name QuestTrigger
extends Area2D

@export var location_id: StringName = &""
## true(기본): 세션당 1회만 emit. false: 진입할 때마다(재진입 시에도) emit.
@export var one_shot: bool = true

var _fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if one_shot and _fired:
		return
	_fired = true
	Events.location_reached.emit(location_id)
