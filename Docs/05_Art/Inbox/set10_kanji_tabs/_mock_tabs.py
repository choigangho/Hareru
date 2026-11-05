import sys
from PIL import Image, ImageDraw, ImageFont
S, OUT = sys.argv[1], sys.argv[2]
base = Image.open(f'{S}/base_238.png').convert('RGB')
rd = Image.open(f'{S}/base_read.png').convert('RGB')
base.paste(rd.crop((0, 648, 1280, 720)), (0, 648))          # no subtitle band
base.paste(rd.crop((1040, 0, 1280, 300)), (1040, 0))        # monitor without the chief's face
MIN = '/System/Library/Fonts/ヒラギノ明朝 ProN.ttc'
GOT = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
def mf(sz): return ImageFont.truetype(MIN, sz, index=0)
def gf(sz): return ImageFont.truetype(GOT, sz, index=0)
INK = (40, 30, 30); PAPER = (247, 240, 214); FADED = (205, 196, 172); AMBER = (232, 150, 40)
GREEN = (96, 200, 120); EMPTY = (190, 180, 160); RED = (200, 50, 40)

def box(d, r, fill, outline=INK, w=4, shadow=True):
    x0, y0, x1, y1 = r
    if shadow:
        d.rectangle((x0 + 8, y0 + 8, x1 + 8, y1 + 8), fill=(30, 18, 14))
    d.rectangle(r, fill=fill, outline=outline, width=w)

def dots(d, x, y, n, size=8, gap=4):
    for i in range(4):
        d.rectangle((x + i * (size + gap), y, x + i * (size + gap) + size - 1, y + size - 1), fill=GREEN if i < n else EMPTY)

TABS = [("自分", 3, True), ("多分", 1, True), ("半分", 0, False)]   # word, stability dots, learned?
TAB_X, TAB_W, TAB_H, TAB_Y0 = 132, 92, 68, 352     # index tabs out of the pile's right side (hit area >= 64)
def tabs(img, skip=None):
    d = ImageDraw.Draw(img)
    for i, (w, n, learned) in enumerate(TABS):
        y = TAB_Y0 + i * (TAB_H + 6)
        if w == skip:
            continue
        box(d, (TAB_X, y, TAB_X + TAB_W, y + TAB_H), PAPER if learned else FADED, shadow=False)
        d.rectangle((TAB_X + TAB_W - 10, y + 4, TAB_X + TAB_W - 5, y + TAB_H - 4), fill=AMBER if learned else EMPTY)
        tx = TAB_X + 28 + (TAB_W - 28 - 10) // 2
        d.text((tx, y + 24), w, font=mf(20), fill=INK if learned else (110, 100, 85), anchor='mm')
        if learned:
            dots(d, tx - 23, y + 46, n, size=10, gap=2)
        else:
            d.text((tx, y + 50), "지나침", font=gf(16), fill=(110, 100, 85), anchor='mm')
    # tabs tuck under the pile's top sheets on the left
    img.paste(base.crop((0, 340, TAB_X + 28, 600)), (0, 340))
    # label: which kanji links them
    d.rectangle((8, 270, 160, 298), fill=(16, 12, 14))
    d.text((18, 284), "分", font=mf(20), fill=AMBER, anchor='lm')
    d.text((44, 284), "지난 문서 3", font=gf(16), fill=(240, 228, 200), anchor='lm')
    # the shared kanji in the headword
    d.rectangle((572, 306, 628, 309), fill=AMBER)

a = base.copy()
tabs(a)
a.save(f'{OUT}/mock_a_tabs.png')

b = base.copy()
tabs(b, skip="自分")
d = ImageDraw.Draw(b)
r = (24, 236, 396, 536)
box(d, r, PAPER)
d.text((44, 262), "판독 기록 · 3일 전", font=gf(16), fill=(120, 110, 95), anchor='lm')
d.text((210, 300), "じぶん", font=mf(16), fill=(90, 80, 70), anchor='mm')
d.text((210, 342), "自分", font=mf(48), fill=INK, anchor='mm')
d.rectangle((210, 372, 258, 375), fill=AMBER)
d.text((210, 396), "자기, 자신", font=gf(20), fill=(70, 60, 50), anchor='mm')
d.text((48, 440), "自分で作ってみます。", font=mf(22), fill=INK, anchor='lm')
d.text((48, 472), "직접 만들어 볼게요.", font=gf(16), fill=(90, 80, 70), anchor='lm')
d.text((48, 500), "안정도", font=gf(16), fill=(90, 80, 70), anchor='lm')
dots(d, 108, 492, 3, size=14, gap=4)
cx, cy = 340, 484
d.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), outline=RED, width=4)
d.text((cx, cy), "読", font=mf(30), fill=RED, anchor='mm')
d.text((210, 520), "클릭 · Esc  되돌려 놓기", font=gf(16), fill=(120, 110, 95), anchor='mm')
b.save(f'{OUT}/mock_b_pulled.png')
