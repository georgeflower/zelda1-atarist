"""The credits wall: the scroll that ends the game (Z_02.asm UpdateMode13WinGame_Sub3 and DrawCredits).

After Zelda's words the ROM scrolls a tall picture upwards, half a pixel a frame: a column of brick wall (tile $FA, in the
backdrop's palette 0) from tile row 1 to tile row $2E, with the staff in it a line at a time, then "ANOTHER QUEST WILL
START FROM HERE.", "PRESS THE START BUTTON." and the copyright. DrawCredits draws one tile row every 8 pixels of scroll,
into the nametable below the one on show, and the two nametables take turns; this module runs that routine on a model of
the nametables and keeps what ends up on screen: a strip of tile rows that credits.s scrolls through the same ring of
200 lines as the story's.

    credits_rows    the distinct rows of tile cells (32 words each, a byte offset into credits_tiles)
    credits_map     which row is at each row of the strip
    credits_tiles   8x8 tiles, eight lines of four plane bytes (the HUD's layout), in the ending's colours

The strip's first 30 rows are the black room with what Zelda said last still in it (it scrolls off); the screen the
scroll ends on is black, with the ash pile and the Triforce of Power on it (two sprite frames here, drawn by credits.s).
"""
from __future__ import annotations

import re
from pathlib import Path

import actors as A
import build_assets as B
import intro as I

CELLS = 32
STRIP_ROWS = 104                      # the window's last line at the end of the scroll is row 102
FIRST_ROWS = 30                       # the page the scroll starts in (nametable 0)
DRAWN_ROWS = 76                       # DrawCredits calls made in the 600 pixels of scroll, one more than needed
SCROLL_PIXELS = 600                   # the first quest's CreditsLastScreenList / CreditsLastVscrollList: 2 * 240 + $78
WALL_TILE = 0xFA
BLANK_TILE = 0x24
WALL_LEFT = 3                         # DynTileBuf+6 is the fourth cell of the row, +31 the 29th
WALL_RIGHT = 28
FIRST_QUEST_LINES = 0x10              # lines from here on are for the Second Quest
LINES_TOTAL = 0x17
ENDING_PALETTE_ROWS = (0x0F, 0x22, 0x10, 0x00, 0x0F, 0x2A, 0x10, 0x00)       # EndingPaletteTransferBuf: $3F08..$3F0F
ENDING_SPRITE_ROW = (0x0F, 0x27, 0x06, 0x16)                                  # and $3F1C..$3F1F
ASH_X = 0x78                          # UpdateMode13WinGame_Sub4: both are drawn at ($78, $88)
ASH_Y = 0x88
TRIFORCE_ITEM = 0x0E
GANON_TYPE = 0x3E
ASHES_FRAME = 11

# What Zelda's last words leave in the black room (PeaceTextboxCharAddrsLo puts them at ($22AC), ($22E4) and ($2346) of the NES
# picture, rows 21, 23 and 26; the port types them at screen rows 16, 18 and 21, which are strip rows 19, 21 and 24: the strip's first row is on screen row -3) and which of its lines the typed text uses.
PEACE_LINES = ((19, 12, "FINALLY,"), (21, 4, "PEACE RETURNS TO HYRULE."), (24, 6, "THIS ENDS THE STORY."))


def nes_codes(text: str) -> list[int]:
    out = []
    for character in text:
        out.append(BLANK_TILE if character == " " else {",": 0x28, "!": 0x29, "'": 0x2A, ".": 0x2C, "-": 0x2F}.get(character)
                   or int(character, 36))
    return out


def palette32(source_root: Path) -> list[int]:
    """Level 9's palettes with the two the ending sends: backdrop palettes 2 and 3 and sprite palette 3."""
    info = B.require_binary(source_root, "dat/LevelInfoUW9.dat")
    palette = list(info[B.LEVEL_INFO_PALETTE_OFFSET : B.LEVEL_INFO_PALETTE_OFFSET + 32])
    palette[8:16] = ENDING_PALETTE_ROWS
    palette[28:32] = ENDING_SPRITE_ROW
    return palette


def pattern_tables(source_root: Path):
    """The ending's background tiles: the common block (letters) and the misc block (the bricks); sprites of Level 9."""
    background = B.assemble_pattern_table([
        (0x00, B.require_binary(source_root, "dat/CommonBackgroundPatterns.dat")),
        (0xF2, B.require_binary(source_root, "dat/CommonMiscPatterns.dat")),
    ])
    return background, A._sprite_table(source_root, 9)


def credit_lines(source_root: Path) -> list[tuple[int, list[int]]]:
    """(first cell, tile codes) of each of the credits' 23 text lines."""
    blob = B.require_binary(source_root, "dat/CreditsTextLines.dat")
    inc = (source_root / "src" / "dat" / "CreditsTextAddrsLo.inc").read_text()
    out = []
    for offset in (int(n) for n in re.findall(r"\+(\d+)", inc)):
        length, first = blob[offset], blob[offset + 1]
        out.append((first, list(blob[offset + 2 : offset + 2 + length])))
    if len(out) != LINES_TOTAL:
        raise SystemExit("The credits do not have 23 text lines")
    return out


def draw_credits(source_root: Path) -> list[tuple[int, list[int], int]]:
    """DrawCredits called DRAWN_ROWS times: (CreditsRow, the row's 32 tiles, the colour of its middle cells)."""
    asm2 = I._asm(source_root, "Z_02.asm")
    attrs = I.table(asm2, "CreditsAttrs")
    masks = I.table(asm2, "CreditsPagesTextMasks")
    lines = credit_lines(source_root)
    row, page, vline, line_index = 0, 0, 0, 0
    out = []
    for _ in range(DRAWN_ROWS):
        tiles = [BLANK_TILE] * CELLS
        if row == 1 or row == 0x2E:
            for column in range(WALL_LEFT, WALL_RIGHT + 1):
                tiles[column] = WALL_TILE
        elif 1 < row < 0x2E:
            tiles[WALL_LEFT] = tiles[WALL_RIGHT] = WALL_TILE
        has_text = (masks[page] << (vline + 1)) & 0x100
        if has_text and line_index < LINES_TOTAL:
            if line_index < FIRST_QUEST_LINES:
                first, codes = lines[line_index]
                tiles[first : first + len(codes)] = codes
            line_index += 1
        vline += 1
        if vline == (6 if page & 3 == 3 else 8):
            vline = 0
            page = page + 1 if page + 1 < 12 else 0
        # The attribute record is sent on every fourth row: the same colour over the six middle blocks, 0 at both ends.
        colour = attrs[row >> 2] if row % 4 == 0 else None
        out.append((row, tiles, colour))
        row += 1
        if row & 0x1F >= 0x1E:
            row += 2
    return out


def colour_of_attr(attr: int) -> int:
    """The palette a whole attribute row of AA, FF, 55 or 00 gives its middle cells; anything mixed is not in the ROM's
    credits (CreditsAttrs), so it is refused."""
    palette = attr & 3
    if attr != palette * 0x55:
        raise SystemExit(f"CreditsAttrs byte {attr:#04x} colours its quarters differently")
    return palette


def strip(source_root: Path):
    """The strip's rows of (tile, palette row) cells."""
    drawn = draw_credits(source_root)
    asm2 = I._asm(source_root, "Z_02.asm")
    attrs = I.table(asm2, "CreditsAttrs")
    rows: dict[int, list[tuple[int, int]]] = {}
    for strip_row in range(FIRST_ROWS):
        rows[strip_row] = [(BLANK_TILE, 0)] * CELLS
    for call, (credits_row, tiles, _) in enumerate(drawn):
        # One call is one nametable row, the nametables taking turns below the first page: strip row 30 + call.
        palette = colour_of_attr(attrs[credits_row >> 2]) if credits_row <= 0x2E else 0     # past the wall the rows are blank
        rows[FIRST_ROWS + call] = [(tiles[c], 0 if c < 4 or c >= 28 else palette) for c in range(CELLS)]
    for line, column, text in PEACE_LINES:
        codes = nes_codes(text)
        cells = list(rows[line])
        for n, code in enumerate(codes):
            cells[column + n] = (code, 0)
        rows[line] = cells
    return [rows.get(n, [(BLANK_TILE, 0)] * CELLS) for n in range(STRIP_ROWS)]


def sprite_frames(source_root: Path, palette: B.PaletteMap) -> tuple[list[bytes], int, int]:
    """The ash pile and the two pictures of the Triforce of Power, as 16x16 masked sprite frames:
    (frames, kind of the triforce, index of the first of its frames)."""
    bg_tiles, sp_tiles = pattern_tables(source_root)
    asm1 = I._asm(source_root, "Z_01.asm")
    anim = B.parse_asm_byte_table(asm1, "ObjAnimations")
    heap = B.parse_asm_byte_table(asm1, "ObjAnimFrameHeap")
    base = anim[GANON_TYPE + 1]
    ash = A._pack_masked(A._monster_image(sp_tiles, palette, B.LINK_PALETTE_ROW + 3, heap[base + ASHES_FRAME], "wide"))
    frames, kind = I.item_frames(I.item_tables(source_root), sp_tiles, bg_tiles, palette, TRIFORCE_ITEM)
    return [ash] + frames, kind, 1


def build(source_root: Path) -> dict:
    """The tables credits.s reads: the picture, its colours and the sprites' frames."""
    bg_tiles, _ = pattern_tables(source_root)
    palette = B.build_palette_map(palette32(source_root))
    cells = strip(source_root)
    bank = I.TileBank()
    rows, mapping = I.build_story_tables(cells, bg_tiles, palette, bank)
    frames, kind, first = sprite_frames(source_root, palette)
    return {
        "palette": list(palette.st_colors),
        "tiles": bank.blob(),
        "rows": rows,
        "map": mapping,
        "frames": frames,
        "triforce_kind": kind,
        "triforce_first": first,
        "row_count": len(cells),
    }
