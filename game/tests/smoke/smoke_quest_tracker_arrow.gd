## 헤드리스 스모크 테스트: 추적 목표 화면 가장자리 화살표(F5-1 확장, M4-2, D-181~D-183).
## "표식은 나오는데 어디 있는지 따라갈 수가 없다"는 피드백 대응 — 목표가 화면 안이면
## 화살표가 숨고(▼ 표식만으로 충분), 화면 밖이면 방향·거리가 QuestTrackerCalc(순수
## 함수) 계산과 일치하는지 확인한다.
##
## 카메라(PlayerCamera, PhantomCamera2D)는 Player를 계속 따라가므로 직접 옮기지 않고
## smoke_quest_marker_tracked.gd와 같은 관례대로 플레이어를 옮기고 여러 프레임을
## 기다려 카메라가 따라잡게 한다.
##
## 실행(기능 확인, headless): godot --headless --path game
##   res://tests/smoke/SmokeQuestTrackerArrow.tscn --quit-after 120
## 실행(스크린샷 확인, Xvfb): smoke_quest_marker_tracked.gd와 동일한 방식.
##   -- --capture=docs/art/preview/quest-tracker-arrow.png
extends Node

var _main: Node
var _tracker: HudQuestTracker
var _camera: Camera2D
var _player: Player
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _wait_camera_settle() -> void:
	for i in range(60):
		await get_tree().process_frame


func _ready() -> void:
	print("=== SMOKE QUEST TRACKER ARROW: 화면 밖 화살표 방향·거리 ===")
	QuestSystem.reset()
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	var ui_root: UiRoot = _main.get_node("UiRoot") as UiRoot
	_tracker = ui_root.hud.get_node("QuestTracker") as HudQuestTracker
	_camera = _main.get_node("Camera2D") as Camera2D
	_player = _main.get_node("Player") as Player
	var layer: Node = _main.get_node("HartlandQuestLayer")

	var accept_result: Dictionary = QuestSystem.accept("quest_main_a1_01_arrival")
	_check(accept_result.get("ok", false), "MQ01 수주 성공")
	QuestSystem.set_tracked("quest_main_a1_01_arrival")

	var teo: QuestNpc = layer.spawned_by_id.get("teo") as QuestNpc
	_check(teo != null, "teo NPC 존재")

	# --- 화면 안: 플레이어를 teo 옆에 두면(카메라가 따라감) 화살표는 숨는다(▼ 표식만으로 충분) ---
	_player.global_position = teo.global_position + Vector2(4, 0)
	await _wait_camera_settle()
	_tracker._refresh()
	_check(not _tracker._arrow.visible, "목표가 화면 안이면 화살표 숨김")

	# --- 화면 밖: 플레이어를 멀리 옮겨 teo가 왼쪽 화면 밖에 있게 한다 ---
	_player.global_position = teo.global_position + Vector2(2000, -300)
	await _wait_camera_settle()
	_tracker._refresh()
	_check(_tracker._arrow.visible, "목표가 화면 밖이면 화살표 표시")

	# 기대값은 QuestTrackerCalc(순수 함수)로 독립 계산해 hud_quest_tracker.gd의 실제
	# 값과 대조한다(같은 카메라 상태를 두 경로로 계산해 일치 여부만 본다).
	var expected: Dictionary = QuestTrackerCalc.edge_arrow(
		_camera.get_screen_center_position(), _tracker.get_viewport_rect().size, _camera.zoom,
		teo.global_position, Tuning.QUEST_ARROW_MARGIN_PX)
	_check(not bool(expected.get("on_screen", true)), "사전 조건: 이 시점엔 실제로 화면 밖이어야 함")
	var expected_rotation := deg_to_rad(float(expected["angle_deg"]) + 90.0)
	_check(is_equal_approx(_tracker._arrow.rotation, expected_rotation),
		"화살표 각도가 QuestTrackerCalc 기대값과 일치: actual=%.3f expected=%.3f" % [_tracker._arrow.rotation, expected_rotation])
	# teo가 플레이어(=카메라 중심 근방) 왼쪽에 있으므로 화살표는 왼쪽(약 -90도 근방)을 가리켜야 한다.
	_check(cos(_tracker._arrow.rotation) < 0.0, "방향 sanity: teo가 왼쪽에 있으니 화살표도 왼쪽을 향함")

	var expected_m := int(round(QuestTrackerCalc.distance_meters(float(expected["distance_px"]), float(Tuning.TILE_SIZE_PROTOTYPE))))
	_check(_tracker._arrow.text == "▲ %dm" % expected_m,
		"화살표 텍스트에 거리(m) 표시: '%s' (기대 %dm)" % [_tracker._arrow.text, expected_m])

	# --- 추적 대상 없음(reset으로 활성 퀘스트 자체를 없앰) -> 화살표 숨김 ---
	QuestSystem.reset()
	_tracker._refresh()
	_check(not _tracker._arrow.visible, "추적 중인 퀘스트가 없으면 화살표 숨김")

	# --- 스크린샷(옵션): Xvfb 실 렌더러일 때만 ---
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	if not capture.is_empty():
		if DisplayServer.get_name() == "headless":
			print("[SKIP] --capture 요청됐지만 headless라 실제 렌더링 불가")
		else:
			QuestSystem.accept("quest_main_a1_01_arrival")
			QuestSystem.set_tracked("quest_main_a1_01_arrival")
			_player.global_position = teo.global_position + Vector2(2000, -300)
			await _wait_camera_settle()
			_tracker._refresh()
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(capture) == OK, "화살표 스크린샷 저장: %s" % capture)

	print("SMOKE_QUEST_TRACKER_ARROW_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
