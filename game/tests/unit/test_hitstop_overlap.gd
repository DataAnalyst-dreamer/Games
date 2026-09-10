## D-129 회귀 테스트: 같은 노드에 히트스톱/피격 플래시가 겹쳐 걸려도(플레이어 공격과
## 몬스터 접촉 공격의 트레이드) 원래 process_mode와 modulate로 반드시 복원돼야 한다.
## 2차 재테스트에서 "적이 새하얗게 굳은 채 사라지지 않는" 증상의 원인이었다.
extends GutTest


func test_overlapping_hitstop_restores_original_mode() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT)
	Hitstop.apply_to([node], 0.05)
	await wait_frames(2) # set_deferred 반영 → DISABLED
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "첫 히트스톱으로 정지")
	# 정지 중에 두 번째 히트스톱(트레이드) — 예전엔 여기서 DISABLED를 원래 값으로 기억했다.
	Hitstop.apply_to([node], 0.05)
	await wait_seconds(0.3)
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT, "겹친 히트스톱이 모두 끝나면 원래 모드로 복원")
	assert_false(Hitstop.is_frozen(node), "메타 정리됨")


func test_later_hitstop_extends_freeze_and_earlier_timer_does_not_unfreeze_early() -> void:
	var node := Node2D.new()
	add_child_autofree(node)
	Hitstop.apply_to([node], 0.05)
	await wait_frames(2)
	Hitstop.apply_to([node], 0.4)
	await wait_seconds(0.15) # 첫 타이머(0.05)는 지났지만 두 번째(0.4)는 진행 중
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "늦게 걸린 히트스톱이 끝나기 전엔 계속 정지")
	await wait_seconds(0.4)
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT, "마지막 히트스톱이 끝나면 복원")


func test_overlapping_flash_restores_true_original_color() -> void:
	var sprite := Sprite2D.new()
	add_child_autofree(sprite)
	var original := Color(0.5, 0.6, 0.7, 1.0)
	sprite.modulate = original
	HitFlash.flash(sprite)
	await wait_seconds(0.04) # 첫 플래시가 흰색으로 올라가는 도중
	assert_true(sprite.modulate.r > 1.0, "플래시 진행 중(오버브라이트)")
	HitFlash.flash(sprite) # 겹친 두 번째 플래시 — 예전엔 흰색을 원래 색으로 기억했다
	await wait_seconds(0.4)
	assert_almost_eq(sprite.modulate.r, original.r, 0.001, "원래 색 R 복원")
	assert_almost_eq(sprite.modulate.g, original.g, 0.001, "원래 색 G 복원")
	assert_almost_eq(sprite.modulate.b, original.b, 0.001, "원래 색 B 복원")
	assert_false(sprite.has_meta(HitFlash.META_ORIGINAL_COLOR), "메타 정리됨")
