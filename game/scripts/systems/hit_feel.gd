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

	# M3-3(D-162 (a)): defender가 플레이어면 VIT+장비 방어력을 damage_after_defense 공식으로
	# 적용한다. 몬스터 쪽 방어는 이번 범위 밖(몬스터는 armor 필드로 별도 관리, characters.json).
	if defender_body is Player:
		var p := defender_body as Player
		var vit: int = int(GameState.stats.get("vit", 0))
		var per_point: float = float(Data.get_value("stats", "vit.defense_per_point", 1.0))
		# M4-4(D-168): guard_bulwark(defense_flat 패시브)를 방어력에 더하고, guard_fortify
		# (dmg_reduction_pct 버프)를 최종 피해에 곱한다.
		var defense: float = StatCalc.defense_value(vit, per_point, p.equip_defense) \
			+ Progression.passive_bonus("defense_flat")
		damage = StatCalc.damage_after_defense(float(damage), defense)
		damage = int(round(float(damage) * maxf(0.0, 1.0 - Progression.buff_pct("dmg_reduction_pct") * 0.01)))

	# 타격 임팩트 SFX(sound-map-m1.md §2/§12): Events 구독만으로는 hitbox.is_heavy가
	# 페이로드에 없어 강공격/일반을 구분할 수 없으므로 여기서 직접 호출한다. Hitstop.
	# apply_to() 호출과 같은 프레임에, 가능한 한 그 직전에 재생해야 화면이 얼어붙기
	# 전에 이미 소리가 나고 있다("즉시 느껴짐", GDD 4.2 원칙 1).
	AudioManager.play_sfx(&"hit_heavy" if hitbox.is_heavy else &"hit_normal", defender_body.global_position)
	# D-162 (c): LUK 진짜 크리티컬이 원소 상성 적중과 같은 프레임에 겹쳐도 같은 레이어를
	# 한 번만 재생한다(둘 중 하나만 있어도 재생 — "LUK 크리 우선"은 전용 SFX가 아직 없어
	# 이 공용 레이어를 LUK 크리도 트리거하는 것으로 반영, audio-designer TODO: 구분 SFX).
	if is_advantage or hitbox.is_critical:
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
		HitFlash.flash(flash_target, hitbox.flash_color)

	# D-162 (c): 데미지 숫자는 하나만 띄우되, 원소 상성이든 LUK 진짜 크리티컬이든 특별
	# 타격이면 같은 강조 표시를 쓴다.
	var is_special_hit: bool = is_advantage or hitbox.is_critical
	spawn_damage_number(defender_body, damage, is_special_hit)

	Events.hit_landed.emit(hitbox.source, defender_body, damage, is_advantage, hitbox.is_critical)

	# 카메라 셰이크 4단계(addendum §3-2, D-63 예정): 피격자가 플레이어면 "hit" 티어
	# (몬스터 공격력·종 무관 일괄). 그 외(플레이어가 몬스터를 때린 경우)는 "crit"(원소
	# 상성 적중 또는 LUK 진짜 크리티컬) / "heavy"(강공격·피니셔)가 동시에 해당할 수 있어
	# D-162 (c): 두 tier 중 진폭(amplitude_px)이 더 큰 쪽을 쓴다. 히트스톱이 화면을
	# 프리즈하는 동안은 안 보이므로 해제 직후 시작한다.
	var shake_tier: String = "normal"
	if defender_body is Player:
		shake_tier = "hit"
	else:
		var candidates: Array[String] = []
		if is_special_hit:
			candidates.append("crit")
		if hitbox.is_heavy:
			candidates.append("heavy")
		shake_tier = _pick_larger_shake_tier(candidates)
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


## D-162 (c): 후보 tier가 없으면 "normal", 하나면 그대로, 둘이면 amplitude_px가 더 큰 쪽.
static func _pick_larger_shake_tier(candidates: Array[String]) -> String:
	if candidates.is_empty():
		return "normal"
	if candidates.size() == 1:
		return candidates[0]
	var best: String = candidates[0]
	var best_amplitude: float = float(Data.get_value("combat", "camera_shake.%s.amplitude_px" % best, 0.0))
	for tier: String in candidates.slice(1):
		var amplitude: float = float(Data.get_value("combat", "camera_shake.%s.amplitude_px" % tier, 0.0))
		if amplitude > best_amplitude:
			best = tier
			best_amplitude = amplitude
	return best


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
	# D-222: knockback.*_px 는 지면 거리다. 넉백은 velocity 가 아니라 global_position
	# Tween 이라 이동 경로의 등각 변환이 여기에만 따로 필요하다.
	var target: Vector2 = body.global_position \
		+ IsoMath.offset_for_ground_distance(direction, distance_px)
	var tween := body.create_tween()
	tween.tween_property(body, "global_position", target, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## public: 가드 칩데미지 등 HitFeel.apply() 전체 파이프라인을 타지 않는 경로(플레이어
## Guard 상태의 부분 피해 표시 등)에서도 같은 데미지 숫자 연출을 재사용하기 위해 공개.
##
## D-07(기본 켜짐, 옵션에서 끌 수 있음): Settings.damage_numbers_enabled가 false면
## 스폰 자체를 생략한다 — 호출부(HitFeel.apply(), player.gd)를 개별적으로 고칠 필요 없이
## 이 단일 지점에서 토글된다.
static func spawn_damage_number(at_body: Node2D, damage: int, is_advantage: bool) -> void:
	if not Settings.damage_numbers_enabled:
		return
	if at_body == null or not is_instance_valid(at_body):
		return
	var tree := at_body.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var number := DamageNumberScene.instantiate()
	tree.current_scene.add_child(number)
	number.global_position = at_body.global_position + Vector2(0, -Tuning.DAMAGE_NUMBER_OFFSET_PX)
	number.setup(damage, is_advantage)
