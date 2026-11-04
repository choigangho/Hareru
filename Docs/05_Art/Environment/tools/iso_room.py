"""연구소 아이소메트릭 v2 — 1단계 방 · 시설 6종 · 배치 시안. usage: iso_room.py <out_dir> <preview_dir> <characters_dir>

기준: Docs/05_Art/StyleRef/ART_BIBLE.md (Phosphor 팔레트 · 크림 CRT · 담쟁이 · 높은 대비) + §9 아이소 규격.
규격 (v2): **1px = 1pt** (UI와 같음). 바닥 한 칸 = 64×32 px = 축마다 32단위. 1칸 ≈ 1m, 높이 1m ≈ 30px.
투영: P(x, y, z) = (OX + x - y, OY + (x + y) / 2 - z). 보이는 면: 위(가장 밝음) · 왼앞(y 최대, 중간) · 오른앞(x 최대, 어두움).
물건마다 따로 그린 뒤 잉크 외곽선을 두르고 뒤 → 앞(열 + 행 순)으로 겹침. 시설은 칸 마름모의 아래 꼭짓점이 그림 바닥.
움직임: 8프레임 · 150ms (화면 글줄 · LED · 테이프 릴 · VU 바늘 · 램프 깜빡임 · 비).
"""
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT, PREV, CHARS = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
OUT.mkdir(parents=True, exist_ok=True)
F = 8
U = 32                                   # 한 칸 = 32단위 (화면 64×32)
GRID = 6
MARGIN = 12                              # 벽과 격자 사이 소품 띠
FLOOR = GRID * U + MARGIN                # 바닥 한 변 (204단위)
WALL_H = 100                             # 벽 높이 (≈3.3m)
WALL_T = 8                               # 벽 두께 (잘린 단면이 보임)


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK, INK_DEEP = hx("231620"), hx("0E090C")
CREAM = [hx("5E5444"), hx("8C7C5E"), hx("B3A07C"), hx("D4BE8C"), hx("EBDFAE"), hx("FFF7DC")]
PUTTY = [hx("2E2C22"), hx("4E4C38"), hx("6E6C4C"), hx("8E8B62"), hx("B0AC80"), hx("D8D4A8")]
CHAR = [hx("141012"), hx("241E20"), hx("38302F"), hx("524844"), hx("74685E"), hx("A89C8A")]
WOOD = [hx("2A1A18"), hx("44282A"), hx("5B3330"), hx("774C44"), hx("9A6448"), hx("B88A62"), hx("D6B080")]
CONC = [hx("2E2E22"), hx("44452F"), hx("5A5B3E"), hx("6E6E4C"), hx("82805C"), hx("98966E"), hx("B0AE86")]
PH = [hx("1F5A33"), hx("2F8A4A"), hx("4CC067"), hx("8AF08A"), hx("D4FFC8")]
GLASS_A, GLASS_B, GLASS_E = hx("1C4A2C"), hx("18422A"), hx("0E2616")
IVY = [hx("0F1A10"), hx("22361E"), hx("36522C"), hx("4E7438"), hx("6E9A46"), hx("A6CC6A")]
AMBERK = [hx("5A2A14"), hx("94481E"), hx("D0702A"), hx("F09A3C"), hx("FFC468"), hx("FFE8B0")]
REDK = [hx("3C0E10"), hx("701C1E"), hx("A82E2C"), hx("D24A42"), hx("F27A68"), hx("FFC0A8")]
METAL = [hx("2A2C30"), hx("484C52"), hx("6C7076"), hx("94989C"), hx("BEC2C2"), hx("E6E8E2")]
FOAM = [hx("1E2A2C"), hx("2C3E40"), hx("3C5456"), hx("4E6A6C")]
PAPER = [hx("B8AA8C"), hx("D8CCAE"), hx("EEE6CE"), hx("FBF6E6")]
CYAN, CYAN_D = hx("2CE8F5"), hx("0A6A76")
LED_OFF = hx("3A2C2A")
CLEAR = (0, 0, 0, 0)
manifest = {}

# ── 그리기 도구 ───────────────────────────────────────────────────


class Iso:
    def __init__(self, w, h, ox, oy):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy

    def P(self, x, y, z=0):
        return (round(self.ox + x - y), round(self.oy + (x + y) / 2 - z))

    def layer(self):
        return Image.new("RGBA", (self.w, self.h))


def poly(img, pts, c):
    ImageDraw.Draw(img).polygon(pts, fill=c)


def line(img, a, b, c, width=1):
    ImageDraw.Draw(img).line([a, b], fill=c, width=width)


def put(img, pts, c):
    px = img.load()
    w, h = img.size
    for x, y in pts:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c


def outline(img, c=INK):
    a = np.array(img.getchannel("A")) > 0
    edge = np.zeros_like(a)
    edge[1:, :] |= a[:-1, :]
    edge[:-1, :] |= a[1:, :]
    edge[:, 1:] |= a[:, :-1]
    edge[:, :-1] |= a[:, 1:]
    edge &= ~a
    arr = np.array(img)
    arr[edge] = c
    return Image.fromarray(arr, "RGBA")


def box(iso, img, x0, y0, z0, x1, y1, z1, top, left, right, hi=None, lo=None):
    """세 면 상자. hi: 윗면 앞 모서리 빛 · lo: 아래 접지 그늘."""
    P = iso.P
    poly(img, [P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)], left)
    poly(img, [P(x1, y0, z0), P(x1, y1, z0), P(x1, y1, z1), P(x1, y0, z1)], right)
    poly(img, [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], top)
    if hi:
        line(img, P(x0, y1, z1), P(x1, y1, z1), hi)
        line(img, P(x1, y1, z1), P(x1, y0, z1), hi)
        line(img, P(x1, y1, z1), P(x1, y1, z0), hi)
    if lo:
        line(img, P(x0, y1, z0 + 1), P(x1, y1, z0 + 1), lo)


def face_left(iso, y, x0, x1, z0, z1):
    P = iso.P
    return [P(x0, y, z0), P(x1, y, z0), P(x1, y, z1), P(x0, y, z1)]


def face_right(iso, x, y0, y1, z0, z1):
    P = iso.P
    return [P(x, y0, z0), P(x, y1, z0), P(x, y1, z1), P(x, y0, z1)]


def save(frames, name, note, anchor=None):
    frames = frames if isinstance(frames, list) else [frames]
    w, h = frames[0].size
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * w, 0))
    strip.save(OUT / f"{name}.png")
    manifest[name] = {"frame": [w, h], "frames": len(frames), "frame_ms": 150, "use": note,
                      **({"anchor_bottom_vertex": anchor} if anchor else {})}
    return frames


# ── 둥근 크림 CRT (아이소, 앞면 = y 최대 면) ─────────────────────────────
def crt(iso, img, x0, y0, z0, w, d, h, f, phase=0, kind="code", ramp=CREAM, small=False):
    lay = iso.layer()
    P = iso.P
    x1, y1, z1 = x0 + w, y0 + d, z0 + h
    box(iso, lay, x0 + 2, y0, z0 + 1, x1 - 2, y1 - 5, z1 - 2, ramp[3], ramp[2], ramp[1])           # 브라운관 엉덩이
    box(iso, lay, x0, y1 - 6, z0, x1, y1, z1, ramp[4], ramp[3], ramp[2], hi=ramp[5])                # 앞 틀
    for k in range(2, x1 - x0 - 2, 3):                                                            # 윗면 통풍 구멍
        lay.putpixel(P(x0 + k, y1 - 3, z1), ramp[2])
    # 둥근 앞 모서리: 네 귀퉁이 깎기
    for (cx, cz, sx, sz) in ((x0, z1, 1, -1), (x1, z1, -1, -1), (x0, z0, 1, 1), (x1, z0, -1, 1)):
        put(lay, [P(cx, y1, cz)], CLEAR)
        put(lay, [P(cx + sx, y1, cz)], ramp[2])
    # 화면: 파인 홈 → 볼록 유리 (가장자리 어둡게) → 주사선 → 내용
    sx0, sx1 = x0 + 2, x1 - 2
    sz0, sz1 = z0 + (4 if not small else 3), z1 - 2
    poly(lay, face_left(iso, y1, sx0 - 1, sx1 + 1, sz0 - 1, sz1 + 1), hx("3C2C28"))
    poly(lay, face_left(iso, y1, sx0, sx1, sz0, sz1), GLASS_E)
    poly(lay, face_left(iso, y1, sx0 + 1, sx1 - 1, sz0 + 1, sz1 - 1), GLASS_A)
    for z in range(sz0 + 1, sz1, 2):
        line(lay, P(sx0 + 1, y1, z), P(sx1 - 1, y1, z), GLASS_B)
    rng = random.Random(phase)
    if kind == "code":
        rows = list(range(sz1 - 2, sz0 + 1, -2))
        shown = (f + phase) % (len(rows) + 3)
        for i, z in enumerate(rows[:shown]):
            ln = rng.randint(2, max(3, sx1 - sx0 - 3))
            line(lay, P(sx0 + 2, y1, z), P(sx0 + 2 + ln, y1, z), PH[3] if i % 3 else PH[4])
        if shown < len(rows) and f % 2 == 0:
            put(lay, [P(sx0 + 2, y1, rows[shown]), P(sx0 + 3, y1, rows[shown])], PH[4])
    elif kind == "chart":
        for k in range(sx0 + 2, sx1 - 1, 2):
            hgt = 1 + int((math.sin(k * 0.9 + f * 0.8) + 1) * (sz1 - sz0 - 4) / 4)
            line(lay, P(k, y1, sz0 + 1), P(k, y1, sz0 + 1 + hgt), PH[2 if k % 4 else 3])
    elif kind == "nature":
        rr = random.Random(9 + f // 2)
        for _ in range(int((sx1 - sx0) * (sz1 - sz0) / 6)):
            put(lay, [P(rr.uniform(sx0 + 1, sx1 - 1), y1, rr.uniform(sz0 + 1, sz1 - 1))], rr.choice([PH[2], IVY[4], PH[3], IVY[5]]))
    put(lay, [P(sx0 + 1, y1, sz1 - 1), P(sx0 + 2, y1, sz1 - 1), P(sx0 + 1, y1, sz1 - 2)], PH[2])     # 유리 반사
    put(lay, [P(x1 - 2, y1, z0 + 1)], PH[3] if (f + phase) % 7 else LED_OFF)                         # 전원 LED
    put(lay, [P(x1 - 4, y1, z0 + 1)], AMBERK[4] if (f + phase) % 3 == 0 else LED_OFF)               # 디스크 램프
    img.alpha_composite(outline(lay))


def cable(img, pts, col, hi, width=2):
    d = ImageDraw.Draw(img)
    d.line(pts, fill=INK, width=width + 2, joint="curve")
    d.line(pts, fill=col, width=width, joint="curve")
    d.line([(x - 0, y - 1) for x, y in pts], fill=hi, width=1)


def droop_pts(a, b, sag, n=16):
    return [(a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n + sag * 4 * (t / n) * (1 - t / n)) for t in range(n + 1)]


def leaf(img, x, y, shade, flip):
    L = [".##..", "####.", "#####", ".###.", "..#.."]
    px = img.load()
    w, h = img.size
    for r, row in enumerate(L):
        for c, v in enumerate(row):
            if v != "#":
                continue
            cc = 4 - c if flip else c
            xx, yy = x + cc - 2, y + r - 2
            if 0 <= xx < w and 0 <= yy < h:
                col = IVY[2 + shade]
                if r + c < 3:
                    col = IVY[min(5, 3 + shade)]
                if r + (4 - c) > 5:
                    col = IVY[1 + shade]
                px[xx, yy] = col


def ivy_from(img, starts, seed, f, length=(20, 60), density=0.35, up=False):
    rng = random.Random(seed)
    lay = Image.new("RGBA", img.size)
    px = lay.load()
    w, h = img.size
    for sx, sy in starts:
        x, y = sx, sy
        n = rng.randint(*length)
        for i in range(n):
            if 0 <= x < w and 0 <= y < h:
                px[int(x), int(y)] = IVY[1]
            if rng.random() < density:
                sway = 1 if (rng.random() < 0.25 and f in (2, 3, 6)) else 0
                leaf(lay, int(x) + rng.choice((-2, 2)) + sway, int(y), rng.choice((0, 1, 1, 2)), rng.random() < 0.5)
            y += -1 if up else 1
            if rng.random() < 0.3:
                x += rng.choice((-1, 1))
    img.alpha_composite(outline(lay, IVY[0]))


# ── 1. 1단계 방 껍데기 (바닥 · 두 벽 · 창 · 문 · 벽 소품) ─────────────────────
RW, RH = 420, 330
ROOM = Iso(RW, RH, RW // 2, WALL_H + 14)


def room_shell(f):
    iso = ROOM
    P = iso.P
    img = iso.layer()
    rng = random.Random(3)
    T = WALL_T
    # 바닥 판 (두께 6 — 잘린 단면이 보이는 디오라마)
    box(iso, img, 0, 0, -6, FLOOR, FLOOR, 0, WOOD[3], WOOD[1], WOOD[0])
    for k in range(0, FLOOR, 8):                                                          # 마루 판 줄 (y 방향)
        line(img, P(0, k, 0), P(FLOOR, k, 0), WOOD[2])
    for k in range(0, FLOOR, 8):                                                          # 판 이음 (엇갈림)
        for x in range((k // 8 % 3) * 21, FLOOR, 64):
            line(img, P(x, k, 0), P(x, k + 8, 0), WOOD[1])
    for _ in range(260):                                                                  # 닳은 자국 · 먼지
        put(img, [P(rng.uniform(2, FLOOR - 2), rng.uniform(2, FLOOR - 2), 0)], rng.choice([WOOD[4], WOOD[2], WOOD[4], WOOD[5]]))
    for _ in range(140):                                                                  # 마루 결 (판 방향 짧은 줄)
        x, y = rng.uniform(2, FLOOR - 12), rng.uniform(1, FLOOR - 1)
        line(img, P(x, y, 0), P(x + rng.uniform(4, 10), y, 0), WOOD[2] if rng.random() < 0.7 else WOOD[4])
    rx0, ry0, rx1, ry1 = 66, 86, 170, 176                                                 # 바랜 러그 (청록 바탕 + 크림 테 + 무늬)
    poly(img, [P(rx0, ry0, 0), P(rx1, ry0, 0), P(rx1, ry1, 0), P(rx0, ry1, 0)], hx("3E5A52"))
    poly(img, [P(rx0 + 4, ry0 + 4, 0), P(rx1 - 4, ry0 + 4, 0), P(rx1 - 4, ry1 - 4, 0), P(rx0 + 4, ry1 - 4, 0)], hx("C8B48A"))
    poly(img, [P(rx0 + 6, ry0 + 6, 0), P(rx1 - 6, ry0 + 6, 0), P(rx1 - 6, ry1 - 6, 0), P(rx0 + 6, ry1 - 6, 0)], hx("4E6E62"))
    for x in range(rx0 + 12, rx1 - 8, 12):                                                 # 마름모 무늬
        for y in range(ry0 + 12, ry1 - 8, 12):
            poly(img, [P(x, y - 3, 0), P(x + 3, y, 0), P(x, y + 3, 0), P(x - 3, y, 0)], hx("6E8A6E") if (x + y) % 24 else hx("A8865A"))
    for _ in range(160):                                                                  # 닳은 자리
        put(img, [P(rng.uniform(rx0 + 6, rx1 - 6), rng.uniform(ry0 + 6, ry1 - 6), 0)], hx("5E7A6E"))
    for y in range(ry0, ry1, 3):                                                           # 술
        line(img, P(rx1, y, 0), P(rx1 + 2, y + 1, 0), hx("C8B48A"))
    # 왼뒤 벽 (x = 0 평면, 두께는 x 음수 쪽)
    box(iso, img, -T, -T, 0, 0, FLOOR, WALL_H, CONC[5], CONC[3], CONC[2])
    poly(img, [P(0, 0, 0), P(0, FLOOR, 0), P(0, FLOOR, WALL_H), P(0, 0, WALL_H)], CONC[3])
    # 오른뒤 벽 (y = 0 평면)
    box(iso, img, -T, -T, 0, FLOOR, 0, WALL_H, CONC[5], CONC[4], CONC[3])
    poly(img, [P(0, 0, 0), P(FLOOR, 0, 0), P(FLOOR, 0, WALL_H), P(0, 0, WALL_H)], CONC[4])
    for z in range(6, WALL_H, 24):                                                         # 거푸집 이음
        line(img, P(0, 0, z), P(FLOOR, 0, z), CONC[3])
        line(img, P(0, 0, z), P(0, FLOOR, z), CONC[2])
    for x in range(14, FLOOR, 24):                                                         # 폼타이 구멍
        for z in range(18, WALL_H, 24):
            put(img, [P(x, 0, z)], CONC[2])
            put(img, [P(0, x, z)], CONC[1])
    for _ in range(320):                                                                   # 물때 · 얼룩
        x, z = rng.uniform(1, FLOOR - 1), rng.uniform(1, WALL_H - 1)
        put(img, [P(x, 0, z)], rng.choice([CONC[3], CONC[5], CONC[3]]))
        x, z = rng.uniform(1, FLOOR - 1), rng.uniform(1, WALL_H - 1)
        put(img, [P(0, x, z)], rng.choice([CONC[2], CONC[4], CONC[2]]))
    for x in range(146, 162):                                                              # 천장 누수 물자국 (오른뒤 벽 위)
        for z in range(WALL_H - 30 + (x * 7) % 9, WALL_H):
            if rng.random() < 0.55:
                put(img, [P(x, 0, z)], CONC[2])
    for k in range(0, FLOOR):                                                              # 걸레받이
        put(img, [P(k, 0, 1), P(k, 0, 2)], CONC[1])
        put(img, [P(0, k, 1), P(0, k, 2)], CONC[0])
    line(img, P(0, 0, 0), P(0, 0, WALL_H), CONC[1])                                        # 모서리 그늘
    # 왼뒤 벽 창 (y 40~120, z 30~84): 금 간 유리 너머 비 오는 도시 · 시안 렉스코드 간판
    wy0, wy1, wz0, wz1 = 44, 124, 30, 84
    poly(img, face_right(iso, 0, wy0 - 3, wy1 + 3, wz0 - 3, wz1 + 3), WOOD[2])
    poly(img, face_right(iso, 0, wy0, wy1, wz0, wz1), hx("1A2230"))
    sky = random.Random(5)
    for k in range(18):                                                                    # 먼 빌딩 실루엣
        by = wy0 + 2 + k * 4.4
        bh = sky.randint(10, 40)
        poly(img, face_right(iso, 0, by, by + 4, wz0, wz0 + bh), hx("232C3A") if k % 2 else hx("1E2734"))
        for z in range(wz0 + 3, wz0 + bh - 2, 4):
            if sky.random() < 0.35:
                put(img, [P(0, by + 2, z)], CYAN_D if sky.random() < 0.7 else AMBERK[3])
    for (sy0, sz0, sw, sh) in ((60, 48, 8, 10), (98, 56, 10, 8)):                          # 렉스코드(QR) 간판
        on = (f + sy0) % 5 != 0
        poly(img, face_right(iso, 0, sy0, sy0 + sw, sz0, sz0 + sh), CYAN if on else CYAN_D)
        for k in range(6):
            put(img, [P(0, sy0 + 1 + (k * 3) % sw, sz0 + 1 + (k * 5) % sh)], hx("0E3A40"))
    for k in range(9):                                                                     # 비 (프레임마다 내려감)
        ry = wy0 + 4 + (k * 9.3) % (wy1 - wy0 - 6)
        rz = wz1 - 2 - ((f * 5 + k * 13) % (wz1 - wz0 - 4))
        line(img, P(0, ry, rz), P(0, ry - 1, rz - 3), hx("5A6C80"))
    for (a, b) in (((60, 80), (78, 66)), ((78, 66), (84, 58)), ((78, 66), (90, 70))):      # 유리 금
        line(img, P(0, a[0], a[1]), P(0, b[0], b[1]), hx("C8D4DC"))
    for y in (wy0 + (wy1 - wy0) // 2,):                                                    # 창살
        poly(img, face_right(iso, 0, y - 1, y + 1, wz0, wz1), WOOD[3])
    poly(img, face_right(iso, 0, wy0 - 4, wy1 + 4, wz0 - 6, wz0 - 3), WOOD[4])              # 창턱
    # 오른뒤 벽: 게시판 「常駐人員: 2」 · 화이트보드 · 문 · 케이블 선반
    poly(img, face_left(iso, 0, 22, 54, 46, 70), WOOD[3])                                  # 게시판 (분필판)
    poly(img, face_left(iso, 0, 24, 52, 48, 68), hx("2E4238"))
    for k, x in enumerate(range(27, 47, 5)):
        line(img, P(x, 0, 62), P(x + 3, 0, 60), hx("D8DAD0"))
        line(img, P(x + 1, 0, 58), P(x + 3, 0, 62), hx("D8DAD0"))
    line(img, P(48, 0, 61), P(50, 0, 59), hx("D8DAD0"))
    poly(img, face_left(iso, 0, 64, 112, 36, 72), METAL[3])                                # 화이트보드
    poly(img, face_left(iso, 0, 66, 110, 38, 70), hx("ECECE4"))
    pts = [P(70 + i, 0, 66 - 22 * (1 - 0.88 ** i)) for i in range(0, 36, 2)]              # 망각 곡선
    ImageDraw.Draw(img).line(pts, fill=REDK[2])
    poly(img, face_left(iso, 0, 150, 182, 0, 70), WOOD[2])                                 # 문
    poly(img, face_left(iso, 0, 152, 180, 0, 68), WOOD[3])
    poly(img, face_left(iso, 0, 156, 176, 40, 62), hx("9AA8A0"))                           # 젖빛 유리
    for x in range(158, 175, 3):
        put(img, [P(x, 0, 51)], hx("4A5A54"))                                              # 'NJL' 스텐실 자리
    put(img, [P(176, 0, 32), P(177, 0, 32)], AMBERK[4])                                    # 손잡이
    poly(img, face_left(iso, 0, 0, FLOOR, WALL_H - 10, WALL_H - 7), METAL[2])              # 천장 케이블 트레이
    for k in range(0, FLOOR, 10):
        put(img, [P(k, 0, WALL_H - 7)], METAL[4])
    cable(img, droop_pts(P(20, 0, WALL_H - 9), P(90, 0, WALL_H - 9), 10), CHAR[2], CHAR[4])
    cable(img, droop_pts(P(70, 0, WALL_H - 9), P(140, 0, WALL_H - 9), 14), CREAM[2], CREAM[4])
    cable(img, droop_pts(P(0, 30, WALL_H - 6), P(0, 100, WALL_H - 6), 12), REDK[2], REDK[4], 1)
    img.alpha_composite(room_ao(iso))
    return img


def room_ao(iso):
    """구석 그늘: 벽 아래 · 바닥의 벽 쪽 · 두 벽이 만나는 모서리를 어둡게, 벽 위쪽은 살짝 밝게."""
    P = iso.P
    ao = iso.layer()
    d = ImageDraw.Draw(ao)
    for k in range(16):
        a = int(90 * (1 - k / 16) ** 1.6)
        d.line([P(0, k, 0), P(FLOOR, k, 0)], fill=(8, 4, 8, a))
        d.line([P(k, 0, 0), P(k, FLOOR, 0)], fill=(8, 4, 8, a))
    for z in range(24):
        a = int(70 * (1 - z / 24) ** 1.4)
        d.line([P(0, 0, z), P(FLOOR, 0, z)], fill=(8, 4, 8, a))
        d.line([P(0, 0, z), P(0, FLOOR, z)], fill=(8, 4, 8, a))
    for k in range(14):
        a = int(60 * (1 - k / 14) ** 1.5)
        d.line([P(k, 0, 0), P(k, 0, WALL_H)], fill=(8, 4, 8, a))
        d.line([P(0, k, 0), P(0, k, WALL_H)], fill=(8, 4, 8, a))
    for z in range(WALL_H - 14, WALL_H):
        a = int(26 * (z - WALL_H + 14) / 14)
        d.line([P(0, 0, z), P(FLOOR, 0, z)], fill=(255, 240, 200, a))
        d.line([P(0, 0, z), P(0, FLOOR, z)], fill=(255, 240, 200, a))
    return ao


# 벽 앞 소품 띠 (격자 밖): 구석의 CRT 더미 · 전선 뭉치 · 책 더미 · 양동이 · 화분
def room_decor(f):
    iso = ROOM
    P = iso.P
    img = iso.layer()
    pile = [(1, 1, 0, 26, 12, 22, "code"), (28, 1, 0, 20, 11, 17, "chart"), (49, 2, 0, 14, 10, 12, "code"),
            (3, 2, 22, 22, 11, 19, "nature"), (27, 2, 17, 19, 10, 15, "code"), (6, 3, 41, 16, 9, 13, "chart"),
            (29, 3, 32, 13, 9, 11, "code")]
    for k, (x, y, z, w, d, h, kind) in enumerate(pile):                                   # 구석 CRT 더미 (조금씩 어긋나게 쌓음)
        crt(iso, img, x, y, z, w, d, h, f, phase=k * 3, kind=kind)
    lay = iso.layer()                                                                     # 더미에서 삐져나온 전선
    cable(lay, droop_pts(P(26, 13, 30), P(44, 16, 4), 6), CHAR[2], CHAR[4])
    cable(lay, droop_pts(P(22, 12, 50), P(48, 13, 22), 8), CREAM[2], CREAM[4])
    cable(lay, droop_pts(P(47, 13, 10), P(64, 14, 1), 4), REDK[2], REDK[4], 1)
    img.alpha_composite(lay)
    ivy_from(img, [P(8, 6, 54), P(18, 6, 54), P(32, 6, 43)], 33, f, length=(10, 34))
    lay = iso.layer()                                                                     # 바닥 전선 뭉치 (벽 따라)
    for k, (col, hi) in enumerate(((CHAR[2], CHAR[4]), (CREAM[2], CREAM[4]), (hx("2E4A34"), hx("4E7A54")))):
        pts = [P(44 + i * 6, 3 + k * 2 + math.sin(i * 0.8 + k) * 1.5, 1) for i in range(26)]
        cable(lay, pts, col, hi)
    img.alpha_composite(lay)
    lay = iso.layer()                                                                     # 책 더미 (왼벽 앞)
    for j, (bz, col) in enumerate(((0, WOOD[3]), (3, REDK[2]), (6, CREAM[3]), (9, hx("3E5A6A")), (12, WOOD[4]))):
        box(iso, lay, 2 + (j % 2), 150 + (j * 2) % 3, bz, 9 + (j % 2), 162 + (j * 2) % 3, bz + 3, PAPER[2], col, col)
    img.alpha_composite(outline(lay))
    lay = iso.layer()                                                                     # 양동이 + 물 (누수 아래)
    x, y = 150, 6
    for r in range(6, 0, -1):
        poly(lay, [P(x - r, y - r // 2 + 4, 0), P(x + r, y - r // 2 + 4, 0)], CLEAR)
    box(iso, lay, x - 5, y, 0, x + 5, y + 8, 10, hx("3E5A6A"), hx("4E6E80"), hx("324858"), hi=hx("7A98A8"))
    poly(lay, [P(x - 4, y + 1, 10), P(x + 4, y + 1, 10), P(x + 4, y + 7, 10), P(x - 4, y + 7, 10)], hx("2A3E4C"))
    img.alpha_composite(outline(lay))
    drop_z = WALL_H - (f * 12) % WALL_H                                                    # 떨어지는 물방울
    if drop_z > 10:
        put(img, [P(x, y + 4, drop_z), P(x, y + 4, drop_z - 1)], hx("A8C8D8"))
    lay = iso.layer()                                                                     # 화분 (앞 오른쪽 구석)
    box(iso, lay, 178, 2, 0, 188, 10, 9, WOOD[4], WOOD[3], WOOD[2], hi=WOOD[5])
    img.alpha_composite(outline(lay))
    ivy_from(img, [P(183, 6, 9)], 4, f, length=(30, 50), up=True)
    return img


def room_ivy(f):
    """벽 위에서 늘어지는 담쟁이 (방 앞쪽 레이어 — 시설보다 뒤, 벽보다 앞)."""
    iso = ROOM
    P = iso.P
    img = iso.layer()
    starts = [P(0, y, WALL_H) for y in (4, 22, 36, 130, 146, 170, 190)] + [P(x, 0, WALL_H) for x in (8, 30, 120, 186, 198)]
    ivy_from(img, starts, 11, f, length=(18, 70))
    return img


ROOM_FRAMES = []
for f in range(F):
    r = room_shell(f)
    r.alpha_composite(room_decor(f))
    r.alpha_composite(room_ivy(f))
    ROOM_FRAMES.append(r)
grid_origin = ROOM.P(MARGIN, MARGIN, 0)
save(ROOM_FRAMES, "room_stage1_v2", "1단계 방 (420×330, 1px=1pt) — 잘린 콘크리트 벽 · 비 오는 도시 창(시안 렉스코드 간판) · 게시판 · 화이트보드 · 문 · "
     "케이블 트레이 · 구석 CRT 더미 · 전선 · 책 더미 · 양동이와 물방울 · 담쟁이")
manifest["room_stage1_v2"]["grid_origin_top_vertex"] = list(grid_origin)
manifest["room_stage1_v2"]["tile"] = [64, 32]


# ── 2. 시설 (한 칸, 그림 바닥 = 칸 마름모 아래 꼭짓점) ─────────────────────────
def fac_iso(h):
    w = 68
    return Iso(w, h, w // 2, h - 2 - U)          # P(32, 32, 0) = (34, h - 2) = 아래 꼭짓점


def contact_shadow(iso, img, x0, y0, x1, y1):
    sh = iso.layer()
    poly(sh, [iso.P(x0 - 1, y0 - 1, 0), iso.P(x1 + 2, y0 - 1, 0), iso.P(x1 + 2, y1 + 2, 0), iso.P(x0 - 1, y1 + 2, 0)], (10, 5, 8, 120))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1.2)))


def chair(iso, img, x0, y0, wood=True):
    """책상 앞 의자 (등받이가 보는 쪽): 쿠션 앉판 · 등받이 · 다리 넷."""
    P = iso.P
    lay = iso.layer()
    cush = hx("6E9A8A") if wood else CREAM[3]
    for (lx, ly) in ((x0, y0 + 6), (x0 + 8, y0 + 6), (x0, y0), (x0 + 8, y0)):
        box(iso, lay, lx, ly, 0, lx + 1.5, ly + 1.5, 11, WOOD[3], WOOD[2], WOOD[1])
    box(iso, lay, x0 - 0.5, y0 - 0.5, 11, x0 + 10, y0 + 8, 13, cush, hx("4E7A6C"), hx("3E6458"), hi=hx("8EBAA8"))
    box(iso, lay, x0, y0 + 7, 13, x0 + 9.5, y0 + 8.5, 26, WOOD[4], WOOD[3], WOOD[2], hi=WOOD[5])   # 등받이
    for z in (17, 21):
        line(lay, P(x0 + 1, y0 + 8.5, z), P(x0 + 8.5, y0 + 8.5, z), WOOD[2])
    img.alpha_composite(outline(lay))


def desk(f, trainee=False):
    iso = fac_iso(100)
    P = iso.P
    img = iso.layer()
    contact_shadow(iso, img, 2, 3, 30, 30)
    lay = iso.layer()
    top = WOOD[5] if not trainee else hx("C4A078")
    for (lx, ly) in ((3, 18), (27, 18), (3, 4), (27, 4)):
        box(iso, lay, lx, ly, 0, lx + 2, ly + 2, 20, WOOD[4], WOOD[3], WOOD[2], lo=WOOD[1])
    box(iso, lay, 3, 3, 12, 29, 5, 20, WOOD[4], WOOD[3], WOOD[2])                          # 뒷판
    box(iso, lay, 20, 4, 3, 29, 20, 20, WOOD[4], WOOD[3], WOOD[2], hi=WOOD[5], lo=WOOD[1])  # 서랍장
    for z in (7, 12, 17):
        line(lay, P(21, 20, z), P(28, 20, z), WOOD[2])
        put(lay, [P(24, 20, z - 2), P(25, 20, z - 2)], AMBERK[3])
    box(iso, lay, 2, 2, 20, 30, 21, 22, top, WOOD[4], WOOD[3], hi=WOOD[6])                  # 상판
    for k in range(4, 29, 5):                                                                # 나뭇결
        line(lay, P(k, 4 + (k % 3), 22), P(k + 3, 4 + (k % 3), 22), WOOD[4])
    img.alpha_composite(outline(lay))
    if not trainee:
        crt(iso, img, 5, 3, 22, 15, 12, 14, f, phase=1)
        lay = iso.layer()
        box(iso, lay, 22, 4, 22, 28, 10, 30, PAPER[3], REDK[2], hx("3E5A6A"))             # 책 더미
        box(iso, lay, 22, 4, 30, 27, 9, 33, PAPER[2], WOOD[3], WOOD[2])
        box(iso, lay, 6, 15, 22, 17, 20, 23, CREAM[4], CREAM[3], CREAM[2], hi=CREAM[5])    # 키보드
        for x in range(7, 17, 2):
            put(lay, [P(x, 17, 23), P(x, 19, 23)], CREAM[1])
        box(iso, lay, 21, 13, 22, 28, 20, 22.5, PAPER[3], PAPER[2], PAPER[1])            # 종이 · 쪽지
        box(iso, lay, 23, 11, 22, 26, 13.5, 26, CREAM[4], CREAM[3], CREAM[2])             # 머그
        img.alpha_composite(outline(lay))
        lay = iso.layer()                                                                   # 스탠드 (켜짐)
        line(lay, P(2, 8, 22), P(3, 8, 34), METAL[3], 1)
        line(lay, P(3, 8, 34), P(8, 10, 38), METAL[3], 1)
        poly(lay, [P(6, 10, 40), P(11, 10, 40), P(11, 10, 36), P(6, 10, 36)], hx("3E6A64"))
        img.alpha_composite(outline(lay))
        if f != 5:
            put(img, [P(8, 10, 35), P(9, 10, 35)], AMBERK[5])
    else:
        crt(iso, img, 5, 4, 22, 12, 11, 11, f, phase=4, small=True)
        lay = iso.layer()                                                                   # 열린 짐 상자
        box(iso, lay, 19, 9, 22, 29, 20, 30, hx("2E2018"), hx("B08C60"), hx("8C6C48"))
        poly(lay, [P(19, 20, 30), P(29, 20, 30), P(31, 23, 34), P(21, 23, 34)], hx("C8A070"))
        box(iso, lay, 22, 11, 28, 26, 15, 33, hx("6EA0A0"), hx("4E7A7A"), hx("3E6464"))      # 상자 속 청록 머그
        img.alpha_composite(outline(lay))
    chair(iso, img, 8, 21, wood=not trainee)
    return img


def archive(f):
    """한자 서고: 작은 서랍이 빽빽한 나무 카드 목록함 + 종이 묶음 + 위 호박 램프 + 담쟁이."""
    iso = fac_iso(124)
    P = iso.P
    img = iso.layer()
    contact_shadow(iso, img, 3, 4, 29, 26)
    lay = iso.layer()
    box(iso, lay, 3, 4, 0, 29, 26, 58, WOOD[4], WOOD[3], WOOD[2], hi=WOOD[5])
    for z in range(4, 56, 6):                                                             # 서랍 줄 (왼앞 면)
        line(lay, P(3, 26, z), P(29, 26, z), WOOD[1])
        for x in range(3, 29, 6):
            line(lay, P(x, 26, z), P(x, 26, z + 6), WOOD[1])
            put(lay, [P(x + 3, 26, z + 2)], AMBERK[3])                                    # 놋쇠 손잡이
            put(lay, [P(x + 2, 26, z + 4), P(x + 4, 26, z + 4)], PAPER[2])                # 이름표
    for z in range(4, 56, 6):                                                             # 오른 면 판
        line(lay, P(29, 4, z), P(29, 26, z), WOOD[1])
    lay2 = iso.layer()
    box(iso, lay2, 5, 6, 58, 15, 16, 64, PAPER[3], PAPER[1], PAPER[0])                    # 위 종이 묶음
    line(lay2, P(5, 11, 61), P(15, 11, 61), REDK[2])
    box(iso, lay2, 17, 10, 58, 25, 20, 61, PAPER[2], PAPER[1], PAPER[0])
    img.alpha_composite(outline(lay))
    img.alpha_composite(outline(lay2))
    lay = iso.layer()                                                                     # 녹색 은행원 램프
    box(iso, lay, 19, 7, 61, 25, 11, 62.5, AMBERK[3], AMBERK[2], AMBERK[1])
    line(lay, P(22, 9, 62), P(22, 9, 66), AMBERK[3])
    box(iso, lay, 18, 7.5, 66, 26, 10.5, 69, hx("4E9A5E"), hx("2E6A40"), hx("1E4A2C"), hi=hx("7AC48A"))
    img.alpha_composite(outline(lay))
    if f != 3:
        put(img, [P(20, 10.5, 65.5), P(21, 10.5, 65.5), P(22, 10.5, 65.5), P(23, 10.5, 65.5), P(24, 10.5, 65.5)], AMBERK[5])
    ivy_from(img, [P(4, 26, 58), P(12, 4, 58)], 21, f, length=(16, 40))
    return img


def copy_room(f):
    """필사실: 낮은 좌식 상 + 펼친 두루마리 + 벼루 · 붓꽂이 + 종이 더미 + 매달린 갓 등."""
    iso = fac_iso(110)
    P = iso.P
    img = iso.layer()
    contact_shadow(iso, img, 2, 4, 30, 28)
    lay = iso.layer()
    box(iso, lay, 1, 3, 0, 31, 29, 1, hx("6A7A5A"), hx("4E5A40"), hx("3E4A34"))            # 다다미 깔개
    for k in range(3, 29, 4):
        line(lay, P(1, k, 1), P(31, k, 1), hx("5A6A4A"))
    for (lx, ly) in ((5, 24), (26, 24), (5, 7), (26, 7)):
        box(iso, lay, lx, ly, 1, lx + 2, ly + 2, 10, WOOD[3], WOOD[2], WOOD[1])
    box(iso, lay, 4, 6, 10, 29, 27, 12, WOOD[5], WOOD[3], WOOD[2], hi=WOOD[6])
    img.alpha_composite(outline(lay))
    lay = iso.layer()
    poly(lay, [P(7, 12, 12), P(22, 12, 12), P(22, 24, 12), P(7, 24, 12)], PAPER[3])        # 화선지
    for k, x in enumerate(range(9, 21, 4)):                                               # 붓글씨 획
        line(lay, P(x, 15, 12), P(x + 1, 21, 12), INK)
    line(lay, P(10, 18, 12), P(19, 18, 12), INK)
    box(iso, lay, 23, 9, 12, 28, 14, 14, CHAR[3], CHAR[2], CHAR[1])                        # 벼루
    put(lay, [P(25, 11, 14)], hx("101010"))
    box(iso, lay, 24, 18, 12, 27, 21, 18, WOOD[2], WOOD[1], WOOD[0])                       # 붓꽂이
    for k in range(3):
        line(lay, P(25 + k, 19, 18), P(24 + k * 2, 19, 25), WOOD[4])
    for k in range(4):                                                                       # 종이 더미 (낮게, 조금씩 어긋나게)
        box(iso, lay, 2 + (k % 2), 2 + (k * 3) % 2, 1 + k, 9 + (k % 2), 10 + (k * 3) % 2, 2 + k, PAPER[3], PAPER[2], PAPER[1])
    img.alpha_composite(outline(lay))
    lay = iso.layer()                                                                       # 바닥에 세운 종이 등 (행등)
    box(iso, lay, 26, 23, 1, 30, 27, 3, WOOD[3], WOOD[2], WOOD[1])
    box(iso, lay, 26.5, 23.5, 3, 29.5, 26.5, 16, PAPER[3], PAPER[2], PAPER[1])
    box(iso, lay, 26, 23, 16, 30, 27, 17, WOOD[3], WOOD[2], WOOD[1])
    for z in (7, 11):
        line(lay, P(26.5, 26.5, z), P(29.5, 26.5, z), WOOD[2])
    img.alpha_composite(outline(lay))
    glow = AMBERK[5] if f % 4 != 3 else AMBERK[4]
    poly(img, face_left(iso, 26.5, 27, 29, 4, 15), (glow[0], glow[1], glow[2], 120))
    return img


def booth(f):
    """녹음 부스: 흡음재 상자 + 창 너머 마이크 + 위 오픈릴 녹음기(릴이 돎) + VU 계기 + 「録音」 빨간 등."""
    iso = fac_iso(124)
    P = iso.P
    img = iso.layer()
    contact_shadow(iso, img, 3, 4, 29, 27)
    lay = iso.layer()
    box(iso, lay, 3, 4, 0, 29, 27, 52, FOAM[3], FOAM[2], FOAM[1], hi=hx("6A8486"))
    for z in range(3, 50, 4):                                                               # 흡음재 요철
        for x in range(4, 28, 4):
            put(lay, [P(x + (z // 4) % 2 * 2, 27, z)], FOAM[1])
        for y in range(5, 26, 4):
            put(lay, [P(29, y + (z // 4) % 2 * 2, z)], FOAM[0])
    poly(lay, face_left(iso, 27, 8, 22, 18, 40), hx("1A2A2C"))                              # 창
    poly(lay, face_left(iso, 27, 9, 21, 19, 39), hx("24383A"))
    line(lay, P(15, 27, 22), P(15, 27, 32), METAL[3])                                       # 마이크
    poly(lay, [P(13, 27, 36), P(17, 27, 36), P(17, 27, 32), P(13, 27, 32)], METAL[4])
    put(lay, [P(10, 27, 37), P(11, 27, 36)], hx("4A6466"))                                  # 유리 반사
    box(iso, lay, 5, 6, 52, 27, 22, 58, CREAM[4], CREAM[3], CREAM[2], hi=CREAM[5])          # 오픈릴 녹음기
    img.alpha_composite(outline(lay))
    lay = iso.layer()
    for k, (cx, cy) in enumerate(((10, 14), (21, 14))):                                    # 릴 (위에서 본 원, 바퀴살이 돎)
        for a in range(0, 360, 12):
            r = 4
            put(lay, [P(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)), 59)], CHAR[2])
        for s in range(3):
            a = math.radians(s * 120 + f * 22 * (1 if k == 0 else -1))
            line(lay, P(cx, cy, 59), P(cx + 3 * math.cos(a), cy + 3 * math.sin(a), 59), CHAR[3])
    line(lay, P(10, 18, 59), P(21, 18, 59), hx("3A2A20"))                                   # 테이프
    img.alpha_composite(lay)
    lay = iso.layer()                                                                       # VU 계기 (앞면)
    poly(lay, face_left(iso, 22, 7, 15, 53, 57), CREAM[5])
    a = [0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7, 0.55][f]
    line(lay, P(11, 22, 53), P(8 + a * 6, 22, 56.5), REDK[2])
    img.alpha_composite(lay)
    lay = iso.layer()                                                                       # 「録音」 빨간 등
    box(iso, lay, 12, 12, 64, 20, 18, 67, CHAR[3], CHAR[2], CHAR[1])
    on = f % 4 < 2
    poly(lay, face_left(iso, 18, 13, 19, 64.5, 66.5), REDK[4] if on else REDK[1])
    img.alpha_composite(outline(lay))
    return img


def server(f):
    """서버 랙: 크림 랙에 테이프 드라이브(릴이 돎) · LED 줄 · 위로 올라가는 전선 다발."""
    iso = fac_iso(132)
    P = iso.P
    img = iso.layer()
    contact_shadow(iso, img, 6, 5, 27, 27)
    lay = iso.layer()
    box(iso, lay, 6, 5, 0, 27, 27, 64, CREAM[3], CREAM[2], CREAM[1], hi=CREAM[4])
    poly(lay, face_left(iso, 27, 8, 25, 3, 61), hx("2A2226"))                                # 열린 앞면
    units = [("tape", 46, 13), ("leds", 38, 6), ("tape", 22, 13), ("leds", 14, 6), ("disk", 4, 8)]
    for k, (kind, z0, hgt) in enumerate(units):
        poly(lay, face_left(iso, 27, 9, 24, z0, z0 + hgt - 1), CREAM[2] if kind != "leds" else CHAR[2])
        line(lay, P(9, 27, z0 + hgt - 1), P(24, 27, z0 + hgt - 1), CREAM[4] if kind != "leds" else CHAR[4])
        if kind == "tape":
            for cx in (13, 20):
                poly(lay, face_left(iso, 27, cx - 3, cx + 3, z0 + 3, z0 + 10), CHAR[1])
                a = f * 45 * (1 if cx == 13 else -1)
                for s in range(2):
                    aa = math.radians(a + s * 180)
                    put(lay, [P(cx + 2 * math.cos(aa), 27, z0 + 6.5 + 2 * math.sin(aa))], CREAM[4])
        if kind == "leds":
            rng = random.Random(k)
            for x in range(10, 24, 2):
                on = rng.random() < 0.5 if (f + x) % 3 else not (rng.random() < 0.5)
                put(lay, [P(x, 27, z0 + 3)], (PH[3] if x % 6 else AMBERK[4]) if on else LED_OFF)
        if kind == "disk":
            for x in range(10, 24, 4):
                line(lay, P(x, 27, z0 + 3), P(x + 2, 27, z0 + 3), CHAR[1])
    for z in range(4, 60, 3):                                                               # 오른 면 통풍
        line(lay, P(27, 9, z), P(27, 24, z), CREAM[0])
    img.alpha_composite(outline(lay))
    lay = iso.layer()                                                                       # 위로 올라가는 전선 다발
    for k, (col, hi) in enumerate(((CHAR[2], CHAR[4]), (CREAM[2], CREAM[4]), (REDK[2], REDK[4]), (hx("2E4A34"), hx("4E7A54")))):
        x = 10 + k * 3
        pts = [P(x, 10, 64)] + [P(x + math.sin(z * 0.2 + k) * 1.5, 10, 64 + z) for z in range(2, 34, 4)]
        cable(lay, pts, col, hi, 1)
    img.alpha_composite(lay)
    return img


FAC = {
    "fac_researcher_desk": (lambda f: desk(f), "주임 연구원 책상 — 크림 CRT(코드) · 책 더미 · 키보드 · 쪽지 · 머그 · 켜진 스탠드 · 서랍장"),
    "fac_trainee_desk": (lambda f: desk(f, trainee=True), "신입 책상 — 작은 터미널 · 열린 짐 상자(청록 머그)"),
    "fac_kanji_archive": (archive, "한자 서고 — 서랍 빽빽한 나무 카드 목록함 · 놋쇠 손잡이 · 종이 묶음 · 호박 램프 · 담쟁이"),
    "fac_copy_room": (copy_room, "필사실 — 다다미 깔개 위 좌식 상 · 화선지 붓글씨 · 벼루 · 붓꽂이 · 매달린 갓 등"),
    "fac_recording_booth": (booth, "녹음 부스 — 흡음재 상자 · 창 너머 마이크 · 오픈릴 녹음기(릴이 돎) · VU 바늘 · 「録音」 빨간 등"),
    "fac_server_rack": (server, "서버 랙 — 크림 랙 · 테이프 드라이브(릴이 돎) · LED 줄 · 위로 올라가는 전선 다발"),
}
FAC_FRAMES = {}
for name, (fn, note) in FAC.items():
    FAC_FRAMES[name] = save([fn(f) for f in range(F)], name, note, anchor=[34, None])
    manifest[name]["anchor_bottom_vertex"] = [34, FAC_FRAMES[name][0].height - 2]


# ── 3. 노멀맵 + 조명 (retro_ui와 같은 방식) ─────────────────────────────
def auto_normal(img, strength=2.2):
    a = np.array(img.getchannel("A"), dtype=np.float32) / 255
    rgb = np.array(img.convert("RGB"), dtype=np.float32)
    luma = (rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11) / 255
    dist = (a > 0.5).astype(np.float32)
    acc = dist.copy()
    for _ in range(3):
        dist = np.minimum.reduce([np.roll(dist, 1, 0), np.roll(dist, -1, 0), np.roll(dist, 1, 1), np.roll(dist, -1, 1), dist])
        acc += dist
    height = 0.55 * (acc / 4) + 0.45 * luma
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(height)
    n = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    out = np.stack([(nx / n * 0.5 + 0.5) * 255, (ny / n * 0.5 + 0.5) * 255, (nz / n * 0.5 + 0.5) * 255, a * 255], -1)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


for name in list(FAC_FRAMES) + ["room_stage1_v2"]:
    src = Image.open(OUT / f"{name}.png").convert("RGBA")
    w = manifest[name]["frame"][0]
    auto_normal(src.crop((0, 0, w, src.height))).save(OUT / f"{name}_n.png")
    manifest[name]["normal"] = f"{name}_n.png"
(OUT / "iso_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


def light_pass(color, normals, lights, ambient):
    c = np.array(color, dtype=np.float32)
    nm = np.array(normals, dtype=np.float32)
    N = nm[..., :3] / 255 * 2 - 1
    N[nm[..., 3] < 10] = (0, 0, 1)
    H, W = c.shape[:2]
    ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
    acc = np.full((H, W, 3), ambient, dtype=np.float32)
    for lx, ly, lz, col, power, radius in lights:
        v = np.stack([lx - xs, ly - ys, np.full_like(xs, lz)], -1)
        dist = np.linalg.norm(v, axis=-1)
        v /= dist[..., None]
        ndl = np.clip((N * v).sum(-1), 0.15, 1)
        att = power / (1 + (dist / radius) ** 2)
        acc += (ndl * att)[..., None] * (np.array(col, np.float32) / 255)
    rgb = c[..., :3]
    emissive = ((rgb[..., 1] > rgb[..., 0] + 25) & (rgb[..., 1] > 120)) | ((rgb[..., 2] > 200) & (rgb[..., 1] > 200) & (rgb[..., 0] < 120)) \
        | ((rgb[..., 0] > 230) & (rgb[..., 1] > 180))                                         # 형광 · 시안 간판 · 호박 램프
    lit = rgb * acc
    lit[emissive] = np.maximum(rgb[emissive], lit[emissive])
    return Image.fromarray(np.concatenate([lit.clip(0, 255), c[..., 3:4]], -1).astype(np.uint8), "RGBA")


# ── 4. 배치 시안: 1단계 방 + 시설 + 두 사람 ─────────────────────────────
def char_frames(name):
    out = []
    for suf in ("idle_se", "walk_se_a", "walk_se_b", "idle_nw"):
        p = CHARS / f"{name}_{suf}.png"
        out.append(Image.open(p).convert("RGBA") if p.exists() else None)
    return out


CHIEF, NEWBIE = char_frames("chief_researcher"), char_frames("newcomer")
PLACED = [("fac_kanji_archive", 0, 1), ("fac_researcher_desk", 1, 1), ("fac_server_rack", 4, 0), ("fac_recording_booth", 5, 1),
          ("fac_copy_room", 0, 4), ("fac_trainee_desk", 3, 3)]


def tile_bottom(c, r):
    return ROOM.P(MARGIN + U * (c + 1), MARGIN + U * (r + 1), 0)


def tile_center(c, r):
    return ROOM.P(MARGIN + U * (c + 0.5), MARGIN + U * (r + 0.5), 0)


def scene(i):
    f = i % F
    col = Image.new("RGBA", (ROOM.w, ROOM.h))
    nrm = Image.new("RGBA", (ROOM.w, ROOM.h))
    room = ROOM_FRAMES[f]
    col.alpha_composite(room)
    nrm.alpha_composite(Image.open(OUT / "room_stage1_v2_n.png"))
    # 창으로 드는 차가운 빛 (바닥 빛 웅덩이 + 비 그림자 줄)
    pool = Image.new("RGBA", col.size)
    P = ROOM.P
    poly(pool, [P(4, 44, 0), P(70, 64, 0), P(70, 144, 0), P(4, 124, 0)], (120, 170, 200, 46))
    for k in range(6):
        y = 50 + (k * 15 + i * 3) % 80
        line(pool, P(8, y, 0), P(66, y + 18, 0), (40, 50, 70, 40))
    col.alpha_composite(pool.filter(ImageFilter.GaussianBlur(1.5)))
    items = [(c + r, "fac", n, c, r) for n, c, r in PLACED]
    walk = (i // 2) % 12
    items.append((1 + 2.6 - 0.01, "char", "chief", 1.6, 2.6))
    items.append((2 + 3.5 + walk * 0.05 - 0.01, "char", "new", 2 + walk * 0.05, 3.6))
    for _, kind, n, c, r in sorted(items):
        if kind == "fac":
            spr = FAC_FRAMES[n][f]
            bx, by = tile_bottom(c, r)
            pos = (bx - 34, by - spr.height + 2)
            col.alpha_composite(spr, pos)
            nrm.alpha_composite(auto_normal(spr), pos)
        else:
            frames = CHIEF if n == "chief" else NEWBIE
            spr = frames[0] if n == "chief" else frames[1 + (i // 2) % 2]
            if spr is None:
                continue
            cx, cy = tile_center(c, r)
            sh = Image.new("RGBA", col.size)
            ImageDraw.Draw(sh).ellipse([cx - 10, cy - 3, cx + 10, cy + 3], fill=(10, 5, 8, 110))
            col.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1)))
            col.alpha_composite(spr, (int(cx - 24), int(cy - 46)))
    lights = [(P(0, 84, 60)[0] + 30, P(0, 84, 60)[1], 50, (140, 190, 255), 0.6, 160),          # 창 (차가운 빛)
              (tile_bottom(1, 1)[0] - 20, tile_bottom(1, 1)[1] - 50, 30, (255, 200, 120), 0.9, 70),   # 주임 스탠드
              (tile_bottom(0, 1)[0] - 10, tile_bottom(0, 1)[1] - 120, 30, (255, 190, 110), 0.5, 60),  # 서고 램프
              (P(10, 8, 20)[0], P(10, 8, 20)[1], 30, (120, 255, 150), 0.35, 60)]                     # 구석 CRT
    out = light_pass(col, nrm, lights, 0.7)
    arr = np.array(out).astype(np.float32)                                                   # 발광 번짐 (HDR 느낌)
    rgb = arr[..., :3]
    mask = (((rgb[..., 1] > rgb[..., 0] + 25) & (rgb[..., 1] > 120)) | ((rgb[..., 2] > 200) & (rgb[..., 1] > 200) & (rgb[..., 0] < 120))
            | ((rgb[..., 0] > 230) & (rgb[..., 1] > 170)))
    glow = np.zeros_like(arr)
    glow[mask] = arr[mask]
    glow[..., 3] = mask * 255
    gimg = Image.fromarray(glow.astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.5))
    gimg.putalpha(gimg.getchannel("A").point(lambda v: int(v * 0.55)))
    out.alpha_composite(gimg)
    beam = Image.new("RGBA", out.size)                                                       # 창빛 기둥 + 먼지
    poly(beam, [P(0, 44, 84), P(0, 124, 84), P(70, 144, 0), P(70, 64, 0)], (150, 200, 230, 16))
    out.alpha_composite(beam.filter(ImageFilter.GaussianBlur(3)))
    rr = random.Random(2)
    for k in range(18):
        x0, y0 = P(rr.uniform(2, 60), rr.uniform(50, 130), rr.uniform(4, 70))
        out.putpixel((int(x0 + math.sin(i * 0.4 + k) * 2) % ROOM.w, int(y0 - (i * 0.6 + k) % 12) % ROOM.h), (220, 240, 255, 150))
    bg = Image.new("RGBA", out.size, hx("0E090C"))
    bg.alpha_composite(out)
    return bg


frames = [scene(i) for i in range(16)]
big = [fr.resize((fr.width * 2, fr.height * 2), Image.NEAREST) for fr in frames]
big[0].save(PREV / "preview_iso_stage1_v2.gif", save_all=True, append_images=big[1:], duration=140, loop=0, disposal=2)
frames[3].save(PREV / "preview_iso_stage1_v2.png")
sheet = Image.new("RGBA", (6 * 76 + 8, 150), hx("1E1418"))
for k, n in enumerate(FAC_FRAMES):
    spr = FAC_FRAMES[n][2]
    sheet.alpha_composite(spr, (6 + k * 76, 146 - spr.height))
sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(PREV / "preview_iso_facilities_v2_x3.png")
print("ok", len(manifest))
