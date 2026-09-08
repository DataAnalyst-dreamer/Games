## Settings(scripts/core/settings.gd) 로드/저장/기본값 테스트(F7-1 태스크 6, D-64).
## 자동로드 싱글턴 대신 새 인스턴스를 만들어 테스트 간 상태를 격리한다(test_game_state.gd와
## 동일한 패턴). _ready()가 실제 user://settings.json을 건드리므로 트리에 add_child하지
## 않고(= _ready 미호출) 메서드를 직접 호출한다 — save/load 테스트만 예외적으로 실제
## 파일을 사용한 뒤 기본값으로 되돌려 저장해 다음 실행을 오염시키지 않는다.
extends GutTest

const SettingsScript := preload("res://scripts/core/settings.gd")


func _make_settings() -> Node:
	return SettingsScript.new()


func test_default_dict_matches_gdd_decisions() -> void:
	var d: Dictionary = SettingsScript.default_dict()
	assert_eq(d["screen_shake_index"], 2, "기본 흔들림 강도=보통(인덱스 2)")
	assert_true(d["damage_numbers_enabled"], "D-07: 데미지 숫자 기본 켜짐")
	assert_false(d["colorblind_mode"])
	assert_false(d["font_size_large"])
	assert_eq(d["master_volume"], 1.0)
	assert_eq(d["bgm_volume"], 1.0)
	assert_eq(d["sfx_volume"], 1.0)


func test_apply_dict_clamps_out_of_range_values() -> void:
	var s := _make_settings()
	s.apply_dict({
		"screen_shake_index": 99,
		"master_volume": 5.0,
		"bgm_volume": -1.0,
	})
	assert_eq(s.screen_shake_index, 3, "0~3 범위로 clamp")
	assert_eq(s.master_volume, 1.0)
	assert_eq(s.bgm_volume, 0.0)
	s.free()


func test_apply_dict_missing_keys_fall_back_to_defaults() -> void:
	var s := _make_settings()
	s.apply_dict({})
	assert_eq(s.to_dict(), SettingsScript.default_dict())
	s.free()


func test_to_dict_round_trip_without_file_io() -> void:
	var s := _make_settings()
	s.apply_dict({
		"screen_shake_index": 1,
		"colorblind_mode": true,
		"font_size_large": true,
		"sfx_volume": 0.4,
	})
	var d: Dictionary = s.to_dict()

	var s2 := _make_settings()
	s2.apply_dict(d)
	assert_eq(s2.screen_shake_index, 1)
	assert_true(s2.colorblind_mode)
	assert_true(s2.font_size_large)
	assert_almost_eq(s2.sfx_volume, 0.4, 0.0001)
	s.free()
	s2.free()


func test_get_shake_scale_matches_tuning_table_d63_d64() -> void:
	var s := _make_settings()
	s.screen_shake_index = 0
	assert_eq(s.get_shake_scale(), Tuning.SCREEN_SHAKE_LEVELS[0])
	s.screen_shake_index = 3
	assert_eq(s.get_shake_scale(), Tuning.SCREEN_SHAKE_LEVELS[3])
	s.free()


func test_save_and_load_round_trip_via_file() -> void:
	var s := _make_settings()
	s.apply_dict({"screen_shake_index": 1, "master_volume": 0.5})
	var err: Error = s.save_settings()
	assert_eq(err, OK, "settings.json 저장이 성공해야 한다")
	assert_true(FileAccess.file_exists("user://settings.json"))

	var s2 := _make_settings()
	s2.load_settings()
	assert_eq(s2.screen_shake_index, 1)
	assert_almost_eq(s2.master_volume, 0.5, 0.0001)

	# 다음 실행 오염 방지: 기본값으로 되돌려 저장.
	s.apply_dict(SettingsScript.default_dict())
	s.save_settings()
	s.free()
	s2.free()
