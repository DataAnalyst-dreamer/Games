## 인벤토리 메뉴(F7-2, M2-2)의 필터·비교 툴팁 순수 계산. Godot 노드에 의존하지 않는
## RefCounted라 GUT에서 직접 테스트한다. 자동 정렬 자체는 새로 만들지 않고 기존
## Inventory.sort_slots()(M2-1, test_inventory.gd에 이미 검증됨)를 그대로 호출부에서
## 쓴다 — 여기서는 "격자에 뭘 보여줄지(필터)"와 "비교 툴팁에 뭘 적을지"만 계산한다.
class_name InventoryUiCalc
extends RefCounted


## 등급 필터에 맞는 슬롯 인덱스만 남긴다. grade_filter가 ""이거나 "all"이면 전체 통과.
static func filter_indices(slots: Array, grade_filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		if grade_filter == "" or grade_filter == "all":
			out.append(i)
			continue
		var slot: Dictionary = slots[i]
		if String(slot.get("grade", "")) == grade_filter:
			out.append(i)
	return out


## Equipment.compute_stats()가 다루는 4종 본체 수치 중 이 카테고리가 기여하는 stat_key.
## ring/amulet/소모품/재료 등 본체 수치가 없는 카테고리는 ""를 반환한다.
static func base_stat_key(category: String) -> String:
	match category:
		"weapon":
			return "attack"
		"sub", "head", "armor", "boots":
			return "defense"
		_:
			return ""


## 아이템 1개의 "본체 수치"(무기=평균 공격력, 방어구류=평균 방어력) — Equipment.
## compute_stats()와 같은 계산 규칙((min+max)/2 * 강화배율)을 개별 아이템에 적용한다
## (그 함수는 장착 전체 합산이라 아이템 1개 비교엔 그대로 못 쓴다). 강화 배율 자체는
## Equipment.enhance_multiplier()를 그대로 쓴다(디렉터 결정 D-85: 중복 정의 금지 — 이
## 파일이 예전에 들고 있던 private _enhance_multiplier()는 제거했다).
static func base_stat_value(item_def: Dictionary, enhance_level: int, enhance_table: Dictionary) -> float:
	if item_def.is_empty():
		return 0.0
	var category := String(item_def.get("category", ""))
	var base_stats: Dictionary = item_def.get("base_stats", {})
	var mult := Equipment.enhance_multiplier(enhance_level, enhance_table)
	match category:
		"weapon":
			return (float(base_stats.get("atk_min", 0.0)) + float(base_stats.get("atk_max", 0.0))) * 0.5 * mult
		"sub", "head", "armor", "boots":
			return (float(base_stats.get("defense_min", 0.0)) + float(base_stats.get("defense_max", 0.0))) * 0.5 * mult
		_:
			return 0.0


## affix 배열([{affix_id, stat_type, value}, ...])을 stat_type -> 합산값으로 묶는다
## (같은 stat_type을 가진 옵션이 이론상 2개 붙을 수 있어 sum으로 안전하게 처리).
static func affix_totals(affixes: Array) -> Dictionary:
	var out: Dictionary = {}
	for affix: Dictionary in affixes:
		var stat_type := String(affix.get("stat_type", ""))
		if stat_type == "":
			continue
		out[stat_type] = float(out.get(stat_type, 0.0)) + float(affix.get("value", 0.0))
	return out


## 비교 툴팁 한 줄: {stat_key, equipped_value, candidate_value, delta, is_new}.
## candidate = 그리드에서 포커스한 아이템(instance+def), equipped = 같은 슬롯에 이미
## 장착된 아이템(없으면 빈 Dictionary 둘 다 넘기면 됨). 반환 순서: 본체 수치(있으면) →
## affix stat_type 알파벳 순.
static func compare_rows(candidate_item: Dictionary, candidate_def: Dictionary,
		equipped_item: Dictionary, equipped_def: Dictionary, enhance_table: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var category := String(candidate_def.get("category", ""))
	var stat_key := base_stat_key(category)
	if stat_key != "":
		var cand_val := base_stat_value(candidate_def, int(candidate_item.get("enhance_level", 0)), enhance_table)
		var eq_val := base_stat_value(equipped_def, int(equipped_item.get("enhance_level", 0)), enhance_table)
		rows.append({
			"stat_key": stat_key,
			"equipped_value": eq_val,
			"candidate_value": cand_val,
			"delta": cand_val - eq_val,
			"is_new": false,
		})

	var cand_affixes := affix_totals(candidate_item.get("affixes", []))
	var eq_affixes := affix_totals(equipped_item.get("affixes", []))
	var stat_types: Array[String] = []
	for k: String in cand_affixes:
		if not stat_types.has(k):
			stat_types.append(k)
	for k2: String in eq_affixes:
		if not stat_types.has(k2):
			stat_types.append(k2)
	stat_types.sort()
	for stat_type: String in stat_types:
		var cand_v: float = float(cand_affixes.get(stat_type, 0.0))
		var eq_v: float = float(eq_affixes.get(stat_type, 0.0))
		rows.append({
			"stat_key": stat_type,
			"equipped_value": eq_v,
			"candidate_value": cand_v,
			"delta": cand_v - eq_v,
			"is_new": not eq_affixes.has(stat_type),
		})
	return rows


## 스탯 증감 표시(순수 텍스트/색-토큰 계산 — 실제 Color 조회는 호출부가 theme에서 한다).
## color_token: "positive"/"negative"/"neutral". 화살표(▲/▼/–)는 항상 표시하고,
## colorblind_mode면 부호(+/-)까지 문자열에 병기한다(와이어프레임 §0.2 "색+아이콘
## 이중 채널" 원칙을 스탯 증감에도 동일 적용).
static func format_delta(delta: float, colorblind_mode: bool, decimals: int = 0) -> Dictionary:
	var arrow := "–"
	var color_token := "neutral"
	if delta > 0.0001:
		arrow = "▲"
		color_token = "positive"
	elif delta < -0.0001:
		arrow = "▼"
		color_token = "negative"
	var number_text: String = ("%." + str(decimals) + "f") % absf(delta)
	var text: String
	if colorblind_mode and color_token != "neutral":
		var sign_text: String = "+" if delta > 0.0 else "-"
		text = "%s%s%s" % [arrow, sign_text, number_text]
	else:
		text = "%s%s" % [arrow, number_text]
	return {"text": text, "color_token": color_token}
