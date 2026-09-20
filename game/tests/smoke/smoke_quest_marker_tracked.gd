## 헤드리스 스모크 테스트: NPC/오브젝트 "목표 표식"(M3-4, D-163) — giver 없는 메인 퀘스트
## MQ01(talk npc:teo)도 테오 위에 표식이 뜨는지 실제 배치(HartlandQuestLayer)로 검증한다.
## smoke_quest_layout.gd의 MQ01 절차(QuestSystem.reset -> accept -> teo.talk() ->
## cargo_pile.interact())를 그대로 따르되, 이번엔 각 단계에서 "표식이 맞게 뜨고 맞게
## 꺼지는지"만 확인한다.
##
## 실행(기능 확인, headless): godot --headless --path game
##   res://tests/smoke/SmokeQuestMarkerTracked.tscn --quit-after 120
## 실행(스크린샷 확인, 실제 렌더러 필요 — walk-animation-diagnosis.md와 동일한 Xvfb
##   오프스크린 방식): Xvfb :99 -screen 0 1920x1080x24 &
##   DISPLAY=:99 godot --display-driver x11 --rendering-driver opengl3 --path game
##   res://tests/smoke/SmokeQuestMarkerTracked.tscn --quit-after 120
##   -- --capture=docs/art/preview/quest-marker-tracked.png
extends Node

var _main: Node
var _quest_layer: Node
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _ready() -> void:
	print("=== SMOKE QUEST MARKER TRACKED: giver 없는 MQ01 목표 표식(▼) ===")
	QuestSystem.reset()
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_quest_layer = _main.get_node("HartlandQuestLayer")

	var accept_result: Dictionary = QuestSystem.accept("quest_main_a1_01_arrival")
	_check(accept_result.get("ok", false), "MQ01 수주 성공")

	var teo: QuestNpc = _quest_layer.spawned_by_id.get("teo") as QuestNpc
	_check(teo != null, "teo NPC 존재")
	await get_tree().process_frame

	# --- 근본 수정 검증: teo는 어떤 퀘스트의 giver도 아니라 기존 로직(giver 스캔뿐)이면
	# 표식이 전혀 안 뜬다 — "추적 중인 퀘스트의 talk 목표 대상"으로만 떠야 정상이다. ---
	_check(teo.marker_visible(), "teo 머리 위 표식 표시(giver 없는 MQ01, 근본 원인 수정 확인)")
	_check(teo.marker_text() == "▼", "teo 표식이 ▼(목표 표식, !/?와 구분): '%s'" % teo.marker_text())

	teo.talk() # obj_01 완료 -> obj_02(interact object:cargo_pile)로 이동.
	await get_tree().process_frame
	_check(not teo.marker_visible(), "talk 후 teo 표식 사라짐(더 이상 현재 목표 대상 아님)")

	var cargo_pile: QuestObject = _quest_layer.spawned_by_id.get("cargo_pile") as QuestObject
	_check(cargo_pile != null, "cargo_pile 오브젝트 존재")
	_check(cargo_pile.marker_visible(), "cargo_pile 머리 위 표식 표시(오브젝트도 동일하게 확장, D-163)")
	_check(cargo_pile.marker_text() == "▼", "cargo_pile 표식도 ▼: '%s'" % cargo_pile.marker_text())

	cargo_pile.interact() # MQ01 목표 전부 완료 -> complete_ready.
	await get_tree().process_frame
	_check(not cargo_pile.marker_visible(), "interact 후 cargo_pile 표식 사라짐(목표 완료)")

	# --- 스크린샷(옵션): 실제 디스플레이가 있을 때만(Xvfb) ---
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	if not capture.is_empty():
		if DisplayServer.get_name() == "headless":
			print("[SKIP] --capture 요청됐지만 headless라 실제 렌더링 불가(walk-animation-diagnosis.md 방식대로 Xvfb+x11 드라이버로 재실행 필요)")
		else:
			# 표식을 다시 보이게(talk 이전 상태로 되돌려) + 카메라가 teo를 비추도록
			# 플레이어를 그 옆으로 순간이동시킨 뒤 캡처한다(smoke_quest_layout.gd의
			# "순간이동 + 프레임 대기" 관례 — 카메라 스무딩이 따라올 시간이 필요해
			# location 트리거 검증(물리 프레임 3개)보다 더 오래 기다린다).
			QuestSystem.reset()
			QuestSystem.accept("quest_main_a1_01_arrival")
			var teo_again: QuestNpc = _quest_layer.spawned_by_id.get("teo") as QuestNpc
			var player: Player = _main.get_node("Player") as Player
			if teo_again != null and player != null:
				player.global_position = teo_again.global_position + Vector2(0, 24)
			for i in range(40): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels := get_viewport().get_texture().get_image()
			var saved := pixels.save_png(capture) == OK
			_check(saved, "표식 스크린샷 저장: %s" % capture)

	print("SMOKE_QUEST_MARKER_TRACKED_RESULT FAIL=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
