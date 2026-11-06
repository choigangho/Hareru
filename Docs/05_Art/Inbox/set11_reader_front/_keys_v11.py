import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v10.png').convert('RGB'); W,H=src.size
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
Y0,Y1=128,164          # lever housings, rows only
PLATES=[(97,108),(138,149),(181,192),(223,234)]   # cream label plate columns per housing (row 150)
G=5                    # +5 columns each side of every lever -> plate 12 -> 22 art px (88 screen px)
ops=[]
for c in [98,107,140,149,182,191,223,232]: ops.append((c,G))   # plain columns beside each lever (no lever pixels)
ops += [(118,-13),(159,-14),(201,-13)]            # take the width out of the gaps between housings
mid=band(src.crop((0,Y0,W,Y1)),ops)
out=src.copy(); out.paste(mid,(0,Y0))
out.save(f'{S}/front_v11.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v11_x4.png')
out.crop((70,118,250,180)).resize((1080,372),Image.NEAREST).save(f'{S}/keys_v11_zoom.png')
