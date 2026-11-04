"""「형광 단말과 담쟁이」 UI 키트 시안 v1. usage: phosphor_kit.py <out_dir> <preview_dir> <tech_lab_pack_dir>

기준: Docs/05_Art/StyleRef/ART_BIBLE.md (팔레트 Phosphor 28 · 재질 · 8프레임 150ms).
판 = 크림 플라스틱 단말 + 녹색 CRT 화면. 화면 안의 그림(아이콘 · 잔디 · 막대)은 모두 형광 단색 계열.
팩(Tech Lab) 소품은 PACK_MAP으로 이 팔레트에 맞춰 다시 칠하고 <out_dir>/from_pack/ 에 둠 (git 제외).
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT, PREV, PACK = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "from_pack").mkdir(exist_ok=True)
F = 8


def hx(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK = hx("231620")
SH1, SH2, SH3 = hx("33232E"), hx("4B2F31"), hx("5B3330")
WD1, WD2, WD3, WD4 = hx("774C44"), hx("AE7155"), hx("B28B69"), hx("C4A078")
CR0, CR1, CR2, CR3, CR4, CR5 = hx("736A54"), hx("A39372"), hx("C0AD88"), hx("DEC792"), hx("EFE7B4"), hx("F7F2D6")
P0, P1, P2, P3, P4, P5 = hx("16301F"), hx("27593A"), hx("2E7445"), hx("46965A"), hx("96E68C"), hx("D2FFBE")
IV0, IV1, IV2, IV3, IV4 = hx("1B2519"), hx("3A452E"), hx("3F5B3A"), hx("6A7B55"), hx("8EA05E")
AM, AM_D, RED, PINK = hx("FADC78"), hx("E0A040"), hx("D65C5C"), hx("E68C8C")
CLEAR = (0, 0, 0, 0)
LED_OFF = hx("5A4A40")
SCR_A, SCR_B = P1, hx("234F34")
BEZEL = hx("4A3A34")
manifest = {}


def save_strip(frames, name, cap=None, note=""):
    w, h = frames[0].size
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * w, 0))
    strip.save(OUT / f"{name}.png")
    manifest[name] = {"frame": [w, h], "frames": len(frames), "frame_ms": 150,
                      **({"cap": cap} if cap is not None else {}), "use": note}
    return frames


def put(img, pts, c):
    px = img.load()
    w, h = img.size
    for x, y in pts:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def outline(img, c=INK):
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if not src[x, y][3] and any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] > 100
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


BLINK = {"steady": [1, 1, 1, 1, 1, 1, 0, 1], "disk": [1, 0, 0, 1, 1, 0, 1, 0], "slow": [1, 1, 1, 1, 0, 0, 0, 0]}


def device(w, h, frame, bezel, cap_inner):
    """크림 플라스틱 몸체(테두리 bezel px) + 파인 CRT 화면. 장식은 모두 cap 안."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0:
                c = INK
            elif d < bezel:
                if d == 1:
                    c = CR5 if (x == 1 or y == 1) and not (x == w - 2 or y == h - 2) else CR1
                else:
                    c = CR3 if y < h - 1 - d else CR2                    # 아래쪽은 살짝 그늘
                    if x == w - 1 - d:
                        c = CR2
            elif d == bezel:
                c = BEZEL                                                # 화면 둘레의 파인 홈
            elif d == bezel + 1:
                c = INK if (x == bezel + 1 or y == bezel + 1) else SH2
            else:
                c = SCR_A if y % 2 == 0 else SCR_B                       # 주사선
                if d == bezel + 2:
                    c = P0                                               # 볼록 유리 가장자리
            px[x, y] = c
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (1, 0), (0, 1), (w - 2, 0), (w - 1, 1),
                   (0, h - 2), (1, h - 1), (w - 1, h - 2), (w - 2, h - 1)):
        px[x, y] = CLEAR                                                 # 둥근 모서리 (2px)
    for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        px[x, y] = INK
    g = bezel + 3                                                        # 유리 반사 (왼쪽 위 cap 안)
    put(img, [(g, g), (g + 1, g), (g + 2, g), (g, g + 1), (g, g + 2)], P2)
    put(img, [(g + 1, g + 1)], P3)
    return img


# ── 1. 판 32×32 · cap 12 ─────────────────────────────────────────
def panel(f):
    img = device(32, 32, f, 5, 12)
    put(img, [(3, 2)], P4 if BLINK["steady"][f] else LED_OFF)           # 전원 LED (녹)
    put(img, [(5, 2)], AM if BLINK["disk"][f] else LED_OFF)             # 디스크 램프 (호박)
    for x in range(20, 29, 2):                                           # 통풍 구멍 줄
        put(img, [(x, 2)], CR1)
    for x in range(20, 29, 2):
        put(img, [(x, 29)], CR1)
    rect(ImageDraw.Draw(img), 3, 29, 8, 29, CR2)                          # 명판
    put(img, [(3, 29)], CR4)
    put(img, [(27, 27), (28, 28)], CR1)                                   # 긁힌 자국
    return img


save_strip([panel(f) for f in range(F)], "ph_panel", 12,
           "판 — 크림 단말 몸체 + 녹색 CRT(주사선 · 볼록 유리 가장자리 · 반사). 전원 LED · 디스크 램프가 깜빡")


def tile(f):
    img = device(24, 24, f, 3, 9)
    put(img, [(20, 1)], P4 if BLINK["slow"][f] else LED_OFF)
    return img


save_strip([tile(f) for f in range(F)], "ph_tile", 9, "작은 판 — 숫자 칸 · 설정 줄. 오른쪽 위 녹색 LED")


# ── 2. 키캡 버튼 (보통 · 눌림) 24×24 · cap 8 ─────────────────────────
def keycap(pressed):
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    top = 2 if pressed else 0
    rect(d, 1, 3 + top, 22, 23, CR0)                                      # 키 옆면(두께)
    rect(d, 1, top, 22, 20 if not pressed else 21, CR3)
    rect(d, 1, top, 22, top, CR5)
    rect(d, 1, top, 1, 20, CR4)
    rect(d, 3, top + 2, 20, (18 if not pressed else 19), CR4)             # 오목한 윗면
    rect(d, 3, top + 2, 20, top + 2, CR3)
    if pressed:
        put(img, [(19, top + 3)], P4)                                      # 눌리면 녹색 표시등
    return outline(img)


save_strip([keycap(False)], "ph_key", 8, "키캡 버튼 기본 (9-slice, 아래 3px = 키 두께)")
save_strip([keycap(True)], "ph_key_pressed", 8, "키캡 눌림 — 2px 내려가고 녹색 표시등")


# ── 3. 화면 속 잔디 (형광 밝기 5단계) + 오늘 칸 ─────────────────────────
HEAT = [(hx("21462E"), hx("2A5A3B")), (P2, P3), (P3, hx("6EBE6E")), (hx("6EBE6E"), P4), (P4, P5)]


def heat(lv, glow=0):
    img = Image.new("RGBA", (8, 8))
    d = ImageDraw.Draw(img)
    body, light = HEAT[lv]
    rect(d, 0, 0, 6, 6, body)
    rect(d, 0, 0, 6, 0, light)
    if lv == 0:
        put(img, [(3, 3)], P2)
    if lv == 4:
        put(img, [(1, 1)], P5)
    if glow:                                                              # 오늘 칸: 번짐 1px 바깥으로
        for p in ((-1, 3), (7, 3), (3, -1), (3, 7)):
            put(img, [p], (210, 255, 190, glow))
        rect(d, 1, 1, 5, 5, P5 if glow > 120 else P4)
    return img


for lv in range(5):
    save_strip([heat(lv)], f"ph_heat_{lv}", None, f"잔디 칸 {lv}단계 (화면 속 형광 밝기)")
save_strip([heat(4, a) for a in (0, 60, 140, 220, 255, 220, 140, 60)], "ph_heat_today", None, "오늘 칸 — 형광이 숨 쉬듯 밝아짐")


# ── 4. 화면 속 아이콘 24px (형광 단색 글리프, 8프레임) ───────────────────
def glyph(fn, f):
    img = Image.new("RGBA", (24, 24))
    fn(ImageDraw.Draw(img), img, f)
    return img


def g_cards(d, img, f):
    d.rectangle([5, 6, 20, 19], outline=P2)
    d.rectangle([3, 4, 18, 17], outline=P3)
    d.rectangle([1, 2, 16, 15], outline=P4, fill=P1)
    n = f + 1
    for row, y in enumerate((5, 8, 11)):
        k = max(0, min(4, n - row * 3))
        for i in range(k):
            rect(d, 3 + i * 3, y, 4 + i * 3, y, P4)
    cy = 5 + 3 * min(2, n // 3)
    if f % 2 == 0:
        rect(d, 3 + (n % 3) * 3 + 1, cy - 1, 3 + (n % 3) * 3 + 2, cy, P5)  # 블록 커서


def g_gauge(d, img, f):
    d.arc([1, 4, 22, 25], 180, 360, fill=P3)
    d.arc([3, 6, 20, 23], 200, 340, fill=P2)
    for a in (190, 230, 270, 310, 350):
        put(img, [(round(11.5 + 10 * math.cos(math.radians(a))), round(14.5 + 10 * math.sin(math.radians(a))))], P4)
    jit = [0, 3, -2, 4, 1, -3, 2, 0][f]
    a = math.radians(346 + jit)
    d.line([(11.5, 14.5), (11.5 + 8 * math.cos(a), 14.5 + 8 * math.sin(a))], fill=P5)
    rect(d, 10, 13, 13, 15, P4)
    rect(d, 1, 17, 22, 17, P2)


def g_watch(d, img, f):
    rect(d, 10, 1, 13, 2, P4)
    d.ellipse([2, 4, 21, 23], outline=P4)
    d.ellipse([4, 6, 19, 21], outline=P2)
    a = math.radians(-90 + f * 45)
    d.line([(11.5, 13.5), (11.5 + 6 * math.cos(a), 13.5 + 6 * math.sin(a))], fill=P5)
    put(img, [(11, 13), (12, 13), (11, 14), (12, 14)], P4)


def g_counter(d, img, f):
    d.rectangle([1, 7, 22, 20], outline=P4)
    rect(d, 9, 4 if f else 5, 13, 6, P3)
    DIG = {0: ["###", "#.#", "#.#", "#.#", "###"], 6: ["###", "#..", "###", "#.#", "###"],
           7: ["###", "..#", ".#.", ".#.", ".#."], 8: ["###", "#.#", "###", "#.#", "###"]}
    roll = [7, 7, 8, 8, 8, 8, 8, 8][f]
    for x, dgt in ((4, 0), (10, 6), (16, roll)):
        d.rectangle([x - 1, 10, x + 3, 16], fill=P1)
        for r, row in enumerate(DIG[dgt]):
            for c, v in enumerate(row):
                if v == "#":
                    put(img, [(x + c, 11 + r)], P5 if x == 16 else P3)


for key, fn, note in (("cards", g_cards, "외운 단어 — 카드에 글자가 찍히고 블록 커서 깜빡"), ("gauge", g_gauge, "기억 유지율 — 바늘 떨림"),
                      ("stopwatch", g_watch, "반응 시간 — 초침 한 바퀴"), ("counter", g_counter, "누적 평가 — 단추 눌림 · 67→68")):
    save_strip([glyph(fn, f) for f in range(F)], f"ph_icon_{key}_24", None, note)


# ── 5. 화면 속 막대 (가로 9-slice 16×8 · cap 4) ──────────────────────
LV = {1: (hx("8A3A40"), PINK), 2: (AM_D, AM), 3: (P3, hx("6EBE6E")), 4: (P4, P5)}


def meter(lv, f):
    img = Image.new("RGBA", (16, 8), CLEAR)
    base, hi = LV[lv]
    for x in range(16):
        for y in range(1, 7):
            if x % 3 != 2:
                put(img, [(x, y)], hi if y == 1 else base)
        if (x - f) % 8 == 0 and x % 3 != 2:                                  # 흐르는 빛
            for y in range(1, 7):
                put(img, [(x, y)], P5)
    return img


def meter_track():
    img = Image.new("RGBA", (16, 8))
    for x in range(16):
        for y in range(1, 7):
            if x % 3 != 2:
                put(img, [(x, y)], P1 if y > 1 else P2)
    return img


save_strip([meter_track()], "ph_meter_track", 4, "화면 속 막대 빈 칸 (3px 칸)")
for lv in range(1, 5):
    save_strip([meter(lv, f) for f in range(F)], f"ph_meter_fill_{lv}", 4,
               f"막대 채움 {lv}단계 — 1 분홍(판독 불가) · 2 호박 · 3 녹 · 4 밝은 녹, 흐르는 빛")


# ── 6. 커서 · 타자 줄 · 주사선 띠 ───────────────────────────────────
cur = [Image.new("RGBA", (6, 10)) for _ in range(F)]
for f, im in enumerate(cur):
    if f < 4:
        rect(ImageDraw.Draw(im), 0, 0, 5, 9, P4)
        rect(ImageDraw.Draw(im), 0, 0, 5, 0, P5)
save_strip(cur, "ph_cursor", None, "블록 커서 — 4프레임 켜짐 · 4프레임 꺼짐 (입력란 · 제목 끝 · 빈 화면)")

typing = []
for f in range(F):
    im = Image.new("RGBA", (48, 6))
    d = ImageDraw.Draw(im)
    n = min(f + 1, 6)
    for i in range(n):
        w = [5, 3, 6, 4, 5, 2][i]
        x = sum([5, 3, 6, 4, 5, 2][:i]) + i * 2
        rect(d, x, 1, x + w - 1, 4, P3)
        put(im, [(x, 1)], P4)
    if f % 2 == 0 and f < 7:
        x = sum([5, 3, 6, 4, 5, 2][:n]) + n * 2
        rect(d, x, 0, x + 2, 5, P5)
    typing.append(im)
save_strip(typing, "ph_typing", None, "한 줄씩 타자되는 가짜 글 — 빈 화면 · 로딩 · 대사 대기")

sweep = []
for f in range(F):
    im = Image.new("RGBA", (8, 64))
    y0 = f * 8
    for y in range(64):
        dist = (y - y0) % 64
        a = {0: 70, 1: 45, 2: 25, 3: 12}.get(dist, 0)
        if a:
            rect(ImageDraw.Draw(im), 0, y, 7, y, (210, 255, 190, a))
    sweep.append(im)
save_strip(sweep, "ph_scan_sweep", None, "화면 위를 위에서 아래로 지나가는 밝은 띠 (가로로 타일, 높이 64 반복)")


# ── 7. 담쟁이 (화면 위에서 늘어지는 덩굴, 8프레임 잎 흔들림) ──────────────────
def ivy_strip(width, height, seed, f):
    rng = random.Random(seed)
    img = Image.new("RGBA", (width, height))
    px = img.load()
    leaves = []
    x = 2
    while x < width - 2:
        length = rng.randint(height // 4, height)
        cx = x
        for y in range(length):                                              # 덩굴 줄기
            if 0 <= cx < width:
                px[cx, y] = IV1
            if rng.random() < 0.25:
                cx += rng.choice((-1, 1))
            if rng.random() < 0.35:
                leaves.append((cx + rng.choice((-2, 1)), y, rng.random()))
        x += rng.randint(4, 9)
    for i, (lx, ly, r) in enumerate(leaves):
        sway = 1 if (i % 5 == f % 5 and f in (2, 3, 6)) else 0
        lx += sway
        shade = IV2 if r < 0.4 else (IV3 if r < 0.8 else IV4)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (0, -1)):
            if 0 <= lx + dx < width and 0 <= ly + dy < height and rng.random() < 0.9:
                px[lx + dx, ly + dy] = shade
        if 0 <= lx < width and 0 <= ly < height:
            px[lx, ly] = IV4 if shade != IV4 else hx("B4C878")
    return outline(img, IV0)


save_strip([ivy_strip(96, 40, 7, f) for f in range(F)], "ph_ivy_hang_96", None,
           "늘어지는 담쟁이 96×40 — 판 · 화면 위 가장자리에 걸침. 잎 몇 장이 1px 흔들림")


# ── 8. 팩 소품을 Phosphor 팔레트로 ─────────────────────────────────
PACK_MAP = {
    (24, 20, 37): INK, (38, 43, 68): hx("4B3A34"), (58, 68, 102): CR0, (90, 105, 136): CR1, (139, 155, 180): CR2,
    (192, 203, 220): CR3, (255, 255, 255): CR5, (18, 78, 137): P1, (0, 153, 219): P3, (44, 232, 245): P4,
    (254, 174, 52): WD3, (247, 118, 34): WD2, (228, 166, 114): WD4, (215, 118, 67): WD2, (190, 74, 47): WD1,
    (184, 111, 80): WD1, (194, 133, 105): WD2, (228, 59, 68): RED, (162, 38, 51): hx("8A3A40"),
    (246, 117, 122): PINK, (254, 231, 97): AM, (99, 199, 77): P4, (62, 137, 72): P3, (38, 92, 66): P2,
    (25, 60, 62): P1, (115, 62, 57): SH3, (62, 39, 49): SH2, (234, 212, 170): CR4, (162, 38, 51): RED,
}
PAL = list({v[:3] for v in PACK_MAP.values()})


def to_phosphor(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            c = PACK_MAP.get((r, g, b))
            if c is None:
                c = min(PAL, key=lambda p: (p[0] - r) ** 2 + (p[1] - g) ** 2 + (p[2] - b) ** 2) + (255,)
            px[x, y] = c[:3] + (a,)
    return img


desk = to_phosphor(Image.open(PACK / "props_64/anim/desk_pc_r1.png").convert("RGBA"))
desk.save(OUT / "from_pack" / "desk_pc_r1_phosphor.png")
dw = desk.width // F
desk_frames = [desk.crop((i * dw, 0, (i + 1) * dw, desk.height)) for i in range(F)]
(OUT / "phosphor_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


# ── 9. 시안 화면: 통계 (같은 배치로 비교) ─────────────────────────────
def frames_of(name):
    s = Image.open(OUT / f"{name}.png").convert("RGBA")
    w, h = manifest[name]["frame"]
    return [s.crop((i * w, 0, (i + 1) * w, h)) for i in range(s.width // w)]


def nine(img, cap, w, h):
    sw, sh = img.size
    out = Image.new("RGBA", (w, h))
    for sx0, sx1, dx0, dx1 in ((0, cap, 0, cap), (cap, sw - cap, cap, w - cap), (sw - cap, sw, w - cap, w)):
        for sy0, sy1, dy0, dy1 in ((0, cap, 0, cap), (cap, sh - cap, cap, h - cap), (sh - cap, sh, h - cap, h)):
            piece = img.crop((sx0, sy0, sx1, sy1))
            pw, ph = piece.size
            if not pw or not ph:
                continue
            for y in range(dy0, dy1, ph):
                for x in range(dx0, dx1, pw):
                    out.alpha_composite(piece.crop((0, 0, min(pw, dx1 - x), min(ph, dy1 - y))), (x, y))
    return out


FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"   # 시안 전용 자리표시 글꼴


def text(img, xy, s, size, color, bold=False):
    ImageDraw.Draw(img).text(xy, s, font=ImageFont.truetype(FONT, size, index=6 if bold else 0), fill=color)


panels, tiles, today = frames_of("ph_panel"), frames_of("ph_tile"), frames_of("ph_heat_today")
cells = [frames_of(f"ph_heat_{i}")[0] for i in range(5)]
icons = {k: frames_of(f"ph_icon_{k}_24") for k in ("cards", "gauge", "stopwatch", "counter")}
fills = {lv: frames_of(f"ph_meter_fill_{lv}") for lv in range(1, 5)}
track = frames_of("ph_meter_track")[0]
cursor, ivy, sweepf, key, keyp = frames_of("ph_cursor"), frames_of("ph_ivy_hang_96"), frames_of("ph_scan_sweep"), frames_of("ph_key")[0], frames_of("ph_key_pressed")[0]

rng = random.Random(5)
hist = [0] * 98
for i in range(70, 96):
    hist[i] = rng.choice([0, 0, 1, 1, 2, 3])
hist[96], hist[97] = 3, 4
TXT, DIM = P4, P3


def wall():
    img = Image.new("RGBA", (201, 437), SH1)
    d = ImageDraw.Draw(img)
    for row, y in enumerate(range(0, 437, 7)):                              # 벽돌 줄눈
        rect(d, 0, y, 200, y, hx("2B1D27"))
        off = 0 if row % 2 else 9
        for x in range(off, 201, 18):
            rect(d, x, y, x, y + 6, hx("2B1D27"))
    return img


WALL = wall()


def screen_sweep(img, x, y, w, h, f):
    band = Image.new("RGBA", (w, h))
    for yy in range(0, h, 64):
        for xx in range(0, w, 8):
            band.alpha_composite(sweepf[f].crop((0, 0, min(8, w - xx), min(64, h - yy))), (xx, yy))
    img.alpha_composite(band, (x, y))


def mock(f):
    img = WALL.copy()
    img.alpha_composite(desk_frames[f], (201 - dw - 2, 6))
    img.alpha_composite(ivy[f], (105, 0))
    img.alpha_composite(ivy[(f + 3) % F].transpose(Image.FLIP_LEFT_RIGHT), (-30, 0))
    text(img, (10, 36), "판독 기록", 17, CR4, bold=True)
    if f < 4:
        img.alpha_composite(cursor[0].resize((6, 14)), (92, 39))
    text(img, (10, 58), "NJL-OS 2.94 // STATS", 8, P3)
    # 잔디 판
    img.alpha_composite(nine(panels[f], 12, 185, 98), (8, 100))
    text(img, (16, 106), "성실도 잔디", 9, TXT, bold=True)
    text(img, (150, 106), "2일 연속", 8, AM)
    for i, lv in enumerate(hist):
        cell = today[f] if i == 97 else cells[lv]
        img.alpha_composite(cell, (22 + (i // 7) * 11, 122 + (i % 7) * 9))
    screen_sweep(img, 14, 106, 173, 86, f)
    # 숫자 칸 넷
    data = [("cards", "27/775", "외운 단어"), ("gauge", "92%", "기억 유지율"),
            ("stopwatch", "73.2초", "평균 반응 시간"), ("counter", "67회", "누적 평가")]
    for k, (kk, val, label) in enumerate(data):
        x, y = 8 + (k % 2) * 94, 204 + (k // 2) * 56
        img.alpha_composite(nine(tiles[(f + k * 2) % F], 9, 91, 53), (x, y))
        img.alpha_composite(icons[kk][f], (x + 7, y + 8))
        text(img, (x + 34, y + 9), val, 13, P5, bold=True)
        text(img, (x + 9, y + 35), label, 8, DIM)
    # 평가 기록
    img.alpha_composite(nine(panels[(f + 3) % F], 12, 185, 70), (8, 318))
    for i, (lv, name, n, pct) in enumerate([(1, "판독 불가", 15, 22), (2, "흐림", 10, 15), (3, "판독", 39, 58), (4, "선명", 3, 4)]):
        y = 328 + i * 14
        text(img, (18, y), name, 8, TXT)
        img.alpha_composite(nine(track, 4, 92, 8), (68, y + 1))
        img.alpha_composite(nine(fills[lv][f], 4, max(10, round(92 * pct / 100)), 8), (68, y + 1))
        text(img, (166, y), f"{n}회", 8, DIM)
    screen_sweep(img, 14, 324, 173, 58, (f + 4) % F)
    # 탭바 = 크림 키보드 줄
    d = ImageDraw.Draw(img)
    rect(d, 6, 394, 194, 433, CR1)
    rect(d, 6, 394, 194, 395, CR3)
    rect(d, 6, 432, 194, 433, CR0)
    labels = ["단말", "연구소", "기록", "설정"]
    for i in range(4):
        cap = keyp if i == 2 else key
        img.alpha_composite(nine(cap, 8, 42, 30), (12 + i * 46, 399))
        text(img, (20 + i * 46, 407 + (2 if i == 2 else 0)), labels[i], 9, P3 if i == 2 else CR0, bold=True)
    for x in range(160, 192, 3):                                            # 스피커 구멍 대신 키보드 끝 LED
        pass
    return img


frames = [mock(f) for f in range(F)]
big = [fr.resize((fr.width * 2, fr.height * 2), Image.NEAREST) for fr in frames]
big[0].save(PREV / "preview_phosphor_stats_mock.gif", save_all=True, append_images=big[1:], duration=150, loop=0, disposal=2)
big[2].save(PREV / "preview_phosphor_stats_mock.png")
print(len(manifest), "parts")
