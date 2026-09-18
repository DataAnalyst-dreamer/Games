extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/"):
		quit(41)
		return
	root.mode = Window.MODE_WINDOWED
	var main: Node2D = load("res://Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.player != null, "Main actual player instantiated")
	main.combat.set_physics_process(false)
	main.player.facing = Vector2.DOWN
	main.player.set_phase("idle")
	check(main.player.uses_fin() and main.player._sprite.texture.get_size() == Vector2(66, 96), "approved Fin south idle loaded at native size")
	check(not main.player._weapon_front.visible and not main.player._glove.visible, "Fin embedded equipment has no duplicate weapon")
	main.player.moving = true
	main.player._walk_distance = 46.0
	check(main.player.fin_frame() == 3, "walk frames follow travelled distance at 23px per frame")
	main.player.moving = false
	check(main.player.fin_frame() == 0, "stopping returns original pose")
	main.player.set_phase("startup", 0.05)
	check(not main.player.uses_fin() and main.player._sprite.region_enabled, "attack restores existing proxy and rig")
	main.player.reset_actor(100)
	check(main.combat != null, "Main actual combat instantiated")
	check(main.world.is_walkable(main.player.position), "player spawn walkable")
	check(main.world.is_walkable(main.world.get_spawn_points().slimes[0]), "slime spawn walkable")
	check(main.actors.y_sort_enabled, "actors and tree use Y sorting")
	check(main.actors.get_node("TreeForeground").texture != null, "foreground uses real background texture")
	check(not main.shake_enabled and main.camera.offset == Vector2.ZERO, "shake disabled by default")
	check(main.hud.text.contains("HP"), "localized HUD populated")
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "logical FHD")
	check(ProjectSettings.get_setting("display/window/size/mode") == Window.MODE_EXCLUSIVE_FULLSCREEN, "exclusive fullscreen configured")
	check(not FileAccess.file_exists("user://save.json"), "specified save.json absent; not an exhaustive write audit")
	main.queue_free()
	await process_frame
	print("QUARTER_SMOKE_RESULT PASS=%d FAIL=%d" % [checks-failures, failures])
	quit(0 if failures == 0 else 1)
