extends Node

const Q1 := "quest_main_a1_01_arrival"
const Q2 := "quest_main_a1_02_firstlook"
var world: Node
var player: Player
var layer: Node
var ui: UiRoot
var failures := 0
var passes := 0
var talks := 0
var accepted := 0
var completed := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_user_data_dir().replace("\\", "/") != "C:/Users/freer/AppData/Roaming/Games-QA-npc-greeting-20260913-story":
		push_error("NPC_PANEL_ISOLATION_FAIL")
		get_tree().quit(1)
		return
	print("NPC_PANEL_ISOLATION_PASS")
	# This test exercises UI/backend, not disk autosave. Dedicated user dir still required.
	Events.main_quest_stage_completed.disconnect(SaveManager._on_autosave_trigger)
	Events.npc_talked.connect(func(_id): talks += 1)
	Events.quest_accepted.connect(func(_id): accepted += 1)
	Events.quest_completed.connect(func(_id): completed += 1)
	QuestSystem.reset()
	world = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	player = world.get_node("Player")
	layer = world.get_node("HartlandQuestLayer")
	ui = world.get_node("UiRoot")
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	await _run()
	print("NPC_PANEL_TEST_RESULT PASS=%d FAIL=%d" % [passes, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + message)


func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _interact(target: Node2D) -> void:
	player.global_position = target.global_position
	for i in range(4): await get_tree().physics_frame
	await _action(&"interact")


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _pad_a() -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _run() -> void:
	player.global_position = layer.spawned_by_id["teo"].global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E)
	_check(ui.is_quest_npc_open() and get_tree().paused, "interact opens modal and pauses world")
	_check(accepted == 0 and QuestSystem.get_state(Q1) == "available", "opening does not auto accept")
	_check(ui.quest_npc_panel.quest_id == Q1, "first offer is existing teo MQ01")
	var old_talks := talks
	await _action(&"interact")
	_check(talks == old_talks, "modal interact does not fire world talk again")
	ui.open_menu()
	ui.open_blacksmith()
	ui.open_mailbox()
	_check(not ui.is_menu_open() and not ui.is_blacksmith_open() and not ui.is_mailbox_open(), "other menus cannot overlap quest modal")
	await _key(KEY_ESCAPE)
	_check(not ui.is_quest_npc_open() and not get_tree().paused and accepted == 0, "cancel closes without accepting")
	await _pad_a()
	_check(ui.is_quest_npc_open() and accepted == 0, "mapped pad A opening press/release does not auto accept")
	await _key(KEY_ENTER)
	_check(accepted == 1 and QuestSystem.get_state(Q1) == "active", "focused accept button invokes backend once")
	_check(not ui.is_quest_npc_open() and not get_tree().paused, "accept closes modal")
	await _action(&"ui_accept")
	_check(accepted == 1, "extra accept does not duplicate acceptance")
	await _interact(layer.spawned_by_id["teo"])
	_check(QuestSystem.get_active_objective_index(Q1) == 1, "existing NPC talk objective remains intact")
	_check(ui.quest_npc_panel.confirm_button.disabled, "active quest cannot turn in early")
	await _action(&"ui_cancel")
	await _interact(layer.spawned_by_id["cargo_pile"])
	_check(QuestSystem.get_state(Q1) == "complete_ready", "cargo input reaches turn-in state")
	await _interact(layer.spawned_by_id["teo"])
	_check(completed == 0 and not ui.quest_npc_panel.confirm_button.disabled, "ready quest waits for completion confirmation")
	var xp := QuestSystem.total_exp_earned
	await _action(&"ui_accept")
	_check(completed == 1 and QuestSystem.get_state(Q1) == "completed" and QuestSystem.total_exp_earned == xp + 5, "completion button grants existing MQ01 reward once")
	await _action(&"ui_accept")
	_check(completed == 1 and QuestSystem.total_exp_earned == xp + 5, "extra confirm cannot duplicate reward")
	await _interact(layer.spawned_by_id["teo"])
	_check(ui.quest_npc_panel.quest_id == Q2 and QuestSystem.get_state(Q2) == "available", "next existing MQ02 offered only after prerequisite")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture=")) == OK, "save actual quest panel render")
	await _action(&"ui_accept")
	_check(accepted == 2 and QuestSystem.get_state(Q2) == "active", "MQ02 accepted through button")
	await _interact(layer.spawned_by_id["heartland_dandelion_village"])
	await _interact(layer.spawned_by_id["meru"])
	_check(not ui.is_quest_npc_open(), "non-giver meru does not expose teo turn-in")
	_check(QuestSystem.get_state(Q2) == "complete_ready", "MQ02 reach and talk through world interaction")
	await _interact(layer.spawned_by_id["teo"])
	await _action(&"ui_accept")
	_check(completed == 2 and QuestSystem.get_state(Q2) == "completed", "MQ02 complete through giver button")
	ui.open_menu()
	ui.open_quest_npc(&"teo")
	_check(ui.is_menu_open() and not ui.is_quest_npc_open(), "quest modal cannot open over inventory")
	ui.close_menu()
