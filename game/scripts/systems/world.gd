## 월드 루트. quarter_atlas.json(애셋 계약)과 world_layout_hartland.json(배치)을 읽어
## 지면·벽·장식을 만든다 (D-201/D-213, 단계 b2).
##
## TileSet 을 .tscn 에 박지 않고 코드로 조립하는 이유: 아틀라스 좌표를 씬 파일에 적어 두면
## 타일이 늘 때마다 리뷰 불가능한 수십 줄이 생기고, 애셋 계약이 두 곳(JSON과 .tscn)으로
## 갈라진다. 생성기가 만든 quarter_atlas.json 하나만 정본으로 둔다.
##
## 등각(iso-1, D-219~D-224): TileSet 은 2:1 다이메트릭 마름모(64×32, DIAMOND_DOWN)다.
## world_layout_hartland.json 의 좌표는 **타일 좌표 = 격자 좌표**라 등각 전환에서
## 변환 없이 그대로 쓴다(스펙 §6 "가장 값싸게 살아남는 자산"). 지면 타일은 iso-1 동안
## 코드로 만든 단색 마름모이고, 정식 등각 애셋은 iso-2 의 gen_iso_tiles.py 몫이다.
##
## 충돌 규칙: 벽·건물의 **발밑 띠(접지선)만** 막는다 - 절벽 정면이나 지붕은 "이미 막힌
## 곳의 그림"이라 물리를 주지 않는다(파일럿 prototypes/quarter-view-lab/world.gd 가 손으로
## 한 것을 데이터화한 것). 띠 높이는 quarter_atlas.json 의 collision_band_px.
##
## TODO(월드 스트리밍 태스크): 64×64 타일 청크 분할 로드, 플레이어 주변 3×3만 활성화
## (Tuning.CHUNK_TILES / ACTIVE_CHUNK_RADIUS, GDD 12장).
extends Node2D

const ATLAS_PATH := "res://assets/iso/iso_atlas.json"
const LAYOUT_TABLE := "world_layout_hartland"

## 지면 변형 타일이 섞이는 비율의 기본값. 순수 연출값이라 테이블화 대상 아님.
const DEFAULT_VARIANT_RATIO := 0.14
## 결정적 배치를 위한 시드.
const SEED := 20260920

## 벽(정적 콜라이더) 레이어. 플레이어·몬스터의 collision_mask 1과 맞춘다.
const WALL_COLLISION_LAYER := 1

## 등각 타일 화면 크기(D-220). 지면 한 칸 32wu 가 화면에서 64×32 마름모가 된다.
const ISO_TILE_W := 64
const ISO_TILE_H := 32

@onready var ground: TileMapLayer = $Ground

## Main.tscn 이 소유하는 형제 노드 이름. Walls/Props 는 Y-sort 계층에 참여해야 해서
## World(z_index -2) 아래 둘 수 없고, Main 의 직계 자식이라야 액터와 앞뒤가 섞인다.
##
## @export NodePath 로 "../Walls" 를 저장해 봤지만 빈 값으로 직렬화된다 — World.tscn
## 안에서는 `..` 가 자기 씬 밖을 가리켜서 저장 시 버려진다. 부모에서 이름으로 찾는다.
const WALLS_NODE := "Walls"
const PROPS_NODE := "Props"
## 고도 1단 지면 레이어(D-224). 절벽 위에서 걸어 다니는 윗면이다.
const ELEV_NODE := "Elev1"

## 고도 한 단의 화면 높이(px). iso_atlas.json 의 _elevation_step 과 같아야 한다.
const ELEVATION_STEP := 32

var atlas: Dictionary = {}
var _assets: Dictionary = {}
var _source_ids: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = SEED
	atlas = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
	if atlas == null or not atlas.has("assets"):
		push_error("[World] %s 를 읽지 못했다 — 소품 배치가 빠진다(지면·벽은 코드 생성)." % ATLAS_PATH)
		return
	_assets = atlas["assets"]
	var tile_set := _build_tile_set()
	ground.tile_set = tile_set
	ground.scale = Vector2.ONE # b1 의 임시 2배 표시 해제.
	var parent: Node = get_parent()
	var walls: Node2D = null
	var props: Node2D = null
	var elevated: TileMapLayer = null
	if parent != null:
		walls = parent.get_node_or_null(WALLS_NODE) as Node2D
		props = parent.get_node_or_null(PROPS_NODE) as Node2D
		elevated = parent.get_node_or_null(ELEV_NODE) as TileMapLayer
	if walls == null or props == null:
		push_warning("[World] 형제 %s/%s 를 찾지 못했다 — 지면만 채운다." % [WALLS_NODE, PROPS_NODE])
	if elevated != null:
		elevated.tile_set = tile_set
		# 고도 한 단만큼 올려 깐다 - 같은 격자 좌표가 한 층 위에 그려진다(D-224).
		elevated.position.y = -ELEVATION_STEP
	_apply_layout(walls, props, elevated)


## 등각 TileSet. 지면 타일은 iso_atlas.json 의 64×32 마름모 PNG 다(D-226).
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
	for name: String in _assets:
		var entry: Dictionary = _assets[name]
		if not String(entry.get("kind", "")).begins_with("ground"):
			continue # 소품·건물·절벽은 타일이 아니라 Sprite2D 로 배치한다.
		var source := TileSetAtlasSource.new()
		source.texture = load(_res_path(entry))
		source.texture_region_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
		source.create_tile(Vector2i.ZERO)
		_source_ids[name] = tile_set.add_source(source)
	return tile_set


## iso_atlas.json 의 path 는 game/ 기준이라 res:// 로 바꾼다.
func _res_path(entry: Dictionary) -> String:
	return "res://" + String(entry["path"]).trim_prefix("game/")


func _cell(name: String) -> int:
	return int(_source_ids.get(name, -1))


func _apply_layout(walls: Node2D, props: Node2D, elevated: TileMapLayer) -> void:
	var layout: Dictionary = Data.table(LAYOUT_TABLE)
	if layout.is_empty():
		push_warning("[World] %s 테이블이 비어 있다 — 지면만 채운다." % LAYOUT_TABLE)
	_fill_ground(layout.get("ground", {}))
	for path: Variant in layout.get("paths", []):
		_fill_rect(ground, "tile_dirt", (path as Dictionary).get("rect", []))
	for pond: Variant in layout.get("water", []):
		var pond_dict: Dictionary = pond as Dictionary
		# D-236(M6-3): "asset" 생략 시 기존과 동일하게 tile_water — 같은 물 계열인
		# tile_stream(개울)도 이 배열에 항목만 더해 재사용한다(신규 최상위 키 불필요).
		var water_asset: String = String(pond_dict.get("asset", "tile_water"))
		var water_rect: Array = pond_dict.get("rect", [])
		_fill_rect(ground, water_asset, water_rect)
		if walls != null:
			_add_ground_solid_collision(walls, water_asset, water_rect)
	for plateau: Variant in layout.get("elevated", []):
		_fill_elevated(elevated, (plateau as Dictionary).get("rect", []))
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


## 직사각 격자 영역을 한 종류 타일로 채운다. iso-1 의 단색 마름모에는 가장자리 변형이
## 없으므로 3×3 오토타일 분기를 없앴다(iso-2 의 마름모 오토타일에서 되살린다).
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
			layer.set_cell(origin + Vector2i(dx, dy), source_id, Vector2i.ZERO)


## D-236(M6-3): 물/개울(kind=ground_solid) 은 지금까지 시각효과일 뿐 실제 충돌이
## 없었다 — iso_atlas.json 의 collision_band 는 절벽·소품(_place_cliff/_place_prop)
## 에서만 읽혔지 지면 채우기(_fill_rect)에서는 무시됐다. 절벽과 같은 마름모 콜리전을
## 칸마다 하나씩 걸어 "통행 불가"를 실제로 만든다. band<=0 인 지면 애셋(잔디·흙길)은
## 스킵된다.
func _add_ground_solid_collision(parent: Node, asset: String, rect: Array) -> void:
	if rect.size() != 4:
		return
	var band: float = float(_assets.get(asset, {}).get("collision_band", 0.0))
	if band <= 0.0:
		return
	var origin := Vector2i(int(rect[0]), int(rect[1]))
	var size := Vector2i(int(rect[2]), int(rect[3]))
	for dy in range(size.y):
		for dx in range(size.x):
			var cell := origin + Vector2i(dx, dy)
			_add_diamond_body(parent, IsoMath.cell_to_screen(cell), band)


## 절벽 한 줄. 등각에서 벽은 격자 행이고, 높이는 **고도 블록 스프라이트**가 표현한다
## (D-224). 타일맵으로 벽면을 그리려면 64×32 격자에 64×64 타일을 얹는 오프셋 곡예가
## 필요한데, 블록 스프라이트는 Props 와 같은 Y-sort 경로를 그대로 쓰므로 훨씬 단순하다.
## 걸어 다니는 윗면은 Elev1 레이어(32px 위)가 담당한다.
func _place_cliff(walls: Node, cliff: Dictionary) -> void:
	var height: int = int(cliff.get("height", ELEVATION_STEP))
	var asset: String = "cliff_block_%d" % height
	var entry: Dictionary = _assets.get(asset, {})
	if entry.is_empty():
		push_warning("[World] 고도 블록이 없다: %s" % asset)
		return
	var start_x: int = int(cliff.get("x", 0))
	var row: int = int(cliff.get("front_y", 0))
	var length: int = maxi(1, int(cliff.get("length", 1)))
	for index in range(length):
		var cell := Vector2i(start_x + index, row)
		_spawn_sprite(walls, entry, asset, cell)
		_add_diamond_body(walls, IsoMath.cell_to_screen(cell), 1.0)


## 절벽 위 대지: 같은 지면 타일을 Elev1 레이어(한 단 위)에 깐다.
func _fill_elevated(layer: TileMapLayer, rect: Array) -> void:
	if layer == null or rect.size() != 4:
		return
	var base: int = _cell("tile_grass_a")
	var variants: Array[int] = [_cell("tile_grass_b"), _cell("tile_grass_c")]
	var origin := Vector2i(int(rect[0]), int(rect[1]))
	for dy in range(int(rect[3])):
		for dx in range(int(rect[2])):
			var source_id: int = base
			if _rng.randf() < 0.35:
				source_id = variants[_rng.randi_range(0, variants.size() - 1)]
			layer.set_cell(origin + Vector2i(dx, dy), source_id, Vector2i.ZERO)


## 소품 한 개를 격자 셀에 놓는다.
func _place_prop(props: Node2D, prop: Dictionary) -> void:
	var asset: String = String(prop.get("asset", ""))
	var entry: Dictionary = _assets.get(asset, {})
	if entry.is_empty():
		push_warning("[World] iso_atlas 에 없는 애셋: %s" % asset)
		return
	var tile: Array = prop.get("tile", [0, 0])
	var cell := Vector2i(int(tile[0]), int(tile[1]))
	_spawn_sprite(props, entry, asset, cell)
	var band: float = float(entry.get("collision_band", 0.0))
	if band > 0.0:
		_add_diamond_body(props, IsoMath.cell_to_screen(cell), band)


## 애셋 하나를 셀 중심에 Sprite2D 로 놓는다.
##
## Y-sort 는 **노드의 global Y** 로 정렬하므로 노드는 셀 중심(발밑)에 두고 그림만
## offset(=-pivot)으로 끌어올린다. pivot 은 iso_atlas 가 정의한 **바닥 마름모 중심**이라,
## 높이가 제각각인 등각 입체들이 전부 같은 규칙으로 정렬된다.
func _spawn_sprite(parent: Node, entry: Dictionary, asset: String, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(_res_path(entry))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var pivot: Array = entry.get("pivot", [0.0, 0.0])
	sprite.position = IsoMath.cell_to_screen(cell)
	sprite.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	sprite.name = "%s_%d_%d" % [asset, cell.x, cell.y]
	parent.add_child(sprite)


## 격자 한 칸을 덮는 마름모 콜리전. 등각에서 지면의 정사각 한 칸은 화면에서 마름모이므로
## RectangleShape2D 로는 footprint 가 맞지 않는다(스펙 §3).
func _add_diamond_body(parent: Node, center: Vector2, scale_ratio: float) -> void:
	var half_w: float = ISO_TILE_W * 0.5 * scale_ratio
	var half_h: float = ISO_TILE_H * 0.5 * scale_ratio
	var body := StaticBody2D.new()
	body.collision_layer = WALL_COLLISION_LAYER
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var diamond := ConvexPolygonShape2D.new()
	diamond.points = PackedVector2Array([
		Vector2(0.0, -half_h), Vector2(half_w, 0.0),
		Vector2(0.0, half_h), Vector2(-half_w, 0.0),
	])
	shape.shape = diamond
	body.add_child(shape)
	parent.add_child(body)
