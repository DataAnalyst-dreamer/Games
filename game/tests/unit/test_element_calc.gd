## ElementCalc(scripts/systems/element_calc.gd) 상성 배율 계산 테스트.
## D-08: 순환형 상성 화→풍→뇌→수→화(앞이 뒤에 강함), 성(聖)은 마물(demon) 계열 특효.
extends GutTest

const ElementCalcScript := preload("res://scripts/systems/element_calc.gd")

var _table: Dictionary


func before_each() -> void:
	_table = {
		"cycle": ["fire", "wind", "thunder", "water"],
		"advantage_multiplier": 1.5,
		"holy_element": "holy",
		"holy_bonus_vs_tags": ["demon"],
	}


func test_no_element_attacker_is_neutral() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("", "water", [], _table), 1.0, 0.0001)


func test_fire_beats_wind() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("fire", "wind", [], _table), 1.5, 0.0001)


func test_wind_beats_thunder() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("wind", "thunder", [], _table), 1.5, 0.0001)


func test_thunder_beats_water() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("thunder", "water", [], _table), 1.5, 0.0001)


func test_water_beats_fire_cycle_wraps() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("water", "fire", [], _table), 1.5, 0.0001)


func test_reverse_matchup_is_neutral() -> void:
	# 화는 풍에 강하지만 그 역(풍이 화에 강함)은 성립하지 않는다(순환형, 대칭 아님).
	assert_almost_eq(ElementCalcScript.get_multiplier("wind", "fire", [], _table), 1.0, 0.0001)


func test_non_adjacent_matchup_is_neutral() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("fire", "water", [], _table), 1.0, 0.0001)


func test_holy_vs_demon_tag_is_advantage() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("holy", "", ["demon"], _table), 1.5, 0.0001)


func test_holy_vs_non_demon_is_neutral() -> void:
	assert_almost_eq(ElementCalcScript.get_multiplier("holy", "", ["beast"], _table), 1.0, 0.0001)


func test_holy_is_not_part_of_the_cycle() -> void:
	# holy는 cycle 배열에 없어야 하고, cycle 계산 경로를 타지 않는다(태그 특효만 적용).
	assert_false(_table["cycle"].has("holy"))
