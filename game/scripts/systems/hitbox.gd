## 공격 판정 영역(Area2D). 플레이어 공격/몬스터 공격 모두 이 컴포넌트를 재사용한다.
##
## 사용법: 씬에 Hitbox를 자식으로 두고(공격 시점에만 활성화되도록 CollisionShape2D를
## 배치), 공격 상태(Attack, MonsterBase 등)가 damage/knockback_px/hitstop_sec/element/
## is_heavy/source를 채운 뒤 activate()를 호출한다. 한 번의 휘두름(activate~deactivate)
## 동안 같은 대상은 한 번만 맞는다(F2-1: "같은 대상 중복 타격 방지").
class_name Hitbox
extends Area2D

## 이 히트박스의 소속 팀. Hurtbox는 다른 팀의 Hitbox에만 반응한다.
@export var team: StringName = &"player"

## 활성화 시점에 호출부가 채우는 공격 파라미터.
var damage: int = 0
var knockback_px: float = 0.0
var hitstop_sec: float = 0.0
var element: StringName = &""
var is_heavy: bool = false
## 이 히트박스를 발동시킨 주체(넉백 방향·데미지 숫자 위치 계산에 사용).
var source: Node2D = null

## 이번 활성화 구간 동안 이미 맞은 대상(Hurtbox의 body) 목록 — 중복 타격 방지.
var _already_hit: Array[Node] = []

signal hit_confirmed(hurtbox: Hurtbox)


func _ready() -> void:
	# collision_layer/mask는 씬에서 설정한다(예: mask=공용 "전투 판정" 레이어).
	# Hitbox는 monitorable일 필요가 없다(자신이 감지당할 이유가 없음).
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


## 새 휘두름을 시작한다: 히트 기록을 비우고 판정을 켠다.
## duration_sec > 0이면 그 시간 뒤 자동으로 deactivate()한다(짧은 판정창 공격에 편리).
##
## monitoring은 set_deferred로 바꾼다 — activate()/deactivate()가 area_entered 같은
## 물리 시그널 콜백 도중(예: 피격 처리 체인 안에서 다음 상태로 전환하며 호출) 불릴 수
## 있는데, 그 안에서 즉시 바꾸면 "Function blocked during in/out signal" 오류가 난다.
func activate(duration_sec: float = -1.0) -> void:
	_already_hit.clear()
	set_deferred("monitoring", true)
	if duration_sec > 0.0:
		var tree := get_tree()
		if tree != null:
			tree.create_timer(duration_sec).timeout.connect(deactivate, CONNECT_ONE_SHOT)


func deactivate() -> void:
	set_deferred("monitoring", false)


## 테스트/코드에서 직접 히트 판정을 넣고 싶을 때 쓰는 진입점(물리 프레임을 기다리지
## 않고 즉시 처리). 실제 게임플레이에서는 area_entered 시그널이 이 함수를 호출한다.
func try_hit(hurtbox: Hurtbox) -> bool:
	if hurtbox == null or hurtbox.team == team:
		return false
	if _already_hit.has(hurtbox.body):
		return false
	_already_hit.append(hurtbox.body)
	hurtbox.receive_hit(self)
	hit_confirmed.emit(hurtbox)
	return true


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	try_hit(hurtbox)
