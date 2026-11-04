"""Key out magenta, cut sprite cells, and downsample to a true pixel grid.

usage: pixelize.py <sheet.png> <concept.png> <out_dir>
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sheet_path, concept_path, out_dir = map(Path, sys.argv[1:4])
out_dir.mkdir(parents=True, exist_ok=True)

FRAME = 48          # source pixel grid is ~8px per art pixel -> ~48px-tall characters
PORTRAIT = 64       # §9.1: dialogue portrait 64x64
COLORS = 20


def key_magenta(img: Image.Image) -> np.ndarray:
    a = np.asarray(img.convert("RGB")).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    bg = (r > 150) & (b > 150) & (g < 130) & (np.abs(r - b) < 90)
    # anti-aliased fringe: anything still clearly magenta-tinted
    bg |= (r - g > 55) & (b - g > 55) & (np.abs(r - b) < 80)
    rgba = np.dstack([a, np.where(bg, 0, 255)]).astype(np.uint8)
    return rgba


def bbox(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def largest_component(rgba: np.ndarray) -> np.ndarray:
    """Drop stray fragments that bleed in from neighbouring cells."""
    from collections import deque
    mask = rgba[..., 3] > 0
    labels = np.zeros(mask.shape, np.int32)
    best, best_n, n = 0, 0, 0
    for y, x in zip(*np.nonzero(mask)):
        if labels[y, x]:
            continue
        n += 1
        labels[y, x] = n
        q, size = deque([(y, x)]), 0
        while q:
            cy, cx = q.popleft()
            size += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n
                    q.append((ny, nx))
        if size > best_n:
            best, best_n = n, size
    out = rgba.copy()
    out[labels != best, 3] = 0
    return out


def downsample(rgba: np.ndarray, scale: float) -> Image.Image:
    """Block-mode downsample: each target pixel takes the most common opaque colour."""
    h, w = rgba.shape[:2]
    tw, th = max(1, round(w * scale)), max(1, round(h * scale))
    out = np.zeros((th, tw, 4), np.uint8)
    for ty in range(th):
        y0, y1 = int(ty / scale), max(int(ty / scale) + 1, int((ty + 1) / scale))
        for tx in range(tw):
            x0, x1 = int(tx / scale), max(int(tx / scale) + 1, int((tx + 1) / scale))
            block = rgba[y0:y1, x0:x1].reshape(-1, 4)
            opaque = block[block[:, 3] > 0]
            if len(opaque) < len(block) * 0.45:
                continue
            q = (opaque[:, :3] // 12).astype(np.int32)
            keys = q[:, 0] * 10000 + q[:, 1] * 100 + q[:, 2]
            vals, counts = np.unique(keys, return_counts=True)
            pick = opaque[keys == vals[counts.argmax()]][:, :3].mean(0)
            out[ty, tx] = [*pick.astype(np.uint8), 255]
    return Image.fromarray(out)


def quantize(img: Image.Image, colors=COLORS) -> Image.Image:
    alpha = img.getchannel("A")
    q = img.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    q.putalpha(alpha)
    return q


def preview(img: Image.Image, k: int, bg=(46, 52, 58)) -> Image.Image:
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    canvas = Image.new("RGBA", big.size, (*bg, 255))
    canvas.alpha_composite(big)
    return canvas


# --- sprite sheet: 2 rows (researcher, newcomer) x 4 poses ---
sheet = key_magenta(Image.open(sheet_path))
H, W = sheet.shape[:2]
names = ["chief_researcher", "newcomer"]
poses = ["idle_se", "walk_se_a", "walk_se_b", "idle_nw"]
cells = {}
for row in range(2):
    for col in range(4):
        cell = sheet[row * H // 2:(row + 1) * H // 2, col * W // 4:(col + 1) * W // 4]
        cell = largest_component(cell)
        x0, y0, x1, y1 = bbox(cell[..., 3])
        cells[(row, col)] = cell[y0:y1, x0:x1]

tallest = max(c.shape[0] for c in cells.values())
scale = (FRAME - 1) / tallest
for row, name in enumerate(names):
    frames = []
    for col, pose in enumerate(poses):
        spr = quantize(downsample(cells[(row, col)], scale))
        frame = Image.new("RGBA", (FRAME, FRAME))
        frame.alpha_composite(spr, ((FRAME - spr.width) // 2, FRAME - spr.height))
        frame.save(out_dir / f"{name}_{pose}.png")
        frames.append(frame)
    strip = Image.new("RGBA", (FRAME * len(frames), FRAME))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * FRAME, 0))
    strip.save(out_dir / f"{name}_strip.png")
    preview(strip, 6).save(out_dir / f"preview_{name}_strip_x6.png")

# --- portraits from the concept art: head + shoulders of each half ---
concept = key_magenta(Image.open(concept_path))
CH, CW = concept.shape[:2]
for i, name in enumerate(names):
    half = concept[:, i * CW // 2:(i + 1) * CW // 2]
    x0, y0, x1, y1 = bbox(half[..., 3])
    side = int((x1 - x0) * 0.78)
    cx = (x0 + x1) // 2 + (-20 if i == 0 else 10)
    crop = half[y0:y0 + side, max(0, cx - side // 2):cx + side // 2]
    port = quantize(downsample(crop, PORTRAIT / crop.shape[0]), 32)
    framed = Image.new("RGBA", (PORTRAIT, PORTRAIT))
    framed.alpha_composite(port, ((PORTRAIT - port.width) // 2, 0))
    framed.save(out_dir / f"{name}_portrait.png")
    preview(framed, 4).save(out_dir / f"preview_{name}_portrait_x4.png")

print("scale", round(scale, 4), "tallest", tallest)
