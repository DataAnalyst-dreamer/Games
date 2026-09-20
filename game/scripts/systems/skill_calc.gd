## 스킬 배우기/장착/시전 가능 조건 + 데미지 순수 계산(M3-3, skills.json 소비,
## docs/specs/skills-m3.md). Data/GameState에 의존하지 않아 GUT에서 테이블을 dict로
## 직접 주입해 테스트한다(progression_calc.gd와 동일 원칙).
class_name SkillCalc
extends RefCounted


## id가 skills.json에 존재하고, 아직 안 배웠고, cost_sp를 낼 스킬 포인트가 있고,
## requires를 전부 배웠으면 학습 가능(D-159: 레벨 게이트 없음).
static func can_learn(skill_id: String, learned: Array, skill_points: int, skills_table: Dictionary) -> bool:
	var entry: Variant = skills_table.get(skill_id, null)
	if not (entry is Dictionary) or learned.has(skill_id):
		return false
	var e: Dictionary = entry
	if skill_points < int(e.get("cost_sp", 1)):
		return false
	for req: Variant in (e.get("requires", []) as Array):
		if not learned.has(String(req)):
			return false
	return true


## 이미 배운 스킬이거나(장착) 빈 문자열(해제)만 슬롯에 넣을 수 있다(D-160: 슬롯 교체 자유).
static func can_equip(skill_id: String, learned: Array) -> bool:
	return skill_id == "" or learned.has(skill_id)


## 슬롯에 스킬이 있고, 쿨타임이 다 됐고, 스태미나가 충분하면 시전 가능.
static func can_cast(skill_id: String, skills_table: Dictionary, stamina: float, cooldown_remaining: float) -> bool:
	var entry: Variant = skills_table.get(skill_id, null)
	if not (entry is Dictionary) or cooldown_remaining > 0.0:
		return false
	return stamina >= float((entry as Dictionary).get("stamina_cost", 0.0))


## 스킬 데미지 = 유효 공격력 * damage_mult(콤보 배율과 별개, skills-m3.md §2).
## hitbox가 null(damage_mult=0, 순수 자기 버프)이면 0.
static func damage_for(skill_entry: Dictionary, effective_attack: float) -> int:
	return int(round(effective_attack * float(skill_entry.get("damage_mult", 0.0))))


## INT 쿨감 배율이 적용된 실제 쿨타임(초).
static func effective_cooldown(base_cooldown_sec: float, cooldown_mult_value: float) -> float:
	return base_cooldown_sec * cooldown_mult_value
