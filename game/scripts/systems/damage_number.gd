## 도트 스타일 데미지 숫자(F2-2, D-07 기본 켜짐). 스폰 즉시 위로 살짝 뜨면서 페이드아웃되고
## 스스로를 큐프리(queue_free)한다. 상성 적중 시 노란색으로 강조한다.
extends Node2D

const RISE_PX := 14.0
const DURATION_SEC := 0.6
const NORMAL_COLOR := Color(1, 1, 1)
const ADVANTAGE_COLOR := Color(1, 0.85, 0.2)

@onready var label: Label = $Label


func setup(damage: int, is_advantage: bool = false) -> void:
	label.text = str(damage)
	label.modulate = ADVANTAGE_COLOR if is_advantage else NORMAL_COLOR
	# 겹쳐 뜨는 숫자를 살짝 흩뿌려 가독성을 준다.
	position.x += randf_range(-4.0, 4.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_PX, DURATION_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, DURATION_SEC).set_delay(DURATION_SEC * 0.4)
	tween.chain().tween_callback(queue_free)
