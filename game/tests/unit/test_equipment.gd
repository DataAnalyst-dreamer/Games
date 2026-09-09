## Equipment(scripts/systems/equipment.gd) 테스트 — 8슬롯, 카테고리 불일치 거부,
## 동일 반지 중복 장착(D-12), 장착 스탯 재계산(base_stats+affix+강화 배율).
extends GutTest

const EquipmentScript := preload("res://scripts/systems/equipment.gd")

const WEAPON_DEF := {"category": "weapon", "base_stats": {"atk_min": 12, "atk_max": 16}}
const RING_DEF := {"category": "ring", "base_stats": {"str": 4}}
const ARMOR_DEF := {"category": "armor", "base_stats": {"defense_min": 5, "defense_max": 7}}

const ENHANCE_TABLE := {
	"enhance_levels": {
		"+1": {"stat_multiplier": 1.08},
		"+3": {"stat_multiplier": 1.24},
	},
}


func _item(item_id: String, grade: String, enhance_level: int = 0, affixes: Array = []) -> Dictionary:
	return {
		"uid": "u_%s" % item_id, "item_id": item_id, "grade": grade, "quantity": 1,
		"affixes": affixes, "enhance_level": enhance_level, "refine_left": 0,
	}


func test_all_eight_slots_start_empty() -> void:
	var eq: Equipment = EquipmentScript.new()
	assert_eq(Equipment.SLOT_NAMES.size(), 8)
	for slot_name: String in Equipment.SLOT_NAMES:
		assert_false(eq.is_equipped(slot_name))


func test_equip_wrong_category_rejected() -> void:
	var eq: Equipment = EquipmentScript.new()
	var result: Dictionary = eq.equip("weapon", _item("ring_common_1", "common"), RING_DEF)
	assert_true(result.has("__error__"))
	assert_false(eq.is_equipped("weapon"))


func test_equip_returns_previous_item() -> void:
	var eq: Equipment = EquipmentScript.new()
	eq.equip("weapon", _item("weapon_common_1", "common"), WEAPON_DEF)
	var previous: Dictionary = eq.equip("weapon", _item("weapon_rare_1", "rare"), WEAPON_DEF)
	assert_eq(String(previous.get("item_id")), "weapon_common_1")
	assert_eq(String(eq.slots["weapon"].get("item_id")), "weapon_rare_1")


func test_unequip_returns_item_and_clears_slot() -> void:
	var eq: Equipment = EquipmentScript.new()
	eq.equip("weapon", _item("weapon_common_1", "common"), WEAPON_DEF)
	var removed: Dictionary = eq.unequip("weapon")
	assert_eq(String(removed.get("item_id")), "weapon_common_1")
	assert_false(eq.is_equipped("weapon"))


func test_duplicate_ring_allowed_in_both_ring_slots() -> void:
	# D-12: 동일 반지 2개 중복 장착 허용.
	var eq: Equipment = EquipmentScript.new()
	var r1: Dictionary = eq.equip("ring1", _item("ring_common_1", "common"), RING_DEF)
	var r2: Dictionary = eq.equip("ring2", _item("ring_common_1", "common"), RING_DEF)
	assert_false(r1.has("__error__"))
	assert_false(r2.has("__error__"))
	assert_true(eq.is_equipped("ring1"))
	assert_true(eq.is_equipped("ring2"))
	assert_eq(String(eq.slots["ring1"].get("item_id")), String(eq.slots["ring2"].get("item_id")))


func test_compute_stats_weapon_attack_averages_min_max() -> void:
	var equipped := {"weapon": _item("weapon_rare_1", "rare")}
	var stats: Dictionary = Equipment.compute_stats(equipped, {"weapon_rare_1": WEAPON_DEF}, {})
	assert_almost_eq(float(stats["attack"]), 14.0, 0.001) # (12+16)/2


func test_compute_stats_applies_enhance_multiplier() -> void:
	var equipped := {"weapon": _item("weapon_rare_1", "rare", 3)} # +3 -> x1.24
	var stats: Dictionary = Equipment.compute_stats(equipped, {"weapon_rare_1": WEAPON_DEF}, ENHANCE_TABLE)
	assert_almost_eq(float(stats["attack"]), 14.0 * 1.24, 0.001)


func test_compute_stats_sums_affixes_by_stat_type() -> void:
	var affixes: Array = [
		{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 0.10},
		{"affix_id": "max_hp_flat", "stat_type": "max_hp_flat", "value": 15.0},
	]
	var equipped := {"weapon": _item("weapon_rare_1", "rare", 0, affixes)}
	var stats: Dictionary = Equipment.compute_stats(equipped, {"weapon_rare_1": WEAPON_DEF}, {})
	assert_almost_eq(float(stats["attack"]), 14.0 * 1.10, 0.001)
	assert_eq(int(stats["max_hp"]), 15)


func test_compute_stats_sums_defense_from_armor_and_defense_flat_affix() -> void:
	var affixes: Array = [{"affix_id": "defense_flat", "stat_type": "defense_flat", "value": 4.0}]
	var equipped := {"armor": _item("armor_uncommon_1", "uncommon", 0, affixes)}
	var stats: Dictionary = Equipment.compute_stats(equipped, {"armor_uncommon_1": ARMOR_DEF}, {})
	assert_almost_eq(float(stats["defense"]), 6.0 + 4.0, 0.001) # (5+7)/2 + 4


func test_compute_stats_empty_equipment_is_all_zero() -> void:
	var eq: Equipment = EquipmentScript.new()
	var stats: Dictionary = Equipment.compute_stats(eq.slots, {}, {})
	assert_almost_eq(float(stats["attack"]), 0.0, 0.001)
	assert_almost_eq(float(stats["defense"]), 0.0, 0.001)
	assert_eq(int(stats["max_hp"]), 0)
	assert_almost_eq(float(stats["speed_pct"]), 0.0, 0.001)


func test_to_dict_from_dict_round_trip() -> void:
	var eq: Equipment = EquipmentScript.new()
	eq.equip("weapon", _item("weapon_common_1", "common"), WEAPON_DEF)
	var dict: Dictionary = eq.to_dict()

	var restored: Equipment = EquipmentScript.new()
	restored.from_dict(dict)
	assert_eq(String(restored.slots["weapon"].get("item_id")), "weapon_common_1")
	assert_true(restored.slots["ring1"].is_empty())
