extends SceneTree
## Native scene grid: actual actor render code, injected poses, not a montage edit.
var main: Node2D
var grid: CanvasLayer
var passed := 0
var failed := 0
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	if value: passed += 1
	else: failed += 1
	print(("PASS " if value else "FAIL ") + description)
func label(text: String, point: Vector2, size: int) -> void:
	var item := Label.new()
	item.text = text
	item.position = point
	item.add_theme_font_override("font",load("res://assets/Galmuri11.ttf"))
	item.add_theme_font_size_override("font_size",size)
	grid.add_child(item)
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/"):
		quit(41)
		return
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	main.combat.set_physics_process(false)
	main.visible = false
	for child in main.get_children():
		if child is CanvasLayer: child.visible = false
	grid = CanvasLayer.new()
	root.add_child(grid)
	var background := ColorRect.new()
	background.size = Vector2(1920,1080)
	background.color = Color("142522")
	grid.add_child(background)
	var words: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/grip-labels.json"))
	label(words.title,Vector2(30,18),30)
	label(words.subtitle,Vector2(30,66),21)
	var directions := [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]
	for row in range(2):
		for col in range(4):
			var panel := ColorRect.new()
			panel.position = Vector2(col*480+12,row*472+110)
			panel.size = Vector2(456,448 if row == 0 else 486)
			panel.color = Color("294138") if row == 0 else Color("20372f")
			grid.add_child(panel)
			label(str(words.directions[col])+" · "+str(words.idle if row == 0 else words.contact),panel.position+Vector2(18,14),26)
			var actor: CharacterBody2D = load("res://actor.gd").new()
			grid.add_child(actor)
			# Different contact positions keep every long blade inside its own card.
			# This is layout of injected QA poses, not a movement comparison.
			var contact_positions := [Vector2(220,840),Vector2(720,1030),Vector2(1290,900),Vector2(1590,900)]
			var actor_position: Vector2 = Vector2(col*480+240,390) if row == 0 else contact_positions[col]
			actor.configure("player",actor_position)
			actor.scale = Vector2(3,3)
			actor.set_combat(main.combat)
			actor.facing = directions[col]
			actor.attack_facing = directions[col]
			actor.set_phase("idle" if row == 0 else "active",0.085)
			if row == 1:
				actor.phase_elapsed = 0.085*actor.progress_for_blade_angle(directions[col].angle())
			actor._refresh_visual()
			actor._label.visible = false
			var attachment: Dictionary = actor.get_weapon_attachment()
			check(attachment.hand_global.distance_to(attachment.hilt_global) < 0.001,"grid %d/%d hand hilt coincide" % [row,col])
			check(bool(attachment.visible),"grid %d/%d weapon visible" % [row,col])
			records.append({"row":row,"direction":col,"art_direction":attachment.art_direction,"pose":attachment.pose,"render_order":attachment.render_order,"hand_global":[attachment.hand_global.x,attachment.hand_global.y],"hilt_global":[attachment.hilt_global.x,attachment.hilt_global.y],"blade_start_global":[attachment.blade_start_global.x,attachment.blade_start_global.y],"blade_tip_global":[attachment.blade_tip_global.x,attachment.blade_tip_global.y]})
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920,1080),"actual native grid readback FHD")
	check(image.save_png("user://weapon-grip-grid.png") == OK,"native scene grid saved without raster edits")
	var output := FileAccess.open("user://weapon-grip-grid.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"fixture":"actual actor classes at 3x scale; phase and orientation injected; no natural movement or pixel-perfect hand segmentation claim","poses":records},"\t"))
	output.close()
	print("QUARTER_GRIP_GRID_RESULT PASS=%d FAIL=%d" % [passed,failed])
	call_deferred("finish")
func finish() -> void:
	grid.queue_free()
	main.queue_free()
	grid = null
	main = null
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
