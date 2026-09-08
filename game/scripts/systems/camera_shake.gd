## 카메라 셰이크 컨트롤러(F2-2: "강공격·크리티컬 시 카메라 셰이크"). Phantom Camera의
## NoiseEmitter2D를 감싸 Events.screen_shake_requested를 구독하고, 접근성 흔들림 강도
## 4단계(Settings.get_shake_scale(), Tuning.SCREEN_SHAKE_LEVELS 기준)를 곱해 세기를
## 조절한다. 배율 0이면 완전히 off(F2-2 예외 규칙).
##
## F7-1(M1-5)에서 Settings 자동로드가 생기며 강도 선택을 export 기본값 대신 Settings가
## 소유하도록 바꿨다(D-64: settings.json 소유=ui-ux-designer) — 접근성 옵션 화면(F7-3)이
## 이 값을 바꾸면 다음 셰이크 요청부터 즉시 반영된다.
extends Node

@export var emitter: PhantomCameraNoiseEmitter2D

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
	var scale: float = Settings.get_shake_scale()
	if scale <= 0.0:
		return
	_noise.amplitude = strength * scale
	emitter.duration = maxf(duration_sec, 0.001)
	emitter.growth_time = 0.01
	emitter.decay_time = maxf(duration_sec * 0.5, 0.01)
	emitter.emit()
