#!/usr/bin/env python3
"""Turn the digidrum engine of the MOD/XM -> YM tool's player header into a binary the assembler can .incbin."""
from __future__ import annotations

import argparse
import re
from pathlib import Path


def _array(text: str, suffix: str) -> list[int]:
    match = re.search(rf"\b\w*{suffix}\[\d+\]\s*=\s*\{{(.*?)\}};", text, re.S)
    if match is None:
        raise SystemExit(f"no array ending in '{suffix}' found")
    return [int(token, 0) for token in re.findall(r"0[xX][0-9a-fA-F]+|\d+", match.group(1))]


def _words_be(words: list[int]) -> bytes:
    return b"".join(word.to_bytes(2, "big") for word in words)


def convert(player_header: Path, out_dir: Path) -> None:
    player = player_header.read_text(encoding="utf-8")
    engine = _words_be(_array(player, "ymdrum_code"))
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "music_engine.bin").write_bytes(engine)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    convert(args.player, args.out_dir)


if __name__ == "__main__":
    main()
