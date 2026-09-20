## 헤드리스 스모크 테스트: 퀘스트 보상 표시(M4-2, D-181~D-183). "완료해도 어떤 보상을
## 받는지 안 보인다" 피드백 대응 — 퀘스트 로그 상세/수락 패널/완료 토스트 3곳 + 실제
## 지급(HUD 반영)까지 확인한다.
##
## main_bootstrap.gd의 자동 온보딩(ensure_onboarding_quest)은 이 스모크가 자기 자신을
## current_scene으로 두는 관례상 발동하지 않는다(smoke_quest_npc_panel.gd와 동일 이유) —
## teo와 직접 상호작용해 수주한다.
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuestRewardsUi.tscn --quit-after 300
extends Node

const Q1 := "quest_main_a1_01_arrival" # 실데이터: gold=0, exp=5, items=[](game-designer 상향 전).

var _main: Node
var _ui_root: UiRoot
var _failures := 0


func _check(cond: bool, label: String) -> void:
	print("[%s] %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await get_tree().process_frame


func _ready() -> void:
	print("=== SMOKE QUEST REWARDS UI: 로그 상세/수락 패널/완료 토스트 ===")
	QuestSystem.reset()
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot
	var layer: Node = _main.get_node("HartlandQuestLayer")
	var player: Player = _main.get_node("Player") as Player
	var quest_log_tab: QuestLogTab = _ui_root.inventory_menu.quest_log_tab
	var synthetic_rows: Array[Dictionary] = QuestLogUiCalc.reward_rows(
		{"gold": 40, "exp": 30, "items": [{"id": "wool_soft", "qty": 2}]})

	# --- 1) 수락 패널(available 상태): 보상 요약 줄이 실데이터로 보이는지 ---
	player.global_position = layer.spawned_by_id["teo"].global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E)
	_check(_ui_root.is_quest_npc_open(), "teo interact로 수락 패널 열림")
	_check(QuestSystem.get_state(Q1) == "available", "수락 전 상태는 available")
	var offer_text: String = _ui_root.quest_npc_panel.body_label.text
	_check(offer_text.contains(tr(&"ui.quest_npc.reward_prefix")), "수락 패널 본문에 보상 접두어 표시")
	var q1_rewards: Dictionary = Data.get_value("quests", Q1, {}).get("rewards", {})
	var exp_reward: int = int(q1_rewards.get("exp", 0))
	var reward_rows: int = int(exp_reward > 0) + int(int(q1_rewards.get("gold", 0)) > 0) + (q1_rewards.get("items", []) as Array).size()
	_check(offer_text.contains(tr(&"ui.quest_log.reward_exp_fmt") % exp_reward), "수락 패널에 실제 EXP 보상(%d) 표시: '%s'" % [exp_reward, offer_text])

	# --- 2) 수락 -> 퀘스트 로그 상세에도 같은 보상이 실데이터로 반영되는지 ---
	var log_before := _ui_root.hud.log_list.get_child_count()
	await _key(KEY_ENTER) # 수락.
	_check(QuestSystem.get_state(Q1) == "active", "수락 후 active로 전환")
	_ui_root.open_menu()
	_ui_root.inventory_menu.select_tab("quest")
	_check(quest_log_tab._detail_title.text == tr(&"quest_main_a1_01_arrival_title"), "퀘스트 로그가 MQ01 상세를 보여줌")
	var mq01_children := quest_log_tab._detail_rewards.get_children()
	_check(mq01_children.size() == 1 + reward_rows, "MQ01은 보상 %d종 + 헤더 = 자식 %d개(actual=%d)" % [reward_rows, 1 + reward_rows, mq01_children.size()])
	_check((mq01_children[mq01_children.size() - 1] as HBoxContainer).get_child_count() == 1, "exp 행은 아이콘 없이 텍스트만(icon=null)")
	_ui_root.close_menu()

	# --- 3) 합성 데이터로 렌더링 코드 자체 검증(gold/exp/item 3종 전부 — 실데이터는
	# game-designer가 아직 item 보상을 상향하지 않아 비어있다). _refresh_detail()이
	# 아니라 _populate_rewards()를 직접 호출하므로 위 실데이터 검증에 영향 없다. ---
	quest_log_tab._populate_rewards(synthetic_rows)
	var reward_children := quest_log_tab._detail_rewards.get_children()
	_check(reward_children.size() == mq01_children.size() + 4,
		"보상 3종 + 헤더 = 4개가 기존 MQ01 표시 위에 추가됨(actual=%d)" % reward_children.size())
	var header_idx := mq01_children.size()
	_check((reward_children[header_idx] as Label).text == tr(&"ui.quest_log.reward_header"), "보상 헤더 표시")
	var item_row := reward_children[header_idx + 3] as HBoxContainer
	_check(item_row.get_child_count() == 2, "아이템 행은 [아이콘|텍스트] 2개(ItemIcon.resolve 재사용)")
	_check(item_row.get_child(0) is TextureRect, "아이템 보상에 아이콘(TextureRect) 표시")

	# --- 4) 완료까지 진행 + 완료 토스트 + 실제 지급(HUD 반영) ---
	var xp_before := QuestSystem.total_exp_earned
	player.global_position = layer.spawned_by_id["teo"].global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E) # 대화(obj_01 완료) -> obj_02(cargo_pile)로 이동, 패널도 다시 열림.
	await _key(KEY_ESCAPE)
	player.global_position = layer.spawned_by_id["cargo_pile"].global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E) # cargo_pile interact -> complete_ready.
	_check(QuestSystem.get_state(Q1) == "complete_ready", "MQ01 완료 보고 가능 상태 도달")
	player.global_position = layer.spawned_by_id["teo"].global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E)
	await _key(KEY_ENTER) # 완료 보고.
	await get_tree().process_frame
	_check(QuestSystem.get_state(Q1) == "completed" and QuestSystem.total_exp_earned == xp_before + exp_reward,
		"실제 지급 확인: Progression.grant_exp 경로로 EXP +%d 반영" % exp_reward)
	_check(_ui_root.hud.log_list.get_child_count() > log_before,
		"완료 토스트가 좌하단 로그에 추가됨(before=%d after=%d)" % [log_before, _ui_root.hud.log_list.get_child_count()])
	var last_log := _ui_root.hud.log_list.get_child(_ui_root.hud.log_list.get_child_count() - 1)
	var last_text := _find_label_text(last_log)
	_check(last_text == tr(&"ui.quest_log.reward_exp_fmt") % exp_reward, "완료 토스트 텍스트가 EXP +%d: '%s'" % [exp_reward, last_text])

	# --- 스크린샷(옵션): Xvfb 실 렌더러일 때만 — 퀘스트 로그 상세의 보상 목록을 담는다 ---
	var capture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
	if not capture.is_empty():
		if DisplayServer.get_name() == "headless":
			print("[SKIP] --capture 요청됐지만 headless라 실제 렌더링 불가")
		else:
			quest_log_tab._populate_rewards(synthetic_rows)
			_ui_root.open_menu()
			_ui_root.inventory_menu.select_tab("quest")
			for i in range(10): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(capture) == OK, "보상 표시 스크린샷 저장: %s" % capture)

	print("SMOKE_QUEST_REWARDS_UI_RESULT FAIL=%d" % _failures)
	get_tree().paused = false
	get_tree().quit(0 if _failures == 0 else 1)


func _find_label_text(node: Node) -> String:
	if node is Label:
		return (node as Label).text
	for child in node.get_children():
		var found := _find_label_text(child)
		if not found.is_empty():
			return found
	return ""
