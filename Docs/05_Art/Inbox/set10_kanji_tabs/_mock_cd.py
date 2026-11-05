import sys
from PIL import Image, ImageDraw, ImageFont
S, OUT = sys.argv[1], sys.argv[2]
base = Image.open(f'{S}/base_238.png').convert('RGB')
rd = Image.open(f'{S}/base_read.png').convert('RGB')
base.paste(rd.crop((0, 648, 1280, 720)), (0, 648))
base.paste(rd.crop((1040, 0, 1280, 300)), (1040, 0))
MIN = '/System/Library/Fonts/ヒラギノ明朝 ProN.ttc'; GOT = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
mf = lambda z: ImageFont.truetype(MIN, z, index=0); gf = lambda z: ImageFont.truetype(GOT, z, index=0)
INK=(40,30,30); PAPER=(247,240,214); FADED=(205,196,172); AMBER=(232,150,40); GREEN=(96,200,120)
EMPTY=(190,180,160); RED=(200,50,40); PH=(140,230,150); PHDIM=(80,150,95); GRAY=(110,100,85)
WORDS=[("自分","じぶん","자기, 자신",3,True,"3일 전"),("多分","たぶん","아마",1,True,"5일 전"),("半分","はんぶん","반, 절반",0,False,"지나침")]

def box(d,r,fill,w=4,shadow=True):
    x0,y0,x1,y1=r
    if shadow: d.rectangle((x0+8,y0+8,x1+8,y1+8),fill=(30,18,14))
    d.rectangle(r,fill=fill,outline=INK,width=w)
def dots(d,x,y,n,s=10,g=2):
    for i in range(4): d.rectangle((x+i*(s+g),y,x+i*(s+g)+s-1,y+s-1),fill=GREEN if i<n else EMPTY)
def stamp(d,cx,cy,ch,r=24):
    d.ellipse((cx-r,cy-r,cx+r,cy+r),outline=RED,width=4); d.text((cx,cy),ch,font=mf(int(r*1.1)),fill=RED,anchor='mm')
def underline(d,x0,x1,y): d.rectangle((x0,y,x1,y+3),fill=AMBER)

# ---------- C: current layout, tabs out of the right outbox, kanji on the monitor ----------
def monitor_kanji(img):
    px=img.load()
    for x in range(1080,1245):
        for y in range(92,240):
            r,g,b=px[x,y]
            if g>r+25 and g>b: px[x,y]=(18,46,30)
    d=ImageDraw.Draw(img)
    d.text((1102,132),"分",font=mf(30),fill=PH,anchor='lm')
    d.text((1140,134),"나눌 분",font=gf(22),fill=PH,anchor='lm')
    d.text((1112,172),"刀 · ブン",font=mf(16),fill=PHDIM,anchor='lm')
    d.text((1122,196),"わける",font=mf(16),fill=PHDIM,anchor='lm')

def outbox_tabs(img, skip=None):
    d=ImageDraw.Draw(img)
    for i,(w,rdg,m,n,ok,when) in enumerate(WORDS):
        x=1068+i*70; y=356+(i%2)*10
        if w==skip: continue
        box(d,(x,y,x+64,y+110),PAPER if ok else FADED,shadow=False)
        d.rectangle((x+4,y+4,x+60,y+9),fill=AMBER if ok else EMPTY)
        d.text((x+32,y+34),w,font=mf(20),fill=INK if ok else GRAY,anchor='mm')
        if ok: dots(d,x+9,y+56,n)
        else: d.text((x+32,y+62),"지나침",font=gf(16),fill=GRAY,anchor='mm')
    img.paste(base.crop((1056,436,1280,470)),(1056,436))   # tabs go down into the outbox
    d.rectangle((1068,318,1270,346),fill=(16,12,14))
    d.text((1078,332),"分",font=mf(20),fill=AMBER,anchor='lm'); d.text((1104,332),"처리함 · 지난 문서 3",font=gf(16),fill=(240,228,200),anchor='lm')
    underline(d,572,628,306)

c1=base.copy(); monitor_kanji(c1); outbox_tabs(c1); c1.save(f'{OUT}/mock_c1_outbox_tabs.png')
c2=base.copy(); monitor_kanji(c2); outbox_tabs(c2,skip="自分"); d=ImageDraw.Draw(c2)
r=(1004,300,1268,628); box(d,r,PAPER)
d.text((1022,322),"판독 기록 · 3일 전",font=gf(16),fill=GRAY,anchor='lm')
d.text((1136,354),"じぶん",font=mf(16),fill=(90,80,70),anchor='mm')
d.text((1136,394),"自分",font=mf(44),fill=INK,anchor='mm'); underline(d,1136,1180,420)
d.text((1136,444),"자기, 자신",font=gf(20),fill=(70,60,50),anchor='mm')
d.text((1020,486),"自分で作ってみます。",font=mf(20),fill=INK,anchor='lm')
d.text((1020,514),"직접 만들어 볼게요.",font=gf(16),fill=(90,80,70),anchor='lm')
d.text((1020,556),"안정도",font=gf(16),fill=(90,80,70),anchor='lm'); dots(d,1074,550,3,12,3)
stamp(d,1228,556,"読",22)
d.text((1136,602),"클릭 · 키 1~4 → 되돌아감",font=gf(16),fill=GRAY,anchor='mm')
c2.save(f'{OUT}/mock_c2_outbox_pulled.png')

# ---------- D: reader moved 140 px left, right zone = front monitor + stepped file box ----------
D=Image.new('RGB',(1280,720),(110,58,38))
dw=ImageDraw.Draw(D)
for y in range(0,720,44):
    dw.rectangle((0,y,1280,y+3),fill=(84,42,28))
    off=(y//44)*173%600
    for x in range(off,1280,600): dw.rectangle((x,y,x+3,y+44),fill=(84,42,28))
D.paste(base.crop((0,0,232,720)).crop((0,0,232,720)),(-140,0))         # pile + printer, pushed off the left edge
D.paste(base.crop((228,88,1032,656)),(88,88))                           # reader 140 px left
D.paste(rd.crop((0,640,220,720)),(0,640))                                # 일어서기
d=ImageDraw.Draw(D)
# front monitor
box(d,(900,28,1256,208),(214,196,150)); d.rectangle((920,44,1236,192),fill=(18,46,30),outline=(60,50,40),width=4)
for y in range(48,190,4): d.line((924,y,1232,y),fill=(14,38,24))
d.text((940,88),"分",font=mf(40),fill=PH,anchor='lm'); d.text((994,90),"나눌 분",font=gf(24),fill=PH,anchor='lm')
d.text((940,140),"부수 刀   음 ブン · フン",font=gf(16),fill=PHDIM,anchor='lm')
d.text((940,166),"훈 わ-ける",font=gf(16),fill=PHDIM,anchor='lm')
# stepped file box
box(d,(900,224,1256,684),(112,72,48)); d.rectangle((912,236,1244,672),fill=(78,48,32))
for i,(w,rdg,m,n,ok,when) in enumerate(WORDS):
    y=252+i*112
    box(d,(920,y,1236,y+150),PAPER if ok else FADED,shadow=i<2)
    d.rectangle((924,y+4,931,y+146),fill=AMBER if ok else EMPTY)
    d.text((946,y+30),w,font=mf(28),fill=INK if ok else GRAY,anchor='lm')
    d.text((1008,y+32),rdg,font=mf(16),fill=GRAY,anchor='lm')
    d.text((1092,y+32),m,font=gf(20),fill=(70,60,50) if ok else GRAY,anchor='lm')
    if ok: dots(d,946,y+64,n,12,3); d.text((1012,y+70),when+" 판독",font=gf(16),fill=GRAY,anchor='lm')
    else: d.text((946,y+70),"지나침 · 눌러서 보기",font=gf(16),fill=GRAY,anchor='lm')
    stamp(d,1206,y+46,"読" if ok else "再",20)
underline(d,572-140,628-140,306)
D.save(f'{OUT}/mock_d_two_column.png')
