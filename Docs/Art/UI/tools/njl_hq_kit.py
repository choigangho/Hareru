"""NJL-OS 고품질 UI 키트 (시안 v1) — 살아 움직이는 단말기 부품. usage: njl_hq_kit.py <out_dir> <preview_dir> <tech_lab_pack_dir>

Tech Lab 팩(Antahonist)을 분석해서 맞춘 기준:
  · 팔레트: ENDESGA 32의 슬레이트 7단 · 시안 3단 · 호박 · 빨강 · 초록 LED (팩 소품을 UI에 그대로 섞어도 색이 맞음)
  · 빛: 왼쪽 위 고정. 외곽선은 가장 어두운 남보라 (24,20,37)
  · 살아 있음: 8프레임 루프 · 프레임당 150ms. 그림의 2~4% 픽셀(LED · 화면 줄 · 바늘)만 바뀜
모든 부품은 가로 스트립(프레임 8장)으로 저장. 9-slice 부품은 프레임마다 같은 cap.
<tech_lab_pack_dir>의 팩 그림을 다시 칠한 사본은 <out_dir>/from_pack/ 에 둠 (git 제외 — 공개 저장소 재배포 금지).
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
PREV.mkdir(parents=True, exist_ok=True)
F = 8

# ── 팔레트 (ENDESGA 32 부분집합 + Hareru 청록) ───────────────────────
K0 = (24, 20, 37, 255)
S1, S2, S3, S4, S5, W = (38, 43, 68, 255), (58, 68, 102, 255), (90, 105, 136, 255), (139, 155, 180, 255), (192, 203, 220, 255), (255, 255, 255, 255)
C1, C2, C3 = (18, 78, 137, 255), (0, 153, 219, 255), (44, 232, 245, 255)
A1, A2, A0 = (254, 174, 52, 255), (254, 231, 97, 255), (184, 111, 80, 255)
R1, R0 = (228, 59, 68, 255), (162, 38, 51, 255)
G1, G0 = (99, 199, 77, 255), (62, 137, 72, 255)
T0, T1, T2, T3 = (25, 60, 62, 255), (40, 70, 76, 255), (62, 104, 106, 255), (98, 148, 144, 255)
SCR_A, SCR_B = (28, 26, 44, 255), (33, 33, 54, 255)
CLEAR = (0, 0, 0, 0)
LED_OFF = (46, 40, 60, 255)

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
    for p in pts:
        px[p] = c


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def rings(w, h, spec, body, pattern=None):
    """spec: 바깥부터 (위·왼 색, 아래·오른 색). 모서리 홈 포함."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < len(spec):
                tl, br = spec[d]
                px[x, y] = br if (x == w - 1 - d or y == h - 1 - d) else tl
            else:
                px[x, y] = (pattern(x, y) if pattern else None) or body
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px[x, y] = CLEAR
    for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        px[x, y] = K0
    return img


def screw(img, x, y):
    put(img, [(x, y)], S5)
    put(img, [(x + 1, y), (x, y + 1)], S3)
    put(img, [(x + 1, y + 1)], S1)


def scan(x, y):
    return SCR_A if y % 2 == 0 else SCR_B


# LED 깜빡임 패턴 (8프레임) — 팩처럼 서로 엇갈리게
BLINK = {
    "steady": [1, 1, 1, 0, 1, 1, 1, 1],
    "half": [1, 0, 1, 0, 1, 0, 1, 0],
    "activity": [1, 1, 0, 1, 0, 0, 1, 0],
    "slow": [1, 1, 1, 1, 0, 0, 0, 0],
}


def led(img, x, y, on, color):
    put(img, [(x, y)], color if on else LED_OFF)


# ── 1. 판 (단말기 본체 + 파인 화면) 32×32 · cap 12 · 8프레임 ─────────────
def panel(frame):
    img = rings(32, 32, [(K0, K0), (S4, S2), (S3, S3), (S3, S3), (S1, S4), (K0, K0)], SCR_A, scan)
    for (x, y) in ((3, 3), (27, 3), (3, 27), (27, 27)):
        screw(img, x, y)
    put(img, [(6, 2), (6, 1)], S5)                                   # 왼쪽 위 모서리 빛
    for k, (pat, col) in enumerate((("steady", G1), ("half", A1), ("activity", C3))):
        led(img, 18 + k * 2, 2, BLINK[pat][frame], col)              # 상태 LED 셋 (위 cap)
    for x in range(8, 14, 2):                                         # 통풍 슬릿
        put(img, [(x, 2)], S2)
    rect(ImageDraw.Draw(img), 8, 29, 12, 29, S2)                      # 아래 명판
    put(img, [(8, 29)], S4)
    put(img, [(7, 7), (8, 7), (7, 8)], (52, 56, 86, 255))             # 화면 유리 반사
    return img


save_strip([panel(f) for f in range(F)], "hq_panel", 12,
           "판 — 단말기 본체(나사 4 · 통풍 슬릿 · 명판) + 파인 화면(주사선). 위 cap의 LED 셋이 엇갈려 깜빡임")


# ── 2. 타일 (작은 판) 24×24 · cap 9 ──────────────────────────────────
def tile(frame):
    img = rings(24, 24, [(K0, K0), (S4, S2), (S3, S3), (S1, S4), (K0, K0)], SCR_A, scan)
    screw(img, 2, 20)
    led(img, 20, 2, BLINK["slow"][frame], C3)
    put(img, [(5, 5), (6, 5), (5, 6)], (52, 56, 86, 255))
    return img


save_strip([tile(f) for f in range(F)], "hq_tile", 9, "작은 판 — 통계 숫자 칸 · 설정 줄. 오른쪽 위 시안 LED 천천히 깜빡")


# ── 3. 잔디 칸 0~4 + 오늘 칸(맥박) ───────────────────────────────────
HEAT = [(K0, S1), (C1, (30, 100, 160, 255)), ((10, 118, 180, 255), C2), (C2, (90, 200, 236, 255)), (C3, (180, 248, 252, 255))]


def heat(level, glow=0):
    img = Image.new("RGBA", (8, 8))
    d = ImageDraw.Draw(img)
    body, light = HEAT[level]
    rect(d, 0, 0, 7, 7, body)
    rect(d, 0, 0, 7, 0, light)
    rect(d, 0, 0, 0, 7, light)
    rect(d, 1, 7, 7, 7, K0 if level else S1)
    put(img, [(0, 0), (7, 0), (0, 7), (7, 7)], CLEAR)
    if level == 0:
        put(img, [(3, 3), (4, 4)], S2)
    if level == 4:
        put(img, [(2, 2)], W)
    if glow:
        for x in range(8):
            for y in range(8):
                r, g, b, a = img.getpixel((x, y))
                if a:
                    img.putpixel((x, y), (min(255, r + glow), min(255, g + glow), min(255, b + glow), 255))
    return img


for lv in range(5):
    save_strip([heat(lv)], f"hq_heat_{lv}", None, f"잔디 칸 {lv}단계 (정지 1프레임)")
save_strip([heat(4, g) for g in (0, 10, 24, 40, 52, 40, 24, 10)], "hq_heat_today", None, "오늘 칸 — 밝기가 맥박처럼 오르내림 (8프레임)")


# ── 4. 통계 아이콘 24px · 8프레임 ─────────────────────────────────────
def outline(img, c=K0):
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if not src[x, y][3] and any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3]
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


def icon_cards(frame):          # 외운 단어: 카드 더미, 맨 위 카드에 글자가 한 줄씩 찍힘
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    rect(d, 5, 7, 20, 20, S3)
    rect(d, 4, 5, 19, 18, S4)
    rect(d, 2, 3, 17, 16, S5)
    rect(d, 2, 3, 17, 3, W)
    typed = frame + 1                                                  # 1~8칸
    rows = [(5, 4), (8, 4), (11, 4)]
    left = typed
    for y, x0 in rows:
        n = min(left, 4)
        for k in range(n):
            rect(d, x0 + k * 3, y, x0 + k * 3 + 1, y, S2 if k else C1)
        left -= n
        if left <= 0:
            break
    if frame % 2 == 0:                                                 # 커서
        cx = 4 + (typed % 4) * 3 + 4
        put(img, [(min(cx, 15), rows[min(typed // 4, 2)][0])], C2)
    put(img, [(18, 18), (19, 18)], A1)                                 # 호박 책갈피
    return outline(img)


def icon_gauge(frame):          # 기억 유지율: 반원 계기판, 바늘이 92% 근처에서 떨림
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    d.pieslice([1, 3, 22, 24], 180, 360, fill=S2)
    d.pieslice([3, 5, 20, 22], 180, 360, fill=SCR_A)
    for a, col in ((200, R1), (240, A1), (290, G1), (330, C3)):        # 눈금
        x = 11.5 + 9 * math.cos(math.radians(a))
        y = 13.5 + 9 * math.sin(math.radians(a))
        put(img, [(round(x), round(y))], col)
    jitter = [0, 3, -2, 4, 1, -3, 2, 0][frame]
    ang = math.radians(180 + 166 + jitter)
    x1, y1 = 11.5 + 7.5 * math.cos(ang), 13.5 + 7.5 * math.sin(ang)
    d.line([(11.5, 13.5), (x1, y1)], fill=A2)
    rect(d, 10, 12, 13, 14, S4)
    rect(d, 2, 15, 21, 16, S3)
    return outline(img)


def icon_stopwatch(frame):      # 반응 시간: 초시계, 바늘이 한 바퀴 (8칸)
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    rect(d, 10, 1, 13, 3, S4)
    rect(d, 17, 3, 19, 5, S3)
    d.ellipse([2, 4, 21, 23], fill=S3)
    d.ellipse([4, 6, 19, 21], fill=S5)
    for k in range(8):
        a = math.radians(-90 + k * 45)
        put(img, [(round(11.5 + 6.5 * math.cos(a)), round(13.5 + 6.5 * math.sin(a)))], S3)
    a = math.radians(-90 + frame * 45)
    d.line([(11.5, 13.5), (11.5 + 5.5 * math.cos(a), 13.5 + 5.5 * math.sin(a))], fill=R1)
    put(img, [(11, 13), (12, 13), (11, 14), (12, 14)], K0)
    return outline(img)


def icon_counter(frame):        # 누적 평가: 기계식 계수기, 마지막 자리가 굴러감
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    rect(d, 1, 7, 22, 20, S3)
    rect(d, 1, 7, 22, 7, S4)
    rect(d, 9, 3, 13, 6, S4 if frame != 0 else S5)                     # 누름 단추 (첫 프레임 눌림)
    if frame == 0:
        rect(d, 9, 4, 13, 6, S4)
    for i, x in enumerate((3, 9, 15)):
        rect(d, x, 10, x + 4, 17, SCR_A)
        rect(d, x, 10, x + 4, 10, K0)
    DIG = {0: ["###", "#.#", "#.#", "#.#", "###"], 6: ["###", "#..", "###", "#.#", "###"],
           7: ["###", "..#", ".#.", ".#.", ".#."], 8: ["###", "#.#", "###", "#.#", "###"]}
    roll = [7, 7, 8, 8, 8, 8, 8, 8][frame]                             # 67 → 68 (+1)
    for x, dgt in ((4, 0), (10, 6), (16, roll)):
        for r, row in enumerate(DIG[dgt]):
            for c, v in enumerate(row):
                if v == "#":
                    put(img, [(x + c, 11 + r)], C3 if x == 16 else S5)
    if frame in (1, 2):                                                 # 굴러가는 중: 반쯤 걸친 줄
        rect(d, 16, 11, 18, 11, C2)
    return outline(img)


for name, fn, note in (("cards", icon_cards, "외운 단어 — 맨 위 카드에 글자가 한 칸씩 찍힘 + 커서"),
                       ("gauge", icon_gauge, "기억 유지율 — 계기판 바늘이 92% 근처에서 떨림"),
                       ("stopwatch", icon_stopwatch, "반응 시간 — 초시계 바늘 한 바퀴"),
                       ("counter", icon_counter, "누적 평가 — 계수기 단추가 눌리고 끝자리가 67→68로 굴러감")):
    save_strip([fn(f) for f in range(F)], f"hq_icon_{name}_24", None, note)


# ── 5. 평가 막대 (가로 9-slice 16×8 · cap 4) — 빛이 흘러가는 칸 ─────────────
LEVEL = {1: (R0, R1), 2: (A0, A1), 3: (T2, T3), 4: (C2, C3)}


def meter(level, frame):
    img = rings(16, 8, [(K0, K0), (S1, S2)], K0)
    base, hi = LEVEL[level]
    for x in range(2, 14):
        for y in range(2, 6):
            seg = (x % 3) != 1                                         # 3px마다 끊긴 칸
            if seg:
                put(img, [(x, y)], hi if y == 2 else base)
        if (x - frame) % 8 == 0:                                       # 흘러가는 빛 (주기 8 = 가운데 폭)
            for y in range(2, 6):
                if (x % 3) != 1:
                    put(img, [(x, y)], W if y == 2 else hi)
    return img


def meter_track():
    return rings(16, 8, [(K0, K0), (S1, S2)], K0, lambda x, y: S1 if (x % 3) != 1 and 2 <= y <= 5 else None)


save_strip([meter_track()], "hq_meter_track", 4, "평가 막대 빈 홈 (가로 9-slice)")
for lv in range(1, 5):
    save_strip([meter(lv, f) for f in range(F)], f"hq_meter_fill_{lv}", 4,
               f"평가 막대 채움 {lv}단계 색 — 3px 칸 + 8px마다 흐르는 빛 (8프레임)")


# ── 6. 팩 소품을 우리 톤으로 다시 칠함 (헤더 그림) ───────────────────────
RECOLOR = {(254, 174, 52): T3, (247, 118, 34): T2, (228, 166, 114): (146, 190, 180, 255), (215, 118, 67): T1,
           (190, 74, 47): T0, (184, 111, 80): T1, (194, 133, 105): T2}


def recolor(img):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in RECOLOR:
                px[x, y] = RECOLOR[(r, g, b)][:3] + (a,)
    return img


desk_strip = recolor(Image.open(PACK / "props_64/anim/desk_pc_r1.png").convert("RGBA"))
desk_strip.save(OUT / "from_pack" / "desk_pc_r1_teal.png")
fw = desk_strip.width // F
desk = [desk_strip.crop((i * fw, 0, (i + 1) * fw, desk_strip.height)) for i in range(F)]
manifest["from_pack/desk_pc_r1_teal"] = {"frame": [fw, desk_strip.height], "frames": F, "frame_ms": 150,
                                         "use": "Tech Lab desk_pc를 청록으로 다시 칠함 — 통계 헤더 그림 (git 제외)"}
(OUT / "njl_hq_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))


# ── 7. 시안 화면: 통계(판독 기록) 1장, 실제 비율 1px = 2pt ──────────────────
def strip_frames(name):
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


FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"   # 시안 미리보기 전용 (글꼴은 오너가 따로 정함)


def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=6 if bold else 0)


def text(img, xy, s, size, color, bold=False):
    d = ImageDraw.Draw(img)
    d.text(xy, s, font=font(size, bold), fill=color)


panels, tiles = strip_frames("hq_panel"), strip_frames("hq_tile")
today = strip_frames("hq_heat_today")
cells = [strip_frames(f"hq_heat_{i}")[0] for i in range(5)]
icons = {k: strip_frames(f"hq_icon_{k}_24") for k in ("cards", "gauge", "stopwatch", "counter")}
fills = {lv: strip_frames(f"hq_meter_fill_{lv}") for lv in range(1, 5)}
track = strip_frames("hq_meter_track")[0]
OS = OUT.parent / "njl_os"
signal = {lv: Image.open(OS / f"njl_signal_{lv}_16.png").convert("RGBA") for lv in range(1, 5)}
tabs = {k: Image.open(OS / f"njl_tab_{k}_{'selected' if k == 'records' else 'normal'}.png").convert("RGBA")
        for k in ("terminal", "institute", "records", "settings")}
ring_s = Image.open(OUT.parent / "njl_story" / "njl_tab_ring.png").convert("RGBA")
rings2 = [ring_s.crop((0, 0, 40, 40)), ring_s.crop((40, 0, 80, 40))]

rng = random.Random(5)
history = [0] * (14 * 7)                                              # 앞 10주 비어 있고 최근 몇 주만 띄엄띄엄 + 마지막 이틀 연속
for i in range(70, 96):
    history[i] = rng.choice([0, 0, 1, 1, 2, 3])
history[96], history[97] = 3, 4
TEXT, DIM = (226, 232, 240, 255), (139, 155, 180, 255)


def mock(f):
    img = Image.new("RGBA", (201, 437), (14, 14, 24, 255))
    d = ImageDraw.Draw(img)
    for y in range(0, 437, 6):                                          # 배경 점 격자
        for x in range(3, 201, 6):
            img.putpixel((x, y), (24, 24, 38, 255))
    img.alpha_composite(desk[f], (201 - fw - 2, 8))                      # 헤더 그림 (팩 소품, 다시 칠함)
    text(img, (10, 34), "판독 기록", 17, TEXT, bold=True)
    text(img, (10, 56), "NJL-OS // STATS", 8, C2)
    # 잔디 판
    img.alpha_composite(nine(panels[f], 12, 185, 98), (8, 100))
    text(img, (16, 106), "성실도 잔디", 9, TEXT, bold=True)
    text(img, (148, 106), "2일 연속", 8, A1)
    gx, gy = 22, 122
    for i, lv in enumerate(history):
        col, row = i // 7, i % 7
        cell = today[f] if i == len(history) - 1 else cells[lv]
        img.alpha_composite(cell, (gx + col * 11, gy + row * 9))
    # 숫자 칸 넷
    data = [("cards", "27/775", "외운 단어"), ("gauge", "92%", "기억 유지율"),
            ("stopwatch", "73.2초", "평균 반응 시간"), ("counter", "67회", "누적 평가")]
    for k, (key, val, label) in enumerate(data):
        x, y = 8 + (k % 2) * 94, 204 + (k // 2) * 56
        img.alpha_composite(nine(tiles[(f + k * 2) % F], 9, 91, 53), (x, y))
        img.alpha_composite(icons[key][f], (x + 7, y + 7))
        text(img, (x + 34, y + 8), val, 13, TEXT, bold=True)
        text(img, (x + 9, y + 35), label, 8, DIM)
    # 평가 기록
    img.alpha_composite(nine(panels[(f + 3) % F], 12, 185, 70), (8, 318))
    rows = [(1, "판독 불가", 15, 22), (2, "흐림", 10, 15), (3, "판독", 39, 58), (4, "선명", 3, 4)]
    for i, (lv, name, n, pct) in enumerate(rows):
        y = 328 + i * 14
        img.alpha_composite(signal[lv], (16, y - 2))
        text(img, (35, y), name, 8, TEXT)
        img.alpha_composite(nine(track, 4, 80, 8), (78, y + 1))
        img.alpha_composite(nine(fills[lv][f], 4, max(10, round(80 * pct / 100)), 8), (78, y + 1))
        text(img, (164, y), f"{n}회", 8, DIM)
    # 탭바
    img.alpha_composite(nine(panels[(f + 5) % F], 12, 185, 40), (8, 392))
    for i, key in enumerate(("terminal", "institute", "records", "settings")):
        img.alpha_composite(tabs[key], (24 + i * 44, 400))
    img.alpha_composite(rings2[0 if f % 4 < 2 else 1], (24 + 2 * 44 - 8, 392))
    return img


frames = [mock(f) for f in range(F)]
big = [fr.resize((fr.width * 2, fr.height * 2), Image.NEAREST) for fr in frames]
big[0].save(PREV / "preview_hq_stats_mock.gif", save_all=True, append_images=big[1:], duration=150, loop=0, disposal=2)
big[0].save(PREV / "preview_hq_stats_mock.png")
# 부품 확대 시트 (8프레임 전부)
names = [n for n in manifest if not n.startswith("from_pack")]
rowh = [manifest[n]["frame"][1] for n in names]
sheet = Image.new("RGBA", (8 * 36 + 120, sum(max(h, 10) + 6 for h in rowh) + 6), (30, 30, 44, 255))
y = 4
for n, h in zip(names, rowh):
    s = Image.open(OUT / f"{n}.png").convert("RGBA")
    w = manifest[n]["frame"][0]
    for i in range(s.width // w):
        sheet.alpha_composite(s.crop((i * w, 0, (i + 1) * w, h)), (4 + i * 36, y))
    ImageDraw.Draw(sheet).text((4 + 8 * 36 + 4, y), n.replace("hq_", ""), fill=(200, 204, 214, 255))
    y += max(h, 10) + 6
sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(PREV / "preview_hq_parts_x3.png")
print(len(manifest), "parts")
