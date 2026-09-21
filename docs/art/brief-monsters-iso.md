# 몬스터 6종 등각 8방향 AI 생성 브리프

> 2026-09-21 작성. 배경: 본편 시점이 등각 2:1로 확정됐고(D-219), 캐릭터는 8방향으로 간다(D-223).
> 대상은 하틀랜드 6종: slime, horn_rabbit(+정예 변종 horn_rabbit_big), mushroom, goblin_scout,
> elite_goblin_captain, elite_bunchi_spawn(구 "뭉치의 새끼"). 프레임 수는 GDD 9장/D-133 그대로
> **유휴 4f · 이동 8f · 공격 6f · 피격 2f · 사망 3~4f** — 몬스터라고 다른 수치를 쓰지 않는다.
>
> **정예 2종(elite_goblin_captain·elite_bunchi_spawn)은 새 캔버스를 만들지 않는다.** 엔진이 이미
> `AnimatedSprite2D.scale` 오버라이드로 정예를 키우는 관행이 있으므로(`monster-attack-anchor.md`),
> 아트는 베이스 골격과 **완전히 같은 캔버스 크기**에 팔레트·소품만 바꾼다 — 이것이 이 브리프의
> 핵심 물량 절약 지점이다(art-director 책임 범위: 몬스터 골격 재사용 매트릭스).
>
> 근거: `docs/art/art-bible.md` §3(하틀랜드 32색)·§9/§9.1(골격 재사용 매트릭스), §4(프레임 규격),
> `docs/specs/isometric-migration-v1.md` §4, `docs/specs/monster-attack-anchor.md`(시각 반지름·
> 스케일 오버라이드 관행), `game/data/monsters.json`, `docs/brd/04-decisions.md` D-227(이 브리프
> 준비 중 정정한 `elite_bunchi_spawn` 골격 오기).

---

## 1. 크기 등급

| 등급 | 캔버스(논리 px) | 배정 몬스터 | 근거 |
|---|---|---|---|
| **작음** | 32×32 | slime, horn_rabbit(+`horn_rabbit_big` 재사용), mushroom | 기존 M1 16×16 셀의 2배 확대 밀도(art-bible §1.1과 동일 원칙), 셋 다 몸집이 작은 필드 잡몹 |
| **중간** | 48×48 | goblin_scout(+`elite_goblin_captain` 재사용) | 직립 인간형이라 8방향 팔·무기 표현에 작음보다 여유가 필요 |
| 큼(예약, 이번 배정 없음) | 64×64 | — | 향후 필드 보스/거대 슬라임 킹('뭉치' 본체 등)용으로 남겨둠 |

- `elite_bunchi_spawn`은 slime 골격 재사용이므로 **작음(32×32)** — §0에서 이미 밝힌 "정예는 새
  캔버스를 안 만든다" 원칙 그대로.
- 캔버스 크기가 발 기준점·피벗 규칙의 정본이다(핀의 96×128/(48,112)와 같은 역할). 실제 피벗은
  각 캔버스의 바닥-중앙: 32×32→(16,32), 48×48→(24,48).

---

## 2. 방향 수 — 8방향 vs 4방향+반전

| 몬스터 | 방향 수 | 이유 |
|---|---|---|
| **slime** | 4방향+반전 허용(실제로는 **정면(S)+우측면(E) 2장만** 생성, N/W는 각각 S/E의 상하·좌우 반전으로 엔진이나 정규화 스크립트가 처리) | 둥근 젤리 몸이라 방향성 있는 디테일(뿔·무기·후드)이 전혀 없다 — 8장을 그려도 눈·입 위치 말고는 차이가 없다 |
| **horn_rabbit**(+big) | **8방향**(5장 원화+3장 반전) | 뿔이 정면을 향하고 귀 각도가 방향마다 달라 방향성이 뚜렷하다 |
| **mushroom** | 4방향+반전 허용(정면+우측면 2장) | `patrol_radius_px=0`(고정형, 순찰 없음) — 애초에 걷지 않으므로 이동 방향성 자체가 약하고, 갓 모양이 거의 대칭이다 |
| **goblin_scout** | **8방향**(5장 원화+3장 반전) | 단검을 오른손에 들고 후드를 쓴 인간형 — 팔·무기 방향성이 필요 |
| **elite_goblin_captain** | goblin_scout과 동일(8방향, 같은 반전 규칙) | 골격 재사용이므로 방향 수도 그대로 승계 |
| **elite_bunchi_spawn** | slime과 동일(4방향+반전, 정면+우측면 2장) | 골격 재사용이므로 방향 수도 그대로 승계 |

- "4방향+반전 허용" 몬스터는 PixelLab에 8방향을 요청하지 않는다 — 정면(S)과 우측면(E) 2장만
  생성하고, `normalize_ai_sheet.py`가 이미 지원하는 가로 반전(E→W)과 세로 반전(구현 필요 시
  Pillow `FLIP_TOP_BOTTOM`, 이번 스크립트 확장 범위 밖 — 결정 필요 항목 §7-1)으로 나머지를 만든다.
  대칭성이 높은 몬스터에 한해 물량을 5장이 아니라 **2장**까지 줄이는 것이 이 등급 배정의 목적이다.

---

## 3. 프레임 표

| 동작 | 프레임 수 | 루프 | 8방향 종(horn_rabbit·goblin_scout·elite_goblin_captain) | 4방향+반전 종(slime·mushroom·elite_bunchi_spawn) |
|---|---|---|---|---|
| 유휴(Idle) | 4f | 반복 | 5장×4f | 2장(S/E)×4f |
| 이동(Walk) | 8f | 반복 | 5장×8f (mushroom은 고정형이라 이동 시트 자체가 불필요 — 만들지 않는다) | 2장×8f (slime만 해당, mushroom 제외) |
| 공격(Attack) | 6f | 1회 | 5장×6f | 2장×6f |
| 피격(Hurt) | 2f | 1회 | 5장×2f | 2장×2f |
| 사망(Dead) | 3~4f | 1회 정지 | 5장×3~4f | 2장×3~4f |

- mushroom은 `patrol_radius_px=0`이므로 걷기 시트를 만들지 않는다(§2 근거 그대로) — 유휴·공격·
  피격·사망만 생산한다. 이는 art-bible §4의 "몬스터 골격 재사용 시에도 프레임 수는 표를 그대로
  따른다" 원칙에 대한 예외가 아니라,애초에 그 동작 자체가 없는 경우다.

---

## 4. 색 지정 (하틀랜드 32색 부분집합)

| 몬스터 | 팔레트 부분집합(art-bible §3 hex) | 비고 |
|---|---|---|
| slime | `#79b8ce`(베이스) `#548789`(그림자) `#71ddee`(하이라이트) `#abc2bc`(테두리) | |
| horn_rabbit | `#c69469`(베이스) `#bd7959`(그림자) `#eecf9b`(하이라이트/뿔) | |
| mushroom | `#e0394c`(갓) `#f2eaf1`(반점) `#a26a83`(갓 안쪽) `#eecf9b`/`#d2b37d`(줄기) | |
| goblin_scout | `#a8a129`(피부) `#5f7160`(피부 그림자) `#965340`/`#61372e`(후드·튜닉) `#8e7c73`(단검날) | |
| elite_goblin_captain | goblin_scout 팔레트 그대로 + `#8e7c73`/`#4e484a`(투구) `#e0394c`(계급 완장) `#a3754e`/`#61372e`(방패) | 새 색 최소 추가(투구·완장·방패용 3색, 전부 기존 32색 안) |
| elite_bunchi_spawn | slime 팔레트 기반 + `#4e484a`(재 얼룩) `#a26a83`(테두리 보라끼) `#d4f5fa`(눈) | D-227: slime 골격 recolor. 새 색 없음(전부 하틀랜드 32색 안) |

- 6종 전부 하틀랜드 32색(art-bible §3) 밖으로 나가지 않는다 — `normalize_ai_sheet.py --quantize`가
  최종 스냅으로 강제한다.

---

## 5. 골격 재사용 매트릭스 (art-bible §9.1에 반영 완료)

| 베이스 | 정예/변종 | 차별화 |
|---|---|---|
| horn_rabbit | horn_rabbit_big | 팔레트 불변, 엔진 스케일 1.3배만(신규 아트 없음) |
| goblin_scout | elite_goblin_captain | 같은 캔버스, 팔레트 스왑(투구·완장·방패 추가) + 엔진 스케일 1.3배 |
| slime | elite_bunchi_spawn | 같은 캔버스, 팔레트 스왑(재/잿빛 얼룩) + 엔진 스케일 1.4배(D-227) |

(art-bible.md §9.1에 이미 같은 표를 반영했다 — 이 브리프는 그 표를 프롬프트 작업 맥락에서
다시 보여주는 것뿐, 정본은 art-bible.md.)

---

## 6. PixelLab 프롬프트 파일 목록

| 파일 | 대상 | 포즈 수 |
|---|---|---|
| `docs/art/mon-slime-iso-prompt.txt` | slime | 2장(S, E) |
| `docs/art/mon-horn-rabbit-iso-prompt.txt` | horn_rabbit(+`horn_rabbit_big` 재사용 안내 포함) | 5장(S,SW,W,NW,N) |
| `docs/art/mon-mushroom-iso-prompt.txt` | mushroom | 2장(S, E) |
| `docs/art/mon-goblin-scout-iso-prompt.txt` | goblin_scout | 5장(S,SW,W,NW,N) |
| `docs/art/mon-elite-goblin-captain-iso-prompt.txt` | elite_goblin_captain | 5장(S,SW,W,NW,N), goblin_scout 골격 재사용 명시 |
| `docs/art/mon-elite-bunchi-spawn-iso-prompt.txt` | elite_bunchi_spawn | 2장(S, E), slime 골격 재사용 명시(D-227) |

각 프롬프트는 이 브리프의 §1(캔버스)·§2(방향 수)·§4(색)를 그대로 반영했다 — 프롬프트 txt 자체가
정본이며 이 문서는 표로 요약만 한다.

---

## 7. 결정 필요 항목

1. **세로 반전(상하 반전) 지원**: slime/mushroom/elite_bunchi_spawn의 "N(후면)"을 S를 상하
   반전해서 만들 수 있는지는 미검증이다 — 슬라임은 완전 대칭이라 상하 반전도 통할 가능성이 높지만
   실제로는 "위쪽에서 보면 그림자만 다르다"는 문제가 있을 수 있다. 지금은 **정면(S)+우측면(E) 2장만
   생성**하고 N/W는 엔진이 그냥 S/E를 재사용(스프라이트를 돌리지 않고 그대로 표시)하는 것으로
   충분한지, 아니면 실제로 상하/좌우 반전 이미지가 필요한지 game-designer/godot-engineer 확인 필요.
   `normalize_ai_sheet.py`에는 아직 상하 반전 기능이 없다(YAGNI — 필요하다고 확정되면 추가).
2. **mushroom 공격 방향성**: `spore_patch`(장판형) 공격이 실제로 방향성이 있는지(캐릭터가 특정
   방향을 보고 공격) 아니면 전방위 AOE라 방향 자체가 무의미한지 game-designer 확인 필요 — 후자면
   공격 시트도 정면 1장만으로 충분해 §3 표보다 더 줄어든다.
3. **elite_goblin_captain 방패 표시 규칙**: §2/프롬프트에서 핀과 같은 "SW/W/NW에서 방패가 앞"
   규칙을 적용했다 — 캡틴이 실제로 방패를 쓰는지(현재 `monsters.json`엔 방패 관련 필드 없음,
   `attack_pattern_id: ranged_dart`만 있음)는 시각적 추가일 뿐 전투 로직에 영향 없음을 확인.
   불필요하면 방패를 빼고 완장·투구만으로 차별화해도 된다.

---

## 변경 이력

- 2026-09-21: 초안 작성(D-219/D-223/D-227). 크기 등급·방향 수·프레임 표·색 지정·골격 재사용
  매트릭스·프롬프트 6개 파일 목록 확정.
