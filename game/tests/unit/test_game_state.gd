## GameState(scripts/core/game_state.gd) 비석 기록/부활 위치 테스트(F8-2, D-28).
## 자동로드 싱글턴 대신 새 인스턴스를 만들어 테스트 간 상태를 격리한다(test_data.gd와
## 동일한 패턴).
extends GutTest

const GameStateScript := preload("res://scripts/core/game_state.gd")


func _make_game_state() -> Node:
	var gs := GameStateScript.new()
	add_child_autofree(gs)
	return gs


func test_respawn_position_defaults_to_origin_without_waystone() -> void:
	var gs := _make_game_state()
	assert_eq(gs.get_respawn_position(), Vector2.ZERO)
	assert_null(gs.last_waystone)


func test_set_last_waystone_records_it_and_updates_respawn_position() -> void:
	var gs := _make_game_state()
	var stone := Node2D.new()
	stone.global_position = Vector2(123.0, -45.0)
	add_child_autofree(stone)

	gs.set_last_waystone(stone)

	assert_eq(gs.last_waystone, stone, "마지막 상호작용 비석이 기록되어야 한다(D-28)")
	assert_eq(gs.get_respawn_position(), Vector2(123.0, -45.0))


func test_interacting_with_a_later_waystone_overwrites_the_previous_one() -> void:
	var gs := _make_game_state()
	var stone_a := Node2D.new()
	stone_a.global_position = Vector2(10.0, 10.0)
	add_child_autofree(stone_a)
	var stone_b := Node2D.new()
	stone_b.global_position = Vector2(999.0, -999.0)
	add_child_autofree(stone_b)

	gs.set_last_waystone(stone_a)
	gs.set_last_waystone(stone_b)

	assert_eq(gs.get_respawn_position(), Vector2(999.0, -999.0), "가장 최근 활성화한 비석 기준이어야 한다")


func test_death_count_increments_on_player_died_event() -> void:
	var gs := _make_game_state()
	assert_eq(gs.death_count, 0)
	Events.player_died.emit()
	assert_eq(gs.death_count, 1)


func test_waystone_scene_activate_records_game_state() -> void:
	# 실제 자동로드 싱글턴(GameState)을 대상으로 씬 레벨 동작(Waystone.activate())을
	# 확인한다 — waystone.gd는 전역 이름 GameState를 직접 참조하기 때문.
	var scene: PackedScene = load("res://scenes/world/Waystone.tscn")
	var stone := scene.instantiate() as Waystone
	stone.global_position = Vector2(7.0, 8.0)
	add_child_autofree(stone)

	stone.activate()

	assert_true(stone.is_active)
	assert_eq(GameState.last_waystone, stone)
	assert_eq(GameState.get_respawn_position(), Vector2(7.0, 8.0))
