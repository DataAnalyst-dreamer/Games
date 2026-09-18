extends SceneTree
const BASE := "C:/Users/freer/ClaudeProject/make-passive-income/Games/game/"
var passes := 0
var failures := 0
class QuestFixture:
	extends RefCounted
	var state := "locked"
	var active_keys: Array[String] = []
	func get_state(_id): return state
	func get_active_interact_objective_keys(_id): return active_keys
func _initialize(): call_deferred("run")
func check(ok, label):
	if ok: passes += 1
	else: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)
func run():
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("WAYPOINT_EXPECTED_USER_DIR"):
		quit(1)
		return
	var translated: Translation = load("res://ui_ko.ko.translation")
	var csv := FileAccess.open("res://ui_ko.csv", FileAccess.READ)
	csv.get_csv_line()
	var expected := {}
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() == 2:
			expected[row[0]] = row[1]
			check(translated != null and translated.get_message(row[0]) == row[1], "compiled CSV translation " + row[0])
	check(expected.size() == 239, "exact239 imported keys")
	var font := FontFile.new()
	font.data = FileAccess.get_file_as_bytes(BASE + "assets/fonts/galmuri/Galmuri11.ttf")
	check(not font.data.is_empty(), "actual Galmuri11 font bytes")
	for size in [11, 15]:
		for suffix in ["before", "active", "after"]:
			var key: String = "observe.waypoint." + suffix
			var width := font.get_string_size(expected[key], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			check(width > 0 and width <= 154, "waypoint width size=%d key=%s px=%s" % [size, key, width])
	# Exact presentation method; fixture replaces only the QuestSystem binding.
	var source := FileAccess.get_file_as_string(BASE + "scripts/world/quest_object.gd")
	var start := source.find("func observation_key()")
	var end := source.find("func _on_quest_accepted", start)
	var adapter := GDScript.new()
	adapter.source_code = "extends RefCounted\nvar object_id: StringName\nvar _used := false\nvar quest_system\n" + source.substr(start, end - start).replace("QuestSystem.", "quest_system.").replace("var state :=", "var state: String =")
	var compiled := adapter.reload() == OK
	check(compiled, "exact observation method compiles with read-only fixture")
	if not compiled:
		quit(1)
		return
	var object = adapter.new()
	var quest := QuestFixture.new()
	object.quest_system = quest
	object.object_id = &"waypoint_stone_01"
	for state in ["locked", "available", "active", "complete_ready", "completed"]:
		quest.state = state
		var suffix := "active" if state == "active" else ("after" if state in ["complete_ready", "completed"] else "before")
		for used in [false, true]:
			object._used = used
			check(object.observation_key() == StringName("observe.waypoint." + suffix), "waypoint state=%s used=%s" % [state, used])
	object.object_id = &"ward_stone_dandelion"
	for state in ["locked", "available", "active", "complete_ready", "completed"]:
		quest.state = state
		var suffix := "active" if state == "active" else ("after" if state in ["complete_ready", "completed"] else "before")
		check(object.observation_key() == StringName("observe.ward." + suffix), "ward mapping preserved " + state)
	object.object_id = &"cargo_pile"
	quest.state = "locked"
	object._used = false
	check(object.observation_key() == &"observe.cargo.before", "cargo before preserved")
	object._used = true
	check(object.observation_key() == &"observe.cargo.used", "cargo used preserved")
	quest.active_keys.assign(["quest:1"])
	check(object.observation_key() == &"observe.cargo.active", "cargo pending objective precedence preserved")
	object.object_id = &"echo_cave_puzzle_01"
	check(object.observation_key() == &"", "unlisted object fallback preserved")
	print("WAYPOINT_IMPORT_CHECK_RESULT PASS=", passes, " FAIL=", failures)
	quit(0 if failures == 0 else 1)
