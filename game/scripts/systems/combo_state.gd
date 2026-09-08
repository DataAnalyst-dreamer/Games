## 3타 콤보 진행 상태를 관리하는 순수 로직 (Godot 노드에 의존하지 않아 GUT에서 직접 테스트 가능).
## Attack 상태(scripts/player/states/attack.gd)가 매 프레임 update(delta)로 구동한다.
##
## 타이밍 모델 (수치 근거: combat.json, docs/specs/combat-tuning-m1.md §4):
##   각 타(1·2타)는 hit_duration_sec 동안 활성(스윙) 상태다. 활성 구간의 마지막
##   input_buffer_sec 동안 공격 입력이 들어오면 "버퍼링"되어, 활성 구간이 끝나는 즉시
##   다음 타로 이어진다(S2-1a: 입력 버퍼로 콤보 연결). 버퍼링되지 않았다면 활성 구간
##   종료 후 "유예 구간"에 들어가며(현재 타 시작 시점 기준 reset_after_sec까지),
##   그 사이 입력이 들어오면 즉시 다음 타로 이어지고, 끝까지 입력이 없으면 콤보가
##   완전히 초기화된다(combo.reset_after_sec). 3타(피니셔)는 다음 타가 없으므로 활성 구간
##   종료 후 finisher_recovery_sec 후딜레이를 거쳐 자동으로 초기화된다.
class_name ComboState
extends RefCounted

## 콤보가 진행 중이 아닐 때의 hit_index 값.
const IDLE_HIT := 0

var max_hits: int
var input_buffer_sec: float
var reset_after_sec: float
var hit_duration_sec: float
var finisher_recovery_sec: float

## 현재 타 번호(1..max_hits). 콤보가 비어 있으면 IDLE_HIT.
var hit_index: int = IDLE_HIT
## 현재 타(또는 피니셔 후딜)가 시작된 후 흐른 시간(초).
var elapsed: float = 0.0
## 현재 타의 버퍼 구간에서 다음 타 입력이 들어왔는지.
var buffered: bool = false
## 3타(피니셔) 후딜레이 중인지.
var in_finisher_recovery: bool = false


func _init(p_max_hits: int, p_input_buffer_sec: float, p_reset_after_sec: float,
		p_hit_duration_sec: float, p_finisher_recovery_sec: float) -> void:
	max_hits = p_max_hits
	input_buffer_sec = p_input_buffer_sec
	reset_after_sec = p_reset_after_sec
	hit_duration_sec = p_hit_duration_sec
	finisher_recovery_sec = p_finisher_recovery_sec


## 공격 입력을 알린다. 새 타(1타 시작 또는 유예 구간에서의 즉시 연결)로 진입하면 true,
## 버퍼링만 되었거나(활성 구간 중) 무시되었으면(피니셔 후딜 중) false를 반환한다.
func on_attack_input() -> bool:
	if hit_index == IDLE_HIT and not in_finisher_recovery:
		_start_hit(1)
		return true
	if in_finisher_recovery:
		return false
	if is_in_buffer_window():
		buffered = true
		return false
	if is_in_grace_window():
		_start_hit(hit_index + 1)
		return true
	return false


## 활성 구간(hit_duration_sec)의 마지막 input_buffer_sec 동안인지.
func is_in_buffer_window() -> bool:
	return hit_index > 0 and not in_finisher_recovery \
		and elapsed >= maxf(hit_duration_sec - input_buffer_sec, 0.0) and elapsed < hit_duration_sec


## 활성 구간이 끝난 뒤, 콤보가 완전히 리셋되기 전까지의 유예 구간인지(피니셔 제외).
func is_in_grace_window() -> bool:
	return hit_index > 0 and hit_index < max_hits and not in_finisher_recovery \
		and elapsed >= hit_duration_sec and elapsed < reset_after_sec


## 매 프레임 호출. 반환: {"advanced": bool, "reset": bool, "entered_finisher_recovery": bool}
func update(delta: float) -> Dictionary:
	var no_op := {"advanced": false, "reset": false, "entered_finisher_recovery": false}
	if hit_index == IDLE_HIT and not in_finisher_recovery:
		return no_op
	elapsed += delta
	if in_finisher_recovery:
		if elapsed >= finisher_recovery_sec:
			reset()
			return {"advanced": false, "reset": true, "entered_finisher_recovery": false}
		return no_op
	if elapsed >= hit_duration_sec:
		if hit_index >= max_hits:
			in_finisher_recovery = true
			elapsed = 0.0
			return {"advanced": false, "reset": false, "entered_finisher_recovery": true}
		if buffered:
			_start_hit(hit_index + 1)
			return {"advanced": true, "reset": false, "entered_finisher_recovery": false}
		if elapsed >= reset_after_sec:
			reset()
			return {"advanced": false, "reset": true, "entered_finisher_recovery": false}
	return no_op


## 구르기 캔슬 허용 여부(피니셔 후딜 중, roll_cancel_after_sec 이후 — S2-1b).
func can_roll_cancel(roll_cancel_after_sec: float) -> bool:
	return in_finisher_recovery and elapsed >= roll_cancel_after_sec


func is_active() -> bool:
	return hit_index != IDLE_HIT or in_finisher_recovery


func reset() -> void:
	hit_index = IDLE_HIT
	elapsed = 0.0
	buffered = false
	in_finisher_recovery = false


func _start_hit(index: int) -> void:
	hit_index = index
	elapsed = 0.0
	buffered = false
	in_finisher_recovery = false
