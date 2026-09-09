## M1-1/M1-2 디버그 HUD. HP/스태미나/콤보 단계 + 가드/저스트 가드/무적/사망 횟수를
## 텍스트로만 표시한다. 테마(ui/theme.tres) 적용·정식 게이지 비주얼은 F7-1 태스크 범위.
extends Control

## 스태미나 부족 경고 색(F2-3 예외: "바 빨간색 깜박임"). 정식 게이지가 없어 라벨 색으로 대체.
const STAMINA_LOW_COLOR := Color(1.0, 0.6, 0.2)
const STAMINA_EMPTY_COLOR := Color(1.0, 0.2, 0.2)
const STAMINA_NORMAL_COLOR := Color(1.0, 1.0, 1.0)
const STAMINA_LOW_RATIO := 0.25
const FLASH_CYCLE_SEC := 0.08

@export var player_path: NodePath

@onready var hp_label: Label = $VBox/HPLabel
@onready var stamina_label: Label = $VBox/StaminaLabel
@onready var combo_label: Label = $VBox/ComboLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var death_label: Label = $VBox/DeathLabel

var _player: Player
var _stamina_ratio: float = 1.0


func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node(player_path) as Player
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_stamina_changed.connect(_on_stamina_changed)
	Events.player_stamina_insufficient.connect(_on_stamina_insufficient)
	Events.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	combo_label.text = "COMBO: %s" % _read_combo_text()
	status_label.text = "STATUS: %s" % _read_status_text()


func _on_hp_changed(current: int, max_value: int) -> void:
	hp_label.text = "HP: %d / %d" % [current, max_value]


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_label.text = "STAMINA: %d / %d" % [int(round(current)), int(round(max_value))]
	_stamina_ratio = current / max_value if max_value > 0.0 else 0.0
	if current <= 0.0:
		stamina_label.modulate = STAMINA_EMPTY_COLOR
	elif _stamina_ratio < STAMINA_LOW_RATIO:
		stamina_label.modulate = STAMINA_LOW_COLOR
	else:
		stamina_label.modulate = STAMINA_NORMAL_COLOR


## S2-1b/S2-1c 예외: 스태미나 부족으로 구르기·가드 히트 등이 미발동됐을 때 라벨을
## 몇 차례 빨갛게 깜박인다.
func _on_stamina_insufficient(_action: StringName) -> void:
	var tween := create_tween()
	for i in 3:
		tween.tween_property(stamina_label, "modulate", STAMINA_EMPTY_COLOR, FLASH_CYCLE_SEC * 0.5)
		tween.tween_property(stamina_label, "modulate", STAMINA_NORMAL_COLOR, FLASH_CYCLE_SEC * 0.5)


func _on_player_died() -> void:
	death_label.text = "DEATHS: %d" % GameState.death_count


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


## 가드/저스트 가드/무적(구르기 무적 등) 플래그를 한 줄로 보여준다(M1-2 디버그용).
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
