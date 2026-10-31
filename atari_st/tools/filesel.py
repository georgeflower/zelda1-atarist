"""The file menu: game modes 1 (player select), E (register your name) and F (elimination mode) of the ROM (Z_02.asm).

As with the title (intro.py), everything comes out of the ROM the way the PPU would have shown it: the nametable
streams of Z_06.asm (Mode1TileTransferBuf, ModeFCharsTransferBuf) and the dynamic transfer buffers InitModeEandF_Full
fills, the menu palette (MenuPalettesTransferBuf), the pattern tables, the sprites the modes place. What comes out is
three pictures of 25 rows of 32 tile cells (the NES lines 24-223 again), one tile table they share, the glyphs the code
writes into the pictures while the menu runs (names, hearts, the death count) and the sprites.

The three pictures leave their dynamic parts blank: the names of the slots, their hearts and death counts (mode 1),
the three name fields (modes E and F). filesel.s draws those, as InitMode1_FillAndTransferSlotTiles and the name entry
do, with the glyphs of the style the picture's attribute table gives that place: 0 = palette row 0 (text), 1 = row 1
(hearts).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import actors as A
import build_assets as B
import intro as I

SCREENS = ("select", "register", "eliminate", "continue")
CELL_ROWS = I.WINDOW_ROWS            # 25
CELL_COLS = I.CELLS                  # 32
PLAYFIELD_COLS = 4                   # the 256-pixel picture is 16 bytes (4 columns of 8x8 cells) in on the 320-pixel screen
GLYPH_STYLES = 2                     # palette row 0 and 1

# Tiles the menu writes at run time: every character of the board (ModeE_CharMap), the blank, the dash of the slot line
# and the three heart tiles FormatHeartsInTextBuf picks.
HEART_FULL, HEART_HALF, HEART_EMPTY, BLANK, DASH = 0xF2, 0x65, 0x66, 0x24, 0x62
QUESTION = 0x2E                  # the "?" of the ROM's font, for the question before RETRY (filesel.s)
SPRITE_HEART_TILE = 0xF3             # Mode1CursorSpriteTriplet, ModeEandFCursorSprites: sprite 0
LINK_TILES = (0x08, 0x0A)            # Mode1_WriteLinkSprites: the left and right halves of Link
SWORD_TILE = 0x20                    # the second quest's marker beside Link
CURSOR_ATTR = 3                      # palette 7 (the heart, the sword)

# What the code puts where (Z_02.asm), in NES pixels.
SELECT_LINK_X, SELECT_LINK_Y = 0x30, 0x58      # UpdateMode1Menu_Sub0
REGISTER_LINK_X, REGISTER_LINK_Y = 0x50, 0x30  # InitModeEandF_Full submode 4
SWORD_DX, SWORD_DY = 0x0C, -3                  # Mode1_WriteLinkSprites
LINK_STEP = 0x18                               # the next slot, $18 pixels down

# Frames in file_sprites.bin
BLUE_RING = 0x32                                # the colour LinkColors gives the blue ring
GAME_BLUE = 0x22                                # the NES colour whose ST colour the game's blue-ring Link wears (the water's blue)
FRAME_LINK = 0                                 # three: the ring Link wears (none, blue, red) picks the colour of his tunic
FRAME_SWORD = 3
FRAME_HEART = 4                                # red (palette 7 as it is in modes 1 and E)
FRAME_HEART_WHITE = 5                          # mode F makes the heart white: MenuPalettesTransferBuf+32 = $30
FRAME_COUNT = 6


@dataclass
class MenuData:
    palette: list[int] = field(default_factory=list)       # 16 ST colours
    tiles: bytes = b""
    cells: bytes = b""                                      # the three pictures, one after the other
    glyphs: bytes = b""                                     # GLYPH_STYLES x 256 words: the offset in tiles of a tile number
    sprites: bytes = b""
    tables: dict[str, list[int]] = field(default_factory=dict)
    constants: dict[str, int] = field(default_factory=dict)


class _WhiteHeart:
    """The palette of the heart cursor in mode F: colour 1 of palette 7 is patched to $30, the white of row 0."""

    def __init__(self, palette: B.PaletteMap):
        self.palette = palette

    def index(self, row: int, pixel: int) -> int:
        if row == 7 and pixel == 1:
            return self.palette.index(0, 1)
        return self.palette.index(row, pixel)


def _records(*parts: list[int]) -> list:
    """The records of the transfer buffers laid one after the other (each ends with $FF)."""
    out = []
    for part in parts:
        records = I.parse_stream(bytes(part))
        if records is None:
            raise SystemExit("A menu transfer buffer of the ROM is not what the disassembly says")
        out.extend(records)
    return out


def _picture(records, bg_tiles, sp_tiles, palette, bank: I.TileBank):
    ppu = I.Ppu()
    ppu.apply(records)
    image = I.title_image(ppu, bg_tiles, sp_tiles, palette, [])
    return I.image_cells(image, I.WINDOW_TOP_LINE, I.WINDOW_LINES, bank), ppu


def build(source_root: Path) -> MenuData:
    asm2 = I._asm(source_root, "Z_02.asm")
    asm6 = I._asm(source_root, "Z_06.asm")
    out = MenuData()
    bg_tiles, sp_tiles = I.pattern_tables(source_root)

    # ----- the palette. The code patches the second colour of the first three sprite palettes with the colour of the ring
    # each slot's Link wears (LinkColors, InitMode1_Sub1); the ST palette has all three.
    record = I.table(asm6, "MenuPalettesTransferBuf")[:36]
    pal32 = I.palette_from_record(record)
    link_colours = I.table(asm2, "LinkColors")
    if len(link_colours) != 3:
        raise SystemExit("LinkColors is not three colours")
    for ring, colour in enumerate(link_colours):
        if colour == BLUE_RING:
            colour = GAME_BLUE         # as in the game (build_assets.link_tunic_indices): $32 itself is a pale lavender that looks white
        pal32[16 + 4 * ring + 1] = colour
    palette = B.build_palette_map(pal32)
    out.palette = list(palette.st_colors)

    # ----- the three pictures
    bank = I.TileBank()
    mode1 = I.table(asm6, "Mode1TileTransferBuf")
    board = I.table(asm6, "ModeFCharsTransferBuf")

    title = I.table(asm2, "ModeFTitleTransferBuf")[:29]
    title_register = list(title)
    patch = I.table(asm2, "ModeFTitlePatchRegister")
    title_register[7 : 7 + len(patch)] = patch
    template = I.table(asm2, "ModeFSaveSlotTemplateTransferBuf")[:0x34]
    template_register = list(template)
    end_patch = I.table(asm2, "ModeFSaveSlotTemplatePatchRegister")
    # the patch lands where the names stop: DynTileBuf+3+$21, the payload of the template's last record
    template_register[0x24 : 0x24 + len(end_patch)] = end_patch

    cells = []
    select_cells, select_ppu = _picture(_records(mode1), bg_tiles, sp_tiles, palette, bank)
    cells.append(select_cells)
    register_cells, register_ppu = _picture(_records(title_register, template_register, board),
                                            bg_tiles, sp_tiles, palette, bank)
    cells.append(register_cells)
    eliminate_cells, _ = _picture(_records(title, template, board), bg_tiles, sp_tiles, palette, bank)
    cells.append(eliminate_cells)
    # mode 8, the question after a death: three words on the black screen (InitMode8 clears it, then the buffer)
    asm5 = I._asm(source_root, "Z_05.asm")
    mode8 = I.table(asm6, "Mode8TextTileBuffer")
    if mode8[:4] != [0x23, 0xC0, 0x7F, 0x00] or mode8[-1] != 0xFF:
        raise SystemExit("Mode8TextTileBuffer is not what filesel.s draws any more")
    continue_cells, continue_ppu = _picture(_records(mode8), bg_tiles, sp_tiles, palette, bank)
    cells.append(continue_cells)

    # ----- the glyphs, in the style of the place they are written to: the slot line's name and death count are in
    # palette row 0 of the select picture, its hearts in row 1, and the name fields of modes E and F in row 0
    for what, ppu, col, row, style in (("name", select_ppu, 9, 11, 0), ("death count", select_ppu, 9, 12, 0),
                                       ("hearts", select_ppu, 18, 11, 1), ("second row of hearts", select_ppu, 18, 12, 1),
                                       ("name field", register_ppu, 14, 6, 0)):
        if ppu.palette_row(0, row, col) != style:
            raise SystemExit(f"The {what} of the menu is not in palette row {style} any more")
    char_map = I.table(asm2, "ModeE_CharMap")
    ids = sorted(set(char_map) | {HEART_FULL, HEART_HALF, HEART_EMPTY, BLANK, DASH, QUESTION})
    glyph_words = []
    for style in range(GLYPH_STYLES):
        offsets = [bank.add(I.cell_pixels(bg_tiles, palette, BLANK, style))] * 256
        for tile in ids:
            offsets[tile] = bank.add(I.cell_pixels(bg_tiles, palette, tile, style))
        glyph_words.extend(offsets)
    out.glyphs = I.words(glyph_words)
    out.cells = b"".join(cells)
    out.tiles = bank.blob()

    # ----- the sprites
    frames = []
    for ring in range(3):
        frames.append(A._pack_masked([a + b for a, b in zip(
            I.sprite_rows(sp_tiles, bg_tiles, palette, LINK_TILES[0], ring),
            I.sprite_rows(sp_tiles, bg_tiles, palette, LINK_TILES[1], ring))]))

    def half(palette_like, tile: int, attr: int) -> bytes:
        return A._pack_masked([line + [-1] * 8 for line in I.sprite_rows(sp_tiles, bg_tiles, palette_like, tile, attr)])

    frames.append(half(palette, SWORD_TILE, CURSOR_ATTR))
    frames.append(half(palette, SPRITE_HEART_TILE, CURSOR_ATTR))
    frames.append(half(_WhiteHeart(palette), SPRITE_HEART_TILE, CURSOR_ATTR))
    out.sprites = b"".join(frames)
    assert len(frames) == FRAME_COUNT

    # ----- small tables and where things are
    trip = I.table(asm2, "Mode1CursorSpriteTriplet")
    ef_sprites = I.table(asm2, "ModeEandFCursorSprites")
    if trip[0] != SPRITE_HEART_TILE or ef_sprites[0] != SPRITE_HEART_TILE:
        raise SystemExit("The cursor sprites are not the heart any more")
    if ef_sprites[3] != 0xF8 or ef_sprites[4] != 0x25:
        raise SystemExit("The name cursor is not the block sprite menu filesel.s draws")
    base = I.table(asm5, "Mode8BaseSpriteValues")
    if base[0] != SPRITE_HEART_TILE:
        raise SystemExit("The cursor of the continue question is not the heart any more")
    # its three words: column, row, length and up to eight tiles each, in the ST screen's grid
    words = []
    for record in _records(mode8)[1:]:
        address, values, _ = record
        col, row = (address & 0x1F) + PLAYFIELD_COLS, ((address & 0x3FF) >> 5) - I.WINDOW_FIRST_ROW
        if len(values) > 8 or continue_ppu.palette_row(0, row + I.WINDOW_FIRST_ROW, col - PLAYFIELD_COLS) != 0:
            raise SystemExit("A word of the continue question is not in palette row 0 any more")
        words += [col, row, len(values)] + list(values) + [BLANK] * (8 - len(values))
    out.tables = {
        "file_continue_ys": I.table(asm5, "Mode8SpriteYs"),
        "file_continue_words": words,
        "file_char_map": char_map,
        "file_zelda": I.table(asm2, "ZeldaString"),
        "file_select_ys": I.table(asm2, "Mode1CursorSpriteYs"),
        "file_register_ys": I.table(asm2, "ModeEandFSlotCursorYs"),
        "file_board_ys": I.table(asm2, "ModeE_CharBoardYOffsetsAndBounds"),
    }
    line_template = I.table(asm2, "Mode1SlotLineTransferBuf")
    death_template = I.table(asm2, "Mode1DeathCountsTransferBuf")
    slot_name = ((line_template[0] << 8) | line_template[1]) + 0x60          # the first slot is one step down
    heart_row2 = ((line_template[20] << 8) | line_template[21]) + 0x60
    death = (death_template[0] << 8) | death_template[1]
    name_field = (template[0] << 8) | template[1]                              # mode E: the first name field
    cursor_x = ef_sprites[2]

    def cell(address: int) -> tuple[int, int]:
        return (address & 0x1F) + PLAYFIELD_COLS, ((address & 0x3FF) >> 5) - I.WINDOW_FIRST_ROW        # on the ST screen's grid

    name_col, name_row = cell(slot_name)
    heart_col, _ = cell(slot_name + 9)
    death_col, death_row = cell(death)
    heart2_col, heart2_row = cell(heart_row2)
    field_col, field_row = cell(name_field)
    if heart2_col != heart_col or heart2_row != name_row + 1 or death_row != name_row + 1 or death_col != name_col:
        raise SystemExit("The slot line is not laid out the way filesel.s draws it")
    out.constants.update({
        "SEL_NAME_COL": name_col, "SEL_NAME_ROW": name_row, "SEL_HEART_COL": heart_col,
        "REG_NAME_COL": field_col, "REG_NAME_ROW": field_row,
        "CONT_HEART_X": base[2],
        "SEL_LINK_X": SELECT_LINK_X, "SEL_LINK_Y": SELECT_LINK_Y,
        "REG_LINK_X": REGISTER_LINK_X, "REG_LINK_Y": REGISTER_LINK_Y,
        "SEL_HEART_X": trip[2], "REG_HEART_X": cursor_x,
        "SWORD_DX": SWORD_DX, "SWORD_DY": SWORD_DY, "LINK_STEP": LINK_STEP,
        "FRAME_LINK": FRAME_LINK, "DASH_TILE": DASH, "FRAME_SWORD": FRAME_SWORD, "FRAME_HEART": FRAME_HEART, "FRAME_HEART_WHITE": FRAME_HEART_WHITE,
        "BLOCK_COLOUR": palette.index(7, 1),
        "GLYPH_STYLE_BYTES": 256 * 2,
        "HEART_FULL": HEART_FULL, "HEART_HALF": HEART_HALF, "HEART_EMPTY": HEART_EMPTY, "BLANK_TILE": BLANK,
    })
    return out


def write(out_dir: Path, data: MenuData) -> list[str]:
    for name, blob in (("file_tiles", data.tiles), ("file_cells", data.cells), ("file_glyphs", data.glyphs),
                       ("file_sprites", data.sprites)):
        (out_dir / f"{name}.bin").write_bytes(blob)
    lines = ["", "| The file menu (tools/filesel.py)."]
    for name, value in sorted(data.constants.items()):
        lines.append(f".equ FILE_{name}, {value}")
    lines.append(f".equ FILE_PICTURE_BYTES, {CELL_ROWS * CELL_COLS * 2}")
    return lines


def tables(data: MenuData) -> list[str]:
    lines = [B.format_words("file_palette", data.palette)]
    for name, values in data.tables.items():
        lines += ["", B.format_bytes(name, values)]
    lines.append("    .align 2")
    return lines
