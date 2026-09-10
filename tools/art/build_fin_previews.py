#!/usr/bin/env python3
"""
핀 스프라이트 시안 검토용 미리보기 이미지 빌드.

`tools/art/build_fin_sprite.py` 실행 후 이 스크립트를 실행한다. 게임에서 실제로
쓰이는 파일은 아니며(대조표·GIF는 검토 전용), `docs/art/preview/`에만 출력한다.

산출물:
- fin-sheet-preview.png : 4개 시트 전체를 4배 확대 + 격자/라벨 대조표
- fin-directions-preview.png : idle 프레임0 기준 4방향을 8배 확대 나란히 배치
- fin-walk.gif / fin-attack.gif : down 방향 재생 GIF(4배 확대, 실제 fps)
- fin-size-comparison.png : 기존 Knight(16x16) vs 신규 핀(32x48) 같은 배율 비교
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

GAME_ROOT = Path("/home/user/Games/game")
FIN_DIR = GAME_ROOT / "assets" / "sprites" / "characters" / "fin"
KNIGHT_SHEET = GAME_ROOT / "assets" / "third_party" / "ninja_adventure" / "Actor" / "Character" / "Knight" / "SpriteSheet.png"
PREVIEW_DIR = Path("/home/user/Games/docs/art/preview")
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

CELL_W, CELL_H = 32, 48
ROW_ORDER = ["down", "left", "up", "right"]

BG = (30, 34, 34, 255)
GRID = (70, 78, 78, 255)
LABEL = (235, 230, 210, 255)


def _font(size):
    for candidate in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def build_sheet_preview():
    specs = [
        ("fin_idle.png", 4),
        ("fin_walk.png", 8),
        ("fin_attack.png", 6),
        ("fin_hurt.png", 2),
    ]
    scale = 4
    font = _font(12)
    label_w = 70
    pad = 10
    max_cols = 8
    cell_w, cell_h = CELL_W * scale, CELL_H * scale

    block_imgs = []
    for filename, n in specs:
        sheet = Image.open(FIN_DIR / filename).convert("RGBA")
        w = label_w + n * cell_w + pad
        h = len(ROW_ORDER) * (cell_h + 14) + 24
        block = Image.new("RGBA", (w, h), BG)
        d = ImageDraw.Draw(block)
        d.text((pad, 4), f"{filename}  ({n} frames x 4 dir)", font=font, fill=LABEL)
        for row_i, direction in enumerate(ROW_ORDER):
            y = 24 + row_i * (cell_h + 14)
            d.text((pad, y + cell_h // 2 - 6), direction, font=font, fill=LABEL)
            for f in range(n):
                cell = sheet.crop((f * CELL_W, row_i * CELL_H, (f + 1) * CELL_W, (row_i + 1) * CELL_H))
                cell = cell.resize((cell_w, cell_h), Image.NEAREST)
                x = label_w + f * cell_w
                d.rectangle((x, y, x + cell_w, y + cell_h), outline=GRID, width=1)
                block.paste(cell, (x, y), cell)
                d.text((x + 2, y + 2), str(f), font=font, fill=LABEL)
        block_imgs.append(block)

    total_h = sum(b.height for b in block_imgs) + 20 * (len(block_imgs) - 1)
    total_w = max(b.width for b in block_imgs)
    canvas = Image.new("RGBA", (total_w, total_h), BG)
    y = 0
    for b in block_imgs:
        canvas.paste(b, (0, y))
        y += b.height + 20
    canvas.convert("RGB").save(PREVIEW_DIR / "fin-sheet-preview.png")
    print("saved fin-sheet-preview.png", canvas.size)


def build_directions_preview():
    scale = 8
    sheet = Image.open(FIN_DIR / "fin_idle.png").convert("RGBA")
    font = _font(14)
    cell_w, cell_h = CELL_W * scale, CELL_H * scale
    pad = 16
    canvas_w = len(ROW_ORDER) * (cell_w + pad) + pad
    canvas_h = cell_h + 60
    canvas = Image.new("RGBA", (canvas_w, canvas_h), BG)
    d = ImageDraw.Draw(canvas)
    d.text((pad, 10), "Fin idle frame0 - 4방향 실루엣 비교 (down/left/up/right)", font=font, fill=LABEL)
    for i, direction in enumerate(ROW_ORDER):
        cell = sheet.crop((0, i * CELL_H, CELL_W, (i + 1) * CELL_H)).resize((cell_w, cell_h), Image.NEAREST)
        x = pad + i * (cell_w + pad)
        y = 40
        canvas.paste(cell, (x, y), cell)
        d.rectangle((x, y, x + cell_w, y + cell_h), outline=GRID, width=2)
        d.text((x, y + cell_h + 6), direction, font=font, fill=LABEL)
    canvas.convert("RGB").save(PREVIEW_DIR / "fin-directions-preview.png")
    print("saved fin-directions-preview.png", canvas.size)


def build_gif(filename, n_frames, fps, out_name, direction="down"):
    scale = 4
    sheet = Image.open(FIN_DIR / filename).convert("RGBA")
    row_i = ROW_ORDER.index(direction)
    frames = []
    for f in range(n_frames):
        cell = sheet.crop((f * CELL_W, row_i * CELL_H, (f + 1) * CELL_W, (row_i + 1) * CELL_H))
        cell = cell.resize((CELL_W * scale, CELL_H * scale), Image.NEAREST)
        bg = Image.new("RGBA", cell.size, (58, 92, 66, 255))
        bg.paste(cell, (0, 0), cell)
        frames.append(bg.convert("RGB"))
    duration_ms = round(1000 / fps)
    frames[0].save(
        PREVIEW_DIR / out_name,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
    )
    print(f"saved {out_name} ({n_frames}f @ {fps}fps, {duration_ms}ms/frame)")


def build_size_comparison():
    scale = 8
    knight = Image.open(KNIGHT_SHEET).convert("RGBA")
    knight_cell = knight.crop((0, 0, 16, 16)).resize((16 * scale, 16 * scale), Image.NEAREST)

    fin_sheet = Image.open(FIN_DIR / "fin_idle.png").convert("RGBA")
    fin_cell = fin_sheet.crop((0, 0, CELL_W, CELL_H)).resize((CELL_W * scale, CELL_H * scale), Image.NEAREST)

    font = _font(13)
    title_font = _font(14)
    pad = 30
    col_gap = 50
    canvas_w = knight_cell.width + fin_cell.width + pad * 2 + col_gap
    canvas_h = max(knight_cell.height, fin_cell.height) + 90
    canvas = Image.new("RGBA", (canvas_w, canvas_h), BG)
    d = ImageDraw.Draw(canvas)
    d.text((pad, 8), "8x 배율 비교", font=title_font, fill=LABEL)
    d.text((pad, 26), "Knight(16x16, M1 placeholder) vs Fin(32x48, D-131 원작)", font=font, fill=LABEL)

    baseline_y = canvas_h - 32
    x1 = pad
    y1 = baseline_y - knight_cell.height
    canvas.paste(knight_cell, (x1, y1), knight_cell)
    d.rectangle((x1, y1, x1 + knight_cell.width, baseline_y), outline=GRID, width=2)
    d.text((x1, baseline_y + 6), "Knight 16x16", font=font, fill=LABEL)

    x2 = x1 + knight_cell.width + col_gap
    y2 = baseline_y - fin_cell.height
    canvas.paste(fin_cell, (x2, y2), fin_cell)
    d.rectangle((x2, y2, x2 + fin_cell.width, baseline_y), outline=GRID, width=2)
    d.text((x2, baseline_y + 6), "Fin 32x48", font=font, fill=LABEL)

    d.line((0, baseline_y, canvas_w, baseline_y), fill=(200, 60, 60, 255), width=1)
    canvas.convert("RGB").save(PREVIEW_DIR / "fin-size-comparison.png")
    print("saved fin-size-comparison.png", canvas.size)


def main():
    build_sheet_preview()
    build_directions_preview()
    build_gif("fin_walk.png", 8, 10, "fin-walk.gif")
    build_gif("fin_attack.png", 6, 12, "fin-attack.gif")
    build_size_comparison()


if __name__ == "__main__":
    main()
