#!/usr/bin/env python3
"""대사표(Docs/03_Story/Acts/N5/lines/N5_*.md)를 앱이 읽는 JSON으로 내보내기.

사용법:
    python3 -I Tools/export_story.py            # → Sources/Hareru/Resources/Data/story_n5.json

- 표 한 줄 = 대사 한 줄. 열은 대사표 머리말과 같음: ID · 화자 · 표정 · 일본어 · 한국어 · 비고
- `## ` 제목은 장면 경계로 함께 넣음 (앱에서 장면 이름 · 건너뛰기 단위)
- 비고의 `톤:xxx`는 tone으로 따로 뽑음 (주임 음성 반전 톤)
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINES = ROOT / "Docs" / "03_Story" / "Acts" / "N5" / "lines"
OUT = ROOT / "Sources" / "Hareru" / "Resources" / "Data" / "story_n5.json"
ROW = re.compile(r"^\|\s*([A-Z0-9]+-\d+)\s*\|")
TONE = re.compile(r"톤:\s*([a-z]+)")


def cells(line):
    parts = [p.strip() for p in line.strip().strip("|").split("|")]
    return (parts + [""] * 6)[:6]


def export_file(path):
    scenes, current = [], None
    for raw in path.read_text(encoding="utf-8").splitlines():
        if raw.startswith("## "):
            current = {"title": raw[3:].strip(), "lines": []}
            scenes.append(current)
        elif ROW.match(raw) and current is not None:
            line_id, speaker, expression, japanese, korean, note = cells(raw)
            tone = TONE.search(note)
            current["lines"].append({
                "id": line_id, "speaker": speaker, "expression": expression,
                "japanese": japanese, "korean": korean, "note": note,
                "tone": tone.group(1) if tone else "",
            })
    return [s for s in scenes if s["lines"]]


def main():
    chapters = {}
    for path in sorted(LINES.glob("N5_*.md")):
        chapters[path.stem.split("_", 1)[1]] = export_file(path)
    OUT.write_text(json.dumps({"chapters": chapters}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    total = sum(len(s["lines"]) for scenes in chapters.values() for s in scenes)
    print(f"{OUT.relative_to(ROOT)}: {len(chapters)}개 묶음 · {total}줄")


if __name__ == "__main__":
    main()
