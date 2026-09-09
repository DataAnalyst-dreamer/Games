## monsters.json / elements.json 스키마 검증 테스트 (data_tables.md §6, §12).
## D-49: 몬스터 방어력 필드는 M2에서 도입 — 이 테스트는 hp/atk/속도/예고 시간만 확인한다.
extends GutTest

const DataScript := preload("res://scripts/core/data.gd")

var _data: Node


func before_each() -> void:
	_data = DataScript.new()
	add_child_autofree(_data)


func test_elements_table_loads_without_errors() -> void:
	assert_true(_data.tables.has("elements"), "elements.json 이 로드되어야 한다")
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])


func test_elements_cycle_matches_d08() -> void:
	var cycle: Array = _data.get_value("elements", "cycle")
	assert_eq(cycle, ["fire", "wind", "thunder", "water"], "D-08 순환형 상성 순서")
	assert_eq(cycle.size(), 4)


func test_elements_holy_bonus_targets_demon() -> void:
	assert_eq(_data.get_value("elements", "holy_element"), "holy")
	var tags: Array = _data.get_value("elements", "holy_bonus_vs_tags")
	assert_true(tags.has("demon"), "D-08: 성속성은 마물 계열 특효")


func test_elements_advantage_multiplier_is_1_5() -> void:
	assert_almost_eq(float(_data.get_value("elements", "advantage_multiplier")), 1.5, 0.0001)


func test_combat_json_no_longer_has_elements_subobject() -> void:
	# D-50: elements.json이 단일 소스이며 combat.json.elements는 M1-1에서 제거됐다.
	assert_false(_data.has_value("combat", "elements.cycle"),
		"D-50: combat.json.elements는 제거되고 elements.json이 단일 소스여야 한다")


func test_combat_json_no_longer_has_roll_speed_px() -> void:
	# D-43: roll_speed_px 삭제, 거리+시간 단일 소스.
	assert_false(_data.has_value("combat", "movement.roll_speed_px"),
		"D-43: movement.roll_speed_px는 폐기되어야 한다")


func test_stamina_exhausted_penalty_matches_d44() -> void:
	assert_almost_eq(float(_data.get_value("combat", "stamina.exhausted_penalty_sec")), 1.0, 0.0001,
		"D-44: 1.5 → 1.0 하향 확정")


func test_combat_json_new_keys_from_d48() -> void:
	for key_path: String in [
		"combo.finisher_recovery_sec",
		"guard.just_guard_enemy_stagger_sec",
		"hitstop.normal_sec",
		"hitstop.heavy_crit_sec",
		"knockback.normal_px",
		"knockback.heavy_px",
	]:
		assert_true(_data.has_value("combat", key_path), "D-48 신규 키 존재: %s" % key_path)


func test_monsters_table_loads_without_errors() -> void:
	assert_true(_data.tables.has("monsters"), "monsters.json 이 로드되어야 한다")
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])


func test_all_m1_monsters_present() -> void:
	for monster_id: String in ["slime", "horn_rabbit", "mushroom"]:
		assert_true(_data.get_value("monsters", monster_id, {}).size() > 0, "%s 데이터 존재" % monster_id)


func test_monster_required_fields_present() -> void:
	for monster_id: String in ["slime", "horn_rabbit", "mushroom"]:
		var entry: Dictionary = _data.get_value("monsters", monster_id, {})
		for field: String in DataScript.MONSTER_REQUIRED_FIELDS:
			assert_true(entry.has(field), "%s.%s 필수 필드 존재" % [monster_id, field])


func test_monster_telegraph_at_least_half_second() -> void:
	# GDD 4.2 강제 규칙: 공격 예고 최소 0.5초.
	for monster_id: String in ["slime", "horn_rabbit", "mushroom"]:
		var entry: Dictionary = _data.get_value("monsters", monster_id, {})
		assert_gte(float(entry.get("telegraph_sec", 0.0)), 0.5, "%s telegraph_sec >= 0.5" % monster_id)


func test_slime_stats_match_combat_tuning_m1_spec() -> void:
	var slime: Dictionary = _data.get_value("monsters", "slime", {})
	assert_eq(int(slime.get("hp")), 18, "combat-tuning-m1.md §8-2")
	assert_eq(int(slime.get("atk")), 8, "combat-tuning-m1.md §8-3")
	assert_almost_eq(float(slime.get("move_speed_px")), 40.0, 0.0001, "combat-tuning-m1.md §8-4")
	assert_almost_eq(float(slime.get("telegraph_sec")), 0.5, 0.0001, "combat-tuning-m1.md §8-4")


func test_ai_common_fields_present_and_positive() -> void:
	# addendum §4-3 확정: AI 공통 5필드가 3종 전부에 존재하고 양수(patrol_radius_px는 0 허용).
	for monster_id: String in ["slime", "horn_rabbit", "mushroom"]:
		var entry: Dictionary = _data.get_value("monsters", monster_id, {})
		assert_gt(float(entry.get("aggro_range_px", 0.0)), 0.0, "%s aggro_range_px > 0" % monster_id)
		assert_gt(float(entry.get("melee_range_px", 0.0)), 0.0, "%s melee_range_px > 0" % monster_id)
		assert_gt(float(entry.get("attack_recovery_sec", 0.0)), 0.0, "%s attack_recovery_sec > 0" % monster_id)
		assert_gte(float(entry.get("patrol_radius_px", -1.0)), 0.0, "%s patrol_radius_px >= 0" % monster_id)
		assert_gt(float(entry.get("leash_range_px", 0.0)), 0.0, "%s leash_range_px > 0" % monster_id)


func test_ai_field_invariant_leash_gt_aggro_gt_melee() -> void:
	# data_tables.md §12 검증 규칙 4.
	for monster_id: String in ["slime", "horn_rabbit", "mushroom"]:
		var entry: Dictionary = _data.get_value("monsters", monster_id, {})
		var leash: float = float(entry.get("leash_range_px"))
		var aggro: float = float(entry.get("aggro_range_px"))
		var melee: float = float(entry.get("melee_range_px"))
		assert_gt(leash, aggro, "%s leash_range_px > aggro_range_px" % monster_id)
		assert_gt(aggro, melee, "%s aggro_range_px > melee_range_px" % monster_id)


func test_horn_rabbit_dash_fields_match_addendum() -> void:
	var entry: Dictionary = _data.get_value("monsters", "horn_rabbit", {})
	assert_almost_eq(float(entry.get("dash_speed_px")), 200.0, 0.0001)
	assert_almost_eq(float(entry.get("dash_duration_sec")), 0.3, 0.0001)
	assert_almost_eq(float(entry.get("aggro_range_px")), 80.0, 0.0001)
	assert_almost_eq(float(entry.get("melee_range_px")), 16.0, 0.0001)
	assert_almost_eq(float(entry.get("attack_recovery_sec")), 0.7, 0.0001)
	assert_almost_eq(float(entry.get("patrol_radius_px")), 96.0, 0.0001)
	assert_almost_eq(float(entry.get("leash_range_px")), 180.0, 0.0001)


func test_mushroom_spore_patch_fields_match_addendum() -> void:
	var entry: Dictionary = _data.get_value("monsters", "mushroom", {})
	assert_almost_eq(float(entry.get("atk_tick_per_sec")), 4.0, 0.0001)
	assert_almost_eq(float(entry.get("aoe_radius_px")), 32.0, 0.0001)
	assert_almost_eq(float(entry.get("aggro_range_px")), 96.0, 0.0001)
	assert_almost_eq(float(entry.get("melee_range_px")), 20.0, 0.0001)
	assert_almost_eq(float(entry.get("attack_recovery_sec")), 1.0, 0.0001)
	assert_eq(float(entry.get("patrol_radius_px")), 0.0, "버섯돌이는 고정형(순찰 없음)")
	assert_almost_eq(float(entry.get("leash_range_px")), 120.0, 0.0001)
	assert_gte(float(entry.get("aoe_radius_px")), float(entry.get("melee_range_px")),
		"aoe_radius_px >= melee_range_px(장판이 트리거 지점보다 넓게 퍼짐)")


func test_aoe_radius_below_melee_range_is_rejected() -> void:
	var probe := DataScript.new()
	add_child_autofree(probe)
	probe.tables["monsters"] = {
		"broken_aoe": {
			"region_id": "x", "tier": "normal", "hp": 1, "atk": 1, "move_speed_px": 1,
			"telegraph_sec": 0.5, "attack_pattern_id": "spore_patch", "drop_table_id": null,
			"codex_entry_id": "x", "aggro_range_px": 100, "melee_range_px": 20,
			"attack_recovery_sec": 1.0, "patrol_radius_px": 0, "leash_range_px": 150,
			"aoe_radius_px": 10,
		}
	}
	probe.validation_errors.clear()
	probe._validate_monsters()
	assert_gt(probe.validation_errors.size(), 0, "aoe_radius_px < melee_range_px는 에러여야 한다")


func test_leash_not_greater_than_aggro_is_rejected() -> void:
	var probe := DataScript.new()
	add_child_autofree(probe)
	probe.tables["monsters"] = {
		"broken_leash": {
			"region_id": "x", "tier": "normal", "hp": 1, "atk": 1, "move_speed_px": 1,
			"telegraph_sec": 0.5, "attack_pattern_id": "melee_contact", "drop_table_id": null,
			"codex_entry_id": "x", "aggro_range_px": 64, "melee_range_px": 14,
			"attack_recovery_sec": 0.4, "patrol_radius_px": 32, "leash_range_px": 50,
		}
	}
	probe.validation_errors.clear()
	probe._validate_monsters()
	assert_gt(probe.validation_errors.size(), 0, "leash_range_px <= aggro_range_px는 에러여야 한다")


func test_reject_bad_monster_entry_detected_by_generic_validator() -> void:
	# _validate_monsters()가 특정 monster_id에 하드코딩되지 않고 임의 항목을 검사하는지 확인.
	var probe := DataScript.new()
	add_child_autofree(probe)
	probe.tables["monsters"] = {"broken_monster": {"hp": 1}} # telegraph_sec 등 누락
	probe.validation_errors.clear()
	probe._validate_monsters()
	assert_gt(probe.validation_errors.size(), 0, "필수 필드 누락 몬스터는 에러로 잡혀야 한다")
