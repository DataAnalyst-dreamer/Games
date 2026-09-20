## 헤드리스 스모크 테스트: 경험치바·레벨업 배너(M3-2, D-153).
##
## 실행: godot --headless --fixed-fps 60 --path game res://tests/smoke/SmokeProgressUi.tscn --quit-after 400
##
## 로직 브랜치(stage/m3-1-exp-level)가 아직 없어 Events.exp_changed/level_up을 이
## 스모크가 직접 emit해 UI만 독립적으로 검증한다(지시서 "개발 중엔 스모크에서 이
## 시그널을 직접 emit" 참고). Main.tscn을 그대로 써서(smoke_hud.gd와 같은 패턴)
## main_bootstrap.gd의 온보딩 자동수주와 실제 충돌하지 않는지도 같이 확인한다 —
## 이 스모크의 root(자기 자신)가 current_scene이라 온보딩은 스킵되어야 정상이다.
extends Node

var _main: Node
var _hud: Hud
var _progress: HudProgress

var _elapsed: float = 0.0
var _phase: int = 0
var _done: bool = false

var _exp_bar_updated: bool = false
var _level_label_updated: bool = false
var _banner_shown: bool = false
var _banner_stats_ok: bool = false
var _banner_auto_hidden: bool = false
var _onboarding_skipped: bool = false


func _ready() -> void:
	print("=== SMOKE PROGRESS UI: 경험치바·레벨업 배너 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)
	_hud = _main.get_node("UiRoot/Hud/Root") as Hud
	_progress = _hud.get_node("HudProgress") as HudProgress

	# 이 스모크 노드(SmokeProgressUi)가 current_scene이어야 main_bootstrap.gd가
	# 온보딩을 스킵한다 — smoke_quest.gd 등 기존 스모크가 깨지지 않는 근거와 동일.
	_onboarding_skipped = QuestSystem.get_state("quest_main_a1_01_arrival") == "available"
	print("온보딩 스킵 확인(quest_main_a1_01_arrival=available 유지)=%s" % _onboarding_skipped)

	Events.exp_changed.emit(30, 100, 3)
	print("Events.exp_changed(30, 100, 3) 발신")


func _process(delta: float) -> void:
	_elapsed += delta

	if not _exp_bar_updated and is_equal_approx(_progress.exp_bar.value, 30.0) \
			and is_equal_approx(_progress.exp_bar.max_value, 100.0):
		_exp_bar_updated = true
		print("t=%.2f ExpBar 갱신 확인: value=%.1f max=%.1f" % [_elapsed, _progress.exp_bar.value, _progress.exp_bar.max_value])

	if not _level_label_updated and _progress.level_label.text.contains("3"):
		_level_label_updated = true
		print("t=%.2f LevelLabel 갱신 확인: %s" % [_elapsed, _progress.level_label.text])

	if _phase == 0 and _exp_bar_updated and _level_label_updated:
		_phase = 1
		Events.level_up.emit(4, {"max_hp": 10, "attack": 2})
		print("Events.level_up(4, {max_hp:10, attack:2}) 발신")

	if _phase == 1:
		if not _banner_shown and _progress.banner.visible:
			_banner_shown = true
			print("t=%.2f LevelUpBanner 표시 확인: %s" % [_elapsed, _progress.banner_title.text])
		if not _banner_stats_ok and _progress.banner_stats.text.contains("MAX_HP") and _progress.banner_stats.text.contains("ATTACK"):
			_banner_stats_ok = true
			print("t=%.2f 배너 스탯 텍스트 확인: %s" % [_elapsed, _progress.banner_stats.text])
		if _banner_shown and not _progress.banner.visible and not _banner_auto_hidden:
			_banner_auto_hidden = true
			print("t=%.2f 배너 자동 소멸 확인" % _elapsed)

	if _elapsed > 5.0 and not _done:
		_finish()


func _finish() -> void:
	_done = true
	print("--- 결과 ---")
	print("온보딩 스킵=%s, ExpBar=%s, LevelLabel=%s, 배너 표시=%s, 배너 스탯=%s, 배너 자동소멸=%s" \
		% [_onboarding_skipped, _exp_bar_updated, _level_label_updated, _banner_shown, _banner_stats_ok, _banner_auto_hidden])
	if _onboarding_skipped and _exp_bar_updated and _level_label_updated and _banner_shown \
			and _banner_stats_ok and _banner_auto_hidden:
		print("[PASS] 경험치바·레벨업 배너가 신호만으로 정상 갱신/자동 소멸했다")
	else:
		print("[FAIL] 기대: 온보딩 스킵 + ExpBar/LevelLabel 갱신 + 배너 표시·스탯·자동소멸")
	get_tree().quit()
