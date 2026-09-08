## Idle 상태: 정지. 이동 입력이 들어오면 Move로, 공격 입력이 들어오면 Attack으로 전환.
## TODO(다음 태스크, M1-2): roll / guard 입력 → 해당 상태로 전환.
extends PlayerState


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		finished.emit(&"Attack", {})


func physics_update(_delta: float) -> void:
	# 남은 관성이 있으면(넉백 등) 슬라이드로 소화한다.
	if player.velocity != Vector2.ZERO:
		player.move_and_slide()
	if player.get_move_input() != Vector2.ZERO:
		finished.emit(&"Move", {})
