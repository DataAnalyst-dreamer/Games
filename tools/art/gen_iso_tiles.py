#!/usr/bin/env python3
"""등각(2:1 다이메트릭) placeholder 애셋 생성기 (D-219~D-226, 단계 iso-2).

기초 도형 + 하틀랜드 32색으로 라그나로크·디아블로 계열 등각 애셋을 만든다. 정식 애셋
(docs/art/brief-quarter-view-gpt-image.md)이 나오면 **같은 경로에 PNG 만 덮어쓰면** 코드
변경 없이 교체된다 - 파일명·논리 크기·발 기준점·footprint 셀 수가 계약이고 계약 본문은
iso_atlas.json 이다.

등각 규칙:
  * 지면 한 칸 = 32 월드단위 = 화면 64×32 마름모(D-220).
  * **모든 수직 물체는 두 면을 같은 비중으로 보여준다** - 남서면(SW)과 남동면(SE).
    45도 돌아간 상자라 두 면의 넓이가 같고, 그래서 탑뷰로 읽히지 않는다.
    빛은 좌상단이므로 SW 가 밝고(SHADE_SW) SE 가 어둡다(SHADE_SE).
  * 지면 타일 가장자리를 어둡게 하지 않는다 - 격자선이 보이면 보드게임처럼 읽힌다.
    대신 타일 안쪽 무늬로 경계를 암시한다.
  * 외곽선은 순검정이 아니라 잉크색 #141b1b (art-bible §2).
  * 발 기준점 = **바닥 마름모의 중심**. world.gd 가 셀 중심에 노드를 놓고 이 pivot 만큼
    그림을 끌어올린다(Y-sort 가 발밑 기준으로 걸리게).

팔레트는 art-bible.md §3 표를 직접 파싱한다 - 사본을 만들면 art-bible 과 갈라진다.

사용: python3 tools/art/gen_iso_tiles.py [--out game/assets/iso]
"""
import argparse
import json
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
ART_BIBLE = ROOT / "docs" / "art" / "art-bible.md"
CELL_W, CELL_H = 64, 32
SHADE_SW = 0.92   # 남서면: 좌상단 빛을 더 받는다
SHADE_SE = 0.72   # 남동면: 그늘
## 지붕은 채도가 높아 SHADE_SE(0.72)를 그대로 먹이면 진흙색으로 읽힌다.
SHADE_SE_ROOF = 0.84
SHADE_TOP = 1.0
ELEV_STEP = 32    # 고도 한 단(D-224)
SEED = 20260921


def load_palette():
    text = ART_BIBLE.read_text(encoding="utf-8")
    section = text.split("## 3. 지역 팔레트")[1].split("\n## ")[0]
    pairs = re.findall(r"\|\s*`(#[0-9a-fA-F]{6})`\s*\|\s*([^|]+?)\s*\|", section)
    if len(pairs) < 20:
        raise SystemExit(f"art-bible §3 팔레트를 읽지 못했다({len(pairs)}색).")
    return {name: hex_to_rgb(code) for code, name in pairs}


def hex_to_rgb(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color[:3])


def role_colors(by_name):
    def find(*keywords):
        for name, rgb in by_name.items():
            if all(k in name for k in keywords):
                return rgb
        raise SystemExit(f"팔레트에서 '{' '.join(keywords)}' 색을 찾지 못했다.")
    return {
        "ink": find("잉크"), "grass": find("잔디", "베이스"),
        "grass_hi": find("잔디", "하이라이트"), "grass_sh": find("그림자"),
        "dirt": find("길"), "dirt_sh": find("흙"),
        "stone": find("돌·벽"), "stone_sh": find("다크 그레이"),
        "wood": find("나무줄기 /"), "wood_sh": find("나무줄기 그림자"),
        "wood_hi": find("목조 벽 하이라이트"), "leaf": find("나뭇잎"),
        "roof": find("지붕 베이스"), "roof_hi": find("지붕·소품"),
        "water": find("물 하이라이트"), "water_sh": find("물 그림자"),
        "straw": find("모래"), "paper": find("연분홍"), "accent": find("레드"),
        "rune": find("물 최상단"), "moss": find("이끼"),
    }


def new_image(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# --- 등각 프리미티브 ---

def diamond(cx, cy, cells_w=1, cells_d=1):
    """footprint 중심 (cx,cy) 의 마름모 꼭짓점 N,E,S,W."""
    half_w = CELL_W * 0.5 * max(cells_w, cells_d)
    half_h = CELL_H * 0.5 * max(cells_w, cells_d)
    return [(cx, cy - half_h), (cx + half_w, cy), (cx, cy + half_h), (cx - half_w, cy)]


def draw_top(d, cx, cy, color, ink=None, cells=1):
    pts = diamond(cx, cy, cells, cells)
    d.polygon(pts, fill=color)
    if ink:
        d.polygon(pts, outline=ink)
    return pts


def iso_box(d, bx, by, height, base, ink, cells=1, top_color=None,
            outline_top=True):
    """바닥 마름모 중심 (bx,by) 에서 height 만큼 솟은 등각 상자.

    남서면과 남동면을 **같은 넓이로** 그린다 - 이게 등각 입체의 핵심이다.
    """
    half_w = CELL_W * 0.5 * cells
    half_h = CELL_H * 0.5 * cells
    top_cy = by - height
    west = (bx - half_w, top_cy)
    south = (bx, top_cy + half_h)
    east = (bx + half_w, top_cy)
    west_b = (bx - half_w, by)
    south_b = (bx, by + half_h)
    east_b = (bx + half_w, by)
    d.polygon([west, south, south_b, west_b], fill=shade(base, SHADE_SW))
    d.polygon([south, east, east_b, south_b], fill=shade(base, SHADE_SE))
    draw_top(d, bx, top_cy, top_color or shade(base, SHADE_TOP),
             ink if outline_top else None, cells)
    d.polygon([west, south, south_b, west_b], outline=ink)
    d.polygon([south, east, east_b, south_b], outline=ink)
    return top_cy


def ground_shadow(d, bx, by, cells=1):
    pts = diamond(bx, by + 2, cells, cells)
    d.polygon(pts, fill=(0, 0, 0, 55))


def speck(d, rng, pts_box, color, count):
    x0, y0, x1, y1 = pts_box
    for _ in range(count):
        d.point((rng.randrange(x0, x1), rng.randrange(y0, y1)), fill=color)


def in_diamond(x, y, cx, cy, half_w, half_h):
    return abs(x + 0.5 - cx) / half_w + abs(y + 0.5 - cy) / half_h <= 1.0


# --- 지면 타일 ---

def make_ground(rng, c, base, variant):
    """64×32 마름모 지면. 가장자리를 어둡게 하지 않아 이어 붙여도 격자선이 안 보인다."""
    img = new_image(CELL_W, CELL_H)
    d = ImageDraw.Draw(img)
    draw_top(d, CELL_W * 0.5, CELL_H * 0.5, base)
    box = (6, 4, CELL_W - 6, CELL_H - 4)
    if variant == 0:
        speck(d, rng, box, shade(base, 1.10), 10)
        speck(d, rng, box, shade(base, 0.90), 6)
    elif variant == 1:      # 풀 뭉치
        speck(d, rng, box, shade(base, 1.10), 6)
        for _ in range(3):
            x, y = rng.randrange(12, CELL_W - 12), rng.randrange(8, CELL_H - 6)
            d.line([(x, y), (x + rng.choice([-1, 1]), y - 4)], fill=shade(base, 0.78))
    elif variant == 2:      # 들꽃
        speck(d, rng, box, shade(base, 1.10), 8)
        for _ in range(3):
            x, y = rng.randrange(14, CELL_W - 14), rng.randrange(10, CELL_H - 8)
            d.point((x, y), fill=(255, 255, 255))
            d.point((x + 1, y + 1), fill=c["accent"])
    else:                   # 자갈
        speck(d, rng, box, shade(base, 1.08), 6)
        for _ in range(3):
            x, y = rng.randrange(12, CELL_W - 14), rng.randrange(8, CELL_H - 8)
            d.ellipse([x, y, x + 4, y + 2], fill=c["stone"])
    return img


# --- 고도: 절벽 블록 ---

def make_cliff_block(rng, c, height):
    """윗면 마름모 + 남서/남동 두 벽면. 높이 height 만큼 솟은 한 칸짜리 절벽."""
    img = new_image(CELL_W, CELL_H + height)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + height
    top_cy = iso_box(d, bx, by, height, c["dirt_sh"], c["ink"],
                     top_color=c["grass"])
    # 흙벽에 박힌 돌 - 두 면 모두에.
    for _ in range(6):
        sx = rng.randrange(6, CELL_W - 8)
        sy = rng.randrange(int(top_cy + 8), int(by + 10))
        if 0 <= sx < CELL_W and 0 <= sy < img.height - 2:
            d.rectangle([sx, sy, sx + 3, sy + 2],
                        fill=shade(c["stone"], SHADE_SE))
    speck(d, rng, (8, int(top_cy) - 8, CELL_W - 8, int(top_cy) + 8),
          c["grass_sh"], 8)
    return img


# --- 소품 / 건물 ---

def make_tree(rng, c):
    """줄기는 등각 상자, 캐노피는 두 면 음영이 들어간 덩어리."""
    trunk_h, canopy = 40, 46
    img = new_image(CELL_W, CELL_H + trunk_h + canopy)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + trunk_h + canopy
    ground_shadow(d, bx, by)
    top_cy = iso_box(d, bx, by, trunk_h, c["wood"], c["ink"], cells=0.34,
                     top_color=shade(c["wood"], 1.1))
    d.ellipse([bx - 28, top_cy - canopy, bx + 28, top_cy + 12], fill=c["leaf"])
    d.ellipse([bx - 24, top_cy - canopy + 4, bx + 2, top_cy - 8],
              fill=shade(c["leaf"], 1.28))
    d.ellipse([bx + 2, top_cy - 26, bx + 27, top_cy + 10],
              fill=shade(c["leaf"], SHADE_SE))
    speck(d, rng, (int(bx) - 22, int(top_cy) - canopy + 6, int(bx) + 24, int(top_cy) + 6),
          shade(c["leaf"], 0.8), 22)
    d.ellipse([bx - 28, top_cy - canopy, bx + 28, top_cy + 12], outline=c["ink"])
    return img


def make_simple_box(rng, c, height, base, cells=1.0, top_color=None, speckle=None):
    span = int(CELL_W * cells)
    img = new_image(span, int(CELL_H * cells) + height)
    d = ImageDraw.Draw(img)
    bx, by = span * 0.5, CELL_H * cells * 0.5 + height
    ground_shadow(d, bx, by, cells)
    iso_box(d, bx, by, height, base, c["ink"], cells=cells, top_color=top_color)
    if speckle:
        speck(d, rng, (4, int(by - height) + 4, span - 4, int(by) + 6), speckle, 18)
    return img, d, bx, by


def make_bush(rng, c):
    img = new_image(CELL_W, CELL_H + 18)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 18
    ground_shadow(d, bx, by)
    d.ellipse([bx - 20, by - 30, bx + 20, by + 6], fill=c["leaf"])
    d.ellipse([bx - 17, by - 27, bx + 1, by - 8], fill=shade(c["leaf"], 1.28))
    d.ellipse([bx + 1, by - 18, bx + 19, by + 4], fill=shade(c["leaf"], SHADE_SE))
    d.ellipse([bx - 20, by - 30, bx + 20, by + 6], outline=c["ink"])
    return img


def make_rock(rng, c):
    img, d, bx, by = make_simple_box(rng, c, 18, c["stone"], cells=0.62,
                                     top_color=shade(c["stone"], 1.22),
                                     speckle=c["stone_sh"])
    return img


def make_fence(rng, c, along_sw):
    """울타리 한 칸. SW(왼쪽 아래) 또는 SE(오른쪽 아래) 격자 방향으로 놓인다."""
    img = new_image(CELL_W, CELL_H + 26)
    d = ImageDraw.Draw(img)
    by = CELL_H * 0.5 + 26
    bx = CELL_W * 0.5
    ends = [(bx - 30, by - 15), (bx, by)] if along_sw else [(bx, by), (bx + 30, by - 15)]
    for x, y in ends:                      # 기둥 두 개(등각 상자)
        iso_box(d, x, y, 26, c["wood"], c["ink"], cells=0.16,
                top_color=shade(c["wood"], 1.2))
    d.line([(ends[0][0], ends[0][1] - 18), (ends[1][0], ends[1][1] - 18)],
           fill=c["wood_hi"], width=3)
    d.line([(ends[0][0], ends[0][1] - 10), (ends[1][0], ends[1][1] - 10)],
           fill=shade(c["wood_hi"], 0.85), width=3)
    return img


def make_house(rng, c):
    """2×2 칸 집: 벽(두 면) + 두 경사면 지붕."""
    wall_h, roof_h = 46, 34
    span = CELL_W * 2
    img = new_image(span, CELL_H * 2 + wall_h + roof_h)
    d = ImageDraw.Draw(img)
    bx, by = span * 0.5, CELL_H + wall_h + roof_h
    ground_shadow(d, bx, by, 2)
    top_cy = iso_box(d, bx, by, wall_h, c["wood"], c["ink"], cells=2,
                     top_color=shade(c["wood"], 1.05), outline_top=False)
    # 지붕: 같은 마름모에서 솟은 두 경사면(남서·남동) + 용마루.
    peak = (bx, top_cy - roof_h)
    west = (bx - CELL_W, top_cy)
    south = (bx, top_cy + CELL_H)
    east = (bx + CELL_W, top_cy)
    d.polygon([west, south, peak], fill=shade(c["roof"], SHADE_SW + 0.08))
    d.polygon([south, east, peak], fill=shade(c["roof"], SHADE_SE_ROOF))
    d.polygon([west, south, peak], outline=c["ink"])
    d.polygon([south, east, peak], outline=c["ink"])
    # 문은 남서면, 창은 남동면 - 두 면 모두 쓰임이 보이게.
    d.polygon([(bx - 26, top_cy + 18), (bx - 8, top_cy + 27),
               (bx - 8, top_cy + 27 + 26), (bx - 26, top_cy + 18 + 26)],
              fill=c["wood_sh"], outline=c["ink"])
    d.polygon([(bx + 10, top_cy + 26), (bx + 28, top_cy + 17),
               (bx + 28, top_cy + 17 + 16), (bx + 10, top_cy + 26 + 16)],
              fill=c["water"], outline=c["ink"])
    return img


def make_smithy(rng, c):
    """2×2 칸 대장간: 돌 기단 + 목조 + 평지붕 + 굴뚝, 남서면에 화로."""
    base_h, wood_h = 30, 26
    span = CELL_W * 2
    img = new_image(span, CELL_H * 2 + base_h + wood_h + 28)
    d = ImageDraw.Draw(img)
    bx, by = span * 0.5, CELL_H + base_h + wood_h + 28
    ground_shadow(d, bx, by, 2)
    stone_top = iso_box(d, bx, by, base_h, c["stone"], c["ink"], cells=2,
                        outline_top=False)
    wood_top = iso_box(d, bx, stone_top, wood_h, c["wood"], c["ink"], cells=2,
                       top_color=shade(c["wood_sh"], 0.9))
    # 화로: 남서면에 뚫린 아치.
    d.polygon([(bx - 44, wood_top + 30), (bx - 14, wood_top + 45),
               (bx - 14, wood_top + 45 + 26), (bx - 44, wood_top + 30 + 26)],
              fill=shade(c["ink"], 1.7), outline=c["ink"])
    d.ellipse([bx - 40, wood_top + 52, bx - 18, wood_top + 68], fill=c["roof"])
    d.ellipse([bx - 36, wood_top + 56, bx - 22, wood_top + 64], fill=c["roof_hi"])
    iso_box(d, bx + 26, wood_top + 6, 22, c["stone_sh"], c["ink"], cells=0.3)
    d.ellipse([bx + 14, wood_top - 24, bx + 38, wood_top - 8], fill=(255, 255, 255, 110))
    return img


def make_board(rng, c):
    img = new_image(CELL_W, CELL_H + 44)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 44
    ground_shadow(d, bx, by)
    for offset in (-11, 11):
        iso_box(d, bx + offset, by + offset * 0.5, 30, c["wood"], c["ink"], cells=0.14)
    panel = [(bx - 22, by - 44), (bx, by - 33), (bx, by - 11), (bx - 22, by - 22)]
    d.polygon(panel, fill=shade(c["wood_hi"], SHADE_SW), outline=c["ink"])
    panel2 = [(bx, by - 33), (bx + 22, by - 44), (bx + 22, by - 22), (bx, by - 11)]
    d.polygon(panel2, fill=shade(c["wood_hi"], SHADE_SE), outline=c["ink"])
    for i in range(2):
        d.polygon([(bx - 17 + i * 9, by - 38 + i * 4), (bx - 11 + i * 9, by - 35 + i * 4),
                   (bx - 11 + i * 9, by - 25 + i * 4), (bx - 17 + i * 9, by - 28 + i * 4)],
                  fill=c["paper"], outline=c["ink"])
    return img


def make_mailbox(rng, c):
    img = new_image(CELL_W, CELL_H + 36)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 36
    ground_shadow(d, bx, by)
    iso_box(d, bx, by, 22, c["wood"], c["ink"], cells=0.14)
    box_top = iso_box(d, bx, by - 22, 14, c["wood_hi"], c["ink"], cells=0.52,
                      top_color=shade(c["wood_hi"], 1.12))
    d.polygon([(bx + 16, box_top + 2), (bx + 24, box_top - 2),
               (bx + 24, box_top + 8), (bx + 16, box_top + 12)],
              fill=c["accent"], outline=c["ink"])
    return img


def make_waystone(rng, c):
    img = new_image(CELL_W, CELL_H + 58)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 58
    ground_shadow(d, bx, by)
    top_cy = iso_box(d, bx, by, 58, c["stone"], c["ink"], cells=0.46,
                     top_color=shade(c["stone"], 1.2))
    speck(d, rng, (int(bx) - 13, int(top_cy) + 4, int(bx) + 13, int(by) + 8),
          c["stone_sh"], 18)
    for radius in (5, 9):   # 남서면에 새긴 룬
        d.arc([bx - 17 - radius * 0.2, by - 40 - radius, bx - 17 + radius,
               by - 40 + radius], 200, 520, fill=c["rune"])
    d.polygon(diamond(bx, by + 2, 0.42, 0.42), fill=c["moss"])
    return img


def make_well(rng, c):
    img = new_image(CELL_W, CELL_H + 48)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 48
    ground_shadow(d, bx, by)
    rim_top = iso_box(d, bx, by, 18, c["stone"], c["ink"], cells=0.86,
                      top_color=shade(c["stone"], 1.15))
    d.polygon(diamond(bx, rim_top, 0.52, 0.52), fill=shade(c["water_sh"], 0.8))
    for offset in (-20, 20):
        iso_box(d, bx + offset, rim_top + 4 + offset * 0.1, 26, c["wood"], c["ink"], cells=0.14)
    roof_y = rim_top - 26
    d.polygon([(bx - 26, roof_y), (bx, roof_y + 13), (bx, roof_y - 14)],
              fill=shade(c["roof"], SHADE_SW + 0.08), outline=c["ink"])
    d.polygon([(bx, roof_y + 13), (bx + 26, roof_y), (bx, roof_y - 14)],
              fill=shade(c["roof"], SHADE_SE_ROOF), outline=c["ink"])
    return img


def make_cargo(rng, c):
    img = new_image(CELL_W, CELL_H + 30)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 30
    ground_shadow(d, bx, by)
    crate_top = iso_box(d, bx, by, 18, c["straw"], c["ink"], cells=0.7,
                        top_color=shade(c["straw"], 1.1))
    d.ellipse([bx - 14, crate_top - 16, bx + 14, crate_top + 6], fill=c["dirt"])
    d.ellipse([bx - 12, crate_top - 14, bx + 1, crate_top - 2], fill=shade(c["dirt"], 1.2))
    d.ellipse([bx + 1, crate_top - 10, bx + 13, crate_top + 4], fill=shade(c["dirt"], SHADE_SE))
    d.ellipse([bx - 14, crate_top - 16, bx + 14, crate_top + 6], outline=c["ink"])
    return img


def make_marker(rng, c):
    img = new_image(CELL_W, CELL_H + 30)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 30
    ground_shadow(d, bx, by)
    top_cy = iso_box(d, bx, by, 30, c["stone"], c["ink"], cells=0.38,
                     top_color=shade(c["stone"], 1.2))
    d.polygon([(bx - 4, by - 22), (bx - 4, by - 12), (bx - 9, by - 12),
               (bx - 1, by - 4), (bx + 7, by - 12), (bx + 2, by - 12),
               (bx + 2, by - 22)], fill=c["rune"])
    d.polygon(diamond(bx, by + 2, 0.36, 0.36), fill=c["moss"])
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="game/assets/iso")
    args = parser.parse_args()
    out_root = ROOT / args.out
    rng = random.Random(SEED)
    c = role_colors(load_palette())
    assets = {}

    def emit(category, name, image, **meta):
        folder = out_root / category
        folder.mkdir(parents=True, exist_ok=True)
        image.save(folder / f"{name}.png")
        assets[name] = dict(path=f"{args.out}/{category}/{name}.png",
                            width=image.width, height=image.height, **meta)
        print(f"  {category}/{name}.png  {image.width}×{image.height}")

    def prop(category, name, image, cells=1.0, band=0.0):
        """발 기준점 = 바닥 마름모 중심. 그림 높이에서 역산한다."""
        pivot_y = image.height - CELL_H * cells * 0.5
        emit(category, name, image, kind="prop", footprint_cells=cells,
             pivot=[image.width * 0.5, pivot_y], collision_band=band)

    print("지면 타일(64×32 마름모):")
    for index, suffix in enumerate("abc"):
        emit("ground", f"tile_grass_{suffix}", make_ground(rng, c, c["grass"], index),
             kind="ground", cell=[CELL_W, CELL_H])
    emit("ground", "tile_dirt", make_ground(rng, c, c["dirt"], 3),
         kind="ground", cell=[CELL_W, CELL_H])
    emit("ground", "tile_water", make_ground(rng, c, c["water_sh"], 0),
         kind="ground_solid", cell=[CELL_W, CELL_H], collision_band=1.0)

    print("고도(D-224):")
    for height in (ELEV_STEP, ELEV_STEP * 2):
        prop("walls", f"cliff_block_{height}", make_cliff_block(rng, c, height),
             cells=1.0, band=1.0)

    print("건물:")
    prop("buildings", "house_a", make_house(rng, c), cells=2.0, band=1.0)
    prop("buildings", "smithy", make_smithy(rng, c), cells=2.0, band=1.0)

    print("소품:")
    prop("props", "tree_oak", make_tree(rng, c), band=0.5)
    prop("props", "bush", make_bush(rng, c))
    prop("props", "rock", make_rock(rng, c), band=0.5)
    prop("props", "fence_sw", make_fence(rng, c, True), band=0.4)
    prop("props", "fence_se", make_fence(rng, c, False), band=0.4)
    prop("props", "board", make_board(rng, c))
    prop("props", "mailbox", make_mailbox(rng, c))
    prop("props", "waystone", make_waystone(rng, c))
    prop("props", "well", make_well(rng, c), band=0.7)
    prop("props", "cargo_pile", make_cargo(rng, c))
    prop("props", "marker_stone", make_marker(rng, c))

    atlas = {
        "_comment": ("등각 애셋 계약(D-219~D-226). tools/art/gen_iso_tiles.py 가 만든 기초 "
                     "도형 placeholder 의 규격이며, 정식 애셋은 같은 경로·같은 크기로 PNG 만 "
                     "덮어쓰면 된다. pivot 은 **바닥 마름모 중심**(발 기준점), footprint_cells 는 "
                     "차지하는 마름모 칸 수, collision_band 는 그 비율만큼 마름모 콜리전을 "
                     "건다(0이면 통과 가능)."),
        "_generated_by": "tools/art/gen_iso_tiles.py",
        "_palette_source": "docs/art/art-bible.md §3 (하틀랜드 32색)",
        "_cell": [CELL_W, CELL_H],
        "_elevation_step": ELEV_STEP,
        "assets": assets,
    }
    (out_root / "iso_atlas.json").write_text(
        json.dumps(atlas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"계약: {args.out}/iso_atlas.json  ({len(assets)}개 애셋)")


if __name__ == "__main__":
    main()
