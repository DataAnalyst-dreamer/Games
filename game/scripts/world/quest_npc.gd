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

var _player_inside: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if greeting_key.is_empty() and not npc_id.is_empty():
		greeting_key = StringName("npc.%s.greeting" % npc_id)
	_apply_sprite_texture()


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside != null and event.is_action_pressed("interact"):
		talk()


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
