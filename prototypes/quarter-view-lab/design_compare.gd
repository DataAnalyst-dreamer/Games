extends Node2D
## Static opt-in design inspection. No combat controller, animation, or save writes.
var entries: Array = []
var originals: Array[Node2D] = []
var candidates: Array[Node2D] = []
var records: Array[Dictionary] = []
var captions: Array[Label] = []
var mode_label: Label
var zoom_factor := 1.0
var comparison_mode := 0 # side-by-side, original at center, candidate at same center
var ready_for_review := false
var asset_set_ready := false
var dark_backings: Array[ColorRect] = []
var dark_enabled := false
var backing_mode := 0
var strings: Dictionary = {}
const CENTERS := [320.0, 960.0, 1600.0]
const BASELINE := 780.0

func _ready() -> void:
	var expected := OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/")
	if expected.is_empty() or OS.get_user_data_dir().replace("\\", "/") != expected:
		push_error("Design comparison requires the isolated sample launcher")
		get_tree().quit(41)
		return
	strings = JSON.parse_string(FileAccess.get_file_as_string("res://design_strings_ko.json"))
	var world: Node2D = load("res://world.gd").new()
	world.name = "SameVillageBackground"
	add_child(world)
	var camera := Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design_compare.json"))
	entries = manifest.candidates
	for center in CENTERS:
		var backing := ColorRect.new()
		backing.position = Vector2(center-292,450)
		backing.size = Vector2(584,420)
		backing.color = Color("192e26")
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backing.hide()
		add_child(backing)
		dark_backings.append(backing)
	var ui := CanvasLayer.new()
	add_child(ui)
	_panel(ui, Vector2(24,20), Vector2(1872,144))
	_label(ui, Vector2(48,36), _s("title"), 28)
	_label(ui, Vector2(48,82), _s("subtitle"), 21)
	mode_label = _label(ui, Vector2(48,120), "", 21)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var original := _make_original(str(entry.id))
		originals.append(original)
		var candidate := _make_candidate(entry)
		candidates.append(candidate)
		_panel(ui, Vector2(CENTERS[index]-292, 310), Vector2(584,116))
		_label(ui, Vector2(CENTERS[index]-270, 322), _s(str(entry.title_key)), 25)
		var caption := _label(ui, Vector2(CENTERS[index]-270, 362), "", 19)
		captions.append(caption)
	_panel(ui, Vector2(24,908), Vector2(1872,150))
	_label(ui, Vector2(48,926), _s("controls"), 22)
	_label(ui, Vector2(48,970), _s("sizes"), 20)
	_label(ui, Vector2(48,1008), _s("limits"), 19)
	_update_layout()
	asset_set_ready = records.size() == 3 and records.all(func(record: Dictionary) -> bool: return bool(record.loaded))
	ready_for_review = true

func get_readiness() -> Dictionary:
	var available := 0
	var missing: Array[String] = []
	for record in records:
		if bool(record.loaded):
			available += 1
		else:
			missing.append(str(record.id))
	return {"asset_set_ready":asset_set_ready,"required_candidates":3,"available_candidates":available,"missing_candidates":missing,"scope":"static_comparison_only","fin_animation_ready":false,"combat_assets_replaced":false}

func _make_original(id: String) -> Node2D:
	var holder := Node2D.new()
	add_child(holder)
	var actor: QuarterActor = load("res://actor.gd").new()
	holder.add_child(actor)
	actor.configure("slime" if id == "slime" else "player", Vector2.ZERO)
	actor.facing = Vector2.RIGHT
	actor.attack_facing = Vector2.RIGHT
	actor.set_phase("idle")
	actor._label.hide()
	if id == "sword":
		# Render the existing weapon code only, without modifying its actor source.
		actor._sprite.hide()
		actor._glove.hide()
		actor.hide()
		var weapon: Node2D = QuarterActor.WeaponLayer.new()
		weapon.actor = actor
		weapon.position = -actor.hand_local()
		holder.add_child(weapon)
	return holder

func _make_candidate(entry: Dictionary) -> Node2D:
	var holder := Node2D.new()
	add_child(holder)
	var record := {"id":entry.id,"loaded":false,"reason":_s(str(entry.status_key))}
	records.append(record)
	if not bool(entry.enabled):
		return holder
	var path := str(entry.path)
	if not path.begins_with("res://assets/design-candidates/") or not FileAccess.file_exists(path):
		record.reason = _s("missing")
		return holder
	if FileAccess.get_sha256(path).to_upper() != str(entry.sha256).to_upper():
		record.reason = _s("hash_mismatch")
		return holder
	var texture: Texture2D = load(path)
	if texture == null:
		record.reason = _s("import_failed")
		return holder
	var image := texture.get_image()
	var size := Vector2i(int(entry.image_size[0]), int(entry.image_size[1]))
	var box := Rect2i(int(entry.alpha_rect[0]),int(entry.alpha_rect[1]),int(entry.alpha_rect[2]),int(entry.alpha_rect[3]))
	if image.get_size() != size or image.detect_alpha() == Image.ALPHA_NONE or image.is_invisible() or image.get_used_rect() != box or box.size.x <= 0 or box.size.y <= 0:
		record.reason = _s("alpha_mismatch")
		return holder
	var has_transparent := false
	var core_min := image.get_size()
	var core_max := Vector2i(-1,-1)
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x,y).a
			if alpha < 0.01:
				has_transparent = true
			if alpha >= 128.0/255.0:
				core_min = core_min.min(Vector2i(x,y))
				core_max = core_max.max(Vector2i(x,y))
	if not has_transparent:
		record.reason = _s("opaque")
		return holder
	var core := Rect2i(core_min, core_max-core_min+Vector2i.ONE)
	var expected_core := Rect2i(int(entry.core_rect[0]),int(entry.core_rect[1]),int(entry.core_rect[2]),int(entry.core_rect[3]))
	if core != expected_core or core.size.x <= 0 or core.size.y <= 0:
		record.reason = _s("alpha_mismatch")
		return holder
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	# Scale by meaningful alpha silhouette but draw the FULL untouched texture.
	# Very faint edge pixels remain visible, never cropped or rewritten.
	var factor := minf(float(entry.target_size[0])/core.size.x, float(entry.target_size[1])/core.size.y)
	sprite.scale = Vector2.ONE * factor
	sprite.position = Vector2(-(core.position.x+core.size.x*0.5)*factor, -(core.position.y+core.size.y)*factor)
	holder.add_child(sprite)
	record.loaded = true
	record.display_size = Vector2(core.size) * factor
	record.faint_extent_size = Vector2(box.size) * factor
	return holder

func _update_layout() -> void:
	var names := ["side_by_side", "original_only", "candidate_only"]
	mode_label.text = _s(names[comparison_mode]) + _s("scale_one" if zoom_factor == 1.0 else "scale_two")
	for index in entries.size():
		originals[index].position = Vector2(CENTERS[index] - (130 if comparison_mode == 0 else 0), BASELINE)
		candidates[index].position = Vector2(CENTERS[index] + (130 if comparison_mode == 0 else 0), BASELINE)
		originals[index].scale = Vector2.ONE * zoom_factor
		candidates[index].scale = Vector2.ONE * zoom_factor
		originals[index].visible = comparison_mode != 2
		candidates[index].visible = comparison_mode != 1
		captions[index].text = str(records[index].reason)

func _panel(parent: Node, at: Vector2, extent: Vector2) -> void:
	var panel := ColorRect.new()
	panel.position = at
	panel.size = extent
	panel.color = Color(0.035,0.08,0.065,0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

func _s(key: String) -> String:
	return str(strings.get(key,key))

func _label(parent: Node, at: Vector2, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_override("font",load("res://assets/Galmuri11.ttf"))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("fff2d0"))
	parent.add_child(label)
	return label

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_TAB:
			comparison_mode = (comparison_mode + 1) % 3
			_update_layout()
		KEY_Z:
			zoom_factor = 2.0 if zoom_factor == 1.0 else 1.0
			_update_layout()
		KEY_ESCAPE: get_tree().quit()
		KEY_B:
			backing_mode = (backing_mode + 1) % 3
			dark_enabled = backing_mode == 1
			for backing in dark_backings:
				backing.visible = backing_mode != 0
				backing.color = Color("192e26") if dark_enabled else Color("fff2d0")
		KEY_F11:
			var full := get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN
			get_window().mode = Window.MODE_WINDOWED if full else Window.MODE_EXCLUSIVE_FULLSCREEN
			if full:
				get_window().size = Vector2i(1280,720)
