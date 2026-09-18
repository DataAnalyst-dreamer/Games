extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ",label)
func run() -> void:
	root.size = Vector2i(1920,1080)
	for frame in range(4): await process_frame
	if OS.get_user_data_dir().replace("\\", "/") != OS.get_environment("DIAG_EXPECTED_USER_DIR"):
		quit(1)
		return
	TranslationServer.set_locale("ko")
	var data := root.get_node("Data")
	var state := root.get_node("GameState")
	var layer = load("res://scenes/ui/InventoryMenu.tscn").instantiate()
	root.add_child(layer)
	var menu = layer.get_node("Root")
	for id in ["slime_jelly","rabbit_horn","mushroom_cap","weapon_common_1"]:
		state.pickup_item({"uid":"material_"+id,"item_id":id,"grade":"common","quantity":3,"affixes":[],"enhance_level":0,"refine_left":0},data.get_value("items",id,{}))
	menu.open_menu()
	await process_frame
	for index in range(3):
		var cell = menu._grid_cells[index]
		check(cell.item_texture.visible and cell.item_texture.size == Vector2(20,20),"material %d loaded20" % index)
		check(cell.grade_icon.visible and cell.grade_bar.visible and cell.qty_label.text == "x3","material %d badges" % index)
		menu.focus_grid_at(index)
		check(menu._description_label.visible and not menu.header_label.text.contains("item_"),"material %d name description" % index)
		cell.set_item(Color.WHITE,"●",1,0)
		check(cell.item_texture.texture == null and cell.icon.visible,"material %d reuse fallback" % index)
		cell.set_item_texture(menu._optional_item_icon("res://missing-material-%d.png" % index))
		check(cell.icon.visible and cell.item_texture.texture == null,"material %d missing fallback" % index)
		menu._paint_cell_with_slot(cell,state.inventory.slots[index])
	check(menu._grid_cells[3].icon.visible and not menu._grid_cells[3].item_texture.visible,"other item unchanged")
	menu.focus_grid_at(1)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("INTEGRATED_CAPTURE")) == OK,"three materials screenshot")
	print("THREE_MATERIAL_RESULT PASS=",checks-failures," FAIL=",failures)
	quit(0 if failures == 0 else 1)


