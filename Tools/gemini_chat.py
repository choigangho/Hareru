#!/usr/bin/env python3
"""Gemini(아르곤)와 스토리 연출을 이어서 이야기하는 터미널 채팅. 클로드 토큰은 쓰지 않습니다.

사용법:
    python3 -I Tools/gemini_chat.py                 # 기본 세션(story) 이어서
    python3 -I Tools/gemini_chat.py --session intro # 다른 세션
    python3 -I Tools/gemini_chat.py --model gemini-3.1-pro-preview

- 키: macOS 키체인 항목 `hareru-gemini` (저장소에는 넣지 않음).
    security add-generic-password -U -s hareru-gemini -a "$USER" -w "<키>"
- 배경 지식: Docs/STORY_BIBLE.md · Docs/GAME_DESIGN.md · Docs/PIXELLAB_ASSET_PLAN.md 를
  시스템 지시로 매번 함께 보냅니다.
- 이전 제미나이 앱 대화: Docs/Story/imports/*.md 에 복사해 두면 새 세션을 시작할 때 이전 대화로 넣습니다.
- 대화는 Docs/Story/sessions/<세션>.json(이어가기용)과 <세션>.md(읽기용)에 한 턴마다 저장됩니다.

입력 중 명령: /paste (여러 줄 입력, 마지막 줄에 . 만 입력해서 끝냄) · /quit
"""
import argparse
import datetime
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STORY = ROOT / "Docs" / "Story"
CONTEXT_DOCS = ["Docs/STORY_BIBLE.md", "Docs/GAME_DESIGN.md", "Docs/PIXELLAB_ASSET_PLAN.md"]
API = "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse"

SYSTEM_PROMPT = """너는 Hareru(晴れる) 프로젝트의 스토리 · 연출 브레인스토밍 파트너다.
Hareru는 JLPT 단어 학습 iOS 앱이자, 2094년 국립언어유산연구소(NJL)를 무대로 한 픽셀아트 연구소 게임이다.
아래 문서들이 현재 확정된 설정이다. 설정과 어긋나는 제안은 어긋난다고 밝히고, 한국어로 답한다."""


def api_key():
    try:
        return subprocess.run(
            ["security", "find-generic-password", "-s", "hareru-gemini", "-w"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit("키체인에 hareru-gemini 키가 없습니다. 파일 맨 위 사용법을 보세요.")


def system_instruction():
    parts = [SYSTEM_PROMPT]
    for rel in CONTEXT_DOCS:
        path = ROOT / rel
        if path.exists():
            parts.append(f"\n\n===== {rel} =====\n{path.read_text(encoding='utf-8')}")
    return {"parts": [{"text": "".join(parts)}]}


def imported_history():
    files = sorted((STORY / "imports").glob("*.md"))
    if not files:
        return []
    text = "\n\n".join(f"===== {f.name} =====\n{f.read_text(encoding='utf-8')}" for f in files)
    return [
        {"role": "user", "parts": [{"text": "아래는 우리가 제미나이 앱에서 나눴던 이전 대화 기록이야. 이 흐름을 그대로 이어서 이야기하자.\n\n" + text}]},
        {"role": "model", "parts": [{"text": "이전 대화 기록을 모두 읽었어. 그 흐름에서 이어서 이야기하자."}]},
    ]


def stream_reply(key, model, history):
    body = json.dumps({"systemInstruction": system_instruction(), "contents": history}).encode()
    request = urllib.request.Request(
        API.format(model=model), data=body,
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    reply, usage = [], {}
    with urllib.request.urlopen(request, timeout=600) as response:
        for raw in response:
            line = raw.decode("utf-8").strip()
            if not line.startswith("data:"):
                continue
            chunk = json.loads(line[5:])
            usage = chunk.get("usageMetadata", usage)
            for candidate in chunk.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if part.get("text") and not part.get("thought"):
                        print(part["text"], end="", flush=True)
                        reply.append(part["text"])
    print()
    return "".join(reply), usage


def read_message():
    line = input("\n나 > ").strip()
    if line != "/paste":
        return line
    print("(여러 줄 입력 — 끝내려면 . 만 있는 줄)")
    lines = []
    while (line := input()) != ".":
        lines.append(line)
    return "\n".join(lines).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--session", default="story")
    parser.add_argument("--model", default="gemini-4-argon")
    args = parser.parse_args()

    sessions = STORY / "sessions"
    sessions.mkdir(parents=True, exist_ok=True)
    state_path = sessions / f"{args.session}.json"
    log_path = sessions / f"{args.session}.md"

    if state_path.exists():
        history = json.loads(state_path.read_text(encoding="utf-8"))
        print(f"세션 '{args.session}' 이어서 ({len(history) // 2}턴) · 모델 {args.model}")
    else:
        history = imported_history()
        note = f" · 이전 대화 {len(list((STORY / 'imports').glob('*.md')))}개 불러옴" if history else ""
        print(f"새 세션 '{args.session}' · 모델 {args.model}{note}")
    key = api_key()

    while True:
        try:
            message = read_message()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if message in ("/quit", "/exit"):
            break
        if not message:
            continue

        history.append({"role": "user", "parts": [{"text": message}]})
        print(f"\n{args.model} > ", end="", flush=True)
        try:
            reply, usage = stream_reply(key, args.model, history)
        except urllib.error.HTTPError as error:
            history.pop()
            print(f"\n[오류 {error.code}] {error.read().decode('utf-8', 'replace')[:500]}")
            continue
        except KeyboardInterrupt:
            history.pop()
            print("\n(답변 중단 — 이 질문은 저장하지 않음)")
            continue

        history.append({"role": "model", "parts": [{"text": reply}]})
        state_path.write_text(json.dumps(history, ensure_ascii=False, indent=1), encoding="utf-8")
        stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        with log_path.open("a", encoding="utf-8") as log:
            log.write(f"\n## 나 · {stamp}\n\n{message}\n\n## {args.model}\n\n{reply}\n")
        if usage:
            print(f"[토큰 입력 {usage.get('promptTokenCount', 0):,} · 출력 {usage.get('candidatesTokenCount', 0):,}]")


if __name__ == "__main__":
    main()
