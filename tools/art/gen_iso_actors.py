#!/usr/bin/env python3
"""등각 8방향 액터 placeholder 시트 생성기 (D-228~D-234, 단계 iso-3).

gen_iso_tiles.py 가 지형·소품을 담당하듯, 이 스크립트는 **캐릭터·몬스터**를 담당한다.
정식 원화(핀 64×96 8방향, PixelLab)가 나오면 **같은 경로에 PNG 만 덮어쓰면** 코드도
JSON 도 바뀌지 않는다 - 셀 규격·발 기준점·행 순서·열 배치가 계약이고, 계약 본문은
game/assets/iso/iso_actor_atlas.json 이다.

계약(= tools/art/normalize_ai_sheet.py 기본값과 동일):
  * 셀 96×128, 발 기준점 (48,112), 행=방향 · 열=프레임 (row-major)
  * 행 순서 8방향: s, sw, w, nw, n, ne, e, se
      정식 원화 5장(S·SW·W·NW·N)이 행 0~4 를 채우고, 미러 3행이 5~7 에 붙는다
      (normalize_ai_sheet.py --dirs 8 이 펼쳐서 납품). 런타임 미러는 하지 않는다.
  * 행 순서 4방향(좌우대칭 몬스터): s, w, n, e - 8방향 요청 시 대각은 수평으로
    폴백한다(D-230, scripts/systems/facing_calc.gd).
  * 열 배치 18열: idle 4 / walk 8 / attack 6 (D-231, GDD D-133 정본)

팔레트는 gen_iso_tiles.py 와 같은 경로로 art-bible.md §3 을 직접 파싱한다(사본 금지).

사용: python3 tools/art/gen_iso_actors.py [--out game/assets/iso/actors]
"""
import argparse
import json
import math

from PIL import Image, ImageDraw

from gen_iso_tiles import ROOT, load_palette, shade

CELL_W, CELL_H = 96, 128
PIVOT_X, PIVOT_Y = 48, 112
COLS = 18
CLIPS = {"idle": [0, 4], "walk": [4, 8], "attack": [12, 6]}

DIRS8 = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]
DIRS4 = ["s", "w", "n", "e"]
_D = math.sqrt(0.5)
DIR_VEC = {
    "s": (0.0, 1.0), "sw": (-_D, _D), "w": (-1.0, 0.0), "nw": (-_D, -_D),
    "n": (0.0, -1.0), "ne": (_D, -_D), "e": (1.0, 0.0), "se": (_D, _D),
}

# 프레임별 자세 계수. lean>0 = 바라보는 쪽으로 기울고, arm 은 무기 팔의 전개도.
IDLE_BOB = [0, -1, -2, -1]
WALK_BOB = [0, -2, -3, -2, 0, -2, -3, -2]
WALK_STEP = [0.0, 0.7, 1.0, 0.7, 0.0, -0.7, -1.0, -0.7]
ATTACK_LEAN = [-0.25, -0.45, 0.85, 1.0, 0.5, 0.15]
ATTACK_ARM = [-0.5, -0.9, 0.9, 1.3, 0.8, 0.2]


def actor_colors(by_name):
    """액터 대역 색. gen_iso_tiles.role_colors 와 같은 방식으로 이름 조각을 찾는다."""
    def find(*keywords):
        for name, rgb in by_name.items():
            if all(k in name for k in keywords):
                return rgb
        raise SystemExit(f"팔레트에서 '{' '.join(keywords)}' 색을 찾지 못했다.")
    return {
        "ink": find("잉크"),
        "white": find("순백"),
        "silver": find("청회색"),          # 은색 투구
        "silver_sh": find("다크 그레이"),
        "coral": find("소품 포인트"),       # 투구 깃털
        "ochre": find("길(흙길)"),          # 튜닉
        "ochre_sh": find("나무줄기 /"),
        "ochre_hi": find("모래"),
        "sage": find("바위·이끼"),          # 망토
        "sage_sh": find("잔디/수풀 그림자"),
        "skin": find("회갈색 하이라이트"),
        "wood": find("목조 벽 중간톤"),
        "wood_sh": find("목조 벽 그림자"),
        "water": find("물 하이라이트"),
        "water_sh": find("청록"),
        "fur": find("중간 회갈색"),
        "red": find("레드 포인트"),
        "pink": find("연분홍"),
        "green": find("잔디 베이스"),
        "green_dk": find("나뭇잎 그림자"),
        "olive": find("올리브"),
        "roof": find("지붕 베이스"),
        "violet": find("보라 포인트"),
        "violet_hi": find("자홍 포인트"),
    }


# --- 기초 등각 도형 ---------------------------------------------------------

def ball(d, cx, cy, rx, ry, base, ink, hi=None, sh=None):
    """구. 빛은 좌상단(등각 규칙) - 하이라이트는 왼쪽 위, 그늘은 오른쪽 아래."""
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=sh or base, outline=ink)
    if sh:
        # 같은 원을 좌상으로 조금 밀어 덮어 아래·오른쪽에만 그늘 테가 남게 한다
        # (반원 chord 로 칠하면 구가 아니라 두 색으로 갈린 원반으로 읽힌다).
        d.ellipse([cx - rx + 1, cy - ry, cx + rx - 3, cy + ry - 3], fill=base)
    if hi:
        d.ellipse([cx - rx * 0.62, cy - ry * 0.78, cx - rx * 0.06, cy - ry * 0.18], fill=hi)


def cyl(d, cx, by, rx, h, base, ink, hi=None, sh=None):
    """원기둥(발밑 중심 (cx,by), 높이 h). 옆면은 좌우 명암으로 원통감을 낸다."""
    ry = max(2, int(rx * 0.5))
    top = by - h
    d.rectangle([cx - rx, top, cx + rx, by], fill=base)
    if sh:
        d.rectangle([cx + rx * 0.2, top, cx + rx, by], fill=sh)
    if hi:
        d.rectangle([cx - rx * 0.85, top, cx - rx * 0.3, by], fill=hi)
    d.ellipse([cx - rx, by - ry, cx + rx, by + ry], fill=sh or base, outline=ink)
    d.ellipse([cx - rx, top - ry, cx + rx, top + ry], fill=hi or base, outline=ink)
    d.line([(cx - rx, top), (cx - rx, by)], fill=ink)
    d.line([(cx + rx, top), (cx + rx, by)], fill=ink)
    return top


def iso_prism(d, cx, by, half_w, h, base, ink):
    """상자. 남서면·남동면을 같은 넓이로 보여준다(gen_iso_tiles 와 같은 규칙)."""
    half_d = max(2, int(half_w * 0.5))
    top = by - h
    d.polygon([(cx - half_w, top), (cx, top - half_d), (cx + half_w, top), (cx, top + half_d)],
              fill=shade(base, 1.0), outline=ink)
    d.polygon([(cx - half_w, top), (cx, top + half_d), (cx, by + half_d), (cx - half_w, by)],
              fill=shade(base, 0.92), outline=ink)
    d.polygon([(cx, top + half_d), (cx + half_w, top), (cx + half_w, by), (cx, by + half_d)],
              fill=shade(base, 0.72), outline=ink)
    return top


def foot_shadow(d, cx, by, rx):
    d.ellipse([cx - rx, by - rx * 0.4, cx + rx, by + rx * 0.4], fill=(0, 0, 0, 60))


def right_of(vec):
    """화면에서 액터의 오른손 방향. x=가로 오프셋, y<0 이면 몸 뒤(먼저 그린다)."""
    return (-vec[1], vec[0])


def eye_pair(d, cx, cy, vec, ink, white, r=2):
    """정면성(fy)에 따라 눈 개수를 줄여 방향을 읽히게 한다."""
    fx, fy = vec
    if fy < -0.4:          # 뒤통수 - 눈 없음
        return
    spread = 4 if fy > 0.4 else 2
    xs = [cx - spread, cx + spread] if abs(fx) < 0.4 else [cx + int(fx * 3)]
    for x in xs:
        d.ellipse([x - r, cy - r, x + r, cy + r], fill=white, outline=ink)
        d.point((x, cy), fill=ink)


# --- 핀(플레이어) -----------------------------------------------------------

def draw_fin(d, c, vec, clip, t, n):
    fx, fy = vec
    rx_, ry_ = right_of(vec)
    bob = _pose_bob(clip, t)
    lean = ATTACK_LEAN[t] if clip == "attack" else 0.0
    arm = ATTACK_ARM[t] if clip == "attack" else (0.25 if clip == "walk" else 0.0)
    step = WALK_STEP[t] if clip == "walk" else 0.0

    bx = PIVOT_X + int(fx * lean * 5)
    by = PIVOT_Y + bob
    foot_shadow(d, PIVOT_X, PIVOT_Y, 18)

    # 다리(튜닉 아래) - 보행은 좌우 다리를 앞뒤로 흔든다.
    for side in (-1, 1):
        lx = bx + side * 8 + int(step * side * 5)
        d.rectangle([lx - 4, by - 26, lx + 4, by - 2], fill=c["ochre_sh"], outline=c["ink"])
        d.rectangle([lx - 5, by - 6, lx + 5, by], fill=c["wood_sh"], outline=c["ink"])

    cloak_x = bx - int(fx * 3)
    if fy < -0.3:   # 등을 보이면 망토가 몸을 덮는다
        _fin_body(d, c, bx, by, vec, lean)
        _fin_cloak(d, c, cloak_x, by, vec)
    else:           # 앞을 보이면 어깨 뒤로 가장자리만 비친다
        _fin_cloak(d, c, cloak_x, by, vec)
        _fin_body(d, c, bx, by, vec, lean)

    # 무기·방패: 오른손 검, 왼손 방패. ry_<0 이면 그 손이 몸 뒤라 작게·먼저 그린다.
    sword = (bx + int(rx_ * 18 + fx * arm * 13), by - 40 + int(ry_ * 4 - arm * 6))
    shield = (bx - int(rx_ * 18), by - 36 - int(ry_ * 4))
    items = [("shield", shield, -ry_), ("sword", sword, ry_)]
    items.sort(key=lambda it: it[2])
    for kind, (px, py), _z in items:
        if kind == "sword":
            d.line([(px, py + 14), (px + int(fx * 9), py - 14)], fill=c["silver"], width=3)
            d.line([(px, py + 14), (px + int(fx * 9), py - 14)], fill=c["white"], width=1)
            d.rectangle([px - 4, py + 12, px + 4, py + 16], fill=c["wood"], outline=c["ink"])
        else:
            ball(d, px, py, 8, 10, c["wood"], c["ink"], hi=c["ochre_hi"], sh=c["wood_sh"])

    _fin_head(d, c, bx + int(fx * lean * 3), by - 62, vec)


def _fin_cloak(d, c, cx, by, vec):
    back = max(0.0, -vec[1])   # 1 = 완전히 등을 보임
    top = by - 64
    width = 17 + int(back * 6)
    d.polygon([(cx - width, top), (cx + width, top), (cx + width + 2, by - 16),
               (cx - width - 2, by - 16)], fill=c["sage"], outline=c["ink"])
    d.polygon([(cx + 2, top), (cx + width, top), (cx + width + 2, by - 16), (cx + 2, by - 16)],
              fill=c["sage_sh"])
    if back > 0.3:   # 등판 이음선 - 뒤를 보고 있다는 단서
        d.line([(cx, top + 2), (cx, by - 18)], fill=c["sage_sh"])


def _fin_body(d, c, bx, by, vec, lean):
    top = by - 62
    d.polygon([(bx - 16, top), (bx + 16, top), (bx + 19, by - 22), (bx - 19, by - 22)],
              fill=c["ochre"], outline=c["ink"])
    d.polygon([(bx + 3, top), (bx + 16, top), (bx + 19, by - 22), (bx + 3, by - 22)],
              fill=c["ochre_sh"])
    d.rectangle([bx - 17, by - 32, bx + 17, by - 26], fill=c["wood_sh"], outline=c["ink"])
    # 어깨 갑주 - 바라보는 쪽이 살짝 넓어진다.
    d.ellipse([bx - 20 + int(vec[0] * lean * 2), top - 4, bx + 20, top + 6],
              fill=c["silver"], outline=c["ink"])


def _fin_head(d, c, cx, cy, vec):
    fx, fy = vec
    ball(d, cx, cy + 6, 9, 8, c["skin"], c["ink"], sh=c["fur"])
    # 투구: 돔 + 챙. 뒤를 보면 챙 대신 목가리개가 보인다.
    d.pieslice([cx - 11, cy - 6, cx + 11, cy + 12], 180, 360, fill=c["silver"], outline=c["ink"])
    if fy < -0.4:
        d.rectangle([cx - 9, cy + 3, cx + 9, cy + 10], fill=c["silver_sh"], outline=c["ink"])
    else:
        d.rectangle([cx - 11, cy + 2, cx + 11, cy + 5], fill=c["silver_sh"], outline=c["ink"])
    d.line([(cx - 4, cy - 4), (cx - 2, cy + 3)], fill=c["white"])
    # 깃털: 바라보는 반대쪽으로 날린다.
    px = cx - int(fx * 7)
    d.polygon([(cx, cy - 6), (px - 3, cy - 17), (px + 3, cy - 14)], fill=c["coral"], outline=c["ink"])
    eye_pair(d, cx, cy + 8, vec, c["ink"], c["white"])


# --- 몬스터 공용 ------------------------------------------------------------

def draw_creature(d, c, vec, clip, t, n, *, w, h, base, hi, sh,
                  ears=0, cap=None, horn=False, box=False, legs=False):
    """구·원기둥·상자로 만드는 몬스터 대역. 방향은 눈/귀/뿔이 표시한다."""
    fx, fy = vec
    bob = _pose_bob(clip, t)
    lean = ATTACK_LEAN[t] if clip == "attack" else 0.0
    squash = 1.0
    if clip == "walk":
        squash = 1.0 + 0.08 * math.sin(2.0 * math.pi * t / max(n, 1))
    elif clip == "attack":
        squash = 1.0 + 0.12 * lean

    bx = PIVOT_X + int(fx * lean * 6)
    by = PIVOT_Y + bob
    foot_shadow(d, PIVOT_X, PIVOT_Y, max(6, w // 3))

    half = w // 2
    body_h = int(h * squash)
    leg_h = 10 if legs else 0
    if legs:
        step = WALK_STEP[t] if clip == "walk" else 0.0
        for side in (-1, 1):
            lx = bx + side * (half // 2) + int(step * side * 4)
            d.rectangle([lx - 3, by - leg_h - 2, lx + 3, by], fill=sh, outline=c["ink"])
    if box:
        # 상자 몸통 + 구 머리. 기둥 하나로는 생물로 안 읽힌다.
        torso_top = iso_prism(d, bx, by - leg_h, half, int(body_h * 0.5), base, c["ink"])
        head_r = max(6, int(half * 0.62))
        head_cy = torso_top - head_r + 2
        ball(d, bx + int(fx * 2), head_cy, head_r, int(head_r * 0.92), hi, c["ink"],
             hi=c["white"], sh=sh)
        top = head_cy - head_r
    elif cap is not None:
        top = cyl(d, bx, by, max(4, half // 2), body_h, base, c["ink"], hi=hi, sh=sh)
        d.pieslice([bx - half, top - int(body_h * 0.55), bx + half, top + int(body_h * 0.35)],
                   180, 360, fill=cap, outline=c["ink"])
        for ox, oy in ((-half // 2, -6), (0, -11), (half // 2, -5)):
            d.ellipse([bx + ox - 3, top + oy - 2, bx + ox + 3, top + oy + 2], fill=c["pink"])
        head_cy = top + 8
        top -= int(body_h * 0.3)
    else:
        ry = max(4, body_h // 2)
        ball(d, bx, by - ry, half, ry, base, c["ink"], hi=hi, sh=sh)
        top = by - body_h
        head_cy = by - int(ry * 1.25)
    if horn:
        hx = bx + int(fx * half * 0.4)
        d.polygon([(hx - 3, top + 4), (hx + 3, top + 4), (hx + int(fx * 5), top - 10)],
                  fill=c["ochre_hi"], outline=c["ink"])
    for i in range(ears):
        side = -1 if i % 2 == 0 else 1
        ex = bx + side * (half // 2) + int(fx * 3)
        d.ellipse([ex - 3, top - 14, ex + 3, top + 4], fill=base, outline=c["ink"])
        d.ellipse([ex - 1, top - 11, ex + 1, top + 1], fill=hi)
    eye_pair(d, bx + int(fx * half * 0.3), head_cy, vec, c["ink"], c["white"])


def _pose_bob(clip, t):
    if clip == "idle":
        return IDLE_BOB[t]
    if clip == "walk":
        return WALK_BOB[t]
    return 0


# --- 액터 등록부 ------------------------------------------------------------

def actor_table(c):
    """id -> (방향 수, 몸 크기, 그림자 배율, 그리기 함수)."""
    def creature(**kw):
        return lambda d, cc, vec, clip, t, n: draw_creature(d, cc, vec, clip, t, n, **kw)

    return {
        "fin": (8, (64, 96), 2.2, draw_fin),
        "slime": (4, (40, 32), 1.4, creature(
            w=40, h=32, base=c["water"], hi=c["white"], sh=c["water_sh"])),
        "horn_rabbit": (8, (44, 44), 1.6, creature(
            w=44, h=44, base=c["skin"], hi=c["white"], sh=c["fur"], ears=2, horn=True)),
        "horn_rabbit_big": (8, (60, 60), 2.0, creature(
            w=60, h=60, base=c["olive"], hi=c["ochre_hi"], sh=c["fur"], ears=2, horn=True)),
        "mushroom": (4, (44, 56), 1.7, creature(
            w=44, h=56, base=c["ochre_hi"], hi=c["white"], sh=c["ochre_sh"], cap=c["red"])),
        "goblin_scout": (8, (48, 72), 1.8, creature(
            w=48, h=72, base=c["green"], hi=c["olive"], sh=c["green_dk"], box=True, legs=True)),
        "elite_goblin_captain": (8, (64, 96), 2.4, creature(
            w=64, h=96, base=c["green_dk"], hi=c["green"], sh=c["ink"], box=True,
            legs=True, horn=True)),
        "elite_bunchi_spawn": (8, (48, 40), 1.7, creature(
            w=48, h=40, base=c["violet"], hi=c["violet_hi"], sh=c["wood_sh"], horn=True)),
    }


def build_sheet(c, directions, draw_fn):
    rows = DIRS8 if directions == 8 else DIRS4
    sheet = Image.new("RGBA", (COLS * CELL_W, len(rows) * CELL_H), (0, 0, 0, 0))
    for row, name in enumerate(rows):
        vec = DIR_VEC[name]
        for clip, (start, count) in CLIPS.items():
            for t in range(count):
                cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
                draw_fn(ImageDraw.Draw(cell), c, vec, clip, t, count)
                sheet.alpha_composite(cell, ((start + t) * CELL_W, row * CELL_H))
    return sheet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="game/assets/iso/actors")
    parser.add_argument("--atlas", default="game/assets/iso/iso_actor_atlas.json")
    args = parser.parse_args()
    out_root = ROOT / args.out
    out_root.mkdir(parents=True, exist_ok=True)
    c = actor_colors(load_palette())

    actors = {}
    for actor_id, (directions, body, shadow, draw_fn) in actor_table(c).items():
        sheet = build_sheet(c, directions, draw_fn)
        sheet.save(out_root / f"{actor_id}.png")
        actors[actor_id] = {
            "path": f"{args.out}/{actor_id}.png",
            "directions": directions,
            "body_px": list(body),
            "shadow_scale": shadow,
        }
        print(f"  {actor_id}.png  {sheet.width}×{sheet.height}  ({directions}방향)")

    atlas = {
        "_comment": ("등각 액터 시트 계약(D-228~D-234, 단계 iso-3). "
                     "tools/art/gen_iso_actors.py 가 만든 기초 도형 placeholder 의 규격이며, "
                     "정식 시트는 **같은 경로에 PNG 만 덮어쓰면** 이 JSON 도 코드도 바뀌지 "
                     "않는다. 행=방향(dir_rows_8/_4 순서), 열=프레임(clips 의 [시작열, 개수]), "
                     "pivot 은 셀 안의 발 기준점이다. 규격은 tools/art/normalize_ai_sheet.py "
                     "기본값과 동일하다."),
        "_generated_by": "tools/art/gen_iso_actors.py",
        "_palette_source": "docs/art/art-bible.md §3 (하틀랜드 32색)",
        "_spec_source": "docs/art/fin-64-production-spec.md (D-140), GDD D-133 (프레임 수)",
        "_cell": [CELL_W, CELL_H],
        "_pivot": [PIVOT_X, PIVOT_Y],
        "_cols": COLS,
        "dir_rows_8": DIRS8,
        "dir_rows_4": DIRS4,
        "clips": CLIPS,
        "actors": actors,
    }
    (ROOT / args.atlas).write_text(
        json.dumps(atlas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"계약: {args.atlas}  ({len(actors)}개 액터)")


if __name__ == "__main__":
    main()
