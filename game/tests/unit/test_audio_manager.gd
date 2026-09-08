## AudioManager 데이터 무결성 테스트(audio-spec.md §6-2 스키마). id→파일 매핑이 실제
## 존재하는 리소스를 가리키는지, 필수 필드가 있는지 검증한다. AudioManager 자체(재생)는
## 헤드리스에서 로그만 남기므로 여기서는 데이터 레이어만 검증한다.
extends GutTest

const DataScript := preload("res://scripts/core/data.gd")

var _data: Node


func before_each() -> void:
	_data = DataScript.new()
	add_child_autofree(_data)


func test_audio_sfx_table_loads() -> void:
	assert_true(_data.tables.has("audio_sfx"), "audio_sfx.json이 로드되어야 한다")


func test_audio_bgm_table_loads() -> void:
	assert_true(_data.tables.has("audio_bgm"), "audio_bgm.json이 로드되어야 한다")


func test_every_sfx_entry_has_required_fields() -> void:
	var table: Dictionary = _data.table("audio_sfx")
	for id: String in table:
		if id.begins_with("_"):
			continue
		var entry: Dictionary = table[id]
		assert_true(entry.has("files"), "%s.files 존재" % id)
		assert_true(entry.get("files", []).size() > 0, "%s.files는 최소 1개" % id)
		assert_true(entry.has("bus"), "%s.bus 존재" % id)
		assert_true(entry.has("volume_db"), "%s.volume_db 존재" % id)


func test_every_sfx_file_path_resolves_to_existing_resource() -> void:
	var table: Dictionary = _data.table("audio_sfx")
	for id: String in table:
		if id.begins_with("_"):
			continue
		var entry: Dictionary = table[id]
		for file_path: String in entry.get("files", []):
			assert_true(ResourceLoader.exists(file_path), "%s: 파일 존재해야 함: %s" % [id, file_path])


func test_every_bgm_file_path_resolves_to_existing_resource() -> void:
	var table: Dictionary = _data.table("audio_bgm")
	for id: String in table:
		if id.begins_with("_"):
			continue
		var entry: Dictionary = table[id]
		assert_true(entry.has("file"), "%s.file 존재" % id)
		assert_true(ResourceLoader.exists(String(entry.get("file", ""))),
			"%s: 파일 존재해야 함: %s" % [id, entry.get("file")])


func test_sfx_bus_names_are_known() -> void:
	var known_buses := ["Master", "BGM", "SFX", "UI", "Ambient"]
	var table: Dictionary = _data.table("audio_sfx")
	for id: String in table:
		if id.begins_with("_"):
			continue
		var bus: String = String(table[id].get("bus", ""))
		assert_true(known_buses.has(bus), "%s.bus(%s)는 default_bus_layout.tres의 5버스 중 하나여야 한다" % [id, bus])


func test_key_m1_events_are_mapped() -> void:
	# sound-map-m1.md §1~§8 핵심 이벤트가 최소한 데이터에 존재하는지(배선 누락 방지).
	var table: Dictionary = _data.table("audio_sfx")
	for id: String in [
		"atk_swing_1", "atk_swing_2", "atk_swing_finisher",
		"hit_normal", "hit_heavy", "player_hurt", "player_guard_chip",
		"just_guard_success", "stamina_exhausted", "player_roll",
		"slime_telegraph", "slime_attack", "slime_hurt", "slime_death",
		"player_death_jingle", "player_respawn_jingle", "waystone_activate",
	]:
		assert_true(table.has(id), "sound-map-m1.md 이벤트 매핑 존재: %s" % id)
