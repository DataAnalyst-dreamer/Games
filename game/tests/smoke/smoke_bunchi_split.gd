## 헤드리스 스모크 테스트: "뭉치의 새끼 처치 → 슬라임 2마리 분열 + 드랍 1회(부모만)".
##
## 실행: godot --headless --path game res://tests/smoke/SmokeBunchiSplit.tscn --quit-after 400
##
## Main.tscn의 LootSpawner(Events.enemy_died 구독)가 실제로 붙어 있는 상태에서 진행한다.
## on_death_split_*(§1-3)로 스폰된 slime 2마리는 suppress_loot_drop=true라 LootSpawner가
## 드랍을 굴리지 않아야 한다 — Events.gold_changed 발신 횟수로 "드랍 1회(부모만)"를
## 검증한다(slime_common/elite_bunchi_spawn 두 드랍 테이블 모두 gold_drop.min > 0이라
## 골드 지급은 항상 확정적으로 발생한다).
extends Node

var _main: Node
var _bunchi: MonsterBase

var _enemy_died_count: int = 0
var _gold_changed_count: int = 0
var _done: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	print("=== SMOKE: 뭉치의 새끼 분열 + 드랍(부모만) ===")
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_main = scene.instantiate()
	add_child(_main)

	_bunchi = _main.get_node("EliteBunchiSpawn1") as MonsterBase
	for n in ["Slime1", "Slime2", "Slime3", "HornRabbit1", "HornRabbit2", "Mushroom1",
			"GoblinScout1", "GoblinScout2", "EliteGoblinCaptain1"]:
		var other := _main.get_node(n)
		if other != null:
			other.queue_free()

	print("bunchi hp=%d on_death_split_monster_id=%s on_death_split_count=%d" \
		% [_bunchi.hp, _bunchi.on_death_split_monster_id, _bunchi.on_death_split_count])

	Events.enemy_died.connect(_on_enemy_died)
	Events.gold_changed.connect(_on_gold_changed)

	var hb := Hitbox.new()
	add_child(hb)
	hb.damage = _bunchi.hp + 999
	_bunchi._on_hurtbox_hurt(hb)


func _on_enemy_died(_enemy: Node2D, _killer: Node) -> void:
	_enemy_died_count += 1


func _on_gold_changed(_new_amount: int, _delta: int) -> void:
	_gold_changed_count += 1


func _process(delta: float) -> void:
	_elapsed += delta
	if _done:
		return

	var slimes: Array = []
	for child in _main.get_children():
		if child is MonsterBase and child != _bunchi and (child as MonsterBase).monster_id == "slime":
			slimes.append(child)

	# 3회(부모 1 + 분열체 2)의 enemy_died가 전부 발신될 때까지 기다린다 — 분열체는
	# 스폰 직후 생존 상태(hp>0)라 스스로 죽지 않으므로, 곧바로 관측 가능한 것은 부모의
	# enemy_died 1건뿐이다. 분열 개수만 먼저 확정되면 그걸로 판정한다.
	if slimes.size() >= _bunchi.on_death_split_count:
		print("t=%.3f 분열체 %d마리 확인, suppress_loot_drop=%s" \
			% [_elapsed, slimes.size(), str((slimes[0] as MonsterBase).suppress_loot_drop)])
		var all_suppressed := true
		for s: MonsterBase in slimes:
			if not s.suppress_loot_drop:
				all_suppressed = false
		print("enemy_died 발신 횟수(부모)=%d, gold_changed 발신 횟수=%d" \
			% [_enemy_died_count, _gold_changed_count])
		if slimes.size() == _bunchi.on_death_split_count and all_suppressed and _gold_changed_count == 1:
			print("[PASS] 슬라임 %d마리 분열 + 드랍은 부모 1회만" % slimes.size())
		else:
			print("[FAIL] 분열 수/드랍 억제/드랍 횟수 중 하나 이상 불일치")
		_finish()
		return

	if _elapsed > 5.0:
		print("[TIMEOUT] slimes=%d enemy_died=%d gold_changed=%d" \
			% [slimes.size(), _enemy_died_count, _gold_changed_count])
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("=== SMOKE 종료 ===")
	get_tree().quit()
