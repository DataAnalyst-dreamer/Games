## 헤드리스 스모크 테스트: "피격 후 HP바 값 갱신 · 스태미나 부족 점멸 시그널 수신 ·
## settings.json 저장 파일 생성"(F7-1 태스크 6/7).
##
## 실행: godot --headless --path game res://tests/smoke/SmokeHud.tscn --quit-after 200
extends Node

var _main: Node
var _hud: Hud
var _player: Player

var _elapsed: float = 0.0
var _done: bool = false

var _hp_bar_updated: bool = false
var _flash_seen_active: bool = false
var _flash_seen_cleared: bool = false
var _settings_file_created: bool = false


func _ready() -> void:
	print("=== SMOKE HUD: HP바 갱신 · 스태미나 부족 점멸 · settings.json 저장 ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_player = _main.get_node("Player") as Player
	_hud = _main.get_node("Hud/Root") as Hud

	# 몬스터가 개입하지 않도록 치운다 — HP 변화는 이 스모크가 직접 유발한다.
	for monster_name in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1"]:
		var m: Node = _main.get_node_or_null(monster_name)
		if m != null:
			m.queue_free()

	var before_hp: int = _player.resources.hp
	var damage := 30
	_player.resources.take_damage(damage)
	Events.player_hp_changed.emit(_player.resources.hp, _player.resources.max_hp)
	print("피격 시뮬레이션: hp %d -> %d" % [before_hp, _player.resources.hp])

	Events.player_stamina_insufficient.emit(&"roll")
	print("Events.player_stamina_insufficient 발신")

	var save_err: Error = Settings.save_settings()
	print("Settings.save_settings() 결과=%s" % save_err)


func _process(delta: float) -> void:
	_elapsed += delta

	if not _hp_bar_updated and int(_hud.hp_bar.value) == _player.resources.hp:
		_hp_bar_updated = true
		print("t=%.2f HP바 값 갱신 확인: hp_bar.value=%d (플레이어 hp=%d)" \
			% [_elapsed, int(_hud.hp_bar.value), _player.resources.hp])

	if _hud.stamina_flash_active and not _flash_seen_active:
		_flash_seen_active = true
		print("t=%.2f 스태미나 점멸 진입 확인(stamina_flash_active=true)" % _elapsed)
	elif _flash_seen_active and not _hud.stamina_flash_active and not _flash_seen_cleared:
		_flash_seen_cleared = true
		print("t=%.2f 스태미나 점멸 해제 확인(stamina_flash_active=false)" % _elapsed)

	if not _settings_file_created and FileAccess.file_exists("user://settings.json"):
		_settings_file_created = true
		print("t=%.2f user://settings.json 존재 확인" % _elapsed)

	if _elapsed > 1.5 and not _done:
		_finish()


func _finish() -> void:
	_done = true
	print("--- 결과 ---")
	print("HP바 갱신=%s, 스태미나 점멸 진입=%s/해제=%s, settings.json 생성=%s" \
		% [_hp_bar_updated, _flash_seen_active, _flash_seen_cleared, _settings_file_created])
	if _hp_bar_updated and _flash_seen_active and _flash_seen_cleared and _settings_file_created:
		print("[PASS] HUD가 피격/스태미나 부족 플래시/설정 저장을 모두 반영했다")
	else:
		print("[FAIL] 기대: HP바 갱신 + 스태미나 점멸 진입·해제 + settings.json 생성")
	get_tree().quit()
