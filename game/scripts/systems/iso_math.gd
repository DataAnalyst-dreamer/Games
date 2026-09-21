## 2:1 다이메트릭 등각 좌표 변환 (D-219~D-222, 단계 iso-1).
##
## 두 공간을 구분한다.
##   * **지면(ground)**: 실제 지형 평면의 직교 좌표. 밸런스 테이블의 `*_px` 는 전부 이
##     단위로 읽는다(D-222) — 사거리·인식 범위·이동 속도가 방향과 무관하게 같은 뜻이 된다.
##   * **화면(screen)**: 노드의 global_position. 물리·히트박스·카메라가 사는 공간(D-221 안 A).
##
## 한 칸 = Tuning.TILE_SIZE_PROTOTYPE(32) 지면 단위, 화면에서는 64×32 마름모(D-220):
##     screen.x = gx - gy
##     screen.y = (gx + gy) / 2
##
## 이 식은 Godot 의 TileMapLayer.map_to_local()(TILE_SHAPE_ISOMETRIC / DIAMOND_DOWN /
## tile_size 64×32)과 **반 칸 오프셋만 다르고 동일**하다 — 추측이 아니라 엔진 출력과
## 대조해 맞췄고, tests/smoke/smoke_iso_coords.gd 가 매 실행 그 일치를 다시 검사한다.
##
## 주의: "세로를 2배 해서 거리를 재는" 순진한 근사(Vector2(d.x, d.y * 2))는 **항상 √2 배
## 크게** 나온다(등방이긴 하다). 그걸 쓰면 밸런스 테이블의 모든 사거리가 조용히 1/√2 로
## 줄어든다 — 반드시 아래 정확한 변환을 쓴다.
class_name IsoMath
extends RefCounted


## 지면 벡터 -> 화면 벡터.
static func to_screen(ground_vec: Vector2) -> Vector2:
	return Vector2(ground_vec.x - ground_vec.y, (ground_vec.x + ground_vec.y) * 0.5)


## 화면 벡터 -> 지면 벡터. to_screen 의 정확한 역변환이다.
static func to_ground(screen_vec: Vector2) -> Vector2:
	return Vector2(screen_vec.x * 0.5 + screen_vec.y, screen_vec.y - screen_vec.x * 0.5)


## 화면 벡터의 **지면 길이**. 사거리·인식 범위 비교는 전부 이걸 쓴다.
static func ground_length(screen_vec: Vector2) -> float:
	return to_ground(screen_vec).length()


## 두 화면 좌표 사이의 지면 거리.
static func ground_distance(from_screen: Vector2, to_screen_pos: Vector2) -> float:
	return to_ground(to_screen_pos - from_screen).length()


## 화면 방향 입력을 "지면에서 등방인" 화면 속도로 바꾼다.
##
## 결과의 지면 속력은 방향과 무관하게 ground_speed 다. 화면에서는 가로가 세로의 2배로
## 빨라 보이는데(2:1 이므로) 그게 등각에서 옳다 — 같은 지면 거리를 가려면 가로로는 더
## 많은 화면 픽셀을 지나야 한다.
static func move_velocity(screen_dir: Vector2, ground_speed: float) -> Vector2:
	if screen_dir == Vector2.ZERO or ground_speed == 0.0:
		return Vector2.ZERO
	return to_screen(to_ground(screen_dir).normalized() * ground_speed)


## 화면 방향으로 지면 거리 ground_distance_px 만큼 갔을 때의 화면 변위.
## 넉백·대시처럼 "속도"가 아니라 "거리"로 정의된 값에 쓴다.
static func offset_for_ground_distance(screen_dir: Vector2, ground_distance_px: float) -> Vector2:
	if screen_dir == Vector2.ZERO:
		return Vector2.ZERO
	return to_screen(to_ground(screen_dir).normalized() * ground_distance_px)


## 격자 셀 중심의 화면 좌표. TileMapLayer.map_to_local() 과 같은 값을 준다.
static func cell_to_screen(cell: Vector2i) -> Vector2:
	var size: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	return to_screen(Vector2(cell) * size) + Vector2(size, size * 0.5)


## 화면 좌표가 속한 격자 셀. TileMapLayer.local_to_map() 과 같은 값을 준다.
static func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var size: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	var ground: Vector2 = to_ground(screen_pos - Vector2(size, size * 0.5))
	return Vector2i(floori(ground.x / size + 0.5), floori(ground.y / size + 0.5))


## 지면에서 반지름 ground_radius 인 **원**을, 화면에서 같은 영역을 덮는 2:1 타원으로 만든다.
##
## 지면 원 (R cos t, R sin t) 를 화면으로 보내면 축 정렬 타원
## (√2·R·cos θ, (√2·R/2)·sin θ) 가 된다 - 즉 반지름 √2·R 인 원을 세로로 0.5 배 누른 것.
## Godot 에 타원 도형이 없으므로 CircleShape2D + 노드 scale 로 만든다.
##
## 이걸 안 하면 인식 범위·장판이 화면에서는 원이지만 **지면에서는 남북으로 2배 긴 타원**이
## 되어, 같은 사거리인데 접근 방향에 따라 판정이 달라진다.
static func apply_ground_circle(shape_node: CollisionShape2D, ground_radius: float) -> void:
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = ground_radius * sqrt(2.0)
	shape_node.scale = Vector2(1.0, 0.5)
