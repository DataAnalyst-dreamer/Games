## 스킬 트리(M4-5, D-161/D-194/D-195, ro-benchmark-progression-v1.md §4). `skill_panel_tab.gd`의
## "skill" 서브탭 실제 구현 — quest_log_tab.gd/skill_panel_tab.gd(구v1)와 동일하게
## 500줄 상한(D-145)을 지키려고 별도 파일로 분리했다.
##
## 게임패드 우선: 계열(blade/guard/trick) 전환은 `ui_filter_prev`/`ui_filter_next`
## (docs/ui/wireframes.md §0.1 "서브 카테고리 전환" 규약 — 상위 SkillPanelTab이 이미
## move_left/right를 스탯/스킬 서브탭 전환에 쓰고 있어 재사용 불가). 노드 포커스는
## tier1→2→3을 이어붙인 1차원 목록을 상/하로 순회(SkillTreeCalc.focus_order). 확인=
## 습득/레벨업, 1~9(HotbarRegisterInput)=핫바 등록(습득된 active/buff만).
##
## `Progression.can_learn_skill/get_skill_level`(stage/m4-4, 병합 전엔 없음)는 has_method
## 가드로 우선 사용하고, 없으면 SkillTreeCalc(로컬 계산)로 폴백한다 — 계산 결과 모양은
## 두 경로가 동일(state/reason)하도록 맞춰 병합 전후 화면이 크게 달라지지 않게 했다.
class_name SkillTreeTab
extends Control

const SERIES_LABEL_KEYS := {
	"blade": &"ui.skill_tree.series.blade",
	"guard": &"ui.skill_tree.series.guard",
	"trick": &"ui.skill_tree.series.trick",
}
## D-194: Progression.can_learn_skill()의 reason(StringName) -> 로컬라이징 키.
const REASON_HINT_KEYS := {
	&"no_points": &"ui.skill.reason_no_points",
	&"requires": &"ui.skill.reason_requires",
	&"maxed": &"ui.skill.reason_maxed",
	&"unknown": &"ui.skill.reason_unknown",
}
const NODE_TYPE_LABEL_KEYS := {
	"active": &"ui.skill.node_type.active",
	"passive": &"ui.skill.node_type.passive",
	"buff": &"ui.skill.node_type.buff",
}
## 레벨별 수치 표시(코디네이터 후속 지시 1건, D-196): SkillTreeCalc.level_detail_rows()가
## 내는 field 이름 -> "%s" 자리에 숫자(문자열)만 넣으면 되는 완성 템플릿. 필드명 원문이
## 그대로 노출되지 않도록 여기 목록에 없는 field는 `_format_detail_rows()`가 건너뛴다.
const FIELD_LABEL_KEYS := {
	"sp_cost": &"ui.skill.field.sp_cost", "cooldown_sec": &"ui.skill.field.cooldown_sec",
	"damage_mult": &"ui.skill.field.damage_mult", "atk_buff_pct": &"ui.skill.field.atk_buff_pct",
	"dmg_reduction_pct": &"ui.skill.field.dmg_reduction_pct", "move_speed_mult": &"ui.skill.field.move_speed_mult",
	"invuln_sec": &"ui.skill.field.invuln_sec", "dash_px": &"ui.skill.field.dash_px",
	"duration_sec": &"ui.skill.field.duration_sec", "atk_pct": &"ui.skill.field.atk_pct",
	"crit_damage_pct": &"ui.skill.field.crit_damage_pct", "aspd_pct": &"ui.skill.field.aspd_pct",
	"defense_flat": &"ui.skill.field.defense_flat", "guard_damage_reduction_pct": &"ui.skill.field.guard_damage_reduction_pct",
	"max_hp_pct": &"ui.skill.field.max_hp_pct", "sp_regen_pct": &"ui.skill.field.sp_regen_pct",
	"crit_chance_pct": &"ui.skill.field.crit_chance_pct", "move_speed_pct": &"ui.skill.field.move_speed_pct",
}

var _series_bar: HBoxContainer
var _series_buttons: Dictionary = {} # series -> Button
var _tier_columns: Array[VBoxContainer] = []
var _node_labels: Dictionary = {} # id -> Button (M5-1: 마우스 클릭)

var _detail_title: Label
var _detail_meta: Label
var _detail_requires: Label
var _detail_numbers: Label
var _detail_hint: Label
var _hotbar_bar: HudHotbarBar

var _series_index: int = 0
var _focus_index: int = 0
var _focus_ids: Array[String] = []
var _skills_table: Dictionary = {}
var _learned: Dictionary = {}
var _skill_points: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	_series_bar = HBoxContainer.new()
	_series_bar.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_series_bar)
	for i in SkillTreeCalc.SERIES.size():
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_series_pressed.bind(i)) # M5-1(마우스).
		_series_bar.add_child(button)
		_series_buttons[SkillTreeCalc.SERIES[i]] = button

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(body)

	var columns_box := HBoxContainer.new()
	columns_box.add_theme_constant_override("separation", 16)
	columns_box.custom_minimum_size = Vector2(280, 0)
	body.add_child(columns_box)
	for _tier in 3:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns_box.add_child(column)
		_tier_columns.append(column)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_box)
	_detail_title = Label.new()
	detail_box.add_child(_detail_title)
	_detail_meta = Label.new()
	detail_box.add_child(_detail_meta)
	_detail_requires = Label.new()
	_detail_requires.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_requires)
	_detail_numbers = Label.new()
	_detail_numbers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_numbers)
	_detail_hint = Label.new()
	_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_hint)
	_hotbar_bar = HudHotbarBar.new()
	_hotbar_bar.slot_clicked.connect(_on_hotbar_slot_clicked) # M5-1(마우스).
	detail_box.add_child(_hotbar_bar)

	_apply_theme_colors()


func _apply_theme_colors() -> void:
	if theme == null:
		return
	for series: String in SkillTreeCalc.SERIES:
		(_series_buttons[series] as Button).add_theme_color_override(
			"font_color", theme.get_color(&"tab_inactive", &"Inventory"))


## SkillPanelTab.open()이 "skill" 서브탭으로 전환될 때 호출.
func open() -> void:
	if not Events.skills_changed.is_connected(_on_skills_changed):
		Events.skills_changed.connect(_on_skills_changed)
	_hotbar_bar.theme = theme
	_skills_table = Data.table("skills")
	_load_state()
	_series_index = 0
	_focus_index = 0
	_refresh_series_bar()
	_rebuild_tree()


func close() -> void:
	if Events.skills_changed.is_connected(_on_skills_changed):
		Events.skills_changed.disconnect(_on_skills_changed)


func _load_state() -> void:
	_learned = SkillTreeCalc.normalize_learned(GameState.get("learned_skills"))
	_skill_points = int(GameState.skill_points)


func _on_skills_changed(learned: Variant, _slots: Variant, skill_points: int) -> void:
	_learned = SkillTreeCalc.normalize_learned(learned)
	_skill_points = skill_points
	if visible:
		_refresh_node_states()
		_refresh_detail()


# --- 입력(SkillPanelTab.handle_input이 "skill" 서브탭일 때만 위임) ---

func handle_input(_delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_filter_prev"):
		_change_series(-1)
	elif Input.is_action_just_pressed(&"ui_filter_next"):
		_change_series(1)
	elif Input.is_action_just_pressed(&"move_up"):
		_move_focus(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		_move_focus(1)
	elif Input.is_action_just_pressed(&"ui_confirm"):
		_confirm_learn()
	else:
		_try_hotbar_register()


func _change_series(delta: int) -> void:
	_series_index = wrapi(_series_index + delta, 0, SkillTreeCalc.SERIES.size())
	_focus_index = 0
	_refresh_series_bar()
	_rebuild_tree()


## M5-1(마우스): 계열 버튼 클릭 — _change_series()와 동일하게 인덱스 대입 후 같은
## 갱신 함수를 재사용(InventoryMenu._on_filter_pressed()와 동일 패턴).
func _on_series_pressed(index: int) -> void:
	_series_index = index
	_focus_index = 0
	_refresh_series_bar()
	_rebuild_tree()


func _move_focus(delta: int) -> void:
	if _focus_ids.is_empty():
		return
	_focus_index = wrapi(_focus_index + delta, 0, _focus_ids.size())
	_refresh_node_states()
	_refresh_detail()


func _current_series() -> String:
	return SkillTreeCalc.SERIES[_series_index]


func _focused_id() -> String:
	if _focus_ids.is_empty() or _focus_index >= _focus_ids.size():
		return ""
	return _focus_ids[_focus_index]


func _confirm_learn() -> void:
	var id: String = _focused_id()
	if id.is_empty():
		return
	if Progression.has_method(&"can_learn_skill"):
		if not bool((Progression.can_learn_skill(id) as Dictionary).get("ok", false)):
			return
	elif String(SkillTreeCalc.node_state(id, _skills_table, _learned, _skill_points).get("state", "")) != "learnable":
		return
	Progression.learn_skill(id)


## M5-1(마우스): 노드 클릭 — 이미 포커스된 노드를 다시 클릭(=피드백 요청 "더블클릭 또는
## 포커스 후 클릭")하면 기존 확정 로직(_confirm_learn)을 그대로 호출하고, 아니면 그
## 노드로 포커스만 옮긴다(확정 로직 중복 금지 원칙).
func _on_node_pressed(id: String) -> void:
	if id == _focused_id():
		_confirm_learn()
		return
	var idx: int = _focus_ids.find(id)
	if idx < 0:
		return
	_focus_index = idx
	_refresh_node_states()
	_refresh_detail()


func _try_hotbar_register() -> void:
	var id: String = _focused_id()
	if id.is_empty():
		return
	var node_type: String = String(_skills_table.get(id, {}).get("node_type", ""))
	if node_type not in ["active", "buff"] or int(_learned.get(id, 0)) <= 0:
		return
	if HotbarRegisterInput.try_assign("skill", id):
		_hotbar_bar.highlight_slot("skill", id)


## M5-1(마우스): 핫바 미리보기 칸 클릭 — 어느 슬롯인지는 클릭이 이미 알려주므로
## 1~9 키 폴링 없이 SkillTreeCalc.assignable_skill_id()로 "지금 등록해도 되는 스킬인지"만
## 판정한다(_try_hotbar_register()와 동일 가드, 로직은 순수 함수로 이미 옮겨둠).
func _on_hotbar_slot_clicked(slot: int) -> void:
	var id: String = SkillTreeCalc.assignable_skill_id(_focused_id(), _skills_table, _learned)
	if HotbarRegisterInput.assign_now(slot, "skill", id):
		_hotbar_bar.highlight_slot("skill", id)


# --- 표시 갱신 ---

func _refresh_series_bar() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory") if theme != null else Color.WHITE
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory") if theme != null else Color.GRAY
	for series: String in SkillTreeCalc.SERIES:
		var button: Button = _series_buttons[series]
		button.text = tr(SERIES_LABEL_KEYS[series])
		var is_active: bool = series == _current_series()
		var series_color: Color = active_color
		if is_active and theme != null and theme.has_color(StringName(series), &"SkillTree"):
			series_color = theme.get_color(StringName(series), &"SkillTree")
		button.add_theme_color_override("font_color", series_color if is_active else inactive_color)


func _rebuild_tree() -> void:
	for column: VBoxContainer in _tier_columns:
		for child in column.get_children():
			child.queue_free()
	_node_labels.clear()

	var series: String = _current_series()
	var by_tier: Dictionary = SkillTreeCalc.nodes_by_tier(series, _skills_table)
	for tier in [1, 2, 3]:
		for id: Variant in (by_tier.get(tier, []) as Array):
			# M5-1(마우스): Label 대신 Button(flat) — pressed 연결만으로 클릭을 받을 수 있어
			# gui_input 좌표 파싱보다 코드가 덜 든다. 이름+상태 두 줄은 텍스트 자체에 이미
			# 개행이 있어(_refresh_node_states 참고) Button에 autowrap이 없어도 문제없다.
			var label := Button.new()
			label.flat = true
			label.focus_mode = Control.FOCUS_NONE
			label.pressed.connect(_on_node_pressed.bind(String(id)))
			_tier_columns[tier - 1].add_child(label)
			_node_labels[String(id)] = label
	_focus_ids = SkillTreeCalc.focus_order(series, _skills_table)
	_refresh_node_states()
	_refresh_detail()


func _refresh_node_states() -> void:
	var focus_color: Color = theme.get_color(&"focus", &"Inventory") if theme != null else Color.YELLOW
	var default_color: Color = theme.get_color(&"neutral", &"Inventory") if theme != null else Color.WHITE
	var disabled_color: Color = theme.get_color(&"disabled", &"Inventory") if theme != null else Color.GRAY
	var focused_id: String = _focused_id()
	for id: String in _focus_ids:
		var label: Button = _node_labels.get(id)
		if label == null:
			continue
		var state: Dictionary = _node_state(id)
		var def: Dictionary = _skills_table.get(id, {})
		var name_text: String = tr(StringName(String(def.get("name_key", id))))
		var level_text: String = tr(&"ui.skill.level_fmt") % [int(state.get("level", 0)), int(state.get("max_level", 5))]
		var mark: String = ""
		if state.get("state") == "maxed":
			mark = tr(&"ui.skill.state.maxed")
		elif int(state.get("level", 0)) > 0:
			mark = tr(&"ui.skill.state.learned")
		elif state.get("state") == "learnable":
			mark = tr(&"ui.skill.state.learnable")
		label.text = "%s\n%s %s" % [name_text, level_text, mark]
		var color := default_color
		if id == focused_id:
			color = focus_color
		elif state.get("state") == "locked":
			color = disabled_color
		label.add_theme_color_override("font_color", color)


func _node_state(id: String) -> Dictionary:
	if Progression.has_method(&"can_learn_skill"):
		var r: Dictionary = Progression.can_learn_skill(id)
		var level: int = Progression.get_skill_level(id) if Progression.has_method(&"get_skill_level") else int(_learned.get(id, 0))
		var max_level: int = int(_skills_table.get(id, {}).get("max_level", SkillTreeCalc.DEFAULT_MAX_LEVEL))
		var reason: StringName = r.get("reason", &"unknown")
		var state: String = "maxed" if reason == &"maxed" else ("learnable" if bool(r.get("ok", false)) else "locked")
		return {"state": state, "reason": reason, "level": level, "max_level": max_level}
	return SkillTreeCalc.node_state(id, _skills_table, _learned, _skill_points)


func _refresh_detail() -> void:
	var id: String = _focused_id()
	if id.is_empty():
		_detail_title.text = tr(&"ui.quest_log.empty")
		_detail_meta.text = ""
		_detail_requires.text = ""
		_detail_numbers.text = ""
		_detail_hint.text = ""
		_hotbar_bar.highlight_slot("skill", "")
		return

	var def: Dictionary = _skills_table.get(id, {})
	var state: Dictionary = _node_state(id)
	var level: int = int(state.get("level", 0))
	var max_level: int = int(state.get("max_level", 5))
	_detail_title.text = "%s %s" % [tr(StringName(String(def.get("name_key", id)))), tr(&"ui.skill.level_fmt") % [level, max_level]]
	_detail_meta.text = tr(NODE_TYPE_LABEL_KEYS.get(String(def.get("node_type", "")), &"ui.skill.node_type.active"))
	_detail_requires.text = _requires_text(id)
	_detail_numbers.text = _format_detail_rows(def, maxi(level, 1))
	_detail_hint.text = _hint_text(def, state, level)
	var node_type: String = String(def.get("node_type", ""))
	_hotbar_bar.highlight_slot("skill", id if (level > 0 and node_type in ["active", "buff"]) else "")


## SkillTreeCalc.level_detail_rows()의 {field,text,next_text}를 로컬라이징 템플릿에
## 끼워 넣는다. next_text가 있으면 "현재 → 다음"을 숫자 자리 하나에 합쳐 넣어(예: 템플릿
## "재사용 %s초" + "6.0 → 4.8" = "재사용 6.0 → 4.8초") 단위를 두 번 반복하지 않는다.
## FIELD_LABEL_KEYS에 없는 field(=모르는 필드)는 건너뛴다 — 원문 필드명 노출 금지.
func _format_detail_rows(entry: Dictionary, level: int) -> String:
	var parts := PackedStringArray()
	for row: Dictionary in SkillTreeCalc.level_detail_rows(entry, level):
		var field: String = String(row.get("field", ""))
		if not FIELD_LABEL_KEYS.has(field):
			continue
		var number: String = String(row.get("text", ""))
		var next_text: String = String(row.get("next_text", ""))
		if not next_text.is_empty():
			number = "%s → %s" % [number, next_text]
		parts.append(tr(FIELD_LABEL_KEYS[field]) % number)
	return " · ".join(parts)


func _requires_text(id: String) -> String:
	var requires: Array = SkillTreeCalc.requires_of(id, _skills_table)
	if requires.is_empty():
		return tr(&"ui.skill.requires_none")
	var parts := PackedStringArray()
	for req: Variant in requires:
		var r: Dictionary = req
		var req_id: String = String(r.get("skill", ""))
		var req_name: String = tr(StringName(String(_skills_table.get(req_id, {}).get("name_key", req_id))))
		parts.append(tr(&"ui.skill.requires_fmt") % [req_name, int(r.get("level", 1))])
	return ", ".join(parts)


func _hint_text(def: Dictionary, state: Dictionary, level: int) -> String:
	var lines := PackedStringArray()
	match String(state.get("state", "")):
		"maxed":
			lines.append(tr(&"ui.skill.reason_maxed"))
		"learnable":
			lines.append(tr(&"ui.skill.learn_hint"))
		_:
			lines.append(tr(REASON_HINT_KEYS.get(state.get("reason", &"unknown"), &"ui.skill.locked_hint")))
	var node_type: String = String(def.get("node_type", ""))
	if level > 0 and node_type in ["active", "buff"]:
		lines.append(tr(&"ui.skill.slot_hint"))
	return "\n".join(lines)
