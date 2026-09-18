extends Node2D

var world: Node2D
var actors: Node2D
var player: CharacterBody2D
var combat: Node
var camera: Camera2D
var hud: Label
var title_label: Label
var badge: Label
var controls: Label
var shake_label: Label
var texts: Dictionary
var language := "ko"
var shake_enabled := false
var shake_left := 0.0
var shake_strength := 0.0

func _ready() -> void:
	var expected := OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/")
	if expected.is_empty() or OS.get_user_data_dir().replace("\\", "/") != expected:
		push_error("Sample must be launched through its isolated launcher")
		get_tree().quit(41)
		return
	texts = JSON.parse_string(FileAccess.get_file_as_string("res://texts.json"))
	world = load("res://world.gd").new()
	world.name = "World"
	add_child(world)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	world.add_foreground(actors)
	var spawns: Dictionary = world.get_spawn_points()
	player = load("res://actor.gd").new()
	player.name = "Player"
	actors.add_child(player)
	player.configure("player", spawns.player)
	var slime: CharacterBody2D = load("res://actor.gd").new()
	slime.name = "Slime"
	actors.add_child(slime)
	slime.configure("slime", spawns.slimes[0])
	combat = load("res://combat.gd").new()
	combat.name = "Combat"
	add_child(combat)
	combat.setup(world, actors, player)
	combat.shake_requested.connect(_shake_requested)
	camera = Camera2D.new()
	camera.position = Vector2(960,540)
	add_child(camera)
	_build_ui()

func _label(parent: Node, position_at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = position_at
	label.add_theme_font_override("font", load("res://assets/Galmuri11.ttf"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("fff2d0"))
	label.add_theme_color_override("font_shadow_color", Color("14231c"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var top := ColorRect.new()
	top.position = Vector2(24,20)
	top.size = Vector2(1070,130)
	top.color = Color(0.04,0.09,0.07,0.87)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)
	title_label = _label(ui, Vector2(46,32), 26)
	badge = _label(ui, Vector2(46,74), 18)
	hud = _label(ui, Vector2(46,108), 22)
	var bottom := ColorRect.new()
	bottom.position = Vector2(24,944)
	bottom.size = Vector2(1330,114)
	bottom.color = top.color
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bottom)
	controls = _label(ui, Vector2(46,956), 21)
	shake_label = _label(ui, Vector2(46,1022), 19)

func tr_key(key: String) -> String:
	return str(texts[language].get(key, key))

func _process(delta: float) -> void:
	if not is_instance_valid(hud):
		return
	var status: Dictionary = combat.get_status()
	title_label.text = tr_key("title")
	badge.text = tr_key("badge")
	controls.text = tr_key("controls")
	hud.text = tr_key("status") % [status.get("player_hp",0),status.get("player_max_hp",0),status.get("slime_hp",0),status.get("slime_max_hp",0),status.get("kills",0)]
	shake_label.text = tr_key("shake_on" if shake_enabled else "shake_off")
	shake_left = maxf(0, shake_left - delta)
	camera.offset = Vector2(sin(shake_left*110),cos(shake_left*137))*shake_strength if shake_enabled and shake_left > 0 else Vector2.ZERO

func _shake_requested(strength: float, duration: float) -> void:
	if shake_enabled:
		shake_left = minf(duration,0.12)
		shake_strength = minf(strength,3.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_ESCAPE: get_tree().quit()
		KEY_F11:
			var full := get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN
			get_window().mode = Window.MODE_WINDOWED if full else Window.MODE_EXCLUSIVE_FULLSCREEN
			if full:
				get_window().size = Vector2i(1280,720)
		KEY_R: combat.reset_encounter()
		KEY_H: shake_enabled = not shake_enabled
		KEY_L: language = "en" if language == "ko" else "ko"
