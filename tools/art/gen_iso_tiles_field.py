#!/usr/bin/env python3
"""등각(2:1 다이메트릭) placeholder 애셋 생성기 — 필드 지형 (M6-3).

`docs/levels/hartland.md` ⑪절(등각 필드 배치)이 요구하는 신규 애셋 4종을 만든다:
개울 타일(tile_stream), 동굴 입구(cave_entrance), 다리(bridge), 이정표(signpost).
공용 도형은 `iso_shapes.py`(gen_iso_tiles.py 와 공유, 500줄 상한 때문에 분리)를 쓴다.

`gen_iso_tiles.py`가 이미 만든 `iso_atlas.json`을 **읽어서 새 항목만 병합**한다 —
마을 애셋을 다시 그리지 않고, 둘 중 어느 쪽을 먼저/나중에 실행해도 최종 계약은 같다.

사용: python3 tools/art/gen_iso_tiles_field.py [--out game/assets/iso]
"""
import argparse
import json
import random

from iso_shapes import (
    CELL_H, CELL_W, SHADE_SE, SHADE_SW, diamond, ground_shadow, iso_box,
    load_palette, make_ground, new_image, role_colors, shade, speck,
)
from PIL import ImageDraw

ROOT = __import__("pathlib").Path(__file__).resolve().parent.parent.parent
SEED = 20260922  # gen_iso_tiles.py 와 다른 시드 — 같은 팔레트라도 독립된 난수열.


def make_stream(rng, c):
    """개울(64×32 마름모). 연못(tile_water, water_sh)과 구분되게 밝은 water 톤을 쓴다."""
    return make_ground(rng, c, c["water"], 0)


def make_cave_entrance(rng, c):
    """절벽 줄의 gap 칸에 얹는 동굴 입구. cliff_block 과 같은 높이(32)의 흙벽 +
    남서면에 뚫린 어두운 아치. collision_band=0 — 입구 칸 자체는 지나갈 수 있고,
    양옆 cliff_block(band=1.0)이 실제 벽을 맡는다."""
    height = 32
    img = new_image(CELL_W, CELL_H + height)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + height
    top_cy = iso_box(d, bx, by, height, c["dirt_sh"], c["ink"], top_color=c["grass_sh"])
    # 아치: 남서면 위에 뚫린 어두운 반원 - 실루엣이 커 보이도록 셀 폭 대부분을 쓴다.
    arch = [bx - 20, top_cy + 6, bx + 2, top_cy + 6 + 30]
    d.ellipse(arch, fill=shade(c["ink"], 1.9))
    d.ellipse([arch[0] + 3, arch[1] + 3, arch[2] - 3, arch[3]], fill=(6, 8, 10, 255))
    # 반딧불 이끼(hartland.md ⑧ "야간엔 이끼 발광") - 낮 placeholder는 이끼색 점만.
    speck(d, rng, (int(arch[0]) - 4, int(arch[1]) - 6, int(arch[2]) + 6, int(arch[1]) + 4),
          c["moss"], 6)
    return img


def make_bridge(rng, c):
    """개울 위 널빤지 다리 한 칸. collision_band=0(개울 gap 칸에 얹어 통행 가능하게)."""
    img = new_image(CELL_W, CELL_H + 12)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 12
    ground_shadow(d, bx, by)
    deck = diamond(bx, by - 6, 0.95, 0.95)
    d.polygon(deck, fill=c["wood_hi"], outline=c["ink"])
    for i in range(-2, 3):  # 널빤지 결
        offset = i * 9
        d.line([(bx - 24 + offset, by - 6 - offset * 0.5),
                (bx + offset, by - 6 - 12 - offset * 0.5)],
               fill=shade(c["wood_hi"], 0.82), width=2)
    for x, y in ((bx - 24, by - 6), (bx + 24, by - 18)):  # 양끝 난간 기둥
        iso_box(d, x, y, 14, c["wood"], c["ink"], cells=0.1)
    return img


def make_signpost(rng, c):
    """방향 표시 팻말. 순수 장식(collision_band=0) - waypoint_stone(룬 마커석)과
    달리 퀘스트 없이 갈림길에 놓는 흙길 안내용."""
    img = new_image(CELL_W, CELL_H + 54)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + 54
    ground_shadow(d, bx, by)
    post_top = iso_box(d, bx, by, 40, c["wood"], c["ink"], cells=0.12,
                       top_color=shade(c["wood"], 1.1))
    for i, (dx, tilt) in enumerate(((-14, 4), (12, -3))):
        y0 = post_top + 6 + i * 14
        arrow = [(bx + dx * 0.2, y0), (bx + dx, y0 + tilt),
                 (bx + dx, y0 + tilt + 10), (bx + dx * 0.2, y0 + 10)]
        tip = (bx + dx * 1.5, y0 + tilt + 5)
        d.polygon(arrow, fill=c["wood_hi"], outline=c["ink"])
        d.polygon([arrow[1], tip, arrow[2]], fill=c["wood_hi"], outline=c["ink"])
    return img


def make_cliff_ramp(rng, c):
    """절벽 gap 을 잇는 계단식 진입로(D-238, "2개 진입 경로" 우회로용). cliff_block
    과 같은 자리에 놓되 **통과 가능**(collision_band=0) - 층진 실루엣만 흉내 낸
    3단 띠로 "계단"임을 읽히게 한다(정식 3D 계단 대신 placeholder 근사)."""
    height = 32
    img = new_image(CELL_W, CELL_H + height)
    d = ImageDraw.Draw(img)
    bx, by = CELL_W * 0.5, CELL_H * 0.5 + height
    ground_shadow(d, bx, by)
    step_h = height / 3.0
    for i in range(3):  # 위에서부터 3단, 아래로 갈수록 넓고 밝다(내려오는 계단감).
        cells = 0.5 + i * 0.22
        step_by = by - (2 - i) * step_h
        iso_box(d, bx, step_by, step_h, c["dirt_sh"], c["ink"], cells=cells,
                top_color=shade(c["dirt"], 1.0 + i * 0.06))
    return img


def emit(assets, out_root, out_arg, category, name, image, **meta):
    folder = out_root / category
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}.png")
    assets[name] = dict(path=f"{out_arg}/{category}/{name}.png",
                        width=image.width, height=image.height, **meta)
    print(f"  {category}/{name}.png  {image.width}×{image.height}")


def prop(assets, out_root, out_arg, category, name, image, cells=1.0, band=0.0):
    pivot_y = image.height - CELL_H * cells * 0.5
    emit(assets, out_root, out_arg, category, name, image, kind="prop",
         footprint_cells=cells, pivot=[image.width * 0.5, pivot_y], collision_band=band)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="game/assets/iso")
    args = parser.parse_args()
    out_root = ROOT / args.out
    atlas_path = out_root / "iso_atlas.json"
    if not atlas_path.exists():
        raise SystemExit(f"{atlas_path} 가 없다 — 먼저 gen_iso_tiles.py 를 실행해야 한다.")
    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    assets = atlas["assets"]

    rng = random.Random(SEED)
    c = role_colors(load_palette())

    def e(*a, **kw):
        emit(assets, out_root, args.out, *a, **kw)

    def p(*a, **kw):
        prop(assets, out_root, args.out, *a, **kw)

    print("필드 지면 타일:")
    e("ground", "tile_stream", make_stream(rng, c),
      kind="ground_solid", cell=[CELL_W, CELL_H], collision_band=1.0)

    print("필드 소품:")
    p("walls", "cave_entrance", make_cave_entrance(rng, c), cells=1.0, band=0.0)
    p("walls", "cliff_ramp", make_cliff_ramp(rng, c), cells=1.0, band=0.0)
    p("props", "bridge", make_bridge(rng, c))
    p("props", "signpost", make_signpost(rng, c))

    atlas["_generated_by"] = "tools/art/gen_iso_tiles.py + gen_iso_tiles_field.py"
    atlas_path.write_text(json.dumps(atlas, ensure_ascii=False, indent=2) + "\n",
                          encoding="utf-8")
    print(f"계약 갱신: {args.out}/iso_atlas.json  (총 {len(assets)}개 애셋)")


if __name__ == "__main__":
    main()
