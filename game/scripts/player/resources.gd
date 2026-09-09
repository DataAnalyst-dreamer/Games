## 플레이어 HP·스태미나 자원(F2-3). Godot 노드에 의존하지 않는 순수 로직이라 단독으로
## 테스트하기 쉽다. 실제 값 변경은 Player가 이 객체를 통해 수행하고, 값이 바뀔 때마다
## Events.player_hp_changed / player_stamina_changed를 쏘는 것은 호출부(Player) 책임이다.
##
## 수치 출처: combat.json (stamina.*), Tuning.PLAYER_MAX_HP(characters.json 확정 전 임시값).
class_name PlayerResources
extends RefCounted

var max_hp: int
var hp: int
var max_stamina: float
var stamina: float
var stamina_regen_per_sec: float
var stamina_regen_delay_sec: float
var stamina_exhausted_penalty_sec: float

## 소모 후 회복이 재개되기까지 남은 대기시간(초). 0이면 즉시 회복 가능.
var _regen_wait: float = 0.0


func _init(p_max_hp: int, p_max_stamina: float, p_regen_per_sec: float,
		p_regen_delay_sec: float, p_exhausted_penalty_sec: float) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	max_stamina = p_max_stamina
	stamina = p_max_stamina
	stamina_regen_per_sec = p_regen_per_sec
	stamina_regen_delay_sec = p_regen_delay_sec
	stamina_exhausted_penalty_sec = p_exhausted_penalty_sec


## 데미지를 받는다. 사망(HP<=0)했으면 true를 반환.
func take_damage(amount: int) -> bool:
	hp = maxi(hp - amount, 0)
	return hp <= 0


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)


## 스태미나 소모를 시도한다. 부족하면 소모 없이 false(F2-3 예외: 액션 미발동).
func try_spend(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	if stamina <= 0.0:
		stamina = 0.0
		# combat-tuning-m1.md §3-2: 완전 고갈 시 회복 재개까지 exhausted_penalty_sec.
		_regen_wait = stamina_exhausted_penalty_sec
	else:
		_regen_wait = stamina_regen_delay_sec
	return true


## regen_multiplier: 이번 프레임에 적용할 회복 속도 배율(기본 1.0). Guard 유지 중처럼
## 특정 상태에서 회복이 느려지는 규칙(M1-2 제안값, combat.json stamina.guard_regen_
## multiplier)을 호출부(Player)가 전달한다. 회복 대기(_regen_wait) 자체에는 영향 없음 —
## "회복이 재개된 뒤의 속도"만 배율 대상이다.
func tick(delta: float, regen_multiplier: float = 1.0) -> void:
	if _regen_wait > 0.0:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		return
	if stamina < max_stamina:
		stamina = minf(stamina + stamina_regen_per_sec * regen_multiplier * delta, max_stamina)


func is_dead() -> bool:
	return hp <= 0


## DEX 스태미나 경감식(S2-1b 규칙, docs/specs/combat-tuning-m1.md §3-3, D-45: M1은 구르기
## 전용). 순수 함수라 Node 없이 GUT에서 직접 테스트 가능. dex=0이면 경감 없음(현재 stats
## 시스템 미구현이라 호출부는 전부 dex=0으로 고정 — characters.json/stats.json 확정 후
## 실제 DEX 값을 전달하도록 교체할 것, godot-engineer TODO).
static func roll_cost_with_dex(base_cost: float, dex: float) -> float:
	return base_cost * (1.0 - minf(0.5, dex / 300.0))


## M2-6(F8-1) 세이브 직렬화. max_hp/max_stamina/회복 관련 필드는 combat.json + 장비
## 스탯(Equipment.compute_stats())로 매 로드마다 다시 계산되는 파생값이라 저장하지
## 않는다 — "현재값"만 담아 로드 후 재계산된 상한에 clamp해서 되돌린다(from_dict).
func to_dict() -> Dictionary:
	return {"hp": hp, "stamina": stamina}


## data가 비어 있으면(구버전 세이브 등) 현재 값을 그대로 둔다. 상한(max_hp/max_stamina)은
## 이 시점에 이미 장비 스탯 반영이 끝나 있어야 정확히 clamp된다 — 호출 순서는 GameState.
## from_dict()(장비 재계산 포함)를 먼저 실행한 뒤 이 함수를 호출할 것(save_manager.gd 참고).
func from_dict(data: Dictionary) -> void:
	hp = clampi(int(data.get("hp", hp)), 0, max_hp)
	stamina = clampf(float(data.get("stamina", stamina)), 0.0, max_stamina)
