## 원거리 투사체(F6-1 신규 패턴 `ranged_dart`, elite-and-farming-m2.md §1-1). 고블린
## 정찰병/정찰대장의 다트 공격이 사용한다 — monster_base.gd:_fire_projectile()이
## instantiate() 직후 damage/knockback_px/hitstop_sec/team/element을 채우고 launch()를
## 호출한다(Hitbox.activate()와 같은 "채운 뒤 시작" 패턴).
##
## CharacterBody2D를 재사용해 move_and_slide()로 벽(정적 콜라이더, collision_mask=1)에서
## 자연스럽게 소멸하게 했다 — MonsterBase 돌진(charge)과 동일한 벽 감지 관례. 실제 피격
## 판정은 자식 Hitbox(레이어 관례상 layer=0/mask=16, "허트박스 공용 레이어") 하나에
## 위임하고, 이 스크립트는 "날아가다가 벽/대상에 닿으면 사라진다"만 담당한다.
class_name Projectile
extends CharacterBody2D

@onready var hitbox: Hitbox = $Hitbox

var direction: Vector2 = Vector2.RIGHT
var speed_px: float = 220.0
var lifetime_sec: float = 1.2

var _launched: bool = false


func _ready() -> void:
	hitbox.hit_confirmed.connect(_on_hit_confirmed)


## 발사 시작 — 방향/속도/생존시간과 Hitbox 파라미터(damage 등)를 스폰한 쪽이 먼저
## 채운 뒤 호출한다. 히트박스 activate() 자체는 여기서 한 번만 한다(콤보처럼 여러 번
## 재활성화될 필요가 없는 "1회성 판정"이기 때문).
func launch(p_direction: Vector2, p_speed_px: float, p_lifetime_sec: float) -> void:
	direction = p_direction.normalized() if p_direction.length() > 0.01 else Vector2.RIGHT
	speed_px = p_speed_px
	lifetime_sec = p_lifetime_sec
	_launched = true
	hitbox.activate()
	var tree := get_tree()
	if tree != null:
		tree.create_timer(lifetime_sec).timeout.connect(_on_lifetime_expired)


func _physics_process(_delta: float) -> void:
	if not _launched:
		return
	velocity = direction * speed_px
	move_and_slide()
	if get_slide_collision_count() > 0:
		queue_free() # 벽(정적 콜라이더)에 부딪힘 — 회수 없이 소멸.


func _on_hit_confirmed(_hurtbox: Hurtbox) -> void:
	queue_free() # 같은 대상 중복 타격 방지(Hitbox 규칙)와 별개로, 다트는 1명 맞히면 소멸.


func _on_lifetime_expired() -> void:
	if is_instance_valid(self):
		queue_free()
