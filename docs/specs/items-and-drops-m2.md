# M2-0 아이템 · 랜덤 옵션 · 드랍 테이블 설계

> 기준: GDD 6장(아이템 & 파밍) 전체, 5.2(스탯 - LUK) / `docs/brd/03-features/03-아이템-파밍.md`(F3-1·F3-2·F3-3, 스펙 S3-3a~c) /
> `docs/brd/04-decisions.md` D-10~D-15·D-32·D-52·D-67 / `docs/specs/data_tables.md` §7~10(items/affixes/drop_tables/enhance) /
> `docs/specs/combat-tuning-m1.md` §8(하틀랜드 초원 몬스터 3종) / `docs/levels/hartland.md` ⑤(정예 2종·보물상자) /
> `game/data/monsters.json` / `game/scripts/core/data.gd`(스키마 로딩 형식) / 캐릭터 서사 플레이버 규칙(`characters.md` §6)
>
> 범위: M2-0(F3-1 데이터 기반). 레벨 1~15(하틀랜드=초원 지역, ★1 난이도)만 확정한다. 16~50 레벨과
> epic/legendary/relic 등급 아이템은 M3 이후 지역이 늘어날 때 이 문서의 공식을 그대로 연장해 채운다(공식은 이미 6등급·전
> 레벨 범위에 대해 정의돼 있어 확장 시 새 공식이 필요 없다 - §2, §5 참고).
>
> 산출물: `game/data/items.json`(57개) · `game/data/affixes.json`(20종) · `game/data/drop_tables.json`(6개 소스) ·
> `game/data/enhance.json` · `tools/qa/validate_tables.py`. 검증 결과는 §6.

---

## 1. 스코프 요약

| 구분 | 수량 | 비고 |
|---|---|---|
| 장비 아이템 | 42개 | 7카테고리(weapon/sub/head/armor/boots/ring/amulet) × 3등급(common/uncommon/rare) × 2레벨티어 |
| 소모품 | 4개 | 포션 2(HP) + 음식 2(버프) |
| 재료 | 8개 | enhance_stone·slime_jelly·rabbit_horn·mushroom_cap·iron_ore·goblin_fang·marsh_moss·salvage_scrap |
| 백팩(치장, D-11) | 3개 | common/uncommon/rare 각 1 (+10/+25/+40칸) |
| **items.json 합계** | **57개** | |
| 옵션 풀(affixes.json) | 20종 | GDD 6.3 "20종" |
| 드랍 테이블(drop_tables.json) | 6개 소스 | 필드 일반 3종 + 정예 2종 + 보물상자 1종 |

- 반지는 물리적으로 2슬롯(GDD 6.2 "동일 반지 2개 중복 장착 허용", D-12)이지만 아이템 카테고리는 `ring` 하나로 공유한다 —
  "8슬롯"은 장비 슬롯 수(무기/보조/투구/갑옷/신발/반지×2/부적)이지 아이템 카테고리 수(7)가 아니다.
- 치장 슬롯 중 모자·의상(`costume_hat`/`costume_outfit`)은 이번 패스 범위 밖(성능 무관 코스메틱, D-11이 요구하는 것은
  백팩뿐). 소모품 중 요리(음식)는 GDD 5.3 예시("매콤 버섯구이 = 10분간 공격력 +8%")를 그대로 첫 아이템에 반영했다.

---

## 2. 등급별 기본 스탯 범위 & 레벨 스케일 (레벨 1~15)

### 2-1. 공식

아이템 자체는 "레벨 구간에 맞춰 미리 굴려둔 고정 스탯"을 갖는다(개별 드랍 인스턴스가 레벨에 따라 동적으로 재계산되지
않는다 - 인스턴스별 가변 값은 옵션(affix)뿐). 대신 같은 카테고리·등급 안에 **레벨 티어 2개**(초반/후반)를 둬서 15레벨
구간 안에서도 자연스러운 재파밍 동기를 만든다.

```
L(level)      = 1 + 0.12 × (level − 1)                # 레벨 스케일 계수
c_grade       = { common: 1.0, uncommon: 1.5, rare: 2.2 }   # 등급 계수
base_stat(cat, grade, level) = k_cat × c_grade × L(level)   # 카테고리별 1차 스탯
```

`k_cat`(카테고리 예산 계수)과 티어별 기준 레벨:

| 카테고리 | 1차 스탯 | k_cat | common t1(lv1) | common t2(lv5) | uncommon t1(lv6) | uncommon t2(lv10) | rare t1(lv10) | rare t2(lv14) |
|---|---|---|---|---|---|---|---|---|
| weapon | atk (min~max, ±15%) | 3.0 | 3~4 | 4~5 | 6~8 | 8~10 | 13~15 | 14~19 |
| sub | defense | 2.0 | 2~3 | 3~3 | 5~5 | 6~7 | 9~10 | 11~13 |
| head | defense | 1.5 | 1~2 | 2~3 | 4~4 | 5~5 | 7~8 | 8~9 |
| armor | defense | 2.5 | 2~3 | 4~4 | 6~7 | 8~9 | 11~13 | 14~16 |
| boots | defense | 1.5 | 1~2 | 2~3 | 4~4 | 5~5 | 7~8 | 8~9 |
| ring | 지정 스탯(STR/DEX/INT/VIT) 1개 flat | 1.5 | 2(STR) | 2(DEX) | 4(INT) | 5(VIT) | 7(STR) | 8(DEX) |
| amulet | elemental_damage_pct | 2.5(가치 산정용) | 3%(원소없음) | 3%(fire) | 5%(wind) | 5%(thunder) | 8%(water) | 8%(원소없음, 최상급) |

**근거**:
- 계수 0.12/레벨은 레벨 15에서 `L=2.68`(레벨1 대비 2.68배) — GDD 5.3 "전투력의 60%는 장비" 목표에 맞춰, 무기
  기준 rare t2(레벨14) atk 16.9(중간값) vs 플레이어 기본 공격력 10(`combat-tuning-m1.md` §0)이 되어 **장비 하나만으로
  기본 공격력의 약 1.7배**를 얹는다. 여기에 affix(공격력%·속성데미지% 등, §3)가 추가로 20~40% 붙으므로 만렙(15) 풀장비
  기준 총 전투력의 60%+ 가 장비에서 나온다는 GDD 목표를 만족한다.
- 등급 계수(1.0/1.5/2.2)는 "고급→희귀"의 체감 상승폭(약 1.47배)이 "일반→고급"(1.5배)보다 완만하지 않게 설계 —
  희귀가 옵션 2개(affix_slot_count=2)까지 더해지므로 기본 스탯 자체는 유사한 배수로 두고 옵션 개수로 진짜 격차를 낸다.
- 레벨 티어는 등급마다 2개만 둬 "약 40개"(요청 수량)를 맞췄다. 3~15레벨 전체를 촘촘히 커버하기보다 **등급 간 교차
  구간**(uncommon t2=lv10, rare t1=lv10)을 의도적으로 겹쳐 "같은 레벨이라도 등급이 깡패"라는 ARPG 공식 룰을 지킨다.
- 방어력(defense) 수치는 **아직 소비할 공식이 없다** — D-49는 "몬스터 방어력은 M2에서 도입"만 확정했고, 플레이어
  방어력이 피해를 얼마나 감소시키는지(`damage_taken = atk × 100/(100+defense)` 같은 공식)는 전투 시스템 결정 사항이라
  이 문서 범위 밖이다. §7 결정 요청에 제안 공식을 남긴다.

### 2-2. 검증 규칙
1. 등급별 `affix_slot_count`: common=0 / uncommon=1 / rare=2 (data_tables.md §7 규칙 그대로)
2. `level_min`은 1~15 범위, 같은 (category, grade) 쌍 안에서 t1 < t2
3. `base_stats.*_min ≤ base_stats.*_max`
4. `unique_skill_id`가 있으면 `grade == legendary`, `set_id`가 있으면 `grade == relic` (M2 범위엔 해당 등급이 없어
   항상 `null`이지만 필드는 미리 스키마에 존재 - M3에서 값만 채우면 됨)

---

## 3. 옵션 풀 20종 (`affixes.json`)

GDD 6.3 예시(공격력%, 속성 데미지, 크리확률, 이동속도, 골드획득량, 쿨감, 흡혈 등)를 20종으로 확장했다. **등급은 옵션
값 범위에 영향을 주지 않고 개수만 늘린다**(F3-1: 고급1/희귀2) — `value_min`/`value_max`는 등급 무관 단일 범위다.

| affix_id | 효과 | 값 범위 | 적용 카테고리 | weight | 비고 |
|---|---|---|---|---|---|
| atk_pct | 공격력 % | 3~8% | weapon/sub/ring/amulet | 10 | 가장 흔한 범용 옵션 |
| crit_chance | 크리티컬 확률 +%p | 2~5%p | weapon/ring/amulet | 8 | |
| crit_damage_pct | 크리티컬 데미지 % | 5~15% | weapon/ring | 6 | |
| move_speed_pct | 이동속도 % | 2~5% | boots/ring | 5 | |
| gold_find_pct | 골드 획득량 % | 5~15% | ring/amulet/armor | 6 | |
| cooldown_reduction_pct | 스킬 쿨타임 감소 % | 2~6% | amulet/ring/head | 5 | INT의 쿨감과 별개 가산 |
| life_steal_pct | 흡혈 % | 1~3% | weapon/ring | 4 | |
| elemental_dmg_{fire,wind,thunder,water}_pct | 속성별 데미지 % (4종) | 4~10% | weapon/amulet | 4 (각) | elements.json.cycle 4원소와 1:1 대응 |
| elemental_dmg_holy_pct | 홀리 데미지 % | 3~8% | weapon/amulet | 2 | demon 태그 상성 전용이라 하틀랜드 체감 낮음 → 가중치 축소 |
| max_hp_flat | 최대 HP + | 8~20 | armor/head/boots/sub/amulet | 9 | |
| max_stamina_flat | 최대 스태미나 + | 5~15 | armor/boots/sub | 7 | |
| stamina_cost_reduction_pct | 스태미나 소모 감소 % | 3~8% | boots/sub | 5 | DEX 구르기 경감(D-45)과 별개 가산 |
| defense_flat | 방어력 + | 2~6 | armor/head/boots/sub | 9 | |
| item_find_pct | 아이템 발견율 % | 3~8% | ring/amulet | 5 | LUK 곱연산(§4)과 별도의 가산 2차 배율 |
| exp_gain_pct | 경험치 획득량 % | 3~8% | amulet/ring | 4 | |
| attack_speed_pct | 공격 속도 % | 2~5% | weapon/ring | 6 | |
| damage_reduction_pct | 받는 피해 감소 % | 2~5% | armor/head/sub | 5 | |

**합계 20종** (elemental 4종을 개별 stat_type으로 셈). weight는 옵션 풀 내 상대 추첨 가중치이며 합계 제약은 없다(§6
검증 규칙 참고).

---

## 4. LUK 곱연산 공식 (D-52 단일 소스)

`drop_tables.json` 최상단 `_luck_formula` 필드가 유일한 정의처다. `stats.json.luk.drop_weight_formula`(아직 파일
없음, M1 stats.json 미생성)가 이 문서 채택 시점부터 생기면 **문자열을 새로 쓰지 말고 이 블록을 참조만** 하도록
엔지니어에게 요청한다(§7, 결정 요청 11 해소).

```
raw_weight[grade]      = grade_base_weight[grade] × luk_multiplier[grade]
luk_multiplier[common] = 1.0
luk_multiplier[g≠common] = 1.0 + LUK × luk_coefficient[g]
final_probability[grade] = raw_weight[grade] / Σ raw_weight[all grades]
```

| 등급 | luk_coefficient |
|---|---|
| uncommon | 0.004 |
| rare | 0.010 |
| epic | 0.020 |
| legendary | 0.035 |
| relic | 0.050 |

등급이 높을수록 계수가 커서(0.004→0.05) "LUK 1점의 가치"가 상위 등급일수록 크다 — 파밍 후반(레어 확정 소스인
정예·던전)일수록 LUK 투자 체감이 커지는 구조. 최대 레벨(50)에서 스탯 전량(3×50=150)을 LUK에 넣는 극단값도
`multiplier[relic] = 1+150×0.05 = 8.5배`로 발산하지 않는 안전 범위.

**검증 예시**(`elite_goblin_captain`, `grade_base_weight={common:0.15, uncommon:0.45, rare:0.40}`):

| LUK | common 최종% | uncommon 최종% | rare 최종% |
|---|---|---|---|
| 0 | 15.00% | 45.00% | 40.00% |
| 20 | 13.44% | 43.55% | 43.01% |

LUK 20에서 rare가 +3.01%p 오르는 대신 common이 -1.56%p 내려간다 — **곱연산이 common을 직접 깎는 게 아니라, 다른
등급의 raw_weight가 커지며 정규화 분모가 늘어나 상대적으로 밀려나는** 원리임을 보여준다(공식이 의도한 그대로 동작).

---

## 5. 드랍 테이블 설계 (`drop_tables.json`, 6개 소스)

### 5-1. 등급 접근 규칙

GDD 6.1 "등급별 획득처" 표를 소스별 `grade_base_weight`에 그대로 반영한다.

| 등급 | GDD 6.1 공식 획득처 | M2 반영 |
|---|---|---|
| 일반(common) | 필드 몬스터 | 필드 3종만 0이 아닌 값 |
| 고급(uncommon) | 필드·미니던전 | 필드 3종 + 정예 2종 + 보물상자(미니던전 대역) 모두 0 아님 |
| 희귀(rare) | 던전·정예 몬스터 | 정예 2종·보물상자만 0 아님, **필드 3종은 0** (GDD가 필드 몬스터를 rare 출처로 명시하지 않음) |
| 영웅(epic) 이상 | 보스·비밀상자 | **M2는 전부 0** - epic/legendary/relic 아이템이 아직 `items.json`에 없어 항목을 채우면 참조가 빈다(§7 결정 요청) |

정예 2종은 F6-3("정예: 희귀~영웅 + 도면 확률")에 따라 uncommon/rare에 걸쳐 두텁게, common은 15%만 남겨 전용 소재
(고블린 이빨/습지 이끼) 드랍 통로로 쓴다(0%면 해당 등급이 아예 안 뽑혀 소재 엔트리가 죽는 버그가 된다 -
`validate_tables.py`가 이 케이스를 전용 규칙으로 잡는다, §6).

### 5-2. 소스별 요약

| source_id | 대상 | grade_base_weight (common/uncommon/rare) | gold_drop | 비고 |
|---|---|---|---|---|
| slime_common | 방울 슬라임(TTK 2타, 최약체) | 0.75 / 0.25 / 0 | 2~5 | |
| horn_rabbit_common | 뿔토끼(TTK 3타) | 0.70 / 0.30 / 0 | 4~8 | |
| mushroom_common | 버섯돌이(TTK 4타, 최탱키) | 0.65 / 0.35 / 0 | 5~10 | TTK가 길수록 uncommon 비중↑ - "더 오래 싸운 만큼 더 준다" |
| elite_goblin_captain | 정예(리스폰 1800s) | 0.15 / 0.45 / 0.40 | 25~45 | 소재=goblin_fang |
| elite_bunchi_spawn | 정예(리스폰 1800s) | 0.15 / 0.45 / 0.40 | 25~45 | 소재=marsh_moss, 골고루 동급으로 설계(어느 쪽을 잡아도 손해 없음) |
| field_treasure_chest | 미니던전 보물상자(범용) | 0 / 0.40 / 0.60 | 15~30 | common 없음 - "상자는 최소 고급 보장" |

### 5-3. 기대값 계산 (파밍 1시간당)

**가정(추정, M1-4 플레이테스트 계측 로그로 추후 검증 필요)**: 처치+접근+포지셔닝을 포함한 몬스터 1마리당
평균 사이클 시간 — 슬라임 8초(TTK 2타로 가장 짧음), 뿔토끼 12초(돌진 회피 판단 포함), 버섯돌이 15초(장판 회피 이동
포함), 정예 45초(2배 이상 긴 교전 + 스폰 지점 이동, `attack_recovery_sec` 등 정예 강화 패턴 반영 예정).

| source_id | 시간당 처치 수 | 시간당 기대 골드 | 시간당 uncommon+ 개수 | 시간당 rare 개수 |
|---|---|---|---|---|
| slime_common | 450 | 1,575 | 112.5 | 0 |
| horn_rabbit_common | 300 | 1,800 | 90.0 | 0 |
| mushroom_common | 240 | 1,800 | 84.0 | 0 |
| elite_goblin_captain | 80 | 2,800 | 36.0 | 32.0 |
| elite_bunchi_spawn | 80 | 2,800 | 36.0 | 32.0 |

**해석**:
- 필드 몬스터 3종은 시간당 기대 골드가 1,575~1,800으로 거의 균일 — TTK가 길수록(마릿수↓) 마리당 골드를 올려
  "어느 필드를 돌아도 시간당 수입은 비슷하다"는 파밍 공평성을 의도했다.
- 정예(30분 리스폰)는 필드보다 시간당 rare 획득 기댓값이 압도적으로 높다(필드 rare=0 vs 정예 32/hr) - 이것이 정예를
  "오늘 할 것" 목록의 최우선 항목으로 만드는 F3-5 리텐션 설계(GDD 6.5)의 수치적 근거다. 단, 정예는 30분 쿨다운이 있어
  실제 시간당 32개가 아니라 **1회 처치당 rare 기대 0.40개**로 해석해야 한다(연속 사냥 가정은 스폰이 여러 지역에
  분산돼 있을 때만 근사적으로 성립 - farming_sources.json 완성 후 재검증 필요, §7 결정 요청).
- `field_treasure_chest`는 rare 60% 고정이라 **상자 1개 = rare 기대 0.6개** - 미니 던전(5~10분) 완주 보상으로서
  "필드보다 확실히 낫다"를 담보한다.

### 5-4. 검증 규칙 (`tools/qa/validate_tables.py`가 자동 확인)
1. `grade_base_weight` 6개 키 모두 존재, 합계 = 1.0 (±1e-6)
2. `entries[].item_id`가 `items.json`에 존재
3. `grade_base_weight[g] > 0`인데 `entries`에 해당 등급 아이템이 하나도 없으면 오류(빈 드랍 풀 방지 - M2에서 실제로
   한 번 잡았던 버그, §5-1 참고)
4. `qty_min ≤ qty_max`, `weight > 0`, `gold_drop.min ≤ gold_drop.max`
5. `_luck_formula.luk_coefficient`가 uncommon→relic 순으로 단조증가

---

## 6. 강화 +0~+10 비용·배율표 (`enhance.json`)

| 단계 | 성공률 | 골드 | 강화석 | 스탯 배율 |
|---|---|---|---|---|
| +1 | 100% | 20 | 1 | ×1.08 |
| +2 | 100% | 35 | 1 | ×1.16 |
| +3 | 100% | 55 | 2 | ×1.24 |
| +4 | 100% | 80 | 2 | ×1.32 |
| +5 | 100% | 110 | 3 | ×1.40 |
| +6 | 100% | 150 | 3 | ×1.48 |
| +7 | **70%**(D-14) | 200 | 4 | ×1.56 |
| +8 | **55%**(D-14) | 260 | 5 | ×1.64 |
| +9 | **40%**(D-14) | 330 | 6 | ×1.72 |
| +10 | **25%**(D-14) | 420 | 8 | ×1.80 |

- 배율 공식: `stat_multiplier(+N) = 1 + 0.08×N` (단조증가, 매 단계 +8%p). +10에서 기본 스탯의 1.8배 — 레어급
  무기(atk 16.9 중간값) 기준 +10 강화 시 atk ≈30.4로, 만렙 근처 캐릭터의 화력 절반 가까이를 강화 하나가 좌우하게
  설계해 "강화를 계속 해야 할 이유"를 만든다.
- **실패 시 강화석만 소실, 단계 유지**(D-32, 실패 천장 없음) — 매 시행이 독립 베르누이라 기댓값은 `1/success_rate`회.

**+10까지 도달 기대 비용**(실패 재시도 포함, 독립시행 가정):

| 구간 | 기대 골드 | 기대 강화석 |
|---|---|---|
| +1~+6 (무실패) | 450 | 12 |
| +7 (기대 1.43회) | 285.7 | 5.71 |
| +8 (기대 1.82회) | 472.7 | 9.09 |
| +9 (기대 2.5회) | 825.0 | 15.0 |
| +10 (기대 4.0회) | 1,680.0 | 32.0 |
| **합계** | **≈3,713 골드** | **≈74개** |

이 값은 economy.json(아직 미생성)의 "구간별 기대 보유 골드" 설계 시 상한선 참고치로 쓸 수 있다(엔지니어/경제
담당에게 전달, §7).

---

## 7. 재련 비용 (D-13)

옵션이 없는 common은 재련 대상이 아니다(재굴림할 줄 자체가 없음). 재료는 강화석(`enhance_stone`) 재사용 —
"장비를 더 파고들수록 강화와 재련이 같은 자원을 두고 경쟁"하게 만들어 파밍한 강화석을 어디에 쓸지 선택하는 미니 결정을
추가한다.

| 등급 | 1회차 | 2회차 | 3회차(D-13: 3회 상한) |
|---|---|---|---|
| uncommon | 100G + 강화석 2 | 150G + 강화석 3 | 220G + 강화석 4 |
| rare | 200G + 강화석 4 | 300G + 강화석 6 | 450G + 강화석 8 |
| epic | 400G + 강화석 8 | 600G + 강화석 12 | 900G + 강화석 16 |
| legendary | 800G + 강화석 15 | 1,200G + 강화석 22 | 1,800G + 강화석 30 |
| relic | 1,500G + 강화석 25 | 2,200G + 강화석 35 | 3,300G + 강화석 50 |

- 등급마다 약 2배씩 뛰는 비용 곡선(uncommon→rare→epic→...)으로 "상위 등급일수록 재련도 신중하게" 압박을 준다.
- **결과는 신·구 옵션 중 택1**(D-13), 확정 시 횟수 1 차감 — 마음에 안 들면 비용만 날리고 기존 옵션 유지 가능(택1
  자체는 무료 재시도가 아니라 "굴리는 행위"에 비용이 들고, 어느 쪽을 쓸지는 무료로 고른다).

---

## 8. 분해 산출표

| 등급 | 강화석 | 재료(salvage_scrap) |
|---|---|---|
| common | 1 | 1 |
| uncommon | 2 | 2 |
| rare | 4 | 3 |
| epic | 7 | 5 |
| legendary | 12 | 8 |
| relic | 20 | 13 |

등급이 높을수록 단조증가(검증 규칙, §5-4와 동일 스크립트가 확인). rare 분해 1개 = 강화 +3(80골드+2강화석) 정도의
강화석을 돌려주는 수준으로 맞춰, "안 쓰는 장비를 분해하면 다른 장비 강화에 보탬이 된다"는 GDD 6.4 "인벤토리 압박의
보상 전환"을 수치로 뒷받침한다.

---

## 9. 검증 스크립트 실행 결과

```
$ python3 tools/qa/validate_tables.py
[validate_tables] data dir = <repo>/game/data
[validate_tables] items=57 affixes=20 drop_tables=6 monsters=3

PASS - 모든 검증 규칙 통과
```

검사 항목: items.json(등급별 affix_slot_count 규칙·unique_skill_id/set_id 등급 제약·sell_price 범위), affixes.json
(stat_type ≥20종·value_min≤max·applicable_categories 유효성), drop_tables.json(grade_base_weight 합계 1.0·entries
참조 무결성·빈 드랍 풀 방지·luk_coefficient 단조증가), enhance.json(D-14 성공률 고정값·D-13 재련 3회 상한·분해 산출
단조증가), monsters.json↔drop_tables.json 교차 참조(D-67).

---

## 10. 엔지니어 요청 (godot-engineer, `game/scripts/core/data.gd`)

M1 시점 `REQUIRED_SCHEMA`는 `combat`/`elements`만 다루고 items/affixes/drop_tables/enhance는 아직 스키마 검증
대상이 아니다(§0 참고: "테이블이 늘어나면 여기에 추가한다"). 아래 항목을 `REQUIRED_SCHEMA`/전용 검증 함수(monsters
처럼 동적 딕셔너리라 `_validate_items()`/`_validate_drop_tables()` 형태가 될 것)에 반영해달라:

1. **items.json 신규 필드**: 이번 패스에서 `docs/specs/data_tables.md` §7 스키마에 없던 `level_min`(int, 1~15),
   `base_stats`(object, 카테고리별 하위 키 상이), `element`(amulet 전용, string|null), `inventory_slot_bonus`(int,
   costume_backpack 전용), `effect_type`/`effect_value`/`duration_sec`(consumable 전용)를 추가했다. §7 문서 표는
   이 문서 갱신과 함께 반영했으니(별도 커밋) `REQUIRED_SCHEMA`에 있는 그대로 등록해달라.
2. **drop_tables.json 신규 필드**: `gold_drop.min`/`gold_drop.max`(§9 스키마에 없던 필드, 몬스터 처치 시 골드 지급
   용). `_luck_formula` 최상단 블록이 파일 로드 시 반드시 존재해야 하는 스키마 키인지 확인 부탁(현재는
   `tools/qa/validate_tables.py`만 이를 검사).
3. **enhance.json 신규 필드**: `refine.cost_material_id`(string, 현재 값 `"enhance_stone"`), 등급별
   `refine.cost_by_grade_and_attempt.{grade}.attempt_{1,2,3}.cost_material_qty`.
4. **재련 횟수(3회) 카운터 저장 위치**: `enhance.json.refine.max_attempts=3`은 상한값일 뿐, 장비 개체별 "남은 횟수"는
   `items.json`(정의 테이블)이 아니라 인벤토리에 저장된 드랍 인스턴스 상태로 관리해야 한다 - 저장 스키마(세이브 파일)
   설계 시 참고.
5. `Data._validate()`에 `monsters.json.drop_table_id`(null이 아닌 경우) → `drop_tables.json` 키 존재 확인 로직을
   추가해달라(D-67 활성화, `data_tables.md` §12 검증 규칙 2가 이미 문서화되어 있음 - 코드 구현만 남음).

---

## 11. 결정 요청 목록 (ID는 메인 세션 부여)

| 항목 | 내용 | 관련 절 |
|---|---|---|
| 결정 요청 A | 플레이어 방어력(defense) 소비 공식 미정 — 이 문서는 아이템에 defense 스탯 값을 이미 배분했지만(§2-1),
  피해 감소로 환산하는 공식이 없다. 제안: `damage_taken = incoming_atk × 100 / (100 + defense)`(디아블로류 관습적
  형태, defense=100일 때 피해 50% 감소). M2 전투 밸런스 담당(본인 game-designer 겸임 또는 별도 결정) 확정 필요 | §2-1 |
| 결정 요청 B | 정예 2종(elite_goblin_captain/elite_bunchi_spawn)이 `monsters.json`에 아직 몬스터 엔트리로 존재하지
  않는다(`docs/levels/hartland.md`에는 있으나 hp/atk/AI 필드 미정) - 드랍 테이블은 이 문서에서 먼저 만들었으니, 레벨
  디자인/전투 밸런스 쪽에서 몬스터 본체 스탯을 확정하는 후속 태스크를 배정해달라 | §5-2 |
| 결정 요청 C | epic 이상 등급 아이템(items.json)이 M2 범위 밖이라 정예·보물상자의 `grade_base_weight.epic`을 0으로
  잠갔다(F6-3 "정예=희귀~영웅"과 완전히 부합하지 않음) - M3에서 epic 아이템을 추가하는 시점에 이 문서와
  `drop_tables.json`을 함께 갱신하는 것으로 합의 필요 | §5-1 |
| 결정 요청 D | `farming_sources.json`(F3-5)이 아직 없어 "정예 30분 쿨다운 동안 시간당 rare 32개"라는 §5-3의 근사가
  실제 파밍 루프(여러 정예를 돌며 쿨다운을 회피하는 동선)와 맞는지 검증 불가 - `farming_sources.json` 작성 시
  이 문서 §5-3을 재계산해야 한다 | §5-3 |
| 결정 요청 E | `stats.json`(F1-2)이 아직 없어 `luk.drop_weight_formula`가 실제로 `_luck_formula`를 참조하는지
  코드 레벨로 확인 불가(결정 요청 11, data_tables.md 기존 항목과 동일 건) - `stats.json` 생성 시 문자열 중복 정의
  대신 참조 방식 사용을 결정해달라 | §4 |
