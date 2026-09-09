# 퀘스트 시스템 엔진 (M2-7, F5-1·F5-2)

> 작성: godot-engineer · 근거: `docs/specs/quest-data-schema.md`(데이터 정본),
> `docs/brd/03-features/05-퀘스트-내러티브.md`, `game/data/quests/act1_hartland.json`.
> 구현: `game/scripts/systems/quest_system.gd`(오토로드 `QuestSystem`).

## 1. 배치: 왜 `scripts/systems/`인데 오토로드인가

다른 `scripts/systems/*.gd`는 대부분 RefCounted 순수 클래스(Inventory/Mailbox/Equipment/
Blacksmith)이고, 오토로드는 `scripts/core/*.gd`(Data/Events/GameState/SaveManager)에
모여 있다. QuestSystem은 예외다 — Data/Events/GameState 세 오토로드만 참조하고 씬
트리(플레이어·월드 노드)에는 의존하지 않아 GameState/Data와 동일하게 "그 자체가 오토로드
싱글턴이면서 GUT이 새 인스턴스를 만들어 격리 테스트할 수 있는" 패턴을 그대로 따른다
(`test_game_state.gd`/`test_data.gd`와 동일 관례 — `QuestSystemScript.new()` +
`add_child_autofree()`). 별도 RefCounted 계층을 두지 않은 이유는 상태(활성 퀘스트·
완료 목록·일일 의뢰 버킷)와 Events 구독/발신이 강하게 얽혀 있어 분리해도 얻는 이득이
적었기 때문이다. `project.godot`엔 `QuestSystem="*res://scripts/systems/quest_system.gd"`로
등록(GameState 다음, SaveManager 앞 — SaveManager가 저장/로드 시 `QuestSystem.to_dict()/
from_dict()`를 직접 호출하므로 초기화 순서상 앞서 있어야 한다).

## 2. 상태 머신

```
locked -> available -> active -> complete_ready -> completed
```

- `locked`: `prerequisites.quests_completed`/`story_flags`를 만족 못 함(또는 quest_id
  자체가 없음).
- `available`: 선행 조건 충족, 아직 미수주.
- `active`: 수주됨, 목표 진행 중(`objective_index` < 목표 수).
- `complete_ready`: 모든 목표 완료, 턴인 대기(`advance()` 호출 필요).
- `completed`: 턴인 완료(보상 지급 + `on_complete` 적용까지 끝남).

`daily_template`(게시판 일일 의뢰)은 `repeatable=true`라 `completed`를 영구 목록에
넣지 않는다 — 대신 `{day_index, completed_ids}` 버킷에 "오늘 완료함"만 기록하고,
`GameState.day_index`가 바뀌면 자동으로 `available`로 돌아간다(§5).

## 3. 공개 API

| 함수 | 설명 |
|---|---|
| `accept(quest_id) -> {ok, reason?}` | `available`일 때만 성공. `Events.quest_accepted` 발신. |
| `abandon(quest_id) -> {ok, reason?}` | `type=="main"`이면 항상 `reason:"main_quest_cannot_abandon"`(F5-1). |
| `get_state(quest_id) -> String` | §2의 5개 상태 문자열 중 하나. |
| `advance(quest_id) -> {ok, reason?}` | `complete_ready`일 때만 성공 — 보상 지급 + `on_complete` 적용 + 턴인. |
| `choose_branch(quest_id, choice_id) -> {ok, reason?}` | 분기 있는 퀘스트의 결과 플래그를 명시적으로 선택(§6). |
| `roll_daily_target(quest_id, day_index) -> {target_id, count}` | 일일 의뢰 풀 추첨(순수 함수, §5). |
| `get_daily_quest_ids() -> Array[String]` | `repeatable==true`인 퀘스트 id 전부(현재 3개). |
| `get_tracked_quest_id()` / `get_tracked_quest_progress()` | HUD 추적 퀘스트 한 줄용(§7). |
| `to_dict()` / `from_dict(data)` | 세이브 연동(§8). |

목표 진행은 이 API들과 별개로 **전부 자동**이다 — 아래 §4의 Events 5종을 구독해
처리하며, 호출부(플레이어 입력·전투·NPC 대화 등)는 그 Events만 정확히 emit하면 된다.

## 4. 목표 진행 자동화 (Events)

| 시그널 | 발신 지점(기존) | 목표 type |
|---|---|---|
| `Events.monster_died(monster_id)` | `monster_base.gd:_on_hurtbox_hurt()`(HP 0 도달 시, `enemy_died`와 동시) | `kill` |
| `Events.item_acquired(item_id, count)` | `GameState.pickup_item()`(인벤토리든 우편함행이든 항상) | `collect` |
| `Events.location_reached(location_id)` | **아직 없음** — 레벨 디자인(트리거 볼륨) 미구현 | `reach` |
| `Events.npc_talked(npc_id)` | **아직 없음** — 다이얼로그 매니저 연동 미구현 | `talk` |
| `Events.object_interacted(object_id)` | **아직 없음** — 상호작용 오브젝트 미구현 | `interact` |

`reach`/`talk`/`interact`는 신호 이름만 `events.gd`에 선언해 뒀다(`_todo_ids.locations`/
`.objects` 참고, level-designer 몫). 실제 트리거가 생기면 그 지점에서 Events만
emit하면 QuestSystem은 즉시 반응한다 — 이번 마일스톤에서는 `SmokeQuest.tscn`이 talk/
reach/interact를 Events 직접 emit으로, kill만 실제 `HornRabbit.tscn` 처치로 검증한다.

내부적으로 `_apply_progress(obj_type, target_key, amount)` 하나가 모든 활성 퀘스트를
순회하며 "현재 objective_index의 목표"만 비교한다(목표는 배열 순서 = 진행 순서, 스키마
§2.2). `pool:<id>` 접두어(daily_template)는 그날 뽑힌 구체 id로 치환해 비교한다(§5).

## 5. 게시판 일일 의뢰 (D-97)

`game/data/pools.json`(신설)에 `pool_id -> {kind, members:[{id, weight}]}`. 현재
2개: `heartland_field_low`(kind=monster, horn_rabbit/mushroom 균등), 
`heartland_field_material_low`(kind=item, mushroom_cap/iron_ore/rabbit_horn 균등) —
전부 `_balance_todo`(가중치는 game-designer 확인 필요).

`_daily_pick(quest_id, day_index)`는 `RandomNumberGenerator.seed = hash("<day>:<quest_id>")`
로 시드를 고정하는 **순수 함수**다. 같은 인자(day_index, quest_id)는 항상 같은
`{target_id, count}`를 반환하므로 이 결과 자체는 세이브에 저장하지 않는다 — 저장하는
건 "오늘 이미 완료한 daily 퀘스트 id 목록"뿐이다(§8). 이렇게 하면 세이브 파일이
`pools.json` 변경에 영향받지 않고, 로드 시점에 재계산해도 항상 저장 시점과 같은 결과가
나온다.

daily_template 3종은 항상 전부(3/3) 게시판에 뜬다 — "3개 중 몇 개를 뽑는" 추첨이
아니라, 3개 템플릿 각각의 **대상/수량**만 매일 재추첨된다.

## 6. 분기 (`quest_side_heartland_montsil`, D-94)

`converges:true`라 선택은 서사 연출(cutscene_key)만 가르고 보상/이후 진행에는 영향이
없다 — 그래서 `choose_branch()`는 게이팅에 관여하지 않고 `story_flags`에 outcome_flag만
기록한다. 대화 선택 UI가 아직 없어 `advance()`가 턴인 시점까지 `choose_branch()`가
호출되지 않았으면 `branch.choices[0]`(스키마상 "release")을 기본값으로 대신 적용한다
(`_resolve_branch_default()`). 향후 선택 UI가 생기면 그 UI가 `choose_branch()`를
직접 호출하도록 배선하면 된다.

## 7. HUD 추적 퀘스트 한 줄

`Hud.gd`는 이미 `set_quest_line(text)`/`$TopCenter/QuestLine` 자리를 갖고 있었다
(M1-5, "퀘스트 시스템이 생기면 이 함수만 호출하면 된다"). 이번에 `Events.quest_accepted/
quest_objective_updated/quest_completed`를 구독해 `QuestSystem.get_tracked_quest_progress()`
결과로 그 함수를 호출하도록 연결했다.

- 추적 대상: 활성 메인 퀘스트 1순위, 없으면 가장 먼저 수주한 활성 퀘스트, 없으면 빈 줄.
- 표시 형식: `ui.hud.quest_progress_fmt`(`"%s (%d/%d)"`) + 제목 로컬라이징.
- n/m 규칙(**구현 편의상 결정 — game-designer 조정 가능**): 현재 목표의 목표 수량이
  1보다 크면(kill/collect) "그 목표의 진행/목표", 아니면(talk/reach/interact, 항상
  count=1) "완료한 목표 수/전체 목표 수"로 대신한다 — 하나짜리 목표는 진행률 표시가
  의미 없기 때문. 퀘스트 로그 UI(다음 단계)에서 다른 표기가 필요하면 이 규칙만 바꾸면
  된다.

## 8. 세이브 연동

`SaveManager._build_payload()`/`_apply_payload()`가 `state.quest_system`에
`QuestSystem.to_dict()`를 그대로 싣고 로드 시 `from_dict()`로 되돌린다. 옛 세이브
파일(이 필드가 없는)은 `from_dict({})`로 빈 상태 초기화되어 하위 호환된다(경고 없음 —
"퀘스트를 아직 하나도 안 한 상태"와 구분 불가능하지만 M2 범위에선 무해).

직렬화 대상: `active`(진행 중인 퀘스트 상태), `completed`(영구 완료 목록), `story_flags`,
`registered`(§9), `daily`(`{day_index, completed_ids}`), `total_exp_earned`,
`pending_skill_points`, `npc_affinity_pending`(둘 다 placeholder, §9).

## 9. `on_complete.events` 태그 처리 (스키마 §2.5)

| 태그 | 처리 |
|---|---|
| `register_quest:<id>` | `_registered`에 기록(게이팅에는 관여 안 함 — 가용 여부는 이미 `prerequisites`만으로 계산됨. 향후 "새 퀘스트!" 토스트 UI용 훅). |
| `unlock_facility:<x>` | `story_flags["facility_<x>_unlocked"] = true`. |
| `unlock_system:<x>` | `story_flags["system_<x>_unlocked"] = true`. |
| `unlock_worldmap` | `story_flags["worldmap_unlocked"] = true`. |
| `save_checkpoint` | 무시(no-op) — `type=="main"` 완료는 `advance()`가 끝에서 항상 `Events.main_quest_stage_completed`를 emit해 SaveManager 오토세이브를 이미 건다. |
| `grant_skill_point:<n>` | `pending_skill_points += n`(placeholder — 스킬 포인트 지급 UI/시스템 미구현). |
| `affinity_stage:<npc>:<stage>` | `story_flags["affinity_stage_<npc>"] = stage`(F5-3 훅만, 실제 호감도 시스템은 별도 담당). |
| 그 외(예: `register_main_act2_regions`) | `push_warning`만 하고 무시 — 2막 데이터가 아직 없어 정의할 수 없는 태그를 하드 에러로 죽이면 안 됨. |

`exp` 보상은 `total_exp_earned`에 누적만 하는 placeholder다(레벨/EXP 시스템이 stats.json
확정 이후에도 "누적 EXP -> 레벨업" 로직이 아직 없음) — 실제 레벨 시스템이 생기면 이
누적치를 소비하거나, 이 필드를 지우고 그 시스템에 직접 연결하면 된다.

## 10. `game/data/quests/*.json` 폴더 로더 (`Data.gd`)

`Data._load_quests()`가 `res://data/quests/*.json`을 전부 읽어 `quests` 배열을
`tables["quests"]`(quest_id 키 딕셔너리)로 병합하고, 각 파일의 `_todo_ids`를
카테고리별로 합집합해 `Data.quest_todo_ids`에 노출한다. `Data._validate_quests()`/
`_validate_pools()`가 참조 무결성을 검사하되, `monster:`/`item:`/`pool:` 접두어
target만 검증한다 — `npc:`/`location:`/`object:`는 대응하는 실제 데이터 테이블이
엔진에 없어(레벨 디자인 소관) 형식만 두고 값은 검사하지 않는다. `tools/qa/
validate_tables.py`에 동일 규칙을 오프라인(파이썬)으로 이식해 뒀다 — 두 곳은 항상
같이 갱신할 것.

## 11. 이번 패스에서 데이터로 즉시 채운 `_todo_ids` (act1_hartland.json)

| 카테고리 | 항목 | 처리 |
|---|---|---|
| monsters | `horn_rabbit_big` | `monsters.json`에 horn_rabbit 기반 hp/atk 1.5배(D-95), `tier:"elite"`, `drop_table_id:null`(보상은 퀘스트 고정 지급 — D-95 F6-3 예외). 씬은 `HornRabbit.tscn` 재사용 + `monster_id`/스케일 1.3 오버라이드(level-designer가 배치 시 적용). |
| items | `wool_soft`/`herb_common`/`ribbon_dandelion`/`stew_basic`/`horn_shard`/`ribbon_charm` | `items.json`에 신규 등록(기존 `item_material_*` 접두어 대신 `mushroom_cap`/`iron_ore` 같은 기존 명명 규칙을 따름). JSON·`docs/story/quests-act1-hartland.md`의 참조도 일괄 갱신. |
| pools | `heartland_field_low`/`heartland_field_material_low` | `game/data/pools.json` 신설(D-97, §5). |

남는 `_todo_ids`(locations 7개, objects 5개)는 레벨 디자인 담당 — 실제 씬/트리거가
생기기 전까지는 `Events.location_reached`/`npc_talked`/`object_interacted`를 발신할
곳이 없다.

## 12. 결정 필요 (D-111~D-114로 기록)

| # | 쟁점 | 임시 처리 |
|---|---|---|
| D-111 | `GameState.day_index`를 언제 올릴지(수면 상호작용? 자정 타이머? 명시적 "하루 종료" 버튼?) — 게시판 일일 의뢰 재추첨 트리거가 곧 이 값의 증가 시점 | 지금은 아무도 증가시키지 않는 순수 카운터로만 둠(0 고정). game-designer가 "하루" 개념을 확정하면 그 지점에서 `GameState.day_index += 1` 한 줄만 추가하면 됨. |
| D-112 | `on_complete.grant_skill_point`/`affinity_stage`가 실제 스킬 포인트 지급 UI·npcs.json 호감도 시스템에 연결되지 않고 placeholder(`pending_skill_points`/`story_flags`)로만 쌓임 | 두 시스템이 각각 확정되면 QuestSystem 쪽 변경 없이 그 시스템이 이 값을 읽어가기만 하면 됨. |
| D-113 | HUD 추적 퀘스트 n/m 표시 규칙(§7, "목표 하나짜리는 완료 목표 수/전체 목표 수로 대신") | game-designer/UI-UX 확인 필요 — 확정되면 `get_tracked_quest_progress()`만 수정. |
| D-114 | `pools.json` 가중치(현재 전부 균등 1.0)와 daily 보상 `_balance_todo` 수치 | game-designer 확인 대기(D-96/D-97 연장선). |
