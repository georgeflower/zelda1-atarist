from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import build_assets as B  # noqa: E402
import intro  # noqa: E402


ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()
_DATA = None


def rom_intro():
    global _DATA
    if _DATA is None:
        _DATA = intro.build(ROM_ROOT)
    return _DATA


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class TransferStreamTests(unittest.TestCase):
    def test_the_streams_are_found_where_the_roms_tables_say_or_by_their_contents(self) -> None:
        story, title = intro.transfer_streams(ROM_ROOT)
        for name, stream in (("story", story), ("title", title)):
            records = intro.parse_stream(stream)
            self.assertIsNotNone(records, name)
            self.assertTrue(records, name)
        # the title's first record writes the first row of the first nametable
        self.assertEqual(intro.parse_stream(title)[0][0], 0x2000)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class PictureTests(unittest.TestCase):
    def test_every_cell_names_a_whole_tile(self) -> None:
        data = rom_intro()
        self.assertEqual(len(data.title_cells), intro.WINDOW_ROWS * intro.CELLS * 2)
        offsets = struct.unpack(f">{len(data.title_cells) // 2}H", data.title_cells)
        self.assertTrue(all(o % intro.TILE_BYTES == 0 and o < len(data.title_tiles) for o in offsets))

    def test_the_story_map_points_at_rows(self) -> None:
        data = rom_intro()
        row_bytes = intro.CELLS * 2
        self.assertEqual(len(data.story_rows) % row_bytes, 0)
        mapping = struct.unpack(f">{len(data.story_map) // 2}H", data.story_map)
        self.assertEqual(len(mapping), data.story_row_count)
        self.assertTrue(all(m % row_bytes == 0 and m < len(data.story_rows) for m in mapping))
        cells = struct.unpack(f">{len(data.story_rows) // 2}H", data.story_rows)
        self.assertTrue(all(c % intro.TILE_BYTES == 0 and c < len(data.story_tiles) for c in cells))

    def test_the_story_strip_reaches_the_last_line_the_window_can_show(self) -> None:
        data = rom_intro()
        last_top = intro.STORY_FIRST_SCROLL + intro.STORY_REST_SCROLL + (intro.PAGE_LINES - intro.STORY_FIRST_SCROLL) \
            + intro.STORY_SCROLL_STEPS - 1 - (intro.PAGE_LINES - intro.STORY_FIRST_SCROLL)
        last_line = last_top + intro.WINDOW_TOP_LINE + intro.WINDOW_LINES - 1
        self.assertGreaterEqual((data.story_first_row + data.story_row_count) * 8, last_line - 8)

    def test_the_waterfall_is_on_a_sixteen_pixel_group(self) -> None:
        # intro.s restores and draws the fall by whole groups
        self.assertEqual(rom_intro().constants["WATERFALL_X"] % 16, 0)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class FadeTests(unittest.TestCase):
    def test_the_fade_has_a_palette_and_a_delay_for_each_step(self) -> None:
        data = rom_intro()
        self.assertEqual(len(data.fade_palettes), intro.FADE_STEPS)
        self.assertEqual(len(data.fade_delays), intro.FADE_STEPS)
        for palette in data.fade_palettes:
            self.assertEqual(len(palette), B.ST_PALETTE_SIZE)

    def test_the_title_palette_has_the_glowing_slot(self) -> None:
        data = rom_intro()
        self.assertLess(data.glow_slot, B.ST_PALETTE_SIZE)
        self.assertEqual(len(data.glow_colours), 8)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class SpriteTests(unittest.TestCase):
    def test_the_frames_are_whole_sprites(self) -> None:
        data = rom_intro()
        self.assertEqual(len(data.sprites), data.sprite_count * intro.FRAME_BYTES)

    def test_every_spawn_names_a_frame_and_an_animation(self) -> None:
        data = rom_intro()
        records = [struct.unpack(">4H", data.spawns[i : i + 8]) for i in range(0, len(data.spawns), 8)]
        self.assertEqual(len(records), data.spawn_count)
        for line, x, frame, kind in records:
            self.assertLess(frame + (1 if kind else 0), data.sprite_count)
            self.assertIn(kind, (intro.KIND_STATIC, intro.KIND_FLASH, intro.KIND_FAIRY))
            self.assertLessEqual(x + 16, 256)
            self.assertGreater(line, 0)
        lines = [r[0] for r in records]
        self.assertEqual(lines, sorted(lines))

    def test_the_parade_has_the_treasures_the_rom_lists(self) -> None:
        data = rom_intro()
        # the ROM's DemoLeftItemIds / DemoRightItemIds: 20 rows of two items, the triforce, Link's sign
        self.assertGreaterEqual(data.spawn_count, 40)


if __name__ == "__main__":
    unittest.main()


class TitlePromptTests(unittest.TestCase):
    """The title says PRESS FIRE where the ROM says PUSH START BUTTON (intro.put_title_prompt)."""

    def test_the_prompt_is_in_the_middle_of_the_line_the_rom_had(self) -> None:
        import credits
        ppu = intro.Ppu()
        for column in range(intro.PROMPT_FIRST_COL, intro.PROMPT_LAST_COL + 1):
            ppu.tiles[intro.PAGE_A][intro.PORT_TEXT_TILE_ROW * 32 + column] = 0x01    # what the ROM's words leave
        intro.put_title_prompt(ppu)
        row = ppu.tiles[intro.PAGE_A][intro.PORT_TEXT_TILE_ROW * 32:(intro.PORT_TEXT_TILE_ROW + 1) * 32]
        codes = credits.nes_codes("PRESS FIRE")
        first = 16 - len(codes) // 2
        self.assertEqual(row[first:first + len(codes)], codes)
        outside = row[intro.PROMPT_FIRST_COL:first] + row[first + len(codes):intro.PROMPT_LAST_COL + 1]
        self.assertTrue(all(code == credits.BLANK_TILE for code in outside), outside)
