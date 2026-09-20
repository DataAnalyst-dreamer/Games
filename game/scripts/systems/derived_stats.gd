## 6스탯 파생 전투 수치 계산(M4-4, docs/specs/ro-benchmark-progression-v1.md §1·§3).
## StatCalc(계수까지 인자로 받는 완전 순수 함수)와 Progression(상태·신호·타이머) 사이의
## 얇은 층으로, stats.json 계수 조회만 담당한다 — progression_service.gd의 500줄 상한
## (D-157)을 지키기 위해 분리했다. GameState/Events에는 의존하지 않는다(스탯 dict와
## 패시브/버프 합계는 호출부가 넘긴다).
class_name DerivedStats
extends RefCounted


static func _v(path: String, fallback: Variant) -> float:
	return float(Data.get_value("stats", path, fallback))


## 전 파생치를 한 번에. stats: 6스탯 dict, passives: SkillCalc.passive_totals() 결과,
## buff_move_pct: 이동속도 버프(%), player: 있으면 실제 공격력/HP/장비 방어력을 읽는다.
static func compute(stats: Dictionary, passives: Dictionary, buff_move_pct: float,
		player: Player) -> Dictionary:
	var agi: int = int(stats.get("agi", 0))
	var dex: int = int(stats.get("dex", 0))
	var int_points: int = int(stats.get("int", 0))
	var vit: int = int(stats.get("vit", 0))
	var attack: float = player.get_attack_power() if player != null else Tuning.PLAYER_BASE_ATTACK
	var max_hp: int = player.resources.max_hp if player != null and player.resources != null else Tuning.PLAYER_MAX_HP
	var equip_defense: float = player.equip_defense if player != null else 0.0
	return {
		"attack": attack,
		"max_hp": max_hp,
		"defense": StatCalc.defense_value(vit, _v("vit.defense_per_point", 1.0), equip_defense) \
			+ float(passives.get("defense_flat", 0.0)),
		"crit_chance": crit_chance(int(stats.get("luk", 0)), float(passives.get("crit_chance_pct", 0.0))),
		"roll_cost_mult": PlayerResources.roll_cost_with_dex(1.0, float(dex)),
		"cooldown_mult": StatCalc.cooldown_mult(int_points,
			_v("int.cooldown_reduction_per_point", 0.002), _v("int.cooldown_reduction_cap_pct", 0.30)),
		"matk": Tuning.PLAYER_BASE_ATTACK + StatCalc.magic_attack_bonus(
			int_points, _v("int.magic_damage_per_point", 0.15)),
		"mdef": StatCalc.mdef_value(int_points, vit,
			_v("int.mdef_per_point", 0.5), _v("vit.mdef_per_point", 0.5)),
		"combo_frame_mult": combo_frame_mult(agi, dex, float(passives.get("aspd_pct", 0.0))),
		"post_recovery_mult": StatCalc.post_recovery_mult(dex,
			_v("dex.post_recovery_mult_per_point", 0.0015), _v("dex.post_recovery_mult_floor", 0.70)),
		"hitbox_scale": hitbox_scale(dex),
		"roll_iframe_bonus": roll_iframe_bonus(agi),
		"move_speed_mult": move_speed_mult(agi, float(passives.get("move_speed_pct", 0.0)), buff_move_pct),
		"max_sp": max_sp(int_points),
		"sp_regen": sp_regen(int_points, float(passives.get("sp_regen_pct", 0.0)), false),
	}


## AGI(주)+DEX(부) 콤보 프레임 배율 — 값이 작을수록 공격이 빠르다(ASPD 번역).
static func combo_frame_mult(agi: int, dex: int, passive_aspd_pct: float) -> float:
	return StatCalc.combo_frame_mult(agi, dex,
		_v("agi.aspd_frame_mult_per_point", 0.0028), _v("agi.aspd_dex_secondary_per_point", 0.0008),
		_v("agi.aspd_frame_mult_floor", 0.65), passive_aspd_pct)


## DEX HIT 번역: 내 공격/스킬 히트박스 크기 배율.
static func hitbox_scale(dex: int) -> float:
	return StatCalc.hitbox_scale_mult(dex,
		_v("dex.hit_hitbox_scale_per_point", 0.0015), _v("dex.hit_hitbox_scale_cap", 0.30))


## AGI FLEE 번역 (a): 구르기 무적시간 가산분(초).
static func roll_iframe_bonus(agi: int) -> float:
	return StatCalc.roll_iframe_bonus(agi,
		_v("agi.roll_iframe_bonus_per_point", 0.001), _v("agi.roll_iframe_bonus_cap_sec", 0.15))


## AGI FLEE 번역 (b): 이동속도 배율(AGI × move_speed_pct 패시브 × 버프, D-193 곱연산).
static func move_speed_mult(agi: int, passive_move_pct: float, buff_move_pct: float) -> float:
	return StatCalc.move_speed_mult(agi, _v("agi.move_speed_pct_per_point", 0.0015),
		_v("agi.move_speed_pct_cap", 0.20), passive_move_pct) * (1.0 + buff_move_pct * 0.01)


## INT 기반 최대 SP(§3).
static func max_sp(int_points: int) -> float:
	return StatCalc.max_sp(int_points, _v("sp.base_sp", 20.0), _v("int.max_sp_per_point", 2.0))


## 초당 SP 회복량. is_idle(마지막 시전 후 regen_idle_delay_sec 경과)이면 가속 배율 적용.
static func sp_regen(int_points: int, passive_sp_regen_pct: float, is_idle: bool) -> float:
	return StatCalc.sp_regen(int_points, _v("sp.regen_per_sec_base", 1.0),
		_v("int.sp_regen_per_point", 0.03), _v("sp.regen_idle_multiplier", 2.5),
		is_idle, passive_sp_regen_pct)


## LUK 크리티컬 확률. trick_precision(crit_chance_pct 패시브)은 기본 확률에 %p로 더하고,
## stats.json의 기존 cap을 최종값에 적용한다(D-193).
static func crit_chance(luk: int, passive_crit_pct: float) -> float:
	return StatCalc.crit_chance(luk,
		_v("luk.base_crit_chance", 0.05) + passive_crit_pct * 0.01,
		_v("luk.crit_chance_per_point", 0.001), _v("luk.crit_chance_cap", 0.75))


## 크리티컬 데미지 배율(blade_edge crit_damage_pct 패시브를 곱연산 합성).
static func crit_damage_mult(passive_crit_damage_pct: float) -> float:
	return _v("luk.crit_damage_multiplier", 1.5) * (1.0 + passive_crit_damage_pct * 0.01)
