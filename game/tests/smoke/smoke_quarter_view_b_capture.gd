## 단계 (b2) 육안 확인용 스크린샷 — 마을 입구 구역. Xvfb 필요(--headless 아님).
##
## 실행: xvfb-run -a godot --path game res://tests/smoke/SmokeQuarterViewBCapture.tscn --quit-after 900
## 출력: docs/art/preview/quarter-view-b-village.png
##
## (a) 캡처와 달리 **캡처 전용 줌을 쓰지 않는다** — 32px 아트가 들어온 뒤로는 실제 게임
## 화면 그대로가 근거여야 한다.
extends Node

## 플레이어를 놓을 지점(타일). 절벽 틈 남쪽에서 마을을 올려다보는 구도.
const VIEW_TILE := Vector2(0.0, -8.0)


func _ready() -> void:
	print("=== CAPTURE 쿼터뷰 (b2): 마을 입구 ===")
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
	# 몬스터가 돌아다니면 구도가 매번 달라져 비교가 안 된다.
	for child: Node in main.get_children():
		if child is MonsterBase:
			child.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = VIEW_TILE * float(Tuning.TILE_SIZE_PROTOTYPE)
	player.facing = Vector2.UP
	player.play_anim("idle")
	for _i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var path := out_dir.path_join("quarter-view-b-village.png")
	var saved := get_viewport().get_texture().get_image().save_png(path) == OK
	print("%s 마을 입구 -> %s" % ["[PASS]" if saved else "[FAIL]", path])
	print("=== CAPTURE 종료 ===")
	get_tree().quit(0 if saved else 1)
