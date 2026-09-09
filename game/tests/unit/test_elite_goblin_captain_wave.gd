## 고블린 정찰대장(elite_goblin_captain) 소환 웨이브(§1-2, wave_*) 테스트: HP 50% 1회
## 발동, 재발동 없음, 완료 시 wave_summon_count마리 소환.
extends GutTest

const CaptainScene := preload("res://scenes/entities/monsters/EliteGoblinCaptain.tscn")
const HitboxScript := preload("res://scripts/systems/hitbox.gd")


func _make_captain() -> MonsterBase:
	var m: MonsterBase = CaptainScene.instantiate()
	add_child_autofree(m)
	return m


func _hit(monster: MonsterBase, damage: int) -> void:
	var hb: Hitbox = HitboxScript.new()
	add_child_autofree(hb)
	hb.damage = damage
	monster._on_hurtbox_hurt(hb)


func test_hp_matches_elite_and_farming_spec() -> void:
	var captain := _make_captain()
	assert_eq(captain.max_hp, 120, "elite-and-farming-m2.md §1-2: hp=120 (24 x5.0)")
	assert_almost_eq(captain.wave_trigger_hp_pct, 0.5, 0.0001)
	assert_true(captain.wave_once_per_life)


func test_hp_drop_to_half_triggers_wave_once() -> void:
	var captain := _make_captain()
	_hit(captain, 61) # 120 - 61 = 59 <= 60(50%) → 발동.

	assert_eq(captain.state, MonsterBase.State.WAVE, "HP 50% 이하로 떨어지면 WAVE로 전이해야 한다")
	assert_almost_eq(captain._state_timer, captain.wave_cast_sec, 0.0001)


func test_wave_does_not_retrigger_on_further_damage_within_same_life() -> void:
	var captain := _make_captain()
	var parent := captain.get_parent()
	var before: Array = parent.get_children()
	_hit(captain, 61)
	assert_eq(captain.state, MonsterBase.State.WAVE)

	captain._state_timer = 0.0
	captain._physics_process(0.001) # 시전 완료 → CHASE/IDLE로 복귀(+ 실제 웨이브 소환 발생).
	for child in parent.get_children():
		if child is MonsterBase and child != captain and not before.has(child):
			autofree(child) # 이번 테스트가 만든 웨이브 소환체 정리(다음 테스트로 새지 않도록).
	assert_ne(captain.state, MonsterBase.State.WAVE)

	_hit(captain, 5) # 여전히 HP <= 50%지만 이미 1회 발동했으므로 재발동 금지.
	assert_ne(captain.state, MonsterBase.State.WAVE, "wave_once_per_life: 같은 생애에 재발동하면 안 된다")


func test_wave_does_not_trigger_above_half_hp() -> void:
	var captain := _make_captain()
	_hit(captain, 10) # 120 - 10 = 110, 아직 50% 초과.
	assert_ne(captain.state, MonsterBase.State.WAVE)


func test_wave_completion_spawns_configured_count_and_they_chase_the_player() -> void:
	var captain := _make_captain()
	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = captain.global_position + Vector2(30, 0)
	captain._player = player
	var parent := captain.get_parent()
	var before: Array = parent.get_children()

	_hit(captain, 61)
	assert_eq(captain.state, MonsterBase.State.WAVE)
	captain._state_timer = 0.0
	captain._physics_process(0.001)

	# before 스냅샷과 비교해 이번 웨이브가 새로 만든 자식만 골라낸다 — queue_free()는
	# 지연 삭제라 이전 테스트가 스폰한 개체가 아직 남아 있을 수 있어(테스트 격리 문제,
	# test_elite_bunchi_split.gd와 동일한 함정) 단순 "MonsterBase면 다 센다"는 위험하다.
	var spawned: Array = []
	for child in parent.get_children():
		if child is MonsterBase and child != captain and not before.has(child):
			autofree(child)
			spawned.append(child)
	assert_eq(spawned.size(), captain.wave_summon_count, "wave_summon_count(3)마리가 소환되어야 한다")
	for s: MonsterBase in spawned:
		assert_true(captain.wave_summon_pool.has(s.monster_id), "wave_summon_pool 소속 종만 소환되어야 한다")
		assert_eq(s.state, MonsterBase.State.CHASE, "소환 즉시 플레이어를 추격해야 한다")
