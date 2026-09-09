# 데이터 테이블 스키마 명세

> 기준: GDD 12장(기술 사양), `docs/brd/03-features/08-시스템-기반.md` F8-4, 각 기능 문서(`docs/brd/03-features/*.md`)의 `데이터` 슬롯
> 목적: `game/data/` 아래 모든 밸런스 테이블의 파일·용도·소유·필수 키·참조 관계·검증 규칙을 한곳에 모은다. F8-4가 요구하는 "테이블 목록·스키마는 `docs/specs/data_tables.md`"의 산출물.
> 소유 표기: **game-designer** = 이 문서를 쓰는 전투/성장/아이템/경제/스킬 밸런스 담당 / **콘텐츠·월드** = 퀘스트·NPC·기후·기믹 등 레벨/내러티브 디자인 담당(현재 조직에 전담 에이전트가 없다면 game-designer가 자리표시자 값을 채우고 담당 배정은 메인 세션에 요청) / **godot-engineer** = 스키마 구현·로더·검증 스크립트 담당(수치 소유 아님)
> 공통 검증(모든 테이블 공통 적용, F8-4 "동작" 슬롯 근거): ① 참조 ID 존재(다른 테이블이 가리키는 id가 실제로 있어야 함) ② 필수 필드 누락 없음(부팅 시 `Data._validate()` 통과) ③ 확률/가중치 합계 규칙(표별로 명시) ④ 단조성 규칙(표별로 명시)

---

## 0. 로딩·검증 파이프라인 (참고, `game/scripts/core/data.gd`)

- 모든 테이블은 `game/data/*.json`에서 파일명(확장자 제외)을 테이블명으로 로드된다. CSV(`exp_curve.csv`)는 별도 파서가 필요 — 아래 §5에서 별도 명시.
- `REQUIRED_SCHEMA`(점 표기 경로)에 등록된 키가 없으면: 개발 빌드는 `push_error`+`assert`로 중단, 릴리즈 빌드는 `RELEASE_FALLBACKS`로 대체 후 경고 로그.
- 본 문서의 "필수 키" 표는 `REQUIRED_SCHEMA`에 반드시 등록되어야 하는 항목(●)과 있으면 검증되지만 코드 동작에 필수는 아닌 선택 항목(○)을 구분한다.
- `_comment`, `_balance_todo`로 시작하는 키는 메타 정보이며 스키마 검증 대상이 아니다(사람이 읽는 주석/작업 표시).

---

## 1. combat.json — 전투 프레임 수치 (완전 정의)

**용도**: F2-1~F2-4(기본 전투, 타격감, 스태미나, 속성) 전 항목의 수치 원본.
**소유**: game-designer (godot-engineer는 로더/검증만).
**파일 형태**: 단일 JSON, 중첩 객체.
**밸런스 근거 문서**: `docs/specs/combat-tuning-m1.md`

### 필수 키 (● REQUIRED_SCHEMA 등록, ○ 선택)

| 키(점 표기) | 타입 | 범위/단위 | 필수 | 설명 | 근거 |
|---|---|---|---|---|---|
| `frame_rate_reference` | int | 60 고정 | ○ | 프레임 수치의 기준 fps | GDD 4.1 |
| `roll.iframes_sec` | float | sec, =0.3 | ● | 구르기 무적 시간 | GDD 4.1 (확정) |
| `roll.duration_sec` | float | sec, >iframes_sec | ○ | 구르기 전체 지속시간 | `combat-tuning-m1.md` §2 (0.45 확정) |
| `roll.distance_px` | float | px | ○ | 구르기 이동 거리 | `combat-tuning-m1.md` §2 (48 확정) |
| `guard.just_guard_window_frames` | int | frames, =6 | ● | 저스트 가드 판정창(프레임) | D-05 (확정) |
| `guard.just_guard_window_sec` | float | sec, = frames/60 | ○ | 저스트 가드 판정창(초), frames와 항상 일치해야 함 | D-05 |
| `guard.chip_damage_ratio` | float | 0~1 | ○ | 가드 시 통과 데미지 비율 | `combat-tuning-m1.md` §5 (0.2 확정) |
| `guard.just_guard_enemy_stagger_sec` (신규) | float | sec | ○ | 저스트 가드 성공 시 적 경직시간 | `combat-tuning-m1.md` §5-3 (0.4 제안) |
| `hitstop.min_sec` | float | sec, =0.05 | ● | 히트스톱 최소값 | GDD 4.2 (확정) |
| `hitstop.max_sec` | float | sec, =0.1 | ● | 히트스톱 최대값 | GDD 4.2 (확정) |
| `hitstop.normal_sec` (신규) | float | sec | ○ | 일반 타격 히트스톱 | `combat-tuning-m1.md` §6-1 (0.05 확정) |
| `hitstop.heavy_crit_sec` (신규) | float | sec | ○ | 강공격/크리티컬 히트스톱 | `combat-tuning-m1.md` §6-1 (0.1 확정) |
| `telegraph.min_sec` | float | sec, =0.5 | ● | 몬스터 공격 최소 예고시간 | GDD 4.2 (확정) |
| `combo.hits` | int | =3 | ● | 콤보 히트 수 | GDD 4.1 (확정) |
| `combo.damage_multipliers` | array[float]×3 | 각 >0 | ● | 타별 데미지 배율 | `combat-tuning-m1.md` §4 ([1.0,1.0,1.5] 확정) |
| `combo.input_buffer_sec` | float | sec | ○ | 콤보 입력 버퍼 구간 | §4 (0.2 확정) |
| `combo.reset_after_sec` | float | sec | ○ | 콤보 초기화 임계시간 | §4 (0.6 확정) |
| `combo.finisher_recovery_sec` (신규) | float | sec | ○ | 3타(피니셔) 후딜레이 | §4-2 (0.35 제안) |
| `movement.walk_speed_px` | float | px/s | ● | 보행 속도(16px 프로토타입 기준) | §1 (80.0 확정) |
| `movement.roll_speed_px` | float | px/s | ○ | **폐기 검토 대상** — `roll.distance_px/duration_sec`와 모순 (§2-3, 결정 요청 2) | — |
| `knockback.normal_px` (신규) | float | px | ○ | 일반 타격 넉백 거리 | §6-2 (8 제안) |
| `knockback.heavy_px` (신규) | float | px | ○ | 강공격 넉백 거리 | §6-2 (20 제안) |
| `stamina.max` | float | >0 | ● | 최대 스태미나 | §3 (100.0 확정) |
| `stamina.regen_per_sec` | float | >0, unit/s | ● | 초당 회복량 | §3 (25.0 확정) |
| `stamina.regen_delay_sec` | float | sec | ○ | 소모 중단 후 회복 시작까지 딜레이 | §3 (0.5 확정) |
| `stamina.exhausted_penalty_sec` | float | sec | ○ | 완전 고갈 시 추가 회복 딜레이 | §3-2 (1.0 확정, 기존 1.5에서 하향) |
| `stamina.costs.roll` | float | >0 | ● | 구르기 소모량 | §3 (20.0 확정) |
| `stamina.costs.heavy_attack` | float | >0 | ○ | 강공격 소모량 | §3 (25.0, M1 후 결정) |
| `stamina.costs.guard_hit` | float | >0 | ○ | 가드 피격당 소모량 | §3 (10.0, M1 후 결정) |
| `elements.advantage_multiplier` | float | =1.5 | ○ | 상성 적중 배율 | D-08 (확정) |
| `elements.cycle` | array[string]×4 | 4원소, 중복 없음 | ○ | 순환 상성 순서 | D-08 (확정, `["fire","wind","thunder","water"]`) |
| `elements.holy_bonus_vs_tags` | array[string] | 태그명 | ○ | 성속성 특효 대상 태그 | D-08 (확정, `["demon"]`) |

### 참조 관계
- `elements.holy_bonus_vs_tags`의 각 문자열은 `monsters.json`의 `tags` 배열에 실제로 등장해야 한다(참조 무결성).

### 검증 규칙
1. `hitstop.min_sec ≤ hitstop.normal_sec ≤ hitstop.heavy_crit_sec ≤ hitstop.max_sec`
2. `guard.just_guard_window_sec == guard.just_guard_window_frames / frame_rate_reference`
3. `combo.damage_multipliers.size() == combo.hits`
4. `roll.iframes_sec ≤ roll.duration_sec`
5. `elements.cycle.size() == 4`, 중복 없음
6. **스키마 정리 필요(결정 요청 2)**: `movement.roll_speed_px`를 유지한다면 `abs(movement.roll_speed_px − roll.distance_px/roll.duration_sec) ≤ 오차 허용치`를 만족해야 함 — 현재는 위반 상태(160 vs 106.7).

---

## 2. characters.json — 캐릭터별 기본 스탯·고유 메커니즘

**용도**: F1-1(캐릭터 선택), F2-5(고유 메커니즘).
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `character_id` | string enum | `fin`/`lyra`/`mori`/`bram` | ● | 캐릭터 식별자 |
| `name_key` | string | 로컬라이징 key | ● | 표시 이름 (`dialogue/*.json` 아님, UI 텍스트 테이블 참조) |
| `base_weapon_type` | string enum | `sword_shield`/`bow`/`staff`/`hammer` | ● | 시작 무기 |
| `base_stats.{str,dex,int,vit,luk}` | int | 각 1~99 | ● | 레벨1 시작 스탯 |
| `base_attack_power` | number | >0 | ● | 무기 미장착 기준 기본 공격력 (`combat-tuning-m1.md` §0: 핀=10) |
| `skill_tree_ids` | array[string]×3 | `skills.json`의 tree_id 참조 | ● | 계열 3종 |
| `unique_mechanic` | object | 캐릭터별 상이 | ● | 아래 참조 |

**`unique_mechanic` 캐릭터별 필드**
- 핀: `parry_window_sec`(number), `parry_damage_multiplier`(number) — `combat.json`의 `guard.just_guard_enemy_stagger_sec`와 정합 필요
- 리라: `hunter_mark_duration_sec`(number, 구르기 종료 후 자동조준 유효시간)
- 모리: `fusion_pairs`(array, 정확히 6개 — D-09), 각 원소 쌍 {element_a, element_b, result_skill_id}
- 브람: `charge_stages`(array[3], 각 {charge_time_sec, damage_multiplier})

### 참조 관계
- `skill_tree_ids` → `skills.json.tree_id` 존재해야 함
- `mori.fusion_pairs[].result_skill_id` → `skills.json` 존재해야 함

### 검증 규칙
- `character_id` 4종 정확히 존재, 중복 없음
- `mori.fusion_pairs.size() == 6` (D-09)

---

## 3. stats.json — 스탯 효과 계수

**용도**: F1-2(레벨·스탯 성장).
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `max_level` | int | =50 | ● | 최대 레벨 (GDD 5.1) |
| `stat_points_per_levelup` | int | =3 | ● | 레벨업당 스탯 포인트 |
| `skill_points_per_levelup` | int | =1 | ● | 레벨업당 스킬 포인트 |
| `str.physical_damage_per_point` | number | >0 | ● | STR 1당 물리 데미지 가중 |
| `dex.stamina_cost_reduction_formula` | string | 수식 문자열 | ● | `combat-tuning-m1.md` §3-3과 동일 수식 소스 (`cost * (1 - min(0.5, DEX/300))`) |
| `dex.attack_speed_per_point` | number | ≥0 | ○ | M1 미구현, M2용 |
| `int.magic_damage_per_point` | number | >0 | ● | INT 1당 마법 데미지 가중 |
| `int.cooldown_reduction_per_point` | number | 0~1 | ● | 스킬 쿨감, 상한 필요 |
| `vit.hp_per_point` | number | >0 | ● | VIT 1당 최대 HP |
| `vit.defense_per_point` | number | ≥0 | ○ | M1 방어 공식 미확정(§9-8 참고) |
| `luk.crit_chance_per_point` | number | 0~1 | ● | LUK 1당 크리 확률 |
| `luk.drop_weight_formula` | string | 수식 문자열 | ● | `drop_tables.json`의 LUK 곱연산 공식과 동일해야 함(§9 참조) |

### 검증 규칙
- `luk.drop_weight_formula`는 `drop_tables.json`에 명시된 `luk_multiplier` 공식과 문자열 동일성 또는 파라미터 동일성 체크(중복 정의 방지).

---

## 4. exp_curve.csv — 레벨 1~50 경험치 곡선

**용도**: F1-2.
**소유**: game-designer.
**형태**: CSV (JSON 로더와 별도 파서 필요 — godot-engineer 확인 사항).

| 컬럼 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `level` | int | 1~50, 연속 | ● | 레벨 |
| `exp_to_next` | int | >0, 레벨50은 0 또는 공란(최대레벨) | ● | 다음 레벨까지 필요 경험치 |
| `hp_bonus` | int | ≥0 | ● | 레벨업 자동 HP 상승분 |
| `stamina_bonus` | int | ≥0 | ○ | 레벨업 자동 스태미나 상승분 |
| `atk_bonus` | number | ≥0 | ● | 레벨업 자동 공격력 상승분 |

### 검증 규칙 (F8-4 명시 항목: "경험치 곡선 단조증가")
1. `level`은 1부터 50까지 빠짐없이 1씩 증가
2. `exp_to_next`는 **단조 비감소**(레벨이 오를수록 요구치가 줄어들지 않음), 레벨50 제외 항상 >0
3. 행 수 = 50

---

## 5. skills.json — 캐릭터별 스킬 트리

**용도**: F1-3.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `node_id` | string | 고유 | ● | 노드 식별자 |
| `character_id` | string | `characters.json` 참조 | ● | 소속 캐릭터 |
| `tree_id` | string | 캐릭터당 3종 중 하나 | ● | 계열(예: 핀=검술/수호/기사도) |
| `tier` | int | 1~6 | ● | 단계 |
| `node_index` | int | 1~2 | ● | 단계 내 노드 순번(단계당 2개, D-33) |
| `type` | string enum | `active`/`passive` | ● | 액티브는 슬롯 장착 대상 |
| `cost_sp` | int | ≥1 | ● | 습득 비용 |
| `prerequisite_tier` | int | =tier-1 (tier=1이면 없음) | ● | D-33: 이전 단계 1포인트 이상 투자 시 개방 |
| `effect` | object | 스킬별 상이 | ● | 배율/쿨타임/스태미나 소모 등 |
| `active_slot_eligible` | bool | type=active일 때만 true | ○ | 슬롯 1·2 장착 가능 여부 |

### 검증 규칙
- 캐릭터(4) × 계열(3) × 단계(6) × 노드(2) = **정확히 144개 노드**
- 각 (character_id, tree_id, tier) 조합에 정확히 2개 노드 존재 (D-33)
- `character_id`는 `characters.json`에 존재

---

## 6. elements.json — 속성 상성·상태이상 (신규 분리 제안)

**용도**: F2-4.
**소유**: game-designer.
**주의**: `combat.json`에도 `elements` 서브 객체가 이미 존재한다. 이 파일이 신설되면 `combat.json.elements`는 **중복이므로 제거**하고 이 파일을 단일 소스로 삼을 것을 권장(godot-engineer 확인 필요 — `combat-tuning-m1.md` §9 결정 요청과 별개로 여기서도 재확인).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `cycle` | array[string]×4 | 5원소 중 4개(성 제외) | ● | 순환 상성, `cycle[i]`가 `cycle[i+1]`에 강함 |
| `advantage_multiplier` | number | =1.5 | ● | 상성 적중 배율(D-08) |
| `holy_element` | string | `"holy"` | ● | 성속성 식별자 |
| `holy_bonus_vs_tags` | array[string] | `monsters.json.tags` 참조 | ● | 성속성 특효 대상 |
| `status_effects.burn.dps` | number | >0 | ● | 화상 초당 피해 |
| `status_effects.burn.duration_sec` | number | >0 | ● | 화상 지속시간 |
| `status_effects.burn.buildup_threshold` | number | >0 | ● | 화상 발동까지 필요한 누적치 |
| `status_effects.freeze.duration_sec` | number | >0 | ● | 빙결(행동불가) 지속시간 |
| `status_effects.freeze.buildup_threshold` | number | >0 | ● | 빙결 발동 누적치 |
| `status_effects.shock.stun_duration_sec` | number | >0 | ● | 감전(행동중단) 지속시간 |
| `status_effects.shock.buildup_threshold` | number | >0 | ● | 감전 발동 누적치 |
| `boss_resistance_multiplier` | number | 0~1 | ● | 보스 상태이상 누적 저항(GDD 4.2 "보스는 상태이상 저항치 보유") |

### 검증 규칙
- `cycle.size() == 4`, 중복 없음, "성" 미포함
- `holy_bonus_vs_tags`의 각 태그가 `monsters.json`에 최소 1회 이상 존재

---

## 7. items.json — 아이템 정의

**용도**: F3-1, F3-2.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `item_id` | string | 고유 | ● | 식별자 |
| `category` | string enum | `weapon`/`sub`/`head`/`armor`/`boots`/`ring`/`amulet`/`costume_hat`/`costume_outfit`/`costume_backpack`/`consumable`/`material` | ● | 슬롯 분류 (GDD 6.2: 8슬롯+치장3) |
| `grade` | string enum | `common`/`uncommon`/`rare`/`epic`/`legendary`/`relic` | ● | 6등급(GDD 6.1) |
| `affix_slot_count` | int | 등급별 고정값 | ● | common=0, uncommon=1, rare=2, epic=3, legendary=3(+고유스킬), relic=3(+세트) |
| `unique_skill_id` | string, optional | `skills.json` 참조 | ○ | 전설 등급만 |
| `set_id` | string, optional | | ○ | 유물 등급 세트 효과 |
| `str_requirement` | int | ≥0 | ○ | 무거운 무기 STR 요구치 |
| `sell_price` | int | ≥0 | ● | 상점 판매가(구매가의 25% 산정 기준, F8-3) |
| `stack_max` | int | ≥1 | ○ | 소모품/재료 최대 중첩 |

### 검증 규칙
- `affix_slot_count`가 등급별 규칙과 일치하는지 (common=0 / uncommon=1 / rare=2 / epic·legendary·relic=3)
- `unique_skill_id`가 있으면 `grade == legendary`
- `set_id`가 있으면 `grade == relic`

---

## 8. affixes.json — 랜덤 옵션 풀

**용도**: F3-1.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `affix_id` | string | 고유 | ● | 옵션 식별자 |
| `stat_type` | string enum | 20종(공격력%, 속성별 데미지×5, 크리확률, 이동속도, 골드획득량, 쿨감, 흡혈 등) | ● | GDD 6.3 |
| `value_min` / `value_max` | number | value_min ≤ value_max | ● | 롤 범위 |
| `applicable_categories` | array[string] | `items.json.category` 참조 | ● | 적용 가능 슬롯 |
| `weight` | number | >0 | ● | 풀 내 추첨 가중치 |

### 검증 규칙
- `stat_type` 종류 ≥ 20개 (GDD 6.3 "20종")
- `applicable_categories`의 각 값이 `items.json.category` enum에 존재

---

## 9. drop_tables.json — 드랍 테이블 (LUK 곱연산 반영)

**용도**: F3-1, F3-5.
**소유**: game-designer.
**규칙(GDD 12장 필수 반영)**: "LUK 스탯은 희귀 등급 가중치에 곱연산" — 아래 공식으로 표준화한다.

```
raw_weight[grade] = base_weight[grade] × luk_multiplier[grade]
luk_multiplier[grade] = 1.0                         (grade == common)
luk_multiplier[grade] = 1.0 + LUK × luk_coefficient[grade]   (grade != common)
final_probability[grade] = raw_weight[grade] / Σ raw_weight[all grades]
```

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `source_id` | string | `monsters.json`/`bosses.json`/맵 상자 id 참조 | ● | 드랍 소스 |
| `grade_base_weight.{common..relic}` | number | 합계 = 1.0 (LUK=0 기준) | ● | 등급별 기본 가중치 |
| `luk_coefficient.{uncommon..relic}` | number | >0, 등급 높을수록 큰 값 | ● | LUK 1당 가중치 증가율 |
| `entries[].item_id` | string | `items.json` 참조 | ● | 등급 확정 후 세부 아이템 추첨 |
| `entries[].weight` | number | >0 | ● | 동일 등급 내 아이템 가중치 |
| `entries[].qty_min` / `qty_max` | int | qty_min ≤ qty_max | ● | 수량 범위 |
| `guaranteed_first_clear` | array[item_id], optional | | ○ | 보스 첫 클리어 확정 보상(GDD 6.5) |

### 검증 규칙 (F8-4 명시 항목: "드랍 확률 합계")
1. `Σ grade_base_weight == 1.0` (LUK=0 기준 원본 테이블에서 검증. 런타임 `final_probability`는 정규화로 항상 1이 되므로 별도 검증 불필요)
2. `entries[].item_id`는 `items.json`에 존재
3. `luk_coefficient`는 `common`에 대해서는 정의하지 않음(등급 상승 없음)

---

## 10. enhance.json — 강화/재련/분해

**용도**: F3-3.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `enhance_levels[+1..+10].success_rate` | number | 0~1 | ● | +1~+6=1.0, +7~+10=[0.70,0.55,0.40,0.25] (D-14) |
| `enhance_levels[].cost_gold` | int | ≥0 | ● | 강화 비용 |
| `enhance_levels[].cost_stone_qty` | int | ≥0 | ● | 강화석 필요 개수 |
| `enhance_levels[].stat_multiplier` | number | >1.0, 단조증가 | ● | 단계별 스탯 배율 |
| `refine.max_attempts` | int | =3 | ● | 재련 횟수 상한(D-13) |
| `refine.cost_by_grade_and_attempt` | table | grade × attempt → gold | ● | 재련 비용 증가표 |
| `disassemble.yield_by_grade.{grade}.stone_qty` | int | ≥0 | ● | 분해 산출 강화석 |
| `disassemble.yield_by_grade.{grade}.material_qty` | int | ≥0 | ● | 분해 산출 재료 |

### 검증 규칙
- `enhance_levels["+7"].success_rate == 0.70`, `+8 == 0.55`, `+9 == 0.40`, `+10 == 0.25` (D-14, 하드 고정값 — "밸런싱 단계 조정 전제"이므로 이 문서 갱신 없이 임의 변경 금지)
- `+1~+6`은 모두 `success_rate == 1.0`
- `refine.max_attempts == 3` (D-13)
- 등급이 높을수록 `disassemble.yield_by_grade`가 단조증가

---

## 11. farming_sources.json — 파밍 소스 리스폰·보상

**용도**: F3-5, F6-3.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `source_id` | string | 고유 | ● | 소스 식별자 |
| `type` | string enum | `field`/`elite`/`mini_dungeon`/`region_dungeon`/`world_boss`/`gathering`/`treasure_map` | ● | GDD 6.5 7종 |
| `respawn_seconds` | int | ≥0, **실제 플레이 시간 기준**(D-15) | ● | field/gathering=0(상시), elite=1800, mini_dungeon=86400, world_boss=259200, region_dungeon=0(재입장 자유) |
| `first_clear_reward_table_id` | string | `drop_tables.json` 참조 | ○ | 첫 클리어 전용(D-15: "첫 클리어와 반복 파밍은 별도 테이블") |
| `repeat_reward_table_id` | string | `drop_tables.json` 참조 | ● | 반복 파밍 |

### 검증 규칙
- `respawn_seconds`가 타입별 GDD 6.5 기준과 일치
- `*_reward_table_id`가 `drop_tables.json.source_id`에 존재

---

## 12. monsters.json — 일반/정예 몬스터

**용도**: F6-1, F6-3.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `monster_id` | string | 고유 | ● | 식별자 |
| `region_id` | string | 지역 id | ● | 소속 지역 |
| `tier` | string enum | `normal`/`elite` | ● | 보스는 `bosses.json`에서 별도 관리 |
| `hp` | number | >0 | ● | 체력 (`combat-tuning-m1.md` §8 예시: 슬라임18/뿔토끼27/버섯돌이45) |
| `atk` | number | >0 | ● | 공격력 |
| `move_speed_px` | number | ≥0 | ● | 이동속도(px/s, 16px 프로토타입 기준) |
| `telegraph_sec` | number | **≥0.5** | ● | 공격 예고시간 (GDD 4.2 최소값 강제) |
| `attack_pattern_id` | string | 패턴 테이블 참조 | ● | 행동 패턴 |
| `drop_table_id` | string | `drop_tables.json` 참조 | ● | 처치 드랍 |
| `element` | string, optional | 5속성 중 하나 | ○ | 속성 부여 몬스터만 |
| `tags` | array[string] | 예: `["demon"]` | ○ | `elements.json.holy_bonus_vs_tags` 참조 대상 |
| `codex_entry_id` | string | 도감 참조 | ● | GDD 8.1 "처치 시 도감 등록" |

### 검증 규칙 (F8-4 명시 항목: "참조 ID 존재")
1. `telegraph_sec ≥ 0.5` 위반 시 빌드 에러 (GDD 4.2 강제 규칙)
2. `drop_table_id`가 `drop_tables.json`에 존재
3. `tags`에 사용된 각 값이 `elements.json.holy_bonus_vs_tags`와 일관(신규 태그 추가 시 두 파일 동시 갱신)

---

## 13. bosses.json — 지역 보스·최종 보스 (3페이즈)

**용도**: F6-2.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `boss_id` | string | 고유 | ● | 식별자 |
| `region_id` | string | | ● | 소속 지역 |
| `phase_thresholds` | array[number]×4 | `[1.0, 0.66, 0.33, 0.0]` 고정 | ● | GDD 8.2 페이즈 경계 |
| `phase_patterns` | array[string]×3 | 패턴 id | ● | P1 학습/P2 강화/P3 발악 |
| `status_resistance.{fire,water,thunder,wind,holy}` | number | 0~1 | ● | GDD 4.2 "보스는 상태이상 저항치 보유" |
| `first_clear_reward` | object | `{type: "legendary_item"|"relic_fragment", ref_id}` | ● | GDD 8.2 확정 보상 |
| `checkpoint_shrine_required` | bool | =true 고정 | ● | D-27 |

### 검증 규칙
- `phase_thresholds == [1.0, 0.66, 0.33, 0.0]` (정확히 3페이즈 경계)
- `phase_patterns.size() == 3`

---

## 14. quests/daily_pool.json — 일일 의뢰 풀

**용도**: F5-2.
**소유**: 콘텐츠·월드(보상 밸런스는 game-designer와 economy.json 교차 검증).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `quest_id` | string | 고유 | ● | 식별자 |
| `type` | string enum | `hunt`/`deliver` | ● | GDD 7.5 |
| `target_id` | string | 몬스터/아이템 id | ● | 대상 |
| `target_qty` | int | >0 | ● | 목표 수량 |
| `level_bracket.{min,max}` | int | 1~50 | ● | 추첨 풀 레벨 구간 |
| `reward_gold` | int | ≥0 | ● | `economy.json` 레벨 구간별 기대치 참조해 산정 |
| `reward_items` | array[{item_id, qty}] | | ○ | |
| `weekly_bonus_eligible` | bool | | ● | 주간 7회 누적 보너스 대상 여부 |

### 검증 규칙
- `reward_gold`가 `economy.json.level_brackets`의 해당 구간 기대 소비량 대비 과대/과소하지 않은지(±20% 권장 — 상세 규칙은 economy.json 소유자와 협의)

---

## 15. npcs.json — NPC 호감도

**용도**: F5-3.
**소유**: 콘텐츠·월드.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `npc_id` | string | 고유 | ● | |
| `region_id` | string | | ● | 지역당 3~4명(GDD 7.4) |
| `preferred_item_ids` / `disliked_item_ids` | array[item_id] | `items.json` 참조 | ○ | |
| `affinity_thresholds` | array[int]×3 | 단조증가 | ● | D-22 3단계(지인/친구/단짝) |
| `tier_rewards[].discount_pct` | number | 0~1 | ○ | 상점 할인(economy.json 판매가 규칙과 연동) |
| `tier_rewards[].costume_id` | string, optional | `items.json` 참조(치장) | ○ | |

### 검증 규칙
- `affinity_thresholds.size() == 3` (D-22)

---

## 16. recipes.json — 요리 레시피

**용도**: F1-4.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `recipe_id` | string | 고유 | ● | |
| `result_item_id` | string | `items.json` 참조, category=consumable | ● | |
| `ingredients` | array[{item_id, qty}] | | ● | |
| `buff.effect_category` | string | 중첩 규칙 판정용(D-04: 동일 카테고리는 대체) | ● | 예: `atk_pct`, `move_speed` |
| `buff.value` | number | | ● | |
| `buff.duration_sec` | number | >0 | ● | 예: 매콤 버섯구이 600초 |

### 검증 규칙
- 동시에 2개까지만 적용(D-04)은 런타임 로직 규칙이나, `effect_category` 필드가 없으면 검증 불가 — 필수 처리

---

## 17. codex_bonus.json — 도감 보너스

**용도**: F1-4.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `category` | string enum | `monster`/`item`/`food`/`fishing` | ● | |
| `thresholds` | array[int]×4 | `[25,50,75,100]` 고정 | ● | D-35 |
| `bonus_stat_by_threshold` | array[object]×4 | | ● | 임계치별 영구 보너스 |

### 검증 규칙
- `thresholds == [25,50,75,100]` (D-35)

---

## 18. economy.json — 골드 경제

**용도**: F8-3.
**소유**: game-designer.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `level_brackets` | array[int] | `[10,20,30,40,50]` | ● | F8-3 |
| `expected_gold_held[bracket]` | int | 단조증가 | ● | 구간별 기대 보유 골드 |
| `shop_sell_ratio` | number | =0.25 고정 | ● | "판매가=구매가의 25%" |
| `death_penalty.pct` | number | =0.05 | ● | D-25 |
| `death_penalty.cap_formula` | string | `"level * 50"` | ● | D-25 |
| `reset_cost_formula` | string | `"level * 100"` | ● | D-03 스킬/스탯 리셋 |
| `inn_stay_cost` | int/formula | | ● | D-29 숙박 유료 |
| `salon_cost` | int/formula | | ● | D-01 미용실 |

### 검증 규칙
- `shop_sell_ratio == 0.25`
- `death_penalty.pct == 0.05`, `cap_formula`가 D-25와 일치

---

## 19. weather.json — 날씨

**용도**: F4-3.
**소유**: 콘텐츠·월드.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `region_id` | string | | ● | |
| `weather_types[].type` | string enum | `clear`/`rain`/`snow`/`sandstorm` | ● | |
| `weather_types[].probability` | number | 0~1, **지역별 합계=1** | ● | |
| `weather_types[].spawn_table_override` | string, optional | `spawns.json` 참조 | ○ | |

### 검증 규칙
- 지역별 `Σ probability == 1.0`

---

## 20. region_hazards.json — 지역 기믹

**용도**: F4-4.
**소유**: 콘텐츠·월드(수치는 game-designer 협의 — 사망 가능 규칙 D-18 반영).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `region_id` | string | | ● | |
| `hazard_type` | string enum | `cold`/`fog`/`heat_sandstorm`/`lava` | ● | |
| `gauge_max` | number | >0 | ● | |
| `gauge_fill_rate` | number | >0, unit/sec | ● | |
| `damage_per_tick` | number | >0 | ● | D-18: 기믹으로도 사망 가능해야 하므로 0 불가 |
| `mitigation_item_id` | string | `items.json` 참조 | ● | 방한복/랜턴/내화장비 |
| `recovery_zone_type` | string, optional | `campfire`/`hotspring` | ○ | |

### 검증 규칙
- `damage_per_tick > 0` (D-18 위반 방지 — 0이면 "사망 가능" 원칙이 깨짐)
- `mitigation_item_id`가 `items.json`에 존재

---

## 21. mount.json — 탈것

**용도**: F4-5.
**소유**: game-designer(수치)/콘텐츠(퀘스트 연동).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `speed_bonus_pct` | number | =60 고정 | ● | GDD 7.3 "+60%" |
| `unlock_quest_id` | string | `quests/` 참조 | ● | |
| `dismount_on_hit` | bool | =true | ● | |
| `disabled_zones` | array[string] | `indoor`/`dungeon`/`lava`/`water` | ● | |

### 검증 규칙
- `speed_bonus_pct == 60`

---

## 22. spawns.json (또는 `spawns/` 청크별 메타) — 스폰 테이블

**용도**: F4-1, F4-3.
**소유**: 콘텐츠·월드.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `chunk_id` | string | 고유(64×64 타일 청크, GDD 12) | ● | |
| `region_id` | string | | ● | |
| `spawn_list_day[].monster_id` | string | `monsters.json` 참조 | ● | |
| `spawn_list_day[].weight` | number | >0 | ● | |
| `spawn_list_night[]` | 위와 동일 구조 | | ○ | 밤 전용 몬스터(F4-3) |
| `max_concurrent` | int | >0 | ● | 청크당 동시 존재 상한 |
| `gathering_nodes[].item_id` | string | `items.json` 참조 | ○ | 채집물 |

### 검증 규칙
- `monster_id`가 `monsters.json`에 존재
- `chunk_id` 청크 좌표계와 `game/maps/` 청크 파일 명명 규칙 일치(godot-engineer 확인)

---

## 23. 범위 밖(다른 기능의 데이터, 참고용 목록만)

이 문서가 다루는 20종 표 외에도 BRD가 언급하는 아래 파일들은 각자의 기능 문서가 소유하며, 이 문서는 존재만 표기하고 스키마는 상세화하지 않는다(필요 시 별도 스펙 문서로 분리):

| 파일 | 소유 기능 | 비고 |
|---|---|---|
| `blueprints.json` | F3-4 대장간 제작 | 도면(소모되지 않음), 재료 목록 |
| `settings.json` | F8-1/F7 접근성 | 흔들림 강도, 색약 모드, 폰트 크기, 데미지 숫자 토글 |
| `dialogue/ko.json`, `dialogue/en.json` | F5-4 대화 | key 기반 로컬라이징 |
| `quests/` (메인 스토리, `daily_pool.json` 제외) | F5-1 | 3막 진행 플래그, 성물 파편 등 |

---

## 24. 결정 요청 목록 (ID는 메인 세션 부여)

| 항목 | 내용 | 관련 절 |
|---|---|---|
| 결정 요청 9 | `combat.json.elements`(기존)와 신설 `elements.json`(§6) 중복 — `elements.json` 신설 승인 및 `combat.json.elements` 제거 시점(godot-engineer 작업) 결정 필요 | §6 |
| 결정 요청 10 | 표 §14~§22(퀘스트/NPC/날씨/기믹/탈것/스폰)의 소유를 "콘텐츠·월드" 담당으로 잠정 표기함 — 실제 담당 에이전트/역할을 메인 세션이 배정해야 함(현재 조직에 해당 역할이 없다면 game-designer가 임시로 겸임할지 결정 필요) | §14, §15, §19, §20, §22 |
| 결정 요청 11 | `luk.drop_weight_formula`(stats.json)와 `drop_tables.json`의 LUK 곱연산 공식이 이중 정의되지 않도록 단일 소스를 어느 파일로 할지 결정(§3, §9) | §3, §9 |
