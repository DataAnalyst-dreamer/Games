# 등각(아이소메트릭) 애셋 — GPT 이미지 생성 프롬프트 브리프 (2026-09-21 개정)

본편 **등각(2:1 다이메트릭)** 이관(D-219)에 필요한 애셋을 ChatGPT 이미지 생성(GPT Image)으로 만들기 위한 프롬프트 모음.

> **2026-09-21 개정(D-219~D-226):** 비스듬 고정 2D(D-199)는 폐기됐다. 목표는 라그나로크·디아블로 계열 **진짜 등각**이다. 스타일 블록·크기 표·타일 프롬프트를 전부 등각 기준으로 바꿨다. 규격 정본은 `game/assets/iso/iso_atlas.json` 이고, `tools/art/gen_iso_tiles.py` 가 같은 이름·같은 크기로 기초 도형 placeholder 를 이미 깔아 뒀다 — 정식 애셋은 **같은 경로에 PNG 만 덮어쓰면** 코드 변경 없이 교체된다.
규격 근거: `docs/art/art-bible.md`(32×32 타일, 팔레트 32색, 외곽선·명암 규칙), `docs/art/fin-64-production-spec.md`(핀 64×96, 캔버스 96×128, 발 기준점 (48,112)),
`docs/specs/isometric-migration-v1.md`(D-219~D-226: 2:1 다이메트릭, 64×32 마름모 격자, 8방향, 고도 레이어).
파이프라인 규칙: `docs/art/ai-sprite-pipeline.md`, 기록 규칙: D-138.

## 0. 먼저 알아둘 것

- **등각의 정체는 "45도 돌아간 격자"다.** 지면 한 칸은 화면에서 **64×32 마름모**이고, 모든 수직 물체는 **남서면과 남동면 두 면을 같은 넓이로** 보여준다. 정면 한 면만 그리면(비스듬 2D) 탑뷰로 읽힌다 — 실제로 그렇게 만들었다가 사용자가 "이건 쿼터뷰라기보다 탑뷰 아니야?"라고 지적해 폐기했다. 원근 수렴 없음(직교). 빛은 좌상단이라 남서면이 밝고 남동면이 어둡다.
- **GPT 이미지는 정확한 픽셀 격자를 못 지킨다.** 그래서 큰 캔버스(1024×1024 또는 1536×1024)에 "pixel art 느낌"으로 생성한 뒤, 우리가 **최근접 축소 + 팔레트 양자화**로 규격에 맞춘다(§4). 프롬프트에 "각 도트를 8×8 화면 픽셀로" 같은 지시를 넣어도 대략만 맞는다 — 기대하지 말 것.
- **한 프롬프트에 한 애셋(또는 한 세트)만.** 여러 종류를 한 장에 넣으면 크기·시점이 흔들린다.
- **투명 배경**: 이미지 생성 옵션에서 배경 투명(PNG)을 켠다. 안 되면 프롬프트의 `solid magenta background (#FF00FF)`를 쓰고 후처리에서 뺀다(`--bg-color ff00ff`).
- **저작권 규칙**: 프롬프트에 실존 게임·캐릭터·회사 이름을 넣지 않는다(D-138, D-167). 생성물은 `docs/art/LICENSES.md`에 툴·플랜·생성일·프롬프트 원문·상업 이용 조건을 기록해야 `game/assets/`에 넣을 수 있다(§5 템플릿).
- **캐릭터 애니메이션은 GPT 이미지가 약하다.** 4방향 걷기·공격 시트는 PixelLab 파이프라인(`brief-fin-pixellab.md`)이 우선이고, GPT 이미지는 **정지 시안·방향별 정지 포즈·환경 오브젝트**에 쓴다. 이 브리프의 캐릭터 프롬프트는 그 용도다.

## 1. 공통 스타일 블록 — 모든 프롬프트 맨 앞에 그대로 붙인다

```
STYLE: 16-bit style pixel art for a cozy medieval fantasy island RPG. TRUE ISOMETRIC view: 2:1 dimetric projection on a 45-degree diamond grid, exactly like classic isometric RPGs. One ground tile is a 64x32 diamond. Every upright object is a box rotated 45 degrees so that TWO faces are visible with EQUAL width - the south-west face and the south-east face - plus its top surface as a diamond. Orthographic, NO perspective convergence, NO vanishing point. Light comes from the top-left, so the south-west face is lighter and the south-east face is darker. Crisp hard-edged pixels, NO anti-aliasing, NO blur, NO gradients, NO glow. Flat shading with exactly 3 tones per surface (base, one shadow, one highlight). Limited warm palette, roughly 32 colors: ink outline #141b1b (never pure black), grass #74a334 / #adbc3a / #5f7160, dirt path #d2b37d / #965340, wood #a3754e / #bd7959 / #c69469 / #61372e, roof orange #e66a3a / #ffad5d / #d78b4a, stone #b3957f / #8d977f / #8e7c73, water #79b8ce / #71ddee / #548789, straw #eecf9b, accent red #e0394c. Objects have a 1px dark outline; ground tiles have NO outline. Cute but sturdy proportions, warm and hand-made feel. No text, no watermark, no signature, no UI. Transparent background.
```

캐릭터·몬스터용 추가 블록(스타일 블록 뒤에 붙임):

```
CHARACTER RULES: 2.5-head-tall chibi proportions, big readable silhouette, small feet planted on the ground, feet at the exact bottom-center of the figure. Poses are for an ISOMETRIC 8-direction set (S, SW, W, NW, N, NE, E, SE) - the "south" pose faces the bottom of the screen, the "south-east" pose faces down-right along the diamond grid. Weapon and shield may extend outside the body box. One figure only, centered, filling about 60% of the canvas height.
```

타일용 추가 블록:

```
TILE RULES: Draw ONE single 2:1 diamond (twice as wide as tall) centred on a solid magenta (#FF00FF) background, with nothing outside the diamond. Seamless and tileable: NO outline on the diamond edge, no vignette, no lighting hotspot, uniform brightness across the whole tile so copies repeat without visible seams or a visible grid. Subtle texture only - a few grass tufts, pebbles or flowers well inside the diamond, never touching its edge.
```

## 2. 애셋 목록과 우선순위

> **파일명·크기 열은 코드와의 계약이다 (D-226).** 엔진은 `game/assets/iso/` 의 이 이름들과
> `iso_atlas.json`(발 기준점·마름모 footprint 칸 수·충돌 여부)만 알고 있다. `tools/art/gen_iso_tiles.py`
> 가 **같은 이름·같은 크기**로 기초 도형 placeholder 를 이미 깔아 뒀으므로, 정식 애셋은 **같은 경로에
> 덮어쓰기만 하면** 코드 변경 없이 교체된다. 크기가 다르면 발 기준점이 어긋나 Y-sort 가림이 깨진다.
> 아래 표는 `iso_atlas.json` 에서 생성했다 — 규격이 바뀌면 생성기를 돌리고 이 표를 다시 뽑는다.
> 격자 한 칸 = 64×32 마름모, 고도 한 단 = 32px.

| 우선 | 애셋 | 파일명 (`game/assets/iso/…`) | 논리 크기 | 생성 캔버스 | 용도 |
|---|---|---|---|---|---|
| 1 | 잔디 지면 A | `ground/tile_grass_a.png` | **64×32** (마름모 1칸) | 1024×1024 | 하트랜드 필드 바닥 |
| 1 | 잔디 지면 B(풀 뭉치) | `ground/tile_grass_b.png` | **64×32** (마름모 1칸) | 1024×1024 | 변형 |
| 1 | 잔디 지면 C(들꽃) | `ground/tile_grass_c.png` | **64×32** (마름모 1칸) | 1024×1024 | 변형 |
| 1 | 흙길 | `ground/tile_dirt.png` | **64×32** (마름모 1칸) | 1024×1024 | 마을·필드 길 |
| 1 | 물 | `ground/tile_water.png` | **64×32** (마름모 1칸) | 1024×1024 | 호수·강(통행 불가) |
| 1 | 절벽 블록 1단 | `walls/cliff_block_32.png` | **64×64** (발 기준점 (32,48) · 1칸) | 1024×1024 | 고도 표현의 핵심(D-224) |
| 1 | 절벽 블록 2단 | `walls/cliff_block_64.png` | **64×96** (발 기준점 (32,80) · 1칸) | 1024×1024 | 고도 2단 |
| 1 | 민들레 마을 집 A | `buildings/house_a.png` | **128×144** (발 기준점 (64,112) · 2칸) | 1024×1024 | 거점 |
| 1 | 대장간 | `buildings/smithy.png` | **128×148** (발 기준점 (64,116) · 2칸) | 1024×1024 | 상호작용 |
| 1 | 큰 참나무 | `props/tree_oak.png` | **64×118** (발 기준점 (32,102) · 1칸) | 1024×1024 | Y-sort 가림의 대표 |
| 1 | 수풀 | `props/bush.png` | **64×50** (발 기준점 (32,34) · 1칸) | 1024×1024 | 장식 |
| 1 | 바위 | `props/rock.png` | **39×37** (발 기준점 (19.5,21) · 1칸) | 1024×1024 | 장식·충돌 |
| 1 | 울타리(남서 방향) | `props/fence_sw.png` | **64×58** (발 기준점 (32,42) · 1칸) | 1024×1024 | 격자 한 축 |
| 1 | 울타리(남동 방향) | `props/fence_se.png` | **64×58** (발 기준점 (32,42) · 1칸) | 1024×1024 | 격자 다른 축 |
| 1 | 퀘스트 게시판 | `props/board.png` | **64×76** (발 기준점 (32,60) · 1칸) | 1024×1024 | 상호작용 |
| 1 | 우편함 | `props/mailbox.png` | **64×68** (발 기준점 (32,52) · 1칸) | 1024×1024 | 상호작용 |
| 1 | 워프 비석 | `props/waystone.png` | **64×90** (발 기준점 (32,74) · 1칸) | 1024×1024 | 상호작용 |
| 1 | 우물 | `props/well.png` | **64×80** (발 기준점 (32,64) · 1칸) | 1024×1024 | 마을 장식 |
| 1 | 짐 보따리 | `props/cargo_pile.png` | **64×62** (발 기준점 (32,46) · 1칸) | 1024×1024 | QuestObject 변형 |
| 1 | 표식 돌(기본) | `props/marker_stone.png` | **64×62** (발 기준점 (32,46) · 1칸) | 1024×1024 | QuestObject 기본 변형 |
| 2 | 핀 8방향 정지 포즈 | `actors/fin_idle_<dir>.png` | 64×96 (캔버스 96×128, 발 기준점 48,112) | 1024×1024 ×5 | D-223 8방향(S·SE·E·NE·N + 좌우 반전) |
| 2 | 몬스터 6종 8방향 정지 | `actors/<monster_id>_<dir>.png` | 32~64 | 1024×1024 | 시안·PixelLab 입력 |
| 3 | 메아리 굴 바닥·벽·발광 버섯 | `dungeon/echo_cave_*.png` | 64×32 세트 | 1024×1024 | 던전 |

## 3. 프롬프트

각 항목은 `[스타일 블록] + [추가 블록] + 아래 본문` 순서로 붙여 넣는다.

### 3.1 잔디 지면 (변형 3종)

```
[STYLE] [TILE RULES]
A single isometric ground tile: one 2:1 diamond (twice as wide as tall) of seamless meadow grass, centred on a solid magenta (#FF00FF) background. Nothing outside the diamond. The grass texture must be uniform so that copies tile without a visible grid. Add a few tiny grass tufts well inside the diamond.
```

후처리: 마젠타 배경을 빼고 마름모를 64×32 로 최근접 축소 → `ground/tile_grass_a.png`. 변형 B(풀 뭉치)·C(들꽃)는 같은 프롬프트에서 마지막 문장만 바꿔 각각 생성한다.

### 3.2 흙길 오토타일 (3×3)

```
[STYLE] [TILE RULES]
A single isometric ground tile: one 2:1 diamond of packed dirt path (#d2b37d with #965340 shadow flecks and a few small pebbles), centred on a solid magenta (#FF00FF) background. Nothing outside the diamond. Uniform brightness so copies tile seamlessly with no visible grid.
```

### 3.3 절벽 / 벽 세트 (높이의 핵심)

```
[STYLE]
A single isometric cliff block, one grid cell wide: a 2:1 diamond of grassy top surface sitting on a cube of layered brown earth, drawn so that BOTH the south-west face and the south-east face are visible with equal width (#965340 base, #61372e shadow, #b3957f embedded stones), the south-west face lighter than the south-east. The block is 32 pixels tall below the diamond top. 1px #141b1b outline on the silhouette only. Centred on a solid magenta (#FF00FF) background.
```

2단 절벽(`cliff_block_64`)은 같은 본문에서 `32 pixels tall` → `64 pixels tall` 로 바꿔 한 번 더 생성한다. 돌담 변형은 `layered brown earth` → `mortared stone (#b3957f / #8d977f / #8e7c73 with #141b1b joints)`.

### 3.4 물 (가장자리 3×3 + 물결 2프레임)

```
[STYLE] [TILE RULES]
A 3x3 grid of square tiles for a calm lake meeting meadow grass in 3/4 oblique view: corners and edges show the grass shore (#74a334) with a thin sandy rim (#eecf9b) stepping down to water; the center tile is open water (#79b8ce base, #548789 shadow ripples, a few #71ddee highlight flecks). The south edge of the shore shows a small vertical drop of earth (#965340) above the water. Thin 2px magenta (#FF00FF) gutter lines between tiles.
```

```
[STYLE] [TILE RULES]
Two square tiles side by side: the same open-water tile in two animation frames. Frame 2 shifts the #71ddee highlight flecks and #548789 ripple lines slightly to the right so looping between the two frames reads as gently moving water. Both tiles are seamless. A 2px magenta (#FF00FF) gutter between them.
```

### 3.5 큰 참나무 (Y-sort 가림 대표)

```
[STYLE]
A single large oak tree in 3/4 oblique view, drawn as a standalone sprite. A round, layered leaf canopy (#74a334 base, #4a7f4b shadow, #adbc3a highlight) sits on top; below it a short thick trunk (#a3754e / #965340 / #61372e) with visible roots at the very bottom-center, so the trunk base is the sprite's ground point. The canopy is wider than the trunk and casts no ground shadow (the game draws its own). 1px #141b1b outline. The figure fills about 70% of the canvas height, centered, trunk base at the bottom-center.
```

작은 나무·침엽수는 `large oak` → `young birch` / `pine`으로 바꾼다. 논리 크기 64×96(캔버스 96×128), 발 기준점 (48,112) — 캐릭터와 같은 규격이라 `normalize_ai_sheet.py` 기본값으로 정규화한다.

### 3.6 수풀 · 바위 · 울타리 · 표지판 (각각 따로 생성)

```
[STYLE]
A single round bush sprite in 3/4 oblique view: dense leaves #74a334 with #4a7f4b shadow on the lower-right and #adbc3a highlight on the upper-left, a few #e0394c berries. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 40% of the canvas.
```

```
[STYLE]
A single mossy boulder sprite in 3/4 oblique view: grey-brown stone #b3957f with #8e7c73 shadow and #bfa49e highlight, a patch of moss #8d977f on top. The south face is slightly darker to read as a vertical side. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 40% of the canvas.
```

```
[STYLE] [TILE RULES]
A horizontal wooden fence segment in 3/4 oblique view: two posts and two rails, wood #a3754e with #61372e shadow and #c69469 highlight, the posts slightly taller than the rails, seen from the south so the front of each post is visible. Tileable horizontally (left and right edges continue). 1px #141b1b outline.
```

```
[STYLE]
A single wooden signpost sprite in 3/4 oblique view: one post with a blank arrow-shaped plank pointing right, wood #a3754e / #61372e / #c69469. No letters on the plank. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 50% of the canvas height.
```

### 3.7 민들레 마을 집 A / B

```
[STYLE]
A single small cottage sprite in 3/4 oblique view, standalone. A steep orange-tiled roof (#e66a3a base, #d78b4a shadow, #ffad5d highlight) seen from above-front, with timber-framed cream walls (#eecf9b plaster, #a3754e beams, #61372e beam shadow) on the visible south face. One wooden door at bottom-center of the front wall and one square window with #79b8ce glass. The front wall is vertical and fully visible; the roof overhangs it slightly. The bottom edge of the front wall is the ground line. 1px #141b1b outline. Fills about 80% of the canvas width.
```

집 B: `small cottage` → `slightly larger two-story house with a small balcony`, 지붕색을 `#a26a83 slate`로 바꿔 구분. 논리 크기 A 96×96, B 128×112.

### 3.8 대장간 · 퀘스트 게시판 · 우편함 · 워프 비석 · 우물

```
[STYLE]
A single blacksmith workshop sprite in 3/4 oblique view: a stone base wall (#b3957f / #8e7c73) with a wooden upper half (#a3754e / #61372e) and a flat dark roof, a wide open front with a glowing forge (#ffad5d / #f38c4c embers) and an anvil visible inside, a chimney with a small smoke puff. Front face fully visible, ground line at the bottom edge of the wall. 1px #141b1b outline. Fills about 80% of the canvas width.
```

```
[STYLE]
A single wooden notice board sprite in 3/4 oblique view: two posts, a small roof, a board with three blank paper notes pinned on it (no writing), wood #a3754e / #61372e / #c69469, paper #f2eaf1. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 50% of the canvas height.
```

```
[STYLE]
A single village mailbox sprite in 3/4 oblique view: a small wooden box with a rounded lid on a post, a tiny #e0394c flag raised on its side. Wood #a3754e / #61372e / #c69469. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 40% of the canvas height.
```

```
[STYLE]
A single ancient waystone sprite in 3/4 oblique view: a tall weathered standing stone (#b3957f / #8e7c73 / #bfa49e) with a faint carved spiral rune glowing softly in #71ddee, moss #8d977f at its base, a few small stones around the bottom. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 70% of the canvas height.
```

```
[STYLE]
A single stone well sprite in 3/4 oblique view: a round low stone rim (#b3957f / #8e7c73) whose front face is visible, two wooden posts holding a small wooden roof and a crank with a bucket. Wood #a3754e / #61372e. 1px #141b1b outline. Ground contact at the bottom-center. Fills about 60% of the canvas height.
```

### 3.9 핀 (플레이어) — 4방향 정지 포즈

정본 정면 프롬프트는 `docs/art/fin-front-64-prompt.txt`. 쿼터뷰용으로는 아래처럼 방향만 바꿔 4장을 만든다(왼쪽은 오른쪽 반전으로 쓰므로 실제로는 정면·뒷면·오른쪽 3장).

```
[STYLE] [CHARACTER RULES]
Fin, a cheerful apprentice knight: open silver helmet with a coral-red feather plume, brown bangs, ochre tunic, short sage-green cape, brown boots. A short straight sword in the RIGHT hand, a small round wooden shield on the LEFT arm. Standing idle, relaxed, feet slightly apart. FRONT view (facing the camera / south). One figure only.
```

- 뒷면: `FRONT view (facing the camera / south)` → `BACK view (facing away, north): we see the back of the helmet, the cape covering the back, the shield's rim on the left and the sword tip on the right`
- 오른쪽: → `RIGHT side view (facing east): sword arm nearest the camera, shield mostly hidden behind the body, feather plume trailing left`

후처리: `normalize_ai_sheet.py --mode frames`(down/left/up/right 폴더, left는 right 반전 복사) → 캔버스 96×128, 발 기준점 (48,112).

### 3.10 몬스터 6종 (정면 + 오른쪽 측면, 각각 따로)

공통 꼬리말: `Ground contact at the bottom-center. One creature only, centered, filling about 45% of the canvas height. FRONT view facing the camera.` 측면은 `RIGHT side view facing east`로 바꿔 한 번 더.

| id | 본문 |
|---|---|
| `slime` | `A round bouncy slime monster, translucent-looking teal jelly (#79b8ce base, #548789 shadow, #71ddee highlight, #abc2bc rim), two simple dark eyes, a small happy mouth, a slight flattened bottom where it touches the ground.` |
| `horn_rabbit` | `A small fluffy rabbit monster with a single short ivory horn (#eecf9b) on its forehead, cream-brown fur (#c69469 / #bd7959 / #eecf9b), long ears up, mischievous eyes.` |
| `horn_rabbit_big` | 위 본문 + `larger and stockier, thicker horn, a darker brown patch on its back (#965340)`(정규화 시 1.5배) |
| `mushroom` | `A walking mushroom monster: a wide red cap with pale spots (#e0394c cap, #f2eaf1 spots, #a26a83 underside), a short stumpy pale stalk body (#eecf9b) with tiny feet and sleepy eyes.` |
| `goblin_scout` | `A small goblin scout: olive-green skin (#a8a129 / #5f7160), pointed ears, a ragged brown hood and tunic (#965340 / #61372e), a crude short dagger, hunched sneaky pose.` |
| `elite_goblin_captain` | `A goblin captain: same olive-green goblin but taller and broader, a dented iron cap (#8e7c73), a red cloth armband (#e0394c), a notched cleaver and a small wooden shield, confident stance.` |
| `elite_bunchi_spawn` | **(D-227 정정, 2026-09-21)** `A small slime monster like the base slime, but ash-tainted: dull grey-plum jelly with dark grey blotches (#4e484a / #a26a83 patches over the base #79b8ce teal), slightly larger and lumpier than the base slime, two dim glowing pale eyes (#d4f5fa), same flattened bottom where it touches the ground.` (이전 "그림자 정령 여우" 서술은 디렉터 오기 — `game/data/monsters.json`의 `elite_base_monster_id: "slime"` 및 `on_death_split_monster_id: "slime"`대로 **슬라임 골격 재사용 + 재/잿빛 얼룩 recolor**가 정본이다. 새 골격이 아니므로 art-bible §9 매트릭스에도 slime→elite_bunchi_spawn 행으로 올린다.) |

### 3.11 NPC 정면 시안

```
[STYLE] [CHARACTER RULES]
Teo, a kind village elder and guide: short grey hair, a long moss-green robe (#5f7160 / #4a7f4b), a wooden walking staff in the right hand, a small leather satchel. Gentle smile. FRONT view. One figure only.
```

```
[STYLE] [CHARACTER RULES]
A stout village blacksmith: broad shoulders, dark leather apron (#61372e) over a rolled-sleeve cream shirt, a heavy hammer resting on the right shoulder, short beard, friendly squint. FRONT view. One figure only.
```

### 3.12 (3순위) 메아리 굴 — 동굴 세트

```
[STYLE] [TILE RULES]
A 3x3 grid of square cave tiles in 3/4 oblique view: row 1 the dark stone cave floor (#4e484a base, #8e7c73 pebbles), row 2 the front face of a rough cave wall (#8e7c73 / #61372e / #b3957f), row 3 the floor meeting the wall base with a soft dark shadow. Add a few tiny glowing blue mushrooms (#71ddee, #79b8ce) on 2 tiles only. Thin 2px magenta (#FF00FF) gutter lines between tiles.
```

## 4. 후처리 절차 (생성 → 규격)

1. 생성 원본은 `game/assets_local/ai_raw/quarter/<이름>_<날짜>.png`에 보관(gitignore). 프롬프트 원문·생성 옵션을 같은 이름의 `.txt`로 옆에 둔다.
2. 그리드형(타일 세트): 마젠타 거터를 기준으로 셀을 자르고 최근접 축소.
   `python3 tools/art/normalize_ai_sheet.py --mode sheet --input <원본> --cols 3 --rows 3 --src-cell-w 256 --src-cell-h 256 --cell 32x32 --pivot 16,32 --transparent-bg --bg-color ff00ff --quantize --palette-source docs/art/preview/hartland_palette_32.png --out game/assets_local/quarter/<이름>`
   (거터 폭이 축소 후 1px 미만이면 잘림에 흡수된다. 어긋나면 `--src-cell-w/h`를 실측값으로.)
3. 단일 오브젝트: `--mode frames`로 폴더 하나에 넣고 `--cell 96x128 --pivot 48,112`(캐릭터·나무) 또는 `--cell 64x64 --pivot 32,60`(소품)로 정규화. 세로 발 기준점이 스프라이트 바닥과 맞는지 미리보기(`--preview-scale 4`)로 확인.
4. 검수(§6) 통과분만 `game/assets/quarter/<카테고리>/`로 옮기고 §5 기록을 남긴다. 미통과분은 `assets_local`에 남긴다.

## 5. LICENSES.md 기록 템플릿 (D-138)

```
### 쿼터뷰 <애셋명> — YYYY-MM-DD
- 툴/플랜: ChatGPT 이미지 생성(GPT Image), <플랜명>
- 생성일: YYYY-MM-DD, 생성 횟수: N (채택 1)
- 프롬프트: docs/art/brief-quarter-view-gpt-image.md §3.x + 변경점 "<...>"
- 후처리: normalize_ai_sheet.py <옵션>, 팔레트 양자화 32색
- 상업 이용: OpenAI 이용약관에 따라 출력물 권리는 사용자에게 귀속(약관 버전/확인일 기재)
- 파일: game/assets/quarter/<경로>
```

## 6. 검수 체크리스트

- [ ] 시점: 수직면이 남쪽에 보이고 지면은 위에서 본 모습인가(정면 원근 수렴 없음)
- [ ] 크기: 축소 후 논리 크기가 표와 같고, 발 기준점이 바닥 중앙인가
- [ ] 팔레트: 양자화 후 32색 밖의 색이 없는가(스와치 대조)
- [ ] 외곽선: 오브젝트 1px `#141b1b`, 타일은 외곽선 없음
- [ ] 안티에일리어싱·그러데이션·글로우 잔재 없음(확대 4배로 확인)
- [ ] 타일: 2×2로 반복 배치했을 때 이음새·밝기 차이 없음
- [ ] 캐릭터: 검 오른손·방패 왼손, 2.5등신, 실루엣이 32px 축소에서도 읽히는가
- [ ] 프롬프트에 실명 게임·캐릭터 없음, LICENSES 기록 완료
