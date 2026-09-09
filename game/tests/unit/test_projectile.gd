## 투사체(Projectile, M2-3 ranged_dart) 팀 판정 + 발사 방향/속도 테스트.
## Hitbox 자체의 중복 타격/무적 규칙은 test_hitbox.gd가 이미 담당하므로, 여기서는
## Projectile 씬이 그 규칙을 그대로 상속하는지(팀=enemy로 스폰됨)와 launch()가
## velocity를 monsters.json 기반 값대로 세팅하는지만 확인한다.
extends GutTest

const ProjectileScene := preload("res://scenes/effects/Projectile.tscn")
const HurtboxScript := preload("res://scripts/systems/hurtbox.gd")


func _make_projectile() -> Projectile:
	var proj: Projectile = ProjectileScene.instantiate()
	add_child_autofree(proj)
	return proj


func _make_hurtbox(team: StringName) -> Hurtbox:
	var hb: Hurtbox = HurtboxScript.new()
	hb.team = team
	var fake_body := Node2D.new()
	add_child_autofree(fake_body)
	hb.body = fake_body
	add_child_autofree(hb)
	return hb


func test_projectile_hitbox_defaults_to_enemy_team() -> void:
	var proj := _make_projectile()
	assert_eq(proj.hitbox.team, &"enemy", "고블린 다트는 몬스터(enemy) 팀 판정으로 스폰되어야 한다")


func test_projectile_hits_player_team_but_not_enemy_team() -> void:
	var proj := _make_projectile()
	proj.launch(Vector2.RIGHT, 220.0, 1.2)

	var player_hurtbox := _make_hurtbox(&"player")
	var enemy_hurtbox := _make_hurtbox(&"enemy")

	assert_true(proj.hitbox.try_hit(player_hurtbox), "다트는 플레이어(다른 팀)를 맞혀야 한다")
	assert_false(proj.hitbox.try_hit(enemy_hurtbox), "다트는 같은 팀(다른 몬스터)을 맞히면 안 된다")


func test_launch_sets_velocity_direction_and_speed() -> void:
	var proj := _make_projectile()
	proj.launch(Vector2.RIGHT, 220.0, 1.2)
	proj._physics_process(0.001)
	assert_almost_eq(proj.velocity.x, 220.0, 0.01, "발사 속도(dart speed)가 그대로 반영되어야 한다")
	assert_almost_eq(proj.velocity.y, 0.0, 0.01)


func test_launch_normalizes_non_unit_direction() -> void:
	var proj := _make_projectile()
	proj.launch(Vector2(3.0, 4.0), 100.0, 1.0) # length=5 → 정규화 필요.
	proj._physics_process(0.001)
	assert_almost_eq(proj.velocity.length(), 100.0, 0.01, "방향 벡터를 정규화한 뒤 속도를 곱해야 한다")


func test_hit_confirmed_frees_the_projectile() -> void:
	var proj := _make_projectile() # 이미 add_child_autofree()로 트리에 붙어 있다.
	proj.launch(Vector2.RIGHT, 220.0, 1.2)
	var hurtbox := _make_hurtbox(&"player")

	proj.hitbox.try_hit(hurtbox)
	await get_tree().process_frame # queue_free()는 다음 프레임에 실제 반영된다.
	assert_false(is_instance_valid(proj), "대상을 맞히면 다트는 소멸해야 한다")
