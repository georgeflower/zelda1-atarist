"""The inventory screen (the ROM's submenu: Z_05.asm UpdateMenu*, DrawSubmenuItems, UpdateSubmenuSelection).

The NES draws it into the second nametable ($2800) with transfer buffers while it scrolls the screen down, so that in the
end the inventory fills the 22 tile rows of the play area and the status bar sits below it. This module replays those
transfer buffers on a PPU model (as intro.py and filesel.py do) and lays out what the code puts on top of them.

What comes out, for the overworld and for a dungeon:
  * a picture of 22 rows of 32 cells (the nametable rows 8 to 29), baked into 8x8 tiles of the ST's colours;
  * the glyphs the 68000 code writes into the picture while it runs: the triforce tiles (overworld) and the room marks of
    the dungeon's sheet map;
  * the sprites: the item pictures, the cursor (in the two palette rows it flashes between) and the dot that marks the
    room Link is in;
  * the places things go (SubmenuItemXs and the rows of DrawSubmenuItems), and per dungeon the rotation and the mask of
    the sheet map (LevelInfo_SubmenuMapRotation, LevelInfo_SubmenuMapMask).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import actors as A
import build_assets as B
import intro as I

PICTURE_ROWS = 22                    # nametable rows 8 to 29
FIRST_ROW = 8
CELL_COLS = 32
BLANK = 0x24

# What the screen shows, as the ROM writes it: the order is that of the states of UpdateMenu*.
COMMON_BUFFERS = ("InventoryTextTransferBuf", "SubmenuBoxesTopsTransferBuf", "SubmenuBoxesSidesTransferBuf",
                  "SelectedItemBoxBottomTransferBuf", "UseBButtonTextTransferBuf", "InventoryBoxBottomTransferBuf")
UW_BUFFERS = COMMON_BUFFERS + ("SubmenuMapRemainderTransferBuf", "SubmenuAttrs1TransferBuf", "SubmenuAttrs2TransferBuf",
                               "BlankBottomRowNT2TransferBuf", "SheetMapBottomEdgeTransferBuf")
TRIFORCE_ROWS = ("TriforceRow0TransferBuf", "TriforceRow1TransferBuf", "TriforceRow2TransferBuf", "TriforceRow3TransferBuf")
OW_BUFFERS = COMMON_BUFFERS + ("SubmenuAttrs1TransferBuf", "SubmenuAttrs2TransferBuf", "BlankBottomRowNT2TransferBuf",
                               "SubmenuTriforceApexTransferBuf") + TRIFORCE_ROWS + (
                               "SubmenuTriforceBottomTransferBuf", "TriforceTextTransferBuf")
SLOT_COUNT = 0x12                    # DrawSubmenuItems looks at the item slots 1 to $11

# Where the sprites go. A sprite's top line is one below its y, and the picture starts at the nametable line 64, which is
# the NES line -1: a sprite at y is y + 2 lines down in the picture. The picture is 32 pixels in from the screen's left edge.
SPRITE_DY = 2
B_BOX_X, B_BOX_Y = 0x40, 0x36
BOOMERANG_X, BOOMERANG_Y = 0x80, 0x36
CURSOR_TILE = 0x1E
DOT_TILE = 0x3E
MARKER_X, MARKER_Y = 0x62, 0x69      # UpdateMenuScrollDownUW: the dot of the room Link is in

# Frames in menu_sprites (16 x 16, masked): the picture of an item id, as it stands in the inventory
FRAMES = (
    ("boomerang", 0x1D), ("magic boomerang", 0x1E), ("bomb", 0x00),
    ("arrow", 0x08), ("silver arrow", 0x09), ("bow", 0x0A),
    ("blue candle", 0x06), ("red candle", 0x07), ("recorder", 0x05), ("food", 0x04),
    ("blue potion", 0x1F), ("red potion", 0x20), ("rod", 0x10),
    ("raft", 0x0C), ("book", 0x11), ("blue ring", 0x12), ("red ring", 0x13), ("ladder", 0x0D),
    ("magic key", 0x0B), ("bracelet", 0x14), ("letter", 0x15), ("compass", 0x16), ("map", 0x17),
)
FRAME_BOOMERANG, FRAME_MAGIC_BOOMERANG = 0, 1
FRAME_CURSOR_A = len(FRAMES)         # the cursor in sprite palette row 5, then row 6
FRAME_CURSOR_B = len(FRAMES) + 1
FRAME_DOT = len(FRAMES) + 2
FRAME_COUNT = len(FRAMES) + 3

# slot -> the frame for the values 1, 2 and the rest (Items[slot])
SLOT_FRAMES = {
    1: ("bomb",) * 3, 2: ("arrow", "silver arrow", "arrow"), 3: ("bow",) * 3,
    4: ("blue candle", "red candle", "blue candle"), 5: ("recorder",) * 3, 6: ("food",) * 3,
    7: ("blue potion", "red potion", "blue potion"), 8: ("rod",) * 3,
    9: ("raft",) * 3, 10: ("book",) * 3, 11: ("blue ring", "red ring", "blue ring"), 12: ("ladder",) * 3,
    13: ("magic key",) * 3, 14: ("bracelet",) * 3, 15: ("letter",) * 3, 16: ("compass",) * 3, 17: ("map",) * 3,
}


@dataclass
class SubmenuData:
    tiles: bytes = b""
    cells: bytes = b""                                      # the overworld's picture, then the dungeon's
    glyphs: bytes = b""                                     # 256 words for each of the two: the offset in tiles of a tile number
    sprites: bytes = b""
    tables: dict[str, list[int]] = field(default_factory=dict)
    constants: dict[str, int] = field(default_factory=dict)


def _ppu(streams) -> I.Ppu:
    """The nametables after the transfer buffers (lists of bytes) have been written, one after the other."""
    ppu = I.Ppu()
    for data in streams:
        data = list(data)
        if data[-1] != 0xFF:                      # TriforceTextTransferBuf: the $FF is in the next segment of the listing
            data.append(0xFF)
        records = I.parse_stream(bytes(data))
        if records is None:
            raise SystemExit("A submenu transfer buffer is not what the disassembly says")
        ppu.apply(records)
    return ppu


def _picture(ppu: I.Ppu, tiles, palette: B.PaletteMap, bank: I.TileBank) -> list[int]:
    cells = []
    for row in range(FIRST_ROW, FIRST_ROW + PICTURE_ROWS):
        for col in range(CELL_COLS):
            style = ppu.palette_row(1, row, col)
            if style > 1:
                raise SystemExit("The inventory uses a background palette row the status bar does not have")
            cells.append(bank.add(I.cell_pixels(tiles, palette, ppu.tiles[1][row * 32 + col], style)))
    return cells


def _item_frame(code, sp_tiles, bg_tiles, palette, item_id: int) -> bytes:
    """What Anim_WriteSpecificItemSprites makes of the item, in the palette row DrawItemInInventory picks."""
    slot = code["slot"][item_id]
    tile = code["tiles"][code["offsets"][slot]]
    base = code["palette"][slot]
    attr = (base + (code["descriptor"][item_id] & 0x0F)) if slot in (0, 2, 4, 7, 0x0B) else base
    rows = A._item_rows(sp_tiles, bg_tiles, palette, tile, 4 + (attr & 3))
    if 0x62 <= tile < 0x6C:
        # slim items: the second sprite starts at x + 7, the first one is in front
        merged_rows = []
        for line in rows:
            left, right = line[:8], line[8:]
            merged = [-1] * 16
            for x in range(8):
                merged[7 + x] = right[x]
            for x in range(8):
                if left[x] >= 0:
                    merged[x] = left[x]
            merged_rows.append(merged)
        rows = merged_rows
    return A._pack_masked(rows)


def build(source_root: Path, palette: B.PaletteMap, ow_bg, uw_bg, sp_tiles) -> SubmenuData:
    asm1 = I._asm(source_root, "Z_01.asm")
    asm5 = I._asm(source_root, "Z_05.asm")
    asm6 = I._asm(source_root, "Z_06.asm")
    out = SubmenuData()
    bank = I.TileBank()

    # ----- the triforce with every piece missing (UpdateMenuStartOW starts from this): the four row buffers are one
    # block of memory and TriforceTransferBufOffsets indexes it from TriforceRow0TransferBuf + 4
    offsets = I.table(asm5, "TriforceTransferBufOffsets")
    empty = I.table(asm5, "TriforceTransferBufTiles")
    replace = I.table(asm5, "TriforceTriforceBufReplacements")
    if not (len(offsets) == len(empty) == len(replace) == 24):
        raise SystemExit("The triforce tables are not 24 long any more")
    row_data = [list(I.table(asm6, label)) for label in TRIFORCE_ROWS]
    memory = [b for row in row_data for b in row]
    starts = [sum(len(r) for r in row_data[:i]) for i in range(4)]
    is_data = [False] * len(memory)
    for start, row in zip(starts, row_data):
        for i in range(3, len(row) - 1):
            is_data[start + i] = True
    for y in range(24):
        at = offsets[y] + 4
        if not is_data[at]:
            raise SystemExit("The triforce tables point outside the tiles of the row buffers")
        memory[at] = empty[y]
    empty_rows = {label: memory[s : s + len(r)] for label, s, r in zip(TRIFORCE_ROWS, starts, row_data)}

    # ----- the two pictures
    ow_streams = [empty_rows[label] if label in empty_rows else I.table(asm6, label) for label in OW_BUFFERS]
    uw_streams = [I.table(asm6, label) for label in UW_BUFFERS]
    ow_ppu, uw_ppu = _ppu(ow_streams), _ppu(uw_streams)
    ow_cells = _picture(ow_ppu, ow_bg, palette, bank)
    uw_cells = _picture(uw_ppu, uw_bg, palette, bank)
    out.cells = I.words(ow_cells + uw_cells)

    # ----- the glyphs written at run time, in palette row 1 (the picture's map and triforce are in the second row of the status bar)
    for ppu, label in ((ow_ppu, "triforce"), (uw_ppu, "sheet map")):
        if any(ppu.palette_row(1, row, col) != 1 for row in (24, 28) for col in (12, 20)):
            raise SystemExit(f"The {label} is not in palette row 1 any more")
    ow_glyphs = [bank.add(I.cell_pixels(ow_bg, palette, BLANK, 1))] * 256
    for tile in sorted({*empty, *replace, 0xF5, BLANK}):
        ow_glyphs[tile] = bank.add(I.cell_pixels(ow_bg, palette, tile, 1))
    uw_glyphs = [bank.add(I.cell_pixels(uw_bg, palette, BLANK, 1))] * 256
    for tile in list(range(0xE2, 0xF2)) + [0xF5, BLANK]:
        uw_glyphs[tile] = bank.add(I.cell_pixels(uw_bg, palette, tile, 1))
    out.glyphs = I.words(ow_glyphs + uw_glyphs)
    out.tiles = bank.blob()

    # ----- the triforce's rows: column, row, length, and where in the memory the tiles start
    row_info = []
    for label, start in zip(TRIFORCE_ROWS, starts):
        (address, values, vertical), = I.parse_stream(bytes(I.table(asm6, label)))
        if vertical:
            raise SystemExit("A triforce row is vertical")
        row_info += [address & 0x1F, ((address & 0x3FF) >> 5) - FIRST_ROW, len(values), start + 3]

    # ----- the sprites
    code = {
        "slot": B.parse_asm_byte_table(asm1, "ItemIdToSlot"),
        "descriptor": B.parse_asm_byte_table(asm1, "ItemIdToDescriptor"),
        "offsets": B.parse_asm_byte_table(asm1, "Anim_ItemFrameOffsets"),
        "tiles": B.parse_asm_byte_table(asm1, "Anim_ItemFrameTiles"),
        "palette": B.parse_asm_byte_table(asm1, "ItemSlotToPaletteOffsetsOrValues"),
    }
    frames = [_item_frame(code, sp_tiles, ow_bg, palette, item) for _, item in FRAMES]
    for attr in (1, 2):                                       # palette rows 5 and 6; the right half is the left, flipped
        left = I.sprite_rows(sp_tiles, ow_bg, palette, CURSOR_TILE, attr)
        right = I.sprite_rows(sp_tiles, ow_bg, palette, CURSOR_TILE, attr | 0x40)
        frames.append(A._pack_masked([a + b for a, b in zip(left, right)]))
    dot = I.sprite_rows(sp_tiles, ow_bg, palette, DOT_TILE, 0)
    frames.append(A._pack_masked([line + [-1] * 8 for line in dot]))
    if len(frames) != FRAME_COUNT:
        raise SystemExit("The inventory frames do not add up")
    out.sprites = b"".join(frames)

    # ----- where things are
    xs = I.table(asm5, "SubmenuItemXs")
    cursor_xs = I.table(asm5, "SubmenuCursorXs")
    names = [name for name, _ in FRAMES]
    slot_x, slot_y, slot_frames = [], [], []
    for slot in range(SLOT_COUNT):
        x = xs[slot] if slot < len(xs) else 0
        if slot < 5:
            y = 0x36
        elif slot == 0x0F or slot < 9:
            y = 0x46
        elif slot < 0x10:
            y = 0x1E
        else:
            x = 0x2C
            y = 0x9E if slot == 0x10 else 0x76
        slot_x.append(x)
        slot_y.append(y)
        if slot in SLOT_FRAMES:
            slot_frames.extend(names.index(n) for n in SLOT_FRAMES[slot])
        else:
            slot_frames.extend([255] * 3)

    # ----- the dungeons' sheet map: the rotation and the mask of each level, and where it sits in the picture
    variables = (source_root / "src" / "Variables.inc").read_text(encoding="utf-8", errors="replace")

    def address(label: str) -> int:
        for line in variables.splitlines():
            if line.startswith(label + " :="):
                return int(line.split("$")[1].split()[0], 16)
        raise SystemExit(f"{label} is not in Variables.inc")

    rotation_at = address("LevelInfo_SubmenuMapRotation") - B.LEVEL_INFO_BASE
    mask_at = address("LevelInfo_SubmenuMapMask") - B.LEVEL_INFO_BASE
    rotations, masks = [], []
    for level in range(1, 10):
        info = B.require_binary(source_root, f"dat/LevelInfoUW{level}.dat")
        rotations.append(info[rotation_at])
        masks.extend(info[mask_at : mask_at + 16])
    (edge_address, edge_values, _), = I.parse_stream(bytes(I.table(asm6, "SheetMapBottomEdgeTransferBuf")))
    if len(edge_values) != 16:
        raise SystemExit("The sheet map is not 16 tiles wide any more")
    map_col = edge_address & 0x1F
    map_first_row = ((edge_address & 0x3FF) >> 5) - FIRST_ROW - 8          # eight rows above the bottom edge

    out.tables = {
        "menu_slot_x": slot_x,
        "menu_slot_y": slot_y,
        "menu_slot_frames": slot_frames,
        "menu_cursor_x": cursor_xs,
        "menu_tri_offsets": offsets,
        "menu_tri_empty": empty,
        "menu_tri_replace": replace,
        "menu_tri_memory": memory,
        "menu_tri_rows": row_info,
        "menu_map_rotation": rotations,
        "menu_map_mask": masks,
    }
    out.constants.update({
        "PICTURE_BYTES": PICTURE_ROWS * CELL_COLS * 2,
        "GLYPH_BYTES": 256 * 2,
        "TRIFORCE_MEMORY": len(memory),
        "MAP_COL": map_col,
        "MAP_ROW": map_first_row,
        "MARKER_X": MARKER_X,
        "MARKER_Y": MARKER_Y,
        "SPRITE_DY": SPRITE_DY,
        "B_BOX_X": B_BOX_X, "B_BOX_Y": B_BOX_Y,
        "BOOMERANG_X": BOOMERANG_X, "BOOMERANG_Y": BOOMERANG_Y,
        "FRAME_BOOMERANG": FRAME_BOOMERANG, "FRAME_MAGIC_BOOMERANG": FRAME_MAGIC_BOOMERANG,
        "FRAME_CURSOR_A": FRAME_CURSOR_A, "FRAME_CURSOR_B": FRAME_CURSOR_B, "FRAME_DOT": FRAME_DOT,
        "BLANK_TILE": BLANK,
    })
    return out


def write(out_dir: Path, data: SubmenuData) -> list[str]:
    for name, blob in (("menu_tiles", data.tiles), ("menu_cells", data.cells), ("menu_glyphs", data.glyphs),
                       ("menu_sprites", data.sprites)):
        (out_dir / f"{name}.bin").write_bytes(blob)
    lines = ["", "| The inventory screen (tools/submenu.py)."]
    for name, value in sorted(data.constants.items()):
        lines.append(f".equ SUBMENU_{name}, {value}")
    return lines


def tables(data: SubmenuData) -> list[str]:
    lines = []
    for name, values in data.tables.items():
        lines += ["", B.format_bytes(name, values)]
    lines.append("    .align 2")
    return lines
