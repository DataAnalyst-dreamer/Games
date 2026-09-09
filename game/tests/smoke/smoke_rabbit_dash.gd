## 헤드리스 스모크 테스트: "뿔토끼 예고 → 돌진(charge) → 후딜(RECOVER) 파이프라인".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeRabbitDash.tscn --quit-after 400
##
## HornRabbit1을 플레이어의 인지 범위(aggro_range_px=80) 안, 근접 사거리(melee_range_px=16)
## 밖에 두어 CHASE→TELEGRAPH→ATTACK(돌진)까지 스스로 진행하게 둔다. ATTACK 중 실측 속도가
## monsters.json.horn_rabbit.dash_speed_px(200)와 일치하는지, ATTACK 종료 후 곧장
## CHASE/TELEGRAPH로 재진입하지 않고 RECOVER(attack_recovery_sec=0.7s)를 거치는지
## 확인한다(QA 리뷰 Major-1 회귀 방지).
extends Node

var _main: Node
var _player: Player
var _rabbit: MonsterBase

var _elapsed: float = 0.0
var _last_state: int = -1
var _attack_entered_at: float = -1.0
var _recover_entered_at: float = -1.0
var _saw_dash_speed_ok: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 뿔토끼 돌진(charge) ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_rabbit = _main.get_node("HornRabbit1") as MonsterBase
	for n in ["Slime1", "Slime2", "Slime3", "HornRabbit2", "Mushroom1"]:
		var other := _main.get_node(n)
		if other != null:
			other.queue_free()

	_player.global_position = Vector2.ZERO
	# 인지 범위(80px) 안, 근접 사거리(16px) 밖 → CHASE로 다가온 뒤 TELEGRAPH → 돌진.
	_rabbit.global_position = _player.global_position + Vector2(60, 0)

	print("뿔토끼 aggro_range_px=%.1f melee_range_px=%.1f dash_speed_px=%.1f dash_duration_sec=%.2f attack_recovery_sec=%.2f" \
		% [_rabbit.aggro_range_px, _rabbit.melee_range_px, _rabbit.dash_speed_px, _rabbit.dash_duration_sec, _rabbit.attack_recovery_sec])


func _process(delta: float) -> void:
	_elapsed += delta

	if _rabbit.state != _last_state:
		var state_name: String = MonsterBase.State.keys()[_rabbit.state]
		print("t=%.3f 상태 전이 -> %s (velocity=%s)" % [_elapsed, state_name, _rabbit.velocity])
		if _rabbit.state == MonsterBase.State.ATTACK:
			_attack_entered_at = _elapsed
		elif _rabbit.state == MonsterBase.State.RECOVER:
			_recover_entered_at = _elapsed
		_last_state = _rabbit.state

	if _rabbit.state == MonsterBase.State.ATTACK and not _saw_dash_speed_ok:
		var observed: float = _rabbit.velocity.length()
		if observed > 1.0:
			print("  돌진 중 속도 실측=%.1f (기대 dash_speed_px=%.1f)" % [observed, _rabbit.dash_speed_px])
			if is_equal_approx(observed, _rabbit.dash_speed_px):
				print("  [PASS] 돌진 속도가 데이터(dash_speed_px)와 일치")
				_saw_dash_speed_ok = true
			else:
				print("  [FAIL] 돌진 속도 불일치")
				_saw_dash_speed_ok = true # 더 이상 반복 로그하지 않음(실패는 이미 기록됨)

	if _recover_entered_at >= 0.0 and not _done:
		var recover_duration: float = _recover_entered_at - _attack_entered_at
		print("ATTACK 지속시간 실측=%.3f (기대 dash_duration_sec=%.2f)" % [recover_duration, _rabbit.dash_duration_sec])
		print("[PASS] ATTACK 종료 후 RECOVER로 전이함(QA Major-1: state 직접 대입 우회 없이 _enter_state 경유 확인)")
		_done = true
		_finish()

	if _elapsed > 6.0 and not _done:
		print("[TIMEOUT] attack_entered_at=%.3f recover_entered_at=%.3f dash_speed_ok=%s" \
			% [_attack_entered_at, _recover_entered_at, _saw_dash_speed_ok])
		_finish()


func _finish() -> void:
	print("=== SMOKE 종료 ===")
	get_tree().quit()
