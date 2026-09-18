extends GutTest
const Q := "quest_side_heartland_waypoint"
var previous: Dictionary
var object: QuestObject
func before_each() -> void:
	previous = QuestSystem.to_dict().duplicate(true)
	QuestSystem.reset()
	object = load("res://scenes/world/QuestObject.tscn").instantiate()
	object.object_id = &"waypoint_stone_01"
	add_child(object)
func after_each() -> void:
	QuestSystem.from_dict(previous)
	object.queue_free()
	await get_tree().process_frame
func test_waypoint_observation_follows_quest_state_not_local_used_flag() -> void:
	assert_eq(object.observation_key(), &"observe.waypoint.before")
	object.interact()
	assert_true(object._used)
	assert_eq(object.observation_key(), &"observe.waypoint.before", "early visit never implies completed quest")
	var state := QuestSystem.to_dict()
	state["completed"] = ["quest_main_a1_05_reclaim"]
	QuestSystem.from_dict(state)
	assert_eq(QuestSystem.get_state(Q), "available")
	assert_eq(object.observation_key(), &"observe.waypoint.before")
	assert_true(QuestSystem.accept(Q).get("ok", false))
	assert_eq(object.observation_key(), &"observe.waypoint.active")
	Events.location_reached.emit(&"heartland_hilltop_waypoint")
	assert_eq(object.observation_key(), &"observe.waypoint.active")
	object.interact()
	assert_eq(QuestSystem.get_state(Q), "complete_ready")
	assert_eq(object.observation_key(), &"observe.waypoint.after")
	state = QuestSystem.to_dict()
	state["active"] = {}
	state["completed"] = ["quest_main_a1_05_reclaim", Q]
	QuestSystem.from_dict(state)
	assert_eq(object.observation_key(), &"observe.waypoint.after")
