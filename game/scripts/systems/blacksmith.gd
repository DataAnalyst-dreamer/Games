## 대장간 강화·재련·분해·제작 순수 로직(F3-3 S3-3a~c, F3-4, M2-4). LootSystem/Inventory/
## Equipment와 동일한 원칙 — Godot 노드에 의존하지 않는 RefCounted(static 함수만)라
## GUT에서 직접 테스트할 수 있다. 성공률·비용·배율·산출표는 전부 enhance.json/
## blueprints.json에서 읽고, 골드·재료 보유량은 호출부(GameState)가 인벤토리를 조회해
## 인자로 넘긴다 — 이 클래스는 GameState/Data/Inventory 인스턴스를 직접 참조하지 않는다.
## RNG는 전부 주입 가능(rng=null이면 새로 만들어 randomize()) — 테스트는 seed 고정 rng를
## 직접 넣어 결정적으로 검증한다.
##
## 반환 Dictionary는 전부 "ok"(bool) + 실패 시 "reason"(String, 이유 코드) 를 갖는다.
## 이유 코드: "gold"(골드 부족), "material"(재료 부족), "max_level"(강화 +10 도달),
## "invalid_level"/"invalid_attempt"(enhance.json에 해당 단계 설정 없음),
## "no_attempts_left"(재련 3회 소진), "not_refinable"(등급이 재련 대상 아님, 예: common),
## "invalid_affix_index", "no_pending_refine", "equipped"(장착 중 분해 불가),
## "locked"(즐겨찾기 잠금 분해 불가, D-85), "invalid_grade", "invalid_blueprint",
## "invalid_result_item".
##
## salvage()는 D-85(디렉터 결정)로 단일/다수 구분 없이 항상 Array를 받는 일괄 처리
## 시그니처다 — 반환은 {ok, results:[{ok, uid, reason?|yields}], yields(합산)}.
class_name Blacksmith
extends RefCounted

## enhance.json.disassemble.yield_by_grade가 돌려주는 "material_qty"는 강화석이 아닌
## 범용 분해 재료다 — item_id는 enhance.json 자체에 없어(문서 주석 참고) 여기 상수로
## 고정한다(items.json 실제 키, docs/specs/data_tables.md §1 재료 목록).
const SALVAGE_MATERIAL_ID := "salvage_scrap"


static func _rng_or_new(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r


## 강화 1회 시행(S3-3a, D-14 성공률·D-32 실패 천장 없음). gold/stone_qty는 호출부가 이미
## 조회한 현재 보유량. 성공/실패와 무관하게 "시행 자체"의 비용(골드+강화석)은 매번
## 소모된다 — docs/specs/data_tables.md §6 "+10까지 기대 비용" 표(예: +7 기대 1.43회 ×
## 200골드 ≈ 285.7골드)가 이 전제로 계산돼 있다. **결정 필요**: F3-3 원문 "실패 시
## 강화석만 소실"은 골드 환불로도 읽힐 수 있어 game-designer 확인이 필요하다 — 완료
## 보고 질문 목록 참고, 여기서는 data_tables.md §6의 수치화된 기댓값 표를 정본으로
## 채택했다(실패해도 골드는 이미 지불된 상태로 유지).
static func enhance(item_inst: Dictionary, enhance_table: Dictionary, gold: int, stone_qty: int,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var level: int = int(item_inst.get("enhance_level", 0))
	if level >= 10:
		return {"ok": false, "reason": "max_level"}
	var next_level: int = level + 1
	var cfg: Dictionary = (enhance_table.get("enhance_levels", {}) as Dictionary).get("+%d" % next_level, {})
	if cfg.is_empty():
		return {"ok": false, "reason": "invalid_level"}
	var cost_gold: int = int(cfg.get("cost_gold", 0))
	var cost_stone: int = int(cfg.get("cost_stone_qty", 0))
	if gold < cost_gold:
		return {"ok": false, "reason": "gold"}
	if stone_qty < cost_stone:
		return {"ok": false, "reason": "material"}

	var local_rng: RandomNumberGenerator = _rng_or_new(rng)
	var success_rate: float = float(cfg.get("success_rate", 1.0))
	var success: bool = local_rng.randf() < success_rate
	if success:
		item_inst["enhance_level"] = next_level

	return {
		"ok": true,
		"success": success,
		"level": int(item_inst.get("enhance_level", level)),
		"consumed": {"gold": cost_gold, "enhance_stone": cost_stone},
	}


## 재련 1단계(S3-3b, D-13 / D-85 디렉터 결정): affix_index번째 옵션 줄을 같은 카테고리
## 풀에서 새로 굴려 신·구 후보를 item_inst["_pending_affix"]에 잠정 저장한다. **골드와
## 재련 횟수(refine_left)는 이 호출 즉시 차감된다**(D-85: "무료 재굴림 반복 방지" —
## 이전 설계는 확정(refine_commit) 시점에 횟수를 차감했으나, 커밋 전 굴림을 몇 번이고
## 취소·재시도할 수 있는 허점이 있어 디렉터가 refine() 시점 차감으로 확정했다). 이미
## 대기 중인 미확정 결과가 있으면 auto_resolve_pending()으로 먼저 정리한 뒤 호출할 것
## (GameState 래퍼가 다른 액션 진입 시 항상 그렇게 한다 — 이 함수 자체는 강제하지 않고
## 있으면 그냥 덮어쓴다).
static func refine(item_inst: Dictionary, affix_index: int, item_def: Dictionary,
		affixes_table: Dictionary, enhance_table: Dictionary, gold: int, stone_qty: int,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var affixes: Array = item_inst.get("affixes", [])
	if affix_index < 0 or affix_index >= affixes.size():
		return {"ok": false, "reason": "invalid_affix_index"}
	if int(item_inst.get("refine_left", 0)) <= 0:
		return {"ok": false, "reason": "no_attempts_left"}

	var grade: String = String(item_inst.get("grade", ""))
	var refine_cfg: Dictionary = enhance_table.get("refine", {})
	var max_attempts: int = int(refine_cfg.get("max_attempts", 3))
	var cost_by_grade: Dictionary = (refine_cfg.get("cost_by_grade_and_attempt", {}) as Dictionary).get(grade, {})
	if cost_by_grade.is_empty():
		return {"ok": false, "reason": "not_refinable"}
	# 몇 번째 시도인지: 차감 전 refine_left 기준으로 역산(예: max_attempts=3, refine_left=3
	# 이면 1번째 시도).
	var attempt_number: int = max_attempts - int(item_inst.get("refine_left", 0)) + 1
	var attempt_cfg: Dictionary = cost_by_grade.get("attempt_%d" % attempt_number, {})
	if attempt_cfg.is_empty():
		return {"ok": false, "reason": "invalid_attempt"}
	var cost_gold: int = int(attempt_cfg.get("cost_gold", 0))
	var cost_material: int = int(attempt_cfg.get("cost_material_qty", 0))
	if gold < cost_gold:
		return {"ok": false, "reason": "gold"}
	if stone_qty < cost_material:
		return {"ok": false, "reason": "material"}

	var category: String = String(item_def.get("category", ""))
	var exclude_ids: Dictionary = {}
	for i in affixes.size():
		if i != affix_index:
			exclude_ids[String((affixes[i] as Dictionary).get("affix_id", ""))] = true
	var pool: Array = []
	for candidate: Dictionary in LootSystem.applicable_affixes(category, affixes_table):
		if not exclude_ids.has(String(candidate.get("affix_id", ""))):
			pool.append(candidate)

	var local_rng: RandomNumberGenerator = _rng_or_new(rng)
	var new_affix: Dictionary = {}
	if not pool.is_empty():
		var weights: Dictionary = {}
		for i2 in pool.size():
			weights[str(i2)] = float((pool[i2] as Dictionary).get("weight", 0.0))
		var idx: int = int(LootSystem.pick_weighted(local_rng, weights))
		var chosen: Dictionary = pool[idx]
		var value: float = local_rng.randf_range(float(chosen.get("value_min", 0.0)), float(chosen.get("value_max", 0.0)))
		new_affix = {"affix_id": chosen.get("affix_id", ""), "stat_type": chosen.get("stat_type", ""), "value": value}

	var old_affix: Dictionary = (affixes[affix_index] as Dictionary).duplicate(true)
	item_inst["_pending_affix"] = {"affix_index": affix_index, "new_affix": new_affix.duplicate(true), "old_affix": old_affix}
	item_inst["refine_left"] = maxi(0, int(item_inst.get("refine_left", 0)) - 1) # D-85: 즉시 차감.
	return {
		"ok": true,
		"old_affix": old_affix,
		"new_affix": new_affix,
		"refine_left": int(item_inst["refine_left"]),
		"cost": {
			"gold": cost_gold,
			"material_id": String(refine_cfg.get("cost_material_id", "enhance_stone")),
			"material_qty": cost_material,
		},
	}


## 재련 2단계(D-13 "신·구 옵션 중 택1"): D-85 이후로는 택1 자체에 추가 비용도, 횟수
## 차감도 없다(둘 다 refine()에서 이미 끝났다) — 이 함수는 오직 어느 옵션을 item_inst.
## affixes에 확정 반영할지만 결정한다. 대기 중인 결과가 없으면 실패.
static func refine_commit(item_inst: Dictionary, keep_new: bool) -> Dictionary:
	var pending: Variant = item_inst.get("_pending_affix")
	if typeof(pending) != TYPE_DICTIONARY or (pending as Dictionary).is_empty():
		return {"ok": false, "reason": "no_pending_refine"}
	var pending_dict: Dictionary = pending
	var affix_index: int = int(pending_dict.get("affix_index", -1))
	var affixes: Array = item_inst.get("affixes", [])
	item_inst.erase("_pending_affix")
	if affix_index < 0 or affix_index >= affixes.size():
		return {"ok": false, "reason": "invalid_affix_index"}

	if keep_new:
		affixes[affix_index] = (pending_dict.get("new_affix", {}) as Dictionary).duplicate(true)
	return {
		"ok": true,
		"kept": "new" if keep_new else "old",
		"affix": (affixes[affix_index] as Dictionary).duplicate(true),
	}


## D-85: "미commit 시 구 옵션 유지로 자동 처리" — refine() 이후 refine_commit()이
## 호출되지 않은 채 다른 대장간 액션(강화/재련 재굴림/분해)이 그 아이템에 들어오면,
## 그 액션을 실행하기 전에 이 함수로 미확정 재련을 자동으로 "구 옵션 유지"로 정리한다
## (GameState 래퍼가 각 진입점 최상단에서 호출). 대기 중인 게 없으면 아무 일도 안 한다.
static func auto_resolve_pending(item_inst: Dictionary) -> void:
	if item_inst.is_empty():
		return
	var pending: Variant = item_inst.get("_pending_affix")
	if typeof(pending) == TYPE_DICTIONARY and not (pending as Dictionary).is_empty():
		refine_commit(item_inst, false)


## 분해(S3-3c) 일괄 처리(D-85: 단일 분해도 길이 1짜리 Array로 호출). 항목별로
## 장착 중("equipped")·잠금("locked", D-85 신설)·미정의 등급("invalid_grade")을 개별
## 판정해 results 배열에 담고, 성공한 항목들의 산출을 yields에 합산한다. equipped_uids는
## 호출부(GameState)가 Equipment.slots를 스캔해 판단해 넘긴다 — 이 클래스는 Equipment를
## 직접 참조하지 않는다. 최상단 "ok"는 하나라도 성공하면 true(부분 성공 허용).
static func salvage(item_insts: Array, enhance_table: Dictionary, equipped_uids: Array) -> Dictionary:
	var stone_material_id: String = String((enhance_table.get("refine", {}) as Dictionary).get("cost_material_id", "enhance_stone"))
	var results: Array = []
	var total_yields: Dictionary = {}
	var any_ok: bool = false

	for item_inst: Dictionary in item_insts:
		var uid: String = String(item_inst.get("uid", ""))
		if equipped_uids.has(uid):
			results.append({"ok": false, "reason": "equipped", "uid": uid})
			continue
		if bool(item_inst.get("locked", false)):
			results.append({"ok": false, "reason": "locked", "uid": uid})
			continue
		var grade: String = String(item_inst.get("grade", "common"))
		var yield_entry: Dictionary = (enhance_table.get("disassemble", {}) as Dictionary).get("yield_by_grade", {}).get(grade, {})
		if yield_entry.is_empty():
			results.append({"ok": false, "reason": "invalid_grade", "uid": uid})
			continue
		var item_yields: Dictionary = {
			stone_material_id: int(yield_entry.get("stone_qty", 0)),
			SALVAGE_MATERIAL_ID: int(yield_entry.get("material_qty", 0)),
		}
		for material_id: String in item_yields:
			total_yields[material_id] = int(total_yields.get(material_id, 0)) + int(item_yields[material_id])
		results.append({"ok": true, "uid": uid, "yields": item_yields})
		any_ok = true

	return {"ok": any_ok, "results": results, "yields": total_yields}


# --- 미리보기 API (부작용 없음, D-85 신설) — UI는 이 4개 함수만 읽고, 실제 소모/반영은
# 위 enhance()/refine()/salvage()/craft() + GameState 래퍼가 담당한다. ---

## 강화 미리보기. +10 도달 시 "maxed"=true와 함께 더 강화할 수 없음을 알린다.
static func get_enhance_preview(item_inst: Dictionary, enhance_table: Dictionary) -> Dictionary:
	var level: int = int(item_inst.get("enhance_level", 0))
	if level >= 10:
		return {
			"level_next": null, "success_rate": 0.0, "cost_gold": 0, "cost_items": {},
			"stat_multiplier_next": Equipment.enhance_multiplier(level, enhance_table), "maxed": true,
		}
	var next_level: int = level + 1
	var cfg: Dictionary = (enhance_table.get("enhance_levels", {}) as Dictionary).get("+%d" % next_level, {})
	var stone_id: String = String((enhance_table.get("refine", {}) as Dictionary).get("cost_material_id", "enhance_stone"))
	return {
		"level_next": next_level,
		"success_rate": float(cfg.get("success_rate", 0.0)),
		"cost_gold": int(cfg.get("cost_gold", 0)),
		"cost_items": {stone_id: int(cfg.get("cost_stone_qty", 0))},
		"stat_multiplier_next": Equipment.enhance_multiplier(next_level, enhance_table),
		"maxed": false,
	}


## 재련 비용 미리보기(다음 시도 1회 기준). 재련 대상이 아니거나(common 등) 횟수가
## 소진됐으면 "refinable"=false.
static func get_refine_cost(item_inst: Dictionary, enhance_table: Dictionary) -> Dictionary:
	var grade: String = String(item_inst.get("grade", ""))
	var refine_cfg: Dictionary = enhance_table.get("refine", {})
	var max_attempts: int = int(refine_cfg.get("max_attempts", 3))
	var attempts_left: int = int(item_inst.get("refine_left", 0))
	var cost_by_grade: Dictionary = (refine_cfg.get("cost_by_grade_and_attempt", {}) as Dictionary).get(grade, {})
	if cost_by_grade.is_empty() or attempts_left <= 0:
		return {"cost_gold": 0, "attempts_left": attempts_left, "refinable": false}
	var attempt_number: int = max_attempts - attempts_left + 1
	var attempt_cfg: Dictionary = cost_by_grade.get("attempt_%d" % attempt_number, {})
	return {
		"cost_gold": int(attempt_cfg.get("cost_gold", 0)),
		"attempts_left": attempts_left,
		"cost_material_id": String(refine_cfg.get("cost_material_id", "enhance_stone")),
		"cost_material_qty": int(attempt_cfg.get("cost_material_qty", 0)),
		"refinable": not attempt_cfg.is_empty(),
	}


## 분해 산출 미리보기(다수 아이템 합산) — 장착/잠금 여부는 반영하지 않는다(실제 거부는
## salvage() 호출 시점에 일어나며, UI가 이미 선택 목록에서 걸러 보여준다는 전제).
static func get_salvage_preview(item_insts: Array, enhance_table: Dictionary) -> Dictionary:
	var stone_material_id: String = String((enhance_table.get("refine", {}) as Dictionary).get("cost_material_id", "enhance_stone"))
	var yields: Dictionary = {}
	for item_inst: Dictionary in item_insts:
		var grade: String = String(item_inst.get("grade", "common"))
		var yield_entry: Dictionary = (enhance_table.get("disassemble", {}) as Dictionary).get("yield_by_grade", {}).get(grade, {})
		if yield_entry.is_empty():
			continue
		yields[stone_material_id] = int(yields.get(stone_material_id, 0)) + int(yield_entry.get("stone_qty", 0))
		yields[SALVAGE_MATERIAL_ID] = int(yields.get(SALVAGE_MATERIAL_ID, 0)) + int(yield_entry.get("material_qty", 0))
	return {"yields": yields}


## 제작 미리보기 — 재료별 필요/보유 수량과 제작 가능 여부(골드+재료 모두 충족)를 계산.
static func get_craft_preview(blueprint_id: String, blueprints_table: Dictionary,
		have_materials: Dictionary, gold: int) -> Dictionary:
	var bp: Dictionary = blueprints_table.get(blueprint_id, {})
	if bp.is_empty():
		return {"materials": [], "cost_gold": 0, "can_craft": false}
	var cost_gold: int = int(bp.get("cost_gold", 0))
	var can_craft: bool = gold >= cost_gold
	var materials: Array = []
	for mat: Dictionary in (bp.get("materials", []) as Array):
		var mat_id: String = String(mat.get("item_id", ""))
		var need: int = int(mat.get("qty", 0))
		var have: int = int(have_materials.get(mat_id, 0))
		materials.append({"id": mat_id, "need": need, "have": have})
		if have < need:
			can_craft = false
	return {"materials": materials, "cost_gold": cost_gold, "can_craft": can_craft}


## 제작(F3-4). 도면은 소모되지 않는다(호출부가 blueprint_id 인벤토리 아이템을 지우지
## 않는 것으로 그 규칙을 지킨다 — 이 함수는 blueprints_table을 읽기만 한다). materials는
## {item_id: 보유수량} — 호출부가 인벤토리를 미리 합산해 넘긴다.
static func craft(blueprint_id: String, blueprints_table: Dictionary, items_table: Dictionary,
		affixes_table: Dictionary, refine_max_attempts: int, gold: int, materials: Dictionary,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if blueprint_id.begins_with("_") or not blueprints_table.has(blueprint_id):
		return {"ok": false, "reason": "invalid_blueprint"}
	var bp: Dictionary = blueprints_table[blueprint_id]
	var cost_gold: int = int(bp.get("cost_gold", 0))
	if gold < cost_gold:
		return {"ok": false, "reason": "gold"}
	for mat: Dictionary in (bp.get("materials", []) as Array):
		var mat_id: String = String(mat.get("item_id", ""))
		var need: int = int(mat.get("qty", 0))
		if int(materials.get(mat_id, 0)) < need:
			return {"ok": false, "reason": "material", "material_id": mat_id}

	var result_item_id: String = String(bp.get("result_item_id", ""))
	var item_def: Dictionary = items_table.get(result_item_id, {})
	if item_def.is_empty():
		return {"ok": false, "reason": "invalid_result_item"}

	var local_rng: RandomNumberGenerator = _rng_or_new(rng)
	# base_stats/affix_slot_count/grade 재정의 없이 items.json 정의를 그대로 재사용
	# (blueprints.json _comment 원칙 그대로) — LootSystem.make_item_instance()를 그대로
	# 호출해 드랍 아이템과 동일한 인스턴스 형태를 만든다(중복 로직 없음).
	var item_inst: Dictionary = LootSystem.make_item_instance(
		result_item_id, item_def, affixes_table, refine_max_attempts, 1, local_rng)
	return {
		"ok": true,
		"item_inst": item_inst,
		"consumed": {"gold": cost_gold, "materials": (bp.get("materials", []) as Array).duplicate(true)},
	}
