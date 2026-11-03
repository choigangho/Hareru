"""1막 P1 직접 제작분 전체 미리보기 한 장. usage: n5_p1_sheet.py <props_dir> <story_ui_dir> <njl_os_dir> <out.png>

소품(원본 x3) · 스토리 UI(원본 x3) · 9-slice를 실제처럼 늘려 조립한 예시 화면(x3)을 한 장에.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PROPS, STORY, OS_DIR, OUT = (Path(p) for p in sys.argv[1:5])
S = 3
BG, PANEL = (24, 27, 38, 255), (52, 58, 76, 255)


def load(d, n):
    return Image.open(d / f"{n}.png").convert("RGBA")


def nine(img, cap, w, h):
    t, l, b, r = cap if isinstance(cap, (list, tuple)) else (cap,) * 4
    sw, sh = img.size
    out = Image.new("RGBA", (w, h))
    for sx0, sx1, dx0, dx1 in ((0, l, 0, l), (l, sw - r, l, w - r), (sw - r, sw, w - r, w)):
        for sy0, sy1, dy0, dy1 in ((0, t, 0, t), (t, sh - b, t, h - b), (sh - b, sh, h - b, h)):
            piece = img.crop((sx0, sy0, sx1, sy1))
            pw, ph = piece.size
            if not pw or not ph:
                continue
            for y in range(dy0, dy1, ph):
                for x in range(dx0, dx1, pw):
                    out.alpha_composite(piece.crop((0, 0, min(pw, dx1 - x), min(ph, dy1 - y))), (x, y))
    return out


def gallery(d, names, width):
    """이름 붙은 원본 갤러리 (x S)."""
    x = y = 8
    rowh, placed = 0, []
    for n in names:
        im = load(d, n)
        w, h = im.width * S, im.height * S
        cell_w = max(w, len(n) * 6 + 4)
        if x + cell_w > width - 8:
            x, y, rowh = 8, y + rowh + 22, 0
        placed.append((im, x, y, n))
        x += cell_w + 14
        rowh = max(rowh, h)
    sheet = Image.new("RGBA", (width, y + rowh + 26), PANEL)
    draw = ImageDraw.Draw(sheet)
    for im, x, y, n in placed:
        sheet.alpha_composite(im.resize((im.width * S, im.height * S), Image.NEAREST), (x, y))
        draw.text((x, y + im.height * S + 4), n, fill=(200, 204, 214, 255))
    return sheet


prop_names = sorted(p.stem for p in PROPS.glob("*.png"))
story_names = sorted(p.stem for p in STORY.glob("*.png"))
WIDTH = 1180

# ── 조립 예시 (1x로 만든 뒤 S배) ─────────────────────────────────
mock = Image.new("RGBA", (380, 236), (12, 14, 22, 255))
# 대사창: 초상 틀 + 본문 + 이름 탭 + ▼
mock.alpha_composite(nine(load(STORY, "njl_dialog_box"), 8, 300, 64), (70, 160))
pb = load(STORY, "njl_dialog_portrait_bg")
mock.alpha_composite(pb, (12, 142))
mock.alpha_composite(load(STORY, "njl_dialog_portrait_frame"), (6, 136))
mock.alpha_composite(nine(load(STORY, "njl_dialog_name_tab"), 5, 52, 12), (90, 154))
mock.alpha_composite(load(STORY, "njl_dialog_next").crop((0, 0, 8, 6)), (354, 214))
# 퀘스트 카드 + 보상 줄 + 아이콘
mock.alpha_composite(nine(load(STORY, "njl_quest_card"), [16, 8, 10, 8], 150, 64), (8, 8))
mock.alpha_composite(load(STORY, "njl_quest_icon_16"), (14, 26))
mock.alpha_composite(nine(load(STORY, "njl_quest_reward_row"), 5, 120, 12), (22, 54))
# 경고창 + 스크롤 줄 + 아이콘
mock.alpha_composite(nine(load(STORY, "njl_warning_frame"), 8, 200, 80), (170, 8))
mock.alpha_composite(load(STORY, "njl_warning_icon_24"), (182, 22))
mock.alpha_composite(nine(load(STORY, "njl_warning_ticker"), 4, 184, 10), (178, 72))
# 부팅 화면
boot = Image.new("RGBA", (150, 60), (8, 10, 16, 255))
logo = load(STORY, "njl_boot_logo")
boot.alpha_composite(logo, ((150 - logo.width) // 2, 8))
boot.alpha_composite(nine(load(STORY, "njl_boot_bar_track"), 4, 110, 8), (20, 32))
boot.alpha_composite(nine(load(STORY, "njl_boot_bar_fill"), 4, 64, 8), (20, 32))
boot.alpha_composite(load(STORY, "njl_boot_loader").crop((48, 0, 72, 8)), (63, 46))
mock.alpha_composite(boot, (8, 78))
# 탭 강조: 공통 부품의 탭 아이콘 위에 링 + 화살표
tabbar = nine(load(OS_DIR, "njl_frame_panel_dark"), 8, 190, 52) if (OS_DIR / "njl_frame_panel_dark.png").exists() else Image.new("RGBA", (190, 52), (30, 36, 52, 255))
for i, key in enumerate(("terminal", "institute", "records", "settings")):
    state = "selected" if i == 0 else "normal"
    p = OS_DIR / f"njl_tab_{key}_{state}.png"
    if p.exists():
        tabbar.alpha_composite(Image.open(p).convert("RGBA"), (14 + i * 44, 18))
tabbar.alpha_composite(load(STORY, "njl_tab_ring").crop((0, 0, 40, 40)), (6, 10))
mock.alpha_composite(tabbar, (172, 96))
mock.alpha_composite(load(STORY, "njl_tab_pointer").crop((0, 0, 10, 10)), (193, 95))
mock = mock.resize((mock.width * S, mock.height * S), Image.NEAREST)

sections = [("Act 1 (N5) P1 props (Docs/Art/Environment/source/n5_props) x3", gallery(PROPS, prop_names, WIDTH)),
            ("story UI (Docs/Art/UI/source/njl_story) x3", gallery(STORY, story_names, WIDTH)),
            ("assembled mock: quest card / warning / boot / tab highlight / dialog (9-slice stretched) x3", mock)]
H = sum(s.height + 30 for _, s in sections) + 10
sheet = Image.new("RGBA", (WIDTH + 20, H), BG)
draw = ImageDraw.Draw(sheet)
y = 8
for title, part in sections:
    draw.text((12, y + 4), title, fill=(236, 238, 242, 255))
    y += 22
    sheet.alpha_composite(part, (10, y))
    y += part.height + 8
sheet.save(OUT)
print(sheet.size)
