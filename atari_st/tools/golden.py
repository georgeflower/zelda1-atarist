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
SCENES: dict[str, list[str]] = {
    "ow_start": ["--room", "0x77", "--vbls", "420"],
    "ow_entrance_l2": ["--room", "0x3c", "--vbls", "420"],
    "uw1_start": ["--uw", "0x73", "--level", "1", "--vbls", "420"],
    "uw1_aquamentus": ["--uw", "0x35", "--level", "1", "--vbls", "420"],
    "uw2_start": ["--uw", "0x7d", "--level", "2", "--vbls", "420"],
    "uw2_dodongo": ["--uw", "0x0e", "--level", "2", "--vbls", "420"],
    "uw2_moldorm": ["--uw", "0x3e", "--level", "2", "--vbls", "420"],
    "uw2_traps": ["--uw", "0x3f", "--level", "2", "--vbls", "420"],
    "uw2_goriyas": ["--uw", "0x5e", "--level", "2", "--vbls", "420"],
    "uw2_old_man": ["--uw", "0x1f", "--level", "2", "--vbls", "420"],
    "uw3_crowd": ["--uw", "0x49", "--level", "3", "--vbls", "420"],
    "uw4_dark": ["--uw", "0x30", "--level", "4", "--vbls", "420"],
    "uw4_stash": ["--uw", "0x11", "--level", "4", "--vbls", "420"],
    "uw7_grumble": ["--uw", "0x28", "--level", "7", "--vbls", "420"],
    "uw7_crowd": ["--uw", "0x5a", "--level", "7", "--vbls", "420"],
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
