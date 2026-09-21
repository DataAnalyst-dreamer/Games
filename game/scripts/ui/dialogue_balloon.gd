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
	root.theme = HUD_THEME # ui_root.gd:29 패턴 — 없으면 테마 상속이 끊겨 엔진 기본 폰트(16px)로 그려진다.
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
	# 클릭 삼킴 버그: STOP(기본값)이면 이 위에 겹친 패널의 gui_input이 못 받는다 —
	# 애드온 dialogue_label.tscn과 같은 취급(이 노드 자체는 입력을 쓰지 않는다).
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(portrait)

	dialogue_label = DialogueLabel.new()
	dialogue_label.position = Vector2(128, 248)
	dialogue_label.size = Vector2(464, 44)
	dialogue_label.add_theme_color_override("default_color", HUD_THEME.get_color(&"text_default", &"HUD"))
	# 위 portrait와 같은 이유 — `DialogueLabel.new()`는 tscn 기본값을 안 물려받고
	# Control 기본 STOP으로 생성돼 본문 위 클릭이 패널까지 못 내려갔다.
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# 4개(계약 상한)가 48px(296~344) 안에 들어가야 해 여백을 두지 않는다(show_responses의
	# 압축 폰트 크기와 함께 계산, dialogue_balloon.gd:121-137 주석 참고).
	responses_menu.add_theme_constant_override("separation", 0)
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


## theme.tres에 Button 스타일이 없어(HUD_THEME은 Panel/Label류만 정의) 응답 버튼이 엔진
## 기본 StyleBoxFlat(내부 여백 포함)으로 그려지면 4개가 계약 영역(128,296)~(592,344,
## 48px)에 못 들어간다. StyleBoxEmpty(여백 0)로 바꾸고 포커스만 Inventory의 나무 프레임
## 하이라이트를 재사용(§5 재사용 목록)한다. 글자 크기는 `Dialogue/font_sizes/response`
## (theme.tres 한 곳, 도트액션RPG-기획안 UI 규칙 3번 — 화면별 상수를 theme.tres로 통일)로
## 48px/4행 예산에 맞춘 압축 크기를 쓴다.
func show_responses(responses: Array) -> void:
	responses_menu.responses = responses
	var empty_style := StyleBoxEmpty.new()
	var focus_style: StyleBox = HUD_THEME.get_stylebox(&"focus_highlight", &"Inventory")
	var response_font_size: int = HUD_THEME.get_font_size(&"response", &"Dialogue")
	for item: Node in responses_menu.get_children():
		if item is Button:
			for state in ["normal", "hover", "pressed", "disabled"]:
				item.add_theme_stylebox_override(state, empty_style)
			item.add_theme_stylebox_override("focus", focus_style)
			item.add_theme_font_size_override("font_size", response_font_size)
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
