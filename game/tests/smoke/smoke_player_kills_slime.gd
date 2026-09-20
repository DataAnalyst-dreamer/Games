## 헤드리스 스모크 테스트: "플레이어 공격 → 슬라임 피격 → HP 감소 → 사망 → enemy_died 발신".
##
## 실행: godot --headless --path game res://tests/smoke/SmokePlayerKillsSlime.tscn --quit-after 400
## (SceneTree 커스텀 -s 스크립트는 프로젝트 오토로드(Data/Events/Tuning)를 초기화하지
## 않아 대신 이 스크립트를 씬 루트로 직접 실행한다 — 오토로드가 정상 초기화된다.)
##
## 입력 타이밍은 고정 시각이 아니라 ComboState의 실제 버퍼/유예 구간을 매 프레임
## 폴링해 반응적으로 누른다 — 히트스톱이 피격자·공격자 모두를 잠깐 정지시키므로
## (F2-2, scripts/systems/hitstop.gd) 벽시계 기준 고정 타이밍은 프레임마다 드리프트될
## 수 있기 때문이다.
##
## 시나리오 A(Slime1, monsters.json 실측치): 슬라임 HP=18, 콤보 배율 [1.0,1.0,1.5] ×
## PLAYER_BASE_ATTACK=10 → 히트당 [10,10,15], 누적 [10,20] → combat-tuning-m1.md §8-2
## 스펙대로 "2타"만에 사망해야 정상이다(즉시 성공 경험을 주는 튜토리얼 몬스터 설계 의도).
##
## 시나리오 B(Slime2, HP를 스크립트에서 임시로 부풀림): 3타 콤보 전체(입력 버퍼 체이닝 →
## 피니셔 배율 1.5×)가 정상적으로 동작하는지 별도로 확인한다(monsters.json은 그대로 두고
## 검증용 인스턴스의 hp 필드만 조작).
##
## 결정성: Progression.roll_crit()은 시드 없는 randf()로 LUK 크리티컬(base 5%)을 굴리므로
## 그대로 두면 시나리오 B의 "기대 HP=964" 검사가 약 14% 확률(3타 중 1타라도 크리)로
## 실패하는 플레이크가 된다(실측: 3타 크리 → 964 대신 956). 이 테스트는 콤보 배율만
## 검증하므로 _ready()에서 메모리상 stats 테이블의 base_crit_chance를 0으로 덮어써
## 크리를 끈다(stats.json 파일은 건드리지 않음, LUK=0이라 per_point 항도 0). 고정 seed()
## 방식은 3타 전에 다른 시스템이 randf()를 몇 번 부르느냐에 따라 결과가 바뀌어 채택하지
## 않았다. 크리 자체의 동작은 smoke_stats_skills.gd(_check_luk_crit)가 따로 검증한다.
extends Node

var _main: Node
var _player: Player
var _slime_a: MonsterBase
var _slime_b: MonsterBase

var _elapsed: float = 0.0
var _scenario: String = "a"
var _scenario_a_done: bool = false
## 다음에 도달해야 할 히트 번호(예: 2면 "2타가 되도록 입력을 누른다"). 0이면 아직
## 1타조차 시작 안 함.
var _target_hit: int = 0

## D-127 회귀 확인: 시나리오 B(3타 콤보 완주) 종료 후 공격 상태를 실제로 벗어날
## 때까지(또는 타임아웃까지) weapon_pivot.visible을 폴링한다.
var _b_combo_checked: bool = false
var _weapon_check_deadline: float = -1.0

const OFFSET := Vector2(12, 0) ## 플레이어 기준 대상 위치(오른쪽, 사거리 안).


func _ready() -> void:
	print("=== SMOKE A/B: 플레이어 공격 → 슬라임 피격/사망 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_slime_a = _main.get_node("Slime1") as MonsterBase
	_slime_b = _main.get_node("Slime2") as MonsterBase

	# 두 시나리오 모두 "몬스터가 스스로 반격/이동"하는 변수를 배제하고 오직 피격 반응만
	# 본다 — AI(추적/공격)는 꺼서 히트박스/허트박스/데미지 파이프라인만 검증한다.
	_slime_a.set_physics_process(false)
	_slime_b.set_physics_process(false)
	_slime_b.hp = 999 # 3타 전체를 관찰하기 위한 테스트 전용 임시 HP(실제 데이터 아님).
	_disable_crit()
	_slime_b.global_position = Vector2(500, 500) # 시나리오 A와 공간적으로 완전히 분리.

	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_slime_a.global_position = _player.global_position + OFFSET

	print("[A] 슬라임 초기 HP=%d (monsters.json 기준, TTK 목표 2타)" % _slime_a.hp)
	print("[B] 콤보 검증용 슬라임 임시 HP=%d" % _slime_b.hp)

	Events.enemy_died.connect(_on_enemy_died)

	_press_attack()
	print("[A] t=%.3f 1타 입력(플레이어 → 슬라임A)" % _elapsed)
	_target_hit = 2


func _process(delta: float) -> void:
	_elapsed += delta

	var target_slime: MonsterBase = _slime_a if _scenario == "a" else _slime_b
	if is_instance_valid(target_slime) and target_slime.hp > 0:
		target_slime.global_position = _player.global_position + OFFSET

	var attack_state = _player.state_machine.states.get(&"Attack")
	if attack_state != null and attack_state.combo != null and _player.state_machine.current_state == attack_state:
		var combo: ComboState = attack_state.combo
		if _target_hit > 0 and _target_hit <= combo.max_hits and combo.hit_index == _target_hit - 1 \
				and (combo.is_in_buffer_window() or combo.is_in_grace_window()):
			_press_attack()
			print("[%s] t=%.3f %d타 입력 발사 (HP=%d)" \
				% [_scenario.to_upper(), _elapsed, _target_hit, target_slime.hp])
			_target_hit += 1

	if _scenario == "a" and not _scenario_a_done and _elapsed > 3.0:
		print("[A][FAIL] 3초 경과에도 사망 신호 없음 (HP=%d) — 예상: 2타 사망" % _slime_a.hp)
		_start_scenario_b()

	if _scenario == "b" and _target_hit > 3 and _elapsed > 0.5 and not _b_combo_checked:
		var combo: ComboState = attack_state.combo if attack_state != null else null
		if combo != null and (combo.in_finisher_recovery or combo.hit_index == 0):
			_b_combo_checked = true
			print("[B] 3타 콤보 종료 시점 HP=%d (기대: 999-10-10-15=964)" % _slime_b.hp)
			print("[B] 피니셔 후딜 진입 확인=%s" % str(combo.in_finisher_recovery))
			if _slime_b.hp == 964:
				print("[B][PASS] 3타 배율(1.0/1.0/1.5) 데미지 정확히 적용됨")
			else:
				print("[B][FAIL] 기대 HP=964, 실제 HP=%d" % _slime_b.hp)
			# D-127: 여기서 바로 끝내지 않고, Attack 상태를 실제로 벗어날 때까지(최대 1초)
			# weapon_pivot.visible을 폴링한다 - "공격 종료 후 N프레임 내
			# weapon_pivot.visible == false"를 실제 플레이 경로로 확인한다.
			_weapon_check_deadline = _elapsed + 1.0

	if _weapon_check_deadline > 0.0:
		var still_attacking: bool = attack_state != null and _player.state_machine.current_state == attack_state
		if not still_attacking or _elapsed >= _weapon_check_deadline:
			if not _player.weapon_pivot.visible:
				print("[D-127][PASS] 공격 종료 후 t=%.3f 시점 weapon_pivot.visible=false" % _elapsed)
			else:
				print("[D-127][FAIL] 공격 종료 후에도 weapon_pivot.visible=true로 남아있음(t=%.3f, still_attacking=%s)" % [_elapsed, still_attacking])
			_finish()
			return

	if _elapsed > 8.0:
		print("[TIMEOUT] 8초 초과 — 테스트가 끝나지 않음 (scenario=%s, target_hit=%d)" % [_scenario, _target_hit])
		_finish()


## 크리티컬을 결정적으로 끈다(파일 상단 "결정성" 주석 참고). Data.tables는 로드된 JSON의
## 메모리 사본이므로 여기서 바꿔도 game/data/stats.json에는 영향이 없다.
func _disable_crit() -> void:
	var stats_table: Dictionary = Data.table("stats")
	var luk: Dictionary = stats_table.get("luk", {})
	luk["base_crit_chance"] = 0.0
	luk["crit_chance_per_point"] = 0.0
	stats_table["luk"] = luk
	Data.tables["stats"] = stats_table
	var chance: float = float(Progression.get_derived().get("crit_chance", -1.0))
	print("[SETUP] 크리티컬 비활성화: crit_chance=%.3f (기대 0.000)" % chance)
	if not is_zero_approx(chance):
		print("[SETUP][FAIL] crit_chance가 0이 아님 — 시나리오 B의 HP 검사는 비결정적일 수 있음")


func _press_attack() -> void:
	var evt := InputEventAction.new()
	evt.action = "attack"
	evt.pressed = true
	_player.state_machine.handle_input(evt)


func _start_scenario_b() -> void:
	print("--- [B] 3타 콤보 전체 체이닝 검증 시작 ---")
	_scenario_a_done = true
	var attack_state = _player.state_machine.states.get(&"Attack")
	if attack_state != null and attack_state.combo != null:
		attack_state.combo.reset()
	_player.velocity = Vector2.ZERO
	_player.state_machine.transition_to(&"Idle", {})
	_scenario = "b"
	_elapsed = 0.0
	_target_hit = 0
	_press_attack()
	print("[B] t=0.000 1타 입력(플레이어 → 슬라임B)")
	_target_hit = 2


func _on_enemy_died(enemy: Node2D, killer: Node) -> void:
	if enemy == _slime_a and not _scenario_a_done:
		print("[A][PASS] enemy_died 발신 확인: enemy=%s killer=%s (t=%.3f, 남은 HP=%d)" \
			% [enemy.name, killer.name, _elapsed, _slime_a.hp])
		_start_scenario_b()


func _finish() -> void:
	print("=== SMOKE A/B 종료 ===")
	get_tree().quit()
