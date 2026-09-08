## 피격 시 공용 타격감 연출 패키지(F2-2): 히트스톱 · 넉백 · 흰색 플래시+점멸 ·
## 데미지 숫자 · (강공격/크리티컬 한정) 카메라 셰이크. Player/MonsterBase가 자신의
## Hurtbox.hurt 신호를 받아 이 정적 함수를 호출한다. 최종 데미지(속성 배율 반영,
## 정수)를 반환하므로 호출부는 HP 차감·사망 판정만 하면 된다.
class_name HitFeel
extends RefCounted

const DamageNumberScene := preload("res://scenes/effects/DamageNumber.tscn")


## defender_body: 피격자 루트 노드(넉백·데미지 숫자 위치 기준).
## flash_target: 흰색 점멸시킬 스프라이트(CanvasItem). null이면 플래시 생략.
## defender_element/defender_tags: 상성 계산용(공격자 속성은 hitbox.element).
static func apply(defender_body: Node2D, flash_target: CanvasItem, hitbox: Hitbox,
		defender_element: String = "", defender_tags: Array = []) -> int:
	var elements_table: Dictionary = Data.table("elements")
	var multiplier: float = ElementCalc.get_multiplier(
		String(hitbox.element), defender_element, defender_tags, elements_table)
	var damage: int = int(round(hitbox.damage * multiplier))
	var is_advantage: bool = multiplier > 1.0

	# 히트스톱: 공격자·피격자 양측(F2-2 "양측 0.05~0.1초 히트스톱").
	var nodes_to_freeze: Array = [defender_body]
	if hitbox.source != null and is_instance_valid(hitbox.source):
		nodes_to_freeze.append(hitbox.source)
	Hitstop.apply_to(nodes_to_freeze, hitbox.hitstop_sec)

	if hitbox.knockback_px > 0.0:
		_apply_knockback(defender_body, _knockback_direction(defender_body, hitbox), hitbox.knockback_px)

	if flash_target != null:
		HitFlash.flash(flash_target)

	_spawn_damage_number(defender_body, damage, is_advantage)

	Events.hit_landed.emit(hitbox.source, defender_body, damage, is_advantage)

	# 카메라 셰이크는 강공격/크리티컬(3타 피니셔 포함)에만 적용한다(F2-2).
	if hitbox.is_heavy:
		Events.screen_shake_requested.emit(Tuning.SHAKE_AMPLITUDE_HEAVY, Tuning.SHAKE_DURATION_HEAVY)

	return damage


static func _knockback_direction(defender_body: Node2D, hitbox: Hitbox) -> Vector2:
	if hitbox.source != null and is_instance_valid(hitbox.source) and hitbox.source is Node2D:
		var diff: Vector2 = defender_body.global_position - (hitbox.source as Node2D).global_position
		if diff.length() > 0.001:
			return diff.normalized()
	return Vector2.DOWN


static func _apply_knockback(body: Node2D, direction: Vector2, distance_px: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var duration: float = Tuning.KNOCKBACK_DURATION_SEC
	var target: Vector2 = body.global_position + direction * distance_px
	var tween := body.create_tween()
	tween.tween_property(body, "global_position", target, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _spawn_damage_number(at_body: Node2D, damage: int, is_advantage: bool) -> void:
	if at_body == null or not is_instance_valid(at_body):
		return
	var tree := at_body.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var number := DamageNumberScene.instantiate()
	tree.current_scene.add_child(number)
	number.global_position = at_body.global_position + Vector2(0, -12)
	number.setup(damage, is_advantage)
