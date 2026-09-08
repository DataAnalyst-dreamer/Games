## 필드 드랍 오브젝트(F3-1). LootSystem이 만든 ItemInstance 하나를 들고 몬스터 사망
## 위치에 스폰되며(scripts/systems/loot_spawner.gd), 플레이어가 접근하면 자동 획득된다.
##
## 표시: 등급 색 외곽선(Rarity.color_of(), game/ui/theme.tres 단일 소스) + 카테고리별
## placeholder 아이콘(전용 아이템 아트가 없어 ninja_adventure Items/Ui 팩에서 카테고리당
## 대표 이미지 하나씩만 매핑 — 개별 아이템 57종 아이콘은 pixel-artist TODO, 완료 보고
## 참고). 접근 시 자동 획득 판정은 Waystone.tscn과 동일하게 Area2D + collision_mask=2
## (Player CharacterBody2D의 collision_layer)로 처리한다.
class_name ItemDrop
extends Area2D

## 카테고리 -> placeholder 아이콘 경로. 없는 카테고리는 아이콘 없이 외곽선만 표시한다.
const CATEGORY_ICON := {
	"weapon": "res://assets/third_party/ninja_adventure/Items/Weapons/Sword/Sprite.png",
	"sub": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Guard.png",
	"head": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Helmet.png",
	"armor": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Armor.png",
	"boots": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Boot.png",
	"ring": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Ring.png",
	"amulet": "res://assets/third_party/ninja_adventure/Ui/Skill Icon/Items & Weapon/Amulet.png",
	"consumable": "res://assets/third_party/ninja_adventure/Items/Potion/LifePot.png",
	"material": "res://assets/third_party/ninja_adventure/Items/Resource/BarIron.png",
	"costume_backpack": "res://assets/third_party/ninja_adventure/Items/Treasure/LittleTreasureChest.png",
}

@onready var _outline: Polygon2D = $Outline
@onready var _icon: Sprite2D = $Icon

var item_instance: Dictionary = {}
var item_def: Dictionary = {}

## 이미 픽업 처리를 시작했는지(같은 프레임에 body_entered가 중복 발화하는 경우 방지).
var _picked_up: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not item_instance.is_empty():
		_apply_visual()
		_play_drop_sfx()


## LootSpawner가 인스턴스화 직후 호출한다. _ready() 이전에 호출될 수도 있어(같은 프레임
## add_child 직후) 양쪽 다 안전하도록 _apply_visual()을 여기서도 시도한다.
func setup(p_item_instance: Dictionary, p_item_def: Dictionary) -> void:
	item_instance = p_item_instance
	item_def = p_item_def
	if is_node_ready():
		_apply_visual()
		_play_drop_sfx()


func _apply_visual() -> void:
	var grade: String = String(item_instance.get("grade", item_def.get("grade", "common")))
	if _outline != null:
		_outline.color = Rarity.color_of(Rarity.from_string(grade), load("res://ui/theme.tres"))
	if _icon != null:
		var tex_path: String = String(CATEGORY_ICON.get(String(item_def.get("category", "")), ""))
		if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
			_icon.texture = load(tex_path)


func _play_drop_sfx() -> void:
	# 등급별 드랍 SFX 훅(F3-1 "등급별 드랍 사운드"). audio_sfx.json에 drop_common..
	# drop_legendary가 아직 없으면 AudioManager.play_sfx()가 조용히 no-op한다(기존
	# 몬스터 미제작 SFX와 동일한 관례, audio_manager.gd 주석 참고) — sound-designer가
	# 항목을 채우면 코드 변경 없이 그대로 소리가 난다.
	var grade: String = String(item_instance.get("grade", item_def.get("grade", "common")))
	AudioManager.play_sfx(StringName("drop_%s" % grade), global_position)


func _on_body_entered(body: Node) -> void:
	if _picked_up or not (body is Player):
		return
	_picked_up = true
	GameState.pickup_item(item_instance, item_def)
	queue_free()
