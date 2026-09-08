## 구르기 회피 상태(S2-1b). 타이밍/무적 판정은 scripts/systems/roll_calc.gd(순수 로직,
## GUT 테스트 대상)에 위임하고, 이 상태는 실제 이동(고정 거리를 고정 시간 동안 등속
## 이동 — D-43)·무적(Player.start_iframes 재사용, Hurt와 동일 메커니즘이라 상태 전환과
## 무관하게 지속됨)·잔상 이펙트(scripts/systems/roll_ghost.gd)만 다룬다.
##
## 스태미나: combat.json stamina.costs.roll(20) 소모, DEX 경감식(PlayerResources.
## roll_cost_with_dex)은 stats 시스템 미구현이라 DEX=0 고정 경로만 동작한다 — 실제 DEX
## 연동은 characters.json/stats.json 확정 후 Player.get_roll_cost()만 고치면 된다.
## 발동 자체(스태미나 부족 시 미발동)는 진입 전 상태(state.gd.try_enter_roll())가 이미
## 걸러내므로, 여기서의 try_spend 실패는 동시성 대비 방어 코드다.
class_name RollState
extends PlayerState

## 구르기 잔상을 몇 초 간격으로 찍을지(순수 연출값, 테이블화 대상 아님).
const GHOST_INTERVAL_SEC := 0.05

var _elapsed: float = 0.0
var _direction: Vector2 = Vector2.DOWN
var _speed_px_s: float = 0.0
var _duration_sec: float = 0.0
var _ghost_accum: float = 0.0


func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	if not player.resources.try_spend(player.get_roll_cost()):
		Events.player_stamina_insufficient.emit(&"roll")
		finished.emit(&"Idle", {})
		return
	Events.player_stamina_changed.emit(player.resources.stamina, player.resources.max_stamina)
	AudioManager.play_sfx(&"player_roll", player.global_position)

	# S2-1b: "회피 입력 시 현재 방향(미입력 시 바라보는 방향)으로 즉시 발동".
	var input_dir := player.get_move_input()
	_direction = input_dir.normalized() if input_dir != Vector2.ZERO else player.facing
	player.set_facing(_direction)

	var iframes_sec: float = float(Data.get_value("combat", "roll.iframes_sec", 0.3))
	_duration_sec = float(Data.get_value("combat", "roll.duration_sec", 0.45))
	var distance_px: float = float(Data.get_value("combat", "roll.distance_px", 48.0))
	_speed_px_s = RollCalc.average_speed_px_s(distance_px, _duration_sec)

	_elapsed = 0.0
	_ghost_accum = 0.0
	player.start_iframes(iframes_sec)
	player.velocity = _direction * _speed_px_s
	player.play_anim("walk") # 전용 구르기 프레임 없음(pixel-artist TODO, 완료 보고 참고).


func physics_update(delta: float) -> void:
	_elapsed += delta
	_ghost_accum += delta
	if _ghost_accum >= GHOST_INTERVAL_SEC:
		_ghost_accum = 0.0
		RollGhost.spawn(player.sprite)

	if RollCalc.is_finished(_elapsed, _duration_sec):
		player.velocity = Vector2.ZERO
		# S2-1b 결과: "종료 후 즉시 입력 수신(경직 최소화)" — 별도 후딜 상태 없이
		# Idle/Move로 바로 넘어가면 그 상태들이 입력을 즉시 받는다.
		if player.get_move_input() != Vector2.ZERO:
			finished.emit(&"Move", {})
		else:
			finished.emit(&"Idle", {})
		return

	player.velocity = _direction * _speed_px_s
	player.move_and_slide()
