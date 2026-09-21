## M6-3 육안 확인용 스크린샷 3장 — 필드 전역 등각 배치(마을/안개숲/메아리 굴 입구).
## Xvfb 필요(--headless 아님), smoke_quarter_view_b_capture.gd 와 같은 패턴.
##
## 실행: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game
##       --rendering-driver opengl3 res://tests/smoke/SmokeIsoFieldCapture.tscn --quit-after 900
## 출력: docs/art/preview/iso-field-village.png / -forest.png / -cave.png
extends Node

const SHOTS := {
	"iso-field-village": Vector2i(-1, -7),   # 기존 마을 허브 구도(비석·대장간·절벽 틈)
	"iso-field-forest": Vector2i(-24, -3),   # 안개숲 입구 — tree_oak 밀집 + 서쪽 스퍼 흙길
	"iso-field-cave": Vector2i(14, -10),     # 메아리 굴 입구 — 절벽 gap + cave_entrance 소품
}


func _ready() -> void:
	print("=== CAPTURE 등각 (M6-3): 필드 전역 3구역 ===")
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
	player.facing = Vector2.UP
	player.play_anim("idle")

	var all_ok := true
	for shot_name: String in SHOTS:
		player.global_position = IsoMath.cell_to_screen(SHOTS[shot_name])
		for _i in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out_dir.path_join("%s.png" % shot_name)
		var saved := get_viewport().get_texture().get_image().save_png(path) == OK
		all_ok = all_ok and saved
		print("%s %s -> %s" % ["[PASS]" if saved else "[FAIL]", shot_name, path])

	print("=== CAPTURE 종료 ===")
	get_tree().quit(0 if all_ok else 1)
