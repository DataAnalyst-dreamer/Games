extends SceneTree
const EXPECTED = "C:/Users/freer/ClaudeProject/make-passive-income/reviews/games-2026-09-12/runtime/hud-large-story-v1/userdata/HudLargeStory"
var passes := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok, message):
	if ok: passes += 1
	else: failures += 1
	print("[PASS] " if ok else "[FAIL] ",message)
func expire(row):
	if not is_instance_valid(row): return
	var tween := create_tween()
	tween.tween_property(row,"modulate:a",0.0,0.01)
	tween.tween_callback(row.queue_free)
func run():
	if OS.get_user_data_dir().replace("\\", "/") != EXPECTED:
		quit(1)
		return
	var view := SubViewport.new()
	view.size = Vector2i(640,360)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas := Control.new()
	canvas.theme = load("res://ui/theme.tres")
	view.add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color("202820")
	bg.size = Vector2(640,360)
	canvas.add_child(bg)
	var title := Label.new()
	title.text = "QA ONLY / retained text + scrolling candidate / NOT ADOPTED"
	title.position = Vector2(8,16)
	canvas.add_child(title)
	# Repeating existing text is stress input, not new game dialogue.
	var full_text := "왔으면 밥부터 먹어. 국 데워줄게. ".repeat(8)
	var panels: Array[ScrollContainer] = []
	for index in range(2):
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(8+index*210,280)
		scroll.size = Vector2(154,64)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		canvas.add_child(scroll)
		var label := Label.new()
		label.text = full_text
		label.add_theme_font_size_override("font_size",15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(label)
		panels.append(scroll)
	await process_frame
	await process_frame
	for scroll in panels:
		var label = scroll.get_child(0)
		check(label.text == full_text,"long original text retained without truncation")
		check(label.size.y > 64,"single long message exceeds64 before clipping")
		check(scroll.size == Vector2(154,64),"scroll viewport stays154x64")
		check(scroll.clip_contents,"scroll viewport clips outside pixels")
	panels[1].scroll_vertical = 100000
	await process_frame
	check(panels[1].scroll_vertical > 0,"long content can reach later segment programmatically")
	var endbar := panels[1].get_v_scroll_bar()
	check(is_equal_approx(endbar.value+endbar.page,endbar.max_value),"end of long message reachable")
	# Test-only in-memory history distinguishes retained data from visible rows.
	var burst := VBoxContainer.new()
	burst.position = Vector2(430,280)
	burst.size = Vector2(154,64)
	canvas.add_child(burst)
	var history: Array[String] = []
	for i in range(10):
		var text := "짐을 살펴본 자리다. #%d" % i
		history.append(text)
		var row := Label.new()
		row.text = text
		row.add_theme_font_size_override("font_size",15)
		burst.add_child(row)
		var callback = expire.bind(row)
		create_timer(0.02).timeout.connect(callback)
		if burst.get_child_count() > 2:
			var oldest = burst.get_child(0)
			burst.remove_child(oldest)
			oldest.queue_free()
	check(history.size() == 10 and history[0].ends_with("#0") and history[9].ends_with("#9"),"burst10 order retained in test memory only")
	check(burst.get_child_count() == 2,"burst visible rows limited to2")
	await create_timer(0.08).timeout
	check(burst.get_child_count() == 0,"queued old callbacks and live timers finish without stale row deletion")
	var replacement := Label.new()
	replacement.text = "new row survives"
	burst.add_child(replacement)
	await create_timer(0.05).timeout
	check(is_instance_valid(replacement) and replacement.get_parent() == burst,"replacement not targeted by old callbacks")
	RenderingServer.force_draw(false)
	var capture := view.get_texture().get_image()
	check(capture.save_png("C:/Users/freer/ClaudeProject/make-passive-income/Games/docs/qa/hud-large-edge-v1.png") == OK,"new edge-case viewport saved")
	print("HUD_LARGE_EDGE_RESULT PASS=",passes," FAIL=",failures)
	view.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
