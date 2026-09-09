## 플레이테스트 계측 로깅 오토로드(M1-4, docs/qa/m1-gate-playtest.md §4).
##
## Events 시그널 구독만으로 데이터를 모은다(게임 로직 수정은 최소 — 필요한 신호 3개만
## events.gd에 새로 추가하고 각각 발신 지점 1곳씩만 연결했다: player_roll_started,
## guard_hit_attempted, combo_finisher_reached — 나머지는 기존 신호(player_died/
## player_damaged/just_guard_succeeded/player_guarded/hit_landed/enemy_died)를 그대로 쓴다).
##
## 실제 카운터 → 성공률/평균 TTK/JSON 변환은 순수 함수인 scripts/systems/metrics_calc.gd
## (MetricsCalc)에 위임한다 — 이 스크립트는 "언제 무엇을 셀지"만 담당해 GUT에서 계산
## 로직만 노드 없이 테스트할 수 있게 한다.
##
## 출력 시점: 5분마다(Timer) + 세션 종료 시(_exit_tree/NOTIFICATION_WM_CLOSE_REQUEST) 같은
## 파일(user://playtest/session_<세션 시작 유닉스초>.json)에 덮어쓴다(다회 저장 시 파일이
## 계속 늘어나지 않도록). 파일의 실제 위치(README.md 기록 대상):
##   Windows: %APPDATA%\Godot\app_userdata\이슬란드 연대기\playtest\
##   macOS:   ~/Library/Application Support/Godot/app_userdata/이슬란드 연대기/playtest/
##   Linux:   ~/.local/share/godot/app_userdata/이슬란드 연대기/playtest/
## (project.godot의 application/config/name 기준 폴더명 — 실제 값은 README.md에서 확인.)
extends Node

const SAVE_INTERVAL_SEC := 300.0 ## 5분.
const PLAYTEST_DIR := "user://playtest"
const TESTER_FILE_PATH := "user://playtest/tester.txt"

var tester_name: String = "anon"
var session_start_unix: int = 0
var _session_start_ticks_msec: int = 0
var _session_file_path: String = ""
var _did_final_save: bool = false

# --- raw 카운터 (MetricsCalc.build_summary()의 입력 스키마와 1:1 대응) ---
var _deaths: int = 0
var _roll_attempts: int = 0
var _roll_iframe_hits: int = 0
## 가장 최근 구르기의 무적 프레임 만료 시각(get_ticks_msec 기준). 그 전까지 발생하는
## player_damaged는 "무적 구간 중 피격"으로 센다(§4 구르기 성공률 정의).
var _roll_iframe_expires_at_ticks: int = -1
var _guard_attempts: int = 0
var _just_guard_success: int = 0
var _normal_guard_count: int = 0
var _combo_finisher_reached_count: int = 0
var _player_hits_taken: int = 0
var _player_damage_taken_total: int = 0
var _kills_by_monster: Dictionary = {} ## {monster_id: int}
## M2-3 신규(F6-3). Events.elite_died 전용 카운터 — enemy_died와 별개로 "정예만" 센다.
var _elite_kills_by_monster: Dictionary = {} ## {monster_id: int}
var _ttk_samples_by_monster: Dictionary = {} ## {monster_id: Array[float]}
## 몬스터 인스턴스 최초 피격 시각(get_ticks_msec). 죽으면 TTK 계산 후 제거된다.
## 키는 get_instance_id()(해제된 인스턴스를 다시 조회하지 않기 위해 Node 참조 대신 id 사용).
var _monster_first_hit_ticks: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PLAYTEST_DIR)
	session_start_unix = int(Time.get_unix_time_from_system())
	_session_start_ticks_msec = Time.get_ticks_msec()
	_session_file_path = "%s/session_%d.json" % [PLAYTEST_DIR, session_start_unix]
	tester_name = _resolve_tester_name()
	print("[Metrics] 세션 시작. tester=%s, 저장 경로=%s" % [tester_name, _session_file_path])

	Events.player_died.connect(_on_player_died)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_roll_started.connect(_on_roll_started)
	Events.guard_hit_attempted.connect(_on_guard_hit_attempted)
	Events.just_guard_succeeded.connect(_on_just_guard_succeeded)
	Events.player_guarded.connect(_on_player_guarded)
	Events.combo_finisher_reached.connect(_on_combo_finisher_reached)
	Events.hit_landed.connect(_on_hit_landed)
	Events.enemy_died.connect(_on_enemy_died)
	Events.elite_died.connect(_on_elite_died)

	var timer := Timer.new()
	timer.name = "SaveIntervalTimer"
	timer.wait_time = SAVE_INTERVAL_SEC
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(_on_save_interval_timeout)
	add_child(timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_and_print()


func _exit_tree() -> void:
	_save_and_print()


func _on_save_interval_timeout() -> void:
	_save_and_print()


# --- Events 구독 핸들러 (수집만, 판단 로직은 metrics_calc.gd) ---

func _on_player_died() -> void:
	_deaths += 1


func _on_roll_started(_player: Node) -> void:
	_roll_attempts += 1
	var iframes_sec: float = float(Data.get_value("combat", "roll.iframes_sec", 0.3))
	_roll_iframe_expires_at_ticks = Time.get_ticks_msec() + int(round(iframes_sec * 1000.0))


func _on_player_damaged(amount: int, _source: Node) -> void:
	_player_hits_taken += 1
	_player_damage_taken_total += amount
	# ignores_iframes 히트박스(포자 장판 등)는 무적 중에도 player_damaged를 낼 수 있다
	# (D-61, 의도된 동작) — 그 경우를 포함해 "무적 구간 중 피격"으로 집계한다.
	if _roll_iframe_expires_at_ticks >= 0 and Time.get_ticks_msec() <= _roll_iframe_expires_at_ticks:
		_roll_iframe_hits += 1


func _on_guard_hit_attempted(_defender: Node, _attacker: Node) -> void:
	_guard_attempts += 1


func _on_just_guard_succeeded(_defender: Node, _attacker: Node) -> void:
	_just_guard_success += 1


func _on_player_guarded(_amount: int, is_just: bool) -> void:
	if not is_just:
		_normal_guard_count += 1


func _on_combo_finisher_reached(_player: Node) -> void:
	_combo_finisher_reached_count += 1


## hit_landed는 플레이어→몬스터/몬스터→플레이어 양쪽에서 발신된다 — target이 몬스터일
## 때만 "이 개체가 처음 맞은 시각"을 기록한다(TTK = 최초 피격 → 사망, 요청 스펙 그대로).
func _on_hit_landed(_attacker: Node, target: Node, _damage: int, _is_advantage: bool, _is_critical: bool) -> void:
	if target == null or not (target is MonsterBase):
		return
	var id: int = target.get_instance_id()
	if not _monster_first_hit_ticks.has(id):
		_monster_first_hit_ticks[id] = Time.get_ticks_msec()


func _on_enemy_died(enemy: Node2D, _killer: Node) -> void:
	if enemy == null or not (enemy is MonsterBase):
		return
	var monster_id: String = (enemy as MonsterBase).monster_id
	_kills_by_monster[monster_id] = int(_kills_by_monster.get(monster_id, 0)) + 1

	var id: int = enemy.get_instance_id()
	if _monster_first_hit_ticks.has(id):
		var elapsed_sec: float = float(Time.get_ticks_msec() - int(_monster_first_hit_ticks[id])) / 1000.0
		var samples: Array = _ttk_samples_by_monster.get(monster_id, [])
		samples.append(elapsed_sec)
		_ttk_samples_by_monster[monster_id] = samples
		_monster_first_hit_ticks.erase(id)


## M2-3 신규(F6-3). enemy_died와 별개로 "정예 처치"만 센다.
func _on_elite_died(enemy: Node2D, _killer: Node) -> void:
	if enemy == null or not (enemy is MonsterBase):
		return
	var monster_id: String = (enemy as MonsterBase).monster_id
	_elite_kills_by_monster[monster_id] = int(_elite_kills_by_monster.get(monster_id, 0)) + 1


# --- 테스터 식별 ---

func _resolve_tester_name() -> String:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in args:
		var s := String(arg)
		if s.begins_with("--tester="):
			var name := s.substr("--tester=".length()).strip_edges()
			if not name.is_empty():
				_save_tester_name(name)
				return name
	var saved := _read_saved_tester_name()
	if not saved.is_empty():
		return saved
	return "anon"


func _save_tester_name(name: String) -> void:
	var f := FileAccess.open(TESTER_FILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(name)


func _read_saved_tester_name() -> String:
	if not FileAccess.file_exists(TESTER_FILE_PATH):
		return ""
	var f := FileAccess.open(TESTER_FILE_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text().strip_edges()


# --- 요약/저장 ---

## HUD 등 다른 시스템이 나중에 읽을 수 있도록 공개 API로 노출(요청 스펙: "Metrics.summary()가
## Dictionary 반환"). 순수 계산은 MetricsCalc.build_summary()에 위임.
func summary() -> Dictionary:
	return MetricsCalc.build_summary(_build_raw_snapshot())


func _build_raw_snapshot() -> Dictionary:
	return {
		"tester": tester_name,
		"session_start_unix": session_start_unix,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"session_duration_sec": float(Time.get_ticks_msec() - _session_start_ticks_msec) / 1000.0,
		"deaths": _deaths,
		"roll_attempts": _roll_attempts,
		"roll_iframe_hits": _roll_iframe_hits,
		"guard_attempts": _guard_attempts,
		"just_guard_success": _just_guard_success,
		"normal_guard_count": _normal_guard_count,
		"combo_finisher_reached_count": _combo_finisher_reached_count,
		"player_hits_taken": _player_hits_taken,
		"player_damage_taken_total": _player_damage_taken_total,
		"kills_by_monster": _kills_by_monster,
		"ttk_samples_by_monster": _ttk_samples_by_monster,
		"elite_kills_by_monster": _elite_kills_by_monster,
	}


func _save_and_print() -> void:
	var data := summary()
	_write_json(data)
	_print_summary(data)
	_did_final_save = true


func _write_json(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(PLAYTEST_DIR)
	var f := FileAccess.open(_session_file_path, FileAccess.WRITE)
	if f == null:
		push_error("[Metrics] 저장 실패: %s (err=%s)" % [_session_file_path, str(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))


func _print_summary(data: Dictionary) -> void:
	print("=== [Metrics] 플레이테스트 요약 (tester=%s) ===" % data.get("tester", "anon"))
	print("세션 길이: %.1fs, 사망: %d" % [data.get("session_duration_sec", 0.0), data.get("deaths", 0)])
	var roll: Dictionary = data.get("roll", {})
	print("구르기: 시도=%d 성공=%d 성공률=%.0f%% (무적중 피격=%d)" % [
		roll.get("attempts", 0), roll.get("success", 0),
		roll.get("success_rate", 0.0) * 100.0, roll.get("iframe_hits", 0)])
	var guard: Dictionary = data.get("guard", {})
	print("가드: 저스트 시도=%d 성공=%d 성공률=%.0f%%, 일반 가드=%d" % [
		guard.get("just_guard_attempts", 0), guard.get("just_guard_success", 0),
		guard.get("just_guard_success_rate", 0.0) * 100.0, guard.get("normal_guard_count", 0)])
	print("콤보 3타 완주: %d회" % data.get("combo_finisher_reached_count", 0))
	var player: Dictionary = data.get("player", {})
	print("플레이어 피격: %d회, 총 피해: %d" % [player.get("hits_taken", 0), player.get("damage_taken_total", 0)])
	var monsters: Dictionary = data.get("monsters", {})
	for monster_id in monsters.keys():
		var m: Dictionary = monsters[monster_id]
		print("몬스터[%s]: 처치=%d, 평균 TTK=%.2fs" % [monster_id, m.get("kills", 0), m.get("avg_ttk_sec", 0.0)])
	print("=== [Metrics] 저장: %s ===" % _session_file_path)
