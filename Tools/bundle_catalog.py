#!/usr/bin/env python3
"""앱 번들 데이터(Resources/Data) = 기존 견본 단어 + 내보내기 묶음(Tools/build/n5 …) 합치기.

사용법:
    python3 -I Tools/bundle_catalog.py Tools/build/n5

- 기존 번들의 견본 단어(팔레트 · 음성 · 테스트가 참조)는 그대로 두고, 표제어가 겹치는 내보내기 단어는 뺍니다.
- 한자는 합집합 (겹치면 기존 번들 쪽 유지).
- 다시 실행해도 같은 결과: 견본은 id가 숫자형(n5_1565440)이 아닌 단어로 구분합니다.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Sources/Hareru/Resources/Data"
EXPORTED_ID = re.compile(r"^n\d_\d+(_\d+)?$")


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, items):
    path.write_text(json.dumps(items, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main():
    words = [w for w in load(DATA / "words.json") if not EXPORTED_ID.match(w["id"])]
    kanji = load(DATA / "kanji.json")
    terms = {w["term"] for w in words}  # 견본 표제어만 — 내보내기 안의 동형이의어(時 등)는 각각 유지
    for directory in map(Path, sys.argv[1:]):
        words += [w for w in load(directory / "words.json") if w["term"] not in terms]
        characters = {k["character"] for k in kanji}
        kanji += [k for k in load(directory / "kanji.json") if k["character"] not in characters]
    save(DATA / "words.json", words)
    save(DATA / "kanji.json", kanji)
    print(f"단어 {len(words)}개 · 한자 {len(kanji)}자 → {DATA.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
