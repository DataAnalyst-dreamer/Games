extends SceneTree
const EXPECTED = "C:/Users/freer/ClaudeProject/make-passive-income/reviews/games-2026-09-12/runtime/hud-large-story-v1/userdata/HudLargeStory"
var failures := 0
func _initialize():
	call_deferred("run")
func check(ok, text):
	print("[PASS] " if ok else "[FAIL] ", text)
	if not ok: failures += 1
func apply_log_size(list, size):
	for row in list.get_children():
		if row is Label: row.add_theme_font_size_override("font_size", size)
		elif row is HBoxContainer:
			for child in row.get_children():
				if child is Label: child.add_theme_font_size_override("font_size", size)
func run():
	if OS.get_user_data_dir().replace("\\", "/") != EXPECTED:
		quit(1)
		return
	if "--probe" in OS.get_cmdline_user_args():
		print("HUD_LARGE_PROBE_EXACT=", EXPECTED)
		quit(0)
		return
	check(root.mode == Window.MODE_MINIMIZED, "minimized window")
	var view := SubViewport.new()
	view.size = Vector2i(640,360)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas := Control.new()
	canvas.theme = load("res://ui/theme.tres")
	view.add_child(canvas)
	var bg := ColorRect.new()
	bg.size = Vector2(640,360)
	bg.color = Color("202820")
	canvas.add_child(bg)
	var texts = ["왔으면 밥부터 먹어. 국 데워줄게.", "묶인 짐을 살펴보자.", "홀씨 모양의 돌이다.", "슬라임 젤리 x1"]
	for variant in range(3):
		var title := Label.new()
		title.text = ["11px / original", "15px / original", "15px / wrap + latest"][variant]
		title.position = Vector2(8+variant*210,220)
		canvas.add_child(title)
		var bottom := Control.new()
		bottom.position = Vector2(6+variant*210,290)
		bottom.size = Vector2(154,64)
		canvas.add_child(bottom)
		var area := ColorRect.new()
		area.color = Color("404830")
		area.size = Vector2(154,64)
		bottom.add_child(area)
		var list := VBoxContainer.new()
		list.size = Vector2(154,64)
		list.alignment = BoxContainer.ALIGNMENT_END
		bottom.add_child(list)
		var labels: Array[Label] = []
		for i in range(4):
			var label := Label.new()
			label.text = texts[i]
			label.add_theme_font_size_override("font_size",11)
			labels.append(label)
			if i == 3:
				var row := HBoxContainer.new()
				var icon := TextureRect.new()
				icon.texture = ImageTexture.create_from_image(Image.load_from_file("C:/Users/freer/ClaudeProject/make-passive-income/Games/game/assets/generated/items/item-slime-jelly-v1.png"))
				icon.custom_minimum_size = Vector2(16,16)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(icon)
				row.add_child(label)
				list.add_child(row)
			else: list.add_child(label)
		if variant > 0:
			apply_log_size(list,15)
			apply_log_size(list,11)
			for label in labels: check(label.get_theme_font_size("font_size") == 11, "toggle back existing Label")
			apply_log_size(list,15)
		for label in labels:
			check(label.get_theme_font_size("font_size") == (11 if variant == 0 else 15), "existing nested/direct Label size")
		if variant == 2:
			for label in labels:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		await process_frame
		await process_frame
		if variant == 2:
			while list.get_combined_minimum_size().y > 64 and list.get_child_count() > 1:
				var oldest = list.get_child(0)
				list.remove_child(oldest)
				oldest.queue_free()
				await process_frame
			list.size = Vector2(154,64)
			await process_frame
		var overflow := list.size.x > 154 or list.size.y > 64
		print("LAYOUT variant=",variant," size=",list.size," rows=",list.get_child_count()," overflow=",overflow)
		if variant == 2:
			check(not overflow, "bounded alternative 154x64")
			for row in list.get_children():
				check(row.position.y + row.size.y <= 64 and row.position.x + row.size.x <= 154, "row inside right/bottom limits")
			check(list.get_child(list.get_child_count()-1) is HBoxContainer, "newest icon row retained")
	var note := Label.new()
	note.text = "QA ONLY / 4 input messages / newest rows retained / not production"
	note.position = Vector2(8,20)
	canvas.add_child(note)
	await process_frame
	RenderingServer.force_draw(false)
	var image := view.get_texture().get_image()
	check(image.get_size() == Vector2i(640,360), "actual 640x360 capture")
	check(image.save_png("C:/Users/freer/ClaudeProject/make-passive-income/Games/docs/qa/hud-large-sample-v2.png") == OK,"capture saved")
	print("HUD_LARGE_RESULT failures=",failures)
	view.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
