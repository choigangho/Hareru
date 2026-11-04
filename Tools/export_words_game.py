#!/usr/bin/env python3
"""N5 단어 데이터를 Godot 게임(Game/)용으로 내보내기.

    python3 -I Tools/export_words_game.py     # → Game/data/words_n5.json

원본: Tools/build/n5/words.json (Tools 파이프라인 결과, 로드맵 §3-4 원본은 한 곳).
- words: 게임이 쓰는 필드만 (id · term · reading · category · trauma · senses[meaning · example · translation · target])
- d1_queue: D1 판독 순서. tutorial = T-2 대본에 적힌 5장 (고정).
  task = T-8 15장 — TASK_OVERRIDE (오너 확정 2026-11-04, SLICE_SCOPE L-3). 비우면 자동 선택으로 돌아감
  (분야 없음 · 트라우마 아님 · 주인공 A 음성 있음 · 튜토리얼 제외 · 한자 단어 먼저).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Tools" / "build" / "n5" / "words.json"
AUDIO = ROOT / "Tools" / "build" / "audio" / "protagonist_a"
OUT = ROOT / "Game" / "data" / "words_n5.json"

TUTORIAL = ["はい", "いいえ", "分かる", "見る", "名前"]   # N5_SCRIPT T-2
# 오너 확정 (2026-11-04): D1 대사에 학습 단어로 나오는 '분야 없음' 13개 + 1일차 주제 2개(声 · 初めて)
TASK_OVERRIDE: list[str] = ["本当", "そう", "大丈夫", "少し", "よく", "できる", "静か", "全部", "どうぞ",
                            "疲れる", "さあ", "明るい", "また", "声", "初めて"]


def slim(w):
    return {
        "id": w["id"], "term": w["term"], "reading": w["reading"], "category": w["category"],
        "trauma": w.get("trauma") or "",
        "senses": [{
            "meaning": s["meaning"],
            "example": s.get("exampleMarkup", ""),
            "target": s.get("exampleTarget", ["", "", ""]),
            "translation": s.get("translation", {"before": "", "answer": "", "after": ""}),
        } for s in w["senses"]],
    }


def has_audio(wid):
    return (AUDIO / f"{wid}_term.m4a").exists() and (AUDIO / f"{wid}_s1_example.m4a").exists()


def main():
    words = json.loads(SRC.read_text(encoding="utf-8"))
    by_term = {}
    for w in words:
        by_term.setdefault(w["term"], w)
    tutorial = [by_term[t]["id"] for t in TUTORIAL]
    for t in TASK_OVERRIDE:
        w = by_term[t]
        assert w["category"] == "분야 없음" and not w.get("trauma"), f"{t}: L-3 규칙 위반"
    if TASK_OVERRIDE:
        task = [by_term[t]["id"] for t in TASK_OVERRIDE]
    else:
        pool = [w for w in words if w["category"] == "분야 없음" and not w.get("trauma")
                and w["id"] not in tutorial and has_audio(w["id"]) and w["senses"][0].get("exampleMarkup")]
        pool.sort(key=lambda w: (not any("\u4e00" <= c <= "\u9fff" for c in w["term"]), len(w["reading"]), w["id"]))
        task, seen = [], set()
        for w in pool:
            if w["term"] not in seen:
                seen.add(w["term"])
                task.append(w["id"])
            if len(task) == 15:
                break
    out = {"words": [slim(w) for w in words],
           "d1_queue": {"tutorial": tutorial, "task": task, "task_is_provisional": not TASK_OVERRIDE}}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: {len(words)}단어 · D1 튜토리얼 {len(tutorial)} + 과제 {len(task)}"
          + (" (과제는 임시 자동 선택)" if not TASK_OVERRIDE else ""))
    print("과제:", " ".join(by_id["term"] for by_id in (next(w for w in words if w["id"] == i) for i in task)))


if __name__ == "__main__":
    main()
