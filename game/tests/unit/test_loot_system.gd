## LootSystem(scripts/systems/loot_system.gd) 테스트 — 등급 판정 LUK 곱연산(D-52),
## 옵션 개수 규칙(F3-1), affix 중복 금지, 실데이터 통합(roll_drop/roll_gold).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const LUK_COEFFICIENT := {
	"uncommon": 0.004, "rare": 0.010, "epic": 0.020, "legendary": 0.035, "relic": 0.050,
}

## docs/specs/items-and-drops-m2.md §4 워크드 예시(elite_goblin_captain 실측값).
const WORKED_EXAMPLE_WEIGHT := {"common": 0.15, "uncommon": 0.45, "rare": 0.40}


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- LUK 곱연산 공식 ---

func test_luck_multiplier_common_is_always_one() -> void:
	assert_almost_eq(LootSystem.luck_multiplier("common", 0.0, LUK_COEFFICIENT), 1.0, 0.0001)
	assert_almost_eq(LootSystem.luck_multiplier("common", 999.0, LUK_COEFFICIENT), 1.0, 0.0001)


func test_luck_multiplier_increases_with_luk() -> void:
	# 1.0 + LUK * coefficient
	assert_almost_eq(LootSystem.luck_multiplier("rare", 20.0, LUK_COEFFICIENT), 1.20, 0.0001)
	assert_almost_eq(LootSystem.luck_multiplier("uncommon", 20.0, LUK_COEFFICIENT), 1.08, 0.0001)


func test_final_probabilities_sum_to_one() -> void:
	var probs: Dictionary = LootSystem.compute_final_probabilities(WORKED_EXAMPLE_WEIGHT, 20.0, LUK_COEFFICIENT)
	var total := 0.0
	for g: String in probs:
		total += probs[g]
	assert_almost_eq(total, 1.0, 0.0001)


func test_worked_example_matches_doc_luk_0() -> void:
	var probs: Dictionary = LootSystem.compute_final_probabilities(WORKED_EXAMPLE_WEIGHT, 0.0, LUK_COEFFICIENT)
	assert_almost_eq(probs["common"], 0.15, 0.0001)
	assert_almost_eq(probs["uncommon"], 0.45, 0.0001)
	assert_almost_eq(probs["rare"], 0.40, 0.0001)


func test_worked_example_matches_doc_luk_20() -> void:
	# docs/specs/items-and-drops-m2.md §4: LUK=20 -> common 13.44% / uncommon 43.55% / rare 43.01%.
	var probs: Dictionary = LootSystem.compute_final_probabilities(WORKED_EXAMPLE_WEIGHT, 20.0, LUK_COEFFICIENT)
	assert_almost_eq(probs["common"], 0.1344, 0.001)
	assert_almost_eq(probs["uncommon"], 0.4355, 0.001)
	assert_almost_eq(probs["rare"], 0.4301, 0.001)


func test_epic_zero_weight_never_selected() -> void:
	var weight := {"common": 0.75, "uncommon": 0.25, "rare": 0.0, "epic": 0.0, "legendary": 0.0, "relic": 0.0}
	var probs: Dictionary = LootSystem.compute_final_probabilities(weight, 50.0, LUK_COEFFICIENT)
	var rng := _seeded_rng(12345)
	for _i in 1000:
		var grade: String = LootSystem.pick_grade(rng, probs)
		assert_true(grade == "common" or grade == "uncommon",
			"epic+ 잠금(grade_base_weight=0)인 등급은 LUK을 아무리 올려도 뽑히면 안 된다 (뽑힘: %s)" % grade)


## 시드 고정 10,000회 등급 판정 분포 — grade_base_weight(가중치) 대비 ±2%p 이내.
func test_grade_distribution_matches_weights_within_2_percent() -> void:
	var probs: Dictionary = LootSystem.compute_final_probabilities(WORKED_EXAMPLE_WEIGHT, 20.0, LUK_COEFFICIENT)
	var rng := _seeded_rng(20260908)
	var counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}
	const N := 10000
	for _i in N:
		var grade: String = LootSystem.pick_grade(rng, probs)
		counts[grade] = int(counts.get(grade, 0)) + 1
	for grade2: String in probs:
		var observed: float = float(counts.get(grade2, 0)) / float(N)
		var expected: float = probs[grade2]
		assert_almost_eq(observed, expected, 0.02,
			"등급 %s 관측 확률(%.4f)이 기대값(%.4f)과 ±2%%p 이상 벗어남" % [grade2, observed, expected])


# --- 가중 랜덤 추첨 ---

func test_pick_weighted_only_positive_weight_key_selected() -> void:
	var rng := _seeded_rng(1)
	for _i in 200:
		assert_eq(LootSystem.pick_weighted(rng, {"a": 0.0, "b": 1.0, "c": 0.0}), "b")


func test_pick_entry_filters_by_grade_then_weight() -> void:
	var items_table := {
		"mat_common": {"grade": "common"},
		"ring_common": {"grade": "common"},
		"ring_uncommon": {"grade": "uncommon"},
	}
	var entries: Array = [
		{"item_id": "mat_common", "weight": 50},
		{"item_id": "ring_common", "weight": 8},
		{"item_id": "ring_uncommon", "weight": 10},
	]
	var common_candidates: Array = LootSystem.filter_entries_by_grade(entries, "common", items_table)
	assert_eq(common_candidates.size(), 2)
	var uncommon_candidates: Array = LootSystem.filter_entries_by_grade(entries, "uncommon", items_table)
	assert_eq(uncommon_candidates.size(), 1)
	assert_eq(String((uncommon_candidates[0] as Dictionary).get("item_id")), "ring_uncommon")


# --- 옵션(affix) 추첨: 개수 규칙 + 중복 금지 ---

func _make_affixes_table() -> Dictionary:
	return {
		"atk_pct": {"affix_id": "atk_pct", "stat_type": "atk_pct", "value_min": 0.03, "value_max": 0.08,
			"applicable_categories": ["weapon"], "weight": 10},
		"crit_chance": {"affix_id": "crit_chance", "stat_type": "crit_chance", "value_min": 0.02, "value_max": 0.05,
			"applicable_categories": ["weapon"], "weight": 8},
		"life_steal_pct": {"affix_id": "life_steal_pct", "stat_type": "life_steal_pct", "value_min": 0.01, "value_max": 0.03,
			"applicable_categories": ["weapon"], "weight": 4},
		"defense_flat": {"affix_id": "defense_flat", "stat_type": "defense_flat", "value_min": 2, "value_max": 6,
			"applicable_categories": ["armor"], "weight": 9},
	}


func test_roll_affixes_count_matches_slot_count() -> void:
	var rng := _seeded_rng(7)
	var affixes: Array = LootSystem.roll_affixes(rng, "weapon", _make_affixes_table(), 2)
	assert_eq(affixes.size(), 2)


func test_roll_affixes_zero_count_for_common() -> void:
	var rng := _seeded_rng(7)
	assert_eq(LootSystem.roll_affixes(rng, "weapon", _make_affixes_table(), 0).size(), 0)


func test_roll_affixes_never_duplicates() -> void:
	var rng := _seeded_rng(99)
	for _i in 500:
		var affixes: Array = LootSystem.roll_affixes(rng, "weapon", _make_affixes_table(), 2)
		var seen: Dictionary = {}
		for affix: Dictionary in affixes:
			var affix_id: String = String(affix.get("affix_id"))
			assert_false(seen.has(affix_id), "같은 옵션(%s)이 한 아이템에 중복으로 뽑힘" % affix_id)
			seen[affix_id] = true


func test_roll_affixes_only_applicable_category() -> void:
	var rng := _seeded_rng(3)
	var affixes: Array = LootSystem.roll_affixes(rng, "armor", _make_affixes_table(), 1)
	assert_eq(affixes.size(), 1)
	assert_eq(String(affixes[0].get("affix_id")), "defense_flat")


func test_roll_affixes_value_within_range() -> void:
	var rng := _seeded_rng(55)
	for _i in 100:
		var affixes: Array = LootSystem.roll_affixes(rng, "weapon", _make_affixes_table(), 1)
		var affix: Dictionary = affixes[0]
		var table_entry: Dictionary = _make_affixes_table()[affix.get("affix_id")]
		assert_between(float(affix.get("value")), float(table_entry["value_min"]), float(table_entry["value_max"]))


# --- ItemInstance 생성 ---

func test_make_item_instance_refine_left_zero_for_common_no_slots() -> void:
	var rng := _seeded_rng(1)
	var item_def := {"grade": "common", "category": "weapon", "affix_slot_count": 0}
	var instance: Dictionary = LootSystem.make_item_instance("weapon_common_1", item_def, _make_affixes_table(), 3, 1, rng)
	assert_eq(instance["refine_left"], 0)
	assert_eq((instance["affixes"] as Array).size(), 0)
	assert_eq(instance["enhance_level"], 0)
	assert_eq(instance["quantity"], 1)


func test_make_item_instance_refine_left_matches_max_attempts_for_equipped_with_slots() -> void:
	var rng := _seeded_rng(1)
	var item_def := {"grade": "rare", "category": "weapon", "affix_slot_count": 2}
	var instance: Dictionary = LootSystem.make_item_instance("weapon_rare_1", item_def, _make_affixes_table(), 3, 1, rng)
	assert_eq(instance["refine_left"], 3)
	assert_eq((instance["affixes"] as Array).size(), 2)


func test_make_item_instance_material_quantity_and_no_affixes() -> void:
	var rng := _seeded_rng(1)
	var item_def := {"grade": "common", "category": "material", "affix_slot_count": 0}
	var instance: Dictionary = LootSystem.make_item_instance("iron_ore", item_def, _make_affixes_table(), 3, 4, rng)
	assert_eq(instance["quantity"], 4)
	assert_eq((instance["affixes"] as Array).size(), 0)


func test_make_item_instance_uid_unique_across_calls() -> void:
	var rng := _seeded_rng(1)
	var item_def := {"grade": "common", "category": "material", "affix_slot_count": 0}
	var a: Dictionary = LootSystem.make_item_instance("iron_ore", item_def, {}, 0, 1, rng)
	var b: Dictionary = LootSystem.make_item_instance("iron_ore", item_def, {}, 0, 1, rng)
	assert_ne(String(a["uid"]), String(b["uid"]))


# --- 실데이터 통합: roll_drop()/roll_gold() (Data 오토로드, 실제 game/data/*.json) ---

func test_roll_drop_slime_common_returns_item_from_correct_grade_pool() -> void:
	var rng := _seeded_rng(2026)
	var drops: Array = LootSystem.roll_drop(&"slime_common", 0.0, rng)
	assert_eq(drops.size(), 1)
	var item: Dictionary = drops[0]
	var item_def: Dictionary = Data.get_value("items", String(item["item_id"]), {})
	assert_eq(String(item["grade"]), String(item_def.get("grade")),
		"드랍된 아이템의 등급은 items.json에 정의된 등급과 같아야 한다")


func test_roll_drop_unknown_source_returns_empty() -> void:
	var rng := _seeded_rng(1)
	assert_eq(LootSystem.roll_drop(&"no_such_source", 0.0, rng).size(), 0)


func test_roll_gold_within_configured_range() -> void:
	var rng := _seeded_rng(3)
	for _i in 200:
		var gold: int = LootSystem.roll_gold(&"slime_common", rng)
		assert_between(gold, 2, 5) # game/data/drop_tables.json slime_common.gold_drop


func test_roll_gold_unknown_source_returns_zero() -> void:
	assert_eq(LootSystem.roll_gold(&"no_such_source", _seeded_rng(1)), 0)
