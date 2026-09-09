## 필드 드랍 오브젝트(F3-1). LootSystem이 만든 ItemInstance 하나를 들고 몬스터 사망
## 위치에 스폰되며(scripts/systems/loot_spawner.gd), 플레이어가 접근하면 자동 획득된다.
##
## 표시: 등급 색 외곽선(Rarity.color_of(), game/ui/theme.tres 단일 소스) + 아이템별
## 아이콘. M2-3 소규모 추가: asset-wrangler가 만든 `game/data/item_icons.json`(58개
## 배정, `docs/art/item-icon-map.md`)을 `ItemIcon.resolve()`(scripts/ui/item_icon.gd)로
## 조회해 아이템 고유 아이콘을 우선 쓰고, 그 표에 없는 아이템만 아래 CATEGORY_ICON
## 카테고리 대표 이미지로 폴백한다(예전엔 전부 카테고리 폴백뿐이었다). 접근 시 자동
## 획득 판정은 Waystone.tscn과 동일하게 Area2D + collision_mask=2(Player CharacterBody2D의
## collision_layer)로 처리한다.
class_name ItemDrop
extends Area2D

## ItemIcon.resolve()가 item_icons.json에서 못 찾았을 때의 카테고리별 폴백 아이콘 경로.
## 없는 카테고리는 아이콘 없이 외곽선만 표시한다.
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
		var item_id: String = String(item_instance.get("item_id", item_def.get("item_id", "")))
		var icon_tex: Texture2D = ItemIcon.resolve(item_id)
		if icon_tex != null:
			_icon.texture = icon_tex
		else:
			# asset-wrangler item_icons.json에 아직 없는 아이템(또는 로드 실패) — 기존
			# 카테고리 대표 아이콘으로 폴백(완전히 아이콘 없는 것보다 낫다).
			var tex_path: String = String(CATEGORY_ICON.get(String(item_def.get("category", "")), ""))
			if not tex_path.is_empty() and ResourceLoader.exists(tex_path):
				_icon.texture = load(tex_path)


func _play_drop_sfx() -> void:
	# 등급별 드랍 SFX(F3-1 "등급별 드랍 사운드", audio_sfx.json _comment/§4 참고).
	# epic/legendary는 베이스 사운드 위에 전용 반짝임/트윙클 레이어를 같은 프레임에
	# 추가로 재생해 2레이어로 겹쳐 들리게 한다(audio-spec.md §4 원칙2 — legendary는
	# "다른 어떤 이벤트에도 재사용 금지"인 전용 레이어라 여기서만 호출한다).
	var grade: String = String(item_instance.get("grade", item_def.get("grade", "common")))
	AudioManager.play_sfx(StringName("drop_%s" % grade), global_position)
	match grade:
		"epic":
			AudioManager.play_sfx(&"drop_epic_layer", global_position)
		"legendary":
			AudioManager.play_sfx(&"legendary_drop_sparkle", global_position)


func _on_body_entered(body: Node) -> void:
	if _picked_up or not (body is Player):
		return
	_picked_up = true
	GameState.pickup_item(item_instance, item_def)
	queue_free()
