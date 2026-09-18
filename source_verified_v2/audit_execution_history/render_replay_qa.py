from pathlib import Path
import sys,json,re
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'));import pymupdf
from PIL import Image,ImageDraw
out=w/'audit_replay_threshold_station_20260918';qa=out/'QA';qa.mkdir(exist_ok=True);report={}
for f in (out/'Documents').glob('*.pdf'):
 d=pymupdf.open(f);pages=[];fullpages=[];outside=[]
 for i,p in enumerate(d):
  pix=p.get_pixmap(matrix=pymupdf.Matrix(1.3,1.3));im=Image.frombytes('RGB',[pix.width,pix.height],pix.samples);im.save(qa/f'{f.stem}_{i+1}.jpg',quality=85);fullpages.append(im.copy())
  thumb=im.copy();thumb.thumbnail((280,400));pages.append(thumb)
  for b in p.get_text('blocks'):
   if b[0]<0 or b[1]<0 or b[2]>p.rect.width+1 or b[3]>p.rect.height+1:outside.append(i+1)
 for start in range(0,len(pages),12):
  sheet=Image.new('RGB',(1120,1260),'#ddd');dr=ImageDraw.Draw(sheet)
  for j,im in enumerate(pages[start:start+12]):x=(j%4)*280;y=(j//4)*420;sheet.paste(im,(x,y+20));dr.text((x+5,y+3),f'p{start+j+1}',fill='black')
  sheet.save(qa/f'{f.stem}_sheet{start//12+1}.jpg',quality=90)
 for start in range(0,len(fullpages),2):
  pair=fullpages[start:start+2];sheet=Image.new('RGB',(sum(x.width for x in pair)+12,max(x.height for x in pair)+25),'#ddd');dr=ImageDraw.Draw(sheet);x=0
  for j,im in enumerate(pair):sheet.paste(im,(x,25));dr.text((x+5,5),f'{f.stem} page {start+j+1}',fill='black');x+=im.width+12
  sheet.save(qa/f'{f.stem}_spread{start//2+1:02d}.jpg',quality=90)
 report[f.stem]=dict(pages=len(d),outside=outside)
(out/'layout_audit.json').write_text(json.dumps(report,indent=2));print(report)
