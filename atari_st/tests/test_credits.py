from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import credits  # noqa: E402
import intro  # noqa: E402


ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()


def row_text(cells) -> str:
    letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return "".join(letters[tile] if tile < 36 else {0x2C: ".", 0x28: ","}.get(tile, " ") for tile, _ in cells).strip()


class CodesTests(unittest.TestCase):
    def test_text_becomes_the_roms_tile_codes(self) -> None:
        self.assertEqual(credits.nes_codes("A 1."), [10, 0x24, 1, 0x2C])


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class WallTests(unittest.TestCase):
    def test_the_strip_has_the_roms_credits_in_order(self) -> None:
        texts = [row_text(row) for row in credits.strip(ROM_ROOT)]
        texts = [t for t in texts if t]
        self.assertEqual(texts[0], "PEACE RETURNS TO HYRULE.")
        self.assertEqual(texts[1], "THIS ENDS THE STORY.")
        wanted = ["STAFF", "ANOTHER QUEST WILL START", "FROM HERE.", "PRESS THE START BUTTON.", "1986 NINTENDO"]
        position = 0
        for text in texts:
            if position < len(wanted) and wanted[position] in text:
                position += 1
        self.assertEqual(position, len(wanted), texts)

    def test_the_first_quest_stops_before_the_second_quests_lines(self) -> None:
        text = " ".join(row_text(row) for row in credits.strip(ROM_ROOT))
        self.assertNotIn("SECOND QUEST", text)

    def test_the_wall_has_bricks_at_both_sides_and_the_tables_fit(self) -> None:
        wall = credits.build(ROM_ROOT)
        rows = credits.strip(ROM_ROOT)
        self.assertEqual(len(rows), credits.STRIP_ROWS)
        brick_rows = [row for row in rows if row[credits.WALL_LEFT][0] == credits.WALL_TILE]
        self.assertTrue(all(row[credits.WALL_RIGHT][0] == credits.WALL_TILE for row in brick_rows))
        self.assertEqual(len(wall["map"]), credits.STRIP_ROWS * 2)
        self.assertEqual(len(wall["palette"]), 16)
        self.assertEqual(len(wall["frames"]), 3, "the ash pile and the two Triforce pictures")

    def test_intro_hands_the_tables_and_constants_to_the_assembler(self) -> None:
        data = intro.build(ROM_ROOT)
        self.assertEqual(data.constants["CREDITS_ROWS"], credits.STRIP_ROWS)
        self.assertEqual(data.constants["CREDITS_FRAME_TRIFORCE"], data.constants["CREDITS_FRAME_ASH"] + 1)
        self.assertEqual(data.sprite_count, data.constants["CREDITS_FRAME_ASH"] + 3)


if __name__ == "__main__":
    unittest.main()
