## Isolated three-process MQ01/MQ02 integration sidecar. Never run on normal user data.
## Requires --expected-user-dir=<dedicated absolute path> --slice-stage=prepare|resume|verify.
## Acceptance/turn-in use current public API (the game has no corresponding UI yet).
extends Node

const Q1 := "quest_main_a1_01_arrival"
const Q2 := "quest_main_a1_02_firstlook"
const QA_DIR_NAME := "Games-QA-quest-slice-20260913-classes"
var _main: Node
var _player: Player
var _layer: Node
var _passes := 0
var _fails := 0
var _saved := 0

func _ready() -> void:
	var expected := ""
	var stage := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expected-user-dir="): expected = arg.trim_prefix("--expected-user-dir=").replace("\\", "/").simplify_path()
		if arg.begins_with("--slice-stage="): stage = arg.trim_prefix("--slice-stage=")
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	print("ISOLATION_ACTUAL=" + actual)
	print("ISOLATION_EXPECTED=" + expected)
	if expected.is_empty() or actual.to_lower() != expected.to_lower() or actual.get_file() != QA_DIR_NAME or not ProjectSettings.get_setting("application/config/use_custom_user_dir", false):
		push_error("ISOLATION_FAIL: save tests refused")
		get_tree().quit(1)
		return
	if stage not in ["prepare", "resume", "verify"]:
		push_error("Invalid slice stage")
		get_tree().quit(1)
		return
	print("ISOLATION_PASS")
	# Fresh dedicated directory required; preserve artifacts rather than deleting anything.
	if stage == "prepare" and FileAccess.file_exists("user://saves/slot0_auto.json"):
		push_error("Existing QA save: prepare refuses overwrite; use a fresh isolated run")
		get_tree().quit(1)
		return
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_layer = _main.get_node("HartlandQuestLayer")
	# Remove only instantiated test-world opponents to avoid incidental combat/autosave refusal.
	for child in _main.get_children():
		if child is MonsterBase: child.queue_free()
	await get_tree().physics_frame
	Events.save_completed.connect(_on_save)
	if stage == "prepare": await _prepare()
	elif stage == "resume": await _resume()
	else: _verify()
	print("QUEST_SAVE_SLICE stage=%s PASS=%d FAIL=%d" % [stage, _passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func _check(label: String, ok: bool) -> void:
	if ok: _passes += 1
	else: _fails += 1
	print(("[PASS] " if ok else "[FAIL] ") + label)

func _on_save(slot: int, kind: StringName, ok: bool) -> void:
	if slot == 0 and kind == &"auto" and ok: _saved += 1

func _enter(target: Node2D) -> void:
	_player.global_position = target.global_position
	for i in 4: await get_tree().physics_frame

func _interact(target: Node2D) -> void:
	await _enter(target)
	_check("physical interaction overlap: " + target.name, target.get("_player_inside") == _player)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = &"interact"
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _prepare() -> void:
	_check("MQ01 accept via public API", QuestSystem.accept(Q1).get("ok", false))
	await _interact(_layer.spawned_by_id["teo"])
	_check("MQ01 talk advanced through input", QuestSystem.get_active_objective_index(Q1) == 1)
	await _interact(_main.get_node("Waystone1"))
	_check("waystone activated through input", _main.get_node("Waystone1").is_active)
	_check("waystone actual autosave", _saved == 1 and FileAccess.file_exists("user://saves/slot0_auto.json"))
	_check("MQ01 remains partial", QuestSystem.get_state(Q1) == "active")

func _resume() -> void:
	_check("restart loads waystone autosave", SaveManager.load(0, "auto").get("ok", false))
	_check("partial objective restored", QuestSystem.get_state(Q1) == "active" and QuestSystem.get_active_objective_index(Q1) == 1)
	_check("waystone silently restored", _main.get_node("Waystone1").is_active and _saved == 0)
	await _interact(_layer.spawned_by_id["cargo_pile"])
	_check("MQ01 cargo input complete_ready", QuestSystem.get_state(Q1) == "complete_ready")
	_turn_in(Q1)
	_check("MQ02 accept unlocked", QuestSystem.accept(Q2).get("ok", false))
	await _enter(_layer.spawned_by_id["heartland_dandelion_village"])
	_check("MQ02 physical reach progressed", QuestSystem.get_active_objective_index(Q2) == 1)
	await _interact(_layer.spawned_by_id["meru"])
	_check("MQ02 talk complete_ready", QuestSystem.get_state(Q2) == "complete_ready")
	_turn_in(Q2)
	_check("both main turn-ins autosaved", _saved == 2)

func _reward_state() -> Dictionary:
	return {"gold": GameState.gold, "inventory": GameState.inventory.to_dict(), "mailbox": GameState.mailbox.to_dict(), "quest": QuestSystem.to_dict()}

func _turn_in(id: String) -> void:
	var before_gold: int = GameState.gold
	var before_exp: int = QuestSystem.total_exp_earned
	var rewards: Dictionary = QuestSystem._quest_def(id).get("rewards", {})
	_check(id + " first turn-in succeeds", QuestSystem.advance(id).get("ok", false))
	_check(id + " exact existing gold reward", GameState.gold - before_gold == int(rewards.get("gold", 0)))
	_check(id + " exact existing exp reward", QuestSystem.total_exp_earned - before_exp == int(rewards.get("exp", 0)))
	var snapshot := _reward_state().duplicate(true)
	_check(id + " duplicate turn-in refused", not QuestSystem.advance(id).get("ok", false))
	_check(id + " duplicate leaves reward state unchanged", snapshot == _reward_state())

func _verify() -> void:
	_check("second restart loads completion autosave", SaveManager.load(0, "auto").get("ok", false))
	_check("both completions survive process restart", QuestSystem.get_state(Q1) == "completed" and QuestSystem.get_state(Q2) == "completed")
	var expected_exp := int(QuestSystem._quest_def(Q1).get("rewards", {}).get("exp", 0)) + int(QuestSystem._quest_def(Q2).get("rewards", {}).get("exp", 0))
	_check("earned exp survives process restart", QuestSystem.total_exp_earned == expected_exp)
	var snapshot := _reward_state().duplicate(true)
	_check("MQ01 replay refused after restart", not QuestSystem.advance(Q1).get("ok", false))
	_check("MQ02 replay refused after restart", not QuestSystem.advance(Q2).get("ok", false))
	_check("restart replay produces zero duplicate rewards", snapshot == _reward_state())
	_check("restore/replay does not autosave", _saved == 0)
