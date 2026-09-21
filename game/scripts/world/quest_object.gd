## 퀘스트 "상호작용"(interact) 오브젝트(F5-1/F5-2, M2-8).
##
## 판정 범위 안에서 interact 입력을 받으면 Events.object_interacted(object_id)를
## emit한다 — BlacksmithNpc/MailboxNpc/BoardNpc(scripts/world/*.gd)와 동일한 "판정
## 범위 진입 + interact" 패턴. QuestSystem은 이 신호 하나만 구독해 interact형 목표를
## 자동으로 진행시킨다(docs/specs/quest-system-m2.md §4).
##
## 옵션 3종(world_objects.json 데이터로 설정, quest_layout_spawner.gd가 배정):
## - one_shot: true면 첫 발견/현재 활성 목표마다 한 번만 진행 신호를 보내고, Placeholder를
##   PlaceholderUsed로 교체한다("완료 후 스프라이트 교체"). false면 영구 랜드마크
##   취급(민들레 결계석·비석처럼 몇 번을 다시 상호작용해도 항상 같은 모습).
## - vanish_on_complete: true면 one_shot과 별개로 상호작용 직후 노드 자체가 사라진다
##   (`montsil_rabbit` — "상호작용 후 사라지는 오브젝트", 설계 문서 hartland.md ⑩ 참고).
## - branch_quest_id/branch_choice_id: 둘 다 채워져 있으면 상호작용 시
##   QuestSystem.choose_branch(branch_quest_id, branch_choice_id)를 함께 호출한다.
##   선택 UI가 아직 없어(quest-system-m2.md §6) `quest_side_heartland_montsil`은 첫
##   상호작용을 항상 "release"로 확정해 명시적으로 기록해 둔다(D-94 문서화).
class_name QuestObject
extends Area2D

## 색·폰트는 game/ui/theme.tres 한 곳에서만 관리한다 — 이 노드는 Control 트리 밖(월드 2D
## 트리)이라 테마 상속을 받지 못해 quest_npc.gd와 동일하게 직접 preload해서 읽는다.
const HUD_THEME: Theme = preload("res://ui/theme.tres")

@export var object_id: StringName = &""
@export var one_shot: bool = false
@export var vanish_on_complete: bool = false
@export var branch_quest_id: StringName = &""
@export var branch_choice_id: StringName = &""
## 대사 분기 경로(D-262). 비어 있으면 기존 branch_choice_id 즉시 확정 경로(하위호환).
## 값이 있으면 branch_quest_id가 "active"일 때만 이 리소스를 열어 플레이어가 직접
## 고르게 하고, emit/vanish는 응답의 do절이 resolve_branch_outcome()으로 미룬다.
@export var dialogue_path: String = ""

## world_objects.json 의 `sprite` 키로 종류별 외형을 바꾼다(D-218). 비우면 씬 기본값
## (marker_stone)을 쓴다 — quest_layout_spawner.gd 가 instantiate() 직후, 즉 @onready
## 가 돌기 전에 대입하므로 값만 보관하고 _ready() 에서 한 번 더 적용한다(quest_npc.gd 와
## 동일 패턴).
@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		_apply_sprite_texture()

## 이미 사용한 오브젝트의 탈색. 전용 "사용됨" 그림을 종류마다 따로 만들지 않는다.
const USED_TINT := Color(0.45, 0.45, 0.45, 0.75)

@onready var _visual: CanvasItem = $Placeholder
@onready var _marker: Label = $MarkerLabel

var _used: bool = false
var _emitted_objectives: Dictionary = {}
var _player_inside: Player = null

## 머리 위 "목표 표식"(M3-4, D-163) — quest_npc.gd의 ▼ 표식과 같은 바운스 연출을
## 그대로 복제한다(공용 헬퍼로 뽑기엔 두 곳뿐이라 과함, 판정 로직만
## QuestSystem.is_tracked_objective_key()로 공유한다).
const MARKER_BOUNCE_PX := 12.0 # D-206 단위 전환 ×2.
const MARKER_BOUNCE_SEC := 0.8
var _marker_base_y: float = 0.0
var _marker_tween: Tween


func _ready() -> void:
	add_to_group(&"quest_markers") # M5-2: 미니맵이 marker_text()/marker_visible()를 재사용.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Events.quest_accepted.connect(_on_quest_accepted)
	Events.load_completed.connect(_on_load_completed)
	Events.quest_objective_updated.connect(_on_any_quest_signal)
	Events.quest_completed.connect(_on_any_quest_signal)
	Events.quest_tracked_changed.connect(_on_any_quest_signal)

	_apply_sprite_texture()
	_marker_base_y = _marker.position.y
	_marker.visible = false
	_refresh_marker()


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and _player_inside != null and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		interact()
		_activate_shared_waystone()


## D-28: this one named ward is the same physical object as Main's waystone1.
## Keep input consumed for unrelated objects; explicitly invoke only this companion,
## only when the player is inside its own range. Quest progress happens before save.
func _activate_shared_waystone() -> void:
	if object_id != &"ward_stone_dandelion" or _player_inside == null: return
	for node in get_tree().get_nodes_in_group(&"waystones"):
		if node is Waystone and node.waystone_id == &"waystone1" and node.overlaps_body(_player_inside):
			node.activate()
			return


## Events 발신 + 분기 선택 + 상태 전환을 한 곳에 모은 공개 진입점 — 실제 플레이어
## 입력뿐 아니라 스모크 테스트(SmokeQuestLayout)도 이 함수를 직접 호출해 검증한다.
func interact() -> void:
	var observation := observation_key()
	if not observation.is_empty():
		get_tree().call_group("world_observation_hud", "show_world_observation", observation)
	var active_keys := QuestSystem.get_active_interact_objective_keys(object_id)
	var pending := false
	for key in active_keys:
		if not _emitted_objectives.has(key): pending = true
	if one_shot and _used and not pending: return
	for key in active_keys: _emitted_objectives[key] = true
	_used = true
	# D-262: dialogue_path가 있으면 emit/분기/vanish를 여기서 하지 않는다 — 대사 응답의
	# do절(resolve_branch_outcome)이 플레이어 선택 이후로 미뤄서 대신 수행한다. 몽실이가
	# 선택 전에 사라지거나 퀘스트 수락 전에 분기 플래그가 확정되는 사고를 막는다.
	if not dialogue_path.is_empty():
		if QuestSystem.get_state(branch_quest_id) == "active":
			get_tree().call_group("npc_dialogue_ui", "open_dialogue_resource", load(dialogue_path), "start", self)
		return
	Events.object_interacted.emit(object_id)
	if not branch_quest_id.is_empty() and not branch_choice_id.is_empty():
		QuestSystem.choose_branch(branch_quest_id, branch_choice_id)
	if vanish_on_complete:
		queue_free()
	elif one_shot:
		_swap_to_used_visual()


## 대사 응답의 do절이 접두어 없이 호출한다(§3.3과 동일한 self-injection 패턴,
## `NpcDialogueController.open_dialogue_resource(res, title, self)`가 이 인스턴스를
## extra_game_states로 주입해 준다). D-262: emit/분기/vanish를 여기 한 곳에 모은다.
func resolve_branch_outcome(choice_id: String) -> void:
	QuestSystem.choose_branch(branch_quest_id, choice_id)
	Events.object_interacted.emit(object_id)
	if vanish_on_complete:
		queue_free()
	elif one_shot:
		_swap_to_used_visual()


## Presentation only; observation itself never emits a quest event.
func observation_key() -> StringName:
	if object_id == &"cargo_pile":
		if not QuestSystem.get_active_interact_objective_keys(object_id).is_empty(): return &"observe.cargo.active"
		if _used: return &"observe.cargo.used"
		if QuestSystem.get_state("quest_main_a1_01_arrival") == "active":
			return &"observe.cargo.active"
		return &"observe.cargo.before"
	if object_id == &"ward_stone_dandelion":
		var state := QuestSystem.get_state("quest_main_a1_04_theshard")
		if state in ["complete_ready", "completed"]: return &"observe.ward.after"
		if state == "active": return &"observe.ward.active"
		return &"observe.ward.before"
	if object_id == &"waypoint_stone_01":
		# interact() observes before emitting the objective event. The completing
		# input still shows active; a subsequent explicit input shows after.
		# This describes investigation, not a new warp activation or saved flag.
		var state := QuestSystem.get_state("quest_side_heartland_waypoint")
		if state in ["complete_ready", "completed"]: return &"observe.waypoint.after"
		if state == "active": return &"observe.waypoint.active"
		return &"observe.waypoint.before"
	return &""


func _on_quest_accepted(quest_id: StringName) -> void:
	for key: String in _emitted_objectives.keys():
		if key.begins_with(String(quest_id) + ":"): _emitted_objectives.erase(key)
	_refresh_marker()


func _on_any_quest_signal(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_refresh_marker()


func _refresh_marker() -> void:
	if object_id.is_empty() or not QuestSystem.is_tracked_objective_key(QuestSystem.get_active_interact_objective_keys(object_id)):
		_marker.visible = false
		_stop_bounce()
		return
	_marker.text = "▼"
	_marker.add_theme_color_override("font_color", HUD_THEME.get_color(&"quest_marker_objective", &"HUD"))
	_marker.add_theme_font_override("font", HUD_THEME.default_font)
	_marker.add_theme_font_size_override("font_size", HUD_THEME.get_font_size(&"large", &"HUD"))
	_marker.visible = true
	_start_bounce()


func _start_bounce() -> void:
	if _marker_tween != null and _marker_tween.is_valid():
		return
	_marker_tween = create_tween()
	_marker_tween.set_loops()
	_marker_tween.tween_property(_marker, "position:y", _marker_base_y - MARKER_BOUNCE_PX, MARKER_BOUNCE_SEC * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_marker_tween.tween_property(_marker, "position:y", _marker_base_y, MARKER_BOUNCE_SEC * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_bounce() -> void:
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	_marker_tween = null
	_marker.position.y = _marker_base_y


# --- 테스트 보조용(스모크에서 표식 상태를 직접 확인, quest_npc.gd와 동일 API) ---

func marker_text() -> String:
	return _marker.text


func marker_visible() -> bool:
	return _marker.visible


func _on_load_completed(_slot: int, _kind: StringName, ok: bool) -> void:
	if ok: _emitted_objectives.clear()
	# Deliberately do not interact: the next explicit player input is required.


func _apply_sprite_texture() -> void:
	if sprite_texture != null and _visual is Sprite2D:
		(_visual as Sprite2D).texture = sprite_texture


func _swap_to_used_visual() -> void:
	# 전용 "사용됨" 스프라이트를 따로 두는 대신 같은 그림을 탈색한다 — 종류별 변형이
	# 생기면서(D-218) 변형마다 used 그림을 하나씩 더 만드는 비용이 실익보다 크다.
	if _visual != null:
		_visual.modulate = USED_TINT


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null
