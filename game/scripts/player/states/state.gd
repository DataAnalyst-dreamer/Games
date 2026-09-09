## 플레이어 상태 베이스 클래스.
##
## 새 상태(attack/roll/hurt/dead 등)는 이 클래스를 상속한 별도 스크립트로 만들고,
## Player.tscn 의 StateMachine 노드 아래에 자식 노드로 붙이면 자동 등록된다.
## 노드 이름이 곧 상태 이름(StringName)이다. 전환은 `finished.emit(&"Move")` 로 요청한다.
class_name PlayerState
extends Node

## 다음 상태로 전환을 요청한다. data 는 다음 상태의 enter() 에 그대로 전달된다.
signal finished(next_state: StringName, data: Dictionary)

## StateMachine 이 _ready 시점에 주입한다.
var player: Player


## 상태 진입. prev 는 직전 상태 이름(최초 진입 시 빈 StringName).
func enter(_prev: StringName, _data: Dictionary = {}) -> void:
	pass


## 상태 이탈.
func exit() -> void:
	pass


## Player._unhandled_input 에서 위임된다. 공격/구르기 입력 처리는 여기에.
func handle_input(_event: InputEvent) -> void:
	pass


## Player._process 에서 위임된다.
func update(_delta: float) -> void:
	pass


## Player._physics_process 에서 위임된다. move_and_slide 호출은 각 상태 책임.
func physics_update(_delta: float) -> void:
	pass


## 구르기 발동 공용 헬퍼(S2-1b 예외: "스태미나 부족 시 미발동 + 바 빨간색 깜박임").
## Idle/Move/Guard/Attack(캔슬 가능 시점) 등 구르기를 트리거할 수 있는 모든 상태가
## 공유한다 — 비용 계산은 Player.get_roll_cost()(DEX 경감 훅 포함)에 위임.
func try_enter_roll() -> void:
	if player.has_stamina_for_roll():
		finished.emit(&"Roll", {})
	else:
		Events.player_stamina_insufficient.emit(&"roll")


## 이 상태에서 적용할 스태미나 회복 배율(기본 1.0 = 정상 회복 속도). Guard처럼 회복이
## 느려지는 상태가 오버라이드한다(M1-2 제안값, combat.json stamina.guard_regen_
## multiplier).
func get_stamina_regen_multiplier() -> float:
	return 1.0
