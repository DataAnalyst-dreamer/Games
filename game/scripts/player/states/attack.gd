## 기본 공격 3타 콤보 상태(F2-1 S2-1a). 타이밍(입력 버퍼/리셋/피니셔 후딜)은
## scripts/systems/combo_state.gd(순수 로직, GUT 테스트 대상)에 위임하고, 이 상태는
## 그 결과를 받아 이동(짧은 전진)·애니메이션(무기 스프라이트 휘두름)·히트박스만 다룬다.
## 콤보 중 피격 시 Hurt 상태가 exit()에서 콤보를 리셋한다(S2-1a 예외).
extends PlayerState

var combo: ComboState

var _lunge_dir: Vector2 = Vector2.DOWN


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	if combo == null:
		combo = _make_combo_state()
	else:
		combo.reset()
	_lunge_dir = player.facing
	combo.on_attack_input()
	_start_current_hit()


func exit() -> void:
	if player.hitbox != null:
		player.hitbox.deactivate()
	combo.reset()
	# D-127: 콤보 피니셔 종료·구르기 캔슬·피격(Hurt 전이) 등 Attack을 벗어나는 모든
	# 경로가 여기를 지나므로, tween 완료 여부와 무관하게 무기 오버레이를 즉시 숨긴다.
	player.hide_weapon_overlay()


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		var new_dir := player.get_move_input()
		if combo.on_attack_input():
			if new_dir != Vector2.ZERO:
				_lunge_dir = new_dir
				player.set_facing(new_dir)
			_start_current_hit()
	elif event.is_action_pressed("roll") and can_roll_cancel():
		# S2-1b: "공격 애니메이션 특정 프레임 이후 구르기로 캔슬 가능" — 피니셔 후딜 중
		# combo.finisher_roll_cancel_after_sec 이후부터 허용(can_roll_cancel() 참고).
		# exit()가 콤보를 리셋하므로 여기서 별도 정리는 필요 없다.
		try_enter_roll()


func physics_update(delta: float) -> void:
	var result: Dictionary = combo.update(delta)
	if result.reset:
		finished.emit(&"Idle", {})
		return
	if result.entered_finisher_recovery and player.hitbox != null:
		player.hitbox.deactivate()
	if result.advanced:
		_start_current_hit()
	# 타별 짧은 전진의 잔여 속도를 감쇠시키며 소화(S2-1a: "짧은 전진 이동 포함").
	# D-124: 이동 입력이 있으면 완전 정지 대신 저속 이동(walk_speed의
	# ATTACK_MOVE_INPUT_BLEND_RATIO배)으로 수렴시킨다 — lunge와 입력을 단순 합산하지
	# 않고, lunge 감쇠가 끝나면 자연스럽게 그 저속 이동으로 이어지도록 move_toward의
	# 목표 자체를 바꾼다. 콤보 판정·히트박스 타이밍에는 영향 없음(속도 블렌딩만).
	var move_input: Vector2 = player.get_move_input()
	var blended_target: Vector2 = move_input * player.walk_speed * Tuning.ATTACK_MOVE_INPUT_BLEND_RATIO
	player.velocity = player.velocity.move_toward(blended_target, 900.0 * delta)
	player.move_and_slide()


## 구르기 캔슬 가능 여부(S2-1b: "공격 애니메이션 특정 프레임 이후 구르기로 캔슬 가능").
## 구르기 자체는 M1-2 구현 대상이라 이 플래그만 미리 노출해 둔다.
func can_roll_cancel() -> bool:
	var after_sec: float = float(Data.get_value("combat", "combo.finisher_roll_cancel_after_sec", 0.167))
	return combo.can_roll_cancel(after_sec)


func _start_current_hit() -> void:
	var hit_index: int = combo.hit_index
	if hit_index >= combo.max_hits:
		# M1-4 계측(Metrics.gd): "3타 완주" = 입력 체이닝으로 피니셔가 실제로 시작된 횟수
		# (적중 여부와 무관). enter()/handle_input()을 거쳐 여기 정확히 한 곳에서만 호출됨.
		Events.combo_finisher_reached.emit(player)
	player.play_anim("attack")
	player.play_attack_swing(hit_index, combo.hit_duration_sec)
	_play_swing_sfx(hit_index)
	var lunge_speed: float = Tuning.ATTACK_LUNGE_PX / maxf(combo.hit_duration_sec, 0.01)
	player.velocity = _lunge_dir * lunge_speed
	_fire_hitbox(hit_index)


## 콤보 1·2타는 가볍게, 3타(피니셔)는 무겁게(sound-map-m1.md §1). 피니셔는 고정 사운드
## 위에 저음 레이어를 얹는다(변주 축소 — 항상 같은 무게감).
func _play_swing_sfx(hit_index: int) -> void:
	if hit_index >= combo.max_hits:
		AudioManager.play_sfx(&"atk_swing_finisher", player.global_position, 0.03)
		AudioManager.play_sfx(&"atk_swing_finisher_layer", player.global_position, 0.0)
	elif hit_index == 2:
		AudioManager.play_sfx(&"atk_swing_2", player.global_position)
	else:
		AudioManager.play_sfx(&"atk_swing_1", player.global_position)


func _fire_hitbox(hit_index: int) -> void:
	var hitbox := player.hitbox
	if hitbox == null:
		return
	var mults: Array = Data.get_value("combat", "combo.damage_multipliers", [1.0, 1.0, 1.5])
	var mult: float = float(mults[clampi(hit_index - 1, 0, mults.size() - 1)])
	var is_finisher: bool = hit_index >= combo.max_hits
	# M2-1(F3-2): 장비 공격력 합산이 반영된 값 — 미장착 시 get_attack_power()는
	# Tuning.PLAYER_BASE_ATTACK과 동일해 기존 동작을 그대로 보존한다.
	hitbox.damage = int(round(player.get_attack_power() * mult))
	# QA 리뷰 Minor-2(docs/qa/review-m1-1-m1-2.md): fallback도 is_finisher 분기를 따라야
	# 한다 — 예전엔 세 번째 인자(기본값)가 분기와 무관하게 일반값(8.0/0.05)으로 고정돼
	# 있어서, Minor-1과 겹쳐 heavy 키가 사라지면 피니셔 타격이 조용히 일반 타격 수치로
	# 강등됐다.
	hitbox.knockback_px = float(Data.get_value(
		"combat", "knockback.heavy_px" if is_finisher else "knockback.normal_px",
		20.0 if is_finisher else 8.0))
	hitbox.hitstop_sec = float(Data.get_value(
		"combat", "hitstop.heavy_crit_sec" if is_finisher else "hitstop.normal_sec",
		0.1 if is_finisher else 0.05))
	hitbox.is_heavy = is_finisher
	hitbox.element = &""
	hitbox.source = player
	hitbox.position = _lunge_dir * 10.0
	hitbox.activate(combo.hit_duration_sec)


func _make_combo_state() -> ComboState:
	return ComboState.new(
		int(Data.get_value("combat", "combo.hits", 3)),
		float(Data.get_value("combat", "combo.input_buffer_sec", 0.2)),
		float(Data.get_value("combat", "combo.reset_after_sec", 0.6)),
		Tuning.ATTACK_HIT_DURATION_SEC,
		float(Data.get_value("combat", "combo.finisher_recovery_sec", 0.35)),
	)
