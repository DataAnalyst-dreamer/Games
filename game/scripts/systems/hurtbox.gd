## 피격 판정 영역(Area2D). Hitbox와 겹치면 receive_hit()이 호출되어 hurt 시그널을
## 낸다. 실제 데미지 적용·연출(히트스톱·넉백·플래시·데미지 숫자·카메라 셰이크)은
## hurt 시그널을 구독하는 쪽(Player/MonsterBase)이 scripts/systems/hit_feel.gd를
## 통해 처리한다 — Hurtbox 자체는 "맞았다"는 사실만 전달하는 얇은 컴포넌트다.
class_name Hurtbox
extends Area2D

signal hurt(hitbox: Hitbox)

## 이 피격판정의 소속 팀. 같은 팀의 Hitbox는 무시한다.
@export var team: StringName = &"enemy"
## 피격 판정의 소유 캐릭터(CharacterBody2D 등). 데미지 적용 대상.
@export var body: Node = null

## 무적 상태면 피격을 완전히 무시한다(구르기 무적, 피격 직후 무적 프레임 등).
var invulnerable: bool = false


func _ready() -> void:
	# collision_layer/mask는 씬에서 설정한다(예: 공용 "전투 판정" 레이어). 여기서
	# 강제로 덮어쓰지 않는다 — Hitbox의 collision_mask가 이 레이어를 가리켜야 감지된다.
	monitoring = false
	monitorable = true
	if body == null:
		body = get_owner()


func receive_hit(hitbox: Hitbox) -> void:
	# 무적(구르기/피격 직후 iframes)은 기본적으로 모든 히트를 막는다 — 단, 히트박스가
	# ignores_iframes(장판형 지속 피해 전용, D-61 예정)면 예외적으로 통과시킨다.
	if invulnerable and not hitbox.ignores_iframes:
		return
	hurt.emit(hitbox)
