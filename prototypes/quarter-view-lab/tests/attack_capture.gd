extends SceneTree
## Actual Main + physical attack input; actor positions and enemy windup are a QA fixture.
var main: Node2D
var passed := 0
var failed := 0
var trace: Array[Dictionary] = []
var pictures: Dictionary = {}
var input_frame: int = -1
var first_damage_frame: int = -1
var initial_hp: int = 0
var replay_frames: Array[Dictionary] = []
var max_grip_error := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + description)

func save_phase(label: String, image: Image) -> void:
	check(image.get_size() == Vector2i(1920,1080), label + " actual FHD readback")
	check(image.save_png("user://attack-"+label+".png") == OK, label + " saved")
	pictures[label] = true

func record_damage(snapshot: Dictionary) -> void:
	# Emitted synchronously by combat._impact after HP changes, before the draw.
	if input_frame >= 0 and first_damage_frame < 0 and int(snapshot.get("slime_hp",initial_hp)) < initial_hp:
		first_damage_frame = Engine.get_physics_frames() - input_frame

func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/"):
		quit(41)
		return
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await process_frame
	main.combat.reset_encounter()
	main.player.position = Vector2(850,735)
	main.player.facing = Vector2.RIGHT
	# Diagnostic zoom only. Main's fixed gameplay camera is not changed on disk.
	main.camera.position = Vector2(880,710)
	main.camera.zoom = Vector2(3,3)
	var slime: CharacterBody2D = main.combat.slimes[0]
	slime.position = main.player.position + Vector2(62,0)
	# Hold the enemy's pre-attack phase so its own lunge does not alter this measurement.
	slime.set_phase("telegraph",10.0)
	await physics_frame
	await process_frame
	initial_hp = slime.hp
	main.combat.status_changed.connect(record_damage)
	input_frame = Engine.get_physics_frames()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = false
	Input.parse_input_event(event)
	var idle_frame := -1
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()+"/motion")
	for sample in range(36):
		await process_frame
		await RenderingServer.frame_post_draw
		var relative_frame := Engine.get_physics_frames() - input_frame
		var attachment: Dictionary = main.player.get_weapon_attachment()
		var grip_error: float = attachment.hand_global.distance_to(attachment.hilt_global)
		max_grip_error = maxf(max_grip_error,grip_error)
		trace.append({"physics_frame_after_input":relative_frame,"phase":main.player.phase,"hp":slime.hp,"hitstop":main.combat.freeze_remaining,"phase_elapsed":main.player.phase_elapsed,"hand_global":[attachment.hand_global.x,attachment.hand_global.y],"hilt_global":[attachment.hilt_global.x,attachment.hilt_global.y],"grip_error":grip_error})
		var image := root.get_texture().get_image()
		var filename := "motion/frame-%02d.png" % sample
		if image.save_png("user://"+filename) != OK:
			failed += 1
		replay_frames.append({"file":filename,"physics_frame_after_input":relative_frame,"phase":main.player.phase})
		if main.player.phase == "startup" and not pictures.has("startup"):
			save_phase("startup",image)
		if first_damage_frame >= 0 and not pictures.has("contact"):
			save_phase("contact",image)
		if main.player.phase == "recovery" and main.player.phase_elapsed >= main.player.phase_duration * 0.6 and not pictures.has("late-recovery"):
			save_phase("late-recovery",image)
		if main.player.phase == "idle" and first_damage_frame >= 0 and idle_frame < 0:
			idle_frame = relative_frame
	check(first_damage_frame == 4, "synchronous front-target damage stays at 4 physics frames")
	check(main.combat.landed_hits == 1 and initial_hp-slime.hp == int(main.combat.config.damage), "single physical press deals exactly one configured hit")
	check(idle_frame > first_damage_frame and idle_frame < 45, "attack returns to idle within 45 physics frames")
	check(pictures.has("startup") and pictures.has("contact") and pictures.has("late-recovery"), "startup contact late-recovery all captured")
	check(max_grip_error < 0.001, "sampled attack loop hand and hilt attachment positions coincide")
	check(replay_frames.size() == 36, "36 native readbacks recorded; no raster postprocessing")
	print("ATTACK_INPUT first_damage_frame=%d idle_frame=%d physics_ticks_per_second=%d" % [first_damage_frame,idle_frame,Engine.physics_ticks_per_second])
	var output := FileAccess.open("user://attack-trace.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"fixture":"actual Main; QA camera 3x; positions injected; slime telegraph held; physical Space press; native fixed60fps clock, not manual combat ticks; first damage from synchronous status signal; idle is sampled observation upper bound; not hardware latency","input_physics_frame":input_frame,"first_damage_frame":first_damage_frame,"idle_frame":idle_frame,"trace":trace},"\t"))
	output.close()
	var template := FileAccess.get_file_as_string("res://tests/motion-preview.html")
	var preview := FileAccess.open("user://weapon-motion-preview.html",FileAccess.WRITE)
	preview.store_string(template.replace("__FRAME_DATA__",JSON.stringify(replay_frames)))
	preview.close()
	print("QUARTER_ATTACK_CAPTURE_RESULT PASS=%d FAIL=%d" % [passed,failed])
	call_deferred("finish")

func finish() -> void:
	main.combat.stop_sounds()
	main.combat._swing_audio.stream = null
	main.combat._hit_audio.stream = null
	var deadline := Time.get_ticks_msec()+200
	while Time.get_ticks_msec() < deadline:
		await process_frame
	main.queue_free()
	main = null
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
