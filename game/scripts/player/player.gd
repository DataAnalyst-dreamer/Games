## 플레이어 캐릭터 (CharacterBody2D).
##
## 실제 행동 로직은 StateMachine 자식(Idle/Move/...)에 있고, 이 스크립트는
## 입력 읽기·방향·애니메이션 재생 같은 공용 유틸리티와 콜백 위임만 담당한다.
class_name Player
extends CharacterBody2D

## 4방향 애니메이션 접미사. 8방향 입력은 수평 우선으로 4방향에 매핑한다.
const DIR_NAMES := {
	Vector2.DOWN: "down",
	Vector2.UP: "up",
	Vector2.LEFT: "left",
	Vector2.RIGHT: "right",
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var weapon_pivot: Node2D = $WeaponPivot

## 바라보는 방향(4방향 중 하나). 공격 히트박스 방향 결정에도 쓴다.
var facing: Vector2 = Vector2.DOWN

## 이동 속도(px/s). combat.json 에서 로드.
var walk_speed: float

## HP·스태미나 자원(F2-3). combat.json/Tuning 값으로 초기화.
var resources: PlayerResources

## 사망 처리가 끝나 더 이상 입력을 받지 않는지.
var is_dead: bool = false

## 무적 프레임 잔여 시간(초). Hurt 상태를 벗어난 뒤에도 계속 줄어들어야 하므로
## (상태 전환과 무관하게) Player._process에서 직접 관리한다.
var _iframe_remaining: float = 0.0


func _ready() -> void:
	# QA 리뷰 Minor-2(docs/qa/review-m1-1-m1-2.md): fallback을 80.0(RELEASE_FALLBACKS와
	# 동일한 확정값)으로 맞춘다 — 예전엔 0.0이라 키가 사라지면 플레이어가 완전히
	# 움직이지 못하는 최악의 실패 모드가 조용히 발생했다.
	walk_speed = float(Data.get_value("combat", "movement.walk_speed_px", 80.0))
	for dir_name: String in DIR_NAMES.values():
		sprite.sprite_frames.set_animation_speed("walk_" + dir_name, Tuning.ANIM_WALK_FPS)
		sprite.sprite_frames.set_animation_speed("idle_" + dir_name, Tuning.ANIM_IDLE_FPS)
	resources = PlayerResources.new(
		Tuning.PLAYER_MAX_HP,
		float(Data.get_value("combat", "stamina.max", 100.0)),
		float(Data.get_value("combat", "stamina.regen_per_sec", 25.0)),
		float(Data.get_value("combat", "stamina.regen_delay_sec", 0.5)),
		float(Data.get_value("combat", "stamina.exhausted_penalty_sec", 1.0)),
	)
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	Events.player_spawned.emit(self)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	state_machine.handle_input(event)


## 사망 중에는 자원(HP/스태미나) 갱신·무적 타이머를 멈추되, Dead 상태의 대기 타이머
## (update(delta))만은 계속 흘려야 사망 연출 뒤 자동 부활이 진행된다(F8-2) — 그래서
## state_machine.update()만 예외적으로 호출하고 나머지는 건너뛴다.
func _process(delta: float) -> void:
	if is_dead:
		state_machine.update(delta)
		return
	var regen_multiplier: float = 1.0
	if state_machine.current_state != null:
		regen_multiplier = state_machine.current_state.get_stamina_regen_multiplier()
	resources.tick(delta, regen_multiplier)
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)
	if _iframe_remaining > 0.0:
		_iframe_remaining = maxf(_iframe_remaining - delta, 0.0)
		if _iframe_remaining <= 0.0:
			hurtbox.invulnerable = false
	state_machine.update(delta)


## duration_sec 동안 피격 무적을 건다(Hurt 상태 진입 시 호출). 상태를 벗어나도
## 잔여 시간이 유지되도록 Player가 직접 관리한다.
func start_iframes(duration_sec: float) -> void:
	hurtbox.invulnerable = true
	_iframe_remaining = maxf(_iframe_remaining, duration_sec)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	state_machine.physics_update(delta)


## Hurtbox.hurt 신호 핸들러: 가드 중이면 가드/저스트 가드 파이프라인(S2-1c)으로,
## 그 외에는 공용 타격감 연출(F2-2)을 적용하고 HP를 깎는 일반 피격 파이프라인으로 간다.
## 무적 상태(구르기 무적, 피격 직후 무적 등)는 Hurtbox.invulnerable이 이미 걸러낸다.
func _on_hurtbox_hurt(source_hitbox: Hitbox) -> void:
	if is_dead:
		return
	var guard_state := state_machine.states.get(&"Guard") as GuardState
	var is_guarding: bool = guard_state != null and state_machine.current_state == guard_state
	if is_guarding and not source_hitbox.unguardable:
		_handle_guarded_hit(source_hitbox, guard_state)
		return
	_apply_full_hit(source_hitbox)


## 가드 불가(unguardable) 공격이거나 가드 중이 아닐 때의 일반 피격 파이프라인. 사망 시
## _die(), 생존 시 Hurt 상태로 전이한다.
func _apply_full_hit(source_hitbox: Hitbox) -> void:
	var damage: int = HitFeel.apply(self, sprite, source_hitbox)
	var died: bool = resources.take_damage(damage)
	Events.player_damaged.emit(damage, source_hitbox.source)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	AudioManager.play_sfx(&"player_hurt", global_position)
	if died:
		_die()
	else:
		state_machine.transition_to(&"Hurt", {})


## 가드 중 피격 처리(S2-1c). 저스트 가드 판정창 안이면 무피해·무소모 경로로, 아니면
## 칩데미지 경로로 분기한다.
func _handle_guarded_hit(source_hitbox: Hitbox, guard_state: GuardState) -> void:
	if guard_state.is_just_guard_window():
		_handle_just_guard(source_hitbox)
		return
	var cost: float = float(Data.get_value("combat", "stamina.costs.guard_hit", 10.0))
	if not resources.try_spend(cost):
		# 가드 붕괴(제안, game-designer 확인 필요 — 완료 보고 질문 목록 참고): 가드
		# 유지 자체는 스태미나를 요구하지 않지만, 막아내는 매 히트마다 스태미나가
		# 필요하다는 F2-3 트리거 규칙을 그대로 적용하면 고갈 시 이번 타격은 무가드로
		# 처리하는 편이 "가드는 생존은 보장하되 무피해는 아니다"라는 설계 의도와도
		# 일관된다.
		Events.player_stamina_insufficient.emit(&"guard_hit")
		_apply_full_hit(source_hitbox)
		return
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)
	var chip_ratio: float = float(Data.get_value("combat", "guard.chip_damage_ratio", 0.2))
	var damage: int = GuardCalc.chip_damage(source_hitbox.damage, chip_ratio)
	var died: bool = resources.take_damage(damage)
	Events.player_damaged.emit(damage, source_hitbox.source)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	Events.player_guarded.emit(source_hitbox.damage - damage, false)
	AudioManager.play_sfx(&"player_guard_chip", global_position)
	HitFlash.flash(sprite)
	HitFeel.spawn_damage_number(self, damage, false)
	if died:
		_die()
	# 생존 시 Guard 상태를 유지한다 — 가드는 경직 없이 계속 버틸 수 있어야 한다.


## 저스트 가드 성공(S2-1c): 피해 0, 스태미나 소모 없음, 공격자에게 경직 요청 신호를
## 보낸다. 전용 이펙트/사운드는 에셋이 없어 흰 플래시로 대체(pixel-artist/audio-designer
## TODO — 완료 보고 질문 목록 참고).
func _handle_just_guard(source_hitbox: Hitbox) -> void:
	Events.just_guard_succeeded.emit(self, source_hitbox.source)
	Events.player_guarded.emit(source_hitbox.damage, true)
	var stagger_sec: float = float(Data.get_value("combat", "guard.just_guard_enemy_stagger_sec", 0.4))
	source_hitbox.stagger_requested.emit(stagger_sec)
	HitFlash.flash(sprite)


func _die() -> void:
	is_dead = true
	state_machine.transition_to(&"Dead", {})
	Events.player_died.emit()


## Dead 상태가 사망 연출(짧은 페이드+대기) 뒤 호출한다(F8-2). 마지막 상호작용 비석
## (GameState.last_waystone, D-28) 위치에서 HP·스태미나 전량으로 부활시킨다.
## 골드 페널티(D-25, 5%·상한 레벨×50)는 골드 시스템이 아직 없어 적용하지 않는다 —
## 골드 시스템 구현 시 Events.player_respawned를 구독해 이 자리에서 차감하면 된다.
## 보스전 예외(D-23: 골드 손실 없음, 보스방 앞 비석 즉시 재도전)는 보스 시스템이 아직
## 없어 GameState.in_boss_encounter 플래그만 자리를 잡아 두었다(M2 TODO).
func respawn() -> void:
	is_dead = false
	resources.hp = resources.max_hp
	resources.stamina = resources.max_stamina
	global_position = GameState.get_respawn_position()
	hurtbox.invulnerable = false
	_iframe_remaining = 0.0
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)
	state_machine.transition_to(&"Idle", {})
	Events.player_respawned.emit(GameState.last_waystone)


## 구르기 스태미나 비용(DEX 경감 훅 포함, S2-1b 규칙 §3-3). stats 시스템이 아직 없어
## DEX=0으로 고정한다 — characters.json/stats.json 확정 후 실제 DEX 값을 전달하도록
## 이 함수만 고치면 된다(godot-engineer TODO).
func get_roll_cost() -> float:
	var base_cost: float = float(Data.get_value("combat", "stamina.costs.roll", 20.0))
	var dex: float = 0.0
	return PlayerResources.roll_cost_with_dex(base_cost, dex)


func has_stamina_for_roll() -> bool:
	return resources.stamina >= get_roll_cost()


## 공격 프레임이 없는 Knight 시트 대신 무기 스프라이트를 회전시켜 휘두름을 표현한다
## (godot-engineer 결정, pixel-artist 몫 TODO: 공격 전용 프레임 필요 — 완료 보고 참고).
func play_attack_swing(hit_index: int, duration: float) -> void:
	if weapon_pivot == null:
		return
	var base_angle: float = facing.angle()
	var sweep: float = deg_to_rad(70.0)
	var start_angle: float = base_angle - sweep
	var end_angle: float = base_angle + sweep
	if hit_index == 2:
		start_angle = base_angle + sweep
		end_angle = base_angle - sweep
	elif hit_index >= 3:
		sweep = deg_to_rad(110.0)
		start_angle = base_angle - sweep
		end_angle = base_angle + sweep
	weapon_pivot.position = facing * 8.0
	weapon_pivot.rotation = start_angle
	weapon_pivot.visible = true
	var tween := weapon_pivot.create_tween()
	tween.tween_property(weapon_pivot, "rotation", end_angle, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(weapon_pivot):
			weapon_pivot.visible = false
	)


## 8방향 이동 입력(정규화). 스틱 데드존은 project.godot 액션 deadzone 이 처리한다.
func get_move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", Tuning.STICK_DEADZONE)
	return v


## 입력 벡터를 4방향 facing 으로 환산한다. 대각선은 수평 우선.
func set_facing(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		return
	if absf(input_dir.x) >= absf(input_dir.y):
		facing = Vector2.RIGHT if input_dir.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if input_dir.y > 0.0 else Vector2.UP


func facing_name() -> String:
	return DIR_NAMES.get(facing, "down")


## "walk" → "walk_down" 식으로 방향 접미사를 붙여 재생. 같은 애니메이션이면 재시작하지 않는다.
func play_anim(base_name: String) -> void:
	var anim := "%s_%s" % [base_name, facing_name()]
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
