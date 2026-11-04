#!/usr/bin/env python3
"""대사표(Docs/03_Story/Acts/N5/lines/N5_*.md)를 Godot 게임(Game/)이 읽는 JSON으로 내보내기.

    python3 -I Tools/export_story_game.py      # → Game/data/story_n5.json

원본은 대사표 하나 (로드맵 §3-4). 열(7개): ID · 화자 · 표정 · 일본어 · 한국어 · 단어 · 비고
- `## ` 제목 = 장면. 장면 key는 제목 앞 토큰 (예: `T-1`)
- 단어 열 `n5_1523060@0-2, …` → words: [{id, start, end}] (범위는 후리가나를 뺀 글자 기준)
- 비고의 `톤:xxx` → tone, 비고의 `필수` → required
- 선택 줄: 비고의 `…` (백틱) 항목 → options
- 비고에 ①②③…가 있으면 → branch (1부터). 선택지 고른 번호와 같을 때만 나옴
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINES = ROOT / "Docs" / "03_Story" / "Acts" / "N5" / "lines"
OUT = ROOT / "Game" / "data" / "story_n5.json"
ROW = re.compile(r"^\|\s*([A-Z0-9]+-\d+)\s*\|")
TONE = re.compile(r"톤:\s*([a-z]+)")
WORD = re.compile(r"(n\d_\d+)@(\d+)-(\d+)")
OPTION = re.compile(r"`([^`]+)`")
CIRCLED = "①②③④⑤⑥⑦⑧⑨"
BRANCH = re.compile(r"([①②③④⑤⑥⑦⑧⑨])")


def cells(line):
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    return (parts + [""] * 7)[:7]


def parse_line(raw):
    line_id, speaker, expression, japanese, korean, words, note = cells(raw)
    out = {
        "id": line_id, "speaker": speaker, "expression": expression,
        "japanese": japanese, "korean": korean, "note": note,
        "words": [{"id": w, "start": int(a), "end": int(b)} for w, a, b in WORD.findall(words)],
        "tone": (TONE.search(note) or [None, ""])[1] if TONE.search(note) else "",
        "required": "필수" in note,
        "branch": 0,
        "options": [],
    }
    m = BRANCH.search(note)
    if m:
        out["branch"] = CIRCLED.index(m.group(1)) + 1
    if speaker == "선택":
        out["options"] = [o for o in OPTION.findall(note) if not o.startswith("[")]
    return out


def export_file(path):
    scenes = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("## "):
            title = raw[3:].strip()
            current = {"key": title.split()[0], "title": title, "lines": []}
            scenes.append(current)
        elif ROW.match(raw) and current is not None:
            current["lines"].append(parse_line(raw))
    return [s for s in scenes if s["lines"]]


def main():
    chapters = {}
    for path in sorted(LINES.glob("N5_*.md")):
        chapters[path.stem.split("_", 1)[1]] = export_file(path)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"chapters": chapters}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = sum(len(s["lines"]) for scenes in chapters.values() for s in scenes)
    print(f"{OUT.relative_to(ROOT)}: {len(chapters)}개 묶음 · {total}줄")


if __name__ == "__main__":
    main()
