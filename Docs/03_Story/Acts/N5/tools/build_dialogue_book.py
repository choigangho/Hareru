#!/usr/bin/env python3
"""N5 대사 데이터(lines/*.md)를 읽기 좋은 대사집 HTML 한 장으로 묶는다.

원본은 lines/*.md. 이 파일은 보기용 — 대사를 고치면 다시 실행:
    python3 Docs/03_Story/Acts/N5/tools/build_dialogue_book.py
"""
import html
import re
from pathlib import Path

STORY = Path(__file__).resolve().parent.parent
LINES = STORY / "lines"
OUT = STORY / "N5_DIALOGUE_BOOK.html"

# 1막 진행 순서 (B1~B3 · M은 순서 무관이지만 읽기용으로 고정)
ORDER = [
    ("N5_D1", "1일차"),
    ("N5_D2", "2일차"),
    ("N5_B1", "Beat 1 · KURO"),
    ("N5_B2", "Beat 2 · 겐"),
    ("N5_B3", "Beat 3 · 미오"),
    ("N5_R", "중간 랠리 R1~R5"),
    ("N5_M", "인물 일상 M1~M3"),
    ("N5_B4", "Beat 4 · 1막 완결"),
]

CHAR_CLASS = {
    "주임": "c-chief", "주인공": "c-hero", "KURO": "c-kuro", "겐": "c-gen",
    "미오": "c-mio", "???": "c-unknown",
}
KIND_CLASS = {
    "연출": "k-stage", "시스템": "k-system", "독백": "k-mono", "타자": "k-type",
    "선택": "k-choice", "입력": "k-input", "—": "k-stage", "": "k-stage",
}


def esc(s):
    return html.escape(s, quote=False)


def inline(s):
    """마크다운 인라인 일부(**굵게**, `코드`)와 후리가나 → HTML."""
    s = esc(s)
    s = re.sub(r"([一-龥々ヶ]+)\(([ぁ-ゖー]+)\)", r"<ruby>\1<rt>\2</rt></ruby>", s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"`(.+?)`", r"<code>\1</code>", s)
    s = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)
    return s


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def render_row(header, c):
    row = dict(zip(header, c))
    rid = row.get("ID", "")
    who = row.get("화자", "")
    face = row.get("표정", "")
    jp = row.get("일본어", "")
    kr = row.get("한국어", "")
    note = row.get("비고", "") or row.get("조건", "")
    word = row.get("단어", "")
    search = esc(" ".join([rid, who, face, jp, kr, note]).lower())

    meta = []
    if note:
        meta.append(f'<span class="note">{inline(note)}</span>')
    if word:
        meta.append(f'<span class="word">{esc(word)}</span>')
    meta_html = f'<div class="meta">{"".join(meta)}</div>' if meta else ""
    idh = f'<span class="rid">{esc(rid)}</span>'

    if who in CHAR_CLASS or who not in KIND_CLASS:
        cls = CHAR_CLASS.get(who, "c-other")
        facet = f'<span class="face">{esc(face)}</span>' if face else ""
        body = ""
        if jp:
            body += f'<div class="jp">{inline(jp)}</div>'
            if kr:
                body += f'<div class="kr sub">{inline(kr)}</div>'
        elif kr:
            body += f'<div class="kr">{inline(kr)}</div>'
        return (f'<div class="row speech {cls}" data-s="{search}">{idh}'
                f'<div class="who"><span class="name">{esc(who)}</span>{facet}</div>'
                f'<div class="say">{body}{meta_html}</div></div>')

    cls = KIND_CLASS[who]
    text = " ".join(x for x in [inline(jp) if jp else "", inline(kr) if kr else ""] if x)
    label = esc(who) if who and who != "—" else ""
    if cls == "k-stage" and not text:
        return (f'<div class="row {cls}" data-s="{search}">{idh}'
                f'<div class="stage">{inline(note)}</div>'
                f'{f"<div class=meta><span class=word>{esc(word)}</span></div>" if word else ""}</div>')
    return (f'<div class="row {cls}" data-s="{search}">{idh}'
            f'<div class="who"><span class="kind">{label}</span></div>'
            f'<div class="say"><div class="txt">{text}</div>{meta_html}</div></div>')


def render_file(stem, title):
    lines = (LINES / f"{stem}.md").read_text(encoding="utf-8").split("\n")
    out, toc = [], []
    header, notes, count = None, [], 0
    for ln in lines:
        if ln.startswith("# "):
            continue
        if ln.startswith("## ") or ln.startswith("### "):
            if notes:
                out.append('<div class="fnote">' + "<br>".join(notes) + "</div>")
                notes = []
            h = ln.lstrip("#").strip()
            sid = f"{stem}-{len(toc)}"
            toc.append((sid, h))
            out.append(f'<h3 id="{sid}">{inline(h)}</h3>')
            header = None
            continue
        if ln.startswith(">"):
            notes.append(inline(ln.lstrip("> ").strip()))
            continue
        if ln.startswith("|"):
            c = cells(ln)
            if header is None:
                header = c
                continue
            if set("".join(c)) <= set(":- "):
                continue
            if "ID" in header and "화자" in header:
                out.append(render_row(header, c))
                count += 1
            else:  # 다른 표 (예: 상시 소품 반응)
                out.append('<div class="row k-system"><div class="say"><div class="txt">'
                           + " · ".join(inline(x) for x in c if x) + "</div></div></div>")
            continue
        if not ln.strip():
            header = None if header and not ln.strip() else header
            continue
        notes.append(inline(ln.strip()))
    if notes:
        out.append('<div class="fnote">' + "<br>".join(notes) + "</div>")
    return out, toc, count


def main():
    body, nav, total = [], [], 0
    for stem, title in ORDER:
        rows, toc, n = render_file(stem, title)
        total += n
        body.append(f'<section id="{stem}"><h2>{esc(title)} <small>{n}줄</small></h2>{"".join(rows)}</section>')
        sub = "".join(f'<a class="sub" href="#{sid}">{inline(h)}</a>' for sid, h in toc)
        nav.append(f'<a href="#{stem}">{esc(title)}</a>{sub}')
    page = TEMPLATE.replace("{{NAV}}", "".join(nav)).replace("{{BODY}}", "".join(body)).replace("{{TOTAL}}", str(total))
    OUT.write_text(page, encoding="utf-8")
    print(f"{OUT} — {total}줄")


TEMPLATE = """<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>N5 대사집</title>
<style>
:root{--bg:#f6f3ec;--paper:#fffdf8;--ink:#2a2723;--mute:#8a8378;--line:#e4ded2;--chip:#efe9dd;
--chief:#3f7d6e;--hero:#4a5f8f;--kuro:#b07a1f;--gen:#a8502f;--mio:#9a5a8e;--sys:#32605a;--phos:#2f8f5b}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#1b1a18;--paper:#23221f;--ink:#ebe6dc;--mute:#9a9385;--line:#36332e;--chip:#2e2c28;
--chief:#7cc4b2;--hero:#9db0e0;--kuro:#e2b25a;--gen:#e08a66;--mio:#d39bc8;--sys:#86c9bd;--phos:#6fd49a}}
:root[data-theme="dark"]{--bg:#1b1a18;--paper:#23221f;--ink:#ebe6dc;--mute:#9a9385;--line:#36332e;--chip:#2e2c28;
--chief:#7cc4b2;--hero:#9db0e0;--kuro:#e2b25a;--gen:#e08a66;--mio:#d39bc8;--sys:#86c9bd;--phos:#6fd49a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.6 -apple-system,"Apple SD Gothic Neo","Hiragino Sans",sans-serif}
header{position:sticky;top:0;z-index:5;background:var(--bg);border-bottom:1px solid var(--line);padding:10px 16px;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
header h1{font-size:16px;margin:0 8px 0 0}
header input{flex:1;min-width:140px;padding:6px 10px;border:1px solid var(--line);border-radius:8px;background:var(--paper);color:var(--ink)}
header label{font-size:13px;color:var(--mute);white-space:nowrap}
.wrap{display:flex;max-width:1100px;margin:0 auto}
nav{width:220px;flex:none;position:sticky;top:52px;align-self:flex-start;max-height:calc(100vh - 52px);overflow:auto;padding:12px 8px 40px 16px;font-size:13px}
nav a{display:block;color:var(--ink);text-decoration:none;padding:3px 6px;border-radius:6px;font-weight:600}
nav a.sub{font-weight:400;color:var(--mute);padding-left:16px}
nav a:hover{background:var(--chip)}
main{flex:1;min-width:0;padding:8px 16px 80px}
section{margin-bottom:40px}
h2{font-size:22px;margin:28px 0 4px;padding-top:8px;border-top:2px solid var(--ink)}
h2 small{font-size:13px;color:var(--mute);font-weight:400}
h3{font-size:15px;margin:26px 0 8px;color:var(--sys)}
.fnote{font-size:12.5px;color:var(--mute);background:var(--chip);border-radius:8px;padding:8px 10px;margin:6px 0 10px}
.row{display:grid;grid-template-columns:64px 92px 1fr;gap:0 10px;padding:5px 0;border-bottom:1px dashed var(--line);align-items:start}
.rid{font:11px/1.9 ui-monospace,Menlo,monospace;color:var(--mute)}
.who{display:flex;flex-direction:column;line-height:1.3;padding-top:2px}
.name{font-weight:700}
.face{font-size:11.5px;color:var(--mute)}
.kind{font-size:11.5px;color:var(--mute);border:1px solid var(--line);border-radius:5px;padding:0 5px;width:max-content}
.jp{font-family:"Hiragino Mincho ProN","Yu Mincho",serif;font-size:17px}
.kr.sub{font-size:13.5px;color:var(--mute)}
rt{font-size:9.5px;color:var(--mute)}
.meta{display:flex;flex-wrap:wrap;gap:4px 8px;margin-top:2px}
.note{font-size:12px;color:var(--mute)}
.word{font:11px ui-monospace,Menlo,monospace;color:var(--phos)}
code{font-size:.9em;background:var(--chip);padding:0 4px;border-radius:4px}
.c-chief .name{color:var(--chief)}.c-hero .name{color:var(--hero)}.c-kuro .name{color:var(--kuro)}
.c-gen .name{color:var(--gen)}.c-mio .name{color:var(--mio)}.c-unknown .name,.c-other .name{color:var(--mute)}
.k-stage{grid-template-columns:64px 1fr}
.stage{font-style:italic;color:var(--mute);font-size:13.5px}
.k-stage .meta{grid-column:2}
.k-system .txt{font:13px ui-monospace,Menlo,monospace;color:var(--sys)}
.k-mono .txt{font-style:italic;color:var(--hero);opacity:.85}
.k-type .txt{font:14px ui-monospace,Menlo,monospace}
.k-choice .txt,.k-input .txt{display:inline-block;border:1px solid var(--line);background:var(--paper);border-radius:6px;padding:1px 8px}
body.nonotes .meta,body.nonotes .fnote,body.nonotes .k-stage{display:none}
body.nokr .kr.sub{display:none}
body.noid .rid{visibility:hidden}
.hide{display:none!important}
@media (max-width:760px){nav{display:none}.row{grid-template-columns:72px 1fr}.row .rid{display:none}.k-stage{grid-template-columns:1fr}.k-stage .meta{grid-column:1}}
</style></head><body>
<header><h1>N5 대사집 <small style="color:var(--mute);font-weight:400">{{TOTAL}}줄</small></h1>
<input id="q" placeholder="검색 (ID · 인물 · 대사 · 비고)">
<label><input type="checkbox" id="tn" checked> 연출 · 비고</label>
<label><input type="checkbox" id="tk" checked> 일본어 줄 뜻</label>
<label><input type="checkbox" id="ti" checked> ID</label>
<select id="who"><option value="">모든 인물</option><option>주임</option><option>주인공</option><option>KURO</option><option>겐</option><option>미오</option></select>
</header>
<div class="wrap"><nav>{{NAV}}</nav><main>{{BODY}}</main></div>
<script>
const b=document.body,rows=[...document.querySelectorAll('.row')];
const bind=(id,cls)=>document.getElementById(id).addEventListener('change',e=>b.classList.toggle(cls,!e.target.checked));
bind('tn','nonotes');bind('tk','nokr');bind('ti','noid');
function filt(){const q=document.getElementById('q').value.trim().toLowerCase(),w=document.getElementById('who').value;
rows.forEach(r=>{const n=r.querySelector('.name');const okw=!w||(n&&n.textContent===w);r.classList.toggle('hide',!(okw&&(!q||r.dataset.s.includes(q))))})}
document.getElementById('q').addEventListener('input',filt);document.getElementById('who').addEventListener('change',filt);
</script></body></html>"""

if __name__ == "__main__":
    main()
