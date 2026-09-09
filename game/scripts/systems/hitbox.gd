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
## 가드 불가 공격(잡기 등, S2-1c 예외). true면 가드/저스트 가드 로직을 건너뛰고 항상
## 정상 피해가 들어간다. 몬스터 쪽에서 이 값을 true로 세팅한 공격은 예고 연출도 구분해야
## 한다(붉은 예고 이펙트 — 현재 M1 몬스터 3종엔 해당 패턴이 없어 실제 연출 훅은 미구현,
## pixel-artist/asset-wrangler TODO).
@export var unguardable: bool = false
## true면 Hurtbox.invulnerable(구르기/피격 직후 무적 프레임) 상태에서도 강제로 hurt
## 신호를 통과시킨다. 버섯돌이 포자 장판처럼 "위험 지역에 서 있는 대가"로 취급하는
## 지속 피해 전용 플래그다(docs/specs/combat-tuning-m1-addendum.md §2-2, D-61 예정) —
## 일반 히트박스는 반드시 false로 둔다(무적을 우회하면 안 됨).
@export var ignores_iframes: bool = false
## 이 히트박스를 발동시킨 주체(넉백 방향·데미지 숫자 위치 계산에 사용).
var source: Node2D = null

## 이번 활성화 구간 동안 이미 맞은 대상(Hurtbox의 body) 목록 — 중복 타격 방지.
var _already_hit: Array[Node] = []

## activate() 호출마다 증가하는 세대 번호. 콤보 연속 타격처럼 이전 활성화의
## duration_sec이 채 끝나기 전에 activate()가 다시 호출되면(예: 1타 활성 0.333s가
## 끝나기 전에 2타가 이미 시작), 예전 활성화가 예약해 둔 자동 deactivate() 타이머가
## 새 활성화 도중 뒤늦게 발동해 monitoring을 도로 꺼버리는 경합이 있었다(디버깅 세션에서
## 실측: 이 경합 탓에 콤보 2·3타의 히트박스가 monitoring=true로 전혀 유지되지 못해
## 데미지가 전혀 들어가지 않았다). 매 activate()마다 세대를 올리고, 예약된 타이머는
## "발동 시점의 세대"를 함께 기억해 자신이 여전히 최신 세대일 때만 실제로 deactivate()
## 하도록 해 낡은 타이머를 무해화한다.
var _activation_generation: int = 0

signal hit_confirmed(hurtbox: Hurtbox)
## 저스트 가드 성공 시 이 히트박스의 소유자(공격자)에게 경직을 요청한다(S2-1c: "저스트
## 성공 시 적 경직"). 방어자(Player)가 emit하고, 공격자(MonsterBase 등)가 자신의 Hitbox에
## 이 신호를 구독해 스스로 경직 상태로 전이해야 한다.
signal stagger_requested(duration_sec: float)


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
	_activation_generation += 1
	var this_generation: int = _activation_generation
	if duration_sec > 0.0:
		var tree := get_tree()
		if tree != null:
			tree.create_timer(duration_sec).timeout.connect(func() -> void:
				# 그 사이 activate()가 다시 호출돼 세대가 넘어갔다면(콤보 다음 타 등),
				# 이 타이머는 낡은 것이니 아무것도 하지 않는다 — 실제 deactivate()는
				# 최신 activate()가 예약한 자신의 타이머가 책임진다.
				if this_generation == _activation_generation:
					deactivate()
			, CONNECT_ONE_SHOT)
	# area_entered 시그널은 "새로 겹친" 순간에만 발생한다 — 콤보 2·3타처럼 대상이
	# 이전 활성화 때부터 계속 같은 자리(사거리 안)에 서 있어 monitoring이 한 번도
	# 꺼지지 않고 계속 겹쳐 있던 경우, 다시 activate()해도 "새로 겹침" 이벤트가 없어
	# area_entered가 재발화하지 않는다(디버깅 세션에서 실측: 이 경로로 콤보 2·3타
	# 데미지가 전혀 안 들어갔다 — 몬스터 쪽에서 몬스터 자신이 얼어붙어 Hitbox가
	# process_mode 전파로 물리 트리에서 잠깐 빠졌다 복귀하며 우연히 재감지되던 것에
	# 기존 동작이 암묵적으로 의존하고 있었다). set_deferred가 반영된 뒤(물리 프레임
	# 갱신 후) 이미 겹쳐 있는 대상을 명시적으로 다시 판정한다.
	call_deferred("_hit_already_overlapping")


## activate() 직후 이미 겹쳐 있는 대상을 명시적으로 재판정한다(위 activate() 주석).
## try_hit()이 _already_hit 중복 방지를 그대로 적용하므로 area_entered와 중복 호출돼도
## 안전하다.
func _hit_already_overlapping() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null:
			try_hit(hurtbox)


func deactivate() -> void:
	set_deferred("monitoring", false)


## 지속 피해(장판)처럼 monitoring을 계속 켜 둔 채 반복 틱이 필요한 호출부가 매 틱마다
## 히트 기록만 초기화할 때 쓴다(monster_base.gd의 포자 장판 참고) — deactivate() 없이
## 같은 대상을 다시 맞힐 수 있게 한다.
func reset_hits() -> void:
	_already_hit.clear()


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
