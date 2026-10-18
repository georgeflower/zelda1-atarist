#!/usr/bin/env python3
"""Check that every table the code reaches through the a6 anchor is within 16-bit reach.

`ltab sym, %aN` assembles to `lea sym - table_anchor(%a6), %aN`. GNU as accepts displacements up to
65535 for that field without complaint, so a table that has crept more than 32767 bytes ahead of the
anchor silently wraps to the wrong address (the overworld then draws garbage). This reads the linked
ELF's symbols and fails the build when any symbol named in an `ltab` is out of the signed range.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

LTAB = re.compile(r"^\s*ltab\s+([A-Za-z_][A-Za-z0-9_]*)\s*,")


def symbol_addresses(nm: str, elf: Path) -> dict[str, int]:
    out = subprocess.run([nm, "-n", str(elf)], check=True, capture_output=True, text=True).stdout
    table = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3:
            table[parts[2]] = int(parts[0], 16)
    return table


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    parser.add_argument("sources", type=Path, nargs="+")
    parser.add_argument("--nm", default="m68k-linux-gnu-nm")
    args = parser.parse_args()
    symbols = symbol_addresses(args.nm, args.elf)
    anchor = symbols["table_anchor"]
    used: dict[str, str] = {}
    for source in args.sources:
        for number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
            match = LTAB.match(line.split("|", 1)[0])
            if match:
                used.setdefault(match.group(1), f"{source.name}:{number}")
    bad = []
    far_back = far_ahead = 0
    for name, where in sorted(used.items()):
        if name not in symbols:
            bad.append(f"{name} ({where}) is not a symbol in the ELF")
            continue
        distance = symbols[name] - anchor
        far_back = min(far_back, distance)
        far_ahead = max(far_ahead, distance)
        if not -32768 <= distance <= 32767:
            bad.append(f"{name} ({where}) is {distance:+d} bytes from table_anchor")
    if bad:
        sys.exit("Tables out of reach of the anchor (move table_anchor or the tables):\n  " + "\n  ".join(bad))
    print(f"Table reach ok: {len(used)} tables, back {-far_back} / 32768, ahead {far_ahead} / 32767")


if __name__ == "__main__":
    main()
