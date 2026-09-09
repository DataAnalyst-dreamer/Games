## Events.enemy_died 구독 → LootSystem으로 드랍을 굴리고 ItemDrop.tscn을 스폰하는
## 씬 레벨 접착 코드(F3-1). LootSystem 자체는 순수 로직(오토로드 아님)이므로, 실제
## "언제/어디에 스폰할지"는 이 노드가 담당한다 — Main.tscn에 CameraShake 등과 같은
## 레벨로 배치된 평범한 Node(오토로드 아님, HitFeel/HitFlash와 유사한 접착 계층).
##
## 골드는 즉시 GameState.add_gold()로 지급(F3-1 "골드는 즉시 획득")하고, 아이템은
## ItemDrop 오브젝트로 필드에 스폰해 접근 시 자동 획득되게 한다.
extends Node

const ITEM_DROP_SCENE: PackedScene = preload("res://scenes/world/ItemDrop.tscn")

## 여러 드랍이 겹쳐 스폰되지 않도록 하는 산개 반경(px). 순수 연출값 — 테이블화 대상 아님.
const SCATTER_RADIUS_PX := 10.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Node2D, _killer: Node) -> void:
	if enemy == null or not (enemy is MonsterBase):
		return
	var monster_def: Dictionary = Data.get_value("monsters", (enemy as MonsterBase).monster_id, {})
	var drop_table_id_raw: Variant = monster_def.get("drop_table_id")
	if drop_table_id_raw == null:
		return # D-67: null은 "확정된 드랍 없음" — goblin_scout처럼 전용 테이블이 아직 없는 몬스터.
	var drop_table_id := StringName(drop_table_id_raw)

	var luck: float = GameState.get_player_luck()
	var gold: int = LootSystem.roll_gold(drop_table_id, _rng)
	if gold > 0:
		GameState.add_gold(gold)

	for item_instance: Dictionary in LootSystem.roll_drop(drop_table_id, luck, _rng):
		_spawn_drop(item_instance, enemy.global_position)


func _spawn_drop(item_instance: Dictionary, at_position: Vector2) -> void:
	var item_def: Dictionary = Data.get_value("items", String(item_instance.get("item_id", "")), {})
	if item_def.is_empty():
		return
	var drop: ItemDrop = ITEM_DROP_SCENE.instantiate()
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(drop)
	drop.global_position = at_position + Vector2(
		_rng.randf_range(-SCATTER_RADIUS_PX, SCATTER_RADIUS_PX),
		_rng.randf_range(-SCATTER_RADIUS_PX, SCATTER_RADIUS_PX),
	)
	drop.setup(item_instance, item_def)
