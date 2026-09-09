## HUD 순수 계산 함수 모음(F7-1 태스크 6: "HP 퍼센트→바 값·경고 임계 계산 순수 함수").
## Node/씬 의존이 없어 GUT에서 인스턴스화 없이(정적 함수) 바로 검증할 수 있다.
class_name HudMath
extends RefCounted

## HP 25% 이하 경고 임계(F7-1 예외 규칙). 스태미나 부족 경고도 동일 비율을 재사용한다
## (docs/specs/combat-tuning-m1.md 관례 — debug_hud.gd STAMINA_LOW_RATIO와 동일 값).
const HP_WARNING_RATIO := 0.25
const STAMINA_LOW_RATIO := 0.25


## current/max → 0.0~1.0 클램프 비율. max<=0이면 0(0 나누기 방지).
static func ratio(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clampf(current / max_value, 0.0, 1.0)


## HP 25% 이하(0 초과, 즉 생존 중)일 때만 점멸+비네트 대상.
static func is_hp_critical(current: float, max_value: float) -> bool:
	var r := ratio(current, max_value)
	return r > 0.0 and r <= HP_WARNING_RATIO


## 스태미나가 낮음(경고색 전환 임계, debug_hud.gd 규칙과 동일).
static func is_stamina_low(current: float, max_value: float) -> bool:
	return ratio(current, max_value) < STAMINA_LOW_RATIO


## 스태미나 완전 고갈("고갈 시 빨간 점멸" 지속 상태 판정).
static func is_stamina_empty(current: float) -> bool:
	return current <= 0.0
