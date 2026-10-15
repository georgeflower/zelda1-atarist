#!/usr/bin/env python3
"""Turn the C headers from the MOD/XM -> YM tool into binaries the assembler can .incbin."""
from __future__ import annotations

import argparse
import re
from pathlib import Path


def _array(text: str, suffix: str) -> list[int]:
    match = re.search(rf"\b\w*{suffix}\[\d+\]\s*=\s*\{{(.*?)\}};", text, re.S)
    if match is None:
        raise SystemExit(f"no array ending in '{suffix}' found")
    return [int(token, 0) for token in re.findall(r"0[xX][0-9a-fA-F]+|\d+", match.group(1))]


def _define(text: str, suffix: str) -> int:
    match = re.search(rf"#define\s+\w*{suffix}\s+(\d+)", text)
    if match is None:
        raise SystemExit(f"no #define ending in '{suffix}' found")
    return int(match.group(1))


def _words_be(words: list[int]) -> bytes:
    return b"".join(word.to_bytes(2, "big") for word in words)


def convert(song_header: Path, player_header: Path, out_dir: Path) -> None:
    song = song_header.read_text(encoding="utf-8")
    player = player_header.read_text(encoding="utf-8")

    stream = bytes(_array(song, "_data"))
    drums = _words_be(_array(song, "_drums"))
    engine = _words_be(_array(player, "ymdrum_code"))
    frames = _define(song, "_FRAMES")

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "music_data.bin").write_bytes(stream)
    (out_dir / "music_drums.bin").write_bytes(drums)
    (out_dir / "music_engine.bin").write_bytes(engine)
    (out_dir / "music.inc").write_text(
        f"    .equ MUSIC_FRAMES, {frames}\n"
        f"    .equ MUSIC_LOOP_FRAME, {_define(song, '_LOOP_FRAME')}\n"
        f"    .equ MUSIC_LOOP_OFFSET, {_define(song, '_LOOP_OFFSET')}\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--song", type=Path, required=True)
    parser.add_argument("--player", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    convert(args.song, args.player, args.out_dir)


if __name__ == "__main__":
    main()
