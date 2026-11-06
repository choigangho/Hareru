import sys
from PIL import Image, ImageDraw, ImageFont
S=sys.argv[1]
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
# 1) in the scene
base=Image.open(f'{S}/mock_v10_text.png').convert('RGB'); im=base.copy(); d=ImageDraw.Draw(im)
d.rectangle((1040,404,1206,600),fill=(78,48,32))
X,W=1044,158
cards=[("分","ふん",True,0),("自分","じぶん",True,48),("半分","はんぶん",False,86)]
for i,(w,r,ok,tx) in enumerate(cards):
    folder(d,X,402+i*64,W,w,r,ok,tx)
im.paste(base.crop((1040,600,1270,700)),(1040,600))
im.save(f'{S}/mock_v10_folder_tabs.png')
# 2) tab width by word length
c=Image.new('RGB',(1280,720),(51,35,46)); d=ImageDraw.Draw(c)
d.text((60,40),"파일 인덱스 탭: 탭 폭이 단어 길이에 맞춰 바뀜 (탭 높이 34 + 띠 30 = 누르는 높이 64px)",font=gf(22),fill=(239,231,180))
samples=[("分","ふん",True),("自分","じぶん",True),("分かる","わかる",True),("自転車","じてんしゃ",False),("一昨日","おととい",True),("お弁当","おべんとう",False)]
for i,(w,r,ok) in enumerate(samples):
    y=100+i*100; x=80
    tw=folder(d,x,y,260,w,r,ok,(i%3)*50)
    d.rectangle((x-10,y+TAB_H+STRIP+4,x+300,y+TAB_H+STRIP+70),fill=(51,35,46))
    d.text((x+300,y+TAB_H),f"탭 폭 {tw}px",font=gf(18),fill=(239,231,180),anchor='lm')
c.save(f'{S}/mock_folder_tab_lengths.png')
