extends GutTest


func test_visit_lines_cycle_and_completed_group_is_separate() -> void:
	var hud := Hud.new()
	for npc in [&"teo", &"meru"]:
		for i in range(4):
			assert_eq(String(hud._next_npc_greeting(npc, false)), "npc.%s.everyday.%d" % [npc, i % 3 + 1])
		for i in range(4):
			assert_eq(String(hud._next_npc_greeting(npc, true)), "npc.%s.after_cave.%d" % [npc, i % 3 + 1])
		assert_eq(String(hud._next_npc_greeting(npc, false)), "npc.%s.everyday.2" % npc)
	assert_eq(hud._next_npc_greeting(&"unknown", false), &"npc.unknown.greeting")
	hud.free()


func test_villagers_cycle_and_dami_completion_is_separate() -> void:
	var hud := Hud.new()
	for npc in [&"pinto", &"rozel", &"dami"]:
		for i in range(4):
			assert_eq(String(hud._next_npc_greeting(npc, true, false)), "npc.%s.everyday.%d" % [npc, i % 3 + 1])
	for i in range(4):
		assert_eq(String(hud._next_npc_greeting(&"dami", false, true)), "npc.dami.after_montsil.%d" % (i % 3 + 1))
	assert_eq(hud._next_npc_greeting(&"dami", false, false), &"npc.dami.everyday.2")
	hud.free()


func test_all_visit_keys_have_korean_translation() -> void:
	var translation: Translation = load("res://localization/ui_ko.ko.translation")
	assert_not_null(translation)
	if translation == null: return
	for npc in ["teo", "meru"]:
		for group in ["everyday", "after_cave"]:
			for i in range(1, 4):
				var key := StringName("npc.%s.%s.%d" % [npc, group, i])
				assert_false(translation.get_message(key).is_empty(), String(key))


func test_new_lines_fit_existing_log_width() -> void:
	var translation: Translation = load("res://localization/ui_ko.ko.translation")
	var hud_theme: Theme = load("res://ui/theme.tres")
	var label := Label.new()
	label.theme = hud_theme
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	for npc in ["teo", "meru"]:
		for group in ["everyday", "after_cave"]:
			for i in range(1, 4):
				var key := StringName("npc.%s.%s.%d" % [npc, group, i])
				var text := translation.get_message(key)
				var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				print("NPC_TEXT_BOUNDS %s width=%s limit=154" % [key, width])
				assert_lte(width, 154.0, String(key))
	label.free()
