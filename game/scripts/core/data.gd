## 데이터 테이블 자동로드 (F8-4 데이터 테이블 파이프라인).
##
## 부팅 시 res://data/*.json 을 전부 로드해 `Data.tables["combat"]` 식으로 접근한다.
## 필수 테이블·필수 키가 빠지면 개발 빌드에서는 push_error + assert 로 중단하고,
## 릴리즈 빌드에서는 push_warning 후 기본값으로 대체한다.
##
## 밸런스 수치는 절대 코드에 하드코딩하지 않는다. 아직 테이블화되지 않은 임시 상수는
## res://scripts/tuning.gd 한 파일에만 둔다.
extends Node

const DATA_DIR := "res://data"

## 필수 테이블 → 필수 키 목록(점 표기 경로). 테이블이 늘어나면 여기에 추가한다.
## 스키마 문서: docs/specs/data_tables.md (game-designer 소유)
const REQUIRED_SCHEMA := {
	"combat": [
		"roll.iframes_sec",
		"guard.just_guard_window_frames",
		"hitstop.min_sec",
		"hitstop.max_sec",
		"telegraph.min_sec",
		"combo.hits",
		"combo.damage_multipliers",
		"movement.walk_speed_px",
		"stamina.max",
		"stamina.regen_per_sec",
		"stamina.costs.roll",
	],
}

## 릴리즈 빌드에서 키가 없을 때 대체할 기본값. 개발 빌드는 여기까지 오지 않는다.
const RELEASE_FALLBACKS := {
	"combat": {
		"roll.iframes_sec": 0.3,
		"guard.just_guard_window_frames": 6,
		"hitstop.min_sec": 0.05,
		"hitstop.max_sec": 0.1,
		"telegraph.min_sec": 0.5,
		"combo.hits": 3,
		"combo.damage_multipliers": [1.0, 1.0, 1.5],
		"movement.walk_speed_px": 80.0,
		"stamina.max": 100.0,
		"stamina.regen_per_sec": 25.0,
		"stamina.costs.roll": 20.0,
	},
}

## 테이블 이름(파일명에서 .json 제거) → Dictionary
var tables: Dictionary = {}

## 로드/검증 중 발견한 문제 목록(문자열). 테스트·툴에서 확인용.
var validation_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


## 모든 테이블을 다시 읽고 검증한다. 에디터 툴이나 테스트에서 재호출 가능.
func reload() -> void:
	tables.clear()
	validation_errors.clear()
	_load_all(DATA_DIR)
	_validate()


func _load_all(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_report("데이터 폴더를 열 수 없음: %s (err=%d)" % [dir_path, DirAccess.get_open_error()])
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "json":
			var table_name := file_name.get_basename()
			var table: Variant = _load_json("%s/%s" % [dir_path, file_name])
			if table != null:
				tables[table_name] = table
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		_report("JSON 파일을 읽을 수 없음: %s" % path)
		return null
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		_report("JSON 파싱 실패: %s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		_report("JSON 최상위가 객체가 아님: %s" % path)
		return null
	return json.data


func _validate() -> void:
	for table_name: String in REQUIRED_SCHEMA:
		if not tables.has(table_name):
			_report("필수 테이블 누락: %s.json" % table_name)
			if not OS.is_debug_build():
				tables[table_name] = {}
		for key_path: String in REQUIRED_SCHEMA[table_name]:
			if not has_value(table_name, key_path):
				_report("필수 키 누락: %s.%s" % [table_name, key_path])
				if not OS.is_debug_build():
					_set_path(tables[table_name], key_path, RELEASE_FALLBACKS[table_name][key_path])


## 개발 빌드: push_error + assert(중단). 릴리즈: push_warning 후 진행.
func _report(message: String) -> void:
	validation_errors.append(message)
	if OS.is_debug_build():
		push_error("[Data] " + message)
		assert(false, "[Data] " + message)
	else:
		push_warning("[Data] " + message)


## 테이블에 점 표기 경로가 존재하는지 확인. 예: Data.has_value("combat", "roll.iframes_sec")
func has_value(table_name: String, key_path: String) -> bool:
	if not tables.has(table_name):
		return false
	var node: Variant = tables[table_name]
	for part: String in key_path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return false
		node = node[part]
	return true


## 점 표기 경로로 값을 읽는다. 없으면 default 반환.
## 예: Data.get_value("combat", "movement.walk_speed_px", 80.0)
func get_value(table_name: String, key_path: String, default: Variant = null) -> Variant:
	if not tables.has(table_name):
		return default
	var node: Variant = tables[table_name]
	for part: String in key_path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return default
		node = node[part]
	return node


## 테이블 전체 Dictionary. 없으면 빈 Dictionary.
func table(table_name: String) -> Dictionary:
	return tables.get(table_name, {})


func _set_path(target: Dictionary, key_path: String, value: Variant) -> void:
	var parts := key_path.split(".")
	var node := target
	for i in range(parts.size() - 1):
		if not node.has(parts[i]) or typeof(node[parts[i]]) != TYPE_DICTIONARY:
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[parts.size() - 1]] = value
