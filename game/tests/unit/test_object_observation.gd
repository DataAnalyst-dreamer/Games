extends GutTest
var world: Node
var hud: Hud
var original_quests: Dictionary
var events_seen := 0

func before_each() -> void:
	original_quests = QuestSystem.to_dict().duplicate(true)
	QuestSystem.reset()
	world = load("res://scenes/main/Main.tscn").instantiate()
	add_child(world)
	hud = world.get_node("UiRoot").hud
	Events.object_interacted.connect(_count_event)
	events_seen = 0

func after_each() -> void:
	Events.object_interacted.disconnect(_count_event)
	QuestSystem.from_dict(original_quests)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _count_event(_id: StringName) -> void:
	events_seen += 1

func test_used_cargo_observation_does_not_repeat_quest_signal() -> void:
	var cargo: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	assert_eq(cargo.observation_key(), &"observe.cargo.before")
	cargo.interact()
	assert_eq(events_seen, 1)
	assert_eq(cargo.observation_key(), &"observe.cargo.used")
	cargo.interact()
	assert_eq(events_seen, 1, "repeat observation never re-emits one-shot event")
	assert_eq(hud.log_list.get_child(hud.log_list.get_child_count() - 1).text, tr(&"observe.cargo.used"))

func test_active_cargo_objective_and_outside_input() -> void:
	var cargo: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	QuestSystem.accept("quest_main_a1_01_arrival")
	Events.npc_talked.emit(&"teo")
	assert_eq(cargo.observation_key(), &"observe.cargo.active")
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	cargo._player_inside = null
	cargo._unhandled_input(event)
	assert_eq(events_seen, 0, "out-of-range input does not observe or progress")
	cargo.interact()
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "complete_ready")
	cargo.interact()
	assert_eq(events_seen, 1)
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "complete_ready")

func test_ward_state_reactions_and_unlisted_fallback() -> void:
	var layer = world.get_node("HartlandQuestLayer")
	var ward: QuestObject = layer.spawned_by_id["ward_stone_dandelion"]
	assert_eq(ward.observation_key(), &"observe.ward.before")
	var data := QuestSystem.to_dict()
	data["active"] = {"quest_main_a1_04_theshard": {"objective_index": 1, "progress": {}, "branch_choice": ""}}
	QuestSystem.from_dict(data)
	assert_eq(ward.observation_key(), &"observe.ward.active")
	data["active"] = {}
	data["completed"] = ["quest_main_a1_04_theshard"]
	QuestSystem.from_dict(data)
	assert_eq(ward.observation_key(), &"observe.ward.after")
	ward.interact()
	ward.interact()
	assert_eq(events_seen, 2, "repeatable ward keeps existing repeated event semantics")
	assert_eq((layer.spawned_by_id["echo_cave_puzzle_01"] as QuestObject).observation_key(), &"")

func test_observation_width_and_translation() -> void:
	var label := Label.new()
	label.theme = load("res://ui/theme.tres")
	var font := label.get_theme_font("font")
	for suffix in ["cargo.before", "cargo.active", "cargo.used", "ward.before", "ward.active", "ward.after"]:
		var key: String = "observe." + suffix
		var text := tr(key)
		assert_ne(text, key)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		print("OBSERVATION_BOUNDS %s width=%s" % [key, width])
		assert_lte(width, 154.0)
	label.free()

func test_explore_cargo_before_accepting_does_not_block_later_objective() -> void:
	var cargo: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	cargo.interact()
	QuestSystem.accept("quest_main_a1_01_arrival")
	Events.npc_talked.emit(&"teo")
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "active", "accept/talk must not auto interact")
	cargo.interact()
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "complete_ready", "explicit revisit progresses prior discovered cargo")
	cargo.interact()
	assert_eq(events_seen, 2, "first discovery + one active objective, no repeat farming")

func test_restore_active_state_requires_explicit_interaction() -> void:
	var cargo: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	QuestSystem.accept("quest_main_a1_01_arrival")
	Events.npc_talked.emit(&"teo")
	var snapshot := QuestSystem.to_dict().duplicate(true)
	cargo.interact()
	assert_eq(events_seen, 1)
	QuestSystem.from_dict(snapshot)
	Events.load_completed.emit(0, &"auto", true)
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "active")
	assert_eq(events_seen, 1, "load does not automatically interact")
	cargo.interact()
	assert_eq(QuestSystem.get_state("quest_main_a1_01_arrival"), "complete_ready")
	assert_eq(events_seen, 2)

func test_later_objective_and_repeat_acceptance_require_new_input() -> void:
	var cargo: QuestObject = world.get_node("HartlandQuestLayer").spawned_by_id["cargo_pile"]
	cargo.interact()
	QuestSystem.accept("quest_main_a1_01_arrival")
	assert_eq(events_seen, 1)
	Events.npc_talked.emit(&"teo")
	assert_eq(events_seen, 1, "later objective activation is not automatic interaction")
	cargo.interact()
	var snapshot := QuestSystem.to_dict()
	snapshot["active"] = {"quest_main_a1_01_arrival": {"objective_index": 1, "progress": {}, "branch_choice": ""}}
	QuestSystem.from_dict(snapshot)
	Events.quest_accepted.emit(&"quest_main_a1_01_arrival")
	assert_eq(events_seen, 2, "accept notification alone emits nothing")
	cargo.interact()
	assert_eq(events_seen, 3, "new acceptance epoch allows explicit use")
