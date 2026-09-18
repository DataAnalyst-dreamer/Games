extends SceneTree
func _initialize() -> void:
	var expected := OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	print("QUARTER_PROBE actual=" + actual + " expected=" + expected)
	quit(0 if not expected.is_empty() and actual == expected else 41)
