extends SceneTree
var passed := 0
var failed := 0
var comparison: Node2D

func _init() -> void:
	var expected := OS.get_environment("QUARTER_LAB_EXPECTED_USER_DIR").replace("\\", "/")
	print("QUARTER_DESIGN_USER_DIR=" + OS.get_user_data_dir().replace("\\", "/"))
	if expected.is_empty() or OS.get_user_data_dir().replace("\\", "/") != expected:
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

func press(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == Vector2i(1920,1080) and image.save_png("user://"+filename) == OK, "native FHD readback " + filename)

func _run() -> void:
	comparison = load("res://DesignCompare.tscn").instantiate()
	root.add_child(comparison)
	current_scene = comparison
	await process_frame
	await process_frame
	check(comparison.ready_for_review, "actual comparison scene ready")
	check(comparison.originals.size() == 3 and comparison.candidates.size() == 3, "three actual original and candidate groups")
	check(comparison.find_child("Combat",true,false) == null, "no combat controller in static comparison")
	check(comparison.zoom_factor == 1 and comparison.comparison_mode == 0, "default side-by-side actual display scale")
	for index in 3:
		var entry: Dictionary = comparison.entries[index]
		var record: Dictionary = comparison.records[index]
		if str(entry.id) == "fin":
			# New PARTIAL-APP gate. The original three-candidate gate is preserved
			# separately with native1 / PASS19 FAIL3, not relabelled as successful.
			check(not bool(entry.enabled), "failed Fin candidate stays explicitly disabled")
			check(not bool(record.loaded), "failed Fin is not replaced with a fake successful asset")
			check(comparison.candidates[index].get_child_count() == 0 and str(entry.status_key) == "fin_blocked", "Fin slot stays empty with explicit extraction failure status")
			continue
		check(bool(entry.enabled), "real candidate required " + str(entry.id))
		check(bool(record.loaded), "imported SHA size transparency bbox validated " + str(entry.id))
		var shown: Vector2 = record.get("display_size", Vector2.ZERO)
		var target := Vector2(entry.target_size[0],entry.target_size[1])
		check(shown.x > 0 and shown.y > 0 and shown.x <= target.x + 0.01 and shown.y <= target.y + 0.01 and (is_equal_approx(shown.x,target.x) or is_equal_approx(shown.y,target.y)), "alpha128 silhouette proportional display box " + str(entry.id))
		print("DESIGN_DISPLAY " + str(entry.id) + " core_px=" + str(shown) + " faint_extent_px=" + str(record.get("faint_extent_size",Vector2.ZERO)))
	var readiness: Dictionary = comparison.get_readiness()
	check(not readiness.asset_set_ready and readiness.available_candidates == 2 and readiness.missing_candidates == ["fin"], "complete asset-set gate remains false independently of partial app")
	await capture("design-compare-native.png")
	await press(KEY_TAB)
	check(comparison.comparison_mode == 1 and comparison.originals[0].position == Vector2(320,780), "Tab original at center")
	await press(KEY_TAB)
	check(comparison.comparison_mode == 2 and comparison.candidates[0].position == Vector2(320,780) and not comparison.originals[0].visible, "Tab candidate at same center")
	await press(KEY_Z)
	check(comparison.zoom_factor == 2 and comparison.candidates[0].scale == Vector2(2,2), "explicit 2x static inspection")
	await capture("design-compare-candidates-2x.png")
	await press(KEY_B)
	check(comparison.dark_enabled and comparison.dark_backings[0].visible, "dark backing enables actual alpha compositing review")
	await capture("design-compare-dark-2x.png")
	await press(KEY_B)
	check(comparison.backing_mode == 2 and comparison.dark_backings[0].color == Color("fff2d0"), "light backing enables actual alpha compositing review")
	await capture("design-compare-light-2x.png")
	var report := FileAccess.open("user://design-readiness.json",FileAccess.WRITE)
	check(report != null, "write distinct partial app and complete asset-set readiness")
	if report != null:
		readiness.partial_app_passed = failed == 0
		readiness.app_checks_passed = passed
		readiness.app_checks_failed = failed
		report.store_string(JSON.stringify(readiness,"\t"))
		report.close()
	print("QUARTER_DESIGN_ASSET_SET_READY=" + str(readiness.asset_set_ready))
	print("QUARTER_DESIGN_PARTIAL_APP_RESULT PASS=%d FAIL=%d" % [passed,failed])
	current_scene = null
	comparison.queue_free()
	comparison = null
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)
