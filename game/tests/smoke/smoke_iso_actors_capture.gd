## 단계 iso-3 육안 확인용 스크린샷 — 마을 입구의 액터 비율. Xvfb 필요(--headless 아님).
##
## 실행: xvfb-run -a -s "-screen 0 1920x1080x24" \
##   godot --path game res://tests/smoke/SmokeIsoActorsCapture.tscn --quit-after 900 \
##   --rendering-driver opengl3
## 출력: docs/art/preview/iso-3-actors.png
##
## 보는 것: 핀 대역(64×96)과 몬스터 대역이 **건물·나무와 같은 축척으로** 서는가.
## iso-2 까지는 캐릭터만 16px×2(=32px 높이)라 집 옆에서 인형처럼 작았다 - 그 어긋남이
## 사라졌는지가 이 한 장의 근거다. 캡처 전용 줌은 쓰지 않는다(실제 게임 화면 그대로).
extends Node

## 플레이어를 놓을 격자 셀. 서쪽 집(world_layout_hartland.props house_a [-6,-8])과
## 바로 앞 - 집 벽 높이와 핀 키를 같은 화면에서 직접 견줄 수 있는 자리다.
const VIEW_CELL := Vector2i(-4, -9)
## 비율 비교용으로 플레이어 주변에 세울 몬스터(격자 셀 오프셋, 바라보는 방향).
const POSES := [
	[Vector2i(2, 0), Vector2(-1, 0)],    # 슬라임 - 플레이어 쪽(서)
	[Vector2i(1, 2), Vector2(0, -1)],    # 뿔토끼 - 북
	[Vector2i(-1, 2), Vector2(1, 1)],    # 버섯돌이 - 남동
]


func _ready() -> void:
	print("=== CAPTURE 등각 액터 비율 (iso-3) ===")
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
	var monsters: Array[MonsterBase] = []
	for child: Node in main.get_children():
		if child is MonsterBase:
			child.set_physics_process(false)
			monsters.append(child)
	player.set_physics_process(false)
	player.global_position = IsoMath.cell_to_screen(VIEW_CELL)
	player.set_facing(Vector2(1, 1))
	player.play_anim("idle")

	# 종이 다른 세 마리를 플레이어 곁에 모은다(같은 축척인지 한 화면에서 보이게).
	var wanted: Array[String] = ["slime", "horn_rabbit", "mushroom"]
	var placed := 0
	for want: String in wanted:
		for monster: MonsterBase in monsters:
			if monster.monster_id != want or placed >= POSES.size():
				continue
			var pose: Array = POSES[placed]
			monster.global_position = IsoMath.cell_to_screen(VIEW_CELL + (pose[0] as Vector2i))
			monster._face_towards(pose[1] as Vector2)
			placed += 1
			break
	print("  배치: 핀 1 + 몬스터 %d (셀 %s 기준)" % [placed, VIEW_CELL])

	for _i in range(16):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var path := out_dir.path_join("iso-3-actors.png")
	var saved := get_viewport().get_texture().get_image().save_png(path) == OK
	print("%s 액터 비율 -> %s" % ["[PASS]" if saved else "[FAIL]", path])
	print("=== CAPTURE 종료 ===")
	get_tree().quit(0 if saved else 1)
