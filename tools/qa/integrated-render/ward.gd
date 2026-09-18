extends Node
var passes := 0
var failures := 0
var saves := 0
var interactions := 0
func _ready() -> void:
	get_window().size = Vector2i(1920,1080)
	for frame in range(4): await get_tree().process_frame
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("DIAG_EXPECTED_USER_DIR"):
		get_tree().quit(1)
		return
	if FileAccess.file_exists("user://saves/slot0_auto.json"):
		push_error("Existing autosave fixture: refusing overwrite")
		get_tree().quit(1)
		return
	var world := load("res://scenes/main/Main.tscn").instantiate() as Node
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	var player := world.get_node("Player") as Player
	var stone := world.get_node("Waystone1") as Waystone
	var ui := world.get_node("UiRoot") as UiRoot
	var ward: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["ward_stone_dandelion"]
	QuestSystem.from_dict({"active": {"quest_main_a1_04_theshard": {"objective_index": 1, "progress": {}, "branch_choice": ""}}})
	Events.save_completed.connect(func(_slot, _kind, ok):
		if ok: saves += 1)
	Events.object_interacted.connect(func(_id): interactions += 1)
	player.global_position = ward.global_position
	for i in range(4): await get_tree().physics_frame
	ui.open_menu()
	await _key()
	_check(not stone.is_active and saves == 0 and interactions == 0, "modal E does not activate either component")
	ui.close_menu()
	await _key()
	_check(stone.is_active and GameState.last_waystone == stone, "one physical E activates shared D28 Waystone")
	_check(saves == 2 and FileAccess.file_exists("user://saves/slot0_auto.json"), "MQ04 completion and first Waystone activation each autosave once")
	_check(interactions == 1 and QuestSystem.get_state("quest_main_a1_04_theshard") == "completed", "same E completes existing system-giver MQ04")
	var found := false
	for line in ui.hud.log_list.get_children():
		if line is Label and line.text == tr("observe.ward.active"): found = true
	_check(found, "same E shows ward observation")
	await _key()
	_check(saves == 2 and interactions == 2 and QuestSystem.total_exp_earned == 5, "repeat E keeps repeatable ward without duplicate autosave or EXP")
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(OS.get_environment("INTEGRATED_CAPTURE")) == OK, "ward actual capture")
	print("WARD_WAYSTONE_RESULT PASS=%d FAIL=%d" % [passes, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _key() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
func _check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)


