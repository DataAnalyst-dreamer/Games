## Physical E / pre-exploration / actual file restore. Fresh QA-only fixture.
extends Node
const Q1 := "quest_main_a1_01_arrival"
const USER_DIR := "C:/Users/freer/AppData/Roaming/Games-QA-object-observation-20260913-story"
var passes := 0
var failures := 0
var signals_seen := 0
var world: Node
var player: Player
var cargo: QuestObject

func _ready() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != USER_DIR:
		push_error("OBJECT_SAVE_ISOLATION_FAIL")
		get_tree().quit(1)
		return
	var verify := "--verify" in OS.get_cmdline_user_args()
	if not verify and FileAccess.file_exists("user://saves/slot2_manual.json"):
		push_error("Existing fixture: refusing overwrite")
		get_tree().quit(1)
		return
	print("OBJECT_SAVE_ISOLATION_PASS " + USER_DIR)
	world = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	player = world.get_node("Player")
	cargo = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	Events.object_interacted.connect(func(_id): signals_seen += 1)
	if not verify:
		QuestSystem.reset()
		await _cargo_input()
		_check(signals_seen == 1 and QuestSystem.get_state(Q1) == "available", "pre-quest E preserves first-discovery signal")
		QuestSystem.accept(Q1)
		Events.npc_talked.emit(&"teo")
		_check(QuestSystem.get_state(Q1) == "active" and signals_seen == 1, "accept/later objective never auto-interacts")
		_check(SaveManager.save(2, "manual").get("ok", false), "fresh active objective saved to actual QA file")
		await _cargo_input()
		_check(QuestSystem.get_state(Q1) == "complete_ready" and signals_seen == 2, "explicit E revisits previously used cargo")
		await _key()
		_check(signals_seen == 2, "repeated E no duplicate quest signal")
	var before_load := signals_seen
	_check(SaveManager.load(2, "manual").get("ok", false), "actual partial save loads")
	_check(QuestSystem.get_state(Q1) == "active" and signals_seen == before_load, "load leaves objective active without interaction")
	await _cargo_input()
	_check(QuestSystem.get_state(Q1) == "complete_ready" and signals_seen == before_load + 1, "explicit E after file load completes objective")
	await _key()
	_check(signals_seen == before_load + 1 and QuestSystem.total_exp_earned == 0, "repeat after restore has no duplicate signal or reward")
	print("OBJECT_OBSERVATION_SAVE_RESULT mode=%s PASS=%d FAIL=%d" % ["verify" if verify else "create", passes, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func _cargo_input() -> void:
	player.global_position = cargo.global_position
	for i in range(4): await get_tree().physics_frame
	await _key()

func _key() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
