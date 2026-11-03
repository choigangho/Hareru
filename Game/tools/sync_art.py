#!/usr/bin/env python3
"""Copy the confirmed Day 1 art from Docs/Art/Inbox into Game/art.

The originals stay in Docs/Art/Inbox (where they were made and confirmed).
Game/art is the runtime copy Godot imports. Re-run after any art change:
    python3 Game/tools/sync_art.py
"""
import shutil, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "Docs/Art/Inbox"
DST = ROOT / "Game/art"

CHIEF = "set3_lab/chars/73d42ed3-8706-4576-a424-be4f20fe9a41"
HERO = "set3_lab/chars/9a66ec5c-e2f2-400e-afd3-de082c48b4a2"

# destination (relative to Game/art) -> source (relative to Docs/Art/Inbox)
FILES = {
    "lab/lab_section_day1.png": "set3_lab/lab_section_day1.png",
    "lab/light/light_dark_mul.png": "set3_lab/light/light_dark_mul.png",
    "lab/light/light_night_mul.png": "set3_lab/light/light_night_mul.png",
    "lab/light/light_night_neon_add.png": "set3_lab/light/light_night_neon_add.png",
    "lab/light/lamp_pool_add.png": "set3_lab/lab_light_lamp_pool.png",
    "lab/light/fluorescent_R_off.png": "set3_lab/light/fluorescent_R_off.png",
    "lab/light/fluorescent_L_off.png": "set3_lab/light/fluorescent_L_off.png",
    "lab/window/window_day.png": "set3_lab/window/window_day.png",
    "chars/hero_sit_north.png": f"{HERO}/8f68a4b5/rotations/north.png",
    "chars/hero_idle_west.png": f"{HERO}/Idle/rotations/west.png",
    "chars/hero_idle_south.png": f"{HERO}/Idle/rotations/south.png",
    "chars/chief_sit_east.png": f"{CHIEF}/73d42ed3/rotations/east.png",
    "chars/chief_idle_east.png": f"{CHIEF}/Idle/rotations/east.png",
    "chars/chief_idle_south.png": f"{CHIEF}/Idle/rotations/south.png",
    "props/kuro_off.png": "set6_kuro/kuro_off.png",
    "props/kuro_amber_dim.png": "set6_kuro/kuro_amber_dim.png",
    "props/kuro_amber_on.png": "set6_kuro/kuro_amber_on.png",
    "ui/ui_hint_dot_0.png": "set9_ui/ui_hint_dot_0.png",
    "ui/ui_hint_dot_1.png": "set9_ui/ui_hint_dot_1.png",
}
PROPS = ["prop_ceiling_leak_stain", "prop_ceiling_leak_patched", "prop_bucket_low", "prop_bucket_mid",
         "prop_bucket_over", "prop_clipboard", "prop_breaker_closed", "prop_breaker_open",
         "prop_research_ledger", "prop_desk_lamp_off", "prop_desk_lamp_on", "prop_box_closed",
         "prop_box_open", "prop_mug_new", "prop_mug_old", "prop_memo_file", "prop_task_sheet",
         "prop_board_staff_1", "prop_board_staff_2", "prop_book_pile_0", "prop_book_pile_1", "prop_book_pile_2"]
for p in PROPS:
    FILES[f"props/{p}.png"] = f"set7_props/final/{p}.png"
for e in ["default", "smile", "glint", "flustered", "troubled", "teary", "serious", "proud"]:
    FILES[f"portraits/chief_{e}.png"] = f"set4_portraits/chief/chief_portrait_{e}.png"
for e in ["default", "daze", "goof", "surprised", "meh", "awkward", "serious"]:
    FILES[f"portraits/hero_{e}.png"] = f"set4_portraits/hero/hero_portrait_{e}.png"
for u in ["ui_dialog_dock", "ui_dialog_portrait_crt", "ui_dialog_scanlines_96", "ui_keycap_choice_idle",
          "ui_keycap_choice_select", "ui_keycap_choice_press", "ui_blank_word"]:
    FILES[f"ui/{u}.png"] = f"set9_ui/{u}.png"


def main() -> None:
    n = 0
    for dst, src in FILES.items():
        s, d = SRC / src, DST / dst
        d.parent.mkdir(parents=True, exist_ok=True)
        if not d.exists() or d.read_bytes() != s.read_bytes():
            shutil.copyfile(s, d)
            n += 1
    print(f"synced {n} changed / {len(FILES)} files")


if __name__ == "__main__":
    main()
