## 스탯 분배 · 스킬 트리 패널(M4-5 v2, ro-benchmark-progression-v1.md §1~2). InventoryMenu의
## 기존 "skill" 탭 자리를 실제로 구현한다(quest_log_tab.gd와 동일 분리 원칙).
##
## 게임패드 우선(docs/ui/skill-panel.md §3): 좌/우로 스탯·스킬 서브탭 전환, 상/하로
## 행/목록 이동, 확인으로 배분/습득. "skill" 서브탭 안쪽 로직(계열 전환·트리 배치·
## 잠금 판정)은 전부 `skill_tree_tab.gd`로 옮겼다(이 파일 500줄 상한 유지, D-145).
##
## `Progression.allocate_stat/next_stat_cost`(next_stat_cost는 stage/m4-4, 아직 미병합)는
## `has_method` 가드로 호출한다 — 미병합 상태에서도 컴파일·실행이 깨지지 않아야 하고,
## 실제 반영은 `Events.stats_changed` 신호로만 받는다(로직은 소비만 한다는 원칙).
class_name SkillPanelTab
extends Control

const SUB_TABS := ["stat", "skill"]
const SUB_TAB_LABEL_KEYS := {
	"stat": &"ui.skill_panel.tab.stat",
	"skill": &"ui.skill_panel.tab.skill",
}
const STAT_NAME_KEYS := {
	"str": &"ui.stat.str", "agi": &"ui.stat.agi", "dex": &"ui.stat.dex",
	"int": &"ui.stat.int", "vit": &"ui.stat.vit", "luk": &"ui.stat.luk",
}
## D-195: "DEX/INT/AGI가 눈에 보이는 효과여야 한다" — 4개 선형 스탯(str/vit/int/luk)의
## 수치 미리보기 화살표와 별개로, 6스탯 전부 항상 이 한 줄 설명을 보여준다.
const STAT_EFFECT_KEYS := {
	"str": &"ui.stat.effect.str", "agi": &"ui.stat.effect.agi", "dex": &"ui.stat.effect.dex",
	"int": &"ui.stat.effect.int", "vit": &"ui.stat.effect.vit", "luk": &"ui.stat.effect.luk",
}
## Progression.get_derived() 11+2키(D-195 확정) 표시 순서·라벨. 값이 없으면(병합 전)
## 행 자체를 숨긴다(derived.has(key) 가드).
const DERIVED_LABEL_KEYS := {
	"atk": &"ui.stat.derived.attack", "matk": &"ui.stat.derived.matk",
	"max_hp": &"ui.stat.derived.max_hp", "max_sp": &"ui.stat.derived.max_sp",
	"def": &"ui.stat.derived.defense", "mdef": &"ui.stat.derived.mdef",
	"crit_chance": &"ui.stat.derived.crit_chance",
	"hit_scale": &"ui.stat.derived.hit_scale", "flee_iframe_bonus": &"ui.stat.derived.flee_iframe_bonus",
	"move_speed_mult": &"ui.stat.derived.move_speed_mult", "combo_frame_mult": &"ui.stat.derived.combo_frame_mult",
	"post_recovery_mult": &"ui.stat.derived.post_recovery_mult", "sp_regen": &"ui.stat.derived.sp_regen",
}

var _sub_tab_bar: HBoxContainer
var _sub_tab_buttons: Dictionary = {} # sub_tab_id -> Button

var _points_header: Label
var _stat_rows: Array = [] # Array[Dictionary]{key, row, name, value, preview}
var _derived_footer: Label
var _stat_focus_index: int = 0

var _skill_tree_tab: SkillTreeTab

var _sub_tab_index: int = 0
var _stats: Dictionary = {}
var _derived: Dictionary = {}
var _stat_points: int = 0


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

	_skill_tree_tab = SkillTreeTab.new()
	_skill_tree_tab.name = "SkillBody"
	_skill_tree_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_skill_tree_tab)

	_apply_theme_colors()


func _build_stat_body(parent: VBoxContainer) -> void:
	var stat_body := VBoxContainer.new()
	stat_body.name = "StatBody"
	stat_body.add_theme_constant_override("separation", 2)
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
		value_label.custom_minimum_size.x = 26
		row.add_child(value_label)
		var plus_button := Button.new()
		plus_button.flat = true
		plus_button.focus_mode = Control.FOCUS_NONE
		plus_button.text = "+"
		plus_button.pressed.connect(_on_stat_plus_pressed.bind(stat_key))
		row.add_child(plus_button)
		var preview_label := Label.new()
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(preview_label)
		_stat_rows.append({"key": stat_key, "row": row, "name": name_label, "value": value_label, "preview": preview_label})

	_derived_footer = Label.new()
	_derived_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_body.add_child(_derived_footer)


func _apply_theme_colors() -> void:
	if theme == null:
		return
	for sub_tab_id: String in SUB_TABS:
		(_sub_tab_buttons[sub_tab_id] as Button).add_theme_color_override(
			"font_color", theme.get_color(&"tab_inactive", &"Inventory"))


## InventoryMenu._apply_tab_visibility()가 "skill" 탭으로 전환될 때마다 호출한다.
func open() -> void:
	if not Events.stats_changed.is_connected(_on_stats_changed):
		Events.stats_changed.connect(_on_stats_changed)
	_skill_tree_tab.theme = theme # 부모가 _ready()에서 뒤늦게 theme을 대입하므로 그보다 나중.
	_load_initial_state()
	_sub_tab_index = 0
	_stat_focus_index = 0
	_refresh_sub_tab_bar()
	_refresh_stat_body()
	_skill_tree_tab.open()


func close() -> void:
	if Events.stats_changed.is_connected(_on_stats_changed):
		Events.stats_changed.disconnect(_on_stats_changed)
	_skill_tree_tab.close()


## GameState.stats는 stage/m4-4(로직) 병합 전엔 5키(구 스키마)이거나 없을 수 있다 —
## Object.get()은 존재하지 않는 프로퍼티에도 에러 없이 null을 준다.
func _load_initial_state() -> void:
	var stats_variant: Variant = GameState.get("stats")
	_stats = stats_variant if typeof(stats_variant) == TYPE_DICTIONARY and not (stats_variant as Dictionary).is_empty() \
		else StatsUiCalc.default_stats(Data.table("stats"))
	_stat_points = GameState.stat_points
	_derived = {} # 신호 수신 전까지 행 자체를 숨긴다(docs/ui/hud.md 3.5절과 동일 선례).


func _on_stats_changed(stats: Dictionary, derived: Dictionary, stat_points: int) -> void:
	_stats = stats
	_derived = derived
	_stat_points = stat_points
	if visible:
		_refresh_stat_body()


# --- 입력(InventoryMenu._process가 "skill" 탭일 때만 위임 호출) ---

func handle_input(delta: float) -> void:
	if Input.is_action_just_pressed(&"move_left"):
		_change_sub_tab(-1)
	elif Input.is_action_just_pressed(&"move_right"):
		_change_sub_tab(1)
	elif SUB_TABS[_sub_tab_index] == "skill":
		_skill_tree_tab.handle_input(delta)
	elif Input.is_action_just_pressed(&"move_up"):
		_move_focus(-1)
	elif Input.is_action_just_pressed(&"move_down"):
		_move_focus(1)
	elif Input.is_action_just_pressed(&"ui_confirm"):
		_confirm()


func _change_sub_tab(delta: int) -> void:
	_sub_tab_index = wrapi(_sub_tab_index + delta, 0, SUB_TABS.size())
	_refresh_sub_tab_bar()


func _move_focus(delta: int) -> void:
	_stat_focus_index = wrapi(_stat_focus_index + delta, 0, _stat_rows.size())
	_refresh_stat_body()


func _confirm() -> void:
	_on_stat_plus_pressed(StatsUiCalc.STAT_KEYS[_stat_focus_index])


func _on_stat_plus_pressed(stat_key: String) -> void:
	_stat_focus_index = StatsUiCalc.STAT_KEYS.find(stat_key)
	_refresh_stat_body()
	Progression.allocate_stat(stat_key)


# --- 표시 갱신: 서브탭 ---

func _refresh_sub_tab_bar() -> void:
	var active_color: Color = theme.get_color(&"tab_active", &"Inventory") if theme != null else Color.WHITE
	var inactive_color: Color = theme.get_color(&"tab_inactive", &"Inventory") if theme != null else Color.GRAY
	for i in SUB_TABS.size():
		var button: Button = _sub_tab_buttons[SUB_TABS[i]]
		button.text = tr(SUB_TAB_LABEL_KEYS[SUB_TABS[i]])
		button.add_theme_color_override("font_color", active_color if i == _sub_tab_index else inactive_color)
	(_points_header.get_parent() as Control).visible = SUB_TABS[_sub_tab_index] == "stat"
	_skill_tree_tab.visible = SUB_TABS[_sub_tab_index] == "skill"


# --- 표시 갱신: 스탯 ---

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
		(entry["preview"] as Label).text = _format_preview_line(stat_key, stats_table, colorblind)
	_derived_footer.text = _format_derived_footer()


func _next_cost(stat_key: String) -> int:
	if Progression.has_method(&"next_stat_cost"):
		return int(Progression.next_stat_cost(stat_key))
	return StatsUiCalc.next_point_cost(int(_stats.get(stat_key, 0)))


## 파생치별 미리보기 소수 자릿수·%표시 여부(값 자체가 작은 sp_regen/crit_chance가
## "▲0.0"으로 뭉개지지 않게). max_hp/max_sp는 정수 스탯이라 소수점이 필요 없다.
const _PREVIEW_DECIMALS := {"max_hp": 0, "max_sp": 0, "sp_regen": 2, "crit_chance": 1}
const _PREVIEW_PERCENT_KEYS := ["crit_chance"]


func _format_preview_line(stat_key: String, stats_table: Dictionary, colorblind: bool) -> String:
	var cost_text: String = tr(&"ui.stat.point_cost_fmt") % _next_cost(stat_key)
	var effect_text: String = tr(STAT_EFFECT_KEYS.get(stat_key, &""))
	var delta: Dictionary = StatsUiCalc.preview_derived_delta(stat_key, stats_table)
	if delta.is_empty():
		return "%s · %s" % [cost_text, effect_text]
	var parts := PackedStringArray()
	for derived_key: String in delta.keys():
		var is_percent: bool = derived_key in _PREVIEW_PERCENT_KEYS
		var value: float = float(delta[derived_key]) * (100.0 if is_percent else 1.0)
		var decimals: int = int(_PREVIEW_DECIMALS.get(derived_key, 1))
		var fmt: Dictionary = InventoryUiCalc.format_delta(value, colorblind, decimals)
		parts.append("%s %s%s" % [tr(DERIVED_LABEL_KEYS.get(derived_key, StringName(derived_key))), fmt["text"], "%" if is_percent else ""])
	return "%s · %s · %s" % [cost_text, effect_text, " ".join(parts)]


func _format_derived_footer() -> String:
	if _derived.is_empty():
		return tr(&"ui.stat.derived.pending")
	var parts := PackedStringArray()
	for derived_key: String in DERIVED_LABEL_KEYS.keys():
		if _derived.has(derived_key):
			parts.append("%s %s" % [tr(DERIVED_LABEL_KEYS[derived_key]), StatsUiCalc.format_derived_value(derived_key, float(_derived[derived_key]))])
	return " / ".join(parts)
