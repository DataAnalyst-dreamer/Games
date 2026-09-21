#!/usr/bin/env python3
"""등각 이관 1회용 좌표 변환기 (D-219/D-225, 단계 iso-1).

지금까지의 좌표는 "32 월드단위 정사각 지면"의 직교 좌표였다. 등각으로 가면 **지면은
그대로이고 화면 투영만 바뀐다**(D-221 안 A: 물리를 화면 공간에 둔다). 따라서 기존
좌표를 지면 좌표로 읽고 화면 좌표로 옮겨 적는다.

    screen.x = gx - gy
    screen.y = (gx + gy) / 2

이 식은 Godot TileMapLayer.map_to_local()(ISOMETRIC / DIAMOND_DOWN / 64×32)과 반 칸
오프셋만 다르고 동일하다 - 엔진 출력과 대조해 확정했다.

**변환하지 않는 것**(중요):
  * combat.json / monsters.json / skills.json 의 `*_px` — D-222 로 "지면 거리"로 재해석만
    한다. 값을 건드리면 b1 이 만든 타일 단위 불변(test_unit_scale_invariants.gd)이 깨진다.
  * world_layout_hartland.json — 이미 **타일 좌표 = 격자 좌표**라 그대로 유효하다.
  * elite_spawner.gd 의 SPAWN_POS_GLOBAL_TILE — 타일 좌표 × TILE_SIZE_PROTOTYPE.

사용: python3 tools/iso_convert.py [--check]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
MARKER = ROOT / "game" / "scripts" / "systems" / "iso_math.gd"


def to_screen(gx, gy):
    return gx - gy, (gx + gy) / 2.0


def fmt(value):
    """정수로 떨어지면 정수로 적는다 - 테이블이 지저분해지지 않게."""
    rounded = round(value)
    return str(rounded) if abs(value - rounded) < 1e-9 else f"{value:g}"


def convert_world_objects(check):
    path = GAME / "data" / "world_objects.json"
    text = path.read_text(encoding="utf-8")
    count = 0

    def replace(match):
        nonlocal count
        count += 1
        sx, sy = to_screen(float(match.group(2)), float(match.group(4)))
        return (f'"position": [{match.group(1)}{fmt(sx)}'
                f'{match.group(3)}{fmt(sy)}{match.group(5)}]')

    number = r"-?\d+(?:\.\d+)?"
    pattern = (r'"position":\s*\[(\s*)(' + number + r')(\s*,\s*)('
               + number + r')(\s*)\]')
    text = re.sub(pattern, replace, text)
    print(f"  world_objects.json: {count} 좌표")
    if not check:
        path.write_text(text, encoding="utf-8")
    return count


def convert_main_scene(check):
    path = GAME / "scenes" / "main" / "Main.tscn"
    lines = path.read_text(encoding="utf-8").split("\n")
    out, count = [], 0
    for line in lines:
        match = re.fullmatch(r"position = Vector2\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)", line)
        if match is None:
            out.append(line)
            continue
        sx, sy = to_screen(float(match.group(1)), float(match.group(2)))
        out.append(f"position = Vector2({fmt(sx)}, {fmt(sy)})")
        count += 1
    print(f"  Main.tscn: {count} 노드 좌표")
    if not check:
        path.write_text("\n".join(out), encoding="utf-8")
    return count


def main():
    check = "--check" in sys.argv
    if "IsoMath" not in MARKER.read_text(encoding="utf-8"):
        raise SystemExit("iso_math.gd 가 없다 - iso-1 엔진 작업 후에 돌린다.")
    print("등각 좌표 변환 (지면 -> 화면)" + (" (검사만)" if check else ""))
    total = convert_world_objects(check) + convert_main_scene(check)
    print(f"합계 {total} 좌표")
    print("\n  변환하지 않음: combat/monsters/skills.json(*_px 는 지면 거리로 재해석),")
    print("                 world_layout_hartland.json(이미 격자 좌표),")
    print("                 elite_spawner.gd(타일 좌표 × TILE_SIZE_PROTOTYPE).")
    print("  세이브 v2->v3 변환은 save_manager.gd 가 런타임에 한다.")


if __name__ == "__main__":
    main()
