## 헤드리스 스모크 테스트: M3-3/M4-4 "6스탯 실제 적용 + 스탯 분배 + 스킬 배우기/장착/시전/쿨타임".
## GameState.stats/learned_skills/skill_slots <-> Progression.allocate_stat()/get_derived()/
## learn_skill()/assign_hotbar()/can_cast_skill()/roll_crit() <-> 실제 Player/Hitbox/Events
## 배선 전체를 실제 Main.tscn(Slime3 더미)으로 확인한다(단위 계산은 test_stat_calc.gd/
## test_skill_calc.gd가 순수 로직으로 커버 — 이 스모크는 배선만 본다).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeStatsSkills.tscn --quit-after 900
extends Node

var _player: Player
var _dummy: MonsterBase
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE STATS/SKILLS: 스탯 분배 + 스킬 배우기/장착/시전/쿨타임 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = scene.instantiate()
	add_child(main)

	_player = main.get_node("Player") as Player
	_dummy = main.get_node("Slime3") as MonsterBase
	_dummy.set_physics_process(false)
	_dummy.hp = 99999
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_dummy.global_position = _player.global_position + Vector2(12, 0)

	_check_str_attack()
	_check_vit_max_hp()
	_check_dex_roll_cost()
	_check_defense()
	await _check_skill_cast_and_cooldown()
	_check_int_cooldown_mult()
	await _check_luk_crit()

	print("=== SMOKE STATS/SKILLS 종료: %s ===" % ("FAIL(%d)" % _fail_count if _fail_count > 0 else "ALL PASS"))
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


## M4-4(§2): 상승 비용이 체증하므로 "N번 올리기"에 필요한 포인트를 넉넉히 지급한 뒤
## 실제 분배 횟수만 센다(단위 검증은 test_progression_v2.gd 몫, 여기는 배선만 본다).
func _allocate(key: String, times: int) -> void:
	for i in range(times):
		GameState.stat_points += Progression.next_stat_cost(key)
		Progression.allocate_stat(key)


func _check_str_attack() -> void:
	var before: float = _player.get_attack_power()
	_allocate("str", 5)
	var after: float = _player.get_attack_power()
	var per_point: float = float(Data.get_value("stats", "str.physical_damage_per_point", 0.2))
	_check(is_equal_approx(after, before + 5.0 * per_point),
		"STR 5분배: 공격력 %.2f -> %.2f (기대 +%.2f)" % [before, after, 5.0 * per_point])


func _check_vit_max_hp() -> void:
	var before: int = _player.resources.max_hp
	_allocate("vit", 5)
	var after: int = _player.resources.max_hp
	var per_point: float = float(Data.get_value("stats", "vit.hp_per_point", 5.0))
	_check(after == before + int(5.0 * per_point),
		"VIT 5분배: 최대HP %d -> %d (기대 +%.0f)" % [before, after, 5.0 * per_point])


func _check_dex_roll_cost() -> void:
	var before: float = _player.get_roll_cost()
	_allocate("dex", 10)
	var after: float = _player.get_roll_cost()
	_check(after < before, "DEX 10분배: 구르기 비용 %.2f -> %.2f (감소해야 함)" % [before, after])


## D-162(a): VIT 분배분 + 장비 방어력이 damage_after_defense 공식으로 실제 피해에
## 반영되는지 hit_feel.gd:apply()를 직접 호출해 확인한다(몬스터 AI 타이밍에 의존하지 않음).
func _check_defense() -> void:
	var fake_source := Node2D.new()
	add_child(fake_source)
	fake_source.global_position = _player.global_position - Vector2(10, 0)
	var fake_hit := Hitbox.new()
	fake_hit.damage = 100
	fake_hit.source = fake_source
	fake_hit.knockback_px = 0.0
	fake_hit.hitstop_sec = 0.0

	var defense: float = float(Progression.get_derived().get("defense", 0.0))
	var expected: int = StatCalc.damage_after_defense(100.0, defense)
	var actual: int = HitFeel.apply(_player, _player.sprite, fake_hit)
	_check(actual == expected and actual < 100,
		"VIT 방어력=%.1f 적용: 100 피해 -> %d (기대 %d)" % [defense, actual, expected])
	fake_source.queue_free()


func _press_action(action: String) -> void:
	var evt := InputEventAction.new()
	evt.action = action
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


## 스킬 배우기(D-159) -> 핫바 슬롯0 배정(M4-1, D-175~D-177) -> hotbar_1 시전 -> 실제
## 히트박스 데미지 배율 확인 -> Events.skill_cast/skill_ready + Progression.can_cast_skill()
## 쿨타임 왕복.
func _check_skill_cast_and_cooldown() -> void:
	const SKILL_ID := "blade_power_slash"
	GameState.skill_points += 1
	var learned: bool = Progression.learn_skill(SKILL_ID)
	var equipped: bool = Progression.assign_hotbar(0, "skill", SKILL_ID)
	_check(learned and equipped and GameState.skill_slots[0] == SKILL_ID,
		"스킬 배우기+핫바 슬롯0 배정: %s" % SKILL_ID)

	# M4-4(D-170): 수치는 현재 습득 레벨의 levels[] 항목에서 읽는다.
	var entry: Dictionary = Progression.skill_level_data(SKILL_ID)
	var sp_before: float = GameState.sp
	var expected_base: int = SkillCalc.damage_for(entry, _player.get_attack_power())
	var hp_before: int = _dummy.hp

	var cast_events: Array = []
	var cb := func(slot: int, id: String, cd: float) -> void: cast_events.append([slot, id, cd])
	Events.skill_cast.connect(cb)
	_press_action("hotbar_1")
	# M4-3: skill.gd가 Tuning.SKILL_ANTICIPATION_SEC만큼 선딜 지연 후에야 히트박스를
	# activate()한다 — 그 시간만큼 먼저 기다린 뒤, activate()의 call_deferred + area
	# 재판정이 반영될 여유(6프레임)를 추가로 준다.
	await get_tree().create_timer(Tuning.SKILL_ANTICIPATION_SEC).timeout
	await _wait_frames(6)
	Events.skill_cast.disconnect(cb)

	var dealt: int = hp_before - _dummy.hp
	_check(dealt >= expected_base and dealt <= int(round(expected_base * 1.5)),
		"스킬 히트박스 데미지: %d (기대 %d~%d, damage_mult=%.1f)" \
			% [dealt, expected_base, int(round(expected_base * 1.5)), float(entry.get("damage_mult", 0.0))])

	_check(cast_events.size() == 1, "Events.skill_cast 1회 발신")
	if not cast_events.is_empty():
		var ev: Array = cast_events[0]
		_check(int(ev[0]) == 0 and String(ev[1]) == SKILL_ID and is_equal_approx(float(ev[2]), float(entry.get("cooldown_sec", 0.0))),
			"skill_cast 페이로드=%s (기대 slot=0 id=%s cd=%.1f, INT=0이라 배율 없음)" \
				% [str(ev), SKILL_ID, float(entry.get("cooldown_sec", 0.0))])

	_check(not Progression.can_cast_skill(0), "시전 직후 쿨타임 중이라 재시전 불가")
	# 대기 중에도 SP 회복이 돌므로(§3) 관측 감소량은 sp_cost보다 약간 작을 수 있다.
	var sp_dropped: float = sp_before - GameState.sp
	var sp_cost: float = float(entry.get("sp_cost", 0.0))
	_check(sp_dropped <= sp_cost + 0.01 and sp_dropped >= sp_cost - 2.0,
		"SP 소모 %.2f (기대 sp_cost=%.1f, 스태미나가 아니라 SP — D-169)" % [sp_dropped, sp_cost])

	var ready_slots: Array = []
	var ready_cb := func(slot: int) -> void: ready_slots.append(slot)
	Events.skill_ready.connect(ready_cb)
	await get_tree().create_timer(float(entry.get("cooldown_sec", 0.0)) + 0.2).timeout
	Events.skill_ready.disconnect(ready_cb)
	_check(ready_slots.has(0), "쿨타임 만료 -> Events.skill_ready(0) 발신")
	_check(Progression.can_cast_skill(0), "쿨타임 만료 후 재시전 가능")


func _check_int_cooldown_mult() -> void:
	_allocate("int", 200) # cap(0.30) 확실히 도달할 만큼 과분배.
	var mult: float = float(Progression.get_derived().get("cooldown_mult", 1.0))
	var cap: float = float(Data.get_value("stats", "int.cooldown_reduction_cap_pct", 0.30))
	_check(is_equal_approx(mult, 1.0 - cap), "INT 200분배: cooldown_mult=%.3f (cap 도달 기대 %.3f)" % [mult, 1.0 - cap])


## LUK을 상한까지 분배한 뒤 Attack 상태의 _fire_hitbox()를 직접 여러 번 호출해(콤보
## 입력 버퍼/유예창 타이밍에 좌우되지 않는 결정적 반복) hitbox.is_critical이 최소 한
## 번은 뜨는지 확인한다(cap=75%이면 15회 무실패 확률은 0.25^15 ≈ 사실상 0).
func _check_luk_crit() -> void:
	_allocate("luk", 800) # cap(0.75) 확실히 도달할 만큼 과분배.
	var cap: float = float(Data.get_value("stats", "luk.crit_chance_cap", 0.75))
	var chance: float = float(Progression.get_derived().get("crit_chance", 0.0))
	_check(is_equal_approx(chance, cap), "LUK 800분배: crit_chance=%.3f (cap 도달 기대 %.3f)" % [chance, cap])

	var saw_crit: bool = false
	var trials: int = 0
	var attack_state = _player.state_machine.states.get(&"Attack")
	_player.state_machine.transition_to(&"Idle", {})
	await _wait_frames(2)
	while not saw_crit and trials < 15:
		_player.state_machine.transition_to(&"Attack", {})
		await _wait_frames(2) # activate()의 call_deferred 재판정이 반영될 시간.
		saw_crit = attack_state.player.hitbox.is_critical
		trials += 1
		_player.state_machine.transition_to(&"Idle", {})
		await _wait_frames(1)
	_check(saw_crit, "LUK cap(75%%)에서 %d회 이내 진짜 크리티컬(is_critical=true) 관측" % trials)
