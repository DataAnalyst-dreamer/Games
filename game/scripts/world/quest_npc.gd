## 퀘스트 관련 NPC(F5-1/F5-2, M2-8). 판정 범위 안에서 interact 입력을 받으면
## Events.npc_talked(npc_id)를 emit한다 — QuestSystem은 이 신호 하나만 구독해 talk형
## 목표를 자동으로 진행시킨다(docs/specs/quest-system-m2.md §4).
##
## 정식 대사 팝업(다이얼로그 매니저 연동)은 아직 없다 — 대신 Hud가 이 신호를 구독해
## "npc.<id>.greeting" 로컬라이징 key 한 줄을 좌하단 로그 토스트로 띄운다
## (scripts/ui/hud.gd:_on_npc_talked 참고). id별 문구는 `game/localization/ui_ko.csv`.
##
## 스프라이트는 정지 상태(idle-down 프레임 1장)만 쓴다 — NPC가 걸어 다니지 않는
## 프로토타입 배치라 걷기 애니메이션 자원은 불필요(art-bible.md §1.1 예외 규정,
## CC0 Ninja Adventure 캐릭터 시트 재사용). sprite_texture는 world_objects.json이
## NPC별로 다른 시트를 배정하고, quest_layout_spawner.gd가 인스턴스화 직후 대입한다.
class_name QuestNpc
extends Area2D

## 색·폰트는 game/ui/theme.tres 한 곳에서만 관리한다(README 규칙) — 이 노드는 Control
## 트리 밖(월드 2D 트리)이라 테마 상속을 받지 못해 직접 preload해서 읽는다.
const HUD_THEME: Theme = preload("res://ui/theme.tres")

@export var npc_id: StringName = &""
## 비워두면 "npc.<npc_id>.greeting"을 사용한다(quest_layout_spawner.gd가 기본값을
## 대입하지만, 씬 단독 배치 시에도 동작하도록 _ready()에서 한 번 더 보정한다).
@export var greeting_key: StringName = &""
## Ninja Adventure 등 CC0 캐릭터 시트(64x112 또는 64x32, 16px 셀) — 좌상단 16x16을
## idle-down 프레임으로 그대로 오려 쓴다(Player.tscn의 Knight 시트와 동일 레이아웃 가정,
## 더 작은 시트도 좌상단은 항상 유효한 정지 프레임이다).
@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		_apply_sprite_texture()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _marker: Label = $MarkerLabel

var _player_inside: Player = null

## D-155(M3-2): 스프라이트 없이 폰트 라벨(! 수주 가능/? 완료 보고 가능)로 시작.
## 위아래 바운스 6px, 0.8초 주기 — 색약 대비는 모양 자체가 다르므로 별도 대체 없음.
const MARKER_BOUNCE_PX := 12.0 # D-206 단위 전환 ×2.
const MARKER_BOUNCE_SEC := 0.8
var _marker_base_y: float = 0.0
var _marker_tween: Tween


func _ready() -> void:
	add_to_group(&"quest_markers") # M5-2: 미니맵이 marker_text()/marker_visible()를 재사용.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if greeting_key.is_empty() and not npc_id.is_empty():
		greeting_key = StringName("npc.%s.greeting" % npc_id)
	_apply_sprite_texture()

	_marker_base_y = _marker.position.y
	_marker.visible = false
	# 이 NPC가 giver인 퀘스트 중 하나라도 상태가 바뀔 만한 신호를 모두 구독해
	# 표식을 갱신한다(폴링 대신 이벤트 기반 — 다른 QuestSystem 연동부와 동일한 관례).
	Events.quest_accepted.connect(_on_any_quest_signal)
	Events.quest_objective_updated.connect(_on_any_quest_signal)
	Events.quest_completed.connect(_on_any_quest_signal)
	Events.quest_tracked_changed.connect(_on_any_quest_signal) # M3-4: 수동 추적 전환도 ▼ 갱신 대상.
	_refresh_marker()


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused and _player_inside != null and event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		talk()
		get_tree().call_group("quest_npc_ui", "open_quest_npc", npc_id)


## Events 발신을 한 곳에 모은 공개 진입점 — 실제 플레이어 입력뿐 아니라 스모크
## 테스트(SmokeQuestLayout)도 이 함수를 직접 호출해 검증한다.
func talk() -> void:
	Events.npc_talked.emit(npc_id)


func _apply_sprite_texture() -> void:
	if _sprite == null or sprite_texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite_texture
	atlas.region = Rect2(0, 0, 16, 16)
	_sprite.texture = atlas


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_inside = body


func _on_body_exited(body: Node) -> void:
	if body == _player_inside:
		_player_inside = null


# --- 테스트 보조용 (스모크에서 표식 상태를 직접 확인) ---

func marker_text() -> String:
	return _marker.text


func marker_visible() -> bool:
	return _marker.visible


# --- 머리 위 퀘스트 표식 (D-155, M3-2) ---

func _on_any_quest_signal(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	_refresh_marker()


## 이 npc_id가 giver인 퀘스트를 전부 스캔해 완료 보고(?) > 수주 가능(!) > 추적 중인
## 퀘스트의 목표 대상(▼, M3-4 D-163) 우선순위로 표식을 정한다(quest_npc_panel.gd가
## giver 매칭에 쓰는 것과 같은 방식이지만, 그쪽처럼 특정 퀘스트 id 목록을 하드코딩하지
## 않고 데이터 테이블 전체를 스캔한다 — NPC 쪽은 신규 퀘스트가 추가될 때마다 코드를
## 고칠 필요가 없어야 하기 때문).
##
## ▼는 giver가 없는 메인 퀘스트(예: MQ01 "talk npc:teo")도 목표 대상 위에 표식이
## 뜨게 하려고 추가했다 — 데모 피드백 "퀘스트 표식이 안 보인다"의 근본 원인이 giver
## 전용 스캔이었다(giver=null인 메인 퀘스트는 애초에 이 스캔에 걸리지 않았다).
func _refresh_marker() -> void:
	if npc_id.is_empty():
		_marker.visible = false
		_stop_bounce()
		return
	var has_complete_ready := false
	var has_available := false
	var quests: Dictionary = Data.table("quests")
	for quest_id: String in quests.keys():
		if String((quests[quest_id] as Dictionary).get("giver", "")) != String(npc_id):
			continue
		match QuestSystem.get_state(quest_id):
			"complete_ready": has_complete_ready = true
			"available": has_available = true
	if has_complete_ready:
		_show_marker("?", HUD_THEME.get_color(&"quest_marker_complete", &"HUD"))
	elif has_available:
		_show_marker("!", HUD_THEME.get_color(&"quest_marker_available", &"HUD"))
	elif QuestSystem.is_tracked_objective_key(QuestSystem.get_active_talk_objective_keys(npc_id)):
		_show_marker("▼", HUD_THEME.get_color(&"quest_marker_objective", &"HUD"))
	else:
		_marker.visible = false
		_stop_bounce()


func _show_marker(text: String, color: Color) -> void:
	_marker.text = text
	_marker.add_theme_color_override("font_color", color)
	_marker.add_theme_font_override("font", HUD_THEME.default_font)
	_marker.add_theme_font_size_override("font_size", HUD_THEME.get_font_size(&"large", &"HUD"))
	_marker.visible = true
	_start_bounce()


func _start_bounce() -> void:
	if _marker_tween != null and _marker_tween.is_valid():
		return # 이미 재생 중이면 그대로 둔다(재시작하면 값이 튐).
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
