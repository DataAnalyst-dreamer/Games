## M1-1 디버그 HUD. HP/스태미나/콤보 단계를 텍스트로만 표시한다.
## 테마(ui/theme.tres) 적용·정식 게이지 비주얼은 F7-1 태스크 범위라 여기서는 최소한만 한다.
extends Control

@export var player_path: NodePath

@onready var hp_label: Label = $VBox/HPLabel
@onready var stamina_label: Label = $VBox/StaminaLabel
@onready var combo_label: Label = $VBox/ComboLabel

var _player: Player


func _ready() -> void:
	if not player_path.is_empty():
		_player = get_node(player_path) as Player
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_stamina_changed.connect(_on_stamina_changed)


func _process(_delta: float) -> void:
	combo_label.text = "COMBO: %s" % _read_combo_text()


func _on_hp_changed(current: int, max_value: int) -> void:
	hp_label.text = "HP: %d / %d" % [current, max_value]


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_label.text = "STAMINA: %d / %d" % [int(round(current)), int(round(max_value))]


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
