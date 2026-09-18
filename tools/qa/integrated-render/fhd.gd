## QA-only render probe. Never changes project settings or game coordinate policy.
extends Node

var failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var expected := OS.get_environment("DIAG_EXPECTED_USER_DIR")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	print("FHD_ISOLATION_ACTUAL=" + actual)
	if actual != expected or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("FHD_ISOLATION_FAIL")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("FHD_RENDER_REQUIRES_DISPLAY: headless cannot prove rendered pixels")
		get_tree().quit(1)
		return
	var capture := ""
	var force_size := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
		if arg == "--force-window-fhd": force_size = true
	Events.main_quest_stage_completed.disconnect(SaveManager._on_autosave_trigger)
	QuestSystem.from_dict({"completed": ["quest_main_a1_01_arrival"]})
	await get_tree().process_frame
	_print_state("before_runtime_size_request")
	if force_size:
		get_window().size = Vector2i(1920, 1080)
	for i in range(4): await get_tree().process_frame
	var world: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	var ui: UiRoot = world.get_node("UiRoot")
	ui.open_quest_npc(&"teo")
	for i in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_print_state("after_render")
	var pixels := get_viewport().get_texture().get_image()
	_check(pixels.get_size() == Vector2i(1920, 1080), "actual render texture is 1920x1080")
	_check(get_window().content_scale_size == Vector2i(640, 360), "existing logical 640x360 unchanged")
	_check(get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "existing canvas_items render scaling unchanged")
	_check(ui.is_quest_npc_open(), "quest panel visible")
	var logical_rect := get_viewport().get_visible_rect()
	for control: Control in [ui.quest_npc_panel.title_label, ui.quest_npc_panel.body_label, ui.quest_npc_panel.confirm_button, ui.quest_npc_panel.close_button]:
		var bounds := control.get_global_rect()
		print("FHD_CONTROL %s rect=%s" % [control.get_class(), bounds])
		_check(logical_rect.encloses(bounds), "control inside logical viewport: " + control.get_class())
	var body := ui.quest_npc_panel.body_label
	print("FHD_TEXT_LINES total=%d visible=%d" % [body.get_line_count(), body.get_visible_line_count()])
	_check(body.get_visible_line_count() >= body.get_line_count(), "body text lines not clipped")
	if not capture.is_empty():
		_check(pixels.save_png(capture) == OK, "actual renderer PNG saved without resizing")
	print("FHD_CAPTURE_RESULT FAIL=%d pixels=%s" % [failures, pixels.get_size()])
	pixels = null
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	print(("[PASS] " if ok else "[FAIL] ") + label)
	if not ok: failures += 1

func _print_state(label: String) -> void:
	var window := get_window()
	for screen in DisplayServer.get_screen_count():
		print("FHD_SCREEN %d position=%s size=%s usable=%s" % [screen, DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen), DisplayServer.screen_get_usable_rect(screen)])
	print("FHD_STATE " + label + " " + JSON.stringify({
		"requested_project_window": [ProjectSettings.get_setting("display/window/size/window_width_override"), ProjectSettings.get_setting("display/window/size/window_height_override")],
		"window_size": str(window.size), "native_client": str(DisplayServer.window_get_size()),
		"screen_size": str(DisplayServer.screen_get_size()), "screen_usable": str(DisplayServer.screen_get_usable_rect()),
		"screen_scale": DisplayServer.screen_get_scale(), "window_mode": window.mode,
		"logical_content": str(window.content_scale_size), "logical_visible": str(window.get_visible_rect()),
		"viewport_texture_reported_size": str(window.get_texture().get_size()), "stretch": str(window.get_stretch_transform()),
		"content_scale_mode": window.content_scale_mode, "content_scale_stretch": window.content_scale_stretch
	}))


