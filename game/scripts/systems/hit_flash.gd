## 피격 시 흰색 플래시 + 점멸 유틸리티(F2-2). CanvasItem(AnimatedSprite2D 등)의
## modulate를 짧게 흰색으로 올렸다가 원래대로 되돌리는 것을 몇 차례 반복한다.
##
## D-129: 플래시가 진행 중인 대상에 다시 flash()가 불리면(연타·트레이드), 예전 구현은
## "지금의 modulate"(흰색 도중 값)를 원래 색으로 기억해 끝난 뒤 흰색으로 굳을 수 있었다.
## 지금은 진짜 원래 색을 메타에 한 번만 저장하고, 이전 플래시 tween은 kill한 뒤 새로
## 시작하며, 끝나면 메타의 원래 색으로 복원한다.
class_name HitFlash
extends RefCounted

const FLASH_COLOR := Color(6.0, 6.0, 6.0, 1.0) ## 1보다 큰 값으로 오버브라이트(흰 번쩍임) 표현.
const FLASH_CYCLE_SEC := 0.06
const FLASH_CYCLES := 3

const META_ORIGINAL_COLOR := &"_hit_flash_original"
const META_TWEEN := &"_hit_flash_tween"


static func flash(target: CanvasItem) -> void:
	if target == null or not is_instance_valid(target):
		return
	# 진행 중인 플래시가 있으면 끊고, 원래 색은 첫 호출 때 저장한 값을 그대로 쓴다.
	var previous: Tween = target.get_meta(META_TWEEN, null) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var original: Color
	if target.has_meta(META_ORIGINAL_COLOR):
		original = target.get_meta(META_ORIGINAL_COLOR)
	else:
		original = target.modulate
		target.set_meta(META_ORIGINAL_COLOR, original)
	var tween := target.create_tween()
	target.set_meta(META_TWEEN, tween)
	for i in FLASH_CYCLES:
		tween.tween_property(target, "modulate", FLASH_COLOR, FLASH_CYCLE_SEC * 0.5)
		tween.tween_property(target, "modulate", original, FLASH_CYCLE_SEC * 0.5)
	tween.finished.connect(func() -> void:
		if is_instance_valid(target):
			target.modulate = original
			target.remove_meta(META_ORIGINAL_COLOR)
			target.remove_meta(META_TWEEN)
	)
