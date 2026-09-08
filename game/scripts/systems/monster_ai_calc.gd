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
