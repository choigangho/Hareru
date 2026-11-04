"""Cut the 3x3 icon sheet into 16px and 24px pixel icons, plus facility icons from facility sprites.

usage: ui_icons.py <icons_sheet.png> <facility_sprites_dir> <out_dir>
Generated labels under some icons are cut off by limiting each row's crop height.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sheet_path, fac_dir, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)

NAMES = [["research_points", "influence", "restored"],
         ["budget", "build", "restore"],
         ["status", "combo", "locked"]]
# rows 2 and 3 have generated text labels below the icon: stop the crop above them
ROW_BOTTOM = [341, 622, 935]
ROW_TOP = [0, 360, 695]   # row 3 starts below row 2's labels


def key(img):
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (r > 150) & (b > 150) & (g < 130) & (np.abs(r - b) < 90)
    bg |= (r - g > 55) & (b - g > 55) & (np.abs(r - b) < 80)
    return np.dstack([a, np.where(bg, 0, 255)]).astype(np.uint8)


def tight(rgba):
    ys, xs = np.nonzero(rgba[..., 3])
    return rgba[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]


def downsample(rgba, tw, th):
    h, w = rgba.shape[:2]
    sy, sx = h / th, w / tw
    res = np.zeros((th, tw, 4), np.uint8)
    for ty in range(th):
        y0, y1 = int(ty * sy), max(int(ty * sy) + 1, int((ty + 1) * sy))
        for tx in range(tw):
            x0, x1 = int(tx * sx), max(int(tx * sx) + 1, int((tx + 1) * sx))
            block = rgba[y0:y1, x0:x1].reshape(-1, 4)
            opaque = block[block[:, 3] > 0]
            if len(opaque) < len(block) * 0.4:
                continue
            q = (opaque[:, :3] // 12).astype(np.int32)
            keys = q[:, 0] * 10000 + q[:, 1] * 100 + q[:, 2]
            vals, counts = np.unique(keys, return_counts=True)
            res[ty, tx] = [*opaque[keys == vals[counts.argmax()]][:, :3].mean(0).astype(np.uint8), 255]
    return res


def to_square(rgba, size, colors=16):
    h, w = rgba.shape[:2]
    s = (size - 1) / max(h, w)   # 1px breathing room
    arr = downsample(rgba, max(1, round(w * s)), max(1, round(h * s)))
    img = Image.fromarray(arr)
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    q.putalpha(alpha)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(q, ((size - q.width) // 2, (size - q.height) // 2))
    return canvas


sheet = key(Image.open(sheet_path))
H, W = sheet.shape[:2]
icons = {}
for r, row in enumerate(NAMES):
    top = ROW_TOP[r]
    for c, name in enumerate(row):
        cell = sheet[top:ROW_BOTTOM[r], c * W // 3:(c + 1) * W // 3]
        icons[name] = tight(cell)

for fac in ["researcher_desk", "kanji_archive", "copy_room", "recording_booth", "server_rack"]:
    icons[f"facility_{fac}"] = tight(np.array(Image.open(fac_dir / f"facility_{fac}.png").convert("RGBA")))

for name, rgba in icons.items():
    for size in (16, 24):
        to_square(rgba, size).save(out / f"icon_{name}_{size}.png")

# preview: all 24px icons at x6 on a glass-like dark tint
names = list(icons)
tile = 24 * 6 + 12
board = Image.new("RGBA", (tile * 5, tile * ((len(names) + 4) // 5)), (54, 62, 78, 255))
for i, name in enumerate(names):
    im = Image.open(out / f"icon_{name}_24.png").resize((144, 144), Image.NEAREST)
    board.alpha_composite(im, ((i % 5) * tile + 6, (i // 5) * tile + 6))
board.save(out / "preview_icons_24_x6.png")
print(len(names), "icons")
