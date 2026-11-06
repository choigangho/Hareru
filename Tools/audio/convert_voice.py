#!/usr/bin/env python3
"""Copy the Day 1 voices the game needs into Game/audio/voice as WAV (Godot does not play m4a).

    python3 Tools/audio/convert_voice.py

- Story lines: Sources/Hareru/Resources/Audio/Story/story_d1_*.m4a → voice/story/ (same names).
- Words of the Day 1 piles (Game/data/words_n5.json d1_queue): term + example per sense.
  The chief reads a word when her file exists (she is met on Day 1), otherwise the protagonist
  (VOICE_RULES: unmet characters' words are read by the protagonist) → voice/words/<id>_term.wav …
Uses macOS afconvert: mono 16-bit 22050 Hz.
"""
import json
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Game" / "audio" / "voice"
WORD_SRC = ROOT / "Tools" / "build" / "audio"


def convert(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "a.wav"
        subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16@22050", "-c", "1", str(src), str(raw)], check=True)
        pcm = data_chunk(raw.read_bytes())
    # afconvert writes WAVE_FORMAT_EXTENSIBLE, which Godot refuses: rewrite as plain PCM
    with wave.open(str(dst), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(22050)
        w.writeframes(pcm)
    print(dst.relative_to(ROOT))


def data_chunk(b: bytes) -> bytes:
    i = 12
    while i + 8 <= len(b):
        cid, size = b[i:i + 4], struct.unpack("<I", b[i + 4:i + 8])[0]
        if cid == b"data":
            return b[i + 8:i + 8 + size]
        i += 8 + size + (size & 1)
    raise ValueError("no data chunk")


def main() -> None:
    for src in sorted((ROOT / "Sources/Hareru/Resources/Audio/Story").glob("story_d1_*.m4a")):
        convert(src, OUT / "story" / (src.stem + ".wav"))
    q = json.loads((ROOT / "Game/data/words_n5.json").read_text())["d1_queue"]
    for wid in q["tutorial"] + q["task"]:
        for voice in ["guide_researcher", "protagonist_a"]:
            files = sorted((WORD_SRC / voice).glob(f"{wid}_*.m4a"))
            if files:
                for src in files:
                    convert(src, OUT / "words" / (src.stem + ".wav"))
                break
        else:
            print("no voice:", wid)


if __name__ == "__main__":
    main()
