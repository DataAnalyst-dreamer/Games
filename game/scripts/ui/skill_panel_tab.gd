## 스탯 분배 · 스킬 패널(F1-2/F1-3, M3-4, D-163~D-166). InventoryMenu의 기존 "skill" 탭
## 자리를 실제로 구현한다(quest_log_tab.gd와 동일 원칙 — inventory_menu.gd가 이미 500줄
## 상한을 넘어 있어 여기 로직을 전부 옮기지 않고 별도 파일로 분리, InventoryMenu.tscn엔
## 빈 컨테이너만 둔다).
##
## 게임패드 우선(docs/ui/skill-panel.md §3): 좌/우로 스탯·스킬 서브탭 전환, 상/하로 행/
## 목록 이동, 확인으로 배분/습득. 슬롯 장착은 M4-2(D-181~183)에서 기존 skill_1(Q)/
## skill_2(R) 2슬롯 방식을 걷어내고 9칸 핫바 등록(hotbar_register_input.gd, 포커스한
## 스킬 위에서 1~9)으로 교체했다(Q/R 장착 코드 제거) — `HudHotbarBar`로 미리보기 표시.
##
## `Progression.allocate_stat/learn_skill/equip_skill`(stage/m3-3, 아직 미병합)는
## `has_method` 가드로 호출한다 — 미병합 상태에서도 컴파일·실행이 깨지지 않아야 하고
## (Progression에 class_name이 없어 정적 타입 검사를 우회하려면 `call()`이 필요하다),
## 실제 반영은 `Events.stats_changed`/`skills_changed` 신호로만 받는다(로직은 소비만
## 한다는 원칙 — 낙관적 로컬 갱신을 하지 않는다).
class_name SkillPanelTab
extends Control

const SUB_TABS := ["stat", "skill"]
const SUB_TAB_LABEL_KEYS := {
	"stat": &"ui.skill_panel.tab.stat",
	"skill": &"ui.skill_panel.tab.skill",
}
const STAT_NAME_KEYS := {
	"str": &"ui.stat.str", "dex": &"ui.stat.dex", "int": &"ui.stat.int",
	"vit": &"ui.stat.vit", "luk": &"ui.stat.luk",
}
const DERIVED_LABEL_KEYS := {
	"attack": &"ui.stat.derived.attack", "max_hp": &"ui.stat.derived.max_hp",
	"defense": &"ui.stat.derived.defense", "crit_chance": &"ui.stat.derived.crit_chance",
}
var _sub_tab_bar: HBoxContainer
var _sub_tab_buttons: Dictionary = {} # sub_tab_id -> Button

var _points_header: Label
var _stat_rows: Array = [] # Array[Dictionary]{name, value, plus_button, preview}
var _derived_footer: Label
var _stat_focus_index: int = 0

var _skill_list_box: VBoxContainer
var _skill_labels: Array = [] # Array[Label]
var _skill_ids: Array[String] = []
var _skill_focus_index: int = 0
var _skill_detail_title: Label
var _skill_detail_desc: Label
var _skill_detail_meta: Label
var _skill_detail_hint: Label
var _hotbar_bar: HudHotbarBar # M4-2(D-181~183): 핫바 등록 미리보기.

var _sub_tab_index: int = 0
var _stats: Dictionary = {}
var _derived: Dictionary = {}
var _stat_points: int = 0
var _learned: Array = []
var _slots: Array = ["", ""]
var _skill_points: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	_sub_tab_bar = HBoxContainer.new()
	_sub_tab_bar.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_sub_tab_bar)
	for sub_tab_id: String in SUB_TABS:
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		_sub_tab_bar.add_child(button)
		_sub_tab_buttons[sub_tab_id] = button

	_build_stat_body(root_vbox)
	_build_skill_body(root_vbox)

	_apply_theme_colors()


func _build_stat_body(parent: VBoxContainer) -> void:
	var stat_body := VBoxContainer.new()
	stat_body.name = "StatBody"
	stat_body.add_theme_constant_override("separation", 4)
	parent.add_child(stat_body)

	_points_header = Label.new()
	stat_body.add_child(_points_header)

	for stat_key: String in StatsUiCalc.STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stat_body.add_child(row)
		var name_label := Label.new()
		name_label.custom_minimum_size.x = 40
		row.add_child(name_label)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 30
		row.add_child(value_label)
		var plus_button := Button.new()
		plus_button.flat = true
		plus_button.focus_mode = Control.FOCUS_NONE
		plus_button.text = "+"
		plus_button.pressed.connect(_on_stat_plus_pressed.bind(stat_key))
		row.add_child(plus_button)
		var preview_label := Label.new()
		row.add_child(preview_label)
		_stat_rows.append({"key": stat_key, "row": row, "name": name_label, "value": value_label, "preview": preview_label})

	_derived_footer = Label.new()
	_derived_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_body.add_child(_derived_footer)


func _build_skill_body(parent: VBoxContainer) -> void:
	var skill_body := HBoxContainer.new()
	skill_body.name = "SkillBody"
	skill_body.add_theme_constant_override("separation", 12)
	skill_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(skill_body)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(200, 0)
	skill_body.add_child(list_scroll)
	_skill_list_box = VBoxContainer.new()
	_skill_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_skill_list_box)

	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_body.add_child(detail_box)
	_skill_detail_title = Label.new()
	detail_box.add_child(_skill_detail_title)
	_skill_detail_desc = Label.new()
	_skill_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_skill_detail_desc)
	_skill_detail_meta = Label.new()
	detail_box.add_child(_skill_detail_meta)
	_skill_detail_hint = Label.new()
	_skill_detail_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_skill_detail_hint)
	_hotbar_bar = HudHotbarBar.new()
	detail_box.add_child(_hotbar_bar)


func _apply_theme_colors() -> void:
	if theme == null:
		return
	for sub_tab_id: String in SUB_TABS:
		(_sub_tab_buttons[sub_tab_id] as Button).add_theme_color_override(
			"font_color", theme.get_color(&"tab_inactive", &"Inventory"))


## InventoryMenu._apply_tab_visibility()가 "skill" 탭으로 전환될 때마다 호출한다
## (quest_log_tab.gd와 동일 관례 — 열려 있는 동안 놓친 변화가 있을 수 있어 매번 전체
## 새로고침).
func open() -> void:
	if not Events.stats_changed.is_connected(_on_stats_changed):
		Events.stats_changed.connect(_on_stats_changed)
		Events.skills_changed.connect(_on_skills_changed)
	_hotbar_bar.theme = theme # 부모(InventoryMenu)가 _ready()에서 뒤늦게 theme을 대입하므로
	# _build_skill_body() 시점엔 아직 null이다 — open()은 그보다 항상 나중이라 안전하다.
	_load_initial_state()
	# "_comment" 등 메타 키(다른 테이블과 동일 관례, stats.json도 동일)는 스킬이 아니다.
	_skill_ids.assign(Data.table("skills").keys().filter(func(id): return not String(id).begins_with("_")))
	_sub_tab_index = 0
	_stat_focus_index = 0
	_skill_focus_index = 0
	_refresh_sub_tab_bar()
	_refresh_stat_body()
	_rebuild_skill_list()
	_refresh_skill_detail()


func close() -> void:
	if Events.stats_changed.is_connected(_on_stats_changed):
		Events.stats_changed.disconnect(_on_stats_changed)
		Events.skills_changed.disconnect(_on_skills_changed)


## GameState.stats/learned_skills/skill_slots는 stage/m3-3(로직) 병합 전엔 아직 없을 수
## 있다 — Object.get()은 존재하지 않는 프로퍼티에도 에러 없이 null을 준다(has_method
## 가드와 같은 이유로 직접 `GameState.stats`처럼 정적 접근하지 않는다).
func _load_initial_state() -> void:
	var stats_variant: Variant = GameState.get("stats")
	_stats = stats_variant if typeof(stats_variant) == TYPE_DICTIONARY and not (stats_variant as Dictionary).is_empty() \
		else StatsUiCalc.default_stats(Data.table("stats"))
	_stat_points = GameState.stat_points
	_skill_points = GameState.skill_points
	var learned_variant: Variant = GameState.get("learned_skills")
	_learned = learned_variant if typeof(learned_variant) == TYPE_ARRAY else []
	var slots_variant: Variant = GameState.get("skill_slots")
	_slots = slots_variant if typeof(slots_variant) == TYPE_ARRAY and (slots_variant as Array).size() >= 2 else ["", ""]
	_derived = {} # 신호 수신 전까지 "-"로 표시(docs/ui/hud.md 3.5절과 동일 선례).


func _on_stats_changed(stats: Dictionary, derived: Dictionary, stat_points: int) -> void:
	_stats = stats
	_derived = derived
	_stat_points = stat_points
	if visible:
		_refresh_stat_body()


func _on_skills_changed(learned: Array, slots: Array, skill_points: int) -> void:
	_learned = learned
	_slots = slots
	_skill_points = skill_points
	if visible:
		_refresh_skill_list_states()
		_refresh_skill_detail()


# --- 입력(InventoryMenu._process가 "skill" 탭일 때만 위임 호출) ---

func handle_input(_delta: float) -> void:
	if Input.is_action_just_pressed(&"move_left"):
		_change_sub_tab(-1)
	elif Input.is_action_just_pressed(&"move_right"):
		_change_sub_tab(1)
	elif Input.is_action_just_pressed(&"move_up"):
		_move_focus(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		_move_focus(1)
	elif Input.is_action_just_pressed(&"ui_confirm"):
		_confirm()
	elif SUB_TABS[_sub_tab_index] == "skill" and not _skill_ids.is_empty() and _learned.has(_skill_ids[_skill_focus_index]):
		if HotbarRegisterInput.try_assign("skill", _skill_ids[_skill_focus_index]):
			_hotbar_bar.highlight_slot("skill", _skill_ids[_skill_focus_index])


func _change_sub_tab(delta: int) -> void:
	_sub_tab_index = wrapi(_sub_tab_index + delta, 0, SUB_TABS.size())
	_refresh_sub_tab_bar()


func _move_focus(delta: int) -> void:
	if SUB_TABS[_sub_tab_index] == "stat":
		_stat_focus_index = wrapi(_stat_focus_index + delta, 0, _stat_rows.size())
		_refresh_stat_body()
	elif not _skill_ids.is_empty():
		_skill_focus_index = wrapi(_skill_focus_index + delta, 0, _skill_ids.size())
		_refresh_skill_list_states()
		_refresh_skill_detail()


func _confirm() -> void:
	if SUB_TABS[_sub_tab_index] == "stat":
		_on_stat_plus_pressed(StatsUiCalc.STAT_KEYS[_stat_focus_index])
	else:
		_learn_focused_skill()


func _on_stat_plus_pressed(stat_key: String) -> void:
	_stat_focus_index = StatsUiCalc.STAT_KEYS.find(stat_key)
	_refresh_stat_body()
	Progression.allocate_stat(stat_key)


func _learn_focused_skill() -> void:
	if _skill_ids.is_empty():
		return
	var id: String = _skill_ids[_skill_focus_index]
	if _skill_state(id) != "learnable":
		return
	Progression.learn_skill(id)


# --- 표시 갱신: 스탯 ---

func _refresh_sub_tab_bar() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory") if theme != null else Color.WHITE
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory") if theme != null else Color.GRAY
	for i in SUB_TABS.size():
		var button: Button = _sub_tab_buttons[SUB_TABS[i]]
		button.text = tr(SUB_TAB_LABEL_KEYS[SUB_TABS[i]])
		button.add_theme_color_override("font_color", active_color if i == _sub_tab_index else inactive_color)
	_stat_rows_visible(SUB_TABS[_sub_tab_index] == "stat")


func _stat_rows_visible(is_stat: bool) -> void:
	(_points_header.get_parent() as Control).visible = is_stat
	((_skill_list_box.get_parent().get_parent()) as Control).visible = not is_stat


func _refresh_stat_body() -> void:
	_points_header.text = tr(&"ui.stat.points_remaining") % _stat_points
	var focus_color: Color = theme.get_color(&"focus", &"Inventory") if theme != null else Color.YELLOW
	var default_color: Color = theme.get_color(&"neutral", &"Inventory") if theme != null else Color.WHITE
	var colorblind: bool = Settings.colorblind_mode
	var stats_table: Dictionary = Data.table("stats")
	for i in _stat_rows.size():
		var entry: Dictionary = _stat_rows[i]
		var stat_key: String = entry["key"]
		var row_color: Color = focus_color if i == _stat_focus_index else default_color
		(entry["name"] as Label).text = tr(STAT_NAME_KEYS[stat_key])
		(entry["name"] as Label).add_theme_color_override("font_color", row_color)
		(entry["value"] as Label).text = str(int(_stats.get(stat_key, 0)))
		(entry["value"] as Label).add_theme_color_override("font_color", row_color)
		(entry["preview"] as Label).text = _format_preview(stat_key, stats_table, colorblind)
	_derived_footer.text = _format_derived_footer()


func _format_preview(stat_key: String, stats_table: Dictionary, colorblind: bool) -> String:
	var delta: Dictionary = StatsUiCalc.preview_derived_delta(stat_key, stats_table)
	if delta.is_empty():
		return ""
	var parts := PackedStringArray()
	for derived_key: String in delta.keys():
		var fmt: Dictionary = InventoryUiCalc.format_delta(float(delta[derived_key]), colorblind, 1)
		parts.append("%s %s" % [tr(DERIVED_LABEL_KEYS.get(derived_key, StringName(derived_key))), fmt["text"]])
	return " ".join(parts)


func _format_derived_footer() -> String:
	if _derived.is_empty():
		return tr(&"ui.stat.derived.pending")
	var parts := PackedStringArray()
	for derived_key: String in DERIVED_LABEL_KEYS.keys():
		if _derived.has(derived_key):
			parts.append("%s %s" % [tr(DERIVED_LABEL_KEYS[derived_key]), str(_derived[derived_key])])
	return " / ".join(parts)


# --- 표시 갱신: 스킬 ---

func _rebuild_skill_list() -> void:
	for child in _skill_list_box.get_children():
		child.queue_free()
	_skill_labels.clear()
	for id: String in _skill_ids:
		var label := Label.new()
		_skill_list_box.add_child(label)
		_skill_labels.append(label)
	_refresh_skill_list_states()


func _refresh_skill_list_states() -> void:
	var focus_color: Color = theme.get_color(&"focus", &"Inventory") if theme != null else Color.YELLOW
	var default_color: Color = theme.get_color(&"neutral", &"Inventory") if theme != null else Color.WHITE
	var disabled_color: Color = theme.get_color(&"disabled", &"Inventory") if theme != null else Color.GRAY
	for i in _skill_ids.size():
		var id: String = _skill_ids[i]
		var def: Dictionary = Data.get_value("skills", id, {})
		var state: String = _skill_state(id)
		var mark: String = {"learned": tr(&"ui.skill.state.learned"), "learnable": tr(&"ui.skill.state.learnable")}.get(state, "")
		var label: Label = _skill_labels[i]
		label.text = "%s %s" % [tr(StringName(String(def.get("name_key", id)))), mark]
		var color := default_color
		if i == _skill_focus_index: color = focus_color
		elif state == "locked": color = disabled_color
		label.add_theme_color_override("font_color", color)


func _refresh_skill_detail() -> void:
	if _skill_ids.is_empty():
		_skill_detail_title.text = tr(&"ui.quest_log.empty")
		_skill_detail_desc.text = ""
		_skill_detail_meta.text = ""
		_skill_detail_hint.text = ""
		_hotbar_bar.highlight_slot("skill", "")
		return
	var id: String = _skill_ids[_skill_focus_index]
	_hotbar_bar.highlight_slot("skill", id if _learned.has(id) else "")
	var def: Dictionary = Data.get_value("skills", id, {})
	_skill_detail_title.text = tr(StringName(String(def.get("name_key", id))))
	_skill_detail_desc.text = tr(StringName(String(def.get("desc_key", ""))))
	var requires: Array = def.get("requires", [])
	var requires_text: String = tr(&"ui.skill.requires_none")
	if not requires.is_empty():
		var requires_names := PackedStringArray()
		for req: Variant in requires:
			requires_names.append(tr(StringName(String(Data.get_value("skills", "%s.name_key" % String(req), req)))))
		requires_text = ", ".join(requires_names)
	_skill_detail_meta.text = tr(&"ui.skill.meta_fmt") % [String(def.get("series", "")), int(def.get("cost_sp", 0)), requires_text]
	match _skill_state(id):
		"learned":
			_skill_detail_hint.text = tr(&"ui.skill.slot_hint")
		"learnable":
			_skill_detail_hint.text = tr(&"ui.skill.learn_hint")
		_:
			_skill_detail_hint.text = tr(&"ui.skill.locked_hint")


## learned: 습득함. learnable: 필요 SP 충족 + requires 전부 습득. locked: 그 외.
func _skill_state(id: String) -> String:
	if _learned.has(id):
		return "learned"
	var def: Dictionary = Data.get_value("skills", id, {})
	var cost_sp: int = int(def.get("cost_sp", 0))
	if _skill_points < cost_sp:
		return "locked"
	for req: Variant in (def.get("requires", []) as Array):
		if not _learned.has(String(req)):
			return "locked"
	return "learnable"
