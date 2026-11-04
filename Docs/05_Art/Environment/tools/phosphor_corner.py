"""연구소 구석 시안 — 콘크리트 + 담쟁이 + 크림 CRT (정확한 2:1 아이소, 8프레임). usage: phosphor_corner.py <out_dir> <preview_dir>

기준: Docs/05_Art/StyleRef/ART_BIBLE.md. 에셋 밀도 = 방 픽셀 1칸에 2칸 (바닥 한 칸 64×32).
아이소 그리기: 바닥 좌표 (x, y)와 높이 z를 화면으로 P(x,y,z) = (ox + x - y, oy + (x + y) / 2 - z).
보이는 면은 위(z 최대) · 왼앞(y 최대) · 오른앞(x 최대). 빛은 왼쪽 위 → 위 > 왼앞 > 오른앞 순으로 밝음.
물건마다 따로 그린 뒤 잉크 외곽선을 둘러 겹침 (뒤 → 앞 순서).
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT, PREV = Path(sys.argv[1]), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
F = 8
W, H = 176, 190
OX, OY = 88, 92


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK = hx("231620")
CR0, CR1, CR2, CR3, CR4, CR5 = hx("736A54"), hx("A39372"), hx("C0AD88"), hx("DEC792"), hx("EFE7B4"), hx("F7F2D6")
WD0, WD1, WD2, WD3, WD4 = hx("5B3330"), hx("774C44"), hx("AE7155"), hx("B28B69"), hx("C4A078")
P0, P1, P2, P3, P4, P5 = hx("16301F"), hx("27593A"), hx("2E7445"), hx("46965A"), hx("96E68C"), hx("D2FFBE")
IV0, IV1, IV2, IV3, IV4, IV5 = hx("1B2519"), hx("3A452E"), hx("3F5B3A"), hx("6A7B55"), hx("8EA05E"), hx("B4C878")
CO0, CO1, CO2, CO3 = hx("4E4F36"), hx("6B6C48"), hx("7D7C57"), hx("908F67")
FL0, FL1, FL2 = hx("33232E"), hx("4B2F31"), hx("5B3A36")
AM, RED = hx("FADC78"), hx("D65C5C")
CLEAR = (0, 0, 0, 0)


def P(x, y, z=0):
    return (round(OX + x - y), round(OY + (x + y) / 2 - z))


def layer():
    return Image.new("RGBA", (W, H))


def outline(img, c=INK):
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(H):
        for x in range(W):
            if not src[x, y][3] and any(0 <= x + dx < W and 0 <= y + dy < H and src[x + dx, y + dy][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


def box(img, x0, y0, z0, x1, y1, z1, top, left, right, hi=None):
    d = ImageDraw.Draw(img)
    d.polygon([P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)], fill=left)    # 왼앞 (y=y1)
    d.polygon([P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1)], fill=right)   # 오른앞 (x=x1)
    d.polygon([P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], fill=top)     # 위
    if hi:   # 위 · 앞 모서리에 빛 1px
        d.line([P(x0, y1, z1), P(x1, y1, z1)], fill=hi)
        d.line([P(x1, y1, z1), P(x1, y0, z1)], fill=hi)


def line(img, a, b, c):
    ImageDraw.Draw(img).line([a, b], fill=c)


# ── 정지 배경: 벽 · 바닥 ─────────────────────────────────────────
WALL_H = 86
SIZE = 84


def room():
    img = layer()
    d = ImageDraw.Draw(img)
    rng = random.Random(3)
    d.polygon([P(0, 0, 0), P(SIZE, 0, 0), P(SIZE, 0, WALL_H), P(0, 0, WALL_H)], fill=CO2)       # 오른뒤 벽 (y=0)
    d.polygon([P(0, 0, 0), P(0, SIZE, 0), P(0, SIZE, WALL_H), P(0, 0, WALL_H)], fill=CO1)       # 왼뒤 벽 (x=0)
    for z in range(4, WALL_H, 21):                                                              # 거푸집 이음 줄
        line(img, P(0, 0, z), P(SIZE, 0, z), CO1)
        line(img, P(0, 0, z), P(0, SIZE, z), CO0)
    for x in range(10, SIZE, 21):                                                               # 폼타이 구멍
        for z in range(14, WALL_H, 21):
            img.putpixel(P(x, 0, z), CO0)
            img.putpixel(P(0, x, z), hx("3E3F2B"))
    for _ in range(140):                                                                        # 얼룩 · 물때
        x, z = rng.randint(2, SIZE - 2), rng.randint(2, WALL_H - 2)
        img.putpixel(P(x, 0, z), rng.choice([CO1, CO3, CO1]))
        x, z = rng.randint(2, SIZE - 2), rng.randint(2, WALL_H - 2)
        img.putpixel(P(0, x, z), rng.choice([CO0, CO2, CO0]))
    for x in range(0, SIZE, 6):                                                                 # 바닥 아래 물 자국 띠
        for z in range(0, 5):
            if rng.random() < 0.6:
                img.putpixel(P(x + rng.randint(0, 5), 0, z), CO1)
    d.polygon([P(0, 0, 0), P(SIZE, 0, 0), P(SIZE, SIZE, 0), P(0, SIZE, 0)], fill=FL1)           # 바닥
    for k in range(0, SIZE + 1, 12):                                                            # 바닥 판 줄눈
        line(img, P(k, 0, 0), P(k, SIZE, 0), FL0)
    for k in range(0, SIZE + 1, 28):
        line(img, P(0, k, 0), P(SIZE, k, 0), FL0)
    for _ in range(40):
        img.putpixel(P(rng.randint(1, SIZE - 1), rng.randint(1, SIZE - 1), 0), FL2)
    line(img, P(0, 0, WALL_H), P(SIZE, 0, WALL_H), CO3)                                         # 벽 윗선 빛
    line(img, P(0, 0, WALL_H), P(0, SIZE, WALL_H), CO3)
    line(img, P(0, 0, 0), P(0, 0, WALL_H), CO0)                                                 # 모서리 그늘
    paper = [(46, 50), (60, 50), (60, 68), (46, 68)]                                            # 벽에 붙인 종이
    d.polygon([P(x, 0, z) for x, z in paper], fill=CR4)
    for z in range(53, 66, 3):
        line(img, P(48, 0, z), P(57 if z % 6 else 54, 0, z), CR1)
    img.putpixel(P(53, 0, 69), RED)                                                             # 압정
    return img


# ── 책상 · CRT · 소품 (프레임마다 화면만 바뀜) ─────────────────────────
def crt(img, x0, y0, z0, w, dep, h, f, phase, nature=False):
    lay = layer()
    x1, y1, z1 = x0 + w, y0 + dep, z0 + h
    box(lay, x0 + 3, y0, z0, x1 - 3, y1 - 6, z1 - 3, CR2, CR1, CR0)                              # 뒤 통 (브라운관 엉덩이)
    box(lay, x0, y1 - 8, z0, x1, y1, z1, CR4, CR3, CR1, hi=CR5)                                 # 앞 틀
    d = ImageDraw.Draw(lay)
    sx0, sx1, sz0, sz1 = x0 + 3, x1 - 3, z0 + 5, z1 - 4                                         # 화면 (왼앞 면 위)
    d.polygon([P(sx0 - 1, y1, sz0 - 1), P(sx1 + 1, y1, sz0 - 1), P(sx1 + 1, y1, sz1 + 1), P(sx0 - 1, y1, sz1 + 1)], fill=hx("4A3A34"))
    d.polygon([P(sx0, y1, sz0), P(sx1, y1, sz0), P(sx1, y1, sz1), P(sx0, y1, sz1)], fill=P1)
    for z in range(sz0, sz1 + 1, 2):                                                            # 주사선
        line(lay, P(sx0, y1, z), P(sx1, y1, z), hx("234F34"))
    if nature:   # 담쟁이 화면: 녹색 숲 영상이 일렁임
        rng = random.Random(9 + f // 2)
        for _ in range(26):
            x, z = rng.uniform(sx0 + 1, sx1 - 1), rng.uniform(sz0 + 1, sz1 - 1)
            lay.putpixel(P(x, y1, z), rng.choice([P3, IV4, P4, IV5]))
    else:        # 코드 화면: 한 줄씩 타자 + 커서
        rows = list(range(sz1 - 3, sz0 + 1, -3))
        shown = (f + phase) % (len(rows) + 3)
        rng = random.Random(phase)
        lens = [rng.randint(4, sx1 - sx0 - 3) for _ in rows]
        for i, z in enumerate(rows[:shown]):
            line(lay, P(sx0 + 2, y1, z), P(sx0 + 2 + lens[i], y1, z), P4 if i % 4 else P5)
            if i % 3 == 1:
                lay.putpixel(P(sx0 + 3 + lens[i] // 2, y1, z), hx("E68C8C"))                     # 분홍 오류 글자
        if shown < len(rows) and f % 2 == 0:
            z = rows[shown]
            for k in range(3):
                lay.putpixel(P(sx0 + 2 + k, y1, z), P5)
                lay.putpixel(P(sx0 + 2 + k, y1, z + 1), P5)
    gx, gz = sx0 + 1, sz1 - 1                                                                   # 유리 반사
    lay.putpixel(P(gx, y1, gz), P3)
    lay.putpixel(P(gx + 1, y1, gz), P3)
    lay.putpixel(P(x1 - 2, y1, z0 + 2), P4 if f != 5 else hx("5A4A40"))                          # 전원 LED
    lay.putpixel(P(x1 - 4, y1, z0 + 2), AM if (f + phase) % 3 == 0 else hx("5A4A40"))           # 디스크 램프
    for k in range(3):                                                                          # 앞 통풍 줄
        line(lay, P(x0 + 2, y1, z0 + 1 + k), P(x0 + 6, y1, z0 + 1 + k), CR1 if k % 2 else CR2)
    img.alpha_composite(outline(lay))


def desk_and_things(f):
    img = layer()
    lay = layer()
    box(lay, 6, 2, 0, 76, 30, 2, WD1, WD0, WD0)                                                 # 바닥 받침 그늘
    for (x, y) in ((8, 26), (72, 26), (8, 4), (72, 4)):                                         # 다리
        box(lay, x, y, 0, x + 3, y + 3, 24, WD2, WD1, WD0)
    box(lay, 6, 2, 24, 78, 30, 28, WD3, WD2, WD1, hi=WD4)                                       # 상판
    for x in range(12, 76, 9):
        line(lay, P(x, 30, 25), P(x + 4, 30, 25), WD1)                                          # 나뭇결
    img.alpha_composite(outline(lay))
    crt(img, 10, 4, 28, 30, 24, 28, f, 0)
    crt(img, 44, 4, 28, 28, 22, 24, f, 3, nature=True)
    crt(img, 13, 6, 56, 24, 20, 22, f, 5)                                                       # 위에 쌓은 작은 CRT
    lay = layer()
    box(lay, 14, 22, 28, 40, 30, 30, CR3, CR2, CR1, hi=CR5)                                     # 키보드
    for x in range(16, 39, 3):
        for y in (24, 26, 28):
            lay.putpixel(P(x, y, 30), CR1)
    box(lay, 64, 18, 28, 70, 24, 38, WD2, WD1, WD0)                                              # 연필꽂이
    for k, c in enumerate((RED, P3, AM, hx("5A7AA0"), CR4)):
        x, y = 65 + k, 19 + (k % 2) * 2
        line(lay, P(x, y, 38), P(x - 1, y, 44 + k % 3), c)
    box(lay, 48, 24, 28, 60, 30, 29, CR5, CR3, CR2)                                             # 종이 몇 장
    line(lay, P(50, 30, 29), P(58, 30, 29), CR1)
    img.alpha_composite(outline(lay))
    lay = layer()
    box(lay, 8, 60, 0, 22, 74, 12, WD2, WD1, WD0, hi=WD4)                                       # 화분
    img.alpha_composite(outline(lay))
    return img


# ── 담쟁이 (벽 위에서 늘어짐 + 화분에서 올라감) ─────────────────────────
def vines(seed):
    rng = random.Random(seed)
    strands = []
    for k in range(12):                                                                         # 벽 윗선에서 내려오는 줄기
        on_left = k % 2 == 0
        t = rng.uniform(2, SIZE - 4)
        top = P(0, t, WALL_H) if on_left else P(t, 0, WALL_H)
        length = rng.randint(18, 70)
        pts, x, y = [], top[0], top[1]
        for _ in range(length):
            pts.append((x, y))
            y += 1
            if rng.random() < 0.3:
                x += rng.choice((-1, 1))
        strands.append(pts)
    pts, x, y = [], *P(15, 67, 12)                                                              # 화분에서 벽을 타고 오름
    for _ in range(60):
        pts.append((x, y))
        y -= 1
        if rng.random() < 0.35:
            x += rng.choice((-1, 0, 1))
    strands.append(pts)
    leaves = []
    for s in strands:
        for i, (x, y) in enumerate(s):
            if rng.random() < 0.32:
                leaves.append((x + rng.choice((-2, -1, 1)), y, rng.random(), rng.random() < 0.18))
    return strands, leaves


STRANDS, LEAVES = vines(11)


def ivy(f):
    img = layer()
    px = img.load()
    for s in STRANDS:
        for x, y in s:
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = IV1
    for i, (x, y, r, sways) in enumerate(LEAVES):
        if sways and f in (2, 3, 6):
            x += 1
        shade = IV2 if r < 0.35 else (IV3 if r < 0.75 else IV4)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (1, 1), (0, -1)):
            if 0 <= x + dx < W and 0 <= y + dy < H and (dx, dy) != (1, 1) or r > 0.5:
                if 0 <= x + dx < W and 0 <= y + dy < H:
                    px[x + dx, y + dy] = shade
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = IV5 if shade == IV4 else IV4
    return outline(img, IV0)


def glow(f):
    """화면 형광이 벽에 번지는 빛 (숨 쉬듯)."""
    img = layer()
    d = ImageDraw.Draw(img)
    a = [26, 30, 34, 38, 34, 30, 26, 22][f]
    cx, cy = P(28, 0, 52)
    for r, k in ((26, 0.5), (18, 0.8), (11, 1.0)):
        d.ellipse([cx - r, cy - r // 2 - 6, cx + r, cy + r // 2 - 6], fill=(150, 230, 140, int(a * k)))
    return img


ROOM = room()
frames = []
for f in range(F):
    img = ROOM.copy()
    img.alpha_composite(glow(f))
    img.alpha_composite(desk_and_things(f))
    img.alpha_composite(ivy(f))
    frames.append(img)

strip = Image.new("RGBA", (W * F, H))
for i, fr in enumerate(frames):
    strip.alpha_composite(fr, (i * W, 0))
strip.save(OUT / "corner_phosphor_ivy.png")
bg = (24, 18, 26, 255)
big = []
for fr in frames:
    b = Image.new("RGBA", (W, H), bg)
    b.alpha_composite(fr)
    big.append(b.resize((W * 3, H * 3), Image.NEAREST))
big[0].save(PREV / "preview_corner_phosphor_ivy.gif", save_all=True, append_images=big[1:], duration=150, loop=0, disposal=2)
big[1].save(PREV / "preview_corner_phosphor_ivy.png")
print("ok")
