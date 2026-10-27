#!/usr/bin/env python3
"""Compare what the ROM (rom_rooms.mjs) made of every room with what the port's tables hold (port_rooms.py).

    python3 compare.py [rom.json port.json] [--level N] [--quest N] [-v]

Prints the rooms where the two disagree, after dropping the differences the port makes on purpose (see NORMALISE).
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))
import actors  # noqa: E402

OUT = TOOLS.parent / "build" / "refnes"
# What the ROM keeps in object slots next to the monsters, and the port does not count as monsters: flames and the people
# beside them ($40, $4B-$52), the weapons and shots a room is set up with ($53 and up: $55 and $56 are shots of a boss, $59 a
# wizzrobe's, $5C a goriya's boomerang, the push block $68, ...), the rupee stash and Grumble, which the port keeps in the
# room's flags.
STASH, GRUMBLE = actors.RUPEE_STASH, actors.GRUMBLE
# One object here is several in the ROM (a boss of many parts) or the port makes it of fewer parts (the Moldorm worms of four
# segments, the Lanmola's): compare whether it is there, not how many.
GROUPS = {0x3C, 0x3A, 0x3B, 0x41, 0x25, 0x26, 0x20}
CARRIERS = (0x17, 0x2A, 0x30)        # MoveAndDrawRoomItem: a like-like, stalfos or gibdo in slot 1 carries the room item along
DIGDOGGER2 = 0xFB                    # the port's name for what InitDigdogger2 starts as; the ROM shows $38


def rom_types(room: dict) -> list[int]:
    types = [o["type"] for o in room["objs"] if o["slot"] <= 11 and o["type"] != 0x40 and o["type"] < 0x4B and o["type"] not in (STASH, GRUMBLE)]
    return types


def norm(types, level: int) -> list[int]:
    out = []
    for t in types:
        t = 0x38 if t == DIGDOGGER2 else t
        if t in GROUPS:
            if t not in out:
                out.append(t)
        else:
            out.append(t)
    return out


def fmt(types) -> str:
    return " ".join(f"{t:02X}" for t in sorted(types)) or "-"


def compare(rom: dict, port: dict, verbose: bool) -> list[str]:
    problems = []
    level = port["level"]
    listed = set(actors.OVERWORLD_LISTED) if level == 0 else set(actors.MONSTER_TYPES)
    for p in port["rooms"]:
        if not p.get("present"):
            continue
        r = rom["rooms"][p["room"]]
        if not r.get("ok"):
            problems.append(f"{p['room']:02X}: the ROM would not enter this room")
            continue
        want = rom_types(r)
        have = list(p["types"])[:p["count"]]
        if level == 0:
            want = [t for t in want if t in listed][:6]
            if 0x1F in want:
                want = [t for t in want if t != 0x20]       # the boulder maker's boulders
            if sorted(want) != sorted(have):
                problems.append(f"{p['room']:02X}: monsters ROM {fmt(want)}  port {fmt(have)}")
            continue
        a, b = Counter(norm(want, level)), Counter(norm(have, level))
        if a != b:
            problems.append(f"{p['room']:02X}: monsters ROM {fmt(want)}  port {fmt(have)}  (+{p['unsupported']} unsupported)")
        item, ri = p["item"], r["item"]
        if ri["id"] == 3 or item["id"] == 0xFF:
            if ri["id"] == 3 and item["id"] != 0xFF:
                problems.append(f"{p['room']:02X}: ROM has no item, port {item['id']:02X}")
            continue
        if ri["state"] not in (0, 0xFF) or ri["id"] != item["id"]:
            problems.append(f"{p['room']:02X}: item ROM {ri['id']:02X} state {ri['state']:02X}  port {item['id']:02X}")
        elif ri["state"] == 0 and (ri["x"], ri["y"]) != (item["x"], item["y"]):
            problems.append(f"{p['room']:02X}: item ROM {ri['id']:02X} at ({ri['x']:02X},{ri['y']:02X})  port at ({item['x']:02X},{item['y']:02X})")
        first = next((o["type"] for o in r["objs"] if o["slot"] == 1), 0)
        if ri["state"] == 0 and first in CARRIERS:
            problems.append(f"{p['room']:02X}: item {ri['id']:02X} is carried by the first monster ({first:02X})  [port: {'moves with it' if p.get('carries') else 'does not'}]")
    return problems


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rom", nargs="?", type=Path, default=OUT / "rom_rooms.json")
    parser.add_argument("port", nargs="?", type=Path, default=OUT / "port_rooms.json")
    parser.add_argument("--level", type=int)
    parser.add_argument("--quest", type=int)
    parser.add_argument("-v", action="store_true")
    args = parser.parse_args()
    rom = json.loads(args.rom.read_text())
    port = json.loads(args.port.read_text())
    total = 0
    for key in sorted(port):
        if key not in rom:
            continue
        p = port[key]
        if (args.level is not None and p["level"] != args.level) or (args.quest is not None and p["quest"] != args.quest):
            continue
        problems = compare(rom[key], p, args.v)
        total += len(problems)
        print(f"== quest {p['quest']} level {p['level']}: {len(problems)} differences")
        for line in problems:
            print("  ", line)
    print("total", total)


if __name__ == "__main__":
    main()
