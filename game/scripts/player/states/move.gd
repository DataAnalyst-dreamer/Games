## Move 상태: 8방향 이동. 입력이 없으면 Idle 로, 공격 입력이 들어오면 Attack으로,
## 구르기/가드 입력이 들어오면 각각 Roll/Guard로 전환한다(M1-2).
## 이동 속도는 Data.tables["combat"].movement.walk_speed_px (하드코딩 금지).
extends PlayerState


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	player.play_anim("walk")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		finished.emit(&"Attack", {})
	elif event.is_action_pressed("roll"):
		try_enter_roll()
	elif event.is_action_pressed("guard"):
		finished.emit(&"Guard", {})


func physics_update(_delta: float) -> void:
	var input_dir := player.get_move_input()
	if input_dir == Vector2.ZERO:
		finished.emit(&"Idle", {})
		return
	player.set_facing(input_dir)
	player.velocity = input_dir * player.walk_speed
	player.move_and_slide()
	# 방향이 바뀌었을 수 있으니 애니메이션 이름을 갱신한다(같은 이름이면 재시작하지 않음).
	player.play_anim("walk")
