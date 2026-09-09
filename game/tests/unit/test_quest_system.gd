## QuestSystem(scripts/systems/quest_system.gd) 테스트(F5-1·F5-2, M2-7).
##
## 자동로드 싱글턴 대신 새 인스턴스를 만들어 테스트 간 상태를 격리한다(test_game_state.gd/
## test_data.gd와 동일 패턴) — 단, 보상 지급은 실제 GameState 오토로드 싱글턴(gold/
## inventory/mailbox)을 그대로 건드리므로 test_save_manager.gd처럼 매 테스트 전후로
## 스냅샷/복원한다. 실제 게임 데이터(game/data/quests/act1_hartland.json)를 그대로
## 사용해 선행 조건 체인을 검증한다.
extends GutTest

const QuestSystemScript := preload("res://scripts/systems/quest_system.gd")

var _saved_gold: int
var _saved_inventory_slots: Array
var _saved_mailbox_mails: Array


func before_each() -> void:
	_saved_gold = GameState.gold
	_saved_inventory_slots = GameState.inventory.slots.duplicate(true)
	_saved_mailbox_mails = GameState.mailbox.mails.duplicate(true)
	GameState.gold = 0
	GameState.inventory.slots.clear()
	GameState.mailbox = Mailbox.new()


func after_each() -> void:
	GameState.gold = _saved_gold
	GameState.inventory.slots = _saved_inventory_slots
	GameState.mailbox.mails = _saved_mailbox_mails


func _make_qs() -> Node:
	var qs := QuestSystemScript.new()
	add_child_autofree(qs)
	return qs


# --- 선행 조건 잠금 ---

func test_unknown_quest_is_locked() -> void:
	var qs := _make_qs()
	assert_eq(qs.get_state("no_such_quest"), "locked")


func test_side_quest_locked_until_prerequisite_completed() -> void:
	var qs := _make_qs()
	assert_eq(qs.get_state("quest_side_heartland_waypoint"), "locked",
		"prerequisites.quests_completed(quest_main_a1_05_reclaim)를 만족 못 했으면 locked")

	qs._completed.append("quest_main_a1_05_reclaim")

	assert_eq(qs.get_state("quest_side_heartland_waypoint"), "available")
	var accept_result: Dictionary = qs.accept("quest_side_heartland_waypoint")
	assert_true(accept_result["ok"])
	assert_eq(qs.get_state("quest_side_heartland_waypoint"), "active")


func test_accept_before_prerequisites_met_is_rejected() -> void:
	var qs := _make_qs()
	var result: Dictionary = qs.accept("quest_side_heartland_waypoint")
	assert_false(result["ok"])
	assert_eq(result["reason"], "not_available")
	assert_eq(result["state"], "locked")


# --- 수락 -> kill 진행 -> 완료 -> 보상 ---

func test_accept_kill_progress_complete_and_rewards() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_01_arrival")
	qs._completed.append("quest_main_a1_02_firstlook")

	var accept_result: Dictionary = qs.accept("quest_main_a1_03_shadowfall")
	assert_true(accept_result["ok"])
	assert_eq(qs.get_state("quest_main_a1_03_shadowfall"), "active")

	for i in 3:
		Events.monster_died.emit(&"horn_rabbit")
		assert_eq(qs.get_state("quest_main_a1_03_shadowfall"), "active",
			"%d/4 마리 처치 - 아직 완료 전이어야 함" % (i + 1))

	Events.monster_died.emit(&"horn_rabbit") # 4번째 처치.

	# giver="system"이라 마지막 목표 완료 즉시 advance()가 자동 호출된다.
	assert_eq(qs.get_state("quest_main_a1_03_shadowfall"), "completed")
	assert_true(qs._completed.has("quest_main_a1_03_shadowfall"))
	assert_eq(GameState.gold, 10, "quest_main_a1_03_shadowfall rewards.gold=10")
	assert_eq(qs.total_exp_earned, 15, "rewards.exp=15 placeholder 누적")


func test_kill_progress_ignores_other_monster_ids() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_01_arrival")
	qs._completed.append("quest_main_a1_02_firstlook")
	qs.accept("quest_main_a1_03_shadowfall")

	Events.monster_died.emit(&"mushroom") # 목표 대상이 아님 - 무시돼야 함.

	assert_eq(qs.get_state("quest_main_a1_03_shadowfall"), "active")


# --- 메인 퀘스트 포기 거부 ---

func test_abandon_main_quest_is_refused() -> void:
	var qs := _make_qs()
	var accept_result: Dictionary = qs.accept("quest_main_a1_01_arrival")
	assert_true(accept_result["ok"])

	var abandon_result: Dictionary = qs.abandon("quest_main_a1_01_arrival")

	assert_false(abandon_result["ok"])
	assert_eq(abandon_result["reason"], "main_quest_cannot_abandon")
	assert_eq(qs.get_state("quest_main_a1_01_arrival"), "active", "포기가 거부됐으니 그대로 active여야 함")


func test_abandon_side_quest_succeeds() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_05_reclaim")
	qs.accept("quest_side_heartland_waypoint")

	var result: Dictionary = qs.abandon("quest_side_heartland_waypoint")

	assert_true(result["ok"])
	assert_eq(qs.get_state("quest_side_heartland_waypoint"), "available", "포기하면 다시 available")


# --- 인벤토리 가득 시 우편함(D-10, Inventory.add_or_mail) ---

func test_reward_item_goes_to_mailbox_when_inventory_full() -> void:
	var qs := _make_qs()
	for i in GameState.inventory.capacity():
		GameState.inventory.add_item(
			{"uid": "u_%d" % i, "item_id": "iron_ore", "quantity": 99},
			Data.get_value("items", "iron_ore", {}))
	assert_true(GameState.inventory.is_full())
	assert_eq(GameState.mailbox.size(), 0)

	for qid in ["quest_main_a1_01_arrival", "quest_main_a1_02_firstlook", "quest_main_a1_03_shadowfall",
			"quest_main_a1_04_theshard"]:
		qs._completed.append(qid)
	qs.accept("quest_main_a1_05_reclaim") # rewards.items = [{id: wool_soft, qty: 2}].

	Events.monster_died.emit(&"horn_rabbit_big")
	Events.location_reached.emit(&"heartland_dandelion_village_square")

	assert_eq(qs.get_state("quest_main_a1_05_reclaim"), "completed", "giver=system이라 자동 완결돼야 함")
	assert_eq(GameState.mailbox.size(), 1, "인벤토리가 가득 차 보상 아이템이 우편함으로 가야 함(D-10)")
	assert_eq(String((GameState.mailbox.mails[0] as Dictionary).get("item_id", "")), "wool_soft")


# --- 게시판 일일 의뢰(F5-2, D-97) ---

func test_daily_templates_are_exactly_three() -> void:
	var qs := _make_qs()
	var ids: Array[String] = qs.get_daily_quest_ids()
	assert_eq(ids.size(), 3, "act1_hartland.json daily_template 3종")
	for id in ids:
		assert_true(String(id).begins_with("quest_daily_heartland_"))


func test_daily_roll_is_reproducible_for_same_day_and_quest() -> void:
	var qs := _make_qs()
	var day := 42
	var first: Dictionary = qs.roll_daily_target("quest_daily_heartland_01", day)
	var second: Dictionary = qs.roll_daily_target("quest_daily_heartland_01", day)

	assert_eq(first, second, "같은 (day_index, quest_id)는 항상 같은 추첨 결과여야 한다(시드 재현성)")
	assert_true(["horn_rabbit", "mushroom"].has(String(first.get("target_id", ""))),
		"heartland_field_low 풀 구성원 중 하나여야 함")
	assert_between(int(first.get("count", 0)), 3, 5, "count_range=[3,5]")


func test_daily_roll_item_pool_picks_valid_member() -> void:
	var qs := _make_qs()
	var picked: Dictionary = qs.roll_daily_target("quest_daily_heartland_02", 7)
	assert_true(["mushroom_cap", "iron_ore", "rabbit_horn"].has(String(picked.get("target_id", ""))),
		"heartland_field_material_low 풀 구성원 중 하나여야 함")


func test_daily_quest_completes_via_pool_target_and_resets_next_day() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_05_reclaim") # 게시판 daily는 전부 이 선행 조건.
	var day := 100
	var picked: Dictionary = qs.roll_daily_target("quest_daily_heartland_01", day)

	# GameState.day_index를 고정해 결정적으로 만든다(원복은 after_each가 아니라 여기서
	# 직접 — day_index는 GameState의 실제 필드라 다른 테스트에 영향 주지 않도록 복원).
	var saved_day: int = GameState.day_index
	GameState.day_index = day

	qs.accept("quest_daily_heartland_01")
	for i in int(picked.get("count", 0)):
		Events.monster_died.emit(StringName(picked.get("target_id", "")))

	# giver="rozel"(NPC)이라 자동 완결되지 않고 턴인 대기 상태여야 한다.
	assert_eq(qs.get_state("quest_daily_heartland_01"), "complete_ready")
	var advance_result: Dictionary = qs.advance("quest_daily_heartland_01")
	assert_true(advance_result["ok"])
	assert_eq(qs.get_state("quest_daily_heartland_01"), "completed", "오늘은 이미 수행함")

	GameState.day_index = day + 1 # 하루가 지나면 다시 수주 가능해야 한다(repeatable).
	assert_eq(qs.get_state("quest_daily_heartland_01"), "available")

	GameState.day_index = saved_day


# --- 분기(D-94 converges) ---

func test_branch_choice_sets_outcome_flag() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_06_echocave")
	qs.accept("quest_side_heartland_montsil")

	Events.npc_talked.emit(&"dami")
	Events.location_reached.emit(&"heartland_pasture_boundary")
	Events.object_interacted.emit(&"montsil_rabbit")

	assert_eq(qs.get_state("quest_side_heartland_montsil"), "complete_ready", "giver=dami(NPC)라 자동 완결되지 않음")

	var result: Dictionary = qs.choose_branch("quest_side_heartland_montsil", "capture_attempt")
	assert_true(result["ok"])
	assert_true(qs.has_story_flag("montsil_capture_tried"))

	var advance_result: Dictionary = qs.advance("quest_side_heartland_montsil")
	assert_true(advance_result["ok"])
	assert_eq(qs.get_state("quest_side_heartland_montsil"), "completed")


func test_branch_defaults_to_first_choice_when_unresolved() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_06_echocave")
	qs.accept("quest_side_heartland_montsil")
	Events.npc_talked.emit(&"dami")
	Events.location_reached.emit(&"heartland_pasture_boundary")
	Events.object_interacted.emit(&"montsil_rabbit")

	qs.advance("quest_side_heartland_montsil") # choose_branch() 호출 없이 바로 턴인.

	assert_true(qs.has_story_flag("montsil_released"), "branch.choices[0]=release가 기본값이어야 함")


# --- 세이브 라운드트립(개별 클래스 단위 — SmokeSaveLoad는 실제 파이프라인 전체를 본다) ---

func test_to_dict_from_dict_round_trip() -> void:
	var qs := _make_qs()
	qs._completed.append("quest_main_a1_05_reclaim")
	qs.accept("quest_side_heartland_waypoint")
	Events.location_reached.emit(&"heartland_hilltop_waypoint")

	var dict: Dictionary = qs.to_dict()
	var restored := QuestSystemScript.new()
	add_child_autofree(restored)
	restored.from_dict(dict)

	assert_eq(restored.get_state("quest_side_heartland_waypoint"), "active")
	assert_eq(restored.get_active_objective_index("quest_side_heartland_waypoint"), 1,
		"reach 목표까지 진행된 상태가 복원돼야 함")
	assert_true(restored._completed.has("quest_main_a1_05_reclaim"))
