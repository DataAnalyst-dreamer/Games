## 경험치바·레벨 라벨·레벨업 배너(M3-2, F7-1 확장, D-153).
##
## hud.gd가 이미 HP·스태미나·로그·보스바·디버그 패널로 500줄에 가까워(D-145 상한) 성장
## 표시만 분리했다. Hud.tscn에서 이 스크립트가 붙은 "HudProgress" 노드는 시각 요소가
## 없는 컨트롤러 자식이고, 실제 라벨/바는 NodePath export로 TopLeft·LevelUpBanner 쪽
## 기존 노드를 그대로 가리킨다(레이아웃은 Hud.tscn 하나의 트리에 유지, D-24와 같은
## "레이아웃 소유자는 하나" 원칙).
##
## Events.exp_changed/level_up 두 시그널만 구독한다(godot-engineer 스테이지
## stage/m3-1-exp-level과 합의한 인터페이스). GameState.level/exp를 직접 읽지 않고
## 항상 신호값으로만 갱신해 로직 브랜치 병합 전에도 스모크(SmokeProgressUi.tscn)에서
## 신호를 직접 emit해 독립적으로 검증할 수 있게 한다.
##
## 경로는 @export NodePath 대신 하드코딩한다 — Hud.tscn이 UiRoot.tscn -> Main.tscn으로
## 여러 겹 인스턴싱될 때 `node_paths` 리맵 방식의 상대 NodePath export가 빈 문자열로
## 깨지는 문제를 실제로 확인했다(smoke_inventory_menu.gd 회귀 발견, "Node not found: ''").
## HudProgress는 Hud.tscn 안에서 항상 같은 자리(Root의 자식)이므로 그냥 자기 위치
## 기준 상대 경로를 코드에 고정한다(hud.gd의 다른 @onready들과 동일한 관례로 복귀).
class_name HudProgress
extends Node

const BANNER_VISIBLE_SEC := 3.0
const BANNER_FADE_SEC := 0.4

@onready var level_label: Label = get_node("../TopLeft/LevelLabel")
@onready var exp_bar: ProgressBar = get_node("../TopLeft/ExpBar")
@onready var banner: Control = get_node("../LevelUpBanner")
@onready var banner_title: Label = get_node("../LevelUpBanner/BannerFrame/BannerVBox/BannerTitle")
@onready var banner_stats: Label = get_node("../LevelUpBanner/BannerFrame/BannerVBox/BannerStats")
@onready var _theme: Theme = (get_parent() as Control).theme

var _level: int = 1
var _banner_tween: Tween


func _ready() -> void:
	banner.visible = false
	banner.modulate.a = 1.0
	exp_bar.min_value = 0.0
	exp_bar.max_value = 1.0
	exp_bar.value = 0.0
	_apply_bar_style()
	_refresh_level_label()
	Events.exp_changed.connect(_on_exp_changed)
	Events.level_up.connect(_on_level_up)


func _apply_bar_style() -> void:
	if _theme == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = _theme.get_color(&"exp_bg", &"HUD")
	var fill := StyleBoxFlat.new()
	fill.bg_color = _theme.get_color(&"exp_fill", &"HUD")
	exp_bar.add_theme_stylebox_override("background", bg)
	exp_bar.add_theme_stylebox_override("fill", fill)
	if banner.has_node("BannerFrame"):
		var frame: Panel = banner.get_node("BannerFrame")
		frame.add_theme_stylebox_override("panel", _theme.get_stylebox(&"wood_frame", &"HUD"))


func _refresh_level_label() -> void:
	level_label.text = "%s %d" % [tr(&"ui.hud.level_prefix"), _level]


## exp_to_next<=0(만렙 등)이면 바를 가득 채워 보여준다 — 0으로 나누기 방지.
func _on_exp_changed(current_exp: int, exp_to_next: int, level: int) -> void:
	_level = level
	exp_bar.max_value = maxf(float(exp_to_next), 1.0)
	exp_bar.value = clampf(float(current_exp), 0.0, exp_bar.max_value)
	_refresh_level_label()


func _on_level_up(new_level: int, stat_gains: Dictionary) -> void:
	_level = new_level
	_refresh_level_label()
	_show_banner(stat_gains)


## M4-5(D-195): stat_gains에 실린 "stat_points"/"skill_points"(레벨업 1회당 지급량,
## exp_curve.csv.stat_points_gain 체증분 — stage/m4-4가 이 두 키를 stat_gains Dictionary에
## 얹기로 코디네이터와 합의)를 배너에 그대로 보여준다. 0이면 그 줄은 생략한다(만렙 등
## 지급이 없는 레벨업에서 "+0" 스팸 방지).
func _show_banner(stat_gains: Dictionary) -> void:
	banner_title.text = tr(&"ui.hud.level_up_banner") % _level
	var stats_text: String = _format_stat_gains(stat_gains)
	var stat_points_gained: int = int(stat_gains.get("stat_points", 0))
	var skill_points_gained: int = int(stat_gains.get("skill_points", 0))
	if stat_points_gained > 0:
		stats_text += "\n" + tr(&"ui.hud.stat_gain_toast") % stat_points_gained
	if skill_points_gained > 0:
		stats_text += "\n" + tr(&"ui.hud.skill_gain_toast") % skill_points_gained
	# M3-4: 레벨업으로 쌓인 스탯/스킬 포인트를 어디서 쓰는지 안내(D-153 데모 피드백
	# "레벨업 후 할 행동이 필요" — GameState.stat_points는 이미 존재하는 실제 필드).
	if GameState.stat_points > 0:
		stats_text += "\n" + tr(&"ui.hud.level_up_points_hint") % GameState.stat_points
	banner_stats.text = stats_text
	banner.visible = true
	banner.modulate.a = 1.0
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = get_tree().create_tween()
	_banner_tween.tween_interval(BANNER_VISIBLE_SEC)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, BANNER_FADE_SEC)
	_banner_tween.tween_callback(func() -> void: banner.visible = false)


## stat_gains는 {stat_key: 증가량}(예: {"max_hp": 10, "attack": 2}) — 스탯 이름 자체의
## 로컬라이징 key는 game-designer의 stats.json 확정 이후 범위라 지금은 키를 그대로
## 대문자로 보여준다(텍스트 골격 ui.hud.level_up_stat_fmt만 로컬라이징 key). "stat_points"/
## "skill_points"(M4-5, D-195)는 별도 줄(_show_banner)로 이미 표시하므로 여기서 뺀다.
const _POINT_GAIN_KEYS := ["stat_points", "skill_points"]


func _format_stat_gains(stat_gains: Dictionary) -> String:
	var parts := PackedStringArray()
	for stat_key: Variant in stat_gains.keys():
		if String(stat_key) in _POINT_GAIN_KEYS:
			continue
		parts.append(tr(&"ui.hud.level_up_stat_fmt") % [String(stat_key).to_upper(), str(stat_gains[stat_key])])
	return " · ".join(parts)
