## 퀘스트 시스템 자동로드(F5-1·F5-2, M2-7).
##
## 데이터: game/data/quests/*.json(Data.table("quests"), quest_id -> Quest 스키마 —
## docs/specs/quest-data-schema.md 정본). 로직은 Data/Events/GameState 세 오토로드만
## 참조하고 씬 트리(플레이어/월드 노드)에는 의존하지 않아 GUT이 이 스크립트를 직접
## preload해 격리된 인스턴스로 테스트할 수 있다(다른 core/*.gd 오토로드와 동일한
## "GUT 가능" 관례 — test_game_state.gd·test_data.gd 참고). scripts/systems/ 아래 있지만
## project.godot에 "QuestSystem" 이름으로 오토로드 등록된다(다른 systems/*.gd는 대개
## RefCounted 순수 클래스 + core/*.gd 래퍼 조합이지만, 이 시스템은 GameState처럼 그
## 자체가 상태를 들고 Events를 직접 구독/발신해도 충분히 순수 테스트 가능해 별도
## RefCounted 계층을 두지 않았다 — docs/specs/quest-system-m2.md §1 참고).
##
## 상태 머신(퀘스트 1개 기준): locked -> available -> active -> complete_ready -> completed
## (daily_template은 completed 대신 "오늘 완료됨" 버킷으로 갔다가 GameState.day_index가
## 바뀌면 다시 available로 돌아온다 — repeatable 퀘스트라 영구 완료 목록에 넣지 않는다).
##
## 목표 진행은 전부 Events 구독으로 자동 처리한다(monster_died/item_acquired/
## location_reached/npc_talked/object_interacted) — 호출부가 QuestSystem을 직접 찌를
## 필요가 없다. accept()/abandon()/advance()/choose_branch() 4개만 플레이어 행동(수주/
## 포기/턴인/분기 선택)에 대응하는 명시적 API다.
extends Node

const STATE_LOCKED := "locked"
const STATE_AVAILABLE := "available"
const STATE_ACTIVE := "active"
const STATE_COMPLETE_READY := "complete_ready"
const STATE_COMPLETED := "completed"

## 하루치 게시판 의뢰 재추첨 대상(daily_template) 수량 범위가 비어 있을 때의 안전값.
const DEFAULT_DAILY_COUNT := 1

## 활성 퀘스트: quest_id -> {objective_index:int, progress:Dictionary(obj_id->int), branch_choice:String}.
var _active: Dictionary = {}
## 영구 완료 목록(main/side). daily_template은 여기 들어가지 않는다(repeatable).
var _completed: Array[String] = []
## 스토리 플래그(선행 조건 story_flags, on_complete의 unlock_*/분기 outcome_flag 저장소).
## flag_name -> true(bool) 또는 문자열 값(affinity_stage처럼 값 자체가 의미 있는 경우).
var _story_flags: Dictionary = {}
## on_complete의 register_quest:<id> 태그로 "막 등록된" 퀘스트 id 집합(문서화/향후 UI
## "새 퀘스트!" 토스트용 — get_state()의 가용 여부 자체는 prerequisites만으로 이미
## 계산되므로 이 목록은 게이팅에 관여하지 않는다. docs/specs/quest-system-m2.md §3 참고).
var _registered: Dictionary = {}
## 일일 의뢰 진행 버킷: {"day_index": int, "completed_ids": Array[String]}. day_index가
## GameState.day_index와 달라지면 새 하루로 간주해 completed_ids를 비운다(재추첨 자체는
## 시드 기반 순수 함수라 저장할 필요 없음 — _daily_pick() 참고).
var _daily: Dictionary = {"day_index": -1, "completed_ids": []}

## exp 보상 placeholder 누적치. 레벨/EXP 시스템(stats.json 확정 이후)이 아직 없어 실제
## 레벨업에는 연결되지 않는다 — game-designer/godot-engineer TODO(완료 보고 참고).
var total_exp_earned: int = 0
## grant_skill_point:<n> on_complete 태그 placeholder 누적치. 스킬 포인트 지급 UI/시스템
## 미구현 — 위와 동일 사유의 TODO.
var pending_skill_points: int = 0
## affinity 보상/affinity_stage 태그 placeholder(F5-3 훅만 — npcs.json 호감도 시스템은
## 별도 담당). npc slug -> 누적 요청량(affinity 보상) 또는 마지막 stage 문자열.
var _npc_affinity_pending: Dictionary = {}


func _ready() -> void:
	Events.monster_died.connect(_on_monster_died)
	Events.item_acquired.connect(_on_item_acquired)
	Events.location_reached.connect(_on_location_reached)
	Events.npc_talked.connect(_on_npc_talked)
	Events.object_interacted.connect(_on_object_interacted)


# --- 조회 ---

func _quest_def(quest_id: String) -> Dictionary:
	return Data.get_value("quests", quest_id, {})


## locked|available|active|complete_ready|completed. 존재하지 않는 quest_id는 locked
## 취급(정의 자체가 없으니 어떤 상태로도 진행할 수 없다).
func get_state(quest_id: String) -> String:
	var qdef: Dictionary = _quest_def(quest_id)
	if qdef.is_empty():
		return STATE_LOCKED
	if _is_completed(quest_id):
		return STATE_COMPLETED
	if _active.has(quest_id):
		var objectives: Array = qdef.get("objectives", [])
		var state: Dictionary = _active[quest_id]
		if int(state.get("objective_index", 0)) >= objectives.size():
			return STATE_COMPLETE_READY
		return STATE_ACTIVE
	if _prerequisites_met(qdef):
		return STATE_AVAILABLE
	return STATE_LOCKED


func _is_completed(quest_id: String) -> bool:
	var qdef: Dictionary = _quest_def(quest_id)
	if bool(qdef.get("repeatable", false)):
		_ensure_daily_bucket(GameState.day_index)
		return (_daily.get("completed_ids", []) as Array).has(quest_id)
	return _completed.has(quest_id)


func _prerequisites_met(qdef: Dictionary) -> bool:
	var prereq: Dictionary = qdef.get("prerequisites", {})
	for qid: Variant in (prereq.get("quests_completed", []) as Array):
		if not _completed.has(String(qid)):
			return false
	for flag: Variant in (prereq.get("story_flags", []) as Array):
		if not _story_flags.has(String(flag)):
			return false
	# level_min: 캐릭터 레벨 시스템(stats.json 확정 이후)이 아직 없어 항상 통과시킨다
	# (godot-engineer TODO, docs/specs/quest-system-m2.md §6 참고).
	return true


func _ensure_daily_bucket(day_index: int) -> void:
	if int(_daily.get("day_index", -1)) != day_index:
		_daily["day_index"] = day_index
		_daily["completed_ids"] = []


# --- 수주/포기/턴인 ---

## 성공: {ok:true}. 실패: {ok:false, reason:"not_found"|"not_available", state?:String}.
func accept(quest_id: String) -> Dictionary:
	var qdef: Dictionary = _quest_def(quest_id)
	if qdef.is_empty():
		return {"ok": false, "reason": "not_found"}
	var state: String = get_state(quest_id)
	if state != STATE_AVAILABLE:
		return {"ok": false, "reason": "not_available", "state": state}
	_active[quest_id] = {"objective_index": 0, "progress": {}, "branch_choice": ""}
	Events.quest_accepted.emit(StringName(quest_id))
	_emit_current_objective_progress(quest_id, qdef)
	return {"ok": true}


## 메인 퀘스트는 항상 거부(F5-1 "메인 퀘스트 포기 불가"). 성공: {ok:true}. 실패:
## {ok:false, reason:"not_found"|"main_quest_cannot_abandon"|"not_active"}.
func abandon(quest_id: String) -> Dictionary:
	var qdef: Dictionary = _quest_def(quest_id)
	if qdef.is_empty():
		return {"ok": false, "reason": "not_found"}
	if String(qdef.get("type", "")) == "main":
		return {"ok": false, "reason": "main_quest_cannot_abandon"}
	if not _active.has(quest_id):
		return {"ok": false, "reason": "not_active"}
	_active.erase(quest_id)
	return {"ok": true}


## complete_ready 상태인 퀘스트를 턴인(보상 지급 + on_complete 적용)한다. giver=="system"
## 퀘스트는 마지막 목표 진행 즉시 내부적으로 이 함수를 자동 호출한다(_on_objectives_complete
## 참고) — NPC 지급 퀘스트는 플레이어가(향후 대화 UI가) 명시적으로 호출해야 한다.
## 성공: {ok:true}. 실패: {ok:false, reason:"not_found"|"not_ready"}.
func advance(quest_id: String) -> Dictionary:
	var qdef: Dictionary = _quest_def(quest_id)
	if qdef.is_empty():
		return {"ok": false, "reason": "not_found"}
	if get_state(quest_id) != STATE_COMPLETE_READY:
		return {"ok": false, "reason": "not_ready"}

	_resolve_branch_default(quest_id, qdef)
	_grant_rewards(qdef.get("rewards", {}))
	_apply_on_complete(qdef.get("on_complete", {}))

	var type: String = String(qdef.get("type", ""))
	if type == "daily_template":
		_ensure_daily_bucket(GameState.day_index)
		(_daily["completed_ids"] as Array).append(quest_id)
	else:
		_completed.append(quest_id)
	_active.erase(quest_id)

	Events.quest_completed.emit(StringName(quest_id))
	if type == "main":
		Events.main_quest_stage_completed.emit(StringName(quest_id)) # SaveManager 오토세이브 트리거.
	return {"ok": true}


## branch가 있는 퀘스트에 한해 플레이어 선택을 기록한다(F5-1 분기, D-94: converges=true라
## 이후 진행/보상에는 영향 없고 outcome_flag만 story_flags에 남긴다). 대화 UI가 아직
## 없어 advance() 시점까지 호출되지 않으면 _resolve_branch_default()가 첫 번째 선택지로
## 대신 채운다.
func choose_branch(quest_id: String, choice_id: String) -> Dictionary:
	var qdef: Dictionary = _quest_def(quest_id)
	var branch: Variant = qdef.get("branch")
	if branch == null:
		return {"ok": false, "reason": "no_branch"}
	for choice: Dictionary in (branch.get("choices", []) as Array):
		if String(choice.get("id", "")) == choice_id:
			_story_flags[String(choice.get("outcome_flag", ""))] = true
			if _active.has(quest_id):
				(_active[quest_id] as Dictionary)["branch_choice"] = choice_id
			return {"ok": true}
	return {"ok": false, "reason": "invalid_choice"}


func _resolve_branch_default(quest_id: String, qdef: Dictionary) -> void:
	var branch: Variant = qdef.get("branch")
	if branch == null:
		return
	var choices: Array = (branch as Dictionary).get("choices", [])
	if choices.is_empty():
		return
	var chosen: String = String((_active.get(quest_id, {}) as Dictionary).get("branch_choice", ""))
	for choice: Dictionary in choices:
		if String(choice.get("id", "")) == chosen:
			return # 이미 명시적으로 선택됨.
	choose_branch(quest_id, String((choices[0] as Dictionary).get("id", "")))


# --- 목표 진행(Events 구독 — 자동) ---

func _on_monster_died(monster_id: StringName) -> void:
	_apply_progress("kill", "monster:%s" % String(monster_id), 1)


func _on_item_acquired(item_id: StringName, count: int) -> void:
	_apply_progress("collect", "item:%s" % String(item_id), count)


func _on_location_reached(location_id: StringName) -> void:
	_apply_progress("reach", "location:%s" % String(location_id), 1)


func _on_npc_talked(npc_id: StringName) -> void:
	_apply_progress("talk", "npc:%s" % String(npc_id), 1)


func _on_object_interacted(object_id: StringName) -> void:
	_apply_progress("interact", "object:%s" % String(object_id), 1)


func _apply_progress(obj_type: String, target_key: String, amount: int) -> void:
	if amount <= 0:
		return
	for quest_id: String in _active.keys():
		var qdef: Dictionary = _quest_def(quest_id)
		if qdef.is_empty():
			continue
		var objectives: Array = qdef.get("objectives", [])
		var state: Dictionary = _active[quest_id]
		var idx: int = int(state.get("objective_index", 0))
		if idx >= objectives.size():
			continue # 이미 complete_ready(턴인 대기) — 다음 목표가 없다.
		var obj: Dictionary = objectives[idx]
		if String(obj.get("type", "")) != obj_type:
			continue
		if _resolve_objective_target(quest_id, obj) != target_key:
			continue

		var obj_id: String = String(obj.get("id", ""))
		var required: int = _resolve_objective_count(quest_id, obj)
		var progress: Dictionary = state.get("progress", {})
		var current: int = mini(int(progress.get(obj_id, 0)) + amount, required)
		progress[obj_id] = current
		state["progress"] = progress
		Events.quest_objective_updated.emit(StringName(quest_id), StringName(obj_id), current, required)

		if current >= required:
			state["objective_index"] = idx + 1
			if int(state["objective_index"]) >= objectives.size():
				_on_objectives_complete(quest_id, qdef)


func _on_objectives_complete(quest_id: String, qdef: Dictionary) -> void:
	if String(qdef.get("giver", "")) == "system":
		advance(quest_id) # NPC가 없는 퀘스트는 턴인 UI가 있을 수 없어 자동 완결한다.
	# giver가 NPC면 complete_ready에 머문다 — 대화 UI(다음 단계)가 advance()를 호출해야 한다.


func _emit_current_objective_progress(quest_id: String, qdef: Dictionary) -> void:
	var objectives: Array = qdef.get("objectives", [])
	var state: Dictionary = _active.get(quest_id, {})
	var idx: int = int(state.get("objective_index", 0))
	if idx >= objectives.size():
		return
	var obj: Dictionary = objectives[idx]
	var obj_id: String = String(obj.get("id", ""))
	var required: int = _resolve_objective_count(quest_id, obj)
	var current: int = int((state.get("progress", {}) as Dictionary).get(obj_id, 0))
	Events.quest_objective_updated.emit(StringName(quest_id), StringName(obj_id), current, required)


## pool: 접두어(daily_template)는 그날 뽑힌 구체 id로 치환해 실제 target 문자열로
## 변환한다. 일반 퀘스트는 obj.target을 그대로 돌려준다.
func _resolve_objective_target(quest_id: String, obj: Dictionary) -> String:
	var target: String = String(obj.get("target", ""))
	if not target.begins_with("pool:"):
		return target
	var picked: Dictionary = _daily_pick(quest_id, GameState.day_index)
	var kind_prefix: String = "monster" if String(obj.get("type", "")) == "kill" else "item"
	return "%s:%s" % [kind_prefix, String(picked.get("target_id", ""))]


## daily_template의 count:0 플레이스홀더는 그날 뽑힌 수량으로 치환한다.
func _resolve_objective_count(quest_id: String, obj: Dictionary) -> int:
	var count: int = int(obj.get("count", 0))
	if count > 0:
		return count
	return int(_daily_pick(quest_id, GameState.day_index).get("count", DEFAULT_DAILY_COUNT))


# --- 게시판 일일 의뢰(F5-2, D-97) ---

## template_vars.monster_pool/item_pool + pools.json으로 그날의 구체 target/count를
## 뽑는다. (day_index, quest_id)만으로 시드를 고정하는 순수 함수라 저장이 필요 없다 —
## 같은 인자로 몇 번을 불러도 항상 같은 결과가 나온다(시드 재현성 요구사항).
func roll_daily_target(quest_id: String, day_index: int) -> Dictionary:
	return _daily_pick(quest_id, day_index)


func _daily_pick(quest_id: String, day_index: int) -> Dictionary:
	var qdef: Dictionary = _quest_def(quest_id)
	var tv: Dictionary = qdef.get("template_vars", {})
	var pool_id: String = ""
	if tv.get("monster_pool") != null:
		pool_id = String(tv.get("monster_pool"))
	elif tv.get("item_pool") != null:
		pool_id = String(tv.get("item_pool"))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [day_index, quest_id])

	var pool: Dictionary = Data.get_value("pools", pool_id, {})
	var members: Array = pool.get("members", [])
	var picked_id: String = ""
	var total_weight := 0.0
	for member: Dictionary in members:
		total_weight += float(member.get("weight", 0.0))
	if total_weight > 0.0:
		var roll: float = rng.randf() * total_weight
		var running := 0.0
		for member2: Dictionary in members:
			running += float(member2.get("weight", 0.0))
			if roll <= running:
				picked_id = String(member2.get("id", ""))
				break
		if picked_id.is_empty() and not members.is_empty():
			picked_id = String((members[-1] as Dictionary).get("id", ""))

	var count_range: Array = tv.get("count_range", [DEFAULT_DAILY_COUNT, DEFAULT_DAILY_COUNT])
	var lo: int = int(count_range[0]) if count_range.size() > 0 else DEFAULT_DAILY_COUNT
	var hi: int = int(count_range[1]) if count_range.size() > 1 else lo
	var count: int = rng.randi_range(lo, hi) if hi >= lo else lo

	return {"target_id": picked_id, "count": count}


## 오늘의 게시판 의뢰 3종(daily_template 전체) id 목록. 실제 대상 문자열은
## roll_daily_target()로 개별 조회한다.
func get_daily_quest_ids() -> Array[String]:
	var ids: Array[String] = []
	var quests: Dictionary = Data.table("quests")
	for quest_id: String in quests:
		if bool((quests[quest_id] as Dictionary).get("repeatable", false)):
			ids.append(quest_id)
	return ids


# --- 보상 / on_complete ---

func _grant_rewards(rewards: Dictionary) -> void:
	var gold: int = int(rewards.get("gold", 0))
	if gold > 0:
		GameState.add_gold(gold)

	var exp: int = int(rewards.get("exp", 0))
	if exp > 0:
		total_exp_earned += exp # placeholder — 레벨/EXP 시스템 미도입(위 total_exp_earned 주석 참고).

	for item: Dictionary in (rewards.get("items", []) as Array):
		var item_id: String = String(item.get("id", ""))
		if item_id.is_empty():
			continue
		var qty: int = int(item.get("qty", 1))
		var item_def: Dictionary = Data.get_value("items", item_id, {})
		var item_instance: Dictionary = {
			"uid": "quest_reward_%d_%s" % [Time.get_ticks_usec(), item_id],
			"item_id": item_id, "quantity": qty,
			"grade": String(item_def.get("grade", "common")),
			"affixes": [], "enhance_level": 0, "refine_left": 0, "locked": false,
		}
		GameState.pickup_item(item_instance, item_def) # D-10: 가득 차면 add_or_mail로 우편함행.

	for aff: Dictionary in (rewards.get("affinity", []) as Array):
		var npc: String = String(aff.get("npc", ""))
		if not npc.is_empty():
			_npc_affinity_pending[npc] = int(_npc_affinity_pending.get(npc, 0)) + int(aff.get("amount", 0))


## docs/specs/quest-data-schema.md §2.5 태그 표 그대로 처리한다. 이 데이터셋에 없는
## 태그(예: register_main_act2_regions — 2막 범위)는 하드 에러 대신 push_warning만
## 남기고 넘어간다(2막 데이터가 아직 없어 정의할 수 없는 태그라 여기서 죽이면 안 됨).
func _apply_on_complete(on_complete: Dictionary) -> void:
	for tag_v: Variant in (on_complete.get("events", []) as Array):
		var tag: String = String(tag_v)
		if tag.begins_with("register_quest:"):
			_registered[tag.substr("register_quest:".length())] = true
		elif tag.begins_with("unlock_facility:"):
			_story_flags["facility_%s_unlocked" % tag.substr("unlock_facility:".length())] = true
		elif tag.begins_with("unlock_system:"):
			_story_flags["system_%s_unlocked" % tag.substr("unlock_system:".length())] = true
		elif tag == "unlock_worldmap":
			_story_flags["worldmap_unlocked"] = true
		elif tag == "save_checkpoint":
			pass # main_quest_stage_completed가 advance() 끝에서 이미 오토세이브를 건다.
		elif tag.begins_with("grant_skill_point:"):
			pending_skill_points += int(tag.substr("grant_skill_point:".length()))
		elif tag.begins_with("affinity_stage:"):
			var parts: PackedStringArray = tag.split(":")
			if parts.size() >= 3:
				_story_flags["affinity_stage_%s" % parts[1]] = parts[2]
		else:
			push_warning("[QuestSystem] 미인식 on_complete 태그(무시): %s" % tag)


# --- HUD 추적 퀘스트 한 줄(F7-1) ---

## 표시 우선순위: 활성 메인 퀘스트 > 그 외 활성 퀘스트(가장 먼저 수주한 순) > 없음("").
func get_tracked_quest_id() -> String:
	var fallback: String = ""
	for quest_id: String in _active.keys():
		if fallback.is_empty():
			fallback = quest_id
		if String(_quest_def(quest_id).get("type", "")) == "main":
			return quest_id
	return fallback


## {} (추적 대상 없음) 또는 {quest_id, title_key, current, target}. current/target 의미:
## 진행 중인 목표의 목표 수량이 1보다 크면(kill/collect) 그 목표의 진행/목표 수량,
## 아니면(talk/reach/interact, count==1) "완료한 목표 수/전체 목표 수"로 대신한다 —
## 목표 하나짜리 진행률은 정보량이 없어 퀘스트 전체 진행으로 보여주는 편이 유용하다는
## 판단(docs/specs/quest-system-m2.md §5 HUD 표시 규칙 참고, 필요시 game-designer 조정).
func get_tracked_quest_progress() -> Dictionary:
	var quest_id: String = get_tracked_quest_id()
	if quest_id.is_empty():
		return {}
	var qdef: Dictionary = _quest_def(quest_id)
	var objectives: Array = qdef.get("objectives", [])
	var state: Dictionary = _active.get(quest_id, {})
	var idx: int = int(state.get("objective_index", 0))
	var title_key: String = String(qdef.get("title_key", ""))
	if idx >= objectives.size() or objectives.is_empty():
		return {"quest_id": quest_id, "title_key": title_key, "current": objectives.size(), "target": objectives.size()}
	var obj: Dictionary = objectives[idx]
	var required: int = _resolve_objective_count(quest_id, obj)
	if required > 1:
		var obj_id: String = String(obj.get("id", ""))
		var current: int = int((state.get("progress", {}) as Dictionary).get(obj_id, 0))
		return {"quest_id": quest_id, "title_key": title_key, "current": current, "target": required}
	return {"quest_id": quest_id, "title_key": title_key, "current": idx, "target": objectives.size()}


# --- 직렬화(SaveManager 연동, F8-1) ---

func to_dict() -> Dictionary:
	return {
		"active": _active.duplicate(true),
		"completed": _completed.duplicate(),
		"story_flags": _story_flags.duplicate(true),
		"registered": _registered.duplicate(true),
		"daily": _daily.duplicate(true),
		"total_exp_earned": total_exp_earned,
		"pending_skill_points": pending_skill_points,
		"npc_affinity_pending": _npc_affinity_pending.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	_active = (data.get("active", {}) as Dictionary).duplicate(true)
	var completed: Array[String] = []
	for qid: Variant in (data.get("completed", []) as Array):
		completed.append(String(qid))
	_completed = completed
	_story_flags = (data.get("story_flags", {}) as Dictionary).duplicate(true)
	_registered = (data.get("registered", {}) as Dictionary).duplicate(true)
	_daily = (data.get("daily", {"day_index": -1, "completed_ids": []}) as Dictionary).duplicate(true)
	total_exp_earned = int(data.get("total_exp_earned", 0))
	pending_skill_points = int(data.get("pending_skill_points", 0))
	_npc_affinity_pending = (data.get("npc_affinity_pending", {}) as Dictionary).duplicate(true)


## 테스트/디버그 전용 — 모든 상태를 초기화한다(실제 자동로드 싱글턴을 재사용하는
## 스모크 테스트가 씬 재시작 없이 깨끗한 상태에서 다시 돌리고 싶을 때 쓴다).
func reset() -> void:
	_active = {}
	_completed = []
	_story_flags = {}
	_registered = {}
	_daily = {"day_index": -1, "completed_ids": []}
	total_exp_earned = 0
	pending_skill_points = 0
	_npc_affinity_pending = {}


# --- 디버그/테스트 보조 ---

## 특정 story_flag가 서 있는지(선행 조건 테스트·향후 UI용).
func has_story_flag(flag: String) -> bool:
	return _story_flags.has(flag)


## quest_id의 현재 objective_index(활성 아니면 -1). 테스트 보조용.
func get_active_objective_index(quest_id: String) -> int:
	if not _active.has(quest_id):
		return -1
	return int((_active[quest_id] as Dictionary).get("objective_index", 0))
