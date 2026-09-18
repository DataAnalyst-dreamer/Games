## Capture presentation fixtures; physical E is real, quest state setup is synthetic.
extends Node
const QA_DIR := "C:/Users/freer/AppData/Roaming/Games-QA-object-observation-20260913-story"
var world: Node
var player: Player
var ui: UiRoot
var passes := 0
var failures := 0
var output := ""

func _ready() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != QA_DIR or DisplayServer.get_name() == "headless":
		push_error("OBSERVATION_CAPTURE_REQUIRES_ISOLATED_RENDERER")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		get_tree().quit(1)
		return
	Events.main_quest_stage_completed.disconnect(SaveManager._on_autosave_trigger)
	Events.waystone_activated.disconnect(SaveManager._on_autosave_trigger)
	QuestSystem.reset()
	world = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	player = world.get_node("Player")
	ui = world.get_node("UiRoot")
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	var objects: Dictionary = world.get_node("HartlandQuestLayer").spawned_by_id
	await _capture(objects["cargo_pile"], "cargo-before", "observe.cargo.before")
	QuestSystem.accept("quest_main_a1_01_arrival")
	Events.npc_talked.emit(&"teo")
	await _capture(objects["cargo_pile"], "cargo-active", "observe.cargo.active")
	await _capture(objects["cargo_pile"], "cargo-after", "observe.cargo.used")
	var state := QuestSystem.to_dict()
	state["active"] = {"quest_main_a1_04_theshard": {"objective_index": 1, "progress": {}, "branch_choice": ""}}
	QuestSystem.from_dict(state)
	await _capture(objects["ward_stone_dandelion"], "ward-active", "observe.ward.active")
	print("OBSERVATION_CAPTURE_RESULT PASS=%d FAIL=%d" % [passes, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _capture(target: Node2D, name_suffix: String, key: String) -> void:
	for child in ui.hud.log_list.get_children(): child.queue_free()
	player.global_position = target.global_position
	for i in range(8): await get_tree().physics_frame
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
	for i in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var logs := ui.hud.log_list.get_children()
	var found := false
	for line in logs:
		if line is Label and line.text == tr(key):
			found = true
			_check(ui.hud.log_list.get_global_rect().encloses(line.get_global_rect()), name_suffix + " log bounds within container")
	_check(found, name_suffix + " actual E shows expected translated text")
	_check(not ui.is_quest_npc_open() and not ui.is_menu_open() and not get_tree().paused, name_suffix + " no modal overlap")
	var pixels := get_viewport().get_texture().get_image()
	print("OBSERVATION_CAPTURE_SIZE %s %s" % [name_suffix, pixels.get_size()])
	_check(pixels.save_png(output.path_join("observation-" + name_suffix + ".png")) == OK, name_suffix + " rendered PNG saved")

func _check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)
