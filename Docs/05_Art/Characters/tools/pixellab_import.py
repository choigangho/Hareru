"""Pixellab 캐릭터 내려받기 → 앱 규격 프레임 (48×48, 투명, 발 기준 하단 정렬).

python3 pixellab_import.py <characters.json> <pixellab_dir> <app_characters_dir> <previews_dir> [name ...]

characters.json: {"<voiceId 또는 chief_researcher/newcomer>": "<Pixellab character id>"}
<pixellab_dir>/<name>/ 에 원본 zip 내용(rotations, animations)을 받아 두고,
앱에는 <name>_idle_se / _idle_nw / _walk_se_a.. (걷기 프레임 수만큼) 를 씀.
Pillow 필요.
"""
import io
import json
import string
import sys
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image

SIZE = 48


def download(char_id: str, dest: Path) -> None:
    url = f"https://api.pixellab.ai/mcp/characters/{char_id}/download"
    data = urllib.request.urlopen(url).read()
    for old in dest.glob("**/*.png"):
        old.unlink()
    zipfile.ZipFile(io.BytesIO(data)).extractall(dest)


def bottom_align(frames: list[Image.Image]) -> list[Image.Image]:
    """같은 묶음은 같은 만큼만 내림 — 걷기의 위아래 흔들림은 살리고 가장 낮은 발이 바닥(48행)에 닿게."""
    frames = [f.convert("RGBA") for f in frames]
    lowest = max(f.getbbox()[3] for f in frames)
    out = []
    for f in frames:
        assert f.size == (SIZE, SIZE), f.size
        canvas = Image.new("RGBA", (SIZE, SIZE))
        canvas.paste(f, (0, SIZE - lowest), f)
        out.append(canvas)
    return out


def walk_frames(state_dir: Path) -> list[Path]:
    walks = sorted((state_dir / "animations").glob("*/south-east"))
    return sorted(walks[0].glob("frame_*.png")) if walks else []


def preview(frames: list[Image.Image], path: Path, scale: int = 6) -> None:
    sheet = Image.new("RGBA", (SIZE * len(frames), SIZE), (28, 32, 36, 255))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * SIZE, 0), f)
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(path)


def main() -> None:
    mapping = json.loads(Path(sys.argv[1]).read_text())
    raw_dir, app_dir, preview_dir = (Path(p) for p in sys.argv[2:5])
    names = sys.argv[5:] or list(mapping)
    for name in names:
        dest = raw_dir / name
        download(mapping[name], dest)
        state = next(dest.glob("*/rotations")).parent
        idle = bottom_align([Image.open(state / "rotations" / f"{d}.png") for d in ("south-east", "north-west")])
        walk = bottom_align([Image.open(p) for p in walk_frames(state)]) or [idle[0], idle[0]]
        outputs = {"idle_se": idle[0], "idle_nw": idle[1]}
        outputs.update({f"walk_se_{string.ascii_lowercase[i]}": f for i, f in enumerate(walk)})
        for old in app_dir.glob(f"{name}_walk_se_*.png"):
            old.unlink()
        for suffix, image in outputs.items():
            image.save(app_dir / f"{name}_{suffix}.png")
        preview([idle[0], *walk, idle[1]], preview_dir / f"preview_{name}_pixellab_x6.png")
        print(name, "walk frames:", len(walk))


if __name__ == "__main__":
    main()
