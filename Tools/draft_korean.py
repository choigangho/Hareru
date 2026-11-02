#!/usr/bin/env python3
"""N4~N1 한국어 뜻 · 한자 훈음 초안을 Gemini로 일괄 생성 (예문은 비워 둠 → 앱에 "예문 추후 추가 예정").

사용법:
    python3 -I Tools/draft_korean.py N4            # 한 급수
    python3 -I Tools/draft_korean.py N4 N3 N2 N1   # 여러 급수 차례로
    python3 -I Tools/draft_korean.py N4 --limit 40 # 시험 삼아 일부만

- 키: macOS 키체인 항목 `hareru-gemini` (Tools/gemini_chat.py와 같음). 모델 기본값은 무료 등급 gemini-3.5-flash.
- 결과: Tools/drafts/<급수>_meanings.json — export_catalog.py가 읽는 짧은 형식 그대로.
  {"words": {id: {"t", "c", "s": [[품사, 뜻, null, "", "", "", ""]], "n"?}}, "kanji": {한자: [훈음, 부수 이름, 뜻...]}}
- 묶음마다 바로 저장하므로 중간에 끊겨도 다시 실행하면 이어서 합니다. 이미 다른 초안에 있는 한자는 건너뜁니다.
- 끝나면: sh Tools/export_levels.sh → swift test
"""
import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRAFTS = ROOT / "Tools" / "drafts"
BUILD = ROOT / "Tools" / "build"
API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# N5 초안에서 쓴 분류 · 품사 이름 (앱 화면 표기 통일)
CATEGORIES = ["시간·일상", "생활·날씨", "음식", "사고·판단", "일상·관계", "상태·거래", "감각·판단", "일상 회화",
              "행동·요구", "비즈니스", "비즈니스·접객", "안전·판단", "모임·관계", "사회·제도", "자연·과학", "감정·성격",
              "학교·학문", "건강·몸", "교통·장소", "문화·예술"]
PARTS_OF_SPEECH = ["명사", "동사", "い형용사", "な형용사", "부사", "대명사", "수사", "조수사", "접미사", "접두어",
                   "연체사", "감탄사", "접속사", "조사", "표현"]

WORD_PROMPT = f"""너는 한국인 JLPT 학습자를 위한 일본어 단어장 편집자다.
각 단어에 대해 한국어 뜻 초안을 만든다.
- senses: 자주 쓰는 의미만 1~3개, 가장 대표적인 의미가 첫 번째. 영어 뜻은 참고용이며 그대로 번역하지 말고 자연스러운 한국어 사전 뜻풀이로.
- meaning: 짧게 (예: "깨다, 잠이 깨다"). partOfSpeech는 다음 중 하나: {", ".join(PARTS_OF_SPEECH)}
- category는 다음 중 하나: {", ".join(CATEGORIES)}
- 표제어에 한자가 하나도 없는 단어만 note를 채운다: kind는 L(외래어) · K(원래 가나로 쓰는 말) · O(의성어·의태어),
  explanation은 한국어 한 문장, 외래어면 originLanguage(예: "영어")와 originTerm(예: "radio")도. 한자가 있으면 note는 생략."""

KANJI_PROMPT = """너는 한국 한자 교육 자료 편집자다. 각 한자에 대해:
- hunEum: 한국 표준 훈음 (예: "마실 음")
- radicalKoreanName: 주어진 부수 글자의 한국어 부수 이름 (예: 食 → "밥 식")
- meanings: 일본어에서 쓰이는 핵심 뜻 1~3개를 한국어로 (예: "마시다", "삼키다")"""

WORD_SCHEMA = {"type": "ARRAY", "items": {"type": "OBJECT", "required": ["id", "category", "senses"], "properties": {
    "id": {"type": "STRING"},
    "category": {"type": "STRING", "enum": CATEGORIES},
    "senses": {"type": "ARRAY", "items": {"type": "OBJECT", "required": ["partOfSpeech", "meaning"], "properties": {
        "partOfSpeech": {"type": "STRING", "enum": PARTS_OF_SPEECH}, "meaning": {"type": "STRING"}}}},
    "note": {"type": "OBJECT", "required": ["kind", "explanation"], "properties": {
        "kind": {"type": "STRING", "enum": ["L", "K", "O"]}, "explanation": {"type": "STRING"},
        "originLanguage": {"type": "STRING"}, "originTerm": {"type": "STRING"}}},
}}}
KANJI_SCHEMA = {"type": "ARRAY", "items": {"type": "OBJECT", "required": ["character", "hunEum", "radicalKoreanName", "meanings"],
    "properties": {"character": {"type": "STRING"}, "hunEum": {"type": "STRING"},
                   "radicalKoreanName": {"type": "STRING"}, "meanings": {"type": "ARRAY", "items": {"type": "STRING"}}}}}


def api_key():
    try:
        return subprocess.run(["security", "find-generic-password", "-s", "hareru-gemini", "-w"],
                              check=True, capture_output=True, text=True).stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit("키체인에 hareru-gemini 키가 없습니다 (Tools/gemini_chat.py 사용법 참고).")


def ask(key, model, prompt, items, schema):
    body = json.dumps({
        "systemInstruction": {"parts": [{"text": prompt}]},
        "contents": [{"role": "user", "parts": [{"text": json.dumps(items, ensure_ascii=False)}]}],
        "generationConfig": {"responseMimeType": "application/json", "responseSchema": schema, "temperature": 0.2},
    }).encode()
    request = urllib.request.Request(API.format(model=model), data=body,
                                     headers={"Content-Type": "application/json", "x-goog-api-key": key})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                data = json.load(response)
            return json.loads(data["candidates"][0]["content"]["parts"][0]["text"])
        except urllib.error.HTTPError as error:
            if error.code not in (429, 500, 503):
                sys.exit(f"[오류 {error.code}] {error.read().decode('utf-8', 'replace')[:400]}")
            wait = 20 * (attempt + 1)
            print(f"  (요청 제한 {error.code} — {wait}초 뒤 다시)", flush=True)
            time.sleep(wait)
        except (KeyError, json.JSONDecodeError, urllib.error.URLError, TimeoutError) as error:
            print(f"  (응답 이상: {error} — 다시)", flush=True)
            time.sleep(5)
    sys.exit("여러 번 실패 — 잠시 뒤 다시 실행하면 이어서 합니다.")


def is_kanji(ch):
    cp = ord(ch)
    return 0x4E00 <= cp <= 0x9FFF or 0x3400 <= cp <= 0x4DBF or 0xF900 <= cp <= 0xFAFF


def drafted_kanji():
    done = set()
    for path in DRAFTS.glob("*.json"):
        done.update(json.loads(path.read_text(encoding="utf-8")).get("kanji", {}))
    return done


def draft_level(key, model, level, words_base, kanji_base, limit, batch):
    out_path = DRAFTS / f"{level.lower()}_meanings.json"
    draft = json.loads(out_path.read_text(encoding="utf-8")) if out_path.exists() else {
        "about": f"{level} 한국어 뜻 · 한자 초안 — Gemini 일괄 생성 (검수 전). 예문은 추후 추가.", "words": {}, "kanji": {}}
    save = lambda: out_path.write_text(json.dumps(draft, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    todo = [w for w in words_base if w["jlptLevel"] == level and w["id"] not in draft["words"]]
    if limit:
        todo = todo[:limit]
    print(f"{level}: 단어 {len(todo)}개 남음 → {out_path.relative_to(ROOT)}")
    for start in range(0, len(todo), batch):
        chunk = todo[start:start + batch]
        items = [{"id": w["id"], "term": w["term"], "reading": w["reading"],
                  "partsOfSpeech": w["partsOfSpeech"], "englishSenses": w["englishSenses"][:4]} for w in chunk]
        by_id = {w["id"]: w for w in chunk}
        for result in ask(key, model, WORD_PROMPT, items, WORD_SCHEMA):
            base = by_id.get(result["id"])
            if not base or not result["senses"]:
                continue
            entry = {"t": base["term"], "c": result["category"],
                     "s": [[s["partOfSpeech"], s["meaning"], None, "", "", "", ""] for s in result["senses"][:3]]}
            note = result.get("note")
            if not any(is_kanji(c) for c in base["term"]):
                if not note:
                    continue  # 한자 없는 단어는 설명이 필수 — 다음 실행 때 다시 시도
                entry["n"] = [note["kind"], note["explanation"]] + (
                    [note.get("originLanguage", ""), note.get("originTerm", "")] if note.get("originTerm") else [])
            draft["words"][base["id"]] = entry
        save()
        print(f"  단어 {min(start + batch, len(todo))}/{len(todo)}", flush=True)

    needed = {c for wid in draft["words"] for c in draft["words"][wid]["t"] if is_kanji(c)}
    kanji_todo = sorted(needed - drafted_kanji(), key=lambda c: kanji_base[c]["frequencyRank"] or 9999)
    print(f"{level}: 한자 {len(kanji_todo)}자 남음")
    for start in range(0, len(kanji_todo), batch):
        chunk = kanji_todo[start:start + batch]
        items = [{"character": c, "radical": kanji_base[c]["radicalCharacter"],
                  "englishMeanings": kanji_base[c]["englishMeanings"][:4], "koreanEum": kanji_base[c]["koreanEum"]}
                 for c in chunk]
        for result in ask(key, model, KANJI_PROMPT, items, KANJI_SCHEMA):
            if result["character"] in chunk and result["meanings"]:
                draft["kanji"][result["character"]] = [result["hunEum"], result["radicalKoreanName"], *result["meanings"][:3]]
        save()
        print(f"  한자 {min(start + batch, len(kanji_todo))}/{len(kanji_todo)}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("levels", nargs="+", choices=["N4", "N3", "N2", "N1"])
    parser.add_argument("--model", default="gemini-3.5-flash")
    parser.add_argument("--limit", type=int, default=0, help="급수마다 이 개수만 (시험용)")
    parser.add_argument("--batch", type=int, default=40)
    args = parser.parse_args()

    words_base = json.loads((BUILD / "words_base.json").read_text(encoding="utf-8"))
    kanji_base = {k["character"]: k for k in json.loads((BUILD / "kanji_base.json").read_text(encoding="utf-8"))}
    key = api_key()
    for level in args.levels:
        draft_level(key, args.model, level, words_base, kanji_base, args.limit, args.batch)


if __name__ == "__main__":
    main()
