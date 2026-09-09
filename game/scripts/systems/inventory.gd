## 인벤토리 순수 로직(F3-2, D-10/D-11). Godot 노드에 의존하지 않는 RefCounted라 GUT에서
## 직접 테스트할 수 있다 — 실제 게임에서는 GameState(오토로드, Node)가 인스턴스 하나를
## 들고 있으면서 Events(item_picked_up/item_mailed/inventory_changed) 발신을 담당한다
## (resources.gd/PlayerResources와 같은 "로직은 순수, 이벤트는 호출부" 분리 패턴).
##
## 슬롯 표현: Array[Dictionary]. 한 슬롯 = ItemInstance(LootSystem 참고)를 그대로 담되,
## 스택 가능 카테고리(material/consumable)는 quantity가 늘어나는 "같은 슬롯"으로 합쳐진다.
## 장비(EQUIP_CATEGORIES)는 절대 스택하지 않는다(옵션·강화 단계가 개체마다 달라 합칠 수
## 없음) — item_def가 없으면(호출부 실수) 안전하게 비스택으로 취급한다.
class_name Inventory
extends RefCounted

const BASE_CAPACITY := 40 ## D-11: 기본 40칸.
const MAX_BACKPACK_BONUS := 40 ## D-11: 백팩으로 최대 +40(합계 80칸) — backpack_large 기준.

enum AddResult { ADDED, STACKED, FULL }

var slots: Array = [] ## Array[Dictionary] — ItemInstance(quantity 포함).
var capacity_bonus: int = 0 ## 장착한 백팩(costume_backpack)의 inventory_slot_bonus 합.


func capacity() -> int:
	return BASE_CAPACITY + capacity_bonus


func slot_count() -> int:
	return slots.size()


func is_full() -> bool:
	return slots.size() >= capacity()


## 백팩 장착/해제 훅(F3-2 "백팩 아이템으로 확장" — 백팩 자체를 착용하는 UI/치장 슬롯은
## M2-2 범위. 지금은 "장착된 백팩의 inventory_slot_bonus 합"만 반영하는 훅으로 둔다).
func set_backpack_bonus(bonus: int) -> void:
	capacity_bonus = clampi(bonus, 0, MAX_BACKPACK_BONUS)


## item_instance를 넣는다. item_def(items.json 엔트리)로 category/stack_max를 판단한다.
## 반환: ADDED(새 슬롯 사용) / STACKED(기존 슬롯에 합침, 슬롯 수 불변) / FULL(자리 없음 —
## 호출부가 D-10대로 우편함으로 돌려야 한다. 이 함수는 인벤토리를 건드리지 않는다).
func add_item(item_instance: Dictionary, item_def: Dictionary) -> AddResult:
	var category: String = String(item_def.get("category", ""))
	var stackable: bool = not Data.EQUIP_CATEGORIES.has(category) and category != ""
	var stack_max: int = int(item_def.get("stack_max", 1)) if stackable else 1
	var item_id: String = String(item_instance.get("item_id", ""))
	var qty: int = int(item_instance.get("quantity", 1))

	if stackable and stack_max > 1:
		for slot: Dictionary in slots:
			if String(slot.get("item_id", "")) != item_id:
				continue
			var current: int = int(slot.get("quantity", 1))
			if current >= stack_max:
				continue
			var room: int = stack_max - current
			var move: int = mini(room, qty)
			slot["quantity"] = current + move
			qty -= move
			if qty <= 0:
				return AddResult.STACKED
		# 남은 수량은 새 슬롯(들)에 채운다 — 자리가 있는 만큼만.
		while qty > 0:
			if is_full():
				return AddResult.FULL
			var put: int = mini(qty, stack_max)
			var new_slot: Dictionary = item_instance.duplicate(true)
			new_slot["quantity"] = put
			slots.append(new_slot)
			qty -= put
		return AddResult.ADDED

	# 비스택(장비, 또는 stack_max<=1인 재료/소모품): 슬롯 1개 = 개체 1개.
	if is_full():
		return AddResult.FULL
	slots.append(item_instance.duplicate(true))
	return AddResult.ADDED


func remove_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots.pop_at(index)


func find_by_uid(uid: String) -> int:
	for i in slots.size():
		if String((slots[i] as Dictionary).get("uid", "")) == uid:
			return i
	return -1


## 자동 정렬(F3-2: "등급→종류→id"). items_table은 슬롯의 category를 조회하기 위해
## 호출부(items.json 소유 테이블)가 명시적으로 넘긴다 — 이 클래스는 Data 오토로드를
## 직접 참조하지 않는 순수 로직 원칙을 지킨다.
func sort_slots(items_table: Dictionary) -> void:
	var grade_rank := Data.ITEM_GRADES
	var category_rank := Data.ITEM_CATEGORIES
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var def_a: Dictionary = items_table.get(String(a.get("item_id", "")), {})
		var def_b: Dictionary = items_table.get(String(b.get("item_id", "")), {})
		var ga: int = grade_rank.find(String(a.get("grade", def_a.get("grade", ""))))
		var gb: int = grade_rank.find(String(b.get("grade", def_b.get("grade", ""))))
		if ga != gb:
			return ga < gb
		var ca: int = category_rank.find(String(def_a.get("category", "")))
		var cb: int = category_rank.find(String(def_b.get("category", "")))
		if ca != cb:
			return ca < cb
		return String(a.get("item_id", "")) < String(b.get("item_id", "")))



func to_dict() -> Dictionary:
	return {
		"capacity_bonus": capacity_bonus,
		"slots": slots.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	capacity_bonus = int(data.get("capacity_bonus", 0))
	slots = (data.get("slots", []) as Array).duplicate(true)
