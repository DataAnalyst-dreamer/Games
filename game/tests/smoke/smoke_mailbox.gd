## 헤드리스 스모크 테스트: "우편함 NPC 상호작용 -> Events.mailbox_opened" +
## "인벤토리 오버플로 -> 우편함 자동 전송 -> 수령/일괄 수령"(M2-4, F3-1 D-10).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeMailbox.tscn --quit-after 600
extends Node

const MATERIAL_DEF := {"category": "material", "stack_max": 99}

var _main: Node
var _player: Player
var _npc: MailboxNpc

var _opened: bool = false
var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE MAILBOX: NPC 상호작용 + 오버플로/수령 파이프라인 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_npc = _main.get_node("MailboxNpc1") as MailboxNpc

	Events.mailbox_opened.connect(_on_opened)
	_player.global_position = _npc.global_position
	var waited: float = 0.0
	while _npc._player_inside != _player and waited < 1.0:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_press_interact()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("NPC 상호작용 -> mailbox_opened 발신", _opened)

	_run_overflow_flow()
	_run_claim_all_flow()

	print("=== SMOKE MAILBOX 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
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


func _run_overflow_flow() -> void:
	GameState.inventory.slots.clear()
	GameState.mailbox = Mailbox.new()
	for i in GameState.inventory.capacity():
		GameState.inventory.add_item({"uid": "block_%d" % i, "item_id": "iron_ore", "quantity": 99}, MATERIAL_DEF)
	assert(GameState.inventory.is_full())

	# GDScript 람다는 바깥 지역 변수를 "값으로" 캡처한다 — bool/String 같은 값 타입은
	# 람다 안에서 대입해도 바깥에 반영되지 않는다(claimed.append() 패턴은 다른 테스트에서도
	# 이미 쓰는 관용구, Array는 참조 타입이라 안전). 그래서 결과를 담을 때 Array를 쓴다.
	var mail_received_ids: Array = []
	var cb := func(mail_id: String, _item_id: StringName, _count: int) -> void: mail_received_ids.append(mail_id)
	Events.mail_received.connect(cb)
	GameState.pickup_item({"uid": "overflow_1", "item_id": "iron_ore", "quantity": 7}, MATERIAL_DEF)
	Events.mail_received.disconnect(cb)

	_check("D-10: 인벤토리 가득 -> 우편함 큐로 전송", GameState.mailbox.size() == 1)
	_check("mail_received 발신(mail_id 포함)", not mail_received_ids.is_empty() and not String(mail_received_ids[0]).is_empty())
	var mail_id: String = String(mail_received_ids[0]) if not mail_received_ids.is_empty() else ""

	# 자리를 비우고 다시 수령하면 성공해야 한다(D-10: 보관 기한 없음, 재시도 가능).
	GameState.inventory.remove_slot(0)
	var claimed_events: Array = []
	var claim_cb := func(claimed_mail_id: String, _result: Dictionary) -> void: claimed_events.append(claimed_mail_id)
	Events.mail_claimed.connect(claim_cb)
	var claim_result: Dictionary = GameState.claim_mail(mail_id)
	Events.mail_claimed.disconnect(claim_cb)
	_check("자리 확보 후 재수령 성공", claim_result.get("ok", false) and not claimed_events.is_empty())
	_check("수령 후 큐가 비어야 함", GameState.mailbox.size() == 0)


func _run_claim_all_flow() -> void:
	GameState.mailbox = Mailbox.new()
	var gold_before: int = GameState.gold
	GameState.mailbox.push({"gold": 77})
	GameState.mailbox.push({"item_id": "iron_ore", "count": 3})

	var result: Dictionary = GameState.claim_all_mail()

	_check("claim_all: 2건 모두 성공", (result["claimed"] as Array).size() == 2)
	_check("claim_all: 골드 우편이 실제로 골드에 반영됨", GameState.gold == gold_before + 77)
	_check("claim_all 후 큐가 비어야 함", GameState.mailbox.size() == 0)
