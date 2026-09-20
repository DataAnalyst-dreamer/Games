## 월드 루트. quarter_atlas.json(애셋 계약)과 world_layout_hartland.json(배치)을 읽어
## 지면·벽·장식을 만든다 (D-201/D-213, 단계 b2).
##
## TileSet 을 .tscn 에 박지 않고 코드로 조립하는 이유: 아틀라스 좌표를 씬 파일에 적어 두면
## 타일이 늘 때마다 리뷰 불가능한 수십 줄이 생기고, 애셋 계약이 두 곳(JSON과 .tscn)으로
## 갈라진다. 생성기가 만든 quarter_atlas.json 하나만 정본으로 둔다.
##
## 충돌 규칙: 벽·건물의 **발밑 띠(접지선)만** 막는다 - 절벽 정면이나 지붕은 "이미 막힌
## 곳의 그림"이라 물리를 주지 않는다(파일럿 prototypes/quarter-view-lab/world.gd 가 손으로
## 한 것을 데이터화한 것). 띠 높이는 quarter_atlas.json 의 collision_band_px.
##
## TODO(월드 스트리밍 태스크): 64×64 타일 청크 분할 로드, 플레이어 주변 3×3만 활성화
## (Tuning.CHUNK_TILES / ACTIVE_CHUNK_RADIUS, GDD 12장).
extends Node2D

const ATLAS_PATH := "res://assets/quarter/quarter_atlas.json"
const LAYOUT_TABLE := "world_layout_hartland"

## 지면 변형 타일이 섞이는 비율의 기본값. 순수 연출값이라 테이블화 대상 아님.
const DEFAULT_VARIANT_RATIO := 0.14
## 결정적 배치를 위한 시드.
const SEED := 20260920

## 벽(정적 콜라이더) 레이어. 플레이어·몬스터의 collision_mask 1과 맞춘다.
const WALL_COLLISION_LAYER := 1

@onready var ground: TileMapLayer = $Ground

## Main.tscn 이 소유하는 형제 노드 이름. Walls/Props 는 Y-sort 계층에 참여해야 해서
## World(z_index -2) 아래 둘 수 없고, Main 의 직계 자식이라야 액터와 앞뒤가 섞인다.
##
## @export NodePath 로 "../Walls" 를 저장해 봤지만 빈 값으로 직렬화된다 — World.tscn
## 안에서는 `..` 가 자기 씬 밖을 가리켜서 저장 시 버려진다. 부모에서 이름으로 찾는다.
const WALLS_NODE := "Walls"
const PROPS_NODE := "Props"

var atlas: Dictionary = {}
var _assets: Dictionary = {}
var _source_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	atlas = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
	if atlas == null or not atlas.has("assets"):
		push_error("[World] %s 를 읽지 못했다 — tools/art/gen_quarter_tiles.py 를 먼저 실행한다." % ATLAS_PATH)
		return
	_assets = atlas["assets"]
	var tile_set := _build_tile_set()
	ground.tile_set = tile_set
	ground.scale = Vector2.ONE # b1 의 임시 2배 표시 해제 — 이제 아트가 실제 32px 이다.
	var parent: Node = get_parent()
	var walls: TileMapLayer = null
	var props: Node2D = null
	if parent != null:
		walls = parent.get_node_or_null(WALLS_NODE) as TileMapLayer
		props = parent.get_node_or_null(PROPS_NODE) as Node2D
	if walls == null or props == null:
		push_warning("[World] 형제 %s/%s 를 찾지 못했다 — 지면만 채운다." % [WALLS_NODE, PROPS_NODE])
	if walls != null:
		walls.tile_set = tile_set
	_apply_layout(walls, props)


## quarter_atlas.json 의 그리드형 애셋마다 TileSetAtlasSource 를 하나씩 만든다.
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	var tile_px: int = int(atlas.get("_tile_px", Tuning.TILE_SIZE_PROTOTYPE))
	tile_set.tile_size = Vector2i(tile_px, tile_px)
	for name: String in _assets:
		var entry: Dictionary = _assets[name]
		if not String(entry.get("kind", "")).begins_with("ground") \
				and String(entry.get("kind", "")) != "wall":
			continue # 소품·건물은 타일이 아니라 Sprite2D 로 배치한다.
		var source := TileSetAtlasSource.new()
		source.texture = load("res://" + String(entry["path"]).trim_prefix("game/"))
		source.texture_region_size = Vector2i(tile_px, tile_px)
		var grid: Array = entry.get("grid", [1, 1])
		for column in range(int(grid[0])):
			for row in range(int(grid[1])):
				source.create_tile(Vector2i(column, row))
		_source_ids[name] = tile_set.add_source(source)
	return tile_set


func _cell(name: String) -> int:
	return int(_source_ids.get(name, -1))


func _apply_layout(walls: TileMapLayer, props: Node2D) -> void:
	var layout: Dictionary = Data.table(LAYOUT_TABLE)
	if layout.is_empty():
		push_warning("[World] %s 테이블이 비어 있다 — 지면만 채운다." % LAYOUT_TABLE)
	_fill_ground(layout.get("ground", {}))
	for path: Variant in layout.get("paths", []):
		_fill_rect(ground, "tile_dirt_auto", (path as Dictionary).get("rect", []))
	for pond: Variant in layout.get("water", []):
		_fill_rect(ground, "water_auto", (pond as Dictionary).get("rect", []))
	if walls != null:
		for cliff: Variant in layout.get("cliffs", []):
			_place_cliff(walls, cliff as Dictionary)
	if props != null:
		for prop: Variant in layout.get("props", []):
			_place_prop(props, prop as Dictionary)


func _fill_ground(config: Dictionary) -> void:
	var radius: int = int(config.get("radius_tiles", Tuning.CHUNK_TILES / 2))
	var variant_ratio: float = float(config.get("variant_ratio", DEFAULT_VARIANT_RATIO))
	var base: int = _cell("tile_grass_a")
	var variants: Array[int] = [_cell("tile_grass_b"), _cell("tile_grass_c")]
	for y in range(-radius, radius):
		for x in range(-radius, radius):
			var source_id: int = base
			if _rng.randf() < variant_ratio:
				source_id = variants[_rng.randi_range(0, variants.size() - 1)]
			ground.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)


## 3×3 오토타일을 직사각형으로 깐다: 가운데 칸은 (1,1), 가장자리는 해당 방향 칸.
func _fill_rect(layer: TileMapLayer, asset: String, rect: Array) -> void:
	if rect.size() != 4:
		return
	var source_id: int = _cell(asset)
	if source_id < 0:
		return
	var origin := Vector2i(int(rect[0]), int(rect[1]))
	var size := Vector2i(int(rect[2]), int(rect[3]))
	for dy in range(size.y):
		for dx in range(size.x):
			var column: int = 0 if dx == 0 else (2 if dx == size.x - 1 else 1)
			var row: int = 0 if dy == 0 else (2 if dy == size.y - 1 else 1)
			layer.set_cell(origin + Vector2i(dx, dy), source_id, Vector2i(column, row))


## 절벽 한 줄: 윗면(front_y-1) · 정면(front_y) · 그림자(front_y+1) 세 행을 깔고,
## 정면 아래 접지 띠에만 StaticBody2D 를 하나 둔다(타일마다 폴리곤을 다는 것보다
## 노드도 적고 데이터도 layout 한 곳에 남는다).
func _place_cliff(walls: TileMapLayer, cliff: Dictionary) -> void:
	var source_id: int = _cell("cliff_auto")
	if source_id < 0:
		return
	var start_x: int = int(cliff.get("x", 0))
	var front_y: int = int(cliff.get("front_y", 0))
	var length: int = maxi(1, int(cliff.get("length", 1)))
	for index in range(length):
		var column: int = 0 if index == 0 else (2 if index == length - 1 else 1)
		var x: int = start_x + index
		walls.set_cell(Vector2i(x, front_y - 1), source_id, Vector2i(column, 0))
		walls.set_cell(Vector2i(x, front_y), source_id, Vector2i(column, 1))
		walls.set_cell(Vector2i(x, front_y + 1), source_id, Vector2i(column, 2))
	var band: float = float(_assets.get("cliff_auto", {}).get("collision_band_px", 10))
	var tile_px: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	var width: float = length * tile_px
	var bottom: float = (front_y + 1) * tile_px
	_add_static_band(walls, Vector2(start_x * tile_px + width * 0.5, bottom - band * 0.5),
		Vector2(width, band))


## 소품 한 개: 발 기준점을 타일 중앙 바닥에 맞춰 Sprite2D 로 놓고, 접지 띠가 있으면
## 같은 자리에 StaticBody2D 를 붙인다.
func _place_prop(props: Node2D, prop: Dictionary) -> void:
	var asset: String = String(prop.get("asset", ""))
	var entry: Dictionary = _assets.get(asset, {})
	if entry.is_empty():
		push_warning("[World] quarter_atlas 에 없는 애셋: %s" % asset)
		return
	var tile: Array = prop.get("tile", [0, 0])
	var tile_px: float = float(Tuning.TILE_SIZE_PROTOTYPE)
	var foot := Vector2((float(tile[0]) + 0.5) * tile_px, (float(tile[1]) + 1.0) * tile_px)

	var sprite := Sprite2D.new()
	sprite.texture = load("res://" + String(entry["path"]).trim_prefix("game/"))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var cell: Array = entry.get("cell", [tile_px, tile_px])
	var variant: int = int(prop.get("variant", 0))
	if int(entry.get("grid", [1, 1])[0]) > 1:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(variant * float(cell[0]), 0.0, float(cell[0]), float(cell[1]))
	# Y-sort 는 **노드의 global Y** 로 정렬한다. 스프라이트를 position 으로 밀어 올리면
	# 노드 Y가 그림의 꼭대기가 되어 큰 나무가 남쪽 집보다 뒤로 가는 식으로 순서가 뒤집힌다.
	# 노드는 발밑에 두고 그림만 offset 으로 끌어올린다.
	var pivot: Array = entry.get("pivot", [float(cell[0]) * 0.5, float(cell[1])])
	sprite.position = foot
	sprite.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	sprite.name = "%s_%d_%d" % [asset, int(tile[0]), int(tile[1])]
	props.add_child(sprite)

	var band: float = float(entry.get("collision_band_px", 0))
	if band > 0.0:
		var solid_width: float = float(cell[0]) * (0.5 if asset == "house_a" else 0.6)
		_add_static_band(props, foot - Vector2(0.0, band * 0.5), Vector2(solid_width, band))


func _add_static_band(parent: Node, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
