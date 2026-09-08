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
