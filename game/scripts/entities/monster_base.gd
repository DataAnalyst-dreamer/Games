## 필드 몬스터 공용 베이스(F6-1). 상태머신: idle/patrol/chase/telegraph/attack/hurt/dead.
##
## 데이터 주도 원칙: 스탯(hp/atk/move_speed_px/telegraph_sec 등)은 전부 monsters.json에서
## monster_id로 조회한다. 신규 몬스터 추가 절차 — 이 스크립트를 그대로 재사용하고:
##   1) monsters.json에 새 monster_id 항목 추가
##   2) 이 씬(Slime.tscn)을 "새로운 상속 씬"으로 열거나 복제해 monster_id와 스프라이트
##      텍스처만 교체(코드 변경 불필요) — F6-1 "데이터+씬 상속만으로 추가" 요구사항.
##
## 인지 범위·근접 사거리·공격 후딜 등은 monsters.json에 아직 없는 값이라
## Tuning.MONSTER_* 임시 상수를 쓴다(game-designer 확인 필요, 완료 보고 질문 목록 참고).
class_name MonsterBase
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, HURT, DEAD }

## monsters.json 키. 인스펙터에서 지정 — 이 값만 바꾸면 스탯이 통째로 바뀐다.
@export var monster_id: String = "slime"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D

var state: State = State.IDLE

var hp: int = 1
var atk: int = 1
var move_speed_px: float = 40.0
var telegraph_sec: float = 0.5
var element: String = ""
var tags: Array = []

var _player: Node2D = null
var _spawn_position: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _attack_dir: Vector2 = Vector2.DOWN
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"monster")
	_load_stats()
	_spawn_position = global_position
	hurtbox.team = &"enemy"
	hitbox.team = &"enemy"
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	detection_area.body_entered.connect(_on_detection_body_entered)
	if detection_shape.shape is CircleShape2D:
		(detection_shape.shape as CircleShape2D).radius = Tuning.MONSTER_DETECTION_RADIUS_PX
	_rng.randomize()
	_enter_state(State.IDLE)


func _load_stats() -> void:
	var entry: Dictionary = Data.get_value("monsters", monster_id, {})
	if entry.is_empty():
		push_error("[MonsterBase] monsters.json에 없는 monster_id: %s" % monster_id)
		return
	hp = int(entry.get("hp", 1))
	atk = int(entry.get("atk", 1))
	move_speed_px = float(entry.get("move_speed_px", 40.0))
	telegraph_sec = float(entry.get("telegraph_sec", 0.5))
	element = String(entry.get("element", ""))
	tags = entry.get("tags", [])


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	match state:
		State.IDLE:
			_process_idle()
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.TELEGRAPH:
			_process_telegraph()
		State.ATTACK:
			_process_attack()
		State.HURT:
			_process_hurt()
		State.DEAD:
			pass
	if state != State.DEAD:
		move_and_slide()


func _enter_state(next: State) -> void:
	state = next
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_state_timer = Tuning.MONSTER_PATROL_PAUSE_SEC
		State.PATROL:
			var angle: float = _rng.randf_range(0.0, TAU)
			var radius: float = _rng.randf_range(Tuning.MONSTER_PATROL_RADIUS_PX * 0.3, Tuning.MONSTER_PATROL_RADIUS_PX)
			_patrol_target = _spawn_position + Vector2(cos(angle), sin(angle)) * radius
		State.CHASE:
			pass
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			_state_timer = telegraph_sec
			_attack_dir = _direction_to_player()
			_start_telegraph_flash()
		State.ATTACK:
			_state_timer = Tuning.MONSTER_ATTACK_ACTIVE_SEC
			_fire_hitbox()
		State.HURT:
			_state_timer = Tuning.MONSTER_HURT_STUN_SEC
		State.DEAD:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			set_physics_process(false)
			hurtbox.monitoring = false
			_play_death()


func _process_idle() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_enter_state(State.PATROL)


func _process_patrol(delta: float) -> void:
	var to_target: Vector2 = _patrol_target - global_position
	if to_target.length() <= 2.0:
		_enter_state(State.IDLE)
		return
	velocity = to_target.normalized() * move_speed_px * 0.5
	_face_towards(velocity)


func _process_chase(_delta: float) -> void:
	if not _player_valid():
		_enter_state(State.IDLE)
		return
	var to_player: Vector2 = _player.global_position - global_position
	if to_player.length() >= Tuning.MONSTER_LEASH_RANGE_PX:
		_player = null
		_enter_state(State.IDLE)
		return
	if to_player.length() <= Tuning.MONSTER_MELEE_RANGE_PX:
		_enter_state(State.TELEGRAPH)
		return
	velocity = to_player.normalized() * move_speed_px
	_face_towards(velocity)


func _process_telegraph() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_enter_state(State.ATTACK)


func _process_attack() -> void:
	if _state_timer <= 0.0:
		hitbox.deactivate()
		_state_timer = Tuning.MONSTER_ATTACK_RECOVERY_SEC
		state = State.CHASE if _player_valid() else State.IDLE


func _process_hurt() -> void:
	if velocity != Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * get_physics_process_delta_time())
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if _player_valid() else State.PATROL)


func _face_towards(dir: Vector2) -> void:
	if dir.length() > 0.01 and sprite != null:
		sprite.flip_h = dir.x < 0.0


func _direction_to_player() -> Vector2:
	if not _player_valid():
		return Vector2.DOWN
	var diff: Vector2 = _player.global_position - global_position
	return diff.normalized() if diff.length() > 0.01 else Vector2.DOWN


func _player_valid() -> bool:
	return _player != null and is_instance_valid(_player)


func _on_detection_body_entered(body: Node) -> void:
	if state == State.DEAD or state == State.HURT:
		return
	if body is Player:
		_player = body
		if state == State.IDLE or state == State.PATROL:
			_enter_state(State.CHASE)


## 예고 연출(F6-1: "예고(점멸 또는 바닥 장판 표시) 최소 0.5초"). 슬라임은 점멸.
func _start_telegraph_flash() -> void:
	if sprite == null:
		return
	var original: Color = sprite.modulate
	var tween := sprite.create_tween()
	var cycles: int = max(int(round(telegraph_sec / 0.15)), 1)
	for i in cycles:
		tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4), 0.075)
		tween.tween_property(sprite, "modulate", original, 0.075)


func _fire_hitbox() -> void:
	hitbox.damage = atk
	hitbox.knockback_px = float(Data.get_value("combat", "knockback.normal_px", 8.0))
	hitbox.hitstop_sec = float(Data.get_value("combat", "hitstop.normal_sec", 0.05))
	hitbox.is_heavy = false
	hitbox.element = StringName(element)
	hitbox.source = self
	hitbox.position = _attack_dir * Tuning.MONSTER_MELEE_RANGE_PX * 0.6
	hitbox.activate(Tuning.MONSTER_ATTACK_ACTIVE_SEC)


func _on_hurtbox_hurt(source_hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	var damage: int = HitFeel.apply(self, sprite, source_hitbox, element, tags)
	hp = maxi(hp - damage, 0)
	if hp <= 0:
		_enter_state(State.DEAD)
		Events.enemy_died.emit(self, source_hitbox.source)
	else:
		_enter_state(State.HURT)


func _play_death() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
