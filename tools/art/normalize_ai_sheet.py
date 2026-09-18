#!/usr/bin/env python3
"""
normalize_ai_sheet.py — AI 도트 생성 툴(PixelLab.ai / 내장 이미지 생성 도구 등) 산출물을
《이슬란드 연대기》 캐릭터 스프라이트 규격(기본: 96×128 셀, 발 기준점 (48,112),
행=방향[down/left/up/right] · 열=프레임, 투명 배경)으로 정규화한다.

배경 문서: docs/art/ai-sprite-pipeline.md, docs/art/art-bible.md(§1·§3),
docs/art/fin-64-production-spec.md(D-140 몸체 64×96/캔버스 96×128/발 기준점 (48,112)),
docs/brd/04-decisions.md D-139·D-140(D-144가 예전 32×48/960×540 기준인 D-130·D-131을 폐기).
레거시 32×48 산출물을 다룰 때는 `--cell 32x48 --pivot 16,43`으로 옛 기본값을 되살릴 수 있다.

의존성: Pillow만 사용(표준 라이브러리 + Pillow). 재실행 가능(매번 전체 재생성,
증분 빌드 아님) — build_item_icon_sheet.py와 동일한 관례를 따른다.

입력 모드
---------
1) sheet  : 한 장의 스프라이트시트 PNG. 행(row)=방향, 열(col)=프레임인
            row-major 그리드로 가정한다(--rows, --cols, --src-cell-w/h로 지정).
2) frames : 폴더 하나. 그 아래 down/ left/ up/ right/ 4개 하위 폴더에
            방향별 개별 프레임 PNG를 파일명 정렬 순서대로 넣어 둔다.
            (PixelLab 등이 방향별 개별 PNG로 내보내는 경우 이 모드를 쓴다.)

핵심 기능
---------
- 배경색 투명화(--transparent-bg, --bg-color, --bg-tolerance)
- 팔레트 양자화(--quantize, --palette-source: art-bible.md 표에서 hex 추출,
  또는 줄바꿈 hex 목록 텍스트 파일)
- 프레임 간 바운딩박스(발 기준점 앵커) 지터 리포트(--out에 <name>_report.json/.txt)
- 발 기준점 정렬: 각 프레임의 불투명 픽셀 바운딩박스 하단-중앙을 목표 셀 안의
  --pivot-x/--pivot-y(또는 --pivot) 좌표로 옮겨 붙인다(비율 유지 축소/확대, NEAREST).
- 4배 확대 미리보기 PNG(그리드선 포함) + 방향별 애니메이션 미리보기 GIF 생성.

예시
----
# PixelLab에서 뽑은 walk 8프레임×4방향 단일 시트(소스 셀 96×128, 마젠타 배경)를 정규화
python3 tools/art/normalize_ai_sheet.py \\
    --mode sheet --input inbox/fin_walk_raw.png \\
    --src-cell-w 96 --src-cell-h 128 --cols 8 --rows 4 \\
    --name chr_fin_walk --transparent-bg --bg-color 255,0,255 \\
    --quantize --out game/assets/sprites/characters/fin/_normalized

# 방향별 폴더로 뽑은 attack 6프레임을 정규화(배경이 이미 투명한 PNG)
python3 tools/art/normalize_ai_sheet.py \\
    --mode frames --input inbox/fin_attack_frames/ \\
    --name chr_fin_attack --out game/assets/sprites/characters/fin/_normalized

# 레거시 32×48/발밑(16,43) 산출물을 정규화할 때만 --cell/--pivot으로 옛 기본값을 되살린다
python3 tools/art/normalize_ai_sheet.py \\
    --mode sheet --input inbox/legacy_walk.png \\
    --src-cell-w 32 --src-cell-h 48 --cols 8 --rows 4 \\
    --cell 32x48 --pivot 16,43 --name chr_fin_walk_legacy --out legacy_out

# 자체 합성 테스트 입력으로 스크립트 동작만 확인(파일 필요 없음)
python3 tools/art/normalize_ai_sheet.py --self-test

전체 옵션은 --help 참고.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
import tempfile
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw

DIRECTIONS = ["down", "left", "up", "right"]

# D-140 기준(96×128 캔버스, 발 기준점 (48,112)). 레거시 32×48/(16,43)은
# --cell 32x48 --pivot 16,43 으로 지정한다(D-144가 D-130·D-131을 폐기).
DEFAULT_CELL_W = 96
DEFAULT_CELL_H = 128
DEFAULT_PIVOT_X = 48
DEFAULT_PIVOT_Y = 112
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
# 입력 로딩
# ---------------------------------------------------------------------------

def load_frames_from_sheet(
    path: Path, src_cell_w: int, src_cell_h: int, cols: int, rows: int
) -> list[list[Image.Image]]:
    """row-major 시트를 [row][col] 프레임 리스트로 분해."""
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


def load_frames_from_folders(path: Path) -> list[list[Image.Image]]:
    grid: list[list[Image.Image]] = []
    counts = []
    for d in DIRECTIONS:
        sub = path / d
        if not sub.is_dir():
            raise FileNotFoundError(f"frames 모드는 {path}/{d}/ 폴더가 있어야 한다")
        files = sorted(sub.glob("*.png"))
        if not files:
            raise FileNotFoundError(f"{sub}에 PNG 프레임이 없다")
        grid.append([Image.open(f).convert("RGBA") for f in files])
        counts.append(len(files))
    if len(set(counts)) != 1:
        print(f"[경고] 방향별 프레임 수가 다르다: {dict(zip(DIRECTIONS, counts))}", file=sys.stderr)
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


# ---------------------------------------------------------------------------
# 메인 파이프라인
# ---------------------------------------------------------------------------

def run_pipeline(args: argparse.Namespace) -> dict:
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.mode == "sheet":
        grid = load_frames_from_sheet(
            Path(args.input), args.src_cell_w, args.src_cell_h, args.cols, args.rows
        )
    else:
        grid = load_frames_from_folders(Path(args.input))

    bg_color = None
    if args.bg_color:
        parts = [int(v) for v in args.bg_color.split(",")]
        if len(parts) != 3:
            raise ValueError("--bg-color는 R,G,B 형식이어야 한다 (예: 255,255,255)")
        bg_color = tuple(parts)

    palette = None
    if args.quantize:
        palette = load_palette(Path(args.palette_source))
        print(f"[정보] 팔레트 {len(palette)}색 로드: {args.palette_source}")

    report: dict = {"directions": {}}
    normalized_grid: list[list[Image.Image]] = []

    for row_idx, row_frames in enumerate(grid):
        direction = DIRECTIONS[row_idx] if row_idx < len(DIRECTIONS) else f"row{row_idx}"
        processed = []
        metrics_before = []
        for frame in row_frames:
            f = frame.convert("RGBA")
            if args.transparent_bg:
                f = make_transparent(f, bg_color, args.bg_tolerance)
            metrics_before.append(frame_metrics(f))
            f = normalize_frame(f, args.cell_w, args.cell_h, args.pivot_x, args.pivot_y)
            if palette is not None:
                f = quantize_to_palette(f, palette)
            processed.append(f)
        normalized_grid.append(processed)

        metrics_after = [frame_metrics(f) for f in processed]
        report["directions"][direction] = {
            "before_normalize": compute_jitter(metrics_before),
            "after_normalize": compute_jitter(metrics_after),
        }

    frame_count = max(len(r) for r in normalized_grid)
    name = args.name
    if not re.search(r"_\d+f$", name):
        name = f"{name}_{frame_count}f"

    sheet = build_output_sheet(normalized_grid, args.cell_w, args.cell_h)
    sheet_path = out_dir / f"{name}.png"
    sheet.save(sheet_path)

    preview = build_preview(sheet, args.cell_w, args.cell_h, args.preview_scale)
    preview_path = out_dir / f"{name}_preview.png"
    preview.save(preview_path)

    gif_paths = []
    if args.make_gif:
        for row_idx, processed in enumerate(normalized_grid):
            direction = DIRECTIONS[row_idx] if row_idx < len(DIRECTIONS) else f"row{row_idx}"
            gif_path = out_dir / f"{name}_preview_{direction}.gif"
            build_gif(processed, args.preview_scale, args.gif_fps, gif_path)
            gif_paths.append(str(gif_path))

    report_path = out_dir / f"{name}_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"[완료] 정규화 시트: {sheet_path} ({sheet.size[0]}×{sheet.size[1]}, {frame_count}프레임×{len(normalized_grid)}방향)")
    print(f"[완료] 미리보기 PNG: {preview_path}")
    for g in gif_paths:
        print(f"[완료] 미리보기 GIF: {g}")
    print(f"[완료] 지터 리포트: {report_path}")
    for direction, d in report["directions"].items():
        pos_j = d["after_normalize"]["max_position_jitter_px"]
        size_j = d["after_normalize"]["max_silhouette_size_jitter_px"]
        flag = "  <-- 실루엣 크기 지터 재검토 필요(임계 2px 초과)" if size_j > 2.0 else ""
        print(f"  - {direction}: 발밑 정렬 후 위치 지터 {pos_j}px / 실루엣 크기 지터 {size_j}px{flag}")

    return {
        "sheet_path": str(sheet_path),
        "preview_path": str(preview_path),
        "gif_paths": gif_paths,
        "report_path": str(report_path),
        "report": report,
    }


# ---------------------------------------------------------------------------
# 자체 합성 테스트 (파일 없이 --self-test로 동작 검증)
# ---------------------------------------------------------------------------

def _draw_dummy_character(
    w: int, h: int, bg: tuple[int, int, int], jitter_x: int, body_color: tuple[int, int, int], size_wobble: int = 0
) -> Image.Image:
    img = Image.new("RGBA", (w, h), (*bg, 255))
    draw = ImageDraw.Draw(img)
    cx = w // 2 + jitter_x
    # 머리(2.5등신 SD 실루엣 흉내: 큰 머리 + 작은 몸). size_wobble로 무기/투구 크기가
    # 프레임마다 들쭉날쭉해지는 상황(실루엣 지터)을 흉내낸다.
    draw.ellipse([cx - 6 - size_wobble, 2, cx + 6 + size_wobble, 14], fill=(*body_color, 255))
    # 몸통
    draw.rectangle([cx - 4, 14, cx + 4, h - 6], fill=(60, 60, 200, 255))
    # 발(피벗 확인용 — 캔버스 하단에서 4px 위)
    draw.rectangle([cx - 4, h - 6, cx + 4, h - 2], fill=(30, 30, 30, 255))
    return img


def self_test() -> None:
    print("=== normalize_ai_sheet.py 자체 합성 테스트 시작 ===")
    tmp_dir = Path(tempfile.mkdtemp(prefix="normalize_ai_sheet_selftest_"))
    src_cell_w, src_cell_h = 16, 24
    cols, rows = 6, 4
    bg = (255, 0, 255)  # 마젠타 배경(투명화 대상)
    body_colors = [(240, 200, 160), (200, 160, 120), (240, 200, 160), (200, 220, 240)]

    sheet = Image.new("RGBA", (cols * src_cell_w, rows * src_cell_h), (*bg, 255))
    for r in range(rows):
        for c in range(cols):
            # row0(down)에는 의도적으로 좌우 위치 지터(±3px)를, row2(up)에는 머리
            # 크기가 프레임마다 커졌다 작아지는 실루엣 지터(±2px)를 넣어 두 지터
            # 리포트가 각각 실제로 이를 잡아내는지 확인한다. 나머지 행은 안정적으로 그린다.
            jitter = (c % 3 - 1) * 3 if r == 0 else 0
            wobble = (c % 3) * 2 if r == 2 else 0
            frame = _draw_dummy_character(src_cell_w, src_cell_h, bg, jitter, body_colors[r], wobble)
            sheet.paste(frame, (c * src_cell_w, r * src_cell_h))
    sheet_path = tmp_dir / "dummy_sheet.png"
    sheet.save(sheet_path)
    print(f"[테스트] 더미 시트 생성: {sheet_path} ({sheet.size[0]}×{sheet.size[1]})")

    out_dir = tmp_dir / "out"
    args = argparse.Namespace(
        mode="sheet",
        input=str(sheet_path),
        src_cell_w=src_cell_w,
        src_cell_h=src_cell_h,
        cols=cols,
        rows=rows,
        name="chr_selftest_walk",
        out=str(out_dir),
        transparent_bg=True,
        bg_color="255,0,255",
        bg_tolerance=24,
        quantize=True,
        palette_source=str(DEFAULT_ART_BIBLE) if DEFAULT_ART_BIBLE.exists() else str(sheet_path),
        cell_w=DEFAULT_CELL_W,
        cell_h=DEFAULT_CELL_H,
        pivot_x=DEFAULT_PIVOT_X,
        pivot_y=DEFAULT_PIVOT_Y,
        preview_scale=4,
        make_gif=True,
        gif_fps=8.0,
    )

    if not DEFAULT_ART_BIBLE.exists():
        print("[테스트] art-bible.md를 찾지 못해 팔레트 양자화는 건너뛴다(경로 문제일 뿐 실패 아님).")
        args.quantize = False

    result = run_pipeline(args)

    # 검증
    sheet_out = Image.open(result["sheet_path"])
    assert sheet_out.size == (cols * DEFAULT_CELL_W, rows * DEFAULT_CELL_H), "출력 시트 크기가 예상과 다르다"
    assert Path(result["preview_path"]).stat().st_size > 0, "미리보기 PNG가 비어 있다"
    for g in result["gif_paths"]:
        assert Path(g).stat().st_size > 0, f"GIF가 비어 있다: {g}"

    down = result["report"]["directions"]["down"]
    up = result["report"]["directions"]["up"]
    left = result["report"]["directions"]["left"]
    down_pos_before = down["before_normalize"]["max_position_jitter_px"]
    down_pos_after = down["after_normalize"]["max_position_jitter_px"]
    left_pos_after = left["after_normalize"]["max_position_jitter_px"]
    up_size_after = up["after_normalize"]["max_silhouette_size_jitter_px"]
    left_size_after = left["after_normalize"]["max_silhouette_size_jitter_px"]
    print(f"[검증] down 행(의도적 위치 지터) 정규화 전 위치지터={down_pos_before}px, 발밑 정렬 후={down_pos_after}px")
    print(f"[검증] up 행(의도적 실루엣 크기 지터) 정규화 후 크기지터={up_size_after}px")
    print(f"[검증] left 행(지터 없음) 정규화 후 위치지터={left_pos_after}px, 크기지터={left_size_after}px")
    assert down_pos_before > 1.0, "의도적으로 넣은 위치 지터가 정규화 전 리포트에서 감지되지 않았다"
    assert down_pos_after < 0.5, "발밑 피벗 정렬 후에도 위치 지터가 남아있다 — normalize_frame 로직 확인 필요"
    assert up_size_after > 1.0, "의도적으로 넣은 실루엣 크기 지터가 정규화 후에도 감지되지 않았다(피벗 정렬로 사라지면 안 되는 지표)"
    assert left_pos_after < 0.5, "지터 없는 방향인데도 정규화 후 위치 오차가 발생했다"
    assert left_size_after < 0.5, "지터 없는 방향인데도 정규화 후 크기 오차가 발생했다"

    # 피벗 자체가 목표 좌표에 정확히 놓였는지 확인(첫 프레임 기준)
    first_down = Image.open(result["sheet_path"]).crop((0, 0, DEFAULT_CELL_W, DEFAULT_CELL_H))
    ax, ay = foot_anchor(first_down)
    print(f"[검증] down 첫 프레임 피벗 좌표 = ({ax:.1f}, {ay:.1f}) (목표 ({DEFAULT_PIVOT_X}, {DEFAULT_PIVOT_Y}))")
    assert abs(ax - DEFAULT_PIVOT_X) <= 1.0, "피벗 X가 목표에서 1px 넘게 벗어났다"
    assert abs(ay - DEFAULT_PIVOT_Y) <= 1.0, "피벗 Y가 목표에서 1px 넘게 벗어났다"

    print(f"=== 자체 테스트 통과. 산출물: {out_dir} ===")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--self-test", action="store_true", help="합성 더미 입력으로 파이프라인 자체 검증만 실행하고 종료")
    p.add_argument("--mode", choices=["sheet", "frames"], help="입력 형식")
    p.add_argument("--input", help="sheet 모드: PNG 시트 경로 / frames 모드: down·left·up·right 하위 폴더를 담은 폴더 경로")
    p.add_argument("--out", default="normalized_out", help="출력 폴더 (기본: ./normalized_out)")
    p.add_argument("--name", default="chr_unnamed", help="출력 파일 접두 이름(네이밍 규칙: chr_<이름>_<동작>[_<프레임수>f])")

    p.add_argument("--src-cell-w", type=int, default=96, help="sheet 모드: 소스 셀 너비(px, 기본 96)")
    p.add_argument("--src-cell-h", type=int, default=128, help="sheet 모드: 소스 셀 높이(px, 기본 128)")
    p.add_argument("--cols", type=int, default=8, help="sheet 모드: 프레임(열) 수")
    p.add_argument("--rows", type=int, default=4, help="sheet 모드: 방향(행) 수 — row-major, 순서는 down/left/up/right 고정")

    p.add_argument("--cell-w", type=int, default=DEFAULT_CELL_W, help="출력 셀 너비(기본 96, D-140/fin-64-production-spec.md)")
    p.add_argument("--cell-h", type=int, default=DEFAULT_CELL_H, help="출력 셀 높이(기본 128, D-140/fin-64-production-spec.md)")
    p.add_argument("--pivot-x", type=int, default=DEFAULT_PIVOT_X, help="출력 셀 안에서 발 기준점 X (기본 48)")
    p.add_argument("--pivot-y", type=int, default=DEFAULT_PIVOT_Y, help="출력 셀 안에서 발 기준점 Y (기본 112)")
    p.add_argument(
        "--cell",
        help="출력 셀 크기를 'WxH' 한 번에 지정(예: 32x48). --cell-w/--cell-h보다 우선. "
        "레거시 32×48 산출물을 다룰 때만 사용",
    )
    p.add_argument(
        "--pivot",
        help="출력 셀 안 발 기준점을 'X,Y' 한 번에 지정(예: 16,43). --pivot-x/--pivot-y보다 우선. "
        "레거시 32×48/(16,43) 산출물을 다룰 때만 사용",
    )

    p.add_argument("--transparent-bg", action="store_true", help="배경색을 투명화한다")
    p.add_argument("--bg-color", help="배경색 R,G,B (생략 시 각 프레임의 (0,0) 픽셀색을 자동 사용)")
    p.add_argument("--bg-tolerance", type=int, default=24, help="배경색 판정 허용 오차(유클리드 거리, 기본 24)")

    p.add_argument("--quantize", action="store_true", help="팔레트 양자화를 적용한다")
    p.add_argument("--palette-source", default=str(DEFAULT_ART_BIBLE), help="hex 팔레트를 추출할 파일(기본: docs/art/art-bible.md)")

    p.add_argument("--preview-scale", type=int, default=4, help="미리보기 PNG/GIF 확대 배율(기본 4배)")
    p.add_argument("--make-gif", dest="make_gif", action="store_true", default=True, help="방향별 미리보기 GIF 생성(기본 켬)")
    p.add_argument("--no-gif", dest="make_gif", action="store_false", help="GIF 생성 생략")
    p.add_argument("--gif-fps", type=float, default=8.0, help="미리보기 GIF 재생 속도(기본 8fps, art-bible.md §4 기준)")

    return p


def apply_cell_pivot_shorthand(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    """--cell WxH / --pivot X,Y 단축 옵션을 --cell-w/-h, --pivot-x/-y에 반영한다."""
    if args.cell:
        m = re.match(r"^(\d+)[xX×](\d+)$", args.cell.strip())
        if not m:
            parser.error(f"--cell 형식이 잘못됐다(예: 32x48): {args.cell!r}")
        args.cell_w, args.cell_h = int(m.group(1)), int(m.group(2))
    if args.pivot:
        parts = args.pivot.strip().split(",")
        if len(parts) != 2 or not all(p.strip().lstrip("-").isdigit() for p in parts):
            parser.error(f"--pivot 형식이 잘못됐다(예: 16,43): {args.pivot!r}")
        args.pivot_x, args.pivot_y = int(parts[0]), int(parts[1])


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    apply_cell_pivot_shorthand(args, parser)

    if args.self_test:
        self_test()
        return 0

    if not args.mode or not args.input:
        parser.error("--mode와 --input은 --self-test가 아닌 한 필수다")

    run_pipeline(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
