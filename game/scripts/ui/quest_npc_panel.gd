## NPC별 수락/완료 UI(D-258). 후보 선정은 QuestNpcPanelCalc(giver 기준 데이터 테이블
## 스캔, D-244 우선순위)에 위임한다 — 특정 quest_id 하드코딩 목록 없이 game/data/quests/
## 전체가 대상이라 신규 퀘스트 추가 시 이 파일을 고칠 필요가 없다. Backend owns
## eligibility/rewards.
class_name QuestNpcPanel
extends Control

signal close_requested
var quest_id := ""
var npc_id := ""
var title_label: Label
var body_label: Label
var confirm_button: Button
var close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(52, 28)
	panel.size = Vector2(376, 214)
	panel.add_theme_stylebox_override("panel", theme.get_stylebox("parchment_fill", "HUD"))
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	title_label = Label.new()
	title_label.add_theme_color_override("font_color", Color("302619"))
	column.add_child(title_label)
	body_label = Label.new()
	body_label.add_theme_color_override("font_color", Color("302619"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(340, 112)
	column.add_child(body_label)
	confirm_button = Button.new()
	confirm_button.pressed.connect(_confirm)
	column.add_child(confirm_button)
	close_button = Button.new()
	close_button.text = tr(&"ui.quest_npc.close")
	close_button.pressed.connect(func(): close_requested.emit())
	column.add_child(close_button)
	visible = false


func open_for_npc(id: StringName) -> bool:
	npc_id = String(id)
	var quest_defs: Dictionary = Data.table("quests")
	var states: Dictionary = {}
	for candidate: String in quest_defs.keys():
		states[candidate] = QuestSystem.get_state(candidate)
	quest_id = QuestNpcPanelCalc.candidate_quest_id(npc_id, quest_defs, states)
	if quest_id.is_empty(): return false
	visible = true
	_refresh()
	return true


func _refresh() -> void:
	var definition: Dictionary = Data.get_value("quests", quest_id, {})
	var state := QuestSystem.get_state(quest_id)
	title_label.text = tr(StringName(definition.get("title_key", "")))
	body_label.text = tr(StringName(definition.get("desc_key", "")))
	confirm_button.disabled = state not in ["available", "complete_ready"]
	confirm_button.text = tr(&"ui.quest_npc.accept" if state == "available" else (&"ui.quest_npc.complete" if state == "complete_ready" else &"ui.quest_npc.active"))
	if state == "available":
		# M4-2(D-181~183): "퀘스트를 수락하면 어떤 보상을 받는지 안 보인다" 대응.
		var reward_line := _format_reward_summary(definition.get("rewards", {}))
		if not reward_line.is_empty():
			body_label.text += "\n\n" + tr(&"ui.quest_npc.reward_prefix") + " " + reward_line
	if state == "active":
		var index := QuestSystem.get_active_objective_index(quest_id)
		var objectives: Array = definition.get("objectives", [])
		if index >= 0 and index < objectives.size():
			body_label.text += "\n\n" + tr(StringName(objectives[index].get("text_key", "")))
	if confirm_button.disabled: close_button.grab_focus()
	else: confirm_button.grab_focus()


## QuestLogUiCalc.reward_rows()를 한 줄 요약으로 합친다("+10 골드, EXP +15"). 이
## 패널은 공간이 좁아(376x214) 아이콘 없이 텍스트만 쓴다(icon 표시는 quest_log_tab.gd
## 상세/hud.gd 완료 토스트 쪽에서 ItemIcon.resolve로 처리).
func _format_reward_summary(rewards: Dictionary) -> String:
	var parts := PackedStringArray()
	for row: Dictionary in QuestLogUiCalc.reward_rows(rewards):
		match String(row.get("kind", "")):
			"gold":
				parts.append("+%d %s" % [int(row.get("amount", 0)), tr(&"ui.hud.gold_unit")])
			"exp":
				parts.append(tr(&"ui.quest_log.reward_exp_fmt") % int(row.get("amount", 0)))
			"item":
				var item_id: String = String(row.get("item_id", ""))
				var item_def: Dictionary = Data.get_value("items", item_id, {})
				parts.append("%s x%d" % [tr(StringName(String(item_def.get("name_key", item_id)))), int(row.get("qty", 1))])
	return ", ".join(parts)


func _confirm() -> void:
	if not visible or confirm_button.disabled: return
	var definition: Dictionary = Data.get_value("quests", quest_id, {})
	if definition.get("giver", "") != npc_id: return
	var state := QuestSystem.get_state(quest_id)
	confirm_button.disabled = true
	var result := {}
	if state == "available": result = QuestSystem.accept(quest_id)
	elif state == "complete_ready": result = QuestSystem.advance(quest_id)
	if result.get("ok", false): close_requested.emit()
	else: _refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif event.is_action("interact") or event.is_action("menu"):
		get_viewport().set_input_as_handled()
