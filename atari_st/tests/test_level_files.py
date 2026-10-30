"""The per-dungeon data files (LEVEL<n>[Q].DAT) and the monster pictures each one carries."""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import build_assets as B  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
ROM_ROOT = ROOT.parent
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()
FRAME = B.SPRITE_FRAME_BYTES


class Identity(dict):
    """A stand-in for actors.mon_index (NES type -> index in mon_table) where the index is the type."""

    def __missing__(self, key):
        return key


class MonsterSetTests(unittest.TestCase):
    def test_a_room_record_names_its_count_of_monsters_from_byte_six(self) -> None:
        record = bytes([2, 0, 0, 0, 0, 0, 7, 9, 99, 99]) + bytes(6)
        empty = bytes(16)
        self.assertEqual(B.room_monsters(record + empty), {7, 9})

    def test_a_count_over_eight_reads_eight(self) -> None:
        record = bytes([12, 0, 0, 0, 0, 0] + list(range(1, 11)))
        self.assertEqual(B.room_monsters(record), set(range(1, 9)))

    def test_what_a_monster_puts_down_comes_with_it(self) -> None:
        index = Identity()
        self.assertEqual(B.with_spawned({0x12}, index), {0x12, 0x1C})                      # a vire's keese
        self.assertEqual(B.with_spawned({0x13}, index), {0x13, 0x15})                      # a zol's gels
        self.assertEqual(B.with_spawned({0x45}, index), {0x45, 0x43, 0xF9, 0x46})          # Gleeok: pieces, heads, the flyer
        self.assertEqual(B.with_spawned({0x38}, index), {0x38, 0x18})                      # Digdogger's kids

    def test_art_is_stored_once_and_a_monster_that_is_not_wanted_points_at_frame_zero(self) -> None:
        a, b = bytes([1]) * (2 * FRAME), bytes([2]) * FRAME
        pool, table = B.monster_art([a, b, a, b], {0, 2, 3})
        self.assertEqual(pool, a + b)
        self.assertEqual(table, bytes([0, 0, 0, 0, 0, 0, 0, 2]))   # the second monster is not wanted, the third shares the first's art

    def test_a_level_file_starts_with_its_magic_and_every_table_sits_behind_the_header(self) -> None:
        tables = [bytes([n]) * (n + 1) for n in range(len(B.LEVEL_TABLES))]
        art = bytes(FRAME)
        data = B.level_file(5, tables, art)
        self.assertEqual(data[:4], B.LEVEL_IMAGE_MAGIC)
        self.assertEqual(int.from_bytes(data[4:6], "big"), 5)
        self.assertEqual(int.from_bytes(data[6:8], "big"), len(data))
        offsets = [int.from_bytes(data[8 + 4 * n : 12 + 4 * n], "big") for n in range(len(B.LEVEL_TABLES) + 1)]
        self.assertGreaterEqual(offsets[0], B.LEVEL_HEADER_BYTES)
        for offset in offsets:
            self.assertEqual(offset % 2, 0)
        for table, offset in zip(tables, offsets):
            self.assertEqual(data[offset : offset + len(table)], table)
        self.assertEqual(data[offsets[-1] : offsets[-1] + FRAME], art)

    def test_the_file_on_the_disk_is_the_packed_image_behind_eight_bytes(self) -> None:
        import lzpack
        image = B.level_file(3, [bytes([n]) * 300 for n in range(len(B.LEVEL_TABLES))], bytes(B.SPRITE_FRAME_BYTES))
        data, need = B.level_packed(image)
        self.assertEqual(data[:4], B.LEVEL_FILE_MAGIC)
        self.assertEqual(data[4:6], image[4:6])                                  # the record number
        self.assertEqual(int.from_bytes(data[6:8], "big"), len(data) - 8)        # the packed size
        self.assertEqual(lzpack.unpack(data[8:]), image)
        self.assertGreaterEqual(need, len(image))
        self.assertEqual(need % 2, 0)

    def test_file_names_are_eight_dot_three(self) -> None:
        from types import SimpleNamespace
        self.assertEqual(B.level_file_name(SimpleNamespace(level=3, quest=0)), "LEVEL3.DAT")
        self.assertEqual(B.level_file_name(SimpleNamespace(level=9, quest=1)), "LEVEL9Q.DAT")
        self.assertLess(len("LEVEL9Q.DAT"), B.LEVEL_NAME_BYTES)


@unittest.skipUnless(HAS_ROM, "needs the ROM")
class SpawnSiteTests(unittest.TestCase):
    """The code can put down monsters no room lists; their art must be in the file of every level that can."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = B.load_assets(ROM_ROOT)
        cls.index = cls.bundle.uw.actors.mon_index

    def named_types(self) -> dict[str, int]:
        text = (ROOT / "tools" / "build_assets.py").read_text(encoding="utf-8")
        names = {name: int(nes, 16) for name, nes in re.findall(r'\.equ (MON_[A-Z0-9_]+), \{uw\.actors\.mon_index\[0x([0-9A-Fa-f]+)\]\}', text)}
        names["MON_KEESE"] = B.CELLAR_MONSTER          # emitted from actors.keese_index
        return names

    def test_every_monster_the_code_puts_down_is_carried_where_it_can_appear(self) -> None:
        names = self.named_types()
        placed = set()
        for path in sorted((ROOT / "src").glob("*.s")):
            for line in path.read_text(encoding="utf-8").splitlines():
                code = line.split("|", 1)[0]
                if re.search(r"\bcmp", code):
                    continue
                m = re.search(r"(?:moveq|move\.b) #(MON_[A-Z0-9_]+), (?:%d1|OFF_ENEMY_TYPE)", code)
                if m:
                    placed.add(m.group(1))
        self.assertTrue(placed)
        carried_somewhere = set()
        for level in self.bundle.levels:
            records = b"".join(level.actors.room_info)
            wanted = B.room_monsters(records) | {self.index[B.CELLAR_MONSTER]}
            carried_somewhere |= B.with_spawned(wanted, self.index)
        ow = (B.room_monsters(self.bundle.ow_room_info) | B.room_monsters(self.bundle.ow_room_info_q2)
              | {self.index[t] for t in B.OVERWORLD_EXTRA})
        carried_somewhere |= B.with_spawned(ow, self.index)
        for name in sorted(placed):
            self.assertIn(name, names, f"{name} is not an equate of build_assets")
            self.assertIn(self.index[names[name]], carried_somewhere, f"{name} is put down by the code but no file carries its art")

    def test_what_a_boss_puts_down_travels_with_it(self) -> None:
        for level in self.bundle.levels:
            records = b"".join(level.actors.room_info)
            wanted = B.with_spawned(B.room_monsters(records), self.index)
            for boss, kids in B.SPAWNED.items():
                if self.index[boss] in B.room_monsters(records):
                    for kid in kids:
                        self.assertIn(self.index[kid], wanted, f"level {level.key}: {hex(boss)} without {hex(kid)}")

    def test_grumble_is_drawn_as_a_moblin_so_his_levels_carry_one(self) -> None:
        for level in self.bundle.levels:
            records = b"".join(level.actors.room_info)
            has_grumble = any(records[at + 1] & 0x20 for at in range(0, len(records), 16))
            if has_grumble:
                art, table = B.monster_art(level.actors.monster_arts, B.with_spawned(
                    B.room_monsters(records) | {self.index[B.GRUMBLE_MONSTER]}, self.index))
                self.assertTrue(art)

    def test_the_buffer_holds_every_image_and_every_file_with_the_room_to_unpack_it_in_place(self) -> None:
        import tempfile
        import lzpack
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            B.write_underworld(out, self.bundle)
            buffer_bytes = int((out / "level_buffer.inc").read_text().splitlines()[0].split()[-1])
            names = [B.level_file_name(level) for level in self.bundle.levels]
            self.assertEqual(len(names), 2 * len(B.UW_LEVELS))
            for name in names:
                data = (out / name).read_bytes()
                image = lzpack.unpack(data[8:])
                self.assertLessEqual(len(image), buffer_bytes, name)
                self.assertLessEqual(len(data) - 8 + lzpack.margin(data[8:]), buffer_bytes, name)
            self.assertEqual(buffer_bytes, max(B.level_packed(lzpack.unpack((out / n).read_bytes()[8:]))[1] for n in names))


class IntroFileTests(unittest.TestCase):
    """INTRO.DAT: the title, story, credits and file menu tables in one packed file, read when the intro starts."""

    def fake_tables(self, out: Path) -> list[bytes]:
        tables = [bytes([n + 1]) * (40 + 7 * n) for n in range(len(B.INTRO_TABLES))]
        for name, table in zip(B.INTRO_TABLES, tables):
            (out / f"{name}.bin").write_bytes(table)
        return tables

    def test_the_file_holds_every_table_at_the_offset_the_header_gives(self) -> None:
        import tempfile
        import lzpack
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            tables = self.fake_tables(out)
            B.write_intro_file(out)
            data = (out / B.INTRO_FILE_NAME).read_bytes()
            self.assertEqual(data[:4], B.LEVEL_FILE_MAGIC)
            self.assertEqual(int.from_bytes(data[4:6], "big"), B.INTRO_RECORD)
            self.assertEqual(int.from_bytes(data[6:8], "big"), len(data) - 8)
            image = lzpack.unpack(data[8:])
            self.assertEqual(image[:4], B.LEVEL_IMAGE_MAGIC)
            self.assertEqual(int.from_bytes(image[6:8], "big"), len(image))
            for k, table in enumerate(tables):
                offset = int.from_bytes(image[8 + 4 * k : 12 + 4 * k], "big")
                self.assertEqual(offset % 2, 0)
                self.assertEqual(image[offset : offset + len(table)], table, B.INTRO_TABLES[k])

    def test_the_buffer_equate_grows_to_hold_the_intro_when_it_is_the_larger(self) -> None:
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.fake_tables(out)
            (out / "level_buffer.inc").write_text(B.buffer_include(8), encoding="utf-8")
            B.write_intro_file(out)
            text = (out / "level_buffer.inc").read_text()
            size = int(text.split()[2])
            data = (out / B.INTRO_FILE_NAME).read_bytes()
            self.assertGreaterEqual(size, len(data) - 8)
            for k, name in enumerate(B.INTRO_TABLES):
                self.assertIn(f".equ IV_{name}, {k}", text)
            self.assertIn(f".equ INTRO_TABLE_COUNT, {len(B.INTRO_TABLES)}", text)
            self.assertIn(f".equ INTRO_RECORD, {B.INTRO_RECORD}", text)

    def test_a_table_name_the_code_asks_for_is_in_the_file(self) -> None:
        used = set()
        for path in sorted((ROOT / "src").glob("*.s")):
            for line in path.read_text(encoding="utf-8").splitlines():
                code = line.split("|", 1)[0]
                if not code.lstrip().startswith(".macro"):
                    used |= set(re.findall(r"\bivtab\s+([a-z0-9_]+)\s*,", code))
        self.assertTrue(used)
        self.assertLessEqual(used, set(B.INTRO_TABLES))

    def test_the_intro_record_is_not_a_level_record(self) -> None:
        self.assertGreater(B.INTRO_RECORD, 2 * len(B.UW_LEVELS))


if __name__ == "__main__":
    unittest.main()
