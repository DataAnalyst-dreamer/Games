## 필드 몬스터 공용 베이스(F6-1). 상태머신: idle/patrol/chase/telegraph/attack/recover/hurt/stunned/dead.
##
## 데이터 주도 원칙: 스탯(hp/atk/move_speed_px/telegraph_sec 등)과 AI 5필드(aggro_range_px/
## melee_range_px/attack_recovery_sec/patrol_radius_px/leash_range_px, addendum §4 확정,
## D-65 예정)는 전부 monsters.json에서 monster_id로 조회한다. 신규 몬스터 추가 절차 —
## 이 스크립트를 그대로 재사용하고:
##   1) monsters.json에 새 monster_id 항목 추가 (attack_pattern_id로 melee_contact/charge/
##      spore_patch 중 하나를 고르면 이 스크립트가 알아서 분기한다)
##   2) 이 씬(Slime.tscn/HornRabbit.tscn/Mushroom.tscn 중 하나)을 "새로운 상속 씬"으로
##      열거나 복제해 monster_id와 스프라이트 텍스처만 교체(코드 변경 불필요) — F6-1
##      "데이터+씬 상속만으로 추가" 요구사항.
##
## attack_pattern_id별 동작:
## 공격 종료 후에는 항상 RECOVER 상태를 거쳐 attack_recovery_sec만큼 대기한 뒤에야
## CHASE/IDLE로 전이한다(QA 리뷰 Major-1 수정, docs/qa/review-m1-1-m1-2.md — 예전에는
## `_process_attack()`이 `_enter_state()`를 우회해 state를 직접 대입해서 ①CHASE로 갈 때
## `_process_chase()`가 `_state_timer`를 보지 않아 attack_recovery_sec이 완전히 죽은 값이
## 됐고 ②IDLE로 갈 때는 `_enter_state(IDLE)`이 설정할 MONSTER_PATROL_PAUSE_SEC 대신
## attack_recovery_sec이 그대로 새어나가 순찰 재개가 3배 빨라졌다).
##
##   - melee_contact(슬라임): 접촉 즉시 1회 타격, Tuning.MONSTER_ATTACK_ACTIVE_SEC 유지.
##   - charge(뿔토끼): 예고 후 dash_speed_px로 dash_duration_sec 동안 직진 돌진 + 히트박스
##     유지. 이동 중 정적 콜라이더와 충돌하면 그 프레임에 STUNNED로 강제 전이하고
##     Tuning.DASH_WALL_STUN_SEC 동안 경직(addendum §1-3 "이동 즉시 클램프 + 경직 유지"
##     정책을 몬스터 자신의 이동에도 동일하게 적용).
##   - spore_patch(버섯돌이): 접촉 즉시 1회 타격(atk) + aoe_radius_px 반경의 지속 피해
##     장판을 Tuning.SPORE_PATCH_DURATION_SEC 동안 전개. 장판 틱은 Hitbox.ignores_iframes
##     경로로 무적 프레임 중에도 적용된다(addendum §2-2, D-61 예정 — "위험 지역에 서 있는
##     대가"는 무적으로 막을 수 없다).
##
## 종별 공통이 아닌 임시 상수(공격 활성 시간·순찰 대기·피격 경직 등, addendum §4-1이
## 승격 범위 밖으로 명시)는 계속 Tuning.MONSTER_* 를 쓴다(game-designer 확인 필요,
## 완료 보고 질문 목록 참고).
class_name MonsterBase
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, STUNNED, HURT, DEAD }

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

## AI 공통 5필드(monsters.json, addendum §4-3). 기본값은 슬라임 기준(§4-3 "기존 공통값").
var attack_pattern_id: String = "melee_contact"
var aggro_range_px: float = 64.0
var melee_range_px: float = 14.0
var attack_recovery_sec: float = 0.4
var patrol_radius_px: float = 32.0
var leash_range_px: float = 140.0

## 돌진형(charge) 전용, monsters.json 확장 필드(뿔토끼).
var dash_speed_px: float = 0.0
var dash_duration_sec: float = 0.0

## 장판형(spore_patch) 전용, monsters.json 확장 필드(버섯돌이).
var atk_tick_per_sec: float = 0.0
var aoe_radius_px: float = 0.0

var _player: Node2D = null
var _spawn_position: Vector2 = Vector2.ZERO
var _patrol_target: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _attack_dir: Vector2 = Vector2.DOWN
var _rng := RandomNumberGenerator.new()

## spore_patch 전용 런타임 노드(코드에서 동적 생성 — 씬에 별도 배선 불필요).
var _spore_hitbox: Hitbox = null
var _spore_tick_timer: Timer = null


func _ready() -> void:
	add_to_group(&"monster")
	_load_stats()
	_spawn_position = global_position
	hurtbox.team = &"enemy"
	hitbox.team = &"enemy"
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	hitbox.stagger_requested.connect(_on_stagger_requested)
	detection_area.body_entered.connect(_on_detection_body_entered)
	if detection_shape.shape is CircleShape2D:
		(detection_shape.shape as CircleShape2D).radius = aggro_range_px
	if attack_pattern_id == "spore_patch" and aoe_radius_px > 0.0:
		_create_spore_hitbox()
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
	attack_pattern_id = String(entry.get("attack_pattern_id", "melee_contact"))
	aggro_range_px = float(entry.get("aggro_range_px", 64.0))
	melee_range_px = float(entry.get("melee_range_px", 14.0))
	attack_recovery_sec = float(entry.get("attack_recovery_sec", 0.4))
	patrol_radius_px = float(entry.get("patrol_radius_px", 32.0))
	leash_range_px = float(entry.get("leash_range_px", 140.0))
	dash_speed_px = float(entry.get("dash_speed_px", 0.0))
	dash_duration_sec = float(entry.get("dash_duration_sec", 0.0))
	atk_tick_per_sec = float(entry.get("atk_tick_per_sec", 0.0))
	aoe_radius_px = float(entry.get("aoe_radius_px", 0.0))


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
		State.RECOVER:
			_process_recover()
		State.STUNNED:
			_process_stunned()
		State.HURT:
			_process_hurt()
		State.DEAD:
			pass
	if state != State.DEAD:
		move_and_slide()
		# addendum §1-3 정책(플레이어 피격 넉백용으로 확정된 "이동 즉시 클램프 + 경직
		# 유지")을 뿔토끼 돌진 자신의 벽 충돌에도 동일하게 적용 — move_and_slide()가
		# 이미 이동을 벽 앞에서 멈춰주므로, 여기서는 경직 상태로 전이만 하면 된다.
		if MonsterAiCalc.should_stun_from_wall_collision(
				state == State.ATTACK and attack_pattern_id == "charge", get_slide_collision_count()):
			_enter_state(State.STUNNED)


func _enter_state(next: State) -> void:
	state = next
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_state_timer = Tuning.MONSTER_PATROL_PAUSE_SEC
		State.PATROL:
			var angle: float = _rng.randf_range(0.0, TAU)
			var radius: float = _rng.randf_range(patrol_radius_px * 0.3, patrol_radius_px)
			_patrol_target = _spawn_position + Vector2(cos(angle), sin(angle)) * radius
		State.CHASE:
			pass
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			_state_timer = telegraph_sec
			_attack_dir = _direction_to_player()
			_start_telegraph_flash()
		State.ATTACK:
			match attack_pattern_id:
				"charge":
					_state_timer = dash_duration_sec
					velocity = MonsterAiCalc.dash_velocity(_attack_dir, dash_speed_px)
					_fire_hitbox(dash_duration_sec)
				"spore_patch":
					_state_timer = Tuning.SPORE_PATCH_DURATION_SEC
					_fire_hitbox()
					_activate_spore_patch()
				_:
					_state_timer = Tuning.MONSTER_ATTACK_ACTIVE_SEC
					_fire_hitbox()
		State.RECOVER:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			if attack_pattern_id == "spore_patch":
				_deactivate_spore_patch()
			_state_timer = attack_recovery_sec
		State.STUNNED:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			_state_timer = Tuning.DASH_WALL_STUN_SEC
		State.HURT:
			_state_timer = Tuning.MONSTER_HURT_STUN_SEC
		State.DEAD:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			if attack_pattern_id == "spore_patch":
				_deactivate_spore_patch()
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
	if MonsterAiCalc.should_leash(to_player.length(), leash_range_px):
		_player = null
		_enter_state(State.IDLE)
		return
	if MonsterAiCalc.is_in_melee_range(to_player.length(), melee_range_px):
		_enter_state(State.TELEGRAPH)
		return
	velocity = to_player.normalized() * move_speed_px
	_face_towards(velocity)


func _process_telegraph() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_enter_state(State.ATTACK)


func _process_attack() -> void:
	if attack_pattern_id == "charge":
		# 돌진 중에는 매 프레임 방향을 다시 밀어준다 — move_and_slide()가 벽에서 속도를
		# 0으로 깎아도(activate 시점 값이 유지되도록) 다음 프레임에 그대로 재적용된다.
		velocity = MonsterAiCalc.dash_velocity(_attack_dir, dash_speed_px)
	if _state_timer <= 0.0:
		# QA Major-1 수정: state를 직접 대입하지 않고 반드시 _enter_state()를 거친다 —
		# RECOVER를 거쳐야 attack_recovery_sec이 실제로 적용된다(CHASE는 타이머를 보지
		# 않고, 예전 코드처럼 IDLE로 직행하면 그 상태 고유 타이머(MONSTER_PATROL_PAUSE_SEC)
		# 대신 recovery 값이 새어나갔다).
		_enter_state(State.RECOVER)


func _process_recover() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if _player_valid() else State.IDLE)


func _process_stunned() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_enter_state(State.CHASE if _player_valid() else State.IDLE)


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
	if state == State.DEAD or state == State.HURT or state == State.STUNNED:
		return
	if body is Player:
		_player = body
		if state == State.IDLE or state == State.PATROL:
			_enter_state(State.CHASE)


## 예고 연출(F6-1: "예고(점멸 또는 바닥 장판 표시) 최소 0.5초"). 3종 모두 점멸(전용
## 바닥 장판 표시 이펙트는 pixel-artist TODO — 완료 보고 참고).
func _start_telegraph_flash() -> void:
	if sprite == null:
		return
	var original: Color = sprite.modulate
	var tween := sprite.create_tween()
	var cycles: int = max(int(round(telegraph_sec / 0.15)), 1)
	for i in cycles:
		tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4), 0.075)
		tween.tween_property(sprite, "modulate", original, 0.075)
	# sound-map-m1.md §5/§12: 몬스터 전용 이벤트라 전역 Events가 아니라 여기서 직접
	# 호출한다. 슬라임만 audio_sfx.json에 정의돼 있어(뿔토끼/버섯돌이는 M1 사운드 미제작)
	# "%s_telegraph" 키가 없으면 play_sfx()가 조용히 null을 반환한다(정상 동작).
	AudioManager.play_sfx(StringName("%s_telegraph" % monster_id), global_position)


## 접촉 히트박스(멜리/돌진/포자장판 공통 "즉시 1회 타격" 경로). duration_sec을 지정하면
## 그 시간만큼(돌진처럼 이동 중 계속 판정이 필요한 경우) 활성 유지, 아니면
## Tuning.MONSTER_ATTACK_ACTIVE_SEC(짧은 펄스)만 쓴다.
func _fire_hitbox(duration_sec: float = -1.0) -> void:
	hitbox.damage = atk
	hitbox.knockback_px = float(Data.get_value("combat", "knockback.normal_px", 8.0))
	hitbox.hitstop_sec = float(Data.get_value("combat", "hitstop.normal_sec", 0.05))
	hitbox.is_heavy = false
	hitbox.ignores_iframes = false
	hitbox.element = StringName(element)
	hitbox.source = self
	hitbox.position = _attack_dir * melee_range_px * 0.6
	var active_duration: float = duration_sec if duration_sec > 0.0 else Tuning.MONSTER_ATTACK_ACTIVE_SEC
	hitbox.activate(active_duration)
	AudioManager.play_sfx(StringName("%s_attack" % monster_id), global_position)


## 포자 장판(spore_patch) 지속 피해 시작 — 트리거 지점(멜리 접촉 위치)을 중심으로
## aoe_radius_px 반경을 계속 감시하다 1초 간격으로 atk_tick_per_sec만큼 데미지를 준다.
## ignores_iframes = true라 무적 프레임(구르기·피격 직후) 중에도 적용된다(D-61 예정).
func _activate_spore_patch() -> void:
	if _spore_hitbox == null:
		return
	_spore_hitbox.global_position = global_position + _attack_dir * melee_range_px
	_spore_hitbox.reset_hits()
	_spore_hitbox.activate(-1.0) # 자동 비활성화 없음 — _deactivate_spore_patch()가 끈다.
	if _spore_tick_timer != null:
		_spore_tick_timer.start()


func _deactivate_spore_patch() -> void:
	if _spore_hitbox != null:
		_spore_hitbox.deactivate()
	if _spore_tick_timer != null:
		_spore_tick_timer.stop()


## SporeHitbox/타이머를 코드로 생성한다(씬에 미리 배선하지 않아도 attack_pattern_id ==
## "spore_patch"인 몬스터는 자동으로 갖춰진다 — F6-1 "데이터+씬 상속만으로 추가" 원칙).
func _create_spore_hitbox() -> void:
	_spore_hitbox = Hitbox.new()
	_spore_hitbox.name = "SporeHitbox"
	_spore_hitbox.team = &"enemy"
	_spore_hitbox.ignores_iframes = true
	_spore_hitbox.collision_layer = hitbox.collision_layer
	_spore_hitbox.collision_mask = hitbox.collision_mask
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = aoe_radius_px
	shape.shape = circle
	_spore_hitbox.add_child(shape)
	add_child(_spore_hitbox)

	_spore_tick_timer = Timer.new()
	_spore_tick_timer.name = "SporeTickTimer"
	# 고정 1초 간격 — atk_tick_per_sec(monsters.json, "초당 데미지")을 "1초마다
	# round(atk_tick_per_sec) 데미지"로 단순화했다. 실제 하위 초 단위 틱이 필요하면
	# wait_time만 바꾸고 _on_spore_tick()의 데미지 계산을 맞추면 된다(tuning.gd 주석 참고).
	_spore_tick_timer.wait_time = 1.0
	_spore_tick_timer.one_shot = false
	_spore_tick_timer.timeout.connect(_on_spore_tick)
	add_child(_spore_tick_timer)


func _on_spore_tick() -> void:
	if _spore_hitbox == null:
		return
	_spore_hitbox.damage = MonsterAiCalc.spore_tick_damage(atk_tick_per_sec)
	_spore_hitbox.knockback_px = 0.0 # 지속 피해는 "위험 지역에 서 있는 대가" — 넉백 없음.
	_spore_hitbox.hitstop_sec = 0.0 # 매초 히트스톱이 걸리면 손맛이 아니라 스터터가 된다.
	_spore_hitbox.is_heavy = false
	_spore_hitbox.element = StringName(element)
	_spore_hitbox.source = self
	# area_entered는 "새로 겹친" 순간에만 발생하므로, 이미 장판 안에 서 있는 대상을
	# 매 틱 다시 맞히려면 겹침 목록을 직접 순회해 try_hit()을 호출해야 한다.
	_spore_hitbox.reset_hits()
	for area in _spore_hitbox.get_overlapping_areas():
		if area is Hurtbox:
			_spore_hitbox.try_hit(area)


## 저스트 가드 성공 시 자신의 Hitbox가 쏘는 경직 요청(S2-1c: "저스트 성공 시 적 경직").
## 데미지 없이 HURT 상태로 강제 전이하되 경직시간은 이 신호가 넘긴 값(guard.
## just_guard_enemy_stagger_sec)을 쓴다 — 일반 피격 경직(Tuning.MONSTER_HURT_STUN_SEC)과
## 구분해야 하므로 _enter_state 이후 _state_timer를 덮어쓴다.
func _on_stagger_requested(duration_sec: float) -> void:
	if state == State.DEAD:
		return
	hitbox.deactivate()
	if attack_pattern_id == "spore_patch":
		_deactivate_spore_patch()
	_enter_state(State.HURT)
	_state_timer = duration_sec


func _on_hurtbox_hurt(source_hitbox: Hitbox) -> void:
	if state == State.DEAD:
		return
	if state == State.ATTACK and attack_pattern_id == "spore_patch":
		_deactivate_spore_patch()
	var damage: int = HitFeel.apply(self, sprite, source_hitbox, element, tags)
	hp = maxi(hp - damage, 0)
	if hp <= 0:
		_enter_state(State.DEAD)
		Events.enemy_died.emit(self, source_hitbox.source)
	else:
		AudioManager.play_sfx(StringName("%s_hurt" % monster_id), global_position)
		_enter_state(State.HURT)


func _play_death() -> void:
	# _play_death()가 끝나면 queue_free()되므로 자식 AudioStreamPlayer로는 소리가
	# 끊긴다 — AudioManager.play_sfx()가 전역 SfxPool에 독립 재생 노드를 스폰한다
	# (sound-map-m1.md §5 주의사항).
	AudioManager.play_sfx(StringName("%s_death" % monster_id), global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
