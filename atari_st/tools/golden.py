#!/usr/bin/env python3
"""Golden-frame regression check: run a fixed set of scenes in Hatari and compare what is on screen.

Each scene starts the game somewhere (a dev build, see `screenshot.py --room/--uw`), runs a fixed number of frames with
optional key presses, and fingerprints the framebuffer plus palette (the `FRAMEHASH` line of screenshot.py). The runs
are deterministic, so a change in the fingerprint means a change in what the game draws or does.

The fingerprints live in `tests/golden/frames.json`. Pictures are not kept in the repository: they would be frames of
Nintendo's artwork. `--png-dir` writes the PNGs of a run so a failure can be looked at, next to the stored hash.

    python3 tools/golden.py                  # compare; exit 1 when a scene changed
    python3 tools/golden.py --update         # accept what the scenes show now
    python3 tools/golden.py --only uw2_dodongo --png-dir build/golden

Needs Hatari and an EmuTOS image (the TOS environment variable or --tos); without them it says so and exits 0 unless
--require is given.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
GOLDEN = PROJECT / "tests" / "golden" / "frames.json"

# name: screenshot.py arguments. Frame counts leave the room time to settle (the game starts at about frame 170).
GANON_ARROW = ("500:=GANON_SCENE=0,500:=LINK_HELD=0,500:=HP_HALVES=40,500:=ENEMY_X.0=0x78,500:=ENEMY_Y.0=0x80,500:=ENEMY_STATE.0=0xff,"
               "500:=INV_ARROW=2,500:=INV_BOW=1,500:=INV_RUPEES=50,500:=B_ITEM=4,505:+up,507:-up,512:+ctrl,514:-ctrl")

def _taps(start: int, keys: list[str], gap: int = 4) -> str:
    """Each key pressed for two frames, one every `gap` frames."""
    events = []
    for number, key in enumerate(keys):
        at = start + number * gap
        events += [f"{at}:+{key}", f"{at + 2}:-{key}"]
    return ",".join(events)


# The file menu (filesel.s), from the title: Start at frame 400 brings up the select screen, Start again on REGISTER the
# name board, where ZELDA is typed (Z: two down and three right; E: two up, one right; L: down, four left; D: up,
# three right; A: three left) and Tab moves on over the other two slots to END; Start leaves it with the new profile.
MENU_TO_REGISTER = "400:+return,410:-return,440:+return,450:-return"
MENU_ZELDA = _taps(500, ["down", "down", "right", "right", "right", "space", "up", "up", "right", "space",
                         "down", "left", "left", "left", "left", "space", "up", "right", "right", "right", "space",
                         "left", "left", "left", "space"])
MENU_REGISTERED = f"{MENU_TO_REGISTER},{MENU_ZELDA},{_taps(610, ['tab', 'tab', 'tab'])},630:+return,632:-return"
MENU_TO_ELIMINATION = f"{MENU_REGISTERED},{_taps(710, ['tab', 'tab'], 4)},720:+return,722:-return"

DEATH = "260:=DYING=1"

INV_OW = "300:=INV_BOMBS=4,300:=B_ITEM=1,300:=INV_BOOMERANG=1,300:=INV_CANDLE=1,300:=INV_RAFT=1,300:=INV_RING=1,300:=TRIFORCE_PIECES=5"
INV_UW = "300:=INV_MAP=1,300:=INV_COMPASS=1,300:=INV_BOMBS=3,300:=B_ITEM=1,300:=UW_FLAGS.115=32,300:=UW_FLAGS.114=32,300:=UW_FLAGS.116=32,300:=UW_FLAGS.99=32,300:=UW_FLAGS.98=32,300:=UW_FLAGS.100=32,300:=UW_FLAGS.83=32,300:=UW_FLAGS.82=32,300:=UW_FLAGS.84=32,300:=UW_FLAGS.67=32,300:=UW_FLAGS.68=32,300:=UW_FLAGS.66=32,300:=UW_FLAGS.51=32,300:=UW_FLAGS.52=32,300:=UW_FLAGS.53=32,300:=UW_FLAGS.35=32,300:=UW_FLAGS.36=32"

BLOCK_L1 = "300:=ENEMY_COUNT=0,330:=LINK_X=0x80,330:=LINK_Y=0x8d,331:+left"
BLOCK_L5 = "300:=ENEMY_COUNT=0,330:=LINK_X=0x80,330:=LINK_Y=0x8d,331:+left"

SCENES: dict[str, list[str]] = {
    # The title and the story (intro.s) run in the normal build, which `make` has built (the others are dev builds).
    "title": ["--vbls", "400"],
    "title_fade": ["--vbls", "760"],
    "story_page": ["--vbls", "1600"],
    "story_parade": ["--vbls", "2600"],
    "title_start": ["--vbls", "480", "--keys", "400:+return,420:-return"],
    "file_register": ["--vbls", "480", "--keys", MENU_TO_REGISTER],
    "file_register_typed": ["--vbls", "556", "--keys", f"{MENU_TO_REGISTER},{MENU_ZELDA}"],
    "file_named": ["--vbls", "700", "--keys", MENU_REGISTERED],
    "file_play": ["--vbls", "800", "--keys", f"{MENU_REGISTERED},710:+return,712:-return"],
    "file_eliminate": ["--vbls", "745", "--keys", MENU_TO_ELIMINATION],
    "file_eliminated": ["--vbls", "780", "--keys", f"{MENU_TO_ELIMINATION},750:+return,752:-return"],
    # The Tab inventory screen (menu.s, tools/submenu.py): the ROM's layout, then closing it again.
    "inv_overworld": ["--room", "0x77", "--vbls", "400", "--keys", f"{INV_OW},380:+tab,385:-tab"],
    "inv_overworld_right": ["--room", "0x77", "--vbls", "440", "--keys", f"{INV_OW},380:+tab,385:-tab,420:+right,423:-right"],
    "inv_closed": ["--room", "0x77", "--vbls", "460", "--keys", f"{INV_OW},380:+tab,385:-tab,420:+right,423:-right,440:+tab,443:-tab"],
    "inv_dungeon": ["--uw", "0x73", "--level", "1", "--vbls", "400", "--keys", f"{INV_UW},380:+tab,385:-tab"],
    "ow_start": ["--room", "0x77", "--vbls", "420"],
    "ow_entrance_l2": ["--room", "0x3c", "--vbls", "420"],
    "uw1_start": ["--uw", "0x73", "--level", "1", "--vbls", "420"],
    "uw1_aquamentus": ["--uw", "0x35", "--level", "1", "--vbls", "420"],
    "uw2_start": ["--uw", "0x7d", "--level", "2", "--vbls", "420"],
    "uw2_dodongo": ["--uw", "0x0e", "--level", "2", "--vbls", "420"],
    "uw2_moldorm": ["--uw", "0x3e", "--level", "2", "--vbls", "420"],
    "uw2_traps": ["--uw", "0x3f", "--level", "2", "--vbls", "420"],
    "uw2_goriyas": ["--uw", "0x5e", "--level", "2", "--vbls", "420"],
    # A goriya's boomerang reaches Link on the same row: his shield turns it back (facing it), or it costs a heart.
    "uw2_goriya_parried": ["--uw", "0x5e", "--level", "2", "--vbls", "366", "--keys",
                           "320:=LINK_X=60,320:=LINK_Y=157,320:=LINK_DIR=1"],
    "uw2_goriya_hit": ["--uw", "0x5e", "--level", "2", "--vbls", "366", "--keys",
                       "320:=LINK_X=60,320:=LINK_Y=157,320:=LINK_DIR=2"],
    "uw2_old_man": ["--uw", "0x1f", "--level", "2", "--vbls", "420"],
    # a sword blow on the old man (person_hit) turns his two fires on Link: a fireball is on its way
    "uw2_old_man_fire": ["--uw", "0x1f", "--level", "2", "--vbls", "520", "--keys", "440:+space,442:-space"],
    "uw3_crowd": ["--uw", "0x49", "--level", "3", "--vbls", "420"],
    "uw4_dark": ["--uw", "0x30", "--level", "4", "--vbls", "420"],
    "uw4_stash": ["--uw", "0x11", "--level", "4", "--vbls", "420"],
    "uw7_grumble": ["--uw", "0x28", "--level", "7", "--vbls", "420"],
    "uw7_crowd": ["--uw", "0x5a", "--level", "7", "--vbls", "420"],
    "uw9_lanmola": ["--uw", "0x11", "--level", "9", "--vbls", "420"],
    "uw9_patra": ["--uw", "0x21", "--level", "9", "--vbls", "420"],
    "uw9_ganon": ["--uw", "0x42", "--level", "9", "--vbls", "420"],
    "uw9_zelda": ["--uw", "0x32", "--level", "9", "--vbls", "420"],
    "uw1_magic_key_door": ["--uw", "0x73", "--level", "1", "--vbls", "500", "--keys", "190:=ITEMS.13=1,200:+up"],
    "uw5_bombs_man": ["--uw", "0x17", "--level", "5", "--vbls", "420"],
    # The push block (combat.s block_slide / block_land): Link lines up at the right of Level 1's block, pushes, and the block
    # slides left a pixel a frame (picture 358), lands and opens the shutters (392); Level 5's room $05 shows the stairs.
    "uw1_block_slide": ["--uw", "0x42", "--level", "1", "--vbls", "358", "--keys", BLOCK_L1],
    "uw1_block_landed": ["--uw", "0x42", "--level", "1", "--vbls", "392", "--keys", BLOCK_L1],
    "uw5_block_stairs": ["--uw", "0x05", "--level", "5", "--vbls", "480", "--keys", BLOCK_L5],
    "uw9_credits_port": ["--uw", "0x32", "--level", "9", "--vbls", "3250", "--keys", "190:=HP_HALVES=40,190:=LINK_Y=0x95"],
    # The overworld's hidden spots (secrets.s). Enemies are cleared at frame 300 so nothing disturbs the poked-in Link.
    "ow_bomb_wall": ["--room", "0x01", "--vbls", "470", "--keys",
                     "300:=ENEMY_COUNT=0,300:=LINK_X=0x90,300:=LINK_Y=0x5d,300:=LINK_DIR=8,300:=INV_BOMBS=8,300:=B_ITEM=1,340:+ctrl,343:-ctrl"],
    "ow_bomb_miss": ["--room", "0x01", "--vbls", "470", "--keys",
                     "300:=ENEMY_COUNT=0,300:=LINK_X=0x90,300:=LINK_Y=0x6d,300:=LINK_DIR=8,300:=INV_BOMBS=8,300:=B_ITEM=1,340:+ctrl,343:-ctrl"],
    "ow_tree_burnt": ["--room", "0x28", "--vbls", "600", "--keys",
                      "300:=ENEMY_COUNT=0,300:=LINK_X=0xc0,300:=LINK_Y=0xa5,300:=LINK_DIR=1,300:=INV_CANDLE=1,300:=B_ITEM=3,340:+ctrl,343:-ctrl"],
    "ow_rock_pushed": ["--room", "0x79", "--vbls", "480", "--keys",
                       "300:=ENEMY_COUNT=0,300:=LINK_X=0x80,300:=LINK_Y=0xa5,300:=LINK_DIR=8,300:=INV_BRACELET=1,340:+up"],
    "ow_rock_no_bracelet": ["--room", "0x79", "--vbls", "480", "--keys",
                            "300:=ENEMY_COUNT=0,300:=LINK_X=0x80,300:=LINK_Y=0xa5,300:=LINK_DIR=8,340:+up"],
    "ow_grave_pushed": ["--room", "0x21", "--vbls", "420", "--keys",
                        "300:=ENEMY_COUNT=0,300:=LINK_X=0x90,300:=LINK_Y=0xa5,300:=LINK_DIR=8,340:+up,352:-up"],
    "ow_grave_returns": ["--room", "0x21", "--vbls", "1000", "--keys",
                         "300:=ENEMY_COUNT=0,300:=LINK_X=0x90,300:=LINK_Y=0xa5,300:=LINK_DIR=8,340:+up,352:-up,380:=LINK_X=0x80,380:=LINK_Y=0xd5,385:+down,560:-down,570:+up"],
    # Ganon: brown after the sword, then a silver arrow. He burns solid, the ashes stay under the Triforce of Power.
    "uw9_ganon_brown": ["--uw", "0x42", "--level", "9", "--vbls", "515", "--keys", GANON_ARROW],
    "uw9_ganon_ashes": ["--uw", "0x42", "--level", "9", "--vbls", "1100", "--keys", GANON_ARROW],
    "uw9_zelda_thanks": ["--uw", "0x32", "--level", "9", "--vbls", "800", "--keys", "190:=HP_HALVES=40,190:=LINK_Y=0x95"],
    # Caves (caves.s): --cave starts inside the cave behind the screen; the keys poke rupees and walk to a ware.
    "cave_sword": ["--room", "0x77", "--cave", "--vbls", "420"],
    "cave_shop": ["--room", "0x25", "--cave", "--vbls", "420"],
    "cave_shop_bought": ["--room", "0x25", "--cave", "--vbls", "560", "--keys",
                         "300:=INV_RUPEES=200,420:+right,425:-right,430:+up,500:-up"],
    "cave_hint": ["--room", "0x70", "--cave", "--vbls", "420"],
    "cave_hint_paid": ["--room", "0x1a", "--cave", "--vbls", "640", "--keys",
                       "300:=INV_RUPEES=100,420:+left,436:-left,440:+up,520:-up"],
    "cave_money_game": ["--room", "0x10", "--cave", "--vbls", "560", "--keys",
                        "300:=INV_RUPEES=100,420:+left,436:-left,440:+up,520:-up"],
    "cave_door_repair": ["--room", "0x01", "--cave", "--vbls", "500", "--keys", "300:=INV_RUPEES=100"],
    "cave_moblin": ["--room", "0x13", "--cave", "--vbls", "600", "--keys",
                    "300:=INV_RUPEES=10,420:+right,425:-right,430:+up,520:-up"],
    "cave_potion_no_letter": ["--room", "0x02", "--cave", "--vbls", "450"],
    "cave_potion_letter": ["--room", "0x02", "--cave", "--vbls", "560", "--keys", "300:=INV_LETTER=1,320:+ctrl,340:-ctrl"],
    "cave_take_any_one": ["--room", "0x06", "--cave", "--vbls", "440"],
    "cave_take_any_road": ["--room", "0x1d", "--cave", "--vbls", "450"],
    "cave_letter_lifted": ["--room", "0x0e", "--cave", "--vbls", "560", "--keys", "420:+right,425:-right,430:+up,520:-up"],
    "cave_white_sword_hearts": ["--room", "0x0a", "--cave", "--vbls", "600", "--keys", "420:+right,425:-right,430:+up,520:-up"],
    "ow_armos_stairs": ["--room", "0x34", "--vbls", "560", "--keys",
                        "400:=LINK_X=0x40,400:=LINK_Y=0x8d,400:=HP_HALVES=0x30,401:+up,430:-up"],
    "ow_fairy_pond": ["--room", "0x39", "--vbls", "440", "--keys", "400:=LINK_Y=0xad,400:=HP_HALVES=2"],
    "ow_pond_stairs": ["--room", "0x42", "--vbls", "900", "--keys",
                       "400:=INV_RECORDER=1,400:=B_ITEM=5,400:=ENEMY_ACTIVE.0=0,420:+ctrl,422:-ctrl"],
    "ow_whirlwind_carries": ["--room", "0x77", "--vbls", "450", "--keys",
                             "400:=TRIFORCE_PIECES=1,400:=INV_RECORDER=1,400:=B_ITEM=5,420:+ctrl,422:-ctrl"],
    # Link's death (death.s): poking DYING at frame 260 is what link_dies does. The blink, the world going red a few
    # lines a frame, the fade, the grey Link and the spark, GAME OVER, then the continue question (filesel.s).
    "death_remap": ["--room", "0x77", "--vbls", "300", "--keys", DEATH],
    "death_red": ["--room", "0x77", "--vbls", "400", "--keys", DEATH],
    "death_fade": ["--room", "0x77", "--vbls", "445", "--keys", DEATH],
    "death_link": ["--room", "0x77", "--vbls", "470", "--keys", DEATH],
    "death_spark": ["--room", "0x77", "--vbls", "495", "--keys", DEATH],
    "death_gameover": ["--room", "0x77", "--vbls", "600", "--keys", DEATH],
    "death_continue": ["--room", "0x77", "--vbls", "670", "--keys", DEATH],
    "death_continue_save": ["--room", "0x77", "--vbls", "710", "--keys", f"{DEATH},{_taps(690, ['tab'])}"],
    "death_continue_flash": ["--room", "0x77", "--vbls", "726", "--keys", f"{DEATH},{_taps(690, ['return'])}"],
    "death_continued": ["--room", "0x77", "--vbls", "800", "--keys", f"{DEATH},{_taps(690, ['return'])}"],
}


def run_scene(name: str, args: list[str], tos: Path, png: Path) -> str:
    command = [sys.executable, str(PROJECT / "tools" / "screenshot.py"), "--tos", str(tos), "--out", str(png), *args]
    result = subprocess.run(command, capture_output=True, text=True, cwd=PROJECT)
    match = re.search(r"^FRAMEHASH (\w+)$", result.stdout, re.M)
    if result.returncode != 0 or not match:
        raise SystemExit(f"{name}: screenshot.py failed\n{result.stdout[-800:]}\n{result.stderr[-800:]}")
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--update", action="store_true", help="store the fingerprints of this run")
    parser.add_argument("--only", action="append", help="a scene name (repeatable)")
    parser.add_argument("--png-dir", type=Path, help="keep each scene's PNG here")
    parser.add_argument("--tos", type=Path, default=Path(os.environ.get("TOS", "")))
    parser.add_argument("--require", action="store_true", help="fail, rather than skip, when Hatari or TOS is missing")
    args = parser.parse_args()

    missing = []
    if not shutil.which(os.environ.get("HATARI", "hatari")):
        missing.append("Hatari")
    if not str(args.tos) or not args.tos.is_file():
        missing.append("an EmuTOS image (TOS or --tos)")
    if missing:
        message = "golden: skipped, needs " + " and ".join(missing)
        sys.exit(message if args.require else print(message) or 0)
    if not (PROJECT.parent / "ext" / "Original.nes").exists():
        message = "golden: skipped, the fingerprints are of the real artwork and need ext/Original.nes"
        sys.exit(message if args.require else print(message) or 0)

    names = args.only or list(SCENES)
    unknown = [n for n in names if n not in SCENES]
    if unknown:
        raise SystemExit(f"unknown scene(s): {', '.join(unknown)}")
    stored = json.loads(GOLDEN.read_text(encoding="utf-8")) if GOLDEN.exists() else {}
    png_dir = args.png_dir or PROJECT / "build" / "golden"
    png_dir.mkdir(parents=True, exist_ok=True)

    changed = []
    for name in names:
        digest = run_scene(name, SCENES[name], args.tos, png_dir / f"{name}.png")
        if args.update:
            stored[name] = digest
            print(f"{name}: {digest[:12]} stored")
        elif stored.get(name) == digest:
            print(f"{name}: ok")
        else:
            changed.append(name)
            print(f"{name}: CHANGED ({'new scene' if name not in stored else stored[name][:12]} -> {digest[:12]}), "
                  f"picture in {png_dir / (name + '.png')}")
    if args.update:
        GOLDEN.parent.mkdir(parents=True, exist_ok=True)
        GOLDEN.write_text(json.dumps(dict(sorted(stored.items())), indent=1) + "\n", encoding="utf-8")
        print(f"wrote {GOLDEN}")
    elif changed:
        sys.exit(f"golden: {len(changed)} scene(s) changed; look at the pictures, then --update if intended")


if __name__ == "__main__":
    main()
