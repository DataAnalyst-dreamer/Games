## 정예 리스폰 관리(F6-3, D-15, elite-and-farming-m2.md §1/§2). farming_sources.json의
## `type == "elite"` 항목(elite_goblin_captain/elite_bunchi_spawn) 각각을 고정 스폰
## 지점에 유지한다 — 처치되면 respawn_seconds(1800초=30분)짜리 카운트다운을
## GameState.elite_respawn_remaining_sec에 심어 두고, 그 값이 실제 플레이 시간(D-15,
## GameState._process()가 매 프레임 감소시킴 — 일시정지 중에는 엔진이 이 함수 자체를
## 호출하지 않아 자동으로 제외된다)만큼 흘러 0 이하가 되면 다시 스폰한다.
##
## 이 노드는 Main.tscn(작은 검증용 아레나 — 정예 2종을 이미 고정 배치해 둔 상태, M2-3
## §6)에는 배치하지 않는다 — 둘 다 붙이면 같은 정예가 중복 스폰된다. 실제 오픈월드
## 청크 스트리밍이 들어오면 그 레벨 루트에 이 노드 하나만 배치하면 된다(F6-3 요구사항
## "스폰 존 내 랜덤 위치"의 "고정 스폰 지점" 버전 — 정예는 스폰 지점 자체가 고정이라
## GDD 8.1/hartland.md ⑤와 정합).
##
## GUT 테스트(tests/unit/test_elite_spawner.gd)는 실제 벽시계 시간을 기다리는 대신
## GameState.elite_respawn_remaining_sec을 직접 조작하거나 GameState._process(delta)를
## 큰 delta로 한 번 호출해 "30분 경과"를 흉내낸 뒤 check_respawns()를 직접 호출한다.
class_name EliteSpawner
extends Node

## source_id(=monsters.json의 monster_id, farming_sources.json의 source_id와 동일
## 문자열) -> 씬.
const ELITE_SCENES := {
	"elite_goblin_captain": preload("res://scenes/entities/monsters/EliteGoblinCaptain.tscn"),
	"elite_bunchi_spawn": preload("res://scenes/entities/monsters/EliteBunchiSpawn.tscn"),
}

## docs/levels/hartland.md ⑤ 좌표(전역 타일) — farming_sources.json.location.
## pos_global_tile와 같은 값이다. 그 필드가 data_tables.md §11 정식 스키마 밖의 제안
## 필드라(elite-and-farming-m2.md §2-2) 여기서는 "고정 스폰 지점을 임시 상수로 관리"
## (M2-3 지시)한다 — 두 값이 어긋나면 game-designer 확인 필요(완료 보고 TODO).
const SPAWN_POS_GLOBAL_TILE := {
	"elite_goblin_captain": Vector2(296.0, 152.0),
	"elite_bunchi_spawn": Vector2(24.0, 272.0),
}

## source_id -> 현재 살아있는 인스턴스(Node) 또는 null.
var _instances: Dictionary = {}


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	for source_id in ELITE_SCENES.keys():
		_instances[source_id] = null
		if float(GameState.elite_respawn_remaining_sec.get(source_id, 0.0)) <= 0.0:
			_spawn(source_id)


func _physics_process(_delta: float) -> void:
	check_respawns()


## 매 프레임(또는 테스트에서 직접) 호출 — 죽어 있고 타이머가 다 된 정예를 스폰한다.
func check_respawns() -> void:
	for source_id in ELITE_SCENES.keys():
		var inst: Node = _instances.get(source_id)
		if inst != null and is_instance_valid(inst):
			continue
		if float(GameState.elite_respawn_remaining_sec.get(source_id, 0.0)) <= 0.0:
			_spawn(source_id)


func _spawn(source_id: String) -> void:
	var scene: PackedScene = ELITE_SCENES.get(source_id)
	if scene == null:
		return
	var inst: MonsterBase = scene.instantiate()
	var tile_pos: Vector2 = SPAWN_POS_GLOBAL_TILE.get(source_id, Vector2.ZERO)
	inst.global_position = tile_pos * float(Tuning.TILE_SIZE_PROTOTYPE)
	add_child(inst)
	_instances[source_id] = inst
	GameState.elite_respawn_remaining_sec.erase(source_id)


func _on_enemy_died(enemy: Node2D, _killer: Node) -> void:
	if enemy == null or not (enemy is MonsterBase):
		return
	var monster_id: String = (enemy as MonsterBase).monster_id
	if not ELITE_SCENES.has(monster_id):
		return
	if _instances.get(monster_id) != enemy:
		return # 이 스포너가 관리하는 인스턴스가 아님(예: 다른 곳의 동일 종 정예).
	_instances[monster_id] = null
	var respawn_sec: float = float(Data.get_value("farming_sources", monster_id, {}).get("respawn_seconds", 1800.0))
	GameState.elite_respawn_remaining_sec[monster_id] = respawn_sec
