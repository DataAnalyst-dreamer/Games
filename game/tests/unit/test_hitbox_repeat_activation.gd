## 회귀 방지: 대상이 활성화 사이에 히트박스 영역을 벗어나지 않고 계속 겹쳐 있어도
## activate()를 다시 호출하면 매번 새로 판정해야 한다(콤보 2·3타가 사거리 안에 가만히
## 서 있는 적을 계속 맞혀야 하는 일반적인 경우).
##
## 배경(디버깅 세션에서 실측, docs/qa/review-m1-1-m1-2.md Major-2 조사 중 발견): 실제
## Area2D의 area_entered 시그널은 "새로 겹친" 순간에만 발생한다. monitoring이 한 번도
## 꺼지지 않고 계속 켜져 있었다면(대상이 자리를 벗어나지 않는 한), activate()를 다시
## 호출해도 area_entered가 재발화하지 않아 콤보 2·3타 데미지가 전혀 들어가지 않는
## 문제가 있었다 — 예전에는 히트스톱이 플레이어 노드 전체를 process_mode=DISABLED로
## 얼려 그 자식인 Hitbox가 물리 트리에서 잠깐 빠졌다 복귀하며 우연히 재감지되던 것에
## 암묵적으로 의존하고 있었다(QA Major-2 수정으로 그 우연한 재감지가 사라지며 노출됨).
##
## 이 테스트는 실제 Area2D 물리 판정(get_overlapping_areas 기반 재판정 로직)을 검증해야
## 하므로 씬 트리에 붙여 물리 프레임을 흘려보낸다.
extends GutTest

const HitboxScript := preload("res://scripts/systems/hitbox.gd")
const HurtboxScript := preload("res://scripts/systems/hurtbox.gd")


func _make_hitbox(team: StringName = &"player") -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.team = team
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	hb.add_child(shape)
	hb.collision_layer = 0
	hb.collision_mask = 2
	add_child_autofree(hb)
	return hb


func _make_hurtbox(team: StringName = &"enemy") -> Hurtbox:
	var hb: Hurtbox = HurtboxScript.new()
	hb.team = team
	var fake_body := Node2D.new()
	add_child_autofree(fake_body)
	hb.body = fake_body
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	hb.add_child(shape)
	hb.collision_layer = 2
	hb.collision_mask = 0
	add_child_autofree(hb)
	return hb


func test_reactivation_hits_target_that_never_left_the_area() -> void:
	var hitbox := _make_hitbox()
	var hurtbox := _make_hurtbox()
	# 같은 위치에 겹쳐 둔 채 한 번도 움직이지 않는다(콤보 대상이 사거리 안에 서 있는
	# 일반적인 상황과 동일).
	hitbox.global_position = Vector2.ZERO
	hurtbox.global_position = Vector2.ZERO

	var hit_count := [0]
	hurtbox.hurt.connect(func(_hb): hit_count[0] += 1)

	hitbox.activate() # 1타.
	await wait_physics_frames(3)
	assert_eq(hit_count[0], 1, "1타는 겹쳐 있는 대상을 맞혀야 한다")

	hitbox.activate() # 2타 — 대상은 그 자리에 그대로 있다.
	await wait_physics_frames(3)
	assert_eq(hit_count[0], 2, "2타도 같은 자리에 서 있는 대상을 다시 맞혀야 한다(회귀 지점)")

	hitbox.activate() # 3타.
	await wait_physics_frames(3)
	assert_eq(hit_count[0], 3, "3타도 마찬가지로 다시 맞혀야 한다")
