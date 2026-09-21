#!/usr/bin/env python3
"""
sprite_sheet_lib.py — normalize_ai_sheet.py 가 쓰는 순수 이미지 처리 함수 모음.

8방향 지원(2026-09-21, `docs/art/brief-fin-pixellab-8dir.md`) 작업으로
`normalize_ai_sheet.py`가 500줄 상한(D-145)을 넘게 되어 분리했다(D-157 "크게 손대는
다음 단계에서 분할" 조항 적용). 이 파일은 팔레트/배경투명화/바운딩박스·지터 계산/
발 기준점 정렬/시트·미리보기·GIF 빌드처럼 방향 개수(4 또는 8)와 무관한 순수 함수만
담는다. 방향 상수·CLI·8방향 반전 확장·self-test는 `normalize_ai_sheet.py`에 남아 있다.

의존성: Pillow만 사용(표준 라이브러리 + Pillow).
"""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

DEFAULT_ART_BIBLE = Path(__file__).resolve().parents[2] / "docs" / "art" / "art-bible.md"
HEX_RE = re.compile(r"#([0-9a-fA-F]{6})\b")


# ---------------------------------------------------------------------------
# 팔레트
# ---------------------------------------------------------------------------

def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def load_palette(path: Path) -> list[tuple[int, int, int]]:
    """art-bible.md의 hex 표 또는 줄바꿈 hex 목록 텍스트에서 팔레트를 읽는다."""
    text = path.read_text(encoding="utf-8")
    hexes = HEX_RE.findall(text)
    seen: dict[str, None] = {}
    for h in hexes:
        seen.setdefault(h.lower(), None)
    palette = [hex_to_rgb(h) for h in seen]
    if not palette:
        raise ValueError(f"{path}에서 hex 색상을 하나도 찾지 못했다")
    return palette


def nearest_color(rgb: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    r, g, b = rgb
    best = palette[0]
    best_d = math.inf
    for pr, pg, pb in palette:
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < best_d:
            best_d = d
            best = (pr, pg, pb)
    return best


def quantize_to_palette(img: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    """알파>0인 픽셀만 최근접 팔레트 색으로 스냅(외곽선·투명 배경은 그대로)."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            snapped = cache.get(key)
            if snapped is None:
                snapped = nearest_color(key, palette)
                cache[key] = snapped
            px[x, y] = (snapped[0], snapped[1], snapped[2], a)
    return img


# ---------------------------------------------------------------------------
# 배경 투명화
# ---------------------------------------------------------------------------

def make_transparent(img: Image.Image, bg_color: tuple[int, int, int] | None, tolerance: int) -> Image.Image:
    img = img.convert("RGBA")
    if bg_color is None:
        bg_color = img.getpixel((0, 0))[:3]
    px = img.load()
    w, h = img.size
    tol2 = tolerance * tolerance
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            d2 = (r - bg_color[0]) ** 2 + (g - bg_color[1]) ** 2 + (b - bg_color[2]) ** 2
            if d2 <= tol2:
                px[x, y] = (r, g, b, 0)
    return img


# ---------------------------------------------------------------------------
# 바운딩박스 / 지터
# ---------------------------------------------------------------------------

def alpha_bbox(img: Image.Image, threshold: int = 10) -> tuple[int, int, int, int] | None:
    """알파>threshold 픽셀의 (left, top, right, bottom) — bottom/right는 exclusive."""
    alpha = img.split()[-1]
    bbox = alpha.point(lambda a: 255 if a > threshold else 0).getbbox()
    return bbox


def foot_anchor(img: Image.Image) -> tuple[float, float]:
    bbox = alpha_bbox(img)
    if bbox is None:
        w, h = img.size
        return (w / 2.0, float(h))
    left, top, right, bottom = bbox
    return ((left + right) / 2.0, float(bottom))


def frame_metrics(img: Image.Image) -> tuple[tuple[float, float], float, float]:
    """(발밑 앵커(x,y), 실루엣 bbox 너비, 높이) — 셋 다 지터 판정에 쓴다."""
    bbox = alpha_bbox(img)
    if bbox is None:
        w, h = img.size
        return (w / 2.0, float(h)), 0.0, 0.0
    left, top, right, bottom = bbox
    return ((left + right) / 2.0, float(bottom)), float(right - left), float(bottom - top)


def compute_jitter(metrics: list[tuple[tuple[float, float], float, float]]) -> dict:
    """anchor(위치) 지터와 bbox 크기(실루엣 형태) 지터를 함께 리포트한다.

    피벗 정렬 후에는 anchor 지터가 항상 0에 가까워지는 것이 정상(발밑을 강제로
    맞췄으므로)이지만, size 지터는 정렬로 사라지지 않는다 — 옷·무기 실루엣이
    프레임마다 커졌다 작아졌다 하는(형태 불안정) 문제를 잡아내는 지표는 이쪽이다.
    """
    if not metrics:
        return {"frame_count": 0}
    anchors = [m[0] for m in metrics]
    widths = [m[1] for m in metrics]
    heights = [m[2] for m in metrics]
    xs = [a[0] for a in anchors]
    ys = [a[1] for a in anchors]
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)
    mean_w = sum(widths) / len(widths)
    mean_h = sum(heights) / len(heights)
    max_pos_dev = max(math.hypot(x - mean_x, y - mean_y) for x, y in anchors)
    max_size_dev = max(math.hypot(w - mean_w, h - mean_h) for w, h in zip(widths, heights))
    return {
        "frame_count": len(metrics),
        "anchors_px": [[round(x, 1), round(y, 1)] for x, y in anchors],
        "mean_anchor_px": [round(mean_x, 1), round(mean_y, 1)],
        "max_position_jitter_px": round(max_pos_dev, 2),
        "bbox_sizes_px": [[round(w, 1), round(h, 1)] for w, h in zip(widths, heights)],
        "mean_bbox_size_px": [round(mean_w, 1), round(mean_h, 1)],
        "max_silhouette_size_jitter_px": round(max_size_dev, 2),
    }


# ---------------------------------------------------------------------------
# 셀 정규화 (리사이즈 + 발밑 피벗 정렬)
# ---------------------------------------------------------------------------

def normalize_frame(
    frame: Image.Image,
    cell_w: int,
    cell_h: int,
    pivot_x: int,
    pivot_y: int,
) -> Image.Image:
    frame = frame.convert("RGBA")
    src_w, src_h = frame.size
    anchor_x, anchor_y = foot_anchor(frame)

    scale = min(cell_w / src_w, cell_h / src_h)
    new_w = max(1, round(src_w * scale))
    new_h = max(1, round(src_h * scale))
    resized = frame.resize((new_w, new_h), Image.NEAREST)

    anchor_x_scaled = anchor_x * scale
    anchor_y_scaled = anchor_y * scale

    offset_x = round(pivot_x - anchor_x_scaled)
    offset_y = round(pivot_y - anchor_y_scaled)

    canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    canvas.paste(resized, (offset_x, offset_y), resized)
    return canvas


# ---------------------------------------------------------------------------
# 입력 로딩 (그리드 분해만 — frames 모드는 방향별 폴더 구조라 normalize_ai_sheet.py에 둔다)
# ---------------------------------------------------------------------------

def load_frames_from_sheet(
    path: Path, src_cell_w: int, src_cell_h: int, cols: int, rows: int
) -> list[list[Image.Image]]:
    """row-major 시트를 [row][col] 프레임 리스트로 분해."""
    import sys

    sheet = Image.open(path).convert("RGBA")
    expected_w, expected_h = cols * src_cell_w, rows * src_cell_h
    if sheet.size != (expected_w, expected_h):
        print(
            f"[경고] 시트 크기 {sheet.size}가 기대값 {(expected_w, expected_h)}"
            f"(cols={cols}×src_cell_w={src_cell_w}, rows={rows}×src_cell_h={src_cell_h})와"
            " 다르다 — 그리드 해석이 어긋났을 수 있으니 --src-cell-w/h, --cols, --rows를 확인할 것.",
            file=sys.stderr,
        )
    grid: list[list[Image.Image]] = []
    for r in range(rows):
        row_frames = []
        for c in range(cols):
            box = (c * src_cell_w, r * src_cell_h, (c + 1) * src_cell_w, (r + 1) * src_cell_h)
            row_frames.append(sheet.crop(box))
        grid.append(row_frames)
    return grid


# ---------------------------------------------------------------------------
# 출력: 정규화 시트 / 미리보기 PNG / GIF
# ---------------------------------------------------------------------------

def build_output_sheet(grid: list[list[Image.Image]], cell_w: int, cell_h: int) -> Image.Image:
    rows = len(grid)
    cols = max(len(r) for r in grid)
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (0, 0, 0, 0))
    for r, row_frames in enumerate(grid):
        for c, frame in enumerate(row_frames):
            sheet.paste(frame, (c * cell_w, r * cell_h), frame)
    return sheet


def build_preview(sheet: Image.Image, cell_w: int, cell_h: int, scale: int) -> Image.Image:
    big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    grid_color = (255, 0, 255, 160)
    for x in range(0, big.width + 1, cell_w * scale):
        draw.line([(x, 0), (x, big.height)], fill=grid_color, width=1)
    for y in range(0, big.height + 1, cell_h * scale):
        draw.line([(0, y), (big.width, y)], fill=grid_color, width=1)
    return big


def build_gif(frames: list[Image.Image], scale: int, fps: float, out_path: Path) -> None:
    if not frames:
        return
    big_frames = [f.resize((f.width * scale, f.height * scale), Image.NEAREST) for f in frames]
    duration_ms = max(1, round(1000.0 / fps))
    # GIF는 완전 투명을 지원하지 않는 뷰어가 많으므로 옅은 회색 배경에 합성
    bg = Image.new("RGBA", big_frames[0].size, (230, 230, 230, 255))
    composited = []
    for f in big_frames:
        frame_bg = bg.copy()
        frame_bg.paste(f, (0, 0), f)
        composited.append(frame_bg.convert("P", palette=Image.ADAPTIVE, colors=64))
    composited[0].save(
        out_path,
        save_all=True,
        append_images=composited[1:],
        duration=duration_ms,
        loop=0,
    )


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
