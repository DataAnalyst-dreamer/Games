## 플레이어 4방향 facing 판정 순수 로직(D-121, docs/qa/walk-animation-diagnosis.md §3).
## Godot 노드에 의존하지 않아 GUT에서 직접 테스트 가능 — monster_ai_calc.gd/guard_calc.gd와
## 같은 패턴.
##
## 배경: 기존 player.gd.set_facing()은 매 물리 프레임 `|x| >= |y|`만으로 4방향을 다시
## 계산했다. 완충(hysteresis)이 없어 입력 벡터가 대각선 45도 부근에서 미세하게 흔들리면
## (게임패드 아날로그 드리프트, 대각선 전환 순간의 타이밍) facing이 프레임마다 수평↔수직
## 축 자체를 오갈 수 있었다 — "빙글빙글 도는 느낌" 피드백의 유력 원인.
class_name FacingCalc
extends RefCounted


## 현재 facing이 속한 축(수평/수직)을 유지하려는 완충을 적용해 다음 facing을 계산한다.
## 새 입력이 현재 축을 뒤집으려면 반대 축 성분이 `axis_switch_bias`배 이상 더 커야
## 전환된다(예: 1.3 = 20~30% 이상 여유). 입력이 축을 확실히 넘어서지 못하면 현재 축을
## 그대로 유지하되, 좌우/상하 방향 자체는 입력 부호를 그대로 따른다.
static func resolve_facing(current_facing: Vector2, input_dir: Vector2, axis_switch_bias: float = 1.3) -> Vector2:
	if input_dir == Vector2.ZERO:
		return current_facing
	var ax: float = absf(input_dir.x)
	var ay: float = absf(input_dir.y)
	var currently_horizontal: bool = current_facing == Vector2.LEFT or current_facing == Vector2.RIGHT
	var use_horizontal: bool
	if currently_horizontal:
		# 수직 입력이 수평보다 bias배 이상 크지 않으면 수평축을 유지한다.
		use_horizontal = not (ay > ax * axis_switch_bias)
	else:
		# 수평 입력이 수직보다 bias배 이상 커야 수평축으로 전환한다.
		use_horizontal = ax > ay * axis_switch_bias
	if use_horizontal:
		return Vector2.RIGHT if input_dir.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if input_dir.y > 0.0 else Vector2.UP
