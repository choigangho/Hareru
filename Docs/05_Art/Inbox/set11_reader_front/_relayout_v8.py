import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v7.png').convert('RGB')
W,H=src.size; SHIFT=18
def widen(part,cols):
    w=Image.new('RGB',(part.width+SHIFT,part.height)); x=0; last=0
    for c in sorted(cols):
        w.paste(part.crop((last,0,c,part.height)),(x,0)); x+=c-last
        s=part.crop((c,0,c+1,part.height))
        for i in range(cols[c]): w.paste(s,(x,0)); x+=1
        last=c
    w.paste(part.crop((last,0,part.width,part.height)),(x,0)); return w
out=Image.new('RGB',(W,H))
out.paste(src.crop((SHIFT,0,98,H)),(0,0))                     # printer to the left edge
R=src.crop((98,0,W,H)); BAND=122
top=widen(R.crop((0,0,R.width,BAND)),{154-98:SHIFT})
bot=widen(R.crop((0,BAND,R.width,H)),{124-98:5,152-98:5,180-98:5,208-98:3})
out.paste(top.crop((0,0,W-80,BAND)),(80,0)); out.paste(bot.crop((0,0,W-80,H-BAND)),(80,BAND))
# taller glass: the panel's upper part moves up 12 rows, glass row 60 repeated
x0,x1,UP,ROW=88,201,12,60
col=out.crop((x0,0,x1,H)); t=Image.new('RGB',col.size)
t.paste(col.crop((0,UP,col.width,ROW)),(0,0))
r=col.crop((0,ROW,col.width,ROW+1))
for i in range(UP): t.paste(r,(0,ROW-UP+i))
t.paste(col.crop((0,ROW,col.width,H)),(0,ROW))
out.paste(t,(x0,0))
out.save(f'{S}/front_v8.png'); out.resize((1280,720),Image.NEAREST).save(f'{S}/front_v8_x4.png')
