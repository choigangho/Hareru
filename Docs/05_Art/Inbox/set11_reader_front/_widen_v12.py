import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v11.png').convert('RGB'); W,H=src.size
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
    assert w==W, w
    return out
def apply(img,y0,y1,ops):
    img.paste(band(img.crop((0,y0,W,y1)),ops),(0,y0))
out=src.copy()
# 1) glass: eat the clamp margins the owner marked (left 10, right 8) and give it to the glass (+18 = 72 screen px)
GL=18
apply(out,0,112,[(88,-10),(170,GL),(240,-8)])
apply(out,112,124,[(77,-10),(170,GL),(247,-8)])   # lamp row: cut outside the lamps so they follow the frame
# 2) lever panel: take the empty right wall of the file box (8) and give it to the lever gaps
apply(out,102,124,[(255,8),(302,-8)])
apply(out,124,H,[(127,3),(165,3),(204,2),(302,-8)])
out.save(f'{S}/front_v12.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v12_x4.png')
