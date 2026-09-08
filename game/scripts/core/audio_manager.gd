## 오디오 자동로드(docs/audio/audio-spec.md §6). SFX/BGM 재생, 지역·전투 BGM 크로스페이드,
## 동시 재생 상한(이벤트별 max_voices + 쿨다운)을 관리한다.
##
## 데이터 원본: res://data/audio_sfx.json, res://data/audio_bgm.json (Data 오토로드로 로드
## — 파일 경로·dB·피치 범위를 이 스크립트에 하드코딩하지 않는다, GDD 12장 원칙).
##
## 헤드리스(--headless) 환경에서는 실제 AudioStreamPlayer를 스폰하지 않고 재생 요청을
## print()로만 로그한다(작업 지시 "헤드리스에서는 재생 요청 로그 모드") — CI/스모크
## 테스트에서 오디오 드라이버 유무와 무관하게 요청 자체는 검증할 수 있게 하기 위함.
##
## 직접 호출 지점(§12 — Events 구독만으로는 강공격/원소상성/가드 여부를 구분할 수 없어
## 페이로드가 부족한 경로): hit_feel.gd:apply(), player.gd:_apply_full_hit()/
## _handle_guarded_hit(), roll.gd:enter(), monster_base.gd(텔레그래프/공격/피격/사망),
## waystone.gd:_play_activation_feedback(). 안전하게 전역 구독 가능한 이벤트만 이 파일의
## _ready()에서 Events에 직접 연결한다(§6-5).
extends Node

## M1 유일 매핑(sound-map-m1.md §9). 지역이 늘어나면 audio_bgm.json에 지역→bgm_id 테이블을
## 추가하는 편이 낫다(game-designer TODO) — 지금은 상수 하나로 충분해 코드에 둔다.
const REGION_BGM := {
	"greenfield_prototype": &"bgm_grassland_1",
}

const COMBAT_POLL_INTERVAL_SEC := 0.25
const COMBAT_EXIT_GRACE_SEC := 3.0
const COMBAT_ENTER_FADE_SEC := 0.5
const COMBAT_EXIT_FADE_SEC := 2.0
const REGION_FADE_SEC := 1.5

var _headless: bool = false
var _rng := RandomNumberGenerator.new()

var _sfx_pool: Node
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _current_bgm_id: StringName = &""
var _current_region_bgm_id: StringName = &""

var _in_combat: bool = false
var _combat_exit_timer: float = -1.0

## id(StringName) → 재생 중인 노드 목록(max_voices 판정용). id(StringName) → 마지막 재생
## 시각(초, cooldown_sec 판정용).
var _active_voices: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_rng.randomize()

	_sfx_pool = Node.new()
	_sfx_pool.name = "SfxPool"
	_sfx_pool.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_pool)

	if not _headless:
		_bgm_a = AudioStreamPlayer.new()
		_bgm_a.name = "BgmA"
		_bgm_a.bus = "BGM"
		_bgm_a.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_bgm_a)
		_bgm_b = AudioStreamPlayer.new()
		_bgm_b.name = "BgmB"
		_bgm_b.bus = "BGM"
		_bgm_b.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_bgm_b)
		_bgm_active = _bgm_a

	Events.region_entered.connect(_on_region_entered)
	Events.just_guard_succeeded.connect(_on_just_guard_succeeded)
	Events.player_stamina_insufficient.connect(_on_stamina_insufficient)
	Events.player_died.connect(_on_player_died)
	Events.player_respawned.connect(_on_player_respawned)
	# F7-1(M1-5): 마스터/BGM/SFX 볼륨은 Settings(D-64 소유)가 관리한다. default_bus_layout.tres
	# 의 믹스 기준 dB(BGM -8, SFX -3)는 그대로 두고, 사용자 볼륨(0~1)을 그 위에 dB로 얹는
	# 방식이라 볼륨 1.0(기본값)일 때 기존 믹스 밸런스가 그대로 유지된다.
	Events.settings_changed.connect(_on_settings_changed)
	_apply_volume_settings()

	var poll_timer := Timer.new()
	poll_timer.name = "CombatPollTimer"
	poll_timer.wait_time = COMBAT_POLL_INTERVAL_SEC
	poll_timer.autostart = true
	poll_timer.timeout.connect(_poll_combat_state)
	add_child(poll_timer)

	# M1에는 청크/월드 스트리밍이 없어 Events.region_entered가 아직 어디서도 emit되지
	# 않는다(구독 자체는 향후 스트리밍 시스템을 위해 미리 준비해 둔 것) — 지금은 유일한
	# 지역(greenfield_prototype)의 BGM을 부팅 시 바로 재생해 M1 게이트 플레이테스트가
	# 초원 BGM을 들을 수 있게 한다. 월드 스트리밍이 이 시그널을 emit하기 시작하면 같은
	# id라 play_bgm()이 자연히 no-op 처리한다.
	_on_region_entered(&"greenfield_prototype")


## id: audio_sfx.json 키. position: Vector2.INF(기본값)면 논포지셔널(2D 감쇠 없음, UI·전역
## 이벤트용) — 그 외 값이면 해당 좌표에 AudioStreamPlayer2D를 스폰(전투·월드 SFX).
## pitch_var: -1.0(기본, 테이블의 pitch_min~max 범위 사용) 또는 호출부가 직접 범위를
## 좁히고 싶을 때 ±비율로 override.
## 반환: 실제로 재생을 시작한 AudioStreamPlayer(2D) 또는 null(테이블에 없음/우선순위
## 밀려 드롭/헤드리스 로그 모드).
func play_sfx(id: StringName, position: Vector2 = Vector2.INF, pitch_var: float = -1.0) -> Node:
	var entry: Dictionary = Data.get_value("audio_sfx", String(id), {})
	if entry.is_empty():
		# 아직 사운드가 배정되지 않은 이벤트(예: 뿔토끼/버섯돌이 전용 SFX 미제작)는
		# 흔한 상황이라 경고를 찍지 않는다 — 진짜 오류(파일 로드 실패)만 아래에서 경고.
		return null

	var now: float = Time.get_ticks_msec() / 1000.0
	var cooldown_sec: float = float(entry.get("cooldown_sec", 0.0))
	if cooldown_sec > 0.0 and _last_played.has(id) and now - float(_last_played[id]) < cooldown_sec:
		return null

	var max_voices: int = int(entry.get("max_voices", 8))
	var active: Array = (_active_voices.get(id, []) as Array).filter(func(n): return is_instance_valid(n))
	if active.size() >= max_voices:
		_active_voices[id] = active
		return null

	var files: Array = entry.get("files", [])
	if files.is_empty():
		return null
	var file: String = String(files[_rng.randi() % files.size()])

	var volume_db: float = float(entry.get("volume_db", 0.0))
	var bus: String = String(entry.get("bus", "SFX"))
	var pitch_min: float = float(entry.get("pitch_min", 1.0))
	var pitch_max: float = float(entry.get("pitch_max", 1.0))
	if pitch_var >= 0.0:
		pitch_min = 1.0 - pitch_var
		pitch_max = 1.0 + pitch_var
	var pitch: float = _rng.randf_range(pitch_min, pitch_max)

	_last_played[id] = now

	if _headless:
		print("[AudioManager] (headless) play_sfx id=%s file=%s bus=%s pos=%s pitch=%.3f" \
			% [id, file, bus, position, pitch])
		return null

	var stream: AudioStream = load(file)
	if stream == null:
		push_warning("[AudioManager] 오디오 파일 로드 실패: %s (id=%s)" % [file, id])
		return null

	var player: Node
	if position == Vector2.INF:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = bus
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		_sfx_pool.add_child(p)
		p.finished.connect(p.queue_free)
		p.play()
		player = p
	else:
		var p2 := AudioStreamPlayer2D.new()
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.global_position = position
		p2.process_mode = Node.PROCESS_MODE_ALWAYS
		_sfx_pool.add_child(p2)
		p2.finished.connect(p2.queue_free)
		p2.play()
		player = p2

	active.append(player)
	_active_voices[id] = active
	return player


## id: audio_bgm.json 키. fade: 크로스페이드 시간(초). 현재 재생 중인 id와 동일하면
## no-op(§2-2). id가 빈 문자열(&"")이면 무음으로 페이드아웃(정지 없이 볼륨만 내림).
func play_bgm(id: StringName, fade: float = 1.5) -> void:
	if id == _current_bgm_id:
		return
	if _headless:
		print("[AudioManager] (headless) play_bgm id=%s fade=%.2f" % [id, fade])
		_current_bgm_id = id
		return

	if String(id) == "":
		_fade_bgm(_bgm_active, null, fade)
		_current_bgm_id = &""
		return

	var entry: Dictionary = Data.get_value("audio_bgm", String(id), {})
	var file: String = String(entry.get("file", ""))
	if file.is_empty():
		push_warning("[AudioManager] audio_bgm.json에 없는 id: %s" % id)
		return
	var stream: AudioStream = load(file)
	if stream == null:
		push_warning("[AudioManager] BGM 파일 로드 실패: %s (id=%s)" % [file, id])
		return

	var out_player: AudioStreamPlayer = _bgm_active
	var in_player: AudioStreamPlayer = _bgm_b if _bgm_active == _bgm_a else _bgm_a
	in_player.stream = stream
	in_player.volume_db = linear_to_db(0.0001)
	in_player.play()
	_fade_bgm(out_player, in_player, fade)
	_bgm_active = in_player
	_current_bgm_id = id


## Equal-power(코사인) 크로스페이드(audio-spec.md §2-1). in_player가 null이면 out_player만
## 무음으로 페이드아웃한다(play_bgm(&"") 경로).
func _fade_bgm(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer, fade_sec: float) -> void:
	var duration: float = maxf(fade_sec, 0.01)
	var tween := create_tween()
	tween.set_parallel(true)
	if out_player != null:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(out_player):
				out_player.volume_db = linear_to_db(maxf(cos(t * PI / 2.0), 0.0001))
		, 0.0, 1.0, duration)
	if in_player != null:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(in_player):
				in_player.volume_db = linear_to_db(maxf(sin(t * PI / 2.0), 0.0001))
		, 0.0, 1.0, duration)
	if out_player != null:
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(out_player) and out_player != in_player:
				out_player.stop()
		)


func _on_region_entered(region_id: StringName) -> void:
	_current_region_bgm_id = REGION_BGM.get(String(region_id), &"")
	if not _in_combat:
		play_bgm(_current_region_bgm_id, REGION_FADE_SEC)


## 전투 진입/이탈 폴링(audio-spec.md §2-3). M1에는 전용 "전투 시작/종료" 시그널이 없어
## monster 그룹을 순회해 TELEGRAPH/ATTACK/CHASE 상태가 하나라도 있으면 전투 중으로 본다.
func _poll_combat_state() -> void:
	var any_active := false
	for m in get_tree().get_nodes_in_group(&"monster"):
		if not (m is MonsterBase):
			continue
		var s: int = (m as MonsterBase).state
		if s == MonsterBase.State.TELEGRAPH or s == MonsterBase.State.ATTACK or s == MonsterBase.State.CHASE:
			any_active = true
			break

	if any_active:
		_combat_exit_timer = -1.0
		if not _in_combat:
			_in_combat = true
			play_bgm(&"bgm_battle", COMBAT_ENTER_FADE_SEC)
		return

	if not _in_combat:
		return
	if _combat_exit_timer < 0.0:
		_combat_exit_timer = COMBAT_EXIT_GRACE_SEC
		return
	_combat_exit_timer -= COMBAT_POLL_INTERVAL_SEC
	if _combat_exit_timer <= 0.0:
		_in_combat = false
		play_bgm(_current_region_bgm_id, COMBAT_EXIT_FADE_SEC)


func _on_just_guard_succeeded(_defender: Node, _attacker: Node) -> void:
	play_sfx(&"just_guard_success")


func _on_stamina_insufficient(_action: StringName) -> void:
	play_sfx(&"stamina_exhausted")


func _on_player_died() -> void:
	play_sfx(&"player_death_jingle")


func _on_player_respawned(_at_gravestone: Node) -> void:
	play_sfx(&"player_respawn_jingle")


## Settings 볼륨(F7-1/D-64) → AudioServer 버스 dB 매핑. default_bus_layout.tres의 믹스
## 기준 dB에 사용자 볼륨(선형 0~1)을 dB로 얹는다 — 1.0(기본값)이면 델타 0dB로 기존 믹스
## 그대로 유지, 0.0이면 사실상 무음(-80dB 부근)까지 내려간다.
func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key in [&"master_volume", &"bgm_volume", &"sfx_volume"]:
		_apply_volume_settings()


func _apply_volume_settings() -> void:
	_set_bus_volume("Master", Settings.master_volume, 0.0)
	_set_bus_volume("BGM", Settings.bgm_volume, -8.0)
	_set_bus_volume("SFX", Settings.sfx_volume, -3.0)


func _set_bus_volume(bus_name: String, user_volume: float, base_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, base_db + linear_to_db(clampf(user_volume, 0.0001, 1.0)))
