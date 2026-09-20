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

const ATLAS_PATH := "res://assets/quarter/quarter_atlas.json"
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

## iso-1 임시 지면 색. iso-2 에서 마름모 애셋으로 교체된다.
const PLACEHOLDER_TILE_COLORS := {
	"tile_grass_a": Color(0.455, 0.639, 0.204),
	"tile_grass_b": Color(0.494, 0.678, 0.227),
	"tile_grass_c": Color(0.412, 0.588, 0.196),
	"tile_dirt_auto": Color(0.824, 0.702, 0.490),
	"water_auto": Color(0.329, 0.529, 0.537),
	"cliff_auto": Color(0.588, 0.325, 0.251),
}

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
		push_error("[World] %s 를 읽지 못했다 — 소품 배치가 빠진다(지면·벽은 코드 생성)." % ATLAS_PATH)
		return
	_assets = atlas["assets"]
	var tile_set := _build_tile_set()
	ground.tile_set = tile_set
	ground.scale = Vector2.ONE # b1 의 임시 2배 표시 해제.
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


## 등각 TileSet. iso-1 에서는 지면을 **코드로 만든 단색 마름모**로 채운다 - b2/b3 의
## 정사각 PNG 를 등각 격자에 얹으면 격자와 그림이 45도 어긋나 아무것도 읽히지 않는다.
## 정식 등각 애셋(마름모 잔디·길·절벽 세트)은 iso-2 의 gen_iso_tiles.py 가 만든다.
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
	for name: String in PLACEHOLDER_TILE_COLORS:
		var source := TileSetAtlasSource.new()
		source.texture = _diamond_texture(PLACEHOLDER_TILE_COLORS[name])
		source.texture_region_size = Vector2i(ISO_TILE_W, ISO_TILE_H)
		source.create_tile(Vector2i.ZERO)
		_source_ids[name] = tile_set.add_source(source)
	return tile_set


## 64×32 마름모 한 장. 가장자리는 한 단계 어둡게 해서 격자가 눈에 보이게 한다
## (iso-1 의 목적 자체가 "격자가 등각으로 도는가"를 확인하는 것이다).
func _diamond_texture(color: Color) -> ImageTexture:
	var image := Image.create(ISO_TILE_W, ISO_TILE_H, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var edge := Color(color.r * 0.82, color.g * 0.82, color.b * 0.82, 1.0)
	var half_w: float = ISO_TILE_W * 0.5
	var half_h: float = ISO_TILE_H * 0.5
	for y in range(ISO_TILE_H):
		for x in range(ISO_TILE_W):
			# 마름모 내부 판정: |x-cx|/halfW + |y-cy|/halfH <= 1
			var nx: float = absf(x + 0.5 - half_w) / half_w
			var ny: float = absf(y + 0.5 - half_h) / half_h
			var d: float = nx + ny
			if d <= 1.0:
				image.set_pixel(x, y, edge if d > 0.86 else color)
	return ImageTexture.create_from_image(image)


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


## 절벽 한 줄. 등각에서는 "정면/윗면/그림자 3행"이 성립하지 않는다 - 벽은 격자 위의
## 셀 나열이고 높이는 고도 레이어가 표현한다(D-224). iso-1 은 평면 벽으로 두고,
## 셀마다 마름모 콜리전을 얹는다.
func _place_cliff(walls: TileMapLayer, cliff: Dictionary) -> void:
	var source_id: int = _cell("cliff_auto")
	if source_id < 0:
		return
	var start_x: int = int(cliff.get("x", 0))
	var row: int = int(cliff.get("front_y", 0))
	var length: int = maxi(1, int(cliff.get("length", 1)))
	for index in range(length):
		var cell := Vector2i(start_x + index, row)
		walls.set_cell(cell, source_id, Vector2i.ZERO)
		_add_diamond_body(walls, IsoMath.cell_to_screen(cell), 1.0)


## 소품 한 개: 발 기준점을 **격자 셀 중심**에 맞춰 Sprite2D 로 놓고, 접지 띠가 있으면
## 같은 자리에 마름모 콜리전을 붙인다.
func _place_prop(props: Node2D, prop: Dictionary) -> void:
	var asset: String = String(prop.get("asset", ""))
	var entry: Dictionary = _assets.get(asset, {})
	if entry.is_empty():
		push_warning("[World] quarter_atlas 에 없는 애셋: %s" % asset)
		return
	var tile: Array = prop.get("tile", [0, 0])
	var foot: Vector2 = IsoMath.cell_to_screen(Vector2i(int(tile[0]), int(tile[1])))

	var sprite := Sprite2D.new()
	sprite.texture = load("res://" + String(entry["path"]).trim_prefix("game/"))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var cell: Array = entry.get("cell", [Tuning.TILE_SIZE_PROTOTYPE, Tuning.TILE_SIZE_PROTOTYPE])
	var variant: int = int(prop.get("variant", 0))
	if int(entry.get("grid", [1, 1])[0]) > 1:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(variant * float(cell[0]), 0.0, float(cell[0]), float(cell[1]))
	# Y-sort 는 **노드의 global Y** 로 정렬한다. 노드는 발밑(셀 중심)에 두고 그림만
	# offset 으로 끌어올린다 - position 으로 밀면 큰 나무가 남쪽 집보다 뒤로 간다.
	var pivot: Array = entry.get("pivot", [float(cell[0]) * 0.5, float(cell[1])])
	sprite.position = foot
	sprite.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	sprite.name = "%s_%d_%d" % [asset, int(tile[0]), int(tile[1])]
	props.add_child(sprite)

	if float(entry.get("collision_band_px", 0)) > 0.0:
		_add_diamond_body(props, foot, 0.7)


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
