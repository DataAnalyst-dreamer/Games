#!/usr/bin/env python3
"""하틀랜드 필드 레이아웃 정합성 검사 (M6-3, docs/levels/hartland.md ⑪).

`game/data/world_layout_hartland.json` 의 장애물(절벽 행 · 물/개울 rect · 충돌이 있는
소품)을 격자로 래스터화하고, 플레이어 시작점(0,0)에서
`game/data/world_objects.json` 의 모든 퀘스트 목표 + `Main.tscn` 고정 몬스터 스폰
10곳까지 8방향 BFS 로 도달 가능한지, 그리고 그 좌표들이 장애물 칸에 묻히지 않았는지
확인한다. Godot 없이 도는 오프라인 게이트로 `tools/qa/validate_tables.py` 가
`validate_layout()`을 불러 쓴다(`tests/smoke/smoke_quarter_view_b.gd` §1 의 런타임
물리 검사와 같은 불변을 빌드 전에 잡는다 — 그 스모크는 실제 Godot 물리 쿼리라 더
정확하지만 느리고, 이 스크립트는 빠른 사전 게이트다).

좌표 변환은 `game/scripts/systems/iso_math.gd`(IsoMath.to_ground/cell_to_screen)와
정확히 같은 공식이다 - 그쪽이 바뀌면 이 상수·공식도 같이 맞출 것.

ponytail 단순화(알려진 한계):
  * 여러 칸을 덮는 소품(house_a/smithy, footprint_cells=2.0)도 배치 칸 1개만 막는
    것으로 취급한다. 실제로는 그보다 넓게 막지만, 이 검사는 "완전히 갇혔는가"를
    보는 성긴 사전 게이트라 과소평가(더 뚫려 보임)는 있어도 과대평가(거짓 FAIL)는
    없다 — 필요해지면 footprint_cells 만큼 정사각으로 넓히면 된다.
  * 8방향 인접 BFS — 실제 이동은 연속 공간이라 대각선 한 칸 틈도 통과 가능하므로
    합리적 근사다.

사용: python3 tools/qa/validate_layout.py [--data-dir game/data]
종료 코드: 0 = 통과, 1 = 하나 이상 위반.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

TILE_PX = 32.0  # Tuning.TILE_SIZE_PROTOTYPE

## Main.tscn 에 고정 배치된 몬스터/액터 화면 좌표(스폰 존, docs/levels/hartland.md ⑤·
## world.gd 배치와 별개로 씬에 직접 박혀 있다). world_objects.json 처럼 파일로 관리되지
## 않아 여기 상수로 옮겨 둔다 — Main.tscn 이 바뀌면 같이 갱신할 것(완료 보고 TODO).
FIXED_ACTOR_SCREEN_POS: Dict[str, Tuple[float, float]] = {
    "Player(스폰)": (0.0, 0.0),
    "Slime1": (200.0, 20.0), "Slime2": (-200.0, -40.0), "Slime3": (-140.0, 110.0),
    "HornRabbit1": (360.0, 120.0), "HornRabbit2": (-420.0, -90.0),
    "Mushroom1": (-340.0, 170.0),
    "GoblinScout1": (600.0, 140.0), "GoblinScout2": (-320.0, -280.0),
    "EliteGoblinCaptain1": (220.0, 390.0), "EliteBunchiSpawn1": (-220.0, -390.0),
}


def to_ground(x: float, y: float) -> Tuple[float, float]:
    return (x * 0.5 + y, y - x * 0.5)


def screen_to_cell(x: float, y: float) -> Tuple[int, int]:
    gx, gy = to_ground(x - TILE_PX, y - TILE_PX * 0.5)
    return (round(gx / TILE_PX), round(gy / TILE_PX))


def _load_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _collision_band(atlas_assets: Dict[str, Any], asset: str) -> float:
    return float(atlas_assets.get(asset, {}).get("collision_band", 0.0))


def blocked_cells(layout: Dict[str, Any], atlas_assets: Dict[str, Any]) -> Set[Tuple[int, int]]:
    """world.gd 가 실제 콜리전을 거는 칸과 같은 규칙(cliffs 전부 / water 는
    collision_band>0 인 asset만 / props 는 collision_band>0 인 것만)으로 래스터화."""
    blocked: Set[Tuple[int, int]] = set()
    for cliff in layout.get("cliffs", []):
        x0 = int(cliff["x"])
        row = int(cliff["front_y"])
        length = max(1, int(cliff.get("length", 1)))
        for i in range(length):
            blocked.add((x0 + i, row))
    for water in layout.get("water", []):
        asset = str(water.get("asset", "tile_water"))
        if _collision_band(atlas_assets, asset) <= 0.0:
            continue
        rect = water.get("rect", [])
        if len(rect) != 4:
            continue
        rx, ry, rw, rh = (int(v) for v in rect)
        for dy in range(rh):
            for dx in range(rw):
                blocked.add((rx + dx, ry + dy))
    for prop in layout.get("props", []):
        asset = str(prop.get("asset", ""))
        if _collision_band(atlas_assets, asset) <= 0.0:
            continue
        tile = prop.get("tile", [0, 0])
        blocked.add((int(tile[0]), int(tile[1])))
    return blocked


def _bfs_reachable(start: Tuple[int, int], blocked: Set[Tuple[int, int]],
                    bounds: Tuple[int, int, int, int]) -> Set[Tuple[int, int]]:
    min_x, min_y, max_x, max_y = bounds
    seen: Set[Tuple[int, int]] = {start}
    queue = deque([start])
    neighbors = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in neighbors:
            nxt = (cx + dx, cy + dy)
            if nxt in seen or nxt in blocked:
                continue
            nx, ny = nxt
            if not (min_x <= nx <= max_x and min_y <= ny <= max_y):
                continue
            seen.add(nxt)
            queue.append(nxt)
    return seen


def validate_layout(data_dir: Path) -> List[str]:
    """오류 메시지 목록을 돌려준다(비어 있으면 통과). data_dir 은 game/data."""
    errors: List[str] = []
    layout = _load_json(data_dir / "world_layout_hartland.json")
    world_objects = _load_json(data_dir / "world_objects.json")
    atlas = _load_json(data_dir.parent / "assets" / "iso" / "iso_atlas.json")
    if not layout:
        errors.append("world_layout_hartland.json 을 읽지 못했다")
        return errors
    if not world_objects:
        errors.append("world_objects.json 을 읽지 못했다")
        return errors
    atlas_assets = atlas.get("assets", {})

    blocked = blocked_cells(layout, atlas_assets)

    targets: Dict[str, Tuple[int, int]] = {}
    for object_id, entry in world_objects.items():
        if object_id.startswith("_") or not isinstance(entry, dict):
            continue
        position = entry.get("position")
        if not isinstance(position, list) or len(position) != 2:
            continue
        targets[f"world_objects.{object_id}"] = screen_to_cell(float(position[0]), float(position[1]))
    for name, (sx, sy) in FIXED_ACTOR_SCREEN_POS.items():
        targets[f"Main.tscn:{name}"] = screen_to_cell(sx, sy)

    start = targets["Main.tscn:Player(스폰)"]

    # 1) 오브젝트 묻힘 — 좌표 자체가 장애물 칸인가(smoke_quarter_view_b.gd §1 과 같은 불변).
    buried = [f"{label}{cell}" for label, cell in targets.items() if cell in blocked]
    if buried:
        errors.append(f"장애물 칸에 묻힌 좌표: {', '.join(sorted(buried))}")

    # 2) 도달성 — 플레이어 시작점에서 8방향 BFS.
    xs = [c[0] for c in list(targets.values()) + list(blocked)] or [0]
    ys = [c[1] for c in list(targets.values()) + list(blocked)] or [0]
    margin = 5
    bounds = (min(xs) - margin, min(ys) - margin, max(xs) + margin, max(ys) + margin)
    reachable = _bfs_reachable(start, blocked, bounds)
    # 묻힌 좌표(장애물 칸 그 자체)는 도달 판정이 무의미하다 - 1번에서 이미 보고했으니
    # 여기서는 제외해 중복 보고하지 않는다.
    unreachable = [f"{label}{cell}" for label, cell in targets.items()
                   if cell not in blocked and cell not in reachable]
    if unreachable:
        errors.append(f"플레이어 시작점 {start} 에서 도달 불가: {', '.join(sorted(unreachable))}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default=None, help="game/data 경로 (기본: 이 스크립트 기준 ../../game/data)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    data_dir = Path(args.data_dir) if args.data_dir else (script_dir / ".." / ".." / "game" / "data")
    data_dir = data_dir.resolve()

    print(f"[validate_layout] data dir = {data_dir}")
    errors = validate_layout(data_dir)
    if errors:
        print(f"\n오류 {len(errors)}건:")
        for e in errors:
            print(f"  - {e}")
        print("\nFAIL")
        return 1
    print("PASS - 도달성·오브젝트 묻힘 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
