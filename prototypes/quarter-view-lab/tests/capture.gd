extends SceneTree
var main: Node2D
var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + description)
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
func screenshot(filename: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture.get_size() == Vector2i(1920,1080), filename + " actual viewport FHD")
	check(picture.save_png("user://"+filename) == OK, filename + " saved")
	return picture
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/"):
		quit(41)
		return
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await frames(12)
	var start: Vector2 = main.player.position
	key(KEY_D,true)
	await frames(18)
	key(KEY_D,false)
	await frames(2)
	check(main.player.position.x > start.x+20, "actual Main physical D moves player")
	key(KEY_SPACE,true)
	await frames(2)
	check(main.player.phase == "startup", "actual Main Space starts attack startup")
	key(KEY_SPACE,false)
	await frames(18)
	key(KEY_H,true); key(KEY_H,false)
	await frames(2)
	check(main.shake_enabled, "actual H enables optional shake")
	key(KEY_H,true); key(KEY_H,false)
	await frames(2)
	check(not main.shake_enabled, "actual H restores shake off")
	key(KEY_F11,true); key(KEY_F11,false)
	await frames(6)
	check(root.mode == Window.MODE_WINDOWED, "actual F11 window mode")
	key(KEY_F11,true); key(KEY_F11,false)
	await frames(8)
	check(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "actual F11 exclusive fullscreen")
	key(KEY_R,true); key(KEY_R,false)
	await frames(2)
	check(main.player.position.distance_to(start) < 1.0 and main.player.hp == main.player.max_hp, "actual R resets encounter")
	var click := InputEventMouseButton.new()
	click.position = Vector2(100,50)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await frames(2)
	check(main.player.phase == "startup", "mouse click over HUD reaches actual combat")
	click.pressed = false
	Input.parse_input_event(click)
	key(KEY_R,true); key(KEY_R,false)
	await frames(2)
	main.combat.set_physics_process(false)
	var picture: Image = await screenshot("quarter-view-fhd.png")
	check(picture.get_pixel(1910,500).r > 0.05 and picture.get_pixel(10,500).g > 0.05, "left and right edges contain background")
	main.player.position = main.world.mapped(Vector2(220,590))
	await frames(2)
	var behind: Image = await screenshot("tree-behind.png")
	main.actors.get_node("TreeForeground").visible = false
	await frames(2)
	var exposed: Image = await screenshot("tree-mask-off.png")
	var changed := 0
	# Same opaque helmet-centre approach as the front check below.
	for y in range(635,644):
		for x in range(245,260):
			if behind.get_pixel(x,y) != exposed.get_pixel(x,y): changed += 1
	check(changed > 20, "behind opaque helmet centre changes when canopy mask is removed")
	main.actors.get_node("TreeForeground").visible = true
	main.player.position = main.world.mapped(Vector2(100,710))
	await frames(2)
	var front: Image = await screenshot("tree-front.png")
	main.actors.get_node("TreeForeground").visible = false
	await frames(2)
	await RenderingServer.frame_post_draw
	var front_off := root.get_texture().get_image()
	var front_changed := 0
	# Compare the opaque helmet centre only: the broad surrounding rectangle also
	# contains background UV edge resampling and is not an actor-occlusion oracle.
	for y in range(773,782):
		for x in range(105,120):
			if front.get_pixel(x,y) != front_off.get_pixel(x,y): front_changed += 1
	print("OCCLUSION behind_changed_pixels=%d front_helmet_changed_pixels=%d" % [changed,front_changed])
	check(front_changed == 0 and main.player.position.y > main.actors.get_node("TreeForeground").position.y, "front opaque helmet remains visible; foot sorts after tree")
	print("QUARTER_CAPTURE_RESULT PASS=%d FAIL=%d" % [passed,failed])
	call_deferred("finish")
func finish() -> void:
	main.queue_free()
	main = null
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
