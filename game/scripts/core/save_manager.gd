## 세이브/로드 매니저 자동로드(F8-1, M2-6).
##
## 파일: user://saves/slot{n}_{kind}.json (kind: "manual"|"auto", n: 0~2 = "슬롯 1~3") +
## 직전 저장본 백업(.bak, 새로 쓰기 직전에 옮겨 둔다 — F8-1 "파일 손상 시 경고 + 백업
## (직전 저장본) 복구 시도"). 슬롯 내부에서 수동/오토는 서로 다른 파일이라 덮어쓰지
## 않는다(F8-1 표 "동작").
##
## 포맷: {version:1, meta:{character, level, playtime_sec, region_id, saved_at_unix},
## state:{game_state:{...}, player:{...}}, checksum: sha256(JSON.stringify(state))}.
## checksum은 state 블록만 대상으로 한다(meta.saved_at_unix가 매번 달라져도 손상 판정과
## 무관하게 만들기 위함).
##
## **암호화**: M2 범위에서는 평문 JSON + sha256 체크섬으로 "손상 검출"만 한다. GDD 12장/
## F8-1은 "암호화 JSON"을 요구하지만 키를 클라이언트에 어떻게 배포·보관할지(단순
## XOR 난독화 수준이면 사실상 무의미, 진짜 암호화는 키 관리 정책이 선행돼야 함)가
## 결정되지 않아 이번 패스에서는 구현하지 않았다 — docs/specs/save-load-m2.md §6
## 결정 필요 항목(D-103 후보) 참고.
extends Node

const FORMAT_VERSION := 3
const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const KINDS: Array[String] = ["manual", "auto"]

## 오토세이브는 항상 슬롯 1(index 0)에 기록한다. F8-1 표는 "슬롯 3개"가 곧 캐릭터별
## 저장 슬롯임을 규정할 뿐, 오토세이브가 슬롯마다 따로 갈리는지는 명시하지 않는다 — M2는
## 캐릭터 1명 고정(슬롯 선택 UI 자체가 없음)이라 슬롯 0 하나로 충분하다. 다중 캐릭터/
## 슬롯 선택 화면이 생기면 "현재 활성 슬롯" 개념이 필요해진다(godot-engineer TODO,
## 완료 보고 질문 목록 참고).
const AUTOSAVE_SLOT := 0

## GDD 11장/F8-1 "슬롯 카드: 캐릭터·레벨·플레이타임·현재 지역·저장 시각" 표시용
## placeholder. 캐릭터 선택·레벨(characters.json/stats.json), 지역 시스템(다중 지역
## 이동)이 아직 없어(월드는 프로토타입 청크 1개뿐, scripts/systems/world.gd 참고)
## 고정값을 쓴다 — 해당 시스템 확정 시 실제 값으로 교체(godot-engineer TODO).
const PLACEHOLDER_CHARACTER := "player"
const PLACEHOLDER_LEVEL := 1
## audio_manager.gd가 쓰는 기본 지역 id와 동일하게 맞췄다(현재 유일한 지역).
const PLACEHOLDER_REGION_ID := "greenfield_prototype"


func _ready() -> void:
	# F8-1 오토세이브 트리거: 워프 비석 활성화(실제 구현됨) / 워프 사용·메인 퀘스트
	# 단계 완료(이름만 선언, 상위 시스템 미구현 — events.gd 참고) / 지역 이동
	# (region_entered, 현재 아무도 emit하지 않지만 향후 대비 연결).
	Events.waystone_activated.connect(_on_autosave_trigger)
	Events.waystone_warp_used.connect(_on_autosave_trigger)
	Events.main_quest_stage_completed.connect(_on_autosave_trigger)
	Events.region_entered.connect(_on_autosave_trigger)


func _on_autosave_trigger(_id: StringName) -> void:
	save(AUTOSAVE_SLOT, "auto")


# --- 경로 ---

func _slot_path(slot: int, kind: String) -> String:
	return "%s/slot%d_%s.json" % [SAVE_DIR, slot, kind]


func _backup_path(slot: int, kind: String) -> String:
	return "%s.bak" % _slot_path(slot, kind)


func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# --- 저장 ---

## 저장을 시도한다. 실패 사유: "invalid_slot"|"invalid_kind"|GameState.can_save()의
## 사유("player_dead"|"in_combat"|"boss_room")|"io_error". 성공/실패 모두
## Events.save_completed(slot, kind, ok)를 발신한다.
func save(slot: int, kind: String) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return _finish_save(slot, kind, {"ok": false, "reason": "invalid_slot"})
	if not KINDS.has(kind):
		return _finish_save(slot, kind, {"ok": false, "reason": "invalid_kind"})

	var gate: Dictionary = GameState.can_save()
	if not gate.get("ok", false):
		return _finish_save(slot, kind, {"ok": false, "reason": String(gate.get("reason", "cannot_save"))})

	# 저장 전 강제 정리(M2-6): 미확정 재련(_pending_affix)이 세이브 파일에 남지 않도록.
	GameState.sanitize_pending_affixes_before_save()

	_ensure_dir()
	var path := _slot_path(slot, kind)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, _backup_path(slot, kind))

	var payload: Dictionary = _build_payload()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _finish_save(slot, kind, {"ok": false, "reason": "io_error"})
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return _finish_save(slot, kind, {"ok": true, "reason": ""})


func _finish_save(slot: int, kind: String, result: Dictionary) -> Dictionary:
	Events.save_completed.emit(slot, StringName(kind), bool(result.get("ok", false)))
	return result


func _build_payload() -> Dictionary:
	var state: Dictionary = {
		"game_state": GameState.to_dict(),
		"quest_system": QuestSystem.to_dict(), # M2-7(F5-1/F5-2): 활성/완료 퀘스트·일일 의뢰 시드.
	}
	var player: Player = GameState.get_player()
	if player != null:
		state["player"] = {
			"position": {"x": player.global_position.x, "y": player.global_position.y},
			"facing": {"x": player.facing.x, "y": player.facing.y},
			"resources": player.resources.to_dict() if player.resources != null else {},
		}
	var meta: Dictionary = {
		"character": PLACEHOLDER_CHARACTER,
		"level": PLACEHOLDER_LEVEL,
		"playtime_sec": GameState.play_time_sec,
		"region_id": PLACEHOLDER_REGION_ID,
		"saved_at_unix": Time.get_unix_time_from_system(),
	}
	# JSON에는 int/float 구분이 없어 JSON.parse_string()은 모든 숫자를 float로 되돌린다 —
	# 저장 시점(GDScript int가 섞인 원본)과 로드 시점(파싱돼 전부 float가 된 값)을 각각
	# JSON.stringify()하면 서로 다른 텍스트가 나와 정상 파일도 체크섬 불일치로 오판하게
	# 된다. 저장 전에 한 번 JSON 왕복(stringify→parse)시켜 "파싱을 거치면 항상 나오는
	# 표준형"으로 맞춘 뒤 그 표준형 자체를 state로 저장하고 체크섬도 그 표준형 기준으로
	# 계산한다 — 이후 로드 시 재파싱해도 항등(idempotent)이라 체크섬이 항상 일치한다.
	var normalized_state: Dictionary = JSON.parse_string(JSON.stringify(state))
	return {
		"version": FORMAT_VERSION,
		"meta": meta,
		"state": normalized_state,
		"checksum": _checksum(normalized_state),
	}


func _checksum(state: Dictionary) -> String:
	return JSON.stringify(state).sha256_text()


# --- 로드 ---

## 로드를 시도한다. 파일이 없거나 파싱/체크섬 검증에 실패하면 같은 슬롯·종류의 .bak을
## 대신 시도한다(F8-1 "파일 손상 시 경고 + 백업 복구 시도") — 둘 다 실패하면
## reason="not_found". 성공 시 GameState/플레이어 위치·자원을 즉시 반영하고
## Events.load_completed(slot, kind, ok)를 발신한다.
func load(slot: int, kind: String) -> Dictionary:
	if slot < 0 or slot >= SLOT_COUNT:
		return _finish_load(slot, kind, {"ok": false, "reason": "invalid_slot"})
	if not KINDS.has(kind):
		return _finish_load(slot, kind, {"ok": false, "reason": "invalid_kind"})

	var payload: Dictionary = _read_and_verify(_slot_path(slot, kind))
	if payload.is_empty():
		payload = _read_and_verify(_backup_path(slot, kind))
		if payload.is_empty():
			return _finish_load(slot, kind, {"ok": false, "reason": "not_found"})
		push_warning("[SaveManager] slot %d(%s) 손상/누락 — 백업(.bak)에서 복구" % [slot, kind])

	var version: int = int(payload.get("version", 0))
	if version == 1:
		# D-210(단계 b1): 타일이 16→32 월드단위가 되면서 월드 좌표가 전부 2배가 됐다.
		# 세이브에 들어 있는 좌표는 플레이어 위치 한 쌍뿐이고(비석은 id 문자열, 나머지
		# 항목은 좌표와 무관) 지형도 함께 2배가 됐으므로 ×2가 정확히 옳다 — 리셋할
		# 이유가 없다. 다음 포맷 변경 때는 이 자리에 version == 2 분기를 잇는다.
		payload = _migrate_v1_to_v2(payload)
		version = int(payload.get("version", 0))
	if version == 2:
		# D-225(iso-1): 등각 전환으로 월드 좌표가 지면 -> 화면 투영으로 바뀌었다.
		# 세이브에 든 좌표는 여전히 플레이어 위치 한 쌍뿐이라 변환도 한 번이다.
		payload = _migrate_v2_to_v3(payload)
		version = int(payload.get("version", 0))
	if version != FORMAT_VERSION:
		return _finish_load(slot, kind, {"ok": false, "reason": "version_unsupported"})

	_apply_payload(payload)
	_advance_day_index_if_new_calendar_day(payload) # D-111(M2-7): 실제 달력 날짜 경과 판정.
	return _finish_load(slot, kind, {"ok": true, "reason": ""})


## v1 -> v2: 월드 단위 ×2 전환(D-206/D-210). 플레이어 위치만 2배로 올린다.
func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var state: Dictionary = payload.get("state", {})
	var player_state: Variant = state.get("player", {})
	if player_state is Dictionary:
		var position: Variant = (player_state as Dictionary).get("position", {})
		if position is Dictionary:
			var pos: Dictionary = position
			pos["x"] = float(pos.get("x", 0.0)) * 2.0
			pos["y"] = float(pos.get("y", 0.0)) * 2.0
	payload["version"] = 2
	push_warning("[SaveManager] 세이브 포맷 v1 -> v2 마이그레이션(월드 단위 ×2, D-210)")
	return payload


## v2 -> v3: 지면 좌표를 등각 화면 좌표로 투영한다(D-219/D-225).
func _migrate_v2_to_v3(payload: Dictionary) -> Dictionary:
	var state: Dictionary = payload.get("state", {})
	var player_state: Variant = state.get("player", {})
	if player_state is Dictionary:
		var position: Variant = (player_state as Dictionary).get("position", {})
		if position is Dictionary:
			var pos: Dictionary = position
			var screen: Vector2 = IsoMath.to_screen(
				Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0))))
			pos["x"] = screen.x
			pos["y"] = screen.y
	payload["version"] = 3
	push_warning("[SaveManager] 세이브 포맷 v2 -> v3 마이그레이션(등각 투영, D-225)")
	return payload


## 로드한 위치가 벽(정적 콜라이더) 안이면 마지막 비석으로 물러난다.
##
## 단위 전환 자체는 좌표를 정확히 2배로 옮기지만, 단계 (b2)가 예전에 없던 절벽·건물을
## 세우기 때문에 옛 세이브의 위치가 새 벽 안일 수 있다. 끼인 채로 살아나는 것보다
## 비석에서 다시 시작하는 편이 언제나 낫다.
func _snap_out_of_walls(player: Player) -> void:
	var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = player.global_position
	query.collision_mask = 1 # 벽/지형 레이어.
	if space.intersect_point(query, 1).is_empty():
		return
	player.global_position = GameState.get_respawn_position()
	push_warning("[SaveManager] 불러온 위치가 벽 안이라 마지막 비석으로 이동")


func _finish_load(slot: int, kind: String, result: Dictionary) -> Dictionary:
	Events.load_completed.emit(slot, StringName(kind), bool(result.get("ok", false)))
	return result


## D-111(M2-7 후속) 확정: GameState.day_index는 "실제 달력 날짜"가 지났을 때만
## +1(며칠 차이든 항상 +1)된다 — 여관 숙박 등 게임플레이 행동은 올리지 않는다(그런
## 행동은 이 값을 직접 건드리지 않으므로 자연히 제외됨). 유일한 증가 지점은 여기 하나
## 뿐이다: 로드한 세이브의 meta.saved_at_unix(저장 시점)와 "지금"(로드 시점의 실제
## 시스템 시각)의 연·월·일이 다르면 로드 직후 1회 올린다. 새 게임(로드 자체가 없음)은
## GameState.day_index 기본값 0 그대로 시작한다. 이 값이 바뀌면 QuestSystem의 일일
## 의뢰 풀 추첨(_daily_pick)이 day_index를 시드로 쓰는 순수 함수라 자동으로 재추첨된
## 결과를 돌려준다 — 별도로 "재추첨" 호출을 할 필요가 없다.
func _advance_day_index_if_new_calendar_day(payload: Dictionary) -> void:
	var meta: Dictionary = payload.get("meta", {})
	var saved_at_unix: int = int(meta.get("saved_at_unix", 0))
	if saved_at_unix <= 0:
		return
	var saved_date: Dictionary = Time.get_date_dict_from_unix_time(saved_at_unix)
	var now_date: Dictionary = Time.get_date_dict_from_unix_time(Time.get_unix_time_from_system())
	if saved_date.get("year") != now_date.get("year") \
			or saved_date.get("month") != now_date.get("month") \
			or saved_date.get("day") != now_date.get("day"):
		GameState.day_index += 1


## 파일을 읽어 JSON 파싱 + 체크섬 검증까지 통과했을 때만 payload를 반환한다. 파일 없음/
## 파싱 실패/체크섬 불일치는 전부 "손상"으로 취급해 빈 Dictionary를 반환한다(호출부가
## .bak로 넘어갈 신호).
func _read_and_verify(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var payload: Dictionary = parsed
	var state: Variant = payload.get("state", {})
	if not (state is Dictionary):
		return {}
	var expected: String = String(payload.get("checksum", ""))
	if expected.is_empty() or expected != _checksum(state):
		return {}
	return payload


func _apply_payload(payload: Dictionary) -> void:
	var state: Dictionary = payload.get("state", {})
	GameState.from_dict(state.get("game_state", {}))
	QuestSystem.from_dict(state.get("quest_system", {})) # M2-7: 옛 세이브(필드 없음)는 빈 상태로 초기화됨.

	var player: Player = GameState.get_player()
	if player == null:
		return
	var player_state: Variant = state.get("player", {})
	if not (player_state is Dictionary) or (player_state as Dictionary).is_empty():
		return
	var player_dict: Dictionary = player_state

	var pos: Dictionary = player_dict.get("position", {})
	player.global_position = Vector2(
		float(pos.get("x", player.global_position.x)),
		float(pos.get("y", player.global_position.y)))
	_snap_out_of_walls(player)

	var facing: Dictionary = player_dict.get("facing", {})
	if not facing.is_empty():
		player.facing = Vector2(
			float(facing.get("x", player.facing.x)),
			float(facing.get("y", player.facing.y)))

	if player.resources != null:
		# GameState.from_dict()가 이미 장비 스탯을 재계산해 max_hp/max_stamina를 갱신한
		# 뒤이므로(apply_equipment_stats_to_player 호출 순서), 여기서 현재값을 그
		# 상한으로 clamp해서 되돌릴 수 있다(PlayerResources.from_dict() 참고).
		player.resources.from_dict(player_dict.get("resources", {}))
		Events.player_hp_changed.emit(player.resources.hp, player.resources.max_hp)
		Events.player_stamina_changed.emit(player.resources.stamina, player.resources.max_stamina)


# --- 슬롯 목록 / 삭제 ---

## 슬롯 카드 UI가 그대로 읽을 수 있는 메타 목록(F8-1). manual/auto 각각 파일이 없거나
## 손상(백업도 손상)이면 null.
func list_slots() -> Array:
	var result: Array = []
	for slot in SLOT_COUNT:
		result.append({
			"slot": slot,
			"manual": _read_meta(slot, "manual"),
			"auto": _read_meta(slot, "auto"),
		})
	return result


func _read_meta(slot: int, kind: String) -> Variant:
	var payload: Dictionary = _read_and_verify(_slot_path(slot, kind))
	if payload.is_empty():
		payload = _read_and_verify(_backup_path(slot, kind))
	if payload.is_empty():
		return null
	return payload.get("meta", {})


## 슬롯의 수동/오토/백업 파일을 전부 삭제한다.
func delete(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	for kind: String in KINDS:
		_delete_file(_slot_path(slot, kind))
		_delete_file(_backup_path(slot, kind))


func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
