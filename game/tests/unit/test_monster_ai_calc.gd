## MonsterAiCalc 순수 로직 테스트(addendum §4 — 돌진/장판 계산). Godot 노드 없이
## GUT에서 직접 검증한다.
extends GutTest

const AiCalc := preload("res://scripts/systems/monster_ai_calc.gd")


func test_is_in_melee_range() -> void:
	assert_true(AiCalc.is_in_melee_range(10.0, 14.0), "사거리 이내는 true")
	assert_true(AiCalc.is_in_melee_range(14.0, 14.0), "경계값은 포함")
	assert_false(AiCalc.is_in_melee_range(14.1, 14.0), "사거리 밖은 false")


func test_should_leash() -> void:
	assert_false(AiCalc.should_leash(139.9, 140.0), "leash 거리 이내면 추적 유지")
	assert_true(AiCalc.should_leash(140.0, 140.0), "경계값에서 추적 포기")
	assert_true(AiCalc.should_leash(200.0, 140.0), "leash 거리 밖이면 추적 포기")


func test_dash_velocity_scales_direction_by_speed() -> void:
	var v: Vector2 = AiCalc.dash_velocity(Vector2.RIGHT, 200.0)
	assert_eq(v, Vector2(200.0, 0.0), "뿔토끼 돌진(dash_speed_px=200) 속도 벡터")


func test_dash_velocity_zero_when_no_direction() -> void:
	assert_eq(AiCalc.dash_velocity(Vector2.ZERO, 200.0), Vector2.ZERO)


func test_spore_tick_damage_rounds_to_int() -> void:
	# 버섯돌이 atk_tick_per_sec=4.0(monsters.json) → 틱당 정수 데미지 4.
	assert_eq(AiCalc.spore_tick_damage(4.0), 4)
	assert_eq(AiCalc.spore_tick_damage(3.4), 3, "반올림 하한")
	assert_eq(AiCalc.spore_tick_damage(3.5), 4, "반올림 상한")


func test_should_stun_from_wall_collision() -> void:
	assert_true(AiCalc.should_stun_from_wall_collision(true, 1), "돌진 중 충돌 1건 이상이면 기절")
	assert_false(AiCalc.should_stun_from_wall_collision(true, 0), "충돌 없으면 기절 아님")
	assert_false(AiCalc.should_stun_from_wall_collision(false, 3), "돌진 중이 아니면 충돌해도 기절 아님(일반 이동)")


# --- M2-3: 호루라기/웨이브/분열 순수 로직(elite-and-farming-m2.md §1) ---

func test_is_whistle_ready() -> void:
	assert_true(AiCalc.is_whistle_ready(0.0), "쿨다운 0이면 사용 가능")
	assert_true(AiCalc.is_whistle_ready(-0.5), "음수(과소진)도 사용 가능 취급")
	assert_false(AiCalc.is_whistle_ready(0.01), "쿨다운이 남아 있으면 사용 불가")


func test_filter_whistle_candidates_excludes_pool_mismatch() -> void:
	var candidates: Array = [
		{"monster_id": "mushroom", "distance_px": 10.0},
		{"monster_id": "slime", "distance_px": 20.0},
	]
	var picked: Array = AiCalc.filter_whistle_candidates(candidates, ["horn_rabbit", "slime"], 140.0, 5)
	assert_eq(picked.size(), 1, "풀에 없는 monster_id는 제외되어야 한다")
	assert_eq(String(picked[0].get("monster_id")), "slime")


func test_filter_whistle_candidates_excludes_out_of_range() -> void:
	var candidates: Array = [
		{"monster_id": "slime", "distance_px": 141.0},
		{"monster_id": "slime", "distance_px": 139.0},
	]
	var picked: Array = AiCalc.filter_whistle_candidates(candidates, ["slime"], 140.0, 5)
	assert_eq(picked.size(), 1, "whistle_range_px를 초과하는 대상은 제외되어야 한다")
	assert_almost_eq(float(picked[0].get("distance_px")), 139.0, 0.0001)


func test_filter_whistle_candidates_sorts_by_distance_and_caps_at_count() -> void:
	var candidates: Array = [
		{"monster_id": "slime", "distance_px": 100.0, "tag": "far"},
		{"monster_id": "slime", "distance_px": 10.0, "tag": "near"},
		{"monster_id": "slime", "distance_px": 50.0, "tag": "mid"},
	]
	# elite_goblin_captain: whistle_summon_count=2 — 가장 가까운 2명만.
	var picked: Array = AiCalc.filter_whistle_candidates(candidates, ["slime"], 140.0, 2)
	assert_eq(picked.size(), 2)
	assert_eq(String(picked[0].get("tag")), "near")
	assert_eq(String(picked[1].get("tag")), "mid")


func test_should_trigger_wave_at_half_hp_once() -> void:
	# elite_goblin_captain: wave_trigger_hp_pct=0.5.
	assert_true(AiCalc.should_trigger_wave(60, 120, 0.5, false), "정확히 절반이면 발동")
	assert_true(AiCalc.should_trigger_wave(59, 120, 0.5, false), "절반 미만도 발동")
	assert_false(AiCalc.should_trigger_wave(61, 120, 0.5, false), "절반 초과는 아직")
	assert_false(AiCalc.should_trigger_wave(30, 120, 0.5, true), "이미 발동했으면(1회 한정) 다시 발동하지 않는다")
	assert_false(AiCalc.should_trigger_wave(0, 120, 0.5, false), "이미 죽은(hp<=0) 경우는 대상 아님")


func test_pick_non_overlapping_offsets_respects_min_separation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var offsets: Array = AiCalc.pick_non_overlapping_offsets(3, 60.0, 20.0, rng)
	assert_eq(offsets.size(), 3, "요청한 개수만큼 생성되어야 한다")
	for i in offsets.size():
		for j in range(i + 1, offsets.size()):
			assert_true((offsets[i] as Vector2).distance_to(offsets[j]) >= 20.0 - 0.01,
				"오프셋 %d/%d 간 최소 이격 거리를 지켜야 한다" % [i, j])


func test_pick_non_overlapping_offsets_is_deterministic_with_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var offsets_a: Array = AiCalc.pick_non_overlapping_offsets(3, 24.0, 20.0, rng_a)
	var offsets_b: Array = AiCalc.pick_non_overlapping_offsets(3, 24.0, 20.0, rng_b)
	assert_eq(offsets_a, offsets_b, "같은 시드면 같은 결과(GUT 재현성)여야 한다")


func test_leash_range_greater_than_melee_range_invariant_holds_for_m1_monsters() -> void:
	# data_tables.md §12 검증 규칙 4: leash_range_px > aggro_range_px > melee_range_px.
	# 여기서는 AiCalc 두 판정이 같은 거리에서 동시에 true가 될 수 없음을 확인한다
	# (불변식이 깨지면 CHASE가 TELEGRAPH/IDLE 사이에서 같은 프레임에 모순되게 판정될 수 있음).
	var melee_range := 16.0
	var leash_range := 180.0
	for i in range(0, 200, 5):
		var distance := float(i)
		var in_melee := AiCalc.is_in_melee_range(distance, melee_range)
		var leashed := AiCalc.should_leash(distance, leash_range)
		assert_false(in_melee and leashed, "distance=%s에서 melee와 leash가 동시에 참일 수 없다" % distance)
