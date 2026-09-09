## 고블린 정찰병 호루라기 증원 호출(§1-1-1) 통합 테스트 — 순수 판정(filter_whistle_
## candidates)은 test_monster_ai_calc.gd가 이미 다루므로, 여기서는 실제 MonsterBase
## 상태머신(WHISTLE 진입/완료/쿨다운, 대상 CHASE 강제, 피격에 의한 시전 취소)을 확인한다.
extends GutTest

const GoblinScoutScene := preload("res://scenes/entities/monsters/GoblinScout.tscn")
const SlimeScene := preload("res://scenes/entities/monsters/Slime.tscn")
const MushroomScene := preload("res://scenes/entities/monsters/Mushroom.tscn")
const HitboxScript := preload("res://scripts/systems/hitbox.gd")


func _make(scene: PackedScene, pos: Vector2) -> MonsterBase:
	var m: MonsterBase = scene.instantiate()
	add_child_autofree(m)
	m.global_position = pos
	return m


func _make_player_at(pos: Vector2) -> Node2D:
	var p := Node2D.new()
	add_child_autofree(p)
	p.global_position = pos
	return p


func test_whistle_summon_forces_pool_members_in_range_into_chase() -> void:
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout._player = _make_player_at(Vector2(50, 0)) # aggro_range_px=110 이내.

	var near_slime := _make(SlimeScene, Vector2(20, 0)) # whistle_range_px=140 이내, pool 소속.
	var far_slime := _make(SlimeScene, Vector2(500, 0)) # 범위 밖.
	var near_mushroom := _make(MushroomScene, Vector2(10, 0)) # pool 밖 종.

	scout._do_whistle_summon()

	assert_eq(near_slime.state, MonsterBase.State.CHASE, "풀 소속 + 범위 안 대상은 강제 CHASE(§1-1-1)")
	assert_eq(near_slime._player, scout._player, "호출자의 플레이어 참조를 그대로 넘겨받아야 한다")
	assert_ne(far_slime.state, MonsterBase.State.CHASE, "whistle_range_px 밖 대상은 호출되지 않는다")
	assert_ne(near_mushroom.state, MonsterBase.State.CHASE, "whistle_summon_pool에 없는 종은 호출되지 않는다")


func test_whistle_summon_respects_count_limit() -> void:
	# elite_goblin_captain 기준(whistle_summon_count=2)으로 대상이 더 많아도 2명까지만.
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout.whistle_summon_count = 1 # goblin_scout 기본값(1) 그대로 명시.
	scout._player = _make_player_at(Vector2(50, 0))
	var s1 := _make(SlimeScene, Vector2(10, 0))
	var s2 := _make(SlimeScene, Vector2(15, 0))

	scout._do_whistle_summon()

	var chase_count := 0
	for s in [s1, s2]:
		if (s as MonsterBase).state == MonsterBase.State.CHASE:
			chase_count += 1
	assert_eq(chase_count, 1, "whistle_summon_count(1)만큼만 호출되어야 한다")


func test_whistle_cast_completion_summons_and_resets_cooldown() -> void:
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout._player = _make_player_at(Vector2(50, 0))
	var near_slime := _make(SlimeScene, Vector2(10, 0))

	scout._enter_state(MonsterBase.State.WHISTLE)
	assert_almost_eq(scout._state_timer, scout.whistle_cast_sec, 0.0001)

	scout._state_timer = 0.0
	scout._physics_process(0.001)

	assert_eq(scout.state, MonsterBase.State.CHASE, "시전 완료 후 CHASE로 복귀")
	assert_almost_eq(scout._whistle_cooldown_remaining, scout.whistle_cooldown_sec, 0.01,
		"시전 완료 시 쿨다운(12초)이 다시 채워져야 한다")
	assert_eq(near_slime.state, MonsterBase.State.CHASE, "시전 완료와 함께 실제 호출도 일어나야 한다")


func test_maybe_start_whistle_requires_ready_cooldown_and_player_in_aggro_range() -> void:
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout._player = _make_player_at(Vector2(50, 0)) # aggro_range_px=110 이내.
	scout._enter_state(MonsterBase.State.IDLE)

	scout._maybe_start_whistle()
	assert_eq(scout.state, MonsterBase.State.WHISTLE, "쿨다운 준비 + 인지범위 안이면 시전 시작")

	scout._enter_state(MonsterBase.State.IDLE)
	scout._whistle_cooldown_remaining = 5.0
	scout._maybe_start_whistle()
	assert_ne(scout.state, MonsterBase.State.WHISTLE, "쿨다운 중에는 재시전하지 않는다")


func test_maybe_start_whistle_does_nothing_when_player_out_of_aggro_range() -> void:
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout._player = _make_player_at(Vector2(500, 0)) # aggro_range_px=110 밖.
	scout._enter_state(MonsterBase.State.IDLE)

	scout._maybe_start_whistle()

	assert_ne(scout.state, MonsterBase.State.WHISTLE, "인지 범위 밖이면 시전하지 않는다")


func test_whistle_cast_is_cancelled_by_taking_damage() -> void:
	# "정찰병에게 달려들어 시전을 끊는다"는 카운터플레이(§1-1-1) — 여느 상태와 동일하게
	# 피격은 곧바로 HURT로 전이시켜 WHISTLE 시전을 자연스럽게 무효화한다.
	var scout := _make(GoblinScoutScene, Vector2.ZERO)
	scout._enter_state(MonsterBase.State.WHISTLE)
	var hb: Hitbox = HitboxScript.new()
	add_child_autofree(hb)
	hb.damage = 1

	scout._on_hurtbox_hurt(hb)

	assert_eq(scout.state, MonsterBase.State.HURT, "피격 시 시전 중이어도 즉시 끊겨야 한다")
