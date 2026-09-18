"""Deterministic cutout motion study using the selected Fin front image.

No independent AI frames and no changes to the original image. This is a front-only
animation blockout, not finished hand-drawn walk animation.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'prototypes/fin-front-test/assets'
REVIEW = ROOT / 'docs/art/preview/fin-front-test'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    source = Image.open(ROOT / 'docs/art/preview/fin-resolution/front-64.png').convert('RGBA')
    assert source.size == (66, 96)
    enlarged = source.resize((528,768),Image.Resampling.NEAREST)
    grid = Image.new('RGBA',(560,800),'#34483e')
    grid.alpha_composite(enlarged,(24,24))
    draw = ImageDraw.Draw(grid)
    for y in range(0,97,8):
        draw.line((24,24+y*8,552,24+y*8),fill='#a8b6a060')
        draw.text((1,24+y*8),str(y),fill='white')
    for x in range(0,67,8):
        draw.line((24+x*8,24,24+x*8,792),fill='#a8b6a060')
        draw.text((24+x*8,5),str(x),fill='white')
    grid.convert('RGB').save(REVIEW/'source-grid.png')
    # Conservative removal of magenta-contaminated boundary pixels only.
    original = source.copy()
    for y in range(source.height):
        for x in range(source.width):
            r,g,b,a = original.getpixel((x,y))
            edge = any(not (0<=x+dx<66 and 0<=y+dy<96) or original.getpixel((x+dx,y+dy))[3]==0 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
            if not a or (edge and r>g*1.35 and b>g*1.35):
                source.putpixel((x,y),(0,0,0,0))
    # Preserve face/head exactly. Only lower-limb masks move independently.
    masks=[]
    polygons=[[(21,74),(34,74),(35,84),(34,96),(18,96),(20,88),(22,84)],
              [(35,74),(47,74),(49,82),(49,87),(56,92),(56,96),(35,96)]]
    core=source.copy()
    legs=[]
    for poly in polygons:
        mask=Image.new('L',source.size)
        ImageDraw.Draw(mask).polygon(poly,fill=255)
        layer=Image.new('RGBA',source.size)
        layer.paste(source,(0,0),mask)
        box=layer.getbbox()
        legs.append((layer.crop(box),box))
        core.paste((0,0,0,0),(0,0,66,96),mask)
    # Hip cover extends the existing trouser shade behind the moving thighs.
    draw_core=ImageDraw.Draw(core)
    draw_core.rectangle((25,74,31,79),fill=source.getpixel((28,76)))
    draw_core.rectangle((38,74,44,79),fill=source.getpixel((41,76)))
    placements=[]
    frames=[]
    # Front approach: stance foot travels backward relative to the advancing body;
    # swing foot returns forward while shortening in depth. No global sideways sway.
    foot_y=[6,2,-2,-6,-5,-2,2,5]
    length=[1,1,1,1,.76,.70,.80,.94]
    inward=[0,0,0,0,1,2,1,0]
    bob=[0,1,0,-1,0,1,0,-1]
    for i in range(8):
        frame=Image.new('RGBA',(96,128))
        placements.append({'frame':i,'torso_offset':[0,bob[i]],'leg_phase':[i,(i+4)%8]})
        for side,(leg,box) in enumerate(legs):
            phase=(i+side*4)%8
            h=round(leg.height*length[phase])
            moved=leg.resize((leg.width,h),Image.Resampling.NEAREST)
            x=15+box[0]+(1 if side==0 else -1)*inward[phase]
            y=16+box[3]+foot_y[phase]-h
            frame.alpha_composite(moved,(x,y))
        frame.alpha_composite(core,(15,16+bob[i]))
        frames.append(frame)
    idle=Image.new('RGBA',(96,128))
    idle.alpha_composite(source,(15,16))
    idle.save(OUT/'fin-front-idle.png')
    atlas=Image.new('RGBA',(768,128))
    for i,frame in enumerate(frames):
        atlas.alpha_composite(frame,(96*i,0))
        # Head pixels must be identical after reversing the intentional 1px bob.
        assert frame.crop((15,16+bob[i],81,59+bob[i])).tobytes()==source.crop((0,0,66,43)).tobytes()
        box=frame.getbbox()
        assert box[0]>0 and box[1]>0 and box[2]<96 and box[3]<128
    assert len({f.tobytes() for f in frames})==8
    atlas.save(OUT/'fin-front-walk.png')
    sheet=Image.new('RGBA',atlas.size,'#30453b')
    sheet.alpha_composite(atlas)
    sheet.resize((1536,256),Image.Resampling.NEAREST).convert('RGB').save(REVIEW/'walk-contact-sheet.png')
    gifs=[]
    for frame in frames:
        canvas=Image.new('RGBA',(288,164),'#233b34')
        canvas.alpha_composite(idle,(16,24))
        canvas.alpha_composite(frame,(164,24))
        d=ImageDraw.Draw(canvas)
        d.text((20,6),'IDLE / LOCKED',fill='white')
        d.text((166,6),'WALK / BLOCKOUT',fill='white')
        canvas=canvas.resize((864,492),Image.Resampling.NEAREST).convert('RGB')
        gifs.append(canvas)
    gifs[0].save(REVIEW/'idle-walk.gif',save_all=True,append_images=gifs[1:],duration=125,loop=0,disposal=2)
    report={'cell':[96,128],'body_budget':[64,96],'foot_anchor':[48,112],'fps':8,'frames':placements,'head_identity_test':'pass; 43 source rows unchanged after bob compensation','distinct_frames':8,'status':'front-only cutout motion blockout; not final hand-drawn animation','source':'docs/art/preview/fin-resolution/front-64.png'}
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
