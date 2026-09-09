## 세이브/부활 + 인벤토리/장비/골드/우편함 등 전역 게임 상태 자동로드(F8-2, D-28 / M2-1
## F3-1·F3-2). 세이브 파일 자체는 M2-4 범위 — 지금은 Inventory/Equipment의 to_dict()/
## from_dict()만 준비해 두고, 실제 디스크 입출력은 세이브 시스템 태스크가 이 함수들을
## 그대로 호출하면 된다.
extends Node

## 순수 로직 클래스(RefCounted) 인스턴스 — GameState(Node, 오토로드)가 이들을 들고
## 있으면서 Events 발신·Player 반영 같은 "부수효과"만 담당한다(resources.gd/PlayerResources
## 와 동일한 분리 원칙).
var inventory := Inventory.new()
var equipment := Equipment.new()

## 골드(F3-1 "골드는 즉시 획득"). 음수 델타(구매 등)는 M2 이후 경제 시스템 범위.
var gold: int = 0

## 인벤토리가 가득 찼을 때 자동 전송되는 마을 우편함(D-10: "보관 기한 없음"). ItemInstance
## Dictionary(LootSystem 참고)를 그대로 쌓아 둔다 — 실제 우편함 UI/수령은 M2-2 이후.
var mailbox: Array = []

## Events.player_spawned로 잡아 두는 참조 — 장비 스탯을 재계산한 뒤 player.resources에
## 반영하려면 필요하다(player.gd:apply_equipment_stats() 참고).
var _player: Player = null

## 마지막으로 상호작용(활성화)한 비석(Waystone) 노드. null이면 아직 비석과 상호작용한
## 적이 없다는 뜻 — 이 경우 부활 위치는 원점(Vector2.ZERO)으로 대체한다(초기 스폰 비석을
## 어디에 둘지는 레벨 디자인 몫, TODO).
var last_waystone: Node2D = null

## 사망 횟수(디버그 HUD 표시용). 세이브 파일에 영구 기록할지는 F8-3(세이브) 범위.
var death_count: int = 0

## 보스전 사망 예외(D-23: 골드 손실 없이 보스방 앞 비석에서 즉시 재도전, 보스 HP 초기화)를
## 위한 자리표시 플래그. 보스 시스템이 아직 없어 지금은 아무도 이 값을 true로 바꾸지
## 않는다 — M2에서 보스 인카운터 진입/종료 시 이 플래그를 토글하도록 연결할 것.
var in_boss_encounter: bool = false


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.player_spawned.connect(_on_player_spawned)


## 비석과 상호작용했을 때 호출(Waystone.activate()). 워프 목적지 선택 UI는 M2 범위 —
## 지금은 "부활 기준점"으로만 쓰인다(D-28: 부활 비석 = 워프 비석 동일 오브젝트).
func set_last_waystone(waystone: Node2D) -> void:
	last_waystone = waystone


## 부활 위치. 비석과 상호작용한 적이 없으면 원점.
func get_respawn_position() -> Vector2:
	if last_waystone != null and is_instance_valid(last_waystone):
		return last_waystone.global_position
	return Vector2.ZERO


func _on_player_died() -> void:
	death_count += 1


func _on_player_spawned(player: Node2D) -> void:
	_player = player as Player
	if _player != null:
		_apply_equipment_stats_to_player()


# --- 인벤토리/골드/우편함 (F3-1, D-10) ---

## LootSystem.roll_drop()/roll_gold()가 만든 ItemInstance를 획득 처리한다(드랍 필드
## 오브젝트 접근 시 자동 획득 — scripts/world/item_drop.gd 참고). 가득 찼으면 D-10대로
## 우편함으로 돌리고 item_mailed를, 아니면 item_picked_up을 발신한다.
func pickup_item(item_instance: Dictionary, item_def: Dictionary) -> void:
	var item_id := StringName(item_instance.get("item_id", ""))
	var qty := int(item_instance.get("quantity", 1))
	var result: Inventory.AddResult = inventory.add_item(item_instance, item_def)
	if result == Inventory.AddResult.FULL:
		mailbox.append(item_instance)
		Events.item_mailed.emit(item_id, qty)
	else:
		Events.item_picked_up.emit(item_id, qty)
	Events.inventory_changed.emit()


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold += amount
	Events.gold_changed.emit(gold, amount)


## LUK 스탯 훅(D-52 LUK 곱연산 공식의 입력값). stats.json/캐릭터 스탯 시스템이 아직 없어
## 0.0 고정 — stats.json 확정 시 이 함수만 실제 플레이어 LUK를 반환하도록 고치면
## LootSystem.roll_drop() 호출부(scripts/systems/loot_spawner.gd)는 그대로 둬도 된다.
func get_player_luck() -> float:
	return 0.0


# --- 장비 (F3-2, D-12) ---

## 슬롯에 장착한다. 이전에 있던 아이템은 인벤토리로 돌아간다(가득 차 있으면 우편함으로,
## pickup_item()과 동일 경로). 카테고리가 안 맞으면 false — 아무것도 바뀌지 않는다.
## 가방의 index번째 슬롯을 slot_name에 장착한다(F7-2 인벤토리 UI 전용 진입점 — 어느
## 슬롯에 넣을지는 호출부(inventory_menu.gd)가 카테고리로 이미 정해서 넘긴다). 카테고리가
## 안 맞으면 인벤토리를 건드리지 않고 false를 반환한다. 성공하면 그 슬롯을 인벤토리에서
## 빼고 장착하고, 기존 장착품은 equip_item()이 인벤토리로 돌려놓는다.
func equip_from_slot(index: int, slot_name: String) -> bool:
	if index < 0 or index >= inventory.slots.size():
		return false
	var item_instance: Dictionary = inventory.slots[index]
	var item_def: Dictionary = Data.get_value("items", String(item_instance.get("item_id", "")), {})
	if not equipment.can_equip(slot_name, item_def):
		return false
	inventory.remove_slot(index)
	return equip_item(slot_name, item_instance, item_def)


func equip_item(slot_name: String, item_instance: Dictionary, item_def: Dictionary) -> bool:
	var result: Dictionary = equipment.equip(slot_name, item_instance, item_def)
	if result.has("__error__"):
		return false
	if not result.is_empty():
		var previous_def: Dictionary = Data.get_value("items", String(result.get("item_id", "")), {})
		pickup_item(result, previous_def)
	_apply_equipment_stats_to_player()
	Events.inventory_changed.emit()
	return true


## 소모품 사용(M2-2, F7-2 인벤토리 "A=사용"). effect_type=="heal_hp"만 실제 효과를
## 적용한다(player.resources.heal) — buff_* 계열(공격력/이속 등 지속버프)은 버프
## 시스템이 아직 없어(M2 이후 범위) 소모만 되고 효과는 적용되지 않는다(엔지니어 TODO:
## 버프 시스템 확정 시 이 match에 분기만 추가하면 됨). 인벤토리 UI가 아닌 다른 화면
## (대장간 등)에서도 재사용할 수 있도록 GameState에 둔다.
func use_item(index: int) -> bool:
	if index < 0 or index >= inventory.slots.size():
		return false
	var slot: Dictionary = inventory.slots[index]
	var item_def: Dictionary = Data.get_value("items", String(slot.get("item_id", "")), {})
	if String(item_def.get("category", "")) != "consumable":
		return false
	var effect_type := String(item_def.get("effect_type", ""))
	if effect_type == "heal_hp" and _player != null and is_instance_valid(_player):
		_player.resources.heal(int(item_def.get("effect_value", 0)))
		Events.player_hp_changed.emit(_player.resources.hp, _player.resources.max_hp)
	var remaining: int = int(slot.get("quantity", 1)) - 1
	if remaining <= 0:
		inventory.remove_slot(index)
	else:
		slot["quantity"] = remaining
	Events.inventory_changed.emit()
	return true


func unequip_item(slot_name: String) -> bool:
	var removed: Dictionary = equipment.unequip(slot_name)
	if removed.is_empty():
		return false
	var removed_def: Dictionary = Data.get_value("items", String(removed.get("item_id", "")), {})
	pickup_item(removed, removed_def)
	_apply_equipment_stats_to_player()
	Events.inventory_changed.emit()
	return true


func _apply_equipment_stats_to_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var stats: Dictionary = Equipment.compute_stats(equipment.slots, Data.table("items"), Data.table("enhance"))
	_player.apply_equipment_stats(stats)


# --- 직렬화 (M2-4 세이브 시스템이 그대로 호출할 수 있도록 준비만 — 지금은 디스크
## 입출력 없이 Dictionary 변환만 제공한다) ---

func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"mailbox": mailbox.duplicate(true),
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	mailbox = (data.get("mailbox", []) as Array).duplicate(true)
	inventory.from_dict(data.get("inventory", {}))
	equipment.from_dict(data.get("equipment", {}))
	_apply_equipment_stats_to_player()


# --- 디버그 (F4, 정식 인벤토리 UI는 M2-2) ---

## F4로 여는 인벤토리 텍스트 덤프(scripts/ui/hud.gd가 호출). 콘솔에 print()하고 같은
## 문자열을 반환한다(스모크 테스트가 내용을 검증할 수 있도록).
func dump_inventory_debug() -> String:
	var lines: Array[String] = []
	lines.append("=== 인벤토리 (%d/%d) ===" % [inventory.slot_count(), inventory.capacity()])
	for i in inventory.slots.size():
		var slot: Dictionary = inventory.slots[i]
		var item_def: Dictionary = Data.get_value("items", String(slot.get("item_id", "")), {})
		var name_key: String = String(item_def.get("name_key", slot.get("item_id", "")))
		lines.append("[%d] %s x%d (%s) uid=%s" % [
			i, name_key, slot.get("quantity", 1), slot.get("grade", ""), slot.get("uid", ""),
		])
	lines.append("--- 장비 ---")
	for slot_name: String in Equipment.SLOT_NAMES:
		var item: Dictionary = equipment.slots.get(slot_name, {})
		if item.is_empty():
			lines.append("%s: (비어있음)" % slot_name)
		else:
			lines.append("%s: %s +%d (%s)" % [
				slot_name, item.get("item_id", ""), item.get("enhance_level", 0), item.get("grade", ""),
			])
	lines.append("골드: %d" % gold)
	lines.append("우편함: %d건" % mailbox.size())
	var text := "\n".join(lines)
	print(text)
	return text
