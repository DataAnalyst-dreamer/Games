## 대사 풍선 결함 수정(테마 미적용/본문·초상 클릭 삼킴) 육안 확인 + 클릭 회귀 가드.
## Xvfb 렌더링이 실제로 필요하다(--headless 아님) — SmokeMenuMouse(D-196)가 이
## 워크트리에 아직 병합돼 있지 않아(docs/specs/dialogue-system-v1.md §9.5) 그 관례를
## 그대로 이 파일 하나로 재현한다: smoke_m4_5_capture.gd와 같은 캡처 패턴 + 실제
## 창 픽셀(1920x1080) -> 캔버스(640x360) 좌표 변환 후 Input.parse_input_event로
## 진짜 좌클릭을 흘려 dialogue_balloon.gd의 advanced 신호가 뜨는지 확인한다.
##
## 출력: docs/art/preview/dialogue-balloon.png (선택지 4개 상태)
## 실행: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game \
##       --rendering-driver opengl3 res://tests/smoke/SmokeDialogueBalloonCapture.tscn --quit-after 900
extends Node

const WINDOW_TO_CANVAS := 3.0 # project.godot: viewport 640x360, window_*_override 1920x1080.

var _out_dir: String
var _ui_root: UiRoot
var _controller: NpcDialogueController
var _advanced_skip_all: Variant = null


func _ready() -> void:
	print("=== CAPTURE 대사 풍선: 테마 적용 + 선택지 4개 + 본문 클릭=다음 ===")
	_out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/art/preview").simplify_path()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	_ui_root = main.get_node("UiRoot") as UiRoot
	_controller = _ui_root.npc_dialogue_controller

	for i in range(4):
		await get_tree().process_frame

	# --- 선택지 4개(계약 상한) 상태 캡처 ---
	var res: DialogueResource = load("res://dialogue/_smoke_test.dialogue")
	_controller.open_dialogue_resource(res, "layout_check")
	await _wait_for(func(): return _controller.balloon.dialogue_label.dialogue_line != null)
	_controller.balloon.skip_typing()
	await _wait_for(func(): return _controller.balloon.responses_menu.visible)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("dialogue-balloon.png")
	# 캡처 후 정리 — 선택지 중 하나를 확정해 대사를 닫는다.
	_controller.balloon.response_chosen.emit(_controller.balloon.responses_menu.responses[0])
	await _wait_for(func(): return not _controller.is_dialogue_open())

	# --- 본문·초상 클릭 삼킴 결함 회귀: 실제 좌클릭이 패널 gui_input까지 내려가는가 ---
	_controller.balloon.advanced.connect(func(skip_all: bool) -> void: _advanced_skip_all = skip_all)
	_controller.open_dialogue_resource(res, "click_check")
	await _wait_for(func(): return _controller.balloon.dialogue_label.dialogue_line != null)
	_controller.balloon.skip_typing()
	await get_tree().process_frame
	await get_tree().process_frame
	# 캔버스 (300,270) = 본문(dialogue_label, x128~592/y248~292) 위 — 창 픽셀로 변환해 쏜다.
	_click(Vector2(300, 270))
	await _wait_for(func(): return _advanced_skip_all != null, 2.0)
	var click_ok: bool = _advanced_skip_all == false
	print("[CLICK] 본문(300,270) 좌클릭 -> advanced(skip_all=false) 수신: %s (실제=%s)" \
		% [str(click_ok), str(_advanced_skip_all)])

	print("=== CAPTURE 대사 풍선 종료 ===")
	get_tree().quit(0 if click_ok else 1)


func _click(canvas_pos: Vector2) -> void:
	var window_pos: Vector2 = canvas_pos * WINDOW_TO_CANVAS
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = window_pos
	down.global_position = window_pos
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _wait_for(cond: Callable, timeout: float = 5.0) -> void:
	var elapsed := 0.0
	while not cond.call():
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > timeout:
			print("[FAIL] 대기 시간 초과")
			return


func _capture(filename: String) -> void:
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(filename)
	var ok := pixels.save_png(path) == OK
	print("%s SAVE %s -> %s" % ["[PASS]" if ok else "[FAIL]", filename, path])
