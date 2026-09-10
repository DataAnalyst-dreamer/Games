#!/usr/bin/env python3
"""
주인공 "핀" 32x48 오리지널 스프라이트 빌드 스크립트.

- 규격: `docs/brd/04-decisions.md` D-130~D-135, `docs/art/art-bible.md` 1·2·4장.
- 캐릭터 설정: `docs/story/characters.md` 2.1절 "핀 (Fin) — 씩씩한 견습 기사".
- 모션 원칙: `docs/art/motion-design-reference.md` (선딜-타격-후딜 3단, 불균등 홀드,
  개성 아이들 동작, 과장된 준비 자세).

디자인 원칙(재실행/편집 용이성):
- 픽셀을 직접 좌표로 찍는 대신, 신체 부위별 "블록"을 함수로 조립하는 파라메트릭 방식을 쓴다
  (art-bible.md §1이 규정한 "헬멧-어깨-다리 3블록 실루엣"을 그대로 코드 구조로 옮긴 것).
- 모든 좌표는 이 파일 상단의 이름 붙은 상수/오프셋 표로만 관리한다 — 수정 시 좌표를 다시
  찾아 헤맬 필요 없이 상수만 바꾸면 된다.
- 팔레트는 전부 하틀랜드 32색 팔레트(`docs/art/art-bible.md` §3)의 부분집합에서만 골랐다
  (외곽선 잉크색만 필수 지정, 나머지는 지역 색과 완전히 통일하기 위한 의도적 선택).
- 4방향 중 좌/우는 완전히 같은 그리기 함수(측면)를 좌우 반전해서 만든다 — GDD가 허용한
  절약 전략이며, 이 사실을 `character-fin-spec.md`에 명시한다.

재실행: `python3 tools/art/build_fin_sprite.py`
"""

from pathlib import Path
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# 경로
# ---------------------------------------------------------------------------
GAME_ROOT = Path("/home/user/Games/game")
OUT_DIR = GAME_ROOT / "assets" / "sprites" / "characters" / "fin"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# 팔레트 — 전부 하틀랜드 32색 팔레트(art-bible.md §3)의 부분집합
# ---------------------------------------------------------------------------
INK = "#141b1b"        # 외곽선(하틀랜드 잉크) — 순검정 금지 규칙 준수
SKIN = "#eecf9b"        # 피부 베이스 (모래·밀짚 톤 재사용)
SKIN_SH = "#d2b37d"     # 피부 그림자 (흙길 베이스 재사용)
TUNIC = "#d78b4a"       # 옷 베이스 (지붕 주황 목조 톤 재사용)
TUNIC_SH = "#965340"    # 옷 그림자 / 망토 베이스 (나무줄기 그림자 재사용)
LEATHER = "#61372e"     # 벨트·부츠·망토 그림자·검자루 (목조 벽 최암 재사용)
WOOD = "#a3754e"        # 방패 나무 베이스 (나무줄기 재사용)
STEEL = "#abc2bc"       # 투구·검날 베이스 (청회색 재사용)
STEEL_SH = "#4e484a"    # 투구·검날 그림자 (다크 그레이 재사용)
WHITE_HI = "#ffffff"    # 최상단 하이라이트 / 눈 흰자 (순백 재사용)
PLUME = "#e0394c"       # 깃털·포인트 레드 (레드 포인트 재사용)
BRASS = "#ffad5d"       # 검 손잡이 장식·버클 (주황 하이라이트 재사용)
BLUSH = "#f2eaf1"       # 볼터치 (연분홍 하이라이트 재사용)

CELL_W, CELL_H = 32, 48

# 프레임 수(GDD D-133 / art-bible §4 확정치)
IDLE_FRAMES = 4
WALK_FRAMES = 8
ATTACK_FRAMES = 6
HURT_FRAMES = 2

# 행 순서 — 이번 작업 지시 규격: 하/좌/상/우 고정
ROW_ORDER = ["down", "left", "up", "right"]


def new_canvas():
    return Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))


def ellipse(draw, bbox, fill, outline=INK, width=1):
    draw.ellipse(bbox, fill=fill, outline=outline, width=width)


def rect(draw, bbox, fill, outline=INK, width=1):
    draw.rectangle(bbox, fill=fill, outline=outline, width=width)


def px(img, x, y, color):
    if 0 <= x < CELL_W and 0 <= y < CELL_H:
        img.putpixel((int(x), int(y)), _rgba(color))


def _rgba(hexcolor, alpha=255):
    h = hexcolor.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (r, g, b, alpha)


# ---------------------------------------------------------------------------
# 공용 파츠
# ---------------------------------------------------------------------------

def draw_shadow(draw, bob):
    """발밑 고정 타원 그림자 (art-bible §2 — 크기 불변, 위치만 캐릭터 따라감)."""
    y = 44
    ellipse(draw, (10, y, 22, y + 3), fill=None, outline=None)
    draw.ellipse((9, y, 23, y + 3), fill=(20, 27, 27, 90))


def leg_cycle(frame, total, amplitude=2):
    """걷기 프레임 → (왼다리 오프셋, 오른다리 오프셋, 전신 바운스) 를 사인 곡선으로 계산.
    불균등 홀드 대신 연속 곡선을 쓰는 이유: '제자리 미끄러짐' 없이 다리가 실제로
    교차하는 인상을 8프레임 전부에서 보장하기 위함(도트 QA 기준 3번째 항목)."""
    import math
    t = (frame / total) * 2 * math.pi
    left = math.sin(t) * amplitude
    right = -left
    bounce = abs(math.sin(t)) * amplitude * 0.9
    return left, right, bounce


# ---------------------------------------------------------------------------
# 정면(down) — 얼굴 노출 + 방패를 몸 앞에 든 실루엣
# ---------------------------------------------------------------------------

def draw_down(action, frame):
    img = new_canvas()
    d = ImageDraw.Draw(img)

    bob = 0
    lean = 0
    blink = False
    regrip = False
    leg_l = leg_r = 0
    shield_fwd = 0
    sword_swing = 0
    arm_raise = 0

    if action == "idle":
        bob = -1 if frame in (1, 2) else 0
        blink = frame == 3
        regrip = frame == 2
    elif action == "walk":
        leg_l, leg_r, bounce = leg_cycle(frame, WALK_FRAMES)
        bob = -round(bounce)
    elif action == "attack":
        # 선딜(0,1: 검 크게 들어올리고 방패를 몸에 바짝 당김 — "저스트 가드" 반사를 과장) -
        # 타격(2: 가장 짧은 프레임, 방패를 앞으로 내지르며 검을 내려침) - 후딜(3,4,5: 서서히 회수)
        # shield_fwd/sword_swing/arm_raise = (방패 전진량, 검 수평 스윙량, 검+어깨 들림량)
        stage = [(-1, 0, 3), (-3, 0, 6), (4, 4, -2), (2, 1, 0), (1, 0, 0), (0, 0, 0)][frame]
        shield_fwd, sword_swing, arm_raise = stage
    elif action == "hurt":
        lean = 5 if frame == 0 else 2
        bob = 2 if frame == 0 else 1
        blink = frame == 0  # 찡그림(윈스) — 눈을 질끈 감는다

    draw_shadow(d, bob)

    # 다리 — 들리는 쪽 다리는 짧게(발이 위로 올라감), 딛는 쪽은 길게(발이 바닥) +
    # 좌우로 살짝 벌어짐(교차 인상). 제자리에서 위아래로만 흔들리지 않게 두 값을 함께 쓴다.
    lift_l = max(0, leg_l) * 1.5
    lift_r = max(0, leg_r) * 1.5
    spread = abs(leg_l) * 0.5
    rect(d, (11 - spread, 34 + bob, 14 - spread, 43 + bob - lift_l), TUNIC_SH)
    rect(d, (18 + spread, 34 + bob, 21 + spread, 43 + bob - lift_r), TUNIC_SH)
    rect(d, (10 - spread, 40 + bob - lift_l, 15 - spread, 43 + bob - lift_l), LEATHER)  # 부츠 좌
    rect(d, (17 + spread, 40 + bob - lift_r, 22 + spread, 43 + bob - lift_r), LEATHER)  # 부츠 우

    # 몸통(튜닉)
    rect(d, (10 + lean * 0.3, 18 + bob, 21 + lean * 0.3, 33 + bob), TUNIC)
    rect(d, (10 + lean * 0.3, 29 + bob, 21 + lean * 0.3, 31 + bob), LEATHER)  # 벨트
    px(img, 16, 30 + bob, BRASS)  # 버클

    # 오른팔 + 검 (허리 옆에 늘어뜨림, 공격 시 내지름)
    sx = 22 + sword_swing
    hilt_raise = arm_raise * 0.5
    rect(d, (21 + lean * 0.3, 20 + bob - arm_raise, 24 + lean * 0.3, 27 + bob), TUNIC)
    rect(d, (sx - 1, 24 + bob - arm_raise, sx + 1, 33 + bob - hilt_raise), STEEL)
    px(img, sx, 23 + bob - arm_raise, WHITE_HI)
    rect(d, (sx - 1, 32 + bob - hilt_raise, sx + 1, 34 + bob - hilt_raise), LEATHER)

    # 왼팔 + 소형 방패(정면에 듦 — 정면 실루엣의 핵심 식별 요소)
    shx = 7 - shield_fwd
    rect(d, (7 + lean * 0.3, 20 + bob, 10 + lean * 0.3, 27 + bob), TUNIC)
    ellipse(d, (shx - 3, 20 + bob, shx + 3, 28 + bob), fill=WOOD)
    d.arc((shx - 3, 20 + bob, shx + 3, 28 + bob), 200, 340, fill=STEEL, width=1)

    # 머리(투구) — 정면은 얼굴이 드러나는 것이 상(뒤통수)과의 핵심 차별점
    hx = lean * 0.4  # 피격 시 머리도 함께 뒤로 젖혀지도록
    ellipse(d, (7 + hx, 3 + bob, 24 + hx, 18 + bob), fill=STEEL)
    d.arc((7 + hx, 3 + bob, 24 + hx, 18 + bob), 200, 340, fill=STEEL_SH, width=1)
    px(img, 10 + hx, 5 + bob, WHITE_HI)
    # 얼굴 개구부(피부)
    ellipse(d, (10 + hx, 8 + bob, 21 + hx, 17 + bob), fill=SKIN, outline=None)
    d.line((10 + hx, 8 + bob, 10 + hx, 15 + bob), fill=INK)
    d.line((21 + hx, 8 + bob, 21 + hx, 15 + bob), fill=INK)
    # 눈
    if not blink:
        px(img, 13 + hx, 12 + bob, INK)
        px(img, 18 + hx, 12 + bob, INK)
    else:
        d.line((12 + hx, 12 + bob, 14 + hx, 12 + bob), fill=INK)
        d.line((17 + hx, 12 + bob, 19 + hx, 12 + bob), fill=INK)
    # 볼터치 + 입
    px(img, 12 + hx, 14 + bob, BLUSH)
    px(img, 19 + hx, 14 + bob, BLUSH)
    d.line((14 + hx, 15 + bob, 17 + hx, 15 + bob), fill=INK)
    # 턱끈
    d.line((11 + hx, 16 + bob, 20 + hx, 16 + bob), fill=LEATHER)

    # 깃털(정면: 위로 솟았다가 앞으로 살짝 휨 — 뒤통수 뷰와 확실히 다른 실루엣)
    d.line((15 + hx, 3 + bob, 14 + hx, -1 + bob), fill=PLUME, width=2)
    d.line((17 + hx, 3 + bob, 18 + hx, -1 + bob), fill=PLUME, width=1)

    if regrip:
        px(img, sx, 30 + bob, BRASS)

    return img


# ---------------------------------------------------------------------------
# 후면(up) — 얼굴 없음, 등에 진 방패+검, 견습 망토가 핵심 실루엣
# ---------------------------------------------------------------------------

def draw_up(action, frame):
    img = new_canvas()
    d = ImageDraw.Draw(img)

    bob = 0
    leg_l = leg_r = 0
    cape_sway = 0
    arm_raise = 0

    if action == "idle":
        bob = -1 if frame in (1, 2) else 0
        cape_sway = 1 if frame == 2 else 0
    elif action == "walk":
        leg_l, leg_r, bounce = leg_cycle(frame, WALK_FRAMES)
        bob = -round(bounce)
        cape_sway = round(leg_l)
    elif action == "attack":
        # 뒤에서 볼 때도 선딜에서 양팔을 크게 들어올렸다가 타격에서 앞으로 툭 떨어뜨리는
        # 실루엣 변화로 3단 타이밍을 드러낸다(등짐 방패·검 자체는 고정 소품이라 움직이지 않음).
        stage = [3, 5, -2, 0, 0, 0][frame]
        arm_raise = stage
        cape_sway = -stage * 0.4
    elif action == "hurt":
        bob = 1 if frame == 0 else 0
        cape_sway = 2 if frame == 0 else 0

    draw_shadow(d, bob)

    # 다리 (draw_down과 동일한 들림/딛음 규칙)
    lift_l = max(0, leg_l) * 1.5
    lift_r = max(0, leg_r) * 1.5
    spread = abs(leg_l) * 0.5
    rect(d, (11 - spread, 34 + bob, 14 - spread, 43 + bob - lift_l), TUNIC_SH)
    rect(d, (18 + spread, 34 + bob, 21 + spread, 43 + bob - lift_r), TUNIC_SH)
    rect(d, (10 - spread, 40 + bob - lift_l, 15 - spread, 43 + bob - lift_l), LEATHER)
    rect(d, (17 + spread, 40 + bob - lift_r, 22 + spread, 43 + bob - lift_r), LEATHER)

    # 망토(견습 표식) — 상 방향에서만 보이는 결정적 실루엣 요소
    rect(d, (11, 17 + bob + cape_sway * 0.3, 20, 30 + bob), TUNIC_SH, outline=INK)
    rect(d, (12, 26 + bob, 19, 29 + bob), LEATHER)

    # 등에 멘 방패(망토 위로 겹쳐 보임)
    ellipse(d, (12, 16 + bob, 20, 25 + bob), fill=WOOD)
    d.arc((12, 16 + bob, 20, 25 + bob), 20, 160, fill=STEEL, width=1)

    # 몸통(튜닉)
    rect(d, (10, 18 + bob, 21, 33 + bob), TUNIC)
    rect(d, (10, 29 + bob, 21, 31 + bob), LEATHER)

    # 팔
    rect(d, (21, 20 + bob - arm_raise, 24, 27 + bob), TUNIC)
    rect(d, (7, 20 + bob, 10, 27 + bob), TUNIC)
    # 등에 멘 검 손잡이(어깨 위로 살짝 보임)
    rect(d, (19, 14 + bob, 21, 20 + bob), LEATHER)
    px(img, 20, 13 + bob, BRASS)

    # 머리(투구 뒤통수) — 얼굴 요소 전혀 없음, 매끈한 돔 + 중앙 솔기 선만
    ellipse(d, (7, 3 + bob, 24, 18 + bob), fill=STEEL)
    d.arc((7, 3 + bob, 24, 18 + bob), 20, 160, fill=STEEL_SH, width=1)
    d.line((16, 4 + bob, 16, 16 + bob), fill=STEEL_SH)
    px(img, 15, 5 + bob, WHITE_HI)

    # 깃털 — 뒤에서 보면 대부분 투구에 가려 짧은 끝만 보임(정면 대비 훨씬 작은 실루엣)
    d.line((16, 3 + bob, 16, 0 + bob), fill=PLUME, width=2)

    return img


# ---------------------------------------------------------------------------
# 측면(side, 기본형=좌) — 옆모습 프로필, 방패는 얇게 날 방향으로만 보임
# ---------------------------------------------------------------------------

def draw_side(action, frame):
    img = new_canvas()
    d = ImageDraw.Draw(img)

    bob = 0
    stride = 0
    sword_fwd = 0
    guard_up = 0
    lean = 0

    if action == "idle":
        bob = -1 if frame in (1, 2) else 0
    elif action == "walk":
        import math
        t = (frame / WALK_FRAMES) * 2 * math.pi
        stride = math.sin(t) * 3
        bob = -round(abs(math.sin(t)) * 2)
    elif action == "attack":
        stage = [(-1, 0), (-2, 1), (4, 0), (2, 0), (0, 0), (0, 0)][frame]
        sword_fwd, guard_up = stage
    elif action == "hurt":
        lean = -2 if frame == 0 else -1
        bob = 1 if frame == 0 else 0

    draw_shadow(d, bob)

    # 뒷다리(진행 방향 반대쪽, 살짝 어둡게 — 원근 대비). 뒤로 빠질 때 살짝 들려 짧아진다.
    back_lift = max(0, -stride) * 0.6
    front_lift = max(0, stride) * 0.6
    rect(d, (16 - stride, 34 + bob, 19 - stride, 43 + bob - back_lift), TUNIC_SH)
    rect(d, (15 - stride, 40 + bob - back_lift, 20 - stride, 43 + bob - back_lift), LEATHER)
    # 앞다리 — 내딛을 때 몸 앞으로 크게 나가 교차가 뚜렷하다.
    rect(d, (12 + stride, 34 + bob, 15 + stride, 43 + bob - front_lift), TUNIC_SH)
    rect(d, (11 + stride, 40 + bob - front_lift, 16 + stride, 43 + bob - front_lift), LEATHER)

    # 망토 자락(등 쪽에 살짝 — 정면에는 없는 요소, 측면 실루엣을 두텁게)
    d.polygon([(20, 19 + bob), (24, 24 + bob), (20, 29 + bob)], fill=TUNIC_SH, outline=INK)

    # 몸통
    rect(d, (11 + lean, 18 + bob, 21 + lean, 33 + bob), TUNIC)
    rect(d, (11 + lean, 29 + bob, 21 + lean, 31 + bob), LEATHER)

    # 방패팔(뒤쪽, 날 방향으로만 보이는 얇은 세로 판 — 정면의 둥근 실루엣과 확실히 다름)
    rect(d, (19 + lean, 21 + bob - guard_up, 21 + lean, 29 + bob - guard_up), WOOD, outline=INK)
    px(img, 20 + lean, 22 + bob - guard_up, STEEL)

    # 검팔(앞쪽, 진행 방향으로 뻗음)
    fx = 8 + sword_fwd
    rect(d, (9 + lean, 20 + bob, 12 + lean, 27 + bob), TUNIC)
    d.line((fx + lean, 24 + bob, fx - 6 + lean, 20 + bob), fill=STEEL, width=2)
    px(img, fx - 6 + lean, 20 + bob, WHITE_HI)
    rect(d, (fx - 1 + lean, 25 + bob, fx + 1 + lean, 28 + bob), LEATHER)

    # 머리(투구 옆모습) — 코 돌출 + 눈 1개만, 정면/후면과 전혀 다른 실루엣
    ellipse(d, (8 + lean, 3 + bob, 23 + lean, 18 + bob), fill=STEEL)
    d.pieslice((6 + lean, 8 + bob, 14 + lean, 16 + bob), 100, 260, fill=SKIN, outline=None)
    d.line((7 + lean, 9 + bob, 7 + lean, 15 + bob), fill=SKIN)
    px(img, 8 + lean, 12 + bob, INK)  # 눈
    px(img, 9 + lean, 15 + bob, BLUSH)
    d.arc((8 + lean, 3 + bob, 23 + lean, 18 + bob), 110, 250, fill=STEEL_SH, width=1)
    px(img, 20 + lean, 5 + bob, WHITE_HI)

    # 깃털(진행 반대쪽으로 수평으로 흩날림 — 정면/후면의 수직 깃털과 다른 방향성)
    d.line((22 + lean, 4 + bob, 27 + lean, 3 + bob), fill=PLUME, width=2)

    return img


DRAW_FUNCS = {"down": draw_down, "up": draw_up, "left": draw_side}


def build_sheet(action, n_frames):
    sheet = Image.new("RGBA", (CELL_W * n_frames, CELL_H * len(ROW_ORDER)), (0, 0, 0, 0))
    for row_i, direction in enumerate(ROW_ORDER):
        src_dir = "left" if direction == "right" else direction
        for f in range(n_frames):
            cell = DRAW_FUNCS[src_dir](action, f)
            if direction == "right":
                cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.paste(cell, (f * CELL_W, row_i * CELL_H), cell)
    return sheet


def main():
    specs = [
        ("fin_idle.png", "idle", IDLE_FRAMES),
        ("fin_walk.png", "walk", WALK_FRAMES),
        ("fin_attack.png", "attack", ATTACK_FRAMES),
        ("fin_hurt.png", "hurt", HURT_FRAMES),
    ]
    for filename, action, n in specs:
        sheet = build_sheet(action, n)
        out_path = OUT_DIR / filename
        sheet.save(out_path, "PNG")
        print(f"saved {out_path} ({sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
