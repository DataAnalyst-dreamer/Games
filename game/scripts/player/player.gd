## 플레이어 캐릭터 (CharacterBody2D).
##
## 실제 행동 로직은 StateMachine 자식(Idle/Move/...)에 있고, 이 스크립트는
## 입력 읽기·방향·애니메이션 재생 같은 공용 유틸리티와 콜백 위임만 담당한다.
class_name Player
extends CharacterBody2D

## 4방향 애니메이션 접미사. 8방향 입력은 수평 우선으로 4방향에 매핑한다.
const DIR_NAMES := {
	Vector2.DOWN: "down",
	Vector2.UP: "up",
	Vector2.LEFT: "left",
	Vector2.RIGHT: "right",
}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: PlayerStateMachine = $StateMachine

## 바라보는 방향(4방향 중 하나). 공격 히트박스 방향 결정에도 쓴다.
var facing: Vector2 = Vector2.DOWN

## 이동 속도(px/s). combat.json 에서 로드.
var walk_speed: float


func _ready() -> void:
	walk_speed = float(Data.get_value("combat", "movement.walk_speed_px", 0.0))
	for dir_name: String in DIR_NAMES.values():
		sprite.sprite_frames.set_animation_speed("walk_" + dir_name, Tuning.ANIM_WALK_FPS)
		sprite.sprite_frames.set_animation_speed("idle_" + dir_name, Tuning.ANIM_IDLE_FPS)
	Events.player_spawned.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	state_machine.handle_input(event)


func _process(delta: float) -> void:
	state_machine.update(delta)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


## 8방향 이동 입력(정규화). 스틱 데드존은 project.godot 액션 deadzone 이 처리한다.
func get_move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", Tuning.STICK_DEADZONE)
	return v


## 입력 벡터를 4방향 facing 으로 환산한다. 대각선은 수평 우선.
func set_facing(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		return
	if absf(input_dir.x) >= absf(input_dir.y):
		facing = Vector2.RIGHT if input_dir.x > 0.0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if input_dir.y > 0.0 else Vector2.UP


func facing_name() -> String:
	return DIR_NAMES.get(facing, "down")


## "walk" → "walk_down" 식으로 방향 접미사를 붙여 재생. 같은 애니메이션이면 재시작하지 않는다.
func play_anim(base_name: String) -> void:
	var anim := "%s_%s" % [base_name, facing_name()]
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
