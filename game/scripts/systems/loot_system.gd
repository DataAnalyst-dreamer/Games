## 드랍 생성 순수 로직(F3-1, docs/specs/items-and-drops-m2.md). Godot 노드도 아니고
## 오토로드도 아니다 — GUT에서 직접 테이블 딕셔너리를 넣어 테스트할 수 있도록 핵심 계산
## (등급 확률·가중치 추첨·옵션 추첨)은 전부 static/순수 함수로 두고, 실제 게임에서 쓰는
## 편의 진입점(roll_drop/roll_gold)만 Data 오토로드 테이블을 대신 읽어준다.
##
## 사용처: scripts/systems/loot_spawner.gd(Events.enemy_died 구독, 실제 스폰).
##
## ItemInstance 스키마(Dictionary, Resource 대신 선택 — JSON 직렬화가 그대로 GameState.
## to_dict()/세이브에 쓰이므로 Dictionary가 더 단순하다):
##   uid: String            고유 인스턴스 id(같은 item_id라도 개체마다 다름 — 강화 단계 등)
##   item_id: String
##   grade: String           "common".."relic"
##   quantity: int           소모품/재료 스택 수량(장비는 항상 1)
##   affixes: Array[Dictionary]  [{affix_id, stat_type, value}] — 장비만, 옵션 없으면 []
##   enhance_level: int      0 (드랍 직후는 항상 +0)
##   refine_left: int        재련 가능 횟수(D-13: 3) — affix_slot_count==0(common 등급)이면 0
class_name LootSystem
extends RefCounted

## uid 충돌 방지용 프로세스 전역 카운터(GDScript 4.2+ static var, 인스턴스 없이 공유됨).
static var _uid_counter: int = 0


# --- LUK 곱연산 공식 (D-52 단일 소스: drop_tables.json._luck_formula) ---

## grade별 LUK 배율. common은 항상 1.0(§4 "common은 곱연산 대상 아님").
static func luck_multiplier(grade: String, luk: float, luk_coefficient: Dictionary) -> float:
	if grade == "common":
		return 1.0
	return 1.0 + luk * float(luk_coefficient.get(grade, 0.0))


## grade_base_weight × luk_multiplier → 정규화된 최종 확률(합계 1.0). 가중치가 전부 0인
## 비정상 입력(빈 테이블 등)에서는 균등분포로 안전하게 대체한다.
static func compute_final_probabilities(grade_base_weight: Dictionary, luk: float, luk_coefficient: Dictionary) -> Dictionary:
	var raw_weight: Dictionary = {}
	var total := 0.0
	for grade: String in grade_base_weight:
		var base: float = float(grade_base_weight[grade])
		var raw: float = base * luck_multiplier(grade, luk, luk_coefficient)
		raw_weight[grade] = raw
		total += raw
	var final_probability: Dictionary = {}
	if total <= 0.0:
		var n: int = maxi(grade_base_weight.size(), 1)
		for grade2: String in grade_base_weight:
			final_probability[grade2] = 1.0 / float(n)
		return final_probability
	for grade3: String in raw_weight:
		final_probability[grade3] = raw_weight[grade3] / total
	return final_probability


# --- 가중 랜덤 추첨(등급 확률·엔트리 weight 공용) ---

## weights: {key: weight(float)}. weight 합이 0 이하면 첫 키를 반환(방어적 폴백 — 정상
## 데이터라면 검증 단계에서 이미 걸러진다).
static func pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k: String in weights:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return String(weights.keys()[0]) if not weights.is_empty() else ""
	var roll: float = rng.randf() * total
	var acc := 0.0
	for k2: String in weights:
		acc += maxf(float(weights[k2]), 0.0)
		if roll < acc:
			return k2
	return String(weights.keys()[-1])


## 등급별 최종 확률로 등급 하나를 뽑는다.
static func pick_grade(rng: RandomNumberGenerator, final_probabilities: Dictionary) -> String:
	return pick_weighted(rng, final_probabilities)


# --- entries(아이템 후보 목록) 추첨 ---

## entries 중 items_table에서 조회한 grade가 target_grade와 일치하는 것만 남긴다
## (§5-1: "등급 판정 → 그 등급 안에서만 entries.weight로 아이템 추첨"과 동일한 2단계 모델 —
## grade_base_weight가 어느 등급을 뽑을지 정하고, weight는 같은 등급 안에서만 경쟁한다).
static func filter_entries_by_grade(entries: Array, target_grade: String, items_table: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in entries:
		var item_id: String = String(entry.get("item_id", ""))
		var item_def: Dictionary = items_table.get(item_id, {})
		if String(item_def.get("grade", "")) == target_grade:
			out.append(entry)
	return out


## 후보 entries 중 weight 가중 추첨으로 하나를 고른다. 빈 배열이면 {} 반환.
static func pick_entry(rng: RandomNumberGenerator, candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var weights: Dictionary = {}
	for i in candidates.size():
		weights[str(i)] = float((candidates[i] as Dictionary).get("weight", 0.0))
	var picked_index: int = int(pick_weighted(rng, weights))
	return candidates[picked_index]


# --- 옵션(affix) 추첨 ---

## item_def.category에 적용 가능한 affix만 남긴다.
static func applicable_affixes(category: String, affixes_table: Dictionary) -> Array:
	var out: Array = []
	for affix_id: String in affixes_table:
		if affix_id.begins_with("_"):
			continue
		var affix: Dictionary = affixes_table[affix_id]
		if (affix.get("applicable_categories", []) as Array).has(category):
			out.append(affix)
	return out


## count개의 서로 다른 affix를 가중 추첨(중복 금지 — 뽑힌 affix_id는 풀에서 제거)하고,
## 각각 value_min~value_max 사이 값을 굴려 [{affix_id, stat_type, value}] 로 반환.
## 후보가 count보다 적으면 있는 만큼만 반환한다(방어적 — 정상 데이터에선 20종 vs 최대
## 2개 요구라 발생하지 않는다).
static func roll_affixes(rng: RandomNumberGenerator, category: String, affixes_table: Dictionary, count: int) -> Array:
	if count <= 0:
		return []
	var pool: Array = applicable_affixes(category, affixes_table)
	var result: Array = []
	for _i in count:
		if pool.is_empty():
			break
		var weights: Dictionary = {}
		for i in pool.size():
			weights[str(i)] = float((pool[i] as Dictionary).get("weight", 0.0))
		var idx: int = int(pick_weighted(rng, weights))
		var chosen: Dictionary = pool[idx]
		pool.remove_at(idx) # 중복 금지: 뽑힌 옵션은 다시 뽑히지 않는다.
		var value_min: float = float(chosen.get("value_min", 0.0))
		var value_max: float = float(chosen.get("value_max", 0.0))
		var value: float = rng.randf_range(value_min, value_max)
		result.append({
			"affix_id": chosen.get("affix_id", ""),
			"stat_type": chosen.get("stat_type", ""),
			"value": value,
		})
	return result


# --- ItemInstance 생성 ---

static func _next_uid() -> String:
	_uid_counter += 1
	return "drop_%d_%d" % [Time.get_ticks_usec(), _uid_counter]


## item_def(items.json 엔트리) + affixes_table + 이미 정해진 등급/수량으로 하나의
## ItemInstance Dictionary를 만든다. 장비(EQUIP_CATEGORIES)만 옵션을 굴리고, 그 외
## (소모품/재료/치장)는 affixes=[]·refine_left=0으로 고정한다(F3-1 "옵션 개수: 고급1/
## 희귀2" 규칙은 item_def.affix_slot_count에 이미 반영돼 있다 — items.json §2-2 규칙1).
static func make_item_instance(item_id: String, item_def: Dictionary, affixes_table: Dictionary,
		refine_max_attempts: int, quantity: int, rng: RandomNumberGenerator) -> Dictionary:
	var grade: String = String(item_def.get("grade", "common"))
	var category: String = String(item_def.get("category", ""))
	var is_equip: bool = Data.EQUIP_CATEGORIES.has(category)
	var slot_count: int = int(item_def.get("affix_slot_count", 0))
	var affixes: Array = roll_affixes(rng, category, affixes_table, slot_count) if is_equip else []
	return {
		"uid": _next_uid(),
		"item_id": item_id,
		"grade": grade,
		"quantity": 1 if is_equip else maxi(quantity, 1),
		"affixes": affixes,
		"enhance_level": 0,
		"refine_left": refine_max_attempts if (is_equip and slot_count > 0) else 0,
	}


# --- 실제 게임 진입점(Data 오토로드 테이블을 대신 읽어주는 편의 래퍼) ---

## drop_table_id 소스에서 아이템 1개를 굴린다. luck: 플레이어 LUK 스탯(stats.json 미구현
## 이라 호출부는 현재 0.0 고정 — GameState.get_player_luck() TODO 참고). rng를 주지 않으면
## 새로 만들어 randomize()한다(테스트는 시드 고정 rng를 직접 넣는다).
## 반환: Array(길이 0 또는 1) — drop_table_id가 없거나 해당 등급에 entries가 없으면 빈 배열.
static func roll_drop(drop_table_id: StringName, luck: float, rng: RandomNumberGenerator = null) -> Array:
	var local_rng: RandomNumberGenerator = rng if rng != null else _make_randomized_rng()
	var drop_tables: Dictionary = Data.table("drop_tables")
	var table: Dictionary = drop_tables.get(String(drop_table_id), {})
	if table.is_empty():
		return []
	var luk_coefficient: Dictionary = (drop_tables.get("_luck_formula", {}) as Dictionary).get("luk_coefficient", {})
	var final_probabilities: Dictionary = compute_final_probabilities(
		table.get("grade_base_weight", {}), luck, luk_coefficient)
	var grade: String = pick_grade(local_rng, final_probabilities)

	var items_table: Dictionary = Data.table("items")
	var candidates: Array = filter_entries_by_grade(table.get("entries", []), grade, items_table)
	var entry: Dictionary = pick_entry(local_rng, candidates)
	if entry.is_empty():
		return [] # 빈 풀(정상 데이터라면 Data._validate_drop_tables()가 이미 막는다).

	var item_id: String = String(entry.get("item_id", ""))
	var item_def: Dictionary = items_table.get(item_id, {})
	if item_def.is_empty():
		return []
	var qty: int = local_rng.randi_range(int(entry.get("qty_min", 1)), int(entry.get("qty_max", 1)))
	var refine_max: int = int((Data.get_value("enhance", "refine.max_attempts", 3)))
	var instance: Dictionary = make_item_instance(
		item_id, item_def, Data.table("affixes"), refine_max, qty, local_rng)
	return [instance]


## drop_table_id 소스의 골드 드랍량을 굴린다. gold_drop이 없으면 0.
static func roll_gold(drop_table_id: StringName, rng: RandomNumberGenerator = null) -> int:
	var local_rng: RandomNumberGenerator = rng if rng != null else _make_randomized_rng()
	var table: Dictionary = Data.table("drop_tables").get(String(drop_table_id), {})
	var gold_drop: Dictionary = table.get("gold_drop", {})
	if gold_drop.is_empty():
		return 0
	return local_rng.randi_range(int(gold_drop.get("min", 0)), int(gold_drop.get("max", 0)))


static func _make_randomized_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng
