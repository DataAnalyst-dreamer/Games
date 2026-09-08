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

	# 타격 임팩트 SFX(sound-map-m1.md §2/§12): Events 구독만으로는 hitbox.is_heavy가
	# 페이로드에 없어 강공격/일반을 구분할 수 없으므로 여기서 직접 호출한다. Hitstop.
	# apply_to() 호출과 같은 프레임에, 가능한 한 그 직전에 재생해야 화면이 얼어붙기
	# 전에 이미 소리가 나고 있다("즉시 느껴짐", GDD 4.2 원칙 1).
	AudioManager.play_sfx(&"hit_heavy" if hitbox.is_heavy else &"hit_normal", defender_body.global_position)
	if is_advantage:
		AudioManager.play_sfx(&"hit_critical_layer", defender_body.global_position)

	# 히트스톱: 공격자·피격자 양측(F2-2 "양측 0.05~0.1초 히트스톱").
	#
	# QA 리뷰 Major-2 수정(docs/qa/review-m1-1-m1-2.md): Player 전체 노드를 얼리면
	# process_mode=DISABLED가 자식까지 강제 전파되어 Player._unhandled_input()도 함께
	# 차단된다 — 콤보 입력 버퍼(0.2s)와 히트스톱 창이 겹치는 프레임(적이 사거리 경계에
	# 있거나 이동형 적 상대)에서 재입력이 소실된다. Player는 노드 전체 대신 "보이는
	# 부분"(스프라이트+무기 스프라이트)만 얼려 시각적 정지감은 유지하되
	# _unhandled_input/물리 처리는 계속 흐르게 한다. 몬스터 등 입력이 없는 노드는 기존대로
	# 노드 전체를 얼린다.
	var nodes_to_freeze: Array = []
	_collect_freeze_targets(defender_body, nodes_to_freeze)
	_collect_freeze_targets(hitbox.source, nodes_to_freeze)
	Hitstop.apply_to(nodes_to_freeze, hitbox.hitstop_sec)

	if hitbox.knockback_px > 0.0:
		_apply_knockback(defender_body, _knockback_direction(defender_body, hitbox), hitbox.knockback_px)

	if flash_target != null:
		HitFlash.flash(flash_target)

	spawn_damage_number(defender_body, damage, is_advantage)

	# M1에는 LUK 기반 진짜 크리티컬이 없다(is_critical은 항상 false) — is_advantage(원소
	# 상성 적중)와 이름이 뒤바뀌어 있던 문제를 바로잡았다(events.gd 주석 참고).
	Events.hit_landed.emit(hitbox.source, defender_body, damage, is_advantage, false)

	# 카메라 셰이크 4단계(addendum §3-2, D-63 예정): 피격자가 플레이어면 "hit" 티어
	# (몬스터 공격력·종 무관 일괄), 그 외(플레이어가 몬스터를 때린 경우)는 원소 상성
	# 적중이면 "crit", 강공격/피니셔면 "heavy", 그 외는 "normal"(진폭 0, GDD 4.2 그대로
	# 셰이크 없음). 히트스톱이 화면을 프리즈하는 동안은 안 보이므로 해제 직후 시작한다.
	var shake_tier: String = "normal"
	if defender_body is Player:
		shake_tier = "hit"
	elif is_advantage:
		shake_tier = "crit"
	elif hitbox.is_heavy:
		shake_tier = "heavy"
	_request_shake_after_hitstop(defender_body, shake_tier, hitbox.hitstop_sec)

	return damage


## Hitstop.apply_to()에 넘길 실제 대상을 고른다. Player는 노드 전체 대신 시각 요소만
## (입력 차단 방지, 위 apply() 주석 참고) — 그 외(몬스터 등)는 노드 그대로.
static func _collect_freeze_targets(body: Node, out: Array) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body is Player:
		var p := body as Player
		if p.sprite != null:
			out.append(p.sprite)
		if p.weapon_pivot != null:
			out.append(p.weapon_pivot)
	else:
		out.append(body)


static func _request_shake_after_hitstop(defender_body: Node2D, tier: String, hitstop_sec: float) -> void:
	var amplitude_px: float = float(Data.get_value("combat", "camera_shake.%s.amplitude_px" % tier, 0.0))
	var duration_sec: float = float(Data.get_value("combat", "camera_shake.%s.duration_sec" % tier, 0.0))
	if amplitude_px <= 0.0:
		return
	var tree: SceneTree = defender_body.get_tree() if defender_body != null and is_instance_valid(defender_body) else null
	if hitstop_sec <= 0.0 or tree == null:
		Events.screen_shake_requested.emit(amplitude_px, duration_sec)
		return
	tree.create_timer(hitstop_sec).timeout.connect(func() -> void:
		Events.screen_shake_requested.emit(amplitude_px, duration_sec)
	)


static func _knockback_direction(defender_body: Node2D, hitbox: Hitbox) -> Vector2:
	if hitbox.source != null and is_instance_valid(hitbox.source) and hitbox.source is Node2D:
		var diff: Vector2 = defender_body.global_position - (hitbox.source as Node2D).global_position
		if diff.length() > 0.001:
			return diff.normalized()
	return Vector2.DOWN


static func _apply_knockback(body: Node2D, direction: Vector2, distance_px: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var duration: float = float(Data.get_value("combat", "knockback.duration_sec", 0.12))
	var target: Vector2 = body.global_position + direction * distance_px
	var tween := body.create_tween()
	tween.tween_property(body, "global_position", target, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## public: 가드 칩데미지 등 HitFeel.apply() 전체 파이프라인을 타지 않는 경로(플레이어
## Guard 상태의 부분 피해 표시 등)에서도 같은 데미지 숫자 연출을 재사용하기 위해 공개.
static func spawn_damage_number(at_body: Node2D, damage: int, is_advantage: bool) -> void:
	if at_body == null or not is_instance_valid(at_body):
		return
	var tree := at_body.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var number := DamageNumberScene.instantiate()
	tree.current_scene.add_child(number)
	number.global_position = at_body.global_position + Vector2(0, -12)
	number.setup(damage, is_advantage)
