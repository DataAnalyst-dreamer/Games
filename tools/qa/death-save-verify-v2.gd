extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("DIAG_EXPECTED_USER_DIR"):
		quit(1)
		return
	var path := "user://saves/slot1_manual.json"
	var before := FileAccess.get_sha256(path)
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	var expected = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("DEATH_EXPECTED")))
	var state = root.get_node("GameState")
	var world = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(world)
	for enemy in get_nodes_in_group("monster"): enemy.queue_free()
	await process_frame
	check(root.get_node("SaveManager").load(1,"manual").get("ok",false), "fresh process load")
	var actual = state.inventory.to_dict()
	print("INVENTORY expected=", JSON.stringify(expected), " actual=", JSON.stringify(actual), " saved=",JSON.stringify(payload.state.game_state.inventory))
	print("INVENTORY keys expected=",expected.keys()," actual=",actual.keys()," capacity types=",typeof(expected.capacity_bonus),"/",typeof(actual.capacity_bonus))
	check(actual.size() == expected.size() and actual.has_all(expected.keys()), "same inventory keys")
	check(int(actual.capacity_bonus) == int(expected.capacity_bonus), "capacity semantic equality")
	check(actual.slots.size() == expected.slots.size(), "slot count preserved")
	for i in range(mini(actual.slots.size(),expected.slots.size())):
		var a = actual.slots[i]
		var e = expected.slots[i]
		print("SLOT index=",i," actual=",a," expected=",e," quantity types=",typeof(a.quantity),"/",typeof(e.quantity))
		check(a.size() == e.size() and a.has_all(e.keys()), "slot keys exact")
		check(a.uid == e.uid and a.item_id == e.item_id and a.grade == e.grade, "ordered UID item grade exact")
		check(float(a.quantity) == float(e.quantity) and int(a.quantity) == 1, "quantity exact one")
	check(JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected)), "normalized inventory exact")
	var player = world.get_node("Player")
	check(player.resources.hp == player.resources.max_hp and player.resources.stamina == player.resources.max_stamina, "loaded full resources")
	check(not player.is_dead and player.state_machine.current_state.name == &"Idle", "loaded alive Idle")
	check(player.global_position.distance_to(world.get_node("Waystone1").global_position)<1.0 and state.death_count==1, "loaded location death count")
	check(before == FileAccess.get_sha256(path), "save SHA unchanged")
	print("DEATH_SAVE_RESULT mode=verify PASS=",checks-failures," FAIL=",failures)
	quit(0 if failures==0 else 1)
