"""9-slice pixel UI frames for the institute screen. usage: ui_frames.py <out_dir> <preview.png>

Each frame is 12x12 px with 4 px corners (cap insets) and a 4x4 centre that tiles.
Palette: institute night navy with a cool rim, amber for the active state — readable on any sky.
  frame_panel  : drawers, menu panel, dialogue box, plates (notched corners, inner rim)
  frame_button : raised button (lit top-left, shaded bottom-right)
  frame_active : pressed/selected button (amber rim, sunk)
  frame_chip   : small inset chip (resource chips, status line)
"""
import sys
from pathlib import Path
from PIL import Image

out = Path(sys.argv[1])
O = (18, 20, 32, 255)
BODY = (38, 44, 62, 238)
BODY_BTN = (56, 64, 86, 245)
BODY_SUNK = (44, 40, 34, 245)
RIM = (98, 112, 136, 255)
LIT = (138, 152, 176, 255)
SHADE = (28, 32, 46, 255)
AMBER = (255, 206, 92, 255)
AMBER_D = (196, 132, 48, 255)
CHIP = (30, 34, 50, 225)
CHIP_RIM = (74, 84, 106, 255)


def frame(body, top_left, bottom_right, notch=True, inner=None):
    img = Image.new("RGBA", (12, 12))
    px = img.load()
    for y in range(12):
        for x in range(12):
            edge = x in (0, 11) or y in (0, 11)
            corner = (x in (0, 11)) and (y in (0, 11))
            if corner and notch:
                continue                       # notched pixel corners
            if edge:
                px[x, y] = O
            elif x == 1 or y == 1:
                px[x, y] = top_left
            elif x == 10 or y == 10:
                px[x, y] = bottom_right
            elif inner and (x == 2 or y == 2 or x == 9 or y == 9):
                px[x, y] = inner
            else:
                px[x, y] = body
    if notch:   # round the inner corner a touch
        for (x, y) in ((1, 1), (10, 1), (1, 10), (10, 10)):
            px[x, y] = O
    return img


frames = {
    "frame_panel": frame(BODY, RIM, SHADE, inner=(46, 54, 76, 238)),
    "frame_button": frame(BODY_BTN, LIT, SHADE),
    "frame_active": frame(BODY_SUNK, AMBER_D, AMBER),
    "frame_chip": frame(CHIP, CHIP_RIM, CHIP_RIM, notch=False),
}
for name, img in frames.items():
    img.save(out / f"{name}.png")

prev = Image.new("RGBA", (4 * 12 * 8 + 3 * 8, 12 * 8), (120, 160, 210, 255))
for i, img in enumerate(frames.values()):
    prev.alpha_composite(img.resize((96, 96), Image.NEAREST), (i * 104, 0))
prev.save(sys.argv[2])
