## 가드/저스트 가드 상태(S2-1c, D-05). 가드 버튼을 누르고 있는 동안 유지되며, 떼면
## 이동 입력 여부에 따라 Move/Idle로 돌아간다. 판정 로직(저스트 가드 창·칩데미지 계산)은
## scripts/systems/guard_calc.gd(순수 로직, GUT 테스트 대상)에 위임하고, 실제 피해 적용은
## Player._on_hurtbox_hurt()가 현재 상태가 Guard인지 조회해 처리한다 — Hurtbox 자체는
## "맞았다"는 사실만 전달하는 얇은 컴포넌트이기 때문(hurtbox.gd 문서 참고).
##
## 이동 배율(guard.move_speed_multiplier)·스태미나 회복 배율(stamina.guard_regen_
## multiplier)은 docs/specs/combat-tuning-m1-addendum.md가 아직 없어 godot-engineer
## 제안값(각 0.5)을 combat.json에 임시 반영했다 — game-designer 확인 필요(완료 보고
## 질문 목록 참고).
class_name GuardState
extends PlayerState

## 가드를 건 시점부터 흐른 시간(초). 저스트 가드 판정 기준(GuardCalc.is_just_guard_window).
var _elapsed: float = 0.0


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.play_anim("idle") # 전용 가드 자세 스프라이트 없음(S2-1c "표시" 항목, pixel-artist TODO).


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("roll"):
		try_enter_roll()


func update(delta: float) -> void:
	_elapsed += delta


func physics_update(_delta: float) -> void:
	if not Input.is_action_pressed("guard"):
		if player.get_move_input() != Vector2.ZERO:
			finished.emit(&"Move", {})
		else:
			finished.emit(&"Idle", {})
		return

	var input_dir := player.get_move_input()
	if input_dir != Vector2.ZERO:
		player.set_facing(input_dir)
		var move_mult: float = float(Data.get_value("combat", "guard.move_speed_multiplier", 0.5))
		player.velocity = input_dir * player.walk_speed * move_mult
	else:
		player.velocity = Vector2.ZERO
	player.move_and_slide()


## 지금 맞으면 저스트 가드가 성립하는지(D-05: 적중 직전 6프레임=0.1초 이내 가드 입력).
## Player._on_hurtbox_hurt()가 히트 처리 직전에 조회한다.
func is_just_guard_window() -> bool:
	var window_sec: float = float(Data.get_value("combat", "guard.just_guard_window_sec", 0.1))
	return GuardCalc.is_just_guard_window(_elapsed, window_sec)


func get_stamina_regen_multiplier() -> float:
	return float(Data.get_value("combat", "stamina.guard_regen_multiplier", 0.5))
