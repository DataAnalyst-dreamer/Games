extends Node2D

var config: Dictionary
var font: SystemFont
var player: CharacterBody2D
var actor: Sprite2D
var detail: Sprite2D
var idle_texture: Texture2D
var frame_textures: Array[AtlasTexture] = []
var status: Label
var arena: Rect2
var obstacles: Array[Rect2] = []
var spawn_point: Vector2
var current_frame := 0
var phase := 0.0
var paused := false
var moving := false
var auto_move := false
var auto_time := 0.0
var show_grid := true
var show_hitbox := true
var testing := false
var test_direction := Vector2.ZERO
var failures: Array[String] = []
var screenshot_path := ""
var screenshot_only := false
var frame_count := 0
var walk_frame_count := 8
var frame_duration_sec := 0.0 # Zero keeps legacy distance-based playback.
var loaded_ok := false


func _pair(value: Variant, positive: bool) -> bool:
	if not value is Array or value.size() != 2: return false
	for part in value:
		if not (part is int or part is float): return false
		if not is_finite(float(part)) or float(part) != floor(float(part)): return false
		if float(part) < (1.0 if positive else 0.0): return false
	return true


func _asset_config_error(candidate: Dictionary, atlas_size: Vector2, idle_size: Vector2) -> String:
	var cell: Variant = candidate.get("cell", [96, 128])
	var pivot: Variant = candidate.get("foot_anchor", [48, 112])
	var count: Variant = candidate.get("frame_count", 8)
	if not _pair(cell, true): return "cell must contain two positive integers"
	if not _pair(pivot, false): return "foot_anchor must contain two nonnegative integers"
	if float(pivot[0]) >= float(cell[0]) or float(pivot[1]) >= float(cell[1]): return "foot_anchor must be inside cell"
	if not (count is int or count is float): return "frame_count must be a positive integer"
	if not is_finite(float(count)) or float(count) < 1 or float(count) != floor(float(count)): return "frame_count must be a positive integer"
	if atlas_size != Vector2(float(cell[0]) * float(count), float(cell[1])): return "walk PNG size must equal cell width * frame_count by cell height (single row)"
	if idle_size != Vector2(cell[0], cell[1]): return "idle PNG size must equal one cell"
	var timing_key := "frame_duration_sec" if candidate.has("frame_duration_sec") else "pixels_per_frame"
	var timing: Variant = candidate.get(timing_key, 8.0)
	if not (timing is int or timing is float): return timing_key + " must be a positive number"
	if not is_finite(float(timing)) or float(timing) <= 0: return timing_key + " must be a positive number"
	return ""


func _config_fail(message: String) -> void:
	push_error("FIN_CONFIG_ERROR: " + message)
	set_physics_process(false)
	set_process_unhandled_key_input(false)
	get_tree().quit(2)


func _ready() -> void:
	var config_path := "res://test_config.json"
	var validate_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="): config_path = arg.trim_prefix("--config=")
		if arg == "--validate-config-only": validate_only = true
	if not FileAccess.file_exists(config_path):
		_config_fail("config file not found: " + config_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not parsed is Dictionary:
		_config_fail("config must be a JSON object")
		return
	config = parsed
	var textures: Array[Texture2D] = []
	for field in ["walk_texture", "idle_texture"]:
		var fallback := "res://assets/fin-front-walk.png" if field == "walk_texture" else "res://assets/fin-front-idle.png"
		var path: Variant = config.get(field, fallback)
		if not path is String or not path.to_lower().ends_with(".png") or not FileAccess.file_exists(path):
			_config_fail(field + " must reference an existing PNG")
			return
		var texture: Texture2D
		if path.begins_with("res://"):
			texture = load(path) as Texture2D
		else:
			var pixels := Image.new()
			if pixels.load(path) == OK:
				texture = ImageTexture.create_from_image(pixels)
		if texture == null:
			_config_fail(field + " PNG could not be loaded (import project PNGs first)")
			return
		textures.append(texture)
	var asset_error := _asset_config_error(config, textures[0].get_size(), textures[1].get_size())
	if not asset_error.is_empty():
		_config_fail(asset_error)
		return
	config["cell"] = config.get("cell", [96, 128])
	config["foot_anchor"] = config.get("foot_anchor", [48, 112])
	config["pixels_per_frame"] = config.get("pixels_per_frame", 8.0)
	walk_frame_count = int(config.get("frame_count", 8))
	frame_duration_sec = float(config.get("frame_duration_sec", 0.0))
	if validate_only:
		print("FIN_CONFIG_RESULT: PASS")
		get_tree().quit(0)
		return
	var a: Array = config.arena
	arena = Rect2(a[0], a[1], a[2], a[3])
	spawn_point = Vector2(config.spawn[0], config.spawn[1])
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI"])
	for arg in OS.get_cmdline_user_args():
		if arg == "--self-test": testing = true
		if arg.begins_with("--capture="): screenshot_path = arg.trim_prefix("--capture=")
		if arg == "--capture-only": screenshot_only = true
	var atlas: Texture2D = textures[0]
	idle_texture = textures[1]
	for i in range(walk_frame_count):
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(i * config.cell[0], 0, config.cell[0], config.cell[1])
		frame_textures.append(region)
	player = CharacterBody2D.new()
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player.position = spawn_point
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	collision.shape = shape
	player.add_child(collision)
	add_child(player)
	actor = Sprite2D.new()
	actor.centered = false
	actor.position = -Vector2(config.foot_anchor[0], config.foot_anchor[1]) * float(config.display_scale)
	actor.scale = Vector2.ONE * float(config.display_scale)
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(actor)
	detail = Sprite2D.new()
	detail.centered = false
	detail.position = Vector2(1448, 282)
	detail.scale = Vector2(3, 3)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(detail)
	for rect in config.obstacles:
		var r := Rect2(rect[0], rect[1], rect[2], rect[3])
		obstacles.append(r)
		_add_wall(r)
	_add_wall(Rect2(arena.position - Vector2(12, 12), Vector2(arena.size.x + 24, 12)))
	_add_wall(Rect2(arena.position + Vector2(-12, arena.size.y), Vector2(arena.size.x + 24, 12)))
	_add_wall(Rect2(arena.position - Vector2(12, 0), Vector2(12, arena.size.y)))
	_add_wall(Rect2(arena.position + Vector2(arena.size.x, 0), Vector2(12, arena.size.y)))
	_build_ui()
	_update_texture()
	loaded_ok = true
	if testing: _run_tests.call_deferred()


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _label(value: String, position_value: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position_value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _build_ui() -> void:
	var t: Dictionary = config.text
	_label(t.eyebrow, Vector2(64, 30), 18, Color("b9b884"))
	_label(t.title, Vector2(64, 60), 38, Color("f1eddb"))
	_label(t.subtitle, Vector2(64, 122), 20, Color("9aafa5"))
	_label(t.arena, Vector2(90, 228), 22, Color("d5dfbe"))
	_label(t.detail, Vector2(1370, 228), 22, Color("d5dfbe"))
	_label(t.scope, Vector2(1370, 744), 20, Color("d5d9c9"))
	_label(t.keys, Vector2(1370, 844), 18, Color("a3b6ab"))
	_label(t.footnote, Vector2(64, 1020), 17, Color("a0ad9b"))
	status = _label("", Vector2(1370, 674), 19, Color("efd39b"))
	var actions: Array[Callable] = [func(): auto_move = not auto_move, _reset, func(): paused = not paused]
	for i in range(3):
		var button := Button.new()
		button.text = [t.auto, t.reset, t.pause][i]
		button.position = Vector2(650 + i * 214, 156)
		button.size = Vector2(200, 40)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 20)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(actions[i])
		add_child(button)


func _read_direction() -> Vector2:
	if testing: return test_direction
	if auto_move:
		return Vector2.DOWN if fmod(auto_time, 10.0) < 5.0 else Vector2.UP
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	return direction.normalized()


func _physics_process(delta: float) -> void:
	if not loaded_ok: return
	frame_count += 1
	auto_time += delta
	var direction := _read_direction()
	player.velocity = direction * float(config.speed)
	var before := player.position
	player.move_and_slide()
	var traveled := player.position.distance_to(before)
	moving = traveled > 0.001
	if not paused:
		if moving:
			phase += delta / frame_duration_sec if frame_duration_sec > 0 else traveled / float(config.pixels_per_frame)
			current_frame = int(phase) % walk_frame_count
		else:
			current_frame = 0
			phase = 0.0
	_update_texture()
	status.text = "FRAME %02d / %02d  ·  %s\n발 기준 (%d, %d)" % [current_frame + 1, walk_frame_count, "PAUSED" if paused else ("WALK" if moving else "IDLE"), player.position.x, player.position.y]
	queue_redraw()
	if screenshot_only and frame_count == 30:
		_capture_and_exit.call_deferred()


func _update_texture() -> void:
	var texture: Texture2D = frame_textures[current_frame] if moving or paused else idle_texture
	actor.texture = texture
	detail.texture = texture


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_ESCAPE: get_tree().quit()
	if event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_PERIOD:
		paused = true
		current_frame = (current_frame + 1) % walk_frame_count
	if event.keycode == KEY_R: _reset()
	if event.keycode == KEY_G: show_grid = not show_grid
	if event.keycode == KEY_H: show_hitbox = not show_hitbox


func _reset() -> void:
	player.position = spawn_point
	player.velocity = Vector2.ZERO
	current_frame = 0
	phase = 0.0
	auto_time = 0.0
	auto_move = false
	paused = false


func _draw() -> void:
	if not loaded_ok: return
	draw_rect(arena, Color("22382f"))
	draw_rect(Rect2(1330, 210, 526, 792), Color("1c2a25"))
	if show_grid:
		for x in range(int(arena.position.x), int(arena.end.x), 64):
			draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), Color("30483a"))
		for y in range(int(arena.position.y), int(arena.end.y), 64):
			draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color("30483a"))
	draw_rect(arena, Color("59745b"), false, 2)
	for rect in obstacles:
		draw_rect(rect.grow(5), Color("12221c"))
		draw_rect(rect, Color("566151"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), Color("7d8664"))
	if is_instance_valid(player):
		draw_ellipse_shadow(player.position)
		if show_hitbox:
			draw_rect(Rect2(player.position - Vector2(16, 8), Vector2(32, 16)), Color("d2c275"), false, 2)
			draw_line(player.position - Vector2(8, 0), player.position + Vector2(8, 0), Color.WHITE)


func draw_ellipse_shadow(pos: Vector2) -> void:
	draw_set_transform(pos, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 32, Color(0.03, 0.06, 0.03, 0.6))
	draw_set_transform(Vector2.ZERO)


func _check(condition: bool, message: String) -> void:
	if condition: print("[PASS] ", message)
	else:
		failures.append(message)
		push_error("[FAIL] " + message)


func _ticks(count: int) -> void:
	for i in range(count): await get_tree().physics_frame


func _run_tests() -> void:
	await _ticks(3)
	_check(get_viewport_rect().size == Vector2(1920,1080), "FHD logical viewport")
	_check(frame_textures.size() == walk_frame_count, "configured walk atlas frames")
	_run_asset_config_tests()
	_check(actor.texture == idle_texture, "initial idle")
	var start := player.position
	test_direction = Vector2.DOWN
	await _ticks(60)
	_check(player.position.y > start.y + 50, "forward movement")
	_check(actor.texture != idle_texture, "movement selects walk texture")
	test_direction = Vector2.ZERO
	await _ticks(2)
	_check(actor.texture == idle_texture and current_frame == 0, "stop restores idle")
	player.position = Vector2(430, 600)
	test_direction = Vector2.DOWN
	await _ticks(90)
	_check(player.position.y < 634, "foot collision stops at obstacle")
	test_direction = Vector2.ZERO
	await _ticks(2)
	paused = true
	current_frame = mini(3, walk_frame_count - 1)
	var held_frame := current_frame
	await _ticks(4)
	_check(current_frame == held_frame, "paused frame remains fixed")
	_reset()
	_check(player.position == spawn_point and not paused, "reset restores spawn and playback")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	_unhandled_key_input(key)
	_check(paused, "Space input toggles pause")
	key.keycode = KEY_PERIOD
	_unhandled_key_input(key)
	_check(current_frame == 1 % walk_frame_count and paused, "period input advances one frame")
	key.keycode = KEY_R
	_unhandled_key_input(key)
	_check(not paused and current_frame == 0, "R input resets motion")
	player.position = arena.position + Vector2(24, 200)
	test_direction = Vector2.LEFT
	await _ticks(60)
	_check(player.position.x >= arena.position.x + 15.0, "arena boundary collision")
	_reset()
	test_direction = Vector2(1, 1).normalized()
	start = player.position
	await _ticks(60)
	var distance := player.position.distance_to(start)
	_check(distance > 60.0 and distance < 68.0, "normalized diagonal speed")
	await _run_timing_runtime_tests()
	test_direction = Vector2.ZERO
	_reset()
	await _ticks(2)
	print("FIN_TEST_RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	await _capture_and_exit()


func _run_timing_runtime_tests() -> void:
	# Reuse four existing atlas regions only; no asset/config file is rewritten.
	var saved_config := config.duplicate(true)
	var saved_textures: Array[AtlasTexture] = frame_textures.duplicate()
	var saved_count := walk_frame_count
	var saved_duration := frame_duration_sec
	var saved_position := player.position
	var saved_velocity := player.velocity
	var saved_phase := phase
	var saved_frame := current_frame
	var saved_paused := paused
	var saved_moving := moving
	var saved_auto := auto_move
	var saved_auto_time := auto_time
	var saved_direction := test_direction
	frame_textures = saved_textures.slice(0, mini(4, saved_textures.size()))
	walk_frame_count = frame_textures.size()
	frame_duration_sec = 1.0 / float(Engine.physics_ticks_per_second)
	config["speed"] = 32.0
	config["pixels_per_frame"] = 1000000.0 # Distance mode could not advance here.
	_reset()
	test_direction = Vector2.DOWN
	await _ticks(12)
	_check(moving and phase >= 8.0, "timing runtime advances independently of distance setting")
	_check(walk_frame_count == mini(4, saved_count) and phase >= walk_frame_count * 2 and current_frame == int(phase) % walk_frame_count, "timing runtime alternate frame count wraps")
	_check(actor.texture == frame_textures[current_frame] and detail.texture == actor.texture, "timing runtime selects actual atlas texture")
	paused = true
	var held_phase := phase
	var held_frame := current_frame
	var before_pause := player.position
	await _ticks(5)
	_check(phase == held_phase and current_frame == held_frame and player.position != before_pause, "timing runtime pause freezes animation not movement")
	test_direction = Vector2.ZERO
	await _ticks(3)
	_check(actor.texture == frame_textures[held_frame], "timing runtime paused stop retains held texture")
	paused = false
	await _ticks(3)
	_check(current_frame == 0 and phase == 0.0 and actor.texture == idle_texture, "timing runtime unpaused stop restores idle")
	test_direction = Vector2.DOWN
	await _ticks(3)
	_check(moving and phase > 0.0 and actor.texture == frame_textures[current_frame], "timing runtime restarts from idle")
	config = saved_config
	frame_textures = saved_textures
	walk_frame_count = saved_count
	frame_duration_sec = saved_duration
	player.position = saved_position
	player.velocity = saved_velocity
	phase = saved_phase
	current_frame = saved_frame
	paused = saved_paused
	moving = saved_moving
	auto_move = saved_auto
	auto_time = saved_auto_time
	test_direction = saved_direction
	_update_texture()
	_check(frame_textures.size() == saved_count and frame_duration_sec == saved_duration and config == saved_config, "timing runtime restores prior settings")


func _run_asset_config_tests() -> void:
	_check(_asset_config_error({}, Vector2(768,128), Vector2(96,128)).is_empty(), "legacy asset defaults")
	var sample := {"cell": [32,48], "foot_anchor": [16,40], "frame_count": 4, "frame_duration_sec": 0.2}
	_check(_asset_config_error(sample, Vector2(128,48), Vector2(32,48)).is_empty(), "alternate cell count pivot timing")
	for bad in [{"cell": [0,48]}, {"cell": [32.5,48]}, {"foot_anchor": [32,40]}, {"frame_count": 0}, {"frame_count": 1.5}, {"frame_duration_sec": 0}, {"frame_duration_sec": "fast"}]:
		var variant := sample.duplicate(true)
		variant.merge(bad, true)
		_check(not _asset_config_error(variant, Vector2(128,48), Vector2(32,48)).is_empty(), "reject invalid asset config: " + str(bad))
	_check(not _asset_config_error(sample, Vector2(127,48), Vector2(32,48)).is_empty(), "reject atlas region overflow")
	_check(not _asset_config_error(sample, Vector2(128,48), Vector2(31,48)).is_empty(), "reject idle size mismatch")


func _capture_and_exit() -> void:
	if not screenshot_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		var error := capture.save_png(screenshot_path)
		_check(error == OK, "save actual engine screenshot")
	get_tree().quit(0 if failures.is_empty() else 1)
