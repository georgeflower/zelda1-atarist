from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import filesel  # noqa: E402


ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()
_DATA = None


def rom_menus():
    global _DATA
    if _DATA is None:
        _DATA = filesel.build(ROM_ROOT)
    return _DATA


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class PictureTests(unittest.TestCase):
    def test_three_pictures_of_whole_tiles(self) -> None:
        data = rom_menus()
        picture = filesel.CELL_ROWS * filesel.CELL_COLS * 2
        self.assertEqual(len(data.cells), 3 * picture)
        offsets = struct.unpack(f">{len(data.cells) // 2}H", data.cells)
        tile_bytes = filesel.I.TILE_BYTES
        self.assertTrue(all(o % tile_bytes == 0 and o < len(data.tiles) for o in offsets))

    def test_the_pictures_differ(self) -> None:
        data = rom_menus()
        picture = filesel.CELL_ROWS * filesel.CELL_COLS * 2
        parts = [data.cells[i * picture:(i + 1) * picture] for i in range(3)]
        self.assertEqual(len(set(parts)), 3)

    def test_the_palette_has_room_for_every_colour(self) -> None:
        data = rom_menus()
        self.assertEqual(len(data.palette), 16)
        self.assertLess(data.constants["BLOCK_COLOUR"], 16)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class GlyphTests(unittest.TestCase):
    def test_every_character_of_the_board_has_a_glyph_in_both_styles(self) -> None:
        data = rom_menus()
        words = struct.unpack(f">{len(data.glyphs) // 2}H", data.glyphs)
        self.assertEqual(len(words), filesel.GLYPH_STYLES * 256)
        blank = [words[style * 256 + filesel.BLANK] for style in range(filesel.GLYPH_STYLES)]
        for tile in data.tables["file_char_map"]:
            for style in range(filesel.GLYPH_STYLES):
                offset = words[style * 256 + tile]
                self.assertLess(offset, len(data.tiles))
                if tile != filesel.BLANK:
                    self.assertNotEqual(offset, blank[style], hex(tile))

    def test_the_hearts_are_in_the_second_style(self) -> None:
        data = rom_menus()
        words = struct.unpack(f">{len(data.glyphs) // 2}H", data.glyphs)
        for tile in (filesel.HEART_FULL, filesel.HEART_HALF, filesel.HEART_EMPTY):
            self.assertNotEqual(words[tile], words[256 + tile])

    def test_the_board_is_eleven_by_four_and_zelda_is_what_the_rom_says(self) -> None:
        data = rom_menus()
        self.assertEqual(len(data.tables["file_char_map"]), 44)
        self.assertEqual(data.tables["file_zelda"], [0x23, 0x0E, 0x15, 0x0D, 0x0A])   # Z E L D A as tiles
        self.assertEqual(data.tables["file_board_ys"], [0x10, 0xC7, 0x87, 0xF0, 0x77, 0xB7])


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class SpriteTests(unittest.TestCase):
    def frames(self):
        data = rom_menus()
        size = filesel.B.SPRITE_FRAME_BYTES
        self.assertEqual(len(data.sprites), filesel.FRAME_COUNT * size)
        return [data.sprites[i * size:(i + 1) * size] for i in range(filesel.FRAME_COUNT)]

    def test_link_wears_the_colour_of_his_ring(self) -> None:
        frames = self.frames()
        self.assertEqual(len({frames[filesel.FRAME_LINK + ring] for ring in range(3)}), 3)

    def test_the_heart_is_white_in_elimination_mode(self) -> None:
        frames = self.frames()
        self.assertNotEqual(frames[filesel.FRAME_HEART], frames[filesel.FRAME_HEART_WHITE])

    def test_the_sword_and_the_heart_fill_only_the_left_half(self) -> None:
        for frame in (self.frames()[filesel.FRAME_SWORD], self.frames()[filesel.FRAME_HEART]):
            for line in range(16):
                mask = struct.unpack(">H", frame[line * 10 + 8:line * 10 + 10])[0]
                self.assertEqual(mask & 0x00FF, 0)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class PlacementTests(unittest.TestCase):
    def test_the_cursor_grid_matches_the_names_the_rom_draws(self) -> None:
        constants = rom_menus().constants
        # the name field of mode E starts at the x the name cursor does ($70); the picture sits 4 cell columns in
        self.assertEqual(constants["REG_NAME_COL"] * 8, 0x70 + 32)
        self.assertEqual(constants["REG_NAME_ROW"] * 8 + 24, 0x2F + 1)
        # mode 1's names and the hearts beside them
        self.assertEqual(constants["SEL_NAME_COL"] * 8, 9 * 8 + 32)
        self.assertEqual(constants["SEL_HEART_COL"] - constants["SEL_NAME_COL"], 9)


if __name__ == "__main__":
    unittest.main()
