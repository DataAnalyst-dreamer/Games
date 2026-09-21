#!/usr/bin/env python3
"""등각(2:1 다이메트릭) placeholder 생성기의 공용 프리미티브 (D-219~D-226, M6-3 분리).

`gen_iso_tiles.py`(하틀랜드 마을 애셋)와 `gen_iso_tiles_field.py`(필드 지형 애셋:
동굴 입구·개울·다리·이정표·계단식 절벽)가 함께 쓴다. 팔레트 파싱·등각 상자·마름모
그리기처럼 "어떤 애셋이든 필요한" 도형만 여기 두고, 개별 애셋 모양(make_house 등)은
각 생성기 파일에 그대로 둔다 — 500줄 상한(§5, CLAUDE.md) 때문에 생성기를 나눈 것이라
공용 코드까지 옮겨 두 파일이 서로 갈라지는 걸 막는다.

팔레트는 art-bible.md §3 표를 직접 파싱한다 - 사본을 만들면 art-bible 과 갈라진다.
"""
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


# --- 지면 타일 (마을·필드 공용) ---

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
