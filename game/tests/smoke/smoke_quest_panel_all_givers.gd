## 헤드리스 스모크 테스트: QuestNpcPanel이 1막 5개 giver NPC 전원(teo/dami/rozel/
## pinto/meru) 각각에 대해 실제 플레이로 수락->완료 보고까지 진행되는지 확인한다
## (D-258, quest_npc_panel_calc.gd로 SUPPORTED 하드코딩 배열을 대체한 배선 검증 —
## 퀘스트 진행 로직 자체는 이미 SmokeQuest/GUT test_quest_system.gd가 커버한다).
##
## 선행 조건 우회: QuestSystem._completed를 직접 조작하지 않고 공개 API from_dict()로
## "세이브를 불러온 상태"를 재현한다(심사 결정 3 — SaveManager 로드 경로와 동일).
## kill/collect 목표는 smoke_quest.gd와 동일한 관례로 실제 Events를 emit해 시뮬레이션
## 한다(전체 체인 재현은 이 스모크의 범위가 아니다 — D-258은 패널 배선 검증).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuestPanelAllGivers.tscn --quit-after 900
extends Node

var _main: Node
var _player: Player
var _ui: UiRoot
var _layer: Node
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


## interact 1회 = talk + 잡담 풍선 + 패널(같은 프레임, D-260). 헤드리스에는 풍선을
## 넘겨 줄 사람이 없어 남은 잡담이 계속 `interact`/`ui_confirm`을 먹으므로(풍선이
## 보이는 동안은 풍선이 입력 우선), 다음 상호작용 전에 플레이어가 잡담을 전체 스킵한
## 것과 같은 공개 API를 명시적으로 호출한다(D-241 = `NpcDialogueController.skip_all()`).
## 게임 로직 쪽에는 타임아웃 같은 안전장치를 두지 않는다.
func _interact(target_id: String) -> void:
	_ui.npc_dialogue_controller.skip_all()
	_player.global_position = (_layer.spawned_by_id[target_id] as Node2D).global_position
	for i in range(4): await get_tree().physics_frame
	await _key(KEY_E)


func _ready() -> void:
	print("=== SMOKE QUEST PANEL ALL GIVERS: teo/dami/rozel/pinto/meru 수락->완료(D-258) ===")
	QuestSystem.reset()
	# 이 스모크는 자기 자신을 current_scene으로 두지 않아 오토세이브 트리거는 무해하지만,
	# smoke_quest_npc_panel.gd와 동일하게 순수 UI/backend 검증에 집중하려 끊어 둔다.
	Events.main_quest_stage_completed.disconnect(SaveManager._on_autosave_trigger)
	QuestSystem.from_dict({"completed": ["quest_main_a1_05_reclaim", "quest_main_a1_06_echocave"]})

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_ui = _main.get_node("UiRoot") as UiRoot
	_layer = _main.get_node("HartlandQuestLayer")
	for child in _main.get_children():
		if child is MonsterBase: child.queue_free()

	await _run_teo()
	await _run_side("dami", "quest_side_heartland_montsil", _run_montsil_objectives)
	await _run_side("rozel", "quest_side_heartland_festival_prep", _run_festival_objectives)
	await _run_side("pinto", "quest_side_heartland_orefetch", _run_orefetch_objectives)
	await _run_side("meru", "quest_side_heartland_herbrun", _run_herbrun_objectives)

	print("SMOKE_QUEST_PANEL_ALL_GIVERS_RESULT FAIL=%d" % _failures)
	get_tree().paused = false
	get_tree().quit(0 if _failures == 0 else 1)


## npc_id와 상호작용해 패널을 연다. 기대 quest_id가 열렸는지 확인한다.
func _open_and_expect(npc_id: String, expected_quest_id: String, context: String) -> void:
	await _interact(npc_id)
	_check(_ui.is_quest_npc_open() and _ui.quest_npc_panel.quest_id == expected_quest_id,
		"%s: %s interact로 %s 패널 열림(actual=%s)" % [context, npc_id, expected_quest_id, _ui.quest_npc_panel.quest_id])


func _run_teo() -> void:
	const NPC := "teo"
	const Q := "quest_main_a1_01_arrival"
	print("--- teo: %s ---" % Q)
	_check(QuestSystem.get_state(Q) == "available", "teo: 초기 available")
	await _open_and_expect(NPC, Q, "teo")
	await _key(KEY_ENTER) # accept
	_check(QuestSystem.get_state(Q) == "active", "teo: 수락 후 active")

	await _interact(NPC) # obj_01: talk npc:teo (재상호작용으로 진행)
	_check(QuestSystem.get_active_objective_index(Q) == 1, "teo: talk 목표 진행")
	await _key(KEY_ESCAPE) # 진행 중 패널 닫기

	await _interact("cargo_pile") # obj_02: interact object:cargo_pile
	_check(QuestSystem.get_state(Q) == "complete_ready", "teo: cargo_pile로 complete_ready 도달")

	await _open_and_expect(NPC, Q, "teo")
	await _key(KEY_ENTER) # advance
	_check(QuestSystem.get_state(Q) == "completed", "teo: 완료 보고로 completed")


## dami/rozel/pinto/meru 공통 흐름: talk -> (objectives_fn) -> complete_ready -> advance.
func _run_side(npc_id: String, quest_id: String, objectives_fn: Callable) -> void:
	print("--- %s: %s ---" % [npc_id, quest_id])
	_check(QuestSystem.get_state(quest_id) == "available", "%s: 선행조건 충족 후 available" % npc_id)
	await _open_and_expect(npc_id, quest_id, npc_id)
	await _key(KEY_ENTER) # accept
	_check(QuestSystem.get_state(quest_id) == "active", "%s: 수락 후 active" % npc_id)

	await _interact(npc_id) # obj_01: talk npc:<npc_id>
	_check(QuestSystem.get_active_objective_index(quest_id) == 1, "%s: talk 목표 진행" % npc_id)
	await _key(KEY_ESCAPE)

	await objectives_fn.call()
	_check(QuestSystem.get_state(quest_id) == "complete_ready", "%s: 나머지 목표 완료 후 complete_ready" % npc_id)

	await _open_and_expect(npc_id, quest_id, npc_id)
	await _key(KEY_ENTER) # advance
	_check(QuestSystem.get_state(quest_id) == "completed", "%s: 완료 보고로 completed" % npc_id)


## dami: obj_02 reach heartland_pasture_boundary(실제 플레이어 이동으로 Area2D 통과) ->
## obj_03 interact object:montsil_rabbit. D-262로 분기 확정이 상호작용 즉시에서 대사
## 응답의 `do resolve_branch_outcome(...)`으로 옮겨졌으므로(world_objects.json에
## branch_choice_id가 더 이상 없다) 이 스모크도 선택지를 실제로 골라야 한다 —
## SmokeDialogueFlow와 같은 관례로 balloon 신호를 직접 튕긴다.
func _run_montsil_objectives() -> void:
	const Q := "quest_side_heartland_montsil"
	_ui.npc_dialogue_controller.skip_all()
	_player.global_position = (_layer.spawned_by_id["heartland_pasture_boundary"] as Node2D).global_position
	for i in range(6): await get_tree().physics_frame
	_check(QuestSystem.get_active_objective_index(Q) == 2, "dami: reach 목표 진행(실제 Area2D 통과)")
	await _interact("montsil_rabbit")
	await _choose_response(0) # "그냥 놓아준다" = release


## 선택지 대사에서 index번째 응답을 고르고, 이어지는 반응 줄까지 정상 확인으로 넘긴다.
## 여기서는 skip_all()을 쓰면 안 된다 — 전체 스킵은 DMConstants.ID_END로 점프하므로
## 반응 줄 뒤의 `do resolve_branch_outcome(...)` 변이가 실행되지 않는다(아래 TODO).
func _choose_response(index: int) -> void:
	var balloon: DialogueBalloon = _ui.npc_dialogue_controller.balloon
	for i in range(120):
		if balloon.is_typing(): balloon.skip_typing()
		if balloon.responses_menu.visible: break
		await get_tree().process_frame
	balloon.response_chosen.emit(balloon.responses_menu.responses[index])
	for i in range(120):
		if balloon.is_typing(): balloon.skip_typing()
		if not _ui.npc_dialogue_controller.is_dialogue_open(): break
		balloon.advanced.emit(false) # 반응 줄 확인 -> do절 실행 -> END
		await get_tree().process_frame


func _run_festival_objectives() -> void:
	const Q := "quest_side_heartland_festival_prep"
	for i in 3: Events.monster_died.emit(&"horn_rabbit")
	_check(QuestSystem.get_active_objective_index(Q) == 2, "rozel: kill 3마리 목표 진행")
	Events.item_acquired.emit(&"ribbon_dandelion", 5)


func _run_orefetch_objectives() -> void:
	const Q := "quest_side_heartland_orefetch"
	for i in 3: Events.monster_died.emit(&"mushroom")
	_check(QuestSystem.get_active_objective_index(Q) == 2, "pinto: kill 3마리 목표 진행")
	Events.item_acquired.emit(&"iron_ore", 4)


func _run_herbrun_objectives() -> void:
	const Q := "quest_side_heartland_herbrun"
	Events.item_acquired.emit(&"herb_common", 4)
	_check(QuestSystem.get_active_objective_index(Q) == 2, "meru: 첫 수집 목표 진행")
	Events.item_acquired.emit(&"mushroom_cap", 2)
