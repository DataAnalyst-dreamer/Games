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
	"elements": [
		"cycle",
		"advantage_multiplier",
		"holy_element",
		"holy_bonus_vs_tags",
		"status_effects.burn.dps",
		"status_effects.burn.duration_sec",
		"status_effects.burn.buildup_threshold",
		"status_effects.freeze.duration_sec",
		"status_effects.freeze.buildup_threshold",
		"status_effects.shock.stun_duration_sec",
		"status_effects.shock.buildup_threshold",
		"boss_resistance_multiplier",
	],
}

## monsters.json은 monster_id를 키로 하는 동적 딕셔너리라 REQUIRED_SCHEMA(고정 경로)로
## 표현할 수 없다. 몬스터 엔트리마다 반드시 있어야 하는 필드 목록(data_tables.md §12 ●).
const MONSTER_REQUIRED_FIELDS := [
	"region_id", "tier", "hp", "atk", "move_speed_px",
	"telegraph_sec", "attack_pattern_id", "drop_table_id", "codex_entry_id",
]

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
	"elements": {
		"cycle": ["fire", "wind", "thunder", "water"],
		"advantage_multiplier": 1.5,
		"holy_element": "holy",
		"holy_bonus_vs_tags": ["demon"],
		"status_effects.burn.dps": 4.0,
		"status_effects.burn.duration_sec": 3.0,
		"status_effects.burn.buildup_threshold": 100.0,
		"status_effects.freeze.duration_sec": 1.5,
		"status_effects.freeze.buildup_threshold": 100.0,
		"status_effects.shock.stun_duration_sec": 1.0,
		"status_effects.shock.buildup_threshold": 100.0,
		"boss_resistance_multiplier": 0.5,
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
	_validate_monsters()
	_validate_value_rules()


## monsters.json은 monster_id 키의 동적 딕셔너리라 REQUIRED_SCHEMA로 표현할 수 없어
## 별도 순회 검증한다(data_tables.md §12 검증 규칙 1: telegraph_sec ≥ 0.5).
func _validate_monsters() -> void:
	if not tables.has("monsters"):
		_report("필수 테이블 누락: monsters.json")
		return
	var monsters: Dictionary = tables["monsters"]
	for monster_id: String in monsters:
		if monster_id.begins_with("_"):
			continue
		var entry: Variant = monsters[monster_id]
		if typeof(entry) != TYPE_DICTIONARY:
			_report("monsters.%s 가 객체가 아님" % monster_id)
			continue
		for field: String in MONSTER_REQUIRED_FIELDS:
			if not (entry as Dictionary).has(field):
				_report("필수 키 누락: monsters.%s.%s" % [monster_id, field])
		if (entry as Dictionary).has("telegraph_sec"):
			var telegraph: float = float(entry["telegraph_sec"])
			if telegraph < 0.5:
				_report("GDD 4.2 위반: monsters.%s.telegraph_sec(%s) < 0.5" % [monster_id, telegraph])


## 값 간 정합성 규칙(data_tables.md §1 검증 규칙, 단순 존재 확인이 아닌 관계식).
func _validate_value_rules() -> void:
	if tables.has("combat"):
		var min_sec: float = float(get_value("combat", "hitstop.min_sec", 0.0))
		var max_sec: float = float(get_value("combat", "hitstop.max_sec", 0.0))
		if has_value("combat", "hitstop.normal_sec"):
			var normal_sec: float = float(get_value("combat", "hitstop.normal_sec"))
			if not (min_sec <= normal_sec):
				_report("hitstop.min_sec(%s) <= hitstop.normal_sec(%s) 위반" % [min_sec, normal_sec])
			if has_value("combat", "hitstop.heavy_crit_sec"):
				var heavy_sec: float = float(get_value("combat", "hitstop.heavy_crit_sec"))
				if not (normal_sec <= heavy_sec):
					_report("hitstop.normal_sec(%s) <= hitstop.heavy_crit_sec(%s) 위반" % [normal_sec, heavy_sec])
				if not (heavy_sec <= max_sec):
					_report("hitstop.heavy_crit_sec(%s) <= hitstop.max_sec(%s) 위반" % [heavy_sec, max_sec])
		if has_value("combat", "guard.just_guard_window_frames") and has_value("combat", "guard.just_guard_window_sec"):
			var frames: int = int(get_value("combat", "guard.just_guard_window_frames"))
			var fps: int = int(get_value("combat", "frame_rate_reference", 60))
			var window_sec: float = float(get_value("combat", "guard.just_guard_window_sec"))
			if not is_equal_approx(window_sec, float(frames) / float(fps)):
				_report("guard.just_guard_window_sec(%s) != frames/fps(%s) 위반" % [window_sec, float(frames) / float(fps)])
		if has_value("combat", "combo.hits") and has_value("combat", "combo.damage_multipliers"):
			var hits: int = int(get_value("combat", "combo.hits"))
			var mults: Array = get_value("combat", "combo.damage_multipliers")
			if mults.size() != hits:
				_report("combo.damage_multipliers.size()(%d) != combo.hits(%d) 위반" % [mults.size(), hits])
		if has_value("combat", "roll.iframes_sec") and has_value("combat", "roll.duration_sec"):
			var iframes: float = float(get_value("combat", "roll.iframes_sec"))
			var duration: float = float(get_value("combat", "roll.duration_sec"))
			if not (iframes <= duration):
				_report("roll.iframes_sec(%s) <= roll.duration_sec(%s) 위반" % [iframes, duration])
		# M1-2 신규 키(제안값, godot-engineer 반영): 배율은 0~1 범위(0=완전 정지/완전 고갈, 1=무배율).
		if has_value("combat", "guard.move_speed_multiplier"):
			var guard_move_mult: float = float(get_value("combat", "guard.move_speed_multiplier"))
			if not (guard_move_mult >= 0.0 and guard_move_mult <= 1.0):
				_report("guard.move_speed_multiplier(%s) 범위(0~1) 위반" % guard_move_mult)
		if has_value("combat", "stamina.guard_regen_multiplier"):
			var guard_regen_mult: float = float(get_value("combat", "stamina.guard_regen_multiplier"))
			if not (guard_regen_mult >= 0.0 and guard_regen_mult <= 1.0):
				_report("stamina.guard_regen_multiplier(%s) 범위(0~1) 위반" % guard_regen_mult)
	if tables.has("elements") and has_value("elements", "cycle"):
		var cycle: Array = get_value("elements", "cycle")
		if cycle.size() != 4:
			_report("elements.cycle.size()(%d) != 4 위반" % cycle.size())
		var unique := {}
		for element: String in cycle:
			unique[element] = true
		if unique.size() != cycle.size():
			_report("elements.cycle 에 중복 원소가 있음: %s" % [cycle])


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
