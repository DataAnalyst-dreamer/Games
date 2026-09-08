## 카메라 셰이크 컨트롤러(F2-2: "강공격·크리티컬 시 카메라 셰이크"). Phantom Camera의
## NoiseEmitter2D를 감싸 Events.screen_shake_requested를 구독하고, 접근성 흔들림 강도
## 4단계(Tuning.SCREEN_SHAKE_LEVELS)를 곱해 세기를 조절한다. 배율 0이면 완전히 off
## (F2-2 예외 규칙). 설정 화면이 아직 없어(F7-1 범위) 기본 강도는 export로 노출한다.
extends Node

@export var emitter: PhantomCameraNoiseEmitter2D
## Tuning.SCREEN_SHAKE_LEVELS 인덱스(0=off, 3=최대). 접근성 옵션 UI 연결 전까지 기본값.
@export var accessibility_level_index: int = 2

var _noise: PhantomCameraNoise2D


func _ready() -> void:
	_noise = PhantomCameraNoise2D.new()
	_noise.positional_noise = true
	_noise.rotational_noise = false
	if emitter != null:
		emitter.noise = _noise
	Events.screen_shake_requested.connect(_on_shake_requested)


func _on_shake_requested(strength: float, duration_sec: float) -> void:
	if emitter == null:
		return
	var levels: Array = Tuning.SCREEN_SHAKE_LEVELS
	var idx: int = clampi(accessibility_level_index, 0, levels.size() - 1)
	var scale: float = levels[idx]
	if scale <= 0.0:
		return
	_noise.amplitude = strength * scale
	emitter.duration = maxf(duration_sec, 0.001)
	emitter.growth_time = 0.01
	emitter.decay_time = maxf(duration_sec * 0.5, 0.01)
	emitter.emit()
