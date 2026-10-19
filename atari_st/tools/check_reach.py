#!/usr/bin/env python3
"""Check the tables the code reaches through the a6 anchor.

`ltab sym, %aN` assembles to `move.l #(sym - table_anchor), %aN` and `adda.l %a6, %aN`: a 32-bit distance, so
the tables may sit anywhere in the image. (It used to be a `lea` with a 16-bit displacement, and a table more
than 32767 bytes from the anchor silently wrapped to the wrong address.) This reads the linked ELF's symbols,
fails the build when a symbol named in an `ltab` does not exist, and reports how far the tables spread; it
fails only if that spread could no longer be a 32-bit distance, and warns when the old 16-bit reach is passed.
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


BRANCH = re.compile(r"^\s*([0-9a-f]+):\s+(?:[0-9a-f]{4} )+\s*(?:bsr|bra|b[a-z]{2})w\s+([0-9a-f]+)\b")


def image_size(objdump: str, elf: Path) -> int:
    """End of the last section: columns of `objdump -h` are Size then VMA."""
    out = subprocess.run([objdump, "-h", str(elf)], check=True, capture_output=True, text=True).stdout
    return max(int(m.group(1), 16) + int(m.group(2), 16)
               for m in re.finditer(r"^\s*\d+\s+\S+\s+([0-9a-f]+)\s+([0-9a-f]+)\s", out, re.M))


def check_branches(objdump: str, elf: Path, image_end: int, code_end: int) -> list[str]:
    """A 16-bit branch reaches 32 KB either way; the assembler leaves it to the linker, which lets a longer one
    wrap silently into the wrong address (it once sent the main loop's `bsr draw_hud` into low RAM). The
    disassembly prints the wrapped target, so any word branch landing outside the image is one of those."""
    out = subprocess.run([objdump, "-d", str(elf)], check=True, capture_output=True, text=True).stdout
    bad = []
    for line in out.splitlines():
        match = BRANCH.match(line)
        # past code_end is the rodata, whose bytes the disassembler also takes for instructions
        if match and int(match.group(1), 16) < code_end and int(match.group(2), 16) >= image_end:
            bad.append(line.strip())
    return bad


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    parser.add_argument("sources", type=Path, nargs="+")
    parser.add_argument("--nm", default="m68k-linux-gnu-nm")
    parser.add_argument("--objdump", default="m68k-linux-gnu-objdump")
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
    if bad:
        sys.exit("Tables the code names but the image lacks:\n  " + "\n  ".join(bad))
    wrapped = check_branches(args.objdump, args.elf, image_size(args.objdump, args.elf), symbols.get("room_palette", 1 << 32))
    if wrapped:
        sys.exit("16-bit branches that overflowed (go through a *_far stub in main.s):\n  " + "\n  ".join(wrapped))
    print(f"Tables ok: {len(used)} tables, furthest back {-far_back}, furthest ahead {far_ahead} bytes from table_anchor")


if __name__ == "__main__":
    main()
