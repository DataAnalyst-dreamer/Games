## STR/DEX/INT/VIT/LUK 파생 전투 수치 순수 계산(M3-3, stats.json 계수 소비). Data/GameState에
## 의존하지 않아 GUT에서 계수를 숫자로 직접 주입해 테스트한다(progression_calc.gd와 동일 원칙).
## DEX 구르기 비용 경감식은 이미 resources.gd:roll_cost_with_dex()가 갖고 있어 여기서
## 재정의하지 않는다.
class_name StatCalc
extends RefCounted


## key가 6스탯(M4-4 v2: AGI 추가) 중 하나이고, 그 스탯의 다음 상승 비용(cost, 체증
## 곡선 §2)을 낼 포인트가 남아 있어야 분배 가능(D-158: 스탯당 상한 없음).
static func can_allocate(key: String, stat_points: int, valid_keys: Array, cost: int = 1) -> bool:
	return cost > 0 and stat_points >= cost and valid_keys.has(key)


## STR: 포인트당 물리 공격력 가산(stats.json str.physical_damage_per_point).
static func attack_bonus(str_points: int, per_point: float) -> float:
	return float(str_points) * per_point


## VIT: 포인트당 최대 HP 가산(stats.json vit.hp_per_point).
static func hp_bonus(vit_points: int, per_point: float) -> float:
	return float(vit_points) * per_point


## VIT+장비: 최종 방어력(stats.json vit.defense_per_point + Equipment.compute_stats().defense).
static func defense_value(vit_points: int, per_point: float, equip_defense: float) -> float:
	return float(vit_points) * per_point + equip_defense


## D-162 확정 공식(stats.json vit.defense_formula 그대로): damage_taken = incoming*100/(100+defense).
static func damage_after_defense(incoming: float, defense: float) -> int:
	if defense <= 0.0:
		return int(round(incoming))
	return int(round(incoming * 100.0 / (100.0 + defense)))


## LUK: 크리티컬 확률(0..1), cap 상한. D-162(b): crit_chance_per_point=0.001을 그대로 쓴다
## (stats.json worked_examples의 "0.1"은 %p 표기라 값 자체는 동일 — 0.001*20 = 2%p).
static func crit_chance(luk_points: int, base_chance: float, per_point: float, cap: float) -> float:
	return minf(cap, base_chance + float(luk_points) * per_point)


## LUK 크리티컬 발동 시 데미지 배율 적용(정수 반올림).
static func crit_damage(damage: int, multiplier: float) -> int:
	return int(round(float(damage) * multiplier))


## INT: 스킬 쿨타임 배율(1.0=감소 없음), cap_pct로 상한.
static func cooldown_mult(int_points: int, per_point: float, cap_pct: float) -> float:
	return 1.0 - minf(cap_pct, float(int_points) * per_point)


# --- M4-4 v2(D-167~D-174, ro-benchmark-progression-v1.md §1~§3) ---

## 스탯 n -> n+1 상승 비용(§2 체증 곡선 stats.json.allocation.point_cost_curve_formula).
static func allocation_cost(current_value: int) -> int:
	return maxi(current_value, 0) / 10 + 1


## AGI 주 · DEX 부: 콤보 프레임(입력 버퍼·타 지속시간)에 곱하는 배율. 값이 작을수록 빠르다.
## passive_aspd_pct(blade_reflex 등 aspd_pct 패시브 합계, %)는 D-193에 따라 곱연산으로
## 합성하고 최종 결과에 floor 상한을 적용한다.
static func combo_frame_mult(agi: int, dex: int, per_point: float, dex_secondary: float,
		floor_value: float, passive_aspd_pct: float = 0.0) -> float:
	var base: float = 1.0 - float(agi) * per_point - float(dex) * dex_secondary
	return maxf(floor_value, base / (1.0 + passive_aspd_pct * 0.01))


## AGI FLEE 번역 (a): 구르기 무적시간 가산분(초, cap 상한).
static func roll_iframe_bonus(agi: int, per_point: float, cap_sec: float) -> float:
	return minf(cap_sec, float(agi) * per_point)


## AGI FLEE 번역 (b): 이동속도 배율(1.0=변화 없음). passive_move_pct(%)는 곱연산 합성.
static func move_speed_mult(agi: int, per_point: float, cap_pct: float,
		passive_move_pct: float = 0.0) -> float:
	return (1.0 + minf(cap_pct, float(agi) * per_point)) * (1.0 + passive_move_pct * 0.01)


## DEX HIT 번역: 내 공격/스킬 히트박스 크기 배율(확률 명중 판정 아님).
static func hitbox_scale_mult(dex: int, per_point: float, cap_pct: float) -> float:
	return 1.0 + minf(cap_pct, float(dex) * per_point)


## DEX: 공격 후딜(모션 잠금) 길이 배율. 값이 작을수록 빠르게 다음 행동.
static func post_recovery_mult(dex: int, per_point: float, floor_value: float) -> float:
	return maxf(floor_value, 1.0 - float(dex) * per_point)


## INT: MATK 가산분(기본치는 호출부가 더한다).
static func magic_attack_bonus(int_points: int, per_point: float) -> float:
	return float(int_points) * per_point


## INT+VIT 절반씩: 마법 방어력.
static func mdef_value(int_points: int, vit_points: int, int_per_point: float, vit_per_point: float) -> float:
	return float(int_points) * int_per_point + float(vit_points) * vit_per_point


## INT: 최대 SP(§3, stats.json sp.base_sp + INT*int.max_sp_per_point).
static func max_sp(int_points: int, base_sp: float, per_point: float) -> float:
	return base_sp + float(int_points) * per_point


## INT: 초당 SP 회복량(§3). is_idle=마지막 스킬 사용 후 regen_idle_delay_sec 경과.
## passive_sp_regen_pct(trick_insight 등, %)는 D-193 곱연산 합성.
static func sp_regen(int_points: int, base_per_sec: float, per_point: float,
		idle_multiplier: float, is_idle: bool, passive_sp_regen_pct: float = 0.0) -> float:
	var regen: float = (base_per_sec + float(int_points) * per_point) * (1.0 + passive_sp_regen_pct * 0.01)
	return regen * (idle_multiplier if is_idle else 1.0)
