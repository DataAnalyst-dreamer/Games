extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("DIAG_EXPECTED_USER_DIR"):
		quit(1)
		return
	var mode := OS.get_environment("DEATH_QA_MODE")
	var path := "user://saves/slot1_manual.json"
	if mode == "create" and DirAccess.dir_exists_absolute("user://saves"):
		push_error("Existing saves: refuse create overwrite")
		quit(1)
		return
	var state = root.get_node("GameState")
	var saver = root.get_node("SaveManager")
	var data = root.get_node("Data")
	var world = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(world)
	for enemy in get_nodes_in_group("monster"): enemy.queue_free()
	await process_frame
	var player = world.get_node("Player")
	var stone = world.get_node("Waystone1")
	if mode == "verify":
		var before := FileAccess.get_sha256(path)
		check(bool(saver.load(1, "manual").get("ok", false)), "fresh process load succeeds")
		check(player.resources.hp == player.resources.max_hp and player.resources.stamina == player.resources.max_stamina, "loaded full HP stamina")
		check(not player.is_dead and player.state_machine.current_state.name == &"Idle", "loaded alive Idle")
		check(player.global_position.distance_to(stone.global_position) < 1.0, "loaded waystone position")
		check(state.death_count == 1, "loaded exactly one death")
		var expected = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("DEATH_EXPECTED")))
		check(state.inventory.to_dict() == expected, "loaded original inventory exact")
		check(before == FileAccess.get_sha256(path), "read-only load leaves save unchanged")
	else:
		state.pickup_item({"uid":"death_qa_jelly","item_id":"slime_jelly","quantity":1,"grade":"common"}, data.get_value("items", "slime_jelly", {}))
		var inventory_before = state.inventory.to_dict().duplicate(true)
		var expected_file := FileAccess.open(OS.get_environment("DEATH_EXPECTED"), FileAccess.WRITE)
		expected_file.store_string(JSON.stringify(inventory_before))
		expected_file.close()
		stone.activate()
		check(bool(saver.save(1, "manual").get("ok", false)), "alive baseline save")
		var baseline := FileAccess.get_sha256(path)
		var hitbox = load("res://scripts/systems/hitbox.gd").new()
		hitbox.team = &"enemy"
		hitbox.damage = 9999
		root.add_child(hitbox)
		hitbox.activate()
		var hit_start := Time.get_ticks_msec()
		check(hitbox.try_hit(player.hurtbox), "actual lethal Hitbox accepted")
		hitbox.queue_free()
		check(player.is_dead and player.state_machine.current_state.name == &"Dead", "real Dead state")
		var denied = saver.save(1, "manual")
		check(not denied.get("ok", true) and denied.get("reason") == "player_dead", "dead save rejected")
		check(baseline == FileAccess.get_sha256(path), "dead rejection preserves baseline SHA")
		while player.is_dead and Time.get_ticks_msec() - hit_start < 10000:
			await process_frame
		check(not player.is_dead and player.state_machine.current_state.name == &"Idle", "timer respawn alive Idle")
		check(player.resources.hp == player.resources.max_hp and player.resources.stamina == player.resources.max_stamina, "respawn full HP stamina")
		check(player.global_position.distance_to(stone.global_position) < 1.0, "respawn waystone position")
		check(state.inventory.to_dict() == inventory_before and state.death_count == 1, "one death inventory preserved")
		while not state.can_save().get("ok", false) and Time.get_ticks_msec() - hit_start < 15000:
			await process_frame
		print("DEATH_SAVE_WAIT wall_ms=", Time.get_ticks_msec()-hit_start, " play_time=", state.play_time_sec)
		check(bool(saver.save(1, "manual").get("ok", false)), "after real combat lock save succeeds")
	print("DEATH_SAVE_RESULT mode=",mode," PASS=",checks-failures," FAIL=",failures)
	quit(0 if failures == 0 else 1)
