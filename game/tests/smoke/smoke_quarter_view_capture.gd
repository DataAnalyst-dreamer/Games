## 쿼터뷰 단계 (a) 육안 확인용 스크린샷 (D-199/D-204). Y-sort 가림과 발밑 그림자가
## 실제 렌더 결과로 보이는지 남긴다 — Xvfb 필요(--headless 아님, 렌더링이 실제로 일어나야 한다).
##
## 실행: xvfb-run -a godot --path game res://tests/smoke/SmokeQuarterViewCapture.tscn --quit-after 900
## 출력: docs/art/preview/quarter-view-a-above.png / -below.png
##
##  - above: 슬라임이 플레이어보다 화면 위(y가 작음) -> 플레이어가 슬라임 앞에 그려진다
##  - below: 슬라임이 플레이어보다 화면 아래(y가 큼) -> 슬라임이 플레이어 앞에 그려진다
##
## 두 장 모두에서 두 액터의 발밑에 눌린 타원 그림자가 보여야 한다.
extends Node

## 캡처 전용 확대 배율(실제 게임 줌 아님).
const CAPTURE_ZOOM := 6.0

var _out_dir: String
var _ok: bool = true


func _ready() -> void:
	print("=== CAPTURE 쿼터뷰 (a): Y-sort 가림 + 발밑 그림자 ===")
	# 렌더러가 없으면 캡처할 화면 자체가 없다. 전체 스모크를 --headless로 한 번에
	# 돌릴 때 영구 실패로 남지 않도록 실패가 아니라 건너뛰기로 끝낸다
	# (가림 순서의 논리 검증은 SmokeQuarterViewYSort가 헤드리스로 담당한다).
	if DisplayServer.get_name() == "headless":
		print("[SKIP] 렌더러 없음 - xvfb-run 으로 실행해야 캡처된다")
		print("=== CAPTURE 종료 ===")
		get_tree().quit(0)
		return
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art/preview").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var main: Node2D = load("res://scenes/main/Main.tscn").instantiate() as Node2D
	add_child(main)
	var player: Player = main.get_node("Player") as Player
	var slime: Node2D = main.get_node("Slime1") as Node2D

	# 겹침 순서만 보여주면 되므로 모든 액터의 자율 행동을 멈춘다 — 몬스터가 돌아다니면
	# 두 캡처의 구도가 달라져 비교가 안 된다.
	for child: Node in main.get_children():
		if child is MonsterBase:
			child.set_physics_process(false)
			if child != slime:
				(child as Node2D).hide()
	player.set_physics_process(false)
	player.facing = Vector2.DOWN
	player.play_anim("idle")

	# 16px 아트를 기본 줌(2배)으로 찍으면 겹침 구간도 그림자 타원도 몇 픽셀에 불과해
	# 육안 확인이 불가능하다. 캡처 전용으로만 확대한다 - Main.tscn의 값은 건드리지 않는다.
	var pcam: Node2D = main.get_node("PlayerCamera") as Node2D
	if pcam != null:
		pcam.set("zoom", Vector2(CAPTURE_ZOOM, CAPTURE_ZOOM))

	for _i in range(8):
		await get_tree().process_frame

	# 두 액터를 거의 겹치게 두고 세로 순서만 바꾼다(가림이 실제로 일어나는 거리).
	var anchor := Vector2(0.0, 0.0)
	await _capture(player, slime, anchor, -10.0, "above")
	await _capture(player, slime, anchor, 10.0, "below")

	print("=== CAPTURE 종료 ===")
	get_tree().quit(0 if _ok else 1)


## slime_dy: 플레이어 기준 슬라임의 세로 오프셋. 음수면 슬라임이 위(뒤), 양수면 아래(앞).
func _capture(player: Player, slime: Node2D, anchor: Vector2, slime_dy: float, tag: String) -> void:
	player.global_position = anchor
	slime.global_position = anchor + Vector2(9.0, slime_dy)
	for _i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join("quarter-view-a-%s.png" % tag)
	var saved := image.save_png(path) == OK
	if not saved:
		_ok = false
	print("%s %s: player.y=%.1f slime.y=%.1f (기대: %s가 앞) -> %s" \
		% ["[PASS]" if saved else "[FAIL]", tag, player.global_position.y, slime.global_position.y,
			"플레이어" if slime_dy < 0.0 else "슬라임", path])
