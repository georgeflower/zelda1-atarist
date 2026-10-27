#!/usr/bin/env python3
"""Compare the tiles the ROM put on the PPU for every overworld screen with what the port's decoder builds from the same ROM data.

    python3 compare_ow_tiles.py [rom_ow.json] [--quest N] [-v]

`build_assets.decode_overworld` gives each screen as 16x11 squares, a square being a metatile of four tiles.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))
import build_assets as B  # noqa: E402

OUT = TOOLS.parent / "build" / "refnes"
ROOT = TOOLS.parent.parent


def expected(quest: int, pool):
    bg = B.load_ow_background_tiles(ROOT)
    rooms, metatiles, *_ = B.decode_overworld(ROOT, bg, 1 if quest == 2 else 0, pool)
    out = []
    for grid in rooms:
        tiles = [[0] * 32 for _ in range(22)]
        for i, index in enumerate(grid):
            row, col = divmod(i, 16)
            _, quad = metatiles[index]
            # square_to_tiles gives the four tiles top-left, top-right, bottom-left, bottom-right
            tiles[row * 2][col * 2], tiles[row * 2][col * 2 + 1] = quad[0], quad[1]
            tiles[row * 2 + 1][col * 2], tiles[row * 2 + 1][col * 2 + 1] = quad[2], quad[3]
        out.append(tiles)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", nargs="?", type=Path, default=OUT / "rom_ow.json")
    parser.add_argument("--quest", type=int)
    parser.add_argument("-v", action="store_true")
    args = parser.parse_args()
    rom = json.loads(args.rom.read_text())
    pool = ({}, [])
    for quest in (1, 2):
        key = f"q{quest}_l0"
        if key not in rom or (args.quest and args.quest != quest):
            continue
        want_rooms = expected(quest, pool)
        bad = 0
        for r in rom[key]["rooms"]:
            if not r.get("ok"):
                continue
            rom_tiles = [[int(row[i * 2:i * 2 + 2], 16) for i in range(32)] for row in r["tiles"]]
            mine = want_rooms[r["room"]]
            diff = [(c, y, rom_tiles[y][c], mine[y][c]) for y in range(22) for c in range(32) if rom_tiles[y][c] != mine[y][c]]
            if diff:
                bad += 1
                print(f"quest {quest} screen {r['room']:02X}: {len(diff)} tiles differ; first {[(c, y, f'{a:02X}', f'{b:02X}') for c, y, a, b in diff[:6]]}")
        print(f"quest {quest}: {bad} screens differ")


if __name__ == "__main__":
    main()
