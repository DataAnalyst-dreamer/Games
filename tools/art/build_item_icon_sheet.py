#!/usr/bin/env python3
"""
아이템 아이콘 아틀라스 빌드 스크립트.

game/data/item_icons.json을 읽어 각 아이콘(16×16 표준)을 모은다:
1. 원본을 로드
2. NEAREST로 16×16으로 리사이징
3. 한 개의 PNG 아틀라스로 합치기
4. 좌표를 item_icons_atlas.json에 저장

재실행 가능 스크립트(증분 빌드 아님, 매번 전체 재생성).
"""

import json
import os
import sys
from pathlib import Path
from PIL import Image

# 경로 설정
GAME_ROOT = Path("/home/user/Games/game")
DATA_DIR = GAME_ROOT / "data"
ICONS_JSON = DATA_DIR / "item_icons.json"

ASSETS_DIR = GAME_ROOT / "assets"
SPRITES_DIR = ASSETS_DIR / "sprites" / "items"
THIRD_PARTY = ASSETS_DIR / "third_party"

OUTPUT_ATLAS = SPRITES_DIR / "item_icons.png"
OUTPUT_COORDS = SPRITES_DIR / "item_icons_atlas.json"

# 아틀라스 설정
ICON_SIZE = 16  # 16x16 픽셀
PADDING = 1  # 아이콘 간 패딩 (선택사항)
COLUMNS = 16  # 한 줄에 16개 아이콘
ICON_SIZE_WITH_PADDING = ICON_SIZE + PADDING


def resolve_godot_path(godot_path: str) -> Path:
    """Godot res:// 경로를 실제 파일 경로로 변환."""
    if godot_path.startswith("res://"):
        return GAME_ROOT / godot_path[6:]
    return Path(godot_path)


def load_and_resize_icon(path: Path) -> Image.Image:
    """이미지를 로드해 16×16으로 리사이징 (NEAREST)."""
    try:
        img = Image.open(path)
        # NEAREST 필터로 리사이징 (도트 보존)
        if img.size != (ICON_SIZE, ICON_SIZE):
            img = img.resize((ICON_SIZE, ICON_SIZE), Image.NEAREST)
        return img.convert("RGBA")  # RGBA로 변환
    except Exception as e:
        print(f"Error loading {path}: {e}")
        # 폴백: 투명한 기본 16x16 이미지 반환
        return Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))


def build_atlas():
    """아이콘 아틀라스 빌드."""
    print(f"Reading {ICONS_JSON}...")
    with open(ICONS_JSON, "r", encoding="utf-8") as f:
        icons_data = json.load(f)

    # _comment 제외
    items = {k: v for k, v in icons_data.items() if not k.startswith("_")}
    print(f"Found {len(items)} items")

    # 출력 디렉터리 생성
    SPRITES_DIR.mkdir(parents=True, exist_ok=True)

    # 아이콘 로드
    icon_images = []
    item_ids = []
    failed_items = []

    for item_id, icon_info in items.items():
        path_str = icon_info.get("path", "")
        resolved_path = resolve_godot_path(path_str)

        if not resolved_path.exists():
            print(f"Warning: {item_id} icon not found at {resolved_path}")
            failed_items.append(item_id)
            # 폴백 이미지 추가
            icon_images.append(Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0)))
        else:
            img = load_and_resize_icon(resolved_path)
            icon_images.append(img)

        item_ids.append(item_id)

    print(f"Loaded {len(icon_images)} icons ({len(failed_items)} missing)")

    # 아틀라스 크기 계산
    num_icons = len(icon_images)
    rows = (num_icons + COLUMNS - 1) // COLUMNS
    atlas_width = COLUMNS * ICON_SIZE_WITH_PADDING
    atlas_height = rows * ICON_SIZE_WITH_PADDING

    print(f"Atlas size: {atlas_width}×{atlas_height} ({COLUMNS} columns, {rows} rows)")

    # 아틀라스 생성 (투명 배경)
    atlas = Image.new("RGBA", (atlas_width, atlas_height), (0, 0, 0, 0))

    # 좌표 매핑
    coords = {}

    for idx, (item_id, icon_img) in enumerate(zip(item_ids, icon_images)):
        col = idx % COLUMNS
        row = idx // COLUMNS

        x = col * ICON_SIZE_WITH_PADDING
        y = row * ICON_SIZE_WITH_PADDING

        # 아틀라스에 붙여넣기
        atlas.paste(icon_img, (x, y), icon_img)

        # 좌표 기록 (시작점과 크기)
        coords[item_id] = {
            "x": x,
            "y": y,
            "w": ICON_SIZE,
            "h": ICON_SIZE
        }

    # 아틀라스 저장
    print(f"Saving atlas to {OUTPUT_ATLAS}...")
    atlas.save(OUTPUT_ATLAS, "PNG")

    # 좌표 JSON 저장
    print(f"Saving coords to {OUTPUT_COORDS}...")
    atlas_data = {
        "atlas": str(OUTPUT_ATLAS),
        "icon_size": ICON_SIZE,
        "padding": PADDING,
        "columns": COLUMNS,
        "rows": rows,
        "width": atlas_width,
        "height": atlas_height,
        "icons": coords
    }

    with open(OUTPUT_COORDS, "w", encoding="utf-8") as f:
        json.dump(atlas_data, f, indent=2, ensure_ascii=False)

    # 요약
    print("\n=== Build Complete ===")
    print(f"Atlas: {OUTPUT_ATLAS}")
    print(f"  Size: {atlas_width}×{atlas_height}")
    print(f"  Icons: {num_icons}")
    print(f"Coordinates: {OUTPUT_COORDS}")
    if failed_items:
        print(f"Failed items ({len(failed_items)}): {', '.join(failed_items)}")

    return True


if __name__ == "__main__":
    try:
        build_atlas()
    except Exception as e:
        print(f"Build failed: {e}", file=sys.stderr)
        sys.exit(1)
