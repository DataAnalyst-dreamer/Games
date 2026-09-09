## InventoryUiCalc(scripts/ui/inventory_ui_calc.gd) 테스트 — 등급 필터, 비교 툴팁
## 델타 계산, 증감 표시 포맷(F7-2, M2-2). 순수 RefCounted라 Node 없이 직접 테스트한다.
extends GutTest

const UiCalcScript := preload("res://scripts/ui/inventory_ui_calc.gd")

const WEAPON_DEF := {"category": "weapon", "base_stats": {"atk_min": 10.0, "atk_max": 14.0}}
const ARMOR_DEF := {"category": "armor", "base_stats": {"defense_min": 4.0, "defense_max": 6.0}}
const RING_DEF := {"category": "ring", "base_stats": {}}

const ENHANCE_TABLE := {
	"enhance_levels": {
		"+1": {"stat_multiplier": 1.1},
	},
}


func _slots(entries: Array) -> Array:
	var out: Array = []
	for e: Dictionary in entries:
		out.append(e)
	return out


# --- filter_indices ---

func test_filter_indices_all_returns_every_index() -> void:
	var slots := [{"grade": "common"}, {"grade": "rare"}]
	assert_eq(UiCalcScript.filter_indices(slots, ""), [0, 1])
	assert_eq(UiCalcScript.filter_indices(slots, "all"), [0, 1])


func test_filter_indices_matches_only_given_grade() -> void:
	var slots := [{"grade": "common"}, {"grade": "rare"}, {"grade": "rare"}]
	assert_eq(UiCalcScript.filter_indices(slots, "rare"), [1, 2])


func test_filter_indices_no_match_returns_empty() -> void:
	var slots := [{"grade": "common"}]
	assert_eq(UiCalcScript.filter_indices(slots, "legendary"), [])


# --- base_stat_key / base_stat_value ---

func test_base_stat_key_by_category() -> void:
	assert_eq(UiCalcScript.base_stat_key("weapon"), "attack")
	assert_eq(UiCalcScript.base_stat_key("armor"), "defense")
	assert_eq(UiCalcScript.base_stat_key("boots"), "defense")
	assert_eq(UiCalcScript.base_stat_key("ring"), "")
	assert_eq(UiCalcScript.base_stat_key("material"), "")


func test_base_stat_value_weapon_averages_min_max() -> void:
	var v: float = UiCalcScript.base_stat_value(WEAPON_DEF, 0, {})
	assert_eq(v, 12.0)


func test_base_stat_value_applies_enhance_multiplier() -> void:
	var v: float = UiCalcScript.base_stat_value(WEAPON_DEF, 1, ENHANCE_TABLE)
	assert_almost_eq(v, 13.2, 0.001)


func test_base_stat_value_empty_def_is_zero() -> void:
	assert_eq(UiCalcScript.base_stat_value({}, 0, {}), 0.0)


# --- affix_totals ---

func test_affix_totals_sums_by_stat_type() -> void:
	var affixes := [
		{"affix_id": "a", "stat_type": "atk_pct", "value": 0.05},
		{"affix_id": "b", "stat_type": "crit_chance", "value": 0.03},
	]
	var totals := UiCalcScript.affix_totals(affixes)
	assert_almost_eq(float(totals["atk_pct"]), 0.05, 0.0001)
	assert_almost_eq(float(totals["crit_chance"]), 0.03, 0.0001)


func test_affix_totals_empty_array() -> void:
	assert_eq(UiCalcScript.affix_totals([]), {})


# --- compare_rows ---

func test_compare_rows_weapon_upgrade_shows_positive_delta() -> void:
	var candidate := {"enhance_level": 0, "affixes": []}
	var equipped := {"enhance_level": 0, "affixes": []}
	var weaker_equipped_def := {"category": "weapon", "base_stats": {"atk_min": 4.0, "atk_max": 6.0}}
	var rows := UiCalcScript.compare_rows(candidate, WEAPON_DEF, equipped, weaker_equipped_def, {})
	assert_eq(rows.size(), 1)
	assert_eq(String(rows[0]["stat_key"]), "attack")
	assert_almost_eq(float(rows[0]["candidate_value"]), 12.0, 0.001)
	assert_almost_eq(float(rows[0]["equipped_value"]), 5.0, 0.001)
	assert_almost_eq(float(rows[0]["delta"]), 7.0, 0.001)


func test_compare_rows_no_equipped_item_deltas_from_zero() -> void:
	var candidate := {"enhance_level": 0, "affixes": []}
	var rows := UiCalcScript.compare_rows(candidate, WEAPON_DEF, {}, {}, {})
	assert_eq(rows.size(), 1)
	assert_almost_eq(float(rows[0]["equipped_value"]), 0.0, 0.001)
	assert_almost_eq(float(rows[0]["delta"]), 12.0, 0.001)


func test_compare_rows_non_equip_category_has_no_base_stat_row() -> void:
	var candidate := {"enhance_level": 0, "affixes": []}
	var rows := UiCalcScript.compare_rows(candidate, RING_DEF, {}, {}, {})
	assert_eq(rows.size(), 0)


func test_compare_rows_includes_affix_rows_sorted_and_flags_new() -> void:
	var candidate := {
		"enhance_level": 0,
		"affixes": [
			{"affix_id": "a", "stat_type": "crit_chance", "value": 0.05},
			{"affix_id": "b", "stat_type": "atk_pct", "value": 0.08},
		],
	}
	var equipped := {
		"enhance_level": 0,
		"affixes": [{"affix_id": "c", "stat_type": "atk_pct", "value": 0.03}],
	}
	var rows := UiCalcScript.compare_rows(candidate, WEAPON_DEF, equipped, WEAPON_DEF, {})
	# rows[0] = 본체(attack), rows[1..] = affix stat_type 알파벳 순(atk_pct < crit_chance).
	assert_eq(rows.size(), 3)
	assert_eq(String(rows[1]["stat_key"]), "atk_pct")
	assert_almost_eq(float(rows[1]["delta"]), 0.05, 0.0001) # 0.08 - 0.03
	assert_false(bool(rows[1]["is_new"]))
	assert_eq(String(rows[2]["stat_key"]), "crit_chance")
	assert_true(bool(rows[2]["is_new"])) # 장착품엔 없던 옵션


# --- format_delta ---

func test_format_delta_positive_normal_mode() -> void:
	var r := UiCalcScript.format_delta(12.0, false)
	assert_eq(String(r["text"]), "▲12")
	assert_eq(String(r["color_token"]), "positive")


func test_format_delta_negative_normal_mode() -> void:
	var r := UiCalcScript.format_delta(-7.0, false)
	assert_eq(String(r["text"]), "▼7")
	assert_eq(String(r["color_token"]), "negative")


func test_format_delta_zero_is_neutral() -> void:
	var r := UiCalcScript.format_delta(0.0, false)
	assert_eq(String(r["text"]), "–0")
	assert_eq(String(r["color_token"]), "neutral")


func test_format_delta_colorblind_mode_adds_sign() -> void:
	var pos := UiCalcScript.format_delta(12.0, true)
	assert_eq(String(pos["text"]), "▲+12")
	var neg := UiCalcScript.format_delta(-7.0, true)
	assert_eq(String(neg["text"]), "▼-7")
	# 중립(0)은 색약 모드라도 부호를 붙이지 않는다(더할 부호가 없음).
	var zero := UiCalcScript.format_delta(0.0, true)
	assert_eq(String(zero["text"]), "–0")
