## Run ONLY in a pre-probed isolated project copy. Never deletes saved files.
extends Node

const Q1 := "quest_main_a1_01_arrival"
const Q2 := "quest_main_a1_02_firstlook"
const LOCATION := "heartland_dandelion_village"
var _main: Node
var _player: Player
var _trigger: QuestTrigger
var _pass := 0
var _fail := 0
var _events := 0

func _ready() -> void:
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-user-dir="): expected = arg.trim_prefix("--expected-user-dir=")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	print("ISOLATION_ACTUAL=" + actual)
	print("ISOLATION_EXPECTED=" + expected)
	if expected != actual or actual.get_file() != "Games-QA-quest-slice-20260913-classes" or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("ISOLATION_FAIL: no quest tests permitted")
		get_tree().quit(1)
		return
	print("ISOLATION_PASS")
	Events.location_reached.connect(_on_reach)
	await _fresh_world()
	await _visit_before_accept()
	await _fresh_world()
	await _accept_while_inside()
	await _fresh_world()
	await _ordinary_duplicate_check()
	await _fresh_world()
	await _load_inside_pending_goal()
	await _fresh_world()
	await _repeatable_volume_check()
	await _fresh_world()
	await _next_objective_while_inside()
	print("QUEST_TRIGGER_ORDER PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _check(label: String, ok: bool) -> void:
	if ok: _pass += 1
	else: _fail += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func _on_reach(id: StringName) -> void:
	if id == StringName(LOCATION): _events += 1

func _frames() -> void:
	for i in 5: await get_tree().physics_frame
	await get_tree().process_frame

func _fresh_world() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		await get_tree().process_frame
	QuestSystem.reset()
	# Existing predecessor completion fixture; no acceptance/progress event spoofing.
	QuestSystem.from_dict({"completed": [Q1]})
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_trigger = _main.get_node("HartlandQuestLayer").spawned_by_id[LOCATION] as QuestTrigger
	for child in _main.get_children():
		if child is MonsterBase: child.queue_free()
	_player.global_position = Vector2(1800, 1800)
	await _frames()
	_events = 0

func _move(position_value: Vector2) -> void:
	_player.global_position = position_value
	await _frames()

func _visit_before_accept() -> void:
	await _move(_trigger.global_position)
	_check("initial pre-quest visit still emits discovery", _events == 1)
	await _move(Vector2(1800, 1800))
	_check("MQ02 can be accepted after early visit", QuestSystem.accept(Q2).get("ok", false))
	await _frames()
	_check("acceptance outside does not award location", QuestSystem.get_active_objective_index(Q2) == 0)
	await _move(_trigger.global_position)
	_check("early visit does not consume later reach objective", QuestSystem.get_active_objective_index(Q2) == 1)

func _accept_while_inside() -> void:
	await _move(_trigger.global_position)
	_check("MQ02 accepted while player already inside", QuestSystem.accept(Q2).get("ok", false))
	await _frames()
	_check("inside acceptance awards current reach without leaving", QuestSystem.get_active_objective_index(Q2) == 1)
	var before := _events
	await _frames()
	_check("deferred notifications do not loop reach events", _events == before)

func _ordinary_duplicate_check() -> void:
	QuestSystem.accept(Q2)
	var keys := QuestSystem.get_active_reach_objective_keys(StringName(LOCATION))
	keys.clear()
	_check("reach lookup returns detached keys", not QuestSystem.get_active_reach_objective_keys(StringName(LOCATION)).is_empty())
	await _move(_trigger.global_position)
	_check("ordinary accepted quest reaches target", QuestSystem.get_active_objective_index(Q2) == 1)
	var before := _events
	await _move(Vector2(1800, 1800))
	await _move(_trigger.global_position)
	_check("completed reach emits no duplicate on revisit", _events == before)
	_check("reach cannot complete following talk objective", QuestSystem.get_state(Q2) == "active" and QuestSystem.get_active_objective_index(Q2) == 1)

func _load_inside_pending_goal() -> void:
	# Dedicated QA slot only. Preserve any prior fixture; never delete or overwrite it.
	if not FileAccess.file_exists("user://saves/slot2_manual.json"):
		QuestSystem.accept(Q2)
		_player.global_position = _trigger.global_position
		# Save before physics awards reach: loading inside must reevaluate this pending goal.
		_check("isolated pending-goal fixture saved", SaveManager.save(2, "manual").get("ok", false))
	else:
		print("Reusing preserved isolated slot2 pending-goal fixture")
		_check("isolated pending-goal fixture preserved", true)
	await _move(_trigger.global_position)
	var restored: Dictionary = SaveManager.load(2, "manual")
	_check("pending-goal save loads successfully", restored.get("ok", false))
	_check("loaded fixture starts with pending reach inside", QuestSystem.get_active_objective_index(Q2) == 0 and _player.global_position.is_equal_approx(_trigger.global_position))
	var before := _events
	await _frames()
	_check("load while already overlapping awards pending reach", QuestSystem.get_active_objective_index(Q2) == 1)
	_check("load recheck emits once", _events == before + 1)
	await _frames()
	_check("load recheck does not loop", _events == before + 1)
	# Separate completed-state QA fixture; no dependency on another test's autosave slot.
	if not FileAccess.file_exists("user://saves/slot2_auto.json"):
		QuestSystem.from_dict({"completed": [Q1, Q2]})
		_check("isolated completed-state fixture saved", SaveManager.save(2, "auto").get("ok", false))
	else:
		_check("isolated completed-state fixture preserved", true)
	_check("completed QA save loads", SaveManager.load(2, "auto").get("ok", false))
	before = _events
	await _move(_trigger.global_position)
	_check("completed save stays complete without duplicate reach", QuestSystem.get_state(Q2) == "completed" and _events == before)

func _repeatable_volume_check() -> void:
	_trigger.one_shot = false
	await _move(_trigger.global_position)
	await _move(Vector2(1800, 1800))
	await _move(_trigger.global_position)
	_check("non-one-shot volume still emits on every entry", _events == 2)

func _next_objective_while_inside() -> void:
	const QUEST := "quest_main_a1_06_echocave"
	QuestSystem.from_dict({"completed": ["quest_main_a1_05_reclaim"]})
	var layer := _main.get_node("HartlandQuestLayer")
	var cave: QuestTrigger = layer.spawned_by_id["heartland_echo_cave_entrance"]
	await _move(cave.global_position)
	_check("later reach quest accepted inside its location", QuestSystem.accept(QUEST).get("ok", false))
	await _frames()
	_check("inside location does not skip preceding talk", QuestSystem.get_active_objective_index(QUEST) == 0)
	# Public NPC signal entrypoint isolates objective transition; this is not a range/UI test.
	layer.spawned_by_id["teo"].talk()
	await _frames()
	_check("newly active reach awards already-overlapping location", QuestSystem.get_active_objective_index(QUEST) == 2)
	_check("location does not skip following interact", QuestSystem.get_state(QUEST) == "active")
