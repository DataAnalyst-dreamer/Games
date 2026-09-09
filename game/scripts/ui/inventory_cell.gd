## 인벤토리/장비 슬롯 셀 하나(F7-2, M2-2 / 잠금 배지·장착 배지는 M2-5 D-88 신설).
## 격자 40~80칸과 장비 8슬롯+치장 3슬롯, 그리고 대장간(BlacksmithMenu, M2-5) 좌측
## 목록 아이콘까지 이 씬을 재사용한다(장비 슬롯은 비어있을 때 CaptionLabel로 슬롯
## 이름을 보여준다는 점만 다르다). 색·나인패치는 game/ui/theme.tres 한 곳에서만
## 읽어온다.
class_name InventoryCell
extends Panel

@onready var icon: ColorRect = $Icon
@onready var grade_bar: ColorRect = $GradeBar
@onready var grade_icon: Label = $GradeIcon
@onready var enhance_label: Label = $EnhanceLabel
@onready var qty_label: Label = $QtyLabel
@onready var caption_label: Label = $CaptionLabel
@onready var lock_overlay: ColorRect = $LockOverlay
@onready var badge_label: Label = $BadgeLabel
@onready var focus_ring: Panel = $FocusRing


func _ready() -> void:
	# get_theme_*()를 쓴다(Control의 상위 테마 상속 조회) — 이 씬 자신은 Theme 리소스를
	# 들고 있지 않아(InventoryMenu의 Root 하나만 theme.tres를 참조) `theme` 프로퍼티를
	# 직접 읽으면 null이다.
	add_theme_stylebox_override("panel", get_theme_stylebox(&"slot_cell", &"HUD"))
	focus_ring.add_theme_stylebox_override("panel", get_theme_stylebox(&"focus_highlight", &"Inventory"))
	lock_overlay.color = get_theme_color(&"locked_mark", &"Inventory")
	clear()


## 빈 칸으로 되돌린다(아이템 표시 전부 숨김). caption(있으면)만 남는다.
func clear() -> void:
	icon.visible = false
	grade_bar.visible = false
	grade_icon.visible = false
	enhance_label.visible = false
	qty_label.visible = false
	lock_overlay.visible = false
	badge_label.visible = false


## 빈 장비 슬롯에 표시할 슬롯 이름(예: "무기"). 격자 칸은 빈 문자열로 둔다.
func set_caption(text: String) -> void:
	caption_label.visible = text != ""
	caption_label.text = text


func set_item(grade_color: Color, grade_icon_char: String, quantity: int, enhance_level: int) -> void:
	caption_label.visible = false
	icon.visible = true
	grade_bar.visible = true
	grade_bar.color = grade_color
	grade_icon.visible = true
	grade_icon.text = grade_icon_char
	grade_icon.add_theme_color_override("font_color", grade_color)
	qty_label.visible = quantity > 1
	qty_label.text = "x%d" % quantity
	enhance_label.visible = enhance_level > 0
	enhance_label.text = "+%d" % enhance_level


func set_focused(focused: bool) -> void:
	focus_ring.visible = focused


## 즐겨찾기 잠금 표시(M2-5 D-88). 잠긴 아이템은 대장간 분해 탭 목록에서 자동 제외된다
## (`BlacksmithUiCalc.filter_salvage_indices`).
func set_locked_marked(marked: bool) -> void:
	lock_overlay.visible = marked


## 대장간 강화/재련 좌측 목록에서 "지금 장착 중"임을 알리는 배지(docs/ui/blacksmith.md
## §1.1 "[E]"). 인벤토리 격자·장비 슬롯 자체는 쓰지 않는다(기본 숨김).
func set_equipped_badge(equipped: bool) -> void:
	badge_label.visible = equipped
	badge_label.text = "[E]" if equipped else ""


func set_disabled(disabled: bool) -> void:
	modulate = get_theme_color(&"disabled", &"Inventory") if disabled else Color(1, 1, 1, 1)
