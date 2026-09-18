## 새 게임 온보딩 부트스트랩(D-154, M3-2). Main 씬이 "실제 부팅 대상"으로 실행될 때만
## 1회 QuestSystem.ensure_onboarding_quest()를 호출해 MQ01을 자동 수주 + 추적 지정한다.
##
## `get_tree().current_scene == self` 가드가 핵심이다: 정식 실행(project.godot의
## run/main_scene=Main.tscn)에서는 엔진이 Main 인스턴스를 current_scene으로 세우지만,
## 기존 스모크 테스트 다수(smoke_quest.gd/smoke_quest_layout.gd/smoke_save_load.gd 등)는
## 자기 자신을 current_scene으로 두고 Main.tscn을 `add_child()`로 하위에 인스턴스화해
## QuestSystem.reset() 직후 "MQ01 초기 상태 available"을 직접 검증한다 — 그 흐름을
## 그대로 두기 위해 여기서는 조용히 스킵한다(회귀 방지, docs/qa 스모크 목록 참고).
extends Node2D


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	QuestSystem.ensure_onboarding_quest()
