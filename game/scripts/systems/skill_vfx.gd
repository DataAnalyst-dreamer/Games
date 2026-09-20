## 스킬 시전 VFX(M4-3 "스킬 이펙트·시전 연출 개선"). skills.json.vfx.kind별로 도형 노드
## 1개(또는 dash_trail처럼 기존 컴포넌트 재사용)를 스폰하고 스스로 페이드아웃 후 free한다.
##
## ponytail: 전용 스프라이트 시트(FX/Slash 등, game/assets/third_party/ninja_adventure)는
## 아직 배선하지 않았다 — 사용자 피드백("정교한 아트보다 타이밍·앵커·읽힘이 먼저다",
## "필요하면 기초 도형 애셋 상태로 되돌려도 된다")을 그대로 반영해 Polygon2D/Line2D 같은
## 기본 도형으로 타이밍·방향·색만 우선 확정한다. kind별 분기 안쪽만 나중에 텍스처로
## 바꾸면 되므로 skill.gd 쪽 호출부는 그대로 유지된다(pixel-artist TODO).
class_name SkillVfx
extends RefCounted

const DEFAULT_LIFETIME_SEC := 0.18
const RING_LIFETIME_SEC := 0.22
const DASH_TRAIL_REPEATS := 3
const DASH_TRAIL_INTERVAL_SEC := 0.05


## kind: "slash_arc"|"thrust_line"|"ring"|"glow"|"dash_trail"|"speed_lines"|"none"(그 외
## 미지정 값 포함 — skills.json v2 vfx 필드가 아직 없는 스킬의 더미 폴백).
## color: skills.json vfx.color(hex) 파싱값. size_px: 히트박스 range_px * vfx.scale.
## parent: 이펙트 노드를 붙일 부모(생략 시 player.get_tree().current_scene — 실제 게임
## 배선). GUT 단위 테스트는 current_scene이 비어있어(Main.tscn을 열지 않으므로) 이 인자로
## add_child_autofree한 테스트 노드를 직접 넘겨 노드 생성·수명을 확인한다(Xvfb 불필요,
## 화면 픽셀 확인은 별도 스크린샷으로).
static func spawn(kind: String, player: Player, color: Color, size_px: float, parent: Node = null) -> void:
	if player == null or not is_instance_valid(player):
		return
	match kind:
		"slash_arc":
			_spawn_slash_arc(player, color, size_px, parent)
		"thrust_line":
			_spawn_thrust_line(player, color, size_px, parent)
		"ring":
			_spawn_ring(player, color, size_px, parent)
		"glow":
			_spawn_glow(player, color, parent)
		"dash_trail":
			_spawn_dash_trail(player)
		"speed_lines":
			_spawn_speed_lines(player, color, size_px, parent)
		_: # "none" 등
			pass


## skills.json vfx.color(hex, 예: "#66ccff")를 플래시용 오버브라이트 색으로 변환한다.
## 빈 값이면 기존 흰 플래시(HitFlash.FLASH_COLOR)를 그대로 써 회귀가 없게 한다.
static func flash_color_from_hex(hex: String) -> Color:
	if hex.is_empty():
		return HitFlash.FLASH_COLOR
	var base := Color(hex)
	return Color(base.r * 2.5, base.g * 2.5, base.b * 2.5, 1.0)


## 도형 채우기용 원색(플래시처럼 오버브라이트하지 않음). 빈 값이면 흰색.
static func base_color_from_hex(hex: String) -> Color:
	return Color(hex) if not hex.is_empty() else Color.WHITE


static func _spawn_root(player: Player, parent: Node = null) -> Node2D:
	var target_parent: Node = parent
	if target_parent == null:
		var tree := player.get_tree()
		target_parent = tree.current_scene if tree != null else null
	if target_parent == null:
		return null
	var root := Node2D.new()
	root.global_position = player.global_position
	root.z_index = 5
	target_parent.add_child(root)
	return root


static func _fade_and_free(node: CanvasItem, lifetime_sec: float) -> void:
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, lifetime_sec)
	tween.tween_callback(node.queue_free)


static func _wedge_points(radius: float, half_angle_deg: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(half_angle_deg)
	for i in segments + 1:
		var t: float = -half + (2.0 * half) * (float(i) / float(segments))
		pts.append(Vector2.RIGHT.rotated(t) * radius)
	return pts


static func _circle_points(radius: float, segments: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(segments)) * radius)
	return pts


## facing 방향으로 회전한 부채꼴(Polygon2D) — 원작 텍스처 없이도 "휘두른 방향"이
## 실루엣만으로 읽히게 하는 최소 형태(motion-design-reference.md "실루엣이 정보량 담당").
static func _spawn_slash_arc(player: Player, color: Color, size_px: float, parent: Node = null) -> void:
	var root := _spawn_root(player, parent)
	if root == null:
		return
	root.rotation = player.facing.angle()
	root.position += player.facing * (size_px * 0.3)
	var poly := Polygon2D.new()
	poly.polygon = _wedge_points(maxf(size_px, 8.0), 55.0, 10)
	poly.color = color
	root.add_child(poly)
	root.scale = Vector2(0.7, 0.7)
	var grow := root.create_tween()
	grow.tween_property(root, "scale", Vector2.ONE, DEFAULT_LIFETIME_SEC).set_trans(Tween.TRANS_SINE)
	_fade_and_free(root, DEFAULT_LIFETIME_SEC)


## facing 축으로 신장하는 직사각형(찌르기).
static func _spawn_thrust_line(player: Player, color: Color, size_px: float, parent: Node = null) -> void:
	var root := _spawn_root(player, parent)
	if root == null:
		return
	root.rotation = player.facing.angle()
	var length: float = maxf(size_px, 12.0)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0, -3), Vector2(length, -3), Vector2(length, 3), Vector2(0, 3),
	])
	poly.color = color
	root.add_child(poly)
	root.scale = Vector2(0.2, 1.0)
	var grow := root.create_tween()
	grow.tween_property(root, "scale", Vector2.ONE, DEFAULT_LIFETIME_SEC * 0.5) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_and_free(root, DEFAULT_LIFETIME_SEC)


## 자기 중심 원형 확장(AoE류).
static func _spawn_ring(player: Player, color: Color, size_px: float, parent: Node = null) -> void:
	var root := _spawn_root(player, parent)
	if root == null:
		return
	var poly := Polygon2D.new()
	poly.polygon = _circle_points(maxf(size_px, 10.0))
	poly.color = Color(color.r, color.g, color.b, 0.5)
	root.add_child(poly)
	root.scale = Vector2(0.2, 0.2)
	var grow := root.create_tween()
	grow.tween_property(root, "scale", Vector2.ONE, RING_LIFETIME_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_and_free(root, RING_LIFETIME_SEC)


## glow: player.sprite.modulate를 직접 건드리면 HitFlash의 modulate 메타 관리와 겹쳐
## 굳는 버그(D-129류)가 재발할 수 있어, 현재 프레임을 복제한 반투명 오버레이를 대신
## 펄스시킨다(roll_ghost.gd와 동일 기법 재사용).
static func _spawn_glow(player: Player, color: Color, parent: Node = null) -> void:
	var sprite := player.sprite
	if sprite == null or not is_instance_valid(sprite):
		return
	var target_parent: Node = parent
	if target_parent == null:
		var tree := sprite.get_tree()
		target_parent = tree.current_scene if tree != null else null
	if target_parent == null:
		return
	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(sprite.animation):
		return
	var texture := frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var glow := Sprite2D.new()
	glow.texture = texture
	glow.global_position = sprite.global_position
	glow.flip_h = sprite.flip_h
	glow.z_index = sprite.z_index + 1
	glow.modulate = Color(color.r, color.g, color.b, 0.0)
	target_parent.add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.7, DEFAULT_LIFETIME_SEC * 0.5)
	tween.tween_property(glow, "modulate:a", 0.0, DEFAULT_LIFETIME_SEC * 0.5)
	tween.tween_callback(glow.queue_free)


## 잔상 대시(RollGhost 재사용, D-180: dash_trail은 연출·self_effect.dash_px는 이동이라
## 같은 스킬에 둘 다 있어도 충돌이 아니다 — 여기선 잔상만 몇 프레임 더 흩뿌린다).
static func _spawn_dash_trail(player: Player) -> void:
	var sprite := player.sprite
	if sprite == null or not is_instance_valid(sprite):
		return
	RollGhost.spawn(sprite)
	var tree := player.get_tree()
	if tree == null:
		return
	for i in DASH_TRAIL_REPEATS - 1:
		tree.create_timer(DASH_TRAIL_INTERVAL_SEC * float(i + 1)).timeout.connect(func() -> void:
			if is_instance_valid(sprite):
				RollGhost.spawn(sprite)
		)


## facing 축 좌우로 짧게 벌어진 두 선(속도감).
static func _spawn_speed_lines(player: Player, color: Color, size_px: float, parent: Node = null) -> void:
	var root := _spawn_root(player, parent)
	if root == null:
		return
	root.rotation = player.facing.angle()
	var length: float = maxf(size_px, 20.0)
	for side in [-1.0, 1.0]:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = color
		line.add_point(Vector2(-length * 0.5, side * 6.0))
		line.add_point(Vector2(length * 0.5, side * 6.0))
		root.add_child(line)
	_fade_and_free(root, DEFAULT_LIFETIME_SEC * 0.7)
