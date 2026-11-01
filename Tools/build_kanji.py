#!/usr/bin/env python3
"""상용한자 2,136자 기본 데이터 빌드 (KANJIDIC2 + JLPT 단어 목록).

사용법:
    python3 -I Tools/build_kanji.py Tools/sources Tools/build/kanji_base.json

- KANJIDIC2 (EDRDG, CC BY-SA 4.0)에서 grade 1~8(=상용한자)만 추출합니다.
- JLPT 급수 추정: KANJIDIC2의 옛 4단계 급수(2010년 이전 공식 기준)를 우선 사용하고,
  N3·N2로 나뉜 옛 2급은 (단어 목록에 처음 등장하는 급수, 사용 빈도) 순으로 줄 세워
  앞쪽 OLD2_TO_N3_COUNT자를 N3, 나머지를 N2로 나눕니다.
  (단어 목록은 쉬운 단어도 어려운 한자 표기로 실어 두는 경우가 많아, 단독 기준으로 쓰면 N5가 과대 추정됨)
  둘 다 없으면 N1.
- 한국어 훈(예: '달')과 한국어 뜻은 원본에 없으므로 빈 값 + reviewStatus "draft"로 두고,
  다음 단계(한국어 초안)에서 채웁니다.
"""
import csv
import gzip
import json
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path

LEVELS = ["N5", "N4", "N3", "N2", "N1"]  # 쉬운 순서
OLD_JLPT_TO_NEW = {4: "N5", 3: "N4", 1: "N1"}  # 옛 2급은 N3·N2로 나눠야 해서 estimate_level에서 처리


OLD2_TO_N3_COUNT = 370  # 흔히 알려진 N3 신규 한자 규모 (추정치)


def estimate_level(old_jlpt, earliest_word_level):
    """옛 2급은 여기서 정하지 않고 split_old_level2에서 한꺼번에 나눔"""
    if old_jlpt in OLD_JLPT_TO_NEW:
        return OLD_JLPT_TO_NEW[old_jlpt], "kanjidic_old"
    if old_jlpt == 2:
        return None, "kanjidic_old2"
    return (earliest_word_level or "N1"), ("word_list" if earliest_word_level else "default")


def split_old_level2(results, earliest):
    old2 = [k for k in results if k["jlptLevelSource"] == "kanjidic_old2"]
    old2.sort(key=lambda k: (LEVELS.index(earliest.get(k["character"], "N1")), k["frequencyRank"] or 9999))
    for index, k in enumerate(old2):
        k["jlptLevel"] = "N3" if index < OLD2_TO_N3_COUNT else "N2"
        k["jlptLevelSource"] = "kanjidic_old2+word_list+frequency"


def is_kanji(ch: str) -> bool:
    cp = ord(ch)
    return 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF


def earliest_level_by_kanji(jlpt_dir: Path) -> dict:
    """JLPT 단어 목록에서 한자별로 처음 등장하는(가장 쉬운) 급수를 찾습니다."""
    earliest = {}
    for level in LEVELS:
        path = jlpt_dir / f"{level.lower()}.csv"
        with path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                for ch in row["expression"]:
                    if is_kanji(ch) and ch not in earliest:
                        earliest[ch] = level
    return earliest


def kangxi_radical(number: int) -> str:
    # 강희 부수 블록(U+2F00~)을 일반 한자 글자로 정규화 (예: ⽢ → 甘)
    return unicodedata.normalize("NFKC", chr(0x2F00 + number - 1))


def build(sources: Path) -> list:
    earliest = earliest_level_by_kanji(sources / "jlpt")
    with gzip.open(sources / "kanjidic2.xml.gz", "rb") as f:
        root = ET.parse(f).getroot()

    results = []
    for char in root.iter("character"):
        misc = char.find("misc")
        grade_text = misc.findtext("grade")
        if not grade_text or not 1 <= int(grade_text) <= 8:
            continue

        literal = char.findtext("literal")
        rad_number = int(char.find("radical/rad_value[@rad_type='classical']").text)
        old_jlpt = misc.findtext("jlpt")

        onyomi, kunyomi, korean_eum, english = [], [], [], []
        for group in char.iter("rmgroup"):
            for reading in group.iter("reading"):
                kind = reading.get("r_type")
                if kind == "ja_on":
                    onyomi.append(reading.text)
                elif kind == "ja_kun":
                    kunyomi.append(reading.text)
                elif kind == "korean_h":
                    korean_eum.append(reading.text)
            english += [m.text for m in group.iter("meaning") if m.get("m_lang") is None]

        level, level_source = estimate_level(int(old_jlpt) if old_jlpt else None, earliest.get(literal))
        results.append({
            "character": literal,
            "strokeCount": int(misc.findtext("stroke_count")),
            "radicalNumber": rad_number,
            "radicalCharacter": kangxi_radical(rad_number),
            "onyomi": onyomi,
            "kunyomi": kunyomi,
            "koreanEum": korean_eum,          # 원본 제공 (예: ["감"])
            "englishMeanings": english,
            "joyoGrade": int(grade_text),     # 1~6 교육한자, 8 = 그 외 상용한자
            "frequencyRank": int(misc.findtext("freq")) if misc.findtext("freq") else None,
            "jlptLevel": level,               # 추정 급수
            "jlptLevelSource": level_source,
            # 한국어 초안 단계에서 채울 값
            "koreanHun": None,                # 예: "달"
            "koreanMeanings": [],
            "radicalKoreanName": None,        # 예: "달 감"
            "reviewStatus": "draft",
        })

    split_old_level2(results, earliest)
    results.sort(key=lambda k: (LEVELS.index(k["jlptLevel"]), k["frequencyRank"] or 9999))
    return results


def main() -> None:
    sources, output = Path(sys.argv[1]), Path(sys.argv[2])
    kanji = build(sources)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(kanji, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    by_level = {}
    for k in kanji:
        by_level[k["jlptLevel"]] = by_level.get(k["jlptLevel"], 0) + 1
    print(f"상용한자 {len(kanji)}자 → {output}")
    print("급수별:", {lvl: by_level.get(lvl, 0) for lvl in LEVELS})


if __name__ == "__main__":
    main()
