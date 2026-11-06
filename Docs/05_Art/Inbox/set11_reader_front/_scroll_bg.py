import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops
S=sys.argv[1]
MIN='/System/Library/Fonts/ヒラギノ明朝 ProN.ttc'; GOT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
mf=lambda z: ImageFont.truetype(MIN,z,index=0); gf=lambda z: ImageFont.truetype(GOT,z,index=0)
INK=(40,30,30); SUB=(110,100,85); RINK=(70,60,50)
TOPY,BOTY=112,446
def xr(y):  # paper edges on the reclined glass
    t=(y-TOPY)/(BOTY-TOPY); return 352-18*t, 838+16*t
def frame(ly):
    im=Image.open(f'{S}/front_v13_x4.png').convert('RGB'); d=ImageDraw.Draw(im)
    d.polygon([(xr(TOPY)[0],TOPY),(xr(TOPY)[1],TOPY),(xr(BOTY)[1],BOTY),(xr(BOTY)[0],BOTY)],fill=(247,242,214))
    for y in range(TOPY,BOTY,8): a,b=xr(y); d.line((a,y,b,y),fill=(241,235,206))
    # receipt: reading log, 16px, as much as fits
    rx,ry=32,176
    lines=["── 判読 記録 ──","No.0003   08:42","分かる  わかる","반응   3.2초","판정   알고있음","다음   내일","- - - - - - - - - -","No.0002   08:41","いいえ","판정   모르겠음"]
    for i,t in enumerate(lines):
        f=mf(16) if any('぀'<=c<='鿿' for c in t) else gf(16)
        d.text((rx,ry+i*26),t,font=f,fill=RINK,anchor='lm')
    return im
MIN='/System/Library/Fonts/ヒラギノ明朝 ProN.ttc'; GOT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
mf=lambda z: ImageFont.truetype(MIN,z,index=0); gf=lambda z: ImageFont.truetype(GOT,z,index=0)
INK=(40,30,30); SUB=(110,100,85); PAPER=(239,231,180); FADED=(208,198,170)
RED=(200,60,50); GREY=(150,140,120)
TAB_H=34; STRIP=30; SLANT=6; PADX=12; MIN_TAB=56
def tab_w(d,word): return max(MIN_TAB,int(d.textlength(word,font=mf(24))+2*PADX+2*SLANT))
def folder(d,x,y,w,word,reading,learned,tab_x):
    """file-folder card: a tab on the top edge holds the word, the strip under it the reading + stamp"""
    fill=PAPER if learned else FADED
    tw=tab_w(d,word); tx=x+tab_x
    tx=min(tx,x+w-tw)                                     # keep the tab on the card
    body=(x,y+TAB_H,x+w,y+TAB_H+STRIP+60)
    d.rectangle((body[0]+6,body[1]+6,body[2]+6,body[3]+6),fill=(30,18,14))
    d.polygon([(tx,y+TAB_H),(tx+SLANT,y),(tx+tw-SLANT,y),(tx+tw,y+TAB_H)],fill=fill,outline=INK)
    d.line((tx,y+TAB_H,tx+SLANT,y),fill=INK,width=4); d.line((tx+SLANT,y,tx+tw-SLANT,y),fill=INK,width=4); d.line((tx+tw-SLANT,y,tx+tw,y+TAB_H),fill=INK,width=4)
    d.rectangle(body,fill=fill,outline=INK,width=4)
    d.rectangle((tx+4,y+TAB_H-2,tx+tw-4,y+TAB_H+3),fill=fill)          # tab opens into the card
    d.text((tx+tw/2,y+TAB_H/2+3),word,font=mf(24),fill=INK if learned else SUB,anchor='mm')
    d.text((x+12,y+TAB_H+STRIP/2+2),reading,font=gf(16),fill=SUB,anchor='lm')
    d.text((x+w-14,y+TAB_H+STRIP/2+2),"読" if learned else "再",font=mf(18),fill=RED if learned else GREY,anchor='rm')
    return tw

base=frame(287); im=base.copy(); d=ImageDraw.Draw(im)
d.rectangle((992,404,1238,640),fill=(78,48,32))
X,W=996,238
cards=[("分","ふん",True,0),("自分","じぶん",True,72),("半分","はんぶん",False,140)]
for i,(w,r,ok,tx) in enumerate(cards):
    folder(d,X,402+i*76,W,w,r,ok,tx)
im.paste(base.crop((980,640,1280,720)),(980,640))


# lever function names on the widened plates (art 22px = 88 screen px each)
KEYS=[(352,"모르겠음"),(520,"애매함"),(684,"알고있음"),(846,"쉬움")]
d=ImageDraw.Draw(im)
for cx,name in KEYS:
    d.text((cx,615),name,font=gf(18),fill=(60,46,36),anchor='mm')
im.save(f'{S}/scroll_bg.png')
im.crop((300,480,1040,700)).resize((1480,440),Image.NEAREST).save(f'{S}/scroll_bg_zoom.png')
