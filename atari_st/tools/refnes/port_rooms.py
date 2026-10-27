#!/usr/bin/env python3
"""What the port holds for every room, from the tables the build generated (build/generated), in the shape of rom_rooms.mjs.

    python3 port_rooms.py [out.json]        # default ../../build/refnes/port_rooms.json

The overworld of the Second Quest is the First Quest's with quest_patch.bin's runs laid over it, as quest_apply does.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))
import actors  # noqa: E402

GEN = TOOLS.parent / "build" / "generated"
ROOM_BYTES = actors.ROOM_INFO_BYTES
OW_BYTES = actors.OW_ROOM_INFO_BYTES
QUEST_TABLES = ("room_maps", "room_attr_a", "room_attr_b", "room_attr_c", "room_attr_d", "room_attr_f", "ow_room_info", "room_secrets")


def read(name: str) -> bytes:
    return (GEN / name).read_bytes()


def quest_two_tables(first: dict[str, bytes]) -> dict[str, bytes]:
    patch = read("quest_patch.bin")
    tables = {name: bytearray(data) for name, data in first.items()}
    pos = 0
    while patch[pos:pos + 2] != b"\xff\xff":
        number = int.from_bytes(patch[pos:pos + 2], "big")
        start = int.from_bytes(patch[pos + 2:pos + 4], "big")
        count = int.from_bytes(patch[pos + 4:pos + 6], "big")
        name = QUEST_TABLES[number]
        if name in tables:
            tables[name][start:start + count] = patch[pos + 6:pos + 6 + count]
        pos += 6 + count
    return {k: bytes(v) for k, v in tables.items()}


def nes_types(indices) -> list[int]:
    return [actors.MONSTER_TYPES[i] for i in indices if i != 0xFF]


def overworld(quest: int) -> dict:
    tables = {"ow_room_info": read("ow_room_info.bin")}
    if quest == 2:
        tables = quest_two_tables(tables)
    info = tables["ow_room_info"]
    rooms = []
    for room in range(128):
        rec = info[room * OW_BYTES:(room + 1) * OW_BYTES]
        rooms.append({"room": room, "present": True, "count": rec[0], "flags": rec[1], "types": nes_types(rec[6:16]),
                      "unsupported": 0, "item": None})
    return {"quest": quest, "level": 0, "rooms": rooms}


def underworld(quest: int, level: int) -> dict:
    key = f"{level}q2" if quest == 2 else f"{level}"
    index = read(f"uw{key}_room_index.bin")
    info = read(f"uw{key}_room_info.bin")
    rooms = []
    for room in range(128):
        i = index[room]
        if i == 0xFF:
            rooms.append({"room": room, "present": False})
            continue
        rec = info[i * ROOM_BYTES:(i + 1) * ROOM_BYTES]
        rooms.append({"room": room, "present": True, "count": rec[0], "trigger": rec[1], "types": nes_types(rec[6:14]),
                      "unsupported": rec[5] & 0x1F, "dark": bool(rec[5] & 0x80),
                      "item": {"id": rec[2], "x": rec[3], "y": rec[4]}})
    return {"quest": quest, "level": level, "rooms": rooms}


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else TOOLS.parent / "build" / "refnes" / "port_rooms.json"
    result = {}
    for quest in (1, 2):
        result[f"q{quest}_l0"] = overworld(quest)
        for level in range(1, 10):
            result[f"q{quest}_l{level}"] = underworld(quest, level)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result))
    print("wrote", out, file=sys.stderr)


if __name__ == "__main__":
    main()
