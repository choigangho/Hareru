import sys
from PIL import Image, ImageDraw, ImageFont
S=sys.argv[1]
MIN='/System/Library/Fonts/ヒラギノ明朝 ProN.ttc'; GOT='/System/Library/Fonts/AppleSDGothicNeo.ttc'
mf=lambda z: ImageFont.truetype(MIN,z,index=0); gf=lambda z: ImageFont.truetype(GOT,z,index=0)
INK=(40,30,30); SUB=(110,100,85); PAPER=(247,242,214); FADED=(214,204,178)
AMBER=(224,160,64); GREY=(160,150,130); RED=(200,60,50)
TAB_H=64; PAD=12; STAMP=30; MINW=96
def tab_width(d,word,reading):
    w=max(d.textlength(word,font=mf(24)),d.textlength(reading,font=gf(16)))
    return max(MINW,int(PAD+8+w+10+STAMP+PAD))      # strip + text + stamp: width follows the word
def tab(d,x,y,word,reading,learned,maxw=None):
    w=tab_width(d,word,reading)
    if maxw: w=min(w,maxw)
    fill=PAPER if learned else FADED
    d.rounded_rectangle((x+6,y+6,x+w+6,y+TAB_H+40),6,fill=(30,18,14))            # shadow on the card behind
    d.rounded_rectangle((x,y,x+w,y+TAB_H+40),6,fill=fill,outline=INK,width=4)     # card goes down behind the next one
    d.rectangle((x+4,y+4,x+10,y+TAB_H+36),fill=AMBER if learned else GREY)
    d.text((x+PAD+8,y+24),word,font=mf(24),fill=INK if learned else SUB,anchor='lm')
    d.text((x+PAD+8,y+50),reading,font=gf(16),fill=SUB,anchor='lm')
    cx,cy=x+w-PAD-STAMP//2,y+32
    d.ellipse((cx-15,cy-15,cx+15,cy+15),outline=RED if learned else GREY,width=3)
    d.text((cx,cy),"読" if learned else "再",font=mf(18),fill=RED if learned else GREY,anchor='mm')
    return w
# 1) in the scene
im=Image.open(f'{S}/mock_v10_text.png').convert('RGB'); d=ImageDraw.Draw(im)
d.rectangle((1040,404,1206,600),fill=(78,48,32))                                 # empty box inside (cards now drawn in code)
words=[("分","ふん",True),("自分","じぶん",True),("半分","はんぶん",False)]
for i,(w,r,ok) in enumerate(words):
    tab(d,1044,408+i*64,w,r,ok,maxw=200)
plank=Image.open(f'{S}/mock_v10_text.png').convert('RGB').crop((1040,600,1270,700)); im.paste(plank,(1040,600))
im.save(f'{S}/mock_v10_tabs.png')
# 2) the same tab with words of 1-4 kanji
c=Image.new('RGB',(1280,720),(51,35,46)); d=ImageDraw.Draw(c)
d.text((60,50),"인덱스 탭: 단어 길이에 맞춰 폭이 바뀜 (높이 64px 고정, 최소 96px)",font=gf(24),fill=(239,231,180))
samples=[("分","ふん",True),("自分","じぶん",True),("分かる","わかる",True),("自転車","じてんしゃ",False),("一昨日","おととい",True),("図書館","としょかん",False)]
for i,(w,r,ok) in enumerate(samples):
    x=80; y=120+i*92
    tw=tab(d,x,y,w,r,ok)
    d.rectangle((x-10,y+TAB_H+4,x+tw+40,y+TAB_H+44),fill=(51,35,46))       # cut the card's lower part for the list
    d.text((x+tw+30,y+32),f"폭 {tw}px",font=gf(18),fill=(239,231,180),anchor='lm')
c.save(f'{S}/mock_tabs_lengths.png')
