## 마을 게시판(F5-2 게시판 일일 의뢰). 판정 범위 안에서 interact 입력을 받으면
## Events.board_opened만 발신한다 — 실제 일일 의뢰 목록 UI는 다음 단계(M2-7은 백엔드
## 로직만, scripts/systems/quest_system.gd:get_daily_quest_ids()/roll_daily_target()
## 참고). BlacksmithNpc/MailboxNpc(scripts/world/*.gd)와 동일한 "판정 범위 진입 +
## interact" 패턴.
class_name BoardNpc
extends Area2D

@export var npc_id: StringName = &"board"

var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		Events.board_opened.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
