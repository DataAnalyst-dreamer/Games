## 플레이어 캐릭터 (CharacterBody2D).
##
## 실제 행동 로직은 StateMachine 자식(Idle/Move/...)에 있고, 이 스크립트는
## 입력 읽기·방향·애니메이션 재생 같은 공용 유틸리티와 콜백 위임만 담당한다.
class_name Player
extends CharacterBody2D

## 핀 시트의 액터 id(game/assets/iso/iso_actor_atlas.json 의 키).
const ACTOR_ID := "fin"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var weapon_pivot: Node2D = $WeaponPivot

## 바라보는 방향(8방향 중 하나, D-228). 공격 히트박스 방향 결정에도 쓴다.
var facing: Vector2 = Vector2.DOWN

## 발밑 그림자 배율. sprite.scale 이 1이 된 뒤(D-232) 크기 단서를 시트 계약이 준다.
var shadow_scale: float = 1.0

## 이동 속도(px/s). combat.json 에서 로드.
var walk_speed: float

## HP·스태미나 자원(F2-3). combat.json/Tuning 값으로 초기화.
var resources: PlayerResources

## 사망 처리가 끝나 더 이상 입력을 받지 않는지.
var is_dead: bool = false

## 대사 진행 중 이동·전투 입력 차단(D-257). `NpcDialogueController`가 대사 시작/종료
## 시 직접 set/clear한다(이 파일은 가드만 소유) — `get_move_input()` 가드만으로는
## attack/roll/guard를 못 막아(각 상태 스크립트가 `_unhandled_input`에서 직접
## `event.is_action_pressed(...)`로 처리) `_unhandled_input()` 최상단에도 얼리리턴을 둔다.
var dialogue_active: bool = false

## 무적 프레임 잔여 시간(초). Hurt 상태를 벗어난 뒤에도 계속 줄어들어야 하므로
## (상태 전환과 무관하게) Player._process에서 직접 관리한다.
var _iframe_remaining: float = 0.0

## 장비 스탯 합산 결과(M2-1, F3-2 — GameState._apply_equipment_stats_to_player()가
## Equipment.compute_stats() 결과로 채운다). D-162(M3-3): defense_formula가 확정돼
## hit_feel.gd:apply()가 VIT 분배분과 합산해 실제 피해 감소에 소비한다.
var equip_attack_bonus: float = 0.0
var equip_defense: float = 0.0
var _base_walk_speed: float = 0.0

## D-128: 마지막 facing 축(수평/수직) 전환 이후 흐른 시간(초). FacingCalc.resolve_facing()의
## 시간 기반 디바운스에 넘기는 값 — _physics_process에서 델타를 누적하고, set_facing()이
## 실제로 축을 바꿀 때만 0으로 리셋한다. 초기값을 크게 잡아 최초 입력 시 디바운스가
## 걸리지 않게 한다.
var _facing_axis_switch_elapsed: float = 1e9

## D-127(재현: 콤보 3타를 빠르게 잇거나 구르기 캔슬/피격으로 Attack 상태가 tween 완료
## 전에 exit()되면, 숨김 콜백이 실행되기 전에 다음 상태로 넘어가 무기가 계속 보이는
## 상태로 남았다) — play_attack_swing()이 만든 tween을 보관해, 같은 노드에 여러 tween이
## 동시에 걸리는 상황 자체를 없애고(hide_weapon_overlay에서 kill), 숨김을 tween 콜백에만
## 의존하지 않고 상태 exit() 시점에 명시적으로 강제할 수 있게 한다.
var _weapon_tween: Tween = null


func _ready() -> void:
	# M5-2(미니맵): NodePath export는 중첩 인스턴싱에서 깨진 전례가 있어(hud_progress.gd
	# 주석 참고) 그룹 조회로 찾게 한다 — hud_minimap.gd가 이 그룹으로 플레이어를 찾는다.
	add_to_group(&"player")
	# QA 리뷰 Minor-2(docs/qa/review-m1-1-m1-2.md): fallback을 80.0(RELEASE_FALLBACKS와
	# 동일한 확정값)으로 맞춘다 — 예전엔 0.0이라 키가 사라지면 플레이어가 완전히
	# 움직이지 못하는 최악의 실패 모드가 조용히 발생했다.
	walk_speed = float(Data.get_value("combat", "movement.walk_speed_px", 80.0))
	_base_walk_speed = walk_speed
	# 등각 8방향 시트를 JSON 계약에서 조립한다(D-228~D-234) - 씬에는 AtlasTexture 를 두지
	# 않는다. 시트가 없으면 씬 원본이 그대로 남고 경고만 뜬다.
	ActorSheet.apply(sprite, ACTOR_ID)
	shadow_scale = ActorSheet.shadow_scale(ACTOR_ID)
	ActorSheet.set_speeds(sprite, Tuning.ANIM_IDLE_FPS, Tuning.ANIM_WALK_FPS,
		Tuning.ATTACK_HIT_DURATION_SEC)
	play_anim("idle")
	resources = PlayerResources.new(
		Tuning.PLAYER_MAX_HP,
		float(Data.get_value("combat", "stamina.max", 100.0)),
		float(Data.get_value("combat", "stamina.regen_per_sec", 25.0)),
		float(Data.get_value("combat", "stamina.regen_delay_sec", 0.5)),
		float(Data.get_value("combat", "stamina.exhausted_penalty_sec", 1.0)),
	)
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	queue_redraw() # D-204: 발밑 그림자 최초 그리기.
	Events.player_spawned.emit(self)
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)
	Events.player_stamina_changed.emit(resources.stamina, resources.max_stamina)


## 발밑 타원 그림자(D-204). CanvasItem._draw()는 자식 노드(AnimatedSprite2D)보다 먼저
## 그려지므로, 여기서 그리면 전용 노드 없이도 그림자가 스프라이트 아래에 깔린다.
## 본체 좌표계에 그리므로 이동할 때마다 다시 그릴 필요가 없다 - _ready()의 queue_redraw()
## 한 번이면 충분하다(씬 진입 시의 최초 NOTIFICATION_DRAW를 놓치지 않기 위한 보험).
## 반지름은 MonsterBase와 같은 규칙으로 sprite.scale 을 곱해 구한다 - 그래야 단위
## 전환(D-206)처럼 스프라이트 배율이 통째로 바뀔 때 두 곳이 따로 놀지 않는다.
func _draw() -> void:
	FootShadow.draw(self, shadow_scale)


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or dialogue_active:
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
	# D-128: 마지막 축 전환 후 흐른 시간을 누적한다(set_facing이 사용). 축이 전환되는
	# 프레임에 set_facing() 안에서 0으로 리셋된다.
	_facing_axis_switch_elapsed += delta
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
	# M1-4 계측(Metrics.gd): 저스트 가드 성공률의 분모 — 저스트 성공/일반 가드/가드 붕괴
	# (스태미나 고갈로 무가드 전환) 모두를 포함해 "가드 상태였던 피격 시도 총횟수"를 센다.
	Events.guard_hit_attempted.emit(self, source_hitbox.source)
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
	# M4-4(D-168): guard_steadfast(guard_damage_reduction_pct 패시브)만큼 칩데미지가 더 줄어든다.
	var chip_ratio: float = float(Data.get_value("combat", "guard.chip_damage_ratio", 0.2)) \
		* maxf(0.0, 1.0 - Progression.passive_bonus("guard_damage_reduction_pct") * 0.01)
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


## 구르기 스태미나 비용(DEX 경감 훅 포함, S2-1b 규칙 §3-3). M3-3: 실제 분배된 DEX를 쓴다.
func get_roll_cost() -> float:
	var base_cost: float = float(Data.get_value("combat", "stamina.costs.roll", 20.0))
	var dex: float = float(GameState.stats.get("dex", 0))
	return PlayerResources.roll_cost_with_dex(base_cost, dex)


func has_stamina_for_roll() -> bool:
	return resources.stamina >= get_roll_cost()


## GameState._apply_equipment_stats_to_player()가 장착/해제 때마다 호출한다(F3-2 "장착
## 즉시 스탯 재계산"). stats: Equipment.compute_stats()의 반환값(attack/defense/max_hp/
## speed_pct). max_hp 증가분은 즉시 채워주고(가득 찬 채로 장착했다는 느낌), 감소분은
## 현재 HP를 새 상한으로 클램프만 한다(체력 손실 없이 안전).
func apply_equipment_stats(stats: Dictionary) -> void:
	equip_attack_bonus = float(stats.get("attack", 0.0))
	equip_defense = float(stats.get("defense", 0.0))
	var new_max_hp: int = Tuning.PLAYER_MAX_HP + int(stats.get("max_hp", 0))
	var hp_gain: int = maxi(new_max_hp - resources.max_hp, 0)
	resources.max_hp = new_max_hp
	resources.hp = clampi(resources.hp + hp_gain, 0, resources.max_hp)
	walk_speed = _base_walk_speed * (1.0 + float(stats.get("speed_pct", 0.0)))
	Events.player_hp_changed.emit(resources.hp, resources.max_hp)


## 실제 타격 데미지 계산이 읽는 공격력(F2-1 기본값 + 장비 합산, M2-1 + STR 분배분, M3-3).
func get_attack_power() -> float:
	# M3-1(F1-2): 레벨업 자동 공격력 상승분(GameState.level_stat_bonus.attack, exp_curve.csv
	# atk_bonus 누적치)을 장비 보너스와 합산한다.
	var str_bonus: float = StatCalc.attack_bonus(
		int(GameState.stats.get("str", 0)), float(Data.get_value("stats", "str.physical_damage_per_point", 0.2)))
	var base: float = Tuning.PLAYER_BASE_ATTACK + equip_attack_bonus \
		+ float(GameState.level_stat_bonus.get("attack", 0.0)) + str_bonus
	# M4-4(D-168/D-193): blade_focus(atk_pct 패시브)와 blade_bloodlust(atk_buff_pct 버프)를
	# 곱연산으로 합성한다 — 둘 다 %, 계산은 Progression 한 곳.
	return base * (1.0 + (Progression.passive_bonus("atk_pct") + Progression.buff_pct("atk_buff_pct")) * 0.01)


## Knight의 방향별 단일 공격 자세(D-137) 위에 무기 회전으로 휘두름을 표현한다.
## 새 원작 6f 공격(T04~06) 전까지의 임시 연출이며 콤보/판정 시간은 기존 값을 유지한다.
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
	weapon_pivot.position = facing * Tuning.WEAPON_PIVOT_OFFSET_PX
	weapon_pivot.rotation = start_angle
	weapon_pivot.visible = true
	# D-127: 이전 타의 tween이 아직 실행 중이면 kill 해서(콤보 2·3타 빠른 입력 시) 같은
	# 노드에 tween이 겹쳐 걸리는 상황 자체를 없앤다.
	if _weapon_tween != null and _weapon_tween.is_valid():
		_weapon_tween.kill()
	_weapon_tween = weapon_pivot.create_tween()
	_weapon_tween.tween_property(weapon_pivot, "rotation", end_angle, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_weapon_tween.tween_callback(func() -> void:
		if is_instance_valid(weapon_pivot):
			weapon_pivot.visible = false
	)


## D-127: tween 콜백에만 의존하지 않고 무기 오버레이를 즉시 숨긴다. Attack 상태
## exit()에서 호출한다(콤보 중간에 구르기 캔슬·피격 등으로 Attack을 벗어나는 모든
## 경로가 PlayerStateMachine.transition_to()를 거치며 반드시 exit()를 호출하므로,
## 이 한 곳만으로 "공격 중이 아닌데 무기가 남아있는" 상태를 방지할 수 있다).
func hide_weapon_overlay() -> void:
	if _weapon_tween != null and _weapon_tween.is_valid():
		_weapon_tween.kill()
	if weapon_pivot != null:
		weapon_pivot.visible = false


## 8방향 이동 입력(정규화). 스틱 데드존은 project.godot 액션 deadzone 이 처리한다.
func get_move_input() -> Vector2:
	if dialogue_active:
		return Vector2.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", Tuning.STICK_DEADZONE)
	return v


## 입력 벡터를 8방향 facing 으로 환산한다(D-228, 등각에서는 4방향이 격자 대각과 45도
## 어긋난다 - isometric-migration-v1.md §4). 양자화는 **화면 벡터** 기준 45도 균등이다.
## D-121/D-128 의 두 완충은 그대로 살아 있다: FacingCalc.resolve_facing_8()이 현재 방향
## ±(22.5 x bias)도 안에서는 방향을 유지하고(크기 완충), 인접 섹터(±45도) 전환은 마지막
## 전환 후 Tuning.FACING_AXIS_SWITCH_MIN_INTERVAL_SEC 동안 보류한다(시간 디바운스, D-229).
## 2섹터 이상 차이는 의도한 큰 전환이라 즉시 통과한다 - 4방향 시절 180도 반전을 막지
## 않았던 것과 같은 규칙이다.
func set_facing(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		return
	var new_facing: Vector2 = FacingCalc.resolve_facing_8(
		facing, input_dir, Tuning.FACING_AXIS_SWITCH_BIAS,
		_facing_axis_switch_elapsed, Tuning.FACING_AXIS_SWITCH_MIN_INTERVAL_SEC)
	if FacingCalc.sector_of(new_facing) != FacingCalc.sector_of(facing):
		_facing_axis_switch_elapsed = 0.0
	facing = new_facing


func facing_name() -> String:
	return ActorSheet.dir_name(ACTOR_ID, facing)


## "walk" → "walk_down" 식으로 방향 접미사를 붙여 재생. 같은 애니메이션이면 재시작하지 않는다.
func play_anim(base_name: String) -> void:
	var anim := ActorSheet.anim_name(ACTOR_ID, base_name, facing)
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
