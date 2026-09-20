## 발밑 타원 그림자(D-204, 쿼터뷰 이관 단계 (a)).
##
## 비스듬 고정 2D 쿼터뷰에서 "액터가 바닥 평면 위에 서 있다"를 알려주는 최소 단서다.
## 파일럿(prototypes/quarter-view-lab/actor.gd:_draw)이 쓴 규칙 - 원을 세로로 눌러
## 그린 타원 - 을 그대로 옮겼고, 반지름만 본편 16px 아트 배율로 환산했다
## (파일럿의 24px는 스프라이트를 4배 확대한 좌표계 기준이다).
##
## 전용 노드를 만들지 않는 이유: CanvasItem._draw()는 자식 노드(스프라이트)보다 먼저
## 그려지므로, 액터 본체(CharacterBody2D)의 _draw()에서 이 함수를 부르면 그림자가
## 자동으로 발밑에 깔린다. 씬 7개(Player + 몬스터 6종)에 노드를 추가할 필요가 없고,
## 본체 원점을 따라 움직이므로 매 프레임 다시 그릴 필요도 없다.
##
## 수치는 전부 Tuning(단일 임시 상수 파일)에 있다 - 이 파일에 숫자를 쓰지 않는다.
class_name FootShadow
extends RefCounted


## canvas(액터 본체)의 로컬 원점 = 발밑에 타원 그림자를 그린다.
##
## size_scale: 몬스터 크기별 배율(D-204 "몬스터는 크기별 배율 허용"). 플레이어는 1.0.
## 0 이하면 아무것도 그리지 않는다(그림자 없는 액터를 표현할 수 있는 탈출구).
static func draw(canvas: CanvasItem, size_scale: float = 1.0) -> void:
	if canvas == null or not is_instance_valid(canvas):
		return
	var radius: float = Tuning.FOOT_SHADOW_RADIUS_PX * size_scale
	if radius <= 0.0:
		return
	# 세로만 눌러 원을 타원으로 만든다. 그린 뒤 반드시 변환을 되돌려야 같은 _draw()
	# 안의 뒤이은 그리기(예: 디버그 도형)가 눌린 좌표계를 물려받지 않는다.
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Tuning.FOOT_SHADOW_Y_SCALE))
	canvas.draw_circle(Vector2.ZERO, radius, Tuning.FOOT_SHADOW_COLOR)
	canvas.draw_set_transform(Vector2.ZERO)
