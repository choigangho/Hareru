"""Cut environment sheets into pixel assets.

usage: env_pixelize.py <facilities.png> <env_props.png> <out_dir>
Objects are found as merged connected components on the magenta-keyed mask, ordered
left->right, top->bottom, and downsampled so their width matches the 2x tile (64 px).
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

fac_path, env_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)
TILE2X = 64  # one floor tile is 32 room px; assets are drawn at 2x (= character density)


def key(img):
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (r > 150) & (b > 150) & (g < 130) & (np.abs(r - b) < 90)
    bg |= (r - g > 55) & (b - g > 55) & (np.abs(r - b) < 80)
    return np.dstack([a, np.where(bg, 0, 255)]).astype(np.uint8)


def components(mask, step=4, gap=6):
    """Coarse labeling on a grid of step px; components closer than gap cells are merged."""
    h, w = mask.shape
    coarse = mask[: h // step * step, : w // step * step].reshape(h // step, step, w // step, step).any(axis=(1, 3))
    # dilate to merge nearby parts (LEDs, droplets)
    pad = np.pad(coarse, gap)
    grown = np.zeros_like(coarse)
    for dy in range(-gap, gap + 1):
        for dx in range(-gap, gap + 1):
            grown |= pad[gap + dy: gap + dy + coarse.shape[0], gap + dx: gap + dx + coarse.shape[1]]
    labels = np.zeros(coarse.shape, np.int32)
    boxes = []
    for y, x in zip(*np.nonzero(grown)):
        if labels[y, x]:
            continue
        n = len(boxes) + 1
        labels[y, x] = n
        q = deque([(y, x)])
        ys, xs = [y], [x]
        while q:
            cy, cx = q.popleft()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < grown.shape[0] and 0 <= nx < grown.shape[1] and grown[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n
                    q.append((ny, nx))
                    ys.append(ny); xs.append(nx)
        boxes.append((min(xs) * step, min(ys) * step, (max(xs) + 1) * step, (max(ys) + 1) * step))
    return [b for b in boxes if (b[2] - b[0]) * (b[3] - b[1]) > 4000]


def crop_tight(rgba, box):
    x0, y0, x1, y1 = box
    c = rgba[y0:y1, x0:x1].copy()
    ys, xs = np.nonzero(c[..., 3])
    return c[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]


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
            if len(opaque) < len(block) * 0.45:
                continue
            q = (opaque[:, :3] // 12).astype(np.int32)
            keys = q[:, 0] * 10000 + q[:, 1] * 100 + q[:, 2]
            vals, counts = np.unique(keys, return_counts=True)
            res[ty, tx] = [*opaque[keys == vals[counts.argmax()]][:, :3].mean(0).astype(np.uint8), 255]
    return res


def quantize(arr, colors=24):
    img = Image.fromarray(arr)
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    q.putalpha(alpha)
    return q


MAX_H2X = 72  # tallest facility = 36 room px (1.5x a character), so the 40px wall still reads as a room


def fit_width(rgba, width=TILE2X):
    h, w = rgba.shape[:2]
    scale = min(width / w, MAX_H2X / h)
    return quantize(downsample(rgba, max(1, round(w * scale)), max(1, round(h * scale))))


def order(boxes):
    rows = sorted(boxes, key=lambda b: b[1])
    return sorted(boxes, key=lambda b: (0 if (b[1] + b[3]) / 2 < 384 else 1, b[0]))


# --- facilities sheet ---
fac = key(Image.open(fac_path))
boxes = components(fac[..., 3] > 0, gap=2)
centers = {b: ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2) for b in boxes}


def nearest(x, y):
    return min(boxes, key=lambda b: (centers[b][0] - x) ** 2 + (centers[b][1] - y) ** 2)


picks = {
    "researcher_desk": nearest(255, 200),
    "kanji_archive": nearest(605, 205),
    "spare_book_table": nearest(205, 560),
    "copy_room": nearest(555, 535),
    "recording_booth": nearest(910, 455),
    "server_rack": nearest(1220, 200),
    "spare_server_rack": nearest(1220, 570),
}
for name, box in picks.items():
    fit_width(crop_tight(fac, box)).save(out / f"facility_{name}.png")

# --- textures + props sheet ---
env = key(Image.open(env_path))
H, W = env.shape[:2]
floor = env[40:420, 45:655]
wall = env[40:420, 720:1330]
Image.fromarray(downsample(floor, 76, 48)).convert("RGB").quantize(16).convert("RGB").save(out / "texture_floor.png")
Image.fromarray(downsample(wall, 76, 48)).convert("RGB").quantize(16).convert("RGB").save(out / "texture_wall.png")

props = env[440:]
pboxes = components(props[..., 3] > 0)
pboxes = sorted(pboxes, key=lambda b: b[0])
names = ["plant", "boxes", "bucket", "cables", "vending_machine"]
for name, box in zip(names, pboxes):
    width = {"plant": 36, "boxes": 52, "bucket": 36, "cables": 44, "vending_machine": 44}[name]
    c = crop_tight(props, box)
    arr = downsample(c, width, max(1, round(c.shape[0] * width / c.shape[1])))
    if name == "vending_machine":
        # remove the brand-like logo on the side panel: saturated red/blue -> side panel grey
        rgb = arr[..., :3].astype(int)
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        sat = rgb.max(-1) - rgb.min(-1)
        cyan = (g > 150) & (b > 150) & (r < 140)
        logo = (arr[..., 3] > 0) & (sat > 28) & ~cyan
        logo[:, : int(arr.shape[1] * 0.62)] = False  # only the side panel; front glass and screen stay
        grey = rgb[(arr[..., 3] > 0) & (np.abs(r - g) < 15) & (np.abs(g - b) < 15) & (r > 110)]
        fill = grey.mean(0).astype(np.uint8) if len(grey) else np.array([140, 150, 150], np.uint8)
        arr[logo] = [*fill, 255]
    quantize(arr).save(out / f"prop_{name}.png")

# previews
for f in sorted(out.glob("*.png")):
    if f.name.startswith("preview"):
        continue
    im = Image.open(f).convert("RGBA")
    big = im.resize((im.width * 5, im.height * 5), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (60, 64, 72, 255)); bg.alpha_composite(big)
    bg.save(out / f"preview_{f.stem}_x5.png")
print("facility boxes", len(boxes), "prop boxes", len(pboxes))
