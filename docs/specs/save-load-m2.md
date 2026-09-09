# M2-6 세이브/로드(F8-1)

> 기준: `docs/brd/03-features/08-시스템-기반.md` F8-1 / `docs/GDD-도트액션RPG-기획안.md` 11장·12장 /
> `docs/brd/04-decisions.md` D-28(부활 비석=워프 비석)·D-85(대장간 미확정 재련 자동 정리) /
> `game/scripts/core/{game_state,events}.gd`·`game/scripts/systems/{inventory,equipment,mailbox}.gd`·
> `game/scripts/player/resources.gd`·`game/scripts/world/waystone.gd`.
>
> 범위: 로컬 파일 세이브/로드 백엔드(슬롯 3개, 수동/오토 분리, 손상 복구, 저장 금지
> 조건, 오토세이브 트리거 배선)와 디버그 입력(F5/F9)까지. 슬롯 선택/저장 UI(여관
> 카운터 상호작용, 슬롯 카드 화면)는 다음 단계 — 지금은 `Events.blacksmith_opened` 등과
> 동일하게 백엔드 API만 완성한다.

---

## 1. 구현 요약

| 파일 | 내용 |
|---|---|
| `game/scripts/core/save_manager.gd` | 세이브/로드 자동로드(`SaveManager`). `save()`/`load()`/`list_slots()`/`delete()`. |
| `game/scripts/core/game_state.gd` | `can_save()`, 전투 중 판정(`_last_combat_activity_sec`), `last_waystone_id`/`activated_waystone_ids`, `get_player()`, `sanitize_pending_affixes_before_save()`, `_restore_waystones()`, `to_dict()`/`from_dict()` 확장. |
| `game/scripts/player/resources.gd` | `PlayerResources.to_dict()`/`from_dict()`(hp/stamina 현재값만 — 상한은 파생값이라 저장 안 함). |
| `game/scripts/world/waystone.gd` | `&"waystones"` 그룹 등록, `Events.waystone_activated` 발신, `restore_active_silently()`(로드 전용, 연출 재생 없음). |
| `game/scripts/core/events.gd` | `save_completed(slot,kind,ok)`/`load_completed(slot,kind,ok)`(시그니처 변경), `waystone_activated`, `waystone_warp_used`(이름만), `main_quest_stage_completed`(이름만) 신설. |
| `game/scripts/tuning.gd` | `IN_COMBAT_SAVE_LOCK_SEC`(제안값, `_balance_todo`). |
| `game/scripts/ui/hud.gd` + `game/scenes/ui/Hud.tscn` | 우하단 `SaveIcon` 라벨(1초 표시, `ui.hud.save_icon` 로컬라이징 key), F5/F9 디버그 입력 처리. |
| `game/project.godot` | 자동로드 `SaveManager`, 입력 액션 `debug_save`(F5)/`debug_load`(F9). |
| `game/scenes/main/Main.tscn` | `Waystone1.waystone_id = &"waystone1"` 부여(이전엔 빈 문자열 — 세이브 복원 대상에서 항상 제외돼 있었다). |
| `game/localization/ui_ko.csv` | `ui.hud.save_icon,저장됨` 추가. |
| `game/tests/unit/test_save_manager.gd` | GUT 유닛 테스트(라운드트립, 체크섬 손상→백업 복구, can_save 거부 사유, 슬롯 목록, 삭제). |
| `game/tests/smoke/smoke_save_load.gd`/`SmokeSaveLoad.tscn` | 헤드리스 스모크(지급→강화→장착→비석 활성화→피격→이동→저장→**씬 전체 재인스턴스화**→로드→복원, 백업 복구, 저장 거부 3종). |

---

## 2. 파일 포맷

```
user://saves/slot{0..2}_{manual|auto}.json      # 슬롯 1~3(0-index) × 수동/오토
user://saves/slot{0..2}_{manual|auto}.json.bak  # 직전 저장본(새로 쓰기 전에 옮겨 둠)
```

```jsonc
{
  "version": 1,
  "meta": {
    "character": "player",           // placeholder — §5 D-105
    "level": 1,                      // placeholder — §5 D-105
    "playtime_sec": 1234.5,
    "region_id": "greenfield_prototype", // placeholder — §5 D-105
    "saved_at_unix": 1780000000
  },
  "state": {
    "game_state": { /* GameState.to_dict() 그대로 */ },
    "player": {
      "position": { "x": 0.0, "y": 0.0 },
      "facing": { "x": 0.0, "y": 1.0 },
      "resources": { "hp": 80, "stamina": 100.0 }
    }
  },
  "checksum": "sha256(JSON.stringify(state))"
}
```

- `checksum`은 `state` 블록만 대상으로 한다(`meta.saved_at_unix`가 매번 달라져도 손상
  판정과 무관하도록).
- `GameState.to_dict()`는 이미 `gold`/`mailbox`/`inventory`/`equipment`/`play_time_sec`/
  `elite_respawn_remaining_sec`를 직렬화하고 있었다(M2-4 대장간 태스크에서 준비) — 이번
  태스크는 여기에 `death_count`/`last_waystone_id`/`activated_waystone_ids`만 추가했다.
- 아이템 인스턴스(`inventory.slots`/`equipment.slots` 안의 각 Dictionary)는 uid/item_id/
  grade/quantity/affixes/enhance_level/refine_left/locked를 그대로 담는다. `_pending_affix`
  (재련 신·구 미확정 상태, D-85)는 저장 대상에서 제외 — `SaveManager.save()`가
  `GameState.sanitize_pending_affixes_before_save()`로 저장 직전에 인벤토리·장착 슬롯
  전체를 훑어 `Blacksmith.auto_resolve_pending()`(D-85 "미commit 시 구 옵션 유지")을
  강제로 태운다. 즉 미확정 재련 중 저장하면 그 재련은 "구 옵션 유지"로 확정된 채
  저장된다(메모리 상태도 함께 바뀐다 — 되돌릴 수 없음, 플레이어가 재련 확정 UI를
  닫지 않고 저장한 경우에 해당).

### 기존 `to_dict()`/`from_dict()` 관례를 그대로 따름 (설계 참고)

지시문은 "각 시스템이 `to_save_dict()`/`from_save_dict(d)`를 제공"이라고 표현했지만,
`Inventory`/`Equipment`/`Mailbox`/`GameState`는 이미 M2-1~M2-4에서 `to_dict()`/`from_dict()`
로 이 역할을 하고 있었고(285개 기존 테스트가 이 이름으로 검증 중) 별도 이름의 병행
API를 새로 만들면 "같은 일을 하는 함수 두 벌"이 된다. 기존 관례를 그대로 확장하는
쪽을 택했다 — `PlayerResources.to_dict()`/`from_dict()`도 동일 이름으로 신설.

### 플레이어 위치/자원

`Player` 자체에는 위치용 API를 따로 만들지 않았다 — `global_position`/`facing`이 이미
공개 필드라 `SaveManager`가 직접 읽고 쓴다. `PlayerResources.to_dict()`는 `hp`/`stamina`
"현재값"만 담는다 — `max_hp`/`max_stamina`/회복 속도는 `combat.json` + 장비 스탯
(`Equipment.compute_stats()`)에서 매번 다시 계산되는 파생값이라 저장하지 않고, 로드 후
장비 재계산이 끝난 상한에 clamp해서 되돌린다(호출 순서: `GameState.from_dict()`가 먼저
장비 스탯을 반영 → `SaveManager`가 그 다음에 `PlayerResources.from_dict()` 호출).

### 활성화된 워프 비석 목록

세이브 파일에는 씬 노드를 직접 담을 수 없어 `waystone_id`(문자열) 목록만 저장한다.
`Waystone._ready()`가 `&"waystones"` 그룹에 등록해 두고, 로드 시
`GameState._restore_waystones()`가 현재 씬의 그 그룹을 스캔해 id가 일치하는 노드의
시각 상태(`is_active`)와 `GameState.last_waystone` 참조를 되살린다.
`Waystone.restore_active_silently()`는 `activate()`와 달리 `Events.waystone_activated`
재발신·오디오·트윈 연출을 다시 일으키지 않는다(이미 여러 번 활성화된 것처럼 보이면
안 됨). **주의**: `waystone_id`가 빈 문자열인 비석은 세이브 대상에서 제외된다 — 이번
태스크에서 `Main.tscn`의 `Waystone1`에 `waystone_id = &"waystone1"`을 새로 부여했다
(이전엔 빈 문자열이라 이 기능이 사실상 죽어 있었다).

---

## 3. 공개 API

```gdscript
SaveManager.save(slot: int, kind: String) -> {ok: bool, reason: String}
SaveManager.load(slot: int, kind: String) -> {ok: bool, reason: String}
SaveManager.list_slots() -> Array[{slot: int, manual: Dictionary|null, auto: Dictionary|null}]
SaveManager.delete(slot: int) -> void

GameState.can_save() -> {ok: bool, reason: String}   # "player_dead"|"in_combat"|"boss_room"|""
GameState.get_player() -> Player                      # null이면 아직 스폰 안 됨
GameState.sanitize_pending_affixes_before_save() -> void
```

`save()`/`load()` 실패 사유(`reason`): `invalid_slot`(0~2 범위 밖) / `invalid_kind`
("manual"/"auto" 외) / `player_dead`·`in_combat`·`boss_room`(저장만, `can_save()` 그대로
전달) / `io_error`(파일 열기 실패) / `not_found`(로드 시 본 파일·백업 모두 없음/손상) /
`version_unsupported`(포맷 버전 불일치, §4).

---

## 4. 마이그레이션 규칙 (현재 상태)

`FORMAT_VERSION = 1` 하나뿐이라 실제 변환 로직은 없다 — `SaveManager.load()`는
`payload.version != FORMAT_VERSION`이면 무조건 `reason: "version_unsupported"`로 거부한다.
버전 2가 생기면:

1. `FORMAT_VERSION`을 올리고,
2. `_apply_payload()` 진입 시 `version`별 변환 함수(`_migrate_v1_to_v2(state) -> state`
   식)를 사슬로 연결해 항상 최신 스키마로 맞춘 뒤 반영,
3. `version_unsupported`는 "미래 버전(다운그레이드 방지)"에만 남긴다.

---

## 5. 저장 금지 조건 (F8-1 "사망 직후·전투 중·보스방 저장 불가")

`GameState.can_save()`가 순서대로 검사한다:

1. **사망 직후**: `Player.is_dead == true`. 부활 완료(`Player.respawn()`이 `is_dead = false`로
   되돌리는 시점) 즉시 다시 저장 가능해진다 — "사망 연출 중"과 "부활 직후 유예시간"을
   구분하는 별도 타이머는 없다.
2. **전투 중**: `Events.hit_landed`(공격자/대상 어느 쪽이든)가 마지막으로 발신된 뒤
   `Tuning.IN_COMBAT_SAVE_LOCK_SEC`(제안값 5.0초, `_balance_todo`) 이내. 실제 플레이
   시간(`GameState.play_time_sec`, 일시정지 제외)을 기준 시계로 쓴다.
3. **보스방**: `GameState.in_boss_encounter`. 보스 인카운터 진입/종료 시 이 플래그를
   토글하는 코드는 아직 없다(보스 시스템 자체가 미구현, `game_state.gd` 기존 주석
   참고) — 보스 시스템 구현 태스크가 이 플래그만 세팅하면 자동으로 연동된다.

세 조건 모두 "예외"만 있고 "완화"는 없다(F8-1 표에 유예 규칙 언급 없음) — 예를 들어
저스트 가드로 완전 무피해 방어했어도 `hit_landed`가 발신됐다면 여전히 "전투 중"으로
잠긴다. 이 판정이 과한지(추격만 당하고 맞지도 맞히지도 않은 상태는 포함 안 됨 — 더
느슨한 기준일 수 있음)는 §6 결정 필요 항목 참고.

---

## 6. 결정 필요 항목 (디렉터가 D-103+로 기록)

| 후보 ID | 항목 | 현재 임시 처리 | 확인 필요 사항 |
|---|---|---|---|
| D-103 | 암호화 방식/키 배포 | 평문 JSON + sha256 체크섬(손상 검출만, 변조 방지 없음) | GDD 12장/F8-1이 "암호화 JSON"을 요구 — 클라이언트에 키를 어떻게 배포·보관할지(단순 난독화 수준이면 사실상 무의미, 진짜 암호화는 키 관리 정책이 선행돼야 함) 결정 필요. 세이브 파일 변조로 인한 부정 이슈를 얼마나 심각하게 볼지(싱글플레이 로컬 세이브라 우선순위 낮을 수 있음)도 함께. |
| D-104 | `IN_COMBAT_SAVE_LOCK_SEC` 값 | 5.0초(제안값) | F8-1 표는 "전투 중 저장 불가"만 규정하고 유예 시간을 정의하지 않음. 판정 기준도 "타격이 실제로 오간 시점부터 N초"(현재 구현) vs "몬스터에게 인지(추격)당한 시점부터"(더 엄격) 중 무엇을 의도했는지 확인 필요. |
| D-105 | 슬롯 카드 placeholder(캐릭터/레벨/지역) | `character="player"`, `level=1`, `region_id="greenfield_prototype"` 고정값 | 캐릭터 선택(4인, GDD 3장)·레벨(stats.json)·다중 지역 이동 시스템이 확정되면 이 3개 필드를 실제 값으로 교체해야 함 — 그 전까지 슬롯 카드 UI가 이 필드들을 신뢰하고 표시하면 안 됨. |
| D-106 | 오토세이브 슬롯 고정(슬롯 1) | 항상 index 0 | 캐릭터/슬롯 선택 화면이 생기기 전까지의 잠정 처리. "현재 활성 슬롯"을 어디서 들고 있을지(GameState? 별도 세션 상태?) 슬롯 선택 UI 설계 시 결정 필요. |
| D-107 | 사망 후 저장 재개 시점 | 부활 완료(`is_dead=false`) 즉시 재개, 별도 유예 없음 | "사망 직후" 금지가 사망 연출 중만인지, 부활 후 몇 초까지 포함하는지 F8-1 표에 명시 없음 — 위 §5-1 참고. |

---

## 7. 디버그 입력

- `debug_save`(F5): 슬롯 1(index 0) 수동 저장. `hud.gd`가 `SaveManager.save(0, "manual")`
  호출 결과를 콘솔에 출력.
- `debug_load`(F9): 같은 슬롯 로드.
- 정식 저장/불러오기 UI(여관 카운터 상호작용, 슬롯 선택 화면)는 다음 단계 범위 —
  `Events.blacksmith_opened`/`mailbox_opened`와 동일하게 지금은 백엔드만 완성했다.

---

## 8. 오토세이브 트리거 배선 상태

| 트리거(F8-1 표) | 배선 상태 |
|---|---|
| 워프 비석 활성화 | **실제 연결됨** — `Waystone.activate()` → `Events.waystone_activated` → `SaveManager._on_autosave_trigger()`. |
| 워프 사용 | 이름만 선언(`Events.waystone_warp_used`) — 워프 목적지 선택 UI가 없어(M2 범위, `waystone.gd` 주석) 아무도 emit하지 않는다. |
| 메인 퀘스트 단계 완료 | 이름만 선언(`Events.main_quest_stage_completed`) — 퀘스트 시스템 미구현. |
| 지역 이동 | 기존 `Events.region_entered`에 연결했지만, 실제 지역 이동 코드가 없어(월드가 프로토타입 청크 1개뿐) 게임플레이 중에는 emit되지 않는다(`audio_manager.gd`가 부팅 시 1회만 수동 호출). |

이 4개 트리거 시스템이 실제로 구현되는 시점에 신호만 emit하면 오토세이브가 자동으로
걸린다 — `SaveManager` 쪽 추가 작업은 필요 없다.
