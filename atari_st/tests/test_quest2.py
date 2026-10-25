"""The Second Quest: its dungeons, the overworld's differences (quest_patch) and its credits."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_assets  # noqa: E402
import credits  # noqa: E402
import underworld  # noqa: E402
import test_build_assets  # noqa: E402

ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()


def apply_in_place(patch: bytearray, tables: dict[str, bytearray]) -> None:
    """quest_apply working on the patch itself: the swap puts the other quest's bytes into the run."""
    position = 0
    while bytes(patch[position : position + 2]) != b"\xff\xff":
        number = int.from_bytes(patch[position : position + 2], "big")
        offset = int.from_bytes(patch[position + 2 : position + 4], "big")
        count = int.from_bytes(patch[position + 4 : position + 6], "big")
        table = tables[build_assets.QUEST_TABLES[number]]
        run = bytes(patch[position + 6 : position + 6 + count])
        patch[position + 6 : position + 6 + count] = bytes(table[offset : offset + count])
        table[offset : offset + count] = run
        position += 6 + count


class QuestPatchTests(unittest.TestCase):
    def tables(self, change: dict[str, dict[int, int]]):
        first = {name: bytes(range(40)) for name in build_assets.QUEST_TABLES}
        second = {}
        for name, data in first.items():
            edited = bytearray(data)
            for offset, value in change.get(name, {}).items():
                edited[offset] = value
            second[name] = bytes(edited)
        return first, second

    def test_an_unchanged_overworld_has_an_empty_patch(self) -> None:
        first, second = self.tables({})
        self.assertEqual(build_assets.quest_patch(first, second), b"\xff\xff")

    def test_applying_the_patch_gives_the_second_quest_and_applying_it_again_the_first(self) -> None:
        first, second = self.tables({"room_maps": {3: 0xAA, 4: 0xBB, 30: 0xCC}, "room_attr_f": {39: 0x11}})
        patch = bytearray(build_assets.quest_patch(first, second))
        tables = {name: bytearray(data) for name, data in first.items()}
        apply_in_place(patch, tables)
        self.assertEqual({k: bytes(v) for k, v in tables.items()}, second)
        apply_in_place(patch, tables)
        self.assertEqual({k: bytes(v) for k, v in tables.items()}, first)

    def test_runs_are_even_and_a_size_change_is_refused(self) -> None:
        first, second = self.tables({"room_maps": {5: 1}})
        patch = build_assets.quest_patch(first, second)
        self.assertEqual(int.from_bytes(patch[4:6], "big") % 2, 0)
        second["room_maps"] = second["room_maps"] + b"\0"
        with self.assertRaises(SystemExit):
            build_assets.quest_patch(first, second)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class SecondQuestDungeonTests(test_build_assets.RomAllDungeonsTests):
    """The eighteen records: levels 1-9 of the First Quest, then 1-9 of the Second."""

    SECOND = {1: 14, 2: 11, 3: 20, 4: 18, 5: 30, 6: 22, 7: 35, 8: 27, 9: 46}
    START = {1: 0x77, 2: 0x75, 3: 0x79, 4: 0x72, 5: 0x7D, 6: 0x74, 7: 0x7F, 8: 0x79, 9: 0x74}

    def test_there_are_eighteen_levels_with_the_second_quests_after_the_first(self) -> None:
        self.assertEqual(len(self.bundle.levels), 18)
        for number, uw in enumerate(self.bundle.levels):
            self.assertEqual((uw.level, uw.quest, uw.key), (number % 9 + 1, number // 9,
                                                            underworld.level_key(number % 9 + 1, number // 9)))

    def test_every_room_of_every_second_quest_dungeon_can_be_reached_through_its_doors(self) -> None:
        for level, count in self.SECOND.items():
            uw = self.bundle.levels[8 + level]
            stored = [room for room, index in enumerate(uw.room_index) if index != 0xFF]
            self.assertEqual(len(stored), count, level)
            self.assertIn(uw.triforce_room, stored, level)
            self.assertIn(uw.start_room, stored, level)
            everything = self._reach(uw, self._locked_pairs(uw))
            self.assertEqual(len(everything), count, (level, sorted(map(hex, everything))))

    def test_the_second_quest_starts_where_its_level_info_says(self) -> None:
        for level, start in self.START.items():
            self.assertEqual(self.bundle.levels[8 + level].start_room, start, level)

    def test_the_second_quest_has_other_dungeons_than_the_first(self) -> None:
        for level in range(1, 10):
            first, second = self.bundle.levels[level - 1], self.bundle.levels[8 + level]
            self.assertNotEqual(first.room_index, second.room_index, level)

    def test_the_overworld_patch_ends_with_its_marker_and_names_known_tables(self) -> None:
        patch = self.bundle.quest_patch
        self.assertEqual(patch[-2:], b"\xff\xff")
        position, runs = 0, 0
        while patch[position : position + 2] != b"\xff\xff":
            number = int.from_bytes(patch[position : position + 2], "big")
            count = int.from_bytes(patch[position + 4 : position + 6], "big")
            self.assertLess(number, len(build_assets.QUEST_TABLES))
            self.assertEqual(count % 2, 0)
            position += 6 + count
            runs += 1
        self.assertEqual(position, len(patch) - 2)
        self.assertGreater(runs, 5)

    def test_black_keese_are_in_the_monster_table(self) -> None:
        self.assertIn(0x1D, self.bundle.levels[0].actors.mon_index)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class SecondQuestCreditsTests(unittest.TestCase):
    @staticmethod
    def texts(quest: int):
        letters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        out = []
        for row in credits.strip(ROM_ROOT, quest):
            out.append("".join(letters[t] if t < 36 else {0x2C: ".", 0x28: ",", 0x29: "!"}.get(t, " ")
                               for t, _ in row).strip())
        return [t for t in out if t]

    def test_the_second_quest_scrolls_720_lines_of_a_longer_strip(self) -> None:
        self.assertEqual(len(credits.strip(ROM_ROOT, 1)), credits.STRIP_ROWS_2)
        self.assertGreater(credits.STRIP_ROWS_2, credits.STRIP_ROWS)

    def test_its_last_lines_are_the_end_of_the_legend_and_the_copyright(self) -> None:
        text = " ".join(self.texts(1))
        for wanted in ("YOU ARE GREAT", "YOU HAVE AN AMAZING", "WISDOM AND POWER", "END OF", "THE LEGEND OF ZELDA 1",
                       "1986 NINTENDO"):
            self.assertIn(wanted, text)
        self.assertNotIn("ANOTHER QUEST WILL START", text)       # lines $C-$F are the First Quest's

    def test_the_first_quest_keeps_its_own_lines(self) -> None:
        text = " ".join(self.texts(0))
        self.assertIn("ANOTHER QUEST WILL START", text)
        self.assertNotIn("YOU ARE GREAT", text)

    def test_the_name_line_has_the_skull_and_room_for_the_name_and_the_count(self) -> None:
        row, colour = credits.name_row(ROM_ROOT)
        cells = credits.strip(ROM_ROOT, 1)[row]
        self.assertEqual(cells[18][0], 0x62)
        for cell in list(range(credits.NAME_CELL, credits.NAME_CELL + 8)) + list(range(credits.DEATH_CELL,
                                                                                       credits.DEATH_CELL + 3)):
            self.assertEqual(cells[cell][0], credits.BLANK_TILE)
        wall = credits.build(ROM_ROOT)
        self.assertEqual(len(wall["glyphs"]), credits.GLYPHS * 2)
        self.assertEqual(wall["name_row"], row)
        self.assertIn(colour, range(4))

    def test_the_attribute_colours_follow_the_rows_quarters(self) -> None:
        self.assertEqual(credits.colour_of_attr(0x50, 0), 0)
        self.assertEqual(credits.colour_of_attr(0x50, 2), 1)
        self.assertEqual(credits.colour_of_attr(0xAA, 1), 2)
        with self.assertRaises(SystemExit):
            credits.colour_of_attr(0x04, 0)


if __name__ == "__main__":
    unittest.main()
