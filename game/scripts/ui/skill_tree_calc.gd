## 스킬 트리(M4-5, D-161/ro-benchmark-progression-v1.md §4) 순수 계산. `skill_tree_tab.gd`/
## `hud_skill_slots.gd`가 사용한다. Data/GameState/Progression을 직접 참조하지 않고
## 전부 인자로 받는다(stats_ui_calc.gd와 동일 원칙, GUT에서 skills.json 구조를 dict로
## 직접 주입해 테스트).
##
## `Progression.can_learn_skill(id)`/`get_skill_level(id)`(stage/m4-4, 병합 전엔 없음)와
## 별개로, 이 파일은 skills.json v2(requires:[{skill,level}], levels[])만으로 tier 배치·
## 잠금 판정·요구 텍스트를 계산한다 — 병합 전 폴백이자 GUT 검증 대상.
class_name SkillTreeCalc
extends RefCounted

const SERIES: Array[String] = ["blade", "guard", "trick"]
const DEFAULT_MAX_LEVEL := 5


## learned는 stage/m4-4 병합 전엔 Array[String](습득 여부만), 병합 후엔 Dictionary
## id->level이다 — 어느 쪽이 와도 id->level Dictionary로 통일한다(Array는 전부 레벨 1로
## 간주, "일단 배웠다"는 사실만 있던 구 스키마와 호환).
static func normalize_learned(learned: Variant) -> Dictionary:
	if typeof(learned) == TYPE_DICTIONARY:
		return learned as Dictionary
	var result: Dictionary = {}
	if typeof(learned) == TYPE_ARRAY:
		for id: Variant in (learned as Array):
			result[String(id)] = 1
	return result


## "_comment" 등 메타 키(다른 테이블과 동일 관례)를 제외한 실제 스킬 id 목록.
static func skill_ids(skills_table: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: Variant in skills_table.keys():
		if not String(id).begins_with("_"):
			result.append(String(id))
	return result


static func nodes_for_series(series: String, skills_table: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in skill_ids(skills_table):
		if String(skills_table[id].get("series", "")) == series:
			result.append(id)
	return result


## T1(선행 없음)=1, 이후 선행 노드 tier의 최댓값+1(§4-1: T2는 T1 1개, T3 궁극기는 T2
## 2개가 선행). 순환 참조는 데이터상 없다고 전제하되(스펙 §4-3 DAG), 방어적으로
## `_visiting`으로 무한 재귀만 막는다(순환 발견 시 1을 반환 — 크래시보다 안전).
static func node_tier(id: String, skills_table: Dictionary, _visiting: Array[String] = []) -> int:
	if _visiting.has(id):
		return 1
	var entry: Dictionary = skills_table.get(id, {})
	var requires: Array = entry.get("requires", [])
	if requires.is_empty():
		return 1
	var visiting: Array[String] = _visiting.duplicate()
	visiting.append(id)
	var max_parent_tier := 0
	for req: Variant in requires:
		var parent_id: String = String((req as Dictionary).get("skill", ""))
		max_parent_tier = maxi(max_parent_tier, node_tier(parent_id, skills_table, visiting))
	return max_parent_tier + 1


## {1: [id,...], 2: [...], 3: [...]} — 각 열 내부 순서는 skills_table 등록 순서 그대로.
static func nodes_by_tier(series: String, skills_table: Dictionary) -> Dictionary:
	var result: Dictionary = {1: [], 2: [], 3: []}
	for id in nodes_for_series(series, skills_table):
		var tier: int = node_tier(id, skills_table)
		if not result.has(tier):
			result[tier] = []
		(result[tier] as Array).append(id)
	return result


## 게임패드 상/하 순회 순서: T1 열 위→아래, T2 열, T3 열 순으로 이어붙인 1차원 목록
## (2D 그리드 내비게이션 대신 — 계열당 8노드 규모엔 과함).
static func focus_order(series: String, skills_table: Dictionary) -> Array[String]:
	var by_tier: Dictionary = nodes_by_tier(series, skills_table)
	var result: Array[String] = []
	for tier in [1, 2, 3]:
		for id: Variant in (by_tier.get(tier, []) as Array):
			result.append(String(id))
	return result


## [{skill, level}, ...] 그대로(구조체만 얇게 감쌈, 존재하지 않는 id면 빈 배열).
static func requires_of(id: String, skills_table: Dictionary) -> Array:
	return skills_table.get(id, {}).get("requires", [])


## 노드 하나 레벨업 비용(SP 아님, 스킬 포인트). skills.json v2는 레벨 무관 고정 1.
static func cost_for_next_level(entry: Dictionary) -> int:
	return int(entry.get("cost_skill_point_per_level", 1))


## `Progression.can_learn_skill(id)`와 동일한 계약: {"state", "reason", "level", "max_level"}.
## state: "locked"|"learnable"|"maxed". reason(state=="locked"/"maxed"일 때만 의미 있음):
## &"no_points"/&"requires"/&"maxed"/&"unknown"(D-194 로컬라이징 키와 1:1).
static func node_state(id: String, skills_table: Dictionary, learned: Dictionary, skill_points: int) -> Dictionary:
	var entry: Variant = skills_table.get(id, null)
	if not (entry is Dictionary):
		return {"state": "locked", "reason": &"unknown", "level": 0, "max_level": DEFAULT_MAX_LEVEL}
	var e: Dictionary = entry
	var level: int = int(learned.get(id, 0))
	var max_level: int = int(e.get("max_level", DEFAULT_MAX_LEVEL))
	if level >= max_level:
		return {"state": "maxed", "reason": &"maxed", "level": level, "max_level": max_level}
	var requires_ok := true
	for req: Variant in (e.get("requires", []) as Array):
		var r: Dictionary = req
		if int(learned.get(String(r.get("skill", "")), 0)) < int(r.get("level", 1)):
			requires_ok = false
			break
	if not requires_ok:
		return {"state": "locked", "reason": &"requires", "level": level, "max_level": max_level}
	if skill_points < cost_for_next_level(e):
		return {"state": "locked", "reason": &"no_points", "level": level, "max_level": max_level}
	return {"state": "learnable", "reason": &"", "level": level, "max_level": max_level}


## levels[] 배열에서 1-based level에 해당하는 항목(범위를 벗어나면 가장 가까운 끝으로
## clamp — level 0(미습득)이면 levels[0](Lv1 미리보기)을 보여준다).
static func level_entry(entry: Dictionary, level: int) -> Dictionary:
	var levels: Array = entry.get("levels", [])
	if levels.is_empty():
		return {}
	var idx: int = clampi(level - 1, 0, levels.size() - 1)
	return levels[idx]


## 슬롯 SP 부족 회색 표시(hud_skill_slots.gd)용 — 미습득(level 0)이면 0.
static func sp_cost_at(skills_table: Dictionary, id: String, level: int) -> float:
	if level <= 0:
		return 0.0
	return float(level_entry(skills_table.get(id, {}), level).get("sp_cost", 0.0))


# --- 레벨별 수치 표시(M4-5 후속, 코디네이터 지시 1건: "필드명 그대로 노출 금지") ---
# skills.json v2에 실제로 등장하는 필드만 안다(§ python3 조사: levels[] 최상위
# {sp_cost,cooldown_sec,damage_mult,value}, self_effect{invuln_sec,atk_buff_pct,
# duration_sec,dmg_reduction_pct,move_speed_mult,dash_px}, passive_stat 9종). 이 목록
# 밖의 필드는 "모르는 필드"로 취급해 조용히 건너뛴다(표시하지 않음) — 화면에 원문
# 필드명이 노출되는 사고를 구조적으로 막는다(허용 목록 방식, 동적 순회 아님).
const ACTIVE_FIELD_ORDER: Array[String] = ["sp_cost", "cooldown_sec", "damage_mult"]
const SELF_EFFECT_FIELD_ORDER: Array[String] = [
	"atk_buff_pct", "dmg_reduction_pct", "move_speed_mult", "invuln_sec", "dash_px", "duration_sec",
]
const KNOWN_PASSIVE_STATS: Array[String] = [
	"atk_pct", "crit_damage_pct", "aspd_pct", "defense_flat", "guard_damage_reduction_pct",
	"max_hp_pct", "sp_regen_pct", "crit_chance_pct", "move_speed_pct",
]
const _SECONDS_FIELDS: Array[String] = ["cooldown_sec", "duration_sec", "invuln_sec"]
const _FLAT_FIELDS: Array[String] = ["sp_cost", "defense_flat", "dash_px"]


## 필드 하나의 표시용 숫자 문자열(단위 없이 — 단위·라벨은 tr() 템플릿이 UI 쪽에서
## 붙인다, 이 파일은 순수 계산이라 로컬라이징 문자열을 만들지 않는다). 정수로 떨어지면
## 소수점을 생략(damage_mult 1.8 -> "180", 0.5% 스탯은 "0.5" 그대로 유지).
static func _format_field_value(field: String, value: float) -> String:
	if field in _SECONDS_FIELDS:
		return "%.1f" % value
	if field in _FLAT_FIELDS:
		return str(int(round(value)))
	var pct: float = value * 100.0 if field == "damage_mult" \
		else (value - 1.0) * 100.0 if field == "move_speed_mult" \
		else value
	if is_equal_approx(pct, round(pct)):
		return str(int(round(pct)))
	return "%.1f" % pct


static func _row(field: String, value: float, next_value: Variant) -> Dictionary:
	var next_text: String = ""
	if next_value != null and not is_equal_approx(float(next_value), value):
		next_text = _format_field_value(field, float(next_value))
	return {"field": field, "text": _format_field_value(field, value), "next_text": next_text}


## 레벨 하나의 표시 행 목록: [{field, text, next_text}]. next_text는 다음 레벨 값이
## 현재와 다를 때만 채워진다(빈 문자열이면 화살표 생략). 패시브 노드는 passive_stat
## 한 줄만, 액티브/버프는 sp_cost·cooldown_sec·damage_mult(0이면 생략 — 순수 유틸기
## 스킬의 "피해 0%" 노이즈 방지) + self_effect 필드 순으로 만든다.
static func level_detail_rows(entry: Dictionary, level: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var max_level: int = int(entry.get("max_level", DEFAULT_MAX_LEVEL))
	var cur: int = clampi(level, 1, max_level)
	var has_next: bool = cur < max_level
	var cur_lv: Dictionary = level_entry(entry, cur)
	var next_lv: Dictionary = level_entry(entry, cur + 1) if has_next else {}

	if entry.has("passive_stat"):
		var stat: String = String(entry["passive_stat"])
		if stat in KNOWN_PASSIVE_STATS and cur_lv.has("value"):
			rows.append(_row(stat, float(cur_lv["value"]), next_lv.get("value")))
		return rows

	for field in ACTIVE_FIELD_ORDER:
		if not cur_lv.has(field):
			continue
		var v: float = float(cur_lv[field])
		if field == "damage_mult" and is_equal_approx(v, 0.0):
			continue
		rows.append(_row(field, v, next_lv.get(field)))

	var self_effect: Dictionary = cur_lv.get("self_effect", {})
	var next_self_effect: Dictionary = next_lv.get("self_effect", {})
	for field in SELF_EFFECT_FIELD_ORDER:
		if not self_effect.has(field):
			continue
		rows.append(_row(field, float(self_effect[field]), next_self_effect.get(field)))
	return rows


## M5-1(마우스): 핫바 미리보기 칸 클릭 시 등록할 skill_id. 포커스된 노드가 있고
## active/buff 타입이며 실제로 배운(level>0) 상태일 때만 값을 준다(skill_tree_tab.gd의
## 기존 1~9 키 폴링 `_try_hotbar_register()`와 동일 가드) — 그 외에는 ""를 반환해
## 호출부가 등록을 시도하지 않게 한다.
static func assignable_skill_id(focused_id: String, skills_table: Dictionary, learned: Dictionary) -> String:
	if focused_id.is_empty():
		return ""
	var node_type: String = String(skills_table.get(focused_id, {}).get("node_type", ""))
	if node_type not in ["active", "buff"] or int(learned.get(focused_id, 0)) <= 0:
		return ""
	return focused_id
