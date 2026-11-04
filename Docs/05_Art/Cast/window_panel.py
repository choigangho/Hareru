"""Cut a see-through window into the plain right-wall panel.

usage: window_panel.py <tile_wall_right.png> <out.png> <preview.png>
The glass is fully transparent so the weather sky behind the room shows through; only a faint
diagonal glint is painted on it. Frame, cross bars and sill use the panel's own palette.
Panel space: x along the wall (0..63); a wall-face row v sits at y = top(x) + v, top(x) = 2 + x/2.
"""
import sys

import numpy as np
from PIL import Image

src, dst, preview = sys.argv[1:4]
a = np.array(Image.open(src).convert("RGBA"))

OUTLINE = (5, 0, 5, 255)
FRAME = (122, 142, 137, 255)
FRAME_LIGHT = (160, 178, 170, 255)
FRAME_SHADE = (78, 93, 102, 255)
GLINT = (255, 255, 255, 80)

X0, X1 = 13, 51          # opening, inclusive (frame included)
V0, V1 = 9, 45           # top/bottom of the frame on the wall face
MID_X = (X0 + X1) // 2
MID_V = (V0 + V1) // 2


def y(x, v):
    return int(2 + x // 2 + v)


def put(x, v, c):
    yy = y(x, v)
    if 0 <= yy < a.shape[0] and 0 <= x < a.shape[1]:
        a[yy, x] = c


for x in range(X0, X1 + 1):
    for v in range(V0, V1 + 1):
        edge = x in (X0, X1) or v in (V0, V1)
        lit = x in (X0 + 1, X0 + 2) or v in (V0 + 1, V0 + 2)          # top-left of the frame catches light
        shaded = x in (X1 - 1, X1 - 2) or v in (V1 - 1, V1 - 2)
        cross = x in (MID_X, MID_X + 1) or v in (MID_V, MID_V + 1)
        if edge:
            put(x, v, OUTLINE)
        elif lit:
            put(x, v, FRAME)
        elif shaded:
            put(x, v, FRAME_SHADE)
        elif cross:
            put(x, v, FRAME_SHADE if (x == MID_X + 1 or v == MID_V + 1) else FRAME)
        else:
            put(x, v, (0, 0, 0, 0))   # glass: see-through

# sill: a 2px ledge under the frame
for x in range(X0 - 1, X1 + 2):
    put(x, V1 + 1, FRAME)
    put(x, V1 + 2, FRAME_SHADE)
    put(x, V1 + 3, OUTLINE)

# glint: two short steep streaks per pane (upper-left panes get the long one)
panes = [(X0 + 3, MID_X - 1, V0 + 3, MID_V - 1), (MID_X + 2, X1 - 3, V0 + 3, MID_V - 1),
         (X0 + 3, MID_X - 1, MID_V + 2, V1 - 3), (MID_X + 2, X1 - 3, MID_V + 2, V1 - 3)]
for i, (px0, px1, pv0, pv1) in enumerate(panes):
    length = 9 if i in (0, 2) else 5
    for k in range(length):
        for offset in (0, 4):
            x = px0 + 3 + offset + k // 2
            v = pv1 - 3 - k
            if px0 <= x <= px1 and pv0 <= v <= pv1 and (offset == 0 or k < length - 3):
                put(x, v, GLINT)

Image.fromarray(a).save(dst)
big = Image.fromarray(a).resize((64 * 6, 112 * 6), Image.NEAREST)
bg = Image.new("RGBA", big.size, (120, 170, 220, 255))   # stand-in sky to check transparency
bg.alpha_composite(big)
bg.save(preview)
