extends SceneTree
const Q := "quest_side_heartland_waypoint"
var passes := 0
var failures := 0
var interactions := 0
var saves := 0
var quest
var events
var state
var player
func _initialize(): call_deferred("run")
func check(ok, label):
	if ok: passes += 1
	else: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)
func _object_event(_id): interactions += 1
func _saved(_slot, _kind, ok):
	if ok: saves += 1
func key_e():
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func move_to(position):
	player.global_position = position
	for frame in range(4): await physics_frame
func last_text(hud) -> String:
	if hud.log_list.get_child_count() == 0: return ""
	return hud.log_list.get_child(hud.log_list.get_child_count() - 1).text
func has_text(hud, text) -> bool:
	for line in hud.log_list.get_children():
		if line is Label and line.text == text: return true
	return false
func run():
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("WAYPOINT_EXPECTED_USER_DIR"):
		quit(1)
		return
	if DirAccess.dir_exists_absolute("user://saves"):
		push_error("Existing saves directory refused")
		quit(1)
		return
	quest = root.get_node("QuestSystem")
	events = root.get_node("Events")
	state = root.get_node("GameState")
	events.object_interacted.connect(_object_event)
	events.save_completed.connect(_saved)
	TranslationServer.set_locale("ko")
	var world = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	for enemy in get_nodes_in_group("monster"): enemy.queue_free()
	await process_frame
	player = world.get_node("Player")
	var ui = world.get_node("UiRoot")
	var hud = ui.hud
	var layer = world.get_node("HartlandQuestLayer")
	var waypoint = layer.spawned_by_id["waypoint_stone_01"]
	var gold_before = state.gold
	check(TranslationServer.translate("observe.waypoint.before") == "언덕 위 비석이다.", "actual project imported waypoint translation")
	check(quest.get_state(Q) == "locked", "fresh S5 locked")
	await move_to(waypoint.global_position)
	check(waypoint._player_inside == player and waypoint.overlaps_body(player), "actual waypoint Area overlap")
	await key_e()
	check(last_text(hud) == "언덕 위 비석이다.", "locked physical E displays before")
	check(interactions == 1 and quest.get_state(Q) == "locked", "early visit retains existing event but no quest advance")
	await move_to(Vector2(0, 0))
	quest.from_dict({"completed": ["quest_main_a1_05_reclaim"]})
	check(quest.get_state(Q) == "available" and waypoint.observation_key() == &"observe.waypoint.before", "available still before even after local use")
	check(quest.accept(Q).get("ok", false), "existing S5 accepted without new quest registration")
	check(quest.to_dict().active[Q].objective_index == 0 and waypoint.observation_key() == &"observe.waypoint.active", "reach step active already uses investigation prompt")
	var before_outside = interactions
	await key_e()
	check(interactions == before_outside, "out-of-range E does not interact")
	await move_to(waypoint.global_position)
	check(quest.to_dict().active[Q].objective_index == 1, "actual reach area advances to existing interact objective")
	await key_e()
	check(last_text(hud) == "비석을 살펴보자.", "completing physical E reads active BEFORE objective emission")
	check(quest.get_state(Q) == "complete_ready", "same E advances existing S5 to complete_ready")
	await key_e()
	check(last_text(hud) == "살펴본 비석이다.", "next physical E reads after in complete_ready")
	check(quest.get_state(Q) == "complete_ready", "revisit never auto-turns-in S5")
	quest.from_dict({"active": {Q: {"objective_index": 1, "progress": {}, "branch_choice": ""}}, "completed": ["quest_main_a1_05_reclaim"]})
	var before_restore = interactions
	events.load_completed.emit(0, &"auto", true)
	check(interactions == before_restore and quest.get_state(Q) == "active", "restored active fixture plus load signal never auto-interacts")
	await key_e()
	check(last_text(hud) == "비석을 살펴보자." and quest.get_state(Q) == "complete_ready", "restored active needs physical E and shows active before advancing")
	quest.from_dict({"completed": ["quest_main_a1_05_reclaim", Q]})
	events.load_completed.emit(0, &"auto", true)
	await key_e()
	check(last_text(hud) == "살펴본 비석이다." and quest.get_state(Q) == "completed", "completed fixture plus load signal keeps after")
	check(saves == 0 and not DirAccess.dir_exists_absolute("user://saves"), "S5 observation adds no autosave")
	check(state.gold == gold_before and quest.total_exp_earned == 0, "S5 observation adds no gold or EXP")
	check(state.last_waystone == null and state.activated_waystone_ids.is_empty(), "S5 observation never activates a warp stone")
	# Existing cargo early-use ordering regression, using the same physical input path.
	quest.reset()
	var cargo = layer.spawned_by_id["cargo_pile"]
	await move_to(cargo.global_position)
	check(cargo._player_inside == player, "actual cargo Area overlap")
	var cargo_start = interactions
	await key_e()
	check(interactions == cargo_start + 1 and cargo.observation_key() == &"observe.cargo.used", "cargo early physical E records discovery once")
	quest.accept("quest_main_a1_01_arrival")
	events.npc_talked.emit(&"teo")
	check(quest.get_state("quest_main_a1_01_arrival") == "active", "cargo acceptance and talk do not auto-interact")
	await key_e()
	check(interactions == cargo_start + 2 and quest.get_state("quest_main_a1_01_arrival") == "complete_ready", "cargo explicit E after prior discovery progresses objective")
	await key_e()
	check(interactions == cargo_start + 2, "cargo one-shot repeat does not emit again")
	check(last_text(hud) == TranslationServer.translate("observe.cargo.used"), "cargo revisit observation preserved")
	# Existing D28 shared-object input/save boundary, not a new S5 warp feature.
	quest.from_dict({"active": {"quest_main_a1_04_theshard": {"objective_index": 1, "progress": {}, "branch_choice": ""}}})
	var ward = layer.spawned_by_id["ward_stone_dandelion"]
	var stone = world.get_node("Waystone1")
	await move_to(ward.global_position)
	check(ward._player_inside == player and stone.overlaps_body(player), "D28 player overlaps both actual Areas")
	var ward_start = interactions
	ui.open_menu()
	await key_e()
	check(not stone.is_active and saves == 0 and interactions == ward_start, "D28 modal E blocks both components")
	ui.close_menu()
	await key_e()
	check(stone.is_active and state.last_waystone == stone, "D28 same physical E activates actual Waystone")
	check(saves == 2 and FileAccess.file_exists("user://saves/slot0_auto.json"), "D28 existing MQ04 and first activation each autosave once")
	check(interactions == ward_start + 1 and quest.get_state("quest_main_a1_04_theshard") == "completed", "D28 same E completes existing system-giver quest")
	check(has_text(hud, TranslationServer.translate("observe.ward.active")), "D28 prior-state observation preserved")
	await key_e()
	check(saves == 2 and interactions == ward_start + 2 and quest.total_exp_earned == 5, "D28 repeat keeps repeat event but no extra save or EXP")
	print("WAYPOINT_RUNTIME_RESULT PASS=", passes, " FAIL=", failures)
	quit(0 if failures == 0 else 1)
