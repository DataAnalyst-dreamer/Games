## EliteSpawner(M2-3, F6-3/D-15) 리스폰 타이머 테스트. 실제 벽시계로 30분을 기다리는
## 대신 GameState.play_time_sec 누적기를 큰 delta로 직접 밀어 넣어(GameState._process()
## 호출 — 다른 테스트들이 _physics_process()를 직접 부르는 것과 같은 관례) "30분 경과"를
## 흉내낸다. GameState는 오토로드 싱글턴이라 테스트 간 오염을 막기 위해 관련 필드를
## before_each/after_each에서 저장·복원한다(waystone 테스트가 같은 싱글턴을 다루는
## test_game_state.gd와 동일한 우려 — 거기서도 실제 GameState를 직접 씀).
extends GutTest

const EliteSpawnerScript := preload("res://scripts/systems/elite_spawner.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")

var _saved_remaining: Dictionary
var _saved_play_time: float


func before_each() -> void:
	_saved_remaining = GameState.elite_respawn_remaining_sec.duplicate(true)
	_saved_play_time = GameState.play_time_sec
	GameState.elite_respawn_remaining_sec.clear()
	GameState.play_time_sec = 0.0


func after_each() -> void:
	GameState.elite_respawn_remaining_sec = _saved_remaining
	GameState.play_time_sec = _saved_play_time


func _make_spawner() -> EliteSpawner:
	var sp: EliteSpawner = EliteSpawnerScript.new()
	add_child_autofree(sp)
	return sp


func test_spawns_both_elites_immediately_when_no_cooldown_recorded() -> void:
	var sp := _make_spawner()
	assert_true(is_instance_valid(sp._instances.get("elite_goblin_captain")),
		"쿨다운 기록이 없으면(첫 진입) 즉시 스폰되어야 한다")
	assert_true(is_instance_valid(sp._instances.get("elite_bunchi_spawn")))


func test_kill_starts_respawn_countdown_from_farming_sources_respawn_seconds() -> void:
	var sp := _make_spawner()
	var captain: MonsterBase = sp._instances["elite_goblin_captain"]

	Events.enemy_died.emit(captain, null)

	var remaining: float = float(GameState.elite_respawn_remaining_sec.get("elite_goblin_captain", 0.0))
	assert_almost_eq(remaining, 1800.0, 0.01, "farming_sources.json.elite_goblin_captain.respawn_seconds(30분)")
	assert_null(sp._instances["elite_goblin_captain"], "죽은 인스턴스는 추적 목록에서 비워야 한다")
	captain.queue_free()


func test_does_not_respawn_before_timer_elapses() -> void:
	var sp := _make_spawner()
	var captain: MonsterBase = sp._instances["elite_goblin_captain"]
	Events.enemy_died.emit(captain, null)
	captain.queue_free()
	await get_tree().process_frame

	sp.check_respawns()

	assert_null(sp._instances["elite_goblin_captain"], "리스폰 타이머가 남아 있으면 재스폰하지 않는다")


func test_respawns_after_play_time_exhausts_the_timer() -> void:
	var sp := _make_spawner()
	var captain: MonsterBase = sp._instances["elite_goblin_captain"]
	Events.enemy_died.emit(captain, null)
	captain.queue_free()
	await get_tree().process_frame

	GameState._process(1800.5) # 실제 플레이 시간 30분 경과를 흉내(D-15).
	sp.check_respawns()

	assert_true(is_instance_valid(sp._instances.get("elite_goblin_captain")),
		"리스폰 타이머(1800초) 소진 후에는 같은 고정 스폰 지점에 다시 스폰되어야 한다")


func test_respawn_position_matches_hartland_fixed_spawn_point() -> void:
	var sp := _make_spawner()
	var captain: MonsterBase = sp._instances["elite_goblin_captain"]
	var expected: Vector2 = EliteSpawnerScript.SPAWN_POS_GLOBAL_TILE["elite_goblin_captain"] \
		* float(Tuning.TILE_SIZE_PROTOTYPE)
	assert_eq(captain.global_position, expected, "hartland.md ⑤ 고정 스폰 지점(임시 상수)이어야 한다")


func test_game_state_serializes_play_time_and_elite_respawn_timers() -> void:
	GameState.play_time_sec = 1234.5
	GameState.elite_respawn_remaining_sec = {"elite_goblin_captain": 900.0}

	var saved: Dictionary = GameState.to_dict()

	var gs2 := GameStateScript.new()
	add_child_autofree(gs2)
	gs2.from_dict(saved)

	assert_almost_eq(gs2.play_time_sec, 1234.5, 0.001, "play_time_sec이 세이브/로드에 보존되어야 한다")
	assert_almost_eq(float(gs2.elite_respawn_remaining_sec.get("elite_goblin_captain", 0.0)), 900.0, 0.001,
		"정예 리스폰 카운트다운도 세이브/로드에 보존되어야 한다")


func test_game_state_process_decrements_elite_timers_by_delta() -> void:
	GameState.elite_respawn_remaining_sec = {"elite_bunchi_spawn": 100.0}
	GameState._process(40.0)
	assert_almost_eq(float(GameState.elite_respawn_remaining_sec.get("elite_bunchi_spawn")), 60.0, 0.001)


func test_game_state_process_clamps_elite_timer_at_zero() -> void:
	GameState.elite_respawn_remaining_sec = {"elite_bunchi_spawn": 10.0}
	GameState._process(999.0)
	assert_eq(float(GameState.elite_respawn_remaining_sec.get("elite_bunchi_spawn")), 0.0,
		"음수로 내려가지 않고 0에서 멈춰야 한다")
