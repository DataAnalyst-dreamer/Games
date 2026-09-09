## 몬스터 AI 판정 순수 로직(F6-1, addendum §4). Godot 노드에 의존하지 않아 GUT에서 직접
## 테스트 가능. monster_base.gd는 이 함수들의 결과에 따라 상태 전환·이동·데미지 계산만
## 수행한다 — roll_calc.gd/guard_calc.gd와 같은 패턴.
class_name MonsterAiCalc
extends RefCounted


## CHASE 중 대상까지 거리가 melee_range_px 이하면 TELEGRAPH로 전이(근접/장판 트리거
## 판정, addendum §4-3 — 장판형은 "장판 트리거 거리"로 해석).
static func is_in_melee_range(distance_px: float, melee_range_px: float) -> bool:
	return distance_px <= melee_range_px


## CHASE 중 대상까지 거리가 leash_range_px 이상이면 추적을 포기한다(F6-1 "일정 거리
## 이탈 시 복귀"). 불변식(leash_range_px > aggro_range_px > melee_range_px, data.gd 검증)
## 덕분에 항상 aggro 반경보다 멀리에서만 발동한다.
static func should_leash(distance_px: float, leash_range_px: float) -> bool:
	return distance_px >= leash_range_px


## 돌진(charge, 뿔토끼) 중 이동 속도 벡터.
static func dash_velocity(direction: Vector2, dash_speed_px: float) -> Vector2:
	return direction * dash_speed_px


## 포자 장판(spore_patch, 버섯돌이) 1틱 데미지. monsters.json.atk_tick_per_sec은 "초당
## 데미지"로 정의돼 있고(addendum §4-3), 구현은 1초 간격으로 그 값을 반올림한 정수
## 데미지 1회를 주는 방식으로 단순화했다(tuning.gd SPORE_PATCH_DURATION_SEC 주석 참고).
static func spore_tick_damage(atk_tick_per_sec: float) -> int:
	return int(round(atk_tick_per_sec))


## 뿔토끼 돌진 중 벽(정적 콜라이더) 충돌 여부만으로 STUNNED 전이가 필요한지 판정하는
## 서술적 헬퍼(실제 충돌 감지는 CharacterBody2D.get_slide_collision_count()가 하고,
## 이 함수는 "그 결과를 STUNNED 전이로 이어도 되는 상태인가"만 순수하게 판정한다).
static func should_stun_from_wall_collision(is_dashing: bool, slide_collision_count: int) -> bool:
	return is_dashing and slide_collision_count > 0


# --- M2-3: 고블린 정찰병/정찰대장 호루라기 증원 호출 + 웨이브 + 정예 분열
# (elite-and-farming-m2.md §1-1-1/§1-2/§1-3, D-75 예정) ---

## 호루라기 재사용 가능 여부(쿨다운 소진 판정). 순수 비교라 굳이 필요 없어 보이지만
## monster_base.gd 쪽 조건문을 "판정은 전부 MonsterAiCalc" 원칙(addendum §4 관례)에
## 맞추고, 0.0 근처 부동소수 오차를 한 곳에서만 다루기 위해 분리했다.
static func is_whistle_ready(cooldown_remaining_sec: float) -> bool:
	return cooldown_remaining_sec <= 0.0


## 호루라기 호출 대상 후보를 필터링한다(§1-1-1 "whistle_range_px 안의 whistle_summon_pool
## 대상 1마리를 인식 상태로 전환"). candidates는 실제 노드가 아니라 순수 판정을 위한
## Dictionary 배열({"monster_id": String, "distance_px": float, ...호출부가 원 노드를
## 되찾기 위한 임의 키(예: "index"/"node")는 그대로 통과시킨다})이어야 한다 — 이미
## CHASE 중인(스스로 플레이어를 인식한) 대상은 "증원"의 의미가 없으므로 호출부가
## candidates에 넣기 전에 걸러내는 것을 권장하지만, 이 함수 자체는 풀 소속 여부·사거리·
## 개수 상한만 판정한다(단일 책임). 거리 오름차순으로 정렬해 가장 가까운 대상부터
## count명을 뽑는다.
static func filter_whistle_candidates(candidates: Array, pool: Array, whistle_range_px: float, count: int) -> Array:
	var in_range: Array = []
	for c: Dictionary in candidates:
		if not pool.has(String(c.get("monster_id", ""))):
			continue
		if float(c.get("distance_px", INF)) > whistle_range_px:
			continue
		in_range.append(c)
	in_range.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance_px", 0.0)) < float(b.get("distance_px", 0.0)))
	return in_range.slice(0, maxi(count, 0))


## 정예 소환 웨이브(elite_goblin_captain, §1-2) 발동 조건: HP 비율이 wave_trigger_hp_pct
## 이하로 떨어졌고, 아직 이번 생애 동안 한 번도 발동하지 않았을 때만 true
## (`wave_once_per_life`, GDD 8.2 "패턴 강화"의 정예 스케일 축소판 — 재발동 없음).
static func should_trigger_wave(hp: int, max_hp: int, wave_trigger_hp_pct: float, already_triggered: bool) -> bool:
	if already_triggered or max_hp <= 0 or hp <= 0:
		return false
	return (float(hp) / float(max_hp)) <= wave_trigger_hp_pct


## 웨이브 소환(§1-2)·정예 분열(§1-3) 공용: 중심점 주변 radius_px 안에 count개의 스폰
## 오프셋을 서로 min_separation_px 이상 떨어뜨려 생성한다("겹침 방지"). 매 후보마다
## 최대 20회 재시도하고, 그래도 조건을 못 채우면 그 후보는 마지막 시도 위치를 그대로
## 채택한다(무한루프 방지 — 완전한 비겹침을 100% 보장하기보다 "웬만하면 겹치지 않게"가
## 목표인 연출용 배치이므로 허용). rng를 주입받아 GUT에서 시드 고정 재현 가능.
static func pick_non_overlapping_offsets(
		count: int, radius_px: float, min_separation_px: float, rng: RandomNumberGenerator) -> Array:
	var offsets: Array = []
	for i in count:
		var chosen: Vector2 = Vector2.ZERO
		for attempt in 20:
			var angle: float = rng.randf_range(0.0, TAU)
			var r: float = rng.randf_range(radius_px * 0.3, radius_px)
			var candidate: Vector2 = Vector2(cos(angle), sin(angle)) * r
			var ok: bool = true
			for existing: Vector2 in offsets:
				if candidate.distance_to(existing) < min_separation_px:
					ok = false
					break
			chosen = candidate
			if ok:
				break
		offsets.append(chosen)
	return offsets
