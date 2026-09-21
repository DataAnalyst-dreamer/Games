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
##
## D-128(2차 재테스트: 크기 기반 완충만으로는 실제 키보드 입력 — 대각선 두 키가 정확히
## 같은 프레임에 눌리지 않는 경우 — 에서 잔여 흔들림이 남았다): 크기 조건을 만족해도
## 마지막 축 전환 후 `min_switch_interval_sec` 이내면 축 전환을 보류하는 시간 기반
## 디바운스를 추가한다. `elapsed_since_last_switch`는 호출 측(Player)이 델타를 누적해
## 넘긴다 — 이 함수는 노드/타이머에 의존하지 않는 순수 함수로 유지한다. 두 인자 모두
## 기본값(elapsed=매우 큼, interval=0)에서는 디바운스가 걸리지 않아 기존 호출부와
## 100% 하위 호환된다.
static func resolve_facing(
	current_facing: Vector2,
	input_dir: Vector2,
	axis_switch_bias: float = 1.3,
	elapsed_since_last_switch: float = 1e9,
	min_switch_interval_sec: float = 0.0,
) -> Vector2:
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
	var would_switch_axis: bool = use_horizontal != currently_horizontal
	if would_switch_axis and elapsed_since_last_switch < min_switch_interval_sec:
		# 크기 조건은 만족했지만 직전 축 전환으로부터 최소 유지 시간이 지나지 않았다 —
		# 축 전환을 보류한다. 아래 공용 부호 판정(입력의 반대 축 성분이 0에 가까울 수
		# 있어 신뢰할 수 없다)을 타지 않고 현재 facing을 그대로 반환해야 한다.
		return current_facing
	if use_horizontal:
		return Vector2.RIGHT if input_dir.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if input_dir.y > 0.0 else Vector2.UP


## --- 8방향(D-228~D-230, 단계 iso-3) ---------------------------------------
##
## 등각에서 화면의 상하좌우는 격자의 대각선이라, 4방향을 그대로 쓰면 격자를 따라 걸을 때
## 스프라이트가 45도 어긋난 채 미끄러진다(isometric-migration-v1.md §4). 양자화는 **화면
## 벡터** 기준 45도 균등 8섹터다(D-228) - 지면 격자 축 기준은 화면에서 0/26.6/90/153.4도로
## 불균등해져 동서 이동이 섹터 경계에 놓이고, 그게 바로 D-121 이 없애려던 흔들림이다.
##
## 행 순서는 시트 계약(game/assets/iso/iso_actor_atlas.json)과 같다.
const DIR_NAMES_8: PackedStringArray = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
## 좌우대칭 몬스터용 4방향 시트. 대각은 수평으로 폴백한다(D-230) - 측면 프로필이
## "옆으로 간다"를 더 잘 읽는다.
const DIR_NAMES_4: PackedStringArray = ["s", "w", "n", "e"]
## 섹터 반폭(도). 8섹터라 45/2.
const SECTOR_HALF_DEG: float = 22.5


## 화면 방향 벡터를 8방향 섹터 번호(0=s, 1=sw, ... 7=se)로 양자화한다.
## s(0,1)=화면 아래가 0번이 되도록 각도에서 90도를 뺀 뒤 45도로 나눈다.
static func sector_of(dir: Vector2) -> int:
	if dir == Vector2.ZERO:
		return 0
	var deg: float = rad_to_deg(dir.angle()) - 90.0
	return wrapi(int(round(deg / 45.0)), 0, 8)


## 섹터 번호 -> 화면 단위 벡터. cos/sin 으로 만들면 45도 배수에서 6e-17 같은 부동소수
## 먼지가 남아 `facing == Vector2.DOWN` 류 비교가 조용히 실패한다 - 표로 고정한다.
const _SQ: float = 0.70710678118
const DIR_VECTORS_8: Array = [
	Vector2(0.0, 1.0), Vector2(-_SQ, _SQ), Vector2(-1.0, 0.0), Vector2(-_SQ, -_SQ),
	Vector2(0.0, -1.0), Vector2(_SQ, -_SQ), Vector2(1.0, 0.0), Vector2(_SQ, _SQ),
]


static func sector_vector(sector: int) -> Vector2:
	return DIR_VECTORS_8[wrapi(sector, 0, 8)]


## 8방향 facing 판정. 4방향판과 같은 두 완충을 그대로 쓴다.
##
## * 크기 완충: `axis_switch_bias` 를 **섹터 반폭의 배수**로 재해석한다 - 1.3 이면 현재
##   방향에서 ±29.25도 안에서는 방향을 유지한다(4방향 시절 "반대 축 성분이 1.3배 이상"과
##   같은 역할).
## * 시간 디바운스(D-128/D-229): **인접 섹터(±45도) 전환만** 막는다. 4방향 시절 디바운스도
##   축 전환(90도)만 막고 180도 반전(LEFT<->RIGHT)은 즉시 허용했다 - 이게 그 규칙의 정확한
##   번역이다. 2섹터 이상 차이는 의도한 큰 방향 전환이라 즉시 통과시킨다.
static func resolve_facing_8(
	current_facing: Vector2,
	input_dir: Vector2,
	axis_switch_bias: float = 1.3,
	elapsed_since_last_switch: float = 1e9,
	min_switch_interval_sec: float = 0.0,
) -> Vector2:
	if input_dir == Vector2.ZERO:
		return current_facing
	var current_sector: int = sector_of(current_facing)
	var current_vec: Vector2 = sector_vector(current_sector)
	# 현재 방향에서 얼마나 벗어났나 - 완충 폭 안이면 그대로 유지한다.
	var off_deg: float = absf(rad_to_deg(current_vec.angle_to(input_dir)))
	if off_deg <= SECTOR_HALF_DEG * axis_switch_bias:
		return current_vec
	var next_sector: int = sector_of(input_dir)
	# 섹터 원형 거리(0~4). 1이면 인접 전환이다.
	var step: int = absi(wrapi(next_sector - current_sector, -4, 4))
	if step <= 1 and elapsed_since_last_switch < min_switch_interval_sec:
		return current_vec
	return sector_vector(next_sector)


## facing -> 시트 행 이름. dir_count 가 4면 대각을 수평으로 접는다(D-230).
static func dir_name(facing: Vector2, dir_count: int = 8) -> String:
	var sector: int = sector_of(facing)
	if dir_count >= 8:
		return DIR_NAMES_8[sector]
	# 8섹터를 4행으로: s(0) / w(1,2,3) / n(4) / e(5,6,7).
	if sector == 0:
		return DIR_NAMES_4[0]
	if sector == 4:
		return DIR_NAMES_4[2]
	return DIR_NAMES_4[1] if sector < 4 else DIR_NAMES_4[3]
