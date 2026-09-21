## 대사 풍선(⑪-1, D-145 6번째 단계). `docs/ui/dialogue-balloon.md`(v0.2) 좌표·입력
## 계약을 구현한다. `NpcDialogueController`의 상시 자식(process_mode는 부모에서 상속).
##
## 무상태(§7.4): 열릴 때마다 항상 줄 0부터 재생하며 내부 진행 상태를 저장하지 않는다.
## 타이핑·선택지 위젯은 이미 코드베이스에 있는 `addons/dialogue_manager`의
## `DialogueLabel`/`DialogueResponsesMenu`를 그대로 재사용한다(새로 만들지 않는다).
##
## 입력: 게임패드/키보드(`ui_confirm`/`interact`=다음·스킵, `ui_cancel`=선택지 없는
## 잡담만 스킵, D-241/D-246)는 이 스크립트의 `_unhandled_input`이 처리하고, 마우스
## 클릭(선택지 확정/본문 클릭=다음, D-196 패턴)은 각 위젯의 `gui_input`이 처리한다.
## `NpcDialogueController.try_consume_ui_confirm()`(D-254/D-259) 게이트를 통과하지
## 못하면 어떤 입력도 소비하지 않고 그대로 둔다 — `QuestNpcPanel`이 먼저 처리한다.
class_name DialogueBalloon
extends CanvasLayer

const HUD_THEME: Theme = preload("res://ui/theme.tres")

## D-254/D-259 입력 중재 게이트 조회 대상. `NpcDialogueController`가 인스턴스화 직후 대입한다.
var controller: Node = null

## 확인(스킵 없이 다음 줄) 시 `skip_all=false`, 취소로 잡담 전체를 건너뛸 때 `true`.
signal advanced(skip_all: bool)
signal response_chosen(response: DialogueResponse)

var name_label: Label
var dialogue_label: DialogueLabel
## VBoxContainer + dialogue_responses_menu.gd(set_script) — 그 스크립트가 `extends
## Container`(레이아웃 없음)로 선언돼 있어도 실제 세로 배치는 노드 타입(VBoxContainer)이
## 담당한다(addon 자신의 example_balloon.tscn도 동일 조합, 확인). GDScript 정적 타입
## 검사기는 런타임 set_script() 이후의 타입 변화를 인식하지 못하므로 이 필드는 의도적으로
## 타입을 명시하지 않는다(duck typing).
var responses_menu

var _current_line: DialogueLine = null
var _has_pending_responses: bool = false


func _ready() -> void:
	visible = false
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(40, 240)
	panel.size = Vector2(560, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", HUD_THEME.get_stylebox(&"parchment_fill", &"HUD"))
	panel.gui_input.connect(_on_panel_gui_input)
	root.add_child(panel)

	name_label = Label.new()
	name_label.position = Vector2(48, 224)
	name_label.size = Vector2(160, 20)
	name_label.add_theme_color_override("font_color", HUD_THEME.get_color(&"text_default", &"HUD"))
	root.add_child(name_label)

	# 초상 슬롯: pixel-artist 애셋 없음 — 회색 placeholder(단색 도형)로 대체
	# (작업 규칙 4, "빈 칸 노출 금지"). TODO(pixel-artist): NPC별 초상 64x64.
	var portrait := ColorRect.new()
	portrait.position = Vector2(48, 248)
	portrait.size = Vector2(64, 64)
	portrait.color = Color(0.5, 0.5, 0.5)
	root.add_child(portrait)

	dialogue_label = DialogueLabel.new()
	dialogue_label.position = Vector2(128, 248)
	dialogue_label.size = Vector2(464, 44)
	dialogue_label.add_theme_color_override("default_color", HUD_THEME.get_color(&"text_default", &"HUD"))
	dialogue_label.finished_typing.connect(_on_finished_typing)
	root.add_child(dialogue_label)

	# DialogueResponsesMenu는 `extends Container`(레이아웃 없음)로 선언돼 있지만 애드온
	# 자신의 example_balloon.tscn도 실제로는 이 스크립트를 VBoxContainer 노드에 붙여
	# 세로 배치를 얻는다(확인) — `DialogueResponsesMenu.new()`로 만들면 평범한 Container라
	# 자식이 전부 (0,0)에 겹친다.
	responses_menu = VBoxContainer.new()
	responses_menu.set_script(preload("res://addons/dialogue_manager/dialogue_responses_menu.gd"))
	responses_menu.position = Vector2(128, 296)
	responses_menu.size = Vector2(464, 48)
	responses_menu.add_theme_constant_override("separation", 4)
	responses_menu.next_action = &"ui_confirm"
	responses_menu.response_selected.connect(func(response: DialogueResponse) -> void:
		response_chosen.emit(response))
	responses_menu.hide()
	root.add_child(responses_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if controller != null and not controller.try_consume_ui_confirm():
		return
	if event.is_action_pressed(&"ui_confirm") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_on_confirm()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


## 무상태 원칙(§7.4): 매번 처음부터 재생하므로 진행 상태를 저장하지 않는다.
func show_line(line: DialogueLine) -> void:
	_current_line = line
	_has_pending_responses = false
	responses_menu.hide()
	name_label.visible = not line.character.is_empty()
	name_label.text = tr(line.character, "dialogue") if not line.character.is_empty() else ""
	dialogue_label.dialogue_line = line
	dialogue_label.type_out()


func show_responses(responses: Array) -> void:
	responses_menu.responses = responses
	# 기본 Button 테마 높이(~30px)로는 4개까지 (128,296)-(592,344) 영역에 안 들어간다 —
	# placeholder UI 단계라 폰트를 줄여 우선 겹치지 않게만 맞춘다(pixel-artist/ui-ux-designer
	# 정식 확정 전 임시. 완료 보고 TODO).
	for item: Node in responses_menu.get_children():
		if item is Button:
			item.add_theme_font_size_override("font_size", 11)
			item.custom_minimum_size = Vector2(0, 14)
	if is_typing():
		_has_pending_responses = true
	else:
		responses_menu.show()


func skip_typing() -> void:
	dialogue_label.skip_typing()


func is_typing() -> bool:
	return dialogue_label.is_typing


func _on_finished_typing() -> void:
	if _has_pending_responses:
		_has_pending_responses = false
		responses_menu.show()


func _on_confirm() -> void:
	if is_typing():
		skip_typing()
		return
	if _current_line == null or not _current_line.responses.is_empty():
		return # 선택지 확정은 DialogueResponsesMenu(ui_confirm=next_action)가 직접 처리한다.
	advanced.emit(false)


## D-241: 선택지 없는 잡담만 `ui_cancel`로 스킵 허용, 분기 대사는 무효화.
func _on_cancel() -> void:
	if _current_line == null or not _current_line.responses.is_empty():
		return
	advanced.emit(true)


## D-196 패턴: 본문 클릭=다음(타이핑 중이면 스킵), 선택지가 떠 있으면 무시(선택지
## 각각의 gui_input이 직접 처리).
func _on_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if is_typing():
		get_viewport().set_input_as_handled()
		skip_typing()
		return
	if _current_line == null or not _current_line.responses.is_empty():
		return
	get_viewport().set_input_as_handled()
	advanced.emit(false)
