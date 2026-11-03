"""1막(N5) 스토리 UI — 직접 그림 (생성 크레딧 0). usage: njl_story_ui.py <out_dir>

근거: Docs/Art/N5_ASSET_LIST.md §6. 공통 부품(njl_os_kit.py)과 같은 팔레트 · 화풍 · 9-slice 규칙(장식은 cap 안에만).
글자(화자 이름 · 퀘스트 제목 · 경고 문구 · 광고 스크롤)는 코드가 얹음. 여기서는 틀과 기호만.
cap은 <out_dir>/njl_story_manifest.json 에 [top, left, bottom, right] 또는 한 값으로 기록 (앱에서 1px = 2pt).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

O = (20, 24, 36, 255)
NAVY, NAVY_2, NAVY_DEEP = (30, 36, 52, 255), (36, 42, 60, 255), (16, 19, 30, 255)
SLATE_D, SLATE, SLATE_L, SLATE_LL, SHADE = (44, 50, 68, 255), (56, 64, 86, 255), (98, 112, 136, 255), (138, 152, 176, 255), (28, 32, 46, 255)
TEAL_D, TEAL, TEAL_L = (40, 70, 76, 255), (62, 104, 106, 255), (98, 148, 144, 255)
PAPER = (232, 228, 214, 255)
AMBER, AMBER_D, AMBER_L = (255, 206, 92, 255), (196, 132, 48, 255), (255, 236, 170, 255)
CYAN, CYAN_D, CYAN_DD = (0, 240, 255, 255), (0, 150, 172, 255), (0, 74, 92, 255)
RED, RED_D, RED_L, RED_BG, RED_BG2 = (226, 72, 64, 255), (140, 36, 40, 255), (255, 140, 120, 255), (44, 22, 30, 255), (52, 26, 34, 255)
CLEAR = (0, 0, 0, 0)

manifest = {}


def save(img, name, cap, note):
    img.save(OUT / f"{name}.png")
    manifest[name] = {"size": list(img.size), **({"cap": cap} if cap is not None else {}), "use": note}


def framed(w, h, rings, body, pattern=None, notch=True):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < len(rings):
                tl, br = rings[d]
                px[x, y] = br if (x == w - 1 - d or y == h - 1 - d) else tl
            else:
                px[x, y] = (pattern(x, y) if pattern else None) or body
    if notch:
        for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
            px[x, y] = CLEAR
        for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
            px[x, y] = O
    return img


def scan(a, b):
    return lambda x, y: a if y % 2 == 0 else b


def put(img, pts, c):
    px = img.load()
    for p in pts:
        px[p] = c


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def outline(img, c=O):
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


# ── 1. 대사창: 본문 9-slice + 초상 틀 + 이름 탭 + 다음 표시 ───────────────
box = framed(24, 24, [(O, O), (SLATE_L, SHADE), (SLATE, SLATE), (NAVY_DEEP, NAVY_DEEP)], NAVY, scan(NAVY, NAVY_2))
put(box, [(x, 2) for x in range(3, 8)], TEAL_L)            # 위 테두리 왼쪽 청록 띠(이름 탭이 앉는 자리)
put(box, [(20, 21)], AMBER)                                 # 오른쪽 아래 호박 LED
save(box, "njl_dialog_box", 8, "대사창 본문 (9-slice). 왼쪽 위에 이름 탭, 왼쪽에 초상 틀을 겹쳐 놓음")

pf = Image.new("RGBA", (76, 76))
pd = ImageDraw.Draw(pf)
rect(pd, 0, 0, 75, 75, O)
rect(pd, 1, 1, 74, 74, SLATE_L)
rect(pd, 2, 2, 74, 74, SHADE)
rect(pd, 2, 2, 73, 73, SLATE)
rect(pd, 4, 4, 71, 71, O)
rect(pd, 5, 5, 70, 70, CLEAR)                               # 64×64 초상이 들어가는 구멍 (6,6)
for (x, y, sx, sy) in ((2, 2, 1, 1), (73, 2, -1, 1), (2, 73, 1, -1), (73, 73, -1, -1)):
    put(pf, [(x + sx * i, y) for i in range(5)] + [(x, y + sy * i) for i in range(5)], CYAN_D)   # 판독 꺾쇠
put(pf, [(37, 2), (38, 2)], AMBER)
save(pf, "njl_dialog_portrait_frame", None, "대사창 초상 틀 76×76 — 가운데 64×64 구멍(6,6부터)에 초상을 깔고 위에 얹음")
pbg = Image.new("RGBA", (64, 64), NAVY_DEEP)
pbd = ImageDraw.Draw(pbg)
for y in range(0, 64, 2):
    rect(pbd, 0, y, 63, y, (22, 27, 40, 255))
for x in range(0, 64, 8):                                    # 옅은 격자 (판독 화면 느낌)
    rect(pbd, x, 0, x, 63, (26, 34, 48, 255))
save(pbg, "njl_dialog_portrait_bg", None, "초상 뒤 배경 64×64 (투명 초상용) — 주사선 + 옅은 격자")

tab = framed(16, 12, [(O, O), (AMBER, AMBER_D)], SLATE_D)
put(tab, [(2, 2), (3, 2)], AMBER_L)
save(tab, "njl_dialog_name_tab", 5, "화자 이름 칸 (가로 9-slice, 높이 12 고정) — 호박색 테두리")
nxt = Image.new("RGBA", (16, 6))
nd = ImageDraw.Draw(nxt)
for f, dy in ((0, 0), (1, 1)):
    nd.polygon([(f * 8 + 1, 0 + dy), (f * 8 + 6, 0 + dy), (f * 8 + 3, 3 + dy)], fill=AMBER)
    put(nxt, [(f * 8 + 1, dy), (f * 8 + 2, dy)], AMBER_L)
save(nxt, "njl_dialog_next", None, "다음 대사 표시 ▼ — 8×6 두 프레임 가로 스트립 (1px 위아래)")


# ── 2. 퀘스트 카드: 머리 띠가 있는 9-slice + 보상 줄 + 아이콘 ──────────────
qc = framed(32, 40, [(O, O), (TEAL_L, TEAL_D), (TEAL, TEAL)], NAVY, scan(NAVY, NAVY_2))
qd = ImageDraw.Draw(qc)
rect(qd, 3, 3, 28, 13, TEAL_D)                               # 머리 띠 (제목 자리)
rect(qd, 3, 3, 28, 3, TEAL_L)
rect(qd, 3, 14, 28, 14, O)
rect(qd, 3, 4, 4, 12, AMBER)                                 # 왼쪽 호박 표식
put(qc, [(26, 6), (26, 10)], NAVY_DEEP)                      # 펀치 구멍
put(qc, [(x, 30) for x in range(4, 28) if x % 2 == 0], SLATE)   # 보상 줄 위 점선 (아래 cap 안)
save(qc, "njl_quest_card", [16, 8, 10, 8], "퀘스트 카드 「오늘의 연구 과제」 (9-slice, cap 위16 · 좌8 · 아래10 · 우8). 머리 띠 = 제목")
rr = framed(16, 12, [(O, O), (NAVY_DEEP, SLATE_L)], NAVY_DEEP, notch=False)
put(rr, [(2, 3), (2, 4), (2, 5), (2, 6), (2, 7), (2, 8)], AMBER_D)
save(rr, "njl_quest_reward_row", 5, "보상 줄 (가로 9-slice) — 「보상: 연구P + 책상 스탠드」 같은 한 줄")
qi = Image.new("RGBA", (16, 16))
qid = ImageDraw.Draw(qi)
rect(qid, 2, 2, 13, 15, PAPER)
rect(qid, 5, 1, 10, 3, SLATE_L)
for y in (6, 9, 12):
    rect(qid, 4, y, 5, y + 1, TEAL)
    rect(qid, 7, y, 11, y, (150, 150, 142, 255))
put(qi, [(4, 6), (5, 7)], AMBER_D)                           # 첫 칸 체크
save(outline(qi), "njl_quest_icon_16", None, "퀘스트 아이콘 16 — 체크 칸이 있는 과제 쪽지")


# ── 3. 경고창: 붉은 테두리 + 위 띠 사선 무늬 + 광고 스크롤 줄 + 아이콘 ──────────
def hazard(x, y):
    if 2 <= y <= 5:
        return RED if (x + y) % 8 < 4 else RED_BG
    return None


warn = framed(24, 24, [(O, O), (RED_L, RED_D), (RED, RED), (O, O)], RED_BG, lambda x, y: hazard(x, y) or (RED_BG if y % 2 else RED_BG2))
wpx = warn.load()
for y in range(2, 6):                                        # 위 띠는 테두리 위로 덮어 그림
    for x in range(2, 22):
        wpx[x, y] = RED if (x + y) % 8 < 4 else (60, 24, 30, 255)
put(warn, [(x, 6) for x in range(2, 22)], O)
save(warn, "njl_warning_frame", 8, "경고창 (9-slice) — 붉은 테두리 + 위 사선 띠. 뉴럴링크 동기화 경고 D1-528 (붉은 깜빡임은 코드)")
tk = framed(16, 10, [(O, O), (RED_D, RED_D)], (24, 14, 20, 255), notch=False)
put(tk, [(x, 2) for x in range(2, 14)], (40, 20, 26, 255))
save(tk, "njl_warning_ticker", 4, "경고창 아래 광고 스크롤 줄 (가로 9-slice) — D1-533 작은 글씨 흐름")
wi = Image.new("RGBA", (24, 24))
wid = ImageDraw.Draw(wi)
wid.polygon([(11, 1), (12, 1), (23, 21), (0, 21)], fill=RED)
wid.polygon([(11, 4), (12, 4), (20, 19), (3, 19)], fill=RED_BG)
rect(wid, 11, 8, 12, 14, AMBER)
rect(wid, 11, 16, 12, 17, AMBER)
put(wi, [(11, 1), (12, 1)], RED_L)
for x in (5, 18):                                             # 뉴럴링크 귀 포트 표식 (시안 점 둘)
    put(wi, [(x, 22), (x + 1, 22)], CYAN)
save(outline(wi), "njl_warning_icon_24", None, "경고 아이콘 24 — 붉은 삼각형 + 호박 느낌표, 아래 시안 점 = 뉴럴링크")


# ── 4. NJL-OS 부팅 도트 ────────────────────────────────────────
FONT5x7 = {   # 직접 그린 도트 글자 (5×7)
    "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
}
text = "NJL-OS"
pitch = 2
cols = sum(5 for _ in text) + (len(text) - 1)
logo = Image.new("RGBA", (cols * pitch + 2, 7 * pitch + 2))
lx = 1
for i, ch in enumerate(text):
    for r, row in enumerate(FONT5x7[ch]):
        for c, v in enumerate(row):
            on = v == "#"
            color = (CYAN if i < 3 else AMBER) if on else (0, 40, 52, 255)
            logo.putpixel((lx + c * pitch, 1 + r * pitch), color)
    lx += 6 * pitch
save(logo, "njl_boot_logo", None, "부팅 로고 「NJL-OS」 도트 매트릭스 (꺼진 점 = 어두운 시안, NJL 시안 · OS 호박)")

loader = Image.new("RGBA", (24 * 4, 8))
ld = ImageDraw.Draw(loader)
for f in range(4):
    for k in range(3):
        lit = k == f - 1 or (f == 0 and False)
        x = f * 24 + 3 + k * 7
        rect(ld, x, 2, x + 3, 5, CYAN if lit else CYAN_DD)
        if lit:
            put(loader, [(x, 2)], (200, 255, 255, 255))
save(loader, "njl_boot_loader", None, "부팅 대기 점 3개 — 24×8 네 프레임 가로 스트립 (꺼짐 → 하나씩 켜짐)")
bt = framed(16, 8, [(O, O), (NAVY_DEEP, SLATE_L)], NAVY_DEEP, notch=False)
save(bt, "njl_boot_bar_track", 4, "부팅 진행 막대 빈 홈 (가로 9-slice)")
bf = framed(16, 8, [(O, O)], NAVY_DEEP, lambda x, y: CYAN if (x % 4) != 3 and 2 <= y <= 5 else (CYAN_D if (x % 4) != 3 else NAVY_DEEP), notch=False)
save(bf, "njl_boot_bar_fill", 4, "부팅 진행 막대 채움 — 4px마다 끊긴 시안 칸 (가운데 주기 4)")


# ── 5. 탭 강조 링 + 안내 화살표 ─────────────────────────────────
def ring(bright):
    img = Image.new("RGBA", (40, 40))
    c, c2 = (CYAN, AMBER) if bright else (CYAN_D, AMBER_D)
    inset = 1 if bright else 2
    for (x, y, sx, sy) in ((inset, inset, 1, 1), (39 - inset, inset, -1, 1), (inset, 39 - inset, 1, -1),
                           (39 - inset, 39 - inset, -1, -1)):
        put(img, [(x + sx * i, y) for i in range(7)] + [(x, y + sy * i) for i in range(7)], c)
        put(img, [(x + sx * i, y + sy) for i in range(1, 5)] + [(x + sx, y + sy * i) for i in range(1, 5)], CYAN_DD)
    for p in ((19, inset), (20, inset), (19, 39 - inset), (20, 39 - inset)):
        put(img, [p], c2)
    return img


strip = Image.new("RGBA", (80, 40))
strip.alpha_composite(ring(True), (0, 0))
strip.alpha_composite(ring(False), (40, 0))
save(strip, "njl_tab_ring", None, "탭 강조 링 — 40×40 두 프레임(밝음 · 어둠) 가로 스트립, 24px 탭 아이콘 둘레에 깜빡임 (D1-163 · 257 · 403 · 500)")
arrow = Image.new("RGBA", (20, 10))
ad = ImageDraw.Draw(arrow)
for f, dy in ((0, 0), (1, 2)):
    ad.polygon([(f * 10 + 1, dy), (f * 10 + 8, dy), (f * 10 + 4, dy + 5), (f * 10 + 5, dy + 5)], fill=AMBER)
    put(arrow, [(f * 10 + 2, dy), (f * 10 + 3, dy)], AMBER_L)
arrow = outline(arrow)
save(arrow, "njl_tab_pointer", None, "탭 위 안내 화살표 ▼ — 10×10 두 프레임 (2px 통통)")

(OUT / "njl_story_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
print(len(manifest), "story ui")
