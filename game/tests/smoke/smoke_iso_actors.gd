## 헤드리스 스모크: 등각 8방향 액터 배선 (D-228~D-234, 단계 iso-3).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeIsoActors.tscn --quit-after 900
##
## 삭제된 SmokeSpriteAxis 의 역할(방향 입력 -> 애니메이션 이름 -> 시트 region)을 새 시트
## 규격으로 흡수하고(D-233), iso-3 가 새로 거는 세 가지를 더 본다:
##   §1 8방향 전환 - 입력 8방향이 시트 8행에 1:1로 걸리고 region 이 그 행을 가리킨다
##   §2 4방향 폴백 - 대각이 수평으로 접힌다(D-230, slime 시트가 4행)
##   §3 히트박스 방향 - 공격 히트박스가 바라보는 쪽에 서고, 지면 거리로 선다(R4)
##   §4 발 기준점 - 스프라이트 오프셋이 pivot 의 음수, 즉 노드 원점 = 발밑
##   §5 Y-sort - 화면 y 가 큰(= 앞쪽) 액터가 나중에 그려진다
extends Node

const DIRS := ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
## 각 방향 이름에 대응하는 화면 입력 벡터(정규화 전).
const INPUTS := {
	"s": Vector2(0, 1), "sw": Vector2(-1, 1), "w": Vector2(-1, 0), "nw": Vector2(-1, -1),
	"n": Vector2(0, -1), "ne": Vector2(1, -1), "e": Vector2(1, 0), "se": Vector2(1, 1),
}
## 방향 전환 사이에 흘려보낼 물리 프레임 수. D-229 디바운스(0.1초)를 확실히 넘긴다 -
## 이 스모크는 디바운스 자체가 아니라 방향 -> 시트 매핑을 본다.
const SETTLE_PHYSICS_FRAMES := 12

var _ok := true


func _fail(message: String) -> void:
	_ok = false
	print("  [FAIL] %s" % message)


func _ready() -> void:
	print("=== SMOKE: 등각 8방향 액터 (iso-3) ===")
	var player: Player = load("res://scenes/player/Player.tscn").instantiate()
	add_child(player)

	_check_sheet_contract()
	_check_eight_directions(player)
	_check_four_direction_fallback()
	_check_hitbox_direction(player)
	_check_foot_pivot(player)
	_check_y_sort()

	print("=== SMOKE %s ===" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


## 시트 계약 자체(정식 원화로 PNG 만 갈아 끼울 수 있으려면 이 값들이 고정이어야 한다).
func _check_sheet_contract() -> void:
	print("§0 시트 계약")
	var atlas: Dictionary = ActorSheet.atlas()
	var cell: Array = atlas.get("_cell", [])
	var pivot: Array = atlas.get("_pivot", [])
	print("  셀=%s pivot=%s 열=%s clips=%s" % [cell, pivot, atlas.get("_cols"), atlas.get("clips")])
	# JSON 은 숫자를 전부 float 으로 읽으므로 배열끼리 == 로 비교하면 항상 다르다.
	if cell.size() != 2 or int(cell[0]) != 96 or int(cell[1]) != 128:
		_fail("셀 규격이 96×128 이 아니다: %s" % [cell])
	if pivot.size() != 2 or int(pivot[0]) != 48 or int(pivot[1]) != 112:
		_fail("발 기준점이 (48,112) 가 아니다: %s" % [pivot])
	if atlas.get("dir_rows_8", []) != DIRS:
		_fail("8방향 행 순서가 계약과 다르다: %s" % [atlas.get("dir_rows_8", [])])
	# D-231(GDD D-133): idle 4 / walk 8 / attack 6.
	var clips: Dictionary = atlas.get("clips", {})
	for pair: Array in [["idle", 4], ["walk", 8], ["attack", 6]]:
		var span: Array = clips.get(pair[0], [])
		if span.size() != 2 or int(span[1]) != int(pair[1]):
			_fail("%s 프레임 수가 %d 이 아니다: %s" % [pair[0], int(pair[1]), span])


## §1 입력 8방향 -> 애니메이션 이름 -> region 의 행. 옛 SmokeSpriteAxis 가 하던 일이다.
func _check_eight_directions(player: Player) -> void:
	print("§1 8방향 전환")
	var frames: SpriteFrames = player.sprite.sprite_frames
	for row in range(DIRS.size()):
		var dir_name: String = DIRS[row]
		for _i in range(SETTLE_PHYSICS_FRAMES):
			player._physics_process(1.0 / 60.0)
		player.set_facing(INPUTS[dir_name])
		player.play_anim("walk")
		var anim: StringName = player.sprite.animation
		var expected := StringName("walk_%s" % dir_name)
		print("  입력=%-3s -> facing_name=%-2s 애니메이션=%s" % [dir_name, player.facing_name(), anim])
		if anim != expected:
			_fail("기대 애니메이션=%s, 실제=%s" % [expected, anim])
			continue
		if frames.get_frame_count(expected) != 8:
			_fail("%s 은 walk 8프레임이어야 한다" % expected)
			continue
		# 같은 클립의 모든 프레임이 **같은 행**을 써야 한다(행=방향이 섞이면 걷다가
		# 방향이 바뀌어 보인다 - D-137 때 실제로 났던 사고다).
		for i in range(8):
			var tex := frames.get_frame_texture(expected, i) as AtlasTexture
			if tex == null:
				_fail("%s frame %d 텍스처 없음" % [expected, i])
				continue
			if not is_equal_approx(tex.region.position.y, float(row * 128)):
				_fail("%s frame %d 행 불일치: y=%.0f (기대 %d)"
					% [expected, i, tex.region.position.y, row * 128])
			if tex.region.size != Vector2(96, 128):
				_fail("%s frame %d 셀 크기 불일치: %s" % [expected, i, tex.region.size])
		# idle/attack 도 같은 행을 유지해야 한다.
		for base: String in ["idle", "attack"]:
			player.play_anim(base)
			var clip := StringName("%s_%s" % [base, dir_name])
			if player.sprite.animation != clip:
				_fail("%s 재생 실패: %s" % [clip, player.sprite.animation])
				continue
			var pose := frames.get_frame_texture(clip, 0) as AtlasTexture
			if pose == null or not is_equal_approx(pose.region.position.y, float(row * 128)):
				_fail("%s 가 다른 행을 가리킨다" % clip)


## §2 4방향 시트(slime)는 대각을 수평으로 접는다(D-230).
func _check_four_direction_fallback() -> void:
	print("§2 8->4 폴백 (slime 시트)")
	if ActorSheet.direction_count("slime") != 4:
		_fail("slime 시트는 4방향이어야 한다")
		return
	var expected := {"s": "s", "sw": "w", "w": "w", "nw": "w",
		"n": "n", "ne": "e", "e": "e", "se": "e"}
	for dir_name: String in DIRS:
		var folded: String = ActorSheet.dir_name("slime", INPUTS[dir_name])
		if folded != String(expected[dir_name]):
			_fail("slime %s -> %s (기대 %s)" % [dir_name, folded, expected[dir_name]])
	print("  %s" % [expected])
	# 8방향 시트(fin)는 접히지 않는다.
	if ActorSheet.dir_name("fin", INPUTS["sw"]) != "sw":
		_fail("fin 시트는 대각을 접으면 안 된다")


## §3 공격 히트박스가 바라보는 쪽에 서는가. 오프셋은 **지면** 거리다(R4/D-222) -
## 화면 벡터에 그냥 곱하면 동서 사거리가 지면에서 1/√2 로 줄어든다.
func _check_hitbox_direction(player: Player) -> void:
	print("§3 히트박스 방향")
	var ground_offsets: Array[float] = []
	for dir_name: String in DIRS:
		for _i in range(SETTLE_PHYSICS_FRAMES):
			player._physics_process(1.0 / 60.0)
		player.set_facing(INPUTS[dir_name])
		player.hitbox.position = IsoMath.offset_for_ground_distance(
			player.facing, Tuning.ATTACK_HITBOX_OFFSET_PX)
		var offset: Vector2 = player.hitbox.position
		# 바라보는 쪽에 있어야 한다: 화면 오프셋과 facing 의 내적이 양수.
		if offset.dot(player.facing) <= 0.0:
			_fail("%s 방향 히트박스가 앞쪽에 서지 않았다: %s" % [dir_name, offset])
		ground_offsets.append(IsoMath.ground_length(offset))
	var lo: float = ground_offsets.min()
	var hi: float = ground_offsets.max()
	print("  지면 오프셋 최소=%.3f 최대=%.3f (기대 %.1f)"
		% [lo, hi, Tuning.ATTACK_HITBOX_OFFSET_PX])
	if not is_equal_approx(lo, hi) or absf(hi - Tuning.ATTACK_HITBOX_OFFSET_PX) > 0.01:
		_fail("방향마다 지면 사거리가 다르다(%.3f~%.3f)" % [lo, hi])


## §4 발 기준점 = 노드 원점. Y-sort·발밑 그림자·히트박스가 전부 이 원점을 쓴다.
func _check_foot_pivot(player: Player) -> void:
	print("§4 발 기준점")
	var sprite: AnimatedSprite2D = player.sprite
	print("  centered=%s offset=%s scale=%s shadow_scale=%.2f"
		% [sprite.centered, sprite.offset, sprite.scale, player.shadow_scale])
	if sprite.centered:
		_fail("centered=true 면 offset 이 pivot 을 뜻하지 않는다")
	if sprite.offset != Vector2(-48, -112):
		_fail("offset 이 -pivot 이 아니다: %s" % sprite.offset)
	if sprite.scale != Vector2.ONE:
		_fail("등각 시트는 배율 1로 쓴다(D-232): %s" % sprite.scale)
	if player.shadow_scale <= 1.0:
		_fail("발밑 그림자 배율이 시트에서 오지 않았다: %.2f" % player.shadow_scale)


## §5 Y-sort: 화면 y 가 큰(앞쪽) 액터가 나중에 그려진다. 노드 원점이 발밑이라
## 정렬 기준도 발밑이 된다 - 스프라이트를 offset 으로 끌어올린 덕이다.
func _check_y_sort() -> void:
	print("§5 Y-sort")
	var root := Node2D.new()
	root.y_sort_enabled = true
	add_child(root)
	var back: MonsterBase = load("res://scenes/entities/monsters/Slime.tscn").instantiate()
	var front: MonsterBase = load("res://scenes/entities/monsters/Slime.tscn").instantiate()
	root.add_child(back)
	root.add_child(front)
	back.global_position = Vector2(0, -40)
	front.global_position = Vector2(0, 40)
	print("  뒤=%s 앞=%s, 스프라이트 상단 y=%.0f/%.0f"
		% [back.global_position, front.global_position,
		back.sprite.offset.y, front.sprite.offset.y])
	# 발밑이 원점이므로 앞쪽 액터의 원점 y 가 더 크다 = Y-sort 가 뒤에 그린다.
	if front.global_position.y <= back.global_position.y:
		_fail("Y-sort 기준이 발밑이 아니다")
	# 그림은 발밑 위로만 뻗어야 한다(아래로 삐져나오면 정렬이 뒤집혀 보인다).
	if back.sprite.offset.y + 128.0 - 112.0 > 0.0 + 16.0:
		_fail("스프라이트가 발밑 아래로 과도하게 뻗는다")
	root.queue_free()
