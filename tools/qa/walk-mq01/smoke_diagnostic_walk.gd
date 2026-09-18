extends Node
const Q := "quest_main_a1_01_arrival"
var player: Player
var world: Node
var ui: UiRoot
var frames := 0
var died := false
var held: Array[int] = []
var saves := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var expected := OS.get_environment("DIAGNOSTIC_EXPECTED_USER_DIR")
	if OS.get_user_data_dir().replace("\\","/") != expected or FileAccess.file_exists("user://saves/slot0_auto.json"):
		_fail("isolation or existing fixture")
		return
	for icon_id in ["slime-jelly","rabbit-horn","mushroom-cap"]:
		if not load("res://assets/generated/items/item-"+icon_id+"-v1.png") is Texture2D:
			_fail("material texture load "+icon_id)
			return
	print("DIAGNOSTIC_THREE_TEXTURES_PASS")
	Events.player_died.connect(func(): died = true)
	Events.save_completed.connect(func(slot,kind,ok):
		if slot==0 and kind==&"auto" and ok: saves+=1)
	world=load("res://scenes/main/Main.tscn").instantiate()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	player=world.get_node("Player")
	ui=world.get_node("UiRoot")
	print("WALK_START position=",player.global_position," monsters=",get_tree().get_nodes_in_group("monster").size())
	if not await _walk(Vector2(-300,0)): return
	if not await _walk(Vector2(-350,135)): return
	await _press(KEY_E)
	if not ui.is_quest_npc_open() or ui.quest_npc_panel.quest_id!=Q:
		_fail("MQ01 offer absent")
		return
	await _press(KEY_ENTER)
	if QuestSystem.get_state(Q)!="active":
		_fail("accept button failed")
		return
	await _press(KEY_E)
	await _press(KEY_ESCAPE)
	if not await _walk(Vector2(-390,175)): return
	var objects = world.get_node("HartlandQuestLayer").spawned_by_id
	print("CARGO_DIAG cargo_overlap=",objects["cargo_pile"].overlaps_body(player)," teo_overlap=",objects["teo"].overlaps_body(player)," objective=",QuestSystem.get_active_objective_index(Q)," position=",player.global_position)
	if not objects["cargo_pile"].overlaps_body(player) or objects["teo"].overlaps_body(player):
		_fail("cargo approach overlap guard")
		return
	await _press(KEY_E)
	print("CARGO_AFTER state=",QuestSystem.get_state(Q)," objective=",QuestSystem.get_active_objective_index(Q))
	if QuestSystem.get_state(Q)!="complete_ready":
		_fail("cargo explicit E did not ready")
		return
	if not await _walk(Vector2(-350,135)): return
	await _press(KEY_E)
	await _press(KEY_ENTER)
	if died or QuestSystem.get_state(Q)!="completed" or saves!=1 or not FileAccess.file_exists("user://saves/slot0_auto.json"):
		_fail("completion/autosave check")
		return
	print("WALK_MQ01_RESULT PASS frames=",frames," saves=",saves," exp=",QuestSystem.total_exp_earned," position=",player.global_position)
	get_tree().quit(0)
func _walk(target: Vector2) -> bool:
	while player.global_position.distance_to(target)>6:
		if died or frames>=7200:
			_release()
			_fail("death or 120sec simulation timeout target="+str(target))
			return false
		var offset:=target-player.global_position
		var wanted: Array[int]=[]
		if absf(offset.x)>4: wanted.append(KEY_D if offset.x>0 else KEY_A)
		if absf(offset.y)>4: wanted.append(KEY_S if offset.y>0 else KEY_W)
		for code in held:
			if code not in wanted: _event(code,false)
		for code in wanted:
			if code not in held: _event(code,true)
		held=wanted
		await get_tree().physics_frame
		frames+=1
	_release()
	for i in range(3): await get_tree().physics_frame
	print("WALK_WAYPOINT target=",target," actual=",player.global_position," frames=",frames)
	return true
func _release() -> void:
	for code in held: _event(code,false)
	held.clear()
func _event(code: int,down: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	Input.parse_input_event(event)
func _press(code: int) -> void:
	_event(code,true)
	await get_tree().process_frame
	_event(code,false)
	await get_tree().process_frame
func _fail(reason: String) -> void:
	_release()
	print("WALK_MQ01_RESULT FAIL reason=",reason," frames=",frames)
	get_tree().paused=false
	get_tree().quit(1)




