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

## 마을 우편함(F3-1 D-10 "보관 기한 없음", M2-4에서 push/claim 큐로 정식화). 순수 로직
## 인스턴스 — inventory/equipment와 동일하게 GameState가 들고 있으면서 Events 발신만
## 담당한다.
var mailbox := Mailbox.new()

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

## 실제 플레이 시간 누적기(D-15: 정예/월드 보스 리스폰 타이머는 오프라인 시간 미포함).
## Node._process(delta)는 SceneTree.paused == true면 자동으로 호출되지 않으므로(기본
## process_mode=INHERIT), 일시정지 제외 조건은 별도 분기 없이 엔진이 보장해 준다.
## scripts/systems/elite_spawner.gd(M2-3)가 이 값을 직접 읽는 대신 아래
## elite_respawn_remaining_sec을 통해서만 리스폰 판정을 하고, 이 값 자체는 세이브
## 참고용/디버그용으로만 노출한다.
var play_time_sec: float = 0.0

## 정예 리스폰 카운트다운(초). source_id(=monster_id, elite_goblin_captain/
## elite_bunchi_spawn) -> 남은 초. 0 이하이거나 키가 없으면 "리스폰 준비됨"(스폰 가능)
## 을 뜻한다 — elite_spawner.gd가 처치 시 farming_sources.json.respawn_seconds로
## 채우고, 여기서 매 프레임 실제 플레이 시간만큼 깎는다(D-15). to_dict()/from_dict()로
## 세이브에 포함된다("GameState에 리스폰 타이머 직렬화").
var elite_respawn_remaining_sec: Dictionary = {}


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.player_spawned.connect(_on_player_spawned)


## 실제 플레이 시간 누적 + 정예 리스폰 카운트다운 감소(D-15). 일시정지 중에는 엔진이
## 이 함수 자체를 호출하지 않는다(기본 process_mode=INHERIT + SceneTree.paused).
func _process(delta: float) -> void:
	play_time_sec += delta
	for source_id in elite_respawn_remaining_sec.keys():
		elite_respawn_remaining_sec[source_id] = maxf(
			0.0, float(elite_respawn_remaining_sec[source_id]) - delta)


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
	var mail_count_before: int = mailbox.size()
	# D-10 오버플로 처리의 유일한 진입점(Inventory.add_or_mail) — 가득 차면 인벤토리를
	# 건드리지 않고 mailbox.push()로 돌린다.
	var result: Inventory.AddResult = inventory.add_or_mail(item_instance, item_def, mailbox)
	if result == Inventory.AddResult.FULL:
		Events.item_mailed.emit(item_id, qty)
		var mail_id: String = ""
		if mailbox.size() > mail_count_before:
			mail_id = String((mailbox.mails[-1] as Dictionary).get("id", ""))
		Events.mail_received.emit(mail_id, item_id, qty)
	else:
		Events.item_picked_up.emit(item_id, qty)
	Events.inventory_changed.emit()


func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold += amount
	Events.gold_changed.emit(gold, amount)


## 골드 지출(대장간 강화/재련/제작, M2-4). 부족하면 아무것도 바꾸지 않고 false.
func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	Events.gold_changed.emit(gold, -amount)
	return true


## mail_id로 지정한 우편을 수령한다(M2-4). 성공하면(골드/아이템 모두) mail_claimed를
## 발신하고, 아이템이었다면 inventory_changed도 함께 발신한다. 인벤토리가 가득 차
## 아이템을 못 받으면 큐에 남긴 채 {ok:false, reason:"inventory_full"}을 그대로 반환한다.
func claim_mail(mail_id: String) -> Dictionary:
	var result: Dictionary = mailbox.claim(mail_id, inventory, Data.table("items"))
	if result.get("ok", false):
		if String(result.get("kind", "")) == "gold":
			add_gold(int(result.get("amount", 0)))
		Events.inventory_changed.emit()
		Events.mail_claimed.emit(mail_id, result)
	return result


## 우편함 일괄 수령(M2-4 D-85 신설). claimed 각 건마다 add_gold/mail_claimed를 그대로
## 반영하고, 마지막에 inventory_changed 한 번만 발신한다(claim_mail()을 N번 부르면
## N번 발신하는 것과 달리 UI 갱신 비용을 한 번으로 줄인다).
func claim_all_mail() -> Dictionary:
	var result: Dictionary = mailbox.claim_all(inventory, Data.table("items"))
	var claimed: Array = result.get("claimed", [])
	for entry: Dictionary in claimed:
		if String(entry.get("kind", "")) == "gold":
			add_gold(int(entry.get("amount", 0)))
		Events.mail_claimed.emit(String(entry.get("mail_id", "")), entry)
	if not claimed.is_empty():
		Events.inventory_changed.emit()
	return result


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


# --- 대장간 (F3-3·F3-4, M2-4) ---
## Blacksmith(scripts/systems/blacksmith.gd)는 순수 로직이라 인벤토리/골드 조회, 실제
## 소모 반영, Events 발신을 이 4개 래퍼가 담당한다. uid로 대상 장비를 찾을 때 인벤토리와
## 장착 슬롯을 모두 뒤진다(장비를 벗지 않고도 강화/재련할 수 있어야 UX가 자연스럽다 —
## Dictionary는 참조 타입이라 장착 중인 item_inst를 직접 mutate해도 Equipment.slots에
## 그대로 반영된다).

func _find_equipped_slot_by_uid(uid: String) -> String:
	for slot_name: String in equipment.slots:
		var item: Dictionary = equipment.slots[slot_name]
		if not item.is_empty() and String(item.get("uid", "")) == uid:
			return slot_name
	return ""


func _find_item_instance_by_uid(uid: String) -> Dictionary:
	var idx: int = inventory.find_by_uid(uid)
	if idx != -1:
		return inventory.slots[idx]
	var slot_name: String = _find_equipped_slot_by_uid(uid)
	if slot_name != "":
		return equipment.slots[slot_name]
	return {}


## 인벤토리 여러 슬롯에 나뉜 재료 보유량 합계(강화석 등 스택형 재료 전용).
func _material_quantity(item_id: String) -> int:
	var total: int = 0
	for slot: Dictionary in inventory.slots:
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 1))
	return total


func blacksmith_enhance(uid: String) -> Dictionary:
	var item_inst: Dictionary = _find_item_instance_by_uid(uid)
	if item_inst.is_empty():
		var not_found: Dictionary = {"ok": false, "reason": "not_found"}
		Events.blacksmith_result.emit(&"enhance", not_found)
		return not_found
	Blacksmith.auto_resolve_pending(item_inst) # D-85: 다른 액션 전에 미확정 재련 자동 정리.
	var stone_id: String = String(Data.get_value("enhance", "refine.cost_material_id", "enhance_stone"))
	var result: Dictionary = Blacksmith.enhance(item_inst, Data.table("enhance"), gold, _material_quantity(stone_id))
	if result.get("ok", false):
		var consumed: Dictionary = result.get("consumed", {})
		spend_gold(int(consumed.get("gold", 0)))
		inventory.consume_item(stone_id, int(consumed.get("enhance_stone", 0)))
		_apply_equipment_stats_to_player()
		Events.inventory_changed.emit()
	Events.blacksmith_result.emit(&"enhance", result)
	return result


## 재련 1단계(D-85: 골드·재련 횟수는 이 호출 즉시 차감 — Blacksmith.refine() 참고).
func blacksmith_refine(uid: String, affix_index: int) -> Dictionary:
	var item_inst: Dictionary = _find_item_instance_by_uid(uid)
	if item_inst.is_empty():
		var not_found: Dictionary = {"ok": false, "reason": "not_found"}
		Events.blacksmith_result.emit(&"refine", not_found)
		return not_found
	Blacksmith.auto_resolve_pending(item_inst) # D-85: 이전 미확정 재련이 있으면 구 옵션으로 먼저 정리.
	var item_def: Dictionary = Data.get_value("items", String(item_inst.get("item_id", "")), {})
	var stone_id: String = String(Data.get_value("enhance", "refine.cost_material_id", "enhance_stone"))
	var result: Dictionary = Blacksmith.refine(
		item_inst, affix_index, item_def, Data.table("affixes"), Data.table("enhance"),
		gold, _material_quantity(stone_id))
	if result.get("ok", false):
		var cost: Dictionary = result.get("cost", {})
		spend_gold(int(cost.get("gold", 0)))
		inventory.consume_item(String(cost.get("material_id", stone_id)), int(cost.get("material_qty", 0)))
	Events.blacksmith_result.emit(&"refine", result)
	return result


## 재련 2단계(D-85: 택1 자체는 무료 — 비용/횟수는 이미 blacksmith_refine()에서 처리됨).
func blacksmith_refine_commit(uid: String, keep_new: bool) -> Dictionary:
	var item_inst: Dictionary = _find_item_instance_by_uid(uid)
	if item_inst.is_empty():
		var not_found: Dictionary = {"ok": false, "reason": "not_found"}
		Events.blacksmith_result.emit(&"refine_commit", not_found)
		return not_found
	var result: Dictionary = Blacksmith.refine_commit(item_inst, keep_new)
	if result.get("ok", false):
		_apply_equipment_stats_to_player()
		Events.inventory_changed.emit()
	Events.blacksmith_result.emit(&"refine_commit", result)
	return result


## 분해(S3-3c, D-85: 일괄 처리 — uids가 1개짜리라도 항상 Array). 항목별로 장착 중/
## 잠금/미확정 재련 자동 정리(auto_resolve_pending) 후 Blacksmith.salvage()에 넘기고,
## 성공한 항목만 실제로 인벤토리에서 지우고 산출물을 지급한다.
func blacksmith_salvage(uids: Array) -> Dictionary:
	var item_insts: Array = []
	var equipped_uids: Array = []
	for uid_v: Variant in uids:
		var uid: String = String(uid_v)
		var item_inst: Dictionary = _find_item_instance_by_uid(uid)
		if item_inst.is_empty():
			item_insts.append({"uid": uid}) # Blacksmith.salvage()가 invalid_grade로 걸러줌.
			continue
		Blacksmith.auto_resolve_pending(item_inst)
		if _find_equipped_slot_by_uid(uid) != "":
			equipped_uids.append(uid)
		item_insts.append(item_inst)

	var result: Dictionary = Blacksmith.salvage(item_insts, Data.table("enhance"), equipped_uids)
	if result.get("ok", false):
		for r: Dictionary in (result.get("results", []) as Array):
			if not r.get("ok", false):
				continue
			var uid2: String = String(r.get("uid", ""))
			var idx2: int = inventory.find_by_uid(uid2)
			if idx2 != -1:
				inventory.remove_slot(idx2)
			for material_id: String in (r.get("yields", {}) as Dictionary):
				var qty: int = int((r.get("yields", {}) as Dictionary)[material_id])
				if qty <= 0:
					continue
				var material_def: Dictionary = Data.get_value("items", material_id, {})
				var material_instance: Dictionary = {
					"uid": "salvage_%d_%s" % [Time.get_ticks_usec(), material_id], "item_id": material_id,
					"grade": "common", "quantity": qty, "affixes": [], "enhance_level": 0,
					"refine_left": 0, "locked": false,
				}
				pickup_item(material_instance, material_def)
		Events.inventory_changed.emit()
	Events.blacksmith_result.emit(&"salvage", result)
	return result


## 제작(F3-4). 도면 자체는 인벤토리/보유 목록에서 지우지 않는다(F3-4 예외 "도면 영구
## 보유" — blueprint_id 문자열만으로 호출한다, blueprints.json 도면을 개별 아이템으로
## 보관하는 시스템은 이번 패스 범위 밖).
func blacksmith_craft(blueprint_id: String) -> Dictionary:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints.get(blueprint_id, {})
	var materials_needed: Array = bp.get("materials", [])
	var have_materials: Dictionary = {}
	for mat: Dictionary in materials_needed:
		var mat_id: String = String(mat.get("item_id", ""))
		have_materials[mat_id] = _material_quantity(mat_id)
	var refine_max: int = int(Data.get_value("enhance", "refine.max_attempts", 3))

	var result: Dictionary = Blacksmith.craft(
		blueprint_id, blueprints, Data.table("items"), Data.table("affixes"), refine_max, gold, have_materials)
	if result.get("ok", false):
		spend_gold(int(bp.get("cost_gold", 0)))
		for mat2: Dictionary in materials_needed:
			inventory.consume_item(String(mat2.get("item_id", "")), int(mat2.get("qty", 0)))
		var item_inst: Dictionary = result.get("item_inst", {})
		var item_def: Dictionary = Data.get_value("items", String(item_inst.get("item_id", "")), {})
		pickup_item(item_inst, item_def)
	Events.blacksmith_result.emit(&"craft", result)
	return result


# --- 대장간 미리보기 API (부작용 없음, D-85 신설) — UI는 이 4개만 읽는다. ---

func get_enhance_preview(uid: String) -> Dictionary:
	var item_inst: Dictionary = _find_item_instance_by_uid(uid)
	if item_inst.is_empty():
		return {"ok": false, "reason": "not_found"}
	return Blacksmith.get_enhance_preview(item_inst, Data.table("enhance"))


func get_refine_cost(uid: String) -> Dictionary:
	var item_inst: Dictionary = _find_item_instance_by_uid(uid)
	if item_inst.is_empty():
		return {"ok": false, "reason": "not_found"}
	return Blacksmith.get_refine_cost(item_inst, Data.table("enhance"))


func get_salvage_preview(uids: Array) -> Dictionary:
	var item_insts: Array = []
	for uid_v: Variant in uids:
		var item_inst: Dictionary = _find_item_instance_by_uid(String(uid_v))
		if not item_inst.is_empty():
			item_insts.append(item_inst)
	return Blacksmith.get_salvage_preview(item_insts, Data.table("enhance"))


func get_craft_preview(blueprint_id: String) -> Dictionary:
	var blueprints: Dictionary = Data.table("blueprints")
	var bp: Dictionary = blueprints.get(blueprint_id, {})
	var have_materials: Dictionary = {}
	for mat: Dictionary in (bp.get("materials", []) as Array):
		var mat_id: String = String(mat.get("item_id", ""))
		have_materials[mat_id] = _material_quantity(mat_id)
	return Blacksmith.get_craft_preview(blueprint_id, blueprints, have_materials, gold)


# --- 직렬화 (M2-4 세이브 시스템이 그대로 호출할 수 있도록 준비만 — 지금은 디스크
## 입출력 없이 Dictionary 변환만 제공한다) ---

func to_dict() -> Dictionary:
	return {
		"gold": gold,
		"mailbox": mailbox.to_dict(),
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
		"play_time_sec": play_time_sec,
		"elite_respawn_remaining_sec": elite_respawn_remaining_sec.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 0))
	mailbox.from_dict(data.get("mailbox", {}))
	inventory.from_dict(data.get("inventory", {}))
	equipment.from_dict(data.get("equipment", {}))
	play_time_sec = float(data.get("play_time_sec", 0.0))
	elite_respawn_remaining_sec = (data.get("elite_respawn_remaining_sec", {}) as Dictionary).duplicate(true)
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
