import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v8.png').convert('RGB'); W,H=src.size
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
SPLIT=122
top=band(src.crop((0,0,W,SPLIT)),[(44,12),(154,24),(236,-36)])
bot=band(src.crop((0,SPLIT,W,H)),[(44,12),(108,8),(141,8),(174,8),(236,-36)])
out=Image.new('RGB',(W,H)); out.paste(top,(0,0)); out.paste(bot,(0,SPLIT))
out.save(f'{S}/front_v10a.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v10a_x4.png')
