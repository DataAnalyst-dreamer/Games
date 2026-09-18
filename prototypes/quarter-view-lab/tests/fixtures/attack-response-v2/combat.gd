extends Node2D
## Disposable play-lab only. No autoload, quests, items, production state or saves.
signal status_changed(snapshot: Dictionary)
signal shake_requested(strength: float, duration: float)

var config: Dictionary = {}
var player: QuarterActor
var slimes: Array[QuarterActor] = []
var world: Node2D
var actors: Node2D
var freeze_remaining: float = 0.0
var attack_buffer_remaining: float = 0.0
var kills: int = 0
var landed_hits: int = 0
var message: String = ""
var _strings: Dictionary = {}
var _keys: Dictionary = {}
var _marks: Array[Dictionary] = []
var _swing_audio: AudioStreamPlayer
var _hit_audio: AudioStreamPlayer
var _ready_for_play: bool = false
var _hitstop_buffered: bool = false

func setup(level: Node2D, actor_root: Node2D, player_actor: QuarterActor) -> void:
	world = level
	actors = actor_root
	player = player_actor
	config = JSON.parse_string(FileAccess.get_file_as_string("res://combat_config.json"))
	for key in ["startup_sec", "active_sec", "recovery_sec", "hurt_sec", "sweep_ease_out_power", "sweep_degrees"]:
		if not is_finite(float(config.get(key, 0.0))) or float(config.get(key, 0.0)) <= 0.0:
			push_error("Invalid positive finite sample attack configuration: " + key)
			get_tree().quit(43)
			return
	_strings = JSON.parse_string(FileAccess.get_file_as_string("res://combat_strings_ko.json"))
	for child in actors.get_children():
		if child is QuarterActor:
			child.set_combat(self)
			if child.kind == "slime":
				slimes.append(child)
	player.blade_inner = float(config.blade_inner_px)
	player.blade_outer = float(config.blade_outer_px)
	player.sweep_radians = deg_to_rad(float(config.sweep_degrees))
	player.sweep_ease_out_power = float(config.sweep_ease_out_power)
	player.weapon_visual = config.weapon_visual.duplicate(true)
	_swing_audio = _make_audio("res://assets/proxy-swing.wav", -12.0)
	_hit_audio = _make_audio("res://assets/proxy-hit.wav", -6.0)
	_ready_for_play = true
	reset_encounter()

func _make_audio(path: String, volume: float) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.volume_db = volume
	if ResourceLoader.exists(path):
		sound.stream = load(path)
	add_child(sound)
	return sound

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		_keys[code] = event.pressed
		if event.pressed and not event.echo and code == KEY_SPACE:
			queue_attack()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_attack()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_keys.clear()

func move_input() -> Vector2:
	var x := float(_keys.get(KEY_D, false) or _keys.get(KEY_RIGHT, false)) - float(_keys.get(KEY_A, false) or _keys.get(KEY_LEFT, false))
	var y := float(_keys.get(KEY_S, false) or _keys.get(KEY_DOWN, false)) - float(_keys.get(KEY_W, false) or _keys.get(KEY_UP, false))
	return Vector2(x, y).limit_length()

func queue_attack() -> void:
	if _ready_for_play and not player.is_dead:
		attack_buffer_remaining = float(config.input_buffer_sec)
		if freeze_remaining > 0.0:
			_hitstop_buffered = true

func reset_encounter() -> void:
	if not _ready_for_play:
		return
	stop_sounds()
	freeze_remaining = 0.0
	attack_buffer_remaining = 0.0
	_hitstop_buffered = false
	kills = 0
	landed_hits = 0
	_keys.clear()
	_marks.clear()
	player.reset_actor(int(config.player_hp))
	for slime in slimes:
		slime.reset_actor(int(config.slime_hp))
	message = String(_strings.start)
	status_changed.emit(get_status())
	queue_redraw()

func stop_sounds() -> void:
	for sound in [_swing_audio, _hit_audio]:
		if is_instance_valid(sound):
			sound.stop()

func _exit_tree() -> void:
	stop_sounds()

func get_status() -> Dictionary:
	return {"player_hp": player.hp if player != null else 0,
		"player_max_hp": player.max_hp if player != null else 0,
		"slime_hp": slimes[0].hp if not slimes.is_empty() else 0,
		"slime_max_hp": slimes[0].max_hp if not slimes.is_empty() else 0,
		"kills": kills, "hits": landed_hits, "message": message,
		"phase": player.phase if player != null else "loading", "hitstop": freeze_remaining > 0.0,
		"proxy": true, "fin_animation_ready": false}

func _physics_process(delta: float) -> void:
	if not _ready_for_play:
		return
	# Input events still buffer, but body, pose, effect and phase clocks stop together.
	if freeze_remaining > 0.0:
		freeze_remaining = maxf(0.0, freeze_remaining - delta)
		return
	for mark in _marks:
		mark.age += delta
	_marks = _marks.filter(func(mark: Dictionary) -> bool: return float(mark.age) < 0.20)
	_update_player(delta)
	if freeze_remaining <= 0.0:
		for slime in slimes:
			_update_slime(slime, delta)
			if freeze_remaining > 0.0:
				break
	if not _hitstop_buffered:
		attack_buffer_remaining = maxf(0.0, attack_buffer_remaining - delta)
	queue_redraw()

func _update_player(delta: float) -> void:
	if player.is_dead:
		return
	var input := move_input()
	var remaining := delta
	# Spend each part of this tick in its actual phase. No extra blank physics tick at
	# startup/active/recovery boundaries, even at 30 Hz. Contact deliberately ends the
	# tick so hitstop holds the contact pose and no later enemy clock runs this tick.
	while remaining > 0.000001:
		if player.phase == "idle" and attack_buffer_remaining > 0.0:
			if input != Vector2.ZERO:
				player.facing = input
			player.attack_facing = player.facing
			player.hit_targets.clear()
			player.set_phase("startup", float(config.startup_sec))
			attack_buffer_remaining = 0.0
			_hitstop_buffered = false
		if player.phase == "idle":
			if input != Vector2.ZERO:
				player.facing = input
			player.tick_clock(remaining)
			player.move_body(remaining, input * float(config.move_speed))
			return
		if player.phase not in ["startup", "active", "recovery", "hurt"]:
			return
		var old_elapsed := player.phase_elapsed
		var consumed := minf(remaining, maxf(0.0, player.phase_duration - old_elapsed))
		player.tick_clock(consumed)
		player.move_body(consumed, Vector2.ZERO)
		remaining -= consumed
		if player.phase == "active":
			var start := clampf(old_elapsed / player.phase_duration, 0.0, 1.0)
			var end := clampf(player.phase_elapsed / player.phase_duration, 0.0, 1.0)
			var contact_progress := _check_player_sweep(start, end)
			if contact_progress >= 0.0:
				# Hold the first contacted blade angle, not a later end-of-tick angle.
				var contact_elapsed := clampf(contact_progress * player.phase_duration, old_elapsed, player.phase_elapsed)
				player.animation_time -= player.phase_elapsed - contact_elapsed
				player.phase_elapsed = contact_elapsed
				player._refresh_visual()
				return
		if player.phase_elapsed >= player.phase_duration - 0.000001:
			if player.phase == "startup":
				player.set_phase("active", float(config.active_sec))
				if _swing_audio.stream != null:
					_swing_audio.play()
				if _check_player_sweep(0.0, 0.0) >= 0.0:
					return
			elif player.phase == "active":
				player.set_phase("recovery", float(config.recovery_sec))
			else:
				player.set_phase("idle")

func _check_player_sweep(start: float, end: float) -> float:
	for slime in slimes:
		if slime.is_dead or player.hit_targets.has(slime.get_instance_id()):
			continue
		var contact := swept_contact_detail(player, slime, start, end)
		if contact.is_empty():
			continue
		player.hit_targets[slime.get_instance_id()] = true
		var direction := (slime.global_position - player.global_position).normalized()
		slime.apply_damage(int(config.damage), direction, float(config.knockback_px), float(config.knockback_sec), float(config.hurt_sec))
		landed_hits += 1
		if slime.is_dead:
			kills += 1
		message = String(_strings.defeated) if slime.is_dead else String(_strings.contact) % int(config.damage)
		_impact(contact.point)
		return float(contact.progress)
	return -1.0

func swept_contact(attacker: QuarterActor, target: QuarterActor, start: float, end: float) -> Vector2:
	var contact := swept_contact_detail(attacker, target, start, end)
	return contact.get("point", Vector2.INF)

func swept_contact_detail(attacker: QuarterActor, target: QuarterActor, start: float, end: float) -> Dictionary:
	var origin := attacker.attack_origin()
	var center := target.hurt_center()
	var start_angle := attacker.blade_angle(start)
	var end_angle := attacker.blade_angle(end)
	# Sample actual swept angular distance, not clock progress: an ease-out may cover
	# most of the arc in its first tick. Render and collision share blade_angle().
	var steps := maxi(1, int(ceil(absf(rad_to_deg(end_angle - start_angle)) / 3.0)))
	for index in range(steps + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / steps)
		var direction := Vector2.from_angle(angle)
		var a := origin + direction * attacker.blade_inner
		var b := origin + direction * attacker.blade_outer
		var closest := Geometry2D.get_closest_point_to_segment(center, a, b)
		if closest.distance_to(center) <= target.actor_radius:
			# A wall between hand and target blocks both damage and a behind-wall spark.
			if wall_clear(attacker, target):
				return {"point": closest, "progress": attacker.progress_for_blade_angle(angle)}
	return {}

func wall_clear(attacker: QuarterActor, target: QuarterActor) -> bool:
	# Both the visible upper-body segment AND floor footprint must be unobstructed.
	# Otherwise a thin horizontal wall may sit below both y-offset hurt centers.
	for pair in [[attacker.hurt_center(), target.hurt_center()], [attacker.global_position, target.global_position]]:
		var query := PhysicsRayQueryParameters2D.create(pair[0], pair[1], 1)
		if not attacker.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func _update_slime(slime: QuarterActor, delta: float) -> void:
	if slime.is_dead:
		return
	slime.tick_clock(delta)
	var difference := player.global_position - slime.global_position
	match slime.phase:
		"idle":
			if player.is_dead:
				slime.move_body(delta, Vector2.ZERO)
			elif difference.length() <= float(config.slime_attack_range_px):
				slime.attack_facing = difference.normalized()
				slime.enemy_hit_done = false
				slime.set_phase("telegraph", float(config.slime_telegraph_sec))
				slime.move_body(delta, Vector2.ZERO)
			elif difference.length() < float(config.slime_aggro_px):
				slime.facing = difference.normalized()
				slime.move_body(delta, slime.facing * float(config.slime_speed))
			else:
				slime.move_body(delta, Vector2.ZERO)
		"telegraph":
			slime.move_body(delta, Vector2.ZERO)
			if slime.phase_elapsed >= slime.phase_duration:
				slime.set_phase("active", float(config.slime_active_sec))
		"active":
			slime.move_body(delta, slime.attack_facing * float(config.slime_lunge_speed))
			difference = player.global_position - slime.global_position
			if not player.is_dead and not slime.enemy_hit_done and player.invulnerable_remaining <= 0.0 and slime.global_position.distance_to(player.global_position) < float(config.slime_contact_px) and wall_clear(slime, player):
				slime.enemy_hit_done = true
				player.apply_damage(int(config.slime_damage), difference.normalized(), float(config.player_knockback_px), float(config.knockback_sec), float(config.hurt_sec))
				player.invulnerable_remaining = float(config.player_iframe_sec)
				message = String(_strings.hurt)
				_impact(player.hurt_center())
			if freeze_remaining <= 0.0 and slime.phase_elapsed >= slime.phase_duration:
				slime.set_phase("recovery", float(config.slime_recovery_sec))
		"recovery", "hurt":
			slime.move_body(delta, Vector2.ZERO)
			if slime.phase_elapsed >= slime.phase_duration:
				slime.set_phase("idle")

func _impact(point: Vector2) -> void:
	freeze_remaining = float(config.hitstop_sec)
	_marks.append({"point": point, "age": 0.0})
	if _hit_audio.stream != null:
		_hit_audio.play()
	shake_requested.emit(float(config.impact_shake_px), float(config.impact_shake_sec))
	status_changed.emit(get_status())
	queue_redraw()

func _draw() -> void:
	for mark in _marks:
		var age := float(mark.age)
		var point: Vector2 = to_local(mark.point)
		for index in 6:
			var direction := Vector2.from_angle(index * TAU / 6.0)
			draw_line(point + direction * (5 + age * 42), point + direction * (18 + age * 85), Color(1, 0.91, 0.54, 1.0 - age / 0.20), 3)
