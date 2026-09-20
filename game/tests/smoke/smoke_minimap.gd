## 헤드리스 스모크: 미니맵 v1(M5-2, D-172 후속) — 플레이어 순간이동 후 미니맵 카메라가
## 따라가는지, 추적 목표(MQ01 teo) 위치가 QuestTargetLocator 경유로 잡히는지 로직만
## 검증한다.
##
## SubViewport 텍스처의 실제 픽셀(빈 화면 여부)은 headless에서 RenderingServer.
## frame_post_draw가 응답하지 않아(await가 걸림 — 실측 확인, smoke_skill_vfx_capture.gd
## 주석과 동일 사유) 검증할 수 없다 — 기존 관례대로 실제 디스플레이(Xvfb)일 때만 픽셀
## 검증 + --capture= 옵션 시 docs/art/preview/minimap.png 저장을 수행한다.
##
## 실행(로직, headless): godot --headless --path game res://tests/smoke/SmokeMinimap.tscn --quit-after 120
## 실행(픽셀+스크린샷, Xvfb): xvfb-run -a godot --path game --rendering-driver opengl3
##   res://tests/smoke/SmokeMinimap.tscn --quit-after 120 -- --capture=docs/art/preview/minimap.png
extends Node

var _main: Node
var _minimap: HudMinimap
var _player: Player
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _ready() -> void:
	print("=== SMOKE MINIMAP: 카메라 추적 · 마커 좌표 · (Xvfb) 텍스처 비어있지 않음 ===")
	QuestSystem.reset()
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_minimap = _main.get_node("UiRoot/Hud/Root/TopRight/MinimapFrame/MinimapMarkers") as HudMinimap
	_check(_minimap != null, "HudMinimap 노드 존재")

	_player.global_position = Vector2(300, -50)
	_minimap.force_refresh()
	await get_tree().process_frame
	var cam_pos: Vector2 = _minimap.camera_global_position()
	_check(cam_pos.distance_to(_player.global_position) < 1.0,
		"미니맵 카메라가 플레이어 위치를 따라감: %s (플레이어=%s)" % [cam_pos, _player.global_position])

	var accept_result: Dictionary = QuestSystem.accept("quest_main_a1_01_arrival")
	_check(accept_result.get("ok", false), "MQ01 수주 성공")
	_minimap.force_refresh()
	var target: Variant = _minimap.tracked_target()
	_check(target != null, "추적 목표 위치 조회됨(QuestTargetLocator 경유): %s" % str(target))

	# --- 픽셀 검증(옵션): 실제 디스플레이가 있을 때만(Xvfb) ---
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")

	if DisplayServer.get_name() == "headless":
		print("[SKIP] SubViewport 픽셀 검증 — headless라 실제 렌더 불가(Xvfb로 재실행 필요)")
	else:
		for i in range(10): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = _minimap.minimap_texture_image()
		var bg: Color = img.get_pixel(0, 0)
		var non_bg_found := false
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				if img.get_pixel(x, y) != bg:
					non_bg_found = true
					break
			if non_bg_found: break
		_check(non_bg_found, "SubViewport 텍스처가 비어있지 않음(단색이 아님)")

		if not capture.is_empty():
			var out_path: String = ProjectSettings.globalize_path("res://").path_join("../%s" % capture).simplify_path()
			DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
			var saved := img.save_png(out_path) == OK
			_check(saved, "스크린샷 저장: %s" % out_path)

	print("SMOKE_MINIMAP_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
