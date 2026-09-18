class_name QuarterActor
extends CharacterBody2D
## Sample actor. Knight 16px atlas x4 is a labelled proxy, NOT finished 64x96 Fin.
## Combat owns the single simulation/animation clock, including hitstop.

class WeaponLayer extends Node2D:
	var actor: Node
	var glove_only: bool = false
	func _draw() -> void:
		if is_instance_valid(actor):
			actor.draw_weapon(self, glove_only)

var kind: String = "player"
var hp: int = 100
var max_hp: int = 100
var is_dead: bool = false
var facing: Vector2 = Vector2.DOWN
var attack_facing: Vector2 = Vector2.DOWN
var phase: String = "idle"
var phase_elapsed: float = 0.0
var phase_duration: float = 0.0
var animation_time: float = 0.0
var moving: bool = false
var spawn_position: Vector2
var knockback_velocity := Vector2.ZERO
var knockback_remaining: float = 0.0
var invulnerable_remaining: float = 0.0
var flash_remaining: float = 0.0
var hit_targets: Dictionary = {}
var enemy_hit_done: bool = false
var blade_inner: float = 12.0
var blade_outer: float = 74.0
var sweep_radians: float = deg_to_rad(110.0)
var sweep_ease_out_power: float = 3.0
var weapon_visual: Dictionary = {"startup_length_ratio": 0.58, "recovery_length_ratio": 0.32, "recovery_pose_hold_ratio": 0.30, "trail_sec": 0.032}
var actor_radius: float = 17.0
var _combat: Node
var _sprite: Sprite2D
var _label: Label
var _strings: Dictionary = {}
var _rig: Dictionary = {}
var _weapon_back: WeaponLayer
var _weapon_front: WeaponLayer
var _glove: WeaponLayer
var _proxy_texture: Texture2D
var _fin_frames: Array[Texture2D] = []
var _walk_distance: float = 0.0

func uses_fin() -> bool:
	return kind == "player" and art_direction() == "down" and phase == "idle" and not is_dead and _fin_frames.size() == 9

func fin_frame() -> int:
	return 1 + int(_walk_distance / 23.0) % 8 if moving else 0

func configure(actor_kind: String, spawn: Vector2) -> void:
	kind = actor_kind
	spawn_position = spawn
	position = spawn
	if is_node_ready():
		_load_proxy()

func set_combat(controller: Node) -> void:
	_combat = controller

func _ready() -> void:
	_strings = JSON.parse_string(FileAccess.get_file_as_string("res://combat_strings_ko.json"))
	_rig = JSON.parse_string(FileAccess.get_file_as_string("res://weapon_rig.json"))
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_weapon_back = WeaponLayer.new()
	_weapon_back.name = "WeaponBack"
	_weapon_back.actor = self
	add_child(_weapon_back)
	_sprite = Sprite2D.new()
	_sprite.region_enabled = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(4, 4)
	_sprite.position = Vector2(0, -24)
	add_child(_sprite)
	_weapon_front = WeaponLayer.new()
	_weapon_front.name = "WeaponFront"
	_weapon_front.actor = self
	add_child(_weapon_front)
	_glove = WeaponLayer.new()
	_glove.name = "OriginalGlove"
	_glove.actor = self
	_glove.glove_only = true
	_glove.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glove)
	_label = Label.new()
	_label.position = Vector2(-92, -98)
	_label.size = Vector2(184, 25)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	if ResourceLoader.exists("res://assets/Galmuri11.ttf"):
		_label.add_theme_font_override("font", load("res://assets/Galmuri11.ttf"))
	add_child(_label)
	_load_proxy()

func _load_proxy() -> void:
	var path := "res://assets/proxy-knight.png" if kind == "player" else "res://assets/proxy-slime.png"
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_proxy_texture = _sprite.texture
	_fin_frames.clear()
	if kind == "player":
		for i in range(9):
			_fin_frames.append(load("res://assets/fin-walk/frame-%d.png" % i))
	_label.text = String(_strings.actor_player if kind == "player" else _strings.actor_slime)
	if _sprite.texture == null:
		_label.text = String(_strings.asset_missing)
	_refresh_visual()

func reset_actor(new_max_hp: int) -> void:
	max_hp = new_max_hp
	hp = max_hp
	is_dead = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	knockback_remaining = 0.0
	invulnerable_remaining = 0.0
	flash_remaining = 0.0
	animation_time = 0.0
	_walk_distance = 0.0
	moving = false
	facing = Vector2.RIGHT if kind == "player" else Vector2.LEFT
	attack_facing = facing
	hit_targets.clear()
	enemy_hit_done = false
	set_phase("idle")
	_refresh_visual()

func set_phase(next: String, duration: float = 0.0) -> void:
	phase = next
	phase_elapsed = 0.0
	phase_duration = duration
	_refresh_visual()

func tick_clock(delta: float) -> void:
	phase_elapsed += delta
	animation_time += delta
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	flash_remaining = maxf(0.0, flash_remaining - delta)
	_refresh_visual()

func move_body(delta: float, desired: Vector2) -> void:
	if is_dead:
		return
	var displacement: Vector2
	var before := position
	var was_knockback := knockback_remaining > 0.0
	if knockback_remaining > 0.0:
		var consumed := minf(delta, knockback_remaining)
		displacement = knockback_velocity * consumed
		knockback_remaining -= consumed
	else:
		displacement = desired * delta
	velocity = desired
	moving = displacement.length_squared() > 0.01
	# Both locomotion and knockback use collision-aware motion; never tween position.
	var collision := move_and_collide(displacement)
	if collision != null:
		if knockback_remaining > 0.0:
			knockback_remaining = 0.0
		else:
			move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	var travelled := position.distance_to(before)
	moving = travelled > 0.001 and desired.length_squared() > 0.01 and not was_knockback
	if moving:
		_walk_distance += travelled
	else:
		_walk_distance = 0.0
	_refresh_visual()

func apply_damage(amount: int, direction: Vector2, distance: float, duration: float, hurt_duration: float) -> void:
	hp = maxi(0, hp - amount)
	is_dead = hp == 0
	flash_remaining = 0.12
	knockback_velocity = direction.normalized() * distance / maxf(duration, 0.001)
	knockback_remaining = duration
	set_phase("dead" if is_dead else "hurt", hurt_duration)
	_refresh_visual()

func attack_origin() -> Vector2:
	return to_global(hand_local()) if kind == "player" else global_position + Vector2(0, -20)

func art_direction() -> String:
	if absf(facing.x) >= absf(facing.y):
		return "right" if facing.x > 0.0 else "left"
	return "down" if facing.y > 0.0 else "up"

func frame_row() -> int:
	if kind == "player" and phase in ["startup", "active", "recovery"]:
		if phase == "active" or (phase == "recovery" and phase_elapsed < phase_duration * float(weapon_visual.recovery_pose_hold_ratio)):
			return 4
		return 0
	return int(animation_time * (9.0 if kind == "player" else 5.0)) % 4 if moving else 0

func socket_spec() -> Dictionary:
	var direction: Dictionary = _rig.directions[art_direction()]
	var row := frame_row()
	if row == 4:
		return direction.attack
	if row in [1, 2, 3]:
		return direction.walk[str(row)]
	return direction.idle

func hand_local() -> Vector2:
	var socket: Array = socket_spec().hand_socket_px
	return (Vector2(float(socket[0]), float(socket[1])) - Vector2(8, 8)) * 4.0 + Vector2(0, -24)

func get_weapon_attachment() -> Dictionary:
	var spec := socket_spec()
	var visual := blade_visual()
	var direction := Vector2.from_angle(float(visual.angle))
	var hand := attack_origin()
	return {"art_direction": art_direction(), "pose": "attack" if frame_row() == 4 else ("idle" if frame_row() == 0 else "walk"),
		"row": frame_row(), "socket_px": spec.hand_socket_px, "hand_local": hand_local(),
		"hand_global": hand, "hilt_global": hand, "blade_start_global": to_global(hand_local() + direction * blade_inner),
		"blade_tip_global": to_global(hand_local() + direction * blade_outer), "render_order": _rig.directions[art_direction()].render_order,
		"phase": phase, "visible": not is_dead}

func hurt_center() -> Vector2:
	return global_position + Vector2(0, -20)

func blade_angle(progress: float) -> float:
	var fraction := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), sweep_ease_out_power)
	return attack_facing.angle() + lerpf(-sweep_radians * 0.5, sweep_radians * 0.5, fraction)

func progress_for_blade_angle(angle: float) -> float:
	var fraction := clampf((angle - attack_facing.angle()) / sweep_radians + 0.5, 0.0, 1.0)
	return 1.0 - pow(1.0 - fraction, 1.0 / sweep_ease_out_power)

func blade_visual() -> Dictionary:
	# Only the weapon/effect changes silhouette. The bitmap never rotates or stretches.
	var t := clampf(phase_elapsed / maxf(phase_duration, 0.001), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var angle := blade_angle(t)
	var carry := deg_to_rad(float(_rig.directions[art_direction()].carry_angle_deg))
	if phase == "startup":
		angle = lerp_angle(carry, blade_angle(0.0), eased)
	elif phase == "recovery":
		angle = lerp_angle(blade_angle(1.0), carry, eased)
	elif phase != "active":
		angle = carry
	# Weapon form persists at rest; only the swing trail is translucent.
	return {"angle": angle, "reach": blade_outer, "alpha": 1.0,
		"trail_angle": blade_angle(maxf(0.0, (phase_elapsed - float(weapon_visual.trail_sec)) / maxf(phase_duration, 0.001)))}

func _refresh_visual() -> void:
	if _sprite == null:
		return
	var column: int = 0
	if kind == "player":
		# Eight-direction aim/movement, explicitly separate four-direction proxy art.
		if absf(facing.x) >= absf(facing.y):
			column = 3 if facing.x > 0.0 else 2
		else:
			column = 0 if facing.y > 0.0 else 1
	var row := frame_row()
	var fin := uses_fin()
	_sprite.texture = _fin_frames[fin_frame()] if fin else _proxy_texture
	_sprite.region_enabled = not fin
	_sprite.scale = Vector2.ONE if fin else Vector2(4, 4)
	_sprite.position = Vector2(0, -48) if fin else Vector2(0, -24)
	_label.text = "핀 · 정면 걷기 시험" if fin else String(_strings.actor_player if kind == "player" else _strings.actor_slime)
	_label.position.y = -126 if fin else -98
	_sprite.region_rect = Rect2(column * 16, row * 16, 16, 16)
	_sprite.modulate = Color(2.4, 2.4, 2.4) if flash_remaining > 0.0 else Color.WHITE
	_sprite.modulate.a = 0.28 if is_dead else 1.0
	var weapon_visible := kind == "player" and not is_dead and not fin
	var behind := String(_rig.directions[art_direction()].render_order) == "behind_body"
	_weapon_back.visible = weapon_visible and behind
	_weapon_front.visible = weapon_visible and not behind
	_glove.visible = weapon_visible
	for layer in [_weapon_back, _weapon_front, _glove]:
		layer.queue_redraw()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.42))
	draw_circle(Vector2.ZERO, 24, Color(0.05, 0.08, 0.09, 0.3))
	draw_set_transform(Vector2.ZERO)
	if is_dead:
		return
	var bar_y := -102 if uses_fin() else -68
	draw_rect(Rect2(-28, bar_y, 56, 5), Color(0.12, 0.13, 0.18))
	draw_rect(Rect2(-28, bar_y, 56 * float(hp) / max_hp, 5), Color(0.4, 0.85, 0.58))
	var origin := Vector2(0, -20)
	if kind == "slime" and phase == "telegraph":
		draw_arc(origin, 37, 0, TAU * clampf(phase_elapsed / phase_duration, 0, 1), 32, Color(1, 0.4, 0.22), 3)

func draw_weapon(canvas: Node2D, glove_only: bool) -> void:
	if kind != "player" or is_dead or _sprite == null:
		return
	if glove_only:
		# Re-render only the exact source glove pixels; no opaque body recolour patch.
		var rect: Array = socket_spec().glove_overlay_rect_px
		var source := Rect2(float(rect[0]) + int(_rig.directions[art_direction()].column) * 16, float(rect[1]) + frame_row() * 16, float(rect[2]), float(rect[3]))
		var destination := Rect2((Vector2(float(rect[0]), float(rect[1])) - Vector2(8, 8)) * 4.0 + Vector2(0, -24), Vector2(float(rect[2]), float(rect[3])) * 4.0)
		if _sprite.texture != null:
			canvas.draw_texture_rect_region(_sprite.texture, destination, source, _sprite.modulate)
		return
	var origin := hand_local()
	var visual := blade_visual()
	var angle: float = visual.angle
	var direction := Vector2.from_angle(angle)
	var reach: float = visual.reach
	if phase == "active":
		# Short moving tail rather than an ever-growing stationary fan.
		canvas.draw_arc(origin, blade_outer - 3, float(visual.trail_angle), angle, 28, Color(1, 0.88, 0.48, 0.42), 6)
		for lag in [0.012, 0.025]:
			var previous := blade_angle(maxf(0.0, (phase_elapsed - lag) / phase_duration))
			var echo := Vector2.from_angle(previous)
			canvas.draw_line(origin + echo * blade_inner, origin + echo * blade_outer, Color(1, 0.90, 0.62, 0.14), 3)
	# The visible blade segment is also the collision-test segment in combat.gd.
	var cross := direction.orthogonal()
	var blade_start := origin + direction * blade_inner
	var tip := origin + direction * reach
	var palette: Dictionary = _rig.palette
	canvas.draw_line(origin - direction * 7, blade_start, Color(palette.outline), 7)
	canvas.draw_line(origin - direction * 6, blade_start, Color(palette.grip), 4)
	canvas.draw_line(blade_start - cross * 7, blade_start + cross * 7, Color(palette.pommel), 4)
	var polygon := PackedVector2Array([blade_start + cross * 3, tip - direction * 8 + cross * 3, tip, tip - direction * 8 - cross * 3, blade_start - cross * 3])
	canvas.draw_colored_polygon(polygon, Color(palette.blade_mid))
	canvas.draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[4], polygon[0]]), Color(palette.outline), 2)
	canvas.draw_line(blade_start + cross * 1.5, tip - direction * 3, Color(palette.blade_edge), 1.5)
