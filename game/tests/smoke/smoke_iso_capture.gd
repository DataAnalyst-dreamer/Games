## 등각 iso-1 육안 확인용 캡처. Xvfb 필요(--headless 아님).
##
## 실행: xvfb-run -a godot --path game res://tests/smoke/SmokeIsoCapture.tscn --quit-after 900
## 출력: docs/art/preview/iso-1-grid.png
##
## 마름모 격자가 실제로 등각으로 도는지, 화면 상하좌우 입력이 격자에서 어느 방향으로
## 가는지를 한 장에 담는다 - 디버그 격자선과 이동 방향 표시를 얹는다(iso-1 한정).
extends Node

## 플레이어를 놓을 격자 셀.
const VIEW_CELL := Vector2i(0, 0)
## 방향 표시를 그릴 화면 입력 4방향.
const ARROW_DIRS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]


func _ready() -> void:
	print("=== CAPTURE 등각 격자 (iso-1) ===")
	if DisplayServer.get_name() == "headless":
		print("[SKIP] 렌더러 없음 - xvfb-run 으로 실행해야 캡처된다")
		print("=== CAPTURE 종료 ===")
		get_tree().quit(0)
		return
	var out_dir := ProjectSettings.globalize_path("res://").path_join("../docs/art/preview").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)

	var main: Node2D = load("res://scenes/main/Main.tscn").instantiate() as Node2D
	add_child(main)
	var player: Player = main.get_node("Player") as Player
	for child: Node in main.get_children():
		if child is MonsterBase:
			child.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = IsoMath.cell_to_screen(VIEW_CELL)
	player.play_anim("idle")

	var overlay := _Overlay.new()
	overlay.origin = player.global_position
	overlay.z_index = 50
	main.add_child(overlay)

	for _i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var path := out_dir.path_join("iso-1-grid.png")
	var saved := get_viewport().get_texture().get_image().save_png(path) == OK
	print("%s 등각 격자 -> %s" % ["[PASS]" if saved else "[FAIL]", path])
	print("=== CAPTURE 종료 ===")
	get_tree().quit(0 if saved else 1)


## 격자선 + 화면 입력 4방향이 격자에서 어디로 가는지 표시하는 디버그 오버레이.
class _Overlay extends Node2D:
	var origin: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var size: float = float(Tuning.TILE_SIZE_PROTOTYPE)
		var line := Color(1, 1, 1, 0.22)
		# 격자선: 지면의 직교 격자를 화면으로 보내면 마름모 격자가 된다.
		for index in range(-14, 15):
			var along := 14.0 * size
			var offset := float(index) * size
			draw_line(to_local(origin + IsoMath.to_screen(Vector2(-along, offset))),
				to_local(origin + IsoMath.to_screen(Vector2(along, offset))), line, 1.0)
			draw_line(to_local(origin + IsoMath.to_screen(Vector2(offset, -along))),
				to_local(origin + IsoMath.to_screen(Vector2(offset, along))), line, 1.0)
		# 화면 입력 4방향 -> 실제 이동 방향. 길이는 지면 1초치(walk_speed).
		var speed: float = float(Data.get_value("combat", "movement.walk_speed_px", 160.0))
		for direction: Vector2 in ARROW_DIRS:
			var velocity: Vector2 = IsoMath.move_velocity(direction, speed)
			var tip := to_local(origin + velocity)
			draw_line(to_local(origin), tip, Color(1, 0.85, 0.2), 3.0)
			draw_circle(tip, 5.0, Color(1, 0.85, 0.2))
