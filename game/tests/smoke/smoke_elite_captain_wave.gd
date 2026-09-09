## 헤드리스 스모크 테스트: "고블린 정찰대장 HP 50% → 소환 웨이브 1회 발동".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeEliteCaptainWave.tscn --quit-after 400
##
## 실제 플레이어 콤보 타이밍을 재현하는 대신(smoke_player_kills_slime.gd 참고 — 여기서는
## "웨이브 발동 자체"가 검증 대상이라 그 경로는 불필요한 노이즈), 합성 Hitbox로 HP를
## 정확히 50% 밑으로 떨어뜨려 WAVE 상태 진입 → wave_cast_sec 경과 → wave_summon_count
## (3)마리 소환까지 실제 MonsterBase 상태머신을 그대로 태운다(elite-and-farming-m2.md §1-2).
extends Node

var _main: Node
var _captain: MonsterBase

var _elapsed: float = 0.0
var _last_state: int = -1
var _hit_applied: bool = false
var _wave_seen: bool = false
var _done: bool = false


func _ready() -> void:
	print("=== SMOKE: 고블린 정찰대장 소환 웨이브(HP 50%) ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	var player := _main.get_node("Player")
	_captain = _main.get_node("EliteGoblinCaptain1") as MonsterBase
	for n in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1",
			"GoblinScout1", "GoblinScout2", "EliteBunchiSpawn1"]:
		var other := _main.get_node(n)
		if other != null:
			other.queue_free()

	_captain._player = player # 웨이브 완료 후 소환된 개체들이 곧장 CHASE하도록.
	print("captain hp=%d max_hp=%d wave_trigger_hp_pct=%.2f wave_cast_sec=%.2f wave_summon_count=%d" \
		% [_captain.hp, _captain.max_hp, _captain.wave_trigger_hp_pct, _captain.wave_cast_sec, _captain.wave_summon_count])

	var hb := Hitbox.new()
	add_child(hb)
	# hp=120 -> 61 데미지 -> 59(=49.2%) <= 50% 임계.
	hb.damage = int(_captain.max_hp * _captain.wave_trigger_hp_pct) + 1
	_captain._on_hurtbox_hurt(hb)
	_hit_applied = true
	print("합성 히트 적용: damage=%d -> captain.hp=%d" % [hb.damage, _captain.hp])


func _process(delta: float) -> void:
	_elapsed += delta

	if _captain.state != _last_state:
		print("t=%.3f captain 상태 전이 -> %s" % [_elapsed, MonsterBase.State.keys()[_captain.state]])
		if _captain.state == MonsterBase.State.WAVE:
			_wave_seen = true
		_last_state = _captain.state

	if _wave_seen and _captain.state != MonsterBase.State.WAVE and not _done:
		var spawned: Array = []
		for child in _main.get_children():
			if child is MonsterBase and child != _captain:
				spawned.append(child)
		print("t=%.3f WAVE 종료. 소환된 개체 수=%d (기대 %d)" % [_elapsed, spawned.size(), _captain.wave_summon_count])
		if spawned.size() == _captain.wave_summon_count:
			print("[PASS] wave_summon_count만큼 소환 확인")
		else:
			print("[FAIL] 소환 수 불일치")
		_finish()
		return

	if _elapsed > 6.0 and not _done:
		print("[TIMEOUT] hit_applied=%s wave_seen=%s state=%s" \
			% [_hit_applied, _wave_seen, MonsterBase.State.keys()[_captain.state]])
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
