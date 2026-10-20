#!/usr/bin/env python3
"""Convert Zelda 1 ROM data into Atari ST planar assets.

Everything here reads the original data through `src/bins.xml` (or an already
extracted `bin/dat/` tree) and re-encodes it for a 320x200 four-bitplane ST
screen. No Nintendo data is stored in this repository; the ROM stays local.
"""
from __future__ import annotations

import argparse
import os
import re
import textwrap
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

METATILE_WIDTH = 16
METATILE_HEIGHT = 16
METATILE_BYTES = METATILE_HEIGHT * 8
CHR_TILE_BYTES = 16

# Pattern blocks are raw CHR streams that the game copies to fixed PPU addresses.
# CommonPatternVramAddrs (Z_02.asm) and PatternBlockPpuAddrs (Z_03.asm) fix where
# each one lands, which in turn fixes the tile index each blob starts at.
OW_BG_COMMON_NAME = "dat/CommonBackgroundPatterns.dat"
OW_BG_BLOCK_NAME = "dat/PatternBlockOWBG.dat"
OW_BG_MISC_NAME = "dat/CommonMiscPatterns.dat"
OW_SP_COMMON_NAME = "dat/CommonSpritePatterns.dat"
OW_SP_BLOCK_NAME = "dat/PatternBlockOWSP.dat"
OW_BG_COMMON_FIRST_TILE = 0x00  # PPU $1000
OW_BG_BLOCK_FIRST_TILE = 0x70  # PPU $1700
OW_BG_MISC_FIRST_TILE = 0xF2  # PPU $1F20
OW_SP_COMMON_FIRST_TILE = 0x00  # PPU $0000
OW_SP_BLOCK_FIRST_TILE = 0x8E  # PPU $08E0

ROOM_LAYOUTS_OW_NAME = "dat/RoomLayoutsOW.dat"
LEVEL_BLOCK_OW_NAME = "dat/LevelBlockOW.dat"
LEVEL_INFO_OW_NAME = "dat/LevelInfoOW.dat"

OW_ROOM_COLS = 16
OW_ROOM_ROWS = 11
OW_ROOM_COUNT = 128
# PondCycleColors (Z_07.asm): the water of the Level 7 pond, one step each eighth frame while the recorder plays
POND_CYCLE_COLORS = (0x12, 0x11, 0x22, 0x21, 0x31, 0x32, 0x33, 0x35, 0x34, 0x36, 0x37, 0x37)
POND_PALETTE_ROW = 3                # the water's background palette row; its last colour is the one that cycles
OW_EXTRA_BYTES = 16                 # after the 128 records of room_secrets: the pond's stairs, then the armos (see decode_overworld)
POND_ROOM = 0x42                    # the Level 7 screen whose pond the recorder drains (FluteRoomSecretsOW)
POND_STAIRS_SQUARE = 0x56           # row 5, column 6: RevealPondStairs puts them at ($60, $90)
ARMOS_TILES = (0xC0, 0xC1, 0xC2, 0xC3)
OW_SECRET_BYTES = 8                 # a record of room_secrets.bin (see "The overworld's hidden spots")
OW_COLUMNS_PER_ROOM = 0x10
LEVEL_BLOCK_TABLE_SIZE = 128
# NextRoomIdOffsets (Z_05.asm) adds -16/+16/-1/+1, so the overworld map is a
# 16-wide grid of the 128 rooms.
OW_GRID_WIDTH = 16
OW_GRID_HEIGHT = OW_ROOM_COUNT // OW_GRID_WIDTH

# LevelInfo begins at $6B7E and opens with a 36-byte PPU transfer buffer:
# a 3-byte header, 8 palette rows of 4 NES colour indices, then a $FF terminator.
LEVEL_INFO_BASE = 0x6B7E
LEVEL_INFO_PALETTE_OFFSET = 3
LEVEL_INFO_FOE_COUNTS = 0x6BA2 - LEVEL_INFO_BASE
LEVEL_INFO_START_Y = 0x6BA6 - LEVEL_INFO_BASE
LEVEL_INFO_START_ROOM_ID = 0x6BAD - LEVEL_INFO_BASE
LEVEL_INFO_TRIFORCE_ROOM_ID = 0x6BAE - LEVEL_INFO_BASE
LEVEL_INFO_ITEM_POSITIONS = 0x6BA7 - LEVEL_INFO_BASE
PALETTE_ROWS = 8
PALETTE_ROW_COLORS = 4
BACKGROUND_PALETTE_ROWS = 4
ST_PALETTE_SIZE = 16

# InitMode3_Sub8 (Z_05.asm) drops Link in the middle horizontally, facing up,
# at the Y the level info supplies.
LINK_START_X = 0x78
LINK_START_DIR = 0x08
# Zelda's direction bits, used throughout the disassembly.
DIR_RIGHT, DIR_LEFT, DIR_DOWN, DIR_UP = 0x01, 0x02, 0x04, 0x08

# Squares covered by the "inner" palette selector rather than the "outer" one,
# derived from FillPlayAreaAttrs in Z_05.asm.
OW_INNER_COL_RANGE = range(2, 14)
OW_INNER_ROW_RANGE = range(2, 9)

# Link's walking frames. ObjAnimations[0] points at ObjAnimFrameHeap[0], whose
# first four entries are the left tile of each frame (Z_01.asm). The NES draws him
# as two 8x16 sprites, so a frame covers tiles T, T+1 (left) and T+2, T+3 (right).
LINK_FRAME_TILES = (0x00, 0x04, 0x08, 0x0C)
# ObjAnimAttrHeap[0..3] are all 0, i.e. sprite palette row 0 == NES palette row 4.
LINK_PALETTE_ROW = 4
ENEMY_FRAME_COUNT = 2
# SetUpWalkingSprites picks tile $00/$04 for horizontal and flips for left; for
# vertical it uses one tile and flips on the second walk frame.
LINK_FRAMES = (
    ("right_a", 0x00, False),
    ("right_b", 0x04, False),
    ("left_a", 0x00, True),
    ("left_b", 0x04, True),
    ("down_a", 0x08, False),
    ("down_b", 0x08, True),
    ("up_a", 0x0C, False),
    ("up_b", 0x0C, True),
)
SPRITE_FRAME_WORDS = 5  # four bitplanes plus an opacity mask
SPRITE_FRAME_BYTES = METATILE_HEIGHT * SPRITE_FRAME_WORDS * 2

# HUD glyphs. Zelda's font puts '0'-'9' at $00-$09 and 'A'-'Z' at $0A-$23, so 'X'
# (the multiplication sign in the counters) is $21 and blank is $24. Heart tiles
# come from Z_01.asm:3277; the counter icons from StatusBarStaticsTransferBuf.
# The attribute bytes at the head of that buffer put text on palette row 0 and
# the hearts and icons on row 1.
HUD_TEXT_ROW = 0
HUD_ACCENT_ROW = 1
HUD_TILE_BYTES = 8 * 4  # eight rows, one byte per bitplane
HUD_GLYPHS = (
    ("BLANK", 0x24, HUD_TEXT_ROW),
    *((f"DIGIT{digit}", digit, HUD_TEXT_ROW) for digit in range(10)),
    ("X", 0x21, HUD_TEXT_ROW),
    ("L", 0x15, HUD_TEXT_ROW),
    ("I", 0x12, HUD_TEXT_ROW),
    ("F", 0x0F, HUD_TEXT_ROW),
    ("E", 0x0E, HUD_TEXT_ROW),
    ("HEART_FULL", 0xF2, HUD_ACCENT_ROW),
    ("HEART_HALF", 0x65, HUD_ACCENT_ROW),
    ("HEART_EMPTY", 0x66, HUD_ACCENT_ROW),
    ("RUPEE", 0xF7, HUD_ACCENT_ROW),
    ("KEY", 0xF9, HUD_ACCENT_ROW),
    ("BOMB", 0x61, HUD_ACCENT_ROW),
    # The item boxes of the status bar.
    ("BOX_TL", 0x69, HUD_TEXT_ROW),
    ("BOX_TR", 0x6B, HUD_TEXT_ROW),
    ("BOX_SIDE", 0x6C, HUD_TEXT_ROW),
    # Letters and punctuation for the people in caves; the NES code is the tile.
    *((f"CH_{chr(ord('A') + n)}", 0x0A + n, HUD_TEXT_ROW) for n in range(26)),
    ("CH_COMMA", 0x28, HUD_TEXT_ROW),
    ("CH_BANG", 0x29, HUD_TEXT_ROW),
    ("CH_APOS", 0x2A, HUD_TEXT_ROW),
    ("CH_PERIOD", 0x2C, HUD_TEXT_ROW),
    ("CH_QUESTION", 0x2E, HUD_TEXT_ROW),
    ("CH_MINUS", 0x2F, HUD_TEXT_ROW),
    ("CH_PLUS", 0x64, HUD_TEXT_ROW),    # the money game's "+20"; text code CODE_PLUS stands for it
)
CODE_PLUS = 0x2B                         # a text code no speech uses

CAVE_WALL_ROW = PALETTE_ROWS       # the palette row appended for the cave's row 3
PERSON_TEXT_NAME = "dat/PersonText.dat"
def _ending_text(lines: tuple[str, ...]) -> bytes:
    """NES text codes for lines of text, in cave_talk's layout: the last character of a line carries $80 (the second
    line next), $40 (the third) or $C0 (the end)."""
    marks = (0x80, 0x40)
    out = bytearray()
    for number, line in enumerate(lines):
        codes = bytearray()
        for character in line:
            codes.append(0x24 if character == " " else {",": 0x28, "!": 0x29, "'": 0x2A, ".": 0x2C}.get(character)
                         or int(character, 36))
        codes[-1] |= 0xC0 if number == len(lines) - 1 else marks[number]
        out.extend(codes)
    return bytes(out)


# Zelda's words (ThanksText in Z_02.asm: the second line is a blank one) and the last screen of the credits.
ENDING_THANKS_TEXT = _ending_text(("THANKS LINK,YOU'RE", " ", "THE HERO OF HYRULE."))
ENDING_PEACE_TEXT = _ending_text(("PEACE RETURNS TO HYRULE.", " ", "THIS ENDS THE STORY."))   # the original has a "FINALLY," first
# The credits (CreditsTextLines.dat, three lines to a page instead of a scrolling wall), and the port's own line.
CREDIT_PAGES = (
    ("EXECUTIVE PRODUCER", " ", "H.YAMAUCHI"),
    ("PRODUCER AND DIRECTOR", " ", "S.MIYAHON"),
    ("DESIGNER", " ", "TEN TEN"),
    ("PROGRAMMERS", "T.NAKAZOO", "YACHAN, MARUMARU"),
    ("SOUND COMPOSER", " ", "KONCHAN"),
    ("ATARI ST PORT", " ", "BY Q"),
    ("YOU ARE GREAT.", "YOU HAVE AN AMAZING", "WISDOM AND POWER."),
    ("END OF", " ", "THE LEGEND OF ZELDA"),
)
CREDIT_TEXTS = tuple(_ending_text(page) for page in CREDIT_PAGES)
ENDING_TEXTS = ENDING_THANKS_TEXT + ENDING_PEACE_TEXT + b"".join(CREDIT_TEXTS)

PERSON_TEXT_BYTES = 43             # the first person's speech
OLD_MAN_TYPE = 0x6A
FIRE_ANIM_INDEX = 0x41
CAVE_SPRITE_FRAMES = 6             # old man, fire, fire turned round, old woman, shopkeeper, moblin
CAVE_PEOPLE = ((0x73, "mirror"), (0x77, "mirror"), (0x7B, "wide"))   # the other people: the type whose animation draws them, and how
CAVE_TYPES = 20                    # $6A..$7D
CAVE_RECORD_BYTES = 16             # a record of cave_table.bin (see build_caves)
CAVE_NONE = 0x3F                   # no item in a ware's slot
CAVE_LAST_MAN, CAVE_LAST_WOMAN, CAVE_LAST_SHOP = 0x72, 0x76, 0x7A

# GetCollidableTile (Z_07.asm) treats a tile as blocking when it is at or above
# ObjectFirstUnwalkableTile, except for the tiles in this list, which it rewrites
# to a walkable value first. ObjectRoomBoundsOW (Z_05.asm) supplies both the
# threshold and the room bounds the engine uses.
OW_FIRST_UNWALKABLE_TILE = 0x89
OW_WALKABLE_TILES = (0x8D, 0x91, 0x9C, 0xAC, 0xAD, 0xCC, 0xD2, 0xD5, 0xDF)
OW_ROOM_BOUNDS = (0x11, 0xE0, 0x4E, 0xCD)

# 2C02 PPU colour output, used to map NES colour indices onto the ST's 3-bit RGB.
NES_RGB = (
    (0x74, 0x74, 0x74), (0x24, 0x18, 0x8C), (0x00, 0x00, 0xA8), (0x44, 0x00, 0x9C),
    (0x8C, 0x00, 0x74), (0xA8, 0x00, 0x10), (0xA4, 0x00, 0x00), (0x7C, 0x08, 0x00),
    (0x40, 0x2C, 0x00), (0x00, 0x44, 0x00), (0x00, 0x50, 0x00), (0x00, 0x3C, 0x14),
    (0x18, 0x3C, 0x5C), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0xBC, 0xBC, 0xBC), (0x00, 0x70, 0xEC), (0x20, 0x38, 0xEC), (0x80, 0x00, 0xF0),
    (0xBC, 0x00, 0xBC), (0xE4, 0x00, 0x58), (0xD8, 0x28, 0x00), (0xC8, 0x4C, 0x0C),
    (0x88, 0x70, 0x00), (0x00, 0x94, 0x00), (0x00, 0xA8, 0x00), (0x00, 0x90, 0x38),
    (0x00, 0x80, 0x88), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0xFC, 0xFC, 0xFC), (0x3C, 0xBC, 0xFC), (0x5C, 0x94, 0xFC), (0xCC, 0x88, 0xFC),
    (0xF4, 0x78, 0xFC), (0xFC, 0x74, 0xB4), (0xFC, 0x74, 0x60), (0xFC, 0x98, 0x38),
    (0xF0, 0xBC, 0x3C), (0x80, 0xD0, 0x10), (0x4C, 0xDC, 0x48), (0x58, 0xF8, 0x98),
    (0x00, 0xE8, 0xD8), (0x78, 0x78, 0x78), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
    (0xFC, 0xFC, 0xFC), (0xA8, 0xE4, 0xFC), (0xC4, 0xD4, 0xFC), (0xD4, 0xC8, 0xFC),
    (0xFC, 0xC4, 0xFC), (0xFC, 0xC4, 0xD8), (0xFC, 0xBC, 0xB0), (0xFC, 0xD8, 0xA8),
    (0xFC, 0xE4, 0xA0), (0xE0, 0xFC, 0xA0), (0xA8, 0xF0, 0xBC), (0xB0, 0xFC, 0xCC),
    (0x9C, 0xFC, 0xF0), (0xC4, 0xC4, 0xC4), (0x00, 0x00, 0x00), (0x00, 0x00, 0x00),
)

def nes_color_to_st(color_index: int) -> int:
    red, green, blue = NES_RGB[color_index & 0x3F]
    return ((red >> 5) << 8) | ((green >> 5) << 4) | (blue >> 5)


@dataclass(frozen=True)
class PaletteMap:
    """One ST palette shared by every NES palette row.

    The NES gives four background rows and four sprite rows of three colours each
    plus a universal backdrop. For the overworld those collapse to sixteen
    distinct ST colours, so a single hardware palette covers tiles and sprites
    with no loss. `table[row][pixel]` is the ST entry a CHR pixel value maps to.
    """

    st_colors: tuple[int, ...]
    table: tuple[tuple[int, ...], ...]

    def index(self, row: int, pixel: int) -> int:
        return self.table[row][pixel]


def build_palette_map(palette_bytes: Sequence[int]) -> PaletteMap:
    """Merge all eight NES palette rows into one 16-entry ST palette."""
    backdrop = palette_bytes[0]
    order: list[int] = []
    table: list[tuple[int, ...]] = []
    for row in range(PALETTE_ROWS):
        entries = []
        for pixel in range(PALETTE_ROW_COLORS):
            # Pixel 0 always shows the universal backdrop, whichever row it is.
            color = backdrop if pixel == 0 else palette_bytes[row * PALETTE_ROW_COLORS + pixel]
            if color not in order:
                order.append(color)
            entries.append(order.index(color))
        table.append(tuple(entries))

    if len(order) > ST_PALETTE_SIZE:
        raise SystemExit(
            f"NES palette needs {len(order)} distinct colours but the ST only has {ST_PALETTE_SIZE}"
        )

    st_colors = [nes_color_to_st(color) for color in order]
    st_colors.extend([0] * (ST_PALETTE_SIZE - len(st_colors)))
    return PaletteMap(st_colors=tuple(st_colors), table=tuple(table))


def extract_binary(source_root: Path, name: str) -> bytes | None:
    """Read a named blob listed in src/bins.xml, preferring an already-extracted copy."""
    direct = source_root / "bin" / name
    if direct.exists():
        return direct.read_bytes()

    rom_path = source_root / "ext" / "Original.nes"
    bins_path = source_root / "src" / "bins.xml"
    if not rom_path.exists() or not bins_path.exists():
        return None

    rom = rom_path.read_bytes()
    if len(rom) < 16 or rom[:4] != b"NES\x1a":
        raise ValueError(f"{rom_path} is not a valid iNES ROM image")
    trainer_bytes = 512 if (rom[6] & 0x04) else 0
    # bins.xml offsets are relative to the start of PRG ROM (see build.ps1).
    data_offset = 16 + trainer_bytes

    xml_root = ET.fromstring(bins_path.read_text(encoding="utf-8"))
    for binary in xml_root.iterfind(".//Binary"):
        if binary.attrib.get("FileName") != name:
            continue
        offset = int(binary.attrib["Offset"], 0) + data_offset
        length = int(binary.attrib["Length"], 0)
        if offset + length > len(rom):
            raise ValueError(
                f"{rom_path} is too short for {name}: need {offset + length} bytes, found {len(rom)}"
            )
        return rom[offset : offset + length]

    return None


def require_binary(source_root: Path, name: str) -> bytes:
    data = extract_binary(source_root, name)
    if data is None:
        raise SystemExit(f"Could not obtain {name} from bin/ or ext/Original.nes")
    return data


_BYTE_LINE = re.compile(r"^\s*\.BYTE\s+(.+?)\s*$", re.IGNORECASE)


def parse_asm_byte_table(asm_text: str, label: str) -> list[int]:
    """Read a contiguous run of .BYTE directives following `label:` in a disassembly file."""
    marker = f"\n{label}:"
    start = asm_text.find(marker)
    if start < 0:
        raise SystemExit(f"Could not find label {label} in the disassembly")

    values: list[int] = []
    for line in asm_text[start + len(marker) :].splitlines()[1:]:
        if not line.strip():
            continue
        match = _BYTE_LINE.match(line)
        if not match:
            break
        for item in match.group(1).split(","):
            item = item.strip()
            if item:
                values.append(int(item.replace("$", "0x"), 0))
    return values


def parse_column_heaps(asm_text: str) -> list[int]:
    """The ColumnHeapOW tables are laid out contiguously and indexed via ColumnDirectoryOW."""
    blob: list[int] = []
    for digit in "0123456789ABCDEF":
        label = f"ColumnHeapOW{digit}"
        if f"\n{label}:" not in asm_text:
            break
        blob.extend(parse_asm_byte_table(asm_text, label))
    if not blob:
        raise SystemExit("Could not find any ColumnHeapOW tables in the disassembly")
    return blob


def parse_column_directory(asm_text: str) -> list[int]:
    """Convert the directory's absolute addresses into offsets into the heap blob."""
    raw = parse_asm_byte_table(asm_text, "ColumnDirectoryOW")
    addresses = [raw[i] | (raw[i + 1] << 8) for i in range(0, len(raw), 2)]
    base = addresses[0]
    return [address - base for address in addresses]


def decode_column(heap: list[int], start: int, column_index: int) -> list[int]:
    """Walk a column heap to the requested column and expand it to OW_ROOM_ROWS squares."""
    remaining = column_index
    pos = start - 1
    while True:
        pos += 1
        if pos >= len(heap):
            raise SystemExit(f"Ran off the end of a column heap looking for column {column_index}")
        if heap[pos] & 0x80:
            remaining -= 1
            if remaining < 0:
                break

    squares: list[int] = []
    repeat_state = 0
    while len(squares) < OW_ROOM_ROWS:
        descriptor = heap[pos]
        squares.append(descriptor & 0x3F)
        if descriptor & 0x40:
            # Bit 6 means "draw this square twice"; the toggle mirrors [$0C] in LayoutRoomOW.
            repeat_state ^= 0x40
            if repeat_state == 0:
                pos += 1
        else:
            pos += 1
    return squares


def square_to_tiles(square_index: int, primary: list[int], secondary: list[int]) -> tuple[int, int, int, int]:
    """Return (top-left, top-right, bottom-left, bottom-right) CHR indices for a square."""
    if square_index >= 0x10:
        base = primary[square_index]
        quad = (base, base + 1, base + 2, base + 3)
    else:
        offset = square_index * 4
        quad = tuple(secondary[offset : offset + 4])
    # WriteSquareOW stores the quad column-major: (col,row), (col,row+1), (col+1,row), (col+1,row+1).
    return quad[0], quad[2], quad[1], quad[3]


def tile_is_blocking(tile: int) -> bool:
    """Apply GetCollidableTile's walkability rule to a single background tile."""
    if tile in OW_WALKABLE_TILES:
        return False
    return tile >= OW_FIRST_UNWALKABLE_TILE


def decode_nes_chr(data: bytes) -> list[list[list[int]]]:
    if len(data) % CHR_TILE_BYTES != 0:
        raise ValueError(f"CHR data length {len(data)} is not divisible by {CHR_TILE_BYTES}")

    tiles: list[list[list[int]]] = []
    for tile_offset in range(0, len(data), CHR_TILE_BYTES):
        plane0 = data[tile_offset : tile_offset + 8]
        plane1 = data[tile_offset + 8 : tile_offset + 16]
        tile_rows: list[list[int]] = []
        for row in range(8):
            row_pixels = []
            lo = plane0[row]
            hi = plane1[row]
            for bit in range(7, -1, -1):
                pixel = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                row_pixels.append(pixel)
            tile_rows.append(row_pixels)
        tiles.append(tile_rows)
    return tiles


def assemble_pattern_table(blocks: Iterable[tuple[int, bytes]]) -> list[list[list[int]]]:
    """Lay CHR blobs into a 256-entry pattern table at their runtime tile indices."""
    tiles: list[list[list[int]]] = [[[0] * 8 for _ in range(8)] for _ in range(256)]
    for base, data in blocks:
        for offset, tile in enumerate(decode_nes_chr(data)):
            index = base + offset
            if index < len(tiles):
                tiles[index] = tile
    return tiles


@dataclass(frozen=True)
class AssetBundle:
    source_note: str
    palette: PaletteMap
    bg_tiles: list[list[list[int]]]
    sprite_tiles: list[list[list[int]]]
    rooms: list[list[int]]
    metatiles: list[tuple[int, tuple[int, int, int, int]]]
    room_attrs_a: list[int]
    room_attrs_b: list[int]
    room_attrs_c: list[int]
    room_attrs_d: list[int]
    room_attrs_f: list[int]
    foe_counts: list[int]
    start_room: int
    start_y: int
    uw: object | None = None        # level 1: the tables shared by every level (monsters, items, ...) come from it
    levels: tuple = ()              # every playable level's UwData, in order (empty: just `uw`)
    cave_map: bytes = bytes(2 * OW_ROOM_COLS * OW_ROOM_ROWS)   # the usual cave's room, then the take-any-road room
    cave_sprites: bytes = bytes(CAVE_SPRITE_FRAMES * SPRITE_FRAME_BYTES)
    cave_text: bytes = bytes((0xEC,)) + ENDING_TEXTS
    cave_table: bytes = bytes(CAVE_TYPES * CAVE_RECORD_BYTES)   # one record per cave type (build_caves)
    cave_shortcuts: bytes = bytes(4)    # the four screens of the take-any-road caves
    ow_room_info: bytes = bytes(128 * 16)   # overworld screens: monster count, flags, monster indices (actors.py)
    room_secrets: bytes = bytes(128 * OW_SECRET_BYTES + OW_EXTRA_BYTES)   # overworld screens: the hidden spot, if any (OW_SECRET_BYTES)
    level_palettes: tuple = ()      # nine rows of 16 ST colours, one per dungeon (empty = reuse `palette`)
    intro: object | None = None     # the title, the story and the parade (tools/intro.py IntroData)
    menus: object | None = None     # the file menu: player select, register, elimination (tools/filesel.py MenuData)
    gameover: object | None = None  # Link's death: the colours, the grey Link and the spark (tools/gameover.py)


def load_uw_background_tiles(source_root: Path) -> list[list[list[int]]] | None:
    """Rebuild the background pattern table that the underworld sees at runtime."""
    import underworld

    common = extract_binary(source_root, OW_BG_COMMON_NAME)
    block = extract_binary(source_root, underworld.UW_BG_BLOCK_NAME)
    if common is None or block is None:
        return None
    misc = extract_binary(source_root, OW_BG_MISC_NAME) or b""
    return assemble_pattern_table(
        (
            (OW_BG_COMMON_FIRST_TILE, common),
            (underworld.UW_BG_BLOCK_FIRST_TILE, block),
            (OW_BG_MISC_FIRST_TILE, misc),
        )
    )


def load_ow_background_tiles(source_root: Path) -> list[list[list[int]]] | None:
    """Rebuild the background pattern table that the overworld sees at runtime."""
    common = extract_binary(source_root, OW_BG_COMMON_NAME)
    block = extract_binary(source_root, OW_BG_BLOCK_NAME)
    if common is None or block is None:
        return None
    misc = extract_binary(source_root, OW_BG_MISC_NAME) or b""
    return assemble_pattern_table(
        (
            (OW_BG_COMMON_FIRST_TILE, common),
            (OW_BG_BLOCK_FIRST_TILE, block),
            (OW_BG_MISC_FIRST_TILE, misc),
        )
    )


def load_ow_sprite_tiles(source_root: Path) -> list[list[list[int]]] | None:
    """Rebuild the sprite pattern table that the overworld sees at runtime."""
    common = extract_binary(source_root, OW_SP_COMMON_NAME)
    if common is None:
        return None
    block = extract_binary(source_root, OW_SP_BLOCK_NAME) or b""
    return assemble_pattern_table(
        ((OW_SP_COMMON_FIRST_TILE, common), (OW_SP_BLOCK_FIRST_TILE, block))
    )


# ---- The overworld's hidden spots (TileObjectTypes $62-$67 in the ROM) ----
# The layouts hide a secret behind a "marker" square (PrimarySquaresOW $E5-$EA). The ROM draws it as the
# plain square of TileObjectPrimarySquaresOW ($C8 rock, $D8 rock wall, $C4 tree, $BC gravestone, $C0 armos) and
# makes a tile object of it. The port does the same: the markers are drawn as that square, and the spot goes
# into room_secrets.bin, 128 records of OW_SECRET_BYTES:
#   0 type (OW_SECRET_*; 0 = none)       1 the marker's square in the room (row * 16 + column)
#   2 the metatile it turns into when the secret is found (bomb wall: cave entrance; tree: stairs; rock and
#     gravestone: bare floor where it stood)
#   3 the square of the stairs a pushed rock or gravestone uncovers (GetShortcutOrItemXYForRoom)  4 their metatile
#   5 the rock's (or gravestone's) metatile when it ends one square above the marker  6 ... one square below
#   7 spare
# 0xFF in 5 or 6 means that push would leave the room.
OW_SECRET_NONE, OW_SECRET_BOMB, OW_SECRET_TREE, OW_SECRET_ROCK, OW_SECRET_GRAVE = range(5)
OW_SECRET_MARKER_TYPES = {0xE5: OW_SECRET_ROCK, 0xE6: OW_SECRET_BOMB, 0xE7: OW_SECRET_TREE, 0xE8: OW_SECRET_GRAVE}
OW_SQUARE_CAVE = 12                             # the secondary square a found rock wall becomes (LayoutRoomOW: $0C)
OW_SQUARE_FLOOR = 14                            # ChangeTileObjTiles($26) makes four floor tiles: this square
OW_STAIRS_PRIMARY = 0x70
QUEST_SECOND_ONLY = 2                           # attribute F bits 6-7: 2 = the secret exists in the second quest only


def overworld_square_for_primary(primary: list[int], wanted: int) -> int:
    """The type 1 square (index >= $10) whose first tile is `wanted`, as PrimarySquaresOW lists them."""
    for index in range(0x10, len(primary)):
        if primary[index] == wanted:
            return index
    raise SystemExit(f"No overworld square has primary {wanted:#04x}")


def decode_overworld(
    source_root: Path, chr_tiles: list[list[list[int]]]
) -> tuple[
    list[list[int]],
    list[tuple[int, tuple[int, int, int, int]]],
    list[int],
    list[int],
    list[int],
    bytes,
    int,
    int,
    bytes,
]:
    asm_text = (source_root / "src" / "Z_05.asm").read_text(encoding="utf-8", errors="replace")
    primary = parse_asm_byte_table(asm_text, "PrimarySquaresOW")
    secondary = parse_asm_byte_table(asm_text, "SecondarySquaresOW")
    heap = parse_column_heaps(asm_text)
    directory = parse_column_directory(
        (source_root / "src" / "Z_06.asm").read_text(encoding="utf-8", errors="replace")
    )

    layouts = require_binary(source_root, ROOM_LAYOUTS_OW_NAME)
    level_block = require_binary(source_root, LEVEL_BLOCK_OW_NAME)
    level_info = require_binary(source_root, LEVEL_INFO_OW_NAME)

    attrs_a = level_block[0:LEVEL_BLOCK_TABLE_SIZE]
    attrs_b = level_block[LEVEL_BLOCK_TABLE_SIZE : LEVEL_BLOCK_TABLE_SIZE * 2]
    attrs_d = level_block[LEVEL_BLOCK_TABLE_SIZE * 3 : LEVEL_BLOCK_TABLE_SIZE * 4]
    attrs_f = level_block[LEVEL_BLOCK_TABLE_SIZE * 5 : LEVEL_BLOCK_TABLE_SIZE * 6]
    shortcut_positions = level_info[LEVEL_INFO_ITEM_POSITIONS : LEVEL_INFO_ITEM_POSITIONS + 4]

    palette_bytes = level_info[
        LEVEL_INFO_PALETTE_OFFSET : LEVEL_INFO_PALETTE_OFFSET + PALETTE_ROWS * PALETTE_ROW_COLORS
    ]

    metatile_ids: dict[tuple[int, tuple[int, int, int, int]], int] = {}
    metatiles: list[tuple[int, tuple[int, int, int, int]]] = []
    rooms: list[list[int]] = []
    secrets = bytearray(OW_ROOM_COUNT * OW_SECRET_BYTES)

    # The marker squares and what the ROM draws in their place (tile object types $62-$67 in order).
    marker_squares = {primary.index(0xE5 + i, 0x10): i for i in range(6)}
    tile_object_primaries = parse_asm_byte_table(asm_text, "TileObjectPrimarySquaresOW")
    marker_look = {square: overworld_square_for_primary(primary, tile_object_primaries[i])
                   for square, i in marker_squares.items()}
    marker_kind = {primary.index(marker, 0x10): kind for marker, kind in OW_SECRET_MARKER_TYPES.items()}
    stairs_square = overworld_square_for_primary(primary, OW_STAIRS_PRIMARY)

    def metatile_for(slot: int, square: int) -> int:
        key = (slot, square_to_tiles(square, primary, secondary))
        index = metatile_ids.get(key)
        if index is None:
            index = len(metatiles)
            metatile_ids[key] = index
            metatiles.append(key)
        return index

    for room_id in range(OW_ROOM_COUNT):
        # LayoutRoomOW shifts bit 6 into the high byte too, so the id is 7 bits (121 layouts).
        unique_id = attrs_d[room_id] & 0x7F
        base = unique_id * OW_COLUMNS_PER_ROOM
        descriptors = layouts[base : base + OW_COLUMNS_PER_ROOM]
        if len(descriptors) < OW_COLUMNS_PER_ROOM:
            raise SystemExit(f"RoomLayoutsOW is too short for unique room {unique_id}")

        outer = attrs_a[room_id] & 0x03
        inner = attrs_b[room_id] & 0x03

        columns = [decode_column(heap, directory[d >> 4], d & 0x0F) for d in descriptors]

        def slot_at(col: int, row: int, inner: int = inner, outer: int = outer) -> int:
            return inner if (col in OW_INNER_COL_RANGE and row in OW_INNER_ROW_RANGE) else outer

        found = [(col, row, columns[col][row]) for row in range(OW_ROOM_ROWS) for col in range(OW_ROOM_COLS)
                 if columns[col][row] in marker_squares]
        if len(found) > 1:
            raise SystemExit(f"Overworld room {room_id:#04x} hides {len(found)} secrets; the port keeps one")
        for col, row, marker in found:
            columns[col][row] = marker_look[marker]
        if found:
            col, row, marker = found[0]
            kind = marker_kind.get(marker, OW_SECRET_NONE)
            quest = attrs_f[room_id] >> 6
            if kind != OW_SECRET_NONE and quest != QUEST_SECOND_ONLY:
                record = bytearray(OW_SECRET_BYTES)
                record[0] = kind
                record[1] = row * OW_ROOM_COLS + col
                here = slot_at(col, row)
                if kind == OW_SECRET_BOMB:
                    record[2] = metatile_for(here, OW_SQUARE_CAVE)
                elif kind == OW_SECRET_TREE:
                    record[2] = metatile_for(here, stairs_square)
                else:
                    record[2] = metatile_for(here, OW_SQUARE_FLOOR)
                    shortcut = shortcut_positions[(attrs_f[room_id] >> 4) & 3]
                    stairs_col, stairs_row = shortcut >> 4, (((shortcut & 0x0F) << 4) - 0x40) >> 4
                    if not (0 <= stairs_col < OW_ROOM_COLS and 0 <= stairs_row < OW_ROOM_ROWS):
                        raise SystemExit(f"Room {room_id:#04x}: the stairs {shortcut:#04x} lie outside the room")
                    record[3] = stairs_row * OW_ROOM_COLS + stairs_col
                    record[4] = metatile_for(slot_at(stairs_col, stairs_row), stairs_square)
                    moved = marker_look[marker]
                    record[5] = metatile_for(slot_at(col, row - 1), moved) if row > 0 else 0xFF
                    record[6] = metatile_for(slot_at(col, row + 1), moved) if row < OW_ROOM_ROWS - 1 else 0xFF
                secrets[room_id * OW_SECRET_BYTES : (room_id + 1) * OW_SECRET_BYTES] = record

        if room_id == POND_ROOM:
            pond_stairs = metatile_for(slot_at(POND_STAIRS_SQUARE & 15, POND_STAIRS_SQUARE >> 4), stairs_square)
        grid: list[int] = []
        for row in range(OW_ROOM_ROWS):
            for col in range(OW_ROOM_COLS):
                slot = slot_at(col, row)
                quad = square_to_tiles(columns[col][row], primary, secondary)
                key = (slot, quad)
                index = metatile_ids.get(key)
                if index is None:
                    index = len(metatiles)
                    metatile_ids[key] = index
                    metatiles.append(key)
                grid.append(index)
        rooms.append(grid)

    # Armos squares: (the metatile, the floor under it when it wakes, the stairs of a secret one), in the palette slot it
    # stands in, for the 6502's ChangeTileObjTiles. Then the 0xff that ends the list.
    extra = bytearray([pond_stairs, POND_STAIRS_SQUARE])
    for index, (slot, quad) in list(enumerate(metatiles)):
        if sorted(quad) == list(ARMOS_TILES):
            extra.extend((index, metatile_for(slot, OW_SQUARE_FLOOR), metatile_for(slot, stairs_square)))
    extra.append(0xFF)
    if len(extra) > OW_EXTRA_BYTES:
        raise SystemExit("Too many armos squares for the extra table")
    extra.extend(bytes(OW_EXTRA_BYTES - len(extra)))
    secrets.extend(extra)

    if len(metatiles) > 256:
        raise SystemExit(f"Overworld needs {len(metatiles)} metatiles, which exceeds the 256 a byte index allows")

    highest = max(tile for _, quad in metatiles for tile in quad)
    if highest >= len(chr_tiles):
        raise SystemExit(f"Overworld references CHR tile {highest:#04x} but only {len(chr_tiles)} were loaded")

    return (
        rooms,
        metatiles,
        list(attrs_a),
        list(attrs_b),
        list(level_block[LEVEL_BLOCK_TABLE_SIZE * 2 : LEVEL_BLOCK_TABLE_SIZE * 3]),
        list(attrs_d),
        list(level_block[LEVEL_BLOCK_TABLE_SIZE * 5 : LEVEL_BLOCK_TABLE_SIZE * 6]),
        list(level_info[LEVEL_INFO_FOE_COUNTS : LEVEL_INFO_FOE_COUNTS + 4]),
        palette_bytes,
        level_info[LEVEL_INFO_START_ROOM_ID],
        level_info[LEVEL_INFO_START_Y],
        bytes(secrets),
    )


def add_cave_palette_row(palette: PaletteMap, source_root: Path) -> PaletteMap:
    """Append the cave's wall palette, squeezed onto the colours the ST palette already has."""
    asm = (source_root / "src" / "Z_06.asm").read_text(encoding="utf-8", errors="replace")
    buffer = parse_asm_byte_table(asm, "CaveBgPaletteRowsTransferBuf")
    row3 = buffer[7:11]  # the buffer is: address, length, then rows 2 and 3 of four colours

    def nearest(nes_color: int) -> int:
        wanted = nes_color_to_st(nes_color)
        def distance(entry: int) -> int:
            return sum(
                (((wanted >> shift) & 7) - ((entry >> shift) & 7)) ** 2 for shift in (8, 4, 0)
            )
        return min(range(len(palette.st_colors)), key=lambda i: distance(palette.st_colors[i]))

    entries = (palette.table[0][0],) + tuple(nearest(color) for color in row3[1:])
    return PaletteMap(st_colors=palette.st_colors, table=palette.table + (entries,))


def decode_cave(source_root: Path, metatiles: list, layout_name: str = "RoomLayoutOWCave0") -> bytes:
    """A cave room layout as metatile ids, appending any metatile it needs (Cave0 is the usual cave, Cave1 the take-any-road room)."""
    asm = (source_root / "src" / "Z_05.asm").read_text(encoding="utf-8", errors="replace")
    primary = parse_asm_byte_table(asm, "PrimarySquaresOW")
    secondary = parse_asm_byte_table(asm, "SecondarySquaresOW")
    heap = parse_column_heaps(asm)
    directory = parse_column_directory(
        (source_root / "src" / "Z_06.asm").read_text(encoding="utf-8", errors="replace")
    )
    layout = parse_asm_byte_table(asm, layout_name)
    columns = [decode_column(heap, directory[d >> 4], d & 0x0F) for d in layout]

    known = {key: index for index, key in enumerate(metatiles)}
    grid = bytearray()
    for row in range(OW_ROOM_ROWS):
        for col in range(OW_ROOM_COLS):
            tiles = square_to_tiles(columns[col][row], primary, secondary)
            # The room's attributes ($44) give every other column the overworld's palette 0 or 1; only the stairs
            # of the take-any-road room show it, everything else in a cave is the wall palette's black.
            key = ((col & 1) if tiles[0] in (0x70, 0x72) else CAVE_WALL_ROW, tiles)
            if key not in known:
                known[key] = len(metatiles)
                metatiles.append(key)
            grid.append(known[key])
    if len(metatiles) > 256:
        raise SystemExit(f"The cave pushes the metatile count to {len(metatiles)}, past a byte index")
    return bytes(grid)


def build_cave_sprites(source_root: Path, sprite_tiles, palette: PaletteMap) -> bytes:
    """The old man and the bonfire, as the original's animation tables lay them out."""
    import actors

    asm = (source_root / "src" / "Z_01.asm").read_text(encoding="utf-8", errors="replace")
    anim = parse_asm_byte_table(asm, "ObjAnimations")
    heap = parse_asm_byte_table(asm, "ObjAnimFrameHeap")
    attrs = parse_asm_byte_table(asm, "ObjAnimAttrHeap")

    def image(anim_index: int, layout: str):
        base = anim[anim_index]
        row = LINK_PALETTE_ROW + (attrs[base] & 3)
        return actors._monster_image(sprite_tiles, palette, row, heap[base], layout)

    old_man = image(OLD_MAN_TYPE + 1, "mirror")   # old men, women and shopkeepers are mirrored
    fire = image(FIRE_ANIM_INDEX, "wide")
    others = [image(person + 1, layout) for person, layout in CAVE_PEOPLE]
    return b"".join(
        actors._pack_masked(rows)
        for rows in (old_man, fire, [row[::-1] for row in fire], *others)
    )


def build_caves(source_root: Path, text_base: int) -> tuple[bytes, bytes, bytes]:
    """What each of the 20 caves (types $6A..$7D) holds and says, as the ROM's InitCave reads it.

    Returns (cave_table, text, shortcuts). The table has one record of CAVE_RECORD_BYTES per type:
      0 CaveFlags (1 pick up one, 2 pay, 4 show the wares, 8 show prices, $10 hint, $20 money game, $40 heart requirement, $80 minus signs)
      1 who stands there (0 old man, 1 old woman, 2 shopkeeper, 3 moblin)
      2-4 the three wares (CAVE_NONE = nothing)   5-7 their prices   8-9 where the speech starts in the cave text
      10-15 three more speeches: what a hint cave says for each ware (HintCaveTextSelectors0/1)
    `text` is what to append to the cave text (the offsets in the table count from `text_base`, the text's length before it);
    shortcuts are the four screens the take-any-road cave leads to.
    """
    level_block = require_binary(source_root, LEVEL_BLOCK_OW_NAME)
    attr_e = level_block[4 * OW_ROOM_COUNT : 5 * OW_ROOM_COUNT]
    asm = (source_root / "src" / "Z_01.asm").read_text(encoding="utf-8", errors="replace")
    selectors = parse_asm_byte_table(asm, "OverworldPersonTextSelectors")
    hints = (parse_asm_byte_table(asm, "HintCaveTextSelectors0"), parse_asm_byte_table(asm, "HintCaveTextSelectors1"))
    texts = require_binary(source_root, PERSON_TEXT_NAME)
    addrs = (source_root / "src" / "dat" / "PersonTextAddrs.inc").read_text(encoding="utf-8", errors="replace")
    starts = [int(m) for m in re.findall(r"PersonText\+(\d+)", addrs)]
    blob = bytearray()
    placed = {0: 0}                         # the first speech is where the text begins

    def speech(selector: int) -> int:
        selector &= 0x3F
        if selector not in placed:
            entry = selector // 2
            end = starts[entry + 1] if entry + 1 < len(starts) else len(texts)
            placed[selector] = text_base + len(blob)
            blob.extend(texts[starts[entry] : end])
        return placed[selector]

    table = bytearray()
    for index in range(CAVE_TYPES):
        kind = 0x6A + index
        items = [attr_e[index * 3 + n] for n in range(3)]
        prices = [attr_e[60 + index * 3 + n] for n in range(3)]
        flags = (items[0] & 0xC0) | ((items[1] & 0xC0) >> 2) | ((items[2] & 0xC0) >> 4)
        flags |= (selectors[index] >> 6) & 0x03           # ASL, ROL, ROL: the text selector's top two bits move to the bottom
        person = 0 if kind <= CAVE_LAST_MAN else 1 if kind <= CAVE_LAST_WOMAN else 2 if kind <= CAVE_LAST_SHOP else 3
        record = bytearray([flags, person, *(item & 0x3F for item in items), *prices])
        record += speech(selectors[index]).to_bytes(2, "big")
        if kind in (0x75, 0x76):
            chosen = hints[0] if kind == 0x75 else hints[1]
            for selector in chosen[:3]:
                record += speech(selector).to_bytes(2, "big")
        record += bytes(CAVE_RECORD_BYTES - len(record))
        table += record
    info = require_binary(source_root, LEVEL_INFO_OW_NAME)
    first = 0x6BB2 - LEVEL_INFO_BASE
    return bytes(table), bytes(blob), bytes(info[first : first + 4])


def text_glyph_map() -> bytes:
    """NES text code (0..63) -> HUD glyph, blank for anything the ribbon has no glyph for."""
    by_tile = {}
    for index, (_, tile, row) in enumerate(HUD_GLYPHS):
        if row == HUD_TEXT_ROW:
            by_tile.setdefault(tile, index)
    by_tile[CODE_PLUS] = [i for i, (name, _, _) in enumerate(HUD_GLYPHS) if name == "CH_PLUS"][0]
    return bytes(by_tile.get(code, 0) for code in range(64))


def load_assets(source_root: Path) -> AssetBundle:
    bg_tiles = load_ow_background_tiles(source_root)
    sprite_tiles = load_ow_sprite_tiles(source_root)
    if bg_tiles is not None and sprite_tiles is not None:
        rooms, metatiles, room_attrs_a, room_attrs_b, room_attrs_c, room_attrs_d, room_attrs_f, foe_counts, palette_bytes, start_room, start_y, room_secrets = decode_overworld(source_root, bg_tiles)
        import underworld
        import intro as intro_module
        import filesel as filesel_module
        import gameover as gameover_module

        # Development aid: ZELDA_START_ROOM=0x37 starts the game in another room.
        override = os.environ.get("ZELDA_START_ROOM")
        if override:
            start_room = int(override, 0)
        palette_map = build_palette_map(palette_bytes)
        cave_map = decode_cave(source_root, metatiles) + decode_cave(source_root, metatiles, "RoomLayoutOWCave1")
        palette_map = add_cave_palette_row(palette_map, source_root)
        cave_sprites = build_cave_sprites(source_root, sprite_tiles, palette_map)
        cave_text = require_binary(source_root, PERSON_TEXT_NAME)[:PERSON_TEXT_BYTES]
        uw_tiles = load_uw_background_tiles(source_root)
        levels = []
        text_base = len(cave_text)
        for number in UW_LEVELS:
            built = underworld.build_level(source_root, number, uw_tiles, palette_bytes, palette_map, sprite_tiles,
                                           text_base=text_base)
            text_base += len(built.actors.person_text)
            levels.append(built)
        uw = levels[0]
        import actors

        ow_room_info = actors.overworld_room_info(
            source_root, room_attrs_a, room_attrs_c, room_attrs_d, room_attrs_f, foe_counts
        )
        level_palettes = tuple(underworld.level_palettes(source_root, palette_bytes, palette_map))
        for built in levels:
            cave_text += built.actors.person_text   # the levels' old men speak from the same text, one after the other
        cave_table, caves_text, cave_shortcuts = build_caves(source_root, len(cave_text))
        cave_text += caves_text                 # then what the overworld's caves say
        cave_text += ENDING_TEXTS               # always the last thing in the text: the ending's two speeches
        if len(cave_text) > 0xFFFE:
            raise SystemExit("The cave and dungeon speeches no longer fit the text index")
        return AssetBundle(
            source_note="ROM-derived overworld tiles, sprites, rooms and palette",
            uw=uw,
            levels=tuple(levels),
            cave_map=cave_map,
            cave_sprites=cave_sprites,
            cave_text=cave_text,
            cave_table=cave_table,
            cave_shortcuts=cave_shortcuts,
            palette=palette_map,
            level_palettes=level_palettes,
            ow_room_info=ow_room_info,
            room_secrets=room_secrets,
            intro=intro_module.build(source_root),
            menus=filesel_module.build(source_root),
            gameover=gameover_module.build(source_root, palette_map, level_palettes, sprite_tiles),
            bg_tiles=bg_tiles,
            sprite_tiles=sprite_tiles,
            rooms=rooms,
            metatiles=metatiles,
            room_attrs_a=room_attrs_a,
            room_attrs_b=room_attrs_b,
            room_attrs_c=room_attrs_c,
            room_attrs_d=room_attrs_d,
            room_attrs_f=room_attrs_f,
            foe_counts=foe_counts,
            start_room=start_room,
            start_y=start_y,
        )

    raise SystemExit(
        f"No ROM found. Put the NES ROM at {source_root / 'ext' / 'Original.nes'} (or extract its blocks into "
        f"{source_root / 'bin'}): every picture, room, text and sound of the port is read from it, nothing is "
        "drawn separately."
    )


def pack_st_row(pixels: Iterable[int]) -> bytes:
    """Pack 16 palette indices into four big-endian bitplane words."""
    plane_words = [0, 0, 0, 0]
    for x, pixel in enumerate(pixels):
        mask = 1 << (15 - x)
        for plane in range(4):
            if pixel & (1 << plane):
                plane_words[plane] |= mask
    return b"".join(word.to_bytes(2, "big") for word in plane_words)


def pack_hud_row(pixels: Sequence[int]) -> bytes:
    """Pack 8 palette indices into one byte per bitplane.

    An 8-pixel tile is exactly one byte of an ST plane word, so the HUD can be
    drawn with plain byte stores instead of the shifting sprite blitter.
    """
    planes = [0, 0, 0, 0]
    for x, pixel in enumerate(pixels):
        mask = 1 << (7 - x)
        for plane in range(4):
            if pixel & (1 << plane):
                planes[plane] |= mask
    return bytes(planes)


def build_metatile_bytes(
    chr_tiles: list[list[list[int]]],
    palette: PaletteMap,
    palette_row: int,
    tile_indices: tuple[int, int, int, int],
) -> bytes:
    tl, tr, bl, br = (chr_tiles[index] for index in tile_indices)
    packed = bytearray()
    for row in range(METATILE_HEIGHT):
        if row < 8:
            left, right = tl[row], tr[row]
        else:
            left, right = bl[row - 8], br[row - 8]
        packed.extend(pack_st_row(palette.index(palette_row, value) for value in (left + right)))
    return bytes(packed)


def build_sprite_frame(
    chr_tiles: list[list[list[int]]],
    palette: PaletteMap,
    palette_row: int,
    first_tile: int,
    flip: bool,
) -> bytes:
    """Encode one 16x16 NES sprite pair as four bitplane words plus an opacity mask.

    The NES draws Link as two 8x16 sprites, so the frame covers tiles T, T+1 on
    the left and T+2, T+3 on the right.
    """
    top_left, bottom_left, top_right, bottom_right = (
        chr_tiles[first_tile + offset] for offset in range(4)
    )
    packed = bytearray()
    for row in range(METATILE_HEIGHT):
        if row < 8:
            pixels = top_left[row] + top_right[row]
        else:
            pixels = bottom_left[row - 8] + bottom_right[row - 8]
        if flip:
            pixels = pixels[::-1]
        packed.extend(pack_st_row(palette.index(palette_row, value) for value in pixels))
        # NES sprite pixel 0 is transparent rather than a colour.
        mask = 0
        for x, pixel in enumerate(pixels):
            if pixel:
                mask |= 1 << (15 - x)
        packed.extend(mask.to_bytes(2, "big"))
    return bytes(packed)


def render_metatiles(bundle: AssetBundle) -> bytes:
    return b"".join(
        build_metatile_bytes(bundle.bg_tiles, bundle.palette, palette_row, quad)
        for palette_row, quad in bundle.metatiles
    )


class _TunicPalette:
    """The palette with Link's first colour (pixel value 1: the green tunic) swapped for a ring's."""

    def __init__(self, palette: PaletteMap, st_index: int | None) -> None:
        self.palette = palette
        self.st_index = st_index
        self.st_colors = palette.st_colors

    def index(self, row: int, pixel: int) -> int:
        if self.st_index is not None and row == LINK_PALETTE_ROW and pixel == 1:
            return self.st_index
        return self.palette.index(row, pixel)


def link_tunic_indices(palette: PaletteMap) -> tuple[int | None, int | None, int | None]:
    """ST palette entries for the tunic with no ring, the blue ring ($32) and the red ring ($16).

    The ROM patches the tunic's colour with LinkColors_CommonCode. The blue is not among the sixteen ST colours
    (the nearest by value would be the white), so the entry nearest in hue is used: the water's blue.
    """
    red = palette.st_colors.index(nes_color_to_st(0x16))
    blue = min(
        (i for i, c in enumerate(palette.st_colors) if (c & 7) > (c >> 8) + 2 and (c & 7) >= 4),
        key=lambda i: abs((palette.st_colors[i] & 7) - 7) + abs(((palette.st_colors[i] >> 4) & 7) - 5),
    )
    return (None, blue, red)


UW_LEVELS = (1, 2, 3, 4, 5, 6, 7, 8, 9)      # the dungeons the game has so far (the Makefile's UW_LEVELS lists the same)
LINK_TUNIC_SETS = 3     # no ring, blue ring, red ring


def render_sprites(bundle: AssetBundle) -> bytes:
    return b"".join(
        build_sprite_frame(bundle.sprite_tiles, _TunicPalette(bundle.palette, tunic), LINK_PALETTE_ROW, first_tile, flip)
        for tunic in link_tunic_indices(bundle.palette)
        for _, first_tile, flip in LINK_FRAMES
    )


def render_hud_tiles(bundle: AssetBundle) -> bytes:
    packed = bytearray()
    for _, tile_index, palette_row in HUD_GLYPHS:
        tile = bundle.bg_tiles[tile_index]
        for row in range(8):
            packed.extend(
                pack_hud_row([bundle.palette.index(palette_row, value) for value in tile[row]])
            )
    return bytes(packed)


def format_words(label: str, values: Iterable[int]) -> str:
    values = list(values)
    chunks = [values[index : index + 8] for index in range(0, len(values), 8)]
    lines = [f"{label}:"]
    for chunk in chunks:
        lines.append("    .word " + ", ".join(f"0x{value:03x}" for value in chunk))
    return "\n".join(lines)


def format_bytes(label: str, values: Iterable[int]) -> str:
    values = list(values)
    chunks = [values[index : index + 20] for index in range(0, len(values), 20)]
    lines = [f"{label}:"]
    for chunk in chunks:
        lines.append("    .byte " + ", ".join(str(value) for value in chunk))
    return "\n".join(lines)


UW_DOOR_RECORD_BYTES = 4 + 4 * 12


def write_level(out_dir: Path, uw) -> None:
    """The tables of one dungeon, as uw<level>_*.bin (levels.inc links them into the image)."""
    import underworld

    prefix = f"uw{uw.level}_"
    (out_dir / f"{prefix}tiles.bin").write_bytes(uw.tile_bank)
    (out_dir / f"{prefix}tile_nes.bin").write_bytes(uw.tile_nes)
    quads, packed = underworld.pack_squares(list(uw.rooms) + list(uw.cellar_maps))
    (out_dir / f"{prefix}quads.bin").write_bytes(quads)
    (out_dir / f"{prefix}rooms.bin").write_bytes(b"".join(packed[: len(uw.rooms)]))
    (out_dir / f"{prefix}room_index.bin").write_bytes(bytes(uw.room_index))
    records = bytearray()
    for types, faces in zip(uw.door_types, uw.open_faces):
        records.extend(types)
        for face in faces:
            records.extend(face)
    (out_dir / f"{prefix}doors.bin").write_bytes(bytes(records))
    (out_dir / f"{prefix}room_info.bin").write_bytes(b"".join(uw.actors.room_info))
    (out_dir / f"{prefix}cellar_maps.bin").write_bytes(b"".join(packed[len(uw.rooms) :]))
    (out_dir / f"{prefix}cellar_info.bin").write_bytes(b"".join(uw.cellar_info))


LEVEL_TABLES = ("room_index", "rooms", "doors", "tiles", "tile_nes", "room_info", "cellar_maps", "cellar_info",
                "mon_art", "quads")
LEVEL_RECORD_BYTES = 4 * len(LEVEL_TABLES) + 8       # the table offsets, then start room, start Y, triforce room, ...


def level_include(levels) -> str:
    """levels.inc: each dungeon's tables, and level_table, the record uw_select_level copies from.

    A record is the distance of each table from table_anchor (the image is position independent, so no
    absolute addresses), then start room, start Y, triforce room, the minimap's first column and the
    number of cellars, padded to eight bytes.
    """
    lines = ["| Generated by tools/build_assets.py -- do not edit.", "    .align 2"]
    for uw in levels:
        for name in LEVEL_TABLES:
            lines.extend([f"uw{uw.level}_{name}:", f'    .incbin "uw{uw.level}_{name}.bin"', "    .align 2"])
    lines.append("level_table:")
    for uw in levels:
        for name in LEVEL_TABLES:
            lines.append(f"    .long uw{uw.level}_{name} - table_anchor")
        lines.append(
            f"    .byte 0x{uw.start_room:02x}, 0x{uw.start_y:02x}, 0x{uw.triforce_room:02x}, {uw.map_col0}, "
            f"{len(uw.cellar_info)}, 0, 0, 0"
        )
    lines.append("")
    return "\n".join(lines)


def monster_pool(levels) -> tuple[bytes, list[bytes]]:
    """One pool of monster frames for every dungeon, and for each dungeon the table of where its monsters' art starts.

    A monster is drawn from the sprite patterns and the colours of the level it is met in, so the same monster can
    have several pictures; identical art is stored once. The first dungeon's table also serves the overworld (its
    monsters are drawn from the overworld's patterns, the same in every level).
    """
    pool = bytearray()
    starts: dict[bytes, int] = {}
    tables = []
    for uw in levels:
        table = bytearray()
        for art in uw.actors.monster_arts:
            if art not in starts:
                starts[art] = len(pool) // SPRITE_FRAME_BYTES
                pool.extend(art)
            table.extend(starts[art].to_bytes(2, "big"))
        tables.append(bytes(table))
    return bytes(pool), tables


def write_underworld(out_dir: Path, bundle_or_uw) -> None:
    levels = getattr(bundle_or_uw, "levels", None) or (getattr(bundle_or_uw, "uw", bundle_or_uw),)
    uw = levels[0]
    for level in levels:
        write_level(out_dir, level)
    pool, art_tables = monster_pool(levels)
    for level, table in zip(levels, art_tables):
        (out_dir / f"uw{level.level}_mon_art.bin").write_bytes(table)
    (out_dir / "levels.inc").write_text(level_include(levels), encoding="utf-8")
    cells = bytearray()
    for direction in uw.door_cells:
        for cell in direction:
            cells.extend(cell.to_bytes(2, "big"))
    (out_dir / "uw_door_cells.bin").write_bytes(bytes(cells))
    actors = uw.actors
    (out_dir / "mon_sprites.bin").write_bytes(pool)
    (out_dir / "mon_table.bin").write_bytes(actors.mon_table)
    (out_dir / "mon_mask.bin").write_bytes(actors.mon_mask)
    (out_dir / "mon_cloud.bin").write_bytes(actors.mon_cloud)
    (out_dir / "mon_art.bin").write_bytes(art_tables[0])
    (out_dir / "mon_index.bin").write_bytes(actors.mon_index)
    (out_dir / "item_sprites.bin").write_bytes(actors.item_sprites)
    (out_dir / "item_index.bin").write_bytes(actors.item_index)
    (out_dir / "drop_table.bin").write_bytes(actors.drop_table)
    (out_dir / "drop_rates.bin").write_bytes(actors.drop_rates)
    (out_dir / "sword_sprites.bin").write_bytes(actors.sword_sprites)
    (out_dir / "beam_sprites.bin").write_bytes(actors.beam_sprites)
    (out_dir / "fx_sprites.bin").write_bytes(actors.fx_sprites)
    (out_dir / "proj_sprites.bin").write_bytes(actors.proj_sprites)
    (out_dir / "hud_items.bin").write_bytes(actors.hud_items)


def underworld_equates(uw, level_count: int = 1) -> list[str]:
    import underworld

    left, right, up, down = underworld.UW_ROOM_BOUNDS
    return [
        "| Underworld: tile rooms rebuilt from LayOutRoom; each level's own tables are in levels.inc.",
        f".equ UW_COLS, {underworld.UW_COLS}",
        f".equ UW_ROWS, {underworld.UW_ROWS}",
        f".equ UW_ROOM_BYTES, {underworld.UW_ROOM_BYTES}",
        f".equ UW_PACKED_BYTES, {underworld.UW_PACKED_BYTES}",
        f".equ UW_SQUARE_COLS, {underworld.UW_SQUARE_COLS}",
        f".equ UW_SQUARE_ROWS, {underworld.UW_SQUARE_ROWS}",
        f".equ UW_DOOR_RECORD_BYTES, {UW_DOOR_RECORD_BYTES}",
        f".equ UW_FIRST_UNWALKABLE_TILE, 0x{underworld.UW_FIRST_UNWALKABLE_TILE:02x}",
        f".equ UW_BOUND_LEFT, 0x{left:02x}",
        f".equ UW_BOUND_RIGHT, 0x{right:02x}",
        f".equ UW_BOUND_UP, 0x{up:02x}",
        f".equ UW_BOUND_DOWN, 0x{down:02x}",
        f".equ LEVEL_COUNT, {level_count}",
        f".equ LEVEL_RECORD_BYTES, {LEVEL_RECORD_BYTES}",
        f".equ MON_COUNT, {len(uw.actors.mon_table) // 8}",
        f".equ ITEM_COUNT, {len(uw.actors.item_sprites) // SPRITE_FRAME_BYTES}",
        f".equ UW_INFO_BYTES, {len(uw.actors.room_info[0])}",
        f".equ CELLAR_COUNT, {len(uw.cellar_info)}",
        f".equ CELLAR_INFO_BYTES, {underworld.CELLAR_INFO_BYTES}",
        f".equ MON_KEESE, {uw.actors.keese_index}",
        f".equ MON_BOULDER, {uw.actors.mon_index[0x20]}",
        f".equ MON_ZORA, {uw.actors.mon_index[0x11]}",
        f".equ MON_GEL, {uw.actors.mon_index[0x15]}",
        f".equ MON_RED_KEESE, {uw.actors.mon_index[0x1C]}",
        f".equ MON_VIRE, {uw.actors.mon_index[0x12]}",
        f".equ MON_ZOL, {uw.actors.mon_index[0x13]}",
        f".equ MON_POLS, {uw.actors.mon_index[0x16]}",
        f".equ MON_LIKELIKE, {uw.actors.mon_index[0x17]}",
        f".equ MON_BUBBLE, {uw.actors.mon_index[0x2B]}",
        f".equ MON_GOHMA_BLUE, {uw.actors.mon_index[0x33]}",
        f".equ MON_GOHMA_RED, {uw.actors.mon_index[0x34]}",
        f".equ MON_GOHMA_LEG_BLUE, {uw.actors.mon_index[0xFD]}",
        f".equ MON_GOHMA_LEG_RED, {uw.actors.mon_index[0xFC]}",
        f".equ MON_MANHANDLA, {uw.actors.mon_index[0x3C]}",
        f".equ MON_DIGDOGGER, {uw.actors.mon_index[0x38]}",
        f".equ MON_DIGDOGGER2, {uw.actors.mon_index[0xFB]}",
        f".equ MON_DIG_KID, {uw.actors.mon_index[0x18]}",
        f".equ MON_GLEEOK2, {uw.actors.mon_index[0x43]}",
        f".equ MON_GLEEOK3, {uw.actors.mon_index[0x44]}",
        f".equ MON_GLEEOK4, {uw.actors.mon_index[0x45]}",
        f".equ MON_GLEEOK_HEAD, {uw.actors.mon_index[0xF9]}",
        f".equ MON_GLEEOK_FLYER, {uw.actors.mon_index[0x46]}",
        f".equ MON_MOBLIN, {uw.actors.mon_index[0x03]}",
        f".equ MON_WIZ_BLUE, {uw.actors.mon_index[0x23]}",
        f".equ MON_WIZ_RED, {uw.actors.mon_index[0x24]}",
        f".equ MON_LANMOLA_RED, {uw.actors.mon_index[0x3B]}",
        f".equ MON_ZELDA, {uw.actors.mon_index[0x37]}",
        f".equ MON_ZELDA_FIRE, {uw.actors.mon_index[0x3F]}",
        f".equ MON_ARMOS, {uw.actors.mon_index[0x1E]}",
        f".equ MON_WHIRLWIND, {uw.actors.mon_index[0x2E]}",
        f".equ MON_FAIRY, {uw.actors.mon_index[0x2F]}",
        f".equ MON_GANON, {uw.actors.mon_index[0x3E]}",
        f".equ MON_PATRA_EYE, {uw.actors.mon_index[0x47]}",
        f".equ MON_PATRA_EYE2, {uw.actors.mon_index[0x48]}",
        f".equ MON_PATRA_CHILD, {uw.actors.mon_index[0x25]}",
        f".equ MON_PATRA_CHILD2, {uw.actors.mon_index[0x26]}",
        f".equ DEV_START_UW, {int(os.environ.get('ZELDA_START_UW', '0xFF'), 0)}",
        f".equ DEV_START_LEVEL, {int(os.environ.get('ZELDA_START_LEVEL', '1'), 0)}",
        f".equ DEV_START_CAVE, {int(os.environ.get('ZELDA_START_CAVE', '0'), 0)}",
        # The title and the story are for a game that is played: a build that starts somewhere on purpose skips them.
        f".equ DEV_SKIP_INTRO, {1 if any(os.environ.get(n) for n in DEV_START_VARS) else 0}",
    ]


DEV_START_VARS = ("ZELDA_START_ROOM", "ZELDA_START_UW", "ZELDA_START_CAVE", "ZELDA_SKIP_INTRO")


def dungeon_entrance(bundle: AssetBundle) -> int:
    """The overworld screen whose stairs lead into the level ZELDA_START_LEVEL (attribute B bits 2-7)."""
    level = int(os.environ.get("ZELDA_START_LEVEL", "1"), 0)
    for room, attr in enumerate(bundle.room_attrs_b):
        if (attr & 0xFC) < 0x40 and (attr & 0xFC) >> 2 == level:
            return room
    return 0x37


def level_manifest(bundle: AssetBundle) -> str:
    return "\n".join(
        f"uw{level.level}_room_count={len(level.rooms)}\nuw{level.level}_tile_count={len(level.tile_nes)}"
        for level in (bundle.levels or (bundle.uw,))
    )


def write_outputs(out_dir: Path, bundle: AssetBundle) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "metatiles.bin").write_bytes(render_metatiles(bundle))
    (out_dir / "link_sprites.bin").write_bytes(render_sprites(bundle))
    (out_dir / "ow_room_info.bin").write_bytes(bundle.ow_room_info)
    (out_dir / "room_secrets.bin").write_bytes(bundle.room_secrets)
    (out_dir / "hud_tiles.bin").write_bytes(render_hud_tiles(bundle))
    # The big tables ship as binaries rather than .byte directives: 22KB of
    # assembler text is slow to assemble, and keeping .rodata compact matters
    # because every reference to it is a PC-relative displacement limited to
    # the 68000's signed 16 bits.
    (out_dir / "metatile_tiles.bin").write_bytes(
        bytes(tile for _, quad in bundle.metatiles for tile in quad)
    )
    (out_dir / "room_maps.bin").write_bytes(
        bytes(value for room in bundle.rooms for value in room)
    )
    write_underworld(out_dir, bundle)
    import intro as intro_module

    intro_lines = intro_module.write(out_dir, bundle.intro)
    import filesel as filesel_module

    intro_lines += filesel_module.write(out_dir, bundle.menus)
    import gameover as gameover_module

    intro_lines += gameover_module.write(out_dir, bundle.gameover)
    (out_dir / "cave_map.bin").write_bytes(bundle.cave_map)
    (out_dir / "cave_sprites.bin").write_bytes(bundle.cave_sprites)
    (out_dir / "cave_text.bin").write_bytes(bundle.cave_text)
    (out_dir / "cave_table.bin").write_bytes(bundle.cave_table)
    (out_dir / "cave_shortcuts.bin").write_bytes(bundle.cave_shortcuts)
    (out_dir / "text_glyphs.bin").write_bytes(text_glyph_map())

    room_count = len(bundle.rooms)
    metatile_count = len(bundle.metatiles)
    room_bytes = OW_ROOM_COLS * OW_ROOM_ROWS

    include_parts = [
        "| Generated by tools/build_assets.py -- do not edit.",
        "",
        f".equ MAP_WIDTH, {OW_ROOM_COLS}",
        f".equ MAP_HEIGHT, {OW_ROOM_ROWS}",
        f".equ ROOM_COUNT, {room_count}",
        f".equ ROOM_BYTES, {room_bytes}",
        f".equ ROOM_GRID_WIDTH, {OW_GRID_WIDTH}",
        f".equ ROOM_GRID_HEIGHT, {OW_GRID_HEIGHT}",
        f".equ METATILE_COUNT, {metatile_count}",
        f".equ METATILE_BYTES, {METATILE_BYTES}",
        f".equ SPRITE_FRAME_COUNT, {len(LINK_FRAMES)}",
        f".equ SPRITE_FRAME_BYTES, {SPRITE_FRAME_BYTES}",
        f".equ HUD_TILE_BYTES, {HUD_TILE_BYTES}",
        f".equ HUD_TILE_COUNT, {len(HUD_GLYPHS)}",
        "",
        "| Overworld collision constants, from ObjectRoomBoundsOW and WalkableTiles.",
        f".equ FIRST_UNWALKABLE_TILE, 0x{OW_FIRST_UNWALKABLE_TILE:02x}",
        f".equ WALKABLE_TILE_COUNT, {len(OW_WALKABLE_TILES)}",
        f".equ ROOM_BOUND_LEFT, 0x{OW_ROOM_BOUNDS[0]:02x}",
        f".equ ROOM_BOUND_RIGHT, 0x{OW_ROOM_BOUNDS[1]:02x}",
        f".equ ROOM_BOUND_UP, 0x{OW_ROOM_BOUNDS[2]:02x}",
        f".equ ROOM_BOUND_DOWN, 0x{OW_ROOM_BOUNDS[3]:02x}",
        "",
        "| Zelda's direction bits, and where InitMode3_Sub8 puts Link at game start.",
        f".equ DIR_RIGHT, {DIR_RIGHT}",
        f".equ DIR_LEFT, {DIR_LEFT}",
        f".equ DIR_DOWN, {DIR_DOWN}",
        f".equ DIR_UP, {DIR_UP}",
        f".equ DIR_HORIZONTAL, {DIR_RIGHT | DIR_LEFT}",
        f".equ DIR_VERTICAL, {DIR_DOWN | DIR_UP}",
        f".equ POND_IDX, {bundle.palette.index(POND_PALETTE_ROW, 3)}",
        f".equ START_ROOM_ID, 0x{bundle.start_room:02x}",
        f".equ START_X, 0x{LINK_START_X:02x}",
        f".equ START_Y, 0x{bundle.start_y:02x}",
        f".equ START_DIR, 0x{LINK_START_DIR:02x}",
        "",
        *underworld_equates(bundle.uw, len(bundle.levels) or 1),
        f".equ ENDING_TEXT_THANKS, {len(bundle.cave_text) - len(ENDING_TEXTS)}",
        f".equ ENDING_TEXT_PEACE, {len(bundle.cave_text) - len(ENDING_TEXTS) + len(ENDING_THANKS_TEXT)}",
        f".equ ENDING_CREDIT_PAGES, {len(CREDIT_PAGES)}",
        *(f".equ ENDING_CREDIT_{n}, {len(bundle.cave_text) - sum(len(t) for t in CREDIT_TEXTS[n:])}"
          for n in range(len(CREDIT_PAGES))),
        f".equ DEV_START_ENTRANCE, 0x{dungeon_entrance(bundle):02x}",
        *intro_lines,
        "",
    ]
    for index, (name, _, _) in enumerate(HUD_GLYPHS):
        include_parts.append(f".equ HUD_{name}, {index}")
    for index, (name, _, _) in enumerate(LINK_FRAMES):
        include_parts.append(f".equ LINK_FRAME_{name.upper()}, {index}")
    include_parts.extend(
        [
            "",
            "| The tables land in .rodata; the equates above stay visible either way.",
            "    .section .rodata",
            "    .align 2",
            format_words("room_palette", bundle.palette.st_colors),
            "",
            format_words("pond_colors", [nes_color_to_st(color) for color in POND_CYCLE_COLORS]),
            "",
            "| Inside dungeon n (1..9) the ST shows level_palettes + (n-1)*32: the overworld's slots with the",
            "| few colours it lacks swapped in (underworld.palette_lookup).",
            format_words(
                "level_palettes",
                [color for row in (bundle.level_palettes or (bundle.palette.st_colors,) * 9) for color in row],
            ),
            "",
            *intro_module.intro_tables(bundle.intro),
            "",
            *filesel_module.tables(bundle.menus),
            "",
            *gameover_module.tables(bundle.gameover),
            "    .align 2",
            "",
            format_bytes("walkable_tiles", OW_WALKABLE_TILES),
            "",
            format_bytes("room_attr_a", bundle.room_attrs_a),
            "",
            format_bytes("room_attr_b", bundle.room_attrs_b),
            "",
            format_bytes("room_attr_c", bundle.room_attrs_c),
            "",
            format_bytes("room_attr_d", bundle.room_attrs_d),
            "",
            format_bytes("room_attr_f", bundle.room_attrs_f),
            "",
            format_bytes("foe_counts", bundle.foe_counts),
            "",
            format_bytes("item_slot", bundle.uw.actors.item_slot),
            "",
            format_bytes("item_desc", bundle.uw.actors.item_desc),
            "    .align 2",
            "    .section .text",
            "",
        ]
    )
    (out_dir / "assets.inc").write_text("\n".join(include_parts), encoding="utf-8")

    manifest = "\n".join(
        [
            f"source={bundle.source_note}",
            f"room_count={room_count}",
            f"room_size={OW_ROOM_COLS}x{OW_ROOM_ROWS}",
            f"room_bytes={room_bytes}",
            f"metatile_count={metatile_count}",
            f"metatile_bytes={METATILE_BYTES}",
            f"sprite_frame_count={len(LINK_FRAMES) * LINK_TUNIC_SETS}",
            f"sprite_frame_bytes={SPRITE_FRAME_BYTES}",
            f"hud_tile_count={len(HUD_GLYPHS)}",
            f"hud_tile_bytes={HUD_TILE_BYTES}",
            f"uw_levels={','.join(str(level.level) for level in (bundle.levels or (bundle.uw,)))}",
            level_manifest(bundle),
            "output_format=Atari ST low-resolution planar 16x16 metatiles",
            "",
        ]
    )
    (out_dir / "asset_manifest.txt").write_text(manifest, encoding="utf-8")


def verify_outputs(out_dir: Path) -> None:
    manifest_path = out_dir / "asset_manifest.txt"
    include_path = out_dir / "assets.inc"
    if not manifest_path.exists() or not include_path.exists():
        raise SystemExit("Missing generated asset files")

    manifest_values = {}
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        key, _, value = line.partition("=")
        manifest_values[key] = value

    required = (
        "room_count",
        "room_size",
        "room_bytes",
        "metatile_count",
        "metatile_bytes",
        "sprite_frame_count",
        "sprite_frame_bytes",
        "hud_tile_count",
        "hud_tile_bytes",
        "uw_levels",
    )
    for key in required:
        if key not in manifest_values:
            raise SystemExit(f"asset_manifest.txt is missing {key}")

    if manifest_values["output_format"] != "Atari ST low-resolution planar 16x16 metatiles":
        raise SystemExit("asset_manifest.txt has the wrong output_format")

    expected_sizes = {
        "metatiles.bin": int(manifest_values["metatile_count"]) * int(manifest_values["metatile_bytes"]),
        "link_sprites.bin": int(manifest_values["sprite_frame_count"])
        * int(manifest_values["sprite_frame_bytes"]),
        "hud_tiles.bin": int(manifest_values["hud_tile_count"]) * int(manifest_values["hud_tile_bytes"]),
        "metatile_tiles.bin": int(manifest_values["metatile_count"]) * 4,
        "room_maps.bin": int(manifest_values["room_count"]) * int(manifest_values["room_bytes"]),
        "room_secrets.bin": int(manifest_values["room_count"]) * OW_SECRET_BYTES + OW_EXTRA_BYTES,
        "cave_table.bin": CAVE_TYPES * CAVE_RECORD_BYTES,
        "cave_shortcuts.bin": 4,
        "uw_door_cells.bin": 4 * 12 * 2,
        "title_cells.bin": 25 * 32 * 2,
    }
    for level in manifest_values["uw_levels"].split(","):
        for key in (f"uw{level}_room_count", f"uw{level}_tile_count"):
            if key not in manifest_values:
                raise SystemExit(f"asset_manifest.txt is missing {key}")
        rooms = int(manifest_values[f"uw{level}_room_count"])
        tiles = int(manifest_values[f"uw{level}_tile_count"])
        expected_sizes[f"uw{level}_rooms.bin"] = rooms * 16 * 11
        expected_sizes[f"uw{level}_doors.bin"] = rooms * UW_DOOR_RECORD_BYTES
        expected_sizes[f"uw{level}_tiles.bin"] = tiles * 32
        expected_sizes[f"uw{level}_tile_nes.bin"] = tiles
        expected_sizes[f"uw{level}_room_index.bin"] = 128
    for name, expected in expected_sizes.items():
        path = out_dir / name
        if not path.exists():
            raise SystemExit(f"Missing generated asset file {name}")
        actual = len(path.read_bytes())
        if actual != expected:
            raise SystemExit(f"Unexpected {name} size: expected {expected}, got {actual}")

    if int(manifest_values["metatile_bytes"]) != METATILE_BYTES:
        raise SystemExit("asset_manifest.txt has wrong metatile_bytes")

    width, _, height = manifest_values["room_size"].partition("x")
    if int(width) * int(height) != int(manifest_values["room_bytes"]):
        raise SystemExit("asset_manifest.txt room_size and room_bytes disagree")

    include_text = include_path.read_text()
    for symbol in ("MAP_WIDTH", "METATILE_COUNT", "HUD_HEART_FULL", "room_palette:", "walkable_tiles:"):
        if symbol not in include_text:
            raise SystemExit(f"assets.inc is missing {symbol}")

    def word_count(label: str) -> int:
        block = include_text.partition(f"\n{label}:")[2]
        total = 0
        for line in block.splitlines()[1:]:
            if not line.strip().startswith(".word"):
                break
            total += len(line.partition(".word")[2].split(","))
        return total

    palette_entries = word_count("room_palette")
    if palette_entries != ST_PALETTE_SIZE:
        raise SystemExit(f"room_palette holds {palette_entries} entries, expected {ST_PALETTE_SIZE}")
    if word_count("level_palettes") != 9 * ST_PALETTE_SIZE:
        raise SystemExit("level_palettes must hold nine rows of sixteen colours")

    print(f"Verified generated assets in {out_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build Atari ST assets from the Zelda ROM")
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()

    if args.verify_only:
        verify_outputs(args.out_dir)
        return

    bundle = load_assets(args.source_root)
    write_outputs(args.out_dir, bundle)
    verify_outputs(args.out_dir)


if __name__ == "__main__":
    main()
