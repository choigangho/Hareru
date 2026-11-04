"""Author pixel effect animations (and the menu icon) procedurally.

usage: fx_author.py <out_dir>
Every effect is a horizontal strip of square-or-fixed frames at asset density (1 room px = 2 px).
Fading uses an ordered (Bayer) dither instead of alpha so pixels stay crisp.
Palette follows the institute art: amber accent, soft cyan, ink indigo, washi off-white, dust beige.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
random.seed(7)

AMBER = (255, 206, 92, 255)
AMBER_HOT = (255, 240, 170, 255)
AMBER_DEEP = (214, 140, 52, 255)
CYAN = (110, 226, 222, 255)
CYAN_HOT = (220, 255, 250, 255)
INK = (34, 32, 58, 255)
INK_SOFT = (74, 70, 112, 255)
WASHI = (244, 236, 214, 255)
DUST = (196, 178, 150, 255)
DUST_DARK = (150, 132, 108, 255)
WATER = (150, 205, 230, 255)
WATER_HOT = (230, 248, 255, 255)
OUTLINE = (24, 26, 40, 255)

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def keep(x, y, visibility):
    """Ordered dither: visibility 0..1 → fraction of pixels kept."""
    return BAYER4[y % 4][x % 4] < visibility * 16


def put(img, x, y, color, visibility=1.0):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height and keep(x, y, visibility):
        img.putpixel((x, y), color)


def disc(img, cx, cy, r, color, visibility=1.0):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                put(img, x, y, color, visibility)


def star(img, cx, cy, arm, color, core, visibility=1.0):
    """4-point pixel sparkle."""
    for i in range(-arm, arm + 1):
        c = core if abs(i) <= max(0, arm // 3) else color
        put(img, cx + i, cy, c, visibility)
        put(img, cx, cy + i, c, visibility)
    if arm >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            put(img, cx + dx, cy + dy, color, visibility)


def strip(frames, name):
    w, h = frames[0].size
    s = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * w, 0))
    s.save(out / f"{name}.png")
    big = s.resize((s.width * 6, s.height * 6), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (58, 64, 78, 255))
    bg.alpha_composite(big)
    bg.save(out / f"preview_{name}_x6.png")
    return len(frames), w, h


specs = {}

# 1) dust puff — a facility lands. 6 frames, 56x24: puffs roll outward along the floor diamond and thin out
frames = []
puffs = [(-1, random.uniform(0.8, 1.2)) for _ in range(5)] + [(1, random.uniform(0.8, 1.2)) for _ in range(5)]
for f in range(6):
    img = Image.new("RGBA", (56, 24))
    t = f / 5
    vis = 1.0 if f < 2 else 1.0 - (f - 1) / 5
    for k, (side, speed) in enumerate(puffs):
        spread = (6 + 20 * t * speed) * side * (0.6 + 0.4 * (k % 5) / 4)
        cx = 28 + spread
        cy = 17 - (k % 5) * 0.8 - 3 * t
        r = 2.2 + 3.2 * t * (0.7 + 0.3 * ((k * 3) % 5) / 4)
        disc(img, cx, cy, r + 0.8, DUST_DARK, vis * 0.9)
        disc(img, cx - 0.5, cy - 0.7, r, DUST, vis)
    frames.append(img)
specs["fx_dust"] = strip(frames, "fx_dust")

# 2) combo sparkle burst — 7 frames, 48x48: amber stars fly out from the centre, then twinkle and fade
frames = []
rays = [(i * math.tau / 7 + random.uniform(-0.2, 0.2), random.uniform(0.75, 1.0)) for i in range(7)]
for f in range(7):
    img = Image.new("RGBA", (48, 48))
    t = f / 6
    vis = 1.0 if f < 4 else 1.0 - (f - 3) / 4
    if f < 2:
        star(img, 24, 24, 5 - f, AMBER, AMBER_HOT)
    for k, (angle, reach) in enumerate(rays):
        dist = 4 + 17 * reach * (1 - (1 - t) ** 2)
        x, y = 24 + math.cos(angle) * dist, 24 + math.sin(angle) * dist
        arm = 3 if (f + k) % 3 else 1
        star(img, round(x), round(y), arm, AMBER if k % 2 else AMBER_DEEP, AMBER_HOT, vis)
    frames.append(img)
specs["fx_sparkle"] = strip(frames, "fx_sparkle")

# 3) ink bloom — kanji restored. 8 frames, 56x56: a drop falls, blooms into an ink ring, a washi glint, fades
frames = []
for f in range(8):
    img = Image.new("RGBA", (56, 56))
    if f == 0:
        disc(img, 28, 14, 2, INK)
    elif f == 1:
        disc(img, 28, 24, 2.5, INK)
        put(img, 28, 21, INK_SOFT)
    else:
        t = (f - 2) / 5
        vis = 1.0 if f < 5 else 1.0 - (f - 4) / 4
        radius = 6 + 16 * (1 - (1 - t) ** 2)
        for a in range(0, 360, 4):
            wobble = 1.5 * math.sin(math.radians(a) * 5 + f)
            rr = radius + wobble
            x, y = 28 + math.cos(math.radians(a)) * rr, 30 + math.sin(math.radians(a)) * rr * 0.6
            put(img, x, y, INK, vis)
            put(img, x + 1, y, INK, vis)
            put(img, x, y + 1, INK_SOFT, vis * 0.8)
            # 고리 안쪽의 옅은 종이빛 — 되살아난 글자가 번지는 느낌
            ix, iy = 28 + math.cos(math.radians(a)) * (rr - 3), 30 + math.sin(math.radians(a)) * (rr - 3) * 0.6
            put(img, ix, iy, WASHI, vis * 0.5)
        if f < 6:
            disc(img, 28, 30, max(1.5, 4 - f * 0.6), INK, vis)
        if 3 <= f <= 6:
            star(img, 28, 30 - int(radius * 0.6) - 2, 2 if f % 2 else 3, WASHI, (255, 255, 255, 255), vis)
    frames.append(img)
specs["fx_ink"] = strip(frames, "fx_ink")

# 4) research motes — points settled. 6 frames, 32x40: cyan motes rise in a loose column and blink out
frames = []
motes = [(random.uniform(6, 26), random.uniform(0, 0.5), random.choice([1, 2])) for _ in range(9)]
for f in range(6):
    img = Image.new("RGBA", (32, 40))
    t = f / 5
    vis = 1.0 if f < 3 else 1.0 - (f - 2) / 4
    for k, (x, delay, size) in enumerate(motes):
        lt = max(0.0, t - delay) / (1 - delay)
        if lt <= 0:
            continue
        y = 36 - 30 * lt
        sway = math.sin(lt * 6 + k) * 1.5
        if size == 2:
            star(img, round(x + sway), round(y), 1, CYAN, CYAN_HOT, vis)
        else:
            put(img, x + sway, y, CYAN_HOT if (f + k) % 2 else CYAN, vis)
    frames.append(img)
specs["fx_motes"] = strip(frames, "fx_motes")

# 5) ceiling leak drip — ambient loop over the bucket. 10 frames, 16x48: drop forms, falls, splashes
frames = []
for f in range(10):
    img = Image.new("RGBA", (16, 48))
    if f <= 2:      # drop swells at the ceiling
        disc(img, 8, 2, 0.8 + f * 0.5, WATER)
        put(img, 8, 1, WATER_HOT)
    elif f <= 6:    # falls, accelerating
        y = 4 + (f - 2) ** 2 * 2.6
        put(img, 8, y - 2, WATER, 0.6)
        disc(img, 8, y, 1.2, WATER)
        put(img, 7, y - 1, WATER_HOT)
    elif f <= 8:    # splash at the rim
        spread = (f - 6) * 2
        for dx in (-spread - 1, -spread, spread, spread + 1):
            put(img, 8 + dx, 44 - (f - 6), WATER)
        put(img, 8, 45, WATER_HOT)
    frames.append(img)  # frame 9: empty pause
specs["fx_drip"] = strip(frames, "fx_drip")

# menu icon — a small two-drawer filing cabinet with a brass handle, 16 and 24 px, institute palette
def cabinet(size):
    img = Image.new("RGBA", (size, size))
    s = size / 24
    body = (126, 140, 140, 255)
    light = (162, 176, 172, 255)
    shade = (92, 104, 108, 255)
    x0, x1, y0, y1 = round(4 * s), round(19 * s), round(2 * s), round(21 * s)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = x in (x0, x1) or y in (y0, y1)
            img.putpixel((x, y), OUTLINE if edge else (light if x < x0 + 2 else body))
    mid = (y0 + y1) // 2
    for x in range(x0, x1 + 1):
        img.putpixel((x, mid), OUTLINE)
    for top, bottom in ((y0, mid), (mid, y1)):
        hy = (top + bottom) // 2
        for x in range(round(9 * s), round(14 * s) + 1):
            img.putpixel((x, hy), AMBER_DEEP)
        img.putpixel((round(9 * s), hy - 1), AMBER)
        for x in range(x0 + 1, x1):
            img.putpixel((x, bottom - 1), shade)
    # a paper tab sticking out of the top drawer (the archive is full)
    for y in range(y0 - 1, y0 + 2):
        for x in range(round(13 * s), round(16 * s) + 1):
            if 0 <= y < size:
                img.putpixel((x, y), WASHI if y < y0 + 1 else OUTLINE)
    # feet
    for x in (x0 + 1, x1 - 1):
        if y1 + 1 < size:
            img.putpixel((x, y1 + 1), OUTLINE)
    return img


for size in (16, 24):
    cabinet(size).save(out / f"icon_menu_{size}.png")
big = cabinet(24).resize((144, 144), Image.NEAREST)
bg = Image.new("RGBA", big.size, (58, 64, 78, 255)); bg.alpha_composite(big)
bg.save(out / "preview_icon_menu_x6.png")

for name, (count, w, h) in specs.items():
    print(f"{name}: {count} frames of {w}x{h}")
