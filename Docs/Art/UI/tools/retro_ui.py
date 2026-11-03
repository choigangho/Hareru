"""레트로 단말 UI 키트 v2 — 둥근 CRT 모니터 · 전선 · 물리 버튼 · 높은 대비. usage: retro_ui.py <out_dir> <preview_dir>

기준: Docs/Art/StyleRef/ART_BIBLE.md v2.1 (2026-11-03 오너 피드백: 둥글고 명암이 살아 있는 레트로 모니터,
조금씩 틀어진 채 쌓인 모니터 · 삐져나온 전선 · 가장자리 전선 뭉치, 입체적인 버튼, HDR처럼 강한 대비).
해상도: UI는 **1px = 1pt** (기기에서 3×3 픽셀). 둥근 모서리 · 명암을 표현하려고 2pt에서 바꿈.
모양은 둥근 사각형 거리장(SDF)으로 계산하고, 빛은 왼쪽 위 고정 → 면의 방향(법선)으로 명암 단계를 고름.
9-slice 부품은 장식을 모두 cap 안에 두고, 가장자리 띠는 일정하게, 가운데는 주기 2·3·4·12 무늬만 씀.
cap은 [위, 왼, 아래, 오른] — <out_dir>/retro_manifest.json.
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT, PREV = Path(sys.argv[1]), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
F = 8


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ── 팔레트: Phosphor 28 + 대비 확장 (깊은 어둠 · 반사광 · 번짐) ───────────────
INK_DEEP, INK = hx("0E090C"), hx("231620")
CREAM = [hx("5E5444"), hx("8C7C5E"), hx("B3A07C"), hx("D4BE8C"), hx("EBDFAE"), hx("FFF7DC")]
PUTTY = [hx("2E2C22"), hx("4E4C38"), hx("6E6C4C"), hx("8E8B62"), hx("B0AC80"), hx("D8D4A8")]
CHAR = [hx("141012"), hx("241E20"), hx("38302F"), hx("524844"), hx("74685E"), hx("A89C8A")]
AMBERK = [hx("5A2A14"), hx("94481E"), hx("D0702A"), hx("F09A3C"), hx("FFC468"), hx("FFE8B0")]
REDK = [hx("3C0E10"), hx("701C1E"), hx("A82E2C"), hx("D24A42"), hx("F27A68"), hx("FFC0A8")]
RECESS = [INK_DEEP, hx("2A1A1C"), hx("46302C"), hx("6A5446")]
GLASS_EDGE, GLASS_0, GLASS_1, GLASS_A, GLASS_B = hx("08140C"), hx("0E2616"), hx("153A22"), hx("1C4A2C"), hx("18422A")
PH = [hx("1F5A33"), hx("2F8A4A"), hx("4CC067"), hx("8AF08A"), hx("D4FFC8")]
AM, AM_D, LED_OFF, RED = hx("FFD060"), hx("E08A2A"), hx("3A2C2A"), hx("FF5A4A")
IVY = [hx("0F1A10"), hx("22361E"), hx("36522C"), hx("4E7438"), hx("6E9A46"), hx("A6CC6A")]
CLEAR = (0, 0, 0, 0)
L = (-0.7071, -0.7071)                                  # 빛: 왼쪽 위
manifest = {}


def save(frames, name, cap=None, note=""):
    frames = frames if isinstance(frames, list) else [frames]
    w, h = frames[0].size
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * w, 0))
    strip.save(OUT / f"{name}.png")
    manifest[name] = {"frame": [w, h], "frames": len(frames), "frame_ms": 150,
                      **({"cap": cap} if cap is not None else {}), "use": note}
    return frames


def frames_of(name):
    s = Image.open(OUT / f"{name}.png").convert("RGBA")
    w, h = manifest[name]["frame"]
    return [s.crop((i * w, 0, (i + 1) * w, h)) for i in range(s.width // w)]


def sdf(x, y, x0, y0, x1, y1, r):
    """둥근 사각형 거리 (안쪽 음수). 픽셀 중심 기준."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hw, hh = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    qx, qy = abs(x + 0.5 - cx) - hw, abs(y + 0.5 - cy) - hh
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def normal(x, y, rect):
    e = 0.5
    dx = sdf(x + e, y, *rect) - sdf(x - e, y, *rect)
    dy = sdf(x, y + e, *rect) - sdf(x, y - e, *rect)
    n = math.hypot(dx, dy) or 1
    return dx / n, dy / n


def ramp_pick(ramp, t):
    """t: -1(그늘) ~ 1(빛)."""
    i = round((t + 1) / 2 * (len(ramp) - 1))
    return ramp[max(0, min(len(ramp) - 1, i))]


def put(img, pts, c):
    px = img.load()
    w, h = img.size
    for x, y in pts:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def disc(img, cx, cy, r, ramp, rim=INK, invert=False):
    """빛 받는 둥근 단추 · 손잡이."""
    px = img.load()
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r + 0.5:
                if d > r - 0.6:
                    px[x, y] = rim
                else:
                    nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
                    t = -(nx * L[0] + ny * L[1]) * (1.4 if not invert else -1.4) + 0.1
                    px[x, y] = ramp_pick(ramp, max(-1, min(1, -t if False else t)))


# ── 1. 모니터 몸체 (9-slice) ─────────────────────────────────────
def monitor(ramp, caps, screen_inset, radius, side=None, chin=None, column=None, seed=1):
    """caps=(위,왼,아래,오른) · screen_inset=(위,왼,아래,오른) · side: 'right'/'left' 옆면이 보이게 틀어짐."""
    T, Lc, B, R = caps
    sw = 7 if side else 0
    w, h = Lc + 12 + R + sw, T + 12 + B
    img = Image.new("RGBA", (w, h))
    px = img.load()
    fx0 = sw if side == "left" else 0
    fx1 = w - (sw if side == "right" else 0)
    outer = (fx0, 0, fx1, h, radius)
    st, sl, sb, sr = screen_inset
    scr = (fx0 + sl, st, fx1 - sr, h - sb, max(3, radius - 4))
    rng = random.Random(seed)
    for y in range(h):
        for x in range(fx0, fx1):
            d = sdf(x, y, *outer)
            if d > 0:
                continue
            if d > -1.2:
                px[x, y] = INK
                continue
            d2 = sdf(x, y, *scr)
            if d2 <= -1:                                              # 유리
                depth = -d2
                if depth < 2:
                    c = GLASS_EDGE
                elif depth < 3.5:
                    c = GLASS_0
                elif depth < 5:
                    c = GLASS_1
                else:
                    c = GLASS_A if y % 2 == 0 else GLASS_B            # 주사선
                px[x, y] = c
            elif d2 <= 0:
                px[x, y] = INK_DEEP
            elif d2 < 3.5:                                            # 화면 둘레 파인 홈 (안쪽 벽 = 빛 반대)
                nx, ny = normal(x, y, scr)
                t = -(nx * -L[0] + ny * -L[1])
                c = ramp_pick(RECESS, t)
                if ny > 0.6 and d2 < 2:
                    c = hx("3C4A30")                                  # 아래 홈에 화면 녹색이 번짐
                px[x, y] = c
            elif d > -4.2:                                            # 바깥 둥근 모서리 (볼록)
                nx, ny = normal(x, y, outer)
                t = -(nx * L[0] + ny * L[1]) * 1.25
                if d > -2.2:
                    t += 0.25
                px[x, y] = ramp_pick(ramp[0:], max(-1, min(1, t)))
            else:                                                     # 앞면
                c = ramp[3]
                if d2 < 6.5:                                          # 홈 둘레 입술 (빛 받는 쪽만 밝게)
                    nx, ny = normal(x, y, scr)
                    lip = -(nx * L[0] + ny * L[1])
                    c = ramp[4] if lip > 0.5 else (ramp[2] if lip < -0.5 else ramp[3])
                n = (x * 7 + y * 13) % 12                              # 주기 12 결 (9-slice 가운데와 맞음)
                if n == 0 and (y * 5) % 12 == 3:
                    c = ramp[2]
                px[x, y] = c
    # 옆면 (틀어진 모니터)
    if side:
        d = ImageDraw.Draw(img)
        if side == "right":
            poly = [(fx1 - 2, radius), (w - 1, radius + 4), (w - 1, h - radius - 1), (fx1 - 2, h - 3)]
        else:
            poly = [(sw + 1, radius), (0, radius + 4), (0, h - radius - 1), (sw + 1, h - 3)]
        d.polygon(poly, fill=ramp[1], outline=INK)
        xs = range(fx1, w - 1) if side == "right" else range(1, sw)
        for y in range(radius + 6, h - radius - 3):
            if y % 3 == 0:                                            # 옆 통풍 슬릿 (주기 3)
                put(img, [(x, y) for x in xs], ramp[0])
        hl = fx1 - 1 if side == "right" else sw
        for y in range(radius, h - 3):
            put(img, [(hl, y)], ramp[2] if side == "right" else ramp[4])
    if chin:
        chin(img, fx0, fx1, w, h)
    if column:
        column(img, fx0, fx1, w, h)
    return img


def chin_crt(img, fx0, fx1, w, h):
    """크림 CRT 턱: 왼쪽 명판 · 가운데 통풍 슬릿(주기 3) · 오른쪽 손잡이 둘 + 전원 LED."""
    d = ImageDraw.Draw(img)
    y = h - 18
    rect(d, fx0 + 6, y, fx0 + 17, y + 5, INK)                          # 명판 (상표 없음)
    rect(d, fx0 + 7, y + 1, fx0 + 16, y + 4, CHAR[2])
    put(img, [(fx0 + 9, y + 2), (fx0 + 11, y + 2), (fx0 + 13, y + 2)], CREAM[3])
    put(img, [(fx0 + 7, y + 1)], CHAR[4])
    for x in range(fx0 + 22, fx1 - 22):
        if x % 3 == 0:
            put(img, [(x, yy) for yy in range(y + 1, y + 5)], CREAM[1])
    disc(img, fx1 - 16, y + 3, 3.2, CHAR)                                # 손잡이
    disc(img, fx1 - 8, y + 3, 3.2, CHAR)
    put(img, [(fx1 - 16, y + 1), (fx1 - 8, y + 2)], CHAR[5])           # 손잡이 눈금
    rect(d, fx0 + 2, h - 9, fx1 - 3, h - 9, CREAM[2])                  # 이음선
    rect(d, fx0 + 2, h - 8, fx1 - 3, h - 8, CREAM[4])


def chin_term(img, fx0, fx1, w, h):
    """작은 터미널 턱: 플로피 슬롯 (오른쪽 cap) · 왼쪽 무지개 대신 녹색 띠 명판."""
    d = ImageDraw.Draw(img)
    y = h - 22
    rect(d, fx1 - 21, y, fx1 - 5, y + 4, INK)                          # 플로피 슬롯
    rect(d, fx1 - 20, y + 1, fx1 - 6, y + 2, INK_DEEP)
    rect(d, fx1 - 20, y + 3, fx1 - 6, y + 3, CREAM[2])
    rect(d, fx1 - 9, y + 6, fx1 - 6, y + 7, CREAM[1])                  # 꺼내기 단추
    rect(d, fx0 + 5, y + 1, fx0 + 10, y + 3, PH[1])                    # 녹색 띠 명판
    put(img, [(fx0 + 5, y + 1)], PH[2])
    for x in range(fx0 + 14, fx1 - 24):
        if x % 4 == 0:
            put(img, [(x, h - 10)], CREAM[1])


def column_industrial(img, fx0, fx1, w, h):
    """산업용 모니터 오른쪽 조작 기둥: 위 cap = LED · 아래 cap = 사각 단추 셋, 가운데 = 골 진 판(주기 3)."""
    d = ImageDraw.Draw(img)
    x0 = fx1 - 25
    rect(d, x0, 6, x0, h - 7, INK)
    for y in range(8, h - 8):
        if 22 <= y < h - 18 and y % 3 == 0:
            put(img, [(x, y) for x in range(x0 + 4, fx1 - 5)], PUTTY[1])
    for k in range(3):                                                  # LED 자리 (색은 애니에서)
        rect(d, x0 + 5 + k * 6, 9, x0 + 8 + k * 6, 12, INK)
    for k in range(3):                                                  # 사각 단추
        bx, by = x0 + 5 + k * 6, h - 15
        rect(d, bx, by, bx + 4, by + 5, INK)
        rect(d, bx + 1, by + 1, bx + 3, by + 3, PUTTY[4] if k != 1 else AMBERK[3])
        rect(d, bx + 1, by + 4, bx + 3, by + 4, PUTTY[1])


def animate_leds(base, spots, f):
    """spots: [(x, y, w, h, color, pattern)] — 8프레임 깜빡임."""
    img = base.copy()
    d = ImageDraw.Draw(img)
    for x, y, w, h, c, pat in spots:
        on = pat[f]
        rect(d, x, y, x + w - 1, y + h - 1, c if on else LED_OFF)
        if on:
            put(img, [(x, y)], hx("FFFFFF") if c in (PH[3],) else c)
    return img


BL = {"steady": [1, 1, 1, 1, 1, 1, 0, 1], "disk": [1, 0, 0, 1, 1, 0, 1, 0], "slow": [1, 1, 1, 1, 0, 0, 0, 0],
      "busy": [1, 0, 1, 1, 0, 1, 0, 0], "rare": [0, 0, 0, 0, 0, 1, 0, 0]}

def add_top(img, ramp, td):
    """윗면 덮개 — 살짝 위에서 내려다보는 3/4 시점. 앞면 윗선을 td px 위로 밀어 올린 띠 (빛을 가장 많이 받음)."""
    w, h = img.size
    src = img.load()
    lid = Image.new("RGBA", (w, h + td))
    lp = lid.load()
    for x in range(w):
        ys = [y for y in range(h) if src[x, y][3]]
        if not ys:
            continue
        yf = ys[0] + td
        for k in range(1, td + 1):
            c = ramp[5] if k >= td - 1 else ramp[4]
            if k == 1:
                c = ramp[2]                                              # 앞 모서리 아래 접힌 그늘
            lp[x, yf - k] = c
        if 2 <= x % 6 <= 3 and td >= 5:
            lp[x, yf - 3] = ramp[2]                                      # 윗면 통풍 구멍 (주기 6)
    lid = outline_px(lid)
    lid.alpha_composite(img, (0, td))
    return lid


def outline_px(img, c=None):
    c = c or INK
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if not src[x, y][3] and any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] > 100
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


TOP_D = {"crt": 6, "industrial": 5, "term": 5}

# A: 크림 CRT (넓은 판)
SHELLS = {}
for side in (None, "right"):
    caps = (16, 20, 30, 20 + (7 if side == "right" else 0))
    base = monitor(CREAM, (16, 20, 30, 20), (10, 10, 24, 10), 10, side=side, chin=chin_crt, seed=3)
    w, h = base.size
    fx1 = w - (7 if side else 0)
    spots = [(fx1 - 27, h - 17, 2, 2, PH[3], BL["steady"]), (fx1 - 27, h - 13, 2, 2, AM, BL["disk"])]
    name = "rt_monitor_crt" + ("_turned" if side else "")
    caps = (caps[0] + TOP_D["crt"],) + tuple(caps[1:])
    SHELLS[name] = save([add_top(animate_leds(base, spots, f), CREAM, TOP_D["crt"]) for f in range(F)], name, list(caps),
                        "크림 CRT 모니터 — 둥근 몸체 · 파인 화면 홈 · 볼록 유리 · 명판 · 손잡이 둘 · 전원/디스크 LED" + (" · 오른쪽으로 틀어져 옆면(통풍 슬릿)이 보임" if side else ""))

# B: 산업용 퍼티색 모니터 (오른쪽 조작 기둥)
for side in (None, "left"):
    base = monitor(PUTTY, (22, 16, 18, 34), (9, 9, 10, 28), 7, side=side, column=column_industrial, seed=5)
    w, h = base.size
    fx1 = w
    spots = [(fx1 - 19 + k * 6, 10, 2, 2, c, BL[p]) for k, (c, p) in enumerate(((RED, "rare"), (AM, "busy"), (PH[3], "steady")))]
    caps = [22 + TOP_D["industrial"], 16 + (7 if side else 0), 18, 34]
    name = "rt_monitor_industrial" + ("_turned" if side else "")
    SHELLS[name] = save([add_top(animate_leds(base, spots, f), PUTTY, TOP_D["industrial"]) for f in range(F)], name, caps,
                        "산업용 퍼티색 모니터 — 오른쪽 조작 기둥(LED 셋 · 사각 단추 셋 · 골 판)" + (" · 왼쪽으로 틀어짐" if side else ""))

# C: 작은 크림 터미널 (플로피 턱)
for side in (None, "right", "left"):
    base = monitor(CREAM, (14, 14, 34, 24), (8, 8, 28, 8), 8, side=side, chin=chin_term, seed=7)
    w, h = base.size
    fx0 = 7 if side == "left" else 0
    spots = [(fx0 + 6, h - 14, 2, 2, PH[3], BL["slow"])]
    caps = [14 + TOP_D["term"], 14 + (7 if side == "left" else 0), 34, 24 + (7 if side == "right" else 0)]
    name = "rt_monitor_term" + (f"_turned_{side}" if side else "")
    SHELLS[name] = save([add_top(animate_leds(base, spots, f), CREAM, TOP_D["term"]) for f in range(F)], name, caps,
                        "작은 크림 터미널 — 플로피 슬롯 턱 · 녹색 띠 명판 · LED" + (f" · {side}쪽 옆면" if side else ""))


def glare():
    """볼록 유리 반사 — 화면 왼쪽 위 모서리에 코드로 얹음 (9-slice 밖)."""
    img = Image.new("RGBA", (26, 18))
    for k in range(14):
        a = 90 - k * 5
        img.putpixel((3 + k, 2 + (k * k) // 60), (190, 255, 200, a))
        if k < 9:
            img.putpixel((2 + (k * k) // 60, 3 + k), (190, 255, 200, a))
    for p, a in (((4, 4), 160), ((5, 4), 110), ((4, 5), 110)):
        img.putpixel(p, (230, 255, 230, a))
    return img


save(glare(), "rt_glass_glare", None, "볼록 유리 반사 26×18 — 화면 왼쪽 위에 얹음 (반투명)")


# ── 2. 전선 ───────────────────────────────────────────────────────
CABLES = [  # (굵기, 몸, 빛, 그늘)
    (3, CREAM[3], CREAM[5], CREAM[1]), (3, CHAR[2], CHAR[4], CHAR[0]), (2, hx("7E7A70"), hx("B8B2A2"), hx("4E4A44")),
    (4, CREAM[2], CREAM[4], CREAM[0]), (2, REDK[2], REDK[4], REDK[0]), (3, hx("2E4A34"), hx("4E7A54"), hx("16281C")),
]


def cable_path(img, pts, spec):
    """굵기 있는 전선: 한 점씩 원기둥처럼 빛 · 몸 · 그늘."""
    wdt, body, lit, dark = spec
    px = img.load()
    W_, H_ = img.size
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for s in range(int(n * 2) + 1):
            t = s / (n * 2)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            tx, ty = (x1 - x0) / n, (y1 - y0) / n
            nl = math.hypot(tx, ty) or 1
            nx, ny = -ty / nl, tx / nl                                 # 전선 단면 방향
            for k in range(-(wdt // 2) - 1, wdt - wdt // 2 + 1):
                xx, yy = int(round(x + nx * k)), int(round(y + ny * k))
                if not (0 <= xx < W_ and 0 <= yy < H_):
                    continue
                edge = k in (-(wdt // 2) - 1, wdt - wdt // 2)
                if edge:
                    if px[xx, yy][3] == 0:
                        px[xx, yy] = INK
                    continue
                side = (k + 0.5) / max(1, wdt) * (nx * L[0] + ny * L[1])
                px[xx, yy] = lit if k == -(wdt // 2) and (nx * L[0] + ny * L[1]) > -0.2 else (dark if k == wdt - wdt // 2 - 1 and wdt > 2 else body)


def bundle_tile(width=32, height=64):
    img = Image.new("RGBA", (width, height))
    xs = [4, 9, 14, 19, 24, 28]
    for i, (x, spec) in enumerate(zip(xs, CABLES)):
        pts = [(x + round(1.4 * math.sin(2 * math.pi * (y / height) + i * 1.3)), y) for y in range(-2, height + 3, 2)]
        cable_path(img, pts, spec)
    d = ImageDraw.Draw(img)
    rect(d, 1, 40, width - 2, 43, CHAR[1])                             # 케이블 타이
    rect(d, 1, 40, width - 2, 40, CHAR[3])
    rect(d, width - 4, 39, width - 2, 44, CHAR[2])
    put(img, [(x, 39) for x in range(1, width - 1)] + [(x, 44) for x in range(1, width - 1)], INK)
    return img


save(bundle_tile(), "rt_cable_bundle_v", [0, 0, 0, 0], "세로 전선 뭉치 (높이 64 반복 타일) — 화면 가장자리를 따라 내려감, 케이블 타이 하나")


def droop(w, h, x0, y0, x1, y1, sag, spec, plug=None):
    img = Image.new("RGBA", (w, h))
    pts = []
    for s in range(41):
        t = s / 40
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t + sag * 4 * t * (1 - t)
        pts.append((x, y))
    cable_path(img, pts, spec)
    if plug:
        px_, py_ = plug
        d = ImageDraw.Draw(img)
        rect(d, px_ - 3, py_, px_ + 3, py_ + 7, INK)
        rect(d, px_ - 2, py_ + 1, px_ + 2, py_ + 6, CHAR[3])
        rect(d, px_ - 2, py_ + 1, px_ - 2, py_ + 6, CHAR[4])
        rect(d, px_ - 1, py_ + 8, px_ + 1, py_ + 9, hx("C8B060"))     # 핀
    return img


save(droop(64, 30, 2, 4, 62, 6, 18, CABLES[1]), "rt_cable_loop_a", None, "모니터 사이로 처진 검은 전선 (64×30)")
save(droop(44, 46, 4, 2, 30, 30, 10, CABLES[0], plug=(30, 30)), "rt_cable_dangle_b", None, "삐져나와 늘어진 크림 전선 + 플러그 (44×46)")
save(droop(80, 26, 2, 3, 78, 10, 14, CABLES[4]), "rt_cable_loop_c", None, "빨간 신호선 처짐 (80×26)")


def coil():
    img = Image.new("RGBA", (72, 40))
    rng = random.Random(4)
    for k in range(9):
        spec = CABLES[k % len(CABLES)]
        cx, cy = 36 + rng.randint(-8, 8), 22 + rng.randint(-3, 3)
        rx, ry = rng.randint(18, 30), rng.randint(8, 13)
        pts = [(cx + rx * math.cos(a / 40 * 2 * math.pi), cy + ry * math.sin(a / 40 * 2 * math.pi)) for a in range(41)]
        cable_path(img, pts, spec)
    return img


save(coil(), "rt_cable_coil", None, "바닥 · 구석의 엉킨 전선 뭉치 (72×40)")


# ── 3. 물리 버튼 ─────────────────────────────────────────────────
def keycap(ramp, pressed=False, disabled=False, w=40, h=40):
    """윗면(오목) + 앞 두께 + 바닥 그림자. cap [10,10,14,10]."""
    if disabled:
        ramp = [hx("2A2424"), hx("3C3434"), hx("4E4644"), hx("625A54"), hx("766C64"), hx("8A8076")]
    img = Image.new("RGBA", (w, h))
    px = img.load()
    depth = 2 if pressed else 6
    top = 4 if pressed else 0
    face = (2, top, w - 2, h - 4 - depth + (0 if not pressed else 0), 6)
    body = (1, top, w - 1, h - 4, 7)
    for y in range(h):                                                  # 바닥 그림자
        for x in range(w):
            if sdf(x, y, 2, 6, w - 1, h, 8) < 0:
                px[x, y] = (14, 9, 12, 110 if not pressed else 60)
    for y in range(top, h - 4 + 1):
        for x in range(w):
            d = sdf(x, y, *body)
            if d > 0:
                continue
            if d > -1.2:
                px[x, y] = INK
                continue
            df = sdf(x, y, *face)
            if df > -0.5:                                                 # 앞 두께 (옆면)
                px[x, y] = ramp[1] if y > face[3] - 2 else ramp[2]
                continue
            nx, ny = normal(x, y, face)
            if df > -2.5:                                                 # 윗면 테 (볼록)
                t = -(nx * L[0] + ny * L[1])
                px[x, y] = ramp_pick(ramp[2:], t)
            elif df > -5:                                                 # 오목한 접시 (빛 반대)
                t = (nx * L[0] + ny * L[1]) * 0.8
                px[x, y] = ramp_pick(ramp[2:5], t)
            else:
                px[x, y] = ramp[3] if not pressed else ramp[3]
    if not disabled:                                                      # 반사광
        put(img, [(5, top + 3), (6, top + 3), (5, top + 4)], ramp[5])
    return img


KEYS = {"cream": CREAM, "amber": AMBERK, "charcoal": CHAR}
for kname, ramp in KEYS.items():
    for state in ("normal", "pressed", "disabled"):
        if kname != "cream" and state == "disabled":
            continue
        save(keycap(ramp, pressed=state == "pressed", disabled=state == "disabled"), f"rt_key_{kname}_{state}", [10, 10, 16, 10],
             f"키캡 {kname} {state} — 오목한 윗면 · 앞 두께 6px(눌림 2px, 4px 내려감) · 바닥 그림자")


def round_button(ramp, pressed):
    img = Image.new("RGBA", (30, 32))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 4, 28, 31], fill=(14, 9, 12, 120))                    # 그림자
    d.ellipse([0, 1, 28, 29], fill=INK)                                 # 받침 테
    d.ellipse([1, 2, 27, 28], fill=CREAM[1])
    disc(img, 14, 15 + (1 if pressed else 0), 10.5 if not pressed else 10, ramp)
    if not pressed:
        put(img, [(9, 9), (10, 9), (9, 10)], ramp[5])
    return img


for rname, ramp in (("red", REDK), ("charcoal", CHAR)):
    for st in ("normal", "pressed"):
        save(round_button(ramp, st == "pressed"), f"rt_round_{rname}_{st}", None, f"둥근 단추 {rname} {st} (30×32) — 볼록한 돔")


def toggle(on, f):
    img = Image.new("RGBA", (52, 26))
    d = ImageDraw.Draw(img)
    for y in range(26):                                                  # 판
        for x in range(52):
            dd = sdf(x, y, 0, 0, 52, 26, 6)
            if dd <= 0:
                img.putpixel((x, y), INK if dd > -1.2 else (CREAM[4] if (x < 3 or y < 3) and dd > -3 else CREAM[3]))
    rect(d, 6, 8, 37, 17, INK)                                          # 홈
    rect(d, 7, 9, 36, 16, INK_DEEP)
    rect(d, 7, 16, 36, 16, CREAM[1])
    kx = 22 if on else 8
    rect(d, kx, 6, kx + 13, 19, INK)                                    # 금속 손잡이
    rect(d, kx + 1, 7, kx + 12, 18, CHAR[4])
    rect(d, kx + 1, 7, kx + 12, 7, CHAR[5])
    rect(d, kx + 1, 7, kx + 1, 18, CHAR[5])
    rect(d, kx + 1, 18, kx + 12, 18, CHAR[2])
    for gx in range(kx + 4, kx + 10, 2):
        rect(d, gx, 9, gx, 16, CHAR[2])
    lit = on and BL["steady"][f]
    d.ellipse([41, 9, 47, 15], fill=INK)                                 # LED
    d.ellipse([42, 10, 46, 14], fill=PH[3] if lit else LED_OFF)
    if lit:
        put(img, [(43, 11)], PH[4])
    return img


save([toggle(False, f) for f in range(F)], "rt_toggle_off", None, "토글 꺼짐 (52×26) — 금속 손잡이 왼쪽, LED 꺼짐")
save([toggle(True, f) for f in range(F)], "rt_toggle_on", None, "토글 켜짐 — 손잡이 오른쪽, 녹색 LED")

LEDC = {1: (REDK[3], REDK[5]), 2: (AMBERK[3], AMBERK[5]), 3: (PH[2], PH[4]), 4: (PH[3], hx("E8FFDC"))}


def led_bars(level, f):
    img = Image.new("RGBA", (22, 14))
    d = ImageDraw.Draw(img)
    on, hi = LEDC[level]
    pulse = [0, 1, 1, 2, 2, 1, 1, 0][f]
    for i in range(4):
        hgt = 4 + i * 3
        x = 1 + i * 5
        rect(d, x, 13 - hgt, x + 3, 13, INK)
        lit = i < level
        rect(d, x + 1, 14 - hgt, x + 2, 12, (on if lit else LED_OFF))
        if lit and (pulse >= 1):
            rect(d, x + 1, 14 - hgt, x + 2, 14 - hgt, hi)
    return img


for lv in range(1, 5):
    save([led_bars(lv, f) for f in range(F)], f"rt_ledbar_{lv}", None, f"평가 키캡 위 LED 막대 {lv}칸 (22×14) — 켜진 칸 끝이 숨 쉬듯 밝아짐")


# ── 4. 화면 속 내용 (형광) — 잔디 · 막대 · 커서 ─────────────────────────
def heat(lv, glow=0):
    img = Image.new("RGBA", (10, 10))
    d = ImageDraw.Draw(img)
    cols = [(hx("123A20"), hx("1A4A2A")), (PH[0], PH[1]), (PH[1], PH[2]), (PH[2], PH[3]), (PH[3], PH[4])][lv]
    rect(d, 0, 0, 8, 8, cols[0])
    rect(d, 0, 0, 8, 0, cols[1])
    rect(d, 0, 0, 0, 8, cols[1])
    if lv == 0:
        put(img, [(4, 4)], PH[0])
    if lv == 4 or glow:
        put(img, [(1, 1), (2, 1), (1, 2)], PH[4] if not glow else hx("FFFFFF"))
    if glow:
        rect(d, 2, 2, 6, 6, PH[4])
    return img


for lv in range(5):
    save(heat(lv), f"rt_heat_{lv}", None, f"잔디 칸 {lv}단계 (10×10, 화면 속 형광)")
save([heat(4, g) for g in (0, 1, 1, 1, 1, 1, 0, 0)], "rt_heat_today", None, "오늘 칸 — 형광이 켜졌다 꺼짐 (번짐은 코드)")


def bar(level, f, w=16):
    img = Image.new("RGBA", (w, 10))
    on, hi = LEDC[level]
    for x in range(w):
        if x % 3 == 2:
            continue
        for y in range(1, 9):
            c = hi if y == 1 else on
            if (x - f * 2) % 16 in (0, 1):
                c = hx("F0FFE8")
            put(img, [(x, y)], c)
    return img


save([Image.new("RGBA", (16, 10))], "rt_bar_track", [0, 4, 0, 4], "막대 홈 자리 (투명 — 홈은 화면 바탕)")
for lv in range(1, 5):
    save([bar(lv, f) for f in range(F)], f"rt_bar_fill_{lv}", [0, 4, 0, 4], f"막대 채움 {lv}단계 — 3px 칸 + 흐르는 빛")
cur = []
for f in range(F):
    im = Image.new("RGBA", (8, 14))
    if f < 4:
        rect(ImageDraw.Draw(im), 0, 0, 7, 13, PH[3])
        rect(ImageDraw.Draw(im), 0, 0, 7, 0, PH[4])
    cur.append(im)
save(cur, "rt_cursor", None, "블록 커서 8×14 — 4프레임 켜짐 · 4프레임 꺼짐")


# ── 5. 담쟁이 (1pt 해상도: 잎 7px · 3단 명암 · 잎맥) ──────────────────────
LEAF = ["..##...", ".####..", "######.", "#######", ".#####.", "..###..", "...#..."]


def leaf(img, x, y, flip, shade):
    px = img.load()
    W_, H_ = img.size
    base = IVY[2 + shade]
    for r, row in enumerate(LEAF):
        for c, v in enumerate(row):
            if v != "#":
                continue
            cc = 6 - c if flip else c
            xx, yy = x + cc - 3, y + r - 3
            if not (0 <= xx < W_ and 0 <= yy < H_):
                continue
            col = base
            if r + (c if not flip else 6 - c) < 4:
                col = IVY[min(5, 3 + shade)]
            if r + (6 - c if not flip else c) > 8:
                col = IVY[1 + shade]
            if r == c or (flip and r == 6 - c):
                col = IVY[1 + shade]                                     # 잎맥
            px[xx, yy] = col


def ivy_curtain(w, h, seed, f, density=1.0):
    img = Image.new("RGBA", (w, h))
    rng = random.Random(seed)
    px = img.load()
    x = 3
    while x < w - 3:
        length = int(rng.randint(h // 4, h) * density)
        cx = x
        pts = []
        for y in range(length):
            pts.append((cx, y))
            if rng.random() < 0.22:
                cx += rng.choice((-1, 1))
        for (sx, sy) in pts:
            if 0 <= sx < w:
                px[sx, sy] = IVY[1]
        for i, (sx, sy) in enumerate(pts):
            if rng.random() < 0.2:
                sway = 1 if (rng.random() < 0.25 and f in (2, 3, 6)) else 0
                leaf(img, sx + rng.choice((-3, 3)) + sway, sy, rng.random() < 0.5, rng.choice((0, 1, 1, 2)))
        x += rng.randint(6, 14)
    out = img.copy()
    po = out.load()
    for y in range(h):                                                    # 잎 테두리
        for x in range(w):
            if not px[x, y][3] and any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                po[x, y] = IVY[0]
    return out


save([ivy_curtain(200, 90, 7, f) for f in range(F)], "rt_ivy_curtain_200", None, "늘어진 담쟁이 200×90 — 잎 7px · 3단 명암 · 잎맥 · 몇 장이 흔들림")
(OUT / "retro_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


# ── 6. 시안 화면 (1px = 1pt, 402×874) ─────────────────────────────────
def nine(img, caps, w, h):
    T, Lc, B, R = caps
    sw, sh = img.size
    out = Image.new("RGBA", (w, h))
    for sx0, sx1, dx0, dx1 in ((0, Lc, 0, Lc), (Lc, sw - R, Lc, w - R), (sw - R, sw, w - R, w)):
        for sy0, sy1, dy0, dy1 in ((0, T, 0, T), (T, sh - B, T, h - B), (sh - B, sh, h - B, h)):
            piece = img.crop((sx0, sy0, sx1, sy1))
            pw, ph = piece.size
            if not pw or not ph:
                continue
            for y in range(dy0, dy1, ph):
                for x in range(dx0, dx1, pw):
                    out.alpha_composite(piece.crop((0, 0, min(pw, dx1 - x), min(ph, dy1 - y))), (x, y))
    return out


GLARE = None


def shell(name, f, w, h):
    global GLARE
    if GLARE is None:
        GLARE = frames_of("rt_glass_glare")[0]
    img = nine(frames_of(name)[f], manifest[name]["cap"], w, h)
    T, Lc, B, R = manifest[name]["cap"]
    inset = INSETS[name]
    img.alpha_composite(GLARE, (inset[1] + 1, inset[0] + 1))
    return img


def screen_rect(name, x, y, w, h):
    """모니터 안 유리 영역 (글자 · 내용 배치용)."""
    T, Lc, B, R = manifest[name]["cap"]
    inset = INSETS[name]
    return x + inset[1] + 5, y + inset[0] + 5, x + w - inset[3] - 5, y + h - inset[2] - 5


INSETS = {"rt_monitor_crt": (16, 10, 24, 10), "rt_monitor_crt_turned": (16, 10, 24, 17),
             "rt_monitor_industrial": (14, 9, 10, 28), "rt_monitor_industrial_turned": (14, 16, 10, 28),
             "rt_monitor_term": (13, 8, 28, 8), "rt_monitor_term_turned_right": (13, 8, 28, 15),
             "rt_monitor_term_turned_left": (13, 15, 28, 8)}


FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"                  # 시안 전용 자리표시 글꼴


MINCHO = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"                # 시안 전용 (명조 자리표시)
MYUNGJO = "/System/Library/Fonts/Supplemental/AppleMyungjo.ttf"

import numpy as np  # noqa: E402


def glow_text(base, xy, s, size, color, bold=True, font=None):
    """형광 글자 + 번짐 (HDR 느낌)."""
    layer = Image.new("RGBA", base.size)
    fnt = ImageFont.truetype(font or FONT, size, index=(6 if bold else 0) if font is None else 0)
    ImageDraw.Draw(layer).text(xy, s, font=fnt, fill=color)
    halo = layer.filter(ImageFilter.GaussianBlur(2.2))
    halo.putalpha(halo.getchannel("A").point(lambda v: int(v * 0.55)))
    base.alpha_composite(halo)
    base.alpha_composite(layer)


def ink_text(base, xy, s, size, color, font):
    ImageDraw.Draw(base).text(xy, s, font=ImageFont.truetype(font, size), fill=color)


def shadow_under(img, x, y, w, h, strength=150):
    sh = Image.new("RGBA", img.size)
    ImageDraw.Draw(sh).rounded_rectangle([x + 4, y + 7, x + w + 3, y + h + 6], 10, fill=(6, 3, 5, strength))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))


def screen_glow(img, r, strength=60):
    g = Image.new("RGBA", img.size)
    ImageDraw.Draw(g).rectangle([r[0] - 6, r[1] - 6, r[2] + 6, r[3] + 6], fill=(70, 200, 100, strength))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(12)))


# ── 7. 탭 아이콘 (키캡에 찍힌 글리프 22×22) ─────────────────────────────
def tab_glyph(kind):
    m = Image.new("L", (22, 22))
    d = ImageDraw.Draw(m)
    if kind == "terminal":      # 판독 단말 = 스캐너 위 종이 + 지나가는 빛줄
        d.rectangle([4, 2, 17, 19], outline=255)
        for y in (6, 9, 12):
            d.line([(7, y), (14 if y != 9 else 12, y)], fill=255)
        d.line([(1, 15), (20, 15)], fill=255)
        d.line([(1, 16), (20, 16)], fill=160)
    elif kind == "institute":   # 연구소 = 지붕 + 기둥 셋 + 담쟁이 잎
        d.polygon([(11, 1), (21, 7), (1, 7)], outline=255)
        for x in (4, 10, 16):
            d.rectangle([x, 9, x + 1, 17], fill=255)
        d.line([(1, 19), (20, 19)], fill=255)
        d.line([(1, 20), (20, 20)], fill=255)
        d.ellipse([15, 3, 19, 7], fill=200)
    elif kind == "records":     # 판독 기록 = 막대 넷 + 선
        for i, hgt in enumerate((6, 10, 8, 15)):
            d.rectangle([2 + i * 5, 19 - hgt, 4 + i * 5, 19], fill=255)
        d.line([(1, 20), (20, 20)], fill=255)
        d.line([(3, 9), (8, 5), (13, 7), (19, 2)], fill=200)
    else:                       # 단말 설정 = 톱니
        for y in range(22):
            for x in range(22):
                r = math.hypot(x - 10.5, y - 10.5)
                a = (math.atan2(y - 10.5, x - 10.5) + math.pi / 8) % (math.pi / 4)
                if (r < 7.5 or (r < 10 and abs(a - math.pi / 8) < 0.25)) and r > 3:
                    m.putpixel((x, y), 255)
    return m


def tab_icon(kind, selected):
    m = tab_glyph(kind)
    img = Image.new("RGBA", (22, 22))
    col = PH[3] if selected else CREAM[0]
    hi = PH[4] if selected else CREAM[1]
    px = img.load()
    for y in range(22):
        for x in range(22):
            v = m.getpixel((x, y))
            if v:
                px[x, y] = (hi if v < 220 else col)
    if not selected:                                                       # 찍힌 글자: 아래쪽 1px 밝은 눌림 자국
        out = Image.new("RGBA", (22, 23))
        sh = img.copy()
        sh.putalpha(sh.getchannel("A").point(lambda a: int(a * 0.5)))
        out.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", (22, 22), CREAM[5][:3]).split(), sh.getchannel("A"))), (0, 1))
        out.alpha_composite(img)
        return out
    return img


TAB_KINDS = ("terminal", "institute", "records", "settings")
for k in TAB_KINDS:
    save(tab_icon(k, False), f"rt_tab_{k}", None, f"탭 아이콘 {k} — 크림 키캡에 찍힌 글리프 (눌림 자국 1px)")
    save(tab_icon(k, True), f"rt_tab_{k}_on", None, f"탭 아이콘 {k} 선택 — 숯색 키캡 위 형광 녹색")


# ── 8. 스캐너 · 종이 · 스캔 빛줄 ─────────────────────────────────────
def scanner():
    caps = (14, 46, 30, 16)
    T, Lc, B, R = caps
    w, h = Lc + 12 + R, T + 12 + B
    img = Image.new("RGBA", (w, h))
    px = img.load()
    outer = (0, 0, w, h, 8)
    glass = (10, 12, w - 10, h - 24, 3)
    for y in range(h):
        for x in range(w):
            d = sdf(x, y, *outer)
            if d > 0:
                continue
            if d > -1.2:
                px[x, y] = INK
                continue
            g = sdf(x, y, *glass)
            if g <= -1:
                px[x, y] = hx("1C2426") if -g > 3 else hx("141A1C")          # 유리 판
            elif g <= 0:
                px[x, y] = INK_DEEP
            elif g < 3:
                nx, ny = normal(x, y, glass)
                px[x, y] = ramp_pick(RECESS, -(nx * -L[0] + ny * -L[1]))
            elif d > -4:
                nx, ny = normal(x, y, outer)
                px[x, y] = ramp_pick(PUTTY, max(-1, min(1, -(nx * L[0] + ny * L[1]) * 1.25)))
            else:
                px[x, y] = PUTTY[3]
    d = ImageDraw.Draw(img)
    for k in range(9):                                                      # 유리 반사 사선 (왼쪽 위 cap 안)
        put(img, [(14 + k, 16 + k // 2), (20 + k, 16 + k // 2)], hx("2C3A3C"))
    y = h - 19                                                              # 앞 턱: LCD · 스캔 단추 · LED
    rect(d, 6, y, 36, y + 11, INK)
    rect(d, 7, y + 1, 35, y + 10, hx("1E3A24"))
    for x in range(9, 33, 4):
        rect(d, x, y + 4, x + 2, y + 7, PH[2])
    rect(d, w - 14, y + 2, w - 6, y + 9, INK)
    rect(d, w - 13, y + 3, w - 7, y + 7, AMBERK[3])
    rect(d, w - 13, y + 3, w - 7, y + 3, AMBERK[5])
    for x in range(40, w - 18):
        if x % 4 == 0:
            put(img, [(x, y + 8)], PUTTY[1])
    return img, list(caps)


sc, sc_caps = scanner()
sc = add_top(sc, PUTTY, 5)
sc_caps[0] += 5
save(sc, "rt_scanner", sc_caps, "스캐너 (평판) — 위 덮개 경첩 · 어두운 유리 판 · 앞 턱의 녹색 LCD · 호박 스캔 단추. 유리 위에 종이(rt_paper)를 얹음")


def paper():
    img = Image.new("RGBA", (48, 48))
    px = img.load()
    for y in range(48):
        for x in range(48):
            edge = min(x, y, 47 - x, 47 - y)
            c = (238, 231, 210)
            n = (x * 7 + y * 13 + (x * y) % 5) % 20                           # 섬유 결 (주기 20 = 가운데 폭)
            if n < 2:
                c = (226, 217, 194)
            elif n == 7:
                c = (244, 239, 222)
            if edge < 3:
                c = tuple(int(v * (0.93 + edge * 0.02)) for v in c)          # 가장자리 누렇게
            if edge == 0:
                c = (196, 184, 158)
            px[x, y] = c + (255,)
    for k in range(7):                                                      # 오른쪽 아래 말린 모서리
        for j in range(7 - k):
            px[47 - k, 47 - j] = (0, 0, 0, 0) if k + j < 3 else ((210, 200, 176, 255) if k + j < 5 else px[47 - k, 47 - j])
    return img


save(paper(), "rt_paper", [14, 14, 14, 14], "스캔한 종이 (9-slice) — 섬유 결 · 누렇게 바랜 가장자리 · 말린 모서리. 글자는 명조체로 코드가 얹음")


def tape():
    img = Image.new("RGBA", (22, 10))
    for y in range(10):
        for x in range(22):
            if 1 <= y <= 8 and not (x < 2 and y in (1, 8)) and not (x > 19 and y in (1, 8)):
                img.putpixel((x, y), (236, 220, 160, 150 if x % 4 else 175))
    return img


save(tape(), "rt_tape", None, "종이를 붙인 테이프 (반투명)")


def scan_bar(f):
    img = Image.new("RGBA", (32, 16))
    for y in range(16):
        dist = abs(y - 7.5)
        a = int(max(0, 1 - dist / 8) ** 2 * 200)
        c = (230, 255, 236) if dist < 1 else (140, 255, 170)
        for x in range(32):
            flick = 18 if (x + f * 3) % 11 == 0 else 0
            img.putpixel((x, y), c + (min(255, a + flick),))
    return img


save([scan_bar(f) for f in range(F)], "rt_scan_bar", [0, 0, 0, 0], "스캔 빛줄 (가로로 타일) — 종이 위를 위에서 아래로 지나감, 코드가 위치를 옮김")


# ── 9. 코드만 흐르는 장식 모니터 (통째로 구운 그림) ─────────────────────────
def code_lines(seed, n=40):
    rng = random.Random(seed)
    lines, indent = [], 0
    for _ in range(n):
        if rng.random() < 0.2:
            indent = max(0, indent + rng.choice((-1, 1)))
        kind = rng.choices(["code", "comment", "key", "err", "blank"], [55, 12, 15, 4, 14])[0]
        lines.append((indent, kind, [rng.randint(2, 7) for _ in range(rng.randint(1, 5))]))
    return lines


def code_monitor(name, w, h, seed, f):
    img = shell(name, f, w, h)
    x0, y0, x1, y1 = screen_rect(name, 0, 0, w, h)
    lines = code_lines(seed)
    lh = 6
    scroll = f * lh // 2                                                    # 8프레임에 네 줄 위로
    px = img.load()
    for i, (ind, kind, words) in enumerate(lines * 2):
        y = y0 + i * lh - scroll
        if y < y0 or y > y1 - 4:
            continue
        x = x0 + ind * 6
        col = {"code": PH[2], "comment": PH[0], "key": PH[3], "err": REDK[4], "blank": None}[kind]
        if not col:
            continue
        for wl in words:
            for k in range(wl * 2):
                if x + k < x1:
                    px[x + k, y] = col
                    px[x + k, y + 1] = col if kind == "key" else (col[0], col[1], col[2], 160)
            x += wl * 2 + 3
    if f % 2 == 0:                                                          # 마지막 줄 커서
        rect(ImageDraw.Draw(img), x0, y1 - 8, x0 + 4, y1 - 1, PH[3])
    return img


CODE_MON = {
    "rt_code_term_a": ("rt_monitor_term_turned_right", 180, 110, 11),
    "rt_code_term_b": ("rt_monitor_term", 150, 100, 12),
    "rt_code_crt_wide": ("rt_monitor_crt", 380, 120, 13),
    "rt_code_industrial": ("rt_monitor_industrial_turned", 200, 104, 14),
}
for nm, (shell_name, w, h, sd) in CODE_MON.items():
    save([code_monitor(shell_name, w, h, sd, f) for f in range(F)], nm, None,
         f"코드만 흐르는 장식 모니터 {w}×{h} — 글줄이 위로 흐르고 커서 깜빡 (통계 · 설정 사이사이에 끼움)")


# ── 10. 노멀맵 — 평면 도트에 빛을 받게 하는 기법 (SpriteKit SKLightNode용) ──────────
def auto_normal(img, strength=2.4):
    """알파 경계 거리(둥근 테) + 밝기(무늬)로 높이를 만들고 기울기로 법선을 구함 — Sprite Lamp · Laigter 방식."""
    a = np.array(img.getchannel("A"), dtype=np.float32) / 255
    rgb = np.array(img.convert("RGB"), dtype=np.float32)
    luma = (rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11) / 255
    dist = (a > 0.5).astype(np.float32)
    acc = dist.copy()
    for _ in range(4):                                                     # 경계에서 4px까지 거리
        e = np.minimum.reduce([np.roll(dist, 1, 0), np.roll(dist, -1, 0), np.roll(dist, 1, 1), np.roll(dist, -1, 1), dist])
        dist = e
        acc += dist
    height = 0.65 * (acc / 5) + 0.35 * luma
    gy, gx = np.gradient(height)
    nx, ny, nz = -gx * strength, -gy * strength, np.ones_like(height)
    n = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    out = np.stack([(nx / n * 0.5 + 0.5) * 255, (ny / n * 0.5 + 0.5) * 255, (nz / n * 0.5 + 0.5) * 255, a * 255], -1)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


NORMAL_SRC = [n for n in manifest if n.startswith(("rt_monitor", "rt_key", "rt_round", "rt_toggle", "rt_cable", "rt_scanner"))]
for n in NORMAL_SRC:
    auto_normal(frames_of(n)[0]).save(OUT / f"{n}_n.png")
    manifest[n]["normal"] = f"{n}_n.png"


def light_pass(color, normals, lights, ambient=0.5):
    """color · normals: 같은 크기 RGBA. lights: [(x, y, z, (r,g,b), 세기, 반경)]. 화면(녹색 유리 · 글자)은 스스로 빛나서 그대로 둠."""
    c = np.array(color, dtype=np.float32)
    nm = np.array(normals, dtype=np.float32)
    N = nm[..., :3] / 255 * 2 - 1
    flat = nm[..., 3] < 10
    N[flat] = (0, 0, 1)
    H, W_ = c.shape[:2]
    ys, xs = np.mgrid[0:H, 0:W_].astype(np.float32)
    acc = np.full((H, W_, 3), ambient, dtype=np.float32)
    for lx, ly, lz, col, power, radius in lights:
        v = np.stack([lx - xs, ly - ys, np.full_like(xs, lz)], -1)
        dist = np.linalg.norm(v, axis=-1)
        v /= dist[..., None]
        ndl = np.clip((N * v).sum(-1), 0, 1)
        att = power / (1 + (dist / radius) ** 2)
        acc += (ndl * att)[..., None] * (np.array(col, np.float32) / 255)
    rgb = c[..., :3]
    emissive = (rgb[..., 1] > rgb[..., 0] + 12) & (rgb[..., 1] > rgb[..., 2])   # 형광 화면
    lit = rgb * acc
    lit[emissive] = rgb[emissive] * np.maximum(1.0, acc[emissive] * 0.9)
    out = np.concatenate([lit.clip(0, 255), c[..., 3:4]], -1)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


(OUT / "retro_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


# ── 11. 시안 화면 ─────────────────────────────────────────────────
class Scene:
    """색 · 법선을 같이 쌓는 캔버스 (마지막에 조명)."""

    def __init__(self, w, h, bg):
        self.c = bg.copy() if bg is not None else Image.new("RGBA", (w, h))
        self.n = Image.new("RGBA", (w, h))
        self.lights = []

    def put(self, sprite, xy, normal=True):
        self.c.alpha_composite(sprite, xy)
        if normal:
            self.n.alpha_composite(auto_normal(sprite), xy)

    def lit(self, ambient=0.55):
        return light_pass(self.c, self.n, self.lights, ambient)


def monitor_at(sc, name, f, x, y, w, h, glow=50):
    shadow_under(sc.c, x, y, w, h)
    m = shell(name, f, w, h)
    r = screen_rect(name, x, y, w, h)
    screen_glow(sc.c, r, glow)
    sc.put(m, (x, y))
    cx, cy = (r[0] + r[2]) / 2, (r[1] + r[3]) / 2
    sc.lights.append((cx, cy + (r[3] - r[1]) * 0.6, 26, (120, 255, 150), 0.18, 110))   # 화면이 아래쪽 물건을 비춤
    return r


def code_at(sc, nm, f, x, y):
    src, w, h, _ = CODE_MON[nm]
    shadow_under(sc.c, x, y, w, h)
    sprite = frames_of(nm)[f]
    sc.put(sprite, (x, y))
    r = screen_rect(src, x, y, w, h)
    screen_glow(sc.c, r, 30)
    sc.lights.append(((r[0] + r[2]) / 2, r[3] + 10, 26, (120, 255, 150), 0.12, 80))


def wall(w, h):
    img = Image.new("RGBA", (w, h), hx("140D11"))
    d = ImageDraw.Draw(img)
    for row, y in enumerate(range(0, h, 12)):
        rect(d, 0, y, w - 1, y, hx("0E080B"))
        off = 0 if row % 2 else 14
        for x in range(off, w, 28):
            rect(d, x, y, x, y + 11, hx("0E080B"))
    return img


def vignette(img, amount=200):
    w, h = img.size
    v = Image.new("L", (w, h), 0)
    ImageDraw.Draw(v).ellipse([-w * 0.3, -h * 0.07, w * 1.3, h * 1.07], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(80))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dark.putalpha(v.point(lambda p: amount - int(p * amount / 255 * 0.95)))
    img.alpha_composite(dark)


bundle = frames_of("rt_cable_bundle_v")[0]
ivyf = frames_of("rt_ivy_curtain_200")
loop_a, dangle, loop_c, coilf = (frames_of(n)[0] for n in ("rt_cable_loop_a", "rt_cable_dangle_b", "rt_cable_loop_c", "rt_cable_coil"))
cells = [frames_of(f"rt_heat_{i}")[0] for i in range(5)]
today = frames_of("rt_heat_today")
cursor = frames_of("rt_cursor")
fills = {lv: frames_of(f"rt_bar_fill_{lv}") for lv in range(1, 5)}
ledbars = {lv: frames_of(f"rt_ledbar_{lv}") for lv in range(1, 5)}
rng = random.Random(5)
HIST = [0] * 98
for i in range(68, 96):
    HIST[i] = rng.choice([0, 0, 1, 1, 2, 3])
HIST[96], HIST[97] = 3, 4


def tabbar(img, f, sel, y=790):
    base = Image.new("RGBA", (390, 80))
    for yy in range(80):
        for xx in range(390):
            dd = sdf(xx, yy, 0, 0, 390, 80, 12)
            if dd <= 0:
                if dd > -1.2:
                    c = INK
                elif dd > -4:
                    nx, ny = normal(xx, yy, (0, 0, 390, 80, 12))
                    c = ramp_pick(CREAM, -(nx * L[0] + ny * L[1]) * 1.2)
                else:
                    c = CREAM[2] if (yy % 4 == 0 and yy > 66) else CREAM[3]
                base.putpixel((xx, yy), c)
    shadow_under(img, 6, y, 390, 80, 180)
    img.alpha_composite(base, (6, y))
    for i, kind in enumerate(TAB_KINDS):
        pressed = i == sel
        k = keycap(CHAR if pressed else CREAM, pressed=pressed)
        kx = 16 + i * 93
        img.alpha_composite(nine(k, [10, 10, 16, 10], 88, 58), (kx, y + 8))
        ic = frames_of(f"rt_tab_{kind}{'_on' if pressed else ''}")[0].resize((44, 44 if pressed else 46), Image.NEAREST)
        if pressed:
            halo = ic.filter(ImageFilter.GaussianBlur(3))
            halo.putalpha(halo.getchannel("A").point(lambda v: int(v * 0.6)))
            img.alpha_composite(halo, (kx + 22, y + 12 + 4))
            ImageDraw.Draw(img).ellipse([kx + 74, y + 16, kx + 78, y + 20], fill=PH[3] if BL["steady"][f] else LED_OFF)
        img.alpha_composite(ic, (kx + 22, y + 12 + (4 if pressed else 0)))


# 통계: 길게 스크롤되는 화면 (코드 모니터가 사이사이) — 시차 4겹
CONTENT_H = 1460


def stats_content(f):
    sc = Scene(402, CONTENT_H, Image.new("RGBA", (402, CONTENT_H)))
    r = monitor_at(sc, "rt_monitor_term_turned_right", f, 18, 30, 236, 120, 40)
    glow_text(sc.c, (r[0] + 2, r[1] + 2), "판독 기록", 24, PH[3])
    if f < 4:
        sc.c.alpha_composite(cursor[0].resize((10, 22), Image.NEAREST), (r[0] + 118, r[1] + 7))
    glow_text(sc.c, (r[0] + 2, r[1] + 36), "NJL-OS 2.94 · STATS", 11, PH[2], bold=False)
    code_at(sc, "rt_code_term_b", f, 258, 40)
    r = monitor_at(sc, "rt_monitor_crt", f, 14, 166, 376, 206, 55)
    glow_text(sc.c, (r[0] + 2, r[1]), "성실도 잔디", 15, PH[3])
    glow_text(sc.c, (r[2] - 66, r[1] + 2), "2일 연속", 13, AM)
    for i, lv in enumerate(HIST):
        sc.c.alpha_composite(today[f] if i == 97 else cells[lv], (r[0] + 10 + (i // 7) * 22, r[1] + 26 + (i % 7) * 12))
    sc.put(loop_a, (120, 362))
    data = [("27/775", "외운 단어", "rt_monitor_term", (16, 386)), ("92%", "기억 유지율", "rt_monitor_term_turned_left", (206, 392)),
            ("73.2초", "평균 반응 시간", "rt_monitor_term_turned_right", (12, 520)), ("67회", "누적 평가", "rt_monitor_term", (208, 526))]
    for val, label, nm, (x, y) in data:
        r = monitor_at(sc, nm, f, x, y, 182, 124, 35)
        glow_text(sc.c, (r[0] + 2, r[1] + 2), val, 22, PH[4])
        glow_text(sc.c, (r[0] + 2, r[1] + 34), label, 12, PH[2], bold=False)
    sc.put(loop_c, (150, 640))
    code_at(sc, "rt_code_crt_wide", f, 10, 664)
    r = monitor_at(sc, "rt_monitor_industrial_turned", f, 10, 800, 384, 156, 45)
    for i, (lv, nm2, n, pct) in enumerate([(1, "판독 불가", 15, 22), (2, "흐림", 10, 15), (3, "판독", 39, 58), (4, "선명", 3, 4)]):
        yy = r[1] + 4 + i * 26
        sc.c.alpha_composite(ledbars[lv][f], (r[0] + 2, yy))
        glow_text(sc.c, (r[0] + 30, yy - 1), nm2, 13, PH[3] if lv > 1 else REDK[4])
        bw = int((r[2] - r[0] - 170) * pct / 100) + 12
        sc.c.alpha_composite(nine(fills[lv][f], [0, 4, 0, 4], bw, 10), (r[0] + 104, yy + 3))
        glow_text(sc.c, (r[2] - 38, yy - 1), f"{n}회", 12, PH[2], bold=False)
    sc.put(dangle, (330, 944))
    code_at(sc, "rt_code_term_a", f, 196, 982)
    code_at(sc, "rt_code_industrial", f, 4, 1000)
    r = monitor_at(sc, "rt_monitor_crt_turned", f, 16, 1130, 370, 170, 50)
    glow_text(sc.c, (r[0] + 2, r[1]), "최근 7일 판독량", 15, PH[3])
    for i, v in enumerate((3, 0, 5, 9, 4, 12, 15)):
        bh = v * 5
        rect(ImageDraw.Draw(sc.c), r[0] + 16 + i * 44, r[3] - 8 - bh, r[0] + 40 + i * 44, r[3] - 8, PH[2])
        rect(ImageDraw.Draw(sc.c), r[0] + 16 + i * 44, r[3] - 8 - bh, r[0] + 40 + i * 44, r[3] - 8 - bh, PH[4])
    sc.lights.append((360, -40, 140, (255, 214, 160), 0.9, 420))          # 위쪽 따뜻한 천장등
    return sc.lit(0.7)


def back_layer(f):
    """뒤쪽 층: 어둡고 흐린 모니터 더미 (멀리 있는 느낌)."""
    img = wall(402, 1800)
    far = Image.new("RGBA", (402, 1800))
    rr = random.Random(2)
    y = 0
    while y < 1800:
        for x in (-30, 90, 210, 320):
            nm = rr.choice(["rt_monitor_term", "rt_monitor_term_turned_left", "rt_monitor_industrial"])
            w, h = rr.randint(110, 150), rr.randint(80, 100)
            far.alpha_composite(shell(nm, (f + x) % F, w, h), (x + rr.randint(-6, 6), y + rr.randint(-6, 6)))
        y += 96
    far = far.filter(ImageFilter.GaussianBlur(1.2))
    tint = Image.new("RGBA", far.size, (10, 6, 10, 0))
    tint.putalpha(far.getchannel("A").point(lambda a: int(a * 0.72)))
    far.alpha_composite(tint)
    img.alpha_composite(far)
    return img


def front_layer(f):
    """앞쪽 층: 카메라 가까이 있는 담쟁이 · 전선 (크고 흐리고 어두움)."""
    img = Image.new("RGBA", (402, 1800))
    for y in range(-20, 1800, 64):
        img.alpha_composite(bundle, (-8, y))
        img.alpha_composite(bundle.transpose(Image.FLIP_LEFT_RIGHT), (380, y + 30))
    for y in (0, 520, 1100):
        iv = ivyf[f].resize((200, 90), Image.NEAREST)
        img.alpha_composite(iv, (-140, y))
        img.alpha_composite(iv.transpose(Image.FLIP_LEFT_RIGHT), (344, y + 260))
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    dark = Image.new("RGBA", img.size, (6, 4, 6, 0))
    dark.putalpha(img.getchannel("A").point(lambda a: int(a * 0.45)))
    img.alpha_composite(dark)
    return img


def dust(f, t, w=402, h=874, n=26):
    img = Image.new("RGBA", (w, h))
    rr = random.Random(9)
    for i in range(n):
        x0, y0, sp = rr.uniform(0, w), rr.uniform(0, h), rr.uniform(0.3, 1.0)
        x = (x0 + math.sin(t * 0.3 + i) * 6) % w
        y = (y0 - t * sp * 3) % h
        a = int(90 + 80 * math.sin(t * 0.7 + i))
        img.putpixel((int(x), int(y)), (200, 255, 210, max(0, a)))
        if i % 4 == 0:
            img.putpixel((int(x) + 1, int(y)), (200, 255, 210, max(0, a // 2)))
    return img


CONTENT = [stats_content(f) for f in range(F)]
BACKS = [back_layer(f) for f in range(F)]
FRONTS = [front_layer(f) for f in range(F)]
coil_n = coilf


def stats_frame(i, n):
    t = i / (n - 1)
    ease = 0.5 - 0.5 * math.cos(math.pi * min(1, t * 1.25))               # 내려갔다가 잠깐 멈춤
    scroll = ease * (CONTENT_H - 874 + 110)
    f = i % F
    img = Image.new("RGBA", (402, 874), hx("140D11"))
    img.alpha_composite(BACKS[f].crop((0, int(scroll * 0.45), 402, int(scroll * 0.45) + 874)))   # 뒤: 0.45배
    img.alpha_composite(CONTENT[f].crop((0, int(scroll), 402, int(scroll) + 874)))              # 본문: 1배
    img.alpha_composite(dust(f, i))
    img.alpha_composite(FRONTS[f].crop((0, int(scroll * 1.35), 402, int(scroll * 1.35) + 874)))  # 앞: 1.35배
    vignette(img, 190)
    img.alpha_composite(coilf, (318, 764))
    tabbar(img, f, 2)
    return img


N = 40
frames = [stats_frame(i, N) for i in range(N)]
frames[0].save(PREV / "preview_retro_stats_scroll.gif", save_all=True, append_images=frames[1:], duration=90, loop=0, disposal=2)
frames[0].save(PREV / "preview_retro_stats_mock.png")
print("stats ok")


# 학습: 스캐너 위 종이 카드 + 스캔 빛줄 + 평가 키
sc_frames = frames_of("rt_scanner")
paper_img = frames_of("rt_paper")[0]
tape_img = frames_of("rt_tape")[0]
bar_frames = frames_of("rt_scan_bar")


def study_frame(i, n):
    f = i % F
    sc = Scene(402, 874, wall(402, 874))
    for y in range(-20, 874, 64):
        sc.c.alpha_composite(bundle, (-8, y))
        sc.c.alpha_composite(bundle.transpose(Image.FLIP_LEFT_RIGHT), (380, y + 30))
    x, y, w, h = 12, 40, 378, 500
    shadow_under(sc.c, x, y, w, h, 170)
    sc.put(nine(sc_frames[0], sc_caps, w, h), (x, y))
    gx0, gy0, gx1, gy1 = x + 12, y + 5 + 14, x + w - 12, y + h - 26
    px0, py0, pw, ph = gx0 + 10, gy0 + 12, gx1 - gx0 - 26, gy1 - gy0 - 30
    shadow_under(sc.c, px0, py0, pw, ph, 120)
    sc.put(nine(paper_img, [14, 14, 14, 14], pw, ph), (px0, py0))
    sc.put(tape_img, (px0 - 6, py0 - 4), normal=False)
    sc.put(tape_img.transpose(Image.FLIP_LEFT_RIGHT), (px0 + pw - 16, py0 - 4), normal=False)
    INK_C = (40, 28, 30, 255)
    ink_text(sc.c, (px0 + 18, py0 + 16), "第一章 · 12 / 43", 12, (120, 104, 96, 255), MYUNGJO)
    ink_text(sc.c, (px0 + 66, py0 + 64), "諦める", 52, INK_C, MINCHO)
    ink_text(sc.c, (px0 + 102, py0 + 140), "あきらめる", 18, (80, 64, 60, 255), MINCHO)
    rect(ImageDraw.Draw(sc.c), px0 + 40, py0 + 178, px0 + pw - 40, py0 + 178, (190, 178, 156, 255))
    ink_text(sc.c, (px0 + 60, py0 + 196), "단념하다 · 포기하다", 18, INK_C, MYUNGJO)
    ink_text(sc.c, (px0 + 28, py0 + 262), "夢をあきらめるな。", 17, (70, 56, 54, 255), MINCHO)
    ink_text(sc.c, (px0 + 28, py0 + 290), "꿈을 포기하지 마.", 14, (110, 96, 90, 255), MYUNGJO)
    sc.lights.append((330, -60, 160, (255, 220, 170), 1.0, 520))          # 스캐너 위 스탠드 불빛
    out = sc.lit(0.8)
    t = (i % 16) / 15                                                      # 스캔 빛줄: 종이 위에서 아래로
    by = int(py0 - 8 + t * (ph + 8))
    band = nine(bar_frames[f], [0, 0, 0, 0], pw + 20, 16)
    out.alpha_composite(band, (px0 - 10, by))
    glow = Image.new("RGBA", out.size)
    ImageDraw.Draw(glow).rectangle([px0 - 10, by + 4, px0 + pw + 10, by + 12], fill=(140, 255, 170, 70))
    out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8)))
    labels = ["판독 불가", "흐림", "판독", "선명"]
    for k in range(4):
        pressed = (k == 2 and f in (3, 4))
        key = keycap(CHAR, pressed=pressed)
        kx, ky = 14 + k * 95, 588 + [0, 4, 1, 3][k]
        shadow_under(out, kx, ky, 88, 92, 140)
        out.alpha_composite(nine(key, [10, 10, 16, 10], 88, 92), (kx, ky))
        dy = 4 if pressed else 0
        out.alpha_composite(ledbars[k + 1][f].resize((44, 28), Image.NEAREST), (kx + 22, ky + 14 + dy))
        ImageDraw.Draw(out).text((kx + 12 + (8 if len(labels[k]) < 3 else 0), ky + 50 + dy), labels[k],
                                 font=ImageFont.truetype(FONT, 13, index=6), fill=CREAM[4] if not pressed else PH[3])
    out.alpha_composite(dangle, (300, 690))
    out.alpha_composite(ivyf[f], (-20, -40))
    out.alpha_composite(ivyf[(f + 4) % F].transpose(Image.FLIP_LEFT_RIGHT), (222, -50))
    vignette(out, 180)
    tabbar(out, f, 0)
    return out


frames = [study_frame(i, 16) for i in range(16)]
frames[0].save(PREV / "preview_retro_study_mock.gif", save_all=True, append_images=frames[1:], duration=110, loop=0, disposal=2)
frames[6].save(PREV / "preview_retro_study_mock.png")
print("study ok")


# 노멀맵 조명 비교: 같은 모니터 — 왼쪽 평면 / 오른쪽 노멀맵 + 움직이는 불빛
def light_demo(i, n=16):
    a = i / n * 2 * math.pi
    lx, ly = 200 + math.cos(a) * 170, 110 + math.sin(a) * 80
    out = Image.new("RGBA", (402, 230), hx("140D11"))
    for k, use_n in enumerate((False, True)):
        sc = Scene(190, 200, Image.new("RGBA", (190, 200), hx("140D11")))
        m = shell("rt_monitor_crt_turned", i % F, 170, 150)
        sc.put(m, (8, 30), normal=use_n)
        sc.lights.append((lx - k * 205, ly, 22, (255, 220, 170), 2.2, 140))
        out.alpha_composite(sc.lit(0.35), (4 + k * 205, 10))
    d = ImageDraw.Draw(out)
    d.ellipse([lx - 4, ly - 4, lx + 4, ly + 4], fill=(255, 230, 170, 255))
    d.text((40, 212), "평면 (빛 무시)", font=ImageFont.truetype(FONT, 12, index=6), fill=CREAM[3])
    d.text((236, 212), "노멀맵 + 움직이는 빛", font=ImageFont.truetype(FONT, 12, index=6), fill=PH[3])
    return out


frames = [light_demo(i) for i in range(16)]
frames[0].save(PREV / "preview_retro_normalmap_demo.gif", save_all=True, append_images=frames[1:], duration=110, loop=0, disposal=2)
print("light ok")
