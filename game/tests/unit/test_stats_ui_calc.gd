## StatsUiCalc(scripts/ui/stats_ui_calc.gd) 테스트(M3-4) — 스탯 파생치 미리보기,
## 기본 스탯값. 순수 RefCounted라 Node 없이 직접 테스트한다(test_inventory_ui_calc.gd와
## 같은 관례). 실제 game/data/stats.json 계수를 그대로 써서(D-158 allocation.initial
## 포함) 회귀를 잡는다.
extends GutTest

const StatsUiCalcScript := preload("res://scripts/ui/stats_ui_calc.gd")

const STATS_TABLE := {
	"allocation": {"initial": {"str": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0}},
	"str": {"physical_damage_per_point": 0.2},
	"dex": {"attack_speed_per_point": 0.0015},
	"int": {"cooldown_reduction_per_point": 0.002},
	"vit": {"hp_per_point": 5.0, "defense_per_point": 1.0},
	"luk": {"crit_chance_per_point": 0.001},
}


func test_str_preview_only_attack() -> void:
	var delta: Dictionary = StatsUiCalcScript.preview_derived_delta("str", STATS_TABLE)
	assert_eq(delta, {"attack": 0.2})


func test_vit_preview_hp_and_defense() -> void:
	var delta: Dictionary = StatsUiCalcScript.preview_derived_delta("vit", STATS_TABLE)
	assert_eq(delta, {"max_hp": 5.0, "defense": 1.0})


func test_luk_preview_crit_chance() -> void:
	var delta: Dictionary = StatsUiCalcScript.preview_derived_delta("luk", STATS_TABLE)
	assert_eq(delta, {"crit_chance": 0.001})


func test_dex_and_int_have_no_preview_in_scope() -> void:
	# GDD 5.2의 DEX 공속/INT 쿨감은 이번 4개(공격/HP/방어/크리) 미리보기 범위 밖(§1 참고).
	assert_eq(StatsUiCalcScript.preview_derived_delta("dex", STATS_TABLE), {})
	assert_eq(StatsUiCalcScript.preview_derived_delta("int", STATS_TABLE), {})


func test_unknown_stat_key_has_no_preview() -> void:
	assert_eq(StatsUiCalcScript.preview_derived_delta("unknown", STATS_TABLE), {})


func test_default_stats_reads_allocation_initial() -> void:
	var stats: Dictionary = StatsUiCalcScript.default_stats(STATS_TABLE)
	assert_eq(stats, {"str": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0})


func test_default_stats_missing_allocation_falls_back_to_zero() -> void:
	var stats: Dictionary = StatsUiCalcScript.default_stats({})
	assert_eq(stats, {"str": 0, "dex": 0, "int": 0, "vit": 0, "luk": 0})
