## Blacksmith(scripts/systems/blacksmith.gd) 테스트 — 강화 +1~+6 무실패(D-14), +7 성공/
## 실패 결정적 검증(D-32 실패 천장 없음), 재련 신·구 택1과 D-85(즉시 차감) 정책, 분해
## 일괄 처리(장착 중·잠금 거부), 제작 재료/골드 부족. 실제 게임 데이터(enhance.json/
## items.json/affixes.json/blueprints.json)를 Data 오토로드로 그대로 읽어 검증한다 —
## "성공률·비용·배율·산출표는 enhance.json/blueprints.json에서만 읽는다"는 지시를 테스트
## 스스로도 지킨다(하드코딩된 기대값은 이 파일 상단에서 실제 테이블 값을 그대로 옮긴
## 것 — 표가 바뀌면 이 테스트도 같이 갱신해야 한다는 의미).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const WEAPON_DEF := {"category": "weapon", "grade": "uncommon", "base_stats": {"atk_min": 6, "atk_max": 8}}

# find_seed.gd(스크래치)로 사전 확인한 결정적 시드: rate=0.70 기준 seed=0 -> randf()=0.202
# (성공), seed=2 -> randf()=0.703(실패). enhance.json이 바뀌어 success_rate가 달라지면
# 이 시드도 다시 확인해야 한다.
const SEED_SUCCESS := 0
const SEED_FAIL := 2


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _weapon_item(level: int, affixes: Array = [], refine_left: int = 3) -> Dictionary:
	return {
		"uid": "u_weapon", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": affixes.duplicate(true), "enhance_level": level, "refine_left": refine_left, "locked": false,
	}


# --- 강화(S3-3a, D-14/D-32) ---

func test_enhance_plus1_to_plus6_always_succeeds_with_enough_resources() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	for level in range(0, 6):
		var item: Dictionary = _weapon_item(level)
		var cfg: Dictionary = enhance_table["enhance_levels"]["+%d" % (level + 1)]
		var result: Dictionary = Blacksmith.enhance(
			item, enhance_table, int(cfg["cost_gold"]), int(cfg["cost_stone_qty"]), _seeded_rng(level))
		assert_true(result["ok"], "레벨 +%d -> +%d 는 성공해야 함" % [level, level + 1])
		assert_true(result["success"], "D-14: +1~+6은 100%% 성공이어야 함 (레벨 %d)" % level)
		assert_eq(result["level"], level + 1)
		assert_eq(item["enhance_level"], level + 1)
		assert_eq(result["consumed"], {"gold": int(cfg["cost_gold"]), "enhance_stone": int(cfg["cost_stone_qty"])})


func test_enhance_plus7_success_with_seeded_rng() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var cfg: Dictionary = enhance_table["enhance_levels"]["+7"]
	var item: Dictionary = _weapon_item(6)
	var result: Dictionary = Blacksmith.enhance(
		item, enhance_table, int(cfg["cost_gold"]), int(cfg["cost_stone_qty"]), _seeded_rng(SEED_SUCCESS))
	assert_true(result["ok"])
	assert_true(result["success"], "seed=%d 는 rate=0.70 기준 성공이어야 함" % SEED_SUCCESS)
	assert_eq(item["enhance_level"], 7)


func test_enhance_plus7_failure_keeps_level_and_still_consumes_enhance_stone() -> void:
	# D-32(실패 천장 없음) + 결정 필요 항목(완료 보고 참고): F3-3 원문 "실패 시 강화석만
	## 소실"을 data_tables.md §6 기대 비용표(골드도 시행마다 소모)에 맞춰 "골드+강화석 모두
	## 매 시행 소모, 성공해야 단계만 오른다"로 구현했다 — 여기서는 그 구현을 그대로 검증한다.
	var enhance_table: Dictionary = Data.table("enhance")
	var cfg: Dictionary = enhance_table["enhance_levels"]["+7"]
	var item: Dictionary = _weapon_item(6)
	var result: Dictionary = Blacksmith.enhance(
		item, enhance_table, int(cfg["cost_gold"]), int(cfg["cost_stone_qty"]), _seeded_rng(SEED_FAIL))
	assert_true(result["ok"])
	assert_false(result["success"], "seed=%d 는 rate=0.70 기준 실패여야 함" % SEED_FAIL)
	assert_eq(result["level"], 6, "실패 시 단계 유지(D-32)")
	assert_eq(item["enhance_level"], 6)
	assert_eq(result["consumed"], {"gold": int(cfg["cost_gold"]), "enhance_stone": int(cfg["cost_stone_qty"])},
		"실패해도 이번 시행의 강화석(과 골드)은 소실됨")


func test_enhance_insufficient_gold_returns_reason_gold() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var item: Dictionary = _weapon_item(0)
	var result: Dictionary = Blacksmith.enhance(item, enhance_table, 0, 99, _seeded_rng(0))
	assert_false(result["ok"])
	assert_eq(result["reason"], "gold")
	assert_eq(item["enhance_level"], 0, "실패 판정 전이므로 인벤토리 상태도 그대로")


func test_enhance_insufficient_material_returns_reason_material() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var item: Dictionary = _weapon_item(0)
	var result: Dictionary = Blacksmith.enhance(item, enhance_table, 9999, 0, _seeded_rng(0))
	assert_false(result["ok"])
	assert_eq(result["reason"], "material")


func test_enhance_max_level_rejected() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var item: Dictionary = _weapon_item(10)
	var result: Dictionary = Blacksmith.enhance(item, enhance_table, 9999, 99, _seeded_rng(0))
	assert_false(result["ok"])
	assert_eq(result["reason"], "max_level")


# --- 재련(S3-3b, D-13 신·구 택1 / D-85 즉시 차감) ---

func test_refine_deducts_gold_and_attempt_immediately_on_roll() -> void:
	# D-85(디렉터 결정): refine() 호출 즉시 refine_left가 차감된다 — commit을 기다리지 않는다.
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var attempt1: Dictionary = enhance_table["refine"]["cost_by_grade_and_attempt"]["uncommon"]["attempt_1"]
	var item: Dictionary = _weapon_item(0, [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}], 3)

	var result: Dictionary = Blacksmith.refine(
		item, 0, WEAPON_DEF, affixes_table, enhance_table,
		int(attempt1["cost_gold"]), int(attempt1["cost_material_qty"]), _seeded_rng(1))

	assert_true(result["ok"])
	assert_eq(item["refine_left"], 2, "D-85: 굴림 즉시 1회 차감")
	assert_eq(result["refine_left"], 2)
	assert_eq(result["cost"]["gold"], int(attempt1["cost_gold"]))
	assert_has(item, "_pending_affix", "확정 전까지 대기 결과를 아이템에 보관해야 함")
	assert_eq(result["old_affix"]["affix_id"], "atk_pct")


func test_refine_commit_keep_new_replaces_affix_and_is_free() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var attempt1: Dictionary = enhance_table["refine"]["cost_by_grade_and_attempt"]["uncommon"]["attempt_1"]
	var item: Dictionary = _weapon_item(0, [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}], 3)
	var roll: Dictionary = Blacksmith.refine(
		item, 0, WEAPON_DEF, affixes_table, enhance_table,
		int(attempt1["cost_gold"]), int(attempt1["cost_material_qty"]), _seeded_rng(1))
	var refine_left_after_roll: int = item["refine_left"]

	var commit: Dictionary = Blacksmith.refine_commit(item, true)

	assert_true(commit["ok"])
	assert_eq(commit["kept"], "new")
	assert_eq(item["affixes"][0], roll["new_affix"])
	assert_eq(item["refine_left"], refine_left_after_roll, "D-85: 택1 확정은 추가 비용/횟수 차감이 없어야 함")
	assert_false(item.has("_pending_affix"), "확정 후 대기 필드는 지워져야 함")


func test_refine_commit_keep_old_preserves_original_affix() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var attempt1: Dictionary = enhance_table["refine"]["cost_by_grade_and_attempt"]["uncommon"]["attempt_1"]
	var original: Dictionary = {"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}
	var item: Dictionary = _weapon_item(0, [original], 3)
	Blacksmith.refine(item, 0, WEAPON_DEF, affixes_table, enhance_table,
		int(attempt1["cost_gold"]), int(attempt1["cost_material_qty"]), _seeded_rng(1))

	var commit: Dictionary = Blacksmith.refine_commit(item, false)

	assert_true(commit["ok"])
	assert_eq(commit["kept"], "old")
	assert_eq(item["affixes"][0], original, "신·구 택1(D-13) — 구 옵션 유지 선택 시 원본 그대로")


func test_auto_resolve_pending_keeps_old_when_not_committed() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var attempt1: Dictionary = enhance_table["refine"]["cost_by_grade_and_attempt"]["uncommon"]["attempt_1"]
	var original: Dictionary = {"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}
	var item: Dictionary = _weapon_item(0, [original], 3)
	Blacksmith.refine(item, 0, WEAPON_DEF, affixes_table, enhance_table,
		int(attempt1["cost_gold"]), int(attempt1["cost_material_qty"]), _seeded_rng(1))

	Blacksmith.auto_resolve_pending(item)

	assert_false(item.has("_pending_affix"))
	assert_eq(item["affixes"][0], original, "미확정 재련은 구 옵션 유지로 자동 처리(D-85)")


func test_refine_common_grade_is_not_refinable() -> void:
	# 실제 데이터에서 common은 affix_slot_count=0이라 refine_left도 항상 0(no_attempts_left로
	# 먼저 걸림, LootSystem.make_item_instance() 규칙). 여기서는 "common 등급 자체가
	# cost_by_grade_and_attempt에 없다(not_refinable)"는 별도 규칙을 직접 검증하기 위해
	# refine_left>0·옵션 1개 있음을 인위로 준 fixture를 쓴다(enhance.json 주석: "common은
	# 재련 대상에서 제외" — 실데이터가 아니라 그 규칙 자체를 단위 테스트로 고정한다).
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var item: Dictionary = {
		"uid": "u_common", "item_id": "weapon_common_1", "grade": "common", "quantity": 1,
		"affixes": [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}],
		"enhance_level": 0, "refine_left": 3, "locked": false,
	}
	var result: Dictionary = Blacksmith.refine(
		item, 0, {"category": "weapon", "grade": "common"}, affixes_table, enhance_table, 9999, 99)
	assert_false(result["ok"])
	assert_eq(result["reason"], "not_refinable")


func test_refine_no_attempts_left_after_three_rolls() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var affixes_table: Dictionary = Data.table("affixes")
	var item: Dictionary = _weapon_item(0, [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}], 1)
	var attempt3: Dictionary = enhance_table["refine"]["cost_by_grade_and_attempt"]["uncommon"]["attempt_3"]
	# refine_left=1이면 실제로는 3번째 시도 비용표를 찾아야 함(max_attempts - refine_left + 1 = 3).
	var result: Dictionary = Blacksmith.refine(
		item, 0, WEAPON_DEF, affixes_table, enhance_table,
		int(attempt3["cost_gold"]), int(attempt3["cost_material_qty"]), _seeded_rng(1))
	assert_true(result["ok"])
	assert_eq(item["refine_left"], 0)

	Blacksmith.auto_resolve_pending(item)
	var second: Dictionary = Blacksmith.refine(item, 0, WEAPON_DEF, affixes_table, enhance_table, 9999, 99)
	assert_false(second["ok"])
	assert_eq(second["reason"], "no_attempts_left")


# --- 분해(S3-3c, 일괄 처리 D-85) ---

func test_salvage_batch_rejects_equipped_and_locked_but_processes_others() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var equipped_item: Dictionary = _weapon_item(0)
	equipped_item["uid"] = "u_equipped"
	var locked_item: Dictionary = _weapon_item(0)
	locked_item["uid"] = "u_locked"
	locked_item["locked"] = true
	var free_item: Dictionary = _weapon_item(0)
	free_item["uid"] = "u_free"

	var result: Dictionary = Blacksmith.salvage(
		[equipped_item, locked_item, free_item], enhance_table, ["u_equipped"])

	assert_true(result["ok"], "일부라도 성공하면 배치 전체 ok=true")
	var by_uid: Dictionary = {}
	for r: Dictionary in result["results"]:
		by_uid[r["uid"]] = r
	assert_false(by_uid["u_equipped"]["ok"])
	assert_eq(by_uid["u_equipped"]["reason"], "equipped")
	assert_false(by_uid["u_locked"]["ok"])
	assert_eq(by_uid["u_locked"]["reason"], "locked")
	assert_true(by_uid["u_free"]["ok"])

	var expected_yield: Dictionary = enhance_table["disassemble"]["yield_by_grade"]["uncommon"]
	assert_eq(result["yields"]["enhance_stone"], int(expected_yield["stone_qty"]),
		"장착/잠금 항목은 제외하고 성공한 1개분만 합산돼야 함")
	assert_eq(result["yields"]["salvage_scrap"], int(expected_yield["material_qty"]))


func test_salvage_invalid_grade_reports_per_item_reason() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var bad_item: Dictionary = _weapon_item(0)
	bad_item["uid"] = "u_bad"
	bad_item["grade"] = "not_a_real_grade"
	var result: Dictionary = Blacksmith.salvage([bad_item], enhance_table, [])
	assert_false(result["ok"])
	assert_eq(result["results"][0]["reason"], "invalid_grade")


# --- 제작(F3-4) ---

func test_craft_success_builds_item_instance_and_reports_consumed() -> void:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints["blueprint_iron_sword"]
	var have: Dictionary = {}
	for mat: Dictionary in bp["materials"]:
		have[String(mat["item_id"])] = int(mat["qty"]) # 정확히 필요한 만큼만 보유.

	var result: Dictionary = Blacksmith.craft(
		"blueprint_iron_sword", blueprints, Data.table("items"), Data.table("affixes"), 3,
		int(bp["cost_gold"]), have, _seeded_rng(0))

	assert_true(result["ok"])
	assert_eq(String(result["item_inst"]["item_id"]), "weapon_uncommon_1")
	assert_eq(result["consumed"]["gold"], int(bp["cost_gold"]))


func test_craft_insufficient_gold_returns_reason_gold() -> void:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints["blueprint_iron_sword"]
	var have: Dictionary = {}
	for mat: Dictionary in bp["materials"]:
		have[String(mat["item_id"])] = int(mat["qty"])
	var result: Dictionary = Blacksmith.craft(
		"blueprint_iron_sword", blueprints, Data.table("items"), Data.table("affixes"), 3, 0, have)
	assert_false(result["ok"])
	assert_eq(result["reason"], "gold")


func test_craft_insufficient_material_returns_reason_material() -> void:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints["blueprint_iron_sword"]
	var result: Dictionary = Blacksmith.craft(
		"blueprint_iron_sword", blueprints, Data.table("items"), Data.table("affixes"), 3,
		int(bp["cost_gold"]), {}) # 재료 전혀 없음.
	assert_false(result["ok"])
	assert_eq(result["reason"], "material")


func test_craft_invalid_blueprint_id_rejected() -> void:
	var result: Dictionary = Blacksmith.craft(
		"blueprint_does_not_exist", Data.table("blueprints"), Data.table("items"), Data.table("affixes"),
		3, 9999, {})
	assert_false(result["ok"])
	assert_eq(result["reason"], "invalid_blueprint")


# --- 미리보기 API(부작용 없음, D-85) ---

func test_get_enhance_preview_matches_table_for_next_level() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var item: Dictionary = _weapon_item(6)
	var preview: Dictionary = Blacksmith.get_enhance_preview(item, enhance_table)
	var cfg: Dictionary = enhance_table["enhance_levels"]["+7"]
	assert_eq(preview["level_next"], 7)
	assert_almost_eq(float(preview["success_rate"]), float(cfg["success_rate"]), 0.0001)
	assert_eq(preview["cost_gold"], int(cfg["cost_gold"]))
	assert_eq(item["enhance_level"], 6, "미리보기는 부작용이 없어야 함")


func test_get_enhance_preview_maxed_at_plus10() -> void:
	var preview: Dictionary = Blacksmith.get_enhance_preview(_weapon_item(10), Data.table("enhance"))
	assert_true(preview["maxed"])
	assert_null(preview["level_next"])


func test_get_refine_cost_reports_attempts_left() -> void:
	var item: Dictionary = _weapon_item(0, [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}], 3)
	var preview: Dictionary = Blacksmith.get_refine_cost(item, Data.table("enhance"))
	assert_eq(preview["attempts_left"], 3)
	assert_true(preview["refinable"])
	assert_eq(item["refine_left"], 3, "미리보기는 부작용이 없어야 함")


func test_get_salvage_preview_sums_multiple_items() -> void:
	var enhance_table: Dictionary = Data.table("enhance")
	var preview: Dictionary = Blacksmith.get_salvage_preview([_weapon_item(0), _weapon_item(0)], enhance_table)
	var per_item: Dictionary = enhance_table["disassemble"]["yield_by_grade"]["uncommon"]
	assert_eq(preview["yields"]["enhance_stone"], int(per_item["stone_qty"]) * 2)


func test_get_craft_preview_reports_need_have_and_can_craft() -> void:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints["blueprint_iron_sword"]
	var preview: Dictionary = Blacksmith.get_craft_preview("blueprint_iron_sword", blueprints, {}, 0)
	assert_false(preview["can_craft"])
	assert_eq(preview["cost_gold"], int(bp["cost_gold"]))
	assert_eq(preview["materials"][0]["have"], 0)
