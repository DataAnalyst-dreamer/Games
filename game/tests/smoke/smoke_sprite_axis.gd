## 헤드리스 스모크 테스트: "Player.tscn 스프라이트 축 수정 확인".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeSpriteAxis.tscn --quit-after 60
##
## D-137 원본 시각 검증: 열=방향(down/up/left/right), 행=보행 시간.
## idle은 첫 행, attack은 y64의 방향별 단일 포즈. 실제 입력 대신 Player가
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
	var direction_columns := {"down": 0.0, "up": 16.0, "left": 32.0, "right": 48.0}
	var all_ok := true

	for dir_name: String in dirs:
		var input_dir: Vector2 = dirs[dir_name]
		# D-128: 축 전환에 최소 유지 시간(Tuning.FACING_AXIS_SWITCH_MIN_INTERVAL_SEC)이
		# 생겼다 — 이 테스트는 스프라이트 축 매핑(방향→애니메이션/region)만 확인하는
		# 목적이라, 방향을 바꾸기 전 물리 프레임을 충분히 흘려보내 디바운스 구간을
		# 벗어난 뒤 set_facing()을 호출한다(실제 플레이에서도 방향 전환 사이엔 여러
		# 프레임이 지난다 — 여기서는 디바운스 자체를 검증하지 않는다).
		for _i in range(10):
			player._physics_process(1.0 / 60.0)
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
		if frames.get_frame_count(StringName(expected_anim)) != 4:
			push_error("[FAIL] prototype walk must have four temporal frames")
			all_ok = false
			continue
		for i in range(4):
			var tex := frames.get_frame_texture(StringName(expected_anim), i) as AtlasTexture
			if tex == null:
				print("  [FAIL] %s frame %d 텍스처 없음" % [expected_anim, i])
				all_ok = false
				continue
			var region: Rect2 = tex.region
			var expected_x: float = direction_columns[dir_name]
			var expected_y_val: float = float(i * 16)
			print("  frame%d region=%s (기대 x=%.0f y=%.0f)" % [i, region, expected_x, expected_y_val])
			if region != Rect2(expected_x, expected_y_val, 16.0, 16.0):
				print("  [FAIL] region 불일치")
				all_ok = false
		# 각 입력 방향에서 idle/attack도 같은 원본 방향 열을 유지해야 한다.
		for action: String in ["idle", "attack"]:
			player.play_anim(action)
			var clip := StringName("%s_%s" % [action, dir_name])
			if player.sprite.animation != clip or frames.get_frame_count(clip) != 1:
				push_error("[FAIL] wrong direction or non-pose frames for %s" % clip)
				all_ok = false
				continue
			var pose := frames.get_frame_texture(clip, 0) as AtlasTexture
			var pose_y := 64.0 if action == "attack" else 0.0
			if pose == null or pose.region != Rect2(direction_columns[dir_name], pose_y, 16.0, 16.0):
				push_error("[FAIL] mixed direction in %s" % clip)
				all_ok = false
			if action == "attack":
				var duration := frames.get_frame_duration(clip, 0) / frames.get_animation_speed(clip)
				if frames.get_animation_loop(clip) or not is_equal_approx(duration, Tuning.ATTACK_HIT_DURATION_SEC):
					push_error("[FAIL] attack pose changed existing combat duration")
					all_ok = false

	if all_ok:
		print("[PASS] walk/idle/attack preserve source direction columns; combat duration unchanged (D-137)")
	else:
		print("[FAIL] 스프라이트 축 불일치가 남아 있음")

	print("=== SMOKE 종료 ===")
	get_tree().quit(0 if all_ok else 1)
