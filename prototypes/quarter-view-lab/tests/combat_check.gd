extends SceneTree
class BodyCenterActor extends QuarterActor:
	# Preserve historical attack origins when replaying old controllers after rigging.
	func attack_origin() -> Vector2:
		return global_position + Vector2(0, -20)
## Isolated deterministic actor/physics checks, not a rendered-play or audio review.
var passed: int = 0
var failed: int = 0
var scene: Node2D
var actor_root: Node2D
var player: QuarterActor
var slime: QuarterActor
var combat: Node2D

func _init() -> void:
	var expected := OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	print("QUARTER_COMBAT_USER_DIR=" + actual)
	if expected.is_empty() or actual != expected:
		printerr("QUARTER_COMBAT_ISOLATION_FAIL")
		quit(2)
		return
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		printerr("FAIL " + label)

func reset_pair() -> void:
	combat.reset_encounter()
	slime.set_phase("test_hold", 100.0) # explicitly inert target fixture
	player.facing = Vector2.RIGHT
	player.attack_facing = Vector2.RIGHT

func _run() -> void:
	scene = Node2D.new()
	root.add_child(scene)
	current_scene = scene
	actor_root = Node2D.new()
	scene.add_child(actor_root)
	player = load("res://actor.gd").new()
	actor_root.add_child(player)
	player.configure("player", Vector2(400, 400))
	slime = load("res://actor.gd").new()
	actor_root.add_child(slime)
	slime.configure("slime", Vector2(700, 400))
	combat = load("res://combat.gd").new()
	scene.add_child(combat)
	combat.setup(scene, actor_root, player)
	combat.set_physics_process(false)
	await physics_frame
	check(player._sprite.texture != null and slime._sprite.texture != null, "two imported legacy proxy textures present")
	check(player._label.text.contains("임시") and not combat.get_status().fin_animation_ready, "proxy label and unfinished Fin status explicit")
	for entry in [[Vector2.DOWN, 0], [Vector2.UP, 1], [Vector2.LEFT, 2], [Vector2.RIGHT, 3]]:
		player.facing = entry[0]
		player.moving = true
		player.animation_time = 1.0 / 9.0
		player._refresh_visual()
		check(player._sprite.region_rect == Rect2(int(entry[1]) * 16, 16, 16, 16), "original Knight column mapping " + str(entry[0]))
	reset_pair()
	combat.queue_attack()
	combat._physics_process(0.01)
	check(player.phase == "startup" and slime.hp == 45, "empty attack starts preparation without damage")
	for index in 60:
		combat._physics_process(1.0 / 60.0)
	check(player.phase == "idle" and slime.hp == 45 and combat.landed_hits == 0, "complete empty strike returns idle with zero hits")
	combat.queue_attack()
	combat._physics_process(0.01)
	slime.global_position = player.global_position + Vector2(50, 0)
	combat._physics_process(0.02) # strictly before the new 50ms boundary, not exactly on it
	check(player.phase == "startup" and slime.hp == 45, "target in range during preparation takes no damage")
	player.set_phase("active", float(combat.config.active_sec))
	combat._check_player_sweep(0.0, 1.0)
	check(slime.hp == 30 and combat.landed_hits == 1, "active sweep deals exactly one hit")
	combat._check_player_sweep(0.0, 1.0)
	check(slime.hp == 30 and combat.landed_hits == 1, "same target cannot be hit twice within strike")
	check(slime.knockback_velocity.x > 0.0, "player strike pushes slime away")
	var frozen_player := player.global_position
	var frozen_slime := slime.global_position
	var frozen_phase := player.phase_elapsed
	var frozen_animation := player.animation_time
	combat._keys[KEY_D] = true
	combat.queue_attack()
	combat.queue_attack()
	combat._physics_process(0.02)
	check(player.global_position == frozen_player and slime.global_position == frozen_slime, "hitstop freezes both actor positions even with movement held")
	check(player.phase_elapsed == frozen_phase and player.animation_time == frozen_animation, "hitstop freezes phase and sprite clocks together")
	check(combat._hitstop_buffered and combat.attack_buffer_remaining > 0.0, "repeated hitstop presses hold one pending attack")
	slime.is_dead = true # remove further target contacts, isolate buffer consumption
	var starts := 0
	for index in 120:
		var previous: String = player.phase
		combat._physics_process(1.0 / 60.0)
		if player.phase == "startup" and previous != "startup":
			starts += 1
	check(starts == 1 and not combat._hitstop_buffered, "hitstop buffer produces exactly one subsequent strike")
	reset_pair()
	slime.global_position = player.global_position + Vector2(50, 0)
	player.set_phase("recovery", float(combat.config.recovery_sec))
	combat._physics_process(0.05)
	check(slime.hp == 45 and combat.landed_hits == 0, "recovery has no damage window")
	for index in 8:
		var direction := Vector2.from_angle(index * TAU / 8.0)
		player.facing = direction
		player.attack_facing = direction
		player.set_phase("active", float(combat.config.active_sec))
		slime.global_position = player.global_position + direction * 60.0
		check(combat.swept_contact(player, slime, 0, 1) != Vector2.INF, "visible blade swept contact direction %d" % index)
	slime.global_position = player.global_position - player.attack_facing * 60.0
	check(combat.swept_contact(player, slime, 0, 1) == Vector2.INF, "target behind sword sweep is not hit")
	reset_pair()
	slime.global_position = player.global_position - Vector2(45, 0)
	slime.attack_facing = Vector2.RIGHT
	slime.set_phase("active", float(combat.config.slime_active_sec))
	combat._update_slime(slime, 0.001)
	check(player.hp == 92 and player.knockback_velocity.x > 0, "slime contact pushes player away not toward attacker")
	_check_attack_response()
	_check_hand_attachment()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(430, 400)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 240)
	collision.shape = rectangle
	wall.add_child(collision)
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	reset_pair()
	slime.global_position = Vector2(455, 400)
	# The hand-origin ray must use the actual attack bitmap/socket, not idle.
	player.facing = Vector2.RIGHT
	player.attack_facing = Vector2.RIGHT
	player.set_phase("active", float(combat.config.active_sec))
	check(combat.swept_contact(player, slime, 0, 1) == Vector2.INF, "wall blocks player's blade damage")
	player.global_position = Vector2(411, 400)
	slime.global_position = Vector2(449, 400)
	slime.attack_facing = Vector2.LEFT
	slime.set_phase("active", float(combat.config.slime_active_sec))
	combat._update_slime(slime, 0.001)
	check(player.hp == 100, "thin wall also blocks slime proximity damage")
	player.global_position = Vector2(400, 400)
	player.apply_damage(1, Vector2.RIGHT, 100.0, 0.1, 0.2)
	player.move_body(0.1, Vector2.ZERO)
	check(player.global_position.x <= 412.1, "knockback collision stops before wall")
	var horizontal := StaticBody2D.new()
	horizontal.collision_layer = 1
	horizontal.collision_mask = 0
	horizontal.position = Vector2(700, 101)
	var horizontal_shape := CollisionShape2D.new()
	var horizontal_rect := RectangleShape2D.new()
	horizontal_rect.size = Vector2(240, 2)
	horizontal_shape.shape = horizontal_rect
	horizontal.add_child(horizontal_shape)
	scene.add_child(horizontal)
	await physics_frame
	await physics_frame
	reset_pair()
	player.global_position = Vector2(700, 85)
	player.facing = Vector2.DOWN
	player.attack_facing = Vector2.DOWN
	player.set_phase("active", float(combat.config.active_sec))
	slime.global_position = Vector2(700, 117)
	check(combat.swept_contact(player, slime, 0, 1) == Vector2.INF, "horizontal thin wall blocks feet-separated blade contact")
	slime.attack_facing = Vector2.UP
	slime.set_phase("active", float(combat.config.slime_active_sec))
	combat._update_slime(slime, 0.001)
	check(player.hp == 100, "horizontal thin wall blocks feet-separated slime contact")
	player.is_dead = true
	combat.queue_attack()
	check(combat.attack_buffer_remaining == 0, "dead player cannot queue attack")
	combat.reset_encounter()
	check(player.hp == 100 and slime.hp == 45 and not player.is_dead and not slime.is_dead, "reset restores both health and death states")
	check(player.global_position == player.spawn_position and slime.global_position == slime.spawn_position, "reset restores original spawn points")
	check(combat.freeze_remaining == 0 and combat.attack_buffer_remaining == 0 and combat._marks.is_empty() and combat.kills == 0 and combat.landed_hits == 0, "reset clears impact buffers and sample counters")
	check(player.phase == "idle" and player.knockback_remaining == 0 and player.invulnerable_remaining == 0, "reset clears phase knockback and invulnerability")
	print("QUARTER_COMBAT_RESULT PASS=%d FAIL=%d" % [passed, failed])
	_finish.call_deferred()

func _check_attack_response() -> void:
	# A/B replay: byte-preserved v1 controller + v1 values, sharing current actor
	# physics with a BODY-CENTER attack-origin override and explicit linear curve.
	# The override prevents the new hand rig contaminating historical timing. Not an old game executable,
	# real keyboard latency, rendered latency, moving target or audio measurement.
	check(FileAccess.get_sha256("res://tests/fixtures/attack-response-v1/combat.gd").to_upper() == "14BBE97856BF458A14DACF8941DCFADBD4D79606DC384459C2A67133822B47DA", "baseline controller bytes match previously tested v1")
	check(FileAccess.get_sha256("res://tests/fixtures/attack-response-v1/combat_config.json").to_upper() == "1581418AFD23109B0229C4AA4B31CA5456DF9C227FD68E1BEB488B8524AAFCB6", "baseline timing config bytes match v1")
	var baseline := _make_baseline("res://tests/fixtures/attack-response-v1/combat.gd")
	baseline.config = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/attack-response-v1/combat_config.json"))
	baseline.player.sweep_ease_out_power = 1.0
	var pre_hand := _make_baseline("res://tests/fixtures/attack-response-v2/combat.gd")
	check(FileAccess.get_sha256("res://tests/fixtures/attack-response-v2/combat.gd").to_upper() == "346D0F56A979B999BF640DD0F362BFD7573F6C6932EA1DB7409A061A2ACCFF76", "pre-hand controller bytes preserve approved response version")
	var all_improved := true
	var all_bounded := true
	for index in 8:
		var direction := Vector2.from_angle(index * TAU / 8.0)
		var old_ms := _measure_first_damage(baseline, direction, 1.0 / 60.0)
		var pre_hand_ms := _measure_first_damage(pre_hand, direction, 1.0 / 60.0)
		var new_ms := _measure_first_damage(combat, direction, 1.0 / 60.0)
		print("ATTACK_RESPONSE_60HZ direction=%d distance_px=62 old_logic_ms=%.3f new_logic_ms=%.3f" % [index, old_ms, new_ms])
		print("HAND_ATTACHMENT_RESPONSE_60HZ direction=%d distance_px=62 before_hand_ms=%.3f hand_ms=%.3f" % [index, pre_hand_ms, new_ms])
		all_improved = all_improved and old_ms > 0 and new_ms > 0 and new_ms < old_ms
		all_bounded = all_bounded and new_ms <= 83.334
	check(all_improved, "8 direction fixed-distance input-handler to damage replay improves")
	check(all_bounded, "8 direction 60Hz damage observed within five physics ticks")
	var old_30 := _measure_first_damage(baseline, Vector2.RIGHT, 1.0 / 30.0)
	var new_30 := _measure_first_damage(combat, Vector2.RIGHT, 1.0 / 30.0)
	print("ATTACK_RESPONSE_30HZ direction=0 distance_px=62 old_logic_ms=%.3f new_logic_ms=%.3f" % [old_30, new_30])
	check(new_30 > 0 and new_30 < old_30, "30Hz larger tick preserves faster contact")
	# A hit must leave the rendered blade at an angle that actually touches the target.
	var contact_axis := Vector2.from_angle(player.blade_angle(player.phase_elapsed / player.phase_duration))
	var closest := Geometry2D.get_closest_point_to_segment(slime.hurt_center(), player.attack_origin() + contact_axis * player.blade_inner, player.attack_origin() + contact_axis * player.blade_outer)
	check(player.phase == "active" and combat.freeze_remaining > 0 and closest.distance_to(slime.hurt_center()) <= slime.actor_radius + 0.001, "hitstop holds actual first-contact blade segment, not overshot recovery")
	baseline.stop_sounds()
	baseline._swing_audio.stream = null
	baseline._hit_audio.stream = null
	baseline.queue_free()
	pre_hand.stop_sounds()
	pre_hand._swing_audio.stream = null
	pre_hand._hit_audio.stream = null
	pre_hand.queue_free()
	player.set_combat(combat)
	slime.set_combat(combat)
	reset_pair()
	combat.queue_attack()
	combat._physics_process(0.20)
	check(player.phase == "recovery" and absf(player.phase_elapsed - 0.065) < 0.0001 and slime.hp == 45, "200ms empty tick carries startup and active remainder into recovery")
	combat._physics_process(0.10)
	check(player.phase == "idle" and combat.landed_hits == 0, "large tick finishes recovery without skipped phase or extra hit")
	check(is_equal_approx(float(combat.config.move_speed), 230.0) and is_equal_approx(float(combat.config.startup_sec) + float(combat.config.active_sec) + float(combat.config.recovery_sec), 0.275), "movement unchanged and sample empty attack totals 275ms")
	player.set_phase("startup", float(combat.config.startup_sec))
	player.tick_clock(0.02)
	check(player.blade_visual().reach == player.blade_outer and player.blade_visual().alpha == 1.0 and player._sprite.region_rect.position.y == 0, "preparation preserves opaque held weapon and genuine idle body pose")
	player.set_phase("active", float(combat.config.active_sec))
	player.tick_clock(0.02)
	check(is_equal_approx(float(player.blade_visual().angle), player.blade_angle(player.phase_elapsed / player.phase_duration)) and is_equal_approx(float(player.blade_visual().reach), player.blade_outer) and player._sprite.region_rect.position.y == 64, "active render shares eased collision angle and genuine attack pose")
	player.set_phase("recovery", float(combat.config.recovery_sec))
	player.tick_clock(0.11)
	check(player.blade_visual().reach == player.blade_outer and player.blade_visual().alpha == 1.0 and player._sprite.region_rect.position.y == 0, "late recovery returns idle pose without shrinking or hiding held weapon")
	check(player._sprite.rotation == 0 and player._sprite.position == Vector2(0, -24) and player._sprite.scale == Vector2(4, 4), "body bitmap is never rotated displaced or stretched")
	reset_pair()

func _measure_first_damage(controller: Node2D, direction: Vector2, step: float) -> float:
	controller.reset_encounter()
	var test_player: QuarterActor = controller.player
	var test_slime: QuarterActor = controller.slimes[0]
	test_slime.set_phase("test_hold", 100.0)
	test_player.facing = direction
	test_player.attack_facing = direction
	test_slime.global_position = test_player.global_position + direction * 62.0
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	controller._unhandled_input(event) # event handler replay, not physical OS input
	for tick in range(1, 121):
		controller._physics_process(step)
		if test_slime.hp < test_slime.max_hp:
			controller.stop_sounds()
			return tick * step * 1000.0
	controller.stop_sounds()
	return -1.0

func _make_baseline(path: String) -> Node2D:
	var baseline_actors := Node2D.new()
	scene.add_child(baseline_actors)
	var old_player := BodyCenterActor.new()
	baseline_actors.add_child(old_player)
	old_player.configure("player", Vector2(400, 400))
	var old_slime := QuarterActor.new()
	baseline_actors.add_child(old_slime)
	old_slime.configure("slime", Vector2(700, 400))
	var controller: Node2D = load(path).new()
	scene.add_child(controller)
	controller.setup(scene, baseline_actors, old_player)
	controller.set_physics_process(false)
	return controller

func _check_hand_attachment() -> void:
	check(FileAccess.get_sha256("res://combat_config.json").to_upper() == "8EDA33E823DAE242681825DE7BFC00F36C2909D606F3DDD1AE169C96FF90E244", "approved timing damage range movement config is byte unchanged")
	check(FileAccess.get_sha256("res://assets/proxy-knight.png").to_upper() == "D20EACC1334ABE43BD69C9298F55E383B86A1E71C726973240EB2BB0C4F5F08C", "original Knight bitmap is byte unchanged")
	var attached := true
	var layered := true
	var aligned := true
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		player.facing = direction
		player.attack_facing = direction
		for state in ["idle", "startup", "active", "recovery"]:
			player.set_phase(state, 0.1)
			player.tick_clock(0.02)
			var binding := player.get_weapon_attachment()
			attached = attached and binding.hand_global.distance_to(binding.hilt_global) < 0.0001 and binding.visible
			aligned = aligned and binding.hand_global == player.attack_origin() and is_equal_approx(binding.blade_start_global.distance_to(binding.hand_global), player.blade_inner) and is_equal_approx(binding.blade_tip_global.distance_to(binding.hand_global), player.blade_outer)
			if player.uses_fin():
				layered = layered and not player._weapon_back.visible and not player._weapon_front.visible and not player._glove.visible
			else:
				layered = layered and player._weapon_back.visible == (direction == Vector2.UP) and player._weapon_front.visible == (direction != Vector2.UP) and player._glove.get_index() > player._sprite.get_index()
	check(attached, "all four directions and four phases keep hilt at original hand socket")
	check(aligned, "render endpoints and attack origin use the same hand geometry")
	check(layered and player._weapon_back.get_index() < player._sprite.get_index() and player._weapon_front.get_index() > player._sprite.get_index(), "up behind and other directions in front preserve body glove draw order")
	var walking_attached := true
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		player.facing = direction
		player.set_phase("idle")
		player.moving = true
		for row in [1, 2, 3]:
			player.animation_time = (row + 0.1) / 9.0
			player._refresh_visual()
			walking_attached = walking_attached and int(player.socket_spec().row) == row and player.get_weapon_attachment().row == row
	check(walking_attached, "walking sockets follow each actual source frame rather than idle hand")
	player.moving = false
	player.set_phase("recovery", float(combat.config.recovery_sec))
	player.phase_elapsed = player.phase_duration
	player._refresh_visual()
	var recovered := player.get_weapon_attachment()
	player.set_phase("idle")
	var idle := player.get_weapon_attachment()
	check(recovered.hand_global.distance_to(idle.hand_global) < 0.001 and recovered.blade_tip_global.distance_to(idle.blade_tip_global) < 0.001 and idle.visible, "recovery endpoint equals persistent idle weapon socket angle and length")
	reset_pair()

func _finish() -> void:
	# Verbose diagnosis identified WAV playback resources, not orphan actors/shapes.
	# Manual simulation outruns the audio thread; stop and allow real-time mixer flush.
	combat.stop_sounds()
	combat._swing_audio.stream = null
	combat._hit_audio.stream = null
	var deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await process_frame
	current_scene = null
	scene.queue_free()
	scene = null
	actor_root = null
	player = null
	slime = null
	combat = null
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
