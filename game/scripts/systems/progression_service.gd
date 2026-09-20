## 경험치·레벨업 오토로드(M3-1, F1-2). ProgressionCalc(순수 계산)를 감싸 Data 테이블
## 조회·GameState 반영·Events 발신 같은 부수효과만 담당한다(resources.gd/inventory.gd와
## 동일한 "계산은 순수 클래스, 반영은 오토로드/서비스" 원칙). UI(ui-ux-designer,
## stage/m3-2-progress-ui)와 합의된 공개 인터페이스:
##   Events.exp_changed(current_exp, exp_to_next, level)
##   Events.level_up(new_level, stat_gains)
##   GameState.level / GameState.exp (읽기용)
##   Progression.exp_for_level(level) / Progression.exp_reward_for_monster(monster_id)
extends Node

const MAX_LEVEL_FALLBACK := 50


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	# D-150(c): 세이브 로드 직후에도 1회 발신해 HUD가 로드 즉시 올바른 값을 갖게 한다.
	# GameState.from_dict()가 이미 끝난 뒤 SaveManager가 이 신호를 쏘므로 타이밍이 맞다.
	Events.load_completed.connect(_on_load_completed)


func _max_level() -> int:
	return int(Data.get_value("stats", "max_level", MAX_LEVEL_FALLBACK))


## 레벨 n -> n+1 도달에 필요한 경험치(exp_curve.csv 기반 순수 함수 래핑).
func exp_for_level(level: int) -> int:
	return ProgressionCalc.exp_for_level(level, Data.table("exp_curve"))


## monster_id 처치 시 지급할 경험치(monsters.json.exp_reward 기반).
func exp_reward_for_monster(monster_id: StringName) -> int:
	return ProgressionCalc.exp_reward_for_monster(String(monster_id), Data.table("monsters"))


## 경험치를 지급하고, 필요한 만큼 레벨업까지 처리한다(퀘스트 보상·몬스터 처치 등 모든
## 경험치 지급 경로가 공통으로 거치는 진입점). amount<=0이면 아무 일도 하지 않는다.
func grant_exp(amount: int) -> void:
	if amount <= 0:
		return
	var max_level: int = _max_level()
	var curve: Dictionary = Data.table("exp_curve")
	var result: Dictionary = ProgressionCalc.apply_exp(GameState.exp, GameState.level, amount, curve, max_level)
	GameState.exp = int(result.get("exp", GameState.exp))
	GameState.level = int(result.get("level", GameState.level))
	for entry: Dictionary in (result.get("level_ups", []) as Array):
		var new_level: int = int(entry.get("new_level", GameState.level))
		var stat_gains: Dictionary = entry.get("stat_gains", {})
		_apply_level_up_effects(stat_gains)
		Events.level_up.emit(new_level, stat_gains)
	_emit_exp_changed()


## D-151: 레벨업 시 자동 상승분을 GameState에 누적하고 장비 스탯 재계산에 반영한
## 뒤(장비 착탈/로드 시마다 재계산돼도 사라지지 않도록), 스탯/스킬 포인트를 쌓고
## HP·스태미나를 전량 회복시킨다(GDD 5.1 + D-151 "스태미나도 함께").
func _apply_level_up_effects(stat_gains: Dictionary) -> void:
	var hp_gain: int = int(stat_gains.get("max_hp", 0))
	var atk_gain: float = float(stat_gains.get("attack", 0.0))
	GameState.level_stat_bonus["max_hp"] = int(GameState.level_stat_bonus.get("max_hp", 0)) + hp_gain
	GameState.level_stat_bonus["attack"] = float(GameState.level_stat_bonus.get("attack", 0.0)) + atk_gain
	GameState.stat_points += int(Data.get_value("stats", "stat_points_per_levelup", 3))
	GameState.skill_points += int(Data.get_value("stats", "skill_points_per_levelup", 1))
	GameState.recompute_player_stats()
	var player: Player = GameState.get_player()
	if player == null or player.resources == null:
		return
	player.resources.hp = player.resources.max_hp
	player.resources.stamina = player.resources.max_stamina
	Events.player_hp_changed.emit(player.resources.hp, player.resources.max_hp)
	Events.player_stamina_changed.emit(player.resources.stamina, player.resources.max_stamina)


func _emit_exp_changed() -> void:
	Events.exp_changed.emit(GameState.exp, exp_for_level(GameState.level), GameState.level)


## D-150(a): 몬스터를 실제로 처치한 주체가 플레이어일 때만 지급한다. 플레이어 공격의
## Hitbox.source는 항상 플레이어 노드 자신으로 채워지므로(attack.gd:hitbox.source =
## player), 몬스터 발사체처럼 source를 "발사 주체"(몬스터 자신)로 채우는 경우와
## 명확히 구분된다 — 향후 플레이어 투사체가 생겨도 같은 관례(source=플레이어)를 따르는
## 한 이 검사로 충분하다.
func _on_enemy_died(enemy: Node, killer: Node) -> void:
	if not (killer is Player):
		return
	if not (enemy is MonsterBase):
		return
	var reward: int = exp_reward_for_monster(StringName((enemy as MonsterBase).monster_id))
	grant_exp(reward)


func _on_load_completed(_slot: int, _kind: StringName, ok: bool) -> void:
	if not ok:
		return
	_emit_exp_changed()
