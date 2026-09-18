extends SceneTree
const BASE = "C:/Users/freer/ClaudeProject/make-passive-income/Games/"
const EXPECTED = "C:/Users/freer/ClaudeProject/make-passive-income/reviews/games-2026-09-12/runtime/npc-villager-story-v1/userdata/NpcVillagerStory"
var passes := 0
var failures := 0
class QuestFixture:
	extends RefCounted
	var states := {}
	func get_state(id): return states.get(id,"locked")
func check(ok, text):
	if ok: passes += 1
	else: failures += 1
	print("[PASS] " if ok else "[FAIL] ",text)
func _initialize(): call_deferred("run")
func run():
	if OS.get_user_data_dir().replace("\\", "/") != EXPECTED:
		quit(1)
		return
	if "--probe" in OS.get_cmdline_user_args():
		print("NPC_VILLAGER_PROBE_EXACT=",EXPECTED)
		quit(0)
		return
	var original := FileAccess.get_file_as_string(BASE+"game/scripts/ui/hud.gd")
	var start := original.find("func _on_npc_talked(")
	var end := original.find("func show_world_observation(",start)
	if start < 0 or end < start:
		quit(1)
		return
	# Exact production dispatch/helper bodies; only singleton binding replaced by read-only fixture.
	var adapter := GDScript.new()
	adapter.source_code = "extends RefCounted\nvar _npc_visit_lines = {}\nvar quest_system\nvar displayed = []\nfunc _push_log_line(text): displayed.append(text)\n" + original.substr(start,end-start).replace("QuestSystem.","quest_system.").replace("var cave_done :=", "var cave_done: bool =").replace("var montsil_done :=", "var montsil_done: bool =")
	var compiled := adapter.reload() == OK
	check(compiled,"current production dispatch/helper compile in isolated adapter")
	if not compiled:
		quit(1)
		return
	var hud = adapter.new()
	var quest := QuestFixture.new()
	hud.quest_system = quest
	var file := FileAccess.open(BASE+"game/localization/ui_ko.csv",FileAccess.READ)
	var translation := Translation.new()
	translation.locale = "ko"
	var keys := {}
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty(): continue
		check(row.size() == 2 and not keys.has(row[0]),"CSV unique two columns: "+row[0])
		if row.size() == 2:
			keys[row[0]] = row[1]
			translation.add_message(row[0],row[1])
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("ko")
	for npc in ["teo","meru","pinto","rozel","dami"]:
		for i in range(4):
			hud._on_npc_talked(StringName(npc))
			check(hud.displayed.back() == keys["npc.%s.everyday.%d" % [npc,i%3+1]],"dispatch cycle "+npc)
	quest.states["quest_main_a1_06_echocave"] = "completed"
	for npc in ["teo","meru"]:
		hud._on_npc_talked(StringName(npc))
		check(hud.displayed.back() == keys["npc.%s.after_cave.1" % npc],"existing cave group "+npc)
	for status in ["locked","available","active","complete_ready"]:
		quest.states["quest_side_heartland_montsil"] = status
		hud._npc_visit_lines.clear()
		hud._on_npc_talked(&"dami")
		check(hud.displayed.back() == keys["npc.dami.everyday.1"],"dami not completed: "+status)
	quest.states["quest_side_heartland_montsil"] = "completed"
	for i in range(4):
		hud._on_npc_talked(&"dami")
		check(hud.displayed.back() == keys["npc.dami.after_montsil.%d" % (i%3+1)],"completed dami cycle")
	hud._on_npc_talked(&"unknown")
	check(hud.displayed.back() == "npc.unknown.greeting","unknown key fallback preserved")
	var font_theme: Theme = load("res://ui/theme.tres")
	var panel := Control.new()
	panel.theme = font_theme
	root.add_child(panel)
	var label := Label.new()
	panel.add_child(label)
	var measured := 0
	var maxima := {}
	for size in [11,15]:
		label.add_theme_font_size_override("font_size",size)
		await process_frame
		check(label.get_theme_font_size("font_size") == size,"direct actual Label size "+str(size))
		var max_width := 0.0
		for npc in ["pinto","rozel","dami"]:
			for group in (["everyday","after_montsil"] if npc=="dami" else ["everyday"]):
				for i in range(1,4):
					var key = "npc.%s.%s.%d" % [npc,group,i]
					label.text = keys[key]
					var width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
					max_width = maxf(width,max_width)
					measured += 1
					check(width <= 154,"NPC_WIDTH size=%d key=%s width=%s" % [size,key,width])
		maxima[size] = max_width
	check(measured==24,"exact12 lines x2 actual font sizes")
	print("NPC_VILLAGER_RESULT PASS=",passes," FAIL=",failures," widths=",maxima)
	panel.queue_free()
	TranslationServer.remove_translation(translation)
	await process_frame
	quit(0 if failures == 0 else 1)
