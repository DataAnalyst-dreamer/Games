## 헤드리스 스모크: 성장 시스템 v2 배선(M4-4, D-167~D-174/D-184~D-194).
## 스탯 분배(체증 비용) -> 파생치가 실제 플레이 값(이동속도·구르기 무적·콤보 프레임·
## 히트박스)에 반영 -> SP 소모/회복 -> 스킬 노드 레벨업 -> 레벨별 수치로 시전까지를
## 실제 Main.tscn에서 확인한다(순수 계산은 test_stat_calc/test_skill_calc/
## test_progression_v2가 커버 — 여기는 배선만 본다).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeProgressionV2.tscn --quit-after 900
extends Node

const SKILL_ID := "blade_power_slash"

var _player: Player
var _dummy: MonsterBase
var _fail_count: int = 0


func _ready() -> void:
	print("=== SMOKE PROGRESSION V2: 6스탯 + SP + 스킬 레벨 ===")
	var main: Node = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	_player = main.get_node("Player") as Player
	_dummy = main.get_node("Slime3") as MonsterBase
	_dummy.set_physics_process(false)
	_dummy.hp = 99999
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_dummy.global_position = _player.global_position + Vector2(12, 0)

	_check_stat_cost_curve()
	_check_agi_effects()
	_check_dex_effects()
	_check_int_sp_pool()
	await _check_sp_spend_and_regen()
	await _check_skill_level_up_changes_cast()

	print("=== SMOKE PROGRESSION V2 종료: %s ===" % ("FAIL(%d)" % _fail_count if _fail_count > 0 else "ALL PASS"))
	get_tree().quit(1 if _fail_count > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _allocate(key: String, times: int) -> void:
	for i in range(times):
		GameState.stat_points += Progression.next_stat_cost(key)
		Progression.allocate_stat(key)


## §2: 0~9구간 1p, 10~19구간 2p. 포인트가 모자라면 분배 자체가 실패해야 한다.
func _check_stat_cost_curve() -> void:
	GameState.stats["luk"] = 0
	GameState.stat_points = 10
	for i in 10:
		Progression.allocate_stat("luk")
	_check(GameState.stats["luk"] == 10 and GameState.stat_points == 0,
		"LUK 0->10에 10p 소모(0~9 구간 1p씩): luk=%d, 잔여=%d" % [GameState.stats["luk"], GameState.stat_points])
	GameState.stat_points = 1
	_check(not Progression.allocate_stat("luk") and GameState.stats["luk"] == 10,
		"10->11 비용은 2p — 1p만 있으면 분배 실패(체증 곡선)")
	GameState.stat_points = 0


## D-168: AGI가 이동속도와 구르기 무적 시간을 실제로 바꾼다.
func _check_agi_effects() -> void:
	var speed_before: float = _player.walk_speed
	var iframe_before: float = Progression.get_derived()["roll_iframe_bonus"]
	_allocate("agi", 40)
	GameState.recompute_player_stats()
	var speed_after: float = _player.walk_speed
	var iframe_after: float = Progression.get_derived()["roll_iframe_bonus"]
	_check(speed_after > speed_before, "AGI 40분배: walk_speed %.1f -> %.1f (상승)" % [speed_before, speed_after])
	_check(iframe_after > iframe_before,
		"AGI 40분배: 구르기 무적 가산 %.3fs -> %.3fs" % [iframe_before, iframe_after])
	_check(Progression.get_derived()["combo_frame_mult"] < 1.0,
		"AGI: 콤보 프레임 배율 %.4f < 1.0 (공격이 빨라짐)" % Progression.get_derived()["combo_frame_mult"])


## D-168: DEX가 히트박스 배율과 후딜 배율을 바꾸고, 기본 공격 Hitbox에 실제로 곱해진 뒤
## deactivate()에서 원래 크기로 복원된다(D-191).
func _check_dex_effects() -> void:
	_allocate("dex", 40)
	var scale_mult: float = Progression.get_derived()["hitbox_scale"]
	_check(scale_mult > 1.0, "DEX 40분배: 히트박스 배율 %.4f > 1.0" % scale_mult)
	_check(Progression.get_derived()["post_recovery_mult"] < 1.0,
		"DEX: 후딜 배율 %.4f < 1.0 (모션 잠금 단축)" % Progression.get_derived()["post_recovery_mult"])

	var hitbox := _player.hitbox
	hitbox.apply_scale_mult(scale_mult)
	_check(is_equal_approx(hitbox.scale.x, scale_mult), "Hitbox.scale에 배율 적용: %.4f" % hitbox.scale.x)
	hitbox.deactivate()
	_check(is_equal_approx(hitbox.scale.x, 1.0), "deactivate()에서 원본 크기로 복원(강제 전이 안전, D-191)")


## §3: max_sp = 20 + INT*2.
func _check_int_sp_pool() -> void:
	var before: float = Progression.max_sp()
	_allocate("int", 10)
	var after: float = Progression.max_sp()
	_check(is_equal_approx(after, before + 20.0), "INT 10분배: max_sp %.0f -> %.0f (+20)" % [before, after])


## SP 소모 -> Events.sp_changed 발신 -> 시간이 지나면 회복.
func _check_sp_spend_and_regen() -> void:
	Progression.refill_sp()
	var seen: Array = []
	var cb := func(current: float, max_value: float) -> void: seen.append([current, max_value])
	Events.sp_changed.connect(cb)
	var before: float = GameState.sp
	var ok: bool = Progression.spend_sp(15.0)
	_check(ok and is_equal_approx(GameState.sp, before - 15.0),
		"SP 15 소모: %.1f -> %.1f" % [before, GameState.sp])
	_check(not seen.is_empty(), "Events.sp_changed 발신(HUD SP바 구독 지점)")
	var after_spend: float = GameState.sp
	await get_tree().create_timer(1.0).timeout
	Events.sp_changed.disconnect(cb)
	_check(GameState.sp > after_spend, "1초 경과 후 SP 회복: %.2f -> %.2f" % [after_spend, GameState.sp])


func _press_action(action: String) -> void:
	var evt := InputEventAction.new()
	evt.action = action
	evt.pressed = true
	_player.state_machine.handle_input(evt)


## 노드 레벨업 -> levels[] 값(sp_cost/damage_mult/cooldown_sec)이 실제 시전에 쓰인다.
func _check_skill_level_up_changes_cast() -> void:
	GameState.skill_points += 3
	_check(Progression.learn_skill(SKILL_ID) and Progression.get_skill_level(SKILL_ID) == 1,
		"스킬 습득 -> 레벨 1")
	var lv1: Dictionary = Progression.skill_level_data(SKILL_ID)
	_check(Progression.learn_skill(SKILL_ID) and Progression.get_skill_level(SKILL_ID) == 2,
		"같은 노드 재투자 -> 레벨 2(D-170)")
	var lv2: Dictionary = Progression.skill_level_data(SKILL_ID)
	_check(float(lv2["damage_mult"]) > float(lv1["damage_mult"]) and float(lv2["sp_cost"]) > float(lv1["sp_cost"]),
		"레벨 2 수치: dmg %.1f->%.1f, sp %.0f->%.0f" \
			% [lv1["damage_mult"], lv2["damage_mult"], lv1["sp_cost"], lv2["sp_cost"]])
	_check(bool(Progression.can_learn_skill("blade_followup").get("reason") == &"requires"),
		"선행 Lv3 미달이면 상위 노드는 reason=requires(D-194)")

	Progression.assign_hotbar(0, "skill", SKILL_ID)
	Progression.refill_sp()
	var sp_before: float = GameState.sp
	var hp_before: int = _dummy.hp
	_press_action("hotbar_1")
	await get_tree().create_timer(Tuning.SKILL_ANTICIPATION_SEC).timeout
	for i in 6:
		await get_tree().physics_frame
	var dealt: int = hp_before - _dummy.hp
	var expected: int = SkillCalc.damage_for(lv2, _player.get_attack_power())
	_check(dealt >= expected, "레벨 2 배율로 시전: 데미지 %d (기대 %d 이상, 크리 시 더 큼)" % [dealt, expected])
	# 시전~판정 사이에도 SP 회복이 계속 돌기 때문에(§3) 정확히 sp_cost만큼 줄지는 않는다 —
	# "소모는 있었고, 회복분을 감안해도 sp_cost에 근접"까지만 본다.
	var dropped: float = sp_before - GameState.sp
	_check(dropped <= float(lv2["sp_cost"]) + 0.01 and dropped >= float(lv2["sp_cost"]) - 2.0,
		"레벨 2의 sp_cost(%.0f)만큼 SP 소모(관측 %.2f, 회복분 감안)" % [float(lv2["sp_cost"]), dropped])
	_check(not Progression.can_cast_skill(0), "쿨타임 중에는 재시전 불가")
