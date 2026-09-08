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


func tick(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		return
	if stamina < max_stamina:
		stamina = minf(stamina + stamina_regen_per_sec * delta, max_stamina)


func is_dead() -> bool:
	return hp <= 0
