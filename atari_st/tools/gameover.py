"""Link's death (game mode $11 of the ROM, Z_05.asm UpdateMode11Death_Full) and the colours it needs.

The ROM redraws the screen with every tile in palette row 3 (the attribute bytes of Mode11PlayAreaAttrs*TransferBuf are
$FF), sets that row to the red ramp of Mode11BackgroundPaletteBottomHalfTransferBuf and then fades it through the four
steps of the level's DeathPaletteSeries; Link turns grey (Mode11DeadLinkPalette) and disappears in a spark. The ST has
one shared palette, so the 68000 code does it the other way round: it takes the picture's pixels to three spare slots
(death_maps says which slot each colour of the shown palette goes to: by how light the colour is, the way the three
colours of a NES row run from dark to light) and then changes the colours of those slots.

The three slots are DEATH_SLOT + 1 .. + 3 (13 to 15): in no level does the HUD, Link or an item use them. Everything
that is drawn in them while Link dies (the grey Link, the spark) is baked here with its pixels already in those slots.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import actors as A
import build_assets as B
import intro as I

DEATH_SLOT = 12                  # the slots 13, 14 and 15 are the three colours of palette row 3 while Link dies
DEAD_LINK_FIRST_TILE = 0x08      # Link facing down
SPARK_TILES = (0x62, 0x64)       # the little and the big spark (UpdateMode11Death_SubA)
SPARK_ATTR = 1                   # sprite palette 1 for the left half; the right half is the same, flipped (attribute $41)
TEXT_ROW_NES = 18                # the "GAME OVER" of GameOverTransferBuf is written at $224C: row 18, column 12
TEXT_COL_NES = 12
SERIES_ROW3 = 4                  # in each step's 8 colours of rows 2 and 3, row 3 starts here


@dataclass
class GameOverData:
    sprites: bytes = b""
    colours: list[int] = field(default_factory=list)       # ST colours, see COLOURS below
    maps: bytes = b""                                       # for the overworld and each level: slot -> slot
    text: list[int] = field(default_factory=list)           # the tiles of "GAME OVER"
    constants: dict[str, int] = field(default_factory=dict)


# death_colours holds, in this order, three colours each: where the red world starts (Mode11BackgroundPalette...),
# its four fading steps (DeathPaletteSeries), the dead Link (Mode11DeadLinkPalette) and the spark.
COLOURS_START, COLOURS_STEPS, COLOURS_LINK, COLOURS_SPARK = 0, 1, 5, 6


class _Slots:
    """A palette in which pixel n of any row is slot DEATH_SLOT + n."""

    def index(self, row: int, pixel: int) -> int:
        return DEATH_SLOT + pixel if pixel else 0


def _lightness(colour: int) -> int:
    red, green, blue = (colour >> 8) & 7, (colour >> 4) & 7, colour & 7
    return 3 * red + 6 * green + blue


def death_map(colours: list[int] | tuple[int, ...]) -> list[int]:
    """Where each of a palette's colours goes: black stays, the rest are shared out by lightness among the
    three colours of the red world (the darkest third to the first, the lightest to the last)."""
    order = sorted(range(1, 16), key=lambda slot: (_lightness(colours[slot]), slot))
    third = (len(order) + 2) // 3
    out = [0] * 16
    for rank, slot in enumerate(order):
        out[slot] = DEATH_SLOT + 1 + min(rank // third, 2)
    return out


def build(source_root: Path, palette: B.PaletteMap, level_palettes, sprite_tiles) -> GameOverData:
    asm6 = I._asm(source_root, "Z_06.asm")
    out = GameOverData()

    # ----- the colours
    start = I.table(asm6, "Mode11BackgroundPaletteBottomHalfTransferBuf")[:12]
    if start[:3] != [0x3F, 0x08, 0x08] or start[3:7] != start[7:11]:
        raise SystemExit("Mode11BackgroundPaletteBottomHalfTransferBuf is not two equal rows any more")
    world = start[8:11]
    series = None
    for name in ["LevelInfoOW"] + [f"LevelInfoUW{n}" for n in range(1, 10)]:
        info = B.require_binary(source_root, f"dat/{name}.dat")
        found = bytes(info[0xDC:0xDC + 32])        # LevelInfo_DeathPaletteSeries - LevelInfo_PalettesTransferBuf
        if series is None:
            series = found
        elif found != series:
            raise SystemExit("The levels do not share one death palette series any more")
    steps = [list(series[8 * step + SERIES_ROW3 + 1: 8 * step + SERIES_ROW3 + 4]) for step in range(4)]
    dead = I.table(asm6, "Mode11DeadLinkPalette")[:8]
    if dead[:3] != [0x3F, 0x10, 0x04]:
        raise SystemExit("Mode11DeadLinkPalette is not a sprite palette 0 record any more")
    spark = [palette.st_colors[palette.table[4 + SPARK_ATTR][pixel]] for pixel in (1, 2, 3)]
    out.colours = [B.nes_color_to_st(c) for c in world]
    for step in steps:
        out.colours += [B.nes_color_to_st(c) for c in step]
    out.colours += [B.nes_color_to_st(c) for c in dead[4:7]]
    out.colours += spark
    assert len(out.colours) == 7 * 3

    # ----- Link grey, and the spark that takes him
    slots = _Slots()
    frames = [B.build_sprite_frame(sprite_tiles, slots, B.LINK_PALETTE_ROW, DEAD_LINK_FIRST_TILE, False)]
    for tile in SPARK_TILES:
        rows = [a + b for a, b in zip(I.sprite_rows(sprite_tiles, sprite_tiles, slots, tile, SPARK_ATTR),
                                      I.sprite_rows(sprite_tiles, sprite_tiles, slots, tile, SPARK_ATTR | 0x40))]
        frames.append(A._pack_masked(rows))
    out.sprites = b"".join(frames)

    # ----- each palette's map
    shown = [palette.st_colors] + [list(row) for row in (level_palettes or (palette.st_colors,) * 9)]
    out.maps = bytes(slot for colours in shown for slot in death_map(colours))

    # ----- GAME OVER
    text = I.table(asm6, "GameOverTransferBuf")
    if text[3:6] != [0x0F, 0x0F, 0xCF] or (text[6], text[7]) != (0x22, 0x4C):
        raise SystemExit("GameOverTransferBuf is not laid out the way death.s draws it")
    out.text = text[9:9 + text[8]]
    if text[8] != 10:
        raise SystemExit("GameOverTransferBuf's text is not ten tiles any more")
    out.constants = {
        "SLOT": DEATH_SLOT,
        "FRAME_LINK": 0, "FRAME_SPARK_SMALL": 1, "FRAME_SPARK_BIG": 2,
        # where the text is on the ST screen: the playfield starts at NES line 64 and ST line 24, column 0 at byte 16
        "TEXT_COL": TEXT_COL_NES + 4, "TEXT_ROW": TEXT_ROW_NES - 8 + 3,
        "TEXT_LEN": len(out.text),
        "COLOURS_STEPS": COLOURS_STEPS, "COLOURS_LINK": COLOURS_LINK, "COLOURS_SPARK": COLOURS_SPARK,
    }
    return out


def write(out_dir: Path, data: GameOverData) -> list[str]:
    (out_dir / "death_sprites.bin").write_bytes(data.sprites)
    (out_dir / "death_maps.bin").write_bytes(data.maps)
    lines = ["", "| Link's death (tools/gameover.py)."]
    for name, value in sorted(data.constants.items()):
        lines.append(f".equ DEATH_{name}, {value}")
    return lines


def tables(data: GameOverData) -> list[str]:
    return [B.format_words("death_colours", data.colours), "", B.format_bytes("death_text", data.text), "    .align 2"]
