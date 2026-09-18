extends SceneTree
func _initialize() -> void:
	var actual := OS.get_user_data_dir().replace("\\", "/")
	var expected := OS.get_environment("WAYPOINT_EXPECTED_USER_DIR")
	print("WAYPOINT_USER_DIR=", actual)
	if not expected.is_empty() and actual == expected:
		print("WAYPOINT_PROBE_EXACT")
		quit(0)
	else:
		quit(1)
