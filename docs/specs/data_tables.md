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
**밸런스 근거**: `docs/specs/items-and-drops-m2.md` §1~2 (M2 실장, 58개: 장비42+소모품4+재료9+백팩3 — D-80으로 재료에 `goblin_ear` 추가).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `item_id` | string | 고유(= JSON 키와 동일) | ● | 식별자 |
| `category` | string enum | `weapon`/`sub`/`head`/`armor`/`boots`/`ring`/`amulet`/`costume_hat`/`costume_outfit`/`costume_backpack`/`consumable`/`material` | ● | 슬롯 분류 (GDD 6.2: 8슬롯+치장3) |
| `grade` | string enum | `common`/`uncommon`/`rare`/`epic`/`legendary`/`relic` | ● | 6등급(GDD 6.1). M2는 common~rare만 실존 |
| `name_key` / `desc_key` | string | `item_<id>_name` / `item_<id>_desc` | ● | 로컬라이징 key (플레이버 텍스트는 텍스트 하드코딩 금지) |
| `affix_slot_count` | int | 등급별 고정값 | ● (장비 7종만) | common=0, uncommon=1, rare=2, epic=3, legendary=3(+고유스킬), relic=3(+세트). 소모품/재료/치장엔 없음 |
| `level_min` | int | 1~15(M2 범위) | ● (장비만, **신규**) | 착용 최소 레벨. `items-and-drops-m2.md` §2 레벨 스케일 공식의 입력값 |
| `base_stats` | object | 카테고리별 하위 키 상이(아래) | ● (장비만, **신규**) | weapon={atk_min,atk_max} / sub·head·armor·boots={defense_min,defense_max} / ring={ (str｜dex｜int｜vit): int } / amulet={elemental_damage_pct: number} |
| `element` | string｜null | 5속성(`elements.json.cycle`+holy) 중 하나 또는 null | ○ (amulet 전용, **신규**) | GDD 6.2 "부적(속성 결정)" — 장착한 부적이 캐릭터의 속성을 정한다 |
| `unique_skill_id` | string｜null | `skills.json` 참조 | ○ | 전설 등급만. M2엔 legendary 아이템이 없어 항상 null |
| `set_id` | string｜null | | ○ | 유물 등급 세트 효과. M2엔 relic 아이템이 없어 항상 null |
| `str_requirement` | int | ≥0 | ○ | 무거운 무기 STR 요구치(M2는 rare 무기 2종만) |
| `sell_price` | int | ≥0 | ● | 상점 판매가(구매가의 25%, F8-3) — 구매가 = `sell_price / economy.json.shop_sell_ratio`(=×4, economy.json 미생성 시엔 0.25 하드값 사용) |
| `stack_max` | int | ≥1 | ○ (consumable/material만) | 최대 중첩 |
| `inventory_slot_bonus` | int | >0 | ● (costume_backpack 전용, **신규**) | D-11. 기본 40칸에 가산되는 인벤토리 칸 수(최대 80칸 = 40+backpack_large의 40) |
| `effect_type` | string enum | `heal_hp`/`heal_stamina`/`buff_atk_pct`/`buff_max_hp_flat`/... | ● (consumable 전용, **신규**) | 소모 효과 종류. 즉발 회복은 `duration_sec=0` |
| `effect_value` | number | | ● (consumable 전용, **신규**) | 효과 크기(회복량 또는 %) |
| `duration_sec` | number | ≥0 | ● (consumable 전용, **신규**) | 버프 지속시간, 즉발 효과는 0. GDD 5.3 "서로 다른 효과 2개까지 동시 적용" 규칙은 버프 시스템(코드) 소관 |

### 검증 규칙
- `affix_slot_count`가 등급별 규칙과 일치하는지 (common=0 / uncommon=1 / rare=2 / epic·legendary·relic=3)
- `unique_skill_id`가 있으면 `grade == legendary`
- `set_id`가 있으면 `grade == relic`
- `base_stats`의 `*_min` ≤ `*_max`
- 같은 (category, grade) 안에서 `level_min`이 레벨 티어마다 달라야 함(중복 레벨 금지는 아니지만 `items-and-drops-m2.md` §2 설계 원칙상 티어별로 다른 값을 쓴다)

---

## 8. affixes.json — 랜덤 옵션 풀

**용도**: F3-1.
**소유**: game-designer.
**밸런스 근거**: `docs/specs/items-and-drops-m2.md` §3. 실제 20종: `atk_pct`·`crit_chance`·`crit_damage_pct`·
`move_speed_pct`·`gold_find_pct`·`cooldown_reduction_pct`·`life_steal_pct`·
`elemental_dmg_{fire,wind,thunder,water,holy}_pct`(5종)·`max_hp_flat`·`max_stamina_flat`·
`stamina_cost_reduction_pct`·`defense_flat`·`item_find_pct`·`exp_gain_pct`·`attack_speed_pct`·`damage_reduction_pct`.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `affix_id` | string | 고유(= JSON 키와 동일) | ● | 옵션 식별자 |
| `stat_type` | string enum | 20종(위 목록) | ● | GDD 6.3. **등급 무관 단일 stat_type** — 등급은 옵션 "개수"만 늘리고 값 범위엔 영향 없음(F3-1) |
| `value_min` / `value_max` | number | value_min ≤ value_max, pct 계열은 비율(0.05=5%) | ● | 롤 범위(등급 무관 단일 범위) |
| `applicable_categories` | array[string] | `items.json.category` 중 장비 7종(weapon/sub/head/armor/boots/ring/amulet)만 | ● | 적용 가능 슬롯 — 소모품/재료/치장엔 옵션이 붙지 않음 |
| `weight` | number | >0 | ● | 풀 내 추첨 가중치(합계 제약 없음) |

### 검증 규칙
- `stat_type` 종류 ≥ 20개 (GDD 6.3 "20종")
- `value_min ≤ value_max`, `weight > 0`
- `applicable_categories`의 각 값이 `items.json.category` enum에 존재

---

## 9. drop_tables.json — 드랍 테이블 (LUK 곱연산 반영)

**용도**: F3-1, F3-5.
**소유**: game-designer.
**밸런스 근거**: `docs/specs/items-and-drops-m2.md` §4~5. M2 실제 소스 7개: `slime_common`/`horn_rabbit_common`/
`mushroom_common`/`goblin_scout_common`(필드 일반 4종, `monsters.json.drop_table_id`가 그대로 가리킴 — D-67 활성화,
`goblin_scout_common`은 D-80 신설) + `elite_goblin_captain`/`elite_bunchi_spawn`(정예 2종, `docs/levels/hartland.md`
⑤, 몬스터 본체는 `monsters.json`에 실존 — D-75) + `field_treasure_chest`(미니던전 보물상자, 지역 무관 범용).
**규칙(GDD 12장 필수 반영)**: "LUK 스탯은 희귀 등급 가중치에 곱연산" — 최상단 `_luck_formula` 필드(D-52 단일 소스)로
표준화한다. **`luk_coefficient`는 `_luck_formula` 안에만 존재하는 전역 값**이며 소스별 `grade_base_weight`와는 별도
키다(과거 버전의 표는 이 둘을 소스별로 함께 나열해 오해를 유발했음 — 이번 갱신으로 분리 명시).

```
raw_weight[grade] = grade_base_weight[grade] × luk_multiplier[grade]
luk_multiplier[grade] = 1.0                         (grade == common)
luk_multiplier[grade] = 1.0 + LUK × luk_coefficient[grade]   (grade != common)
final_probability[grade] = raw_weight[grade] / Σ raw_weight[all grades]
```

### `_luck_formula` (최상단, 소스 아님)

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `_luck_formula.formula` | string | 위 공식 문자열 | ● | 사람이 읽는 문서화용(코드가 파싱하지 않음, 실제 계산은 로더 구현) |
| `_luck_formula.luk_coefficient.{uncommon..relic}` | number | >0, 등급 높을수록 큰 값(단조증가) | ● | LUK 1당 가중치 증가율. **전 소스 공통 단일 값**(D-52) |

### 소스별 엔트리 (`slime_common` 등, 위 6개 키)

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `source_id` | string | `monsters.json`/`bosses.json`/맵 상자 id 참조(= JSON 키와 동일) | ● | 드랍 소스 |
| `grade_base_weight.{common..relic}` | number | 6개 키 모두 존재, 합계 = 1.0 (LUK=0 기준) | ● | 등급별 기본 가중치. 아직 없는 등급(M2의 epic 이상)은 값 0으로 명시 — 키 자체를 생략하지 않는다 |
| `gold_drop.min` / `gold_drop.max` | int | min ≤ max, ≥0 | ● (**신규**, §7 미정의였던 필드) | 처치 1회당 골드 지급 범위(균등분포 가정) |
| `entries[].item_id` | string | `items.json` 참조 | ● | 등급 확정 후, 같은 등급 아이템들 중에서 세부 추첨 |
| `entries[].weight` | number | >0 | ● | 동일 등급 내 아이템 가중치 |
| `entries[].qty_min` / `qty_max` | int | qty_min ≤ qty_max | ● | 수량 범위 |
| `guaranteed_first_clear` | array[item_id], optional | | ○ | 보스 첫 클리어 확정 보상(GDD 6.5). M2 6개 소스엔 미사용(보스가 아님) |

### 검증 규칙 (F8-4 명시 항목: "드랍 확률 합계")
1. `Σ grade_base_weight == 1.0` (LUK=0 기준 원본 테이블에서 검증. 런타임 `final_probability`는 정규화로 항상 1이 되므로 별도 검증 불필요)
2. `entries[].item_id`는 `items.json`에 존재
3. `_luck_formula.luk_coefficient`는 `common`에 대해서는 정의하지 않음(등급 상승 없음), uncommon→relic 순으로 단조증가
4. **`grade_base_weight[g] > 0`인데 `entries`에 해당 등급 아이템이 하나도 없으면 오류** — 드랍 시 빈 풀이 되는 실전
   버그를 잡기 위해 M2에서 신설한 규칙(`items-and-drops-m2.md` §5-1, `tools/qa/validate_tables.py` 구현)
5. `monsters.json.drop_table_id`(null이 아닌 값)는 이 파일의 키로 존재해야 함(D-67, `_validate_monsters`에 아직
   미구현 — §12 "엔지니어 요청" 참고)

---

## 10. enhance.json — 강화/재련/분해

**용도**: F3-3.
**소유**: game-designer.
**밸런스 근거**: `docs/specs/items-and-drops-m2.md` §6~8 (+0~+10 기대 비용 ≈3,713골드/74강화석 계산 포함).

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `enhance_levels["+1".."+10"].success_rate` | number | 0~1 | ● | +1~+6=1.0, +7~+10=[0.70,0.55,0.40,0.25] (D-14). 키는 문자열 `"+1"`~`"+10"` |
| `enhance_levels[].cost_gold` | int | ≥0 | ● | 강화 비용(성공/실패 무관 매 시행 소모) |
| `enhance_levels[].cost_stone_qty` | int | ≥0 | ● | 강화석 필요 개수(매 시행 소모, D-32 "실패 시 강화석만 소실") |
| `enhance_levels[].stat_multiplier` | number | >1.0, 단조증가 | ● | 단계별 스탯 배율. M2 공식: `1 + 0.08×N` |
| `refine.max_attempts` | int | =3 | ● | 재련 횟수 상한(D-13), 장비 인스턴스당 카운터(정의 테이블이 아니라 세이브 상태로 관리 — 엔지니어 요청) |
| `refine.cost_material_id` | string | `items.json` 참조 | ● (**신규**) | 재련 소모 재료 id. M2 값: `"enhance_stone"`(강화석 재사용) |
| `refine.cost_by_grade_and_attempt.{grade}.attempt_{1,2,3}.cost_gold` | int | ≥0, attempt 순으로 단조증가 | ● | 재련 비용(골드). `grade`는 `uncommon`~`relic`만(common은 옵션 슬롯이 없어 대상 아님) |
| `refine.cost_by_grade_and_attempt.{grade}.attempt_{1,2,3}.cost_material_qty` | int | ≥0 (**신규**) | ● | 재련 비용(재료 개수) |
| `disassemble.yield_by_grade.{grade}.stone_qty` | int | ≥0 | ● | 분해 산출 강화석(`enhance_stone`) |
| `disassemble.yield_by_grade.{grade}.material_qty` | int | ≥0 | ● | 분해 산출 범용 재료(`salvage_scrap`) — 몬스터 전용 재료(iron_ore 등)는 분해로 나오지 않음 |

### 검증 규칙
- `enhance_levels["+7"].success_rate == 0.70`, `+8 == 0.55`, `+9 == 0.40`, `+10 == 0.25` (D-14, 하드 고정값 — "밸런싱 단계 조정 전제"이므로 이 문서 갱신 없이 임의 변경 금지)
- `+1~+6`은 모두 `success_rate == 1.0`
- `enhance_levels[].stat_multiplier`가 `+1`→`+10` 순으로 단조증가
- `refine.max_attempts == 3` (D-13)
- `refine.cost_by_grade_and_attempt`에 `common` 키가 없어야 함(옵션 슬롯 0인 등급은 재련 대상이 아님)
- 등급이 높을수록 `disassemble.yield_by_grade.{grade}.stone_qty`/`material_qty` 각각 단조증가

---

## 11. farming_sources.json — 파밍 소스 리스폰·보상

**용도**: F3-5, F6-3.
**소유**: game-designer.
**밸런스 근거**: `docs/specs/elite-and-farming-m2.md` §2 (실제 8행 — `field`/`gathering`/`treasure_map` 각 1 + `elite` 2
+ `mini_dungeon`/`region_dungeon`/`world_boss` 각 1. `type`은 GDD 6.5 7종 카테고리 그대로이나 `elite`는 개체별
리스폰 타이머가 독립적이라 `source_id`를 2개(`elite_goblin_captain`/`elite_bunchi_spawn`)로 분리했다).

> 갱신(§4 엔지니어 요청 반영): 이 절은 원래 단수 `first_clear_reward_table_id`/`repeat_reward_table_id`(string)로
> 정의돼 있었으나, 실제 `game/data/farming_sources.json`은 상위호환 확장 필드인 복수형 배열
> `first_clear_reward_table_ids`/`repeat_reward_table_ids`(array[string])를 쓴다 — 아래 표는 실제 키 기준으로 갱신했다.

| 키 | 타입 | 범위/단위 | 필수 | 설명 |
|---|---|---|---|---|
| `source_id` | string | 고유(= JSON 키와 동일) | ● | 소스 식별자 |
| `type` | string enum | `field`/`elite`/`mini_dungeon`/`region_dungeon`/`world_boss`/`gathering`/`treasure_map` | ● | GDD 6.5 7종 |
| `region_id` | string | `monsters.json.region_id`와 동일 계열 | ● | 소속 지역 |
| `respawn_seconds` | int | ≥0, **실제 플레이 시간 기준**(D-15) | ● | field/gathering/treasure_map/region_dungeon=0, elite=1800, mini_dungeon=86400, world_boss=259200 |
| `respawn_trigger` | string enum | `always`/`on_kill`/`on_completion`/`on_map_use` | ● (**신규**) | 리스폰 카운트다운을 시작시키는 이벤트 — `respawn_seconds=0`(상시)인 소스는 대개 `always`, `treasure_map`은 쿨다운이 아니라 "지도 보유 시 언제든" 의미로 `on_map_use` |
| `first_clear_reward_table_ids` | array[string] | `drop_tables.json.source_id` 참조 | ● (**신규**, 배열 — 비어도 됨) | 첫 클리어 전용(D-15: "첫 클리어와 반복 파밍은 별도 테이블"). M2는 `mini_dungeon_echo_cave`만 값 있음, 나머지는 빈 배열 |
| `repeat_reward_table_ids` | array[string] | `drop_tables.json.source_id` 참조 | ● (**신규**, 배열 — 비어도 됨) | 반복 파밍. `type=field`는 지역 내 필드 몬스터 전원의 드랍 테이블을 한 배열에 묶는다(예: `field_hartland`=4종) |
| `first_clear_bonus_item_id` | string, optional | `items.json` 참조 | ○ (**신규**, `mini_dungeon`류만) | 확률 드랍이 아닌 고정 지급 첫 클리어 보너스(GDD 5.3) |
| `show_respawn_icon_on_map` | bool | | ● (**신규**) | 월드맵에 리스폰 상태 아이콘 표시 여부 — `type`이 `elite`/`world_boss`일 때만 `true` |
| `location` | object, optional | `{chunk_id, pos_global_tile:[x,y], landmark}` 또는 `{quest_id, landmark}` 또는 `{landmark}`만 | ○ (**신규**) | 고정 스폰 좌표가 있는 소스(정예/월드보스)는 `chunk_id`+`pos_global_tile`, 퀘스트 연동 소스는 `quest_id`, 나머지는 `landmark` 서술만 |

### 검증 규칙
1. `respawn_seconds`가 타입별 GDD 6.5 기준과 일치(`tools/qa/validate_tables.py`의 `FARMING_TYPE_RESPAWN_SECONDS` 참고)
2. `first_clear_reward_table_ids`/`repeat_reward_table_ids`의 각 원소가 `drop_tables.json.source_id`에 존재
3. `type == "elite"`이면 `repeat_reward_table_ids[0]`을 `drop_table_id`로 갖는 `tier == "elite"` `monsters.json` 엔트리가 최소 1개 존재해야 함(D-67/D-75 교차 참조)
4. `show_respawn_icon_on_map == (type in {"elite", "world_boss"})` (그 외 타입은 항상 `false`)

---

## 12. monsters.json — 일반/정예 몬스터

**용도**: F6-1, F6-3.
**소유**: game-designer.
**밸런스 근거**: `combat-tuning-m1.md` §8(hp/atk/속도/예고), `combat-tuning-m1-addendum.md` §4(AI 공통 필드 승격, D-53 예정)·§6(`drop_table_id` null 허용 규칙, D-58 예정), `elite-and-farming-m2.md` §1-0~1-4(정예 배율 규칙·`goblin_scout`/정예 2종 신규 필드, D-75 예정).

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
| `drop_table_id` | string \| null | `drop_tables.json` 참조, **`null` 허용**(§ 검증 규칙 2 참고) | ● | 처치 드랍. `null` = "드랍 없음"으로 확정되었거나 `drop_tables.json` 부재 시기의 자리표시자 |
| `element` | string, optional | 5속성 중 하나 | ○ | 속성 부여 몬스터만 |
| `tags` | array[string] | 예: `["demon"]` | ○ | `elements.json.holy_bonus_vs_tags` 참조 대상 |
| `codex_entry_id` | string | 도감 참조 | ● | GDD 8.1 "처치 시 도감 등록" |
| `aggro_range_px` | number | >0, `melee_range_px`보다 커야 함 | ● (M1-1부터 정식 필드, `combat-tuning-m1-addendum.md` §4) | 인지(추적 시작) 반경. F6-1 "인지 범위 진입 시 추적" |
| `melee_range_px` | number | >0 | ● | 근접/접촉 판정 발동 거리(장판형 몬스터는 "장판 트리거 거리"로 해석) |
| `attack_recovery_sec` | number | >0 | ● | 공격 후 재사용 대기(후딜). 플레이어 반격 타이밍의 근거 |
| `patrol_radius_px` | number | ≥0 | ● | 비추적 상태 순찰 반경. 0 = 고정형(순찰 없음) |
| `leash_range_px` | number | >0, `aggro_range_px`보다 커야 함 | ● | 추적 포기 후 원위치 복귀를 시작하는 거리(F6-1 "일정 거리 이탈 시 복귀") |
| `dash_speed_px` | number | >0 | ○ (돌진형 종만, 예: 뿔토끼) | 돌진 중 이동속도 |
| `dash_duration_sec` | number | >0 | ○ (돌진형 종만) | 돌진 지속시간 |
| `atk_tick_per_sec` | number | >0 | ○ (장판형 종만, 예: 버섯돌이) | 장판 내부 지속 피해(초당) |
| `aoe_radius_px` | number | >0, `melee_range_px` 이상 | ○ (장판형 종만) | 실제 전개된 장판 반경. `melee_range_px`(트리거 거리)와 별개 값 — 장판은 트리거 지점보다 넓게 퍼진다 |
| `whistle_cooldown_sec` / `whistle_cast_sec` / `whistle_range_px` | number | 각 >0 | ○ (**신규**, 원거리 경보형 종만 — `goblin_scout`/`elite_goblin_captain`) | 증원 호출 쿨다운·시전시간·유효 반경(`elite-and-farming-m2.md` §1-1-1) |
| `whistle_summon_pool` | array[monster_id] | `monsters.json` 참조 | ○ (위와 동일 종만, **신규**) | 호출 가능 대상 풀 |
| `whistle_summon_count` | int | >0 | ○ (위와 동일 종만, **신규**) | 1회 호출당 소환 마리 수 |
| `wave_trigger_hp_pct` / `wave_cast_sec` / `wave_summon_count` | number | 0~1 / >0 / >0 | ○ (**신규**, 정예 강화 패턴 보유 종만 — 예: `elite_goblin_captain`) | HP 비율 임계값 도달 시 1회 발동하는 웨이브 소환(시전시간·마리 수) |
| `wave_summon_pool` | array[monster_id] | `monsters.json` 참조 | ○ (위와 동일 종만, **신규**) | 웨이브 소환 대상 풀 |
| `wave_once_per_life` | bool | | ○ (위와 동일 종만, **신규**) | 생애주기당 1회만 발동(재발동 없음) |
| `on_death_split_monster_id` | string | `monsters.json` 참조 | ○ (**신규**, 분열형 종만 — 예: `elite_bunchi_spawn`) | 처치 시 분열 스폰될 몬스터(재귀 방지: 스폰된 개체는 일반 데이터 그대로 사용) |
| `on_death_split_count` / `on_death_split_spawn_radius_px` | int / number | >0 | ○ (위와 동일 종만, **신규**) | 분열 마리 수·스폰 반경 |
| `elite_base_monster_id` | string | `monsters.json` 참조(`tier=normal` 엔트리) | ○ (**신규**, `tier=elite`만, 참고용) | 이 정예의 배율 계산 베이스가 된 일반 몬스터(`elite-and-farming-m2.md` §1-0 배율 규칙의 입력). 스키마 확정 전 참고 필드 |

### 검증 규칙 (F8-4 명시 항목: "참조 ID 존재")
1. `telegraph_sec ≥ 0.5` 위반 시 빌드 에러 (GDD 4.2 강제 규칙)
2. `drop_table_id` 참조 무결성: **M2 F3-1(`game/data/drop_tables.json` 생성)로 이 규칙이 활성화됐다(D-67).** `drop_table_id == null`은 "확정된 드랍 없음"으로 유효, `null`이 아니면 반드시 `drop_tables.json`에 실제로 존재해야 한다(위반 시 빌드 에러). `monsters.json`의 `"slime_common"`/`"horn_rabbit_common"`/`"mushroom_common"`/`"goblin_scout_common"`(D-80)/`"elite_goblin_captain"`/`"elite_bunchi_spawn"`은 모두 `drop_tables.json`의 실존 키를 가리키는 정식 참조다. **코드 구현(`Data._validate()`에 이 교차 검증 추가)은 아직 안 됐다** — `tools/qa/validate_tables.py`가 오프라인으로 이를 검증하며, `data.gd` 반영은 godot-engineer 몫(`docs/specs/items-and-drops-m2.md` §10 엔지니어 요청 5).
3. `tags`에 사용된 각 값이 `elements.json.holy_bonus_vs_tags`와 일관(신규 태그 추가 시 두 파일 동시 갱신)
4. `leash_range_px > aggro_range_px > melee_range_px` (AI 상태 전이가 논리적으로 겹치지 않도록 강제)
5. `aoe_radius_px`가 존재하면 `aoe_radius_px ≥ melee_range_px`
6. 방어력 필드는 아직 없음 — M1은 단순 모델(`combat-tuning-m1.md` §0), 도입 시점은 D-49(M2) 유지
7. `whistle_summon_pool`/`wave_summon_pool`/`on_death_split_monster_id`/`elite_base_monster_id`의 각 값이 `monsters.json`에 실존하는 `monster_id`여야 함(정예 신규 필드, `elite-and-farming-m2.md` §1 참고 — 코드 검증 미구현, `tools/qa/validate_tables.py` 범위 밖)

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
| 결정 요청 11 | `luk.drop_weight_formula`(stats.json)와 `drop_tables.json`의 LUK 곱연산 공식이 이중 정의되지 않도록 단일 소스를 어느 파일로 할지 결정(§3, §9). **해소(D-52)**: `drop_tables.json._luck_formula`가 단일 소스 — `stats.json` 생성 시 문자열을 새로 쓰지 않고 이 블록을 참조만 할 것(stats.json 자체가 아직 없어 최종 확인은 결정 요청 E로 재이관) | §3, §9 |
| 결정 요청 12 (M2-0, `items-and-drops-m2.md` §11-A) | 플레이어 방어력(defense) 소비 공식 미정 — items.json이 defense 스탯을 배분했지만(§7) 피해 감소 환산 공식이 없음. 제안: `damage_taken = incoming_atk × 100 / (100 + defense)` | §7 |
| 결정 요청 13 (M2-0, §11-B) | 정예 2종(`elite_goblin_captain`/`elite_bunchi_spawn`)이 `monsters.json`에 몬스터 엔트리로 아직 없음(`docs/levels/hartland.md`에만 존재) — hp/atk/AI 필드 확정 담당 배정 필요 | §9, §12 |
| 결정 요청 14 (M2-0, §11-C) | epic 이상 아이템이 M2 범위 밖이라 정예·보물상자의 `grade_base_weight.epic`을 0으로 잠갔음(F6-3 "정예=희귀~영웅"과 완전 부합 아님) — M3 epic 아이템 추가 시 함께 갱신 합의 필요 | §9 |
| 결정 요청 15 (M2-0, §11-D) | `farming_sources.json`(F3-5, §11 표)이 아직 없어 정예 리스폰(1800s) 대비 시간당 드랍 기댓값 근사가 실제 파밍 동선과 맞는지 검증 불가 — 작성 시 `items-and-drops-m2.md` §5-3 재계산 필요 | §11 |
