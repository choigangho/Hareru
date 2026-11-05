import sys
from PIL import Image
S=sys.argv[1]
src=Image.open(f'{S}/front_v3.png').convert('RGBA')
W,H=src.size
SHIFT=18          # printer moves to the left edge
TOP_COL=110       # column copied to widen the scanner (rails / glass / wall)
BOT_COL=124       # gap between key 1 and key 2 for the lower panel
BAND=122          # rows below this use BOT_COL
ROW=95            # glass row copied to make the bed taller
ADD_ROWS=12
out=Image.new('RGBA',(W,H))
out.paste(src.crop((SHIFT,0,100,H)),(0,0))
R=src.crop((100,0,W,H))
def widen(img,cols,rows):
    """cols: {column in img: copies} — copies summing to SHIFT"""
    a,b=rows
    part=img.crop((0,a,img.width,b))
    w=Image.new('RGBA',(img.width+SHIFT,b-a))
    x=0; last=0
    for c in sorted(cols):
        w.paste(part.crop((last,0,c,b-a)),(x,0)); x+=c-last
        strip=part.crop((c,0,c+1,b-a))
        for i in range(cols[c]): w.paste(strip,(x,0)); x+=1
        last=c
    w.paste(part.crop((last,0,part.width,b-a)),(x,0))
    return w
R2=Image.new('RGBA',(R.width+SHIFT,H))
R2.paste(widen(R,{TOP_COL-100:SHIFT},(0,BAND)),(0,0))
R2.paste(widen(R,{124-100:5,152-100:5,180-100:5,208-100:3},(BAND,H)),(0,BAND))
out.paste(R2.crop((0,0,W-(100-SHIFT),H)),(100-SHIFT,0))
# taller bed: copy glass row ROW down by ADD_ROWS inside the scanner's columns
x0,x1=62,218
col=out.crop((x0,0,x1,H))
tall=Image.new('RGBA',(x1-x0,H))
tall.paste(col.crop((0,0,x1-x0,ROW)),(0,0))
row=col.crop((0,ROW,x1-x0,ROW+1))
for i in range(ADD_ROWS): tall.paste(row,(0,ROW+i))
tall.paste(col.crop((0,ROW,x1-x0,H-ADD_ROWS)),(0,ROW+ADD_ROWS))
out.paste(tall,(x0,0))
out.save(f'{S}/front_v4.png')
out.convert('RGB').resize((1280,720),Image.NEAREST).save(f'{S}/front_v4_x4.png')
