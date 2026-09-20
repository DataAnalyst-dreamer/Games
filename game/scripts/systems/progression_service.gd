## 경험치·레벨업 오토로드(M3-1, F1-2). ProgressionCalc(순수 계산)를 감싸 Data 테이블
## 조회·GameState 반영·Events 발신 같은 부수효과만 담당한다(resources.gd/inventory.gd와
## 동일한 "계산은 순수 클래스, 반영은 오토로드/서비스" 원칙). UI(ui-ux-designer,
## stage/m3-2-progress-ui)와 합의된 공개 인터페이스:
##   Events.exp_changed(current_exp, exp_to_next, level)
##   Events.level_up(new_level, stat_gains)
##   GameState.level / GameState.exp (읽기용)
##   Progression.exp_for_level(level) / Progression.exp_reward_for_monster(monster_id)
##
## M3-3(D-158~D-162, F1-2/F1-3) 추가: 5스탯 분배 + 스킬 배우기/장착/시전/쿨타임. 계산은
## StatCalc/SkillCalc(순수, RefCounted)에 위임하고 여기는 GameState 반영·Events 발신·
## 쿨타임 타이머만 담당한다(기존 exp/레벨 부분과 동일 원칙). 합의된 공개 인터페이스:
##   Progression.allocate_stat(key) / get_derived() / learn_skill(id) /
##   can_cast_skill(slot) / start_skill_cooldown(slot, skill_id) /
##   roll_crit(damage) (attack.gd/skill.gd 공용)
##   Events.stats_changed / skill_cast / skill_ready
##
## M4-1(D-175~D-177) 추가: 핫바 9칸(스킬·아이템 혼용). 기존 skill_1(Q)/skill_2(R) 전용
## equip_skill/unequip_skill(slot 0~1 고정)은 assign_hotbar/clear_hotbar(slot 0~8)로
## 대체했다 — 스킬 배정 시 skill_slots[slot]도 함께 채워 can_cast_skill/시전/쿨타임은
## 그대로 slot 인덱스로 동작한다. 옛 세이브(2칸 skill_slots, hotbar 없음) 마이그레이션은
## _on_load_completed()에서 처리한다(GameState.from_dict()는 필드 로딩만 담당).
##   Progression.assign_hotbar(slot, kind, id) / clear_hotbar(slot)
##   Events.hotbar_changed / skills_changed(learned, slots, skill_points — slots는 이제 9칸)
extends Node

const MAX_LEVEL_FALLBACK := 50
const STAT_KEYS: Array[String] = ["str", "dex", "int", "vit", "luk"]

## slot(int) -> 남은 쿨타임(초). 값이 있는 슬롯만 담아 매 프레임 순회를 최소화한다.
var _skill_cooldowns: Dictionary = {}


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	# D-150(c): 세이브 로드 직후에도 1회 발신해 HUD가 로드 즉시 올바른 값을 갖게 한다.
	# GameState.from_dict()가 이미 끝난 뒤 SaveManager가 이 신호를 쏘므로 타이밍이 맞다.
	Events.load_completed.connect(_on_load_completed)


## 스킬 쿨타임 타이머(M3-3). HUD가 슬롯별 잔여 쿨타임을 직접 조회할 필요 없이
## skill_ready(slot) 신호만 구독하면 되도록, 0에 도달한 슬롯만 골라 통지한다.
func _process(delta: float) -> void:
	if _skill_cooldowns.is_empty():
		return
	for slot: Variant in _skill_cooldowns.keys().duplicate():
		var remaining: float = float(_skill_cooldowns[slot]) - delta
		if remaining <= 0.0:
			_skill_cooldowns.erase(slot)
			Events.skill_ready.emit(int(slot))
		else:
			_skill_cooldowns[slot] = remaining


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
	_migrate_hotbar_if_needed()
	_emit_exp_changed()
	_emit_stats_changed()
	_emit_skills_changed()


## M4-1(D-175~D-177) 세이브 마이그레이션. GameState.from_dict()는 옛 세이브(hotbar 필드
## 없음)를 의도적으로 빈 배열(size 0)로 남겨 둔다(game_state.gd 주석 참고) — 새 게임
## 기본값(9칸, 빈 dict로 채움)과 구분하기 위해서다. 여기서만 그 구분을 소비해 옛
## skill_slots(0/1번 칸)를 hotbar로 승격한다. 신규 세이브(hotbar 이미 9칸)는 그냥 지나간다.
func _migrate_hotbar_if_needed() -> void:
	if not GameState.hotbar.is_empty():
		return
	var migrated: Array = []
	for skill_id_v: Variant in GameState.skill_slots:
		var skill_id: String = String(skill_id_v)
		migrated.append({"kind": "skill", "id": skill_id} if skill_id != "" else {"kind": "", "id": ""})
	GameState.hotbar = migrated
	Events.hotbar_changed.emit(GameState.hotbar)


# --- M3-3: 스탯 분배 ---

## 스탯 포인트 1개를 key(str/dex/int/vit/luk)에 분배한다. 포인트가 없거나 key가 잘못되면
## false(D-158: 스탯당 상한 없음 — allocation.max_per_stat=null).
func allocate_stat(key: String) -> bool:
	if not StatCalc.can_allocate(key, GameState.stat_points, STAT_KEYS):
		return false
	GameState.stat_points -= 1
	GameState.stats[key] = int(GameState.stats.get(key, 0)) + 1
	GameState.recompute_player_stats()
	_emit_stats_changed()
	return true


## 파생 전투 수치(HUD 표시용). attack/max_hp/defense는 실제 게임플레이가 쓰는 것과 동일한
## StatCalc 호출로 계산해 표시값과 실제 값이 어긋나지 않는다.
func get_derived() -> Dictionary:
	var s: Dictionary = GameState.stats
	var player: Player = GameState.get_player()
	var attack: float = player.get_attack_power() if player != null else Tuning.PLAYER_BASE_ATTACK
	var max_hp: int = player.resources.max_hp if player != null and player.resources != null else Tuning.PLAYER_MAX_HP
	var equip_defense: float = player.equip_defense if player != null else 0.0
	var defense: float = StatCalc.defense_value(
		int(s.get("vit", 0)), float(Data.get_value("stats", "vit.defense_per_point", 1.0)), equip_defense)
	var roll_cost_mult: float = PlayerResources.roll_cost_with_dex(1.0, float(s.get("dex", 0)))
	var cd_mult: float = StatCalc.cooldown_mult(
		int(s.get("int", 0)),
		float(Data.get_value("stats", "int.cooldown_reduction_per_point", 0.002)),
		float(Data.get_value("stats", "int.cooldown_reduction_cap_pct", 0.30)))
	return {
		"attack": attack,
		"max_hp": max_hp,
		"defense": defense,
		"crit_chance": _crit_chance(),
		"roll_cost_mult": roll_cost_mult,
		"cooldown_mult": cd_mult,
	}


func _emit_stats_changed() -> void:
	Events.stats_changed.emit(GameState.stats, get_derived(), GameState.stat_points)


func _crit_chance() -> float:
	return StatCalc.crit_chance(
		int(GameState.stats.get("luk", 0)),
		float(Data.get_value("stats", "luk.base_crit_chance", 0.05)),
		float(Data.get_value("stats", "luk.crit_chance_per_point", 0.001)),
		float(Data.get_value("stats", "luk.crit_chance_cap", 0.75)))


## STR/스킬 기본 데미지에 LUK 진짜 크리티컬을 굴려 적용한다(attack.gd/skill.gd 공용,
## D-162 (b): crit_chance_per_point=0.001을 그대로 쓴다). 반환: {damage, is_critical}.
func roll_crit(damage: int) -> Dictionary:
	var is_crit: bool = randf() < _crit_chance()
	var final_damage: int = damage
	if is_crit:
		final_damage = StatCalc.crit_damage(damage, float(Data.get_value("stats", "luk.crit_damage_multiplier", 1.5)))
	return {"damage": final_damage, "is_critical": is_crit}


# --- M3-3: 스킬 배우기/장착/시전/쿨타임 ---

## skills.json 확인 + 스킬 포인트 소모 + 습득 반영(D-159: 레벨 게이트 없음).
func learn_skill(id: String) -> bool:
	if not SkillCalc.can_learn(id, GameState.learned_skills, GameState.skill_points, Data.table("skills")):
		return false
	var entry: Dictionary = Data.get_value("skills", id, {})
	GameState.skill_points -= int(entry.get("cost_sp", 1))
	GameState.learned_skills.append(id)
	_emit_skills_changed()
	return true


## slot(0~8)에 skill 또는 item을 배정한다(M4-1, D-160 계승: 슬롯 교체 자유).
## kind="skill"이면 배운 스킬만(SkillCalc.can_equip), kind="item"이면 id만 있으면 된다
## (재고 유무는 시전 시점에 판단 — D-177: 재고 0이어도 슬롯 배정 자체는 유지).
## D-175: 같은 스킬을 여러 슬롯에 중복 배정하는 것을 막지 않는다(제약 없음).
func assign_hotbar(slot: int, kind: String, id: String) -> bool:
	if slot < 0 or slot >= GameState.hotbar.size():
		return false
	if kind == "skill":
		if not SkillCalc.can_equip(id, GameState.learned_skills):
			return false
		GameState.skill_slots[slot] = id
	elif kind == "item":
		# 소비품만 핫바 대상(장비·재료는 조용히 거부). UI 두 경로(스킬 패널·인벤토리)가
		# 모두 여기를 거치므로 판정은 이 한 곳에만 둔다.
		if id == "" or String(Data.get_value("items", id, {}).get("category", "")) != "consumable":
			return false
		GameState.skill_slots[slot] = "" # 이 슬롯에 스킬이 있었다면 해제.
	else:
		return false
	GameState.hotbar[slot] = {"kind": kind, "id": id}
	_emit_skills_changed()
	Events.hotbar_changed.emit(GameState.hotbar)
	return true


func clear_hotbar(slot: int) -> void:
	if slot < 0 or slot >= GameState.hotbar.size():
		return
	GameState.skill_slots[slot] = ""
	GameState.hotbar[slot] = {"kind": "", "id": ""}
	_emit_skills_changed()
	Events.hotbar_changed.emit(GameState.hotbar)


func _emit_skills_changed() -> void:
	Events.skills_changed.emit(GameState.learned_skills, GameState.skill_slots, GameState.skill_points)


## slot에 스킬이 장착돼 있고, 쿨타임이 다 됐고, 스태미나가 충분하면 true(skill.gd 진입
## 전 state.gd:try_enter_skill()이 조회).
func can_cast_skill(slot: int) -> bool:
	if slot < 0 or slot >= GameState.skill_slots.size():
		return false
	var id: String = GameState.skill_slots[slot]
	if id == "":
		return false
	var player: Player = GameState.get_player()
	var stamina: float = player.resources.stamina if player != null and player.resources != null else 0.0
	return SkillCalc.can_cast(id, Data.table("skills"), stamina, float(_skill_cooldowns.get(slot, 0.0)))


## 시전 성공 시(skill.gd가 스태미나를 실제로 소모한 직후) 호출 — INT 쿨감을 적용한 실제
## 쿨타임을 등록하고 HUD용 Events.skill_cast를 발신한다.
func start_skill_cooldown(slot: int, skill_id: String) -> void:
	var entry: Dictionary = Data.get_value("skills", skill_id, {})
	var base_cd: float = float(entry.get("cooldown_sec", 0.0))
	var cd: float = SkillCalc.effective_cooldown(base_cd, get_derived().get("cooldown_mult", 1.0))
	_skill_cooldowns[slot] = cd
	Events.skill_cast.emit(slot, skill_id, cd)
