# 쿼터뷰 이관 단계 (b) 계획 — 32px 오블리크 타일 · 마을 배치 · 벽 충돌

- 작성: gameplay-programmer, 2026-09-20. 브랜치 `stage/m5-3-quarter-view-b`, 베이스 `ba544c1`(단계 (a)).
- 상태: **계획 전용. 구현은 결정(§7) 확정 후.** 이 문서는 코드를 바꾸지 않는다.
- 목표: 사용자가 "쿼터뷰가 됐다"고 체감하는 것. (a)는 규칙만 깔았고 16px 탑다운 아트라 화면이 거의 그대로다.

---

## 1. 먼저 — "×2 일괄"은 한 가지 뜻이 아니다

지시의 "좌표·속도·거리 상수 ×2 일괄"을 그대로 실행하기 전에 확인한 것:

**모든 px 값을 똑같이 2배 하면 화면은 하나도 안 바뀐다.** 타일도, 캐릭터도, 맵 좌표도, 카메라가 담는 범위도 전부 2배가 되므로 단위 이름만 바뀐 것과 같다. 실측:

| | 화면에 보이는 타일 수 | 텍스처 1px = 기기 px |
|---|---|---|
| 현재 (타일 16wu, zoom 2, 아트 16px) | 20.0 × 11.2 | 6 |
| (b) 전부 ×2 (타일 32wu, zoom 1, 아트 32px) | **20.0 × 11.2** | **3** |

즉 ×2 일괄이 주는 것은 **아트 해상도 2배뿐**이고, 그건 정확히 우리가 원하는 것이다 — 게임플레이는 한 톨도 안 바뀐다는 뜻이기도 하다. 사용자가 체감할 "쿼터뷰가 됐다"는 숫자가 아니라 **오블리크 아트·벽 정면·나무·집·마을 배치**에서 나온다.

여기서 갈리는 세 가지를 분리해야 한다:

| 축 | 현재 | 목표 | (b)에서? |
|---|---|---|---|
| 타일 아트 해상도 | 16px | 32px (GDD 9장) | **한다** |
| 월드 단위 (1타일 = 몇 wu) | 16 | 32 | **한다** (순수 단위 전환) |
| **캐릭터 : 타일 비율** | 1×1 타일 | **2×3 타일** (핀 64×96 / 타일 32, D-140) | **하지 않는다 — (c)로** |

세 번째가 함정이다. 캐릭터를 타일 대비 크게 만드는 것은 단위 전환이 아니라 **게임플레이 공간의 실제 변경**이다 — 근접 사거리·히트박스·몬스터 간격·마을 통로 폭이 전부 재튜닝 대상이 되고, 그건 game-designer 몫이다. 게다가 지금 하면 16px 기사를 4배로 늘린 뭉개진 그림으로 튜닝하게 된다. **실제 64×96 핀이 들어오는 (c)에서 아트와 함께 한다.**

그래서 (b)의 ×2는 **모든 px을 예외 없이 2배 하는 순수 단위 전환**으로 한정한다. 예외를 두는 순간 "단위 전환"이 아니라 밸런스 변경이 되고, 검증할 수 없게 된다.

> 지시의 "플레이어·몬스터 스프라이트 2배 표시"는 이 원칙 하에서 **월드 크기 유지 + 아트 해상도 2배**로 해석한다(16px 아트를 `scale=2`로 키워 32wu를 채운다 — 타일도 32wu가 되므로 캐릭터:타일 비율은 1:1로 **현재와 동일**). 캐릭터가 타일 대비 커지는 것은 (c).
> 지시의 "히트박스·aggro·melee_range ×2 일관성 스모크"도 이 해석에 맞춰 **비율 불변 검사**로 만든다(§5).

### 1.1 대안 — 단위 전환 없이 가기 (결정 Q7)

데이터 100여 개를 건드리는 게 부담이면, 월드 단위를 16wu로 둔 채 32px 아트를 `TileMapLayer.scale = 0.5`로 얹는 방법이 있다. **데이터·좌표·세이브 변경 0**으로 같은 해상도를 얻는다.
대가: 이후 영원히 "1wu = 아트 2px"가 되어 D-140의 64×96 핀이 32×48wu가 되는 등 모든 수치에 ÷2 암산이 붙는다. 한 번 하고 끝나는 기계적 변환을 피하려고 영구 세금을 무는 셈이라 **권고하지 않는다.** 다만 (b)를 최소 위험으로 가져가야 하면 이 길이 있다.

---

## 2. 애셋: `tools/art/gen_quarter_tiles.py`

기초 도형 + 하틀랜드 32색으로 오블리크 placeholder를 생성한다. 사용자가 ChatGPT로 만든 정식 애셋과 **파일명·크기·발 기준점이 같아서 파일만 덮어쓰면 되게** 한다.

### 2.1 팔레트

`docs/art/art-bible.md` §3의 하틀랜드 32색 표를 **스크립트가 직접 파싱**한다(`| \`#xxxxxx\` | 이름 |` 행 정규식, 약 5줄). 팔레트 JSON을 따로 만들지 않는다 — 사본을 만들면 art-bible과 갈라진다. 표가 바뀌면 타일도 따라 바뀐다.

### 2.2 산출물 (`game/assets/generated/quarter/`)

| 파일 | 크기 | 내용 | 발 기준점 / 접지 |
|---|---|---|---|
| `ground_grass.png` | 96×32 (32×32 ×3) | 잔디 3종(베이스·하이라이트 점묘·마른풀) | 전면 접지 |
| `ground_dirt_auto.png` | 96×96 (3×3) | 흙길 오토타일 3×3(4방향 가장자리+모서리) | 전면 접지 |
| `water_auto.png` | 96×96 (3×3) | 물 3×3 + 가장자리 | 통행 불가 |
| `cliff.png` | 96×96 (3×3) | 절벽/벽 3×3 — **윗면·정면·바닥 그림자 띠** | 하단 1행이 접지 띠 |
| `tree.png` | 64×96 | 캐노피 + 줄기 | (32, 88) |
| `bush.png` | 32×32 | 수풀 | (16, 30) |
| `rock.png` | 32×32 | 바위 | (16, 30) |
| `fence.png` | 96×32 (3종) | 울타리 가로·세로·모서리 | (·, 30) |
| `house_a.png` | 96×96 | 집 A — 지붕 + 정면 벽 + 문 | 하단 1행(32px)이 접지 |
| `quarter_atlas.json` | – | 파일별 셀 좌표·발 기준점·접지 띠 높이·충돌 여부 | – |

`quarter_atlas.json`이 코드와 아트 사이의 유일한 계약이다 — 정식 애셋으로 교체할 때 PNG만 갈아끼우고 JSON은 그대로 둔다.

**오블리크 규칙(전 오브젝트 공통)**: 윗면은 세로로 0.42 눌러 그린다(단계 (a)의 `Tuning.FOOT_SHADOW_Y_SCALE`과 같은 각도 — 그림자와 지형의 시점각이 어긋나면 안 된다). 정면은 눌리지 않은 수직면. 정면 색은 윗면 색의 명도 65%. 외곽선은 `#141b1b`(art-bible §2, 순검정 금지).

**라이선스**: 자체 제작이므로 `docs/art/LICENSES.md` "프로젝트 신규 생성물"에 행 추가(sfxr 자체 제작 SFX와 동일 형식), 출처는 재생성 커맨드. 외부 팩 등급 대상 아님.

### 2.3 미해결 의존성 — 블로커

지시가 근거로 든 **`docs/art/brief-quarter-view-gpt-image.md`가 워크트리에 없다**(`docs/art/` 전체 확인). 위 표의 이름·크기는 내가 지시 본문에서 읽어 정한 것이라 정식 브리프와 어긋날 수 있다. 브리프를 받으면 표를 맞춘다 — 어긋난 채로 생성하면 "파일만 교체" 목표가 깨진다. **결정 Q8.**

---

## 3. 월드

### 3.1 단위 전환 ×2 — 안전하게 하는 법

핵심은 **손으로 고르지 않는 것**이다. 변환 스크립트(`tools/qv_scale2.py`, 1회용, 커밋 후 삭제 가능)가 규칙으로 훑고, 테스트가 결과를 증명한다.

대상(실측 개수):

| 파일 | 대상 | 개수 |
|---|---|---|
| `data/combat.json` | `*_px` 전부 (`roll.distance_px`, `movement.walk_speed_px`, `knockback.*_px`, `camera_shake.*.amplitude_px`) | 8 |
| `data/monsters.json` | `move_speed_px`/`dash_speed_px`/`aggro_range_px`/`melee_range_px`/`patrol_radius_px`/`leash_range_px`/`whistle_range_px`/`aoe_radius_px`/`attack_vfx_offset_px`/`on_death_split_spawn_radius_px` | 48 |
| `data/skills.json` | `hitbox.range_px`/`hitbox.width_px`/`knockback_px`/`self_effect.dash_px` | 44 |
| `data/world_objects.json` | `position` 19쌍 | 38 |
| `game/scenes/main/Main.tscn` | 노드 `position` | ~20 |
| `game/scripts/tuning.gd` | `TILE_SIZE_PROTOTYPE` 16→32, `ATTACK_LUNGE_PX`, `QUEST_ARROW_MARGIN_PX`, `ELITE_SPAWN_MIN_SEPARATION_PX`, `RANGED_DART_SPEED_PX`, `FOOT_SHADOW_RADIUS_PX` 6→12 | 6 |
| 액터 씬 7개 | `CollisionShape2D`/`Hurtbox`/`Hitbox` 모양 크기·오프셋, 스프라이트 오프셋 | ~28 |

**자동 변환하면 안 되는 것** (스크립트가 건드리지 않고, 테스트가 불변을 확인):
- `camera_shake.*.amplitude_px` — 화면 흔들림은 월드 거리가 아니라 **화면 픽셀**이다. 월드가 2배가 되고 zoom이 절반이 되면 화면상 흔들림은 그대로여야 하므로 **×2가 맞다**(월드 단위로 해석되어 zoom에서 ÷2 되므로). 단 `Tuning.SCREEN_SHAKE_LEVELS`(배율표)는 무차원이라 **불변**.
- `Tuning.FACING_AXIS_SWITCH_BIAS`, `*_SEC` 전부, 확률·비율·배율 — 무차원/시간. **불변**.
- `exp_curve.csv`, `items.json`, `drop_tables.json` 등 px이 없는 테이블 — **접근 금지**.

`scripts/systems/elite_spawner.gd`는 이미 `tile_pos * Tuning.TILE_SIZE_PROTOTYPE`으로 **타일 좌표**를 쓴다 — 상수 하나만 바뀌면 자동으로 따라온다. **스폰존 좌표 변환 불필요**(결정 Q10의 답). `scripts/ui/quest_tracker_calc.gd`의 "1타일=1m" 환산도 `TILE_SIZE_PROTOTYPE`을 나누므로 미터 표기가 그대로 유지된다.

카메라: `Main.tscn` `PlayerCamera.zoom` 2→1, `follow_offset` (0,−12)→(0,−24). `Tuning.CAMERA_ZOOM`은 아무도 안 읽는 죽은 상수라 **삭제**한다(2.0으로 남겨두면 다음 사람이 속는다).

### 3.2 세이브 마이그레이션

세이브에 들어있는 좌표는 **`player.position` x/y 한 쌍뿐**이다(`save_manager.gd:115`). 비석은 `last_waystone_id`(문자열), 나머지는 전부 좌표와 무관하다.

- `FORMAT_VERSION` 1 → 2.
- 마이그레이션: v1 페이로드를 읽으면 `player.position`만 **×2**하고 나머지는 그대로 통과. 순수 단위 전환이라 지형도 같이 2배가 되므로 ×2가 정확히 옳다 — **리셋할 이유가 없다**(이전 스펙 §7.2의 "리셋" 규칙을 이 근거로 갱신한다).
- 다만 (b)는 **없던 벽을 새로 만든다.** 옛 좌표 ×2 지점이 새 절벽/집 안일 수 있다. 안전장치: 로드 직후 플레이어 위치가 `Walls` 충돌과 겹치면 `GameState.get_respawn_position()`(마지막 비석)으로 스냅하고 로그를 남긴다. `save_manager.gd`에 약 12줄.
- v2를 v1로 되돌리는 경로는 만들지 않는다(YAGNI — 필요해지면 그때).

### 3.3 World.tscn · 벽 · 마을 배치

현재 `World.tscn`은 Ninja Adventure 아틀라스 좌표 ~75줄이 `sub_resource`로 박혀 있다. 이걸 32px 타일셋으로 손으로 다시 쓰면 .tscn이 더 커지고 diff가 읽히지 않는다.

→ **`world.gd`가 `quarter_atlas.json`을 읽어 TileSet을 코드로 조립한다.** `world.gd`는 이미 지면을 절차적으로 채우고 있어(`_fill_prototype_ground`) 구조가 맞고, `World.tscn`에서 ~85줄이 **삭제**된다(순 diff 감소).

층 구성(단계 (a)의 Y-sort 위에 얹는다):
```
Main (y_sort)
├─ World (z_index = -2)          지면·길·물 — 액터와 겹칠 일 없음
│  ├─ Ground (TileMapLayer)
│  └─ Water  (TileMapLayer)
├─ Walls (TileMapLayer)          ← Main 직계로 승격, y_sort_enabled = true
│                                  y_sort_origin = 셀 하단(접지선), StaticBody는 접지 띠만
├─ Props (Node2D, y_sort)        나무·집·바위·울타리 = Sprite2D + 발밑 StaticBody
├─ Player / 몬스터 / NPC …
└─ UiRoot (CanvasLayer)
```
- **충돌은 발밑 띠만**: 절벽/집의 정면 벽은 "이미 막힌 곳의 그림"이라 물리를 주지 않는다. `quarter_atlas.json`의 `collision_band_px`가 셀 하단 몇 px에 콜리전을 넣을지 정한다(파일럿 `world.gd:_block()`이 손으로 한 것을 데이터화).
- **플레이어 충돌 레이어**: 현재 `Player.collision_layer=2 / mask=1`, 몬스터는 `mask=0`(아무것도 안 부딪힘). 벽은 layer 1로 두면 플레이어만 막힌다. 몬스터도 막으려면 몬스터 `mask`를 1로 — **결정 Q9**(몬스터가 벽을 통과하던 기존 동작이 바뀌고 AI 추적이 벽에 걸린다. leash로 복귀하므로 안전하다고 보지만 game-designer 확인 대상).
- **하틀랜드 마을 입구 한 구역**을 실제 배치한다: 절벽으로 둘러싼 진입로 + 흙길 + 집 A 2채 + 나무 6~8그루 + 울타리 + 물가 한쪽. 배치는 `game/data/world_layout_hartland.json`(신규)에 타일 좌표로 두고 `world.gd`가 읽는다 — .tscn에 손으로 박지 않는다(CLAUDE.md "배치도 데이터 테이블 1곳" 원칙, `world_objects.json`과 같은 방식).

---

## 4. 액터

- **발밑 캡슐 충돌**: 몸통 `RectangleShape2D` 10×8 → `CapsuleShape2D`(가로 눕힘, 반지름 6·높이 20 ×2 단위 기준). 단계 (a)에서 미룬 이유(벽이 0개)가 (b)에서 해소된다.
- **스프라이트 2배**: `AnimatedSprite2D.scale = 2` + 오프셋 ×2. 16px 아트를 확대하는 임시 조치이며, 캐릭터:타일 비율은 1:1로 현재와 동일(§1).
- **히트박스·허트박스**: 크기·오프셋 ×2. 형상은 그대로(부채꼴 전환은 (c), 이전 스펙 §5.1).
- 몬스터 6종 씬 동일.

---

## 5. 검증

1. `--import` → 메인 씬 헤드리스 실행 SCRIPT ERROR 0
2. **GUT 537개 전부 통과** — 단위 전환이 순수 단위 전환이면 기존 테스트가 깨질 이유가 없다. 깨지면 그 값은 단위가 아니라 밸런스였다는 뜻이므로 **깨진 테스트가 곧 설계 검토 지점**이다.
3. **신규 `test_unit_scale_invariants.gd`** — "×2 일관성"을 비율 불변으로 검사한다. 절대값을 다시 적는 테스트는 변환 스크립트를 두 번 쓰는 것이라 의미가 없다:
   - `aggro_range_px / walk_speed_px` (종별) 불변
   - `melee_range_px / aggro_range_px` 불변
   - `roll.distance_px / walk_speed_px` 불변
   - `knockback.heavy_px / knockback.normal_px` 불변
   - `TILE_SIZE_PROTOTYPE`로 나눈 타일 단위 거리 불변
   - 무차원 값(`SCREEN_SHAKE_LEVELS`, `*_SEC`, 확률) 원본과 동일
   기준값은 단계 (a) 커밋 `ba544c1`의 값을 테스트에 상수로 박는다.
4. 기존 스모크 전체 회귀 — 베이스 대비 동일 결과. 알려진 예외: 하네스 게이트 9건, 플레이키 `SmokeHotbar`(별도 과제).
5. **신규 `SmokeQuarterViewB`** — 벽 충돌(플레이어를 절벽으로 밀어 통과 못 함 + 접지 띠 밖 정면 벽은 통과 가능), 집/나무 뒤로 걸어가면 가려짐, 32px 좌표계(타일 좌표 ↔ 월드 좌표 왕복), 세이브 v1→v2 마이그레이션(옛 좌표 ×2), 벽 안 스폰 시 비석 스냅.
6. **Xvfb 캡처** `docs/art/preview/quarter-view-b-village.png` — 마을 입구 구역. (a) 캡처와 달리 캡처 전용 줌을 쓰지 않는다(실제 게임 화면이 근거여야 한다).

---

## 6. PR 분할과 diff 규모

500줄 상한에 한 PR로는 안 들어간다. **2개로 나눈다.**

### PR (b1) — 단위 전환 ×2 (아트 없음, 화면 변화 없음)

| 파일 | 변경 | 줄 |
|---|---|---|
| `game/data/combat.json` / `monsters.json` / `skills.json` | px 값 ×2 (스크립트 생성) | ~100 |
| `game/data/world_objects.json` | position 19쌍 ×2 | ~38 |
| `game/scenes/main/Main.tscn` | 노드 position ×2, zoom 2→1, follow_offset ×2 | ~22 |
| `game/scripts/tuning.gd` | TILE_SIZE 16→32 외 5개 ×2, `CAMERA_ZOOM` 삭제 | ~8 |
| 액터 씬 7개 | 충돌·허트·히트박스 ×2, 스프라이트 scale 2 | ~28 |
| `game/scripts/core/save_manager.gd` | FORMAT_VERSION 2 + v1 위치 ×2 마이그레이션 | ~22 |
| `game/tests/unit/test_unit_scale_invariants.gd` (신규) | 비율 불변 | ~70 |
| `tools/qv_scale2.py` (신규, 1회용) | 변환 스크립트 | ~60 |
| **합계** | | **~348** |

완료 기준: 화면이 (a)와 **똑같이 보이고** GUT 537개가 그대로 통과. 보이는 변화가 있으면 단위 전환이 아니다.

### PR (b2) — 오블리크 타일셋 · 마을 · 벽 · 액터 캡슐

| 파일 | 변경 | 줄 |
|---|---|---|
| `tools/art/gen_quarter_tiles.py` (신규) | 생성기 | ~230 |
| `game/data/world_layout_hartland.json` (신규) | 마을 입구 배치(타일 좌표) | ~60 |
| `game/scripts/systems/world.gd` | atlas.json → TileSet 조립, 레이어/배치/충돌 띠 | +110 |
| `game/scenes/world/World.tscn` | 박힌 아틀라스 제거, 레이어 추가 | **−85 / +15** |
| `game/scenes/main/Main.tscn` | `Walls`·`Props` 레이어 | ~8 |
| 액터 씬 7개 | 캡슐 충돌 교체 | ~14 |
| `game/tests/smoke/SmokeQuarterViewB` (신규) | 벽·가림·좌표·마이그레이션 | ~120 |
| `game/tests/smoke/SmokeQuarterViewBCapture` (신규) | 캡처(헤드리스 SKIP 가드) | ~60 |
| `docs/art/LICENSES.md` / `asset-sources.md` | 자체 제작 등재 | ~6 |
| **합계** | | **~453** (생성 PNG·GDD 제외) |

생성 PNG는 바이너리라 줄 수에 안 들어가지만 **`game/assets/generated/`에 커밋**한다 — 재현 가능해도 빌드 의존성을 늘리지 않는 편이 낫다.

---

## 7. 결정 필요 항목 (D-205+)

| ID | 항목 | 권고 | 비고 |
|---|---|---|---|
| Q7 | 단위 전환 방식 | **×2 단위 전환**(PR b1) | 대안은 `TileMapLayer.scale=0.5`로 데이터 무변경 — 영구 단위 왜곡이 대가(§1.1) |
| Q8 | `brief-quarter-view-gpt-image.md` 부재 | **브리프 받고 §2.2 표 확정 후 생성기 착수** | 이름/크기가 어긋나면 "파일만 교체" 목표가 깨진다. **b2 블로커** |
| Q9 | 몬스터도 벽에 막을 것인가 | **막는다**(`collision_mask` 0→1) | 기존엔 벽을 통과했다. AI가 벽에 걸려도 leash로 복귀. game-designer 확인 |
| Q10 | 스폰존 좌표 변환 | **불필요** | `elite_spawner.gd`가 이미 타일 좌표 × `TILE_SIZE_PROTOTYPE` |
| Q11 | 세이브 마이그레이션 | **v1→v2, 위치 ×2 + 벽 겹침 시 비석 스냅** | 리셋 불필요(좌표가 세이브에 한 쌍뿐) |
| Q12 | 청크 크기 | **`CHUNK_TILES=64` 불변** | 타일 수 기준이라 px 규격과 무관. 다만 64타일 = 2048wu로 커져 메모리는 4배 — 스트리밍 미구현이라 (b)에서는 영향 없음 |
| Q13 | 캐릭터:타일 비율 2×3 전환 | **(c)로 미룸** | (b)에서 하면 16px 기사를 4배 확대한 그림으로 근접 사거리를 튜닝하게 된다(§1) |
| Q14 | 생성 PNG 커밋 여부 | **커밋** | 재현 가능해도 Pillow 빌드 의존을 런타임에 걸지 않는다 |

**game-designer 질문**: Q9, Q13. 그리고 §5-2에서 GUT가 깨지는 값이 나오면 그 값은 단위가 아니라 밸런스였다는 뜻이므로 개별 판단이 필요하다.
