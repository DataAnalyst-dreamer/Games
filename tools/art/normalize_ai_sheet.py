#!/usr/bin/env python3
"""
normalize_ai_sheet.py — AI 도트 생성 툴(PixelLab.ai / 내장 이미지 생성 도구 등) 산출물을
《이슬란드 연대기》 캐릭터 스프라이트 규격(기본: 96×128 셀, 발 기준점 (48,112),
4방향 행=down/left/up/right · 열=프레임, 투명 배경)으로 정규화한다.

**2026-09-21(D-223, 등각 8방향) 갱신**: `--dirs 8`을 추가했다. 8방향 행 순서는
S,SW,W,NW,N,NE,E,SE — 입력은 **S·SW·W·NW·N 5방향뿐**이고, NE/E/SE는 각각 NW/W/SW를
가로 반전해 스크립트가 만든다(`docs/art/brief-fin-pixellab-8dir.md` §1). 기존 4방향
동작(`--dirs 4`, 기본값)은 변경 없음 — 8방향 지원 추가로 파일이 500줄 상한(D-145)을
넘게 되어 순수 이미지 처리 함수는 `sprite_sheet_lib.py`로 분리했다(D-157 "크게 손대는
다음 단계에서 분할" 조항 적용).

배경 문서: docs/art/ai-sprite-pipeline.md, docs/art/art-bible.md(§1·§3),
docs/art/fin-64-production-spec.md(D-140 몸체 64×96/캔버스 96×128/발 기준점 (48,112)),
docs/specs/isometric-migration-v1.md §4(D-223, 8방향), docs/brd/04-decisions.md
D-139·D-140(D-144가 예전 32×48/960×540 기준인 D-130·D-131을 폐기).
레거시 32×48 산출물을 다룰 때는 `--cell 32x48 --pivot 16,43`으로 옛 기본값을 되살릴 수 있다.

의존성: Pillow만 사용(표준 라이브러리 + Pillow). 재실행 가능(매번 전체 재생성,
증분 빌드 아님) — build_item_icon_sheet.py와 동일한 관례를 따른다.

입력 모드
---------
1) sheet  : 한 장의 스프라이트시트 PNG. 행(row)=방향, 열(col)=프레임인
            row-major 그리드로 가정한다(--rows, --cols, --src-cell-w/h로 지정).
            `--dirs 8`일 때는 --rows 5 고정(5방향을 반전 확장한다 — 8행을 직접
            받는 경로는 아직 만들지 않았다. 필요해지면 별도로 확장한다).
2) frames : 폴더 하나. `--dirs 4`(기본)면 그 아래 down/left/up/right 4개,
            `--dirs 8`이면 s/sw/w/nw/n 5개 하위 폴더에 방향별 개별 프레임 PNG를
            파일명 정렬 순서대로 넣어 둔다(PixelLab 등이 방향별 개별 PNG로
            내보내는 경우 이 모드를 쓴다).

핵심 기능
---------
- 배경색 투명화(--transparent-bg, --bg-color, --bg-tolerance)
- 팔레트 양자화(--quantize, --palette-source: art-bible.md 표에서 hex 추출,
  또는 줄바꿈 hex 목록 텍스트 파일)
- 프레임 간 바운딩박스(발 기준점 앵커) 지터 리포트(--out에 <name>_report.json/.txt)
- 발 기준점 정렬: 각 프레임의 불투명 픽셀 바운딩박스 하단-중앙을 목표 셀 안의
  --pivot-x/--pivot-y(또는 --pivot) 좌표로 옮겨 붙인다(비율 유지 축소/확대, NEAREST).
- 4배 확대 미리보기 PNG(그리드선 포함) + 방향별 애니메이션 미리보기 GIF 생성.
- `--dirs 8`: NW/W/SW 프레임을 가로 반전해 NE/E/SE를 만든 뒤 8행 전부를 위 파이프라인에
  그대로 통과시킨다 — 미러링은 크롭 직후 한 번뿐, 이후 로직은 4방향일 때와 동일하다.

예시
----
# PixelLab에서 뽑은 walk 8프레임×4방향 단일 시트(소스 셀 96×128, 마젠타 배경)를 정규화
python3 tools/art/normalize_ai_sheet.py \\
    --mode sheet --input inbox/fin_walk_raw.png \\
    --src-cell-w 96 --src-cell-h 128 --cols 8 --rows 4 \\
    --name chr_fin_walk --transparent-bg --bg-color 255,0,255 \\
    --quantize --out game/assets/sprites/characters/fin/_normalized

# 등각 8방향 걷기: S/SW/W/NW/N 5행짜리 시트를 받아 NE/E/SE를 반전 생성
python3 tools/art/normalize_ai_sheet.py \\
    --mode sheet --input inbox/fin_iso_walk_raw.png --dirs 8 \\
    --src-cell-w 96 --src-cell-h 128 --cols 8 --rows 5 \\
    --name chr_fin_iso_walk --transparent-bg --bg-color 255,0,255 \\
    --quantize --out game/assets/sprites/characters/fin/_normalized

# 방향별 폴더로 뽑은 attack 6프레임을 정규화(배경이 이미 투명한 PNG)
python3 tools/art/normalize_ai_sheet.py \\
    --mode frames --input inbox/fin_attack_frames/ \\
    --name chr_fin_attack --out game/assets/sprites/characters/fin/_normalized

# 자체 합성 테스트 입력으로 스크립트 동작만 확인(파일 필요 없음) — 4방향·8방향 둘 다 실행
python3 tools/art/normalize_ai_sheet.py --self-test

레거시 32×48/(16,43) 산출물은 --cell 32x48 --pivot 16,43을 덧붙인다. 전체 옵션은 --help 참고.
"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

import sprite_sheet_lib as lib

DIRECTIONS_4 = ["down", "left", "up", "right"]
DIRECTIONS_8_SRC = ["s", "sw", "w", "nw", "n"]  # PixelLab에서 실제로 받는 원화 5장
DIRECTIONS_8_FULL = ["s", "sw", "w", "nw", "n", "ne", "e", "se"]  # 반전 확장 후 8행
MIRROR_SOURCE_8 = {"ne": "nw", "e": "w", "se": "sw"}

# D-140 기준(96×128 캔버스, 발 기준점 (48,112)). 레거시 32×48/(16,43)은
# --cell 32x48 --pivot 16,43 으로 지정한다(D-144가 D-130·D-131을 폐기).
DEFAULT_CELL_W = 96
DEFAULT_CELL_H = 128
DEFAULT_PIVOT_X = 48
DEFAULT_PIVOT_Y = 112


# ---------------------------------------------------------------------------
# 8방향 반전 확장
# ---------------------------------------------------------------------------

def mirror_expand_5_to_8(grid5: list[list[Image.Image]]) -> list[list[Image.Image]]:
    """[S,SW,W,NW,N] 5행을 받아 NE/E/SE를 가로 반전으로 만들고 8행을 반환한다.

    행 순서는 DIRECTIONS_8_FULL(S,SW,W,NW,N,NE,E,SE)과 일치한다. 검을 오른손·
    방패를 왼손에 든 장비 좌우가 반전되므로(character-fin-spec.md §2가 이미 지적한
    문제) 이 함수 자체는 좌우를 되돌리지 않는다 — 반전 결과가 실제로 어색한지는
    브리프 체크리스트(brief-fin-pixellab-8dir.md §4)로 육안 검수한다.
    """
    if len(grid5) != 5:
        raise ValueError(f"8방향 반전 확장은 정확히 5행(S,SW,W,NW,N)이 필요한데 {len(grid5)}행을 받았다")
    idx = {d: i for i, d in enumerate(DIRECTIONS_8_SRC)}
    full = list(grid5)
    for mirrored_dir in ("ne", "e", "se"):
        src_row = grid5[idx[MIRROR_SOURCE_8[mirrored_dir]]]
        full.append([f.transpose(Image.FLIP_LEFT_RIGHT) for f in src_row])
    return full


# ---------------------------------------------------------------------------
# 입력 로딩 (frames 모드 — 방향별 폴더 구조는 여기서만 다룬다)
# ---------------------------------------------------------------------------

def load_frames_from_folders(path: Path, direction_names: list[str]) -> list[list[Image.Image]]:
    grid: list[list[Image.Image]] = []
    counts = []
    for d in direction_names:
        sub = path / d
        if not sub.is_dir():
            raise FileNotFoundError(f"frames 모드는 {path}/{d}/ 폴더가 있어야 한다")
        files = sorted(sub.glob("*.png"))
        if not files:
            raise FileNotFoundError(f"{sub}에 PNG 프레임이 없다")
        grid.append([Image.open(f).convert("RGBA") for f in files])
        counts.append(len(files))
    if len(set(counts)) != 1:
        print(f"[경고] 방향별 프레임 수가 다르다: {dict(zip(direction_names, counts))}", file=sys.stderr)
    return grid


# ---------------------------------------------------------------------------
# 메인 파이프라인
# ---------------------------------------------------------------------------

def _load_grid(args: argparse.Namespace) -> tuple[list[list[Image.Image]], list[str]]:
    """(그리드, 방향 이름 리스트)를 반환한다 — 8방향은 여기서 5→8 반전 확장까지 끝낸다."""
    if args.dirs == 4:
        direction_names = DIRECTIONS_4
        if args.mode == "sheet":
            grid = lib.load_frames_from_sheet(Path(args.input), args.src_cell_w, args.src_cell_h, args.cols, args.rows)
        else:
            grid = load_frames_from_folders(Path(args.input), DIRECTIONS_4)
        return grid, direction_names

    # --dirs 8: 항상 5방향(S,SW,W,NW,N) 입력 → 반전 확장
    if args.mode == "sheet":
        if args.rows != 5:
            raise ValueError("--dirs 8의 sheet 모드는 --rows 5여야 한다(S,SW,W,NW,N 5행을 반전 확장한다)")
        grid5 = lib.load_frames_from_sheet(Path(args.input), args.src_cell_w, args.src_cell_h, args.cols, args.rows)
    else:
        grid5 = load_frames_from_folders(Path(args.input), DIRECTIONS_8_SRC)
    return mirror_expand_5_to_8(grid5), DIRECTIONS_8_FULL


def run_pipeline(args: argparse.Namespace) -> dict:
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    grid, direction_names = _load_grid(args)

    bg_color = None
    if args.bg_color:
        parts = [int(v) for v in args.bg_color.split(",")]
        if len(parts) != 3:
            raise ValueError("--bg-color는 R,G,B 형식이어야 한다 (예: 255,255,255)")
        bg_color = tuple(parts)

    palette = None
    if args.quantize:
        palette = lib.load_palette(Path(args.palette_source))
        print(f"[정보] 팔레트 {len(palette)}색 로드: {args.palette_source}")

    report: dict = {"directions": {}}
    normalized_grid: list[list[Image.Image]] = []

    for row_idx, row_frames in enumerate(grid):
        direction = direction_names[row_idx] if row_idx < len(direction_names) else f"row{row_idx}"
        processed = []
        metrics_before = []
        for frame in row_frames:
            f = frame.convert("RGBA")
            if args.transparent_bg:
                f = lib.make_transparent(f, bg_color, args.bg_tolerance)
            metrics_before.append(lib.frame_metrics(f))
            f = lib.normalize_frame(f, args.cell_w, args.cell_h, args.pivot_x, args.pivot_y)
            if palette is not None:
                f = lib.quantize_to_palette(f, palette)
            processed.append(f)
        normalized_grid.append(processed)

        metrics_after = [lib.frame_metrics(f) for f in processed]
        report["directions"][direction] = {
            "before_normalize": lib.compute_jitter(metrics_before),
            "after_normalize": lib.compute_jitter(metrics_after),
        }

    frame_count = max(len(r) for r in normalized_grid)
    name = args.name
    if not re.search(r"_\d+f$", name):
        name = f"{name}_{frame_count}f"

    sheet = lib.build_output_sheet(normalized_grid, args.cell_w, args.cell_h)
    sheet_path = out_dir / f"{name}.png"
    sheet.save(sheet_path)

    preview = lib.build_preview(sheet, args.cell_w, args.cell_h, args.preview_scale)
    preview_path = out_dir / f"{name}_preview.png"
    preview.save(preview_path)

    gif_paths = []
    if args.make_gif:
        for row_idx, processed in enumerate(normalized_grid):
            direction = direction_names[row_idx] if row_idx < len(direction_names) else f"row{row_idx}"
            gif_path = out_dir / f"{name}_preview_{direction}.gif"
            lib.build_gif(processed, args.preview_scale, args.gif_fps, gif_path)
            gif_paths.append(str(gif_path))

    report_path = out_dir / f"{name}_report.json"
    lib.write_json(report_path, report)

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
    draw.ellipse([cx - 6 - size_wobble, 2, cx + 6 + size_wobble, 14], fill=(*body_color, 255))
    draw.rectangle([cx - 4, 14, cx + 4, h - 6], fill=(60, 60, 200, 255))
    draw.rectangle([cx - 4, h - 6, cx + 4, h - 2], fill=(30, 30, 30, 255))
    return img


def _base_self_test_args(out_dir: Path, sheet_path: Path, cols: int, rows: int, src_cell_w: int, src_cell_h: int) -> argparse.Namespace:
    args = argparse.Namespace(
        mode="sheet",
        input=str(sheet_path),
        src_cell_w=src_cell_w,
        src_cell_h=src_cell_h,
        cols=cols,
        rows=rows,
        dirs=4,
        name="chr_selftest_walk",
        out=str(out_dir),
        transparent_bg=True,
        bg_color="255,0,255",
        bg_tolerance=24,
        quantize=True,
        palette_source=str(lib.DEFAULT_ART_BIBLE) if lib.DEFAULT_ART_BIBLE.exists() else str(sheet_path),
        cell_w=DEFAULT_CELL_W,
        cell_h=DEFAULT_CELL_H,
        pivot_x=DEFAULT_PIVOT_X,
        pivot_y=DEFAULT_PIVOT_Y,
        preview_scale=4,
        make_gif=True,
        gif_fps=8.0,
    )
    if not lib.DEFAULT_ART_BIBLE.exists():
        print("[테스트] art-bible.md를 찾지 못해 팔레트 양자화는 건너뛴다(경로 문제일 뿐 실패 아님).")
        args.quantize = False
    return args


def self_test_4dir(tmp_dir: Path) -> None:
    print("=== normalize_ai_sheet.py 자체 합성 테스트(4방향) 시작 ===")
    src_cell_w, src_cell_h = 16, 24
    cols, rows = 6, 4
    bg = (255, 0, 255)
    body_colors = [(240, 200, 160), (200, 160, 120), (240, 200, 160), (200, 220, 240)]

    sheet = Image.new("RGBA", (cols * src_cell_w, rows * src_cell_h), (*bg, 255))
    for r in range(rows):
        for c in range(cols):
            # row0(down)에는 의도적 위치 지터(±3px), row2(up)에는 실루엣 크기 지터(±2px)를
            # 넣어 두 지터 리포트가 각각 실제로 이를 잡아내는지 확인한다.
            jitter = (c % 3 - 1) * 3 if r == 0 else 0
            wobble = (c % 3) * 2 if r == 2 else 0
            frame = _draw_dummy_character(src_cell_w, src_cell_h, bg, jitter, body_colors[r], wobble)
            sheet.paste(frame, (c * src_cell_w, r * src_cell_h))
    sheet_path = tmp_dir / "dummy_sheet_4dir.png"
    sheet.save(sheet_path)
    print(f"[테스트] 더미 시트 생성: {sheet_path} ({sheet.size[0]}×{sheet.size[1]})")

    out_dir = tmp_dir / "out_4dir"
    args = _base_self_test_args(out_dir, sheet_path, cols, rows, src_cell_w, src_cell_h)
    result = run_pipeline(args)

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

    first_down = Image.open(result["sheet_path"]).crop((0, 0, DEFAULT_CELL_W, DEFAULT_CELL_H))
    ax, ay = lib.foot_anchor(first_down)
    print(f"[검증] down 첫 프레임 피벗 좌표 = ({ax:.1f}, {ay:.1f}) (목표 ({DEFAULT_PIVOT_X}, {DEFAULT_PIVOT_Y}))")
    assert abs(ax - DEFAULT_PIVOT_X) <= 1.0, "피벗 X가 목표에서 1px 넘게 벗어났다"
    assert abs(ay - DEFAULT_PIVOT_Y) <= 1.0, "피벗 Y가 목표에서 1px 넘게 벗어났다"

    print(f"=== 4방향 자체 테스트 통과. 산출물: {out_dir} ===")


def self_test_8dir(tmp_dir: Path) -> None:
    """5행(S,SW,W,NW,N) 더미 시트를 --dirs 8로 돌려 반전 확장·행 순서·시트 크기를 검증한다."""
    print("=== normalize_ai_sheet.py 자체 합성 테스트(8방향) 시작 ===")
    src_cell_w, src_cell_h = 16, 24
    cols, rows = 6, 5  # S,SW,W,NW,N
    bg = (255, 0, 255)
    # 방향마다 팔 길이(size_wobble 대용으로 폭)를 다르게 그려 미러링이 맞게 됐는지 육안/수치로 구분한다.
    body_colors = [(240, 200, 160), (200, 160, 120), (160, 200, 240), (220, 180, 140), (180, 220, 160)]

    sheet = Image.new("RGBA", (cols * src_cell_w, rows * src_cell_h), (*bg, 255))
    for r in range(rows):
        for c in range(cols):
            frame = _draw_dummy_character(src_cell_w, src_cell_h, bg, 0, body_colors[r], size_wobble=0)
            sheet.paste(frame, (c * src_cell_w, r * src_cell_h))
    sheet_path = tmp_dir / "dummy_sheet_8dir.png"
    sheet.save(sheet_path)
    print(f"[테스트] 더미 시트 생성(S,SW,W,NW,N만): {sheet_path} ({sheet.size[0]}×{sheet.size[1]})")

    out_dir = tmp_dir / "out_8dir"
    args = _base_self_test_args(out_dir, sheet_path, cols, rows, src_cell_w, src_cell_h)
    args.dirs = 8
    args.name = "chr_selftest_iso_walk"
    result = run_pipeline(args)

    sheet_out = Image.open(result["sheet_path"])
    assert sheet_out.size == (cols * DEFAULT_CELL_W, 8 * DEFAULT_CELL_H), "8방향 출력 시트 크기가 예상과 다르다(8행이어야 한다)"
    assert list(result["report"]["directions"].keys()) == DIRECTIONS_8_FULL, (
        f"행 순서가 S,SW,W,NW,N,NE,E,SE가 아니다: {list(result['report']['directions'].keys())}"
    )

    # 미러링 검증: NE/E/SE 실루엣 bbox 크기가 원본 NW/W/SW와 같아야 한다(가로 반전은 크기를 바꾸지 않는다).
    for mirrored, src in MIRROR_SOURCE_8.items():
        mirrored_size = result["report"]["directions"][mirrored]["after_normalize"]["mean_bbox_size_px"]
        src_size = result["report"]["directions"][src]["after_normalize"]["mean_bbox_size_px"]
        print(f"[검증] {mirrored}(반전) bbox={mirrored_size} vs {src}(원본) bbox={src_size}")
        assert mirrored_size == src_size, f"{mirrored}가 {src}의 가로 반전이 아닌 것 같다(bbox 크기 불일치)"

    for g in result["gif_paths"]:
        assert Path(g).stat().st_size > 0, f"GIF가 비어 있다: {g}"

    print(f"=== 8방향 자체 테스트 통과. 산출물: {out_dir} ===")


def self_test() -> None:
    tmp_dir = Path(tempfile.mkdtemp(prefix="normalize_ai_sheet_selftest_"))
    self_test_4dir(tmp_dir)
    print()
    self_test_8dir(tmp_dir)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--self-test", action="store_true", help="합성 더미 입력으로 파이프라인 자체 검증만 실행하고 종료(4방향·8방향 둘 다)")
    p.add_argument("--mode", choices=["sheet", "frames"], help="입력 형식")
    p.add_argument("--input", help="sheet 모드: PNG 시트 경로 / frames 모드: 방향별 하위 폴더를 담은 폴더 경로")
    p.add_argument("--out", default="normalized_out", help="출력 폴더 (기본: ./normalized_out)")
    p.add_argument("--name", default="chr_unnamed", help="출력 파일 접두 이름(네이밍 규칙: chr_<이름>_<동작>[_<프레임수>f])")
    p.add_argument(
        "--dirs", type=int, choices=[4, 8], default=4,
        help="방향 수(기본 4=down/left/up/right). 8=등각 S,SW,W,NW,N,NE,E,SE — 입력은 S,SW,W,NW,N 5개뿐이고 "
        "NE/E/SE는 NW/W/SW를 가로 반전해 만든다(sheet 모드는 --rows 5 필수, frames 모드는 s/sw/w/nw/n 5폴더 필수)",
    )

    p.add_argument("--src-cell-w", type=int, default=96, help="sheet 모드: 소스 셀 너비(px, 기본 96)")
    p.add_argument("--src-cell-h", type=int, default=128, help="sheet 모드: 소스 셀 높이(px, 기본 128)")
    p.add_argument("--cols", type=int, default=8, help="sheet 모드: 프레임(열) 수")
    p.add_argument(
        "--rows", type=int, default=4,
        help="sheet 모드: 방향(행) 수 — row-major. --dirs 4면 4(down/left/up/right), --dirs 8이면 반드시 5(S/SW/W/NW/N)",
    )

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
    p.add_argument("--palette-source", default=str(lib.DEFAULT_ART_BIBLE), help="hex 팔레트를 추출할 파일(기본: docs/art/art-bible.md)")

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


def validate_dirs_args(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    if args.dirs == 8 and args.mode == "sheet" and args.rows != 5:
        parser.error("--dirs 8의 sheet 모드는 --rows 5여야 한다(S,SW,W,NW,N 5행 → NE/E/SE 반전 확장)")


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    apply_cell_pivot_shorthand(args, parser)

    if args.self_test:
        self_test()
        return 0

    if not args.mode or not args.input:
        parser.error("--mode와 --input은 --self-test가 아닌 한 필수다")
    validate_dirs_args(args, parser)

    run_pipeline(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
