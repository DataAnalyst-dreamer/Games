## StatsUiCalc(scripts/ui/stats_ui_calc.gd) 테스트(M4-5 v2) — 6스탯 파생치 미리보기,
## 다음 포인트 비용, derived 표시 서식. 순수 RefCounted라 Node 없이 직접 테스트한다
## (test_inventory_ui_calc.gd와 같은 관례). 계수는 실제 stats.json 값을 그대로 썼다.
extends GutTest

const StatsUiCalcScript := preload("res://scripts/ui/stats_ui_calc.gd")

const STATS_TABLE := {
	"allocation": {"initial": {"str": 0, "agi": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0}},
	"str": {"physical_damage_per_point": 0.2},
	"agi": {"aspd_frame_mult_per_point": 0.0028},
	"dex": {"hit_hitbox_scale_per_point": 0.0015},
	"int": {
		"magic_damage_per_point": 0.15, "mdef_per_point": 0.5,
		"max_sp_per_point": 2.0, "sp_regen_per_point": 0.03,
	},
	"vit": {"hp_per_point": 5.0, "defense_per_point": 1.0, "mdef_per_point": 0.5},
	"luk": {"crit_chance_per_point": 0.001},
}


func test_str_preview_only_atk() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("str", STATS_TABLE), {"atk": 0.2})


func test_vit_preview_hp_def_mdef() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("vit", STATS_TABLE),
		{"max_hp": 5.0, "def": 1.0, "mdef": 0.5})


func test_int_preview_matk_mdef_sp() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("int", STATS_TABLE),
		{"matk": 0.15, "mdef": 0.5, "max_sp": 2.0, "sp_regen": 0.03})


func test_luk_preview_crit_chance() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("luk", STATS_TABLE), {"crit_chance": 0.001})


func test_agi_and_dex_have_no_linear_preview() -> void:
	# 상한(cap) 있는 비선형 배율이라 숫자 미리보기 대상이 아니다(ui.stat.effect.* 텍스트로 대신함).
	assert_eq(StatsUiCalcScript.preview_derived_delta("agi", STATS_TABLE), {})
	assert_eq(StatsUiCalcScript.preview_derived_delta("dex", STATS_TABLE), {})


func test_unknown_stat_key_has_no_preview() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("unknown", STATS_TABLE), {})


func test_default_stats_reads_allocation_initial_6_keys() -> void:
	var stats: Dictionary = StatsUiCalcScript.default_stats(STATS_TABLE)
	assert_eq(stats, {"str": 0, "agi": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0})


func test_default_stats_missing_allocation_falls_back_to_zero() -> void:
	assert_eq(StatsUiCalcScript.default_stats({}), {"str": 0, "agi": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0})


## D-184 확정 공식: cost(n->n+1) = floor(n/10)+1.
func test_next_point_cost_bracket() -> void:
	assert_eq(StatsUiCalcScript.next_point_cost(0), 1)
	assert_eq(StatsUiCalcScript.next_point_cost(9), 1)
	assert_eq(StatsUiCalcScript.next_point_cost(10), 2)
	assert_eq(StatsUiCalcScript.next_point_cost(49), 5)
	assert_eq(StatsUiCalcScript.next_point_cost(58), 6)


# --- D-195: derived 표시 서식(원시값 덤프 금지, 눈에 보이는 효과로) ---

func test_format_derived_value_int_keys() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("max_hp", 130.0), "130")
	assert_eq(StatsUiCalcScript.format_derived_value("max_sp", 84.0), "84")


func test_format_derived_value_crit_chance_is_percent() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("crit_chance", 0.053), "5.3%")


func test_format_derived_value_hit_scale_and_move_speed_are_total_up_percent() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("hit_scale", 1.075), "+7.5%")
	assert_eq(StatsUiCalcScript.format_derived_value("move_speed_mult", 1.075), "+7.5%")


func test_format_derived_value_combo_frame_mult_is_speedup_percent() -> void:
	# 스펙 worked example: AGI 50 -> combo_frame_mult=0.86 -> "14% 빨라짐".
	assert_eq(StatsUiCalcScript.format_derived_value("combo_frame_mult", 0.86), "+14.0%")


func test_format_derived_value_post_recovery_mult_is_negative_percent() -> void:
	# 스펙 worked example: DEX 50 -> post_attack_recovery_mult=0.925 -> "7.5%↓".
	assert_eq(StatsUiCalcScript.format_derived_value("post_recovery_mult", 0.925), "-7.5%")


func test_format_derived_value_flee_iframe_bonus_is_seconds() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("flee_iframe_bonus", 0.05), "+0.05s")


func test_format_derived_value_sp_regen() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("sp_regen", 2.74), "2.74/s")


func test_format_derived_value_raw_1dp_keys() -> void:
	assert_eq(StatsUiCalcScript.format_derived_value("atk", 33.6), "33.6")
	assert_eq(StatsUiCalcScript.format_derived_value("def", 58.0), "58.0")
