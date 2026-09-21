## 등각 액터 시트 -> SpriteFrames 조립 (D-228~D-234, 단계 iso-3).
##
## 씬에 AtlasTexture 수십 개를 박아 넣지 않는 이유는 world.gd 가 iso_atlas.json 으로
## TileSet 을 조립하는 이유와 같다: 액터가 늘 때마다 리뷰 불가능한 수백 줄이 .tscn 에
## 생기고, 애셋 계약이 두 곳(JSON 과 .tscn)으로 갈라진다. 계약은 JSON 한 곳에만 둔다.
##
## 시트 규격(= tools/art/normalize_ai_sheet.py 기본값):
##   셀 96×128, 발 기준점 (48,112), 행=방향 · 열=프레임.
##   8방향 행 순서 s/sw/w/nw/n/ne/e/se, 4방향 s/w/n/e(대각은 수평 폴백, D-230).
##   열 18개 = idle 4 / walk 8 / attack 6 (D-231).
##
## 정식 원화는 **같은 경로에 PNG 만 덮어쓰면** 되고, 미러 3행은 납품 전(normalize 단계)에
## 이미 펼쳐져 온다 - 런타임 미러(flip_h)는 하지 않는다.
class_name ActorSheet
extends RefCounted

const ATLAS_PATH := "res://assets/iso/iso_actor_atlas.json"

static var _atlas: Dictionary = {}


static func atlas() -> Dictionary:
	if _atlas.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_PATH))
		_atlas = parsed if parsed is Dictionary else {}
		if _atlas.is_empty():
			push_warning("[ActorSheet] %s 를 읽지 못했다" % ATLAS_PATH)
	return _atlas


static func entry(actor_id: String) -> Dictionary:
	var actors: Variant = atlas().get("actors", {})
	if not (actors is Dictionary):
		return {}
	var found: Variant = (actors as Dictionary).get(actor_id, {})
	return found if found is Dictionary else {}


## 이 액터가 쓰는 시트의 방향 수(8 또는 4). 모르는 액터는 8로 본다.
static func direction_count(actor_id: String) -> int:
	return int(entry(actor_id).get("directions", 8))


## 발밑 그림자 배율. sprite.scale 이 1이 되면서(D-232) 크기 단서가 사라진 자리를
## 시트 계약이 대신 채운다 - FootShadow.draw() 의 size_scale 로 그대로 넘긴다.
static func shadow_scale(actor_id: String) -> float:
	return float(entry(actor_id).get("shadow_scale", 1.0))


## 액터의 시각 높이(px). 머리 위 표시(HP바·이름표)가 발밑에 붙지 않게 하는 기준이다.
static func body_height(actor_id: String) -> float:
	var body: Variant = entry(actor_id).get("body_px", [32, 32])
	return float((body as Array)[1]) if body is Array and (body as Array).size() > 1 else 32.0


## facing -> 이 액터의 시트가 가진 행 이름.
static func dir_name(actor_id: String, facing: Vector2) -> String:
	return FacingCalc.dir_name(facing, direction_count(actor_id))


## "walk" + facing -> "walk_sw" 같은 애니메이션 이름.
static func anim_name(actor_id: String, base: String, facing: Vector2) -> String:
	return "%s_%s" % [base, dir_name(actor_id, facing)]


## sprite 에 이 액터의 SpriteFrames·발 기준점·배율을 배선한다.
## 시트가 없으면 씬에 들어 있던 원본을 그대로 두고 경고만 남긴다(테스트 안전장치).
## 반환값: 배선 성공 여부.
static func apply(sprite: AnimatedSprite2D, actor_id: String) -> bool:
	if sprite == null:
		return false
	var meta: Dictionary = entry(actor_id)
	if meta.is_empty():
		push_warning("[ActorSheet] iso_actor_atlas 에 없는 액터: %s" % actor_id)
		return false
	var texture: Texture2D = load(_res_path(String(meta.get("path", ""))))
	if texture == null:
		push_warning("[ActorSheet] 시트 로드 실패: %s" % meta.get("path", ""))
		return false

	var data: Dictionary = atlas()
	var cell: Array = data.get("_cell", [96, 128])
	var pivot: Array = data.get("_pivot", [48, 112])
	var cell_w: int = int(cell[0])
	var cell_h: int = int(cell[1])
	var rows: Array = data.get(
		"dir_rows_8" if int(meta.get("directions", 8)) >= 8 else "dir_rows_4", [])
	var clips: Dictionary = data.get("clips", {})

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in range(rows.size()):
		for base: String in clips:
			var span: Array = clips[base]
			var anim := StringName("%s_%s" % [base, rows[row]])
			frames.add_animation(anim)
			frames.set_animation_loop(anim, base != "attack")
			for i in range(int(span[1])):
				var region := Rect2(
					float((int(span[0]) + i) * cell_w), float(row * cell_h),
					float(cell_w), float(cell_h))
				var slice := AtlasTexture.new()
				slice.atlas = texture
				slice.region = region
				frames.add_frame(anim, slice)
	sprite.sprite_frames = frames
	# 발 기준점을 노드 원점에 맞춘다 - Y-sort 와 발밑 그림자가 전부 이 원점을 쓴다.
	sprite.centered = false
	sprite.offset = Vector2(-float(pivot[0]), -float(pivot[1]))
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.flip_h = false
	return true


## 아틀라스의 path 는 game/ 기준이라 res:// 로 바꾼다(world.gd 와 같은 규칙).
static func _res_path(path: String) -> String:
	return "res://" + path.trim_prefix("game/")


## 클립별 재생 속도(fps)를 건다. attack 은 프레임 수가 아니라 **지속시간**으로 맞춘다 -
## 콤보 판정 시간(Tuning.ATTACK_HIT_DURATION_SEC)은 밸런스고, 프레임 수는 아트 규격이라
## 서로 독립이어야 한다(시트가 6프레임이든 4프레임이든 같은 시간 동안 재생된다).
static func set_speeds(sprite: AnimatedSprite2D, idle_fps: float, walk_fps: float,
		attack_sec: float) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = sprite.sprite_frames
	for anim: StringName in frames.get_animation_names():
		var name_text := String(anim)
		if name_text.begins_with("walk"):
			frames.set_animation_speed(anim, walk_fps)
		elif name_text.begins_with("idle"):
			frames.set_animation_speed(anim, idle_fps)
		elif attack_sec > 0.0:
			frames.set_animation_speed(anim, float(frames.get_frame_count(anim)) / attack_sec)
