"""Inspect actual generated alpha and show flipbook motion over light/dark cards."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'assets/vfx/combat_release'
OUT=ROOT/'docs/art/combat_release'
OUT.mkdir(parents=True,exist_ok=True)
try:font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
except OSError:font=ImageFont.load_default()

report={}
for name in ('glass_dust_4x4','pressure_pop_4x4'):
    atlas=Image.open(SRC/(name+'.png')).convert('RGBA');assert atlas.size==(512,512)
    debug=Image.new('RGB',(1024,560),'#142338');d=ImageDraw.Draw(debug)
    frames=[];maxalpha=[]
    for frame in range(16):
        row,col=divmod(frame,4);im=atlas.crop((col*128,row*128,(col+1)*128,(row+1)*128))
        a=im.getchannel('A');maxalpha.append(a.getextrema()[1])
        assert not a.crop((0,0,128,3)).getbbox() and not a.crop((0,0,3,128)).getbbox()
        for side,bg in enumerate(('#142338','#A4CFED')):
            card=Image.new('RGBA',(128,128),bg);card.alpha_composite(im)
            debug.paste(card.convert('RGB'),(side*512+col*128,48+row*128))
        d.text((col*128+6,row*128+52),str(frame),font=font,fill='#FFD778')
        d.text((512+col*128+6,row*128+52),str(frame),font=font,fill='#34415C')
        card=Image.new('RGBA',(512,256),'#142338');sky=Image.new('RGBA',(256,256),'#A4CFED');card.alpha_composite(sky,(256,0))
        large=im.resize((256,256),Image.Resampling.LANCZOS);card.alpha_composite(large,(0,0));card.alpha_composite(large,(256,0));frames.append(card.convert('RGB'))
    assert maxalpha[-1]==0 and maxalpha[0]>0 and all(a>=b for a,b in zip(maxalpha,maxalpha[1:]))
    d.text((12,10),name+' / dark and bright-sky alpha / source order 0-15',font=font,fill='white')
    debug.save(OUT/(name+'_alpha_order.png'))
    # GIF is a preview only; the PNG atlas is the actual upload.
    frames.append(Image.new('RGB',(512,256),'#142338'))
    frames[0].save(OUT/(name+'_preview.gif'),save_all=True,append_images=frames[1:],duration=40,loop=0)
    report[name]={'size':[512,512],'frames':16,'frame_alpha_max':maxalpha,'gutter_verified':True,'terminal_frame_empty':True,'studio_order_verified':False}
(OUT/'texture_validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
