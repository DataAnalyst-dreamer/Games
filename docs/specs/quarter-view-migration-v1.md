# 본편 쿼터뷰 이관 기술 스펙 v1 (게이트 5, D-196 후보)

- 작성: gameplay-programmer, 2026-09-20. 브랜치 `stage/m5-0-quarter-view`.
- 근거: 사용자 결정 "이제 탑뷰에서 쿼터뷰로 시점을 이동했으면 해"(2026-09-20), D-143 파일럿, D-139/D-140/D-133 아트 규격.
- 상태: **계획 전용. 구현은 디렉터의 결정(§8) 확정 후.** 이 문서는 코드를 바꾸지 않는다.

---

## 1. 파일럿이 실제로 구현한 "쿼터뷰"의 정의

`prototypes/quarter-view-lab/`의 코드를 읽은 결과, 파일럿은 **등각(isometric) 투영이 아니다.**
2:1 다이아몬드 TileMap도, 좌표 변환도, 세로 감쇠도 존재하지 않는다.

파일럿이 쿼터뷰로 보이는 이유는 **네 가지 연출 규칙**뿐이다:

| # | 규칙 | 파일럿 구현 위치 |
|---|---|---|
| 1 | **비스듬히 그려진 배경 그림 한 장** — 시점감은 전적으로 그림이 만든다 | `world.gd:_ready()` (village-gate.png, 1672×941을 FHD로 스케일) |
| 2 | **발밑 타원 그림자** — 바닥 평면을 암시 | `actor.gd:_draw()` `draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.42))` + `draw_circle(ZERO, 24)` |
| 3 | **Y-sort 가림** — 액터와 전경 오브젝트가 같은 Y-sort 노드 아래에서 global Y로 정렬 | `main.gd` `actors.y_sort_enabled = true`, `world.gd:add_foreground()`가 나무 다각형을 같은 노드에 넣음 |
| 4 | **발밑 충돌** — 벽/건물의 "바닥 접지선"만 수동 다각형으로 막음 (그림의 높이 부분은 통과 가능) | `world.gd:_block()` × 7, 손으로 측정한 `CollisionPolygon2D` |

시뮬레이션 자체는 **완전히 등방(isotropic) 2D 탑다운**이다.

### 1.1 파일럿 ↔ 본편 차이표

| 항목 | 파일럿 (`prototypes/quarter-view-lab/`) | 본편 (`game/`) 현재 | 이관 시 |
|---|---|---|---|
| 투영 | 비스듬한 고정 2D (LTTP식 3/4). 등각 아님 | 탑다운 2D | **동일 좌표계 유지** (좌표 변환 없음) |
| 세로 감쇠 | **없음 (1.0)**. `move_body(delta, input * 230.0)` 그대로 | 없음 (1.0) | §8 결정 1 — 기본 제안 **1.0 유지** |
| 이동 속도 | 230 px/s (FHD·1672px 배경 기준) | 80 px/s (`combat.json movement.walk_speed_px`, 16px 타일 기준) | 화면 배율이 달라 직접 이식 불가. §8 결정 5 |
| 방향 | 입력·조준 8방향, **아트는 4방향 + 좌우 반전** | 입력 8방향, 아트 4방향(`Player.DIR_NAMES`) | **동일. 변경 없음** |
| 발 원점 | 노드 원점 = 발. 스프라이트는 `position.y = -24`(4배 확대 16px) | 노드 원점 ≈ 발. 스프라이트 `position.y = -4` (16px art) | 16px 아트에서 4px 오차 — §4.1 |
| 몸통 충돌 | `CircleShape2D` r=14, 원점(발) | `RectangleShape2D` 10×8, 원점 중심(-4..+4) | 이미 발밑 풋프린트. **변경 없음** |
| 허트박스 | 코드 `hurt_center() = pos + (0,-20)` | `Hurtbox` Area2D, 10×8 @ (0,-4) | 변경 없음 |
| 히트박스 | 코드 스윕 세그먼트(`blade_inner` 12 → `blade_outer` 74, 110° 부채꼴) | `Hitbox` Area2D **CircleShape2D r=8**, facing 방향으로 이동 | 부채꼴 아님. §5 |
| Y-sort | `Actors` 노드에 `y_sort_enabled = true` | **없음.** 액터가 `Main`의 직계 자식, 트리 순서로 그려짐 | **핵심 이관 항목** |
| 그림자 | 타원 (y 0.42배) | **없음** | 추가 |
| 벽 충돌 | 손측정 `CollisionPolygon2D` 7개 | **없음** (World는 `Ground` TileMapLayer 1장, StaticBody 0개) | 단계 (b) |
| 넉백 | `move_and_collide` 기반 등속, 벽 인식 | `HitFeel._apply_knockback()`이 **`global_position`을 Tween** — 벽 무시 | 감쇠 적용 지점이 다름(§4.2) |
| 카메라 | 고정 `Camera2D` (스크롤 없음) | PhantomCamera2D, follow, zoom 2.0 | 유지 + 오프셋 (§6) |
| 타일 | 없음 (배경 그림 1장) | 16px TileMapLayer, 코드 생성 풀밭 | §3.2 |
| 세이브/퀘스트 | 없음 | `save_manager.gd` v1, `world_objects.json` 19항목 | §7 |

### 1.2 이관의 성질 — 중요

**"탑뷰 → 쿼터뷰"는 좌표계 변경이 아니라 렌더링 규칙 + 아트 방향 변경이다.**
사용자가 "조작과 공간감은 너무 좋다"고 평가한 대상에는 세로 감쇠도, 등각 격자도 들어있지 않았다.
따라서 이관의 90%는 **Y-sort · 발밑 그림자 · 비스듬한 아트**이고, 좌표/데이터/세이브는 건드릴 이유가 없다.
등각 격자를 채택하면 반대로 `world_objects.json` 19좌표, 세이브, 퀘스트 트리거, 청크 규격이 전부 재작업 대상이 된다 — 이 비용은 §8 결정 1에 명시한다.

---

## 2. 권고안 요약 (디렉터 판단용)

| 결정 | 권고 | 이유 |
|---|---|---|
| 등각 vs 비스듬 2D | **비스듬 고정 2D** | 사용자가 승인한 파일럿이 이것. 좌표/세이브/데이터 이관 비용 0 |
| 세로 감쇠 | **1.0 (감쇠 없음)** | 파일럿이 1.0이었고 그 조작감을 사용자가 승인. 감쇠는 아트가 비스듬해진 뒤 체감으로 판단 |
| 타일 규격 | 단계 (a) 16px 유지 → 단계 (b)부터 32px | GDD 9장이 32px 확정이나, (a)에서 바꾸면 모든 좌표·속도가 동시에 흔들려 원인 분리가 안 됨 |
| 4/8방향 | **4방향 유지** | 핀 파이프라인(D-133/D-140)이 4방향 + 좌우 반전. 8방향은 아트 2배 |
| 파일럿 수치 이식 | **이식 안 함** | 배율계가 다름. `combat.json`/`tuning.gd`가 정본 |

---

## 3. 렌더 / 월드

### 3.1 Y-sort 층 구성

현재 `Main.tscn`은 `World`(Node2D) + 액터들이 **전부 Main의 직계 자식**이고 Y-sort가 어디에도 없다.
가장 작은 변경으로 전체 가림을 얻는 구성:

```
Main (Node2D)            y_sort_enabled = true      ← 추가
├─ World (Node2D)        z_index = -2               ← 추가 (지면은 항상 최하단)
│  └─ Ground (TileMapLayer)
│  └─ Walls (TileMapLayer)    ... 단계 (b)에서 추가, y_sort_enabled = true, Main 직계로 승격
├─ Player / 몬스터 / NPC / Waystone / QuestObject / ItemDrop   ← 자동으로 global Y 정렬
└─ UiRoot (CanvasLayer)  ← 영향 없음
```

- Godot 4의 Y-sort는 **y_sort_enabled 노드의 직계 자식**을 global Y로 정렬한다. `World`를 그 아래 두면 서브트리 전체가 `World.position.y = 0` 한 점으로 정렬되어 y<0인 액터가 지면 뒤로 숨는다 → `World.z_index = -2`로 해결(z_index가 Y-sort보다 우선). `-1`은 "지면 위·액터 아래" 층으로 비워 둔다 — `RollGhost.spawn()`이 구르기 잔상을 Main의 자식으로 `z_index = -1`에 스폰하기 때문이다(World를 `-1`로 두면 잔상이 지면과 같은 층에서 Y로 경쟁해 플레이어가 y<0일 때만 사라진다).
- `LootSpawner`는 드롭을 `tree.current_scene`(= Main)에 추가하므로 자동 정렬된다.
- `DamageNumber.tscn`은 `z_index = 100` — 그대로 항상 위.
- `SkillVfx` `z_index = 5`, `RollGhost` `z_index = sprite.z_index - 1` — Y-sort 계층 안에서 상대 z가 유지되므로 그대로 둔다.
- 단계 (b)의 벽/건물 타일은 **`Walls` TileMapLayer를 `Main` 직계 자식으로** 올리고 `y_sort_enabled = true` + `y_sort_origin`을 타일별 발밑으로 지정해야 액터와 섞여 정렬된다. World 아래 두면 통째로 한 덩어리로 정렬된다.

### 3.2 타일 규격

| 단계 | 타일 | 근거 |
|---|---|---|
| (a) | **16px 유지** | 좌표·속도·`world_objects.json`·세이브 전부 그대로. 시점 규칙만 격리 검증 |
| (b) | 32px placeholder (GDD 9장, D-139 FHD와 정합) | 전환 시 `Tuning.TILE_SIZE_PROTOTYPE` 16→32, `walk_speed_px` 80→160, `world_objects.json` 좌표 ×2, `roll.distance_px`·`knockback.*_px`·몬스터 `*_px` 전부 ×2 — **일괄 스케일 1회**, §7.2의 변환 규칙과 동일 |
| (c) | 32px 원작 | 아트 파이프라인 |

`Tuning.CHUNK_TILES = 64`는 타일 수 기준이라 px 규격과 무관 — 변경 없음.

### 3.3 벽 / 건물의 정면 높이 표현

비스듬 2D에서 벽은 **"윗면(바닥 평면) + 정면(카메라를 향한 수직면)"** 두 부분으로 그린다.

- **충돌은 윗면의 아래 가장자리(접지선)에만** 건다 — 파일럿 `world.gd:_block()`이 손으로 한 것과 같은 규칙. 정면 벽은 통과 불가 영역이 아니라 "이미 막힌 곳의 그림"이다.
- **Y-sort 원점은 접지선** — `TileSet`의 `y_sort_origin`을 타일 셀 하단으로 지정하면 플레이어가 벽 앞/뒤에 있을 때 자동으로 가려진다.
- 높이 h인 오브젝트는 `h / 32` 만큼 정면 타일을 세로로 쌓고, 접지 타일에만 물리를 준다.

### 3.4 Placeholder 타일셋 생성기 — `tools/art/gen_quarter_tiles.py` (단계 (b))

Pillow로 생성하는 **기초 도형 전용** 타일셋. 사용자가 "기초 도형 애셋 상태에서 다시 진행해도 돼"라고 허용한 범위.

- 출력: `game/assets/generated/quarter_placeholder_32.png` + `.json`(아틀라스 좌표 맵)
- 범위(이것만):
  1. 지면 4종 (풀/흙/돌/물) 32×32 단색 + 2px 명도 노이즈
  2. 지면 경계 전이 타일 없음 — placeholder는 경계를 그리지 않는다
  3. 벽 블록: 윗면 32×32 + 정면 32×32(같은 색 65% 명도) 2장 세트, 3색
  4. 나무/기둥 오브젝트: 32×64, 하단 8px가 접지 폭
- 생성 규칙은 결정론적(고정 seed). 외부 애셋이 아니므로 `asset-sources.md` 등급/`LICENSES.md` 기록 대상이 아니다 — 대신 스크립트가 출력 PNG 옆에 `_generated.txt`(생성 커맨드·seed)를 남긴다.
- **범위 밖**: autotile/terrain 비트마스크, 애니메이션 타일, 조명, 지역별 팔레트.

---

## 4. 액터

### 4.1 발밑 원점(pivot) · 충돌 형상

현재 본편은 이미 거의 발밑 기준이다:

| 노드 | 현재 | 판정 |
|---|---|---|
| `CollisionShape2D` (몸통) | Rect 10×8, 원점 중심 → y −4..+4 | **이미 발밑 풋프린트. 변경 불필요** |
| `AnimatedSprite2D` | `position = (0, -4)`, 16×16 → y −12..+4 | 스프라이트 하단이 원점보다 4px 아래 |
| `Hurtbox` / `Hitbox` | @ (0, −4) | 몸통 중앙. 변경 불필요 |

**단계 (a)에서 pivot을 옮기지 않는다.** 16px 아트에서 4px 어긋남은 두 액터가 4px 이내로 겹칠 때만 정렬이 뒤집히고, 그때는 스프라이트가 이미 서로를 덮고 있어 육안 차이가 없다.
`ponytail:` 4px Y-sort 오차 — 64×96 핀(발 기준점 (48,112), D-144)이 들어오는 단계 (c)에서 pivot이 저절로 정확해진다. 그 전에 옮기면 허트박스·히트박스·그림자·HP바 오프셋 7종을 같이 옮겨야 하고, 전투 사거리 체감이 함께 변해 시점 변경의 효과를 분리 검증할 수 없다.

충돌 형상을 타원/캡슐로 바꾸는 것도 단계 (c)로 미룬다 — 현재 본편에는 **StaticBody 벽이 0개**라(§1.1) 몸통 충돌이 어떤 모양이든 아무것도 부딪히지 않는다. 벽이 생기는 단계 (b)에 `CapsuleShape2D`(가로 12 × 세로 7, 눕힘)로 교체한다.

### 4.2 세로 감쇠 — 적용 지점 (결정 1이 <1.0일 때만 구현)

`Tuning.QUARTER_VIEW_Y_SCALE`(단일 임시 상수) 하나를 두고, **네 군데**에서만 곱한다.
권고값 1.0에서는 전부 무연산이므로 **단계 (a)에서는 코드를 아예 쓰지 않는다.**

| # | 지점 | 파일:라인 | 덮는 범위 |
|---|---|---|---|
| 1 | `Player.move_iso()` 래퍼 (velocity.y 임시 축소 후 `move_and_slide()`, 원복) | `scripts/player/player.gd` 신규 + `states/{move,idle,roll,guard,hurt,skill,attack}.gd`의 `move_and_slide()` 8곳 치환 | 걷기·구르기·가드이동·피격이동·스킬 대시·공격 런지 |
| 2 | `MonsterBase` `move_and_slide()` 직전 | `scripts/entities/monster_base.gd:278` | 몬스터 순찰·추격·돌진 전부 (모든 AI가 이 한 줄을 통과) |
| 3 | `HitFeel._apply_knockback()`의 `direction` | `scripts/systems/hit_feel.gd:146` | **넉백은 velocity가 아니라 `global_position` Tween이라 #1·#2가 못 잡는다** |
| 4 | `Projectile` | `scripts/systems/projectile.gd:43` | 원거리 다트 |

**추적 벡터는 감쇠하지 않는다.** 몬스터 AI(`monster_base.gd:380` 등)는 `to_player.normalized() * speed`로 방향을 잡고 #2에서 감쇠되므로, 여기서 또 곱하면 이중 적용된다.

### 4.3 그림자

파일럿 규칙(`Vector2(1, 0.42)` 타원)을 본편 스케일로 옮긴다.

- `CharacterBody2D._draw()`는 **자식(스프라이트)보다 먼저** 그려지므로 새 노드 없이 발밑 그림자를 깔 수 있다.
- `scripts/systems/foot_shadow.gd` — static 함수 하나(`draw(canvas: CanvasItem, radius: float)`), `Player._draw()`와 `MonsterBase._draw()`에서 호출.
- 반지름은 16px 아트 기준 6px(파일럿 24px는 4배 확대 기준이므로 ÷4). 세로 배율 0.42는 파일럿 그대로.
- `Settings`에 토글 없음 — 접근성 대상이 아닌 순수 연출.

### 4.4 방향 수: 4방향 유지

| 근거 | 내용 |
|---|---|
| D-133 / `character-fin-spec.md` §2 | 4방향 실루엣 차별화가 핵심 요구. left는 right의 좌우 반전 → **실제 원화는 3방향** |
| `motion-design-reference.md` 1장 | "8방향 대신 4방향 + 반전"이 명시된 절약 전략 |
| 파일럿 | 입력/조준은 8방향, 표시는 4방향 — 사용자가 승인한 조작감이 이 조합 |
| D-140 (64×96) | 8방향은 이동 8f × 공격 6f × 8방향 = 112프레임, 4방향 대비 2배 |

→ **입력 8방향 · 표시 4방향 유지. 코드 변경 없음.** `Player.set_facing()`의 축 전환 완충(D-121/D-128)도 그대로 유효하다.

---

## 5. 전투

### 5.1 히트박스 형상

본편 `Hitbox`는 **`CircleShape2D` r=8을 facing 방향으로 이동시키는 방식**(`Player.tscn`, `attack.gd`)이고, 파일럿의 110° 부채꼴 스윕과는 다른 모델이다.

- 감쇠 1.0(권고) → **원은 원으로 보인다. 변경 없음.**
- 감쇠 <1.0 → 세로 방향 공격의 사거리가 시각적으로만 줄어 보인다. 이때는 히트박스 자체를 감쇠하지 말고, **위/아래 공격 시 히트박스 오프셋만 `* Y_SCALE`** 하여 "발 아래 도달 거리"를 화면과 맞춘다. 부채꼴 도입은 이번 범위 밖(별도 스펙).
- 스킬 히트박스(`skill.gd:153` 주변)도 같은 규칙.

### 5.2 몬스터 AI 추적 벡터

`monster_base.gd`의 chase/patrol/dash는 전부 정규화 방향 × 속도 → `move_and_slide()` 한 줄을 통과한다(§4.2 #2). **AI 코드는 한 줄도 바꾸지 않는다.**
단, `melee_range_px`/`aggro_px`는 **감쇠하지 않은 월드 거리**로 계속 판정한다 — 화면상 거리로 판정하면 위아래에서 오는 적만 늦게 반응해 텔레그래프 0.5초 규칙(GDD 4.2)이 깨진다.

### 5.3 원거리 투사체

`Projectile`은 `CharacterBody2D` + `move_and_slide()`. §4.2 #4 한 곳. 다트 스프라이트 회전은 **감쇠 전 방향각**을 쓴다(감쇠 후 각도로 회전하면 화살이 지면에 누워 보인다).

---

## 6. 카메라

PhantomCamera2D를 **그대로 유지**한다. `Main.tscn`의 `PlayerCamera` 노드 속성만 조정:

| 속성 | 현재 | 제안 | 이유 |
|---|---|---|---|
| `follow_mode` | 2 (SIMPLE) | **3 (FRAMED)** | 데드존 확보 |
| `dead_zone_width/height` | – | 0.22 / 0.18 | 세로 데드존을 가로보다 좁게 — 비스듬 시점은 세로 이동이 정보량이 큼 |
| `follow_offset` | (0,0) | **(0, −12)** | 플레이어를 화면 중앙보다 아래에 두어 "앞쪽(먼 곳)"을 더 보여준다 |
| `zoom` | (2,2) | 유지 (단계 (b) 32px 전환 시 (1,1) 재검토) | – |
| `snap_to_pixel` | true | 유지 | 도트 흔들림 방지 |

`CameraShake` + `NoiseEmitter` 경로와 `Tuning.SCREEN_SHAKE_LEVELS` 접근성 배율은 변경 없음.

---

## 7. 레벨 데이터 · 세이브 호환

### 7.1 권고안(비스듬 2D, 감쇠 1.0, 16px 유지)에서의 결론

**`world_objects.json` 변환 불필요. 세이브 마이그레이션 불필요. `FORMAT_VERSION` 유지.**

- `world_objects.json`의 19개 항목 좌표는 월드 px 그대로 유효하다 — 좌표계가 바뀌지 않기 때문.
- `quest_layout_spawner.gd`, `QuestTrigger`/`QuestObject`/`QuestNpc`, `Waystone`(워프 비석) 전부 무변경. 단, 이들이 Main 직계 자식으로 스폰되는지 확인해야 Y-sort를 탄다(`HartlandQuestLayer`는 Node2D이므로 **그 아래 스폰물은 한 덩어리로 정렬된다** → `HartlandQuestLayer.y_sort_enabled = true` + `Main`도 true여야 2단으로 정렬된다. Godot Y-sort는 중첩 시 하위 y_sort 노드가 부모 정렬에 참여하므로 이 한 줄로 해결).
- `save_manager.gd:240`의 플레이어 위치 복원은 그대로 동작한다.

### 7.2 좌표 변환이 필요해지는 경우의 규칙 (결정 1/3이 바뀔 때)

| 변경 | 변환 | 자동화 |
|---|---|---|
| 타일 16→32 | 모든 px 좌표 `× 2` | 가능. `world_objects.json` + `Main.tscn` 노드 position 일괄 스크립트 |
| 세로 감쇠 s 도입 | **변환 불필요** — 감쇠는 속도에만 걸고 좌표계는 그대로 | – |
| 등각 격자 채택 | `iso = Vector2((x−y), (x+y)/2)` | **불가.** 19개 좌표 수작업 재배치 + 세이브 v2 + 퀘스트 트리거 반경 재산정. 이 비용이 결정 1의 핵심 |

세이브 규칙: 좌표계가 바뀌는 변경을 채택하면 `FORMAT_VERSION` 1→2로 올리고, **위치만 리셋**(마지막 워프 비석 = `GameState.last_waystone`으로 스폰)한다. 인벤토리·퀘스트·레벨은 좌표와 무관하므로 보존한다. 좌표 자체를 변환하지 않는 이유: 구 세이브의 위치가 신 지형에서 벽 안일 수 있어 변환이 안전하지 않다.

---

## 8. 디렉터 결정 필요 항목 (D-196+)

| ID | 항목 | 선택지 | 권고 | 비용 차이 |
|---|---|---|---|---|
| Q1 | 투영 방식 | (A) 비스듬 고정 2D + Y-sort / (B) 등각 2:1 다이아몬드 | **A** | B는 좌표 19개 재배치 + 세이브 v2 + 퀘스트 반경 재산정 + 청크 규격 재정의 |
| Q2 | 세로 감쇠 비율 | 1.0 / 0.75 / 0.6 | **1.0** | <1.0이면 §4.2의 4개 지점 구현(≈40줄) + 히트박스 오프셋 보정 |
| Q3 | 타일 규격 전환 시점 | (a)에서 즉시 32px / (b)부터 32px | **(b)부터** | 즉시 전환 시 좌표·속도·거리 상수 전부 동시 이동 → 회귀 원인 분리 불가 |
| Q4 | 방향 수 | 4방향 유지 / 8방향 | **4방향 유지** | 8방향은 핀 원화 2배, D-133/D-140 파이프라인 재설계 |
| Q5 | 파일럿 수치 이식 | 230 px/s·50/85/140ms를 본편에 반영 / 반영 안 함 | **반영 안 함** | 파일럿은 FHD·1672px 배경 기준, 본편은 16px 타일·640×360 기준. 배율계가 달라 숫자 자체가 의미를 잃는다. 32px 전환(Q3) 후 `combat.json`에서 재튜닝 |
| Q6 | 그림자 반지름 | 액터별 고정 / 스프라이트 폭 비례 | 고정 6px (16px 아트) | 사소. game-designer 확인 불필요 |

**Q5 보충(게임 디자이너 몫 질문)**: 파일럿의 공격 타이밍(준비 50 / 타격 85 / 회수 140ms, 총 275ms)은 본편 `combat.json combo.hits`·`Tuning.ATTACK_*`와 모델이 다르다(파일럿은 단타, 본편은 3타 콤보 + 스태미나). 본편 콤보 타이밍을 파일럿 체감에 맞추려면 game-designer가 `combat.json`에서 3타 전체 예산을 다시 짜야 한다 — 시점 이관과 분리된 별도 과제로 제안한다.

---

## 9. 단계 분할

### 단계 (a) — 엔진 규칙만, 현재 애셋 그대로 [이번 PR 대상]

현재 16px Ninja Adventure 애셋 그대로 **Y-sort · 발밑 그림자 · 카메라 오프셋**만 적용한다. 즉시 체감 가능하고, 좌표/데이터/세이브를 건드리지 않아 되돌리기도 쉽다.

| 파일 | 변경 | 예상 줄수 |
|---|---|---|
| `game/scenes/main/Main.tscn` | `Main` 노드에 `y_sort_enabled = true`; `World` 인스턴스에 `z_index = -1`; `HartlandQuestLayer`에 `y_sort_enabled = true`; `PlayerCamera` 속성 4줄(§6) | +8 |
| `game/scripts/systems/foot_shadow.gd` (신규) | static `draw()` 1함수 + 주석 | +25 |
| `game/scripts/player/player.gd` | `_draw()` 추가(FootShadow 호출) + `_ready()`에 `queue_redraw()` | +6 |
| `game/scripts/entities/monster_base.gd` | 동일 | +6 |
| `game/scripts/tuning.gd` | `FOOT_SHADOW_RADIUS_PX`, `FOOT_SHADOW_Y_SCALE`, (Q2가 <1.0이면) `QUARTER_VIEW_Y_SCALE` + 주석 | +14 |
| `game/tests/unit/test_foot_shadow.gd` (신규) | 타원 반경/배율 계산 GUT 검사 | +20 |
| `game/tests/smoke/SmokeQuarterViewYSort.tscn` + `.gd` (신규) | 플레이어를 몬스터 위/아래로 이동시켜 `get_index()`가 아닌 **실제 draw 순서**를 Y-sort 규칙으로 검증 | +45 |
| `docs/specs/quarter-view-migration-v1.md` | 이 문서 | +· |
| `docs/brd/04-decisions.md` + GDD 9장·시점 절 | D-196~D-201 기록 | +20 |

**총 ≈ 145줄 — 500줄 상한의 30%.** Q2가 <1.0으로 결정되면 §4.2의 4지점(+40줄, `move_and_slide()` 8곳 치환 포함)이 더해져 ≈185줄. 그래도 상한 내.

상한 준수 방안: (b)의 타일셋 생성기(≈200줄)와 (c)의 아트 교체는 **별도 PR**로 분리한다. (a)는 "새 애셋 0개, 새 데이터 0개, 좌표 변경 0개"를 스스로의 경계로 삼는다.

**검증**
1. `--import` 후 `--headless --check-only` 전 스크립트 파싱
2. GUT 전체 (회귀: 기존 스모크 30여 개가 전부 통과해야 한다 — 좌표를 안 바꿨으므로 실패하면 Y-sort가 무언가를 가린 것)
3. `SmokeQuarterViewYSort`: 플레이어 y > 몬스터 y → 플레이어가 앞. 반대도.
4. 실제 씬 실행 + 캡처: 플레이어를 슬라임 위/아래로 지나가게 해 가림과 그림자 확인
5. 세이브/로드 스모크 통과(좌표 무변경 증거)

### 단계 (b) — placeholder 오블리크 타일셋 + 오브젝트 높이

- `tools/art/gen_quarter_tiles.py`(§3.4), 32px 전환(§3.2), `Walls` TileMapLayer + `y_sort_origin`, 액터 충돌 캡슐 교체(§4.1), 벽 접지선 물리.
- 검증: 벽 뒤로 걸어들어가면 가려지고 앞으로 나오면 드러나는 캡처, 벽 충돌 스모크, 32px 전환 후 `world_objects.json` ×2 변환 결과가 퀘스트 트리거 스모크를 통과하는지.

### 단계 (c) — 원작 타일 · 핀 64×96

- 핀 4방향 비스듬 원화(발 기준점 (48,112)), pivot·충돌 타원·허트박스 정밀화, 히트박스 부채꼴 검토.
- pixel-artist 선행 의존. 이 단계에서만 §4.1의 pivot 보정을 한다.

---

## 10. pixel-artist 에셋 요청 (단계 (c) 선행)

1. 핀 4방향 **비스듬 시점** 보행 8f / 공격 6f / 유휴 4f — 64×96 몸체, 96×128 캔버스, 발 기준점 (48,112)
2. 몬스터 6종(슬라임·뿔토끼·버섯돌이·고블린 정찰병 + 정예 2종)의 비스듬 시점 대응 — 현재 Ninja Adventure 대역은 탑다운
3. 32px 오블리크 지면 타일(풀/흙/돌/물) + 벽 윗면/정면 세트 — (b)의 생성 placeholder를 대체
4. 발밑 그림자 스프라이트(선택) — 현재는 코드 렌더 타원

## 11. game-designer 질문

- Q5(파일럿 공격 타이밍 이식) — §8 보충 참고.
- 32px 전환 시 `combat.json`의 px 단위 값(walk_speed 80, roll.distance 48, knockback 8/20, 몬스터 `*_px` 전종) 일괄 ×2가 밸런스적으로 타당한지, 아니면 체감 재튜닝이 필요한지.
- 세로 감쇠를 도입할 경우 몬스터 `aggro_px`/`melee_range_px`를 **월드 거리로 유지**하는 §5.2 규칙이 텔레그래프 0.5초 규칙과 충돌하지 않는지 확인.
