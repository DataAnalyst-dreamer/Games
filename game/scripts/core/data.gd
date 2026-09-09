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

## M2-1(아이템/드랍) 검증에 쓰는 공용 enum류 상수. tools/qa/validate_tables.py와 반드시
## 동일한 값을 유지한다(오프라인 파이썬 검증과 런타임 Data 검증이 같은 기준을 봐야 함,
## docs/specs/items-and-drops-m2.md §10 엔지니어 요청 1/5).
const ITEM_GRADES := ["common", "uncommon", "rare", "epic", "legendary", "relic"]
const AFFIX_SLOT_BY_GRADE := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 3, "relic": 3}
const EQUIP_CATEGORIES := ["weapon", "sub", "head", "armor", "boots", "ring", "amulet"]
const ITEM_CATEGORIES := [
	"weapon", "sub", "head", "armor", "boots", "ring", "amulet",
	"costume_hat", "costume_outfit", "costume_backpack",
	"consumable", "material",
]

## D-45 정본 문자열(구르기 스태미나 DEX 경감식, combat-tuning-m1.md §3-3 / combat.json.
## stamina._comment와 "수학적으로" 동일해야 한다 — 단, combat.json 쪽 서술은 유니코드
## 연산자(×, −)를 쓰는 자연어 문장 안에 있어 stats.json의 ASCII 단독 필드값과 바이트
## 단위로는 절대 일치하지 않는다(기존에도 이미 그랬던 표기 차이). 그래서 여기서는
## stats.json 자신의 값이 이 정본 문자열과 일치하는지만 검사한다 — combat.json 서술과의
## 사람 눈 대조는 완료 보고 질문 목록으로 남긴다(elite-and-farming-m2.md §4-3 규칙1).
const DEX_ROLL_COST_FORMULA_CANONICAL := "cost * (1 - min(0.5, DEX/300))"

## farming_sources.json: GDD 6.5 기준 type별 respawn_seconds(D-15, 실제 플레이 시간
## 기준). elite-and-farming-m2.md §4-2 규칙1.
const FARMING_TYPE_RESPAWN_SECONDS := {
	"field": 0, "gathering": 0, "treasure_map": 0, "region_dungeon": 0,
	"elite": 1800, "mini_dungeon": 86400, "world_boss": 259200,
}
## GDD 7.3 "정예·월드 보스 리스폰 상태 아이콘" 대상 타입(elite-and-farming-m2.md §4-2 규칙4).
const FARMING_MAP_ICON_TYPES := ["elite", "world_boss"]

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
		"hurt.stun_sec",
		"hurt.iframes_sec",
		"knockback.duration_sec",
		# QA 리뷰 Minor-1(docs/qa/review-m1-1-m1-2.md): D-46/D-48·M1-2에서 combat.json에
		# 추가된 뒤 REQUIRED_SCHEMA 보호를 받지 못하던 16개 키. 이 키들이 실수로
		# 삭제/오타나도 개발 빌드가 push_error+assert로 즉시 잡아내도록 등록한다.
		"roll.duration_sec",
		"roll.distance_px",
		"guard.chip_damage_ratio",
		"guard.just_guard_enemy_stagger_sec",
		"guard.move_speed_multiplier",
		"hitstop.normal_sec",
		"hitstop.heavy_crit_sec",
		"combo.reset_after_sec",
		"combo.finisher_recovery_sec",
		"combo.finisher_roll_cancel_after_sec",
		"stamina.regen_delay_sec",
		"stamina.exhausted_penalty_sec",
		"stamina.guard_regen_multiplier",
		"stamina.costs.guard_hit",
		"stamina.costs.heavy_attack",
		"knockback.normal_px",
		"knockback.heavy_px",
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
	# M2-1(items-and-drops-m2.md §10 엔지니어 요청 1/2/3): items/affixes는 item_id/
	# affix_id 키의 동적 딕셔너리라 monsters.json처럼 여기엔 "테이블이 존재해야 한다"만
	# 등록하고, 실제 필드 단위 검증은 _validate_items()/_validate_affixes()에 위임한다.
	"items": [],
	"affixes": [],
	# drop_tables._luck_formula는 파일 로드 시 반드시 존재해야 하는 고정 경로라
	# REQUIRED_SCHEMA로 표현 가능(요청 2 "_luck_formula가 스키마 키인지 확인").
	"drop_tables": [
		"_luck_formula.formula",
		"_luck_formula.luk_coefficient.uncommon",
		"_luck_formula.luk_coefficient.rare",
		"_luck_formula.luk_coefficient.epic",
		"_luck_formula.luk_coefficient.legendary",
		"_luck_formula.luk_coefficient.relic",
	],
	# enhance.json 신규 필드(요청 3): refine.cost_material_id·max_attempts. 등급별
	# cost_by_grade_and_attempt는 동적 키(등급명)라 _validate_enhance()에서 순회 확인.
	"enhance": [
		"refine.max_attempts",
		"refine.cost_material_id",
		"enhance_levels.+1.success_rate",
		"enhance_levels.+10.success_rate",
	],
	# stats.json(F1-2, docs/specs/elite-and-farming-m2.md §4-4 요청 1) — 고정 경로만.
	# 등급별/스탯별 나머지 필드(*_per_point, *_cap 등)는 동적이라 _validate_stats()에서
	# 순회 확인한다.
	"stats": [
		"max_level",
		"stat_points_per_levelup",
		"skill_points_per_levelup",
		"dex.stamina_cost_reduction_formula",
		"luk._luck_formula_ref",
		"vit.defense_formula",
	],
	# farming_sources.json은 source_id 키의 동적 딕셔너리라(monsters.json과 동일 사정)
	# "테이블 존재"만 여기 등록하고 필드 단위 검증은 _validate_farming_sources()에 위임
	# (요청 2).
	"farming_sources": [],
	# blueprints.json(F3-4, M2-4 신설) — blueprint_id 키의 동적 딕셔너리라 "테이블 존재"만
	# 여기 등록하고 필드 단위 검증은 _validate_blueprints()에 위임(items/drop_tables와
	# 동일 패턴).
	"blueprints": [],
	# quests(F5-1/F5-2, M2-7 신설) — game/data/quests/*.json 폴더 병합 결과(quest_id 키의
	# 동적 딕셔너리, _load_quests() 참고). "테이블 존재"만 여기 등록하고 필드 단위 검증은
	# _validate_quests()에 위임(items/blueprints와 동일 패턴).
	"quests": [],
	# pools.json(F5-2 게시판 일일 의뢰 풀, D-97 신설) — pool_id 키의 동적 딕셔너리.
	# _validate_pools()에 위임.
	"pools": [],
	# world_objects.json(F5-1/F5-2, M2-8 신설, level-designer 소유) — object_id 키의
	# 동적 딕셔너리(kind: location|object|npc). "테이블 존재"만 여기 등록하고 필드 단위
	# 검증은 _validate_world_objects()에 위임(pools/blueprints와 동일 패턴). quests의
	# npc:/location:/object: 목표 참조가 이 테이블과 대조된다(_validate_quests() 확장,
	# quest-system-m2.md §10에서 "형식만 두고 값은 검사하지 않는다"고 했던 부분을 M2-8이
	# 실제 레벨 배치가 생기면서 채운다).
	"world_objects": [],
}

## monsters.json은 monster_id를 키로 하는 동적 딕셔너리라 REQUIRED_SCHEMA(고정 경로)로
## 표현할 수 없다. 몬스터 엔트리마다 반드시 있어야 하는 필드 목록(data_tables.md §12 ●).
const MONSTER_REQUIRED_FIELDS := [
	"region_id", "tier", "hp", "atk", "move_speed_px",
	"telegraph_sec", "attack_pattern_id", "drop_table_id", "codex_entry_id",
	"aggro_range_px", "melee_range_px", "attack_recovery_sec",
	"patrol_radius_px", "leash_range_px",
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
		"hurt.stun_sec": 0.25,
		"hurt.iframes_sec": 0.5,
		"knockback.duration_sec": 0.12,
		"roll.duration_sec": 0.45,
		"roll.distance_px": 48,
		"guard.chip_damage_ratio": 0.2,
		"guard.just_guard_enemy_stagger_sec": 0.4,
		"guard.move_speed_multiplier": 0.5,
		"hitstop.normal_sec": 0.05,
		"hitstop.heavy_crit_sec": 0.1,
		"combo.reset_after_sec": 0.6,
		"combo.finisher_recovery_sec": 0.35,
		"combo.finisher_roll_cancel_after_sec": 0.167,
		"stamina.regen_delay_sec": 0.5,
		"stamina.exhausted_penalty_sec": 1.0,
		"stamina.guard_regen_multiplier": 0.5,
		"stamina.costs.guard_hit": 10.0,
		"stamina.costs.heavy_attack": 25.0,
		"knockback.normal_px": 8,
		"knockback.heavy_px": 20,
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
	"items": {},
	"affixes": {},
	"drop_tables": {
		"_luck_formula.formula": "raw_weight[grade] = grade_base_weight[grade] * luk_multiplier[grade]",
		"_luck_formula.luk_coefficient.uncommon": 0.004,
		"_luck_formula.luk_coefficient.rare": 0.010,
		"_luck_formula.luk_coefficient.epic": 0.020,
		"_luck_formula.luk_coefficient.legendary": 0.035,
		"_luck_formula.luk_coefficient.relic": 0.050,
	},
	"enhance": {
		"refine.max_attempts": 3,
		"refine.cost_material_id": "enhance_stone",
		"enhance_levels.+1.success_rate": 1.0,
		"enhance_levels.+10.success_rate": 0.25,
	},
	"stats": {
		"max_level": 50,
		"stat_points_per_levelup": 3,
		"skill_points_per_levelup": 1,
		"dex.stamina_cost_reduction_formula": "cost * (1 - min(0.5, DEX/300))",
		"luk._luck_formula_ref": "drop_tables.json",
		"vit.defense_formula": "damage_taken = incoming_atk * 100 / (100 + defense)",
	},
	"farming_sources": {},
	"blueprints": {},
	"quests": {},
	"pools": {},
	"world_objects": {},
}

## 테이블 이름(파일명에서 .json 제거) → Dictionary
var tables: Dictionary = {}

## 로드/검증 중 발견한 문제 목록(문자열). 테스트·툴에서 확인용.
var validation_errors: PackedStringArray = PackedStringArray()

## M2-7(F5-1/F5-2 퀘스트) 신설. game/data/quests/*.json 각 파일 상단 _todo_ids를
## 카테고리별로 합집합해 둔 것("monsters"/"items"/"locations"/"objects"/"pools" ->
## Array[String], 중복 제거). 실제 참조 무결성 검증(_validate_quests())이 이 목록을
## "알려진 미해결"로 취급해 경고만 내고 넘어가는 데 쓰고, 완료 보고/툴에서도 그대로
## 참고할 수 있도록 공개 필드로 노출한다.
var quest_todo_ids: Dictionary = {}


func _ready() -> void:
	reload()


## 모든 테이블을 다시 읽고 검증한다. 에디터 툴이나 테스트에서 재호출 가능.
func reload() -> void:
	tables.clear()
	validation_errors.clear()
	quest_todo_ids.clear()
	_load_all(DATA_DIR)
	_load_quests("%s/quests" % DATA_DIR)
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


## game/data/quests/*.json 폴더 병합 로더(M2-7). 각 파일 = 한 막·지방 묶음
## (docs/specs/quest-data-schema.md §1) — "quests" 배열을 quest_id 키 딕셔너리로 펼쳐
## tables["quests"]에 합치고, "_todo_ids"는 카테고리별로 합집합해 quest_todo_ids에
## 쌓는다. 폴더 자체가 없으면(테스트 등) 조용히 넘어간다 — quests는 REQUIRED_SCHEMA에
## "테이블 존재"만 등록돼 있어 _validate()가 그 시점에 필요하면 보고한다.
func _load_quests(dir_path: String) -> void:
	var merged: Dictionary = tables.get("quests", {})
	var dir := DirAccess.open(dir_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() == "json":
				var file_data: Variant = _load_json("%s/%s" % [dir_path, file_name])
				if file_data != null:
					_merge_quest_file(file_data, merged, file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	# 폴더가 없어도(dir == null) 항상 "quests" 테이블을 세팅해 둔다 — REQUIRED_SCHEMA의
	# "필수 테이블 누락" 오탐(빈 quests={}조차 못 만드는 상황)을 피한다.
	tables["quests"] = merged


func _merge_quest_file(file_data: Dictionary, merged: Dictionary, file_name: String) -> void:
	for quest: Dictionary in (file_data.get("quests", []) as Array):
		var quest_id: String = String(quest.get("id", ""))
		if quest_id.is_empty():
			_report("quests(%s): id 없는 퀘스트 항목" % file_name)
			continue
		if merged.has(quest_id):
			_report("quests(%s): quest_id 중복 - '%s' (스키마 체크리스트 '모든 id 유일' 위반)" % [file_name, quest_id])
		merged[quest_id] = quest
	var todo: Dictionary = file_data.get("_todo_ids", {})
	for category: String in todo:
		if category.begins_with("_"):
			continue # _resolved_m2_7 같은 사람이 읽는 주석 필드는 건너뛴다.
		var bucket: Array = quest_todo_ids.get(category, [])
		for id_v: Variant in (todo[category] as Array):
			var id_str: String = String(id_v)
			if not bucket.has(id_str):
				bucket.append(id_str)
		quest_todo_ids[category] = bucket


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
	_validate_items()
	_validate_affixes()
	_validate_drop_tables()
	_validate_enhance()
	_validate_stats()
	_validate_farming_sources()
	_validate_blueprints()
	_validate_pools()
	_validate_world_objects()
	_validate_quests()
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
		# addendum §4-2 확정(D-65 예정): AI 상태 전이가 논리적으로 겹치지 않도록 강제
		# (data_tables.md §12 검증 규칙 4~5).
		var dict_entry: Dictionary = entry as Dictionary
		if dict_entry.has("leash_range_px") and dict_entry.has("aggro_range_px") and dict_entry.has("melee_range_px"):
			var leash: float = float(dict_entry["leash_range_px"])
			var aggro: float = float(dict_entry["aggro_range_px"])
			var melee: float = float(dict_entry["melee_range_px"])
			if not (leash > aggro and aggro > melee):
				_report("monsters.%s: leash_range_px(%s) > aggro_range_px(%s) > melee_range_px(%s) 위반" \
					% [monster_id, leash, aggro, melee])
		if dict_entry.has("aoe_radius_px") and dict_entry.has("melee_range_px"):
			var aoe: float = float(dict_entry["aoe_radius_px"])
			var melee2: float = float(dict_entry["melee_range_px"])
			if not (aoe >= melee2):
				_report("monsters.%s: aoe_radius_px(%s) >= melee_range_px(%s) 위반" % [monster_id, aoe, melee2])
		# M2-1(items-and-drops-m2.md §10 엔지니어 요청 5, D-67): drop_table_id가 null이
		# 아니면 drop_tables.json에 실존하는 키여야 한다. null은 "확정된 드랍 없음"으로
		# 허용(D-67 원문 그대로).
		if dict_entry.has("drop_table_id") and dict_entry["drop_table_id"] != null:
			var dt_id: String = String(dict_entry["drop_table_id"])
			var drop_tables_table: Dictionary = tables.get("drop_tables", {})
			if not drop_tables_table.has(dt_id):
				_report("monsters.%s: drop_table_id '%s' 가 drop_tables.json에 없음 (D-67 위반)" % [monster_id, dt_id])


## items.json 필드 단위 검증(M2-1, tools/qa/validate_tables.py:validate_items() 이식).
## 오프라인 스크립트가 CI에서만 잡던 것을 개발 빌드가 즉시 push_error+assert로 잡는다.
func _validate_items() -> void:
	if not tables.has("items"):
		return
	var items: Dictionary = tables["items"]
	for item_id: String in items:
		if item_id.begins_with("_"):
			continue
		if typeof(items[item_id]) != TYPE_DICTIONARY:
			_report("items.%s 가 객체가 아님" % item_id)
			continue
		var entry: Dictionary = items[item_id]
		for field: String in ["item_id", "category", "grade", "sell_price"]:
			if not entry.has(field):
				_report("items.%s: 필수 키 누락 '%s'" % [item_id, field])
		if String(entry.get("item_id", "")) != item_id:
			_report("items.%s: item_id 필드값('%s')이 키와 불일치" % [item_id, entry.get("item_id")])
		var category: String = String(entry.get("category", ""))
		if entry.has("category") and not ITEM_CATEGORIES.has(category):
			_report("items.%s: category '%s' 가 enum에 없음" % [item_id, category])
		var grade: String = String(entry.get("grade", ""))
		if entry.has("grade") and not ITEM_GRADES.has(grade):
			_report("items.%s: grade '%s' 가 enum에 없음" % [item_id, grade])
		if EQUIP_CATEGORIES.has(category):
			if not entry.has("affix_slot_count"):
				_report("items.%s: 장비인데 affix_slot_count 없음" % item_id)
			elif AFFIX_SLOT_BY_GRADE.has(grade):
				var expected: int = int(AFFIX_SLOT_BY_GRADE[grade])
				if int(entry["affix_slot_count"]) != expected:
					_report("items.%s: affix_slot_count=%s != grade '%s' 규칙값(%d)" \
						% [item_id, entry["affix_slot_count"], grade, expected])
		if entry.get("unique_skill_id") != null and grade != "legendary":
			_report("items.%s: unique_skill_id가 있으면 grade는 legendary여야 함 (현재 %s)" % [item_id, grade])
		if entry.get("set_id") != null and grade != "relic":
			_report("items.%s: set_id가 있으면 grade는 relic이어야 함 (현재 %s)" % [item_id, grade])
		if float(entry.get("sell_price", 0)) < 0.0:
			_report("items.%s: sell_price는 0 이상이어야 함" % item_id)
		if entry.has("base_stats") and typeof(entry["base_stats"]) == TYPE_DICTIONARY:
			var base_stats: Dictionary = entry["base_stats"]
			for k: String in base_stats:
				if k.ends_with("_min"):
					var max_key: String = k.substr(0, k.length() - 4) + "_max"
					if base_stats.has(max_key) and float(base_stats[k]) > float(base_stats[max_key]):
						_report("items.%s: base_stats.%s(%s) > %s(%s)" \
							% [item_id, k, base_stats[k], max_key, base_stats[max_key]])


## affixes.json 필드 단위 검증(validate_tables.py:validate_affixes() 이식).
func _validate_affixes() -> void:
	if not tables.has("affixes"):
		return
	var affixes: Dictionary = tables["affixes"]
	var stat_types: Dictionary = {}
	for affix_id: String in affixes:
		if affix_id.begins_with("_"):
			continue
		if typeof(affixes[affix_id]) != TYPE_DICTIONARY:
			_report("affixes.%s 가 객체가 아님" % affix_id)
			continue
		var entry: Dictionary = affixes[affix_id]
		for field: String in ["affix_id", "stat_type", "value_min", "value_max", "applicable_categories", "weight"]:
			if not entry.has(field):
				_report("affixes.%s: 필수 키 누락 '%s'" % [affix_id, field])
		if String(entry.get("affix_id", "")) != affix_id:
			_report("affixes.%s: affix_id 필드값이 키와 불일치" % affix_id)
		if entry.has("value_min") and entry.has("value_max") \
				and float(entry["value_min"]) > float(entry["value_max"]):
			_report("affixes.%s: value_min(%s) > value_max(%s)" % [affix_id, entry["value_min"], entry["value_max"]])
		if float(entry.get("weight", 0)) <= 0.0:
			_report("affixes.%s: weight는 0보다 커야 함 (현재 %s)" % [affix_id, entry.get("weight")])
		for cat: String in (entry.get("applicable_categories", []) as Array):
			if not ITEM_CATEGORIES.has(cat):
				_report("affixes.%s: applicable_categories의 '%s' 가 items 카테고리 enum에 없음" % [affix_id, cat])
		stat_types[String(entry.get("stat_type", ""))] = true
	if stat_types.size() < 20:
		_report("affixes: stat_type 종류가 %d개 (GDD 6.3 '20종' 미달)" % stat_types.size())


## drop_tables.json 검증(validate_tables.py:validate_drop_tables() 이식) — LUK 계수
## 단조증가, grade_base_weight 합계 1.0, entries 참조 무결성, 빈 드랍 풀 방지(D-67 원인이
## 됐던 실제 버그), gold_drop 범위.
func _validate_drop_tables() -> void:
	if not tables.has("drop_tables"):
		return
	var drop_tables: Dictionary = tables["drop_tables"]
	var items: Dictionary = tables.get("items", {})

	if drop_tables.has("_luck_formula") and typeof(drop_tables["_luck_formula"]) == TYPE_DICTIONARY:
		var luk: Dictionary = drop_tables["_luck_formula"]
		var coeff: Dictionary = luk.get("luk_coefficient", {})
		var ordered: Array = []
		for grade: String in ITEM_GRADES:
			if grade == "common":
				continue
			if not coeff.has(grade):
				_report("drop_tables._luck_formula.luk_coefficient: '%s' 계수 없음" % grade)
				continue
			if float(coeff[grade]) <= 0.0:
				_report("drop_tables._luck_formula.luk_coefficient.%s: 0보다 커야 함" % grade)
			ordered.append(grade)
		for i in range(ordered.size() - 1):
			var a: String = ordered[i]
			var b: String = ordered[i + 1]
			if float(coeff[a]) >= float(coeff[b]):
				_report("drop_tables._luck_formula.luk_coefficient: %s(%s) >= %s(%s) - 등급이 높을수록 커야 함" \
					% [a, coeff[a], b, coeff[b]])
	else:
		_report("drop_tables: 최상단 '_luck_formula' 필드 없음 (D-52 단일 소스 위반)")

	for source_id: String in drop_tables:
		if source_id.begins_with("_"):
			continue
		if typeof(drop_tables[source_id]) != TYPE_DICTIONARY:
			_report("drop_tables.%s 가 객체가 아님" % source_id)
			continue
		var table: Dictionary = drop_tables[source_id]
		if String(table.get("source_id", "")) != source_id:
			_report("drop_tables.%s: source_id 필드값이 키와 불일치" % source_id)

		var entries: Array = table.get("entries", [])
		var gbw: Variant = table.get("grade_base_weight")
		if typeof(gbw) != TYPE_DICTIONARY:
			_report("drop_tables.%s: grade_base_weight 없음" % source_id)
		else:
			var gbw_dict: Dictionary = gbw
			var missing: Array = []
			for g: String in ITEM_GRADES:
				if not gbw_dict.has(g):
					missing.append(g)
			if not missing.is_empty():
				_report("drop_tables.%s: grade_base_weight에 등급 누락 %s" % [source_id, missing])
			var total := 0.0
			for g2: String in ITEM_GRADES:
				total += float(gbw_dict.get(g2, 0.0))
			if abs(total - 1.0) > 1e-6:
				_report("drop_tables.%s: grade_base_weight 합계=%s (1.0이어야 함)" % [source_id, total])
			var covered_grades: Dictionary = {}
			for e: Dictionary in entries:
				var iid: String = String(e.get("item_id", ""))
				if items.has(iid):
					covered_grades[String((items[iid] as Dictionary).get("grade", ""))] = true
			for g3: String in ITEM_GRADES:
				if float(gbw_dict.get(g3, 0.0)) > 0.0 and not covered_grades.has(g3):
					_report("drop_tables.%s: grade_base_weight.%s>0 인데 entries에 해당 등급 아이템이 하나도 없음(드랍 시 빈 풀)" \
						% [source_id, g3])

		for e2: Dictionary in entries:
			var item_id: String = String(e2.get("item_id", ""))
			if not items.has(item_id):
				_report("drop_tables.%s: entries의 item_id '%s' 가 items.json에 없음" % [source_id, item_id])
			if float(e2.get("weight", 0)) <= 0.0:
				_report("drop_tables.%s: entries[%s].weight는 0보다 커야 함" % [source_id, item_id])
			if e2.has("qty_min") and e2.has("qty_max") and int(e2["qty_min"]) > int(e2["qty_max"]):
				_report("drop_tables.%s: entries[%s] qty_min(%s) > qty_max(%s)" \
					% [source_id, item_id, e2["qty_min"], e2["qty_max"]])

		var gold: Variant = table.get("gold_drop")
		if typeof(gold) == TYPE_DICTIONARY:
			var gold_dict: Dictionary = gold
			if float(gold_dict.get("min", 0)) > float(gold_dict.get("max", 0)):
				_report("drop_tables.%s: gold_drop.min > gold_drop.max" % source_id)
			if float(gold_dict.get("min", 0)) < 0.0:
				_report("drop_tables.%s: gold_drop.min < 0" % source_id)


## enhance.json 검증(validate_tables.py:validate_enhance() 이식) — D-14 성공률 고정값,
## 배율 단조증가, D-13 재련 3회 상한(common 제외), 분해 산출 단조증가.
func _validate_enhance() -> void:
	if not tables.has("enhance"):
		return
	var enhance: Dictionary = tables["enhance"]
	var levels: Dictionary = enhance.get("enhance_levels", {})

	for lv: String in ["+1", "+2", "+3", "+4", "+5", "+6"]:
		var rate: Variant = (levels.get(lv, {}) as Dictionary).get("success_rate")
		if rate != 1.0:
			_report("enhance.enhance_levels.%s.success_rate=%s (D-14: +1~+6은 1.0이어야 함)" % [lv, rate])
	var expected_rates: Dictionary = {"+7": 0.70, "+8": 0.55, "+9": 0.40, "+10": 0.25}
	for lv2: String in expected_rates:
		var rate2: Variant = (levels.get(lv2, {}) as Dictionary).get("success_rate")
		if rate2 != expected_rates[lv2]:
			_report("enhance.enhance_levels.%s.success_rate=%s (D-14 고정값 %s 위반)" % [lv2, rate2, expected_rates[lv2]])

	var prev_mult := 0.0
	for lv3: String in ["+1", "+2", "+3", "+4", "+5", "+6", "+7", "+8", "+9", "+10"]:
		if not levels.has(lv3):
			_report("enhance.enhance_levels: '%s' 단계 없음" % lv3)
			continue
		var mult: float = float((levels[lv3] as Dictionary).get("stat_multiplier", 0.0))
		if mult <= prev_mult:
			_report("enhance.enhance_levels.%s.stat_multiplier=%s 가 이전 단계(%s) 이하 - 단조증가 위반" % [lv3, mult, prev_mult])
		prev_mult = mult

	var refine: Dictionary = enhance.get("refine", {})
	if int(refine.get("max_attempts", -1)) != 3:
		_report("enhance.refine.max_attempts=%s (D-13: 3이어야 함)" % refine.get("max_attempts"))
	var cost_by_grade: Dictionary = refine.get("cost_by_grade_and_attempt", {})
	if cost_by_grade.has("common"):
		_report("enhance.refine.cost_by_grade_and_attempt: 'common'은 affix_slot_count=0이라 재련 대상이 아님")

	var yields: Dictionary = (enhance.get("disassemble", {}) as Dictionary).get("yield_by_grade", {})
	var prev_stone := -1
	var prev_mat := -1
	for grade: String in ITEM_GRADES:
		if not yields.has(grade):
			_report("enhance.disassemble.yield_by_grade: '%s' 없음" % grade)
			continue
		var y: Dictionary = yields[grade]
		var stone: int = int(y.get("stone_qty", 0))
		var mat: int = int(y.get("material_qty", 0))
		if stone <= prev_stone:
			_report("enhance.disassemble.yield_by_grade.%s.stone_qty가 이전 등급 이하 - 단조증가 위반" % grade)
		if mat <= prev_mat:
			_report("enhance.disassemble.yield_by_grade.%s.material_qty가 이전 등급 이하 - 단조증가 위반" % grade)
		prev_stone = stone
		prev_mat = mat


## stats.json 검증(elite-and-farming-m2.md §4-3 규칙 1~3. 규칙4 "defense_formula가
## 실제 피해 계산에 연결되지 않았는지"는 런타임 검증 불가라 코드 리뷰 항목으로 남긴다).
func _validate_stats() -> void:
	if not tables.has("stats"):
		return
	var stats: Dictionary = tables["stats"]

	var dex: Dictionary = stats.get("dex", {})
	var formula: String = String(dex.get("stamina_cost_reduction_formula", ""))
	if formula != DEX_ROLL_COST_FORMULA_CANONICAL:
		_report("stats.dex.stamina_cost_reduction_formula='%s' 가 D-45 정본 문자열('%s')과 다름" \
			% [formula, DEX_ROLL_COST_FORMULA_CANONICAL])

	var luk: Dictionary = stats.get("luk", {})
	if String(luk.get("_luck_formula_ref", "")) != "drop_tables.json":
		_report("stats.luk._luck_formula_ref='%s' (D-52/D-78 예정: 'drop_tables.json' 고정값이어야 함)" \
			% luk.get("_luck_formula_ref"))
	if luk.has("drop_weight_formula"):
		_report("stats.luk.drop_weight_formula 필드가 존재함 — D-52/D-78(예정) 위반(공식은 drop_tables.json 하나에만 존재해야 함)")

	# *_cap 계열은 0~1 범위(비율).
	if luk.has("crit_chance_cap"):
		var crit_cap: float = float(luk["crit_chance_cap"])
		if crit_cap < 0.0 or crit_cap > 1.0:
			_report("stats.luk.crit_chance_cap=%s 범위(0~1) 위반" % crit_cap)
	var int_stat: Dictionary = stats.get("int", {})
	if int_stat.has("cooldown_reduction_cap_pct"):
		var cd_cap: float = float(int_stat["cooldown_reduction_cap_pct"])
		if cd_cap < 0.0 or cd_cap > 1.0:
			_report("stats.int.cooldown_reduction_cap_pct=%s 범위(0~1) 위반" % cd_cap)

	# 만렙 풀분배(한 스탯 몰빵 가정: (max_level-1) × stat_points_per_levelup 포인트) 도달
	# 시에도 상한을 넘지 못하면 그 상한은 사실상 죽은 설정이다 — 에러가 아니라 경고만
	# (규칙3, _report()는 개발 빌드에서 assert까지 걸어 항상 "에러"가 되므로 여기선 쓰지
	# 않고 push_warning()을 직접 부른다).
	var max_points: float = float(stats.get("stat_points_per_levelup", 3)) \
		* float(int(stats.get("max_level", 50)) - 1)
	if luk.has("base_crit_chance") and luk.has("crit_chance_per_point") and luk.has("crit_chance_cap"):
		var projected_crit: float = float(luk["base_crit_chance"]) + max_points * float(luk["crit_chance_per_point"])
		if projected_crit <= float(luk["crit_chance_cap"]):
			push_warning("[Data] stats.luk: 만렙 몰빵(%.0f포인트) crit_chance=%.4f 가 상한(%.4f)에 못 미침 — 상한이 사실상 의미 없음" \
				% [max_points, projected_crit, luk["crit_chance_cap"]])
	if int_stat.has("cooldown_reduction_per_point") and int_stat.has("cooldown_reduction_cap_pct"):
		var projected_cd: float = max_points * float(int_stat["cooldown_reduction_per_point"])
		if projected_cd <= float(int_stat["cooldown_reduction_cap_pct"]):
			push_warning("[Data] stats.int: 만렙 몰빵 cooldown_reduction=%.4f 가 상한(%.4f)에 못 미침 — 상한이 사실상 의미 없음" \
				% [projected_cd, int_stat["cooldown_reduction_cap_pct"]])


## farming_sources.json 검증(elite-and-farming-m2.md §4-2 규칙 1~4).
func _validate_farming_sources() -> void:
	if not tables.has("farming_sources"):
		return
	var farming: Dictionary = tables["farming_sources"]
	var drop_tables: Dictionary = tables.get("drop_tables", {})
	var monsters: Dictionary = tables.get("monsters", {})

	for source_id: String in farming:
		if source_id.begins_with("_"):
			continue
		if typeof(farming[source_id]) != TYPE_DICTIONARY:
			_report("farming_sources.%s 가 객체가 아님" % source_id)
			continue
		var entry: Dictionary = farming[source_id]
		var type: String = String(entry.get("type", ""))
		var respawn: int = int(entry.get("respawn_seconds", -1))
		if respawn < 0:
			_report("farming_sources.%s: respawn_seconds는 0 이상이어야 함 (현재 %s)" % [source_id, respawn])
		if FARMING_TYPE_RESPAWN_SECONDS.has(type) and respawn != int(FARMING_TYPE_RESPAWN_SECONDS[type]):
			_report("farming_sources.%s: type='%s'의 respawn_seconds=%d 가 GDD 6.5 기준값(%d)과 다름" \
				% [source_id, type, respawn, FARMING_TYPE_RESPAWN_SECONDS[type]])

		# 규칙2: reward_table_ids 원소는 drop_tables.json 실제 source_id여야 한다.
		# (type=gathering이거나 아직 보상 미확정 소스는 배열이 비어 있어 자연히 통과한다.)
		for list_field: String in ["first_clear_reward_table_ids", "repeat_reward_table_ids"]:
			for ref_id: Variant in (entry.get(list_field, []) as Array):
				if not drop_tables.has(String(ref_id)):
					_report("farming_sources.%s.%s: '%s' 가 drop_tables.json에 없음" % [source_id, list_field, ref_id])

		# 규칙3: type=elite는 monsters.json에 tier=elite이고 drop_table_id가 이 소스의
		# repeat_reward_table_ids[0]과 일치하는 엔트리가 최소 1개 있어야 한다.
		if type == "elite":
			var repeat_ids: Array = entry.get("repeat_reward_table_ids", [])
			var expected_drop_table: String = String(repeat_ids[0]) if not repeat_ids.is_empty() else ""
			var found := false
			for monster_id: String in monsters:
				if monster_id.begins_with("_"):
					continue
				var m: Dictionary = monsters[monster_id]
				if typeof(m) != TYPE_DICTIONARY or String(m.get("tier", "")) != "elite":
					continue
				# M2-7: drop_table_id가 null인 정예(예: horn_rabbit_big, D-95 F6-3 예외 —
				# 확정된 파밍 드랍이 없는 스토리 전용 정예)에 String()을 바로 호출하면
				# "Invalid call 'String' constructor" 런타임 에러가 난다 — null은 이
				# 규칙(farming_sources 연동 대상) 자체가 아니므로 조용히 건너뛴다.
				var m_drop_table_id: Variant = m.get("drop_table_id")
				if m_drop_table_id != null and String(m_drop_table_id) == expected_drop_table:
					found = true
					break
			if not found:
				_report("farming_sources.%s: type=elite인데 tier='elite'·drop_table_id='%s'인 monsters.json 엔트리가 없음" \
					% [source_id, expected_drop_table])

		# 규칙4: show_respawn_icon_on_map은 elite/world_boss 타입과 정확히 일치해야 한다.
		var show_icon: bool = bool(entry.get("show_respawn_icon_on_map", false))
		var expected_icon: bool = FARMING_MAP_ICON_TYPES.has(type)
		if show_icon != expected_icon:
			_report("farming_sources.%s: show_respawn_icon_on_map=%s 가 type='%s' 기준(%s)과 다름" \
				% [source_id, show_icon, type, expected_icon])


## blueprints.json 검증(F3-4, M2-4 신설 — tools/qa/validate_tables.py:validate_blueprints()
## 이식). result_item_id/materials[].item_id 참조 무결성, cost_gold·qty 범위.
func _validate_blueprints() -> void:
	if not tables.has("blueprints"):
		return
	var blueprints: Dictionary = tables["blueprints"]
	var items: Dictionary = tables.get("items", {})
	for blueprint_id: String in blueprints:
		if blueprint_id.begins_with("_"):
			continue
		if typeof(blueprints[blueprint_id]) != TYPE_DICTIONARY:
			_report("blueprints.%s 가 객체가 아님" % blueprint_id)
			continue
		var entry: Dictionary = blueprints[blueprint_id]
		for field: String in ["blueprint_id", "name_key", "desc_key", "result_item_id", "cost_gold", "materials"]:
			if not entry.has(field):
				_report("blueprints.%s: 필수 키 누락 '%s'" % [blueprint_id, field])
		if String(entry.get("blueprint_id", "")) != blueprint_id:
			_report("blueprints.%s: blueprint_id 필드값이 키와 불일치" % blueprint_id)
		var result_item_id: String = String(entry.get("result_item_id", ""))
		if entry.has("result_item_id") and not items.has(result_item_id):
			_report("blueprints.%s: result_item_id '%s' 가 items.json에 없음" % [blueprint_id, result_item_id])
		if float(entry.get("cost_gold", 0)) < 0.0:
			_report("blueprints.%s: cost_gold는 0 이상이어야 함" % blueprint_id)
		for material: Dictionary in (entry.get("materials", []) as Array):
			var mat_id: String = String(material.get("item_id", ""))
			if not items.has(mat_id):
				_report("blueprints.%s: materials의 item_id '%s' 가 items.json에 없음" % [blueprint_id, mat_id])
			if int(material.get("qty", 0)) <= 0:
				_report("blueprints.%s: materials[%s].qty는 0보다 커야 함" % [blueprint_id, mat_id])


## pools.json 검증(F5-2 게시판 일일 의뢰, D-97 신설) — 구성원 참조 무결성(kind에 따라
## monsters.json/items.json)과 가중치 합 검증(0보다 커야 추첨 가능).
func _validate_pools() -> void:
	if not tables.has("pools"):
		return
	var pools: Dictionary = tables["pools"]
	var monsters: Dictionary = tables.get("monsters", {})
	var items: Dictionary = tables.get("items", {})
	for pool_id: String in pools:
		if pool_id.begins_with("_"):
			continue
		if typeof(pools[pool_id]) != TYPE_DICTIONARY:
			_report("pools.%s 가 객체가 아님" % pool_id)
			continue
		var entry: Dictionary = pools[pool_id]
		if String(entry.get("pool_id", "")) != pool_id:
			_report("pools.%s: pool_id 필드값이 키와 불일치" % pool_id)
		var kind: String = String(entry.get("kind", ""))
		if kind != "monster" and kind != "item":
			_report("pools.%s: kind '%s' 는 'monster'|'item' 중 하나여야 함" % [pool_id, kind])
		var members: Variant = entry.get("members")
		if typeof(members) != TYPE_ARRAY or (members as Array).is_empty():
			_report("pools.%s: members가 비어있거나 배열이 아님" % pool_id)
			continue
		var total_weight := 0.0
		for member: Dictionary in (members as Array):
			var member_id: String = String(member.get("id", ""))
			var weight: float = float(member.get("weight", 0.0))
			if weight <= 0.0:
				_report("pools.%s: members '%s'의 weight(%s)는 0보다 커야 함" % [pool_id, member_id, weight])
			total_weight += weight
			if kind == "monster" and not monsters.has(member_id):
				_report("pools.%s: monster 풀 구성원 '%s' 가 monsters.json에 없음" % [pool_id, member_id])
			elif kind == "item" and not items.has(member_id):
				_report("pools.%s: item 풀 구성원 '%s' 가 items.json에 없음" % [pool_id, member_id])
		if total_weight <= 0.0:
			_report("pools.%s: 전체 weight 합이 0 이하 - 추첨 불가(D-97 가중치 합 검증)" % pool_id)


## world_objects.json 검증(F5-1/F5-2, M2-8 신설, level-designer 소유). id 키의 동적
## 딕셔너리 — kind별 필수 필드(pools/blueprints와 동일 "존재만 REQUIRED_SCHEMA, 필드는
## 여기" 패턴)와 position이 [x, y] 2요소 배열인지 확인한다. QuestSystem이 참조하는
## kind 값과 여기 kind 값이 일치하는지는 _validate_quests()가 교차 검증한다.
func _validate_world_objects() -> void:
	if not tables.has("world_objects"):
		return
	var world_objects: Dictionary = tables["world_objects"]
	var valid_kinds := ["location", "object", "npc"]
	for object_id: String in world_objects:
		if object_id.begins_with("_"):
			continue
		if typeof(world_objects[object_id]) != TYPE_DICTIONARY:
			_report("world_objects.%s 가 객체가 아님" % object_id)
			continue
		var entry: Dictionary = world_objects[object_id]
		if String(entry.get("id", "")) != object_id:
			_report("world_objects.%s: id 필드값이 키와 불일치" % object_id)
		var kind: String = String(entry.get("kind", ""))
		if not valid_kinds.has(kind):
			_report("world_objects.%s: kind '%s' 는 'location'|'object'|'npc' 중 하나여야 함" % [object_id, kind])
		if String(entry.get("scene", "")).is_empty():
			_report("world_objects.%s: scene 경로 누락" % object_id)
		if not entry.has("region_id") or String(entry.get("region_id", "")).is_empty():
			_report("world_objects.%s: region_id 누락" % object_id)
		var position: Variant = entry.get("position")
		if typeof(position) != TYPE_ARRAY or (position as Array).size() != 2:
			_report("world_objects.%s: position이 [x, y] 2요소 배열이 아님" % object_id)


## game/data/quests/*.json 검증(F5-1/F5-2, M2-7 신설, M2-8에서 npc:/location:/object:
## 확장 — docs/specs/quest-data-schema.md §3 검증 체크리스트 이식). quest_id 중복은
## _load_quests()가 병합 시점에 이미 보고한다(이 함수는 그 이후 필드 단위 규칙만 본다).
## npc:/location:/object: 접두어 target은 world_objects.json(M2-8, level-designer
## 소유)의 id·kind와 대조한다 — quest-system-m2.md §10이 "형식만 두고 값은 검사하지
## 않는다"고 적었던 부분을 world_objects.json 도입으로 채운다.
func _validate_quests() -> void:
	if not tables.has("quests"):
		return
	var quests: Dictionary = tables["quests"]
	var monsters: Dictionary = tables.get("monsters", {})
	var items: Dictionary = tables.get("items", {})
	var pools: Dictionary = tables.get("pools", {})
	var world_objects: Dictionary = tables.get("world_objects", {})
	var todo_monsters: Array = quest_todo_ids.get("monsters", [])
	var todo_items: Array = quest_todo_ids.get("items", [])
	var todo_pools: Array = quest_todo_ids.get("pools", [])
	# M2-8: world_objects.json이 생기기 전에 남아있던 미해결 항목 통로(_todo_ids.locations/
	# .objects/.npcs) — level-designer가 아직 만들지 않은 지역용으로 계속 유효하다.
	var todo_locations: Array = quest_todo_ids.get("locations", [])
	var todo_objects: Array = quest_todo_ids.get("objects", [])
	var todo_npcs: Array = quest_todo_ids.get("npcs", [])

	for quest_id: String in quests:
		if quest_id.begins_with("_"):
			continue
		if typeof(quests[quest_id]) != TYPE_DICTIONARY:
			_report("quests.%s 가 객체가 아님" % quest_id)
			continue
		var entry: Dictionary = quests[quest_id]
		if String(entry.get("id", "")) != quest_id:
			_report("quests.%s: id 필드값이 키와 불일치" % quest_id)

		var type: String = String(entry.get("type", ""))
		if type == "main" and not (entry.get("fail_conditions", []) as Array).is_empty():
			_report("quests.%s: type=main인데 fail_conditions가 비어있지 않음(F5-1 '메인 포기 불가' 위반)" % quest_id)
		var repeatable: bool = bool(entry.get("repeatable", false))
		if type == "daily_template" and not repeatable:
			_report("quests.%s: type=daily_template인데 repeatable=false (스키마 체크리스트 위반)" % quest_id)
		elif type != "daily_template" and repeatable:
			_report("quests.%s: type=%s인데 repeatable=true (daily_template만 가능)" % [quest_id, type])

		for prereq_id: Variant in ((entry.get("prerequisites", {}) as Dictionary).get("quests_completed", []) as Array):
			if not quests.has(String(prereq_id)):
				_report("quests.%s: prerequisites.quests_completed의 '%s' 가 존재하지 않는 퀘스트 id" % [quest_id, prereq_id])

		for objective: Dictionary in (entry.get("objectives", []) as Array):
			var target: String = String(objective.get("target", ""))
			if target.begins_with("monster:"):
				var monster_ref: String = target.substr(len("monster:"))
				if not monsters.has(monster_ref) and not todo_monsters.has(monster_ref):
					_report("quests.%s: objective target '%s' 가 monsters.json/_todo_ids.monsters 어디에도 없음" % [quest_id, target])
			elif target.begins_with("item:"):
				var item_ref: String = target.substr(len("item:"))
				if not items.has(item_ref) and not todo_items.has(item_ref):
					_report("quests.%s: objective target '%s' 가 items.json/_todo_ids.items 어디에도 없음" % [quest_id, target])
			elif target.begins_with("pool:"):
				var pool_ref: String = target.substr(len("pool:"))
				if not pools.has(pool_ref) and not todo_pools.has(pool_ref):
					_report("quests.%s: objective target '%s' 가 pools.json/_todo_ids.pools 어디에도 없음" % [quest_id, target])
			elif target.begins_with("location:"):
				_check_world_object_ref(quest_id, target, target.substr(len("location:")),
					"location", world_objects, todo_locations, "_todo_ids.locations")
			elif target.begins_with("object:"):
				_check_world_object_ref(quest_id, target, target.substr(len("object:")),
					"object", world_objects, todo_objects, "_todo_ids.objects")
			elif target.begins_with("npc:"):
				_check_world_object_ref(quest_id, target, target.substr(len("npc:")),
					"npc", world_objects, todo_npcs, "_todo_ids.npcs")

		for reward_item: Dictionary in ((entry.get("rewards", {}) as Dictionary).get("items", []) as Array):
			var reward_item_id: String = String(reward_item.get("id", ""))
			if not items.has(reward_item_id) and not todo_items.has(reward_item_id):
				_report("quests.%s: rewards.items의 '%s' 가 items.json/_todo_ids.items 어디에도 없음" % [quest_id, reward_item_id])

		# giver도 사실상 npc 참조다("system"은 예외 — 자동 발동 퀘스트, giver NPC 없음).
		var giver: String = String(entry.get("giver", ""))
		if not giver.is_empty() and giver != "system":
			_check_world_object_ref(quest_id, "giver:%s" % giver, giver,
				"npc", world_objects, todo_npcs, "_todo_ids.npcs")


## quests.<id>의 location:/object:/npc: 참조 1건을 world_objects.json(M2-8)과 대조한다.
## world_objects에 있으면 kind가 기대한 값과 일치하는지까지 확인하고, 없으면 아직
## level-designer가 만들지 않은 지역으로 보고 _todo_ids 목록에 있는지만 확인한다(둘 다
## 없으면 위반).
func _check_world_object_ref(quest_id: String, target_label: String, ref_id: String,
		expected_kind: String, world_objects: Dictionary, todo_ids: Array, todo_field_label: String) -> void:
	if world_objects.has(ref_id):
		var kind: String = String((world_objects[ref_id] as Dictionary).get("kind", ""))
		if kind != expected_kind:
			_report("quests.%s: '%s' 가 world_objects.%s인데 kind='%s'(기대값 '%s')" \
				% [quest_id, target_label, ref_id, kind, expected_kind])
		return
	if not todo_ids.has(ref_id):
		_report("quests.%s: '%s' 가 world_objects.json/%s 어디에도 없음" % [quest_id, target_label, todo_field_label])


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
		# addendum §2-1 확정(D-61 예정): 피격 경직은 무적시간보다 길 수 없다(스턴락 방지).
		if has_value("combat", "hurt.stun_sec") and has_value("combat", "hurt.iframes_sec"):
			var stun_sec: float = float(get_value("combat", "hurt.stun_sec"))
			var iframes_sec: float = float(get_value("combat", "hurt.iframes_sec"))
			if not (stun_sec <= iframes_sec):
				_report("hurt.stun_sec(%s) <= hurt.iframes_sec(%s) 위반" % [stun_sec, iframes_sec])
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
