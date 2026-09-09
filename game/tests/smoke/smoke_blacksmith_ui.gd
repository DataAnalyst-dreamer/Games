## 헤드리스 스모크 테스트: "대장간 메뉴 열기 -> 4탭 진입 -> 강화 1회 -> 재련 1회 확정
## -> 분해 1개 -> 제작 1개 -> 닫기"(F3-3/F3-4, M2-5 작업 지시 6번). 실제 UI 스크립트
## (BlacksmithMenu/UiRoot)의 공개 API를 InventoryMenu 스모크(smoke_inventory_menu.gd)와
## 동일한 방식으로 호출해 "같은 코드 경로"를 검증한다 — 로직 자체(성공률/차감 규칙)는
## smoke_blacksmith.gd(M2-4)가 이미 검증했으므로 여기서는 UI가 그 로직을 올바르게
## 배선했는지만 확인한다.
##
## 실행: godot --headless --path game res://tests/smoke/SmokeBlacksmithUi.tscn --quit-after 300
extends Node

var _main: Node
var _ui_root: UiRoot
var _menu: BlacksmithMenu
var _mailbox: MailboxPopup
var _npc: BlacksmithNpc

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE BLACKSMITH UI: 메뉴 열기 -> 4탭 -> 강화/재련/분해/제작 -> 닫기 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_ui_root = _main.get_node("UiRoot") as UiRoot
	_menu = _ui_root.blacksmith_menu
	_mailbox = _ui_root.mailbox_popup
	_npc = _main.get_node("BlacksmithNpc1") as BlacksmithNpc

	_setup_state()

	# 1) NPC 상호작용 -> Events.blacksmith_opened -> UiRoot가 열고 paused(D-24).
	var player: Player = _main.get_node("Player") as Player
	player.global_position = _npc.global_position
	var waited: float = 0.0
	while _npc._player_inside != player and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_press_action("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("NPC 상호작용 -> 대장간 열림 + paused(D-24)", _ui_root.is_blacksmith_open() and get_tree().paused)

	_run_enhance_tab()
	_run_refine_tab()
	_run_salvage_tab()
	_run_craft_tab()

	# 6) 닫기 -> unpaused(D-24).
	_ui_root.close_blacksmith()
	_check("닫기 -> unpaused(D-24)", not _ui_root.is_blacksmith_open() and not get_tree().paused)

	await _run_mailbox_flow()

	print("=== SMOKE BLACKSMITH UI 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _setup_state() -> void:
	GameState.gold = 0
	GameState.inventory.slots.clear()
	GameState.add_gold(10000)
	var stone_id: String = String(Data.get_value("enhance", "refine.cost_material_id", "enhance_stone"))
	GameState.inventory.add_item({"uid": "u_ui_stone", "item_id": stone_id, "quantity": 50}, Data.get_value("items", stone_id, {}))
	GameState.inventory.slots.append({
		"uid": "u_ui_weapon", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}],
		"enhance_level": 0, "refine_left": 3, "locked": false,
	})
	GameState.inventory.slots.append({
		"uid": "u_ui_salvage_target", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": [], "enhance_level": 0, "refine_left": 0, "locked": false,
	})
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints.get("blueprint_iron_sword", {})
	for mat: Dictionary in (bp.get("materials", []) as Array):
		GameState.inventory.slots.append({"uid": "u_ui_mat_%s" % mat["item_id"], "item_id": mat["item_id"], "quantity": int(mat["qty"]) + 5})


func _press_action(action: String) -> void:
	var evt := InputEventAction.new()
	evt.action = action
	evt.pressed = true
	Input.parse_input_event(evt)


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _run_enhance_tab() -> void:
	_menu.set_tab(&"enhance")
	_check("강화 탭 진입", _menu.current_tab() == &"enhance")
	var idx: int = _menu.find_entry_index("u_ui_weapon")
	_check("강화 탭 목록에 대상 장비 존재", idx != -1)
	_menu.focus_at(idx)
	_menu.confirm() # A = 강화 실행(+1은 D-14 성공률 100%).
	var slot_idx: int = GameState.inventory.find_by_uid("u_ui_weapon")
	_check("강화 1회 -> +1 도달", slot_idx != -1 and int(GameState.inventory.slots[slot_idx].get("enhance_level", 0)) == 1)


func _run_refine_tab() -> void:
	_menu.set_tab(&"refine")
	_check("재련 탭 진입", _menu.current_tab() == &"refine")
	var idx: int = _menu.find_entry_index("u_ui_weapon")
	_check("재련 탭 목록에 대상 장비 존재(옵션 보유)", idx != -1)
	_menu.focus_at(idx)
	_menu.enter_refine_affix_focus(0)
	var refine_left_before: int = int(GameState.inventory.slots[GameState.inventory.find_by_uid("u_ui_weapon")].get("refine_left", 0))
	_menu.confirm() # A(옵션 줄 포커스 상태) = 재련 굴림 -> 비교 팝업.
	_check("재련 굴림 -> 비교 팝업 열림", _menu.has_popup_open())
	_menu.set_refine_choice_and_confirm(true) # 신규 옵션 채택.
	var weapon: Dictionary = GameState.inventory.slots[GameState.inventory.find_by_uid("u_ui_weapon")]
	_check("재련 확정 -> 팝업 닫힘 + 횟수 차감", not _menu.has_popup_open() and int(weapon.get("refine_left", 0)) == refine_left_before - 1)


func _run_salvage_tab() -> void:
	_menu.set_tab(&"salvage")
	_check("분해 탭 진입", _menu.current_tab() == &"salvage")
	var idx: int = _menu.find_entry_index("u_ui_salvage_target")
	_check("분해 탭 목록에 대상(비장착·비잠금) 존재", idx != -1)
	_menu.focus_at(idx)
	_menu.confirm() # A = 체크 토글.
	_menu.trigger_salvage_hold_complete() # Y 0.8초 홀드 완료와 동일 판정 경로.
	_check("분해 완료 -> 대상이 인벤토리에서 사라짐", GameState.inventory.find_by_uid("u_ui_salvage_target") == -1)


func _run_craft_tab() -> void:
	_menu.set_tab(&"craft")
	_check("제작 탭 진입", _menu.current_tab() == &"craft")
	var idx: int = _menu.find_entry_index("blueprint_iron_sword")
	_check("제작 탭 목록에 도면 존재(blueprints.json 연동, D-89)", idx != -1)
	_menu.focus_at(idx)
	var gold_before: int = GameState.gold
	_menu.confirm() # A = 제작 실행.
	var crafted: bool = false
	for slot: Dictionary in GameState.inventory.slots:
		if String(slot.get("item_id", "")) == "weapon_uncommon_1" and String(slot.get("uid", "")) != "u_ui_weapon":
			crafted = true
			break
	_check("제작 완료 -> 결과물이 인벤토리에 추가되고 골드 차감", crafted and GameState.gold < gold_before)


func _run_mailbox_flow() -> void:
	GameState.mailbox.mails.clear()
	GameState.mailbox.push({"gold": 77})
	var mailbox_npc: MailboxNpc = _main.get_node("MailboxNpc1") as MailboxNpc
	var player: Player = _main.get_node("Player") as Player
	player.global_position = mailbox_npc.global_position
	var waited: float = 0.0
	while mailbox_npc._player_inside != player and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_press_action("interact")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("우편함 오브젝트 상호작용 -> 팝업 열림 + paused(D-24)", _ui_root.is_mailbox_open() and get_tree().paused)

	var gold_before: int = GameState.gold
	_mailbox.focus_at(0)
	_mailbox.claim_focused()
	_check("우편함 개별 수령 -> 골드 반영", GameState.gold == gold_before + 77)

	_ui_root.close_mailbox()
	_check("우편함 닫기 -> unpaused(D-24)", not _ui_root.is_mailbox_open() and not get_tree().paused)
