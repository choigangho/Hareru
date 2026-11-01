"""Clean magenta fringe and draw the chief researcher's glasses. usage: touchup.py <sprites_dir> <out_dir>"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
OUTLINE = (9, 13, 37, 255)
FRAME_DARK = (24, 26, 40, 255)
LENS = (196, 222, 236, 255)

def clean(a):
    rgb = a[..., :3].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    purple = (a[..., 3] > 0) & (r > g + 15) & (b > g + 25) & (b > r)
    opaque = a[..., 3] > 0
    pad = np.pad(opaque, 1)
    edge = ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    a[purple & edge] = 0
    a[purple & ~edge] = OUTLINE
    return a

def glasses(a):
    rgb = a[..., :3].astype(int)
    skin = (a[..., 3] > 0) & (rgb[..., 0] > 200) & (rgb[..., 1] > 180) & (rgb[..., 2] > 150) & (rgb[..., 0] - rgb[..., 2] > 35)
    rows = [y for y in range(a.shape[0]) if skin[y].sum() >= 4]
    if not rows:
        return a
    y = rows[0] + 1
    xs = np.nonzero(skin[y] | skin[y - 1])[0]
    x0, x1 = xs.min(), xs.max()
    # near lens (right side, facing SE) bigger: [dark, lens, lens, dark] + bridge + [lens, dark]
    pattern = [FRAME_DARK, LENS, FRAME_DARK, FRAME_DARK, LENS, LENS, FRAME_DARK]
    start = max(x0 - 1, x1 - len(pattern) + 2)
    for i, c in enumerate(pattern):
        x = start + i
        if 0 <= x < a.shape[1] and a[y, x, 3] > 0:
            a[y, x] = c
    return a

for f in sorted(src.glob("*.png")):
    if f.name.endswith("_strip.png"):
        continue
    a = clean(np.array(Image.open(f).convert("RGBA")))
    if f.name.startswith("chief_researcher") and "_nw" not in f.name:
        a = glasses(a)
    Image.fromarray(a).save(out / f.name)

for name in ["chief_researcher", "newcomer"]:
    frames = [Image.open(out / f"{name}_{p}.png") for p in ["idle_se", "walk_se_a", "walk_se_b", "idle_nw"]]
    strip = Image.new("RGBA", (48 * 4, 48))
    for i, fr in enumerate(frames):
        strip.alpha_composite(fr, (48 * i, 0))
    strip.save(out / f"{name}_strip.png")
    big = strip.resize((strip.width * 6, strip.height * 6), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (196, 160, 122, 255)); bg.alpha_composite(big)
    bg.save(out / f"preview_{name}_x6.png")
