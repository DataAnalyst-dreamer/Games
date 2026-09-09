## 마을 우편함 큐 순수 로직(F3-1 D-10 "보관 기한 없음" / M2-4 F3-3·F3-4 신설). Godot 노드에
## 의존하지 않는 RefCounted라 GUT에서 직접 테스트할 수 있다 — GameState(오토로드)가
## 인스턴스 하나를 들고 있으면서 Events(mail_received/mail_claimed) 발신만 담당한다
## (inventory.gd/equipment.gd와 동일한 "로직은 순수, 이벤트는 호출부" 분리 원칙).
##
## Mail 스키마(Dictionary): {id, item_id?, gold?, count, expires_day}. gold 우편은
## item_id 없이 gold 필드만, 아이템 우편은 item_id+count(+장비라면 LootSystem.
## make_item_instance()가 만드는 uid/grade/affixes/enhance_level/refine_left 등 부가
## 필드를 그대로 실어도 된다 — claim() 시 그 필드들을 살려서 인벤토리에 되돌린다.
## expires_day는 스키마에만 존재 — D-10이 "보관 기한 없음"을 확정했으므로 이 클래스는
## 아직 만료를 검사하지 않는다(향후 만료 정책이 추가되면 claim() 앞단에 필터 한 줄만
## 추가하면 됨 — game-designer 결정 대기, 완료 보고 질문 목록 참고).
class_name Mailbox
extends RefCounted

## uid 충돌 방지용 프로세스 전역 카운터(LootSystem._uid_counter와 동일 패턴).
static var _uid_counter: int = 0

var mails: Array = [] ## Array[Dictionary]


func size() -> int:
	return mails.size()


func is_empty() -> bool:
	return mails.is_empty()


## mail을 큐에 넣는다. id가 비어 있으면 자동 채번해서 그 값을 넣은 사본을 반환한다
## (호출부가 반환값의 "id"로 이후 claim()을 호출할 수 있도록).
func push(mail: Dictionary) -> Dictionary:
	var entry: Dictionary = mail.duplicate(true)
	if String(entry.get("id", "")).is_empty():
		entry["id"] = _next_id()
	mails.append(entry)
	return entry


func find_index(mail_id: String) -> int:
	for i in mails.size():
		if String((mails[i] as Dictionary).get("id", "")) == mail_id:
			return i
	return -1


## mail_id를 수령한다. gold 우편은 인벤토리 자리가 필요 없어 항상 성공(즉시 큐에서
## 제거). 아이템 우편은 인벤토리가 가득 차 있으면 실패("inventory_full")하고 큐에는
## 그대로 남는다(D-10 "보관 기한 없음"과 정합 — 나중에 자리를 비우고 다시 시도 가능).
## items_table은 스택 규칙(category/stack_max) 판단에 필요해 호출부가 넘긴다(Inventory.
## add_item()과 동일한 의존성 주입 원칙 — 이 클래스는 Data 오토로드를 직접 참조하지 않음).
## 반환:
##   실패: {ok:false, reason: "not_found"|"inventory_full"}
##   성공(골드): {ok:true, kind:"gold", amount:int, mail_id:String}
##   성공(아이템): {ok:true, kind:"item", item_id:String, count:int, mail_id:String}
func claim(mail_id: String, inventory: Inventory, items_table: Dictionary) -> Dictionary:
	var idx: int = find_index(mail_id)
	if idx == -1:
		return {"ok": false, "reason": "not_found"}
	var mail: Dictionary = mails[idx]

	if mail.has("gold"):
		mails.remove_at(idx)
		return {"ok": true, "kind": "gold", "amount": int(mail.get("gold", 0)), "mail_id": mail_id}

	var item_id: String = String(mail.get("item_id", ""))
	var item_def: Dictionary = items_table.get(item_id, {})
	var item_instance: Dictionary = mail.duplicate(true)
	item_instance.erase("id")
	item_instance.erase("expires_day")
	if not item_instance.has("quantity"):
		item_instance["quantity"] = int(mail.get("count", 1))
	if not item_instance.has("uid"):
		item_instance["uid"] = _next_id()

	var result: Inventory.AddResult = inventory.add_item(item_instance, item_def)
	if result == Inventory.AddResult.FULL:
		return {"ok": false, "reason": "inventory_full"}
	mails.remove_at(idx)
	return {
		"ok": true, "kind": "item", "item_id": item_id,
		"count": int(item_instance.get("quantity", 1)), "mail_id": mail_id,
	}


## 큐에 있는 모든 우편을 한 번에 수령 시도한다(M2-4 D-85 신설). 각 우편은 claim()과
## 동일한 규칙 — 인벤토리가 가득 차 실패한 아이템 우편은 큐에 남는다. id 목록을 먼저
## 스냅샷 떠서 순회하므로 claim() 내부의 remove_at()과 안전하게 공존한다.
func claim_all(inventory: Inventory, items_table: Dictionary) -> Dictionary:
	var ids: Array = []
	for mail: Dictionary in mails:
		ids.append(String(mail.get("id", "")))
	var claimed: Array = []
	var failed: Array = []
	for mail_id: String in ids:
		var result: Dictionary = claim(mail_id, inventory, items_table)
		if result.get("ok", false):
			claimed.append(result)
		else:
			failed.append(result)
	return {"claimed": claimed, "failed": failed}


static func _next_id() -> String:
	_uid_counter += 1
	return "mail_%d_%d" % [Time.get_ticks_usec(), _uid_counter]


func to_dict() -> Dictionary:
	return {"mails": mails.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	mails = (data.get("mails", []) as Array).duplicate(true)
