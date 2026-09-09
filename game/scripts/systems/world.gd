## 월드 루트. 프로토타입 단계: 청크 1개(64×64 타일) 크기의 풀밭을 코드로 채운다.
##
## TODO(월드 스트리밍 태스크): LDtk 맵을 64×64 타일 청크로 분할 로드하고
## 플레이어 주변 3×3 청크만 활성화 (Tuning.CHUNK_TILES / ACTIVE_CHUNK_RADIUS, GDD 12장).
extends Node2D

## TilesetField.png 아틀라스 좌표 (16px 셀, 5열 × 15행).
## 각 색상 블롭은 3×3(좌상단 col0,row r) + 2×2 변형(col3~4, row r~r+1).
const ATLAS_SOURCE_ID := 0
const GRASS_CENTER := Vector2i(1, 4)
const GRASS_VARIANTS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]
## 짙은 풀 3×3 블롭의 좌상단 아틀라스 좌표.
const DARK_GRASS_BLOB_ORIGIN := Vector2i(0, 6)

## 변형 타일이 섞이는 비율. 순수 연출값이라 테이블화 대상 아님.
const VARIANT_RATIO := 0.12
## 결정적 배치를 위한 시드.
const SEED := 20260908

@onready var ground: TileMapLayer = $Ground


func _ready() -> void:
	_fill_prototype_ground()


func _fill_prototype_ground() -> void:
	var half := Tuning.CHUNK_TILES / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y in range(-half, half):
		for x in range(-half, half):
			var atlas := GRASS_CENTER
			if rng.randf() < VARIANT_RATIO:
				atlas = GRASS_VARIANTS[rng.randi_range(0, GRASS_VARIANTS.size() - 1)]
			ground.set_cell(Vector2i(x, y), ATLAS_SOURCE_ID, atlas)
	# 짙은 풀 패치 몇 개를 3×3 블롭으로 얹는다 (플레이어 이동 확인용 랜드마크).
	for i in range(6):
		var origin := Vector2i(rng.randi_range(-half + 2, half - 5), rng.randi_range(-half + 2, half - 5))
		_place_blob(origin, DARK_GRASS_BLOB_ORIGIN)


func _place_blob(cell_origin: Vector2i, atlas_origin: Vector2i) -> void:
	for dy in range(3):
		for dx in range(3):
			ground.set_cell(cell_origin + Vector2i(dx, dy), ATLAS_SOURCE_ID, atlas_origin + Vector2i(dx, dy))
