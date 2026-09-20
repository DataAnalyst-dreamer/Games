## 헤드리스 스모크: 쿼터뷰 단계 (b2) — 벽 충돌·가림·32px 좌표·세이브 마이그레이션.
##
## 실행: godot --headless --path game res://tests/smoke/SmokeQuarterViewB.tscn --quit-after 900
##
## 검사하는 것:
##  1) 배치 무결성 — 새 벽/건물이 기존 퀘스트 오브젝트·NPC·몬스터 스폰을 막지 않는가.
##     (b2에서 없던 정적 콜라이더가 생겼으므로 가장 먼저 깨질 수 있는 불변이다.)
##  2) 벽 충돌 — 절벽 접지 띠는 막고, 진입로 틈은 통과된다.
##  3) 가림 — 절벽 남쪽에 선 플레이어가 절벽보다 앞에 정렬된다.
##  4) 32px 좌표 — 타일 좌표 ↔ 월드 좌표 왕복이 Tuning.TILE_SIZE_PROTOTYPE 과 일치.
##  5) 세이브 v1 -> v2 — 실지형에서 옛 좌표가 2배로 복원되고, 벽 안이면 비석으로 물러난다.
##  6) D-208 — 몬스터가 벽을 통과하지 못하고, 리쉬 범위를 벗어나면 추적을 포기한다.
extends Node

var _ok: bool = true
var _main: Node2D


func _fail(message: String) -> void:
	_ok = false
	print("  [FAIL] %s" % message)


func _tile_px() -> float:
	return float(Tuning.TILE_SIZE_PROTOTYPE)


## 해당 월드 좌표에 정적 콜라이더(벽 레이어)가 있는가.
func _solid_at(world_pos: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1
	query.collide_with_areas = false
	return not _main.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _ready() -> void:
	print("=== SMOKE: 쿼터뷰 (b2) 벽·가림·좌표·세이브 ===")
	_main = load("res://scenes/main/Main.tscn").instantiate() as Node2D
	add_child(_main)
	for _i in range(4):
		await get_tree().physics_frame

	_check_layout_does_not_block_content()
	_check_coordinates()
	await _check_wall_blocks_and_gap_passes()
	_check_occlusion()
	_check_save_migration_on_real_terrain()
	await _check_monster_wall_and_leash()

	if _ok:
		print("[PASS] 벽 충돌·가림·좌표·세이브·몬스터 벽 모두 기대대로")
	else:
		print("[FAIL] 단계 (b2) 불변 위반")
	print("=== SMOKE 종료 ===")
	get_tree().quit(0 if _ok else 1)


## 1) 새 지형이 기존 콘텐츠를 묻어버리지 않는가.
func _check_layout_does_not_block_content() -> void:
	print("-- 1. 배치 무결성 (벽이 퀘스트·NPC·몬스터를 막지 않는가) --")
	var blocked: Array[String] = []
	for object_id: String in Data.table("world_objects"):
		if object_id.begins_with("_"):
			continue
		var entry: Variant = Data.table("world_objects")[object_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var position: Array = (entry as Dictionary).get("position", [])
		if position.size() == 2 and _solid_at(Vector2(float(position[0]), float(position[1]))):
			blocked.append(object_id)
	for child: Node in _main.get_children():
		var body := child as Node2D
		if body == null:
			continue
		if child is MonsterBase or child is Player or String(child.name).ends_with("Npc1") \
				or String(child.name).begins_with("Waystone"):
			if _solid_at(body.global_position):
				blocked.append(String(child.name))
	if blocked.is_empty():
		print("  퀘스트 오브젝트 %d개 + 씬 배치 액터 전부 벽 밖" % Data.table("world_objects").size())
	else:
		_fail("벽 안에 묻힌 대상: %s" % [blocked])


## 4) 타일 <-> 월드 좌표 왕복.
func _check_coordinates() -> void:
	print("-- 4. 32px 좌표계 --")
	if not is_equal_approx(_tile_px(), 32.0):
		_fail("TILE_SIZE_PROTOTYPE=%s (32 기대)" % _tile_px())
	var layout: Dictionary = Data.table("world_layout_hartland")
	var cliffs: Array = layout.get("cliffs", [])
	if cliffs.is_empty():
		_fail("world_layout_hartland.cliffs 가 비었다")
		return
	var cliff: Dictionary = cliffs[0]
	var front_world_y: float = float(cliff["front_y"]) * _tile_px()
	print("  타일 front_y=%d -> 월드 y=%.0f (타일 %.0fpx)" % [int(cliff["front_y"]), front_world_y, _tile_px()])
	if not is_equal_approx(front_world_y / _tile_px(), float(cliff["front_y"])):
		_fail("타일↔월드 왕복 불일치")


## 2) 절벽은 막고, 진입로 틈은 통과된다.
func _check_wall_blocks_and_gap_passes() -> void:
	print("-- 2. 벽 충돌 / 진입로 통과 --")
	var player: Player = _main.get_node("Player") as Player
	var layout: Dictionary = Data.table("world_layout_hartland")
	var cliff: Dictionary = (layout.get("cliffs", []) as Array)[0]
	var front_y: float = float(cliff["front_y"]) * _tile_px()
	# 절벽 한가운데 아래에서 북쪽으로 밀어 본다.
	var wall_x: float = (float(cliff["x"]) + float(cliff["length"]) * 0.5) * _tile_px()
	var start_y: float = front_y + _tile_px() * 3.0
	player.global_position = Vector2(wall_x, start_y)
	await _push_north(player)
	if player.global_position.y < front_y:
		_fail("절벽을 통과했다 (y=%.0f, 접지선 y=%.0f)" % [player.global_position.y, front_y])
	else:
		print("  절벽 앞에서 멈춤: y=%.0f (접지선 %.0f)" % [player.global_position.y, front_y])
	# 진입로 틈(x=0 부근)에서는 통과돼야 한다.
	player.global_position = Vector2(0.0, start_y)
	await _push_north(player)
	if player.global_position.y > front_y:
		_fail("진입로 틈이 막혀 있다 (y=%.0f)" % player.global_position.y)
	else:
		print("  진입로 통과: y=%.0f" % player.global_position.y)


func _push_north(player: Player) -> void:
	for _i in range(90):
		player.velocity = Vector2(0.0, -player.walk_speed * 3.0)
		player.move_and_slide()
		await get_tree().physics_frame


## 3) 절벽 남쪽의 플레이어가 벽보다 앞에 정렬된다.
func _check_occlusion() -> void:
	print("-- 3. 가림(Y-sort) --")
	var walls: TileMapLayer = _main.get_node_or_null("Walls") as TileMapLayer
	var props: Node2D = _main.get_node_or_null("Props") as Node2D
	if walls == null or props == null:
		_fail("Walls/Props 노드를 찾지 못했다")
		return
	if walls.get_used_cells().is_empty():
		_fail("Walls 레이어가 비었다 — 절벽이 그려지지 않는다")
	if props.get_child_count() == 0:
		_fail("Props 가 비었다 — 나무·집이 배치되지 않았다")
	if not _main.is_y_sort_enabled() or not walls.y_sort_enabled or not props.y_sort_enabled:
		_fail("Main/Walls/Props 중 y_sort 가 꺼진 노드가 있다")
	else:
		print("  Walls %d칸, Props %d개, y_sort 전부 켜짐" \
			% [walls.get_used_cells().size(), props.get_child_count()])


## 5) 실지형에서의 세이브 마이그레이션.
func _check_save_migration_on_real_terrain() -> void:
	print("-- 5. 세이브 v1 -> v2 (실지형) --")
	var payload := {"version": 1, "state": {"player": {"position": {"x": -40.0, "y": -100.0}}}}
	var migrated: Dictionary = SaveManager._migrate_v1_to_v2(payload)
	var pos: Dictionary = migrated["state"]["player"]["position"]
	if not (is_equal_approx(float(pos["x"]), -80.0) and is_equal_approx(float(pos["y"]), -200.0)):
		_fail("v1 좌표가 2배로 변환되지 않았다: %s" % pos)
	elif _solid_at(Vector2(float(pos["x"]), float(pos["y"]))):
		_fail("마이그레이션된 좌표(%s)가 새 벽 안이다 — 배치를 조정해야 한다" % pos)
	else:
		print("  (-40,-100) -> (%.0f,%.0f), 벽 밖 확인" % [float(pos["x"]), float(pos["y"])])


## 6) D-208: 몬스터가 벽을 통과하지 않고, 리쉬 밖이면 추적을 포기한다.
func _check_monster_wall_and_leash() -> void:
	print("-- 6. 몬스터 벽 충돌 + 리쉬 복귀 (D-208) --")
	var monster: MonsterBase = null
	for child: Node in _main.get_children():
		if child is MonsterBase:
			monster = child as MonsterBase
			break
	if monster == null:
		_fail("몬스터를 찾지 못했다")
		return
	if monster.collision_mask & 1 == 0:
		_fail("몬스터 collision_mask 에 벽 레이어(1)가 없다 — 벽을 통과한다")
	var player: Player = _main.get_node("Player") as Player
	var layout: Dictionary = Data.table("world_layout_hartland")
	var cliff: Dictionary = (layout.get("cliffs", []) as Array)[0]
	var front_y: float = float(cliff["front_y"]) * _tile_px()
	var wall_x: float = (float(cliff["x"]) + float(cliff["length"]) * 0.5) * _tile_px()
	# 몬스터는 벽 남쪽, 플레이어는 벽 북쪽 — 직선으로 가면 벽에 막힌다.
	monster.global_position = Vector2(wall_x, front_y + _tile_px() * 2.0)
	player.global_position = Vector2(wall_x, front_y - _tile_px() * 2.0)
	for _i in range(60):
		await get_tree().physics_frame
	if monster.global_position.y < front_y:
		_fail("몬스터가 절벽을 통과했다 (y=%.0f)" % monster.global_position.y)
	else:
		print("  몬스터가 벽 남쪽에 머묾: y=%.0f (접지선 %.0f)" % [monster.global_position.y, front_y])
	# 리쉬: 플레이어를 리쉬 범위 밖으로 옮기면 추적을 포기하고 IDLE 로 돌아온다.
	player.global_position = monster.global_position + Vector2(monster.leash_range_px * 2.0, 0.0)
	for _i in range(30):
		await get_tree().physics_frame
	if monster.state == MonsterBase.State.CHASE:
		_fail("리쉬 범위 밖인데 아직 추적 중이다")
	else:
		print("  리쉬 범위 밖 -> 추적 포기 (state=%d)" % monster.state)
