"""User-approved deterministic postprocessing; preserve the generated original.

Requires Pillow. Run from any directory. No network or API calls.
"""
from collections import deque
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/art/preview/fin-cq-walk-draft-v1.png'
OUT = ROOT / 'game/assets/sprites/characters/fin'
PREVIEW = ROOT / 'docs/art/preview'


def extract(cell):
    """Remove only near-neutral bright pixels connected to the cell boundary.

    Unlike a global color key, enclosed silver equipment is not selected.
    Keep original RGB for all retained pixels; no erosion of the silhouette.
    """
    w, h = cell.size
    p = cell.load()
    seen = set()
    queue = deque()
    def visit(x, y):
        if not (0 <= x < w and 0 <= y < h) or (x, y) in seen:
            return
        r, g, b, _ = p[x, y]
        if min(r, g, b) >= 150 and max(r, g, b) - min(r, g, b) <= 25:
            seen.add((x, y))
            queue.append((x, y))
    for x in range(w):
        visit(x, 0)
        visit(x, h - 1)
    for y in range(h):
        visit(0, y)
        visit(w - 1, y)
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            visit(x + dx, y + dy)
    for x, y in seen:
        p[x, y] = (0, 0, 0, 0)
    return cell


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert('RGBA')
    assert source.size == (1536, 1024), source.size
    cleaned = Image.new('RGBA', source.size)
    frames = []
    bounds = []
    for row in range(4):
        for col in range(8):
            cell = extract(source.crop((col*192, row*256, (col+1)*192, (row+1)*256)))
            box = cell.getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < 192 and box[3] < 256, (row, col, box)
            bounds.append(box)
            cleaned.paste(cell, (col*192, row*256))
            frames.append(cell)
    cleaned.save(PREVIEW / 'fin-cq-walk-clean-v1.png')
    # One scale shared by all poses avoids size pumping; pad equipment separately.
    scale = 48 / max(b[3] - b[1] for b in bounds)
    atlas = Image.new('RGBA', (48*8, 64*4))
    small_frames = []
    for i, (cell, box) in enumerate(zip(frames, bounds)):
        crop = cell.crop(box)
        small = crop.resize((round(crop.width*scale), round(crop.height*scale)), Image.Resampling.NEAREST)
        frame = Image.new('RGBA', (48, 64))
        # Original column center is a stable horizontal anchor; feet land at y=55.
        x = round(24 + (box[0]-96)*scale)
        y = 56 - small.height
        assert x >= 0 and x+small.width <= 48
        frame.paste(small, (x, y))
        small_frames.append(frame)
        atlas.paste(frame, ((i%8)*48, (i//8)*64))
    # Shared palette, no dithering: avoid per-frame palette shimmer.
    alpha = atlas.getchannel('A')
    atlas = atlas.convert('RGB').quantize(colors=32, dither=Image.Dither.NONE).convert('RGBA')
    atlas.putalpha(alpha)
    atlas.save(OUT / 'fin-walk-v1.png')
    small_frames = [atlas.crop((col*48,row*64,(col+1)*48,(row+1)*64)) for row in range(4) for col in range(8)]
    sheet = Image.new('RGBA', atlas.size, '#334d43')
    sheet.alpha_composite(atlas)
    sheet.resize((1536, 1024), Image.Resampling.NEAREST).convert('RGB').save(PREVIEW / 'fin-cq-walk-pixel-review.png')
    animation = []
    for col in range(8):
        canvas = Image.new('RGBA', (48*4, 76), '#334d43')
        draw = ImageDraw.Draw(canvas)
        for row, label in enumerate(('DOWN', 'LEFT', 'UP', 'RIGHT')):
            canvas.alpha_composite(small_frames[row*8+col], (row*48, 12))
            draw.text((row*48+3, 1), label, fill='white')
        animation.append(canvas.resize((768, 304), Image.Resampling.NEAREST).convert('RGB'))
    animation[0].save(PREVIEW / 'fin-cq-walk-review.gif', save_all=True, append_images=animation[1:], duration=125, loop=0, disposal=2)
    alpha = atlas.getchannel('A')
    assert set(alpha.tobytes()) == {0, 255}
    resources = ['[gd_resource type="SpriteFrames" load_steps=34 format=3]', '', '[ext_resource type="Texture2D" path="res://assets/sprites/characters/fin/fin-walk-v1.png" id="1"]']
    for row in range(4):
        for col in range(8):
            resources += ['', f'[sub_resource type="AtlasTexture" id="f{row}_{col}"]', 'atlas = ExtResource("1")', f'region = Rect2({col*48}, {row*64}, 48, 64)']
    animations = []
    for row, direction in enumerate(('down','left','up','right')):
        refs = ', '.join('{"duration": 1.0, "texture": SubResource("f%d_%d")}' % (row,col) for col in range(8))
        animations.append('{"frames": ['+refs+'], "loop": true, "name": &"walk_'+direction+'", "speed": 8.0}')
    resources += ['', '[resource]', 'animations = ['+',\n'.join(animations)+']', '']
    (OUT / 'fin-walk-v1.tres').write_text('\n'.join(resources), encoding='utf-8')
    report = {'source': SOURCE.relative_to(ROOT).as_posix(), 'atlas': 'fin-walk-v1.png', 'size': list(atlas.size), 'cell': [48,64], 'rows': ['down','left','up','right'], 'frames_per_row':8, 'fps':8, 'foot_anchor':[24,56], 'uniform_scale':scale, 'alpha_values':[0,255], 'source_bounds':bounds, 'status':'walk-only candidate; no attack/idle animation; not wired into Player'}
    (OUT / 'fin-walk-v1.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
