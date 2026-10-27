#!/usr/bin/env python3
"""Phase 2 of the playthrough audit, the port's side: play a dungeon room in Hatari with the dev-only autoplay
(src/autoplay.s, the same policy as rom_play.mjs) and sample the variable block every few frames.

    port_play.py [--quest 1|2] [--level N] [--rooms 0x74,0x73] [--frames 1500] [--every 10] [--name auto0] [out.json]

Needs ext/Original.nes and TOS (an EmuTOS image). One dev build and one Hatari run per room.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
sys.path.insert(0, str(PROJECT / "tools"))
import screenshot  # noqa: E402

START_VBL = 175           # the game starts running at about VBL 170 under EmuTOS
LOCATE_VBL = 230


def rooms_of(quest: int, level: int) -> list[int]:
    """The rooms the level has (from the generated tables of a normal build)."""
    key = f"{level}q2" if quest == 2 else f"{level}"
    index = (PROJECT / "build" / "generated" / f"uw{key}_room_index.bin").read_bytes()
    return [room for room, i in enumerate(index) if i != 0xFF]


def play_room(args, quest: int, level: int, room: int, layout: dict[str, int]):
    prg = screenshot.build_dev(PROJECT, None, room, level, False, quest, autoplay="idle" if args.idle else True, name=args.name)
    work = PROJECT / "build" / f"{args.name}_shots"
    work.mkdir(parents=True, exist_ok=True)
    ram_path = work / screenshot.RAM_DUMP
    # pass 1: where is the variable block?
    capture = work / "locate.ini"
    capture.write_text(f"savebin {ram_path} 0 $100000\ncont\n", encoding="utf-8")
    screenshot.run_hatari(args.hatari, args.tos, prg, work, LOCATE_VBL,
                          f"b VBL > {LOCATE_VBL - 1} :once :file {capture}\n")
    base = screenshot.find_globals(ram_path.read_bytes())
    size = layout["__size__"]
    # pass 2: the same run, dumping the block every few frames
    script, dumps = "", []
    for k, vbl in enumerate(range(START_VBL, START_VBL + args.frames + 1, args.every)):
        dump = work / f"s{k}.bin"
        step = work / f"s{k}.ini"
        step.write_text(f"savebin {dump} {base:#x} {size}\ncont\n", encoding="utf-8")
        script += f"b VBL > {vbl - 1} :once :file {step}\n"
        dumps.append(dump)
    last = START_VBL + args.frames
    screenshot.run_hatari(args.hatari, args.tos, prg, work, last, script)
    samples = []
    for dump in dumps:
        if not dump.exists():
            break
        block = dump.read_bytes()
        dump.unlink()

        def b(name, i=0):
            return block[layout[name] + i]

        count = b("ENEMY_COUNT")
        samples.append({
            "frame": int.from_bytes(block[layout["FRAME_COUNTER"]:][:2], "big"),
            "mode": b("GAME_MODE"), "room": b("ROOM_ID"), "link": [b("LINK_X"), b("LINK_Y")],
            "count": count,
            "mon": [[i, b("ENEMY_TYPE", i), b("ENEMY_X", i), b("ENEMY_Y", i), b("ENEMY_ACTIVE", i), b("ENEMY_CLOUD", i),
                     b("ENEMY_HP", i)] for i in range(count)],
            "items": [[b("ITEM_ACTIVE", i), b("ITEM_ID", i), b("ITEM_X", i), b("ITEM_Y", i)] for i in range(3)],
            # Levels 7-9 keep their world flags in the second set (UW_BLOCK = UW_B_DELTA, see globals.s)
            "open": b("UW_OPEN_B" if level >= 7 else "UW_OPEN", room), "flags": b("UW_FLAGS_B" if level >= 7 else "UW_FLAGS", room),
            "keys": b("INV_KEYS"),
            "kills": b("ROOM_KILLS"), "block": b("BLOCK_STATE"),
        })
    return samples


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("out", nargs="?", type=Path, default=PROJECT / "build" / "refnes" / "port_play.json")
    parser.add_argument("--quest", type=int, default=1, choices=(1, 2))
    parser.add_argument("--level", type=int, default=1)
    parser.add_argument("--rooms", default="", help="comma separated room ids (default: every room of the level)")
    parser.add_argument("--frames", type=int, default=1500)
    parser.add_argument("--every", type=int, default=10)
    parser.add_argument("--idle", action="store_true", help="Link only stands there (ROM: rom_play.mjs --idle)")
    parser.add_argument("--name", default="auto0", help="build/<name> is the dev build directory (use two for two workers)")
    parser.add_argument("--hatari", default="hatari")
    parser.add_argument("--tos", type=Path, default=Path(__import__("os").environ.get("TOS", "")))
    args = parser.parse_args()
    if not args.tos.is_file():
        raise SystemExit("Pass --tos or set TOS")
    layout = screenshot.parse_globals_layout(PROJECT / "src" / "globals.s")
    rooms = [int(r, 0) for r in args.rooms.split(",") if r] or rooms_of(args.quest, args.level)
    result = json.loads(args.out.read_text()) if args.out.exists() else {}
    key = f"q{args.quest}_l{args.level}"
    entry = result.setdefault(key, {"quest": args.quest, "level": args.level, "rooms": {}})
    for room in rooms:
        samples = play_room(args, args.quest, args.level, room, layout)
        entry["rooms"][f"{room:#04x}"] = samples
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result))
        print(f"{key} room {room:#04x}: {len(samples)} samples", flush=True)


if __name__ == "__main__":
    main()
