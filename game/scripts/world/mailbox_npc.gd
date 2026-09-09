## 마을 우편함 NPC(F3-1 D-10 "마을 우편함으로 자동 전송"). 판정 범위 안에서 interact
## 입력을 받으면 Events.mailbox_opened만 발신한다 — 실제 수령 UI는 다음 단계(M2-4는
## 백엔드 로직만, scripts/systems/mailbox.gd + GameState.claim_mail() 참고).
## Waystone(scripts/world/waystone.gd)과 동일한 "판정 범위 진입 + interact" 패턴.
class_name MailboxNpc
extends Area2D

@export var npc_id: StringName = &"mailbox"

var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		Events.mailbox_opened.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
