## Data 자동로드 / combat.json 검증 테스트 (GUT).
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const DataScript := preload("res://scripts/core/data.gd")

var _data: Node


func before_each() -> void:
	# 자동로드 싱글턴 대신 새 인스턴스를 만들어 디스크에서 다시 읽는다.
	_data = DataScript.new()
	add_child_autofree(_data)


func test_combat_table_loads() -> void:
	assert_true(_data.tables.has("combat"), "combat.json 이 로드되어야 한다")
	assert_eq(_data.validation_errors.size(), 0, "검증 에러가 없어야 한다: %s" % [_data.validation_errors])


func test_required_keys_exist() -> void:
	for key_path: String in DataScript.REQUIRED_SCHEMA["combat"]:
		assert_true(_data.has_value("combat", key_path), "필수 키 존재: combat.%s" % key_path)


func test_roll_iframes_matches_gdd() -> void:
	# GDD 4.1: 구르기 무적 0.3초
	assert_almost_eq(float(_data.get_value("combat", "roll.iframes_sec")), 0.3, 0.0001)


func test_just_guard_window_matches_d05() -> void:
	# D-05: 6프레임 = 0.1초 (60fps)
	var frames: int = int(_data.get_value("combat", "guard.just_guard_window_frames"))
	var fps: int = int(_data.get_value("combat", "frame_rate_reference"))
	assert_eq(frames, 6)
	assert_eq(fps, 60)
	assert_almost_eq(float(_data.get_value("combat", "guard.just_guard_window_sec")), float(frames) / float(fps), 0.0001)


func test_hitstop_range() -> void:
	# GDD 4.2: 히트스톱 0.05~0.1초
	var min_sec := float(_data.get_value("combat", "hitstop.min_sec"))
	var max_sec := float(_data.get_value("combat", "hitstop.max_sec"))
	assert_almost_eq(min_sec, 0.05, 0.0001)
	assert_almost_eq(max_sec, 0.1, 0.0001)
	assert_lt(min_sec, max_sec)


func test_telegraph_minimum() -> void:
	# GDD 4.2: 공격 예고 최소 0.5초
	assert_gte(float(_data.get_value("combat", "telegraph.min_sec")), 0.5)


func test_combo_multipliers_match_hit_count() -> void:
	var hits := int(_data.get_value("combat", "combo.hits"))
	var mults: Array = _data.get_value("combat", "combo.damage_multipliers")
	assert_eq(hits, 3, "GDD 4.1: 3타 콤보")
	assert_eq(mults.size(), hits, "타별 배율 개수 = 타수")
	for m in mults:
		assert_gt(float(m), 0.0, "배율은 양수")


func test_movement_and_stamina_ranges() -> void:
	var walk := float(_data.get_value("combat", "movement.walk_speed_px"))
	assert_between(walk, 16.0, 400.0, "이동 속도는 합리적 범위(px/s)")
	var stamina_max := float(_data.get_value("combat", "stamina.max"))
	var regen := float(_data.get_value("combat", "stamina.regen_per_sec"))
	var roll_cost := float(_data.get_value("combat", "stamina.costs.roll"))
	assert_gt(stamina_max, 0.0)
	assert_gt(regen, 0.0)
	assert_gt(roll_cost, 0.0)
	assert_lte(roll_cost, stamina_max, "구르기 1회 비용은 최대치 이하")


func test_hurt_stun_and_iframes_match_addendum() -> void:
	# addendum §2 확정: 경직 0.25s < 무적 0.5s (스턴락 방지).
	assert_almost_eq(float(_data.get_value("combat", "hurt.stun_sec")), 0.25, 0.0001)
	assert_almost_eq(float(_data.get_value("combat", "hurt.iframes_sec")), 0.5, 0.0001)
	assert_lte(float(_data.get_value("combat", "hurt.stun_sec")), float(_data.get_value("combat", "hurt.iframes_sec")))


func test_hurt_stun_greater_than_iframes_is_rejected() -> void:
	var probe := DataScript.new()
	add_child_autofree(probe)
	probe.tables["combat"] = {"hurt": {"stun_sec": 0.6, "iframes_sec": 0.5}}
	probe.validation_errors.clear()
	probe._validate_value_rules()
	assert_gt(probe.validation_errors.size(), 0, "stun_sec > iframes_sec는 에러여야 한다(스턴락 방지)")


func test_knockback_duration_matches_addendum() -> void:
	assert_almost_eq(float(_data.get_value("combat", "knockback.duration_sec")), 0.12, 0.0001)


func test_camera_shake_tiers_present() -> void:
	# addendum §3-2: normal은 진폭 0(GDD 4.2 그대로 셰이크 없음), 나머지 3단계는 양수.
	assert_almost_eq(float(_data.get_value("combat", "camera_shake.normal.amplitude_px")), 0.0, 0.0001)
	for tier: String in ["heavy", "crit", "hit"]:
		var amp: float = float(_data.get_value("combat", "camera_shake.%s.amplitude_px" % tier))
		var dur: float = float(_data.get_value("combat", "camera_shake.%s.duration_sec" % tier))
		assert_gt(amp, 0.0, "camera_shake.%s.amplitude_px > 0" % tier)
		assert_gt(dur, 0.0, "camera_shake.%s.duration_sec > 0" % tier)
	# 강공격 < 크리티컬 진폭·지속(addendum §3-2 표: 크리는 강공격보다 한 단계 더 강함).
	assert_lt(float(_data.get_value("combat", "camera_shake.heavy.amplitude_px")),
		float(_data.get_value("combat", "camera_shake.crit.amplitude_px")))


func test_guard_and_stamina_multipliers_confirmed_not_balance_todo() -> void:
	# 결정 요청 8 승인(D-68 예정): guard.move_speed_multiplier / stamina.guard_regen_multiplier
	# 는 확정 전환되어 더 이상 _balance_todo 목록에 있으면 안 된다.
	var guard_todo: Array = _data.get_value("combat", "guard._balance_todo", [])
	var stamina_todo: Array = _data.get_value("combat", "stamina._balance_todo", [])
	assert_false(guard_todo.has("move_speed_multiplier"), "move_speed_multiplier는 확정 전환됨")
	assert_false(stamina_todo.has("guard_regen_multiplier"), "guard_regen_multiplier는 확정 전환됨")
	assert_almost_eq(float(_data.get_value("combat", "guard.move_speed_multiplier")), 0.5, 0.0001)
	assert_almost_eq(float(_data.get_value("combat", "stamina.guard_regen_multiplier")), 0.5, 0.0001)


func test_get_value_default_for_missing_key() -> void:
	assert_eq(_data.get_value("combat", "does.not.exist", 42), 42)
	assert_eq(_data.get_value("no_such_table", "x", "fallback"), "fallback")
	assert_false(_data.has_value("combat", "does.not.exist"))
