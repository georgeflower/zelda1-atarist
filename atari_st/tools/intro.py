"""The title screen, the story and the parade of treasures: what game mode 0 of the ROM shows (Z_02.asm).

Everything is read from the ROM and from the disassembly's tables, the way the PPU would have drawn it: the nametable
streams the title and the story are sent as (GameTitleTransferBuf, StoryTileAttrTransferBuf), the pattern tables the
mode loads (the common and the demo blocks), the palettes the code transfers and the sprites it places. What comes out
are tables of 8x8 tiles in ST bitplane layout, which intro.s puts on the screen a line at a time.

The ST screen is 200 lines high and the NES picture 240: the window shows the NES lines 24-223 (tile rows 3-27).

The pictures are described by

    *_tiles.bin   8x8 tiles, eight lines of four plane bytes each (the HUD's layout)
    title_cells   25 rows of 32 cells, each a byte offset into title_tiles
    story_rows    the distinct rows of tile cells the scroll shows (32 words each), story_map says which row is
                  at each tile row of the scroll (a byte offset into story_rows)
    intro_sprites 16x16 frames as sprite.s draws them (four plane words and a mask per line)
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import actors as A
import build_assets as B

WINDOW_TOP_LINE = 24                  # the NES line shown on the first ST line
WINDOW_LINES = 200
WINDOW_FIRST_ROW = WINDOW_TOP_LINE // 8
WINDOW_ROWS = WINDOW_LINES // 8
CELLS = 32
TILE_BYTES = 32
FRAME_BYTES = B.SPRITE_FRAME_BYTES      # 160

# The pages: $2000 is the one the title and the story are drawn in, $2800 the one below it that the story scrolls out of.
PAGE_A = 0
PAGE_B = 1
BLANK_TILE = 0x24
STORY_FIRST_SCROLL = 0x10             # CurVScroll when the story starts, in page B
STORY_REST_SCROLL = 0x08              # where the first screen of the story stops (in page A)
STORY_SCROLL_STEPS = 1408             # ScrolledLineCount counts these before the last one (5 * 256 + $80)
STORY_LINE_AHEAD = 48                 # a line is written 48 pixels below the bottom edge of the window
PAGE_LINES = 240

FADE_STEPS = 14                       # the palettes AnimateDemoPhase0Subphase1 goes through

# What PPU memory looks like when the ROM draws a sprite of the table that bit 0 of its tile number picks.
SPRITE_PRIORITY_BEHIND = 0x20


def _asm(source_root: Path, name: str) -> str:
    return (source_root / "src" / name).read_text(encoding="utf-8", errors="replace")


def table(asm: str, label: str) -> list[int]:
    return B.parse_asm_byte_table(asm, label)


# ---------------------------------------------------------------------------------------------- the ROM's streams
def parse_stream(data: bytes) -> list[tuple[int, list[int]]] | None:
    """The records of a transfer buffer: (PPU address, bytes, vertical?). None unless the data is exactly a buffer."""
    records = []
    i = 0
    while i < len(data):
        hi = data[i]
        if hi == 0xFF:
            return records if i == len(data) - 1 else None
        if hi & 0x80 or i + 3 > len(data):
            return None
        lo, count = data[i + 1], data[i + 2]
        n = (count & 0x3F) or 64
        i += 3
        if count & 0x40:
            if i >= len(data):
                return None
            values = [data[i]] * n
            i += 1
        else:
            if i + n > len(data):
                return None
            values = list(data[i : i + n])
            i += n
        records.append(((hi << 8) | lo, values, bool(count & 0x80)))
    return None


def transfer_streams(source_root: Path) -> tuple[bytes, bytes]:
    """The story's and the title's transfer buffers.

    bins.xml puts them where the US disassembly has them; other revisions of the ROM have this part of bank 6 laid out
    differently, so what is found there is checked and, when it is not a buffer, the pair is looked for by what comes
    just before it (Mode11PlayAreaAttrsBottomHalfTransferBuf, then the story's first record).
    """
    story = B.extract_binary(source_root, "dat/StoryTileAttrTransferBuf.dat")
    title = B.extract_binary(source_root, "dat/GameTitleTransferBuf.dat")
    if story and title and parse_stream(story) is not None and parse_stream(title) is not None:
        return story, title
    rom_path = source_root / "ext" / "Original.nes"
    if not rom_path.exists():
        raise SystemExit("The title and story data need ext/Original.nes")
    rom = rom_path.read_bytes()[16:]
    anchor = bytes([0x23, 0xE8, 0x58, 0xFF, 0xFF, 0x20, 0x00, 0x20])
    start = rom.find(anchor)
    if start < 0 or rom.find(anchor, start + 1) >= 0:
        raise SystemExit("Could not find the story's transfer buffer in the ROM")
    start += 5
    story_length = len(story) if story else 1131
    title_length = len(title) if title else 1121
    story = rom[start : start + story_length]
    title = rom[start + story_length : start + story_length + title_length]
    if parse_stream(story) is None or parse_stream(title) is None:
        raise SystemExit("The title and story data in the ROM are not what the disassembly says")
    return story, title


class Ppu:
    """The two nametable pages the demo uses, with their attribute bytes (a vertical-scroll layout)."""

    def __init__(self) -> None:
        self.tiles = [[BLANK_TILE] * 960 for _ in range(2)]
        self.attrs = [[0] * 64 for _ in range(2)]

    def write(self, address: int, value: int) -> None:
        page = PAGE_A if (address & 0x0800) == 0 else PAGE_B
        offset = address & 0x3FF
        if offset < 960:
            self.tiles[page][offset] = value
        else:
            self.attrs[page][offset - 960] = value

    def apply(self, records) -> None:
        for address, values, vertical in records:
            for value in values:
                self.write(address, value)
                address += 32 if vertical else 1

    def palette_row(self, page: int, row: int, col: int) -> int:
        attr = self.attrs[page][(row // 4) * 8 + col // 4]
        return (attr >> (((row // 2) & 1) * 4 + ((col // 2) & 1) * 2)) & 3


# ------------------------------------------------------------------------------------------------ the pictures
def pattern_tables(source_root: Path):
    """Background and sprite pattern tables as the demo has them in CHR RAM (the common and the demo blocks)."""
    background = B.assemble_pattern_table([
        (0x00, B.require_binary(source_root, "dat/CommonBackgroundPatterns.dat")),
        (0x70, B.require_binary(source_root, "dat/DemoBackgroundPatterns.dat")),
        (0xF2, B.require_binary(source_root, "dat/CommonMiscPatterns.dat")),
    ])
    sprites = B.assemble_pattern_table([
        (0x00, B.require_binary(source_root, "dat/CommonSpritePatterns.dat")),
        (0x70, B.require_binary(source_root, "dat/DemoSpritePatterns.dat")),
    ])
    return background, sprites


def palette_from_record(record: list[int]) -> list[int]:
    """The 32 colours of a transfer record that sets $3F00."""
    if record[:3] != [0x3F, 0x00, 0x20]:
        raise SystemExit("Not a full palette record")
    return record[3:35]


def pack_tile(pixels: list[list[int]]) -> bytes:
    return b"".join(B.pack_hud_row(line) for line in pixels)


def cell_pixels(tiles, palette: B.PaletteMap, tile: int, row: int) -> list[list[int]]:
    return [[palette.index(row, p) for p in line] for line in tiles[tile]]


def sprite_rows(sp_tiles, bg_tiles, palette, tile: int, attr: int) -> list[list[int]]:
    """An 8x16 sprite as 16 lines of 8 palette indices, -1 where it is transparent."""
    tiles = bg_tiles if tile & 1 else sp_tiles
    top = tile & 0xFE
    row = 4 + (attr & 3)
    lines = []
    for y in range(16):
        pixels = list(tiles[top + (1 if y >= 8 else 0)][y % 8])
        lines.append([-1 if p == 0 else palette.index(row, p) for p in pixels])
    if attr & 0x80:
        lines.reverse()
    if attr & 0x40:
        lines = [list(reversed(line)) for line in lines]
    return lines


def sprite_pair(sp_tiles, bg_tiles, palette, left: tuple[int, int], right: tuple[int, int]) -> bytes:
    """Two sprites side by side (8 pixels apart) as one 16x16 masked frame."""
    a = sprite_rows(sp_tiles, bg_tiles, palette, *left)
    b = sprite_rows(sp_tiles, bg_tiles, palette, *right)
    return A._pack_masked([x + y for x, y in zip(a, b)])


class TileBank:
    """Distinct 8x8 tiles, by the byte offset they will have in the table."""

    def __init__(self) -> None:
        self.tiles: dict[bytes, int] = {}

    def add(self, pixels: list[list[int]]) -> int:
        packed = pack_tile(pixels)
        if packed not in self.tiles:
            self.tiles[packed] = len(self.tiles) * TILE_BYTES
        return self.tiles[packed]

    def blob(self) -> bytes:
        return b"".join(self.tiles)


def words(values) -> bytes:
    return b"".join(int(v).to_bytes(2, "big") for v in values)


# ------------------------------------------------------------------------------------------------------ title
@dataclass
class IntroData:
    title_palette: list[int] = field(default_factory=list)        # 16 ST colours
    glow_slot: int = 0                                            # which of them the triforce's glow changes
    glow_colours: list[int] = field(default_factory=list)         # ST colours, TriforceGlowingColors
    fade_palettes: list[list[int]] = field(default_factory=list)  # 14 x 16 ST colours
    fade_delays: list[int] = field(default_factory=list)
    story_palette: list[int] = field(default_factory=list)
    title_tiles: bytes = b""
    title_cells: bytes = b""
    story_tiles: bytes = b""
    story_rows: bytes = b""
    story_map: bytes = b""
    story_first_row: int = 0
    story_row_count: int = 0
    sprites: bytes = b""
    sprite_count: int = 0
    spawns: bytes = b""            # records of 8 bytes: strip line (word), x (word), first frame (word), kind (word)
    spawn_count: int = 0
    waves: list[int] = field(default_factory=list)                # first frame of the wave pairs
    crests: list[int] = field(default_factory=list)
    constants: dict[str, int] = field(default_factory=dict)


def title_image(ppu: Ppu, bg_tiles, sp_tiles, palette: B.PaletteMap, sprites: list[list[int]]) -> list[list[int]]:
    """The title screen with its static sprites drawn in: 240 lines of 256 palette indices."""
    image = [[0] * 256 for _ in range(240)]
    for ty in range(30):
        for tx in range(32):
            tile = ppu.tiles[PAGE_A][ty * 32 + tx]
            pixels = cell_pixels(bg_tiles, palette, tile, ppu.palette_row(PAGE_A, ty, tx))
            for y in range(8):
                image[ty * 8 + y][tx * 8 : tx * 8 + 8] = pixels[y]
    # The first sprite in OAM is in front: draw them back to front.
    for y, tile, attr, x in reversed(sprites):
        rows = sprite_rows(sp_tiles, bg_tiles, palette, tile, attr)
        for dy, line in enumerate(rows):
            line_y = y + 1 + dy
            if not 0 <= line_y < 240:
                continue
            for dx, pixel in enumerate(line):
                if pixel >= 0 and 0 <= x + dx < 256:
                    if attr & SPRITE_PRIORITY_BEHIND and image[line_y][x + dx] != palette.index(0, 0):
                        continue
                    image[line_y][x + dx] = pixel
    return image


def image_cells(image: list[list[int]], first_line: int, lines: int, bank: TileBank) -> bytes:
    out = []
    for cell_row in range(lines // 8):
        for tx in range(CELLS):
            pixels = [image[first_line + cell_row * 8 + y][tx * 8 : tx * 8 + 8] for y in range(8)]
            out.append(bank.add(pixels))
    return words(out)


def fade_palettes(palette: B.PaletteMap, steps: list[list[int]]) -> list[list[int]]:
    """Each step of the title's fade, as the 16 ST colours: the slots stay what they are, each takes the colour its
    entries have in the step."""
    slots: dict[int, int] = {}
    result = []
    for step_number, colours in enumerate(steps):
        st = [0] * B.ST_PALETTE_SIZE
        taken: dict[int, int] = {}
        for row in range(B.PALETTE_ROWS):
            for pixel in range(B.PALETTE_ROW_COLORS):
                slot = palette.index(row, pixel)
                colour = colours[0] if pixel == 0 else colours[row * 4 + pixel]
                st_colour = B.nes_color_to_st(colour)
                if slot in taken and taken[slot] != st_colour:
                    raise SystemExit(f"Fade step {step_number}: colour slot {slot} would need two colours")
                taken[slot] = st_colour
        for slot, colour in taken.items():
            st[slot] = colour
        result.append(st)
    return result


# ------------------------------------------------------------------------------------------------------ story
def _physical(k: int) -> tuple[int, int]:
    """Which nametable page and row the scroll's tile row k is: page B above the story's page A, and so on round."""
    if k < 30:
        return PAGE_B, k
    if k < 60:
        return PAGE_A, k - 30
    lap = (k - 60) // 30
    return (PAGE_B if lap % 2 == 0 else PAGE_A), (k - 60) % 30


def story_strip(ppu: Ppu, text_fields: bytes, addrs: list[int], line_attrs: list[int]):
    """The tile rows the story scroll shows, from the first screen's page to the last line the ROM writes.

    The scroll never goes backwards and the ROM writes each line well before it is in view, so the whole thing is a
    fixed picture; only the attribute bytes (a colour for each 2x2 tiles) are changed late, and a check below makes
    sure no change lands on rows that are on show.
    """
    lines = len(line_attrs)
    # Strip rows: 0-29 page B (blank), 30-59 page A (the story), then the lines from row 68 on, page B and A again.
    rows_tiles: dict[int, list[int]] = {}
    for k in range(60):
        page = PAGE_B if k < 30 else PAGE_A
        rows_tiles[k] = ppu.tiles[page][(k % 30) * 32 : (k % 30) * 32 + 32]
    for k in range(60, 68):
        rows_tiles[k] = [BLANK_TILE] * 32
    # The writes, as the ROM does them.
    vram_hi, vram_lo = 0x29, 0x00
    attr_hi, attr_lo = 0x2B, 0xE0
    text_index = 0
    events = []                    # (step, page, attr row) for each zeroing of attribute bytes
    pages = [ppu.tiles[PAGE_A][:], ppu.tiles[PAGE_B][:]]
    attrs = [ppu.attrs[PAGE_A][:], ppu.attrs[PAGE_B][:]]
    written: dict[int, list[int]] = {}
    spawn_lines = []
    for n in range(lines):
        step = 8 * (n + 1)
        flags = line_attrs[n]
        row = [BLANK_TILE] * 32
        if flags & 0x80:
            start = addrs[text_index]
            offset = text_fields[start]
            i = start + 1
            while text_fields[i] != 0xFF:
                row[offset] = text_fields[i]
                offset += 1
                i += 1
            text_index += 1
        address = (vram_hi << 8) | vram_lo
        page = PAGE_A if (address & 0x0800) == 0 else PAGE_B
        strip_row = 68 + n
        written[strip_row] = row
        pages[page][(address & 0x3FF) // 32 * 32 : (address & 0x3FF) // 32 * 32 + 32] = row
        vram_lo += 0x20
        if vram_lo > 0xFF:
            vram_lo &= 0xFF
            vram_hi += 1
        elif vram_lo == 0xC0:
            if vram_hi == 0x2B:
                vram_hi, vram_lo = 0x20, 0
            elif vram_hi == 0x23:
                vram_hi, vram_lo = 0x28, 0
        if flags & 0x40:
            apage = PAGE_A if (attr_hi & 0x08) == 0 else PAGE_B
            offset = (attr_hi << 8 | attr_lo) & 0x3FF
            first = offset - 960
            events.append((step, apage, first // 8))
            for q in range(8):
                attrs[apage][first + q] = 0
            attr_lo = (attr_lo + 8) & 0xFF
            if attr_lo == 0:
                attr_hi, attr_lo = (0x2B, 0xC0) if attr_hi == 0x23 else (0x23, 0xC0)
        if flags & 0x20:
            spawn_lines.append(n)
    # Each strip row's colours are those on show when it comes into view, the moment the window's bottom edge reaches it.
    attr_state = [ppu.attrs[PAGE_A][:], ppu.attrs[PAGE_B][:]]
    pending = list(events)
    first_row = WINDOW_FIRST_ROW + 2           # the window's top row when the story starts (scroll $10 = 16 lines)
    last_line = STORY_FIRST_SCROLL + STORY_REST_SCROLL + 224 + STORY_SCROLL_STEPS + 224
    last_row = (last_line + 7) // 8
    rows_cells: list[list[tuple[int, int]]] = []
    for k in range(first_row, last_row + 1):
        # The step at which row k's top line enters the bottom of the window.
        scroll_at_view = 8 * k - 240
        step_at_view = scroll_at_view - (PAGE_LINES + STORY_REST_SCROLL)
        while pending and pending[0][0] <= step_at_view:
            step, apage, arow = pending.pop(0)
            if any(attr_state[apage][arow * 8 + q] for q in range(8)):
                # Zeroing coloured attribute bytes: fine unless one of the rows they colour is on show.
                top = (STORY_REST_SCROLL + PAGE_LINES + step) // 8
                for shown in range(top, top + 31):
                    if _physical(shown)[0] == apage and _physical(shown)[1] // 4 == arow:
                        raise SystemExit(f"The story recolours row {shown} while it is on show")
            for q in range(8):
                attr_state[apage][arow * 8 + q] = 0
        if k in written:
            tiles = written[k]
        elif k in rows_tiles:
            tiles = rows_tiles[k]
        else:
            tiles = [BLANK_TILE] * 32
        page, prow = _physical(k)
        cells = []
        for col in range(32):
            attr = attr_state[page][(prow // 4) * 8 + col // 4]
            colour_row = (attr >> (((prow // 2) & 1) * 4 + ((col // 2) & 1) * 2)) & 3
            cells.append((tiles[col], colour_row))
        rows_cells.append(cells)
    return rows_cells, spawn_lines


def build_story_tables(rows_cells, bg_tiles, palette, bank: TileBank):
    unique: dict[bytes, int] = {}
    order: list[bytes] = []
    mapping = []
    for cells in rows_cells:
        encoded = words(bank.add(cell_pixels(bg_tiles, palette, tile, colour_row)) for tile, colour_row in cells)
        if encoded not in unique:
            unique[encoded] = len(order) * CELLS * 2
            order.append(encoded)
        mapping.append(unique[encoded])
    return b"".join(order), words(mapping)


# --------------------------------------------------------------------------------------------------- sprites
def item_tables(source_root: Path) -> dict:
    asm1 = _asm(source_root, "Z_01.asm")
    return {
        "slot": table(asm1, "ItemIdToSlot"),
        "descriptor": table(asm1, "ItemIdToDescriptor"),
        "offsets": table(asm1, "Anim_ItemFrameOffsets"),
        "tiles": table(asm1, "Anim_ItemFrameTiles"),
        "palette": table(asm1, "ItemSlotToPaletteOffsetsOrValues"),
    }


FLASHING_SLOTS = (0x16, 0x19, 0x1A, 0x1B)
VARYING_SLOTS = (0, 2, 4, 7, 0x0B)
FAIRY_ID = 0x23
FAIRY_SLOT = 0x14
KIND_STATIC = 0
KIND_FLASH = 1                  # two frames, swapped every 8 frames
KIND_FAIRY = 2                  # two frames, swapped every 4 frames


def item_frames(code: dict, sp_tiles, bg_tiles, palette, item_id: int) -> tuple[list[bytes], int]:
    """The frames of a parade item and how they animate (DrawItemBySlot and AnimateStationaryFairy)."""
    slot = code["slot"][item_id]
    if item_id == FAIRY_ID:
        first = code["offsets"][FAIRY_SLOT]
        return ([A._pack_masked(A._item_rows(sp_tiles, bg_tiles, palette, code["tiles"][first + n], 4 + 2))
                 for n in range(2)], KIND_FAIRY)
    tile = code["tiles"][code["offsets"][slot]]
    if slot in FLASHING_SLOTS:
        return ([A._pack_masked(A._item_rows(sp_tiles, bg_tiles, palette, tile, 4 + attr)) for attr in (1, 2)],
                KIND_FLASH)
    base = code["palette"][slot]
    attr = (base + (code["descriptor"][item_id] & 0x0F)) if slot in VARYING_SLOTS else base
    return [A._pack_masked(A._item_rows(sp_tiles, bg_tiles, palette, tile, 4 + (attr & 3)))], KIND_STATIC


def build(source_root: Path) -> IntroData:
    asm2 = _asm(source_root, "Z_02.asm")
    out = IntroData()
    bg_tiles, sp_tiles = pattern_tables(source_root)
    story_stream, title_stream = transfer_streams(source_root)

    # ----- the title
    title_pal32 = palette_from_record(table(asm2, "TitlePaletteTransferRecord")[:36])
    title_palette = B.build_palette_map(title_pal32)
    ppu = Ppu()
    ppu.apply(parse_stream(title_stream))
    initial = table(asm2, "InitialTitleSprites")
    static = [tuple(initial[i : i + 4]) for i in range(0, 0x70, 4)]
    image = title_image(ppu, bg_tiles, sp_tiles, title_palette, static)
    bank = TileBank()
    out.title_cells = image_cells(image, WINDOW_TOP_LINE, WINDOW_LINES, bank)
    out.title_tiles = bank.blob()
    out.title_palette = list(title_palette.st_colors)

    glow = table(asm2, "TriforceGlowingColors")
    if table(asm2, "TriforcePaletteTransferRecord")[:3] != [0x3F, 0x04, 0x04]:
        raise SystemExit("The triforce's glow is not where intro.s expects it")
    out.glow_slot = title_palette.index(1, 2)         # the glow patches DynTileBuf+5: the third colour of row 1
    out.glow_colours = [B.nes_color_to_st(c) for c in glow]
    steps_flat = table(asm2, "DemoPhase0Subphase1Palettes")
    steps = [steps_flat[i * 32 : i * 32 + 32] for i in range(FADE_STEPS)]
    out.fade_palettes = fade_palettes(title_palette, steps)
    out.fade_delays = table(asm2, "DemoPhase0Subphase1Delays")[:FADE_STEPS]

    # ----- the story
    story_pal32 = palette_from_record(table(asm2, "StoryPaletteTransferRecord")[:36])
    story_palette = B.build_palette_map(story_pal32)
    out.story_palette = list(story_palette.st_colors)
    ppu = Ppu()
    ppu.apply(parse_stream(story_stream))
    line_attrs = table(asm2, "DemoLineAttrs")
    text_fields = B.require_binary(source_root, "dat/DemoTextFields.dat")
    addrs = [int(m.group(1)) for m in re.finditer(r"\.ADDR DemoTextFields\+(\d+)",
                                                  (source_root / "src" / "dat" / "DemoLineTextAddrs.inc").read_text())]
    lines = len(line_attrs)
    rows_cells, spawn_lines = story_strip(ppu, text_fields, addrs, line_attrs)
    story_bank = TileBank()
    out.story_rows, out.story_map = build_story_tables(rows_cells, bg_tiles, story_palette, story_bank)
    out.story_tiles = story_bank.blob()
    out.story_first_row = WINDOW_FIRST_ROW + 2
    out.story_row_count = len(rows_cells)

    # ----- sprites: the waterfall, the parade
    frames: list[bytes] = []
    wave_tiles = table(asm2, "WaterfallWaveTiles")
    crest_tiles = table(asm2, "WaterfallCrestTiles")
    xs = table(asm2, "WaterfallSpriteXs")
    if xs != [xs[0], xs[0] + 8, xs[0] + 16, xs[0] + 24] or xs[0] % 16:
        raise SystemExit("The waterfall's sprites are not where intro.s expects them")
    out.constants["WATERFALL_X"] = xs[0]
    for offset in (0, 8, 0x10):
        out.waves.append(len(frames))
        for pair in range(2):
            left = (wave_tiles[2 * pair] + offset, 0)
            right = (wave_tiles[2 * pair + 1] + offset, 0)
            frames.append(sprite_pair(sp_tiles, bg_tiles, title_palette, left, right))
    for offset in (0, 8):
        out.crests.append(len(frames))
        for pair in range(2):
            frames.append(sprite_pair(sp_tiles, bg_tiles, title_palette,
                                      (crest_tiles[2 * pair] + offset, 0), (crest_tiles[2 * pair + 1] + offset, 0)))

    code = item_tables(source_root)
    left_ids = table(asm2, "DemoLeftItemIds")
    right_ids = table(asm2, "DemoRightItemIds")
    column_left = table(asm2, "DemoItemColumnX1")[0]
    column_right = table(asm2, "DemoItemColumnX2")[0]
    final_tiles = table(asm2, "DemoStoryFinalSpriteTiles")
    final_attrs = table(asm2, "DemoStoryFinalSpriteAttrs")
    item_frame_index: dict[int, tuple[int, int]] = {}

    def frames_for(item_id: int) -> tuple[int, int]:
        if item_id not in item_frame_index:
            made, kind = item_frames(code, sp_tiles, bg_tiles, story_palette, item_id)
            item_frame_index[item_id] = (len(frames), kind)
            frames.extend(made)
        return item_frame_index[item_id]

    spawns = []        # (strip line, x, first frame, kind)
    row = 0
    for n in spawn_lines:
        step = 8 * (n + 1)
        strip_line = STORY_FIRST_SCROLL + (PAGE_LINES + STORY_REST_SCROLL - STORY_FIRST_SCROLL) + step + 240
        item = left_ids[row]
        if item >= 0x30:
            index = item & 0x0F
            tiles = final_tiles[index * 6 : index * 6 + 6]
            attrs = final_attrs[index * 6 : index * 6 + 6]
            for pair in range(3):
                a, b = tiles[2 * pair], tiles[2 * pair + 1]
                if a == 0 and b == 0:
                    continue
                if a == 0 or b == 0:
                    raise SystemExit("A half-empty pair in the story's last sprites")
                spawns.append((strip_line, 0x68 + 16 * pair, len(frames), KIND_STATIC))
                frames.append(sprite_pair(sp_tiles, bg_tiles, story_palette, (a, attrs[2 * pair]),
                                          (b, attrs[2 * pair + 1])))
        else:
            first, kind = frames_for(item)
            if item == 0x1B:
                spawns.append((strip_line, 0x78, first, kind))     # the triforce, centred (twice in the ROM)
            else:
                spawns.append((strip_line, column_left, first, kind))
                first, kind = frames_for(right_ids[row])
                spawns.append((strip_line, column_right, first, kind))
        row += 1
    out.spawns = b"".join(words(s) for s in spawns)
    out.spawn_count = len(spawns)
    out.sprites = b"".join(frames)
    out.sprite_count = len(frames)
    out.constants.update({
        "STORY_LINES": lines,
        "STORY_FIRST_ROW": out.story_first_row,
        "STORY_ROW_COUNT": out.story_row_count,
        "INTRO_SPAWNS": out.spawn_count,
        "TITLE_TILE_BYTES": len(out.title_tiles),
    })
    return out


def write(out_dir: Path, data: IntroData) -> list[str]:
    """The binaries, and the lines of assets.inc that name their sizes and the small tables."""
    for name, blob in (("title_tiles", data.title_tiles), ("title_cells", data.title_cells),
                       ("story_tiles", data.story_tiles), ("story_rows", data.story_rows),
                       ("story_map", data.story_map), ("intro_sprites", data.sprites),
                       ("intro_spawns", data.spawns)):
        (out_dir / f"{name}.bin").write_bytes(blob)
    lines = ["", "| The title screen and the story (tools/intro.py)."]
    for name, value in sorted(data.constants.items()):
        lines.append(f".equ {name}, {value}")
    lines.append(f".equ WAVE_FRAME_0, {data.waves[0]}")
    lines.append(f".equ CREST_FRAME_0, {data.crests[0]}")
    lines.append(f".equ GLOW_SLOT, {data.glow_slot}")
    lines.append(f".equ FADE_STEPS, {len(data.fade_palettes)}")
    return lines


def intro_tables(data: IntroData) -> list[str]:
    """.rodata tables small enough to be words in the include."""
    return [
        B.format_words("title_palette", data.title_palette),
        "",
        B.format_words("story_palette", data.story_palette),
        "",
        B.format_words("glow_colours", data.glow_colours),
        "",
        B.format_words("fade_palettes", [c for step in data.fade_palettes for c in step]),
        "",
        B.format_bytes("fade_delays", data.fade_delays),
    ]
