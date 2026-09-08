## 피격 시 흰색 플래시 + 점멸 유틸리티(F2-2). CanvasItem(AnimatedSprite2D 등)의
## self_modulate를 짧게 흰색으로 올렸다가 원래대로 되돌리는 것을 몇 차례 반복한다.
class_name HitFlash
extends RefCounted

const FLASH_COLOR := Color(6.0, 6.0, 6.0, 1.0) ## 1보다 큰 값으로 오버브라이트(흰 번쩍임) 표현.
const FLASH_CYCLE_SEC := 0.06
const FLASH_CYCLES := 3


static func flash(target: CanvasItem) -> void:
	if target == null or not is_instance_valid(target):
		return
	var original: Color = target.modulate
	var tween := target.create_tween()
	for i in FLASH_CYCLES:
		tween.tween_property(target, "modulate", FLASH_COLOR, FLASH_CYCLE_SEC * 0.5)
		tween.tween_property(target, "modulate", original, FLASH_CYCLE_SEC * 0.5)
	tween.finished.connect(func() -> void:
		if is_instance_valid(target):
			target.modulate = original
	)
