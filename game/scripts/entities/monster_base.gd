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
##   - ranged_dart(고블린 정찰병/정찰대장, M2-3): 접촉 히트박스 대신
##     scenes/effects/Projectile.tscn을 발사한다 — 그 외(예고→ATTACK→RECOVER 리듬)는
##     melee_contact와 동일하게 취급한다(elite-and-farming-m2.md §1-1).
##
## 종별 공통이 아닌 임시 상수(공격 활성 시간·순찰 대기·피격 경직 등, addendum §4-1이
## 승격 범위 밖으로 명시)는 계속 Tuning.MONSTER_* 를 쓴다(game-designer 확인 필요,
## 완료 보고 질문 목록 참고).
##
## M2-3(elite-and-farming-m2.md §1) 추가 — 상태머신과 독립적으로 동작하는 두 가지
## 부가 행동:
##   - 호루라기 증원 호출(whistle_*, goblin_scout/elite_goblin_captain 공통): IDLE/
##     PATROL/CHASE 중 플레이어가 aggro_range_px 안에 있고 쿨다운이 다 찼으면 WHISTLE
##     상태로 전이해 whistle_cast_sec 동안 시전(피격 시 여느 상태와 동일하게 HURT로
##     전이되어 자연스럽게 "끊긴다" — 별도 인터럽트 처리 불필요). 시전 완료 시
##     whistle_range_px 안의 whistle_summon_pool 대상을 강제로 CHASE 전이시킨다.
##   - 소환 웨이브(wave_*, elite_goblin_captain 전용): HP가 wave_trigger_hp_pct 이하로
##     떨어지면(1회 한정, wave_once_per_life) WAVE 상태로 전이해 wave_cast_sec 동안
##     시전 후 wave_summon_count마리를 주변에 스폰한다.
##   - 사망 시 분열(on_death_split_*, elite_bunchi_spawn 전용): DEAD 진입 시
##     on_death_split_monster_id를 on_death_split_count마리 스폰한다(재귀 없음 — 스폰된
##     개체는 on_death_split_* 필드가 없는 일반 몬스터 데이터를 그대로 쓰므로 데이터
##     상으로 안전, §1-3).
##   - 정예(tier=="elite") 공통: 이름표+등급 테두리 HP바(디버그 수준)를 자동 표시하고,
##     처치 시 Events.enemy_died와 별도로 Events.elite_died를 추가로 emit한다.
class_name MonsterBase
extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, STUNNED, HURT, DEAD, WHISTLE, WAVE }

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

## M2-3(elite-and-farming-m2.md §1) 확장 필드 — 전부 monsters.json에서 조회, 없으면
## 기본값(빈 문자열/0/false)이라 기존 3종(slime/horn_rabbit/mushroom)은 영향 없다.
var tier: String = "normal"
var name_ko: String = ""
var elite_base_monster_id: String = "" ## 참고용(§1-2/§1-3 "_comment") — 로직에서 참조만.
## _load_stats()가 최초 hp를 그대로 기억해 둔 값(웨이브 트리거 HP% 판정, 정예 HP바 표시용).
var max_hp: int = 1

## 호루라기 증원 호출(goblin_scout·elite_goblin_captain 공통, §1-1-1).
var whistle_cooldown_sec: float = 0.0
var whistle_cast_sec: float = 0.0
var whistle_range_px: float = 0.0
var whistle_summon_pool: Array = []
var whistle_summon_count: int = 0

## 소환 웨이브(elite_goblin_captain 전용, §1-2 "강화 패턴").
var wave_trigger_hp_pct: float = 0.0
var wave_cast_sec: float = 0.0
var wave_summon_count: int = 0
var wave_summon_pool: Array = []
var wave_once_per_life: bool = false

## 사망 시 분열(elite_bunchi_spawn 전용, §1-3 "강화 패턴").
var on_death_split_monster_id: String = ""
var on_death_split_count: int = 0
var on_death_split_spawn_radius_px: float = 0.0

## true면 이 개체가 죽어도 LootSpawner가 드랍을 굴리지 않는다(§1-3 "분열체는 드랍
## 테이블 없음 — 부모가 드랍"). 분열로 스폰된 개체에서만 true로 세팅한다(_spawn_death_split()).
var suppress_loot_drop: bool = false

var _whistle_cooldown_remaining: float = 0.0
var _wave_triggered: bool = false

## 정예 전용 디버그 표시(이름표 + 등급 테두리 HP바). tier=="elite"일 때만 생성된다.
var _elite_nameplate: Label = null
var _elite_hp_bar_bg: ColorRect = null
var _elite_hp_bar_fill: ColorRect = null
const _ELITE_HP_BAR_WIDTH_PX: float = 24.0
const _ELITE_HP_BAR_HEIGHT_PX: float = 3.0

const _PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/Projectile.tscn")

## 사망 분열(on_death_split_*)이 참조하는 monster_id -> 씬 매핑. elite_bunchi_spawn만
## slime을 가리키므로 지금은 1개뿐이다 — 다른 정예가 분열 패턴을 재사용하게 되면
## 여기 항목만 추가하면 된다(신규 애셋 불필요 원칙, §1-3). game-designer가 분열 대상을
## 늘릴 경우 이 딕셔너리도 함께 갱신 필요(완료 보고 TODO).
const _SPLIT_SPAWN_SCENES := {
	"slime": preload("res://scenes/entities/monsters/Slime.tscn"),
}

## 호루라기/웨이브 소환 풀(whistle_summon_pool/wave_summon_pool)이 참조하는 monster_id
## -> 씬 매핑. monsters.json 어느 종이 풀에 등장하든 스폰할 수 있어야 하므로 M2-3 시점
## 씬이 있는 4종을 전부 등록한다(정예 자기 자신은 풀에 없음).
const _SUMMONABLE_SCENES := {
	"slime": preload("res://scenes/entities/monsters/Slime.tscn"),
	"horn_rabbit": preload("res://scenes/entities/monsters/HornRabbit.tscn"),
	"mushroom": preload("res://scenes/entities/monsters/Mushroom.tscn"),
	"goblin_scout": preload("res://scenes/entities/monsters/GoblinScout.tscn"),
}

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
	if tier == "elite":
		_setup_elite_display()
	_rng.randomize()
	_enter_state(State.IDLE)


func _load_stats() -> void:
	var entry: Dictionary = Data.get_value("monsters", monster_id, {})
	if entry.is_empty():
		push_error("[MonsterBase] monsters.json에 없는 monster_id: %s" % monster_id)
		return
	hp = int(entry.get("hp", 1))
	max_hp = hp
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
	tier = String(entry.get("tier", "normal"))
	name_ko = String(entry.get("name_ko", monster_id))
	elite_base_monster_id = String(entry.get("elite_base_monster_id", ""))
	whistle_cooldown_sec = float(entry.get("whistle_cooldown_sec", 0.0))
	whistle_cast_sec = float(entry.get("whistle_cast_sec", 0.0))
	whistle_range_px = float(entry.get("whistle_range_px", 0.0))
	whistle_summon_pool = entry.get("whistle_summon_pool", [])
	whistle_summon_count = int(entry.get("whistle_summon_count", 0))
	wave_trigger_hp_pct = float(entry.get("wave_trigger_hp_pct", 0.0))
	wave_cast_sec = float(entry.get("wave_cast_sec", 0.0))
	wave_summon_count = int(entry.get("wave_summon_count", 0))
	wave_summon_pool = entry.get("wave_summon_pool", [])
	wave_once_per_life = bool(entry.get("wave_once_per_life", false))
	on_death_split_monster_id = String(entry.get("on_death_split_monster_id", ""))
	on_death_split_count = int(entry.get("on_death_split_count", 0))
	on_death_split_spawn_radius_px = float(entry.get("on_death_split_spawn_radius_px", 0.0))


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	_whistle_cooldown_remaining = maxf(0.0, _whistle_cooldown_remaining - delta)
	_maybe_start_whistle()
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
		State.WHISTLE:
			_process_whistle()
		State.WAVE:
			_process_wave()
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
				"ranged_dart":
					_state_timer = Tuning.MONSTER_ATTACK_ACTIVE_SEC
					_fire_projectile()
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
			_spawn_death_split()
			_play_death()
		State.WHISTLE:
			velocity = Vector2.ZERO
			_state_timer = whistle_cast_sec
			_start_cast_flash()
			AudioManager.play_sfx(&"goblin_whistle", global_position)
		State.WAVE:
			velocity = Vector2.ZERO
			_state_timer = wave_cast_sec
			_start_cast_flash()
			AudioManager.play_sfx(&"goblin_whistle", global_position)


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


func _process_whistle() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_do_whistle_summon()
		_whistle_cooldown_remaining = whistle_cooldown_sec
		_enter_state(State.CHASE if _player_valid() else State.IDLE)


func _process_wave() -> void:
	velocity = Vector2.ZERO
	if _state_timer <= 0.0:
		_do_wave_summon()
		_enter_state(State.CHASE if _player_valid() else State.IDLE)


## IDLE/PATROL/CHASE 중에만 새로 시전을 시작할 수 있다(§1-1-1) — TELEGRAPH/ATTACK/
## RECOVER/STUNNED/HURT/DEAD/WHISTLE/WAVE 중에는 끼어들지 않는다.
func _maybe_start_whistle() -> void:
	if whistle_cooldown_sec <= 0.0 or whistle_summon_pool.is_empty():
		return
	if state != State.IDLE and state != State.PATROL and state != State.CHASE:
		return
	if not MonsterAiCalc.is_whistle_ready(_whistle_cooldown_remaining):
		return
	if not _player_valid():
		return
	if global_position.distance_to(_player.global_position) > aggro_range_px:
		return
	_enter_state(State.WHISTLE)


## 호루라기 시전 완료 — whistle_range_px 안의 whistle_summon_pool 소속 몬스터 중 아직
## 플레이어를 인식하지 못한(IDLE/PATROL) 대상을 최대 whistle_summon_count마리까지
## 강제로 CHASE 전이시킨다("대상들 CHASE 강제").
func _do_whistle_summon() -> void:
	var group: Array = get_tree().get_nodes_in_group(&"monster")
	var candidates: Array = []
	for node in group:
		var other := node as MonsterBase
		if other == null or other == self:
			continue
		if other.state != State.IDLE and other.state != State.PATROL:
			continue # 이미 스스로 인식했거나 전투 중인 대상은 "증원"의 의미가 없다.
		candidates.append({
			"monster_id": other.monster_id,
			"distance_px": global_position.distance_to(other.global_position),
			"node": other,
		})
	var picked: Array = MonsterAiCalc.filter_whistle_candidates(
		candidates, whistle_summon_pool, whistle_range_px, whistle_summon_count)
	for c: Dictionary in picked:
		var target: MonsterBase = c.get("node")
		if target == null or not is_instance_valid(target):
			continue
		target._player = _player
		target._enter_state(State.CHASE)


## 소환 웨이브(elite_goblin_captain, HP 50% 1회) — wave_summon_pool에서 매번 무작위
## monster_id를 뽑아 wave_summon_count마리를 자신 주변(반경 whistle_range_px, 겹침
## 방지)에 스폰하고 곧바로 CHASE시킨다.
func _do_wave_summon() -> void:
	if wave_summon_pool.is_empty() or wave_summon_count <= 0:
		return
	var radius: float = whistle_range_px if whistle_range_px > 0.0 else aggro_range_px
	var offsets: Array = MonsterAiCalc.pick_non_overlapping_offsets(
		wave_summon_count, radius, Tuning.ELITE_SPAWN_MIN_SEPARATION_PX, _rng)
	var parent: Node = get_parent() if get_parent() != null else self
	for offset: Vector2 in offsets:
		var pool_id: String = String(wave_summon_pool[_rng.randi_range(0, wave_summon_pool.size() - 1)])
		var scene: PackedScene = _SUMMONABLE_SCENES.get(pool_id)
		if scene == null:
			push_warning("[MonsterBase] wave_summon_pool에 씬이 없는 monster_id: %s" % pool_id)
			continue
		var inst: MonsterBase = scene.instantiate()
		parent.add_child(inst)
		inst.global_position = global_position + offset
		if _player_valid():
			inst._player = _player
			inst._enter_state(State.CHASE)


## 사망 시 분열(elite_bunchi_spawn, §1-3). on_death_split_monster_id가 비어 있으면
## (대다수 몬스터) 아무 일도 하지 않는다. 스폰된 개체는 suppress_loot_drop=true라
## LootSpawner가 드랍을 굴리지 않는다("분열체는 드랍 테이블 없음 — 부모가 드랍").
func _spawn_death_split() -> void:
	if on_death_split_monster_id.is_empty() or on_death_split_count <= 0:
		return
	var scene: PackedScene = _SPLIT_SPAWN_SCENES.get(on_death_split_monster_id)
	if scene == null:
		push_warning("[MonsterBase] on_death_split_monster_id에 씬이 없음: %s" % on_death_split_monster_id)
		return
	var offsets: Array = MonsterAiCalc.pick_non_overlapping_offsets(
		on_death_split_count, on_death_split_spawn_radius_px,
		Tuning.ELITE_SPAWN_MIN_SEPARATION_PX, _rng)
	var parent: Node = get_parent() if get_parent() != null else self
	for offset: Vector2 in offsets:
		var inst: MonsterBase = scene.instantiate()
		parent.add_child(inst)
		inst.global_position = global_position + offset
		inst.suppress_loot_drop = true


## ranged_dart(고블린 정찰병/정찰대장) — 접촉 히트박스 대신 투사체를 발사한다.
## damage/knockback/hitstop은 _fire_hitbox()와 동일한 combat.json 값을 그대로 쓴다.
func _fire_projectile() -> void:
	var proj: Projectile = _PROJECTILE_SCENE.instantiate()
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(proj)
	proj.global_position = global_position + _attack_dir * melee_range_px * 0.6
	proj.hitbox.damage = atk
	proj.hitbox.knockback_px = float(Data.get_value("combat", "knockback.normal_px", 8.0))
	proj.hitbox.hitstop_sec = float(Data.get_value("combat", "hitstop.normal_sec", 0.05))
	proj.hitbox.element = StringName(element)
	proj.hitbox.source = self
	proj.launch(_attack_dir, Tuning.RANGED_DART_SPEED_PX, Tuning.RANGED_DART_LIFETIME_SEC)
	AudioManager.play_sfx(StringName("%s_attack" % monster_id), global_position)


## 정예 디버그 표시(§F6-3 "정예는 이름표 + 등급 테두리 전용 HP바") — 전용 아트 없이
## Label + ColorRect 두 장(테두리색 배경 + 채움)으로 구성한 최소 구현. pixel-artist가
## 정식 UI를 만들면 이 함수만 교체하면 된다(완료 보고 TODO).
func _setup_elite_display() -> void:
	_elite_nameplate = Label.new()
	_elite_nameplate.text = name_ko
	_elite_nameplate.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_elite_nameplate.add_theme_font_size_override("font_size", 8)
	_elite_nameplate.position = Vector2(-_ELITE_HP_BAR_WIDTH_PX * 0.5, -22.0)
	_elite_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elite_nameplate.custom_minimum_size = Vector2(_ELITE_HP_BAR_WIDTH_PX, 10.0)
	add_child(_elite_nameplate)

	_elite_hp_bar_bg = ColorRect.new()
	_elite_hp_bar_bg.color = Color(1.0, 0.85, 0.2) # 등급 테두리색(골드) — 배경째로 테두리처럼 보이게.
	_elite_hp_bar_bg.position = Vector2(-_ELITE_HP_BAR_WIDTH_PX * 0.5, -12.0)
	_elite_hp_bar_bg.size = Vector2(_ELITE_HP_BAR_WIDTH_PX, _ELITE_HP_BAR_HEIGHT_PX)
	add_child(_elite_hp_bar_bg)

	_elite_hp_bar_fill = ColorRect.new()
	_elite_hp_bar_fill.color = Color(0.85, 0.15, 0.15)
	_elite_hp_bar_fill.position = _elite_hp_bar_bg.position + Vector2(1.0, 1.0)
	_elite_hp_bar_fill.size = Vector2(_ELITE_HP_BAR_WIDTH_PX - 2.0, _ELITE_HP_BAR_HEIGHT_PX - 2.0)
	add_child(_elite_hp_bar_fill)


func _update_elite_hp_bar() -> void:
	if _elite_hp_bar_fill == null or max_hp <= 0:
		return
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_elite_hp_bar_fill.size.x = (_ELITE_HP_BAR_WIDTH_PX - 2.0) * ratio


## 호루라기/웨이브 시전 중 표시(붉은 예고 점멸과 구분되는 유틸 액션 색, Tuning 참고).
## _start_telegraph_flash()와 동일하게 유한 사이클(무한 루프 아님)로 만들어, 시전이
## 피격으로 중간에 끊겨도(HURT 전이) 낡은 tween이 남아 이후 modulate를 오염시키지
## 않는다 — _state_timer 만료 시점과 대략 맞도록 cast_sec 기준 사이클 수만 계산한다.
func _start_cast_flash() -> void:
	if sprite == null:
		return
	var cast_sec: float = whistle_cast_sec if state == State.WHISTLE else wave_cast_sec
	var original: Color = sprite.modulate
	var tween := sprite.create_tween()
	var cycles: int = max(int(round(cast_sec / 0.3)), 1)
	for i in cycles:
		tween.tween_property(sprite, "modulate", Tuning.WHISTLE_CAST_FLASH_COLOR, 0.15)
		tween.tween_property(sprite, "modulate", original, 0.15)


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
	_update_elite_hp_bar()
	if hp <= 0:
		_enter_state(State.DEAD)
		Events.enemy_died.emit(self, source_hitbox.source)
		if tier == "elite":
			Events.elite_died.emit(self, source_hitbox.source)
	elif wave_once_per_life and MonsterAiCalc.should_trigger_wave(hp, max_hp, wave_trigger_hp_pct, _wave_triggered):
		# 소환 웨이브(§1-2)는 일반 HURT 경직보다 우선한다 — HP 50% 관문을 넘는 그 히트가
		# 곧바로 대규모 소환의 방아쇠가 된다("페이즈 전환"에 준하는 취급).
		_wave_triggered = true
		AudioManager.play_sfx(StringName("%s_hurt" % monster_id), global_position)
		_enter_state(State.WAVE)
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
