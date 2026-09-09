## HP 위험(25% 이하) 화면 가장자리 비네트(F7-1 예외 규칙). 색약 모드에서는 반투명 색
## 채움 대신 대각선 해치 패턴으로 대체한다(GDD 11장 "색만으로 구분하지 않음").
class_name VignetteOverlay
extends Control

var _active: bool = false
var _colorblind: bool = false
var _edge_color: Color = Color(0.7, 0, 0, 0.35)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(edge_color: Color) -> void:
	_edge_color = edge_color


func set_state(active: bool, colorblind: bool) -> void:
	if _active == active and _colorblind == colorblind:
		return
	_active = active
	_colorblind = colorblind
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var s: Vector2 = size
	var thickness := 28.0
	if not _colorblind:
		draw_rect(Rect2(0, 0, s.x, thickness), _edge_color)
		draw_rect(Rect2(0, s.y - thickness, s.x, thickness), _edge_color)
		draw_rect(Rect2(0, 0, thickness, s.y), _edge_color)
		draw_rect(Rect2(s.x - thickness, 0, thickness, s.y), _edge_color)
		return

	# 색약 모드: 네 변을 따라 대각선 해치 패턴(펄스 없이도 형태로 구분 가능).
	var step := 8.0
	var x := 0.0
	while x < s.x:
		draw_line(Vector2(x, 0), Vector2(x + thickness, thickness), _edge_color, 2.0)
		draw_line(Vector2(x, s.y), Vector2(x + thickness, s.y - thickness), _edge_color, 2.0)
		x += step
	var y := 0.0
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(thickness, y + thickness), _edge_color, 2.0)
		draw_line(Vector2(s.x, y), Vector2(s.x - thickness, y + thickness), _edge_color, 2.0)
		y += step
