# M2 정예 몬스터 · 파밍 소스 · 스탯 계수 설계

> 기준: GDD 5.2(스탯)·6.5(파밍 콘텐츠 소스)·8.1(몬스터 설계 기준) / `docs/brd/03-features/03-아이템-파밍.md` F3-5 /
> `docs/brd/03-features/06-몬스터-보스.md` F6-3 / `docs/levels/hartland.md` ⑤(정예 2종·월드 보스 제단·스폰 존) /
> `docs/specs/combat-tuning-m1.md` §8-3(공격력 역산 방법론)·`combat-tuning-m1-addendum.md` §4(AI 공통 5필드) /
> `docs/specs/items-and-drops-m2.md`(§4 LUK 공식, §5-3 정예 기대값, §11 결정 요청 A/B/D/E) / `docs/specs/data_tables.md` §3·§11·§12 /
> `docs/brd/04-decisions.md` D-15·D-45·D-52
>
> 이번 세션에서 처음 부여하는 결정 ID(D-74·D-75·D-77·D-78)는 **메인 세션이 `docs/brd/04-decisions.md`에 정식
> 반영하기 전까지 "예정"** 표기로 쓴다(`combat-tuning-m1-addendum.md`가 D-61~D-70을 다루던 것과 동일한 관례).
> 이 세션은 아래 3개 파일만 작성한다: 본 문서, `game/data/farming_sources.json`(신규), `game/data/stats.json`(신규).
> 기존 `game/data/*.json`·`game/scripts/core/data.gd`는 **수정하지 않았다** — 필요한 변경은 §4 "엔지니어 요청"으로만 남긴다.

---

## 1. 정예 몬스터 2종 (D-75 예정)

### 1-0. 배율 규칙 (일반 → 정예, 공통)

GDD 8.1 "정예 몬스터는 일반 몬스터의 강화 변종(고유 이름 + 강화 패턴 1개)으로 골격을 재사용한다"를 수치화한다.
`combat-tuning-m1.md` §8이 이미 확정한 "TTK 역산" 방법론을 그대로 확장했다.

| 필드 | 배율/규칙 | 근거 |
|---|---|---|
| `hp` | 일반 × **5.0** | `items-and-drops-m2.md` §5-3 "정예=필드보다 2배 이상 긴 교전"을 만족하는 안전 마진. 몬스터 방어력이 아직 없는 단순모델(D-49, `combat-tuning-m1.md` §0)에서는 HP만으로 TTK를 늘릴 수 있으므로, 최소 배율(2×)에 여유를 더해 5×로 설정 — 아래 1-2·1-3 TTK 검증 참고 |
| `atk` | 일반 × **1.5** | 플레이어 HP 100 기준 즉사 방지(GDD "읽고 피하는 전투" 원칙, `combat-tuning-m1.md` §8-3과 동일 철학) — 확실히 아프지만 여러 방 버틸 수 있는 수준 유지 |
| `move_speed_px` | 일반 × **1.15** | "네임드"다운 약간의 위압감(더 빠르고 집요함), 회피 난이도를 과하게 올리지 않는 선 |
| `telegraph_sec` | `max(0.5, 일반 − 0.1)` | GDD 4.2 최소 예고 0.5초는 **정예도 예외 없이 강제**(빌드 에러 규칙, `data_tables.md` §12 검증 규칙 1). 두 몬스터 모두 베이스가 정확히 0.5초라 이 규칙은 하한에 걸려 **사실상 변화 없음** — 대신 아래 강화 패턴의 자체 예고(웨이브 1.5초/분열 없음)가 정보량을 보완 |
| `aggro_range_px` / `leash_range_px` | 일반 × **1.2** (동시 적용) | 더 멀리서 알아채고 더 멀리 쫓아온다는 "네임드 위협감". 두 값을 함께 곱해 `leash > aggro` 불변식(`data_tables.md` §12 검증 규칙 4, `combat-tuning-m1-addendum.md` §4-2)을 항상 보존 |
| `melee_range_px` / `attack_recovery_sec` | 판정 거리 **불변**, 후딜 × **0.9** | 판정 히트박스 크기를 키우면 회피 자체가 불공정해지므로 유지. 후딜만 10% 단축해 "조금 더 몰아친다"는 압박만 추가 |
| `patrol_radius_px` | 불변 | 정예는 대부분 고정 스폰(부서진 마차/습지)이라 순찰 성격 자체를 바꿀 이유 없음 |

### 1-1. 고블린 정찰병 (일반, `goblin_scout`) — 정찰대장의 베이스 골격

GDD 8.1 예시 4종 중 유일한 원거리 경보형(`hartland.md` ⑤ "고블린 정찰병"). `monsters.json`에 아직 엔트리가 없어
(정찰대장을 정의하려면 베이스가 먼저 있어야 한다) 이번 문서에서 함께 확정한다.

**TTK 역산** (`combat-tuning-m1.md` §8-1과 동일 모델: `player_base_attack=10`, 콤보 배율 `[1.0,1.0,1.5]`, 누적 `[10,20,35]`):
목표 TTK 3타(뿔토끼와 동급 — 원거리라 접근에 시간이 들지만, 일단 붙잡으면 만만한 개체라는 "호루라기가 진짜 위협"
설계 의도) → HP=24 (누적 20과 35 사이, 3타째 35에서 처치, 여유 11). 직접 공격력은 낮게(10) 잡아 "다트 자체는
안 아프고, 진짜 위협은 증원 호출"이라는 역할을 명확히 한다.

| 필드 | 값 | 비고 |
|---|---|---|
| `hp` | 24 | TTK 3타 |
| `atk` | 10 | 다트 직격, 슬라임(8)보다 약간 높고 뿔토끼(15)보다 낮음 |
| `move_speed_px` | 45 | 순찰 중 이동. 대시 없음 |
| `telegraph_sec` | 0.5 | GDD 최소값(다트 투척은 예비동작이 짧다) |
| `attack_pattern_id` | `ranged_dart` | 신규 패턴 id(엔지니어 요청, §4-1) |
| `aggro_range_px` | 110 | 4종 중 최대 — 원거리형이라 조기 감지해야 도주/호출 판단 시간이 생김 |
| `melee_range_px` | 90 | "근접 판정"이 아니라 **다트 발사 트리거 거리**로 해석(장판형 몬스터의 트리거 거리 해석 관례를 원거리형에 확장) |
| `attack_recovery_sec` | 0.9 | 원거리 딜레이, 뿔토끼(0.7)보다 약간 김 |
| `patrol_radius_px` | 80 | 경계 순찰 컨셉 |
| `leash_range_px` | 200 | `melee(90) < aggro(110) < leash(200)` 불변식 충족 |
| `whistle_cooldown_sec` | 12.0 | 아래 1-1-1 참고 |
| `whistle_cast_sec` | 1.0 | 호출 시전 시간(끊을 수 있는 창) |
| `whistle_range_px` | 140 | 이 반경 내 대상만 호출 가능 |
| `whistle_summon_pool` | `["horn_rabbit", "slime"]` | `hartland.md` ⑤ "증원(주변 뿔토끼/슬라임)" 그대로 |
| `whistle_summon_count` | 1 | 1회 호출당 소환 마리 수 |

#### 1-1-1. 호루라기 증원 호출 패턴 (일반판)

- 플레이어가 `aggro_range_px`(110) 안에 있고 `whistle_cooldown_sec`(12초)가 다 찼으면, `whistle_range_px`(140) 안의
  `whistle_summon_pool` 대상 1마리를 인식 상태로 즉시 전환(원거리 어그로 전이)한다.
- **"우선순위 타겟 학습 유도"(GDD 8.1)**: 정찰병을 방치할수록 호출이 반복돼 전장이 복잡해지므로, 플레이어는
  "먼저 죽여야 할 대상"을 스스로 학습하게 된다. 쿨다운 12초는 뿔토끼 TTK(3타, 대략 3~5초 교전)보다 넉넉히 길어
  "잡을 시간은 충분히 준다"는 공정성을 유지한다.
- `whistle_cast_sec`(1.0초)은 GDD 4.2 예고 최소값(0.5초)의 2배 — 호출 자체가 데미지가 없는 유틸 액션이라 강제
  규칙 대상은 아니지만, "정찰병에게 달려들어 시전을 끊는다"는 카운터플레이를 성립시키려면 충분히 길어야 한다.

### 1-2. 고블린 정찰대장 (`elite_goblin_captain`, 정예)

§1-0 배율을 `goblin_scout`에 그대로 적용한 값 + `hartland.md` ⑤ 강화 패턴("호루라기 범위 확대 + 소환 웨이브 1회 추가").

| 필드 | 값 | 계산 |
|---|---|---|
| `hp` | 120 | 24 × 5.0 |
| `atk` | 15 | 10 × 1.5 |
| `move_speed_px` | 52 | 45 × 1.15 = 51.75 → 반올림 |
| `telegraph_sec` | 0.5 | `max(0.5, 0.5−0.1)` — 하한 적용, 변화 없음 |
| `aggro_range_px` | 132 | 110 × 1.2 |
| `melee_range_px` | 90 | 불변 |
| `attack_recovery_sec` | 0.81 | 0.9 × 0.9 |
| `patrol_radius_px` | 80 | 불변 |
| `leash_range_px` | 240 | 200 × 1.2 (`240 > 132 > 90` 충족) |
| `whistle_cooldown_sec` | 10.0 | 기본보다 약간 짧게 — 압박 강화 |
| `whistle_cast_sec` | 1.0 | 카운터플레이 창은 유지(공정성) |
| `whistle_range_px` | 210 | 140 × 1.5 — "범위 확대" |
| `whistle_summon_pool` | `["horn_rabbit", "slime", "goblin_scout"]` | 계급이 높아 동족(정찰병)도 호출 가능 |
| `whistle_summon_count` | 2 | 정기 호출 1회당 2마리 |
| `wave_trigger_hp_pct` | 0.5 | **강화 패턴**: HP 50% 도달 시 1회만 발동 |
| `wave_cast_sec` | 1.5 | 정기 호루라기(1.0초)보다 긴 시전 — "큰 이벤트가 온다"는 정보량 강화 |
| `wave_summon_count` | 3 | 웨이브 1회 소환 마리 수 |
| `wave_summon_pool` | `["horn_rabbit", "slime", "goblin_scout"]` | |
| `wave_once_per_life` | true | 재발동 없음 — GDD 8.2 "패턴 강화"를 정예 스케일로 축소한 버전(페이즈 1개짜리 보스 미니어처) |
| `drop_table_id` | `"elite_goblin_captain"` | `drop_tables.json`에 실존(D-67 규칙 충족) |
| `tier` | `"elite"` | |
| `codex_entry_id` | `"elite_goblin_captain"` | |

**TTK 검증**: `player_base_attack=10` 3타 콤보 사이클당 누적 35 데미지. HP120 → 4회 온전한 콤보(140) 필요 ≈ 히트
수 기준 `goblin_scout`(3타) 대비 약 4배 — F6-3 "희귀~영웅 + 도면 확률" 보상에 걸맞은 장기 교전. (이 계산은 M1 무장비
베이스라인이며, 실제 M2 플레이어는 장비 atk가 붙어 더 빨리 잡는다 — §2-3에서 재검증)

### 1-3. 뭉치의 새끼 (`elite_bunchi_spawn`, 정예) — 슬라임 분열 변종

베이스 = `slime`(기존 `monsters.json`, hp18/atk8/move40/telegraph0.5/aggro64/melee14/recovery0.4/patrol32/leash140).
강화 패턴(`hartland.md` ⑤ "분열체") = **처치 시 일반 슬라임 2마리로 분열**.

| 필드 | 값 | 계산 |
|---|---|---|
| `hp` | 90 | 18 × 5.0 |
| `atk` | 12 | 8 × 1.5 |
| `move_speed_px` | 46 | 40 × 1.15 |
| `telegraph_sec` | 0.5 | 하한 적용, 변화 없음 |
| `aggro_range_px` | 77 | 64 × 1.2 |
| `melee_range_px` | 14 | 불변 |
| `attack_recovery_sec` | 0.36 | 0.4 × 0.9 |
| `patrol_radius_px` | 32 | 불변 |
| `leash_range_px` | 168 | 140 × 1.2 (`168 > 77 > 14` 충족) |
| `on_death_split_monster_id` | `"slime"` | 기존 `slime` 엔트리를 그대로 재사용 — GDD 8.1 "골격 재사용" 원칙, 신규 애셋 불필요 |
| `on_death_split_count` | 2 | |
| `on_death_split_spawn_radius_px` | 24 | 사망 지점 주변에 스폰 |
| `drop_table_id` | `"elite_bunchi_spawn"` | `drop_tables.json`에 실존 |
| `tier` | `"elite"` | |
| `codex_entry_id` | `"elite_bunchi_spawn"` | |

**분열 재귀 방지**: 분열로 스폰된 `slime` 개체는 일반 슬라임과 동일 데이터(재분열 없음)이므로 데이터 상으로는
안전하다 — 별도의 "재귀 금지 플래그"가 필요 없다(정예 전용 필드인 `on_death_split_*`가 일반 `slime` 엔트리에는
아예 없기 때문). 엔지니어는 스폰 로직에서 "이 개체가 `elite_bunchi_spawn`인가"만 확인하면 된다.

**TTK 검증**: HP90 → 콤보 2.5회(87.5) ≈ 슬라임(2타) 대비 약 4.5배 히트 수. 정찰대장(§1-2)과 오차범위 내로 맞춰
"어느 쪽을 잡아도 손해 없다"는 `items-and-drops-m2.md` §5-2 설계 의도(두 정예 보상표가 완전히 동일한 이유)와
전투 난이도 측면에서도 정합된다.

### 1-4. `monsters.json` 반영용 JSON (엔지니어가 그대로 복사)

```json
{
  "goblin_scout": {
    "monster_id": "goblin_scout",
    "name_ko": "고블린 정찰병",
    "region_id": "hartland",
    "tier": "normal",
    "hp": 24,
    "atk": 10,
    "move_speed_px": 45,
    "telegraph_sec": 0.5,
    "attack_pattern_id": "ranged_dart",
    "aggro_range_px": 110,
    "melee_range_px": 90,
    "attack_recovery_sec": 0.9,
    "patrol_radius_px": 80,
    "leash_range_px": 200,
    "whistle_cooldown_sec": 12.0,
    "whistle_cast_sec": 1.0,
    "whistle_range_px": 140,
    "whistle_summon_pool": ["horn_rabbit", "slime"],
    "whistle_summon_count": 1,
    "drop_table_id": null,
    "codex_entry_id": "goblin_scout",
    "tags": [],
    "_comment": "elite-and-farming-m2.md §1-1(D-75 예정). TTK 목표 3타(player_base_attack=10 단순모델). drop_table_id=null: drop_tables.json에 goblin_scout 전용 테이블이 아직 없음(엔지니어 요청 §4-1) — D-67 규칙상 null은 유효하나 임시 상태이므로 M2 F3 후속 패스에서 테이블 추가 후 갱신할 것. AI 공통 5필드는 combat-tuning-m1-addendum.md §4 방법론을 신규 종에 확장 적용."
  },

  "elite_goblin_captain": {
    "monster_id": "elite_goblin_captain",
    "name_ko": "고블린 정찰대장",
    "region_id": "hartland",
    "tier": "elite",
    "hp": 120,
    "atk": 15,
    "move_speed_px": 52,
    "telegraph_sec": 0.5,
    "attack_pattern_id": "ranged_dart",
    "aggro_range_px": 132,
    "melee_range_px": 90,
    "attack_recovery_sec": 0.81,
    "patrol_radius_px": 80,
    "leash_range_px": 240,
    "whistle_cooldown_sec": 10.0,
    "whistle_cast_sec": 1.0,
    "whistle_range_px": 210,
    "whistle_summon_pool": ["horn_rabbit", "slime", "goblin_scout"],
    "whistle_summon_count": 2,
    "wave_trigger_hp_pct": 0.5,
    "wave_cast_sec": 1.5,
    "wave_summon_count": 3,
    "wave_summon_pool": ["horn_rabbit", "slime", "goblin_scout"],
    "wave_once_per_life": true,
    "drop_table_id": "elite_goblin_captain",
    "codex_entry_id": "elite_goblin_captain",
    "tags": [],
    "elite_base_monster_id": "goblin_scout",
    "_comment": "elite-and-farming-m2.md §1-2(D-75 예정). 배율 규칙(§1-0): hp x5.0, atk x1.5, move x1.15, telegraph=max(0.5,base-0.1), aggro/leash x1.2, melee/patrol 불변, recovery x0.9. 강화 패턴=호루라기 범위 확대(x1.5)+HP50% 1회 소환 웨이브(hartland.md ⑤). drop_table_id='elite_goblin_captain'은 drop_tables.json에 실존(D-67). elite_base_monster_id는 참고용 신규 필드(스키마 미확정, 엔지니어 요청 §4-1)."
  },

  "elite_bunchi_spawn": {
    "monster_id": "elite_bunchi_spawn",
    "name_ko": "뭉치의 새끼",
    "region_id": "hartland",
    "tier": "elite",
    "hp": 90,
    "atk": 12,
    "move_speed_px": 46,
    "telegraph_sec": 0.5,
    "attack_pattern_id": "melee_contact",
    "aggro_range_px": 77,
    "melee_range_px": 14,
    "attack_recovery_sec": 0.36,
    "patrol_radius_px": 32,
    "leash_range_px": 168,
    "on_death_split_monster_id": "slime",
    "on_death_split_count": 2,
    "on_death_split_spawn_radius_px": 24,
    "drop_table_id": "elite_bunchi_spawn",
    "codex_entry_id": "elite_bunchi_spawn",
    "tags": [],
    "elite_base_monster_id": "slime",
    "_comment": "elite-and-farming-m2.md §1-3(D-75 예정). 배율 규칙(§1-0)을 slime(hp18/atk8/move40/aggro64/melee14/recovery0.4/patrol32/leash140)에 적용. 강화 패턴=분열(처치 시 slime 2마리 스폰, 재귀 없음 - 스폰된 개체는 일반 slime 데이터를 그대로 씀). drop_table_id='elite_bunchi_spawn'은 drop_tables.json에 실존(D-67). 2막 스토리(3.1)의 동일 개체 재사용."
  }
}
```

---

## 2. 파밍 소스 7종 (`farming_sources.json`, D-77 예정)

### 2-1. 소스 목록과 리스폰 주기

GDD 6.5 표(7개 카테고리, `type` enum — `data_tables.md` §11)를 하틀랜드에 실제 배치했다. 정예만 개체별 독립
타이머가 필요해(F6-3: 정예마다 별도의 이름표+HP바+월드맵 아이콘) 2개 `source_id`로 나눴다 — 그래서 파일은 8행이지만
"7종"은 카테고리 수를 뜻한다.

| # (GDD 6.5 순서) | `source_id` | `type` | `respawn_seconds` | 실제 단위 | 보상 테이블 | 첫클리어 구분 |
|---|---|---|---|---|---|---|
| 1. 필드 사냥터 | `field_hartland` | field | 0 | 상시 | slime_common / horn_rabbit_common / mushroom_common | 없음(상시 반복형) |
| 2. 정예 몬스터 | `elite_goblin_captain` | elite | 1800 | 30분 | elite_goblin_captain | 없음(F6-3 미언급) |
| | `elite_bunchi_spawn` | elite | 1800 | 30분 | elite_bunchi_spawn | 없음 |
| 3. 미니 던전 | `mini_dungeon_echo_cave` | mini_dungeon | 86400 | 1일 | field_treasure_chest (+정령 조각 고정) | **있음**(정령 조각 고정 지급으로 차별화) |
| 4. 지역 던전 | `region_dungeon_hartland` | region_dungeon | 0 | 재입장 자유 | 미정(§2-4) | 미정 |
| 5. 월드 보스 | `world_boss_hartland` | world_boss | 259200 | 3일 | 미정(§2-4) | 미정 |
| 6. 낚시·채광·채집 | `gathering_hartland` | gathering | 0 | 상시 | 해당 없음(spawns.json 고정 지급, §2-4) | 없음 |
| 7. 보물 지도 | `treasure_map_hartland` | treasure_map | 0(쿨다운 아님) | 지도 소지 시 즉시 | field_treasure_chest | 없음 |

리스폰 주기는 모두 D-15(실제 플레이 시간 기준, 오프라인 미포함)를 따른다. 정예·미니던전·월드보스는 GDD 6.5의
30분/1일/3일 그대로이며, 이는 `docs/levels/hartland.md` ⑤가 이미 확정한 좌표·리스폰값과 동일하다(중복 결정 아님,
동일 소스를 파밍 소스 스키마로 옮겨 적은 것).

### 2-2. `first_clear`/`repeat` 스키마를 배열로 확장한 이유

`data_tables.md` §11은 `first_clear_reward_table_id`/`repeat_reward_table_id`를 **단수 문자열**로 정의한다. 그러나
"필드 사냥터" 하나에 실제로는 몬스터 3종(향후 고블린 정찰병까지 4종)의 서로 다른 드랍 테이블이 걸려 있어 단수
필드로는 표현이 안 된다. 이 문서는 `repeat_reward_table_ids`/`first_clear_reward_table_ids`(복수형 배열)로
**모든 소스에 일괄 적용**해 스키마를 통일했다(필드가 하나뿐인 소스도 배열 길이 1로 통일 — 검증 스크립트 분기 최소화).
이 스키마 변경은 §4 "엔지니어 요청"으로 `data_tables.md` §11 갱신을 요청한다(이 세션은 그 문서를 직접 고치지 않는다).

### 2-3. 정예 시간당 기대 골드/장비 재검증 (`items-and-drops-m2.md` §5-3 재계산)

`items-and-drops-m2.md` §5-3은 "정예 시간당 처치 수 80"을 가정해 시간당 rare 32개를 계산했지만, 그 문서 스스로
"정예는 30분 쿨다운이 있어 실제 시간당 32개가 아니다"라고 결정 요청 D로 상위 이관했다. 이제 `farming_sources.json`이
확정되어 **하틀랜드에는 정예 스폰 지점이 정확히 2곳(모두 1800초 독립 타이머)뿐**임을 알 수 있으므로 재계산한다.

**전제**: 두 정예 모두 `grade_base_weight={common:0.15, uncommon:0.45, rare:0.40}`, `gold_drop={25~45}`
(`drop_tables.json` 실측값). 아이템은 처치 1회당 1개 드랍(등급 1회 추첨 + 해당 등급 내 아이템 1회 추첨) 모델.

- 처치 1회 기대값: 골드 `(25+45)/2=35`, uncommon+ `0.45+0.40=0.85`개, rare `0.40`개 (`items-and-drops-m2.md`가
  이미 밝힌 "1회 처치당 rare 기대 0.40개"와 동일 — 이 부분은 원래도 맞았다).
- **오류였던 부분**: "시간당 처치 수 80"은 정예 1마리를 연속으로 80번 잡는다는 뜻인데, 리스폰이 1800초(30분)이므로
  같은 스폰 지점에서 물리적으로 가능한 최대 처치 수는 **시간당 2회**(3600/1800)뿐이다. 스폰이 2곳이므로 두 곳을
  완벽한 타이밍으로 순회해도 **시간당 최대 4처치**(정예 2종 × 2회)가 상한이다.

| 시나리오 | 시간당 처치 | 시간당 기대 골드 | 시간당 uncommon+ | 시간당 rare |
|---|---|---|---|---|
| 원문 §5-3 (오류, 정정 대상) | 160(80×2) | 5,600 | 136.0 | 64.0 |
| **정정: 정예만 완벽 순회(상한)** | **4**(2곳×2회) | **140** | **3.4** | **1.6** |
| **정정: 필드+정예 혼합 루트(현실적)**(아래) | 필드 상시 + 정예 4/hr | **≈1,635** | **≈86.2** | **1.6** |

**혼합 루트 계산** (30분 주기 1사이클 기준, 정예 왕복·처치에 2분씩 총 4분 소요 가정 → 필드 순수 사냥 26분):
- 필드 3종 평균(시간당): 골드 `(1,575+1,800+1,800)/3=1,725`, uncommon+ `(112.5+90+84)/3≈95.5`, rare `0`
  (`items-and-drops-m2.md` §5-3 필드 표 그대로 재사용).
- 26분(0.4333시간) 필드분: 골드 `747.6`, uncommon+ `41.4`.
- 정예 왕복 2회(각 1마리씩) 즉시 처치분: 골드 `2×35=70`, uncommon+ `2×0.85=1.7`, rare `2×0.40=0.80`.
- 30분 합계: 골드 `817.6`, uncommon+ `43.1`, rare `0.80` → **시간당(×2)**: 골드 `1,635.2`, uncommon+ `86.2`,
  rare `1.6`.

**해석 (레벨 디자인 시사점)**:
1. 정예를 "혼자 반복 사냥하는 활동"으로 취급하면 시간당 기댓값이 필드보다 **오히려 낮다**(140 vs 1,725 골드) —
   정예는 **시간당 파밍 효율 콘텐츠가 아니라 필드 루프 위에 얹는 "주기적 확정 보너스"** 로 설계돼야 한다는 뜻이다.
   이는 F3-5의 원래 의도("오늘 할 것 목록의 최우선 항목")와 정합 — "효율"이 아니라 "오늘 들렀는가"가 핵심.
2. 혼합 루트에서 정예는 필드 루프에 **시간당 rare +1.6개를 공짜로 얹는다**(필드 단독은 rare 0) — 이 값이 F3-5
   "오늘 할 것" 리텐션 설계의 진짜 수치적 근거다.
3. M3에서 지역이 5개로 늘어나면 정예 스폰 지점도 10곳(지역당 2종)이 되어, 여러 지역을 순회하는 상위 플레이어는
   `items-and-drops-m2.md` 원문이 가정했던 "시간당 다수 처치"에 근접하게 된다 — 즉 원문 가정은 **"5개 지역을 모두
   순회할 수 있는 M3 후반 플레이어"에게는 근사적으로 유효**하고, M2(하틀랜드 1개 지역)에서만 크게 어긋난다. 이
  조건을 `items-and-drops-m2.md` §5-3에 각주로 남기도록 §5 결정 요청에 반영을 요청한다.

### 2-4. 미정 보상 (M2 범위에서 채울 수 없는 항목)

- `region_dungeon_hartland`·`world_boss_hartland`의 보상 테이블: GDD 6.5가 요구하는 "영웅~전설"/"전설 확정"은
  epic 이상 등급 아이템이 최소 1개는 있어야 성립하는데, M2는 epic+ 아이템을 만들지 않는다
  (`items-and-drops-m2.md` §5-1, 결정 요청 C). 몬스터 본체(`corrupted_ox_deumjigi`)도 없다. 좌표·리스폰 주기만
  선반영하고 보상은 M3로 이관한다(§5 결정 요청).
- `gathering_hartland`: 낚시/채집/채광은 `drop_tables.json`의 확률 롤 구조가 아니라 `spawns.json`
  (레벨 디자인 소유, D-51)의 `gathering_nodes`가 정의하는 고정 `item_id` 목록에서 직접 획득한다 — 이 소스에
  `reward_table_id`가 비어 있는 것이 정상이다(§4 검증 규칙 참고).

---

## 3. `stats.json` — 스탯 효과 계수 (D-45·D-78 예정)

### 3-1. 레벨업 3요소

`max_level=50`, `stat_points_per_levelup=3`, `skill_points_per_levelup=1` — GDD 5.1 그대로, 계산 근거 불필요(GDD가
이미 확정한 리터럴 값).

### 3-2. 구르기 DEX 경감식 (D-45, 재확인만)

`stats.json.dex.stamina_cost_reduction_formula = "cost * (1 - min(0.5, DEX/300))"` — `combat-tuning-m1.md` §3-3과
**문자열까지 동일**해야 한다(`data_tables.md` §3 검증 규칙). 범위는 구르기 전용(`stamina_cost_reduction_scope:
"roll_only"`), 강공격/가드 확장은 D-45가 이미 "M2 플레이테스트 후" 유예했으므로 이 문서에서 건드리지 않는다.

| DEX | 경감 비율 | 실제 구르기 소모(기본 20) |
|---|---|---|
| 0 | 0% | 20.0 |
| 50 | 16.7% | 16.7 |
| 100 | 33.3% | 13.3 |
| 150 이상 | 50%(상한) | 10.0 |

추가로 GDD 5.2가 명시하지만 아직 어떤 문서에도 계수가 없던 DEX의 나머지 2효과(공격 속도, 원거리 데미지)를
`_balance_todo` 제안값으로 채웠다(`attack_speed_per_point=0.0015`, `ranged_damage_per_point=0.15`) — 둘 다 M1
코드에 훅이 없어 **현재는 순수 데이터로만 존재**한다(엔지니어 요청 §4-1).

### 3-3. 크리티컬 확률 (LUK)

GDD 5.2 "행운 LUK → 아이템 드랍률, 크리티컬 확률". **드랍률 공식은 이 파일에서 절대 재정의하지 않는다** — D-52가
이미 `drop_tables.json._luck_formula`를 단일 소스로 못박았고, `items-and-drops-m2.md` §4·결정 요청 E가
"`stats.json` 생성 시 문자열을 새로 쓰지 말고 참조만 하라"고 명시했다. 이 요구를 문자 그대로 구현했다:

```json
"luk": { "_luck_formula_ref": "drop_tables.json", ... }
```

`luk.drop_weight_formula`(문자열 복제 필드, `data_tables.md` §3 원안)는 **의도적으로 만들지 않았다** — 만드는 순간
공식이 두 파일에 존재하게 되어 D-52가 막으려던 문제가 재발한다. `data_tables.md` §3 문서 자체를 이 방식으로
갱신해달라는 요청을 §4에 남긴다.

크리티컬 확률은 LUK의 두 번째 효과로, 드랍률과 별개 계수를 새로 도입했다(`combat.json.camera_shake`의 주석이
"진짜 크리티컬은 M2 LUK 도입 후"라고 예고했던 부분 — 이 문서가 그 시점이다):

```
crit_chance = base_crit_chance(0.05) + LUK * crit_chance_per_point(0.001), capped at crit_chance_cap(0.75)
crit_damage = base_damage * crit_damage_multiplier(1.5)   # 원소 상성 배율(1.5, D-08)과 동일 수치로 통일해 "결정타" 신호를 일관되게 유지
```

| LUK | 크리티컬 확률 |
|---|---|
| 0 | 5.0% |
| 20 | 7.0% |
| 45(레벨15 풀분배) | 9.5% |

LUK을 크리 확률에 과하게 태우지 않은 이유: GDD가 LUK을 "파밍 게임의 핵심 재미 스탯"으로 못박은 축은 드랍률이지
전투 딜사이클이 아니다 — 크리 확률은 보조 보너스로 남겨, LUK 스탯이 "드랍이냐 전투냐"로 분열되지 않게 한다.

### 3-4. 방어력 소비 공식 D-74(예정) 임시값

```
damage_taken = incoming_atk * 100 / (100 + defense)
```

`items-and-drops-m2.md` 결정 요청 A / `data_tables.md` 결정 요청 12가 제안한 식을 그대로 `stats.json.vit`에
`_balance_todo`로 반영했다(`defense_formula_status: "provisional_pending_D-74"`). **주의**: 아직 정식 결정(D-74)이
나지 않았으므로 엔지니어는 이 공식을 실제 피해 계산 코드에 연결하지 말고, `defense` 스탯 자체(수치 노출·UI 표시)만
먼저 구현해도 된다 — §4·§5에서 결정 요청으로 재확인한다.

| defense | 피해 감소율 |
|---|---|
| 0 | 0% |
| 50 | 33.3% |
| 100 | 50.0% |
| 150 | 60.0% |

`vit.defense_per_point=1.0`(임시): 레벨15 풀분배(약 42포인트) 기준 defense 42 → 감소율 약 29.6%, 여기에 장비
`defense_flat` 옵션(2~6/슬롯)과 방어구 `base_stats.defense`(§2-1 아이템 스펙, 카테고리별 1~16)가 더해져 M2 후반
defense 80~120대(감소율 45~55%)에 도달하도록 설계했다 — GDD 5.3 "전투력 60%는 장비" 목표와 동일한 비율 감각을
방어 스탯에도 적용했다.

---

## 4. 검증 규칙 & 엔지니어 요청

### 4-1. `monsters.json` 반영 시 (§1 관련)

1. **신규 필드**: `whistle_cooldown_sec`/`whistle_cast_sec`/`whistle_range_px`/`whistle_summon_pool`(array[string])/
   `whistle_summon_count`(정찰병·정찰대장 공용), `wave_trigger_hp_pct`/`wave_cast_sec`/`wave_summon_count`/
   `wave_summon_pool`/`wave_once_per_life`(정찰대장 전용), `on_death_split_monster_id`/`on_death_split_count`/
   `on_death_split_spawn_radius_px`(뭉치의 새끼 전용), `elite_base_monster_id`(정보용, 두 정예 공용) — 모두
   `MONSTER_REQUIRED_FIELDS`(`data.gd`)에는 넣지 말 것(종별 선택 필드), 다만 `data_tables.md` §12 표에 "○ (정예
   전용)" 행으로 문서화 요청.
2. **신규 패턴 id**: `ranged_dart`(고블린 계열) — `attack_pattern_id` 분기 스크립트(`monster_base.gd`로 추정)에
   `melee_contact`/`charge`/`spore_patch`와 나란히 추가.
3. `drop_table_id`가 `"elite_goblin_captain"`/`"elite_bunchi_spawn"`인 두 엔트리는 **지금 바로** D-67 교차 검증을
   통과한다(`drop_tables.json`에 실존, 이미 확인함). `goblin_scout`은 `null` 유지 — 향후 전용 테이블 추가 시 갱신.
4. `region_id`: 기존 3종(`slime`/`horn_rabbit`/`mushroom`)은 `"greenfield_prototype"`(M1 프로토타입 잔재)이고
   이번에 추가하는 3종은 `"hartland"`(실제 지역 ID, `hartland.md` 스키마 초안과 동일)이다 — **의도적 불일치**이며,
   기존 3종을 언제 `"hartland"`로 마이그레이션할지는 결정 필요(§5).

### 4-2. `farming_sources.json` 검증 규칙 (`tools/qa/validate_tables.py`에 추가 요청)

1. `respawn_seconds ≥ 0`, 그리고 `type`별 GDD 6.5 기준과 일치: `field`/`gathering`/`treasure_map`/`region_dungeon`
   = 0 허용, `elite` = 1800, `mini_dungeon` = 86400, `world_boss` = 259200.
2. `repeat_reward_table_ids`/`first_clear_reward_table_ids`의 각 원소가 `drop_tables.json`의 실제 `source_id`
   (즉 `_comment`/`_luck_formula`를 제외한 키)로 존재해야 한다. **예외**: `type`이 `gathering`이거나, 아직 보상
   미확정으로 명시된 소스(`region_dungeon_hartland`, `world_boss_hartland`)는 빈 배열이어도 오류 아님.
3. `type`이 `elite`인 모든 `source_id`는 `monsters.json`에 `tier: "elite"`이고 `drop_table_id`가 해당
   `repeat_reward_table_ids[0]`과 일치하는 몬스터 엔트리가 최소 1개 존재해야 한다(교차 검증).
4. `show_respawn_icon_on_map=true`인 소스는 GDD 7.3 "정예·월드 보스 리스폰 상태 아이콘" 대상과 정확히 일치해야
   한다(현재는 `elite`·`world_boss` 2개 타입만 true).

### 4-3. `stats.json` 검증 규칙

1. `dex.stamina_cost_reduction_formula` 문자열이 `combat.json._comment`/`combat-tuning-m1.md` §3-3과 정확히
   동일한지 문자열 비교(기존 `data_tables.md` §3 규칙 그대로).
2. `luk._luck_formula_ref == "drop_tables.json"` 고정값 검증 + `luk`에 `drop_weight_formula`라는 키가 **존재하지
   않아야 함**(중복 정의 재발 방지 — 있으면 오류로 처리해달라는 신규 규칙 제안).
3. `*.cap`/`*_cap_pct` 계열(`luk.crit_chance_cap`, `int.cooldown_reduction_cap_pct`) 값이 `0~1` 범위인지, 그리고
   해당 `*_per_point`로 만렙 풀분배(약 147포인트, 한 스탯 몰빵 가정) 도달 시에도 상한을 넘지 않는지(넘으면 상한이
   사실상 의미 없어짐 — 경고만, 에러 아님) 확인.
4. `vit.defense_formula_status == "provisional_pending_D-74"`인 동안은 코드가 이 공식을 실제 데미지 계산에
   연결하지 않았는지 별도로 확인할 방법이 없음(런타임 검증 불가, 코드 리뷰 항목으로 대체 요청).

### 4-4. `data.gd` REQUIRED_SCHEMA 반영 요청 (godot-engineer)

M1 시점 `REQUIRED_SCHEMA`는 `combat`/`elements`만 다루고 `monsters`는 `MONSTER_REQUIRED_FIELDS` 전용 검증 함수로
별도 처리 중이다(`items-and-drops-m2.md` §10과 동일한 상황이 `stats`/`farming_sources`에도 해당). 요청:

1. `stats.json`을 위한 `_validate_stats()` 함수 신설 — `REQUIRED_SCHEMA["stats"]`에 `max_level`,
   `stat_points_per_levelup`, `skill_points_per_levelup`, `dex.stamina_cost_reduction_formula`,
   `luk._luck_formula_ref`, `vit.defense_formula` 최소 등록.
2. `farming_sources.json`을 위한 `_validate_farming_sources()` 함수 신설 — §4-2 규칙 1·2를 코드 레벨로 이식.
3. `Data._validate()`에 `farming_sources.json.*.repeat_reward_table_ids[]` → `drop_tables.json` 키 존재 확인
   교차 검증 추가(§4-2 규칙 2와 동일 로직, `items-and-drops-m2.md` §10 요청 5의 `monsters.drop_table_id` 교차
   검증과 같은 패턴으로 구현 가능).
4. `docs/specs/data_tables.md` §11 표를 `repeat_reward_table_id`(단수) → `repeat_reward_table_ids`(복수 배열)로,
   §3 표를 `luk.drop_weight_formula` → `luk._luck_formula_ref`로 갱신 요청(이 세션은 그 문서를 직접 수정하지
   않았다 — 메인 세션/문서 소유자 승인 후 반영).

---

## 5. 신규 결정 요청 목록 (ID는 메인 세션 부여 — D-74·D-75·D-77·D-78 정식 반영 포함)

| 항목 | 내용 | 관련 절 |
|---|---|---|
| D-74 예정 (방어력 공식) | `damage_taken = incoming_atk * 100/(100+defense)`를 정식 확정할지, 아니면 다른 식을 쓸지 — `items-and-drops-m2.md` 결정 요청 A / `data_tables.md` 결정 요청 12와 동일 건. 확정 전까지 `stats.json.vit.defense_formula`는 `_balance_todo`·`defense_formula_status`로 계속 표시 | §3-4 |
| D-75 예정 (정예 2종 스탯) | `goblin_scout`(신규 일반 몬스터)·`elite_goblin_captain`·`elite_bunchi_spawn`의 HP/ATK/AI 필드·강화 패턴(§1-4 JSON 블록)을 `monsters.json`에 정식 반영 승인 — `items-and-drops-m2.md` 결정 요청 B / `data_tables.md` 결정 요청 13 해소 | §1 |
| D-76 관련 (epic 게이트, 참고) | `region_dungeon_hartland`/`world_boss_hartland`의 보상 테이블이 epic+ 아이템 부재로 비어 있다 — 기존 결정 요청 C(`items-and-drops-m2.md`)와 동일 건이 파밍 소스 레벨에서도 재확인됨. M3 epic 아이템 추가 시 두 소스를 함께 채울 것 | §2-4 |
| D-77 예정 (파밍 소스 7종) | `farming_sources.json`의 8행(7카테고리, 정예 2개체 분리) 구조·리스폰 주기·`repeat_reward_table_ids` 배열 스키마를 정식 승인. `data_tables.md` §11을 단수→복수 필드로 갱신하는 것도 함께 승인 필요(§4-4 요청 4) | §2 |
| D-78 예정 (LUK 공식 참조 방식) | `stats.json.luk._luck_formula_ref = "drop_tables.json"` 방식을 정식 채택하고 `data_tables.md` §3의 `luk.drop_weight_formula`(문자열 복제) 표기를 폐기 — `items-and-drops-m2.md` 결정 요청 E 최종 해소 | §3-3 |
| 신규 A | GDD 13장 로드맵 "M2 목표: 던전 1개·보스 1종"이 `region_dungeon_hartland`(지역 던전·거대 슬라임 킹)를 가리키는지, `world_boss_hartland`(월드 보스 제단)를 가리키는지, 아니면 둘 다 M3로 미루고 M2는 메아리 굴(미니던전)만으로 "버티컬 슬라이스"를 완성하는지 — 범위 확정 필요(레벨 디자인·엔지니어 일정에 직접 영향) | §2-4 |
| 신규 B | `goblin_scout` 전용 드랍 테이블(`drop_tables.json`에 `goblin_scout_common` 등 신규 source_id) 추가 담당·시점 배정 — `field_hartland.repeat_reward_table_ids`가 현재 3종만 포함하고 있어 완전하지 않음 | §1-1, §2-1 |
| 신규 C | 기존 `monsters.json` 3종(`slime`/`horn_rabbit`/`mushroom`)의 `region_id`를 `"greenfield_prototype"`에서 `"hartland"`로 마이그레이션할 시점 결정(§4-1의 의도적 불일치 해소) | §4-1 |
