extends SceneTree
func _initialize():
	var expected := OS.get_environment("EDITOR_DIFF_EXPECTED_USER_DIR")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	print("EDITOR_DIFF_USER_DIR actual=", actual, " expected=", expected)
	var ok := not expected.is_empty() and actual == expected
	print("EDITOR_DIFF_PROBE_PASS" if ok else "EDITOR_DIFF_PROBE_FAIL")
	quit(0 if ok else 1)
