## 뭉치의 새끼(elite_bunchi_spawn) 사망 시 분열(§1-3, on_death_split_*) + 정예 공통
## 처치 신호(Events.elite_died) 테스트. 실제 MonsterBase._on_hurtbox_hurt()를 직접
## 호출해 치사량 피해를 주는 방식은 test_monster_recover_state.gd와 동일한 관례다.
##
## 분열로 스폰되는 slime은 _spawn_death_split()이 add_child()로 직접 붙이므로(GUT의
## add_child_autofree 경유가 아님) 반드시 autofree()로 등록해야 한다 — queue_free()는
## 지연 삭제라 다음 테스트 함수 시작 전에 정리된다는 보장이 없어(GUT는 add_free 계열만
## 테스트 하나가 끝날 때마다 즉시 free() 처리) 이전 테스트의 분열체가 다음 테스트의
## get_children() 결과에 섞여 들어가는 오염이 실제로 발생했다(디버깅 세션에서 확인).
extends GutTest

const EliteBunchiScene := preload("res://scenes/entities/monsters/EliteBunchiSpawn.tscn")
const HitboxScript := preload("res://scripts/systems/hitbox.gd")


func _make_bunchi() -> MonsterBase:
	var m: MonsterBase = EliteBunchiScene.instantiate()
	add_child_autofree(m)
	return m


func _kill(monster: MonsterBase) -> void:
	var hb: Hitbox = HitboxScript.new()
	add_child_autofree(hb)
	hb.damage = monster.hp + 999 # 확실한 즉사.
	monster._on_hurtbox_hurt(hb)


## 분열로 새로 생긴 MonsterBase 자식들을 찾아 autofree() 등록까지 한 번에 한다.
func _split_children_of(parent: Node, exclude: Node) -> Array:
	var out: Array = []
	for child in parent.get_children():
		if child is MonsterBase and child != exclude:
			autofree(child)
			out.append(child)
	return out


func test_death_spawns_two_slimes() -> void:
	var bunchi := _make_bunchi()
	var parent := bunchi.get_parent()

	_kill(bunchi)

	var slimes: Array = _split_children_of(parent, bunchi)
	assert_eq(slimes.size(), 2, "on_death_split_count=2 (elite-and-farming-m2.md §1-3)")
	for s in slimes:
		assert_eq((s as MonsterBase).monster_id, "slime")


func test_split_spawns_suppress_loot_and_do_not_recursively_split() -> void:
	var bunchi := _make_bunchi()
	var parent := bunchi.get_parent()

	_kill(bunchi)

	var slimes: Array = _split_children_of(parent, bunchi)
	for s: MonsterBase in slimes:
		assert_true(s.suppress_loot_drop, "분열체는 드랍 없음 — 부모가 드랍(§1-3)")
		assert_eq(s.on_death_split_monster_id, "",
			"slime 데이터엔 on_death_split_monster_id가 없어 재귀 분열이 데이터상 불가능해야 한다")


func test_split_offsets_are_within_spawn_radius_and_not_overlapping() -> void:
	var bunchi := _make_bunchi()
	var parent := bunchi.get_parent()
	var center: Vector2 = bunchi.global_position

	_kill(bunchi)

	var slimes: Array = _split_children_of(parent, bunchi)
	assert_eq(slimes.size(), 2)
	for s: MonsterBase in slimes:
		assert_true(s.global_position.distance_to(center) <= bunchi.on_death_split_spawn_radius_px + 0.5,
			"on_death_split_spawn_radius_px(24px) 반경 안에 스폰되어야 한다")
	if slimes.size() == 2:
		assert_true((slimes[0] as MonsterBase).global_position.distance_to((slimes[1] as MonsterBase).global_position) > 0.5,
			"두 분열체가 같은 자리에 겹쳐 스폰되면 안 된다")


func test_parent_normal_slime_has_no_split_fields_so_it_cannot_split_again() -> void:
	# 재귀 방지의 데이터 측 근거: 부모(elite_bunchi_spawn)와 달리 일반 slime 엔트리에는
	# on_death_split_* 필드가 아예 없다(§1-3 "데이터 상으로 안전").
	var entry: Dictionary = Data.get_value("monsters", "slime", {})
	assert_false(entry.has("on_death_split_monster_id"))


func test_death_emits_enemy_died_and_elite_died() -> void:
	var bunchi := _make_bunchi()
	var saw_enemy_died := [false]
	var saw_elite_died := [false]
	var on_enemy := func(e: Node2D, _k: Node) -> void:
		if e == bunchi:
			saw_enemy_died[0] = true
	var on_elite := func(e: Node2D, _k: Node) -> void:
		if e == bunchi:
			saw_elite_died[0] = true
	Events.enemy_died.connect(on_enemy)
	Events.elite_died.connect(on_elite)

	_kill(bunchi)

	assert_true(saw_enemy_died[0], "정예도 일반 처치 신호(enemy_died)를 그대로 내야 한다")
	assert_true(saw_elite_died[0], "정예 전용 신호(elite_died)도 함께 내야 한다(F6-3)")

	Events.enemy_died.disconnect(on_enemy)
	Events.elite_died.disconnect(on_elite)
	_split_children_of(bunchi.get_parent(), bunchi)
