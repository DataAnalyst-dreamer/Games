## Hitbox/Hurtbox 컴포넌트 테스트: 한 번의 휘두름 동안 같은 대상 중복 타격 방지(F2-1),
## 팀이 같으면 무시, 무적(invulnerable) 상태면 hurt 신호가 나가지 않음.
extends GutTest

const HitboxScript := preload("res://scripts/systems/hitbox.gd")
const HurtboxScript := preload("res://scripts/systems/hurtbox.gd")


func _make_hitbox(team: StringName = &"player") -> Hitbox:
	var hb: Hitbox = HitboxScript.new()
	hb.team = team
	add_child_autofree(hb)
	return hb


func _make_hurtbox(team: StringName = &"enemy") -> Hurtbox:
	var hb: Hurtbox = HurtboxScript.new()
	hb.team = team
	var fake_body := Node2D.new()
	add_child_autofree(fake_body)
	hb.body = fake_body
	add_child_autofree(hb)
	return hb


func test_hit_confirmed_once_per_activation() -> void:
	var hitbox := _make_hitbox()
	var hurtbox := _make_hurtbox()
	var hit_count := [0] # GDScript 람다는 외부 지역변수를 값으로 캡처하므로 배열로 우회.
	hurtbox.hurt.connect(func(_hb): hit_count[0] += 1)

	hitbox.activate()
	assert_true(hitbox.try_hit(hurtbox), "첫 타격은 성공해야 한다")
	assert_false(hitbox.try_hit(hurtbox), "같은 휘두름 중 같은 대상 재타격은 무시되어야 한다")
	assert_eq(hit_count[0], 1, "hurt 신호는 한 번만 발생해야 한다")


func test_reactivation_clears_hit_history() -> void:
	var hitbox := _make_hitbox()
	var hurtbox := _make_hurtbox()

	hitbox.activate()
	hitbox.try_hit(hurtbox)
	hitbox.deactivate()
	hitbox.activate() # 새 휘두름 시작 → 히트 기록 초기화
	assert_true(hitbox.try_hit(hurtbox), "재활성화 후에는 같은 대상도 다시 맞을 수 있다")


func test_same_team_is_ignored() -> void:
	var hitbox := _make_hitbox(&"enemy")
	var hurtbox := _make_hurtbox(&"enemy")
	hitbox.activate()
	assert_false(hitbox.try_hit(hurtbox), "같은 팀끼리는 타격이 성립하지 않는다")


func test_invulnerable_hurtbox_ignores_hit() -> void:
	var hitbox := _make_hitbox()
	var hurtbox := _make_hurtbox()
	hurtbox.invulnerable = true
	var hit_count := [0]
	hurtbox.hurt.connect(func(_hb): hit_count[0] += 1)

	hitbox.activate()
	# try_hit 자체는 "새 대상"으로 기록되지만(무적은 receive_hit 내부에서 걸러짐),
	# hurt 신호는 나가지 않아야 한다.
	hitbox.try_hit(hurtbox)
	assert_eq(hit_count[0], 0, "무적 상태에서는 hurt 신호가 나가지 않아야 한다")


func test_different_targets_can_both_be_hit_in_same_activation() -> void:
	var hitbox := _make_hitbox()
	var hurtbox_a := _make_hurtbox()
	var hurtbox_b := _make_hurtbox()
	hitbox.activate()
	assert_true(hitbox.try_hit(hurtbox_a))
	assert_true(hitbox.try_hit(hurtbox_b), "다른 대상은 같은 휘두름 중에도 각각 맞을 수 있다")
