## Dedicated UI -> automatic save -> process restart integration, no backend accept/advance calls.
extends Node
const Q1 := "quest_main_a1_01_arrival"
const Q2 := "quest_main_a1_02_firstlook"
const USER_DIR := "C:/Users/freer/AppData/Roaming/Games-QA-quest-ui-save-20260913-story"
var world: Node
var player: Player
var layer: Node
var ui: UiRoot
var passes := 0
var failures := 0
var saves := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_user_data_dir().replace("\\", "/") != USER_DIR:
		push_error("QUEST_UI_SAVE_ISOLATION_FAIL")
		get_tree().quit(1)
		return
	print("QUEST_UI_SAVE_ISOLATION_PASS " + USER_DIR)
	var stage := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	if stage not in ["create", "resume", "verify"] or (stage == "create" and FileAccess.file_exists("user://saves/slot0_auto.json")):
		push_error("Invalid stage or existing fixture; refusing overwrite")
		get_tree().quit(1)
		return
	world = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	player = world.get_node("Player")
	layer = world.get_node("HartlandQuestLayer")
	ui = world.get_node("UiRoot")
	for child in world.get_children():
		if child is MonsterBase: child.queue_free()
	await get_tree().physics_frame
	Events.save_completed.connect(func(slot, kind, ok):
		if slot == 0 and kind == &"auto" and ok: saves += 1)
	if stage == "create":
		await _talk()
		_check(QuestSystem.get_state(Q1) == "available", "open does not accept")
		await _key(KEY_ENTER)
		_check(QuestSystem.get_state(Q1) == "active", "MQ01 button accepts")
		await _talk()
		await _key(KEY_ESCAPE)
		await _interact(layer.spawned_by_id["cargo_pile"])
		_check(QuestSystem.get_state(Q1) == "complete_ready", "MQ01 input objectives ready")
		await _talk()
		await _key(KEY_ENTER)
		_check(QuestSystem.get_state(Q1) == "completed" and QuestSystem.total_exp_earned == 5, "MQ01 button completes exact five EXP")
		_check(saves == 1 and FileAccess.file_exists("user://saves/slot0_auto.json"), "button completion triggers actual autosave")
		await _key(KEY_ENTER)
		_check(saves == 1 and QuestSystem.total_exp_earned == 5, "extra Enter no duplicate reward or save")
	else:
		_check(SaveManager.load(0, "auto").get("ok", false), "new process loads actual autosave")
		_check(QuestSystem.get_state(Q1) == "completed", "MQ01 completion restored")
		_check(QuestSystem.total_exp_earned == (5 if stage == "resume" else 10), "exact EXP restored")
		_check(saves == 0, "load does not trigger autosave")
		if stage == "resume":
			await _talk()
			_check(ui.quest_npc_panel.quest_id == Q2, "completed MQ01 never offered for turn-in again")
			await _key(KEY_ENTER)
			_check(QuestSystem.get_state(Q2) == "active", "MQ02 button accepts after restart")
			await _interact(layer.spawned_by_id["heartland_dandelion_village"])
			await _interact(layer.spawned_by_id["meru"])
			_check(QuestSystem.get_state(Q2) == "complete_ready", "MQ02 physical reach and talk")
			await _talk()
			await _key(KEY_ENTER)
			_check(QuestSystem.get_state(Q2) == "completed" and QuestSystem.total_exp_earned == 10, "MQ02 giver button completes exact total EXP")
			_check(saves == 1, "MQ02 button completion autosaves")
		else:
			_check(QuestSystem.get_state(Q2) == "completed", "MQ02 completion restored")
			var snapshot := QuestSystem.to_dict().duplicate(true)
			await _talk()
			_check(not ui.is_quest_npc_open(), "completed supported quests offer no repeat buttons")
			await _key(KEY_ENTER)
			_check(snapshot == QuestSystem.to_dict() and saves == 0, "post-restart input produces no duplicate reward/save")
	print("QUEST_UI_SAVE_RESULT stage=%s PASS=%d FAIL=%d" % [stage, passes, failures])
	get_tree().paused = false
	get_tree().quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame

func _talk() -> void:
	await _interact(layer.spawned_by_id["teo"])

func _interact(target: Node2D) -> void:
	player.global_position = target.global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E)
