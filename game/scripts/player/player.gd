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
	walk_speed = float(Data.get_value("combat", "movement.walk_speed_px", 0.0))
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


func _process(delta: float) -> void:
	resources.tick(delta)
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)
	if _iframe_remaining > 0.0:
		_iframe_remaining = maxf(_iframe_remaining - delta, 0.0)
		if _iframe_remaining <= 0.0:
			hurtbox.invulnerable = false
	if is_dead:
		return
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


## Hurtbox.hurt 신호 핸들러: 공용 타격감 연출을 적용하고 HP를 깎는다(F2-2).
## 무적 상태(구르기 무적, 피격 직후 무적 등)는 Hurtbox.invulnerable이 이미 걸러낸다.
func _on_hurtbox_hurt(source_hitbox: Hitbox) -> void:
	if is_dead:
		return
	var damage: int = HitFeel.apply(self, sprite, source_hitbox)
	var died: bool = resources.take_damage(damage)
	Events.player_damaged.emit(damage, source_hitbox.source)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	if died:
		_die()
	else:
		state_machine.transition_to(&"Hurt", {})


func _die() -> void:
	is_dead = true
	state_machine.transition_to(&"Dead", {})
	Events.player_died.emit()


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
