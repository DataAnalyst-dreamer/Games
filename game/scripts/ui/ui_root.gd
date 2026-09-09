## HUD(F7-1)와 전체화면 UI 3종(인벤토리 F7-2, 대장간·우편함 F3-3/F3-4 M2-5)을 한
## CanvasLayer 아래 묶어 열기/닫기 + `get_tree().paused`(D-24)를 이 한 곳에서만
## 결정한다(M2-2 작업 지시 5번, M2-5로 대장간/우편함까지 확장). 각 화면 스크립트는
## Hud.gd와 마찬가지로 이 규칙을 건드리지 않는다 — "전체화면 UI가 하나라도 열려 있으면
## paused" 불변식을 이 스크립트 하나로 강제한다.
##
## process_mode=ALWAYS: `paused=true`가 된 뒤에도 이 노드와 하위 화면들은 계속 입력을
## 받아야 `menu`/`ui_close`/`pause`로 다시 닫을 수 있다(그 외 Player/몬스터/World는
## 기본 PAUSABLE이라 의도대로 멈춘다).
class_name UiRoot
extends CanvasLayer

@onready var hud: Hud = $Hud/Root
@onready var inventory_menu: InventoryMenu = $InventoryMenu/Root
@onready var blacksmith_menu: BlacksmithMenu = $BlacksmithMenu/Root
@onready var mailbox_popup: MailboxPopup = $MailboxPopup/Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_menu.close_requested.connect(close_menu)
	blacksmith_menu.close_requested.connect(close_blacksmith)
	mailbox_popup.close_requested.connect(close_mailbox)
	Events.blacksmith_opened.connect(open_blacksmith)
	Events.mailbox_opened.connect(open_mailbox)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(&"menu"):
		# 대장간/우편함이 이미 열려 있으면 인벤토리 메뉴를 겹쳐 열지 않는다(전체화면 UI는
		# 한 번에 하나만 — D-91과 같은 원칙의 연장).
		if is_blacksmith_open() or is_mailbox_open():
			return
		toggle_menu()


func is_menu_open() -> bool:
	return inventory_menu.is_open()


func is_blacksmith_open() -> bool:
	return blacksmith_menu.is_open()


func is_mailbox_open() -> bool:
	return mailbox_popup.is_open()


## 스모크/GUT 및 `menu` 액션 핸들러가 공용으로 쓰는 공개 API — 열림/닫힘과 paused를
## 항상 함께 바꿔서 "메뉴 열림 == paused" 불변식이 절대 깨지지 않게 한다.
func toggle_menu() -> void:
	if is_menu_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	inventory_menu.open_menu()
	_recompute_paused()


func close_menu() -> void:
	inventory_menu.close_menu()
	_recompute_paused()


func open_blacksmith() -> void:
	if is_menu_open() or is_mailbox_open():
		return
	blacksmith_menu.open_menu()
	_recompute_paused()


func close_blacksmith() -> void:
	blacksmith_menu.close_menu()
	_recompute_paused()


func open_mailbox() -> void:
	if is_menu_open() or is_blacksmith_open():
		return
	mailbox_popup.open_popup()
	_recompute_paused()


func close_mailbox() -> void:
	mailbox_popup.close_popup()
	_recompute_paused()


func _recompute_paused() -> void:
	get_tree().paused = is_menu_open() or is_blacksmith_open() or is_mailbox_open()
