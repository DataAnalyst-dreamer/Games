# 핀(Fin) PixelLab.ai / Ludo.ai 생성 브리프

> 대상: 플레이어블 4인 중 **핀** — 씩씩한 견습 기사(`docs/story/characters.md` 2.1).
> 규격 기준: `docs/art/art-bible.md` §1(32×48px, 2.5등신 SD, 발밑 피벗) + §2(1px 외곽선, 순검정
> 금지) + §3(하틀랜드 32색 팔레트) + `docs/brd/04-decisions.md` D-130~D-133(걷기 8 · 공격 6 ·
> 대기 4 · 피격 2프레임). `docs/art/character-fin-spec.md`(피벗 (16,43) 등 세부 규격 원문)가
> 정본이며, 아래 프롬프트의 셀·피벗 수치는 그 문서를 그대로 옮긴 것이다. 어긋나면 스펙 문서를 우선한다.
>
> **아래 프롬프트는 사용자가 PixelLab.ai / Ludo.ai 화면에 그대로 복사해 붙여넣는 용도다.**
> PixelLab의 실제 UI 옵션 이름(예: "Style", "View Angle", "Outline" 토글의 정확한 라벨)은
> 서비스가 자주 업데이트되므로 **이 문서에서 옵션명을 단정하지 않고 "옵션명은 서비스 UI 기준
> 확인"으로 표기한다** — 프롬프트 텍스트 자체와 스펙 키워드(크기·방향 수·투명 배경 등)를
> 텍스트 필드에 그대로 넣으면 옵션 UI가 달라져도 결과에 큰 영향이 없다.

---

## 0. 캐릭터 설정 요약 (프롬프트 작성 근거, `docs/story/characters.md` 2.1)

- **정체성**: 대륙 변방 국경 마을 수비대 견습 기사. 정면 승부형, 반사적으로 방패부터 드는
  버릇(저스트 가드 메커니즘과 연결).
- **비주얼 방향**: 둥근 SD 2.5~3등신, 소박한 검 + 소형 방패, 투구(깃털 등 방향 구분 장치 — GDD·
  art-bible이 요구하는 "네 방향 실루엣 즉시 구분" 조건을 만족시키기 위한 장치). 톤은 "귀엽지만
  씩씩함"(art-bible 톤 한 줄 요약 "아기자기하고 따뜻하다"를 벗어나지 않음, 무섭거나 그로테스크한
  요소 없음).
- **저작권 주의**: 아래 프롬프트에 특정 상용 게임·캐릭터 이름을 넣지 않았다. 사용자가 프롬프트를
  변형할 때도 실명(젤다·크루세이더 퀘스트 등)을 넣지 말 것 — `ai-sprite-pipeline.md` §2.3 참고.

---

## 1. PixelLab.ai 프롬프트 — 베이스 캐릭터 + 4방향 대기

**공통 스펙 키워드**(모든 프롬프트에 포함): `32x48 pixel canvas, 4-directional (down/left/up/right), top-down RPG view, 1px dark outline (not pure black), limited color palette (~32 colors), transparent background`.

### 1.1 변형 A — 기본형 (권장 1순위)

```
Cute chibi fantasy knight, SD proportions 2.5 heads tall, round soft shapes,
sturdy simple sword and small round shield, plain steel helmet with a small
feather plume on top for silhouette recognition, warm earthy color scheme
(brown leather, muted steel gray, small orange accent), determined but
friendly expression, standing idle pose.
32x48 pixel canvas, 4-directional character sheet (down/left/up/right),
top-down RPG view, 1px dark outline (not pure black), limited color palette
(around 32 colors), transparent background, crisp pixel art, no
anti-aliasing, feet-anchored pivot at the bottom of the cell.
```

### 1.2 변형 B — 깃털 강조(방향 구분 장치 보강)

```
Cute chibi fantasy knight, 2.5-head-tall SD proportions, round helmet with
a tall single feather plume that clearly points backward when viewed from
behind and sideways when viewed from the side (used as a direction-reading
device), simple sword on the right hip, small round shield on the left arm,
warm rounded silhouette, friendly brave expression.
32x48 pixel canvas, 4-directional (down/left/up/right), top-down RPG
perspective, 1px dark outline (avoid pure black, use a dark desaturated
tone), limited palette (~32 colors), transparent background, pixel-perfect
edges, no gradients.
```

### 1.3 변형 C — 저채도/그림자 대비 강조(하틀랜드 팔레트 정합용)

```
Chibi SD knight character, 2.5 heads tall, rounded blocky shapes (helmet-
shoulders-legs three-block silhouette), muted grass-and-wood color palette
(olive green, warm brown, straw beige) to match a pastoral countryside
setting, small sword and round shield, gentle heroic pose, three-tone
shading (base / one shadow step / one highlight step), no smooth gradients.
32x48 pixel canvas, 4-directional character turnaround (down/left/up/
right), top-down RPG view, 1px outline in a dark tone (not pure black),
limited palette (~32 colors), transparent background.
```

---

## 2. PixelLab.ai 프롬프트 — 걷기 8프레임 (D-133 기준)

```
Same character as the approved base sheet (round chibi knight with sword
and small shield, feathered helmet). Generate a walking animation cycle,
8 frames per direction, for all 4 directions (down/left/up/right),
32x48 pixel canvas per frame, top-down RPG view, feet-anchored pivot
(character's feet stay at the same baseline across all frames — no
vertical bobbing beyond a subtle 1px bounce), consistent silhouette and
weapon/shield shape across every frame (avoid frame-to-frame jitter in
size or position), 1px dark outline (not pure black), same limited
palette as the base sheet (~32 colors), transparent background.
Emphasize a natural alternating leg motion typical of a top-down RPG
walk cycle at 8-12 fps.
```

- 옵션명은 서비스 UI 기준 확인: PixelLab이 "Animation" 또는 "Motion" 탭에서 프레임 수를 별도
  숫자 입력으로 받는 경우, 텍스트의 "8 frames"보다 그 숫자 필드를 8로 명시적으로 설정하는 쪽을
  우선한다.

---

## 3. PixelLab.ai 프롬프트 — 공격 6프레임 (D-133 기준)

```
Same character as the approved base sheet. Generate a sword-attack swing
animation, 6 frames, for all 4 directions (down/left/up/right), 32x48
pixel canvas per frame, top-down RPG view. Timing structure: frames 1-2
= anticipation (winding up, shield arm pulling back slightly), frame 3-4
= the strike (fastest, most extended pose, sword fully swung forward),
frames 5-6 = follow-through/recovery (settling back toward idle stance).
Exaggerate the wind-up pose slightly for a chibi SD character (bigger
telegraphed motion reads better at low resolution). Feet stay anchored
at the same baseline pivot across all frames. Consistent weapon and
shield silhouette size across frames (no shrinking/growing sword).
1px dark outline (not pure black), same limited palette (~32 colors) as
the base sheet, transparent background.
```

---

## 4. PixelLab.ai 프롬프트 — 피격 2프레임 (D-133 기준)

```
Same character as the approved base sheet. Generate a short hurt/damage
reaction, 2 frames, for all 4 directions (down/left/up/right), 32x48
pixel canvas per frame, top-down RPG view. Frame 1: character flinches
backward slightly, shield raised defensively, brief pained expression
(kept cute, not gory or grim — no blood, no injury detail). Frame 2:
mid-recovery, starting to return toward idle stance. Feet stay anchored
at the same baseline pivot. Same outline rule (1px, not pure black) and
same limited palette (~32 colors) as the base sheet, transparent
background.
```

---

## 5. Ludo.ai — 모션 프리셋 적용 워크플로

Ludo.ai는 도트 1장(정지 포즈)에 모션 프리셋을 얹어 애니메이션 아틀라스를 뽑는 방식이다. PixelLab
에서 위 1번(베이스) 결과 중 **승인된 idle 정면(down) 1장**을 업로드한 뒤, 아래 프리셋들을 순서대로
적용한다:

| 순서 | 적용할 모션 프리셋(예상 명칭 — 옵션명은 서비스 UI 기준 확인) | 목적 | 목표 프레임 수 |
|---|---|---|---|
| 1 | 대기 호흡(Idle breathing / Breathing loop) | 정지 이미지가 아니라 살아있는 인상 — art-bible §4 "유휴 4f, 개성 동작 필수" 대응 | 4 |
| 2 | 공격 휘두르기(Attack swing / Slash) | PixelLab 6프레임 결과와 비교해 더 자연스러운 쪽을 채택(둘 다 뽑아서 비교 권장) | 6 |
| 3 | 피격(Hit reaction / Hurt / Flinch) | 짧고 즉각적인 반응 — 프레임 수를 넘치게 뽑아주면 앞 2프레임만 사용 | 2 |

- Ludo.ai가 뽑아주는 프레임 수가 D-133 기준(위 표)과 다르게 나올 수 있다 — 초과분은 버리고, 부족한
  경우 재생성하거나 PixelLab 결과로 대체한다. 최종 프레임 수는 반드시 표 값과 정확히 일치시킨다
  (`normalize_ai_sheet.py`가 파일명에 프레임 수를 자동 기입하므로 다르면 바로 눈에 띈다).
- Ludo.ai 결과물도 §1의 공통 스펙(32×48 셀, 투명 배경, 1px 외곽선, 팔레트 32색)을 만족하지 않을 수
  있다 — 다운로드 후 `tools/art/normalize_ai_sheet.py`(`docs/art/ai-sprite-pipeline.md` §4 워크플로)
  로 반드시 정규화한다.
- 4방향이 필요한 애니메이션(걷기·공격·피격)을 Ludo.ai가 1방향만 지원한다면, PixelLab 쪽 4방향
  결과를 기준선으로 쓰고 Ludo.ai는 "모션의 질감(타이밍·과장)만 참고"하는 보조 자료로 격하한다 —
  최종 채택은 4방향이 모두 갖춰진 세트를 우선한다.

---

## 6. 생성 후 처리 (필수)

1. 생성 결과 PNG를 `assets-inbox` 브랜치에 업로드.
2. `tools/art/normalize_ai_sheet.py`로 정규화(예시 명령은 스크립트 상단 docstring 및
   `docs/art/ai-sprite-pipeline.md` §4 참고).
3. `docs/art/ai-sprite-pipeline.md` §3 체크리스트 7항목 통과 확인.
4. `docs/art/LICENSES.md`에 툴·플랜·생성일·프롬프트·상업적 이용 조건 기입(§2.2 형식) — **이 기입이
   없으면 반입 불가**.
5. 승인 후 `game/assets/sprites/characters/fin/`에 배치, godot-engineer에게 SpriteFrames 통합 요청.

---

## 변경 이력

- 2026-09-18: 초안 작성. `docs/story/characters.md` 2.1(핀 설정) + art-bible §1~5 + D-130~D-133
  기준 프롬프트 5절 확정. `character-fin-spec.md` 미확인으로 피벗·히트박스 세부치는 이 문서 자체
  수치(32×48, 발밑 피벗)를 잠정 근거로 사용.
