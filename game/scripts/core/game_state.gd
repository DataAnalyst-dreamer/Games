## 세이브/부활 등 전역 게임 상태 자동로드(F8-2, D-28). 골드·세이브 시스템이 아직 없어
## 현재는 "마지막으로 상호작용한 비석"과 사망 횟수(디버그용)만 추적한다.
extends Node

## 마지막으로 상호작용(활성화)한 비석(Waystone) 노드. null이면 아직 비석과 상호작용한
## 적이 없다는 뜻 — 이 경우 부활 위치는 원점(Vector2.ZERO)으로 대체한다(초기 스폰 비석을
## 어디에 둘지는 레벨 디자인 몫, TODO).
var last_waystone: Node2D = null

## 사망 횟수(디버그 HUD 표시용). 세이브 파일에 영구 기록할지는 F8-3(세이브) 범위.
var death_count: int = 0

## 보스전 사망 예외(D-23: 골드 손실 없이 보스방 앞 비석에서 즉시 재도전, 보스 HP 초기화)를
## 위한 자리표시 플래그. 보스 시스템이 아직 없어 지금은 아무도 이 값을 true로 바꾸지
## 않는다 — M2에서 보스 인카운터 진입/종료 시 이 플래그를 토글하도록 연결할 것.
var in_boss_encounter: bool = false


func _ready() -> void:
	Events.player_died.connect(_on_player_died)


## 비석과 상호작용했을 때 호출(Waystone.activate()). 워프 목적지 선택 UI는 M2 범위 —
## 지금은 "부활 기준점"으로만 쓰인다(D-28: 부활 비석 = 워프 비석 동일 오브젝트).
func set_last_waystone(waystone: Node2D) -> void:
	last_waystone = waystone


## 부활 위치. 비석과 상호작용한 적이 없으면 원점.
func get_respawn_position() -> Vector2:
	if last_waystone != null and is_instance_valid(last_waystone):
		return last_waystone.global_position
	return Vector2.ZERO


func _on_player_died() -> void:
	death_count += 1
