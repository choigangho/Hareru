#!/usr/bin/env python3
"""기본 데이터(kanji_base / words_base) + 한국어 초안(drafts/*.json) → 앱 형식 words.json / kanji.json.

사용법:
    python3 -I Tools/export_catalog.py Tools/build/kanji_base.json Tools/build/words_base.json \\
        Tools/drafts/n5_pilot.json Tools/build/pilot

- 초안이 있는 단어만 내보냅니다 (예문 없는 단어는 앱 카드가 성립하지 않으므로 제외).
- 내보낸 단어의 표제어에 쓰인 한자는 반드시 kanji.json에 함께 들어가야 하므로, 초안에 한자 한국어 정보가 없으면 오류.
- 검수용 표(review.md)도 함께 만듭니다.
- 앱의 CatalogRepository 무결성 검사는 Swift 테스트(testPilotCatalogExportPassesAppValidation)에서 수행.
"""
import json
import sys
from pathlib import Path

PART_OF_SPEECH_ORDER = ["N5", "N4", "N3", "N2", "N1"]


def is_kanji(ch: str) -> bool:
    cp = ord(ch)
    return 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF


def export_word(base: dict, draft: dict) -> dict:
    if draft["term"] != base["term"]:
        raise SystemExit(f"초안 표제어 불일치: {base['id']} base={base['term']} draft={draft['term']}")
    senses = []
    for number, sense in enumerate(draft["senses"], start=1):
        sense_id = f"{base['id']}_s{number}"
        senses.append({
            "id": sense_id,
            "senseNumber": number,
            "partOfSpeech": sense["partOfSpeech"],
            "meaning": sense["meaning"],
            "exampleMarkup": sense["exampleMarkup"],
            "translation": sense["translation"],
            "voiceId": sense["voiceId"],
            "exampleAudioFile": f"{sense_id}_example",
        })
    word = {
        "id": base["id"],
        "jlptLevel": base["jlptLevel"],
        "category": draft["category"],
        "term": base["term"],
        "reading": base["reading"],
        "termAudioFile": f"{base['id']}_term",
        "senses": senses,
        "kanjiUsages": [{k: v for k, v in u.items() if v is not None} for u in base["kanjiUsages"]],
    }
    if "nonKanjiNote" in draft:
        word["nonKanjiNote"] = draft["nonKanjiNote"]
    return word


def export_kanji(base: dict, draft: dict) -> dict:
    return {
        "character": base["character"],
        "koreanHunEum": draft["hunEum"],
        "meanings": draft["meanings"],
        "onyomi": base["onyomi"],
        "kunyomi": base["kunyomi"],
        "strokeCount": base["strokeCount"],
        "radical": f"{base['radicalCharacter']} ({draft['radicalKoreanName']})",
        "jlptLevel": base["jlptLevel"],
    }


def review_table(words: list, kanji: list) -> str:
    lines = ["# 시험 배치 검수표", "",
             "고칠 내용은 `Tools/drafts/` 초안 JSON을 직접 고치거나, 이 표에 메모해 주세요.", "",
             "## 단어", "", "| 단어 | 읽기 | 뜻 | 예문 | 해석 | 음성 |", "| :--- | :--- | :--- | :--- | :--- | :--- |"]
    for w in words:
        for s in w["senses"]:
            t = s["translation"]
            lines.append(f"| {w['term']} | {w['reading']} | {s['meaning']} ({s['partOfSpeech']}) | "
                         f"{s['exampleMarkup']} | {t['before']}**{t['answer']}**{t['after']} | {s['voiceId']} |")
    lines += ["", "## 한자", "", "| 한자 | 훈음 | 뜻 | 음독 | 훈독 | 부수 | 급수 |",
              "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |"]
    for k in kanji:
        lines.append(f"| {k['character']} | {k['koreanHunEum']} | {', '.join(k['meanings'])} | "
                     f"{' '.join(k['onyomi'])} | {' '.join(k['kunyomi'][:4])} | {k['radical']} | {k['jlptLevel']} |")
    return "\n".join(lines) + "\n"


def main() -> None:
    kanji_base_path, words_base_path, *draft_paths, out_dir = map(Path, sys.argv[1:])
    kanji_base = {k["character"]: k for k in json.loads(kanji_base_path.read_text(encoding="utf-8"))}
    words_base = {w["id"]: w for w in json.loads(words_base_path.read_text(encoding="utf-8"))}

    kanji_drafts, word_drafts = {}, {}
    for path in draft_paths:
        data = json.loads(path.read_text(encoding="utf-8"))
        kanji_drafts.update(data.get("kanji", {}))
        word_drafts.update(data.get("words", {}))

    words = [export_word(words_base[wid], draft) for wid, draft in word_drafts.items()]
    words.sort(key=lambda w: (PART_OF_SPEECH_ORDER.index(w["jlptLevel"]), w["reading"]))

    needed = sorted({c for w in words for c in w["term"] if is_kanji(c)},
                    key=lambda c: kanji_base[c]["frequencyRank"] or 9999)
    missing = [c for c in needed if c not in kanji_drafts]
    if missing:
        raise SystemExit(f"한자 한국어 초안 누락: {''.join(missing)}")
    kanji = [export_kanji(kanji_base[c], kanji_drafts[c]) for c in needed]

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "words.json").write_text(json.dumps(words, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (out_dir / "kanji.json").write_text(json.dumps(kanji, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (out_dir / "review.md").write_text(review_table(words, kanji), encoding="utf-8")
    print(f"단어 {len(words)}개 · 한자 {len(kanji)}자 → {out_dir}")


if __name__ == "__main__":
    main()
