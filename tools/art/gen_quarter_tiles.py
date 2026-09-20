#!/usr/bin/env python3
"""쿼터뷰 32px 오블리크 placeholder 타일셋 생성기 (D-201/D-213, 단계 b2).

기초 도형 + 하틀랜드 32색만으로 "비스듬히 보는 바닥과 정면이 보이는 수직면"을 만든다.
정식 애셋(docs/art/brief-quarter-view-gpt-image.md)이 나오면 **같은 경로에 PNG 만
덮어쓰면** 코드 변경 없이 교체된다 - 파일명·논리 크기·발 기준점이 계약이고, 계약 본문은
quarter_atlas.json 이다.

오블리크 규칙(전 오브젝트 공통):
  * 윗면(바닥 평면)은 세로로 OBLIQUE_SQUASH(0.42) 눌러 그린다 - 단계 (a)의 발밑 그림자
    (Tuning.FOOT_SHADOW_Y_SCALE)와 같은 각도여야 그림자와 지형의 시점이 어긋나지 않는다.
  * 정면(카메라를 향한 수직면)은 눌리지 않은 수직면, 명도는 윗면의 FRONT_SHADE(65%).
  * 외곽선은 순검정이 아니라 잉크색 #141b1b (art-bible §2).

팔레트는 art-bible.md §3 표를 직접 파싱한다 - 사본을 만들면 art-bible 과 갈라진다.

사용: python3 tools/art/gen_quarter_tiles.py [--out game/assets/quarter]
"""
import argparse
import json
import random
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
ART_BIBLE = ROOT / "docs" / "art" / "art-bible.md"
TILE = 32
OBLIQUE_SQUASH = 0.42
FRONT_SHADE = 0.65
SEED = 20260920


def load_palette():
    """art-bible.md §3 하틀랜드 32색 표에서 `#rrggbb` 를 읽어 온다."""
    text = ART_BIBLE.read_text(encoding="utf-8")
    section = text.split("## 3. 지역 팔레트")[1].split("\n## ")[0]
    pairs = re.findall(r"\|\s*`(#[0-9a-fA-F]{6})`\s*\|\s*([^|]+?)\s*\|", section)
    if len(pairs) < 20:
        raise SystemExit(f"art-bible §3 팔레트를 읽지 못했다({len(pairs)}색). 표 형식 확인 필요.")
    return {name: hex_to_rgb(code) for code, name in pairs}, [hex_to_rgb(c) for c, _ in pairs]


def hex_to_rgb(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


# 팔레트 이름은 한국어라 코드에서 쓰기 번거롭다 - 역할별로 한 번만 뽑아 쓴다.
def role_colors(by_name):
    def find(*keywords):
        for name, rgb in by_name.items():
            if all(k in name for k in keywords):
                return rgb
        raise SystemExit(f"팔레트에서 '{' '.join(keywords)}' 색을 찾지 못했다.")
    return {
        "ink": find("잉크"),
        "grass": find("잔디", "베이스"),
        "grass_hi": find("잔디", "하이라이트"),
        "grass_sh": find("그림자"),
        "dirt": find("길"),
        "dirt_sh": find("흙"),
        "stone": find("돌·벽"),
        "stone_sh": find("다크 그레이"),
        "wood": find("나무줄기 /"),
        "wood_sh": find("나무줄기 그림자"),
        "wood_hi": find("목조 벽 하이라이트"),
        "leaf": find("나뭇잎"),
        "roof": find("지붕 베이스"),
        "roof_hi": find("지붕·소품"),
        "water": find("물 하이라이트"),
        "water_sh": find("물 그림자"),
        "straw": find("모래"),
    }


def noise(draw, rng, box, color, count):
    """평평한 면에 도트 몇 개만 흩뿌려 단색 느낌을 없앤다(그라데이션 금지)."""
    x0, y0, x1, y1 = box
    for _ in range(count):
        x = rng.randrange(x0, x1)
        y = rng.randrange(y0, y1)
        draw.point((x, y), fill=color)


def new_image(width, height):
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


# --- 지면 ---

def make_grass(rng, c, variant):
    img = new_image(TILE, TILE)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, TILE - 1, TILE - 1], fill=c["grass"])
    noise(d, rng, (0, 0, TILE, TILE), c["grass_hi"], 5)
    noise(d, rng, (0, 0, TILE, TILE), c["grass_sh"], 3)
    if variant == 1:  # 들꽃
        for _ in range(3):
            x, y = rng.randrange(4, TILE - 4), rng.randrange(4, TILE - 4)
            d.point((x, y), fill=(255, 255, 255))
            d.point((x + 1, y + 1), fill=c["roof_hi"])
    elif variant == 2:  # 마른 풀
        noise(d, rng, (0, 0, TILE, TILE), c["straw"], 8)
    return img


def make_auto_3x3(rng, c, inner, outer, fleck):
    """3×3 오토타일: 가운데가 채움, 가장자리 8칸이 outer 로 전이.

    placeholder 라 경계는 직선 + 약간의 톱니만 준다(정식 애셋이 불규칙 경계를 담당).
    """
    img = new_image(TILE * 3, TILE * 3)
    d = ImageDraw.Draw(img)
    inset = 10
    for row in range(3):
        for col in range(3):
            ox, oy = col * TILE, row * TILE
            d.rectangle([ox, oy, ox + TILE - 1, oy + TILE - 1], fill=outer)
            x0 = ox + (inset if col == 0 else 0)
            y0 = oy + (inset if row == 0 else 0)
            x1 = ox + TILE - 1 - (inset if col == 2 else 0)
            y1 = oy + TILE - 1 - (inset if row == 2 else 0)
            d.rectangle([x0, y0, x1, y1], fill=inner)
            noise(d, rng, (x0 + 1, y0 + 1, max(x0 + 2, x1), max(y0 + 2, y1)), fleck, 8)
    return img


# --- 벽 / 절벽: 오블리크의 핵심 ---

def make_cliff(rng, c):
    """3×3. 0행=윗면(눌린 바닥), 1행=정면(수직면), 2행=바닥 그림자 띠.

    열은 좌 끝/반복/우 끝. 접지선은 1행 아래 가장자리이며, 충돌은 그 띠에만 건다
    (collision_band_px) - 정면 벽은 "이미 막힌 곳의 그림"이라 물리를 주지 않는다.
    """
    img = new_image(TILE * 3, TILE * 3)
    d = ImageDraw.Draw(img)
    top, front = c["grass"], shade(c["dirt_sh"], 1.0)
    for col in range(3):
        ox = col * TILE
        # 0행: 절벽 윗면 - 잔디. 뒤쪽(북) 가장자리를 눌린 만큼 살짝 띠로 표시.
        d.rectangle([ox, 0, ox + TILE - 1, TILE - 1], fill=top)
        d.rectangle([ox, 0, ox + TILE - 1, int(TILE * OBLIQUE_SQUASH) - 1], fill=shade(top, 1.12))
        noise(d, rng, (ox, 0, ox + TILE, TILE), c["grass_sh"], 10)
        # 1행: 정면 - 흙벽 + 박힌 돌. 윗면 명도의 FRONT_SHADE.
        d.rectangle([ox, TILE, ox + TILE - 1, TILE * 2 - 1], fill=shade(front, 1.0))
        d.rectangle([ox, TILE, ox + TILE - 1, TILE + 2], fill=shade(c["grass"], FRONT_SHADE))
        for _ in range(4):
            sx = ox + rng.randrange(3, TILE - 6)
            sy = TILE + rng.randrange(6, TILE - 6)
            d.rectangle([sx, sy, sx + 3, sy + 2], fill=shade(c["stone"], FRONT_SHADE))
        d.line([ox, TILE * 2 - 1, ox + TILE - 1, TILE * 2 - 1], fill=c["ink"])
        # 2행: 벽 아래 잔디에 드리운 그림자.
        d.rectangle([ox, TILE * 2, ox + TILE - 1, TILE * 3 - 1], fill=c["grass"])
        d.rectangle([ox, TILE * 2, ox + TILE - 1, TILE * 2 + 5], fill=c["grass_sh"])
        # 좌/우 끝 열은 바깥쪽 모서리에 외곽선을 세운다.
        if col == 0:
            d.line([ox, 0, ox, TILE * 2 - 1], fill=c["ink"])
        if col == 2:
            d.line([ox + TILE - 1, 0, ox + TILE - 1, TILE * 2 - 1], fill=c["ink"])
    return img


# --- 오브젝트: 발밑이 접지, 위로 자란다 ---

def make_tree(rng, c):
    """64×96. 캐노피 + 줄기. 발 기준점은 줄기 밑동 (32, 88)."""
    img = new_image(64, 96)
    d = ImageDraw.Draw(img)
    d.ellipse([18, 78, 46, 92], fill=(0, 0, 0, 60))          # 발밑 그림자(눌린 타원)
    d.rectangle([27, 52, 36, 88], fill=c["wood"])             # 줄기
    d.rectangle([27, 52, 30, 88], fill=c["wood_sh"])
    d.rectangle([26, 51, 37, 89], outline=c["ink"])
    d.ellipse([4, 4, 60, 58], fill=c["leaf"])                 # 캐노피
    d.ellipse([10, 8, 46, 40], fill=shade(c["leaf"], 1.35))
    noise(d, rng, (10, 10, 54, 50), shade(c["leaf"], 0.8), 26)
    d.ellipse([4, 4, 60, 58], outline=c["ink"])
    return img


def make_bush(rng, c):
    img = new_image(TILE, TILE)
    d = ImageDraw.Draw(img)
    d.ellipse([6, 24, 26, 30], fill=(0, 0, 0, 55))
    d.ellipse([3, 8, 29, 28], fill=c["leaf"])
    d.ellipse([7, 10, 22, 21], fill=shade(c["leaf"], 1.3))
    noise(d, rng, (6, 11, 27, 26), shade(c["leaf"], 0.78), 10)
    d.ellipse([3, 8, 29, 28], outline=c["ink"])
    return img


def make_rock(rng, c):
    img = new_image(TILE, TILE)
    d = ImageDraw.Draw(img)
    d.ellipse([7, 24, 25, 30], fill=(0, 0, 0, 55))
    d.polygon([(6, 28), (10, 12), (20, 9), (26, 20), (24, 28)], fill=c["stone"])
    d.polygon([(10, 12), (20, 9), (19, 17), (11, 19)], fill=shade(c["stone"], 1.2))
    noise(d, rng, (9, 13, 24, 27), c["stone_sh"], 8)
    d.polygon([(6, 28), (10, 12), (20, 9), (26, 20), (24, 28)], outline=c["ink"])
    return img


def make_fence(rng, c):
    """96×32 = 가로/세로/모서리 3종. 기둥은 아래가 접지."""
    img = new_image(TILE * 3, TILE)
    d = ImageDraw.Draw(img)

    def post(ox, x):
        d.rectangle([ox + x, 10, ox + x + 4, 28], fill=c["wood"])
        d.rectangle([ox + x, 10, ox + x + 1, 28], fill=c["wood_sh"])
        d.rectangle([ox + x - 1, 9, ox + x + 5, 29], outline=c["ink"])

    def rail(ox, x0, x1, y):
        d.rectangle([ox + x0, y, ox + x1, y + 3], fill=c["wood_hi"])
        d.rectangle([ox + x0, y, ox + x1, y + 3], outline=c["ink"])

    rail(0, 0, TILE - 1, 15); post(0, 4); post(0, 22)          # 가로
    d.rectangle([TILE + 13, 6, TILE + 18, 30], fill=c["wood"])  # 세로(원근상 얇게)
    d.rectangle([TILE + 12, 5, TILE + 19, 31], outline=c["ink"])
    rail(TILE * 2, 14, TILE - 1, 15); post(TILE * 2, 12)        # 모서리
    d.rectangle([TILE * 2 + 13, 15, TILE * 2 + 18, 31], fill=c["wood"])
    return img


def make_house_a(rng, c):
    """96×96. 지붕(윗면·눌림) + 정면 벽 + 문. 하단 32px 한 행이 접지 띠."""
    img = new_image(96, 96)
    d = ImageDraw.Draw(img)
    d.rectangle([6, 84, 90, 94], fill=(0, 0, 0, 55))
    d.rectangle([10, 44, 86, 88], fill=c["wood"])              # 정면 벽
    d.rectangle([10, 44, 86, 88], outline=c["ink"])
    noise(d, rng, (12, 46, 84, 86), c["wood_sh"], 30)
    d.polygon([(4, 46), (48, 8), (92, 46)], fill=c["roof"])     # 지붕
    d.polygon([(4, 46), (48, 8), (48, 46)], fill=c["roof_hi"])
    d.polygon([(4, 46), (48, 8), (92, 46)], outline=c["ink"])
    d.rectangle([40, 60, 56, 88], fill=c["wood_sh"])            # 문
    d.rectangle([40, 60, 56, 88], outline=c["ink"])
    d.rectangle([18, 54, 32, 66], fill=c["water"])              # 창
    d.rectangle([18, 54, 32, 66], outline=c["ink"])
    d.rectangle([64, 54, 78, 66], fill=c["water"])
    d.rectangle([64, 54, 78, 66], outline=c["ink"])
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="game/assets/quarter")
    args = parser.parse_args()
    out_root = ROOT / args.out
    rng = random.Random(SEED)
    by_name, _ = load_palette()
    c = role_colors(by_name)

    assets = {}

    def emit(category, name, image, **meta):
        folder = out_root / category
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / f"{name}.png"
        image.save(path)
        assets[name] = dict(path=f"{args.out}/{category}/{name}.png",
                            width=image.width, height=image.height, **meta)
        print(f"  {path.relative_to(ROOT)}  {image.width}×{image.height}")

    print("지면:")
    for index, suffix in enumerate("abc"):
        emit("ground", f"tile_grass_{suffix}", make_grass(rng, c, index),
             kind="ground", cell=[TILE, TILE], grid=[1, 1])
    emit("ground", "tile_dirt_auto", make_auto_3x3(rng, c, c["dirt"], c["grass"], c["dirt_sh"]),
         kind="ground", cell=[TILE, TILE], grid=[3, 3])
    emit("ground", "water_auto", make_auto_3x3(rng, c, c["water_sh"], c["grass"], c["water"]),
         kind="ground_solid", cell=[TILE, TILE], grid=[3, 3], collision_band_px=TILE)

    print("벽:")
    emit("walls", "cliff_auto", make_cliff(rng, c),
         kind="wall", cell=[TILE, TILE], grid=[3, 3],
         # 접지 띠: 정면(1행)의 아래 10px 만 막는다. 윗면과 그림자 행은 통과 가능.
         collision_band_px=10, front_row=1, top_row=0, shadow_row=2)

    print("소품:")
    emit("props", "tree_oak", make_tree(rng, c),
         kind="prop", cell=[64, 96], grid=[1, 1], pivot=[32, 88], collision_band_px=8)
    emit("props", "bush", make_bush(rng, c),
         kind="prop", cell=[TILE, TILE], grid=[1, 1], pivot=[16, 30], collision_band_px=0)
    emit("props", "rock", make_rock(rng, c),
         kind="prop", cell=[TILE, TILE], grid=[1, 1], pivot=[16, 30], collision_band_px=6)
    emit("props", "fence", make_fence(rng, c),
         kind="prop", cell=[TILE, TILE], grid=[3, 1], pivot=[16, 30], collision_band_px=6)

    print("건물:")
    emit("buildings", "house_a", make_house_a(rng, c),
         kind="prop", cell=[96, 96], grid=[1, 1], pivot=[48, 92], collision_band_px=20)

    atlas = {
        "_comment": ("쿼터뷰 애셋 계약(D-207). tools/art/gen_quarter_tiles.py 가 생성한 "
                     "기초 도형 placeholder 의 규격이며, 정식 애셋은 같은 경로·같은 크기로 "
                     "PNG 만 덮어쓰면 된다. pivot 은 발 기준점(px), collision_band_px 는 "
                     "셀 하단에서 이만큼만 충돌을 건다(0이면 통과 가능)."),
        "_generated_by": "tools/art/gen_quarter_tiles.py",
        "_palette_source": "docs/art/art-bible.md §3 (하틀랜드 32색)",
        "_tile_px": TILE,
        "_oblique_squash": OBLIQUE_SQUASH,
        "assets": assets,
    }
    atlas_path = out_root / "quarter_atlas.json"
    atlas_path.write_text(json.dumps(atlas, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"계약: {atlas_path.relative_to(ROOT)}  ({len(assets)}개 애셋)")


if __name__ == "__main__":
    main()
