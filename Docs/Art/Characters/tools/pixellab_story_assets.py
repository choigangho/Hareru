from __future__ import annotations
"""Hareru 스토리 소품(1번) + 미완성 캐릭터(2번: announcer_ai, courier_rin 도보 버전) 일괄 생성 스크립트.
외부 라이브러리(PIL 등) 없이 100% Python 표준 라이브러리(zlib, struct, zipfile)만으로 동작합니다.
"""
import base64
import io
import json
import os
import re
import string
import struct
import time
import urllib.error
import urllib.request
import zipfile
import zlib
from pathlib import Path

MCP_URL = "https://api.pixellab.ai/mcp"
REPO = Path(__file__).resolve().parents[4]
SIZE = 48


def load_token() -> str:
    env_tok = os.environ.get("PIXELLAB_TOKEN", "").strip()
    if env_tok:
        return env_tok
    candidates = [
        Path.home() / ".gemini" / "settings.json",
        Path("/Users/choigangho/.gemini/settings.json"),
        Path("/Users/choigangho/.gemini/users/user1/.gemini/settings.json"),
    ]
    for p in candidates:
        if p.exists():
            try:
                data = json.loads(p.read_text())
                auth = (
                    data.get("mcpServers", {})
                    .get("pixellab", {})
                    .get("headers", {})
                    .get("Authorization", "")
                )
                if auth.startswith("Bearer "):
                    return auth.split("Bearer ", 1)[1].strip()
            except Exception:
                pass
    raise RuntimeError("PIXELLAB_TOKEN 환경변수 또는 ~/.gemini/settings.json 설정이 필요합니다.")


# --- Pure-Python RGBA PNG Reader/Writer & Bottom-Aligner (No PIL required) ---
def read_png_rgba(data: bytes) -> tuple[int, int, list[bytearray]]:
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Not a valid PNG"
    pos = 8
    w = h = bit_depth = color_type = 0
    idat = bytearray()
    plte = b""
    trns = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            w, h, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif ctype == b"PLTE":
            plte = chunk
        elif ctype == b"tRNS":
            trns = chunk
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(bytes(idat))
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    stride = w * bpp
    rows: list[bytearray] = []
    idx = 0
    prev = bytearray(stride)
    for _ in range(h):
        f = raw[idx]
        idx += 1
        line = bytearray(raw[idx : idx + stride])
        idx += stride
        if f == 1:  # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:  # Average
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
        elif f == 4:  # Paeth
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        prev = line
        # Convert to RGBA row (w * 4 bytes)
        rgba = bytearray(w * 4)
        if color_type == 6:
            rgba[:] = line
        elif color_type == 2:
            for x in range(w):
                rgba[x * 4 : x * 4 + 3] = line[x * 3 : x * 3 + 3]
                rgba[x * 4 + 3] = 255
        elif color_type == 3:
            for x in range(w):
                pi = line[x]
                rgba[x * 4 : x * 4 + 3] = plte[pi * 3 : pi * 3 + 3]
                rgba[x * 4 + 3] = trns[pi] if pi < len(trns) else 255
        rows.append(rgba)
    return w, h, rows


def write_png_rgba(w: int, h: int, rows: list[bytearray]) -> bytes:
    def make_chunk(ctype: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(ctype + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + ctype + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    raw = bytearray()
    for r in rows:
        raw.append(0)
        raw.extend(r)
    idat = zlib.compress(bytes(raw), 9)
    return b"\x89PNG\r\n\x1a\n" + make_chunk(b"IHDR", ihdr) + make_chunk(b"IDAT", idat) + make_chunk(b"IEND", b"")


def bottom_align_pngs(png_list: list[bytes]) -> list[bytes]:
    decoded = [read_png_rgba(b) for b in png_list]
    lowest = 0
    for w, h, rows in decoded:
        for y in range(h - 1, -1, -1):
            row = rows[y]
            if any(row[x * 4 + 3] > 0 for x in range(w)):
                lowest = max(lowest, y + 1)
                break
    if lowest == 0:
        return png_list
    shift = SIZE - lowest
    out: list[bytes] = []
    for w, h, rows in decoded:
        new_rows = [bytearray(SIZE * 4) for _ in range(SIZE)]
        for y in range(h):
            ny = y + shift
            if 0 <= ny < SIZE:
                new_rows[ny][: min(w, SIZE) * 4] = rows[y][: min(w, SIZE) * 4]
        out.append(write_png_rgba(SIZE, SIZE, new_rows))
    return out


class MCPClient:
    def __init__(self, token: str):
        self.token = token
        self.session_id = None
        self.req_id = 0

    def post(self, method: str, params: dict = None):
        self.req_id += 1
        payload = {"jsonrpc": "2.0", "id": self.req_id, "method": method}
        if params is not None:
            payload["params"] = params
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id
        req = urllib.request.Request(
            MCP_URL,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
            if sid:
                self.session_id = sid
            raw = resp.read().decode("utf-8", errors="replace")
            if raw.lstrip().startswith("event:") or "data: " in raw:
                last_data = None
                for line in raw.splitlines():
                    if line.startswith("data: "):
                        last_data = line[6:].strip()
                if last_data:
                    return json.loads(last_data)
            return json.loads(raw)

    def initialize(self):
        return self.post("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "hareru-story-batch", "version": "1.0.0"}
        })

    def call_tool(self, name: str, arguments: dict):
        return self.post("tools/call", {"name": name, "arguments": arguments})


def extract_text(res: dict) -> str:
    content = res.get("result", {}).get("content", [])
    return "\n".join(c.get("text", "") for c in content if c.get("type") == "text")


def extract_image_bytes(res: dict) -> bytes | None:
    content = res.get("result", {}).get("content", [])
    for c in content:
        if c.get("type") == "image" and c.get("data"):
            return base64.b64decode(c["data"])
    text = extract_text(res)
    urls = re.findall(r"https://[^\s\)\"'\]]+", text)
    for u in urls:
        if any(k in u for k in ["image", "png", "download", "storage", "api.pixellab.ai", "backblazeb2"]):
            try:
                req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
                data = urllib.request.urlopen(req, timeout=30).read()
                if data.startswith(b"\x89PNG"):
                    return data
            except Exception:
                pass
    return None


def poll_image(client: MCPClient, job_id: str, max_wait: int = 120) -> bytes | None:
    start = time.time()
    while time.time() - start < max_wait:
        res = client.call_tool("get_image", {"job_id": job_id})
        txt = extract_text(res)
        first_line = txt.splitlines()[0] if txt else "대기 중..."
        print(f"  [이미지 폴링 {int(time.time() - start)}s] {job_id}: {first_line[:100]}", flush=True)
        img_bytes = extract_image_bytes(res)
        if img_bytes:
            return img_bytes
        if "failed" in txt.lower() or "error:" in txt.lower():
            print("  실패:", txt, flush=True)
            break
        time.sleep(4)
    return None


def poll_character(client: MCPClient, char_id: str, wait_for_walk: bool = False, max_wait: int = 240) -> str:
    start = time.time()
    while time.time() - start < max_wait:
        res = client.call_tool("get_character", {"character_id": char_id, "include_preview": False})
        txt = extract_text(res)
        lines = [ln for ln in txt.splitlines() if any(k in ln.lower() for k in ["status", "progress", "walk", "animation", "error", "eta"])]
        summary = " | ".join(lines[:3]) if lines else (txt.splitlines()[0] if txt else "...")
        print(f"  [캐릭터 폴링 {int(time.time() - start)}s] {char_id[:8]}: {summary[:120]}", flush=True)
        low = txt.lower()
        if "status: processing" not in low and "processing (" not in low and "queued" not in low:
            if not wait_for_walk or ("south-east" in low and ("walking" in low or "walk" in low) and "processing" not in low):
                return txt
        time.sleep(6)
    return ""


def import_character_zip(char_id: str, name: str, raw_root: Path, app_dir: Path) -> bool:
    url = f"https://api.pixellab.ai/mcp/characters/{char_id}/download"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=60).read()
    except Exception as e:
        print(f"  ⚠️ {name} ZIP 다운로드 실패: {e}", flush=True)
        return False

    dest = raw_root / name
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob("**/*.png"):
        old.unlink()
    zipfile.ZipFile(io.BytesIO(data)).extractall(dest)

    rot_dirs = list(dest.glob("**/rotations"))
    if not rot_dirs:
        print(f"  ⚠️ {name} rotations 폴더 없음", flush=True)
        return False
    state_dir = rot_dirs[0].parent
    se_path = state_dir / "rotations" / "south-east.png"
    nw_path = state_dir / "rotations" / "north-west.png"
    if not se_path.exists() or not nw_path.exists():
        print(f"  ⚠️ {name} south-east/north-west 파일 없음", flush=True)
        return False

    idle_aligned = bottom_align_pngs([se_path.read_bytes(), nw_path.read_bytes()])
    walks = sorted((state_dir / "animations").glob("*/south-east"))
    walk_paths = sorted(walks[0].glob("frame_*.png")) if walks else []
    walk_aligned = bottom_align_pngs([p.read_bytes() for p in walk_paths]) if walk_paths else [idle_aligned[0], idle_aligned[0]]

    (app_dir / f"{name}_idle_se.png").write_bytes(idle_aligned[0])
    (app_dir / f"{name}_idle_nw.png").write_bytes(idle_aligned[1])
    for old in app_dir.glob(f"{name}_walk_se_*.png"):
        old.unlink()
    for i, wb in enumerate(walk_aligned):
        suffix = string.ascii_lowercase[i]
        (app_dir / f"{name}_walk_se_{suffix}.png").write_bytes(wb)
    print(f"  ✅ {name} 앱 번들 반영 완료 (걷기 프레임: {len(walk_aligned)}장)", flush=True)
    return True


def main():
    token = load_token()
    client = MCPClient(token)
    client.initialize()

    bal = client.call_tool("get_balance", {})
    print("=== 시작 전 잔여 크레딧 ===", flush=True)
    print(extract_text(bal), flush=True)

    palette_path = REPO / "Sources/Hareru/Resources/Art/Characters/chief_researcher_idle_se.png"
    palette_b64 = base64.b64encode(palette_path.read_bytes()).decode("ascii")
    uuid_re = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

    # -------------------------------------------------------------------------
    # [1번 작업] 스토리 핵심 소품 3종 생성 (48x48 아이소메트릭)
    # -------------------------------------------------------------------------
    props = [
        (
            "prop_handwritten_resume",
            "cardboard moving box half-open with a handwritten paper resume letter and a small pixelated cyan-amber mosaic sticky note on top, isometric pixel art prop, near-future decaying research institute, muted teal grey and off-white palette, single amber accent",
        ),
        (
            "prop_faded_diary",
            "weathered old hardcover bookstore diary journal with a fountain pen and glowing amber bookmark ribbon resting on top, isometric pixel art prop, near-future decaying research institute, muted teal grey and off-white palette, single amber accent",
        ),
        (
            "prop_recipe_notebook",
            "open vintage hand-stitched cafe recipe notebook next to a warm ceramic teacup on a wooden tray, isometric pixel art prop, near-future decaying research institute, muted teal grey and off-white palette, single amber accent",
        ),
    ]

    out_dir = REPO / "Docs/Art/Environment/v2/assets"
    out_dir.mkdir(parents=True, exist_ok=True)

    for name, desc in props:
        out_path = out_dir / f"{name}.png"
        if out_path.exists():
            print(f"\n[스킵] {name}.png 이미 존재함", flush=True)
            continue
        print(f"\n=== [1번: 스토리 소품 생성] {name} ===", flush=True)
        res = client.call_tool("create_image_pixflux", {
            "description": desc,
            "width": 48,
            "height": 48,
            "no_background": True,
            "isometric": True,
            "view": "low top-down",
            "direction": "south-east",
            "outline": "single color black outline",
            "shading": "medium shading",
            "detail": "medium detail",
            "color_image_base64": palette_b64,
        })
        txt = extract_text(res)
        print(txt, flush=True)
        m = re.search(uuid_re, txt)
        img_bytes = extract_image_bytes(res) or (poll_image(client, m.group(0)) if m else None)
        if img_bytes:
            out_path.write_bytes(img_bytes)
            print(f"✅ 저장 완료: {out_path} ({len(img_bytes)} bytes)", flush=True)

    # -------------------------------------------------------------------------
    # [2번 작업] 미완성 캐릭터 마무리 (announcer_ai & courier_rin 도보 버전)
    # -------------------------------------------------------------------------
    chars_json_path = REPO / "Docs/Art/Characters/pixellab/characters.json"
    chars_map = json.loads(chars_json_path.read_text())
    cast_raw_dir = REPO / "Docs/Art/Cast/pixellab"
    app_char_dir = REPO / "Sources/Hareru/Resources/Art/Characters"

    # 2-A: announcer_ai (aa0afd95-6d56-4632-b5c1-24d31263fda7) 상태 확인 및 걷기 모션/임포트
    announcer_id = chars_map.get("announcer_ai", "aa0afd95-6d56-4632-b5c1-24d31263fda7")
    print(f"\n=== [2-A: announcer_ai 확인] ({announcer_id}) ===", flush=True)
    res_ann = client.call_tool("get_character", {"character_id": announcer_id, "include_preview": False})
    txt_ann = extract_text(res_ann)
    print(txt_ann[:500], flush=True)
    if "completed" in txt_ann.lower() or "rotations" in txt_ann.lower():
        if "walking" not in txt_ann.lower() and "walk" not in txt_ann.lower():
            print("  -> announcer_ai 남동(south-east) 걷기 애니메이션 요청 중...", flush=True)
            anim_res = client.call_tool("animate_character", {
                "character_id": announcer_id,
                "template_animation_id": "walking-6-frames",
                "directions": ["south-east"],
            })
            print(extract_text(anim_res), flush=True)
            poll_character(client, announcer_id, wait_for_walk=True, max_wait=180)
        if import_character_zip(announcer_id, "announcer_ai", cast_raw_dir, app_char_dir):
            chars_map["announcer_ai"] = announcer_id
            chars_json_path.write_text(json.dumps(chars_map, indent=2, ensure_ascii=False) + "\n")

    # 2-B: courier_rin 도보 버전("on foot, no vehicle") 재생성 + 걷기 애니메이션
    print("\n=== [2-B: courier_rin 도보 버전 재생성] ===", flush=True)
    rin_res = client.call_tool("create_character", {
        "name": "courier_rin_on_foot",
        "description": "energetic young female courier standing on foot, no vehicle, no scooter, short windswept dark hair, amber goggles on forehead, weathered courier jacket, messenger satchel bag with old paper books, near-future decaying research institute, muted faded teal grey and off-white palette, single amber accent, no logos",
        "mode": "v3",
        "size": 48,
        "view": "low top-down",
        "outline": "single color black outline",
        "detail": "medium detail",
    })
    rin_txt = extract_text(rin_res)
    print(rin_txt, flush=True)
    m_rin = re.search(uuid_re, rin_txt)
    if m_rin:
        new_rin_id = m_rin.group(0)
        print(f"  -> 새 courier_rin ID: {new_rin_id}, 회전 생성 완료 대기 중...", flush=True)
        done_txt = poll_character(client, new_rin_id, wait_for_walk=False, max_wait=240)
        if done_txt and "failed" not in done_txt.lower():
            print("  -> courier_rin 남동(south-east) 걷기 애니메이션 요청 중...", flush=True)
            anim_rin = client.call_tool("animate_character", {
                "character_id": new_rin_id,
                "template_animation_id": "walking-6-frames",
                "directions": ["south-east"],
            })
            print(extract_text(anim_rin), flush=True)
            poll_character(client, new_rin_id, wait_for_walk=True, max_wait=240)
            if import_character_zip(new_rin_id, "courier_rin", cast_raw_dir, app_char_dir):
                chars_map["courier_rin"] = new_rin_id
                chars_json_path.write_text(json.dumps(chars_map, indent=2, ensure_ascii=False) + "\n")

    bal_after = client.call_tool("get_balance", {})
    print("\n=== 작업 후 잔여 크레딧 ===", flush=True)
    print(extract_text(bal_after), flush=True)


if __name__ == "__main__":
    main()
