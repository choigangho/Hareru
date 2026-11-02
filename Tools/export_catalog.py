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
import re
import sys
from pathlib import Path

PART_OF_SPEECH_ORDER = ["N5", "N4", "N3", "N2", "N1"]


def is_kanji(ch: str) -> bool:
    cp = ord(ch)
    return 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF


NON_KANJI_KINDS = {"L": "loanword", "K": "native_kana", "O": "onomatopoeia"}
# 분야 없음 단어의 담당 음성 (draft_korean.py의 P/C)
FIELDLESS_VOICES = {"P": "protagonist", "C": "chiefResearcher"}


RUBY = re.compile(r"\{([^|{}]+)\|([^{}]+)\}")


def kanji_level(c: str, kanji_base: dict) -> int:
    """한자의 (추정) 급수 순번. 상용한자 밖 한자는 N1로 취급 (시험에서도 가나로 냄)."""
    if c not in kanji_base or not kanji_base[c]["isJoyo"]:
        return len(PART_OF_SPEECH_ORDER) - 1
    return PART_OF_SPEECH_ORDER.index(kanji_base[c]["jlptLevel"])


def term_at(base: dict, stage: int, kanji_base: dict) -> str:
    """JLPT 시험처럼 그 급수까지의 한자만 한자로, 나머지는 히라가나로 쓴 표제어.
    한자별 읽기(kanjiUsages)가 없는 한자(当て字·숙자훈)가 가려지면 표제어 전체를 읽기로."""
    # 当て字·숙자훈(readingType "special")은 한자별 읽기가 아니라 묶음 읽기 → 한 글자씩 가나로 바꿀 수 없음
    readings = {u["kanji"]: u.get("activeReading") for u in base["kanjiUsages"] if u.get("readingType") != "special"}
    out = []
    for c in base["term"]:
        if is_kanji(c) and kanji_level(c, kanji_base) > stage:
            if not readings.get(c):
                return base["reading"]
            out.append(readings[c])
        else:
            out.append(c)
    return "".join(out)


def markup_at(markup: str, stage: int, kanji_base: dict) -> str:
    """예문 마크업 {漢字|かな}에서 그 급수보다 어려운 한자가 있는 묶음은 읽기(가나)로."""
    return RUBY.sub(lambda m: m.group(0) if all(kanji_level(c, kanji_base) <= stage for c in m.group(1) if is_kanji(c))
                    else m.group(2), markup)


# 표적 단어 뒤에 붙는 활용 어미 (동사 · い형용사). 앞의 한 글자는 활용 단의 가나 (行[き]ます, 飲[ん]だ, 高[か]った)
_ENDINGS = (r"(?:ませんでした|ましょう|ました|ません|ます|なかった|なくて|ない|たかった|たい|ています|ている|ていた"
            r"|てください|てくれ|なさい|って|った|んで|んだ|かった|くて|て|た|だ|で|ば|う|る|ろ|よう)")
# で · だ는 활용 단 가나 뒤에서만 (泳[い]で, 飲[ん]だ) — 바로 붙으면 お忘れ[です]처럼 뒤 말
CONJUGATION = rf"(?:[ぁ-ゖ]{_ENDINGS}|(?![でだ]){_ENDINGS}|(?![でだ])[ぁ-ゖ])"
ADJECTIVE_ENDINGS = r"(?:くなかった|くない|くて|かった|ければ|く|い|さ)"


def split_target(markup: str, term: str, reading: str, part_of_speech: str):
    """예문 마크업을 [앞, 표적 단어, 뒤]로 (번역의 before/answer/after와 같은 모양). 못 찾으면 None.
    표적은 마크업 묶음 경계에 맞춤 — 앞+표적+뒤를 이으면 원래 마크업."""
    tokens = []  # (마크업 조각, 화면 글자)
    position = 0
    for m in RUBY.finditer(markup):
        tokens += [(c, c) for c in markup[position:m.start()]]
        tokens.append((m.group(0), m.group(1)))
        position = m.end()
    tokens += [(c, c) for c in markup[position:]]
    starts, offset = [], 0
    for _, surface in tokens:
        starts.append(offset)
        offset += len(surface)
    display = "".join(surface for _, surface in tokens)

    conjugates = part_of_speech in ("동사", "い형용사") and len(term) > 1 and not is_kanji(term[-1])
    for form in dict.fromkeys([term, reading]):
        stem = form[:-1] if conjugates else form
        # 가나만으로 된 어간(はく → は)은 조사와 헷갈리므로 활용 어미가 꼭 붙은 것만
        ending = ADJECTIVE_ENDINGS if part_of_speech == "い형용사" else CONJUGATION
        ending = (ending + ("?" if any(is_kanji(c) for c in stem) else "")) if conjugates else ""
        pattern = re.compile("(?=(" + re.escape(stem) + ending + "))")
        matches = [(m.start(), m.start() + len(m.group(1))) for m in pattern.finditer(display)]
        # 묶음 첫 글자에서 시작하는 것 우선 (銀行 속 行 제외), 없으면 조수사처럼 묶음 안(五百円의 円) → 그 묶음 전체
        for begin, end in sorted(matches, key=lambda span: span[0] not in starts):
            first = max(i for i, start in enumerate(starts) if start <= begin)
            last = max(i for i, start in enumerate(starts) if start < end)
            pieces = [t for t, _ in tokens]
            return ["".join(pieces[:first]), "".join(pieces[first:last + 1]), "".join(pieces[last + 1:])]
    return None


def staged(make, first: int) -> list:
    """단어 급수부터 N1까지 표기가 바뀌는 지점만 [(급수, 표기)]. 처음부터 끝까지 같으면 빈 목록."""
    stages = []
    for stage in range(first, len(PART_OF_SPEECH_ORDER)):
        text = make(stage)
        if not stages or stages[-1][1] != text:
            stages.append((PART_OF_SPEECH_ORDER[stage], text))
    return stages if len(stages) > 1 else []


def normalize_word_draft(draft: dict) -> dict:
    """짧은 형식도 허용:
    {"t": 표제어, "c": 대분류, "f": 분야 없음 담당 P/C(선택), "s": [[품사, 뜻, 음성ID(미정이면 null), 예문 마크업, before, answer, after], ...],
     "n": [종류 L/K/O, 설명, 원어(선택), 원어 표기(선택)]}"""
    if "t" not in draft:
        return draft
    senses = [{"partOfSpeech": s[0], "meaning": s[1], "voiceId": s[2], "exampleMarkup": s[3],
               "translation": {"before": s[4], "answer": s[5], "after": s[6]}} for s in draft["s"]]
    result = {"term": draft["t"], "category": draft["c"], "senses": senses}
    if "f" in draft:
        result["fieldlessVoice"] = FIELDLESS_VOICES[draft["f"]]
    if "n" in draft:
        n = draft["n"]
        note = {"kind": NON_KANJI_KINDS.get(n[0], n[0]), "explanation": n[1]}
        if len(n) > 2:
            note["originLanguage"] = n[2]
        if len(n) > 3:
            note["originTerm"] = n[3]
        result["nonKanjiNote"] = note
    return result


def export_word(base: dict, draft: dict, kanji_base: dict) -> dict:
    draft = normalize_word_draft(draft)
    if draft["term"] != base["term"]:
        raise SystemExit(f"초안 표제어 불일치: {base['id']} base={base['term']} draft={draft['term']}")
    level = PART_OF_SPEECH_ORDER.index(base["jlptLevel"])
    senses = []
    for number, sense in enumerate(draft["senses"], start=1):
        sense_id = f"{base['id']}_s{number}"
        example_stages = staged(lambda stage: markup_at(sense["exampleMarkup"], stage, kanji_base), level)
        target = split_target(sense["exampleMarkup"], base["term"], base["reading"], sense["partOfSpeech"]) \
            if sense["exampleMarkup"] else None
        senses.append({
            "id": sense_id,
            "senseNumber": number,
            "partOfSpeech": sense["partOfSpeech"],
            "meaning": sense["meaning"],
            "exampleMarkup": sense["exampleMarkup"],
            "translation": sense["translation"],
            # 음성 캐릭터는 게임 인물과 연동 예정 — 배정 전에는 "unassigned"
            "voiceId": sense.get("voiceId") or "unassigned",
            "exampleAudioFile": f"{sense_id}_example",
        })
        if target:
            senses[-1]["exampleTarget"] = target
        if example_stages:
            senses[-1]["exampleNotations"] = [{"level": lv, "markup": text} for lv, text in example_stages]
            if target:  # 묶음 단위로 바뀌므로 조각마다 따로 바꿔도 이어 붙이면 그 급수 예문과 같음
                for notation in senses[-1]["exampleNotations"]:
                    stage = PART_OF_SPEECH_ORDER.index(notation["level"])
                    notation["target"] = [markup_at(piece, stage, kanji_base) for piece in target]
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
    if "fieldlessVoice" in draft:
        word["fieldlessVoice"] = draft["fieldlessVoice"]
    # 급수별 표기: 단어 급수에선 아직 안 배운 한자를 가나로, 그 한자의 급수가 되면 한자로 (바뀌는 순간 앱에서 재학습)
    term_stages = staged(lambda stage: term_at(base, stage, kanji_base), level)
    if term_stages:
        word["notations"] = [{"level": lv, "term": text} for lv, text in term_stages]
        # 단어 급수보다 어려운 한자가 들어간 단어 → 담당 인물을 만나기 전까지 주인공 음성 (음성 세션 요청)
        word["aboveLevelKanji"] = True
    if "nonKanjiNote" in draft:
        word["nonKanjiNote"] = draft["nonKanjiNote"]
    return word


def normalize_kanji_draft(draft) -> dict:
    """짧은 형식 [훈음, 부수 한국어 이름, 뜻1, 뜻2, ...]도 허용"""
    if isinstance(draft, list):
        return {"hunEum": draft[0], "radicalKoreanName": draft[1], "meanings": draft[2:]}
    return draft


def export_kanji(base: dict, draft: dict) -> dict:
    draft = normalize_kanji_draft(draft)
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

    words = [export_word(words_base[wid], draft, kanji_base) for wid, draft in word_drafts.items()]
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
