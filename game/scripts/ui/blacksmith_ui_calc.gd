## 대장간 화면(강화/재련/분해/제작, F3-3/F3-4, M2-5) 순수 계산. Godot 노드에 의존하지
## 않는 RefCounted라 GUT에서 직접 테스트한다 — `InventoryUiCalc`/`InventoryFocusCalc`와
## 동일한 "로직은 순수, 그리기·입력 폴링은 blacksmith_menu.gd" 분리 원칙(docs/ui/
## blacksmith.md §6). 실제 소모/굴림은 전부 `Blacksmith`(scripts/systems/blacksmith.gd)가
## 담당하고, 이 파일은 "목록에 뭘 보여줄지"·"버튼을 눌러도 되는지"·"홀드가 얼마나
## 찼는지"만 계산한다 — 미리보기 수치 자체(성공률/비용/스탯 배율)는 절대 다시 계산하지
## 않고 `Blacksmith.get_*_preview()`가 돌려주는 값을 그대로 표시용으로만 가공한다
## (중복 구현 금지, D-85 원칙 승계).
##
## `Data.ITEM_GRADES`/`Data.EQUIP_CATEGORIES`는 Data 오토로드가 들고 있는 컴파일 타임
## 상수(JSON에서 매 프레임 읽는 실데이터 테이블이 아니다) — `Inventory.sort_slots()`가
## 이미 같은 방식으로 참조하는 선례를 그대로 따른다(순수성 위반 아님, RNG/세이브 등
## 실제 상태를 갖는 오토로드를 참조하는 것과는 다른 층위).
class_name BlacksmithUiCalc
extends RefCounted

## D-90: +7부터는 확인 팝업 없이 "상시 경고 문구"만 노출한다. 이 상수는 그 문구를
## 강조 표시(예: 경고색)할지 판정하는 경계값으로만 쓴다 — 팝업 트리거가 아니다.
const HIGH_RISK_LEVEL := 7

## D-100: 분해 선택 목록에 이 등급(Data.ITEM_GRADES 인덱스) 이상이 하나라도 포함되면
## 확인 단계 1회를 띄운다. Data.ITEM_GRADES == ["common","uncommon","rare","epic",
## "legendary","relic"]이므로 인덱스 3 = "epic".
const EPIC_GRADE_INDEX := 3

## Y 홀드 파괴적 확정(분해 실행)의 기본 임계값(D-85: 비가역 확정=0.8초, 인벤토리의
## 가역 마킹 0.5초와 의도적으로 다르다).
const SALVAGE_HOLD_SEC := 0.8


## +n 목표 단계가 "실패 시 위험"(D-14: +7부터 성공률<100%) 구간인지.
static func is_high_risk_level(level: int) -> bool:
	return level >= HIGH_RISK_LEVEL


## 재련 잔여 횟수로 재련 가능 여부(경계값 3/2/1/0).
static func refine_available(refine_left: int) -> bool:
	return refine_left > 0


## 골드+아이템 비용을 감당할 수 있는지(강화/재련/제작 공용 — 미리보기 Dictionary의
## cost_gold/cost_items를 그대로 넘기면 된다). cost_items/have_items는 {item_id: qty}.
static func afford(cost_gold: int, cost_items: Dictionary, gold: int, have_items: Dictionary) -> bool:
	if gold < cost_gold:
		return false
	for item_id: String in cost_items:
		if int(have_items.get(item_id, 0)) < int(cost_items[item_id]):
			return false
	return true


## D-100 판정: 선택된 아이템 인스턴스 중 하나라도 epic 이상 등급이면 true.
static func salvage_has_epic_or_above(item_insts: Array) -> bool:
	for item_inst: Dictionary in item_insts:
		var idx: int = Data.ITEM_GRADES.find(String(item_inst.get("grade", "common")))
		if idx >= EPIC_GRADE_INDEX:
			return true
	return false


## 강화 탭 좌측 목록: 장비 카테고리 슬롯만, 등급 필터(""=전체) 적용. 인벤토리와
## 장착 슬롯을 합쳐 보여주고 싶을 때는 호출부가 두 소스를 하나의 slots 배열로 합쳐
## 넘기면 된다(현재 blacksmith_menu.gd는 인벤토리 슬롯만 우선 지원 — §8 남은 이슈).
static func filter_enhance_indices(slots: Array, items_table: Dictionary, grade_filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		if _is_gear(slots[i], items_table) and _grade_matches(slots[i], grade_filter):
			out.append(i)
	return out


## 재련 탭 좌측 목록: 장비 + 등급 필터 + affix_slot_count>0(재련할 옵션 줄이 있는
## 등급만, `enhance.json` 주석대로 common은 애초에 제외).
static func filter_refine_indices(slots: Array, items_table: Dictionary, grade_filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if not _is_gear(slot, items_table) or not _grade_matches(slot, grade_filter):
			continue
		var item_def: Dictionary = items_table.get(String(slot.get("item_id", "")), {})
		if int(item_def.get("affix_slot_count", 0)) <= 0:
			continue
		out.append(i)
	return out


## 분해 탭 좌측 목록: 장비 + 등급 필터 + 장착 중/잠금 자동 제외(F3-3c, D-88).
static func filter_salvage_indices(slots: Array, items_table: Dictionary, equipped_uids: Array,
		grade_filter: String) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if not _is_gear(slot, items_table) or not _grade_matches(slot, grade_filter):
			continue
		if bool(slot.get("locked", false)):
			continue
		if equipped_uids.has(String(slot.get("uid", ""))):
			continue
		out.append(i)
	return out


## 제작 탭 좌측 목록: 도면의 "결과물 등급"으로 필터한다(제작 탭은 결과물 등급=필터
## 기준, docs/ui/blacksmith.md §3 "제작 탭은 도면에 등급 필터 적용" 그대로).
## blueprint_ids는 "_"로 시작하는 _comment 키를 호출부가 이미 걸러 넘긴다는 전제.
static func filter_craft_indices(blueprint_ids: Array, blueprints_table: Dictionary,
		items_table: Dictionary, grade_filter: String) -> Array:
	var out: Array = []
	for bp_id: Variant in blueprint_ids:
		var bp: Dictionary = blueprints_table.get(String(bp_id), {})
		var result_def: Dictionary = items_table.get(String(bp.get("result_item_id", "")), {})
		var grade: String = String(result_def.get("grade", ""))
		if grade_filter != "" and grade != grade_filter:
			continue
		out.append(bp_id)
	return out


## Y 홀드 진행률(0~1, 분해 확정 게이지). `InventoryMenu._update_discard_hold()`와 동일한
## 계산을 상수만 다르게(0.8초) 공유한다(D-85).
static func hold_progress(hold_time_sec: float, threshold_sec: float = SALVAGE_HOLD_SEC) -> float:
	if threshold_sec <= 0.0:
		return 1.0
	return clampf(hold_time_sec / threshold_sec, 0.0, 1.0)


static func _is_gear(slot: Dictionary, items_table: Dictionary) -> bool:
	var item_def: Dictionary = items_table.get(String(slot.get("item_id", "")), {})
	return Data.EQUIP_CATEGORIES.has(String(item_def.get("category", "")))


static func _grade_matches(slot: Dictionary, grade_filter: String) -> bool:
	return grade_filter == "" or String(slot.get("grade", "")) == grade_filter
