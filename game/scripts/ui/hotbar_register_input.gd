## 핫바(9칸) 등록 입력 헬퍼(M4-2, D-181~D-183). skill_panel_tab.gd/inventory_menu.gd가
## 공통으로 쓴다 — "포커스 항목 위에서 1~9를 누르면 그 슬롯에 등록"(RO식) 흐름 전부를
## 여기 한 파일로 격리해 두 500줄 근접 파일의 diff를 최소화한다.
##
## D-182: hotbar_1~9 입력 액션은 stage/m4-1(로직)이 project.godot에 소유한다 — 이
## 브랜치는 project.godot을 건드리지 않고 액션 "이름"만 문자열로 참조한다. 액션이 아직
## 없으면(m4-1 미병합) InputMap.has_action 가드로 조용히 아무 것도 하지 않는다.
## GameState.hotbar/Progression.assign_hotbar도 같은 이유로 has_method/get() 가드를
## 쓴다(skill_panel_tab.gd의 GameState.get("skill_slots") 관례와 동일).
class_name HotbarRegisterInput
extends RefCounted

const ACTION_NAMES: Array[StringName] = [
	&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5",
	&"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9",
]


## 순수 함수: 액션 이름 -> 0based 슬롯(hotbar_N -> N-1). 매칭 안 되면 -1. GUT 테스트 대상.
static func slot_for_action(action_name: StringName) -> int:
	return ACTION_NAMES.find(action_name)


## 현재 GameState.hotbar에서 kind+id가 이미 등록된 슬롯(0based), 없으면 -1. 순수 함수
## (hotbar 배열을 인자로 받는다 — GUT 테스트 대상).
static func find_registered_slot(hotbar: Array, kind: String, id: String) -> int:
	if id.is_empty():
		return -1
	for i in hotbar.size():
		var entry: Variant = hotbar[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = entry
		if String(e.get("kind", "")) == kind and String(e.get("id", "")) == id:
			return i
	return -1


## 이번 프레임에 막 눌린 hotbar_N 액션이 있으면 그 슬롯, 없으면 -1. InputMap에
## 액션이 없으면(D-182) 절대 조회하지 않는다.
static func poll_pressed_slot() -> int:
	for action_name in ACTION_NAMES:
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			return slot_for_action(action_name)
	return -1


## 포커스 항목(kind: "skill"|"item", id)을 방금 눌린 슬롯에 등록. 등록에 성공하면
## true(호출부가 미리보기를 새로고침해야 함). Progression.assign_hotbar는 stage/m4-1
## (로직, 미병합) 소유라 has_method 가드로 호출한다.
static func try_assign(kind: String, id: String) -> bool:
	if id.is_empty():
		return false
	var slot := poll_pressed_slot()
	if slot < 0:
		return false
	return Progression.assign_hotbar(slot, kind, id)
