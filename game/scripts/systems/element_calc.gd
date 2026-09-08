## 속성 상성 배율 계산 (D-08 순환형 상성, F2-4, GDD 4.2). Godot 노드에 의존하지 않는
## 순수 정적 함수라 GUT에서 elements.json 데이터를 직접 넣어 테스트할 수 있다.
class_name ElementCalc
extends RefCounted


## attacker_element / defender_element: "fire"/"wind"/"thunder"/"water"/"holy" 또는 무속성("").
## defender_tags: 피격자의 tags 배열(예: ["demon"]).
## elements_table: Data.table("elements") 형태의 Dictionary(cycle, advantage_multiplier,
## holy_element, holy_bonus_vs_tags 키 사용).
static func get_multiplier(attacker_element: String, defender_element: String,
		defender_tags: Array, elements_table: Dictionary) -> float:
	if attacker_element.is_empty():
		return 1.0
	var advantage: float = float(elements_table.get("advantage_multiplier", 1.0))
	var holy_element: String = String(elements_table.get("holy_element", "holy"))
	if attacker_element == holy_element:
		var holy_tags: Array = elements_table.get("holy_bonus_vs_tags", [])
		for tag: String in defender_tags:
			if holy_tags.has(tag):
				return advantage
		return 1.0
	var cycle: Array = elements_table.get("cycle", [])
	if cycle.is_empty():
		return 1.0
	var idx: int = cycle.find(attacker_element)
	if idx == -1:
		return 1.0
	var strong_against: String = cycle[(idx + 1) % cycle.size()]
	if defender_element == strong_against:
		return advantage
	return 1.0
