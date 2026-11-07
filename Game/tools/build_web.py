"""Export the web demo to build/web and give the game data a new file name per build.

Browsers keep index.pck for a while (GitHub Pages: max-age=600), so a fixed name means a
returning player gets the old game. The pck is renamed to index-<hash>.pck and the page's
GODOT_CONFIG points at it. The engine files (wasm/js) only change with the Godot version.

    python3 Game/tools/build_web.py [path/to/godot]
"""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "web"
GODOT = sys.argv[1] if len(sys.argv) > 1 else "/Applications/Godot.app/Contents/MacOS/Godot"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("index-*.pck"):
        old.unlink()   # last build's renamed pck (build/ is git-ignored output)
    subprocess.run([GODOT, "--headless", "--path", str(ROOT / "Game"),
                    "--export-release", "Web", "../build/web/index.html"], check=True)
    pck = OUT / "index.pck"
    name = "index-%s.pck" % hashlib.sha1(pck.read_bytes()).hexdigest()[:10]
    pck.rename(OUT / name)

    html = OUT / "index.html"
    text = html.read_text()
    m = re.search(r"GODOT_CONFIG = (\{.*?\});", text)
    cfg = json.loads(m.group(1))
    cfg["mainPack"] = name
    cfg["fileSizes"][name] = cfg["fileSizes"].pop("index.pck")
    text = text[:m.start(1)] + json.dumps(cfg, separators=(",", ":")) + text[m.end(1):]
    html.write_text(text)
    (OUT / ".nojekyll").touch()
    print("built", OUT, "->", name)


if __name__ == "__main__":
    main()
