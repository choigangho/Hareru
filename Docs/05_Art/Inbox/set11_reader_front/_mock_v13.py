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
    cx=595; L=380
    d.text((cx,TOPY+30),"わかる",font=mf(18),fill=SUB,anchor='mm')
    d.text((cx,TOPY+86),"分かる",font=mf(64),fill=INK,anchor='mm')
    d.text((cx,TOPY+146),"알다, 이해하다",font=gf(22),fill=SUB,anchor='mm')
    d.line((L,TOPY+172,812,TOPY+172),fill=(200,190,160),width=2)
    d.text((L,TOPY+212),"この字の意味、分かりますか？",font=mf(28),fill=INK,anchor='lm')
    d.text((L,TOPY+256),"이 글자 뜻, 알겠어요?",font=gf(20),fill=SUB,anchor='lm')
    # receipt: reading log, 16px, as much as fits
    rx,ry=32,176
    lines=["── 判読 記録 ──","No.0003   08:42","分かる  わかる","반응   3.2초","판정   알고있음","다음   내일","- - - - - - - - - -","No.0002   08:41","いいえ","판정   모르겠음"]
    for i,t in enumerate(lines):
        f=mf(16) if any('぀'<=c<='鿿' for c in t) else gf(16)
        d.text((rx,ry+i*26),t,font=f,fill=RINK,anchor='lm')
    light=Image.new('RGB',im.size); shade=Image.new('L',im.size,0); ld=ImageDraw.Draw(light); sd=ImageDraw.Draw(shade)
    for y in range(TOPY,BOTY+1):
        a,b=xr(y); dd=abs(y-ly); g=max(0,1-dd/34)
        if g>0: ld.line((a,y,b,y),fill=(int(70*g),int(110*g),int(60*g)))
        sd.line((a,y,b,y),fill=int(120*min(1,max(0,(dd-50)/150))))
    im=ImageChops.add(im,light)
    im=Image.composite(Image.new('RGB',im.size,(30,24,26)),im,shade.point(lambda v:int(v*0.5)))
    d=ImageDraw.Draw(im); a,b=xr(ly); d.rectangle((a-14,ly-2,b+14,ly+1),fill=(150,230,150))
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
im.save(f'{S}/mock_v13_shift.png')
im.crop((300,480,1040,700)).resize((1480,440),Image.NEAREST).save(f'{S}/mock_v13_zoom.png')
