## 장비 8슬롯 순수 로직(F3-2, D-12). Godot 노드에 의존하지 않는 RefCounted — GameState
## (오토로드)가 인스턴스 하나를 들고 있고, 장착/해제 뒤 실제 player.resources 반영은
## GameState가 담당한다(이 클래스는 슬롯 상태와 스탯 합산만 안다).
##
## 슬롯 8개: 무기/보조/투구/갑옷/신발/반지×2/부적(GDD 6.2). 반지는 물리적으로 2슬롯이지만
## items.json category는 "ring" 하나를 공유한다 — ring1/ring2 모두 category=="ring"만
## 받아들이므로 D-12(동일 반지 2개 중복 장착)는 "막을 이유가 없어서 그냥 되는" 자연스러운
## 결과다(각 슬롯이 독립적이라 중복 검사 자체를 하지 않음).
class_name Equipment
extends RefCounted

const SLOT_NAMES: Array[String] = ["weapon", "sub", "head", "armor", "boots", "ring1", "ring2", "amulet"]

const SLOT_CATEGORY := {
	"weapon": "weapon", "sub": "sub", "head": "head", "armor": "armor", "boots": "boots",
	"ring1": "ring", "ring2": "ring", "amulet": "amulet",
}

## slot_name -> ItemInstance Dictionary(비어있으면 {}).
var slots: Dictionary = {}


func _init() -> void:
	for slot_name: String in SLOT_NAMES:
		slots[slot_name] = {}


func is_valid_slot(slot_name: String) -> bool:
	return SLOT_CATEGORY.has(slot_name)


## item_def.category가 slot_name이 받는 카테고리와 맞는지. STR 요구치(items.json.
## str_requirement, "무거운 무기는 STR 요구치 필요" F3-2 규칙)는 stats.json/캐릭터 STR
## 스탯이 아직 없어 검사하지 않는다 — 훅만 남긴다(엔지니어 TODO: stats 시스템 확정 시
## `player_str < int(item_def.get("str_requirement", 0))`이면 false를 반환하도록 이
## 함수에 조건 한 줄만 추가하면 된다).
func can_equip(slot_name: String, item_def: Dictionary) -> bool:
	if not is_valid_slot(slot_name):
		return false
	return String(item_def.get("category", "")) == SLOT_CATEGORY[slot_name]


func is_equipped(slot_name: String) -> bool:
	return not (slots.get(slot_name, {}) as Dictionary).is_empty()


## 장착한다. 반환: 그 슬롯에 이미 있던 아이템(없었으면 {}) — 호출부(GameState)가 인벤토리로
## 돌려놓는다. can_equip()이 false면 아무것도 바꾸지 않고 {"__error__": "category_mismatch"}를
## 반환한다(호출부는 반환값에 "__error__" 키가 있는지로 실패를 구분).
func equip(slot_name: String, item_instance: Dictionary, item_def: Dictionary) -> Dictionary:
	if not can_equip(slot_name, item_def):
		return {"__error__": "category_mismatch"}
	var previous: Dictionary = slots.get(slot_name, {})
	slots[slot_name] = item_instance
	return previous


func unequip(slot_name: String) -> Dictionary:
	if not is_valid_slot(slot_name):
		return {}
	var previous: Dictionary = slots.get(slot_name, {})
	slots[slot_name] = {}
	return previous


## 장착 중인 아이템 전체로 스탯을 재계산한다(F3-2 "장착 즉시 스탯 재계산"). 순수 static
## 함수라 GUT에서 items_table/enhance_table을 직접 만들어 테스트할 수 있다.
##
## 계산 순서(§2-1/§3 근거):
##  1) 카테고리별 base_stats에서 공격/방어 "본체 수치"를 뽑는다 — weapon.atk_(min+max)/2,
##     sub/head/armor/boots.defense_(min+max)/2. 링/부적의 base_stats(STR 등 속성치,
##     원소 데미지%)는 stats.json/원소 시스템 확장 전이라 이 집계엔 포함하지 않는다
##     (스탯 시스템 확정 시 이 함수만 확장하면 됨 — attack/defense/max_hp/speed 4종은
##     지시받은 범위 그대로).
##  2) enhance_level이 있으면 enhance.json.enhance_levels["+N"].stat_multiplier를
##     그 아이템의 본체 수치에만 곱한다(다른 아이템에는 영향 없음).
##  3) 옵션(affixes)을 stat_type별로 전부 합산: atk_pct(공격 % 가산), defense_flat(방어
##     플랫 가산), max_hp_flat(최대 HP 가산), move_speed_pct(이동속도 % 가산).
##  4) 최종 attack = Σ무기본체 × (1 + Σatk_pct). defense = Σ방어구본체 + Σdefense_flat.
##     max_hp = Σmax_hp_flat(반올림). speed_pct = Σmove_speed_pct.
##
## 방어력을 실제 피해 감소로 환산하는 공식은 아직 결정되지 않았다(docs/specs/
## items-and-drops-m2.md 결정 요청 A, `_balance_todo` — 여기서는 defense "수치"만
## 합산해 반환하고, 그 수치를 데미지 계산에 어떻게 쓸지는 전투 시스템 쪽 결정 사항이다).
static func compute_stats(equipped: Dictionary, items_table: Dictionary, enhance_table: Dictionary) -> Dictionary:
	var attack_flat := 0.0
	var atk_pct_sum := 0.0
	var defense := 0.0
	var max_hp := 0.0
	var speed_pct := 0.0

	for slot_name: String in equipped:
		var item: Dictionary = equipped[slot_name]
		if item.is_empty():
			continue
		var item_def: Dictionary = items_table.get(String(item.get("item_id", "")), {})
		if item_def.is_empty():
			continue
		var category: String = String(item_def.get("category", ""))
		var base_stats: Dictionary = item_def.get("base_stats", {})
		var enhance_mult: float = enhance_multiplier(int(item.get("enhance_level", 0)), enhance_table)

		match category:
			"weapon":
				var atk_min: float = float(base_stats.get("atk_min", 0.0))
				var atk_max: float = float(base_stats.get("atk_max", 0.0))
				attack_flat += (atk_min + atk_max) * 0.5 * enhance_mult
			"sub", "head", "armor", "boots":
				var def_min: float = float(base_stats.get("defense_min", 0.0))
				var def_max: float = float(base_stats.get("defense_max", 0.0))
				defense += (def_min + def_max) * 0.5 * enhance_mult
			_:
				pass # ring/amulet 본체 수치(STR 등)는 stats.json 확정 전까지 훅 없음.

		for affix: Dictionary in (item.get("affixes", []) as Array):
			var stat_type: String = String(affix.get("stat_type", ""))
			var value: float = float(affix.get("value", 0.0))
			match stat_type:
				"atk_pct":
					atk_pct_sum += value
				"defense_flat":
					defense += value
				"max_hp_flat":
					max_hp += value
				"move_speed_pct":
					speed_pct += value

	return {
		"attack": attack_flat * (1.0 + atk_pct_sum),
		"defense": defense,
		"max_hp": int(round(max_hp)),
		"speed_pct": speed_pct,
	}


## 강화 단계별 스탯 배율(enhance.json.enhance_levels["+N"].stat_multiplier). 공개 함수 —
## Equipment.compute_stats()뿐 아니라 InventoryUiCalc(비교 툴팁)·Blacksmith(강화 미리보기,
## M2-4)가 전부 이 함수 하나만 쓴다(디렉터 결정 D-85: 중복 정의 금지, 한 곳에만 둔다).
static func enhance_multiplier(enhance_level: int, enhance_table: Dictionary) -> float:
	if enhance_level <= 0:
		return 1.0
	var levels: Dictionary = enhance_table.get("enhance_levels", {})
	var key := "+%d" % enhance_level
	return float((levels.get(key, {}) as Dictionary).get("stat_multiplier", 1.0))


func to_dict() -> Dictionary:
	return slots.duplicate(true)


func from_dict(data: Dictionary) -> void:
	for slot_name: String in SLOT_NAMES:
		slots[slot_name] = (data.get(slot_name, {}) as Dictionary).duplicate(true)
