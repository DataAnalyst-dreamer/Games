## 헤드리스 스모크 테스트: "슬라임 처치 → Events.exp_changed 발신 → 누적 경험치로
## Events.level_up 발신 → 레벨업 자동 상승분 반영(HP 전량 회복 포함)"(M3-1, F1-2).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeExpLevel.tscn --quit-after 400
##
## 1단계(실제 전투 경로): 플레이어가 Main.tscn의 Slime1을 실제로 공격해 죽여
## (monster_base.gd가 Events.enemy_died를 실발신) Progression이 exp_reward_for_monster
## ("slime")=5를 지급해 Events.exp_changed(5, 20, 1)를 쏘는지 확인한다(smoke_player_
## kills_slime.gd와 동일한 입력 폴링 관례).
## 2단계: 슬라임 3마리분(5×3=15, 누적 20 = 레벨1→2 정확한 임계치, D-148 설계 의도)을
## Progression.grant_exp()로 추가 지급해(장면에 몬스터를 여러 마리 스폰하는 건 이
## 스모크 범위 밖) Events.level_up(2, {...})과 HP/스태미나 전량 회복(D-151)을 확인한다.
extends Node

var _main: Node
var _player: Player
var _slime: MonsterBase

var _pass_count: int = 0
var _fail_count: int = 0

var _exp_changed_log: Array[Dictionary] = []
var _level_up_log: Array[Dictionary] = []

var _elapsed: float = 0.0
var _target_hit: int = 0
const OFFSET := Vector2(12, 0)


func _ready() -> void:
	print("=== SMOKE EXP/LEVEL: 슬라임 처치 -> exp_changed -> 레벨업 ===")
	# 다른 스모크/이전 세션 상태가 남아있지 않도록 명시적으로 초기화(이 프로세스는
	# 매번 새로 뜨므로 사실상 기본값과 같지만, 의도를 코드로 남긴다).
	GameState.level = 1
	GameState.exp = 0
	GameState.stat_points = 0
	GameState.skill_points = 0
	GameState.level_stat_bonus = {"max_hp": 0, "attack": 0.0}

	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_player = _main.get_node("Player") as Player
	_slime = _main.get_node("Slime1") as MonsterBase
	_slime.set_physics_process(false) # AI/반격 배제 — 순수 피격 파이프라인만 본다.
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_slime.global_position = _player.global_position + OFFSET

	Events.exp_changed.connect(_on_exp_changed)
	Events.level_up.connect(_on_level_up)

	print("[설정] slime.exp_reward=%d, 레벨1->2 필요 경험치=%d" \
		% [Progression.exp_reward_for_monster(&"slime"), Progression.exp_for_level(1)])
	print("[설정] 초기 max_hp=%d max_stamina=%.1f" % [_player.resources.max_hp, _player.resources.max_stamina])

	_press_attack()
	print("[1] t=%.3f 1타 입력" % _elapsed)
	_target_hit = 2


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_slime) and _slime.hp > 0:
		_slime.global_position = _player.global_position + OFFSET

	var attack_state = _player.state_machine.states.get(&"Attack")
	if attack_state != null and attack_state.combo != null and _player.state_machine.current_state == attack_state:
		var combo: ComboState = attack_state.combo
		if _target_hit > 0 and _target_hit <= combo.max_hits and combo.hit_index == _target_hit - 1 \
				and (combo.is_in_buffer_window() or combo.is_in_grace_window()):
			_press_attack()
			print("[1] t=%.3f %d타 입력(HP=%d)" % [_elapsed, _target_hit, _slime.hp])
			_target_hit += 1

	if _elapsed > 5.0 and _exp_changed_log.is_empty():
		_check("5초 내 실전투 처치로 exp_changed 발신", false)
		_finish()


func _press_attack() -> void:
	var evt := InputEventAction.new()
	evt.action = "attack"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _on_exp_changed(current_exp: int, exp_to_next: int, level: int) -> void:
	_exp_changed_log.append({"exp": current_exp, "exp_to_next": exp_to_next, "level": level})
	print("[exp_changed #%d] exp=%d exp_to_next=%d level=%d" % [_exp_changed_log.size(), current_exp, exp_to_next, level])
	if _exp_changed_log.size() == 1:
		_check("실전투 슬라임 처치 1회 -> exp_changed(5, 20, 1)", current_exp == 5 and exp_to_next == 20 and level == 1)
		_continue_with_direct_grants()


func _on_level_up(new_level: int, stat_gains: Dictionary) -> void:
	_level_up_log.append({"level": new_level, "stat_gains": stat_gains})
	print("[level_up] new_level=%d stat_gains=%s" % [new_level, stat_gains])


func _continue_with_direct_grants() -> void:
	# 슬라임 3마리분을 더 지급(5*3=15) — 누적 5+15=20 = 레벨1->2 임계치와 정확히 일치.
	for _i in 3:
		Progression.grant_exp(Progression.exp_reward_for_monster(&"slime"))
	await get_tree().process_frame

	_check("level_up 시그널 정확히 1회 수신", _level_up_log.size() == 1)
	if not _level_up_log.is_empty():
		var gains: Dictionary = _level_up_log[0].get("stat_gains", {})
		_check("level_up(2, {...}) 수신", int(_level_up_log[0].get("level", 0)) == 2)
		_check("stat_gains에 max_hp/attack 포함", gains.has("max_hp") and gains.has("attack"))
		# M4-4(UI 합의): 레벨업 배너가 읽도록 지급량 2키가 payload에 실린다.
		_check("stat_gains에 stat_points/skill_points 포함(%s)" % [gains],
			int(gains.get("stat_points", -1)) == 2 and int(gains.get("skill_points", -1)) == 1)
	_check("GameState.level == 2", GameState.level == 2)
	_check("GameState.exp == 0(정확히 소진, 잔여 없음)", GameState.exp == 0)
	# M4-4(§2): 레벨업 지급량은 exp_curve.csv.stat_points_gain — 레벨 2 구간은 2점(구 고정값 3 폐기).
	_check("stat_points +2 누적(exp_curve.csv stat_points_gain)", GameState.stat_points == 2)
	_check("skill_points +1 누적", GameState.skill_points == 1)
	_check("HP 전량 회복(max_hp=%d)" % _player.resources.max_hp, _player.resources.hp == _player.resources.max_hp)
	_check("스태미나 전량 회복", _player.resources.stamina == _player.resources.max_stamina)
	_check("장비 재계산 후에도 레벨 HP 보너스 유지", _player.resources.max_hp == Tuning.PLAYER_MAX_HP + 8)
	print("[exp_changed 최종] %s" % [_exp_changed_log[-1]])
	_check("마지막 exp_changed도 level=2와 일치", int(_exp_changed_log[-1].get("level", -1)) == 2)
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % label)
	else:
		_fail_count += 1
		print("[FAIL] %s" % label)


func _finish() -> void:
	print("=== SMOKE EXP/LEVEL 종료: PASS=%d FAIL=%d ===" % [_pass_count, _fail_count])
	get_tree().quit(0 if _fail_count == 0 else 1)
