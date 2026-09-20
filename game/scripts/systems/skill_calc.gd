## 스킬 트리 v2(M4-4, D-170/D-186/D-188, docs/specs/ro-benchmark-progression-v1.md §4)
## 순수 계산: 노드 레벨업 가능 조건 · 레벨별 수치 조회 · 시전 조건 · 패시브 합산.
## Data/GameState에 의존하지 않아 GUT에서 테이블을 dict로 직접 주입해 테스트한다
## (progression_calc.gd와 동일 원칙).
##
## v1에서 바뀐 점: learned가 Array -> Dictionary(id -> level), requires가 문자열 배열 ->
## [{"skill": id, "level": n}], 소모 자원이 stamina_cost -> levels[i].sp_cost, 그리고
## cooldown_sec/damage_mult/self_effect가 노드 최상위 -> levels[i] 안으로 내려갔다.
class_name SkillCalc
extends RefCounted


## 노드 정의의 level(1-based) 항목. 범위 밖이면 빈 Dictionary(호출부가 get()으로 안전 폴백).
static func level_data(skill_entry: Dictionary, level: int) -> Dictionary:
	var levels: Array = skill_entry.get("levels", [])
	if level < 1 or level > levels.size():
		return {}
	var row: Variant = levels[level - 1]
	return row if row is Dictionary else {}


## 노드 1레벨 올리기 가능 여부. 반환 {"ok": bool, "reason": StringName} —
## &"" (가능) / &"unknown"(테이블에 없는 id) / &"maxed"(max_level 도달) /
## &"no_points"(스킬 포인트 부족) / &"requires"(선행 스킬 레벨 미충족).
## reason의 로컬라이징 키 매핑은 UI 몫(D-194, ui.skill.reason_*).
static func can_learn(skill_id: String, learned: Dictionary, skill_points: int,
		skills_table: Dictionary) -> Dictionary:
	var entry: Variant = skills_table.get(skill_id, null)
	if not (entry is Dictionary):
		return {"ok": false, "reason": &"unknown"}
	var e: Dictionary = entry
	var current: int = int(learned.get(skill_id, 0))
	if current >= int(e.get("max_level", 5)):
		return {"ok": false, "reason": &"maxed"}
	if skill_points < int(e.get("cost_skill_point_per_level", 1)):
		return {"ok": false, "reason": &"no_points"}
	for req_v: Variant in (e.get("requires", []) as Array):
		if not (req_v is Dictionary):
			continue
		var req: Dictionary = req_v
		if int(learned.get(String(req.get("skill", "")), 0)) < int(req.get("level", 1)):
			return {"ok": false, "reason": &"requires"}
	return {"ok": true, "reason": &""}


## 이미 배운 스킬이거나(장착) 빈 문자열(해제)만 슬롯에 넣을 수 있다(D-160: 슬롯 교체 자유).
## 패시브 노드는 상시 적용이라 슬롯 장착 대상이 아니다(§5, node_type in {active, buff}만).
static func can_equip(skill_id: String, learned: Dictionary, skills_table: Dictionary = {}) -> bool:
	if skill_id == "":
		return true
	if int(learned.get(skill_id, 0)) <= 0:
		return false
	var entry: Variant = skills_table.get(skill_id, null)
	if not (entry is Dictionary):
		return true # 테이블 미주입 호출부(테스트 등)는 습득 여부만 본다.
	return String((entry as Dictionary).get("node_type", "active")) != "passive"


## 슬롯 스킬이 존재하고, 습득 레벨이 1 이상이고, 쿨타임이 끝났고, SP가 충분하면 시전 가능
## (D-169: 스킬은 스태미나가 아니라 SP를 쓴다).
static func can_cast(skill_id: String, level: int, skills_table: Dictionary, sp: float,
		cooldown_remaining: float) -> bool:
	var entry: Variant = skills_table.get(skill_id, null)
	if not (entry is Dictionary) or level < 1 or cooldown_remaining > 0.0:
		return false
	return sp >= sp_cost(level_data(entry, level))


## 현재 레벨 항목의 SP 소모량(패시브 등 sp_cost가 없는 노드는 0).
static func sp_cost(level_entry: Dictionary) -> float:
	return float(level_entry.get("sp_cost", 0.0))


## 스킬 데미지 = 유효 공격력 * 해당 레벨의 damage_mult. hitbox가 없는 버프 노드는 0.
static func damage_for(level_entry: Dictionary, effective_attack: float) -> int:
	return int(round(effective_attack * float(level_entry.get("damage_mult", 0.0))))


## INT 쿨감 배율이 적용된 실제 쿨타임(초).
static func effective_cooldown(base_cooldown_sec: float, cooldown_mult_value: float) -> float:
	return base_cooldown_sec * cooldown_mult_value


## 습득한 패시브 노드(node_type=="passive")의 현재 레벨 value를 passive_stat별로 합산한다
## (§4-3 패시브 9종: atk_pct/crit_damage_pct/aspd_pct/defense_flat/
## guard_damage_reduction_pct/max_hp_pct/sp_regen_pct/crit_chance_pct/move_speed_pct).
static func passive_totals(learned: Dictionary, skills_table: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for skill_id_v: Variant in learned:
		var skill_id: String = String(skill_id_v)
		var entry: Variant = skills_table.get(skill_id, null)
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry
		if String(e.get("node_type", "")) != "passive":
			continue
		var stat: String = String(e.get("passive_stat", ""))
		if stat == "":
			continue
		var value: float = float(level_data(e, int(learned[skill_id_v])).get("value", 0.0))
		totals[stat] = float(totals.get(stat, 0.0)) + value
	return totals
