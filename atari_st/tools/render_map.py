#!/usr/bin/env python3
"""Render the whole decoded 16x8 overworld to one PNG for visual verification."""

from __future__ import annotations

import argparse
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_assets as B  # noqa: E402

MAP_COLS = 16
MAP_ROWS = 8


def st_to_rgb(color: int) -> tuple[int, int, int]:
    return (((color >> 8) & 7) * 36, ((color >> 4) & 7) * 36, (color & 7) * 36)


def write_png(path: Path, rows: list[list[tuple[int, int, int]]]) -> None:
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for rgb in row:
            raw.extend(rgb)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    header = struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def render_room(bundle: B.AssetBundle, room_id: int) -> list[list[tuple[int, int, int]]]:
    pixels = []
    room = bundle.rooms[room_id]
    for square_y in range(B.OW_ROOM_ROWS):
        rows = [[] for _ in range(B.METATILE_HEIGHT)]
        for square_x in range(B.OW_ROOM_COLS):
            row_pal, quad = bundle.metatiles[room[square_y * B.OW_ROOM_COLS + square_x]]
            tl, tr, bl, br = (bundle.bg_tiles[i] for i in quad)
            for y in range(B.METATILE_HEIGHT):
                left, right = (tl[y], tr[y]) if y < 8 else (bl[y - 8], br[y - 8])
                for value in left + right:
                    rows[y].append(st_to_rgb(bundle.palette.st_colors[bundle.palette.index(row_pal, value)]))
        pixels.extend(rows)
    return pixels


def render_underworld(bundle: B.AssetBundle) -> list[list[tuple[int, int, int]]]:
    uw = bundle.uw
    colours = [st_to_rgb(c) for c in bundle.palette.st_colors]
    tiles = []
    for tile in range(len(uw.tile_nes)):
        rows = []
        for y in range(8):
            planes = uw.tile_bank[tile * 32 + y * 4 : tile * 32 + y * 4 + 4]
            rows.append([
                colours[sum(((planes[p] >> (7 - x)) & 1) << p for p in range(4))] for x in range(8)
            ])
        tiles.append(rows)
    width, height = 32 * 8, 22 * 8
    canvas = [[(24, 24, 24)] * (16 * width) for _ in range(8 * height)]
    for room, index in enumerate(uw.room_index):
        if index == 0xFF:
            continue
        ox, oy = (room % 16) * width, (room // 16) * height
        grid = uw.rooms[index]
        for cell in range(32 * 22):
            cx, cy = (cell % 32) * 8, (cell // 32) * 8
            for y, row in enumerate(tiles[grid[cell]]):
                canvas[oy + cy + y][ox + cx : ox + cx + 8] = row
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=HERE.parent.parent)
    parser.add_argument("--out", type=Path, default=HERE.parent / "build" / "overworld.png")
    parser.add_argument("--room", type=lambda v: int(v, 0), help="render only this room id")
    parser.add_argument("--underworld", action="store_true", help="render the stored underworld rooms")
    args = parser.parse_args()

    bundle = B.load_assets(args.source_root)
    if args.underworld:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        write_png(args.out, render_underworld(bundle))
        print(f"wrote {args.out}")
        return
    if args.room is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        write_png(args.out, render_room(bundle, args.room))
        print(f"wrote {args.out}")
        return
    room_h = B.OW_ROOM_ROWS * 16
    rows = [[] for _ in range(MAP_ROWS * room_h)]
    for room_id in range(MAP_COLS * MAP_ROWS):
        base = (room_id // MAP_COLS) * room_h
        for y, row in enumerate(render_room(bundle, room_id)):
            rows[base + y].extend(row)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    write_png(args.out, rows)
    print(f"wrote {args.out} start_room={bundle.start_room:#04x} start_y={bundle.start_y:#04x}")


if __name__ == "__main__":
    main()
