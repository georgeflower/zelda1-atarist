#!/usr/bin/env python3
"""Compare the tiles the ROM put on the PPU for every dungeon room (rom_rooms.mjs: rom_full.json) with the port's room grids.

    python3 compare_tiles.py [rom_full.json] [--level N] [--quest N] [-v]

The port keeps each room as a 32x22 grid of bank ids (uw<N>_rooms.bin) and `uw<N>_tile_nes.bin` says which NES tile each is;
the doors are drawn closed (the state a room is entered in). Prints the rooms that differ and where.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent.parent / "build" / "generated"
OUT = HERE.parent.parent / "build" / "refnes"
COLS, ROWS = 32, 22


def port_room(key: str, index: int, rooms: bytes, tile_nes: bytes) -> list[list[int]]:
    base = index * COLS * ROWS
    grid = rooms[base:base + COLS * ROWS]
    return [[tile_nes[grid[r * COLS + c]] for c in range(COLS)] for r in range(ROWS)]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", nargs="?", type=Path, default=OUT / "rom_full.json")
    parser.add_argument("--level", type=int)
    parser.add_argument("--quest", type=int)
    parser.add_argument("-v", action="store_true")
    args = parser.parse_args()
    rom = json.loads(args.rom.read_text())
    grand = 0
    for key in sorted(rom):
        data = rom[key]
        level, quest = data["level"], data["quest"]
        if level == 0 or (args.level is not None and level != args.level) or (args.quest is not None and quest != args.quest):
            continue
        name = f"{level}q2" if quest == 2 else f"{level}"
        index = (GEN / f"uw{name}_room_index.bin").read_bytes()
        rooms = (GEN / f"uw{name}_rooms.bin").read_bytes()
        tile_nes = (GEN / f"uw{name}_tile_nes.bin").read_bytes()
        bad = []
        for r in data["rooms"]:
            if not r.get("ok") or index[r["room"]] == 0xFF:
                continue
            want = [[int(row[i * 2:i * 2 + 2], 16) for i in range(COLS)] for row in r["tiles"]]
            have = port_room(name, index[r["room"]], rooms, tile_nes)
            diff = [(c, y, want[y][c], have[y][c]) for y in range(ROWS) for c in range(COLS) if want[y][c] != have[y][c]]
            if diff:
                bad.append((r["room"], diff, r["doors"]))
        grand += len(bad)
        print(f"== quest {quest} level {level}: {len(bad)} rooms differ")
        for room, diff, doors in bad:
            cols = sorted({c for c, *_ in diff}); rows = sorted({y for _, y, *_ in diff})
            print(f"   {room:02X}: {len(diff)} tiles, columns {cols[0]}-{cols[-1]}, rows {rows[0]}-{rows[-1]}, ROM doors {doors:02X}")
            if args.v:
                for c, y, a, b in diff[:12]:
                    print(f"        ({c},{y}) ROM {a:02X} port {b:02X}")
    print("rooms differing:", grand)


if __name__ == "__main__":
    main()
