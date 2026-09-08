## 헤드리스 스모크 테스트: "Player.tscn 스프라이트 축 수정 확인".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSpriteAxis.tscn --quit-after 60
##
## docs/art/sprite-layouts-m1.md §1.2 수정안: walk_down=y0, walk_left=y16, walk_up=y32,
## walk_right=y48, 각 방향 4프레임은 x=0/16/32/48(열=프레임). 실제 입력 대신 Player가
## 게임플레이에서 쓰는 것과 동일한 API(set_facing/play_anim)를 호출해 애니메이션 이름과
## AtlasTexture.region을 그대로 로그로 확인한다.
extends Node


func _ready() -> void:
	print("=== SMOKE: 스프라이트 축(방향 입력 → 애니메이션 이름·region) ===")
	var scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player: Player = scene.instantiate()
	add_child(player)

	var dirs := {
		"down": Vector2.DOWN,
		"left": Vector2.LEFT,
		"up": Vector2.UP,
		"right": Vector2.RIGHT,
	}
	var expected_y := {"down": 0.0, "left": 16.0, "up": 32.0, "right": 48.0}
	var all_ok := true

	for dir_name: String in dirs:
		var input_dir: Vector2 = dirs[dir_name]
		player.set_facing(input_dir)
		player.play_anim("walk")
		var anim_name: StringName = player.sprite.animation
		print("입력=%s(%s) -> facing_name=%s, 재생 애니메이션=%s" \
			% [dir_name, input_dir, player.facing_name(), anim_name])

		var expected_anim: String = "walk_%s" % dir_name
		if String(anim_name) != expected_anim:
			print("  [FAIL] 기대 애니메이션=%s, 실제=%s" % [expected_anim, anim_name])
			all_ok = false

		var frames: SpriteFrames = player.sprite.sprite_frames
		for i in range(4):
			var tex := frames.get_frame_texture(StringName(expected_anim), i) as AtlasTexture
			if tex == null:
				print("  [FAIL] %s frame %d 텍스처 없음" % [expected_anim, i])
				all_ok = false
				continue
			var region: Rect2 = tex.region
			var expected_x: float = float(i * 16)
			var expected_y_val: float = expected_y[dir_name]
			print("  frame%d region=%s (기대 x=%.0f y=%.0f)" % [i, region, expected_x, expected_y_val])
			if not (is_equal_approx(region.position.x, expected_x) and is_equal_approx(region.position.y, expected_y_val)):
				print("  [FAIL] region 불일치")
				all_ok = false

	if all_ok:
		print("[PASS] 4방향 walk 애니메이션이 행=방향/열=프레임 축으로 정확히 배치됨(sprite-layouts-m1.md §1.2)")
	else:
		print("[FAIL] 스프라이트 축 불일치가 남아 있음")

	print("=== SMOKE 종료 ===")
	get_tree().quit()
