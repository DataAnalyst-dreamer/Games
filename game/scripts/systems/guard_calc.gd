## 가드/저스트 가드 판정 순수 로직(S2-1c, D-05). Godot 노드에 의존하지 않아 GUT에서
## 직접 테스트 가능. 실제 상태(scripts/player/states/guard.gd)는 가드 버튼을 누른 뒤
## 경과 시간(elapsed_sec)을 재고, 그 값으로 이 함수들을 호출한다.
class_name GuardCalc
extends RefCounted


## 가드 입력 후 elapsed_sec가 흘렀을 때 아직 저스트 가드 판정창(window_sec, D-05: 6프레임
## =0.1초) 안인지. "적중 직전 6프레임 내 가드 입력"을 "가드를 건 지 얼마 안 됐을 때 맞으면
## 저스트"로 뒤집어 표현한 것과 동치(가드 시작 시각과 적중 시각의 차이가 window_sec 이하).
static func is_just_guard_window(elapsed_since_guard_start_sec: float, window_sec: float) -> bool:
	return elapsed_since_guard_start_sec >= 0.0 and elapsed_since_guard_start_sec <= window_sec


## 프레임 수를 fps 기준 초 단위로 환산(D-05: 6프레임@60fps=0.1초). Data.gd의 값 정합성
## 검증(guard.just_guard_window_sec == frames/fps)과 동일한 계산을 코드 쪽에서도 순수
## 함수로 노출해 둔다.
static func frames_to_sec(frames: int, fps: int) -> float:
	if fps <= 0:
		return 0.0
	return float(frames) / float(fps)


## 일반 가드 칩데미지(S2-1c: "피해 대폭 경감", combat-tuning-m1.md §5-1 chip_damage_
## ratio=0.2 → 80% 경감). 반올림한 정수 데미지를 반환.
static func chip_damage(raw_damage: int, chip_ratio: float) -> int:
	return int(round(float(raw_damage) * chip_ratio))
