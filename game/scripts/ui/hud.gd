## 인게임 HUD 정식 구현(F7-1, M1-5). DebugHud(scenes/ui/DebugHud.tscn)를 대체한다 —
## DebugHud의 HP/스태미나/콤보/상태/사망수 텍스트는 F3로 여닫는 디버그 패널로 흡수했다.
##
## 담당: 좌상단 HP·스태미나 바 + 버프 아이콘 자리, 하단 퀵슬롯(십자키 배치, D-47) +
## 스킬슬롯, 우상단 미니맵 토글, 좌하단 획득 로그, 상단 추적 퀘스트 한 줄, 보스 HP바.
## HP 25% 이하 점멸+비네트(색약 모드는 패턴 대체), 스태미나 고갈 점멸(F2-3).
##
## 색·나인패치 스타일은 game/ui/theme.tres 한 곳에서만 정의하고(README 규칙), 이
## 스크립트는 런타임에 theme.get_color()/get_stylebox()로 읽어와 각 노드에 적용만 한다.
class_name Hud
extends Control

const LOG_MAX_LINES := 4
const LOG_DURATION_SEC := 3.0
const HP_BLINK_INTERVAL_SEC := 0.25
const STAMINA_BLINK_INTERVAL_SEC := 0.2
const STAMINA_FLASH_CYCLE_SEC := 0.08

@export var player_path: NodePath

@onready var level_label: Label = $TopLeft/LevelLabel
@onready var hp_bar: ProgressBar = $TopLeft/HPBar
@onready var hp_text: Label = $TopLeft/HPText
@onready var stamina_bar: ProgressBar = $TopLeft/StaminaBar

@onready var quest_line_label: Label = $TopCenter/QuestLine

@onready var minimap_container: Control = $TopRight
@onready var minimap_frame: Panel = $TopRight/MinimapFrame

@onready var boss_bar_container: Control = $BossBar
@onready var boss_frame: Panel = $BossBar/BossFrame
@onready var boss_name_label: Label = $BossBar/BossFrame/BossVBox/BossName
@onready var boss_hp_bar: ProgressBar = $BossBar/BossFrame/BossVBox/BossHPBar
@onready var boss_phase_label: Label = $BossBar/BossFrame/BossVBox/BossPhase

@onready var skill_slot_1: Panel = $BottomCenter/SkillSlot1
@onready var skill_slot_2: Panel = $BottomCenter/SkillSlot2
@onready var slot_up: Panel = $BottomCenter/QuickCross/SlotUp
@onready var slot_right: Panel = $BottomCenter/QuickCross/SlotRight
@onready var slot_down: Panel = $BottomCenter/QuickCross/SlotDown
@onready var slot_left: Panel = $BottomCenter/QuickCross/SlotLeft

@onready var log_list: VBoxContainer = $BottomLeft/LogList

@onready var vignette: VignetteOverlay = $VignetteOverlay

@onready var debug_panel: Control = $DebugPanel
@onready var debug_bg: Panel = $DebugPanel/DebugBg
@onready var debug_hp_label: Label = $DebugPanel/DebugVBox/HPLabel
@onready var debug_stamina_label: Label = $DebugPanel/DebugVBox/StaminaLabel
@onready var debug_combo_label: Label = $DebugPanel/DebugVBox/ComboLabel
@onready var debug_status_label: Label = $DebugPanel/DebugVBox/StatusLabel
@onready var debug_death_label: Label = $DebugPanel/DebugVBox/DeathLabel

var _player: Player

var _hp_current: int = 0
var _hp_max: int = 1
var _stamina_current: float = 0.0
var _stamina_max: float = 1.0

var _hp_blinking: bool = false
var _stamina_blinking: bool = false
var _hp_blink_tween: Tween
var _stamina_blink_tween: Tween

## 스모크 테스트(F7-1 태스크 6)가 확인할 수 있도록 스태미나 부족 플래시 진행 여부를 공개.
var stamina_flash_active: bool = false

var _hp_bg_style: StyleBoxFlat
var _hp_fill_style: StyleBoxFlat
var _hp_warning_style: StyleBoxFlat
var _stamina_bg_style: StyleBoxFlat
var _stamina_fill_style: StyleBoxFlat
var _stamina_empty_style: StyleBoxFlat
var _boss_fill_style: StyleBoxFlat


func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node(player_path) as Player

	_apply_theme_frames()
	_build_bar_styles()
	_apply_font_size()

	level_label.text = tr(&"ui.hud.level_prefix") + " 1"
	quest_line_label.text = ""
	hp_text.text = "-- / --"
	boss_bar_container.visible = false
	debug_panel.visible = false

	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_stamina_changed.connect(_on_stamina_changed)
	Events.player_stamina_insufficient.connect(_on_stamina_insufficient)
	Events.player_died.connect(_on_player_died)
	Events.item_picked_up.connect(_on_item_picked_up)
	Events.gold_changed.connect(_on_gold_changed)
	# 지시문은 Events.boss_encounter_started를 언급하지만 core/events.gd에는 그 이름이
	# 없다 — 이미 있는 동등 시그널 boss_started/boss_defeated(boss_id)를 재사용한다
	# (docs/ui/hud.md §4 참고, 신규 시그널 중복 추가 방지).
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.settings_changed.connect(_on_settings_changed)

	# Player._ready()가 Hud보다 먼저(트리 순서상) 초기 시그널을 이미 쏜 뒤일 수 있어
	# (DebugHud와 같은 한계), 현재 값을 한 번 직접 끌어와 초기 표시를 맞춘다.
	if _player != null and _player.resources != null:
		_on_hp_changed(_player.resources.hp, _player.resources.max_hp)
		_on_stamina_changed(_player.resources.stamina, _player.resources.max_stamina)


func _process(_delta: float) -> void:
	_update_hp_blink()
	_update_stamina_blink()
	if debug_panel.visible:
		_update_debug_text()

	if Input.is_action_just_pressed(&"map"):
		minimap_container.visible = not minimap_container.visible
	if Input.is_action_just_pressed(&"debug_toggle"):
		debug_panel.visible = not debug_panel.visible
	# F4: 인벤토리 텍스트 덤프(M2-1). 정식 인벤토리 UI는 M2-2 — 지금은 콘솔 출력만.
	if Input.is_action_just_pressed(&"debug_inventory_dump"):
		GameState.dump_inventory_debug()


# --- 테마 적용 ---

func _apply_theme_frames() -> void:
	var wood: StyleBox = theme.get_stylebox(&"wood_frame", &"HUD")
	var cell: StyleBox = theme.get_stylebox(&"slot_cell", &"HUD")
	var parchment: StyleBox = theme.get_stylebox(&"parchment_fill", &"HUD")
	minimap_frame.add_theme_stylebox_override("panel", wood)
	boss_frame.add_theme_stylebox_override("panel", wood)
	debug_bg.add_theme_stylebox_override("panel", parchment)
	for slot: Panel in [skill_slot_1, skill_slot_2, slot_up, slot_right, slot_down, slot_left]:
		slot.add_theme_stylebox_override("panel", cell)


func _build_bar_styles() -> void:
	_hp_bg_style = _flat(theme.get_color(&"hp_bg", &"HUD"))
	_hp_fill_style = _flat(theme.get_color(&"hp_fill", &"HUD"))
	_hp_warning_style = _flat(theme.get_color(&"hp_warning", &"HUD"))
	_stamina_bg_style = _flat(theme.get_color(&"stamina_bg", &"HUD"))
	_stamina_fill_style = _flat(theme.get_color(&"stamina_fill", &"HUD"))
	_stamina_empty_style = _flat(theme.get_color(&"stamina_empty", &"HUD"))
	_boss_fill_style = _flat(theme.get_color(&"boss_fill", &"HUD"))

	hp_bar.add_theme_stylebox_override("background", _hp_bg_style)
	hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)
	stamina_bar.add_theme_stylebox_override("background", _stamina_bg_style)
	stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style)
	boss_hp_bar.add_theme_stylebox_override("background", _hp_bg_style)
	boss_hp_bar.add_theme_stylebox_override("fill", _boss_fill_style)

	vignette.configure(theme.get_color(&"vignette", &"HUD"))


static func _flat(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb


func _apply_font_size() -> void:
	var key: StringName = &"large" if Settings.font_size_large else &"default"
	var font_size: int = theme.get_font_size(key, &"HUD")
	add_theme_font_size_override("font_size", font_size)


# --- HP / 스태미나 ---

func _on_hp_changed(current: int, max_value: int) -> void:
	_hp_current = current
	_hp_max = max_value
	hp_bar.max_value = max_value
	hp_bar.value = current
	hp_text.text = "%d / %d" % [current, max_value]
	debug_hp_label.text = "HP: %d / %d" % [current, max_value]


func _on_stamina_changed(current: float, max_value: float) -> void:
	_stamina_current = current
	_stamina_max = max_value
	stamina_bar.max_value = max_value
	stamina_bar.value = current
	debug_stamina_label.text = "STAMINA: %d / %d" % [int(round(current)), int(round(max_value))]


func _update_hp_blink() -> void:
	var critical: bool = HudMath.is_hp_critical(_hp_current, _hp_max)
	vignette.set_state(critical, Settings.colorblind_mode)
	if critical and not _hp_blinking:
		_hp_blinking = true
		_start_hp_blink_tween()
	elif not critical and _hp_blinking:
		_hp_blinking = false
		_kill_tween(_hp_blink_tween)
		hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)


func _start_hp_blink_tween() -> void:
	_kill_tween(_hp_blink_tween)
	_hp_blink_tween = create_tween()
	_hp_blink_tween.set_loops()
	_hp_blink_tween.tween_callback(func() -> void: hp_bar.add_theme_stylebox_override("fill", _hp_warning_style))
	_hp_blink_tween.tween_interval(HP_BLINK_INTERVAL_SEC)
	_hp_blink_tween.tween_callback(func() -> void: hp_bar.add_theme_stylebox_override("fill", _hp_fill_style))
	_hp_blink_tween.tween_interval(HP_BLINK_INTERVAL_SEC)


func _update_stamina_blink() -> void:
	var empty: bool = HudMath.is_stamina_empty(_stamina_current)
	if empty and not _stamina_blinking:
		_stamina_blinking = true
		_start_stamina_blink_tween()
	elif not empty and _stamina_blinking:
		_stamina_blinking = false
		_kill_tween(_stamina_blink_tween)
		stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style)


func _start_stamina_blink_tween() -> void:
	_kill_tween(_stamina_blink_tween)
	_stamina_blink_tween = create_tween()
	_stamina_blink_tween.set_loops()
	_stamina_blink_tween.tween_callback(func() -> void: stamina_bar.add_theme_stylebox_override("fill", _stamina_empty_style))
	_stamina_blink_tween.tween_interval(STAMINA_BLINK_INTERVAL_SEC)
	_stamina_blink_tween.tween_callback(func() -> void: stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style))
	_stamina_blink_tween.tween_interval(STAMINA_BLINK_INTERVAL_SEC)


## S2-1b/S2-1c 예외: 스태미나 부족으로 구르기 등이 미발동됐을 때 바를 급속 점멸(3회)한다.
## "고갈 시 지속 점멸"(_update_stamina_blink)과는 별개의 짧은 피드백.
func _on_stamina_insufficient(_action: StringName) -> void:
	stamina_flash_active = true
	var tween := create_tween()
	for i in 3:
		tween.tween_callback(func() -> void: stamina_bar.add_theme_stylebox_override("fill", _stamina_empty_style))
		tween.tween_interval(STAMINA_FLASH_CYCLE_SEC)
		tween.tween_callback(func() -> void: stamina_bar.add_theme_stylebox_override("fill", _stamina_fill_style))
		tween.tween_interval(STAMINA_FLASH_CYCLE_SEC)
	tween.tween_callback(func() -> void: stamina_flash_active = false)


func _kill_tween(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()


# --- 획득 로그 (좌하단, 3초, 최대 4줄) ---

## M2-1: 아이템명은 아직 로컬라이징 CSV가 없어(README "텍스트 규칙" 참고) name_key
## 문자열 자체를 그대로 보여준다(M2-2에서 tr(name_key)로 교체 예정) — 대신 등급 색은
## game/ui/theme.tres 단일 소스(Rarity)를 바로 붙인다.
func _on_item_picked_up(item_id: StringName, quantity: int) -> void:
	var item_def: Dictionary = Data.get_value("items", String(item_id), {})
	var name_key: String = String(item_def.get("name_key", item_id))
	var grade: String = String(item_def.get("grade", "common"))
	var color: Color = Rarity.color_of(Rarity.from_string(grade), theme)
	_push_log_line("%s x%d" % [name_key, quantity], color)


func _on_gold_changed(_new_amount: int, delta: int) -> void:
	if delta > 0:
		_push_log_line("+%d %s" % [delta, tr(&"ui.hud.gold_unit")])


func _push_log_line(text: String, color: Variant = null) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color if color is Color else theme.get_color(&"text_default", &"HUD"))
	log_list.add_child(label)
	while log_list.get_child_count() > LOG_MAX_LINES:
		var oldest: Node = log_list.get_child(0)
		log_list.remove_child(oldest)
		oldest.queue_free()

	var timer := get_tree().create_timer(LOG_DURATION_SEC)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(label):
			return
		var fade := create_tween()
		fade.tween_property(label, "modulate:a", 0.0, 0.4)
		fade.tween_callback(label.queue_free)
	)


# --- 보스 HP바 ---

func _on_boss_started(boss_id: StringName) -> void:
	boss_name_label.text = String(boss_id)
	boss_phase_label.text = ""
	boss_hp_bar.max_value = 100.0
	boss_hp_bar.value = 100.0
	boss_bar_container.visible = true


func _on_boss_defeated(_boss_id: StringName) -> void:
	boss_bar_container.visible = false


# --- 설정 반영 ---

func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == &"font_size_large":
		_apply_font_size()
	elif key == &"colorblind_mode":
		vignette.set_state(HudMath.is_hp_critical(_hp_current, _hp_max), Settings.colorblind_mode)


# --- 디버그 패널 (F3, DebugHud 흡수) ---

func _on_player_died() -> void:
	debug_death_label.text = "DEATHS: %d" % GameState.death_count


func _update_debug_text() -> void:
	debug_combo_label.text = "COMBO: %s" % _read_combo_text()
	debug_status_label.text = "STATUS: %s" % _read_status_text()


func _read_combo_text() -> String:
	if _player == null or _player.state_machine == null:
		return "-"
	var current_state: PlayerState = _player.state_machine.current_state
	if current_state == null or current_state.name != &"Attack":
		return "-"
	if "combo" in current_state and current_state.combo != null:
		var combo: ComboState = current_state.combo
		if combo.in_finisher_recovery:
			return "%d/%d (recovery)" % [combo.max_hits, combo.max_hits]
		return "%d/%d" % [combo.hit_index, combo.max_hits]
	return "-"


func _read_status_text() -> String:
	if _player == null or _player.state_machine == null:
		return "-"
	var flags := PackedStringArray()
	var current_state: PlayerState = _player.state_machine.current_state
	if current_state != null and current_state.name == &"Guard":
		var guard_state := current_state as GuardState
		if guard_state != null and guard_state.is_just_guard_window():
			flags.append("JUST-GUARD!")
		else:
			flags.append("GUARD")
	if current_state != null and current_state.name == &"Roll":
		flags.append("ROLL")
	if _player.hurtbox != null and _player.hurtbox.invulnerable:
		flags.append("IFRAME")
	if flags.is_empty():
		return "-"
	return " ".join(flags)


# --- 향후 연동용 공개 API (F7-2 등) ---

## 추적 퀘스트 한 줄(현재는 빈 문자열). 퀘스트 시스템이 생기면 이 함수만 호출하면 된다.
func set_quest_line(text: String) -> void:
	quest_line_label.text = text
