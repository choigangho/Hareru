#!/usr/bin/env python3
"""JLPT 단어 기본 데이터 빌드 (JLPT 목록 × JMdict × JmdictFurigana).

사용법:
    python3 -I Tools/build_words.py Tools/sources Tools/build/kanji_base.json Tools/build/words_base.json

- JLPT 목록(open-anki-jlpt-decks, 원천 tanos.co.uk)에서 급수와 표기·읽기를 가져옵니다.
  같은 단어가 여러 급수에 있으면 가장 쉬운 급수를 씁니다.
- JMdict(EDRDG, CC BY-SA 4.0)와 표기·읽기로 매칭해 품사·영어 뜻을 붙입니다.
- JmdictFurigana(CC BY-SA)로 한자별 실제 발음(kanjiUsages)을 만듭니다.
  숙자훈(美味→おい)처럼 여러 한자가 한 읽기를 공유하면 readingType "special"로 표시하고,
  앱의 표제어 루비(TermRuby)가 묶음 루비로 처리합니다.
- 한국어 뜻·예문은 다음 단계(초안 생성)에서 채웁니다.
"""
import csv
import gzip
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

LEVELS = ["N5", "N4", "N3", "N2", "N1"]
VOICELESS = str.maketrans("がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽっ",
                          "かきくけこさしすせそたちつてとはひふへほはひふへほつ")


def is_kanji(ch: str) -> bool:
    cp = ord(ch)
    return 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF


def to_hiragana(text: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in text)


def clean_form(raw: str) -> str:
    """'足; 脚' → '足', 'べんきょう (する)' → 'べんきょう', '～ころ' → 'ころ', '回る、回す' → '回る'"""
    first = re.split(r"[;；、]", raw)[0]
    first = re.sub(r"[（(][^)）]*[)）]", "", first)
    return first.replace("～", "").replace("〜", "").replace(" ", "").strip()


def load_jlpt(jlpt_dir: Path) -> list:
    seen, words = set(), []
    for level in LEVELS:
        with (jlpt_dir / f"{level.lower()}.csv").open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                term, reading = clean_form(row["expression"]), clean_form(row["reading"])
                # 'する' 동사: 표기에는 없는데 읽기에만 붙어 있거나(運動/うんどうする), 둘 다 붙은 경우(コピーする)
                if reading.endswith("する") and len(reading) > 2:
                    if term.endswith("する") and len(term) > 2:
                        term = term[:-2]
                    if not term.endswith("する"):
                        reading = reading[:-2]
                if not term or (term, reading) in seen:
                    continue
                seen.add((term, reading))
                words.append({"term": term, "reading": reading, "jlptLevel": level,
                              "listGloss": row["meaning"], "rawExpression": row["expression"]})
    return words


def load_jmdict(path: Path) -> dict:
    """(표기, 읽기) 및 (읽기, 읽기) → 엔트리 요약, 그리고 ('*', 표기) → 그 표기의 첫 엔트리 (읽기 보정용)"""
    index = {}
    with gzip.open(path, "rb") as f:
        for _, entry in ET.iterparse(f):
            if entry.tag != "entry":
                continue
            kebs = [k.findtext("keb") for k in entry.findall("k_ele")]
            rebs = [r.findtext("reb") for r in entry.findall("r_ele")]
            senses, pos_carry = [], []
            for sense in entry.findall("sense"):
                pos = [p.text for p in sense.findall("pos")] or pos_carry
                pos_carry = pos
                glosses = [g.text for g in sense.findall("gloss")]
                misc = [m.text for m in sense.findall("misc")]
                senses.append({"pos": pos, "glosses": glosses, "misc": misc})
            summary = {"seq": int(entry.findtext("ent_seq")), "kebs": kebs, "rebs": rebs, "senses": senses}
            for keb in kebs:
                index.setdefault(("*", keb), summary)
                for reb in rebs:
                    index.setdefault((keb, reb), summary)
            for reb in rebs:
                index.setdefault((reb, reb), summary)
            entry.clear()
    return index


def load_furigana(path: Path) -> dict:
    with zipfile.ZipFile(path) as z:
        data = json.loads(z.read(z.namelist()[0]).decode("utf-8-sig"))
    return {(d["text"], d["reading"]): d["furigana"] for d in data}


def classify_reading(kanji: str, rt: str, kanji_info: dict):
    """한 글자 한자의 실제 발음이 음독/훈독 중 무엇인지 (연탁·촉음 변형 허용)"""
    info = kanji_info.get(kanji)
    if not info:
        return "special", None
    target = rt.translate(VOICELESS)
    for on in info["onyomi"]:
        base = to_hiragana(on)
        if rt == base or target == base.translate(VOICELESS) or \
           (len(base) > 1 and target[:-1] == base.translate(VOICELESS)[:-1] and rt.endswith("っ")):
            return "onyomi", on
    for kun in info["kunyomi"]:
        stem = kun.split(".")[0].strip("-")
        if rt == stem or target == stem.translate(VOICELESS):
            return "kunyomi", kun
    return "special", None


def kanji_usages(furigana_parts, kanji_info) -> list:
    usages, seen = [], set()
    for part in furigana_parts or []:
        ruby, rt = part["ruby"], part.get("rt")
        kanji_chars = [c for c in ruby if is_kanji(c)]
        if not rt or not kanji_chars:
            continue
        for ch in kanji_chars:
            if ch in seen:
                continue
            seen.add(ch)
            if len(ruby) == 1:
                reading_type, dictionary = classify_reading(ch, rt, kanji_info)
            else:
                reading_type, dictionary = "special", None  # 숙자훈 등 묶음 읽기
            usages.append({"kanji": ch, "activeReading": rt, "dictionaryReading": dictionary,
                           "readingType": reading_type})
    return usages


def estimated_group_usages(term: str, reading: str) -> list:
    """JmdictFurigana에 없는 불규칙 읽기(可愛い, 真っ赤 등): 앞뒤 가나를 뺀 나머지 읽기를 한자 묶음에 통째로"""
    reading = to_hiragana(reading)
    prefix = ""
    for ch in term:
        if is_kanji(ch):
            break
        prefix += to_hiragana(ch)
    suffix = ""
    for ch in reversed(term):
        if is_kanji(ch):
            break
        suffix = to_hiragana(ch) + suffix
    core = reading
    if prefix and core.startswith(prefix):
        core = core[len(prefix):]
    if suffix and core.endswith(suffix):
        core = core[:len(core) - len(suffix)]
    kanji_chars = list(dict.fromkeys(c for c in term if is_kanji(c)))
    return [{"kanji": c, "activeReading": core, "dictionaryReading": None, "readingType": "special"}
            for c in kanji_chars]


def main() -> None:
    sources, kanji_path, output = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    kanji_info = {k["character"]: k for k in json.loads(kanji_path.read_text(encoding="utf-8"))}
    jlpt_words = load_jlpt(sources / "jlpt")
    jmdict = load_jmdict(sources / "JMdict_e.gz")
    furigana = load_furigana(sources / "JmdictFurigana.json.zip")

    results, unmatched = [], []
    for w in jlpt_words:
        term, reading = w["term"], to_hiragana(w["reading"]) if not w["term"].isascii() else w["reading"]
        entry = jmdict.get((term, w["reading"])) or jmdict.get((term, reading))
        reading_adjusted = False
        if entry is None and ("*", term) in jmdict:
            # 목록의 읽기가 표기와 어긋난 경우(伯父/おじさん, お金持ち/かねもち) → JMdict 대표 읽기로 보정
            entry = jmdict[("*", term)]
            w["reading"], reading_adjusted = entry["rebs"][0], True
        if entry is None:
            unmatched.append(w)
        has_kanji = any(is_kanji(c) for c in term)
        usages = kanji_usages(furigana.get((term, w["reading"])), kanji_info) if has_kanji else []
        usage_estimated = False
        if has_kanji and not usages:
            usages, usage_estimated = estimated_group_usages(term, w["reading"]), True
        missing_kanji = [c for c in term if is_kanji(c) and c not in {u["kanji"] for u in usages}]
        results.append({
            "id": f"{w['jlptLevel'].lower()}_{entry['seq'] if entry else 'x' + str(len(results))}",
            "jmdictSeq": entry["seq"] if entry else None,
            "term": term,
            "reading": w["reading"],
            "jlptLevel": w["jlptLevel"],
            "hasKanji": has_kanji,
            "usuallyKana": bool(entry and entry["senses"] and
                                any("usually written using kana alone" in (m or "") for m in entry["senses"][0]["misc"])),
            "partsOfSpeech": entry["senses"][0]["pos"] if entry and entry["senses"] else [],
            "englishSenses": [s["glosses"][:4] for s in entry["senses"][:4]] if entry else [[w["listGloss"]]],
            "kanjiUsages": usages,
            "nonJoyoKanji": [c for c in term if is_kanji(c) and c not in kanji_info],
            "issues": (["jmdict_unmatched"] if entry is None else []) +
                      (["reading_adjusted"] if reading_adjusted else []) +
                      (["kanji_usage_estimated"] if usage_estimated else []) +
                      (["kanji_usage_missing"] if missing_kanji else []),
            # 다음 단계에서 채울 값
            "koreanSenses": [],
            "category": None,
            "reviewStatus": "draft",
        })

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(results, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    by_level = {lvl: sum(1 for r in results if r["jlptLevel"] == lvl) for lvl in LEVELS}
    with_issue = [r for r in results if r["issues"]]
    print(f"단어 {len(results)}개 → {output}")
    print("급수별:", by_level)
    print(f"읽기 보정 {sum('reading_adjusted' in r['issues'] for r in results)}개 · "
          f"한자 읽기 추정 {sum('kanji_usage_estimated' in r['issues'] for r in results)}개")
    print(f"JMdict 매칭 실패 {len(unmatched)}개 · 한자 읽기 누락 "
          f"{sum('kanji_usage_missing' in r['issues'] for r in results)}개 · "
          f"상용 외 한자 포함 {sum(bool(r['nonJoyoKanji']) for r in results)}개")
    print("매칭 실패 예:", [u["rawExpression"] for u in unmatched[:15]])


if __name__ == "__main__":
    main()
