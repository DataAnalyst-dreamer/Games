extends SceneTree
func _initialize():
	var actual := OS.get_user_data_dir().replace("\\", "/")
	var expected := OS.get_environment("NPC_EXPECTED_USER_DIR")
	print("NPC_USER_DIR=", actual)
	if not expected.is_empty() and actual == expected:
		print("NPC_PROBE_EXACT")
		quit(0)
	else:
		quit(1)
