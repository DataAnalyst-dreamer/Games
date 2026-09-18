extends SceneTree

func _initialize() -> void:
	var sheet := Image.load_from_file("res://assets/sprites/characters/fin/fin-walk-v1.png")
	assert(sheet != null and sheet.get_size() == Vector2i(384, 256))
	for row in range(4):
		for col in range(8):
			var frame := sheet.get_region(Rect2i(col * 48, row * 64, 48, 64))
			var occupied := frame.get_used_rect()
			assert(occupied.size.x > 20 and occupied.size.y > 40)
			assert(occupied.position.x > 0 and occupied.end.x < 48)
			assert(occupied.end.y == 56)
			for x in range(48):
				assert(frame.get_pixel(x, 0).a == 0.0)
				assert(frame.get_pixel(x, 63).a == 0.0)
	print("[PASS] Fin atlas: 32 frames, transparent margins, consistent feet, no cell clipping")
	quit(0)
