# M4-0: RO 벤치마크 스탯 v2 · 스킬 트리 v2 · SP · 핫바 · 퀘스트 보상

> 기준: GDD v1.1 5.2/5.3, `docs/brd/04-decisions.md` D-141/D-142/D-158~D-166, `docs/research/ro-mechanics-2026-09-20.md`(RO 구조 리서치)
> 소유: game-designer(수치) / godot-engineer(로더·구현)
> 이 문서는 `docs/specs/data_tables.md` §3(stats.json)·§5(skills.json 구 스키마)를 **대체**하고, `docs/specs/skills-m3.md`(M3-3 6종 액티브)를 이번 24노드 트리로 **흡수**한다. 두 문서는 삭제하지 않고 상단에 "v2로 대체됨" 표시만 남긴다(이력 보존).
> **저작권 경계(D-167 원칙)**: RO의 스킬명·직업명·아이콘·정확한 수치는 인용하지 않는다. 가져온 것은 "선행 스킬+스킬 레벨 게이트", "체증 포인트 비용", "SP 분리 자원", "9칸 핫바" 같은 **구조**뿐이며, 계수·이름은 전부 새로 산정했다.
> **실시간 액션 번역 원칙**: RO의 HIT/FLEE는 확률 판정(명중 실패=데미지 0)이다. 우리는 실시간 액션이라 이를 그대로 이식하면 "맞았는데 데미지가 0"이라는 조작감 배신이 생긴다(연구 문서 "주의점"). 그래서 HIT는 **히트박스 크기 보정**으로, FLEE는 **구르기 무적시간 연장 + 이동속도 보정**으로 번역했다. 확률 굴림은 오직 크리티컬(LUK, 기존 시스템 그대로)에만 남는다.

---

## 1. 6스탯 파생 공식표 (`game/data/stats.json`)

AGI가 신규 추가되어 5→6스탯이 됐다. 역할 분담은 연구 문서 §1 권장 그대로 "AGI=몸(회피·속도), DEX=조준(명중·모션잠금 단축)"으로 갈랐다. 기존 DEX의 공격속도 효과는 AGI로 이관했다(레거시 필드는 호환용으로 남기고 실사용 안 함).

| 스탯 | 파생치 | 공식 | 계수(`_balance_todo`) | 화면 효과 |
|---|---|---|---|---|
| STR | ATK | `10 + STR*0.2 + weapon.atk` | `str.physical_damage_per_point=0.2` | 공격력 수치 상승 |
| AGI | ASPD(공격속도) | `combo_frame_mult = max(0.65, 1 - AGI*0.0028 - DEX*0.0008)` — combat.json 콤보 프레임(input_buffer/finisher_recovery 등)에 곱연산 | `agi.aspd_frame_mult_per_point=0.0028`, 부계수 `agi.aspd_dex_secondary_per_point=0.0008`, 하한 `0.65` | 콤보가 더 빠르게 이어짐(연출 체감) |
| AGI | FLEE→구르기 무적 연장 | `roll.iframes_sec += min(0.15, AGI*0.001)` | `agi.roll_iframe_bonus_per_point=0.001`, 상한 `0.15` | 구르기 판정창이 넓어짐(같은 타이밍에도 더 잘 피함) |
| AGI | FLEE→이동속도 | `walk_speed_px *= (1 + min(0.20, AGI*0.0015))` | `agi.move_speed_pct_per_point=0.0015`, 상한 `20%` | 이동속도 상승 |
| DEX | HIT→히트박스 보정 | `hitbox_scale_mult = 1 + min(0.30, DEX*0.0015)` — 내 공격/스킬 히트박스 range_px·width_px에 곱연산 | `dex.hit_hitbox_scale_per_point=0.0015`, 상한 `30%` | 공격 판정이 살짝 넓어져 더 잘 맞음(확률 굴림 아님) |
| DEX | 모션 잠금(후딜) 단축 | `post_attack_recovery_mult = max(0.70, 1 - DEX*0.0015)` | `dex.post_recovery_mult_per_point=0.0015`, 하한 `0.70` | 공격 후 다음 행동까지 빨라짐 |
| DEX | 구르기 스태미나 절감(기존) | `cost * (1 - min(0.5, DEX/300))` | 불변(D-45 정본 문자열) | 구르기 스태미나 소모 감소 |
| INT | MATK | `10 + INT*0.15 + weapon.atk(지팡이류)` | `int.magic_damage_per_point=0.15` | 마법 공격력 상승 |
| INT | 스킬 쿨다운 단축 | `cooldown_sec *= (1 - min(0.30, INT*0.002))` | `int.cooldown_reduction_per_point=0.002`, 상한 `30%` | 스킬 재사용 대기시간 감소 |
| INT | MaxSP·SP회복 | 아래 §3 | `int.max_sp_per_point=2.0`, `int.sp_regen_per_point=0.03` | SP 바 최대치·회복 속도 상승 |
| INT | MDEF(절반) | `MDEF = INT*0.5 + VIT*0.5` | `int.mdef_per_point=0.5` | 마법 방어력 상승 |
| VIT | MaxHP | `+VIT*5.0` | `vit.hp_per_point=5.0` | 최대 체력 상승 |
| VIT | DEF | `damage_taken = incoming_atk*100/(100+DEF)`, `DEF=VIT*1.0+장비` | `vit.defense_per_point=1.0`(D-162 확정) | 받는 피해 감소 |
| VIT | MDEF(절반) | 위 참고 | `vit.mdef_per_point=0.5` | 마법 방어력 상승 |
| LUK | 크리티컬 | `5% + LUK*0.1%`, 상한 75% | 불변(D-162 확정) | 크리티컬 확률 상승 |
| LUK | 드랍 가중치 | `drop_tables.json._luck_formula` 단일 소스(불변) | — | 희귀 아이템 체감 상승 |

**딜레이 2계층 채택(D-167, 연구 문서 §7 권장 3계층 중 축소)**: RO는 모션 잠금 / 애프터캐스트 하한(≈300ms) / 쿨다운 3계층이지만, 우리는 **모션 잠금(기존 공격 애니메이션 길이, DEX가 단축) + 쿨다운(스킬 고유, INT가 단축)** 2계층만 쓴다. 애프터캐스트 하한 계층은 도입하지 않는다 — 별도 필드 없이 두 계층이 서로 다른 스탯이 담당하므로 감산이 겹치지 않는다.

---

## 2. 스탯 포인트 비용 곡선 (`stats.json.allocation`)

연구 문서 §2 권장(요약표 1행): RO 원본 `floor((X-1)/10)+2`(1→99 총 628p)를 만렙 50 규모로 축소해 **`cost(n→n+1) = floor(n/10) + 1`**을 채택했다.

- 0~9구간: 포인트당 1소모, 10~19: 2, 20~29: 3, 30~39: 4, 40~49: 5, 50~59: 6 …

레벨업 지급량도 재산정해 `exp_curve.csv`에 `stat_points_gain` 컬럼을 신설했다(기존 `stats.json.stat_points_per_levelup=3` 고정값은 레거시로 격하):

| 레벨 구간 | 레벨업당 지급 | 근거 |
|---|---|---|
| 2~10 (9회) | 2 | `2 + floor((L-1)/10)` |
| 11~20 (10회) | 3 | 〃 |
| 21~30 (10회) | 4 | 〃 |
| 31~40 (10회) | 5 | 〃 |
| 41~50 (10회) | 6 | 〃 |

**총 지급량 = 198포인트**(레벨 1→50, `python3 -c`로 검산 완료, `exp_curve.csv` 합계와 일치).

### 만렙 몰빵 상한 검산

| 시나리오 | 계산 | 결과 |
|---|---|---|
| 단일 스탯 몰빵 | 0→50 소모 150p(브래킷별 10×1+10×2+10×3+10×4+10×5) + 50→58 소모 48p(8×6) = 198p | **58**까지 도달(구 선형모델 147보다 낮음 → 몰빵 억제 강화, GDD 5.3 "전투력 60%는 장비" 목표 강화) |
| 6스탯 균등분배 | 33p씩 → 0→20 소모 30p + 20→21 소모 3p = 33p | 스탯당 **21**까지 |
| STR 58 몰빵 | `10+58*0.2=21.6` (기본 공격력 10 대비 +116%, 무기 별도) | 장비 의존도 유지 |
| VIT 58 몰빵 | HP `+290`(레벨 자동증가분 별도), DEF `58` → 감소율 `58/158=36.7%` | 과잉 방어 아님 |
| AGI 58 몰빵 | `combo_frame_mult=0.8376`(16.2%↑), `roll_iframe=0.358s`, `move_speed=+8.7%` | 회피형 빌드가 체감되되 과하지 않음 |
| INT 58 몰빵 | `max_sp=136`, `regen=2.74/s`(전투 중) | 스킬 스팸형 빌드 성립 |
| LUK 58 몰빵 | `crit=10.8%`(상한 75%와 거리 있음 — 기존 경고, D-162로 이미 확정값이라 이번엔 재조정 안 함) | — |

전부 `game/data/stats.json.allocation.worked_examples_lv50_198points` / 각 스탯 `worked_examples`에 동일 수치로 기록.

---

## 3. SP 자원 (`stats.json.sp`)

연구 문서 §3~4 권장: "스킬 전용 자원 + INT 비례 회복 + 정지 시 가속". RO의 "앉기(sit)"는 실시간 액션에 안 맞아 **"마지막 스킬 사용 후 경과시간"**으로 대체(스태미나의 `regen_delay_sec`와 동일 패턴 재사용).

```
max_sp        = base_sp(20) + INT * int.max_sp_per_point(2.0)
regen_per_sec = (regen_per_sec_base(1.0) + INT * int.sp_regen_per_point(0.03))
                * (regen_idle_multiplier(2.5) if 마지막 스킬 사용 후 경과 >= regen_idle_delay_sec(2.0) else 1.0)
```

- 스킬(액티브·버프)만 SP 소모. 패시브는 자원 소모 없음(상시 적용). 구르기·가드는 기존대로 스태미나(`combat.json`) 소비 — 변경 없음.
- `INT=0` 빌드는 `max_sp=20`, 전투 중 회복 1.0/s로 T1 스킬(SP 6~10)조차 연속 사용이 어렵다. **의도된 트레이드오프**(RO도 논캐스터는 SP를 거의 안 씀)지만 완전 논캐스터가 스킬을 한 번도 못 쓰게 막는 게 맞는지는 D-167 결정 필요 항목 참고.

---

## 4. 스킬 트리 v2 (`game/data/skills.json`, 24노드)

3계열(blade/guard/trick, D-161 유지) × 8노드(액티브4·패시브3·버프1) = 24. 기존 6종(`blade_power_slash`, `blade_thrust`, `guard_shield_bash`, `guard_iron_wall`, `trick_dash_strike`, `trick_fleet_step`)은 id를 그대로 유지한 채 트리 안에 T1 노드로 흡수했다(엔지니어 마이그레이션 최소화).

### 4-1. 구조 (3계열 공통 패턴)

| 단계 | 노드 수 | 구성 | 해금 조건 |
|---|---|---|---|
| T1 | 3 | 액티브2(무거운 일격 1 + 빠른 견제 1) + 패시브1 | 없음(즉시 습득 가능) |
| T2 | 3 | 액티브1 + 패시브1 + 버프1 | 대응 T1 노드 Lv3 |
| T3 | 2 | 패시브1 + 액티브1(궁극기) | 패시브: 대응 T2 액티브 Lv3 / 궁극기: 대응 T2 패시브+버프 각 Lv3(2개 선행) |

모든 노드 `max_level=5`, `cost_skill_point_per_level=1`(노드 하나 만렙에 SP 5) — 24노드 전체 만렙에는 스킬 포인트 120 필요(레벨업당 1점이면 레벨120 상당, 만렙 50까지는 49점뿐 → 전 노드 만렙 불가능은 **의도**, D-167 결정 필요 항목 참고).

### 4-2. 레벨별 수치 공식(노드 클래스별)

| 노드 클래스 | 대상 | SP소모(Lv1→5) | 쿨다운(Lv1→5) | 배율/효과(Lv1→5) |
|---|---|---|---|---|
| T1-무거움 | blade_power_slash, guard_shield_bash, trick_dash_strike | 10→18(+2/lv) | 4.5s→3.7s(−0.2/lv) | dmg 1.6→2.4(+0.2/lv) |
| T1-빠름 | blade_thrust, trick_quickslash | 6→10(+1/lv) | 2.2s→1.8s(−0.1/lv) | dmg 1.1→1.7(+0.15/lv) |
| T1-방어(특수) | guard_iron_wall | 10→18(+2/lv) | 8.0s→6.4s(−0.4/lv) | invuln_sec 0.8→1.2(+0.1/lv), dmg 0 |
| T2 액티브 | blade_followup, guard_shield_charge, trick_flurry | 14→26(+3/lv) | 6.0s→4.8s(−0.3/lv) | dmg 1.8→2.8(+0.25/lv) |
| T3 궁극기 | blade_finishing_strike, guard_retribution, trick_execute | 25→45(+5/lv) | 12.0s→10.0s(−0.5/lv) | dmg 2.6→4.2(+0.4/lv) |
| 패시브(9종) | 아래 표 | — | — | 스탯별 §4-3 |
| 버프(3종) | blade_bloodlust, guard_fortify, trick_fleet_step | 아래 표 | 아래 표 | 아래 표 |

**패시브 9종**(`passive_stat` / Lv1→5):

| id | 계열 | passive_stat | Lv1→5 |
|---|---|---|---|
| blade_focus | blade | atk_pct | 2→10%(+2/lv) |
| blade_edge | blade | crit_damage_pct | 3→15%(+3/lv) |
| blade_reflex | blade | aspd_pct | 1.5→7.5%(+1.5/lv) |
| guard_bulwark | guard | defense_flat | 2→10(+2/lv) |
| guard_steadfast | guard | guard_damage_reduction_pct | 2→10%(+2/lv) |
| guard_vitality | guard | max_hp_pct | 3→15%(+3/lv) |
| trick_insight | trick | sp_regen_pct | 4→20%(+4/lv) |
| trick_precision | trick | crit_chance_pct | 0.5→2.5%(+0.5/lv) |
| trick_swift | trick | move_speed_pct | 1→5%(+1/lv) |

**버프 3종**(self_effect, Lv1→5):

| id | sp | 쿨다운 | duration_sec | 크기 |
|---|---|---|---|---|
| blade_bloodlust | 18→30(+3/lv) | 25→21s(−1/lv) | 5→9(+1/lv) | atk_buff_pct 6→22%(+4/lv) |
| guard_fortify | 20→32(+3/lv) | 28→24s(−1/lv) | 6→10(+1/lv) | dmg_reduction_pct 10→22%(+3/lv) |
| trick_fleet_step | 12→20(+2/lv) | 15→13s(−0.5/lv) | 4→8(+1/lv) | move_speed_mult 1.20→1.40(+0.05/lv) |

정확한 24×5 전체 수치는 `game/data/skills.json`이 유일한 소스(위 표는 공식 요약, 값 불일치 시 JSON이 정본).

### 4-3. 트리 그래프 (id/타입/선행)

```
blade_power_slash(A,T1) ──Lv3──> blade_followup(A,T2) ──Lv3──> blade_reflex(P,T3)
blade_thrust(A,T1)      ──Lv3──> blade_edge(P,T2) ─┐
blade_focus(P,T1)       ──Lv3──> blade_bloodlust(Buff,T2) ─┴─Lv3+Lv3──> blade_finishing_strike(A,T3 궁극)

guard_shield_bash(A,T1) ──Lv3──> guard_shield_charge(A,T2) ──Lv3──> guard_vitality(P,T3)
guard_iron_wall(A,T1)   ──Lv3──> guard_steadfast(P,T2) ─┐
guard_bulwark(P,T1)     ──Lv3──> guard_fortify(Buff,T2) ─┴─Lv3+Lv3──> guard_retribution(A,T3 궁극)

trick_quickslash(A,T1)  ──Lv3──> trick_flurry(A,T2) ──Lv3──> trick_swift(P,T3)
trick_dash_strike(A,T1) ──Lv3──> trick_precision(P,T2) ─┐
trick_insight(P,T1)     ──Lv3──> trick_fleet_step(Buff,T2) ─┴─Lv3+Lv3──> trick_execute(A,T3 궁극)
```

`requires`는 `[{"skill": "<id>", "level": 3}]` 형태(구 스키마의 문자열 배열에서 변경, RO식 "선행 스킬 N레벨 이상"). VFX 힌트는 `skills.json`의 `vfx.kind`(`slash_arc|thrust_line|ring|glow|dash_trail|speed_lines|none`) 참고 — 계열별 색상(blade `#e2544f`, guard `#5a7ea8`, trick `#7fbf5f`)로 통일.

---

## 5. 핫바 규칙 (9칸, 1~9)

연구 문서 §5 권장: "실사용은 1줄(9칸)뿐" + "스킬/아이템 오조작 방지". 우리는 아래처럼 절충한다.

- **9칸(1~9), 스킬·아이템 혼용 등록**(브리프 요구 그대로 — 연구 문서의 "소모품 전용 분리" 권장은 이번엔 채택하지 않음, 슬롯 수를 늘리지 않기 위한 절충. 오조작 리스크는 슬롯 UI에 아이템/스킬 아이콘 테두리 색을 다르게 해 완화 제안).
- **Q/R 스킬 전용 키 폐지**. 기존 D-119(상호작용 F→E, 스킬2 E→R)의 R도 폐기 — 이제 스킬은 전부 숫자키(1~9)로만 사용.
- **메뉴 탭 이동: Q/E → `[`/`]`**. 상호작용 키 E(D-119)와 충돌 없음.
- 장착 대상: `node_type in {active, buff}`만 슬롯 장착 가능(패시브는 상시 적용이라 슬롯 불필요, RO와 동일 원칙).
- 저장 스키마 제안(엔지니어용, 이번 범위는 명세만): `hotbar_slots: [{type: "skill"|"item"|null, id: string|null}] * 9`, 세이브에 추가.
- UI 등록: 스킬/스탯 패널에서 드래그 또는 "장착" 버튼으로 지정(연구 문서 §5: 키보드 전용 플레이엔 직접 지정 병행).

---

## 6. 퀘스트 보상 (`game/data/quests/act1_hartland.json`, 15개 전부 갱신)

**공식**: 메인 퀘스트 `exp = round(exp_curve.csv[기준레벨].exp_to_next * 0.3~0.5)`. 기준레벨은 그 퀘스트를 완료할 무렵 기대 캐릭터 레벨(D-147 몬스터 경험치 페이싱과 정합). 사이드는 0.15~0.2, 데일리(반복 파밍)는 0.07~0.1로 낮춘다. 골드는 `exp * 1.1~1.25`.

| id | 타입 | 기준레벨 | exp_to_next | 비율 | exp | gold | 아이템/기타 |
|---|---|---|---|---|---|---|---|
| main_a1_01_arrival | main | 1 | 20 | 0.40 | 8 | 10 | — |
| main_a1_02_firstlook | main | 1 | 20 | 0.45 | 9 | 12 | — |
| main_a1_03_shadowfall | main | 2 | 57 | 0.35 | 20 | 25 | — |
| main_a1_04_theshard | main | 3 | 104 | 0.30 | 30 | 35 | **스킬 포인트 +1**(`grant_skill_point:1`) |
| main_a1_05_reclaim | main | 4 | 160 | 0.45 | 72 | 90 | wool_soft×2(기존 유지) |
| main_a1_06_echocave | main | 6 | 294 | 0.40 | 118 | 140 | iron_ore×2(1→2 상향), 스킬 포인트 +1(기존 D-112 이벤트 유지) |
| main_a1_07_fiveroads | main | 8 | 453 | 0.50 | 227 | 270 | **weapon_uncommon_2×1(신규, 1막 마무리 장비)**, 스킬 포인트 +1 |
| side_heartland_montsil | side | 2 | 57 | 0.20 | 11 | 13 | **potion_hp_small×1(신규)** |
| side_heartland_festival_prep | side | 4 | 160 | 0.20 | 32 | 38 | ribbon_charm×1(기존), affinity rozel+1 |
| side_heartland_orefetch | side | 5 | 224 | 0.15 | 34 | 41 | iron_ore×2(기존), affinity pinto+1 |
| side_heartland_herbrun | side | 3 | 104 | 0.20 | 21 | 25 | stew_basic×1(기존), affinity meru+1 |
| side_heartland_waypoint | side | 2 | 57 | 0.15 | 9 | 11 | — |
| daily_heartland_01 | daily | 5(기준) | 224 | 0.10 | 22 | 26 | — |
| daily_heartland_02 | daily | 5(기준) | 224 | 0.07 | 16 | 19 | — |
| daily_heartland_03 | daily | 5(기준) | 224 | 0.10 | 22 | 26 | — |

- **스킬 포인트 보너스는 3개 퀘스트에만**(04/06/07, "일부" 원칙) — `on_complete.events`에 `grant_skill_point:1` 추가/유지(D-112 기존 포맷 재사용, 신규 필드 없음).
- **1막 마무리 장비**: `main_a1_07_fiveroads`에 `weapon_uncommon_2`(level_min 10, 기준레벨 8과 근접) 신규 지급 — 15개 중 유일한 장비 보상.
- **UI 노출**: 브리프 요구대로 수락 전(퀘스트 창)·로그(진행 중 툴팁)·완료 토스트 3곳에 동일 레이아웃(EXP/골드/아이템 아이콘×수량)으로 노출 — 연구 문서 §6 "업계 표준" 권장. 로컬라이징 키 `ui.quest.reward_*`(`ui_ko.csv` 추가 완료) 참고. UI 구현은 이번 범위 밖(엔지니어).
- `_reward_design_ref` 주석을 `act1_hartland.json` 최상단에 추가해 이 표를 역참조하게 했다.

---

## 7. `validate_tables.py`가 v2에서 깨지는 지점 (수정은 엔지니어 몫, 여기는 목록만)

`tools/qa/validate_tables.py`를 v2 데이터로 그대로 실행하면 **`validate_skills()`에서 즉시 `TypeError: unhashable type: 'dict'`로 크래시**한다(구 스키마의 `requires: [string,...]`를 가정한 `if req not in data` 비교에 신 스키마의 `requires: [{"skill":.., "level":..}]` 딕셔너리가 들어가서). 크래시 지점을 임시로 우회한 스크래치 사본으로 계속 돌려 뒤에 숨어있는 실패도 전부 확인했다(85 errors):

1. **`validate_skills` 크래시(최우선 수정 대상)**: `requires` 원소 비교/순환 검출(DFS) 두 곳 모두 `req`를 문자열로 가정. `req.get("skill")` 형태로 바꿔야 함.
2. **`node_type` 화이트리스트 과거값 고정**: `if sk.get("node_type") != "active": error`가 M3-3 범위를 강제하던 코드라, v2의 정당한 `passive`/`buff` 노드 15개가 전부 오류로 잡힌다(24개 중 9 passive+3 buff = 12곳). `{"active","passive","buff"}` 화이트리스트로 교체 필요.
3. **레벨 배열 미인식**: `cooldown_sec`/`stamina_cost`/`damage_mult`를 노드 최상위 필드로 읽는데, v2는 이 값들이 `levels[i]` 안에 있고(게다가 `stamina_cost`→`sp_cost`로 개명) 최상위엔 아예 없다 → 24개 노드 × 3필드 = 72개 "None" 오류. 검증 로직을 `levels[]` 순회 + 레벨 단조성(`sp_cost`/`cooldown_sec` 단조, `damage_mult` 단조 등) 체크로 재작성해야 함.
4. **`stats.allocation.initial` 5키 하드코딩**: `STAT_KEYS = {"str","dex","int","vit","luk"}`가 `agi`를 모른다 → `{'str':0,'agi':0,...}` 6키가 항상 오류. `STAT_KEYS`에 `agi` 추가 필요.
5. **`self_effect` 검증 위치·허용 목록 둘 다 안 맞음**: (a) v2는 `self_effect`가 노드 최상위가 아니라 `levels[i]` 안에 있어 현재 코드는 아예 못 찾는다(위 3번과 같은 구조 문제). (b) 설령 위치를 고치더라도 `SKILL_SELF_EFFECT_KEYS`(3종 고정)에 `{atk_buff_pct,duration_sec}`(blade_bloodlust)·`{dmg_reduction_pct,duration_sec}`(guard_fortify) 2종이 없어 오류가 난다 — 허용 목록에 추가 필요.
6. **`hitbox`/`knockback_px`가 패시브 노드엔 없음(의도)**: 현재 검증은 `damage_mult>0인데 hitbox=null`만 오류로 잡으므로 패시브 자체는 안 걸리지만, `passive_stat`/`value` 같은 v2 패시브 전용 필드는 전혀 검증되지 않는다(사각지대, 크래시는 아님).
7. **몰빵 상한 경고 계산이 legacy 필드 기반**: `validate_stats()`의 `max_points = stat_points_per_levelup(3) * (max_level-1)` 계산이 여전히 구 선형모델(147)을 쓴다 — 실제로는 `exp_curve.csv.stat_points_gain` 합계(198) + `point_cost_curve_formula`(체증)로 역산해야 정확한 몰빵 상한(58)이 나온다. 지금은 crit_chance/cooldown_reduction 경고 메시지의 숫자가 부정확하다(크래시는 아니고 오탐 경고).
8. **`exp_curve.csv` 신규 컬럼(`stat_points_gain`) 무검증**: CSV 로더는 여분 컬럼을 그냥 통과시켜 크래시는 없지만, 값의 단조 비증가 방지(체증)나 `stats.json`의 비용 곡선과의 합계 정합성은 전혀 검사하지 않는다.
9. **퀘스트 보상 검증 자체가 없음**: 스크립트에 `validate_quests()`가 없어 `rewards.gold/exp/items`나 신설 `on_complete.events`의 `grant_skill_point:N` 포맷은 애초에 검증 대상이 아니다(이번 변경으로 새로 깨진 것은 아니고 원래 없었음, 참고용으로 병기).

이 중 1~5는 **파싱/실행 자체가 막히거나 정당한 데이터를 오류로 잘못 신고**하는 실제 회귀이고, 6~9는 신규 필드가 검증 사각지대에 있다는 커버리지 공백이다. 재작성은 엔지니어 몫(스크립트 소유는 game-designer 아님, 이 파일 도입부 관례와 동일).

---

## 8. 결정 필요 항목 (D-184~D-189, 디렉터 확정 — 04-decisions.md)

| ID | 항목 | 제안(기본값) | 비고 |
|---|---|---|---|
| D-184 | 딜레이 구조 2계층(모션잠금+쿨다운) 확정 | **채택**(RO 3계층 중 애프터캐스트 하한 계층 미도입) | 이번 스펙에 이미 반영, 공식 결정 등재만 필요 |
| D-185 | INT=0 논캐스터의 SP 고갈 허용 여부 | 제안: 그대로 허용(의도된 트레이드오프), 대신 스탯 패널에 "SP 부족 시 스킬 사용 불가" 툴팁 노출 | 대안: `base_sp`를 올려 최소 1~2회는 보장 |
| D-186 | 24노드 완전 습득 불가능(스킬P 120 필요, 만렙까지 49점) 허용 여부 | 제안: 허용(빌드 다양성 유도, "선택과 집중"). 몬스터 도감 완성 보너스(GDD 5.3)에 스킬 포인트를 추가 지급처로 열어둘지는 별도 결정 | RO도 전 스킬 만렙은 못 함 |
| D-187 | HIT/FLEE 번역(히트박스 보정/구르기 무적 연장)의 적용 범위 | 제안: 이번 마일스톤은 **플레이어 스탯 효과만** 연결, 몬스터 쪽 명중률(HIT 대응)은 도입하지 않음 | 몬스터 AI에 HIT 개념을 넣을지는 후속 결정 |
| D-188 | 3계열(blade/guard/trick)을 4캐릭터 전원이 공통으로 배우게 할지 | 제안: 이번 스펙은 **전원 공통 허용**(캐릭터 잠금 없음)을 전제로 설계 | `class-progression-v3.md`의 캐릭터별 추천 계열과는 별개(미승인 설계, 참고만) |
| D-189 | 재전직(D-142) 시 스킬 포인트 환불 규칙 | 제안: 이번 스펙 범위 밖, `retraining-policy-v1.md`에 위임 | 계열 전환과 노드 환불의 상호작용은 후속 스펙 |

---

## 부록: `stats.json` 몰빵 계산 검산 스크립트(재현용)

```python
def cost(n):
    return n // 10 + 1

def total_cost(n):
    return sum(cost(i) for i in range(n))

# 총 지급량
gain = lambda L: 0 if L <= 1 else 2 + (L - 1) // 10
total_points = sum(gain(L) for L in range(1, 51))  # 198

# 단일 스탯 몰빵 상한
n = 0
budget = total_points
while total_cost(n + 1) <= budget:
    n += 1
print(total_points, n)  # 198 58
```
