"""Cut the owner-supplied v2 sheets (flat beige background) into pixel assets.

usage: cast_env_v2.py <images_dir> <out_dir>
- Background: flood fill from the image border with a colour tolerance, so beige-ish colours
  inside objects (wood, paper) are kept.
- Characters: 4 equal columns (idle SE, walk A, walk B, back NW), one shared scale so relative
  heights between cast members survive; tallest frame = 47 px in a 48x48 frame (same as the leads).
- Environment: objects found as connected components left->right, downsampled at the sheet's
  native pixel size (~2.7 px) and capped to the facility box (64 wide, 72 tall).
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

CHARACTERS = {2: "ai_kuro", 3: "master_gen", 4: "citizen_mio", 6: "elder_tsuru", 7: "craftsman_jin",
              8: "rival_reina", 9: "inspector_ren", 10: "announcer_ai"}   # 5 = duplicate of 4, courier_rin missing
POSES = ["idle_se", "walk_se_a", "walk_se_b", "idle_nw"]
ENV = {
    11: ["facility_researcher_desk", "facility_kanji_archive", "facility_copy_room", "facility_recording_booth", "facility_server_rack"],
    12: ["prop_plant", "prop_bucket", "prop_vending_machine", "prop_cables", "prop_boxes"],
    13: ["tile_floor_light", "tile_floor_dark", "tile_wall_left", "tile_wall_right", "tile_window_rain", "tile_window_clear"],
    14: ["expansion_tea_table", "expansion_module_dock", "expansion_microfilm_scanner", "expansion_sign_workbench"],
    15: ["module_onyomi_ai", "module_kunyomi_terminal", "module_radical_robot", "module_etymology_drone"],
    16: ["sign_bookstore", "sign_street_lamp", "sign_cafe", "sign_building"],
}
ENV_PIXEL = 2.7
# room tiles must land on the iso grid exactly: floor tile = 64x32 diamond + 6px edge;
# wall/window panels span two tiles (64 wide, 32 px slant) with an 80 px (= 40 room px) wall face
EXACT = {"tile_floor_light": (64, 38), "tile_floor_dark": (64, 38),
         "tile_wall_left": (64, 112), "tile_wall_right": (64, 112),
         "tile_window_rain": (64, 112), "tile_window_clear": (64, 112)}
# props stay below ~1.3x a character (characters are 48 tall at this density)
PROP_MAX_H = {"prop_plant": 48, "prop_bucket": 36, "prop_vending_machine": 64, "prop_cables": 26, "prop_boxes": 52}


def key_border(rgb, tol=26):
    h, w = rgb.shape[:2]
    a = rgb.astype(int)
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        q.extend([(0, x), (h - 1, x)])
    for y in range(h):
        q.extend([(y, 0), (y, w - 1)])
    ref = np.median(np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]]), axis=0)
    while q:
        y, x = q.popleft()
        if bg[y, x] or np.abs(a[y, x] - ref).max() > tol:
            continue
        bg[y, x] = True
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                q.append((ny, nx))
    return np.dstack([rgb, np.where(bg, 0, 255)]).astype(np.uint8)


def column_boxes(alpha, min_gap=6, min_width=12):
    """Split along x where whole columns are empty (objects sit side by side)."""
    filled = alpha.any(axis=0)
    boxes, x, w = [], 0, len(filled)
    while x < w:
        if not filled[x]:
            x += 1
            continue
        start = x
        empty = 0
        while x < w and (filled[x] or empty < min_gap):
            empty = 0 if filled[x] else empty + 1
            x += 1
        end = x - empty
        if end - start >= min_width:
            ys = np.nonzero(alpha[:, start:end].any(axis=1))[0]
            boxes.append((start, ys.min(), end, ys.max() + 1))
    return boxes


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


def preview(img, k, name):
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (58, 64, 78, 255))
    bg.alpha_composite(big)
    bg.save(out / f"preview_{name}_x{k}.png")


# --- characters: shared scale ---
crops = {}
for n, vid in CHARACTERS.items():
    rgba = key_border(np.asarray(Image.open(src / f"{n}.png").convert("RGB")))
    W = rgba.shape[1]
    for i, pose in enumerate(POSES):
        cell = rgba[:, i * W // 4:(i + 1) * W // 4]
        ys, xs = np.nonzero(cell[..., 3])
        crops[(vid, pose)] = cell[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]
scale = 47 / max(c.shape[0] for c in crops.values())
for vid in CHARACTERS.values():
    strip = Image.new("RGBA", (48 * 4, 48))
    for i, pose in enumerate(POSES):
        c = crops[(vid, pose)]
        spr = quantize(downsample(c, max(1, round(c.shape[1] * scale)), max(1, round(c.shape[0] * scale))), 20)
        frame = Image.new("RGBA", (48, 48))
        frame.alpha_composite(spr, ((48 - spr.width) // 2, 48 - spr.height))
        frame.save(out / f"{vid}_{pose}.png")
        strip.alpha_composite(frame, (48 * i, 0))
    strip.save(out / f"{vid}_strip.png")
    preview(strip, 4, vid)
print("character scale", round(scale, 4), "px per art px", round(1 / scale, 2))

# --- environment ---
for n, names in ENV.items():
    rgba = key_border(np.asarray(Image.open(src / f"{n}.png").convert("RGB")))
    boxes = column_boxes(rgba[..., 3] > 0)
    if len(boxes) != len(names):
        print(f"sheet {n}: expected {len(names)} objects, found {len(boxes)}: {boxes}")
    row = []
    for name, (x0, y0, x1, y1) in zip(names, boxes):
        c = rgba[y0:y1, x0:x1]
        w, h = c.shape[1] / ENV_PIXEL, c.shape[0] / ENV_PIXEL
        if name.startswith(("facility_", "expansion_", "module_")):
            cap = min(1.0, 64 / w, 72 / h)
            w, h = w * cap, h * cap
        elif name in EXACT:
            w, h = EXACT[name]
        elif name in PROP_MAX_H:
            cap = min(1.0, PROP_MAX_H[name] / h)
            w, h = w * cap, h * cap
        img = quantize(downsample(c, max(1, round(w)), max(1, round(h))))
        img.save(out / f"{name}.png")
        row.append(img)
        print(f"{name}: {img.size}")
    sheet = Image.new("RGBA", (sum(i.width + 4 for i in row), max(i.height for i in row)))
    x = 0
    for i in row:
        sheet.alpha_composite(i, (x, sheet.height - i.height))
        x += i.width + 4
    preview(sheet, 4, f"sheet{n}")
