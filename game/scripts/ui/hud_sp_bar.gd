## SP바(M4-5, ro-benchmark-progression-v1.md §3). hud_progress.gd(경험치바)와 동일한
## 분리 원칙 — hud.gd가 이미 500줄에 가까워(D-145) 성장 표시만 옮긴 선례를 그대로
## 따른다. TopLeft의 HPBar/StaminaBar 형제로 SPBar를 두고 이 스크립트가 값만 반영한다.
##
## `Events.sp_changed(current, max)`는 stage/m4-4(로직, 병합 전)가 신설하는 시그널이라
## 아직 `core/events.gd`에 없다 — `has_signal` 가드 뒤에서만 정적 `Events.sp_changed`
## 심볼을 참조한다(가드 안쪽은 런타임에만 평가되므로, 신호가 없어도 컴파일·실행 모두
## 깨지지 않는다는 사실을 이 브랜치에서 직접 확인했다).
class_name HudSpBar
extends Node

@onready var sp_bar: ProgressBar = get_node("../TopLeft/SPBar")
@onready var _theme: Theme = (get_parent() as Control).theme


func _ready() -> void:
	sp_bar.min_value = 0.0
	sp_bar.max_value = 1.0
	sp_bar.value = 0.0
	_apply_bar_style()
	if Events.has_signal(&"sp_changed"):
		Events.sp_changed.connect(_on_sp_changed)


func _apply_bar_style() -> void:
	if _theme == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = _theme.get_color(&"sp_bg", &"HUD")
	var fill := StyleBoxFlat.new()
	fill.bg_color = _theme.get_color(&"sp_fill", &"HUD")
	sp_bar.add_theme_stylebox_override("background", bg)
	sp_bar.add_theme_stylebox_override("fill", fill)


func _on_sp_changed(current: float, max_value: float) -> void:
	sp_bar.max_value = maxf(max_value, 1.0)
	sp_bar.value = clampf(current, 0.0, sp_bar.max_value)
	if _theme != null:
		sp_bar.add_theme_stylebox_override("fill", _flat(_theme.get_color(
			&"sp_empty" if current <= 0.0 else &"sp_fill", &"HUD")))


static func _flat(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb
