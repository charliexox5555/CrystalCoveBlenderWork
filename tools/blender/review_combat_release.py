"""File-only PNG/hash QA and genuine contact sheets. Run with ordinary Python/Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
ROSTER=json.loads((ROOT/'docs/design/RELEASE_ROSTER_24.json').read_text())['roster']
ICONS=ROOT/'assets/icons/release_v2'
OUT=ROOT/'docs/art/combat_release'
OUT.mkdir(parents=True,exist_ok=True)
try:FONT=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
except OSError:FONT=ImageFont.load_default()

def contact_sheet(rows,name,compare=False):
    w=1200;cell=400;height=850 if compare else 910
    canvas=Image.new('RGB',(w,height),'#142338');d=ImageDraw.Draw(canvas)
    d.text((24,14),name+' / Blender previews / Studio materials pending',font=FONT,fill='#D9EFFF')
    for i,row in enumerate(rows):
        if compare:
            positions=[(i%3*cell+30,i//3*400+65,ICONS/'before'/(row['id']+'.png')),(i%3*cell+220,i//3*400+65,ICONS/(row['id']+'.png'))]
            size=160
        else:
            positions=[(i%3*cell+30,i//3*420+65,ICONS/(row['id']+'.png'))];size=340
        for x,y,p in positions:
            im=Image.open(p).convert('RGBA');im.thumbnail((size,size));canvas.paste(im,(x,y),im)
        x=i%3*cell+30;y=i//3*(400 if compare else 420)+(240 if compare else 414)
        d.text((x,y),row['name'],font=FONT,fill='white')
        if compare:d.text((x,y+30),'Original                 Release v2',font=FONT,fill='#AFCAD6')
        # Real 64px icon-size comparison next to the large preview.
        im=Image.open(ICONS/(row['id']+'.png')).convert('RGBA').resize((64,64),Image.Resampling.LANCZOS)
        canvas.paste(im,(x+290,y-60),im)
    canvas.save(OUT/(name+'.png'))

def run():
    results=[];seen=set()
    for row in ROSTER:
        gid=row['id'];assert gid not in seen;seen.add(gid)
        p=ROOT/'assets/blender/glassies'/gid/'release_v2/manifest.json'
        if not p.exists():continue
        m=json.loads(p.read_text());assert m['shard_count']==16 and m['intact_triangles']<=m['triangle_budget']
        assert abs(m['fracture_volume_ratio']-1)<.001
        for k,f in m['files'].items():assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==m['hashes'][k],(gid,k)
        image=Image.open(m['files']['icon']);assert image.size==(512,512) and image.mode=='RGBA'
        alpha=image.getchannel('A');bounds=alpha.getbbox();assert bounds and min(bounds)>0 and max(bounds)<512,(gid,'padding',bounds)
        # Aim for centered visible artwork; record any eccentric silhouette honestly.
        center=((bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2)
        results.append({'id':gid,'batch':row['batch'],'intact_triangles':m['intact_triangles'],'shards':16,'alpha_bounds':bounds,'alpha_center':center,'fbx_roundtrip':m.get('fbx_roundtrip',{}).get('passed',False),'studio_imported':False})
    for batch in 'ABCD':
        rows=[r for r in ROSTER if r['batch']==batch]
        if all((ICONS/(r['id']+'.png')).exists() for r in rows):contact_sheet(rows,'batch_'+batch)
        old=[r for r in rows if (ICONS/'before'/(r['id']+'.png')).exists() and (ICONS/(r['id']+'.png')).exists()]
        if old:contact_sheet(old,'batch_'+batch+'_before_after',True)
    if len(results)==24:
        board=Image.new('RGB',(1440,1090),'#142338');draw=ImageDraw.Draw(board)
        draw.text((20,10),'GLASS CLASH / 24 release asset previews / Studio import pending',font=FONT,fill='white')
        for i,row in enumerate(ROSTER):
            x=(i%6)*240;y=(i//6)*260+45
            im=Image.open(ICONS/(row['id']+'.png')).convert('RGBA');im.thumbnail((216,216))
            board.paste(im,(x+12,y),im)
            draw.text((x+12,y+220),row['name'],font=FONT,fill='#DBEDF6')
        board.save(OUT/'roster_24.png')
    path=OUT/'file_validation.json';path.write_text(json.dumps({'expected':24,'validated':len(results),'results':results},indent=2))
    print(json.dumps({'validated':len(results),'fbx_roundtrips':sum(r['fbx_roundtrip'] for r in results),'report':str(path)}))

if __name__=='__main__':run()
