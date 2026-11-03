"""레트로 단말 UI 키트 v2.3 — 나머지 부품 + 화면 시안. usage: retro_ui_more.py <out_dir> <preview_dir>

retro_ui.py의 부품 · 도구(모니터 · 키캡 · 노멀맵 · 조명 · Scene)를 그대로 불러 씀 (그 파일의 시안 부분은 건너뜀).
새 부품: 명판 칩 · LCD 입력란 · 영수증 토스트 · 레일 스크롤 · 페이더 · 피아노 키 세그먼트 · 글리프 · 넘버 시계 · 계기판 ·
         음성 파동 · 형광 해 · 인터콤 대사창 · 초상 CRT · 클립보드 · 체크칸 · 경고 모니터 · 글리치 · 부팅 로고 · 탭 강조.
기준: Docs/Art/StyleRef/ART_BIBLE.md §6~8.
"""
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).parent
_src = (HERE / "retro_ui.py").read_text()
_src = _src[:_src.index("# 통계: 길게 스크롤되는 화면")]
sys.argv = [str(HERE / "retro_ui.py"), sys.argv[1], sys.argv[2]]
exec(compile(_src, str(HERE / "retro_ui.py"), "exec"))                     # noqa: S102 — 우리 저장소의 스크립트

from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

WOOD = [hx("3A2420"), hx("5B3330"), hx("774C44"), hx("AE7155"), hx("C4A078"), hx("DDBE94")]
METAL = [hx("2A2C30"), hx("484C52"), hx("6C7076"), hx("94989C"), hx("BEC2C2"), hx("E6E8E2")]
PAPER_INK = (40, 28, 30, 255)
LCD_BG, LCD_DOT = hx("1A3420"), hx("234A2C")
CYAN, CYAN_D = hx("2CE8F5"), hx("0A7A86")


# ── 1. 공통 부품 ─────────────────────────────────────────────────
def plate(ramp, w=40, h=24, screws=True):
    """엠보싱 명판 · 칩 (9-slice cap [8,8,8,8]): 둥근 금속/플라스틱 판 + 네 모서리 나사."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    box = (0, 0, w, h, 4)
    for y in range(h):
        for x in range(w):
            d = sdf(x, y, *box)
            if d > 0:
                continue
            if d > -1.2:
                px[x, y] = INK
            elif d > -3:
                nx, ny = normal(x, y, box)
                px[x, y] = ramp_pick(ramp, max(-1, min(1, -(nx * L[0] + ny * L[1]) * 1.3)))
            else:
                px[x, y] = ramp[3]
    if screws:
        for sx, sy in ((3, 3), (w - 5, 3), (3, h - 5), (w - 5, h - 5)):
            put(img, [(sx, sy)], ramp[5])
            put(img, [(sx + 1, sy), (sx, sy + 1)], ramp[2])
            put(img, [(sx + 1, sy + 1)], ramp[0])
    return img


save(plate(CREAM), "rt_plate_cream", [8, 8, 8, 8], "크림 명판 칩 (9-slice) — 나사 넷 · 둥근 볼록 테. 글자는 짙은 갈색")
save(plate(METAL), "rt_plate_metal", [8, 8, 8, 8], "금속 명판 (9-slice) — 이름표 · 배지")
save(plate(AMBERK, screws=False), "rt_plate_amber", [8, 8, 8, 8], "호박 강조 칩 (나사 없음) — 연속 일수 · 새 소식")


def lcd_field(focused):
    """파인 LCD 입력란 (9-slice [8,8,8,8]): 어두운 녹색 액정 + 점 격자(주기 2)."""
    w, h = 32, 28
    img = Image.new("RGBA", (w, h))
    px = img.load()
    box = (0, 0, w, h, 4)
    inner = (4, 4, w - 4, h - 4, 2)
    for y in range(h):
        for x in range(w):
            d = sdf(x, y, *box)
            if d > 0:
                continue
            di = sdf(x, y, *inner)
            if d > -1.2:
                px[x, y] = INK
            elif di > 0:
                nx, ny = normal(x, y, inner)
                px[x, y] = ramp_pick(CREAM, -(nx * -L[0] + ny * -L[1]))       # 파인 테 (빛 반대)
            elif di > -1:
                px[x, y] = INK_DEEP
            else:
                px[x, y] = LCD_DOT if (x % 2 == 0 and y % 2 == 0) else LCD_BG
    if focused:
        for x in range(6, w - 6):
            put(img, [(x, h - 7)], PH[2])
    return img


save(lcd_field(False), "rt_lcd_field", [8, 8, 8, 8], "LCD 입력란 (9-slice) — 파인 테 · 녹색 액정 점 격자")
save(lcd_field(True), "rt_lcd_field_focus", [8, 8, 8, 8], "LCD 입력란 입력 중 — 아래 녹색 밑줄 (커서는 rt_cursor)")


def receipt():
    """영수증 토스트 (세로 9-slice [6,6,10,6]): 감열지 + 아래 톱니 가장자리 + 위 그림자(프린터 입구)."""
    w, h = 40, 36
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    rect(d, 1, 0, w - 2, h - 5, (246, 242, 230, 255))
    for x in range(1, w - 1):
        tooth = 2 - abs((x % 4) - 2)
        rect(d, x, h - 5, x, h - 5 + tooth, (246, 242, 230, 255))
    rect(d, 1, 0, w - 2, 2, (200, 194, 180, 255))
    put(img, [(0, y) for y in range(h - 4)] + [(w - 1, y) for y in range(h - 4)], (180, 172, 156, 255))
    return outline_px(img)


save(receipt(), "rt_receipt", [6, 6, 10, 6], "영수증 토스트 (9-slice) — 프린터에서 나오는 감열지, 아래 톱니. 글자는 짙은 회색 고딕")


def printer_slot():
    img = Image.new("RGBA", (60, 14))
    d = ImageDraw.Draw(img)
    for y in range(14):
        for x in range(60):
            dd = sdf(x, y, 0, 0, 60, 14, 4)
            if dd <= 0:
                img.putpixel((x, y), INK if dd > -1.2 else (PUTTY[4] if y < 4 else PUTTY[3]))
    rect(d, 8, 7, 51, 9, INK_DEEP)
    rect(d, 8, 10, 51, 10, PUTTY[1])
    put(img, [(54, 5), (55, 5)], PH[3])
    return img


save(printer_slot(), "rt_printer_slot", None, "토스트용 작은 프린터 입구 (60×14) — 영수증이 여기서 내려옴")


def rail(knob=False):
    if knob:
        img = Image.new("RGBA", (12, 28))
        d = ImageDraw.Draw(img)
        rect(d, 0, 0, 11, 27, INK)
        rect(d, 1, 1, 10, 26, METAL[3])
        rect(d, 1, 1, 10, 1, METAL[5])
        rect(d, 1, 1, 1, 26, METAL[4])
        rect(d, 10, 1, 10, 26, METAL[1])
        for y in (9, 13, 17):
            rect(d, 3, y, 8, y, METAL[1])
        return img
    img = Image.new("RGBA", (12, 24))
    d = ImageDraw.Draw(img)
    rect(d, 3, 0, 8, 23, INK)
    rect(d, 4, 0, 7, 23, INK_DEEP)
    rect(d, 7, 0, 7, 23, CHAR[2])
    return img


save(rail(), "rt_rail", [4, 0, 4, 0], "스크롤 표시 레일 (세로 9-slice) — 오른쪽 가장자리의 금속 홈")
save(rail(True), "rt_rail_knob", None, "레일 손잡이 12×28 — 미끄럼 방지 홈")


def fader(knob=False):
    if knob:
        img = Image.new("RGBA", (22, 30))
        d = ImageDraw.Draw(img)
        rect(d, 2, 4, 21, 29, (14, 9, 12, 110))
        rect(d, 0, 0, 19, 25, INK)
        rect(d, 1, 1, 18, 24, CHAR[3])
        rect(d, 1, 1, 18, 3, CHAR[4])
        rect(d, 1, 21, 18, 24, CHAR[1])
        rect(d, 1, 12, 18, 12, CREAM[4])                                  # 가운데 흰 줄
        return img
    img = Image.new("RGBA", (24, 14))
    d = ImageDraw.Draw(img)
    rect(d, 0, 4, 23, 9, INK)
    rect(d, 0, 5, 23, 8, INK_DEEP)
    rect(d, 0, 8, 23, 8, CHAR[2])
    for x in range(0, 24, 6):
        rect(d, x, 0, x, 2, CREAM[2])
        rect(d, x, 11, x, 13, CREAM[2])
    return img


save(fader(), "rt_fader_track", [0, 6, 0, 6], "페이더 홈 (가로 9-slice) — 눈금 6px마다 (슬라이더)")
save(fader(True), "rt_fader_knob", None, "페이더 손잡이 22×30 — 숯색 + 흰 기준선")
for st in ("normal", "pressed"):
    save(keycap(CREAM, pressed=st == "pressed", w=28, h=40), f"rt_piano_{st}", [10, 8, 16, 8],
         f"피아노 키 세그먼트 칸 {st} (9-slice) — 여러 개를 붙여 세그먼트(시간대 · 급수 고르기)")


GLYPHS = {
    "play": ["..........", ".##.......", ".####.....", ".######...", ".########.", ".######...", ".####.....", ".##......."],
    "eye": ["..........", "...####...", ".##....##.", "#...##...#", "#..####..#", ".##.##.##.", "...####...", ".........."],
    "speaker": ["....#.....", "...##.....", "####..#...", "####...#..", "####...#..", "####..#...", "...##.....", "....#....."],
    "back": ["...#......", "..##......", ".#########", "##########", ".#########", "..##......", "...#......", ".........."],
    "check": ["........##", ".......##.", "......##..", "#....##...", "##..##....", ".####.....", "..##......", ".........."],
}


def glyph(name, color, scale=2):
    rows = GLYPHS[name]
    img = Image.new("RGBA", (len(rows[0]) * scale, len(rows) * scale))
    d = ImageDraw.Draw(img)
    for r, row in enumerate(rows):
        for c, v in enumerate(row):
            if v == "#":
                rect(d, c * scale, r * scale, c * scale + scale - 1, r * scale + scale - 1, color)
    return img


for g in GLYPHS:
    save(glyph(g, CREAM[0]), f"rt_glyph_{g}", None, f"키캡에 찍는 글리프 {g} (20×16, 짙은 크림) — 형광판은 코드가 색만 바꿈")


# ── 2. 넘버 시계 · 계기판 · 음성 파동 · 형광 해 ───────────────────────────
DIGITS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"], "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
}


def flip_card(ch, flap=0):
    """넘버 시계 한 칸 24×34: 위 반쪽(밝음) · 가운데 경첩 · 아래 반쪽. flap 1~3 = 위 날개가 넘어가는 중."""
    img = Image.new("RGBA", (24, 34))
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 23, 33, INK)
    rect(d, 1, 1, 22, 16, CHAR[2])
    rect(d, 1, 17, 22, 32, CHAR[1])
    rect(d, 1, 1, 22, 1, CHAR[4])
    for r, row in enumerate(DIGITS[ch]):
        for c, v in enumerate(row):
            if v == "1":
                y = 4 + r * 4
                rect(d, 5 + c * 3, y, 7 + c * 3, y + 2, CREAM[4] if y < 16 else CREAM[3])
    rect(d, 1, 16, 22, 17, INK_DEEP)                                      # 경첩
    put(img, [(0, 16), (23, 16)], METAL[3])
    if flap:
        h = [0, 10, 5, 1][flap]
        rect(d, 1, 16 - h, 22, 16, CHAR[3] if flap < 3 else CHAR[4])
        rect(d, 1, 16 - h, 22, 16 - h, CHAR[5])
    return img


for ch in DIGITS:
    save(flip_card(ch), f"rt_flip_{'dash' if ch == '-' else ch}", None, f"넘버 시계 칸 「{ch}」 24×34")
save([flip_card("3", k) for k in (1, 2, 3)], "rt_flip_flap", None, "넘버 시계 넘어가는 날개 3프레임 (숫자 칸 위에 얹어 씀)")


def gauge(f):
    img = Image.new("RGBA", (72, 44))
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 71, 43, INK)
    rect(d, 1, 1, 70, 42, CHAR[2])
    d.pieslice([6, 6, 65, 65], 180, 360, fill=CREAM[4])
    d.arc([6, 6, 65, 65], 180, 360, fill=INK)
    d.arc([12, 12, 59, 59], 300, 360, fill=REDK[3], width=3)              # 빨간 구간 (부족)
    for k in range(11):
        a = math.radians(180 + k * 18)
        x0, y0 = 35.5 + 27 * math.cos(a), 35.5 + 27 * math.sin(a)
        x1, y1 = 35.5 + (23 if k % 5 else 20) * math.cos(a), 35.5 + (23 if k % 5 else 20) * math.sin(a)
        d.line([(x0, y0), (x1, y1)], fill=CHAR[1])
    jit = [0, 2, -1, 3, 1, -2, 2, 0][f]
    a = math.radians(180 + 138 + jit)                                       # 33/43 ≈ 77%
    d.line([(35.5, 35.5), (35.5 + 24 * math.cos(a), 35.5 + 24 * math.sin(a))], fill=REDK[2], width=2)
    disc(img, 35.5, 35.5, 3.5, CHAR)
    rect(d, 1, 36, 70, 42, CHAR[2])
    rect(d, 1, 36, 70, 36, CHAR[3])
    for k in range(6):                                                      # 유리 반사
        put(img, [(10 + k, 9 + k // 3)], (255, 255, 255, 90))
    return img


save([gauge(f) for f in range(F)], "rt_gauge", None, "아날로그 계기판 72×44 — 바늘이 떨림, 빨간 부족 구간 (학습 속도)")


def wave(f):
    img = Image.new("RGBA", (16, 20))
    d = ImageDraw.Draw(img)
    for k in range(3):
        if (f // 2) % 4 > k:
            r = 4 + k * 4
            d.arc([-r, 10 - r, r, 10 + r], 300, 60, fill=PH[3] if k < 2 else PH[2])
    return img


save([wave(f) for f in range(F)], "rt_audio_wave", None, "음성 단추 옆 소리 파동 16×20 — 호가 하나씩 퍼짐")


def sun(f):
    img = Image.new("RGBA", (64, 64))
    d = ImageDraw.Draw(img)
    for k in range(12):
        a = math.radians(k * 30 + f * 3.75)
        ln = 28 if (k + f // 2) % 2 == 0 else 23
        d.line([(31.5 + 16 * math.cos(a), 31.5 + 16 * math.sin(a)), (31.5 + ln * math.cos(a), 31.5 + ln * math.sin(a))],
               fill=PH[3] if k % 2 else PH[2], width=2)
    d.ellipse([18, 18, 45, 45], fill=PH[4])
    d.ellipse([22, 22, 41, 41], fill=hx("E8FFDC"))
    for y in range(18, 46, 3):                                              # 주사선
        d.line([(16, y), (47, y)], fill=(0, 0, 0, 40))
    return img


save([sun(f) for f in range(F)], "rt_phosphor_sun", None, "晴れる 형광 해 64×64 — 빛살이 천천히 돌고 번갈아 길어짐")


# ── 3. 스토리 UI ─────────────────────────────────────────────────
def grille_right(img, fx0, fx1, w, h):
    d = ImageDraw.Draw(img)
    for y in range(12, h - 10):
        for x in range(fx1 - 16, fx1 - 5):
            if (x + y) % 2 == 0 and y % 2 == 0:
                put(img, [(x, y)], PUTTY[1])                               # 스피커 구멍 (주기 2)
    rect(d, fx1 - 16, h - 9, fx1 - 6, h - 8, PUTTY[2])


dlg = monitor(PUTTY, (16, 100, 18, 26), (10, 94, 12, 20), 8, column=grille_right, seed=21)
dlg = add_top(dlg, PUTTY, 5)
save(dlg, "rt_dialog_body", [21, 100, 18, 26], "인터콤 대사창 (9-slice) — 왼쪽 98px = 초상 CRT 자리, 오른쪽 스피커 구멍, 가운데 녹색 글자 화면")


def portrait_crt():
    """초상 CRT 84×88 — 가운데 64×64 구멍(투명)에 초상을 깔고 이 틀을 얹음."""
    w, h = 84, 88
    base = nine(monitor(CREAM, (12, 12, 16, 12), (10, 10, 14, 10), 6, seed=23), [12, 12, 16, 12], w, h)
    px = base.load()
    for y in range(10, 74):
        for x in range(10, 74):
            if sdf(x, y, 10, 10, 74, 74, 3) < -1:
                px[x, y] = (0, 0, 0, 0)
    return add_top(base, CREAM, 4)


save(portrait_crt(), "rt_portrait_crt", None, "초상 CRT 84×92 — 64×64 구멍(10,14부터)에 초상, 위에 rt_scanline_overlay")
so = Image.new("RGBA", (64, 64))
for y in range(0, 64, 2):
    ImageDraw.Draw(so).line([(0, y), (63, y)], fill=(10, 30, 16, 60))
for k in range(10):
    so.putpixel((4 + k, 3 + k // 4), (220, 255, 220, 70))
save(so, "rt_scanline_overlay", None, "초상 위 주사선 + 반사 64×64 (반투명)")


def clipboard():
    w, h = 40, 48
    img = Image.new("RGBA", (w, h))
    px = img.load()
    box = (0, 0, w, h, 5)
    for y in range(h):
        for x in range(w):
            d = sdf(x, y, *box)
            if d > 0:
                continue
            if d > -1.2:
                px[x, y] = INK
            elif d > -3:
                nx, ny = normal(x, y, box)
                px[x, y] = ramp_pick(WOOD, max(-1, min(1, -(nx * L[0] + ny * L[1]) * 1.3)))
            else:
                px[x, y] = WOOD[3] if (y * 3 + x // 7) % 11 else WOOD[2]      # 나뭇결
    return img


save(clipboard(), "rt_clipboard", [14, 12, 12, 12], "퀘스트 클립보드 (9-slice) — 나무판. 위에 종이(rt_paper) · 집게(rt_clip)")


def clip():
    img = Image.new("RGBA", (44, 18))
    d = ImageDraw.Draw(img)
    rect(d, 4, 4, 39, 15, METAL[2])
    rect(d, 4, 4, 39, 6, METAL[4])
    rect(d, 4, 13, 39, 15, METAL[1])
    rect(d, 14, 0, 29, 5, METAL[3])
    rect(d, 17, 1, 26, 3, METAL[1])
    rect(d, 2, 8, 41, 10, METAL[3])
    return outline_px(img)


save(clip(), "rt_clip", None, "클립보드 집게 44×18 (금속)")


def checkbox(done):
    img = Image.new("RGBA", (14, 14))
    d = ImageDraw.Draw(img)
    d.rectangle([1, 2, 11, 12], outline=(70, 60, 60, 255))
    d.line([(1, 2), (12, 1)], fill=(70, 60, 60, 255))                     # 연필로 그린 듯 살짝 비뚤
    if done:
        d.line([(3, 7), (6, 10), (13, 1)], fill=REDK[2], width=2)
    return img


save(checkbox(False), "rt_checkbox", None, "연필 체크칸 (빈 칸)")
save(checkbox(True), "rt_checkbox_done", None, "연필 체크칸 + 빨간 체크")


def warn_column(img, fx0, fx1, w, h):
    d = ImageDraw.Draw(img)
    for x in range(fx0 + 10, fx1 - 10):                                    # 위 턱 경고 띠 (주기 8)
        for y in range(2, 6):
            put(img, [(x, y)], REDK[3] if (x + y) % 8 < 4 else INK)


wm = monitor(CHAR, (16, 16, 18, 16), (10, 10, 12, 10), 8, chin=None, column=warn_column, seed=31)
wm = add_top(wm, CHAR, 5)
save(wm, "rt_warning_monitor", [21, 16, 18, 16], "경고 모니터 (9-slice) — 숯색 몸체 + 위 빨강/검정 사선 띠. 바깥 세계(뉴럴링크) 경고")


def glitch(f):
    img = Image.new("RGBA", (64, 64))
    rng = random.Random(f * 7)
    d = ImageDraw.Draw(img)
    for _ in range(4 + f % 3):
        y = rng.randint(0, 60)
        hgt = rng.randint(1, 4)
        x0 = rng.randint(-10, 40)
        d.rectangle([x0, y, x0 + rng.randint(10, 40), y + hgt], fill=CYAN + (0,) if False else (CYAN[0], CYAN[1], CYAN[2], rng.randint(60, 150)))
    for _ in range(18):
        img.putpixel((rng.randint(0, 63), rng.randint(0, 63)), (255, 90, 80, 160))
    return img


save([glitch(f) for f in range(F)], "rt_glitch", None, "글리치 겹침 64×64 (타일) — 시안 띠가 어긋나고 빨간 점 노이즈 (렉스코드 침입)")

LOGO = {"N": ["10001", "11001", "10101", "10011", "10001"], "J": ["00111", "00010", "00010", "10010", "01100"],
        "L": ["10000", "10000", "10000", "10000", "11111"], "O": ["01110", "10001", "10001", "10001", "01110"],
        "S": ["01111", "10000", "01110", "00001", "11110"], "-": ["00000", "00000", "01110", "00000", "00000"]}


def boot_logo():
    txt = "NJL-OS"
    pitch = 4
    img = Image.new("RGBA", (len(txt) * 6 * pitch + 8, 5 * pitch + 8))
    d = ImageDraw.Draw(img)
    for i, ch in enumerate(txt):
        for r, row in enumerate(LOGO[ch]):
            for c, v in enumerate(row):
                x, y = 4 + (i * 6 + c) * pitch, 4 + r * pitch
                col = (PH[4] if i < 3 else AM) if v == "1" else hx("123A20")
                rect(d, x, y, x + 2, y + 2, col)
    glow = img.filter(ImageFilter.GaussianBlur(2.5))
    glow.putalpha(glow.getchannel("A").point(lambda a: int(a * 0.6)))
    out = Image.new("RGBA", img.size)
    out.alpha_composite(glow)
    out.alpha_composite(img)
    return out


save(boot_logo(), "rt_boot_logo", None, "부팅 로고 「NJL-OS」 도트 매트릭스 (꺼진 점까지 · 번짐)")


def ring(f):
    w, h = 104, 78
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    on = f % 4 < 2
    c = PH[4] if on else PH[2]
    ins = 0 if on else 2
    for (x, y, sx, sy) in ((ins, ins, 1, 1), (w - 1 - ins, ins, -1, 1), (ins, h - 1 - ins, 1, -1), (w - 1 - ins, h - 1 - ins, -1, -1)):
        d.line([(x, y), (x + sx * 12, y)], fill=c, width=2)
        d.line([(x, y), (x, y + sy * 12)], fill=c, width=2)
    if on:
        g = img.filter(ImageFilter.GaussianBlur(2))
        g.putalpha(g.getchannel("A").point(lambda a: int(a * 0.7)))
        g.alpha_composite(img)
        img = g
    return img


save([ring(f) for f in range(F)], "rt_tab_ring", None, "탭 강조 꺾쇠 104×78 — 형광 녹색, 깜빡이며 2px 오므라듦 (탭 키 둘레)")


def pointer(f):
    img = Image.new("RGBA", (20, 20))
    d = ImageDraw.Draw(img)
    dy = [0, 1, 2, 3, 3, 2, 1, 0][f]
    d.polygon([(2, 2 + dy), (17, 2 + dy), (9, 12 + dy), (10, 12 + dy)], fill=AMBERK[4])
    d.line([(3, 3 + dy), (15, 3 + dy)], fill=AMBERK[5])
    return outline_px(img)


save([pointer(f) for f in range(F)], "rt_pointer", None, "탭 위 안내 화살표 20×20 — 3px 통통 (호박)")

(OUT / "retro_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
for n in ("rt_plate_cream", "rt_plate_metal", "rt_plate_amber", "rt_lcd_field", "rt_receipt", "rt_printer_slot", "rt_rail_knob",
          "rt_fader_knob", "rt_piano_normal", "rt_piano_pressed", "rt_dialog_body", "rt_portrait_crt", "rt_clipboard", "rt_clip",
          "rt_warning_monitor", "rt_gauge"):
    auto_normal(frames_of(n)[0]).save(OUT / f"{n}_n.png")
    manifest[n]["normal"] = f"{n}_n.png"
(OUT / "retro_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
print("parts", len(manifest))


# ── 4. 화면 시안 ─────────────────────────────────────────────────
GOTHIC = FONT
bundle = frames_of("rt_cable_bundle_v")[0]
ivyf = frames_of("rt_ivy_curtain_200")
dangle, loop_a, loop_c, coilf = (frames_of(n)[0] for n in ("rt_cable_dangle_b", "rt_cable_loop_a", "rt_cable_loop_c", "rt_cable_coil"))
cursor = frames_of("rt_cursor")
ledbars = {lv: frames_of(f"rt_ledbar_{lv}") for lv in range(1, 5)}


def base_scene():
    sc = Scene(402, 874, wall(402, 874))
    for y in range(-20, 874, 64):
        sc.c.alpha_composite(bundle, (-8, y))
        sc.c.alpha_composite(bundle.transpose(Image.FLIP_LEFT_RIGHT), (380, y + 30))
    return sc


def finish(out, f, tab, ivy=True):
    if ivy:
        out.alpha_composite(ivyf[f], (-20, -40))
        out.alpha_composite(ivyf[(f + 4) % F].transpose(Image.FLIP_LEFT_RIGHT), (222, -50))
    vignette(out, 175)
    out.alpha_composite(coilf, (318, 764))
    tabbar(out, f, tab)
    return out


def text(img, xy, s, size, color, bold=True, font=None):
    ImageDraw.Draw(img).text(xy, s, font=ImageFont.truetype(font or GOTHIC, size, index=(6 if bold else 0) if font is None else 0), fill=color)


def key_at(img, ramp, x, y, w, h, pressed=False, shadow=True):
    if shadow:
        shadow_under(img, x, y, w, h, 140)
    img.alpha_composite(nine(keycap(ramp, pressed=pressed), [10, 10, 16, 10], w, h), (x, y))
    return 4 if pressed else 0


def flip_row(img, x, y, s, flap_on_last=0):
    for i, ch in enumerate(s):
        img.alpha_composite(frames_of(f"rt_flip_{'dash' if ch == '-' else ch}")[0], (x + i * 26, y))
    if flap_on_last:
        img.alpha_composite(frames_of("rt_flip_flap")[flap_on_last - 1], (x + (len(s) - 1) * 26, y))


def save_gif(frames, name, ms=130, still=0):
    frames[0].save(PREV / f"{name}.gif", save_all=True, append_images=frames[1:], duration=ms, loop=0, disposal=2)
    frames[still].save(PREV / f"{name}.png")


# M1 학습 대시보드
def dashboard(i):
    f = i % F
    sc = base_scene()
    r = monitor_at(sc, "rt_monitor_term_turned_right", f, 18, 30, 236, 120, 40)
    glow_text(sc.c, (r[0] + 2, r[1] + 2), "오늘의 판독", 24, PH[3])
    if f < 4:
        sc.c.alpha_composite(cursor[0].resize((10, 22), Image.NEAREST), (r[0] + 140, r[1] + 7))
    glow_text(sc.c, (r[0] + 2, r[1] + 36), "第一章 · N2 목표", 11, PH[2], bold=False)
    code_at(sc, "rt_code_term_b", f, 258, 40)
    shadow_under(sc.c, 14, 168, 214, 96)                                    # 시험까지 넘버 시계
    sc.put(nine(frames_of("rt_plate_metal")[0], [8, 8, 8, 8], 214, 96), (14, 168))
    text(sc.c, (28, 178), "시험까지", 12, METAL[0])
    flip_row(sc.c, 30, 200, "D-33", flap_on_last=(i % 16 - 12) if 13 <= i % 16 <= 15 else 0)
    text(sc.c, (148, 236), "2026.12.06", 10, METAL[1], bold=False)
    shadow_under(sc.c, 236, 172, 154, 92)                                   # 계기판
    sc.put(nine(frames_of("rt_plate_cream")[0], [8, 8, 8, 8], 154, 92), (236, 172))
    sc.c.alpha_composite(frames_of("rt_gauge")[f], (276, 182))
    text(sc.c, (248, 232), "판독 속도 33 / 43", 11, CREAM[0])
    r = monitor_at(sc, "rt_monitor_crt", f, 14, 282, 376, 160, 55)
    glow_text(sc.c, (r[0] + 2, r[1]), "오늘의 권장 판독량", 13, PH[2], bold=False)
    glow_text(sc.c, (r[0] + 2, r[1] + 18), "하루 43단어", 32, PH[4])
    glow_text(sc.c, (r[0] + 2, r[1] + 62), "● 조금만 속도를 올리면 시험일까지 완주해요", 12, AM, bold=False)
    for k, (lab, val, nm) in enumerate((("외운 단어", "27", "rt_monitor_term"), ("오늘 판독", "0", "rt_monitor_term_turned_left"),
                                        ("복습 대기", "24", "rt_monitor_term_turned_right"))):
        r = monitor_at(sc, nm, f, 12 + k * 128, 456 + [0, 5, 2][k], 124, 110, 30)
        glow_text(sc.c, (r[0] + 2, r[1]), lab, 10, PH[2], bold=False)
        glow_text(sc.c, (r[0] + 2, r[1] + 14), val, 24, PH[4])
    sc.put(loop_c, (120, 560))
    out = sc.lit(0.72)
    pressed = 18 <= i % 24 <= 19
    dy = key_at(out, AMBERK, 14, 600, 376, 74, pressed)
    play = glyph("play", AMBERK[0], 3)
    out.alpha_composite(play, (74, 624 + dy))
    text(out, (118, 622 + dy), "이어서 판독 시작", 20, AMBERK[0])
    code = frames_of("rt_code_industrial")[f]
    shadow_under(out, 96, 690, 200, 104)
    out.alpha_composite(code, (96, 690))
    return finish(out, f, 0)


save_gif([dashboard(i) for i in range(24)], "preview_retro_dashboard_mock", 120)
print("dashboard")


# M2 카드: 앞면 → 정답 보기 → 뒷면
sc_img = frames_of("rt_scanner")[0]
paper_img = frames_of("rt_paper")[0]
tape_img = frames_of("rt_tape")[0]
bars = frames_of("rt_scan_bar")


def card(i):
    f = i % F
    back = i >= 12
    sc = base_scene()
    x, y, w, h = 12, 40, 378, 500
    shadow_under(sc.c, x, y, w, h, 170)
    sc.put(nine(sc_img, sc_caps, w, h), (x, y))
    gx0, gy0, gx1, gy1 = x + 12, y + 19, x + w - 12, y + h - 26
    px0, py0, pw, ph = gx0 + 10, gy0 + 12, gx1 - gx0 - 26, gy1 - gy0 - 30
    shadow_under(sc.c, px0, py0, pw, ph, 120)
    sc.put(nine(paper_img, [14, 14, 14, 14], pw, ph), (px0, py0))
    sc.put(tape_img, (px0 - 6, py0 - 4), normal=False)
    sc.put(tape_img.transpose(Image.FLIP_LEFT_RIGHT), (px0 + pw - 16, py0 - 4), normal=False)
    ink = PAPER_INK
    text(sc.c, (px0 + 18, py0 + 16), "第一章 · 12 / 43" + ("  · 뒷면" if back else ""), 12, (120, 104, 96, 255), font=MYUNGJO)
    if back:
        text(sc.c, (px0 + 96, py0 + 46), "あきら", 14, (110, 92, 88, 255), font=MINCHO)
        text(sc.c, (px0 + 66, py0 + 64), "諦める", 52, ink, font=MINCHO)
        rect(ImageDraw.Draw(sc.c), px0 + 40, py0 + 140, px0 + pw - 40, py0 + 140, (190, 178, 156, 255))
        text(sc.c, (px0 + 60, py0 + 156), "단념하다 · 포기하다", 18, ink, font=MYUNGJO)
        text(sc.c, (px0 + 28, py0 + 222), "ゆめ", 9, (110, 92, 88, 255), font=MINCHO)
        text(sc.c, (px0 + 28, py0 + 232), "夢をあきらめるな。", 17, (70, 56, 54, 255), font=MINCHO)
        text(sc.c, (px0 + 28, py0 + 260), "꿈을 포기하지 마.", 14, (110, 96, 90, 255), font=MYUNGJO)
    else:
        text(sc.c, (px0 + 66, py0 + 84), "諦める", 52, ink, font=MINCHO)
        text(sc.c, (px0 + 28, py0 + 232), "夢をあきらめるな。", 17, (70, 56, 54, 255), font=MINCHO)
    sc.lights.append((330, -60, 160, (255, 220, 170), 1.0, 520))
    out = sc.lit(0.8)
    if back:                                                                 # 종이 모서리의 음성 단추
        rb = frames_of("rt_round_charcoal_" + ("pressed" if i in (16, 17) else "normal"))[0]
        out.alpha_composite(rb, (px0 + pw - 52, py0 + 54))
        out.alpha_composite(glyph("speaker", PH[3], 1), (px0 + pw - 42, py0 + 66 + (1 if i in (16, 17) else 0)))
        out.alpha_composite(frames_of("rt_audio_wave")[f], (px0 + pw - 20, py0 + 59))
    t = ((i % 12) / 11)
    by = int(py0 - 8 + t * (ph + 8))
    if (i < 10) or (12 <= i < 22):
        out.alpha_composite(nine(bars[f], [0, 0, 0, 0], pw + 20, 16), (px0 - 10, by))
        g = Image.new("RGBA", out.size)
        ImageDraw.Draw(g).rectangle([px0 - 10, by + 4, px0 + pw + 10, by + 12], fill=(140, 255, 170, 70))
        out.alpha_composite(g.filter(ImageFilter.GaussianBlur(8)))
    if not back:
        pressed = i in (10, 11)
        dy = key_at(out, CREAM, 70, 588, 262, 80, pressed)
        out.alpha_composite(glyph("eye", CREAM[0], 3), (112, 612 + dy))
        text(out, (156, 612 + dy), "정답 보기", 20, CREAM[0])
    else:
        labels = ["판독 불가", "흐림", "판독", "선명"]
        for k in range(4):
            pressed = (k == 2 and i in (21, 22))
            kx, ky = 14 + k * 95, 588 + [0, 4, 1, 3][k]
            dy = key_at(out, CHAR, kx, ky, 88, 92, pressed)
            out.alpha_composite(ledbars[k + 1][f].resize((44, 28), Image.NEAREST), (kx + 22, ky + 14 + dy))
            text(out, (kx + 12 + (8 if len(labels[k]) < 3 else 0), ky + 50 + dy), labels[k], 13, CREAM[4] if not pressed else PH[3])
    out.alpha_composite(dangle, (300, 690))
    return finish(out, f, 0)


save_gif([card(i) for i in range(24)], "preview_retro_card_flow", 140, still=14)
print("card")


# M3 세션 완료 — 晴れる
def complete(i):
    f = i % F
    sc = base_scene()
    r = monitor_at(sc, "rt_monitor_crt", f, 14, 40, 374, 330, 70)
    sun = frames_of("rt_phosphor_sun")[f].resize((128, 128), Image.NEAREST)
    sc.c.alpha_composite(sun, ((r[0] + r[2]) // 2 - 64, r[1] + 10))
    glow_text(sc.c, ((r[0] + r[2]) // 2 - 62, r[1] + 146), "晴れる", 40, PH[4], font=MINCHO)
    glow_text(sc.c, ((r[0] + r[2]) // 2 - 108, r[1] + 202), "흐릿하던 기억이 맑게 갰어요", 16, PH[3])
    for k, (lab, val) in enumerate((("오늘 외운 단어", "12개"), ("내일 다시 만날 단어", "5개"))):
        y0 = 392 + k * 58
        shadow_under(sc.c, 14, y0, 374, 48)
        sc.put(nine(frames_of("rt_plate_metal")[0], [8, 8, 8, 8], 374, 48), (14, y0))
        text(sc.c, (34, y0 + 14), lab, 15, METAL[0])
        text(sc.c, (300, y0 + 12), val, 18, METAL[0])
    sc.put(loop_a, (160, 500))
    out = sc.lit(0.72)
    sl = frames_of("rt_printer_slot")[0]                                      # 영수증: 프린터에서 내려옴
    out.alpha_composite(sl, (230, 520))
    hgt = min(120, max(12, (i % 24) * 9))
    rc = nine(frames_of("rt_receipt")[0], [6, 6, 10, 6], 48, hgt)
    out.alpha_composite(rc, (236, 530))
    if hgt > 60:
        text(out, (242, 534 + hgt - 70), "NJL-OS", 9, (90, 86, 80, 255))
        text(out, (242, 548 + hgt - 70), "판독 12", 9, (90, 86, 80, 255), bold=False)
        text(out, (242, 560 + hgt - 70), "+연구P 18", 9, (90, 86, 80, 255), bold=False)
    dy = key_at(out, AMBERK, 14, 664, 200, 70, 20 <= i % 24 <= 21)
    out.alpha_composite(glyph("back", AMBERK[0], 2), (36, 691 + dy))
    text(out, (70, 686 + dy), "학습 요약으로", 17, AMBERK[0])
    return finish(out, f, 0)


save_gif([complete(i) for i in range(24)], "preview_retro_complete_mock", 120, still=16)
print("complete")


# M4 설정 v2
def settings(i):
    f = i % F
    sc = base_scene()
    r = monitor_at(sc, "rt_monitor_term", f, 18, 30, 236, 120, 40)
    glow_text(sc.c, (r[0] + 2, r[1] + 2), "단말 설정", 24, PH[3])
    if f < 4:
        sc.c.alpha_composite(cursor[0].resize((10, 22), Image.NEAREST), (r[0] + 118, r[1] + 7))
    glow_text(sc.c, (r[0] + 2, r[1] + 36), "NJL-OS 2.94 · CONFIG", 11, PH[2], bold=False)
    r = monitor_at(sc, "rt_monitor_crt_turned", f, 12, 160, 384, 176, 50)
    glow_text(sc.c, (r[0] + 2, r[1]), "목표", 12, PH[2], bold=False)
    glow_text(sc.c, (r[0] + 2, r[1] + 16), "JLPT N2", 28, PH[3])
    flip_row(sc.c, r[2] - 112, r[1] + 6, "D-33")
    r2 = monitor_at(sc, "rt_monitor_industrial", f, 12, 344, 384, 230, 45)
    glow_text(sc.c, (r2[0] + 2, r2[1]), "날씨", 12, PH[2], bold=False)
    sc.put(nine(frames_of("rt_lcd_field_focus")[0], [8, 8, 8, 8], r2[2] - r2[0] - 4, 30), (r2[0], r2[1] + 18))
    glow_text(sc.c, (r2[0] + 12, r2[1] + 24), "서울 · 엷은 안개 12°", 14, PH[3])
    glow_text(sc.c, (r2[0] + 2, r2[1] + 62), "현재 위치 날씨 자동 적용", 13, PH[3], bold=False)
    sc.c.alpha_composite(frames_of("rt_toggle_on")[f], (r2[2] - 54, r2[1] + 56))
    glow_text(sc.c, (r2[0] + 2, r2[1] + 94), "시간대 미리보기", 13, PH[3], bold=False)
    glow_text(sc.c, (r2[0] + 2, r2[1] + 150), "글자 속도", 13, PH[3], bold=False)
    out = sc.lit(0.72)
    for k, lab in enumerate(("새벽", "아침", "낮", "저녁", "밤")):        # 피아노 키 세그먼트
        pressed = k == 2
        kx = r2[0] + k * 54
        dy = key_at(out, CREAM, kx, r2[1] + 112, 52, 34, pressed, shadow=False)
        text(out, (kx + 13 + (5 if len(lab) == 1 else 0), r2[1] + 118 + dy), lab, 12, CREAM[0] if not pressed else PH[2])
    out.alpha_composite(nine(frames_of("rt_fader_track")[0], [0, 6, 0, 6], 200, 14), (r2[0] + 84, r2[1] + 152))
    kx = r2[0] + 84 + 40 + int(60 * (0.5 + 0.5 * math.sin(i / 24 * 2 * math.pi)))
    out.alpha_composite(frames_of("rt_fader_knob")[0], (kx, r2[1] + 144))
    dy = key_at(out, AMBERK, 26, 252, 230, 36, 9 <= i % 24 <= 10)
    text(out, (48, 260 + dy), "목표 급수 · 시험일 재설정", 13, AMBERK[0])
    shadow_under(out, 14, 590, 236, 56)                                     # 계정 명판
    out.alpha_composite(nine(frames_of("rt_plate_metal")[0], [8, 8, 8, 8], 236, 56), (14, 590))
    text(out, (30, 598), "계정", 10, METAL[1], bold=False)
    text(out, (30, 614), "Google 학습자", 16, METAL[0])
    rb = frames_of("rt_round_red_" + ("pressed" if i % 24 == 6 else "normal"))[0]
    out.alpha_composite(rb, (268, 600))
    text(out, (304, 606), "로그아웃", 13, REDK[4])
    sl = frames_of("rt_printer_slot")[0]                                      # 저장 토스트 (영수증)
    out.alpha_composite(sl, (300, 4))
    hgt = min(64, max(10, (i % 24) * 6))
    out.alpha_composite(nine(frames_of("rt_receipt")[0], [6, 6, 10, 6], 48, hgt), (306, 14))
    if hgt > 40:
        text(out, (312, 14 + hgt - 34), "저장됨", 10, (90, 86, 80, 255))
        text(out, (312, 28 + hgt - 34), "✓ 날씨", 9, (90, 86, 80, 255), bold=False)
    out.alpha_composite(nine(frames_of("rt_rail")[0], [4, 0, 4, 0], 12, 560), (388, 160))
    out.alpha_composite(frames_of("rt_rail_knob")[0], (388, 200 + (i % 24) * 2))
    out.alpha_composite(dangle, (60, 640))
    return finish(out, f, 3)


save_gif([settings(i) for i in range(24)], "preview_retro_settings_mock", 120, still=14)
print("settings")


# M5 스토리: 인터콤 대사창 + 클립보드 퀘스트 + 탭 강조
PORTRAIT = Path(OUT).parents[4] / "Sources/Hareru/Resources/Art/Characters/chief_researcher_portrait.png"
LINE = "어서 와요. 오늘부터 여기가 당신 자리예요."


def story(i):
    f = i % F
    sc = base_scene()
    code_at(sc, "rt_code_term_a", f, 196, 30)
    code_at(sc, "rt_code_term_b", f, 30, 50)
    shadow_under(sc.c, 30, 170, 300, 300, 170)                               # 클립보드 퀘스트
    sc.put(nine(frames_of("rt_clipboard")[0], [14, 12, 12, 12], 300, 300), (30, 170))
    sc.put(nine(paper_img, [14, 14, 14, 14], 270, 260), (45, 196))
    sc.put(frames_of("rt_clip")[0].resize((88, 36), Image.NEAREST), (136, 160))
    text(sc.c, (64, 214), "오늘의 연구 과제", 20, PAPER_INK, font=MYUNGJO)
    rect(ImageDraw.Draw(sc.c), 64, 244, 290, 244, (190, 178, 156, 255))
    sc.c.alpha_composite(frames_of("rt_checkbox_done" if i >= 16 else "rt_checkbox")[0].resize((20, 20), Image.NEAREST), (64, 262))
    text(sc.c, (92, 262), "새 단어 15개 해독하기", 16, PAPER_INK, font=MYUNGJO)
    sc.c.alpha_composite(frames_of("rt_checkbox")[0].resize((20, 20), Image.NEAREST), (64, 296))
    text(sc.c, (92, 296), "천장 누수 막기", 16, PAPER_INK, font=MYUNGJO)
    text(sc.c, (64, 400), "보상: 연구P + 책상 스탠드", 14, (150, 60, 50, 255), font=MYUNGJO)
    stamp = Image.new("RGBA", (70, 70))
    ImageDraw.Draw(stamp).ellipse([2, 2, 67, 67], outline=(180, 50, 46, 200), width=3)
    ImageDraw.Draw(stamp).text((14, 24), "NJL", font=ImageFont.truetype(GOTHIC, 18, index=6), fill=(180, 50, 46, 200))
    sc.c.alpha_composite(stamp.rotate(-14), (228, 360))
    x, y, w, h = 8, 560, 386, 200                                              # 인터콤 대사창
    shadow_under(sc.c, x, y, w, h, 170)
    sc.put(nine(frames_of("rt_dialog_body")[0], [21, 100, 18, 26], w, h), (x, y))
    out = sc.lit(0.72)
    pc = frames_of("rt_portrait_crt")[0]
    if PORTRAIT.exists():
        por = Image.open(PORTRAIT).convert("RGBA").resize((64, 64), Image.NEAREST)
        bg = Image.new("RGBA", (64, 64), GLASS_A)
        bg.alpha_composite(por)
        out.alpha_composite(bg, (x + 8 + 10, y + 34 + 14))
        out.alpha_composite(frames_of("rt_scanline_overlay")[0], (x + 8 + 10, y + 34 + 14))
    out.alpha_composite(pc, (x + 8, y + 34))
    shadow_under(out, x + 14, y - 14, 150, 30, 120)                            # 이름 명판
    out.alpha_composite(nine(frames_of("rt_plate_metal")[0], [8, 8, 8, 8], 150, 30), (x + 14, y - 14))
    text(out, (x + 30, y - 7), "주임 연구원", 14, METAL[0])
    shown = LINE[: min(len(LINE), i * 2)]
    tx, ty = x + 104, y + 36
    lines = [shown[:13], shown[13:]]
    for k, ln in enumerate(lines):
        glow_text(out, (tx, ty + k * 26), ln, 16, PH[3])
    if len(shown) == len(LINE) and f % 2 == 0:
        glow_text(out, (x + w - 54, y + h - 46), "▼", 14, PH[4])
    elif f % 2 == 0:
        out.alpha_composite(cursor[0], (tx + len(lines[-1]) * 15 + 2, ty + (26 if len(shown) > 13 else 0) + 2))
    out = finish(out, f, 1, ivy=True)
    out.alpha_composite(frames_of("rt_tab_ring")[f], (16 + 93 - 8, 790 + 2))
    out.alpha_composite(frames_of("rt_pointer")[f], (16 + 93 + 34, 768))
    return out


save_gif([story(i) for i in range(24)], "preview_retro_story_mock", 130, still=20)
print("story")


# M6 부팅 → 뉴럴링크 경고
def boot(i):
    f = i % F
    sc = base_scene()
    r = monitor_at(sc, "rt_monitor_crt", f, 12, 40, 378, 520, 60)
    out = sc.lit(0.72)
    logo = frames_of("rt_boot_logo")[0]
    if i < 14:
        rows = min(logo.height, int(logo.height * min(1, i / 6)))
        out.alpha_composite(logo.crop((0, 0, logo.width, rows)), ((r[0] + r[2]) // 2 - logo.width // 2, r[1] + 70))
        out.alpha_composite(nine(frames_of("rt_bar_track")[0], [0, 4, 0, 4], 220, 10), ((r[0] + r[2]) // 2 - 110, r[1] + 120))
        fill_w = int(220 * min(1, i / 12))
        if fill_w > 8:
            out.alpha_composite(nine(frames_of("rt_bar_fill_4")[f], [0, 4, 0, 4], fill_w, 10), ((r[0] + r[2]) // 2 - 110, r[1] + 120))
        log = ["MEM CHECK ......... OK", "PAPER SCANNER ..... OK", "LEXCODE FILTER .... OFF", "NEURAL SYNC ....... ?"]
        for k, ln in enumerate(log[: max(0, i - 4) // 2]):
            glow_text(out, (r[0] + 14, r[1] + 170 + k * 20), ln, 12, PH[2] if "?" not in ln else AM, bold=False)
        if f % 2 == 0:
            out.alpha_composite(cursor[0], (r[0] + 14, r[1] + 170 + min(4, max(0, i - 4) // 2) * 20))
    else:
        w = nine(frames_of("rt_warning_monitor")[0], [21, 16, 18, 16], 330, 300)
        wx, wy = 36, 140
        shadow_under(out, wx, wy, 330, 300, 190)
        out.alpha_composite(w, (wx, wy))
        sx0, sy0, sx1, sy1 = wx + 15, wy + 20, wx + 315, wy + 282
        red = Image.new("RGBA", out.size)
        if f % 2 == 0:                                                       # 붉은 깜빡임
            ImageDraw.Draw(red).rectangle([sx0, sy0, sx1, sy1], fill=(200, 30, 30, 70))
            out.alpha_composite(red)
        text(out, (sx0 + 16, sy0 + 20), "경고 · 뉴럴링크 동기화", 20, REDK[4])
        text(out, (sx0 + 16, sy0 + 56), "동기화하면 광고 수신에", 14, CYAN, bold=False)
        text(out, (sx0 + 16, sy0 + 76), "동의한 것으로 간주합니다", 14, CYAN, bold=False)
        text(out, (sx0 + 16, sy0 + 100), "(1日 400件)", 13, CYAN_D, bold=False)
        gl = frames_of("rt_glitch")[f]
        for gy in range(sy0, sy1, 64):
            for gx in range(sx0, sx1, 64):
                out.alpha_composite(gl.crop((0, 0, min(64, sx1 - gx), min(64, sy1 - gy))), (gx, gy))
        fld = nine(frames_of("rt_lcd_field")[0], [8, 8, 8, 8], 290, 30)
        out.alpha_composite(fld, (sx0 + 5, sy1 - 44))
        ad = "  꿈에서 먹는 스테이크 맛 캡슐 · 잠든 사이 외우는 언어 패치 (※ 효과 없음)  "
        off = (i * 9) % 260
        strip = Image.new("RGBA", (276, 18))
        text(strip, (-off, 1), ad * 2, 11, PH[3], bold=False)
        out.alpha_composite(strip, (sx0 + 12, sy1 - 37))
    return finish(out, f, 3, ivy=False)


save_gif([boot(i) for i in range(26)], "preview_retro_boot_warning", 140, still=10)
print("boot")
