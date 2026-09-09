# 퀘스트 데이터 스키마 v0.1

> 작성: narrative-designer · 대상: `game/data/quests/*.json`
> 근거: `docs/GDD-도트액션RPG-기획안.md` 7.5, `docs/brd/03-features/05-퀘스트-내러티브.md`(F5-1·F5-2)
> 역할: 엔진 구현(godot-engineer)이 다음 단계에서 파서·런타임을 붙일 수 있도록 **필드·타입·enum만** 고정한다. 수치 튜닝·실제 드랍 테이블 연결은 game-designer 담당.
> 검증 원칙: 이 문서에 없는 필드를 JSON에 넣지 않는다. JSON에 있는 모든 몬스터/아이템 id는 `game/data/monsters.json`·`items.json`에 존재하거나, 파일 상단 `_todo_ids`에 등록되어야 한다(둘 다 없으면 스키마 위반).

---

## 1. 파일 구조

```jsonc
{
  "_schema_version": "0.1",
  "_todo_ids": {
    "monsters": ["jelly_bell", "..."],   // 아직 monsters.json에 없는 몬스터 id
    "items": ["item_material_wool_soft", "..."] // 아직 items.json에 없는 아이템 id
  },
  "quests": [ /* Quest 오브젝트 배열, 아래 2절 */ ]
}
```

- 한 파일 = 한 막·지방 묶음 (예: `act1_hartland.json` = 1막 하틀랜드 전체: 메인+사이드+게시판 템플릿).
- `_todo_ids`는 참조 무결성 검사를 위한 임시 장부다. godot-engineer가 실제 `monsters.json`/`items.json`을 만들면 이 목록과 대조해 실존 여부를 확정하고, 확정된 항목은 다음 리비전에서 제거한다.

## 2. Quest 오브젝트

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `id` | string | O | 고유 id. 패턴: 메인 `quest_main_a{막번호}_{2자리 순번}_{slug}`, 사이드 `quest_side_{지방}_{slug}`, 게시판 `quest_daily_{지방}_{2자리 번호}`(characters.md 1.1절 로컬라이징 key와 동일 문자열 — 데이터 id와 텍스트 key를 일치시켜 이중 관리 방지) |
| `type` | enum | O | `main` \| `side` \| `daily_template` |
| `region` | string | O | 지방 slug(world-bible/characters.md 컨벤션: `heartland` 등) |
| `title_key` | string | O | 제목 로컬라이징 key → `quest_ko.csv` |
| `desc_key` | string | O | 수주 시 노출되는 의뢰 설명 로컬라이징 key |
| `giver` | string | O | NPC slug(characters.md 컨벤션) 또는 `system`(NPC 없이 자동 등록, 예: 스토리 트리거) |
| `prerequisites` | object | O | 아래 2.1절 |
| `objectives` | array\<Objective\> | O | 1개 이상, 아래 2.2절. 순서대로 진행(현재 스키마는 순차 단계만 지원 — 동시 병렬 목표는 v0.2에서 확장) |
| `branch` | object \| null | X | 선택지가 결과를 가르는 경우만. 아래 2.3절 |
| `fail_conditions` | array\<string\> | X | 실패 트리거 id 목록. 메인 퀘스트는 항상 `[]`(F5-1 "메인 퀘스트 포기 불가") |
| `rewards` | object | O | 아래 2.4절 |
| `on_complete` | object | O | 아래 2.5절 |
| `template` | boolean | O | `daily_template`이면 `true`, 그 외 `false` |
| `template_vars` | object \| null | X | `template: true`일 때만. 아래 2.6절 |
| `foreshadowing_refs` | array\<string\> | O | `docs/story/foreshadowing.md`의 F-ID 배열. 표에 없는 구조적 복선은 `"narrative:<설명 슬러그>"` 형태로 자유 기재. 없으면 `[]` |
| `repeatable` | boolean | O | `daily_template`만 `true` 가능, 메인/사이드는 `false` |

### 2.1 `prerequisites`

```jsonc
{
  "quests_completed": ["quest_main_a1_01_arrival"], // 선행 퀘스트 id 배열, 없으면 []
  "story_flags": [],       // 선택. 세이브 플래그 문자열 배열(엔진 정의는 godot-engineer)
  "level_min": 1           // 선택. 없으면 필드 자체를 생략 가능
}
```

### 2.2 Objective

```jsonc
{
  "id": "obj_01",
  "type": "talk | kill | collect | reach | interact",
  "target": "npc:meru | monster:horn_rabbit | item:item_material_herb_common | location:heartland_pasture_boundary | object:ward_stone_dandelion",
  "count": 1,
  "text_key": "quest_main_a1_02_obj_01"
}
```

- `type`별 `target` 접두어 고정: `talk`→`npc:<slug>`, `kill`→`monster:<id>`(집계형은 `count` 사용), `collect`→`item:<id>`, `reach`→`location:<id>`, `interact`→`object:<id>`.
- `count`는 `kill`·`collect`에서 목표 수량, `talk`·`reach`·`interact`는 항상 `1`.
- `daily_template`의 `kill`/`collect` 목표는 고정 `count` 대신 `template_vars.count_range`가 실제 수량을 정하므로, 정적 데이터에서는 `count: 0`(플레이스홀더)으로 두고 런타임이 `count_range`에서 뽑은 값으로 덮어쓴다.
- 목표 순서는 배열 순서 = 진행 순서(병렬 진행 필요 시 v0.2에서 `"parallel_group"` 필드 도입 예정 — 이번 범위에서는 미사용).

### 2.3 `branch` (선택 결과가 갈리는 경우만)

```jsonc
{
  "at_objective": "obj_02",
  "choices": [
    { "id": "release", "text_key": "...", "outcome_flag": "montsil_released" },
    { "id": "capture_attempt", "text_key": "...", "outcome_flag": "montsil_capture_tried" }
  ],
  "converges": true   // true면 이후 목표·보상은 선택과 무관하게 동일(이번 데이터셋은 전부 true — 서사적 결말만 다르고 보상 차등 없음, "결정 필요" 표 D-94 참고)
}
```

### 2.4 `rewards`

```jsonc
{
  "_balance_todo": true,
  "gold": 30,
  "exp": 20,
  "items": [ { "id": "item_material_herb_common", "qty": 2 } ],
  "affinity": [ { "npc": "rozel", "amount": 1 } ]
}
```

- `_balance_todo: true`는 수치가 잠정치임을 표시(game-designer 확정 전까지 유지, 확정 후 필드 삭제).
- `affinity`는 F5-3 호감도 수치 연동용 훅만 남긴다 — 실제 상승폭 테이블은 `npcs.json`(game-designer) 소관.
- `items[].id`가 `items.json`에 없으면 파일 상단 `_todo_ids.items`에 반드시 등록.

### 2.5 `on_complete`

```jsonc
{
  "events": ["unlock_facility:smith", "register_quest:quest_main_a1_06_echocave"],
  "cutscene_key": "main_a1_s05_heartland_meru_01" // 선택. main-storyline.md 대사 key 재사용, 없으면 필드 생략
}
```

- `events`는 문자열 태그 배열. 이번 데이터셋에서 쓰는 태그: `unlock_facility:<smith|shop|inn|board|mailbox>`, `unlock_worldmap`, `register_quest:<id>`, `register_quests:<id 콤마 없이 별도 배열 사용, 다건은 배열 항목 반복>`, `save_checkpoint`. 새 태그가 필요하면 이 표에 추가 후 사용.

### 2.6 `template_vars` (게시판 일일 의뢰 전용)

```jsonc
{
  "monster_pool": "heartland_field_low",   // monsters.json에 pool 태그로 정의 예정(현재 미존재 → _todo_ids 아님, pool 자체가 별도 테이블이므로 D-97 결정 필요 항목 참고)
  "count_range": [3, 5],
  "item_pool": null                        // collect형일 때만 사용, kill형은 null
}
```

- `objectives[0].target`은 템플릿에서 `monster:{pool}`처럼 플레이스홀더로 두고, 실제 몬스터는 런타임에 `monster_pool`에서 추첨(F5-2 "목표는 레벨 구간 풀에서 추첨"). 그래서 daily_template의 `target`은 구체 몬스터 id가 아니라 `pool:<pool명>` 접두어를 쓴다 — 2.2절 접두어 표의 예외.
- `title_key`/`desc_key` 문구 안의 `{몬스터}`·`{수량}`은 런타임 바인딩 변수(characters.md 5장 표기 그대로).

---

## 3. 검증 체크리스트 (godot-engineer 인수 전 self-check)

- [ ] 모든 `id` 유일
- [ ] 모든 `prerequisites.quests_completed` 항목이 같은 파일 또는 이전 막 파일에 실존
- [ ] 모든 몬스터/아이템 참조가 `_todo_ids`에 등록되어 있거나 실제 테이블에 존재
- [ ] `type: "main"`의 `fail_conditions`는 항상 `[]`
- [ ] `type: "daily_template"`의 `repeatable`은 항상 `true`, 그 외는 `false`
- [ ] `rewards._balance_todo: true`인 항목은 이 문서의 "결정 필요" 표(각 시나리오 문서 하단)에 잠정치 근거가 있는지 확인
