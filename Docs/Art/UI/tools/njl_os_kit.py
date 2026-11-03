"""NJL-OS 픽셀 UI 키트 — 직접 그림 (생성 크레딧 0). usage: njl_os_kit.py <source_dir> <previews_dir>

UI_RESKIN_DRAFT §4 · PIXELLAB_ASSET_PLAN 팔레트(바랜 청록 · 슬레이트 · 남색 #141824 · 호박색 · 시안 #00F0FF).
기존 frame_*.png(ui_frames.py)과 같은 화풍: 1px 남색 외곽선 · 홈 파인 모서리 · 왼쪽 위 빛 / 오른쪽 아래 그늘.
9-slice 이미지는 모서리(cap) 안에만 장식을 넣고, 가장자리는 한 줄 단색, 가운데는 주기 2·4 무늬라 타일로 늘려도 이음새가 없음.
cap 값은 <source_dir>/njl_os_manifest.json 에 기록 (앱에서는 1px = 2pt).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SRC, PREV = Path(sys.argv[1]), Path(sys.argv[2])
SRC.mkdir(parents=True, exist_ok=True)
PREV.mkdir(parents=True, exist_ok=True)

# ── 팔레트 ───────────────────────────────────────────────
O = (20, 24, 36, 255)            # 남색 외곽선 #141824
NAVY = (30, 36, 52, 255)
NAVY_2 = (36, 42, 60, 255)
NAVY_DEEP = (16, 19, 30, 255)
SLATE_D = (44, 50, 68, 255)
SLATE = (56, 64, 86, 255)
SLATE_L = (98, 112, 136, 255)
SLATE_LL = (138, 152, 176, 255)
SHADE = (28, 32, 46, 255)
TEAL_D = (40, 70, 76, 255)
TEAL = (62, 104, 106, 255)
TEAL_L = (98, 148, 144, 255)
TEAL_LL = (146, 190, 180, 255)
PAPER = (232, 228, 214, 255)
PAPER_2 = (224, 220, 204, 255)
PAPER_L = (248, 245, 234, 255)
PAPER_D = (190, 186, 170, 255)
PAPER_DD = (150, 150, 142, 255)
AMBER = (255, 206, 92, 255)
AMBER_D = (196, 132, 48, 255)
CYAN = (0, 240, 255, 255)
CYAN_D = (0, 150, 172, 255)
RED = (222, 96, 82, 255)
GREY = (82, 86, 98, 255)
GREY_L = (112, 116, 126, 255)
GREY_D = (60, 63, 74, 255)
CLEAR = (0, 0, 0, 0)

manifest = {}


def save(img, name, cap=None, note=""):
    img.save(SRC / f"{name}.png")
    manifest[name] = {"size": list(img.size), **({"cap": cap} if cap is not None else {}), "use": note}
    return img


# ── 9-slice 틀 ───────────────────────────────────────────
def framed(w, h, rings, body, pattern=None, notch=True, top=0):
    """rings: [(top_left, bottom_right), ...] 바깥부터. body: 가운데 색, pattern(x, y) -> 색 or None."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(top, h):
        for x in range(w):
            d = min(x, y - top, w - 1 - x, h - 1 - y)
            if d < len(rings):
                tl, br = rings[d]
                px[x, y] = br if (x == w - 1 - d or y == h - 1 - d) else tl
            else:
                c = pattern(x, y) if pattern else None
                px[x, y] = c or body
    if notch:   # 홈 파인 모서리: 바깥 모서리는 비우고 한 칸 안쪽을 외곽선으로
        for (x, y) in ((0, top), (w - 1, top), (0, h - 1), (w - 1, h - 1)):
            px[x, y] = CLEAR
        for (x, y) in ((1, top + 1), (w - 2, top + 1), (1, h - 2), (w - 2, h - 2)):
            px[x, y] = O
    return img


def scan(a, b):
    return lambda x, y: a if y % 2 == 0 else b


def put(img, pts, c):
    px = img.load()
    for x, y in pts:
        px[x, y] = c


def brackets(img, inset, length, c):
    """네 모서리 안쪽의 ㄱ자 꺾쇠 (cap 안에만 그림)."""
    w, h = img.size
    pts = []
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        ox = inset if sx > 0 else w - 1 - inset
        oy = inset if sy > 0 else h - 1 - inset
        pts += [(ox + sx * i, oy) for i in range(length)] + [(ox, oy + sy * i) for i in range(length)]
    put(img, pts, c)


def panel(dark):
    if dark:
        img = framed(24, 24, [(O, O), (SLATE_L, SHADE), (SLATE, SLATE), (NAVY_DEEP, NAVY_DEEP)], NAVY,
                     scan(NAVY, NAVY_2))
        put(img, [(3, 3), (20, 3), (3, 20), (20, 20)], SLATE_LL)     # 리벳
        put(img, [(6, 2)], AMBER)                                    # 상태 LED
        put(img, [(17, 2)], CYAN_D)
    else:
        img = framed(24, 24, [(O, O), (PAPER_L, PAPER_DD), (PAPER_D, PAPER_D), (SLATE_L, SLATE_L)], PAPER,
                     scan(PAPER, PAPER_2))
        put(img, [(3, 3), (20, 3), (3, 20), (20, 20)], PAPER_L)
        put(img, [(6, 2)], AMBER_D)
        put(img, [(17, 2)], TEAL)
    return img


def card(dark):
    if dark:
        img = framed(24, 24, [(O, O), (TEAL_L, TEAL_D), (TEAL, TEAL), (O, O)], NAVY, scan(NAVY, NAVY_2))
        brackets(img, 5, 3, CYAN_D)
    else:
        img = framed(24, 24, [(O, O), (TEAL_LL, TEAL), (TEAL_L, TEAL_L), (SLATE_L, SLATE_L)], PAPER_L,
                     scan(PAPER_L, PAPER))
        brackets(img, 5, 3, TEAL)
    put(img, [(2, 3), (3, 2)], AMBER if dark else AMBER_D)        # 왼쪽 위 호박색 표식
    return img


def chip(dark):
    if dark:
        img = framed(16, 16, [(O, O), (SLATE_L, SLATE_D)], NAVY)
        put(img, [(2, 2)], SLATE_LL)
    else:
        img = framed(16, 16, [(O, O), (PAPER_L, PAPER_D)], PAPER)
        put(img, [(2, 2)], (255, 255, 255, 255))
    return img


def field(dark):
    if dark:   # 파인 입력란: 그늘이 왼쪽 위, 빛이 오른쪽 아래 + 아래쪽 시안 밑줄
        img = framed(24, 24, [(O, O), (NAVY_DEEP, SLATE_L), (SHADE, SHADE)], NAVY_DEEP, notch=False)
        put(img, [(x, 21) for x in range(3, 21)], CYAN_D)
    else:
        img = framed(24, 24, [(O, O), (PAPER_DD, PAPER_L), (PAPER_D, PAPER_L)], PAPER_L, notch=False)
        put(img, [(x, 21) for x in range(3, 21)], TEAL)
    return img


for kind, fn, cap, note in (("panel", panel, 8, "판 — 단말 화면 · 서랍 · 대사 창"),
                            ("card", card, 8, "단어 카드 · 통계 카드 (꺾쇠 = 판독 창)"),
                            ("chip", chip, 6, "작은 정보 칩 · 배지"),
                            ("field", field, 8, "입력란 (파인 홈 + 밑줄)")):
    for tone in ("dark", "light"):
        save(fn(tone == "dark"), f"njl_frame_{kind}_{tone}", cap, f"{note} · {'어둠' if tone == 'dark' else '밝음'}")


# ── 버튼 3상태 (24×24, 아래 2px = 두께, 눌리면 2px 내려감) ──
def button(state):
    if state == "normal":
        img = framed(24, 22, [(O, O), (SLATE_LL, SHADE), (SLATE_L, SLATE)], SLATE)
        base = Image.new("RGBA", (24, 24))
        lip = framed(24, 24, [(O, O)], SHADE)          # 두께(그늘 2px)
        base.alpha_composite(lip)
        base.alpha_composite(img)
        put(base, [(1, 20), (22, 20)], O)
        put(base, [(4, 3), (5, 3), (6, 3)], AMBER)      # 위쪽 호박색 빛 줄
        return base
    if state == "pressed":
        img = framed(24, 24, [(O, O), (SHADE, SLATE_L), (AMBER_D, AMBER_D)], SLATE_D, top=2)
        put(img, [(4, 5), (5, 5), (6, 5)], AMBER)
        return img
    hatch = lambda x, y: GREY_D if (x + y) % 4 == 0 else None   # 비활성: 사선 빗금
    img = framed(24, 22, [(O, O), (GREY_L, GREY_D), (GREY, GREY)], GREY, hatch)
    base = Image.new("RGBA", (24, 24))
    base.alpha_composite(framed(24, 24, [(O, O)], GREY_D))
    base.alpha_composite(img)
    put(base, [(1, 20), (22, 20)], O)
    return base


for state, note in (("normal", "기본 — 위 빛 · 아래 2px 두께"), ("pressed", "눌림 — 2px 내려감 · 호박색 테두리"),
                    ("disabled", "비활성 — 회색 · 사선 빗금")):
    save(button(state), f"njl_button_{state}", 8, f"버튼 {note}")


# ── 아이콘 공통: 채우기 → 바깥 1px 외곽선 자동 ───────────────
def outline(img, c=O):
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


# ── 평가 버튼 신호 막대 1~4 ─────────────────────────────────
LEVEL = {1: (RED, (250, 150, 132, 255)), 2: (AMBER_D, AMBER), 3: (TEAL_L, TEAL_LL), 4: (CYAN_D, CYAN)}


def signal(level, size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    if size == 24:
        xs, wid, heights, bottom = (2, 7, 12, 17), 4, (5, 9, 13, 17), 20
    else:
        xs, wid, heights, bottom = (1, 5, 9, 13), 2, (3, 6, 9, 12), 13
    fill, light = LEVEL[level]
    for i, (x, hgt) in enumerate(zip(xs, heights)):
        y0 = bottom - hgt + 1
        if i < level:
            rect(d, x, y0, x + wid - 1, bottom, fill)
            rect(d, x, y0, x + wid - 1, y0, light)          # 막대 끝 빛
        else:
            rect(d, x, y0, x + wid - 1, bottom, NAVY_DEEP)  # 빈 칸: 어두운 홈
            if wid > 2:
                rect(d, x + 1, y0 + 1, x + wid - 2, bottom - 1, NAVY)
    img = outline(img)
    if level == 1:   # 판독 불가: 빈 칸 위에 작은 X
        cx, cy = (17, 5) if size == 24 else (11, 3)
        r = 2 if size == 24 else 1
        put(img, [(cx + i, cy + i) for i in range(-r, r + 1)] + [(cx + i, cy - i) for i in range(-r, r + 1)], RED)
    return img


for level, name in ((1, "판독 불가"), (2, "흐림"), (3, "판독"), (4, "선명")):
    for size in (16, 24):
        save(signal(level, size), f"njl_signal_{level}_{size}", None, f"평가 버튼 신호 막대 {level}칸 — {name}")


# ── 탭바 아이콘 24px (보통 · 선택) ─────────────────────────────
def tab_terminal(sel):
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    case, case_l = (TEAL_L, TEAL_LL) if sel else (SLATE_L, SLATE_LL)
    rect(d, 4, 2, 19, 21, case)
    rect(d, 4, 2, 19, 2, case_l)
    rect(d, 4, 2, 4, 21, case_l)
    rect(d, 6, 4, 17, 13, NAVY_DEEP)                       # 화면
    glyph = CYAN if sel else TEAL_L
    for y, x1 in ((6, 14), (8, 11), (10, 15)):             # 판독 중인 줄
        rect(d, 8, y, x1, y, glyph)
    put(img, [(8, 12), (10, 12), (12, 12)], CYAN_D if sel else TEAL)   # 모자이크 점
    rect(d, 7, 16, 9, 18, SLATE_D if not sel else TEAL)    # 버튼
    rect(d, 12, 16, 16, 16, SHADE)                         # 스피커 줄
    rect(d, 12, 18, 16, 18, SHADE)
    put(img, [(17, 19)], AMBER if sel else SLATE)          # 전원 LED
    return outline(img)


def tab_institute(sel):
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    wall, wall_l = (PAPER, PAPER_L) if sel else (SLATE_L, SLATE_LL)
    roof = TEAL if sel else SLATE
    rect(d, 11, 1, 11, 5, GREY_L)                          # 안테나
    put(img, [(11, 1)], CYAN if sel else SLATE_L)
    rect(d, 3, 6, 20, 8, roof)                             # 처마
    rect(d, 2, 8, 21, 9, roof)
    rect(d, 4, 10, 19, 21, wall)
    rect(d, 4, 10, 4, 21, wall_l)
    win = AMBER if sel else NAVY_DEEP
    for x in (6, 15):                                      # 창문
        rect(d, x, 12, x + 2, 14, win)
        rect(d, x, 17, x + 2, 19, win if sel else NAVY_DEEP)
    rect(d, 10, 15, 13, 21, NAVY_DEEP)                     # 문
    rect(d, 10, 12, 13, 13, AMBER_D if sel else SLATE)     # NJL 현판
    return outline(img)


def tab_records(sel):
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    frame, frame_l = (TEAL_L, TEAL_LL) if sel else (SLATE_L, SLATE_LL)
    rect(d, 2, 3, 21, 20, frame)
    rect(d, 2, 3, 21, 3, frame_l)
    rect(d, 4, 5, 19, 18, NAVY_DEEP)
    bars = (CYAN_D, CYAN) if sel else (TEAL, TEAL_L)
    for x, top in ((6, 14), (9, 11), (12, 13), (15, 8)):   # 막대
        rect(d, x, top, x + 1, 17, bars[0])
        put(img, [(x, top), (x + 1, top)], bars[1])
    put(img, [(6, 12), (9, 9), (12, 10), (15, 6), (17, 6)], AMBER if sel else SLATE_LL)   # 선 그래프 점
    rect(d, 9, 21, 14, 21, frame)                          # 받침
    return outline(img)


def tab_settings(sel):
    img = Image.new("RGBA", (24, 24))
    px = img.load()
    body, light = (AMBER_D, AMBER) if sel else (SLATE_L, SLATE_LL)
    cx = cy = 11.5
    for y in range(24):
        for x in range(24):
            r = math.hypot(x - cx, y - cy)
            a = (math.atan2(y - cy, x - cx) + math.pi / 8) % (math.pi / 4)
            tooth = r < 10.6 and abs(a - math.pi / 8) < 0.22
            if r < 7.6 or tooth:
                px[x, y] = light if (x + y) < 20 and r > 5 else body
            if r < 3.2:
                px[x, y] = CLEAR
    img = outline(img)
    px = img.load()
    for y in range(24):
        for x in range(24):
            if 3.2 <= math.hypot(x - cx, y - cy) < 4.3 and px[x, y][3]:
                px[x, y] = O
    if sel:
        put(img, [(11, 11), (12, 11), (11, 12), (12, 12)], CYAN)   # 가운데 시안 코어
    return img


for key, fn, label in (("terminal", tab_terminal, "학습 → 판독 단말"), ("institute", tab_institute, "연구소"),
                       ("records", tab_records, "통계 → 판독 기록"), ("settings", tab_settings, "설정 → 단말 설정")):
    for sel in (False, True):
        save(fn(sel), f"njl_tab_{key}_{'selected' if sel else 'normal'}", None,
             f"탭바 {label} · {'선택' if sel else '보통'}")


# ── 설정 컨트롤 ─────────────────────────────────────────────
def toggle(on):
    img = framed(32, 16, [(O, O), (NAVY_DEEP, SLATE_L)], TEAL if on else NAVY_DEEP)
    if on:   # 켜짐: 청록 홈 + 시안 표시등 줄
        put(img, [(x, 7) for x in range(4, 15, 2)], CYAN)
    else:
        put(img, [(x, 7) for x in range(19, 28, 2)], SLATE_D)
    kx = 17 if on else 1
    knob = framed(14, 14, [(O, O), (PAPER_L if on else SLATE_LL, PAPER_D if on else SHADE)],
                  PAPER if on else SLATE_L)
    put(knob, [(6, 4), (6, 6), (6, 8), (7, 4), (7, 6), (7, 8)], PAPER_D if on else SLATE)   # 손잡이 홈
    img.alpha_composite(knob, (kx, 1))
    return img


save(toggle(False), "njl_toggle_off", None, "토글 꺼짐 (32×16)")
save(toggle(True), "njl_toggle_on", None, "토글 켜짐 (32×16) — 손잡이 오른쪽, 시안 표시등")
save(framed(16, 16, [(O, O), (NAVY_DEEP, SLATE_L)], NAVY_DEEP, notch=False), "njl_segment_track", 6,
     "세그먼트 바깥 홈 (9-slice)")
seg = framed(16, 16, [(O, O), (SLATE_LL, SHADE), (AMBER_D, AMBER_D)], SLATE)
put(seg, [(4, 3), (5, 3)], AMBER)
save(seg, "njl_segment_thumb", 6, "세그먼트 고른 칸 (9-slice, 홈 위에 겹침)")
save(framed(16, 8, [(O, O), (NAVY_DEEP, SLATE_L)], NAVY_DEEP, notch=False), "njl_slider_track", 3,
     "슬라이더 빈 홈 (가로 9-slice, 높이 고정)")
save(framed(16, 8, [(O, O), (CYAN_D, TEAL)], TEAL, scan(TEAL, TEAL_L), notch=False), "njl_slider_fill", 3,
     "슬라이더 채운 부분 (가로 9-slice)")
knob = framed(12, 16, [(O, O), (SLATE_LL, SHADE), (SLATE_L, SLATE_L)], SLATE_L)
put(knob, [(x, y) for y in (6, 8, 10) for x in range(4, 8)], SHADE)   # 미끄럼 방지 홈
put(knob, [(5, 3), (6, 3)], AMBER)
save(knob, "njl_slider_knob", None, "슬라이더 손잡이 (12×16) — 위 호박색 표시")


# ── 통계: 잔디 칸 5단계 · 그래프 마커 ───────────────────────────
HEAT = [(NAVY_DEEP, SLATE_D), (TEAL_D, TEAL), (TEAL, TEAL_L), (TEAL_L, TEAL_LL), (CYAN_D, CYAN)]
for level, (body, light) in enumerate(HEAT):
    cell = framed(8, 8, [(light, body)], body, notch=False)
    px = cell.load()
    for (x, y) in ((0, 0), (7, 0), (0, 7), (7, 7)):
        px[x, y] = CLEAR
    if level == 0:
        put(cell, [(3, 3), (4, 4)], SLATE_D)          # 빈 칸: 점 두 개
    if level == 4:
        put(cell, [(2, 2)], (220, 255, 255, 255))     # 가장 진한 칸: 반짝 한 점
    save(cell, f"njl_heat_{level}", None, f"잔디 칸 {level}단계 (8×8, 칸 사이 간격은 코드에서)")

bar = Image.new("RGBA", (8, 8))
put(bar, [(x, y) for y in range(8) for x in range(8) if abs(x - 3.5) + abs(y - 3.5) <= 3], AMBER)
put(bar, [(3, 1), (2, 2), (3, 2)], (255, 236, 170, 255))
save(outline(bar.crop((0, 0, 8, 8))), "njl_marker_bar", None, "막대 그래프 끝 마커 (호박색 마름모)")
ring = Image.new("RGBA", (8, 8))
put(ring, [(x, y) for y in range(8) for x in range(8) if 1.6 <= math.hypot(x - 3.5, y - 3.5) <= 3.1], CYAN)
put(ring, [(x, y) for y in range(8) for x in range(8) if math.hypot(x - 3.5, y - 3.5) < 1.6], NAVY_DEEP)
save(outline(ring), "njl_marker_line", None, "선 그래프 점 마커 (시안 고리)")

(SRC / "njl_os_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


# ── 미리보기 ─────────────────────────────────────────────────
def nine(img, cap, w, h):
    """9-slice를 타일 방식으로 늘림 (앱의 .tile 과 같은 방식)."""
    sw, sh = img.size
    out = Image.new("RGBA", (w, h))
    cx = [(0, cap, 0, cap), (cap, sw - cap, cap, w - cap), (sw - cap, sw, w - cap, w)]
    cy = [(0, cap, 0, cap), (cap, sh - cap, cap, h - cap), (sh - cap, sh, h - cap, h)]
    for sx0, sx1, dx0, dx1 in cx:
        for sy0, sy1, dy0, dy1 in cy:
            piece = img.crop((sx0, sy0, sx1, sy1))
            pw, ph = piece.size
            for y in range(dy0, dy1, ph):
                for x in range(dx0, dx1, pw):
                    out.alpha_composite(piece.crop((0, 0, min(pw, dx1 - x), min(ph, dy1 - y))), (x, y))
    return out


DARK_BG, LIGHT_BG = (52, 58, 76, 255), (196, 202, 210, 255)


def strip(names, scale, bg, gap=4):
    imgs = [Image.open(SRC / f"{n}.png") for n in names]
    w = sum(i.width for i in imgs) + gap * (len(imgs) + 1)
    h = max(i.height for i in imgs) + gap * 2
    sheet = Image.new("RGBA", (w, h), bg)
    x = gap
    for i in imgs:
        sheet.alpha_composite(i, (x, gap + (h - 2 * gap - i.height)))
        x += i.width + gap
    return sheet.resize((w * scale, h * scale), Image.NEAREST)


groups = {
    "frames_dark": ([f"njl_frame_{k}_dark" for k in ("panel", "card", "chip", "field")], DARK_BG),
    "frames_light": ([f"njl_frame_{k}_light" for k in ("panel", "card", "chip", "field")], LIGHT_BG),
    "buttons": ([f"njl_button_{s}" for s in ("normal", "pressed", "disabled")], DARK_BG),
    "signal": ([f"njl_signal_{l}_24" for l in range(1, 5)] + [f"njl_signal_{l}_16" for l in range(1, 5)], DARK_BG),
    "tabs": ([f"njl_tab_{k}_{s}" for s in ("normal", "selected") for k in ("terminal", "institute", "records", "settings")], DARK_BG),
    "controls": (["njl_toggle_off", "njl_toggle_on", "njl_segment_track", "njl_segment_thumb", "njl_slider_track",
                  "njl_slider_fill", "njl_slider_knob"], DARK_BG),
    "stats": ([f"njl_heat_{l}" for l in range(5)] + ["njl_marker_bar", "njl_marker_line"], DARK_BG),
}
for gname, (names, bg) in groups.items():
    strip(names, 6, bg).save(PREV / f"preview_njl_{gname}_x6.png")


# 전체 시트: 원본 줄 + 9-slice를 늘려 본 예시 (x4)
def label(sheet, text, xy, c=(230, 232, 236, 255)):
    ImageDraw.Draw(sheet).text(xy, text, fill=c)


S = 4
rows = []


def row_demo(tone, bg):
    """판 위에 카드·칩·입력란·버튼을 실제 크기로 늘려 배치한 미니 화면."""
    canvas = Image.new("RGBA", (200, 104), (24, 27, 38, 255))
    canvas.alpha_composite(nine(Image.open(SRC / f"njl_frame_panel_{tone}.png"), 8, 200, 104))
    canvas.alpha_composite(nine(Image.open(SRC / f"njl_frame_card_{tone}.png"), 8, 120, 56), (10, 12))
    canvas.alpha_composite(nine(Image.open(SRC / f"njl_frame_chip_{tone}.png"), 6, 54, 16), (136, 12))
    canvas.alpha_composite(nine(Image.open(SRC / f"njl_frame_chip_{tone}.png"), 6, 38, 16), (136, 32))
    canvas.alpha_composite(nine(Image.open(SRC / f"njl_frame_field_{tone}.png"), 8, 120, 22), (10, 72))
    for i, state in enumerate(("normal", "pressed", "disabled")):
        canvas.alpha_composite(nine(Image.open(SRC / f"njl_button_{state}.png"), 8, 18, 24), (136 + i * 20, 70))
    return canvas


demo_dark, demo_light = row_demo("dark", DARK_BG), row_demo("light", LIGHT_BG)
ctrl = Image.new("RGBA", (200, 60), DARK_BG)
ctrl.alpha_composite(Image.open(SRC / "njl_toggle_off.png"), (8, 8))
ctrl.alpha_composite(Image.open(SRC / "njl_toggle_on.png"), (46, 8))
ctrl.alpha_composite(nine(Image.open(SRC / "njl_segment_track.png"), 6, 110, 16), (84, 8))
ctrl.alpha_composite(nine(Image.open(SRC / "njl_segment_thumb.png"), 6, 36, 16), (121, 8))
ctrl.alpha_composite(nine(Image.open(SRC / "njl_slider_track.png"), 3, 150, 8), (8, 38))
ctrl.alpha_composite(nine(Image.open(SRC / "njl_slider_fill.png"), 3, 80, 8), (8, 38))
ctrl.alpha_composite(Image.open(SRC / "njl_slider_knob.png"), (82, 34))
heat = Image.new("RGBA", (200, 60), DARK_BG)
for i in range(7 * 22):
    level = [0, 1, 0, 2, 3, 1, 4, 2, 0, 3, 4, 4, 1, 2][(i * 7 + i // 7) % 14]
    heat.alpha_composite(Image.open(SRC / f"njl_heat_{level}.png"), (4 + (i // 7) * 9, 2 + (i % 7) * 8))
pts = [(6, 40), (34, 30), (62, 36), (90, 18), (118, 24)]
ImageDraw.Draw(heat)  # 마커 예시는 아래 시트에 따로
sections = [
    ("frames (dark / light) — 9-slice", [strip(groups["frames_dark"][0], S, DARK_BG), strip(groups["frames_light"][0], S, LIGHT_BG)]),
    ("buttons normal / pressed / disabled", [strip(groups["buttons"][0], S, DARK_BG)]),
    ("rating signal 1-4 (24, 16)", [strip(groups["signal"][0], S, DARK_BG)]),
    ("tab icons normal / selected", [strip(groups["tabs"][0], S, DARK_BG)]),
    ("settings controls", [strip(groups["controls"][0], S, DARK_BG)]),
    ("stats heat 0-4 + markers", [strip(groups["stats"][0], S, DARK_BG)]),
    ("stretched demo (dark / light / controls / heat)", [
        demo_dark.resize((800, 416), Image.NEAREST), demo_light.resize((800, 416), Image.NEAREST),
        ctrl.resize((800, 240), Image.NEAREST), heat.resize((800, 240), Image.NEAREST)]),
]
W = max(max(p.width for p in parts) for _, parts in sections) + 32
H = sum(24 + sum(p.height + 8 for p in parts) for _, parts in sections) + 16
sheet = Image.new("RGBA", (W, H), (24, 27, 38, 255))
y = 12
for title, parts in sections:
    label(sheet, title, (16, y + 4))
    y += 24
    for p in parts:
        sheet.alpha_composite(p, (16, y))
        y += p.height + 8
sheet.save(PREV / "preview_njl_os_sheet.png")
print(len(manifest), "assets")
