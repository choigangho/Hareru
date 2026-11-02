"""Interior icon: a paint roller with a fresh teal stripe (16 and 24 px). usage: icon_interior.py <out_dir>"""
import sys
from pathlib import Path
from PIL import Image

out = Path(sys.argv[1])
O, ROLL, ROLL_L, HANDLE, GRIP, PAINT = (24, 26, 40, 255), (226, 220, 200, 255), (246, 242, 228, 255), (150, 160, 160, 255), (214, 140, 52, 255), (110, 138, 136, 255)

def icon(size):
    s = size / 24
    img = Image.new("RGBA", (size, size))
    px = img.load()
    def box(x0, y0, x1, y1, c):
        for y in range(round(y0 * s), round(y1 * s) + 1):
            for x in range(round(x0 * s), round(x1 * s) + 1):
                if 0 <= x < size and 0 <= y < size:
                    px[x, y] = c
    box(2, 15, 21, 19, PAINT)          # fresh paint stripe
    box(4, 3, 19, 9, O)                # roller
    box(5, 4, 18, 8, ROLL)
    box(5, 4, 18, 5, ROLL_L)
    box(19, 6, 21, 6, O)               # arm
    box(21, 6, 21, 13, O)
    box(12, 12, 21, 12, O)
    box(12, 12, 12, 16, O)
    box(11, 16, 13, 22, GRIP)          # grip
    box(11, 16, 11, 22, O)
    box(13, 16, 13, 22, O)
    box(11, 22, 13, 22, O)
    return img

for size in (16, 24):
    icon(size).save(out / f"icon_interior_{size}.png")
