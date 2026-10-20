#!/usr/bin/env python3
"""ZELDA.SAV, the saved games (src/save.s), as a Python model: build a file, read one, and check it.

The file is a header of eight bytes (the letters ZSAV, the version, a checksum of everything after the header: the sum
of its 16-bit words plus a seed) and three records of 640 bytes, one per profile. A record starts with what the file
menu shows (active, deaths, quest, ring, the hearts value and the partial heart, the eight tiles of the name) and goes on
with the state of the game, laid out by the `save_fields` table of save.s.

    python3 tools/savefile.py out.sav --name ZELDA --deaths 3       # a file with one profile, for tests in Hatari
                                                                    # (screenshot.py --hd-file ZELDA.SAV=out.sav)
"""
from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "src"

MAGIC = b"ZSAV"
VERSION = 1
SEED = 0x5A5A
RECORDS = 3
HEADER_BYTES = 8
RECORD_BYTES = 640
FILE_BYTES = HEADER_BYTES + RECORDS * RECORD_BYTES
STATE_OFFSET = 16
NAME_TILE_SPACE = 0x24
# the layout of the state, as in save.s `save_fields`: (variable, bytes)
FIELDS = [("ITEMS", 32), ("INV_RUPEES", 1), ("INV_KEYS", 1), ("HEART_CONTAINERS", 1), ("HP_HALVES", 1), ("HP_FRAC", 1),
          ("MAX_BOMBS", 1), ("B_ITEM", 1), ("TRIFORCE_PIECES", 1), ("INV_MAP", 1), ("INV_COMPASS", 1), ("TELE_INDEX", 1),
          ("PATCH_N", 1), ("PATCHES", 192), ("OW_KILLS", 128), ("UW_OPEN", 128), ("UW_FLAGS", 128)]
PATCH_MAX = 48


def checksum(body: bytes) -> int:
    """What save_checksum computes over the three records."""
    total = SEED
    for (word,) in struct.iter_unpack(">H", body):
        total = (total + word) & 0xFFFF
    return total


def blank_record() -> bytearray:
    return bytearray(RECORD_BYTES)


def field_offset(name: str) -> int:
    offset = STATE_OFFSET
    for field, size in FIELDS:
        if field == name:
            return offset
        offset += size
    raise KeyError(name)


def make_record(name: str = "ZELDA", deaths: int = 0, hearts: int = 0x22, partial: int = 0, ring: int = 0,
                state: dict[str, bytes] | None = None) -> bytearray:
    """An active profile; `state` gives bytes for some of the fields, the rest are zero."""
    record = blank_record()
    record[0:4] = bytes([1, deaths, 0, ring])
    record[4:6] = bytes([hearts, partial])
    tiles = [(0x0A + ord(c) - ord("A")) if c.isalpha() else NAME_TILE_SPACE for c in name.upper()[:8]]
    record[8:16] = bytes(tiles + [NAME_TILE_SPACE] * (8 - len(tiles)))
    for field, data in (state or {}).items():
        size = dict(FIELDS)[field]
        if len(data) > size:
            raise ValueError(f"{field} is {size} bytes")
        offset = field_offset(field)
        record[offset:offset + len(data)] = data
    return record


def make_file(records: list[bytes] | None = None) -> bytes:
    records = list(records or [])
    records += [bytes(RECORD_BYTES)] * (RECORDS - len(records))
    body = b"".join(bytes(r) for r in records)
    if len(body) != RECORDS * RECORD_BYTES:
        raise ValueError("a record is 640 bytes")
    return MAGIC + struct.pack(">HH", VERSION, checksum(body)) + body


def parse(data: bytes) -> list[bytes] | None:
    """The records, or None for what save_read takes as no file."""
    if len(data) != FILE_BYTES or data[:4] != MAGIC:
        return None
    version, total = struct.unpack(">HH", data[4:8])
    body = data[HEADER_BYTES:]
    if version != VERSION or total != checksum(body):
        return None
    return [body[i * RECORD_BYTES:(i + 1) * RECORD_BYTES] for i in range(RECORDS)]


def from_sources() -> dict[str, int]:
    """The constants as save.s and globals.s have them, to keep this model in step."""
    text = (SRC / "save.s").read_text(encoding="utf-8")
    found = {m.group(1): int(m.group(2), 0) for m in re.finditer(r"^\s*\.equ (\w+), (0x[0-9a-f]+|\d+)", text, re.M)}
    found["fields"] = re.findall(r"^\s*sfield (\w+), (\d+)", text, re.M)
    globals_text = (SRC / "globals.s").read_text(encoding="utf-8")
    found["gvars"] = {m.group(1): int(m.group(2)) for m in re.finditer(r"^\s*gvar (\w+), (\d+)", globals_text, re.M)}
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path)
    parser.add_argument("--name", default="ZELDA")
    parser.add_argument("--deaths", type=int, default=0)
    parser.add_argument("--hearts", type=lambda s: int(s, 0), default=0x22, help="the hearts value: containers in the high nibble")
    args = parser.parse_args()
    record = make_record(args.name, args.deaths, args.hearts, state={
        "HEART_CONTAINERS": bytes([3]), "HP_HALVES": bytes([6]), "MAX_BOMBS": bytes([8])})
    args.out.write_bytes(make_file([record]))
    print(f"wrote {args.out} ({FILE_BYTES} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
