## HotbarRegisterInput(scripts/ui/hotbar_register_input.gd) 테스트(M4-2, D-181~D-183) —
## 액션 이름 <-> 슬롯 매핑, 등록된 슬롯 탐색. poll_pressed_slot()/try_assign()은 Input/
## InputMap 싱글턴(엔진 입력 상태)에 의존해 여기서 다루지 않는다(hud.gd의 _unhandled_input류와
## 같은 관례 — 실 입력 경로는 SmokeHotbarAssignUi가 확인).
extends GutTest


func test_slot_for_action_maps_one_based_name_to_zero_based_index() -> void:
	assert_eq(HotbarRegisterInput.slot_for_action(&"hotbar_1"), 0)
	assert_eq(HotbarRegisterInput.slot_for_action(&"hotbar_9"), 8)


func test_slot_for_action_unknown_name_is_negative_one() -> void:
	assert_eq(HotbarRegisterInput.slot_for_action(&"hotbar_10"), -1)
	assert_eq(HotbarRegisterInput.slot_for_action(&"skill_1"), -1)


func test_find_registered_slot_matches_kind_and_id() -> void:
	var hotbar := [
		{"kind": "item", "id": "potion_hp_small"},
		{"kind": "", "id": ""},
		{"kind": "skill", "id": "bolt_1"},
	]
	assert_eq(HotbarRegisterInput.find_registered_slot(hotbar, "skill", "bolt_1"), 2)
	assert_eq(HotbarRegisterInput.find_registered_slot(hotbar, "item", "potion_hp_small"), 0)


func test_find_registered_slot_not_found_is_negative_one() -> void:
	var hotbar := [{"kind": "item", "id": "potion_hp_small"}]
	assert_eq(HotbarRegisterInput.find_registered_slot(hotbar, "skill", "bolt_1"), -1)


func test_find_registered_slot_empty_id_is_negative_one() -> void:
	assert_eq(HotbarRegisterInput.find_registered_slot([{"kind": "item", "id": "x"}], "item", ""), -1)


func test_find_registered_slot_ignores_non_dictionary_entries() -> void:
	assert_eq(HotbarRegisterInput.find_registered_slot(["", null], "item", "x"), -1)
