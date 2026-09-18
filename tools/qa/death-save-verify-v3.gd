extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)

# JSON object key order is irrelevant; array order and every field are significant.
# Permit JSON's int/float representation difference without truncating fractions.
func numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
func semantic_equal(a: Variant, b: Variant) -> bool:
	if numeric(a) and numeric(b):
		return is_finite(float(a)) and is_finite(float(b)) and abs(float(a)) <= 9007199254740991.0 and abs(float(b)) <= 9007199254740991.0 and a == b
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size() or not a.has_all(b.keys()): return false
		for key in a:
			if not semantic_equal(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not semantic_equal(a[i], b[i]): return false
		return true
	return a == b
func integral(value: Variant) -> bool:
	return numeric(value) and is_finite(float(value)) and float(value) == floor(float(value)) and abs(float(value)) <= 9007199254740991.0
func comparator_tests() -> void:
	check(semantic_equal({"capacity": 0, "slots": [{"quantity": 1}]}, {"slots": [{"quantity": 1.0}], "capacity": 0.0}), "comparator accepts numeric representation and object key order")
	check(not semantic_equal(1.5, 1) and not integral(1.5), "comparator rejects fractional quantity")
	check(not semantic_equal(0.5, 0) and not integral(0.5), "comparator rejects fractional capacity")
	check(not semantic_equal(true, 1), "comparator rejects bool numeric coercion")
	check(not semantic_equal("1", 1), "comparator rejects string numeric coercion")
	check(not semantic_equal([{"uid":"a"}, {"uid":"b"}], [{"uid":"b"}, {"uid":"a"}]), "comparator preserves slot order")
	check(not semantic_equal({"uid": "a"}, {"uid": "b"}), "comparator detects changed UID")
	check(not semantic_equal({"item_id": "slime_jelly"}, {"item_id": "rabbit_horn"}), "comparator detects changed item")
	check(not semantic_equal({"grade": "common"}, {"grade": "rare"}), "comparator detects changed grade")
	check(not semantic_equal({"affixes": [{"power": 1}]}, {"affixes": [{"power": 2}]}), "comparator detects nested affix change")
	check(not semantic_equal({"a": 1}, {"a": 1, "b": null}), "comparator rejects additional field")
	check(not semantic_equal({"a": 1, "b": null}, {"a": 1}), "comparator rejects missing field")
	check(not semantic_equal([1], []), "comparator detects missing slot")
	check(not semantic_equal(INF, INF) and not semantic_equal(NAN, NAN), "comparator rejects nonfinite values")
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("DIAG_EXPECTED_USER_DIR"):
		quit(1)
		return
	comparator_tests()
	var path := "user://saves/slot1_manual.json"
	var before := FileAccess.get_sha256(path)
	check(before.to_upper() == "3C49EDBB0503198DAA95C6EC479E037E0F6128189CBB2915035AE90EFF3E670D", "original manual fixture SHA exact")
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	var expected = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("DEATH_EXPECTED")))
	var saved = payload.state.game_state.inventory
	var state = root.get_node("GameState")
	var world = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(world)
	for enemy in get_nodes_in_group("monster"): enemy.queue_free()
	await process_frame
	check(root.get_node("SaveManager").load(1,"manual").get("ok",false), "fresh process load")
	var actual = state.inventory.to_dict()
	print("INVENTORY expected=", JSON.stringify(expected), " actual=", JSON.stringify(actual), " saved=", JSON.stringify(saved))
	print("INVENTORY capacity values expected/actual/saved=", expected.capacity_bonus, "/", actual.capacity_bonus, "/", saved.capacity_bonus, " type codes=", typeof(expected.capacity_bonus), "/", typeof(actual.capacity_bonus), "/", typeof(saved.capacity_bonus))
	check(actual.size() == expected.size() and actual.has_all(expected.keys()), "same inventory keys")
	check(integral(actual.capacity_bonus) and integral(expected.capacity_bonus) and semantic_equal(actual.capacity_bonus, expected.capacity_bonus), "capacity exact integral equality")
	check(actual.slots.size() == expected.slots.size(), "slot count preserved")
	for i in range(mini(actual.slots.size(), expected.slots.size())):
		var a = actual.slots[i]
		var e = expected.slots[i]
		print("SLOT index=", i, " actual=", a, " expected=", e, " quantity types=", typeof(a.quantity), "/", typeof(e.quantity))
		check(a.size() == e.size() and a.has_all(e.keys()), "slot keys exact")
		check(a.uid == e.uid and a.item_id == e.item_id and a.grade == e.grade, "ordered UID item grade exact")
		check(integral(a.quantity) and integral(e.quantity) and semantic_equal(a.quantity, e.quantity) and a.quantity == 1, "quantity exact integral one")
		check(semantic_equal(a, e), "ordered slot all fields exact including optional nested fields")
	check(semantic_equal(actual, expected), "full inventory semantic equality")
	check(semantic_equal(saved, expected) and semantic_equal(saved, actual), "saved expected loaded three-way full inventory equality")
	var player = world.get_node("Player")
	check(player.resources.hp == player.resources.max_hp and player.resources.stamina == player.resources.max_stamina, "loaded full resources")
	check(not player.is_dead and player.state_machine.current_state.name == &"Idle", "loaded alive Idle")
	check(player.global_position.distance_to(world.get_node("Waystone1").global_position) < 1.0 and state.death_count == 1, "loaded location death count")
	check(before == FileAccess.get_sha256(path), "save SHA unchanged")
	print("DEATH_SAVE_RESULT mode=verify PASS=", checks-failures, " FAIL=", failures)
	quit(0 if failures == 0 else 1)
