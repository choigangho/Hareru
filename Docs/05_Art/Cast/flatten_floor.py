"""Seamless flat plank texture in the colours of an isometric floor tile.

usage: flatten_floor.py <tile.png> <out.png>
Unprojecting the tile's diagonal plank lines breaks them into dots, so the planks are redrawn in
flat space instead: 32x32 texels, planks 4 texels wide running along u (= the grid's column axis),
staggered end joints, light grain dither and two knots. Colours come from the tile's top face.
The texture repeats every tile, so its edges are made to match (seams on multiples of 4).
"""
import sys

import numpy as np
from PIL import Image

src, dst = sys.argv[1:3]
tile = np.array(Image.open(src).convert("RGB")).astype(int)
face = tile[8:24, 20:44].reshape(-1, 3)                 # centre of the diamond
base = np.median(face, axis=0)
N, PLANK = 32, 4
rng = np.random.default_rng(3)


def shade(k):
    return np.clip(base * k, 0, 255)


out = np.zeros((N, N, 3))
for v in range(N):
    row = v // PLANK
    tone = 1.0 + (0.05 if row % 2 else -0.03) + rng.uniform(-0.02, 0.02)
    joint = (row * 11) % N                                 # staggered butt joint per plank row
    for u in range(N):
        k = tone
        if v % PLANK == PLANK - 1:
            k = 0.66                                       # seam between planks
        elif u == joint:
            k = 0.74                                       # end joint
        elif v % PLANK == 0:
            k = tone * 1.07                                # lit upper edge of a plank
        elif (u * 7 + v * 3) % 13 == 0:
            k = tone * 0.92                                # grain flecks
        out[v, u] = shade(k)
for kx, ky in ((9, 5), (25, 21)):                          # knots
    out[ky, kx] = shade(0.6)
    out[ky, kx + 1] = shade(0.75)
Image.fromarray(out.astype(np.uint8)).save(dst)
