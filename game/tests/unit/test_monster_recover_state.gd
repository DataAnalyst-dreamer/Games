## QA 리뷰 Major-1 회귀 방지 테스트(docs/qa/review-m1-1-m1-2.md).
## 예전에는 _process_attack()이 _enter_state()를 우회해 state를 직접 대입했다 — 그 결과
## ①CHASE로 갈 때 attack_recovery_sec이 완전히 죽은 값이 됐고 ②IDLE로 갈 때는
## MONSTER_PATROL_PAUSE_SEC 대신 attack_recovery_sec이 새어나갔다. 이제는 ATTACK 종료 시
## 반드시 RECOVER 상태를 거치고, RECOVER가 끝나야 비로소 CHASE/IDLE로 (각 상태 고유의
## _enter_state() 초기화를 받으며) 전이한다.
extends GutTest

const SlimeScene := preload("res://scenes/entities/monsters/Slime.tscn")


func _make_slime() -> MonsterBase:
	var slime: MonsterBase = SlimeScene.instantiate()
	add_child_autofree(slime)
	return slime


func test_attack_end_transitions_to_recover_not_directly_to_chase_or_idle() -> void:
	var slime := _make_slime()
	slime._enter_state(MonsterBase.State.ATTACK)
	assert_eq(slime.state, MonsterBase.State.ATTACK)

	slime._state_timer = 0.0
	slime._physics_process(0.001)

	assert_eq(slime.state, MonsterBase.State.RECOVER,
		"ATTACK 종료 직후 CHASE/IDLE로 직행하지 않고 RECOVER를 거쳐야 한다")
	assert_almost_eq(slime._state_timer, slime.attack_recovery_sec, 0.0001,
		"RECOVER 타이머는 monsters.json.attack_recovery_sec이어야 한다(예전엔 이 값이 죽은 값이었음)")


func test_recover_end_enters_idle_via_enter_state_with_correct_patrol_pause_timer() -> void:
	var slime := _make_slime()
	slime._enter_state(MonsterBase.State.RECOVER)
	assert_almost_eq(slime._state_timer, slime.attack_recovery_sec, 0.0001)

	slime._state_timer = 0.0
	slime._physics_process(0.001)

	assert_eq(slime.state, MonsterBase.State.IDLE,
		"플레이어가 없으면 RECOVER 종료 후 IDLE로 전이해야 한다")
	assert_almost_eq(slime._state_timer, Tuning.MONSTER_PATROL_PAUSE_SEC, 0.0001,
		"IDLE은 _enter_state()를 거쳐야 하므로 MONSTER_PATROL_PAUSE_SEC이어야 한다 " \
		+ "(예전엔 attack_recovery_sec이 새어나가 순찰 재개가 3배 빨라졌었다)")


func test_recover_duration_matches_species_specific_attack_recovery_sec() -> void:
	# 슬라임(0.4s)과 뿔토끼(0.7s)가 서로 다른 attack_recovery_sec을 쓰는지 회귀 확인.
	var slime := _make_slime()
	slime._enter_state(MonsterBase.State.RECOVER)
	assert_almost_eq(slime._state_timer, 0.4, 0.0001)

	var rabbit_scene: PackedScene = load("res://scenes/entities/monsters/HornRabbit.tscn")
	var rabbit: MonsterBase = rabbit_scene.instantiate()
	add_child_autofree(rabbit)
	rabbit._enter_state(MonsterBase.State.RECOVER)
	assert_almost_eq(rabbit._state_timer, 0.7, 0.0001)
