import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v12.png').convert('RGB'); W,H=src.size
def band(img, ops):
    """ops: [(col, +n copies of col | -n removes cols col..col+n)] in source coords"""
    pieces=[]; last=0
    for c,n in sorted(ops):
        pieces.append(img.crop((last,0,c,img.height)))
        if n>0:
            s=img.crop((c,0,c+1,img.height)); pieces += [s]*n; last=c
        else:
            last=c-n
    pieces.append(img.crop((last,0,img.width,img.height)))
    w=sum(p.width for p in pieces); out=Image.new('RGB',(w,img.height)); x=0
    for p in pieces: out.paste(p,(x,0)); x+=p.width
    assert w==img.width, w
    return out
K=20                                   # owner: drop the empty left margin (vines + printer's outer side) ...
out=band(src,[(0,-K),(283,K)])         # ... and give the same width to the right monitor and file box
# file box: push its front plank down so the files get the height the owner marked (to ~y 660 on screen)
BX,DY=243,10
box=out.crop((BX,0,W,H)); rows=[box.crop((0,y,box.width,y+1)) for y in range(H)]
rows=rows[:146]+[rows[145]]*DY+rows[146:H-DY]
nb=Image.new('RGB',box.size)
for y,r in enumerate(rows): nb.paste(r,(0,y))
out.paste(nb,(BX,0))
out.save(f'{S}/front_v13.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v13_x4.png')
