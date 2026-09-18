extends SceneTree
func _initialize() -> void:
	var actual := OS.get_user_data_dir().replace("\\", "/")
	var expected := "C:/Users/freer/ClaudeProject/make-passive-income/reviews/games-2026-09-12/runtime/reactivity-font-story-v1/userdata/ReactivityFontStory"
	print("REACTIVITY_FONT_PROBE actual=" + actual + " match=" + str(actual == expected))
	quit(0 if actual == expected else 1)
