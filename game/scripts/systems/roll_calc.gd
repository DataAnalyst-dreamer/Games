## 구르기(회피) 타이밍 순수 로직(S2-1b, combat-tuning-m1.md §2). Godot 노드에 의존하지
## 않아 GUT에서 직접 테스트 가능. 실제 상태(scripts/player/states/roll.gd)는 이 함수들의
## 결과에 따라 무적(Player.start_iframes)·이동(velocity)·상태 전환만 수행한다.
##
## 타이밍 모델(D-43 확정): 구르기는 "고정 거리(roll.distance_px)를 고정 시간
## (roll.duration_sec) 동안 등속 이동"한다. 그중 시작 시점부터 roll.iframes_sec 동안만
## 무적이고, 나머지(duration_sec - iframes_sec)는 후딜레이(착지 경직)다.
class_name RollCalc
extends RefCounted


## elapsed_sec 시점에 무적 구간인지(구르기 시작 기준). [0, iframes_sec) 구간이 무적.
static func is_invulnerable(elapsed_sec: float, iframes_sec: float) -> bool:
	return elapsed_sec >= 0.0 and elapsed_sec < iframes_sec


## elapsed_sec 시점에 구르기 전체(무적+후딜레이 포함)가 끝났는지.
static func is_finished(elapsed_sec: float, duration_sec: float) -> bool:
	return elapsed_sec >= duration_sec


## 거리/시간으로부터 역산한 등속 이동 속도(px/s). duration_sec <= 0이면 0(안전값).
static func average_speed_px_s(distance_px: float, duration_sec: float) -> float:
	if duration_sec <= 0.0:
		return 0.0
	return distance_px / duration_sec
