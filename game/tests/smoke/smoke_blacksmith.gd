## 헤드리스 스모크 테스트: "대장간 NPC 상호작용 -> Events.blacksmith_opened" +
## "GameState.blacksmith_*() 강화/재련/제작 전체 파이프라인"(M2-4, F3-3·F3-4).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeBlacksmith.tscn --quit-after 600
extends Node

var _main: Node
var _player: Player
var _npc: BlacksmithNpc

var _opened: bool = false
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE BLACKSMITH: NPC 상호작용 + 강화/재련/제작 파이프라인 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_npc = _main.get_node("BlacksmithNpc1") as BlacksmithNpc

	Events.blacksmith_opened.connect(_on_opened)
	_player.global_position = _npc.global_position
	# body_entered는 물리 프레임에 발생 — 감지될 때까지 최대 1초 폴링한다(smoke_death_
	# respawn.gd와 동일 패턴, 고정 프레임 수 대기보다 안전).
	var waited: float = 0.0
	while _npc._player_inside != _player and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_press_interact()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("NPC 상호작용 -> blacksmith_opened 발신", _opened)

	_run_enhance_flow()
	_run_refine_flow()
	_run_craft_flow()
	_run_salvage_flow()

	print("=== SMOKE BLACKSMITH 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)


func _on_opened() -> void:
	_opened = true


func _press_interact() -> void:
	var evt := InputEventAction.new()
	evt.action = "interact"
	evt.pressed = true
	Input.parse_input_event(evt)


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _run_enhance_flow() -> void:
	GameState.gold = 0
	GameState.inventory.slots.clear()
	GameState.add_gold(5000)
	var stone_id: String = String(Data.get_value("enhance", "refine.cost_material_id", "enhance_stone"))
	GameState.inventory.add_item(
		{"uid": "u_stone", "item_id": stone_id, "quantity": 50},
		Data.get_value("items", stone_id, {}))
	var weapon: Dictionary = {
		"uid": "u_smoke_weapon", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": [{"affix_id": "atk_pct", "stat_type": "atk_pct", "value": 5.0}],
		"enhance_level": 0, "refine_left": 3, "locked": false,
	}
	GameState.inventory.slots.append(weapon)

	var reached_plus6: bool = true
	for _i in 6:
		var result: Dictionary = GameState.blacksmith_enhance("u_smoke_weapon")
		if not (result.get("ok", false) and result.get("success", false)):
			reached_plus6 = false
			break
	_check("강화 +1~+6 전부 성공(D-14)", reached_plus6 and int(weapon["enhance_level"]) == 6)
	_check("강화 성공마다 골드 차감", GameState.gold < 5000)


func _run_refine_flow() -> void:
	var uid := "u_smoke_weapon"
	var weapon: Dictionary = GameState.inventory.slots[GameState.inventory.find_by_uid(uid)]
	var refine_left_before: int = int(weapon["refine_left"])
	var roll: Dictionary = GameState.blacksmith_refine(uid, 0)
	_check("재련 굴림 성공", roll.get("ok", false))
	_check("D-85: 굴림 즉시 재련 횟수 차감", int(weapon["refine_left"]) == refine_left_before - 1)
	var commit: Dictionary = GameState.blacksmith_refine_commit(uid, true)
	_check("재련 확정(신규 옵션 채택)", commit.get("ok", false) and commit.get("kept") == "new")


func _run_craft_flow() -> void:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints.get("blueprint_iron_sword", {})
	for mat: Dictionary in (bp.get("materials", []) as Array):
		GameState.inventory.slots.append({
			"uid": "u_mat_%s" % mat["item_id"], "item_id": mat["item_id"], "quantity": int(mat["qty"]),
		})
	GameState.add_gold(int(bp.get("cost_gold", 0)) + 100)
	var result: Dictionary = GameState.blacksmith_craft("blueprint_iron_sword")
	# 재료 슬롯 2개가 소모되며 사라지고 완성품 슬롯 1개가 새로 생기므로 슬롯 "수"가 아니라
	# 실제 완성품 uid가 인벤토리에 들어왔는지로 확인한다(net slot delta는 재료 수에 따라
	# 음수가 될 수 있어 부정확한 판정 기준).
	var crafted_uid: String = String(result.get("item_inst", {}).get("uid", ""))
	var found: bool = result.get("ok", false) and GameState.inventory.find_by_uid(crafted_uid) != -1
	_check("제작 성공 -> 인벤토리에 결과물 추가", found)


func _run_salvage_flow() -> void:
	GameState.inventory.slots.append({
		"uid": "u_salvage_target", "item_id": "weapon_uncommon_1", "grade": "uncommon", "quantity": 1,
		"affixes": [], "enhance_level": 0, "refine_left": 0, "locked": false,
	})
	var stones_before: int = 0
	for slot: Dictionary in GameState.inventory.slots:
		if String(slot.get("item_id", "")) == "enhance_stone":
			stones_before += int(slot.get("quantity", 0))
	var result: Dictionary = GameState.blacksmith_salvage(["u_salvage_target"])
	_check("분해 성공(비장착·비잠금)", result.get("ok", false))
	_check("분해로 아이템이 인벤토리에서 사라짐", GameState.inventory.find_by_uid("u_salvage_target") == -1)
