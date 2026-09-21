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
var quest_npc_panel: QuestNpcPanel
var npc_dialogue_controller: NpcDialogueController

## D-259: `close_quest_npc()`가 켜는 1프레임 입력 유예 플래그 — 패널을 닫은 바로 그 입력이
## (패드에서 interact/ui_confirm이 같은 버튼) 대사 풍선에 곧장 먹히지 않게 한다.
var quest_npc_just_closed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_npc_ui")
	quest_npc_panel = QuestNpcPanel.new()
	quest_npc_panel.theme = hud.theme
	add_child(quest_npc_panel)
	npc_dialogue_controller = NpcDialogueController.new()
	npc_dialogue_controller.ui_root = self
	npc_dialogue_controller.player = get_tree().get_first_node_in_group(&"player")
	add_child(npc_dialogue_controller)
	inventory_menu.close_requested.connect(close_menu)
	blacksmith_menu.close_requested.connect(close_blacksmith)
	mailbox_popup.close_requested.connect(close_mailbox)
	Events.blacksmith_opened.connect(open_blacksmith)
	Events.mailbox_opened.connect(open_mailbox)
	quest_npc_panel.close_requested.connect(close_quest_npc)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(&"menu"):
		# 대장간/우편함이 이미 열려 있으면 인벤토리 메뉴를 겹쳐 열지 않는다(전체화면 UI는
		# 한 번에 하나만 — D-91과 같은 원칙의 연장). D-256: 대사 진행 중에도 마찬가지.
		if is_blacksmith_open() or is_mailbox_open() or is_quest_npc_open() or is_dialogue_open():
			return
		toggle_menu()
	elif Input.is_action_just_pressed(&"quest_log"):
		# D-153: J 키 = 퀘스트 로그 바로가기(키보드 전용, 패드 미배정). 다른 전체화면
		# UI가 이미 열려 있으면 무시하고, 메뉴가 닫혀 있으면 열면서 곧장 quest 탭으로,
		# 이미 열려 있으면(다른 탭이었어도) quest 탭으로만 전환한다. D-256: 대사 중도 무시.
		if is_blacksmith_open() or is_mailbox_open() or is_quest_npc_open() or is_dialogue_open():
			return
		if not is_menu_open():
			open_menu()
		inventory_menu.select_tab("quest")


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
	if is_quest_npc_open() or is_blacksmith_open() or is_mailbox_open(): return
	inventory_menu.open_menu()
	_recompute_paused()


func close_menu() -> void:
	inventory_menu.close_menu()
	_recompute_paused()


func open_blacksmith() -> void:
	if is_menu_open() or is_mailbox_open() or is_quest_npc_open():
		return
	blacksmith_menu.open_menu()
	_recompute_paused()


func close_blacksmith() -> void:
	blacksmith_menu.close_menu()
	_recompute_paused()


func open_mailbox() -> void:
	if is_menu_open() or is_blacksmith_open() or is_quest_npc_open():
		return
	mailbox_popup.open_popup()
	_recompute_paused()


func close_mailbox() -> void:
	mailbox_popup.close_popup()
	_recompute_paused()


## M4-5 버그 수정: 전체화면 UI가 열려 있는 동안 Hud(CanvasLayer)를 계속 그리고 있었다.
## InventoryMenu의 반투명 Backdrop(72% 불투명, 의도된 "은은한" 디자인)이 HUD 위에
## 겹쳐지면서 HUD TopLeft의 HP바(적색 채움)·HP 숫자("100 / 100")가 28% 밝기로 비쳐
## 보였고, 하필 InventoryMenu의 TabBar(좌상단, 거의 같은 자리)와 겹쳐 "스킬OO 도감O"처럼
## 탭 글자 위에 숫자가 겹쳐 보이는 문제를 만들었다(디버그 캡처로 원인 확정 — Hud만
## 숨기면 겹침이 완전히 사라짐, TabBar 쪽엔 중복 노드가 전혀 없었다). 전체화면 UI가
## 열려 있는 동안은 어차피 각 화면이 필요한 정보(스탯/스킬 패널의 파생치 등)를 자체
## 표시하므로, HUD를 숨겨도 정보 손실이 없다 — `_recompute_paused()`와 동일한 조건으로
## 함께 갱신한다.
func _recompute_paused() -> void:
	var any_fullscreen_open: bool = is_menu_open() or is_blacksmith_open() or is_mailbox_open() or is_quest_npc_open()
	get_tree().paused = any_fullscreen_open
	hud.visible = not any_fullscreen_open


func is_quest_npc_open() -> bool:
	return is_instance_valid(quest_npc_panel) and quest_npc_panel.visible


func open_quest_npc(npc_id: StringName) -> void:
	if is_menu_open() or is_blacksmith_open() or is_mailbox_open() or is_quest_npc_open(): return
	if quest_npc_panel.open_for_npc(npc_id): _recompute_paused()


func close_quest_npc() -> void:
	quest_npc_panel.visible = false
	_recompute_paused()
	quest_npc_just_closed = true
	_clear_quest_npc_just_closed_next_frame()


## D-259: 패널을 닫은 프레임에 곧장 재사용되는 같은 버튼(interact/ui_confirm 패드 공유)이
## 대사 풍선에 먹히지 않도록 1프레임만 유예한다.
func _clear_quest_npc_just_closed_next_frame() -> void:
	await get_tree().process_frame
	quest_npc_just_closed = false


## D-256: `is_dialogue_open()`도 이 5종 상호배타 집합에 넣는다(대사 중 menu/quest_log 무시).
func is_dialogue_open() -> bool:
	return is_instance_valid(npc_dialogue_controller) and npc_dialogue_controller.is_dialogue_open()
