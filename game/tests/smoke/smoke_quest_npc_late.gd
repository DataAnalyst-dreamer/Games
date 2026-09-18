## UI slice: prior completions and objective events are fixtures, not a full cave playthrough.
extends Node
const Q6 := "quest_main_a1_06_echocave"
const Q7 := "quest_main_a1_07_fiveroads"
var panel: QuestNpcPanel
var passes := 0
var failures := 0
func _ready() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != "C:/Users/freer/AppData/Roaming/Games-QA-npc-greeting-20260913-story":
		get_tree().quit(1)
		return
	print("LATE_PANEL_ISOLATION_PASS")
	Events.main_quest_stage_completed.disconnect(SaveManager._on_autosave_trigger)
	TranslationServer.set_locale("ko")
	panel = QuestNpcPanel.new()
	panel.theme = load("res://ui/theme.tres")
	add_child(panel)
	panel.close_requested.connect(func(): panel.hide())
	QuestSystem.reset()
	_check(QuestSystem.get_state(Q6) == "locked" and QuestSystem.get_state(Q7) == "locked", "late quests locked before prerequisites")
	var prior := ["quest_main_a1_01_arrival","quest_main_a1_02_firstlook","quest_main_a1_03_shadowfall","quest_main_a1_04_theshard","quest_main_a1_05_reclaim"]
	QuestSystem.from_dict({"completed":prior})
	_check(QuestSystem.get_state(Q6) == "available" and QuestSystem.get_state(Q7) == "locked", "MQ05 fixture unlocks only MQ06")
	_check(not panel.open_for_npc(&"meru"), "non-giver rejected")
	_check(panel.open_for_npc(&"teo") and panel.quest_id == Q6, "Teo offers MQ06")
	await _bounds("MQ06 offer")
	await _enter()
	_check(QuestSystem.get_state(Q6) == "active" and not panel.visible, "MQ06 button accepts")
	await _enter()
	_check(QuestSystem.get_active_objective_index(Q6) == 0, "extra accept does not advance")
	var signals := ["talk","reach","interact","collect"]
	for index in range(4):
		panel.open_for_npc(&"teo")
		var def: Dictionary = Data.get_value("quests",Q6,{})
		var expected := tr(StringName(def.objectives[index].text_key))
		_check(panel.body_label.text.ends_with(expected) and panel.confirm_button.disabled,"MQ06 current objective %d" % index)
		await _bounds("MQ06 objective %d" % index)
		if index == 2 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png("C:/Users/freer/ClaudeProject/make-passive-income/Games/docs/qa/quest-npc-mq06-v1.png") == OK,"MQ06 actual capture")
		panel.hide()
		match signals[index]:
			"talk": Events.npc_talked.emit(&"teo")
			"reach": Events.location_reached.emit(&"heartland_echo_cave_entrance")
			"interact": Events.object_interacted.emit(&"echo_cave_puzzle_01")
			"collect": Events.item_acquired.emit(&"iron_ore",1)
	panel.open_for_npc(&"teo")
	_check(QuestSystem.get_state(Q6) == "complete_ready" and not panel.confirm_button.disabled,"MQ06 completion button ready")
	await _bounds("MQ06 ready")
	await _enter()
	_check(QuestSystem.get_state(Q6) == "completed" and QuestSystem.total_exp_earned == 25,"MQ06 reward exact")
	var snap := QuestSystem.to_dict().duplicate(true)
	var gold := GameState.gold
	var inventory := GameState.inventory.slots.duplicate(true)
	await _enter()
	_check(snap == QuestSystem.to_dict() and gold == GameState.gold and inventory == GameState.inventory.slots,"MQ06 duplicate confirm changes nothing")
	_check(panel.open_for_npc(&"teo") and panel.quest_id == Q7,"MQ07 offered after MQ06")
	await _bounds("MQ07 offer")
	await _enter()
	_check(QuestSystem.get_state(Q7) == "active","MQ07 button accepts")
	for index in range(2):
		panel.open_for_npc(&"teo")
		var def: Dictionary = Data.get_value("quests",Q7,{})
		_check(panel.body_label.text.ends_with(tr(StringName(def.objectives[index].text_key))) and panel.confirm_button.disabled,"MQ07 current objective %d" % index)
		await _bounds("MQ07 objective %d" % index)
		panel.hide()
		if index == 0: Events.location_reached.emit(&"heartland_ward_stone")
		else: Events.npc_talked.emit(&"teo")
	panel.open_for_npc(&"teo")
	_check(QuestSystem.get_state(Q7) == "complete_ready" and not panel.confirm_button.disabled,"MQ07 ready")
	await _bounds("MQ07 ready")
	await _enter()
	_check(QuestSystem.get_state(Q7) == "completed" and QuestSystem.total_exp_earned == 45,"MQ07 reward exact")
	snap = QuestSystem.to_dict().duplicate(true)
	gold = GameState.gold
	inventory = GameState.inventory.slots.duplicate(true)
	await _enter()
	_check(snap == QuestSystem.to_dict() and gold == GameState.gold and inventory == GameState.inventory.slots,"MQ07 duplicate confirm changes nothing")
	_check(not panel.open_for_npc(&"teo"),"completed quests not reoffered")
	print("LATE_PANEL_RESULT PASS=%d FAIL=%d" % [passes,failures])
	get_tree().quit(0 if failures == 0 else 1)
func _check(ok: bool, message: String) -> void:
	if ok: passes += 1
	else: failures += 1
	print("[PASS] " if ok else "[FAIL] ",message)
func _enter() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame
func _bounds(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var body := panel.body_label
	var needed := body.get_line_count() * body.get_line_height()
	_check(not body.text.contains("quest_main_") and needed <= body.size.y and body.get_global_rect().end.y <= panel.confirm_button.get_global_rect().position.y and panel.close_button.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y,label+" full text bounds")
