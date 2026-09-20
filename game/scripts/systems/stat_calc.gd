## STR/DEX/INT/VIT/LUK 파생 전투 수치 순수 계산(M3-3, stats.json 계수 소비). Data/GameState에
## 의존하지 않아 GUT에서 계수를 숫자로 직접 주입해 테스트한다(progression_calc.gd와 동일 원칙).
## DEX 구르기 비용 경감식은 이미 resources.gd:roll_cost_with_dex()가 갖고 있어 여기서
## 재정의하지 않는다.
class_name StatCalc
extends RefCounted


## key가 5스탯 중 하나이고 분배할 포인트가 남아 있어야 분배 가능(D-158: 스탯당 상한 없음).
static func can_allocate(key: String, stat_points: int, valid_keys: Array) -> bool:
	return stat_points > 0 and valid_keys.has(key)


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
