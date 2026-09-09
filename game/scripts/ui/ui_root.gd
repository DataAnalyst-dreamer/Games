## HUD(F7-1)와 인벤토리 메뉴(F7-2)를 한 CanvasLayer 아래 묶어 `menu` 액션 하나로 열기/
## 닫기 + `get_tree().paused`(D-24)를 이 한 곳에서만 결정한다(M2-2 작업 지시 5번).
## Hud.gd는 이 액션을 건드리지 않는다 — 각 화면이 저마다 pause를 만지면 상태가 어긋나기
## 쉬우므로, "메뉴가 하나라도 열려 있으면 paused" 규칙을 이 스크립트 하나로 강제한다.
##
## process_mode=ALWAYS: `paused=true`가 된 뒤에도 이 노드와 InventoryMenu 자신은 계속
## 입력을 받아야 `menu`/`ui_close`로 다시 닫을 수 있다(그 외 Player/몬스터/World는 기본
## PAUSABLE이라 의도대로 멈춘다).
class_name UiRoot
extends CanvasLayer

@onready var hud: Hud = $Hud/Root
@onready var inventory_menu: InventoryMenu = $InventoryMenu/Root


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inventory_menu.close_requested.connect(close_menu)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(&"menu"):
		toggle_menu()


func is_menu_open() -> bool:
	return inventory_menu.is_open()


## 스모크/GUT 및 `menu` 액션 핸들러가 공용으로 쓰는 공개 API — 열림/닫힘과 paused를
## 항상 함께 바꿔서 "메뉴 열림 == paused" 불변식이 절대 깨지지 않게 한다.
func toggle_menu() -> void:
	if is_menu_open():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	inventory_menu.open_menu()
	get_tree().paused = true


func close_menu() -> void:
	inventory_menu.close_menu()
	get_tree().paused = false
