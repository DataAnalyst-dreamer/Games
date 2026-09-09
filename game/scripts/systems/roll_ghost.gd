## 구르기 무적 구간 잔상 이펙트(S2-1b "표시: 무적 구간 잔상 이펙트"). 전용 아트가 없어
## (pixel-artist TODO — 완료 보고 질문 목록 참고) 플레이어 스프라이트의 현재 프레임을
## 그대로 복제해 옅게 물들이고 짧게 페이드아웃하는 방식으로 대체한다.
class_name RollGhost
extends RefCounted

const FADE_DURATION_SEC := 0.25
const GHOST_TINT := Color(0.65, 0.85, 1.0, 0.5)


## source_sprite: 현재 재생 중인 AnimatedSprite2D(Player.sprite). 트리 밖이거나
## SpriteFrames/애니메이션이 없으면 조용히 무시한다(방어적 — 테스트/에디터 상황 대비).
static func spawn(source_sprite: AnimatedSprite2D) -> void:
	if source_sprite == null or not is_instance_valid(source_sprite):
		return
	var tree := source_sprite.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var frames := source_sprite.sprite_frames
	if frames == null or not frames.has_animation(source_sprite.animation):
		return
	var texture := frames.get_frame_texture(source_sprite.animation, source_sprite.frame)
	if texture == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.global_position = source_sprite.global_position
	ghost.global_rotation = source_sprite.global_rotation
	ghost.flip_h = source_sprite.flip_h
	ghost.z_index = source_sprite.z_index - 1
	ghost.modulate = GHOST_TINT
	tree.current_scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, FADE_DURATION_SEC)
	tween.tween_callback(ghost.queue_free)
