## 워프/부활 비석(F8-2, D-28: "부활 비석 = 워프 비석 동일 오브젝트"). 플레이어가 판정
## 범위 안에서 상호작용(interact) 입력을 누르면 활성화되어 GameState.last_waystone에
## 자신을 기록한다 — 이후 사망 시 이 위치에서 부활한다(player.gd respawn() 참고).
##
## 워프 목적지 선택 UI(여러 비석 중 이동)는 M2 범위. 지금은 "마지막으로 활성화한 비석"
## 하나만 의미가 있다. 전용 아트가 없어(pixel-artist TODO — 완료 보고 참고) 단색 도형
## placeholder를 쓰고, 활성화 시 색을 밝게 바꿔 피드백을 준다.
class_name Waystone
extends Area2D

## 여러 비석을 구분하기 위한 식별자(워프 UI 도입 시 사용, 현재는 로그/디버그용).
@export var waystone_id: StringName = &""

@onready var _visual: Polygon2D = $Placeholder

var is_active: bool = false
var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		activate()


func activate() -> void:
	if is_active:
		return
	is_active = true
	GameState.set_last_waystone(self)
	_play_activation_feedback()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null


func _play_activation_feedback() -> void:
	AudioManager.play_sfx(&"waystone_activate", global_position)
	if _visual == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual, "modulate", Color(1.3, 1.25, 0.6, 1.0), 0.3)
