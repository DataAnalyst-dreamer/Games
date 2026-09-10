## 몬스터 머리 위 소형 체력바(D-123, monster_base.gd) 테스트 — 평소 숨김 → 피격 시
## 노출 → 마지막 피격 후 Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC 뒤 페이드아웃. 실제
## MonsterBase._on_hurtbox_hurt()/_physics_process()를 직접 호출해 타이머를 결정적으로
## 진행시키는 관례는 test_monster_recover_state.gd/test_elite_bunchi_split.gd와 동일하다.
extends GutTest

const SlimeScene := preload("res://scenes/entities/monsters/Slime.tscn")
const EliteBunchiScene := preload("res://scenes/entities/monsters/EliteBunchiSpawn.tscn")
const HitboxScript := preload("res://scripts/systems/hitbox.gd")


func _make_slime() -> MonsterBase:
	var slime: MonsterBase = SlimeScene.instantiate()
	add_child_autofree(slime)
	return slime


func _hit(monster: MonsterBase, damage: int) -> void:
	var hb: Hitbox = HitboxScript.new()
	add_child_autofree(hb)
	hb.damage = damage
	monster._on_hurtbox_hurt(hb)


func test_hp_bar_hidden_by_default() -> void:
	var slime := _make_slime()
	assert_false(slime._hp_bar_bg.visible, "평소에는 숨겨져 있어야 한다")
	assert_false(slime._hp_bar_fill.visible)


func test_hp_bar_shows_on_hit() -> void:
	var slime := _make_slime()
	_hit(slime, 5)
	assert_true(slime._hp_bar_bg.visible, "피격 시 노출되어야 한다")
	assert_true(slime._hp_bar_fill.visible)
	assert_almost_eq(slime._hp_bar_bg.modulate.a, 1.0, 0.001)


func test_hp_bar_fill_ratio_matches_remaining_hp() -> void:
	var slime := _make_slime()
	var max_hp: int = slime.max_hp
	_hit(slime, int(max_hp / 2))
	var expected_ratio: float = float(slime.hp) / float(max_hp)
	assert_almost_eq(slime._hp_bar_fill.size.x / slime._hp_bar_fill_full_width, expected_ratio, 0.01)


func test_normal_tier_hp_bar_is_smaller_than_elite() -> void:
	var slime := _make_slime()
	var bunchi: MonsterBase = EliteBunchiScene.instantiate()
	add_child_autofree(bunchi)
	assert_true(slime._hp_bar_bg.size.x < bunchi._hp_bar_bg.size.x,
		"일반 몬스터 체력바는 정예보다 작아야 한다(D-123)")


func test_hp_bar_stays_visible_before_fade_delay_elapses() -> void:
	var slime := _make_slime()
	_hit(slime, 5)
	slime._physics_process(Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC - 0.1)
	assert_true(slime._hp_bar_bg.visible, "페이드 지연 시간이 아직 안 지났으면 계속 보여야 한다")
	assert_null(slime._hp_bar_fade_tween, "아직 페이드아웃 트윈이 시작되면 안 된다")


func test_hp_bar_starts_fade_after_delay_elapses() -> void:
	var slime := _make_slime()
	_hit(slime, 5)
	slime._physics_process(Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC + 0.01)
	assert_not_null(slime._hp_bar_fade_tween, "지연 시간이 지나면 페이드아웃 트윈이 시작되어야 한다")


func test_hp_bar_hides_after_fade_completes() -> void:
	var slime := _make_slime()
	_hit(slime, 5)
	slime._physics_process(Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC + 0.01)
	assert_not_null(slime._hp_bar_fade_tween)
	await slime._hp_bar_fade_tween.finished
	assert_false(slime._hp_bar_bg.visible, "페이드아웃 완료 후 숨겨져야 한다")
	assert_false(slime._hp_bar_fill.visible)


func test_hit_again_resets_fade_timer_and_reveals_immediately() -> void:
	var slime := _make_slime()
	_hit(slime, 5)
	slime._physics_process(Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC + 0.01)
	assert_not_null(slime._hp_bar_fade_tween, "먼저 페이드아웃이 시작된 상태여야 한다")

	_hit(slime, 5)

	assert_true(slime._hp_bar_bg.visible, "재피격 시 즉시 다시 보여야 한다")
	assert_almost_eq(slime._hp_bar_bg.modulate.a, 1.0, 0.001, "재피격 시 완전 불투명으로 되돌아가야 한다")
	assert_almost_eq(slime._hp_bar_hide_timer, Tuning.MONSTER_HP_BAR_FADE_DELAY_SEC, 0.001,
		"재피격은 페이드 지연 타이머를 리셋해야 한다")
