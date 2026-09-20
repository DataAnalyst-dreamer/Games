## GUT: Progression.assign_hotbar/clear_hotbar + 세이브 마이그레이션(M4-1, D-175~D-177).
## Progression은 오토로드 싱글턴 GameState를 직접 참조하므로(주입 불가, progression_service.gd
## 참고) 이 테스트도 실제 싱글턴을 조작한다 — before_each/after_each로 건드린 필드를
## 스냅샷·복원해 다른 테스트를 오염시키지 않는다.
## 실행: godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
extends GutTest

const REAL_SKILL_ID := "blade_power_slash"

var _snapshot: Dictionary


func _empty_hotbar() -> Array:
	var hotbar: Array = []
	for i in 9:
		hotbar.append({"kind": "", "id": ""})
	return hotbar


func before_each() -> void:
	_snapshot = {
		"hotbar": GameState.hotbar.duplicate(true),
		"skill_slots": GameState.skill_slots.duplicate(),
		"learned_skills": GameState.learned_skills.duplicate(),
	}
	GameState.hotbar = _empty_hotbar()
	GameState.skill_slots = ["", "", "", "", "", "", "", "", ""]
	GameState.learned_skills = {REAL_SKILL_ID: 1} # M4-4(D-170): id -> 레벨


func after_each() -> void:
	GameState.hotbar = _snapshot["hotbar"]
	GameState.skill_slots = _snapshot["skill_slots"]
	GameState.learned_skills = _snapshot["learned_skills"]


func test_assign_hotbar_skill_requires_learned() -> void:
	assert_false(Progression.assign_hotbar(0, "skill", "not_learned_id"), "안 배운 스킬은 배정 실패")
	assert_true(Progression.assign_hotbar(0, "skill", REAL_SKILL_ID), "배운 스킬은 배정 성공")
	assert_eq(GameState.hotbar[0], {"kind": "skill", "id": REAL_SKILL_ID})
	assert_eq(GameState.skill_slots[0], REAL_SKILL_ID, "skill_slots도 동기화돼야 시전/쿨타임이 동작")


## D-175: 같은 스킬을 여러 슬롯에 중복 배정해도 막지 않는다.
func test_assign_hotbar_allows_duplicate_skill_slots() -> void:
	assert_true(Progression.assign_hotbar(0, "skill", REAL_SKILL_ID))
	assert_true(Progression.assign_hotbar(5, "skill", REAL_SKILL_ID))
	assert_eq(GameState.skill_slots[0], REAL_SKILL_ID)
	assert_eq(GameState.skill_slots[5], REAL_SKILL_ID)


func test_assign_hotbar_item_requires_non_empty_id_and_clears_skill_slot() -> void:
	assert_false(Progression.assign_hotbar(2, "item", ""), "빈 id는 실패")
	assert_false(Progression.assign_hotbar(2, "item", "weapon_common_1"), "소비품이 아니면 실패(장비·재료)")
	Progression.assign_hotbar(2, "skill", REAL_SKILL_ID)
	assert_true(Progression.assign_hotbar(2, "item", "potion_hp_small"))
	assert_eq(GameState.hotbar[2], {"kind": "item", "id": "potion_hp_small"})
	assert_eq(GameState.skill_slots[2], "", "아이템으로 바뀌면 이전 스킬 슬롯은 해제된다")


func test_assign_hotbar_rejects_out_of_range_and_bad_kind() -> void:
	assert_false(Progression.assign_hotbar(-1, "skill", REAL_SKILL_ID))
	assert_false(Progression.assign_hotbar(9, "skill", REAL_SKILL_ID))
	assert_false(Progression.assign_hotbar(0, "buff", "whatever"), "kind가 skill/item이 아니면 실패")


func test_clear_hotbar_resets_slot_and_skill_slots() -> void:
	Progression.assign_hotbar(4, "skill", REAL_SKILL_ID)
	Progression.clear_hotbar(4)
	assert_eq(GameState.hotbar[4], {"kind": "", "id": ""})
	assert_eq(GameState.skill_slots[4], "")


func test_hotbar_changed_emitted_on_assign_and_clear() -> void:
	var events: Array = []
	var cb := func(hotbar: Array) -> void: events.append(hotbar.duplicate(true))
	Events.hotbar_changed.connect(cb)
	Progression.assign_hotbar(1, "skill", REAL_SKILL_ID)
	Progression.clear_hotbar(1)
	Events.hotbar_changed.disconnect(cb)
	assert_eq(events.size(), 2, "assign 1회 + clear 1회")


## 옛 세이브(2칸 skill_slots, hotbar 없음 -> GameState.from_dict()가 빈 배열로 남김)를
## 로드하면 Progression._on_load_completed()가 9칸 hotbar로 승격해야 한다.
func test_load_completed_migrates_old_two_slot_save_to_hotbar() -> void:
	GameState.hotbar = []
	GameState.skill_slots = [REAL_SKILL_ID, "", "", "", "", "", "", "", ""]
	var events: Array = []
	var cb := func(hotbar: Array) -> void: events.append(hotbar.duplicate(true))
	Events.hotbar_changed.connect(cb)
	Events.load_completed.emit(0, &"manual", true)
	Events.hotbar_changed.disconnect(cb)
	assert_eq(GameState.hotbar.size(), 9)
	assert_eq(GameState.hotbar[0], {"kind": "skill", "id": REAL_SKILL_ID}, "옛 skill_slots[0]이 핫바로 승격")
	assert_eq(GameState.hotbar[1], {"kind": "", "id": ""})
	assert_true(events.size() >= 1, "마이그레이션 시 hotbar_changed 발신")


## 신규 세이브(hotbar 이미 9칸)는 skill_slots와 어긋나 있어도 덮어쓰지 않는다.
func test_load_completed_skips_migration_when_hotbar_already_populated() -> void:
	GameState.hotbar[0] = {"kind": "item", "id": "potion_hp_small"}
	GameState.skill_slots[0] = ""
	Events.load_completed.emit(0, &"manual", true)
	assert_eq(GameState.hotbar[0], {"kind": "item", "id": "potion_hp_small"},
		"이미 채워진 hotbar는 마이그레이션 대상이 아니다")
