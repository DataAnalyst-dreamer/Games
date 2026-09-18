extends Node2D

const SOURCE_SIZE := Vector2(1672, 941)
const DISPLAY_SIZE := Vector2(1920, 1080)
var obstacles: Array[PackedVector2Array] = []

func mapped(point: Vector2) -> Vector2:
	return point * DISPLAY_SIZE / SOURCE_SIZE

func _ready() -> void:
	var backdrop := Sprite2D.new()
	backdrop.texture = load("res://assets/village-gate.png")
	backdrop.centered = false
	backdrop.scale = DISPLAY_SIZE / SOURCE_SIZE
	add_child(backdrop)
	# Hand measured footprint boundaries, not automatic segmentation.
	_block([Vector2(0,0), Vector2(735,0), Vector2(735,445), Vector2(0,465)])
	_block([Vector2(950,0), Vector2(1672,0), Vector2(1672,590), Vector2(1450,470), Vector2(950,445)])
	_block([Vector2(65,625), Vector2(130,625), Vector2(145,690), Vector2(55,690)])
	_block([Vector2(-40,-40),Vector2(0,-40),Vector2(0,981),Vector2(-40,981)])
	_block([Vector2(1672,-40),Vector2(1712,-40),Vector2(1712,981),Vector2(1672,981)])
	_block([Vector2(0,925),Vector2(1672,925),Vector2(1672,981),Vector2(0,981)])
	_block([Vector2(0,-40),Vector2(1672,-40),Vector2(1672,0),Vector2(0,0)])

func _block(points: Array) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(mapped(point))
	obstacles.append(polygon)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := CollisionPolygon2D.new()
	shape.polygon = polygon
	body.add_child(shape)
	add_child(body)

func get_spawn_points() -> Dictionary:
	return {"player": mapped(Vector2(740,640)), "slimes": [mapped(Vector2(1020,640))]}

func is_walkable(point: Vector2) -> bool:
	for polygon in obstacles:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return false
	return Rect2(Vector2.ZERO, DISPLAY_SIZE).has_point(point)

func add_foreground(actors: Node2D) -> void:
	# Re-render a hand traced region of the same texture; no raster image edits.
	# This approximate silhouette is a prototype mask, not production segmentation.
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world_layout.json"))
	var points: Array = layout.foremost_tree.render_polygon_px
	var front := Polygon2D.new()
	front.name = "TreeForeground"
	front.position = mapped(Vector2(0,682))
	front.texture = load("res://assets/village-gate.png")
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in points:
		var source_point := Vector2(point[0], point[1])
		vertices.append(mapped(source_point) - front.position)
		uvs.append(source_point)
	front.polygon = vertices
	front.uv = uvs
	actors.add_child(front)
