extends SceneTree
func _initialize() -> void:
	call_deferred("_measure")
func _measure() -> void:
	var expected := "C:/Users/freer/ClaudeProject/make-passive-income/reviews/games-2026-09-12/runtime/reactivity-font-story-v1/userdata/ReactivityFontStory"
	if OS.get_user_data_dir().replace("\\", "/") != expected:
		quit(1)
		return
	var input_path := "res://quest-reactivity-v1.json"
	if "--empty-input-regression" in OS.get_cmdline_user_args():
		input_path = "res://empty-reactivity.json"
	var document = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not document is Dictionary or not document.get("reactions") is Array:
		push_error("Invalid reactivity document")
		quit(1)
		return
	var panel := Control.new()
	panel.theme = load("res://ui/theme.tres")
	if panel.theme == null or panel.theme.default_font == null:
		push_error("Required theme/default font missing")
		panel.free()
		quit(1)
		return
	root.add_child(panel)
	var bottom := Control.new()
	panel.add_child(bottom)
	var log_list := VBoxContainer.new()
	log_list.size = Vector2(154,64)
	bottom.add_child(log_list)
	var label := Label.new()
	log_list.add_child(label)
	var count := 0
	var failures := 0
	var maximum := 0.0
	for mode in ["default", "large"]:
		panel.add_theme_font_size_override("font_size", panel.theme.get_font_size(mode, "HUD"))
		await process_frame
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		if font == null or font_size != 11:
			push_error("Measured Label font context changed; expected nonnull font at 11px")
			panel.queue_free()
			quit(1)
			return
		print("FONT_CONTEXT mode=%s parent_override=%s actual_label_size=%d family=%s theme_default=%d" % [mode,panel.get_theme_font_size("font_size"),font_size,font.get_font_name(),panel.theme.default_font_size])
		for card in document.reactions:
			for line in card.lines:
				label.text = line.hud_short
				var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
				count += 1
				maximum = maxf(maximum,width)
				if width > 154: failures += 1
				print("REACTIVITY_WIDTH mode=%s id=%s choice=%s width=%.2f limit=154 text=%s" % [mode,card.id,line.choice,width,label.text])
	print("REACTIVITY_FONT_RESULT measurements=%d max_width=%.2f overflow=%d expanded=UNTESTED runtime=UNCONNECTED" % [count,maximum,failures])
	panel.queue_free()
	await process_frame
	if count != 80:
		push_error("Expected exactly 80 measurements, got %d" % count)
	print("REACTIVITY_GUARD_RESULT expected=80 actual=%d valid=%s" % [count, count == 80 and failures == 0])
	quit(0 if failures == 0 and count == 80 else 1)
