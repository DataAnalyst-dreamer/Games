## 플레이테스트 계측 카운터의 순수 계산 로직(M1-4, docs/qa/m1-gate-playtest.md §4).
## Godot 노드·오토로드에 의존하지 않아 GUT에서 직접 테스트 가능. 실제 수집(Events 구독,
## 파일 저장)은 scripts/core/metrics.gd(오토로드)가 담당하고, 이 스크립트는 "누적된 raw
## 카운터 → 성공률/평균 TTK/JSON 스키마"로 변환하는 계산만 한다.
class_name MetricsCalc
extends RefCounted

## JSON 파일 스키마 버전. 필드를 추가/변경할 때만 올린다(HUD 등 소비자가 버전으로 분기 가능).
const SCHEMA_VERSION := 1


## 0으로 나누기 방지 성공률(0.0~1.0). attempts가 0이면 "시도 자체가 없었다"는 의미로 0.0.
static func success_rate(successes: int, attempts: int) -> float:
	if attempts <= 0:
		return 0.0
	return clampf(float(successes) / float(attempts), 0.0, 1.0)


## 구르기 성공 횟수 = 진입 횟수 - 무적 구간 중 피격당한 횟수(음수 방지).
## §4 "구르기 성공률" 규칙: 무적 구간 중 Events.player_damaged가 발생하지 않은 시도 = 성공.
## (ignores_iframes 히트박스, 예: 버섯돌이 포자 장판은 의도적으로 무적을 뚫으므로
## iframe_hits에 포함되는 것이 정상 — D-61.)
static func roll_success_count(attempts: int, iframe_hits: int) -> int:
	return maxi(attempts - iframe_hits, 0)


## 표본 배열의 평균(초). 표본이 없으면 0.0(TTK 계산 불가 = 아직 아무도 못 죽였다는 뜻).
static func average_sec(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = 0.0
	for v in samples:
		total += float(v)
	return total / float(samples.size())


## 몬스터 종별 처치 수·평균 TTK를 하나의 Dictionary로 합친다.
## kills_by_monster: {monster_id: int}, ttk_samples_by_monster: {monster_id: Array[float]}.
static func build_monster_stats(kills_by_monster: Dictionary, ttk_samples_by_monster: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var monster_ids: Array = kills_by_monster.keys()
	for id in ttk_samples_by_monster.keys():
		if not monster_ids.has(id):
			monster_ids.append(id)
	for monster_id in monster_ids:
		var samples: Array = ttk_samples_by_monster.get(monster_id, [])
		out[monster_id] = {
			"kills": int(kills_by_monster.get(monster_id, 0)),
			"avg_ttk_sec": average_sec(samples),
			"ttk_samples_sec": samples.duplicate(),
		}
	return out


## Metrics.gd가 수집한 raw 카운터 Dictionary를 세션 종료/주기 저장용 JSON 직렬화
## Dictionary로 변환한다(순수 함수 — GUT이 스키마를 직접 검증). 기대 raw 키는
## metrics.gd의 _build_raw_snapshot() 주석 참고.
static func build_summary(raw: Dictionary) -> Dictionary:
	var roll_attempts: int = int(raw.get("roll_attempts", 0))
	var roll_iframe_hits: int = int(raw.get("roll_iframe_hits", 0))
	var roll_success: int = roll_success_count(roll_attempts, roll_iframe_hits)

	var guard_attempts: int = int(raw.get("guard_attempts", 0))
	var just_guard_success: int = int(raw.get("just_guard_success", 0))

	return {
		"schema_version": SCHEMA_VERSION,
		"tester": String(raw.get("tester", "anon")),
		"session_start_unix": int(raw.get("session_start_unix", 0)),
		"generated_at_unix": int(raw.get("generated_at_unix", 0)),
		"session_duration_sec": float(raw.get("session_duration_sec", 0.0)),
		"deaths": int(raw.get("deaths", 0)),
		"roll": {
			"attempts": roll_attempts,
			"iframe_hits": roll_iframe_hits,
			"success": roll_success,
			"success_rate": success_rate(roll_success, roll_attempts),
		},
		"guard": {
			"just_guard_attempts": guard_attempts,
			"just_guard_success": just_guard_success,
			"just_guard_success_rate": success_rate(just_guard_success, guard_attempts),
			"normal_guard_count": int(raw.get("normal_guard_count", 0)),
		},
		"combo_finisher_reached_count": int(raw.get("combo_finisher_reached_count", 0)),
		"player": {
			"hits_taken": int(raw.get("player_hits_taken", 0)),
			"damage_taken_total": int(raw.get("player_damage_taken_total", 0)),
		},
		"monsters": build_monster_stats(
			raw.get("kills_by_monster", {}), raw.get("ttk_samples_by_monster", {})),
		## M2-3 신규(F6-3): 정예 처치 수만 별도로 노출({monster_id: kills}). 이미
		## build_monster_stats()에 잡힌 elite_goblin_captain/elite_bunchi_spawn 처치 수의
		## 부분집합이지만(enemy_died도 정예에 대해 함께 emit되므로), 정예만 빠르게 보고
		## 싶을 때(예: F6-3 리텐션 지표)를 위한 전용 키다.
		"elite_kills": (raw.get("elite_kills_by_monster", {}) as Dictionary).duplicate(),
	}
