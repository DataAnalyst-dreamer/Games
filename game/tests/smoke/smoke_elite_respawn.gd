## 헤드리스 스모크 테스트: "정예 처치 → 30분(실제 플레이 시간) 후 같은 지점에 재스폰".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeEliteRespawn.tscn --quit-after 200
##
## Main.tscn(정예 2종이 이미 고정 배치돼 있음, M2-3 §6)과는 별개로 EliteSpawner 단독
## 씬으로 검증한다 — 둘을 같이 쓰면 같은 정예가 중복 스폰된다(elite_spawner.gd 주석
## 참고). 실제로 30분을 기다리는 대신 GameState._process()를 큰 delta로 한 번 호출해
## "실제 플레이 시간 1800초 경과"(D-15)를 흉내낸다.
extends Node

const EliteSpawnerScript := preload("res://scripts/systems/elite_spawner.gd")

var _spawner: Node
var _elapsed: float = 0.0
var _phase: String = "initial_spawn"
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 정예 리스폰(D-15, 실제 플레이 시간 30분) ===")
	GameState.elite_respawn_remaining_sec.clear()
	GameState.play_time_sec = 0.0

	_spawner = EliteSpawnerScript.new()
	add_child(_spawner)

	var captain = _spawner._instances.get("elite_goblin_captain")
	print("초기 스폰 확인: elite_goblin_captain 인스턴스=%s (위치=%s)" \
		% [str(captain), str(captain.global_position) if captain != null else "?"])

	Events.enemy_died.emit(captain, null)
	captain.queue_free()
	var remaining: float = float(GameState.elite_respawn_remaining_sec.get("elite_goblin_captain", 0.0))
	print("처치 후 리스폰 카운트다운=%.1f초 (farming_sources.json 기대값=1800.0)" % remaining)


func _process(delta: float) -> void:
	_elapsed += delta

	match _phase:
		"initial_spawn":
			# 죽은 다음 프레임까지 기다려 큐프리 정리 + check_respawns() 최초 호출 관찰.
			if _elapsed > 0.05:
				_spawner.check_respawns()
				var still_dead: bool = _spawner._instances.get("elite_goblin_captain") == null
				print("t=%.3f 30분 경과 전 재스폰 시도: still_dead=%s (기대 true)" % [_elapsed, still_dead])
				_phase = "fast_forward"
		"fast_forward":
			GameState._process(1800.5) # 실제 플레이 시간 30분 경과(D-15)를 한 번에 흉내.
			_spawner.check_respawns()
			var inst = _spawner._instances.get("elite_goblin_captain")
			if inst != null and is_instance_valid(inst):
				var expected: Vector2 = EliteSpawnerScript.SPAWN_POS_GLOBAL_TILE["elite_goblin_captain"] \
					* float(Tuning.TILE_SIZE_PROTOTYPE)
				var pos_ok: bool = (inst as Node2D).global_position == expected
				print("t=%.3f [PASS] 30분 경과 후 재스폰 확인 (같은 고정 지점=%s)" % [_elapsed, pos_ok])
				_finish()
			else:
				print("[FAIL] 30분 경과 후에도 재스폰되지 않음")
				_finish()

	if _elapsed > 4.0 and not _done:
		print("[TIMEOUT] phase=%s" % _phase)
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
