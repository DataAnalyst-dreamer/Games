## 헤드리스 스모크: 등각 좌표계 (D-219~D-225, 단계 iso-1).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeIsoCoords.tscn --quit-after 900
##
## 검사하는 것:
##  1) IsoMath 의 변환식이 **엔진 TileMapLayer 와 같은 값**인가 - 수식을 손으로 적은 이상
##     엔진과 갈라질 수 있고, 갈라지면 타일 위에 선 것처럼 보이는데 실제론 어긋난다.
##  2) 지면 거리의 등방성 - 같은 지면 거리는 방향이 달라도 같은 값이어야 한다.
##     (순진한 "세로 2배" 근사는 항상 √2 배 크게 나온다. 그걸 썼는지 여기서 걸린다.)
##  3) 이동 속력의 등방성 - walk_speed 는 지면 속력이다.
##  4) 타일맵이 실제로 등각으로 설정됐는가.
##  5) 세이브 v2 -> v3 투영.
extends Node

const EPS := 0.001

var _ok: bool = true
var _main: Node2D


func _fail(message: String) -> void:
	_ok = false
	print("  [FAIL] %s" % message)


func _ready() -> void:
	print("=== SMOKE: 등각 좌표계 (iso-1) ===")
	_main = load("res://scenes/main/Main.tscn").instantiate() as Node2D
	add_child(_main)
	for _i in range(4):
		await get_tree().physics_frame

	_check_matches_engine()
	_check_roundtrip()
	_check_ground_distance_isotropy()
	_check_move_speed_isotropy()
	_check_tilemap_is_isometric()
	_check_save_migration()

	if _ok:
		print("[PASS] 변환식·등방성·타일맵·세이브 모두 기대대로")
	else:
		print("[FAIL] 등각 좌표계 불변 위반")
	print("=== SMOKE 종료 ===")
	get_tree().quit(0 if _ok else 1)


## 1) 엔진과의 일치 — 이 검사가 나머지 전부의 토대다.
func _check_matches_engine() -> void:
	print("-- 1. IsoMath ↔ 엔진 TileMapLayer 일치 --")
	var ground_layer: TileMapLayer = _main.get_node("World/Ground") as TileMapLayer
	if ground_layer == null or ground_layer.tile_set == null:
		_fail("Ground 레이어/TileSet 을 찾지 못했다")
		return
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(2, 0), Vector2i(0, 2), Vector2i(-3, 5), Vector2i(7, -2)]:
		var engine_pos: Vector2 = ground_layer.map_to_local(cell)
		var mine: Vector2 = IsoMath.cell_to_screen(cell)
		if mine.distance_to(engine_pos) > EPS:
			_fail("cell %s: 엔진=%s IsoMath=%s" % [cell, engine_pos, mine])
			return
		if ground_layer.local_to_map(engine_pos) != IsoMath.screen_to_cell(engine_pos):
			_fail("역변환 불일치 cell %s" % cell)
			return
	print("  8개 셀에서 map_to_local / local_to_map 과 완전 일치")


## 2) to_screen ↔ to_ground 왕복.
func _check_roundtrip() -> void:
	print("-- 2. 지면↔화면 왕복 --")
	for ground_vec: Vector2 in [Vector2(32, 0), Vector2(0, 32), Vector2(-96, 64), Vector2(17, -43)]:
		var back: Vector2 = IsoMath.to_ground(IsoMath.to_screen(ground_vec))
		if back.distance_to(ground_vec) > EPS:
			_fail("왕복 실패 %s -> %s" % [ground_vec, back])
			return
	print("  4개 벡터 왕복 오차 < %.3f" % EPS)


## 3) 지면 거리 등방성 + 절대값.
func _check_ground_distance_isotropy() -> void:
	print("-- 3. 지면 거리 등방성 --")
	var size: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	# 격자 축으로 한 칸 = 어느 축이든 지면 거리 = 타일 크기.
	for ground_step: Vector2 in [Vector2(size, 0), Vector2(0, size),
			Vector2(-size, 0), Vector2(0, -size)]:
		var measured: float = IsoMath.ground_length(IsoMath.to_screen(ground_step))
		if absf(measured - size) > EPS:
			_fail("한 칸 이동의 지면 거리 %.3f (기대 %.0f)" % [measured, size])
			return
	# 순진한 "세로 2배" 근사를 썼다면 여기서 √2 배로 어긋난다.
	var naive: float = Vector2(64.0, 0.0 * 2.0).length()
	var exact: float = IsoMath.ground_length(Vector2(64.0, 0.0))
	if absf(exact - 45.2548) > 0.01:
		_fail("화면 (64,0) 의 지면 거리 %.4f (기대 45.2548 = 64/√2)" % exact)
	else:
		print("  한 칸=%.0f 등방 / 화면(64,0)=%.3f (순진 근사라면 %.0f 였을 것)" \
			% [size, exact, naive])


## 4) 이동 속력이 방향과 무관한가.
func _check_move_speed_isotropy() -> void:
	print("-- 4. 이동 속력 등방성 --")
	var speed: float = float(Data.get_value("combat", "movement.walk_speed_px", 160.0))
	var screen_speeds: Array[float] = []
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
			Vector2(1, 1).normalized(), Vector2(-1, 2).normalized()]:
		var velocity: Vector2 = IsoMath.move_velocity(direction, speed)
		var ground_speed: float = IsoMath.ground_length(velocity)
		if absf(ground_speed - speed) > EPS:
			_fail("%s 방향 지면 속력 %.3f (기대 %.1f)" % [direction, ground_speed, speed])
			return
		screen_speeds.append(velocity.length())
	print("  6개 방향 전부 지면 속력 %.0f — 화면 속력은 %.0f~%.0f 로 다르다(2:1 이라 정상)" \
		% [speed, screen_speeds.min(), screen_speeds.max()])


## 5) 타일맵이 등각인가.
func _check_tilemap_is_isometric() -> void:
	print("-- 5. 타일맵 등각 설정 --")
	# iso-2(D-224): Walls 는 고도 블록 **스프라이트** 컨테이너라 TileMapLayer 가 아니다.
	# 타일맵은 지면(Ground)과 고도 1단 대지(Elev1) 둘이다.
	for path: String in ["World/Ground", "Elev1"]:
		var layer: TileMapLayer = _main.get_node_or_null(path) as TileMapLayer
		if layer == null or layer.tile_set == null:
			_fail("%s 에 TileSet 이 없다" % path)
			continue
		var tile_set: TileSet = layer.tile_set
		if tile_set.tile_shape != TileSet.TILE_SHAPE_ISOMETRIC:
			_fail("%s tile_shape 가 등각이 아니다" % path)
		elif tile_set.tile_size != Vector2i(64, 32):
			_fail("%s tile_size=%s (64×32 기대, D-220)" % [path, tile_set.tile_size])
		else:
			print("  %s: ISOMETRIC %s, 셀 %d개" \
				% [path, tile_set.tile_size, layer.get_used_cells().size()])


## 6) 세이브 v2 -> v3.
func _check_save_migration() -> void:
	print("-- 6. 세이브 v2 -> v3 --")
	var payload := {"version": 2, "state": {"player": {"position": {"x": 64.0, "y": 32.0}}}}
	var migrated: Dictionary = SaveManager._migrate_v2_to_v3(payload)
	var pos: Dictionary = migrated["state"]["player"]["position"]
	var expected: Vector2 = IsoMath.to_screen(Vector2(64.0, 32.0))
	if int(migrated["version"]) != 3:
		_fail("버전이 3으로 올라가지 않았다")
	elif Vector2(float(pos["x"]), float(pos["y"])).distance_to(expected) > EPS:
		_fail("좌표 투영 불일치: %s (기대 %s)" % [pos, expected])
	else:
		print("  지면(64,32) -> 화면(%.0f,%.0f), version=3" % [float(pos["x"]), float(pos["y"])])
