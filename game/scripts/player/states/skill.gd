## 액티브 스킬 시전 상태(M3-3, docs/specs/skills-m3.md). Attack 상태의 히트박스 발사
## 패턴을 재사용하되, 판정 모양(arc/line/circle)·배율·넉백·자기 버프는 전부 skills.json
## 값으로 채운다. 쿨타임 등록/조회는 Progression이 전담(state.gd:try_enter_skill()이 진입
## 전 can_cast_skill()로 이미 검증했으므로 여기서는 방어적으로만 다시 확인한다).
##
## M4-3(시전 연출 개선): 선딜(Tuning.SKILL_ANTICIPATION_SEC) → 발동(히트박스+SkillVfx
## 동시 스폰) → 후딜(SkillVfx 자체 소멸) 3단 구조. vfx/feel은 skills.json v2 예정 필드.
extends PlayerState

var _elapsed: float = 0.0
var _duration: float = 0.0

## player.hitbox의 원래 CollisionShape2D(원형, 근접 콤보용)를 스킬 판정 동안만 바꿔치기
## 하고 exit() 시 되돌린다(Player.tscn에 스킬 전용 Hitbox를 새로 만들지 않기 위한 재사용).
var _shape_node: CollisionShape2D = null
var _orig_shape: Shape2D = null
var _orig_shape_position: Vector2 = Vector2.ZERO
## 씬의 기본 공격 히트박스는 **지면 원**이라 노드에 (1, 0.5) 배율이 걸려 있다(R3).
## 스킬은 자기 모양을 직접 만들므로 그 배율을 벗겨 두고(안 벗기면 모든 스킬 판정이
## 조용히 세로로 반이 된다) 복원 시 되돌린다.
var _orig_shape_scale: Vector2 = Vector2.ONE

## M4-3: 선딜(anticipation) 지연 콜백이 도착했을 때 이미 이 상태를 벗어났으면(피격·구르기
## 캔슬 등 exit()가 먼저 불림) 히트박스를 켜지 않게 막는 가드. D-127(무기 tween 유실
## 사례)과 같은 부류 — "상태를 나간 뒤 뒤늦게 도착하는 콜백"은 항상 상태 소유 여부를
## 먼저 확인해야 한다.
var _exited: bool = false


func enter(_prev: StringName, data: Dictionary = {}) -> void:
	var slot: int = int(data.get("slot", 0))
	var skill_id: String = ""
	if slot >= 0 and slot < GameState.skill_slots.size():
		skill_id = GameState.skill_slots[slot]
	# 방어적 재검증(try_enter_skill이 이미 확인했지만, 입력~전이 사이 프레임에 스태미나가
	# 소모됐을 수도 있는 동시성 대비 — Roll 상태의 동일 관례).
	if skill_id == "" or not Progression.can_cast_skill(slot):
		finished.emit(&"Idle", {})
		return
	# M4-4(D-169/D-170): 노드 정의는 최상위(hitbox/knockback/vfx/feel), 수치는 현재 습득
	# 레벨의 levels[] 항목(sp_cost/cooldown_sec/damage_mult/self_effect)에서 읽는다.
	var entry: Dictionary = Data.get_value("skills", skill_id, {})
	var level: Dictionary = Progression.skill_level_data(skill_id)
	if not Progression.spend_sp(SkillCalc.sp_cost(level)):
		Events.player_stamina_insufficient.emit(&"skill") # HUD 공용 "자원 부족" 깜박임 재사용.
		finished.emit(&"Idle", {})
		return
	Progression.start_skill_cooldown(slot, skill_id)

	_elapsed = 0.0
	_duration = Tuning.SKILL_HIT_DURATION_SEC
	_exited = false
	player.velocity = Vector2.ZERO
	player.play_anim("attack") # 전용 스킬 애니메이션 없음(pixel-artist TODO, icon도 skills.json 전부 null).
	AudioManager.play_sfx(&"atk_swing_finisher", player.global_position)

	_apply_self_effect(level.get("self_effect", null))

	# M4-3(D-167~D-180 "시전 연출 개선"): 선딜 동안은 자세만 고정하고(velocity=0, 위),
	# 색 예고 플래시만 즉시 준다 — 실제 판정+발동 이펙트는 anticipation_sec 뒤로 미뤄
	# "선딜을 길게, 타격은 짧게" 3단 구조(motion-design-reference.md)를 흉내낸다.
	# vfx/feel은 skills.json v2 예정 필드(game-designer 작업 중) — 없으면 더미로 안전하게
	# 폴백(kind="none", 기존 히트스톱/셰이크/흰 플래시 그대로, 회귀 없음).
	var vfx_variant: Variant = entry.get("vfx", null)
	var vfx: Dictionary = vfx_variant if vfx_variant is Dictionary else {}
	var hex: String = String(vfx.get("color", ""))
	var base_color: Color = SkillVfx.base_color_from_hex(hex)
	var flash_color: Color = SkillVfx.flash_color_from_hex(hex)
	HitFlash.flash(player.sprite, flash_color)

	var anticipation_sec: float = Tuning.SKILL_ANTICIPATION_SEC
	var tree := player.get_tree()
	if tree == null or anticipation_sec <= 0.0:
		_fire(entry, level, vfx, base_color, flash_color)
	else:
		tree.create_timer(anticipation_sec).timeout.connect(func() -> void:
			if _exited or not is_instance_valid(player):
				return
			_fire(entry, level, vfx, base_color, flash_color)
		)


func exit() -> void:
	_exited = true
	if player.hitbox != null:
		player.hitbox.deactivate()
	_restore_hitbox_shape()


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.move_and_slide()
	if _elapsed >= _duration:
		if player.get_move_input() != Vector2.ZERO:
			finished.emit(&"Move", {})
		else:
			finished.emit(&"Idle", {})


## self_effect 스키마(v2, §4-2): dash_px(+invuln_sec) / invuln_sec / move_speed_mult /
## atk_buff_pct / dmg_reduction_pct — 뒤의 3종은 지속시간이 있는 버프라 Progression이
## 보관하고(스탯 계산에 합산), 즉발 2종만 여기서 직접 처리한다.
func _apply_self_effect(effect_variant: Variant) -> void:
	if not (effect_variant is Dictionary):
		return
	var effect: Dictionary = effect_variant
	var duration: float = float(effect.get("duration_sec", 0.0))
	if effect.has("dash_px"):
		player.start_iframes(float(effect.get("invuln_sec", 0.0)))
		_dash(float(effect.get("dash_px", 0.0)))
	elif effect.has("move_speed_mult"):
		# 배율(1.20) -> 버프 %(20)로 환산해 Progression의 버프 창구 하나로 모은다.
		Progression.apply_buff("move_speed_pct", (float(effect["move_speed_mult"]) - 1.0) * 100.0, duration)
	elif effect.has("atk_buff_pct"):
		Progression.apply_buff("atk_buff_pct", float(effect["atk_buff_pct"]), duration)
	elif effect.has("dmg_reduction_pct"):
		Progression.apply_buff("dmg_reduction_pct", float(effect["dmg_reduction_pct"]), duration)
	elif effect.has("invuln_sec"):
		player.start_iframes(float(effect.get("invuln_sec", 0.0)))


func _dash(distance_px: float) -> void:
	if distance_px <= 0.0:
		return
	# D-222: dash_px 는 지면 거리. 넉백과 같은 이유로 Tween 경로를 직접 변환한다.
	var target: Vector2 = player.global_position \
		+ IsoMath.offset_for_ground_distance(player.facing, distance_px)
	var tween := player.create_tween()
	tween.tween_property(player, "global_position", target, _duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 선딜 종료 시점(즉시 또는 anticipation_sec 뒤)에 히트박스 판정과 발동 이펙트를 같은
## 콜백에서 함께 시작한다 — "히트박스 활성 프레임과 이펙트 타격 프레임을 동일 타이머로
## 동기화"(M4-3 요구사항 2)를 이 한 함수로 만족시킨다.
func _fire(entry: Dictionary, level: Dictionary, vfx: Dictionary, base_color: Color, flash_color: Color) -> void:
	_fire_hitbox(entry, level, flash_color)
	var hb_variant: Variant = entry.get("hitbox", null)
	var range_px: float = float((hb_variant as Dictionary).get("range_px", 40.0)) if hb_variant is Dictionary else 40.0
	var scale: float = float(vfx.get("scale", 1.0))
	SkillVfx.spawn(String(vfx.get("kind", "none")), player, base_color, range_px * scale)


## hitbox가 null이면(damage_mult=0, 순수 자기 버프 스킬) 히트박스를 활성화하지 않는다
## (skills-m3.md §2). 크리티컬은 attack.gd와 동일하게 Progression.roll_crit()을 공유한다.
func _fire_hitbox(entry: Dictionary, level: Dictionary, flash_color: Color) -> void:
	var hitbox := player.hitbox
	if hitbox == null:
		return
	var hb_variant: Variant = entry.get("hitbox", null)
	if not (hb_variant is Dictionary):
		return
	var hb: Dictionary = hb_variant

	var base_damage: int = SkillCalc.damage_for(level, player.get_attack_power())
	var crit_result: Dictionary = Progression.roll_crit(base_damage)
	hitbox.damage = int(crit_result.get("damage", base_damage))
	hitbox.is_critical = bool(crit_result.get("is_critical", false))
	hitbox.knockback_px = float(entry.get("knockback_px", 0.0))

	# M4-3(D-178): feel.shake_tier 기본 "normal", 데이터가 "heavy"를 명시한 스킬(각 계열
	# 4번째 액티브=피니셔 성격)만 hit_feel.gd의 기존 crit/heavy 후보 비교 로직
	# (_pick_larger_shake_tier)에서 "heavy" 후보가 되게 hitbox.is_heavy로 넘긴다 — 새 분기
	# 없이 기존 카메라 셰이크 배선을 그대로 재사용.
	var feel_variant: Variant = entry.get("feel", null)
	var feel: Dictionary = feel_variant if feel_variant is Dictionary else {}
	hitbox.is_heavy = String(feel.get("shake_tier", "normal")) == "heavy"
	# skills-m3.md §2 기본값(combat.json.hitstop.normal_sec) 유지, feel.hitstop_sec가 있으면 덮어쓴다.
	hitbox.hitstop_sec = float(feel.get("hitstop_sec", Data.get_value("combat", "hitstop.normal_sec", 0.05)))
	hitbox.flash_color = flash_color
	hitbox.element = &""
	hitbox.source = player
	hitbox.position = Vector2.ZERO

	# M4-4(D-168, §1 HIT 번역): DEX만큼 스킬 판정도 넓어진다(기본 공격은 attack.gd에서
	# Hitbox.apply_scale_mult로 같은 배율을 적용 — 여기선 모양을 직접 만들므로 치수에 곱한다).
	var hit_scale: float = float(Progression.get_derived().get("hitbox_scale", 1.0))
	var width_variant: Variant = hb.get("width_px")
	_apply_hitbox_shape(
		String(hb.get("shape", "circle")), float(hb.get("range_px", 40.0)) * hit_scale,
		(float(width_variant) * hit_scale) if width_variant != null else null)
	hitbox.activate(_duration)


func _ensure_shape_cached() -> void:
	if _shape_node != null or player == null or player.hitbox == null:
		return
	_shape_node = player.hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape_node != null:
		_orig_shape = _shape_node.shape
		_orig_shape_position = _shape_node.position
		_orig_shape_scale = _shape_node.scale


## arc/line/circle 근사. D-228(8방향)부터 line 은 **회전**으로 방향을 잡는다 - 예전의
## "facing 이 LEFT/RIGHT 면 가로, 아니면 세로" 분기는 대각 facing 이 두 조건 어디에도
## 맞지 않아 else(세로)로 떨어지는 버그였다. 회전은 8방향뿐 아니라 임의 방향에도 맞고
## 분기 자체가 사라진다.
## ponytail: arc 는 여전히 facing 쪽으로 치우친 원 근사다(실제 부채꼴 판정은
## CollisionPolygon2D 가 필요해지는 시점에). circle 은 자기 중심 AoE.
func _apply_hitbox_shape(shape_name: String, range_px: float, width_px_variant: Variant) -> void:
	_ensure_shape_cached()
	if _shape_node == null:
		return
	var width_px: float = float(width_px_variant) if width_px_variant != null else range_px
	_shape_node.scale = Vector2.ONE
	match shape_name:
		"line":
			var rect := RectangleShape2D.new()
			rect.size = Vector2(range_px, width_px)
			_shape_node.shape = rect
			_shape_node.rotation = player.facing.angle()
			_shape_node.position = _orig_shape_position + player.facing * (range_px * 0.5)
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = range_px
			_shape_node.shape = circle
			_shape_node.rotation = 0.0
			_shape_node.position = _orig_shape_position
		_: # "arc" 근사
			var arc_circle := CircleShape2D.new()
			arc_circle.radius = range_px * 0.5
			_shape_node.shape = arc_circle
			_shape_node.rotation = 0.0
			_shape_node.position = _orig_shape_position + player.facing * (range_px * 0.5)


func _restore_hitbox_shape() -> void:
	if _shape_node != null and _orig_shape != null:
		_shape_node.shape = _orig_shape
		_shape_node.position = _orig_shape_position
		_shape_node.rotation = 0.0
		_shape_node.scale = _orig_shape_scale
