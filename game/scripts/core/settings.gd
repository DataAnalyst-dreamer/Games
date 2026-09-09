## 접근성·오디오 설정 자동로드(F7-3, D-64: 소유=ui-ux-designer).
##
## `user://settings.json`에 저장한다. 세이브 슬롯과 무관한 계정 단위 설정
## (docs/ui/wireframes.md 화면10 "설정은 세이브 슬롯과 무관한 공용 저장").
##
## 화면 흔들림 배율표는 Tuning.SCREEN_SHAKE_LEVELS([0, 0.5, 1.0, 1.5], D-63/D-64)를
## 인덱스로 참조한다 — 배율 값 자체를 여기서 중복 정의하지 않는다(단일 소스 유지).
extends Node

const SAVE_PATH := "user://settings.json"

## 화면 흔들림 강도 인덱스: 0=끔 1=약 2=보통(기본) 3=강. Tuning.SCREEN_SHAKE_LEVELS 인덱스.
var screen_shake_index: int = 2
## 데미지 숫자 표시(D-07: 기본 켜짐, 옵션에서 끌 수 있음).
var damage_numbers_enabled: bool = true
## 색약 모드: 등급 색 옆 아이콘 강조 + HP 위험 비네트를 패턴으로 대체.
var colorblind_mode: bool = false
## 폰트 크기: false=기본, true=크게 (2단계, wireframes 화면10).
var font_size_large: bool = false
## 볼륨 0.0~1.0. AudioServer 버스(Master/BGM/SFX)에 매핑된다.
var master_volume: float = 1.0
var bgm_volume: float = 1.0
var sfx_volume: float = 1.0


func _ready() -> void:
	load_settings()


## 기본값(GDD/결정 기준). 순수 함수 — 필드를 직접 건드리지 않아 GUT에서 부작용 없이 확인 가능.
static func default_dict() -> Dictionary:
	return {
		"screen_shake_index": 2,
		"damage_numbers_enabled": true,
		"colorblind_mode": false,
		"font_size_large": false,
		"master_volume": 1.0,
		"bgm_volume": 1.0,
		"sfx_volume": 1.0,
	}


## 현재 필드를 직렬화한다. 파일 IO 없음 — GUT이 저장 없이 라운드트립을 검증할 수 있다.
func to_dict() -> Dictionary:
	return {
		"screen_shake_index": screen_shake_index,
		"damage_numbers_enabled": damage_numbers_enabled,
		"colorblind_mode": colorblind_mode,
		"font_size_large": font_size_large,
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
	}


## dict → 필드 반영(범위 밖 값은 clamp, 누락 키는 기본값). 파일 IO 없이 GUT에서 직접 검증.
func apply_dict(data: Dictionary) -> void:
	var defaults := default_dict()
	screen_shake_index = clampi(
		int(data.get("screen_shake_index", defaults["screen_shake_index"])), 0, 3)
	damage_numbers_enabled = bool(
		data.get("damage_numbers_enabled", defaults["damage_numbers_enabled"]))
	colorblind_mode = bool(data.get("colorblind_mode", defaults["colorblind_mode"]))
	font_size_large = bool(data.get("font_size_large", defaults["font_size_large"]))
	master_volume = clampf(float(data.get("master_volume", defaults["master_volume"])), 0.0, 1.0)
	bgm_volume = clampf(float(data.get("bgm_volume", defaults["bgm_volume"])), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", defaults["sfx_volume"])), 0.0, 1.0)


func reset_to_defaults() -> void:
	apply_dict(default_dict())
	for key in default_dict().keys():
		Events.settings_changed.emit(StringName(key), get(key))
	save_settings()


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		apply_dict(default_dict())
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[Settings] settings.json 열기 실패, 기본값 사용")
		apply_dict(default_dict())
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		apply_dict(parsed)
	else:
		push_warning("[Settings] settings.json 파싱 실패, 기본값 사용")
		apply_dict(default_dict())


func save_settings() -> Error:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Settings] settings.json 저장 실패: %s" % SAVE_PATH)
		return FAILED
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return OK


## camera_shake.gd가 참조하는 접근성 배율(D-63/D-64). 0=완전 off.
func get_shake_scale() -> float:
	var levels: Array = Tuning.SCREEN_SHAKE_LEVELS
	return levels[clampi(screen_shake_index, 0, levels.size() - 1)]


func set_screen_shake_index(index: int) -> void:
	screen_shake_index = clampi(index, 0, 3)
	Events.settings_changed.emit(&"screen_shake_index", screen_shake_index)
	save_settings()


func set_damage_numbers_enabled(enabled: bool) -> void:
	damage_numbers_enabled = enabled
	Events.settings_changed.emit(&"damage_numbers_enabled", enabled)
	save_settings()


func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	Events.settings_changed.emit(&"colorblind_mode", enabled)
	save_settings()


func set_font_size_large(enabled: bool) -> void:
	font_size_large = enabled
	Events.settings_changed.emit(&"font_size_large", enabled)
	save_settings()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	Events.settings_changed.emit(&"master_volume", master_volume)
	save_settings()


func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	Events.settings_changed.emit(&"bgm_volume", bgm_volume)
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	Events.settings_changed.emit(&"sfx_volume", sfx_volume)
	save_settings()
