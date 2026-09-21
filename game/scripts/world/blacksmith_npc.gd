## 대장간 NPC(F3-3 표 "전제: 마을 대장간 NPC"). 판정 범위 안에서 interact 입력을 받으면
## Events.blacksmith_opened만 발신한다 — 실제 강화/재련/분해/제작 UI는 다음 단계(M2-4는
## 백엔드 로직만, scripts/systems/blacksmith.gd + GameState.blacksmith_*() 참고).
## Waystone(scripts/world/waystone.gd)과 동일한 "판정 범위 진입 + interact" 패턴.
##
## 시각 요소는 두 겹이다 - "Placeholder"(smithy.png 건물 그림, iso-2 그대로)는 대장간
## 건물을, "PersonAnchor/AnimatedSprite2D"(등각 액터 시트, D-228~D-234 NPC 확장)는 그
## 앞에 선 대장장이 본인을 그린다. 상호작용 판정(Area2D)은 건물째로 하나만 유지한다.
##
## PersonAnchor가 판정 원점에서 (-16,40) 떨어진 이유: 사람 대역 키(96px)가 이 건물
## placeholder 전체 높이(148px)에 비해 커서, 판정 원점(문간)에 그대로 세우면 머리가
## 지붕·굴뚝을 뚫고 올라간다 - 화덕 문 앞으로 한 걸음 내보내 피한다(지시사항 "겹치면
## 8px 단위로만 조정" — (-16,40) = 8×(-2, 5)).
class_name BlacksmithNpc
extends Area2D

## 핀·몬스터와 같은 규칙 - 이 값이 iso_actor_atlas.json 의 키다.
const ACTOR_ID := "npc_blacksmith"

@export var npc_id: StringName = &"blacksmith"

@onready var _anchor: Node2D = $PersonAnchor
@onready var _sprite: AnimatedSprite2D = $PersonAnchor/AnimatedSprite2D

## 발밑 그림자 배율(D-232). sprite.scale 이 1이 된 뒤 크기 단서를 시트 계약이 준다.
var shadow_scale: float = 1.0

var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if ActorSheet.apply(_sprite, ACTOR_ID):
		shadow_scale = ActorSheet.shadow_scale(ACTOR_ID)
		ActorSheet.set_speeds(_sprite, Tuning.ANIM_IDLE_FPS, Tuning.ANIM_WALK_FPS, 0.0)
		_sprite.play(ActorSheet.anim_name(ACTOR_ID, "idle", Vector2.DOWN))
	queue_redraw() # D-204와 동일 패턴: 발밑 그림자 최초 그리기.


## 발밑 타원 그림자(D-204). 건물 placeholder(Placeholder)는 자체 그림이라 그림자를
## 따로 그리지 않고, 대장장이 본인 발밑(PersonAnchor 위치)에만 건다.
func _draw() -> void:
	FootShadow.draw(self, shadow_scale, _anchor.position)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		Events.blacksmith_opened.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
