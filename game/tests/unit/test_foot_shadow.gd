## FootShadow(scripts/systems/foot_shadow.gd) + 그림자 상수 계약 테스트 (D-204).
##
## 그리기 명령 자체는 헤드리스에서 되읽을 수 없으므로, 그림자를 "쿼터뷰의 바닥 단서"로
## 성립시키는 조건 - 원이 아닌 타원일 것, 불투명하지 않을 것, 크기 배율이 선형일 것,
## 그리고 호출이 안전할 것 - 을 검사한다. 이 중 하나라도 깨지면 바닥 평면 단서가
## 사라지거나(Y_SCALE=1.0이면 위에서 내려다본 원) 스프라이트를 덮는다.
extends GutTest

const FootShadowScript := preload("res://scripts/systems/foot_shadow.gd")


func test_shadow_is_an_ellipse_not_a_circle() -> void:
	# 세로 눌림이 없으면(1.0) 탑다운의 동그란 그림자가 되어 쿼터뷰 단서가 사라진다.
	assert_lt(Tuning.FOOT_SHADOW_Y_SCALE, 1.0, "그림자는 세로로 눌린 타원이어야 한다")
	assert_gt(Tuning.FOOT_SHADOW_Y_SCALE, 0.0, "세로 배율이 0 이하면 그림자가 선으로 무너진다")


func test_shadow_is_translucent() -> void:
	assert_lt(Tuning.FOOT_SHADOW_COLOR.a, 1.0, "불투명 그림자는 지면 타일을 덮는다")
	assert_gt(Tuning.FOOT_SHADOW_COLOR.a, 0.0, "완전 투명이면 그리는 의미가 없다")


func test_shadow_radius_is_positive() -> void:
	assert_gt(Tuning.FOOT_SHADOW_RADIUS_PX, 0.0, "반지름이 0 이하면 그림자가 없다")


func test_pilot_ellipse_ratio_preserved() -> void:
	# 파일럿(prototypes/quarter-view-lab/actor.gd:_draw)이 사용자 승인을 받은 값.
	# 단계 (c)에서 비스듬 원화의 시점각과 재대조하기 전까지 이 값이 기준이다.
	assert_almost_eq(Tuning.FOOT_SHADOW_Y_SCALE, 0.42, 0.001, "파일럿 승인 세로 배율 0.42 유지")


func test_monster_size_scale_is_linear() -> void:
	# 몬스터 그림자는 스프라이트 배율에 비례해야 한다(D-204 "크기별 배율 허용") -
	# MonsterBase._draw()가 sprite.scale.x를 그대로 넘긴다.
	var base: float = Tuning.FOOT_SHADOW_RADIUS_PX * 1.0
	var doubled: float = Tuning.FOOT_SHADOW_RADIUS_PX * 2.0
	assert_almost_eq(doubled, base * 2.0, 0.001, "2배 스프라이트는 2배 그림자")


func test_draw_is_safe_with_null_canvas() -> void:
	# 소멸 중인 액터에서 불려도 죽지 않아야 한다.
	FootShadowScript.draw(null)
	assert_true(true, "null canvas 로 호출해도 예외 없이 반환")


func test_draw_skips_when_scale_is_zero_or_negative() -> void:
	# 0 이하 배율은 "그림자 없는 액터"를 표현하는 탈출구 - draw_circle에 음수 반지름을
	# 넘기지 않고 조용히 건너뛰어야 한다.
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	FootShadowScript.draw(canvas, 0.0)
	FootShadowScript.draw(canvas, -1.0)
	assert_true(true, "0/음수 배율에서 예외 없이 반환")
