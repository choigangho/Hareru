"""1막(N5) P1 소품 — 직접 그림 (생성 크레딧 0). usage: n5_props.py <out_dir> <existing_prop_bucket.png>

근거: Docs/Archive/N5_ASSET_LIST.md §4, 장면 비고는 Docs/03_Story/Acts/N5/lines/N5_D1.md · N5_D2.md.
글자는 글꼴을 쓰지 않고 획(stroke) 좌표로 직접 찍음 — 시스템 글꼴을 그림에 굳히면 라이선스 문제가 생길 수 있어서.
손글씨(연필 · 펜 · 분필)는 획 끝점을 살짝 흔들어 서툰 느낌을 냄 (seed 고정 → 다시 돌려도 같은 결과).
`insert_*` = 확대 인서트 컷(정면), `prop_*` = 방 안 소품(에셋 밀도 2배, 기존 prop_* 화풍).
"""
import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
BUCKET = Path(sys.argv[2])

# ── 팔레트 (기존 소품: 탁한 외곽선 · 바랜 색) ───────────────────
O = (24, 26, 40, 255)
PAPER, PAPER_D, PAPER_DD, PAPER_L = (232, 226, 208, 255), (204, 196, 174, 255), (168, 160, 140, 255), (246, 242, 228, 255)
LINE = (186, 190, 196, 255)                 # 공책 줄
INK = (44, 58, 104, 255)                    # 파란 펜
PENCIL = (78, 80, 92, 255)
CARD, CARD_L, CARD_D, CARD_DD = (176, 152, 116, 255), (204, 184, 148, 255), (140, 118, 88, 255), (96, 80, 62, 255)
TEAL, TEAL_L, TEAL_D = (98, 148, 144, 255), (146, 190, 180, 255), (62, 104, 106, 255)
MUG, MUG_D, MUG_L = (226, 222, 210, 255), (186, 182, 170, 255), (246, 244, 236, 255)
OLD, OLD_D, OLD_L = (206, 192, 166, 255), (164, 148, 122, 255), (224, 212, 188, 255)
AMBER, AMBER_D, AMBER_L = (255, 206, 92, 255), (196, 132, 48, 255), (255, 236, 170, 255)
RED, RED_D = (196, 70, 60, 255), (140, 44, 40, 255)
BOARD, BOARD_D, BOARD_L = (46, 66, 60, 255), (34, 50, 46, 255), (60, 84, 76, 255)
WOOD, WOOD_D, WOOD_L = (120, 88, 60, 255), (86, 62, 44, 255), (150, 114, 80, 255)
CHALK, CHALK_D, SMEAR = (222, 224, 214, 255), (170, 178, 170, 255), (92, 112, 104, 255)
METAL, METAL_L, METAL_D = (118, 126, 140, 255), (160, 168, 180, 255), (74, 80, 94, 255)
TAPE, TAPE_D, TAPE_L = (160, 164, 168, 255), (118, 122, 128, 255), (196, 198, 200, 255)
STAIN, STAIN_D = (150, 128, 98, 255), (118, 98, 74, 255)
WATER, WATER_L, WATER_D = (104, 146, 164, 255), (156, 194, 204, 255), (70, 104, 124, 255)
WB, WB_D = (238, 238, 232, 255), (200, 202, 200, 255)
MARK_N, MARK_R = (40, 60, 120, 255), (190, 60, 56, 255)
NAVY, NAVY_D = (30, 36, 52, 255), (20, 24, 36, 255)
CLEAR = (0, 0, 0, 0)

manifest = {}


def save(img, name, note):
    img.save(OUT / f"{name}.png")
    manifest[name] = {"size": list(img.size), "use": note}


# ── 그리기 도구 ───────────────────────────────────────────────
def line(px, a, b, c, w=None, h=None):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        if (w is None or 0 <= x0 < w) and (h is None or 0 <= y0 < h):
            px[x0, y0] = c
        if (x0, y0) == (x1, y1):
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def outline(img, c=O):
    w, h = img.size
    src = img.load()
    out = img.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and src[x + dx, y + dy][3] > 128
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = c
    return out


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def mosaic(img, x0, y0, w, h, cell, tones, seed):
    """판독 불가 모자이크 덩어리 (정지 그림용 — 움직이는 해독은 코드)."""
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    for y in range(y0, y0 + h, cell):
        for x in range(x0, x0 + w, cell):
            rect(d, x, y, min(x + cell, x0 + w) - 1, min(y + cell, y0 + h) - 1, rng.choice(tones))


# ── 글자: 획 좌표 (kanji 11×11 · kana 9×9 · 한글 9×11) ─────────────
G = {
    "採": [[(0, 3), (3, 3)], [(2, 0), (2, 10), (1, 9)], [(0, 8), (3, 6)], [(5, 1), (10, 0)],
          [(5, 2), (5, 3)], [(7, 2), (7, 3)], [(10, 2), (9, 3)], [(4, 5), (10, 5)], [(7, 4), (7, 10)],
          [(6, 6), (4, 9)], [(8, 6), (10, 9)]],
    "用": [[(1, 1), (1, 9), (0, 10)], [(1, 1), (9, 1), (9, 10), (8, 9)], [(2, 4), (8, 4)], [(2, 7), (8, 7)],
          [(5, 1), (5, 10)]],
    "通": [[(4, 0), (9, 0), (7, 2)], [(4, 2), (4, 7)], [(4, 2), (10, 2), (10, 7), (9, 7)], [(5, 4), (9, 4)],
          [(5, 6), (9, 6)], [(7, 2), (7, 7)], [(1, 0), (2, 1)], [(0, 4), (2, 4), (2, 8)],
          [(2, 8), (4, 10), (10, 10)]],
    "知": [[(1, 0), (0, 3)], [(1, 2), (4, 2)], [(0, 5), (5, 5)], [(3, 1), (3, 5), (0, 10)], [(3, 6), (5, 9)],
          [(6, 3), (10, 3), (10, 8), (6, 8), (6, 3)]],
    "常": [[(5, 0), (5, 2)], [(2, 1), (3, 2)], [(8, 1), (7, 2)], [(0, 3), (0, 4)], [(0, 3), (10, 3), (10, 4)],
          [(3, 5), (7, 5), (7, 6), (3, 6), (3, 5)], [(1, 8), (1, 10)], [(1, 8), (9, 8), (9, 10)], [(5, 7), (5, 10)]],
    "駐": [[(1, 0), (1, 7)], [(1, 0), (4, 0)], [(1, 2), (4, 2)], [(1, 4), (4, 4)], [(3, 0), (3, 6)],
          [(1, 7), (4, 7), (4, 9), (3, 10)], [(1, 9), (1, 9)], [(2, 9), (2, 9)], [(8, 0), (8, 1)],
          [(6, 2), (10, 2)], [(6, 6), (10, 6)], [(6, 10), (10, 10)], [(8, 2), (8, 10)]],
    "人": [[(5, 0), (5, 4)], [(5, 4), (0, 10)], [(5, 4), (10, 10)]],
    "員": [[(3, 0), (7, 0), (7, 2), (3, 2), (3, 0)], [(2, 3), (8, 3), (8, 8), (2, 8), (2, 3)], [(2, 5), (8, 5)],
          [(2, 7), (8, 7)], [(3, 9), (1, 10)], [(7, 9), (9, 10)]],
    "言": [[(4, 0), (5, 1)], [(0, 2), (10, 2)], [(2, 4), (8, 4)], [(2, 6), (8, 6)],
          [(2, 8), (8, 8), (8, 10), (2, 10), (2, 8)]],
    "き": [[(2, 1), (7, 0)], [(1, 3), (8, 2)], [(3, 0), (6, 5)], [(6, 5), (2, 6)], [(2, 7), (4, 8), (7, 8)]],
    "み": [[(1, 1), (5, 1)], [(5, 1), (1, 6)], [(1, 6), (2, 8), (5, 6), (8, 6)], [(6, 3), (5, 8)]],
    "は": [[(1, 0), (1, 8)], [(3, 2), (8, 2)], [(6, 0), (6, 7)], [(6, 7), (4, 8), (3, 7), (5, 6), (8, 8)]],
    "、": [[(1, 6), (2, 7)]],
    "ら": [[(2, 0), (3, 1)], [(1, 2), (1, 5)], [(1, 5), (4, 3), (6, 4), (6, 6), (3, 8), (1, 8)]],
    "め": [[(2, 1), (4, 7)], [(6, 0), (4, 4), (2, 7), (1, 6), (3, 3), (7, 3), (8, 5), (6, 8), (4, 8)]],
    "ろ": [[(1, 1), (5, 1), (1, 5), (5, 4), (7, 5), (6, 8), (3, 8)]],
    "출": [[(4, 0), (4, 0)], [(2, 1), (6, 1)], [(4, 1), (2, 3)], [(4, 1), (6, 3)], [(0, 4), (8, 4)], [(4, 4), (4, 5)],
          [(1, 6), (7, 6), (7, 8), (1, 8), (1, 10), (7, 10)]],
    "근": [[(1, 0), (7, 0), (7, 3)], [(0, 5), (8, 5)], [(1, 7), (1, 10), (7, 10)]],
    "일": [[(1, 0), (3, 0), (4, 1), (4, 3), (3, 4), (1, 4), (0, 3), (0, 1), (1, 0)], [(7, 0), (7, 5)],
          [(1, 6), (7, 6), (7, 8), (1, 8), (1, 10), (7, 10)]],
    "오": [[(3, 0), (5, 0), (6, 1), (6, 3), (5, 4), (3, 4), (2, 3), (2, 1), (3, 0)], [(4, 5), (4, 6)], [(0, 7), (8, 7)]],
    "늘": [[(1, 0), (1, 3), (7, 3)], [(0, 5), (8, 5)], [(1, 6), (7, 6), (7, 8), (1, 8), (1, 10), (7, 10)]],
    ":": [[(0, 3), (0, 3)], [(0, 7), (0, 7)]],
    "1": [[(1, 2), (3, 0), (3, 10)], [(1, 10), (5, 10)]],
    "?": [[(0, 0), (2, 0), (2, 1), (1, 2), (1, 2)], [(1, 4), (1, 4)]],
}
SIZE = {"kanji": (11, 11), "kana": (9, 9), "hangul": (9, 11)}


def write(img, text, x, y, color, kind, gap=1, jitter=0, seed=0, widths=None):
    """획 좌표로 글자를 찍음. jitter>0 이면 손글씨처럼 끝점을 흔듦."""
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size
    for ch in text:
        gw, gh = SIZE[kind]
        if ch in (":", "、", "1", "?"):
            gw = {":": 1, "、": 3, "1": 6, "?": 3}[ch]
        if ch == " ":
            x += gw // 2 + gap
            continue
        bob = rng.choice((-1, 0, 0, 1)) if jitter else 0
        for stroke in G[ch]:
            pts = [(x + px_ + (rng.choice((-1, 0, 0, 0, 1)) if jitter > 1 else 0),
                    y + py_ + bob + (rng.choice((0, 0, 1)) if jitter > 1 else 0)) for px_, py_ in stroke]
            for a, b in zip(pts, pts[1:] or pts):
                line(px, a, b, color, w, h)
        x += gw + gap
    return x


# ── 1. 「採用通知」 ───────────────────────────────────────────
def notice():
    img = Image.new("RGBA", (68, 88))
    d = ImageDraw.Draw(img)
    rect(d, 4, 4, 67, 87, (0, 0, 0, 70))                      # 그림자
    rect(d, 0, 0, 63, 83, PAPER)
    rect(d, 0, 0, 63, 0, PAPER_L)
    rect(d, 63, 0, 63, 83, PAPER_D)
    rect(d, 0, 83, 63, 83, PAPER_D)
    rect(d, 4, 3, 59, 3, PAPER_DD)                            # 머리 줄
    write(img, "採用通知", 8, 7, NAVY_D, "kanji", gap=1)
    rect(d, 4, 21, 59, 21, PAPER_DD)
    mosaic(img, 10, 24, 44, 6, 3, [PAPER_DD, (140, 134, 120, 255), (120, 116, 106, 255), PAPER_D], seed=3)  # 기관명
    for y, x1 in ((35, 56), (39, 52), (43, 57), (47, 40)):    # 본문 줄 (읽히지 않는 활자)
        for x in range(7, x1, 3):
            rect(d, x, y, x + 1, y, (150, 146, 136, 255))
    x = write(img, "출근일", 5, 58, INK, "hangul", gap=1, jitter=1, seed=7)
    x = write(img, ":", x + 1, 58, INK, "hangul", gap=2, jitter=1, seed=8)
    write(img, "오늘", x + 1, 58, INK, "hangul", gap=1, jitter=1, seed=9)
    line(img.load(), (34, 72), (58, 71), INK)                  # 서둘러 그은 밑줄
    stamp = [(x, y) for y in range(72, 82) for x in range(46, 58) if 3.4 <= ((x - 51.5) ** 2 + (y - 76.5) ** 2) ** .5 <= 4.8]
    for p in stamp:
        img.putpixel(p, RED)                                   # 직인 (안은 모자이크)
    mosaic(img, 49, 74, 5, 5, 1, [RED, RED_D, PAPER], seed=11)
    return img


save(notice(), "insert_notice_saiyou", "D1-019 「採用通知」 인서트 — 기관명 모자이크 · 손글씨 「출근일: 오늘」 · 붉은 직인")


# ── 2. 짐 상자 (열림): 머그 · 충전기 · 접힌 종이 ─────────────────────
def box_open():
    img = Image.new("RGBA", (64, 56))
    d = ImageDraw.Draw(img)
    rect(d, 6, 22, 45, 53, CARD)                              # 앞면
    rect(d, 46, 18, 57, 49, CARD_D)                           # 옆면
    d.polygon([(46, 22), (57, 18), (57, 49), (46, 53)], fill=CARD_D)
    d.polygon([(6, 22), (17, 14), (57, 14), (46, 22)], fill=CARD_DD)   # 열린 속(어둠)
    d.polygon([(6, 22), (0, 12), (11, 6), (17, 14)], fill=CARD_L)      # 왼쪽 날개
    d.polygon([(46, 22), (57, 14), (63, 22), (52, 30)], fill=CARD_L)   # 오른쪽 날개
    d.polygon([(17, 14), (22, 2), (60, 2), (57, 14)], fill=CARD)       # 뒤 날개
    rect(d, 6, 34, 45, 36, (196, 186, 160, 255))              # 테이프
    # 머그 (주인공 것 — 청록)
    rect(d, 20, 6, 29, 18, TEAL)
    rect(d, 20, 6, 29, 7, TEAL_L)
    rect(d, 21, 7, 28, 7, TEAL_D)
    rect(d, 30, 9, 32, 15, TEAL)
    rect(d, 31, 11, 31, 13, CLEAR)
    # 충전기 + 감긴 선
    rect(d, 36, 9, 42, 15, MUG)
    rect(d, 36, 9, 42, 9, MUG_L)
    rect(d, 38, 7, 38, 8, METAL_L)
    rect(d, 40, 7, 40, 8, METAL_L)
    for i in range(5):
        d.ellipse([33 - i, 15, 47 - i, 20], outline=(60, 62, 70, 255))
    # 접힌 종이 (바닥 쪽 모서리만 보임)
    d.polygon([(10, 18), (18, 15), (19, 21), (11, 22)], fill=PAPER)
    line(img.load(), (14, 16), (15, 21), PAPER_D)
    return outline(img)


save(box_open(), "insert_box_open", "D1-342 짐 상자를 엶 — 청록 머그 · 충전기와 감긴 선 · 바닥에 접힌 종이")


# ── 3. 쪽지 「きみは、[■]らめろ」 + 투명 파일 ─────────────────────────
def memo():
    img = Image.new("RGBA", (84, 28))
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 83, 27, PAPER)
    for y in (7, 19):
        rect(d, 0, y, 83, y, LINE)
    rect(d, 41, 0, 41, 27, PAPER_D)                           # 접었던 자국
    for x in range(0, 84, 3):                                 # 찢은 위쪽 가장자리
        img.putpixel((x, 0), CLEAR)
        img.putpixel((x + 1 if x + 1 < 84 else x, 0), PAPER_D)
    x = write(img, "きみは、", 5, 9, PENCIL, "kana", gap=1, jitter=1, seed=21)
    mosaic(img, x + 1, 9, 9, 9, 3, [PENCIL, (120, 122, 130, 255), PAPER_DD, (100, 102, 112, 255)], seed=22)
    write(img, "らめろ", x + 12, 9, PENCIL, "kana", gap=1, jitter=1, seed=23)
    return img


def memo_in_file(m):
    img = Image.new("RGBA", (92, 36))
    img.alpha_composite(m, (4, 4))
    sheet = Image.new("RGBA", (92, 36), (200, 236, 240, 54))  # 투명 파일
    sd = ImageDraw.Draw(sheet)
    sd.rectangle([0, 0, 91, 35], outline=(150, 190, 196, 200))
    for k in range(3):                                        # 비스듬한 반사
        line(sheet.load(), (60 + k * 6, 1), (70 + k * 6, 34), (255, 255, 255, 90 - k * 25))
    rect(sd, 0, 0, 91, 1, (230, 250, 252, 120))
    img.alpha_composite(sheet)
    return img


m = memo()
save(m, "insert_memo", "D1-345 쪽지 확대 — 연필 「きみは、[■]らめろ」, [■] 모자이크 (번역 레이어 깨짐은 코드)")
save(memo_in_file(m), "insert_memo_file", "D1-357 · D2-200 투명 파일에 꽂힌 쪽지 (반투명 PNG)")


def memo_room():
    img = Image.new("RGBA", (18, 11))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 0), (17, 0), (13, 10), (0, 10)], fill=(214, 236, 238, 255))   # 책상에 눕힌 파일
    d.polygon([(5, 1), (15, 1), (12, 9), (2, 9)], fill=PAPER)
    for y, (a, b) in ((3, (6, 12)), (6, (4, 11))):
        line(img.load(), (a, y), (b, y), PENCIL)
    rect(d, 9, 3, 10, 4, (110, 112, 122, 255))                # [■]
    line(img.load(), (13, 1), (11, 9), (255, 255, 255, 255))   # 반사
    return outline(img)


save(memo_room(), "prop_memo_masked", "신입 책상 위 상시 소품 — 투명 파일 속 쪽지 (방 소품 크기)")


# ── 4. 머그 둘 ───────────────────────────────────────────────
def mug(old):
    body, dark, light = (OLD, OLD_D, OLD_L) if old else (MUG, MUG_D, MUG_L)
    img = Image.new("RGBA", (24, 24))
    d = ImageDraw.Draw(img)
    rect(d, 3, 4, 16, 21, body)
    rect(d, 3, 4, 4, 21, light)
    rect(d, 15, 4, 16, 21, dark)
    d.ellipse([3, 2, 16, 6], fill=dark)                       # 입구
    d.ellipse([4, 3, 15, 5], fill=(92, 70, 52, 255) if old else (120, 92, 64, 255))   # 차
    d.ellipse([16, 8, 22, 17], fill=body)
    d.ellipse([18, 10, 20, 15], fill=CLEAR)
    rect(d, 4, 20, 15, 21, dark)
    if old:   # 이 나간 자리 + 바랜 그림: 해 하나 · 사람 둘
        for p in ((12, 2), (13, 2), (13, 3), (14, 2)):
            img.putpixel(p, CLEAR)
        img.putpixel((12, 3), dark)
        d.ellipse([6, 8, 9, 11], fill=AMBER_D)
        for p in ((7, 7), (5, 9), (10, 9), (7, 12)):
            img.putpixel(p, AMBER_D)
        for hx in (9, 12):                                     # 사람 둘 (막대 인형)
            img.putpixel((hx, 13), (96, 110, 120, 255))
            line(img.load(), (hx, 14), (hx, 16), (96, 110, 120, 255))
            img.putpixel((hx - 1, 17), (96, 110, 120, 255))
            img.putpixel((hx + 1, 17), (96, 110, 120, 255))
        line(img.load(), (10, 15), (11, 15), (96, 110, 120, 255))   # 손잡기
        rect(d, 5, 18, 14, 18, OLD_D)                         # 얼룩 자국
    else:
        rect(d, 3, 9, 16, 10, TEAL)                           # 새것: 청록 띠 한 줄
    return outline(img)


save(mug(False), "insert_mug_new", "D1-414 새 머그 — 깨끗한 오프화이트 + 청록 띠")
save(mug(True), "insert_mug_old", "D1-414 · R2 낡은 머그 — 이 나간 입구 · 바랜 해 하나 · 손잡은 사람 둘")


# ── 5. 벽 게시판 「常駐人員: 1 / 2」 ───────────────────────────────
def board(n):
    img = Image.new("RGBA", (68, 30))
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 67, 29, WOOD)
    rect(d, 0, 0, 67, 0, WOOD_L)
    rect(d, 0, 29, 67, 29, WOOD_D)
    rect(d, 2, 2, 65, 26, BOARD)
    rect(d, 2, 2, 65, 2, BOARD_D)
    for x, y in ((9, 22), (30, 24), (50, 6), (58, 21)):       # 오래 지운 분필 자국
        rect(d, x, y, x + 3, y, SMEAR)
    rect(d, 6, 27, 20, 28, WOOD_D)                            # 분필 받침
    rect(d, 9, 26, 12, 26, CHALK)
    x = write(img, "常駐人員", 4, 8, CHALK, "kanji", gap=1, jitter=1, seed=31)
    x = write(img, ":", x + 1, 8, CHALK, "kanji", gap=2)
    if n == 1:
        write(img, "1", x, 8, CHALK, "kanji", jitter=1, seed=32)
    else:   # 1을 손바닥으로 지운 번짐 + 서툰 2 (획이 크고 비뚤)
        for yy in range(7, 20):
            for xx in range(x - 1, x + 6):
                if (xx * 7 + yy * 3) % 5 < 3:
                    img.putpixel((xx, yy), SMEAR)
        pts = [(x - 1, 9), (x + 1, 6), (x + 5, 6), (x + 6, 9), (x + 3, 14), (x - 1, 20), (x + 7, 19)]
        for a, b in zip(pts, pts[1:]):
            line(img.load(), a, b, CHALK)
        img.putpixel((x + 7, 18), CHALK_D)
    return img


save(board(1), "insert_board_resident_1", "D1-135 벽 게시판 「常駐人員: 1」 (분필)")
save(board(2), "insert_board_resident_2", "D1-135 이후 「常駐人員: 2」 — 1을 지운 번짐 + 서툰 분필 2")


# ── 6. 책상 스탠드 꺼짐 / 켜짐 ─────────────────────────────────────
def lamp(on):
    img = Image.new("RGBA", (26, 28))
    d = ImageDraw.Draw(img)
    d.ellipse([3, 22, 15, 27], fill=METAL_D)                  # 받침
    d.ellipse([3, 21, 15, 25], fill=METAL)
    line(img.load(), (9, 22), (6, 12), METAL_L)                # 팔
    line(img.load(), (10, 22), (7, 12), METAL)
    line(img.load(), (6, 12), (13, 6), METAL_L)
    line(img.load(), (7, 12), (14, 7), METAL)
    d.polygon([(11, 3), (17, 1), (22, 9), (15, 12)], fill=TEAL_D)   # 갓
    d.polygon([(11, 3), (17, 1), (18, 3), (12, 5)], fill=TEAL)
    img = outline(img)
    if on:
        glow = Image.new("RGBA", img.size)
        gd = ImageDraw.Draw(glow)
        for r, a in ((7, 56), (5, 96), (3, 160)):             # 전구 둘레 빛무리 (디더 없이 3단)
            gd.ellipse([18 - r, 10 - r, 18 + r, 10 + r], fill=(255, 222, 130, a))
        img = Image.alpha_composite(glow, img)
        d = ImageDraw.Draw(img)
        rect(d, 17, 9, 19, 10, AMBER_L)                       # 전구
        img.putpixel((18, 11), AMBER)
    else:
        rect(ImageDraw.Draw(img), 17, 9, 19, 10, (104, 104, 96, 255))
    return img


save(lamp(False), "prop_desk_lamp_off", "책상 스탠드 꺼짐 (D1-704 퀘스트 보상 전)")
save(lamp(True), "prop_desk_lamp_on", "책상 스탠드 켜짐 — 노란 전구 + 반투명 불빛 (D1-802 · D1-900 · D2-100)")


# ── 7. 천장 패치 붙음 / 덜렁 · 넘친 양동이 ───────────────────────────
def patch(loose):
    img = Image.new("RGBA", (30, 26))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 0, 28, 13], fill=STAIN)                     # 물 자국
    d.ellipse([4, 2, 25, 11], fill=(166, 146, 116, 255))
    d.ellipse([1, 0, 28, 13], outline=STAIN_D)
    if not loose:
        d.polygon([(4, 2), (7, 1), (26, 10), (23, 12)], fill=TAPE)     # X 테이프
        d.polygon([(23, 1), (26, 3), (7, 12), (4, 10)], fill=TAPE)
        line(img.load(), (5, 2), (24, 11), TAPE_L)
        line(img.load(), (24, 2), (5, 11), TAPE_L)
    else:
        d.polygon([(23, 1), (26, 3), (7, 12), (4, 10)], fill=TAPE)     # 한 줄만 남음
        line(img.load(), (24, 2), (5, 11), TAPE_L)
        d.polygon([(4, 2), (7, 1), (10, 5), (8, 7)], fill=TAPE)        # 떨어진 줄: 매달려 늘어짐
        d.polygon([(8, 7), (10, 5), (13, 18), (10, 20)], fill=TAPE_D)
        d.polygon([(10, 20), (13, 18), (15, 23), (12, 25)], fill=TAPE)
        img.putpixel((14, 16), WATER_L)                        # 맺힌 물방울
    return outline(img)


save(patch(False), "prop_ceiling_patch", "D1-312 천장 누수 막기 퀘스트 후 — 물 자국 위 X자 테이프")
save(patch(True), "prop_ceiling_patch_loose", "R4 덜렁거리는 패치 — 테이프 한 줄이 떨어져 매달림 + 물방울")


def bucket_overflow():
    src = Image.open(BUCKET).convert("RGBA")
    img = Image.new("RGBA", (src.width + 18, src.height + 6))
    d = ImageDraw.Draw(img)
    d.ellipse([0, src.height - 6, src.width + 17, src.height + 5], fill=WATER_D)   # 웅덩이
    d.ellipse([3, src.height - 5, src.width + 12, src.height + 3], fill=WATER)
    for p in ((8, src.height - 3), (src.width + 8, src.height), (src.width + 3, src.height - 2)):
        img.putpixel(p, WATER_L)
    img.alpha_composite(src, (9, 0))
    bbox = src.getbbox()
    px = img.load()
    rim = []
    for y in range(bbox[1], bbox[1] + 9):                     # 입구의 황갈색(빈 속) → 가득 찬 물
        for x in range(9 + bbox[0], 9 + bbox[2]):
            r, g, b, a = px[x, y]
            if a and r > 140 and r > b + 30:
                px[x, y] = WATER_L if y == bbox[1] + 1 or (x + y) % 5 == 0 else WATER
                rim.append((x, y))
    xs = [x for x, _ in rim]
    for sx in (min(xs) - 1, max(xs) + 1):                     # 양옆으로 넘쳐 흐르는 줄기
        for y in range(bbox[1] + 4, bbox[3] - 2):
            if px[sx, y][3]:
                px[sx, y] = WATER if y % 3 else WATER_L
    return img


save(bucket_overflow(), "prop_bucket_overflow", "D1-308 넘친 양동이 — 기존 prop_bucket + 찬 수면 · 넘쳐 흐르는 물 · 웅덩이")


# ── 8. 화이트보드 · 망각 곡선(미끄럼틀) · 마커 뚜껑 ──────────────────────
def whiteboard(curve):
    img = Image.new("RGBA", (64, 58))
    d = ImageDraw.Draw(img)
    for x in (6, 56):                                          # 다리 + 바퀴
        rect(d, x, 40, x + 1, 54, METAL)
        d.ellipse([x - 2, 53, x + 3, 57], fill=METAL_D)
    rect(d, 6, 48, 57, 48, METAL_D)
    rect(d, 0, 0, 63, 41, METAL_L)
    rect(d, 2, 2, 61, 38, WB)
    rect(d, 2, 37, 61, 38, WB_D)
    rect(d, 6, 39, 26, 41, METAL_D)                            # 마커 받침
    rect(d, 9, 39, 14, 39, MARK_R)
    rect(d, 17, 39, 21, 39, MARK_N)
    for x, y in ((40, 8), (12, 30), (50, 30)):                 # 덜 지운 자국
        rect(d, x, y, x + 4, y, (222, 224, 220, 255))
    if curve:
        px = img.load()
        line(px, (8, 6), (8, 33), MARK_N)                      # 축
        line(px, (8, 33), (58, 33), MARK_N)
        pts = [(9 + i, 7 + round(25 * (1 - 0.82 ** (i * 0.9)) )) for i in range(0, 48)]
        for a, b in zip(pts, pts[1:]):                         # 망각 곡선 (굵게 2줄)
            line(px, a, b, MARK_R)
            line(px, (a[0], a[1] - 1), (b[0], b[1] - 1), MARK_R)
        for y in range(8, 32, 4):                              # 미끄럼틀 사다리 (나중에 덧그린 가로대)
            line(px, (3, y), (8, y), MARK_N)
        line(px, (3, 6), (3, 33), MARK_N)
        line(px, (56, 30), (60, 29), MARK_R)                   # 착지 끝 살짝 들림
        img.putpixel((12, 5), MARK_N)                          # 꼭대기 사람 점
        line(px, (12, 3), (12, 4), MARK_N)
    return outline(img)


save(whiteboard(False), "prop_whiteboard", "이동식 화이트보드 (빈 판)")
save(whiteboard(True), "prop_whiteboard_curve", "D2-308~314 망각 곡선 — 사다리까지 그려져 미끄럼틀처럼 보임")
cap = Image.new("RGBA", (8, 6))
cd = ImageDraw.Draw(cap)
rect(cd, 1, 1, 5, 4, MARK_N)
rect(cd, 1, 1, 5, 1, (80, 100, 160, 255))
rect(cd, 6, 2, 6, 3, MARK_N)
save(outline(cap), "prop_marker_cap", "D2-306 날아간 마커 뚜껑 · D2-327 주워 건넴")


# ── 9. 주임 이름표 (言継 晴) — 블러 / 첫 글자만 선명 ─────────────────────
def nameplate(first):
    img = Image.new("RGBA", (48, 24))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 23), (4, 3), (43, 3), (47, 23)], fill=WOOD)  # 책상용 삼각 명패 앞면
    d.polygon([(4, 3), (43, 3), (44, 5), (3, 5)], fill=WOOD_L)
    rect(d, 6, 6, 41, 21, (60, 66, 80, 255))                   # 금속 판
    rect(d, 6, 6, 41, 6, METAL)
    x = 15
    for i in range(3):                                          # 후리가나 「？？？」
        write(img, "?", x + i * 5, 8, (210, 212, 216, 255), "kana")
    if first:
        write(img, "言", 8, 10, PAPER_L, "kanji")
    for i, cx in enumerate((8, 20, 32)):
        if first and i == 0:
            continue
        rng = random.Random(40 + i)                             # 블러 = 번진 덩어리
        for yy in range(10, 21):
            for xx in range(cx, cx + 11):
                edge = xx in (cx, cx + 10) or yy in (10, 20)
                if rng.random() < (0.35 if edge else 0.85):
                    img.putpixel((xx, yy), rng.choice([(150, 152, 158, 255), (128, 132, 140, 255), (176, 176, 178, 255)]))
    return outline(img)


save(nameplate(False), "prop_nameplate_chief_blur", "D1-249 주임 책상 이름표 — 이름 3글자 블러 · 후리가나 「？？？」")
save(nameplate(True), "prop_nameplate_chief_first", "B4 첫 글자 「言」만 선명 (言継 晴 — STORY_BIBLE §3), 나머지 블러")

(OUT / "n5_props_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
print(len(manifest), "props")
