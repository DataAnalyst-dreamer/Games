"""Prepare newly generated resolution-specific front poses, not upscaled v1 art.

User-approved local postprocessing. Pillow required. Comparison only; no Player edits.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/art/preview/fin-resolution'


def main():
    rows = []
    for width, height in ((48, 72), (64, 96)):
        src = Image.open(OUT / f'front-{width}-source.png').convert('RGBA')
        rgb = src.convert('RGB')
        # Measure whether the generator actually followed the requested 8x grid.
        proxy = rgb.resize((128,128), Image.Resampling.NEAREST).resize(rgb.size, Image.Resampling.NEAREST)
        unequal = sum(a != b for a,b in zip(rgb.tobytes(),proxy.tobytes())) / len(rgb.tobytes())
        pixels = list(src.get_flattened_data())
        mask = [r > 170 and b > 130 and g < 120 and r > g*1.7 and b > g*1.5 for r,g,b,a in pixels]
        assert sum(mask) > src.width*src.height*.15, 'Expected magenta extraction background'
        src.putdata([(0,0,0,0) if remove else p for p,remove in zip(pixels,mask)])
        box = src.getbbox()
        crop = src.crop(box)
        # BOX aggregates the enlarged design's clusters; unlike old nearest-only
        # reduction, avoids arbitrarily dropping a thin feature. No 32-color cap.
        frame = crop.resize((round(crop.width*height/crop.height),height), Image.Resampling.BOX)
        alpha = frame.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        frame.putalpha(alpha)
        frame.save(OUT / f'front-{width}.png')
        src.save(OUT / f'front-{width}-clean.png')
        rows.append({'body_budget':[width,height], 'source_size':list(src.size), 'actual_equipment_inclusive_size':list(frame.size), 'source_bounds':box, 'rgb_channels_not_matching_8x_grid_fraction':round(unequal,4), 'status':'new resolution-specific AI draft, then extracted and resampled; not manually pixel-authored'})
    # Rejected old 32x48-body walk sample is an explicitly labeled baseline only.
    old = Image.open(ROOT / 'game/assets/sprites/characters/fin/fin-walk-v1.png').convert('RGBA').crop((0,0,48,64))
    old.crop(old.getbbox()).save(OUT / 'old-baseline.png')
    board = Image.new('RGBA', (960,540), '#233b34')
    draw = ImageDraw.Draw(board)
    for col,(name,label,zoom) in enumerate((('old-baseline','REJECTED V1 / WALK',6),('front-48','NEW A / 48x72 TARGET',4),('front-64','NEW B / 64x96 TARGET',3))):
        im = Image.open(OUT / (name+'.png')).convert('RGBA')
        cx = col*320+160
        draw.text((col*320+22,18),label,fill='white')
        draw.text((col*320+22,43),'NATIVE 1x / '+str(im.size),fill='#becdb5')
        board.alpha_composite(im,(cx-im.width//2,155-im.height))
        draw.line((col*320+20,158,col*320+300,158),fill='#6e8166')
        draw.text((col*320+22,186),'DETAIL / INTEGER '+str(zoom)+'x',fill='#becdb5')
        big=im.resize((im.width*zoom,im.height*zoom),Image.Resampling.NEAREST)
        board.alpha_composite(big,(cx-big.width//2,510-big.height))
    board.convert('RGB').save(OUT / 'comparison.png')
    fhd = Image.new('RGBA',(1920,1080),'#233b34')
    draw = ImageDraw.Draw(fhd)
    font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',24)
    draw.text((40,32),'FHD 1920 x 1080 / displayed at 2x / static scale study, not gameplay',font=font,fill='white')
    for col,(name,label) in enumerate((('old-baseline','Rejected v1'),('front-48','48 x 72 target'),('front-64','64 x 96 target'))):
        cx=col*640+320
        im=Image.open(OUT/(name+'.png')).convert('RGBA')
        draw.rectangle((col*640+25,130,col*640+615,990),outline='#4a695c',width=2)
        draw.text((col*640+70,180),label,font=font,fill='white')
        big=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
        fhd.alpha_composite(big,(cx-big.width//2,650-big.height))
        draw.line((col*640+70,650,col*640+570,650),fill='#9aa886',width=2)
        draw.text((col*640+70,720),f'Height {big.height}px / {big.height/1080:.1%} of screen',font=font,fill='#c7d4c4')
    fhd.convert('RGB').save(OUT/'fhd-scale.png')
    (OUT / 'measurements.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(rows))


if __name__ == '__main__':
    main()
