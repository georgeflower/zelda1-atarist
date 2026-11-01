from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "atari_st" / "tools"))
import build_assets as B  # noqa: E402
import dump_tables as D  # noqa: E402


class DumpTablesTests(unittest.TestCase):
    def test_screens_are_named_column_letter_then_row(self) -> None:
        self.assertEqual(D.screen_name(0x00), "A1")
        self.assertEqual(D.screen_name(0x77), "H8")
        self.assertEqual(D.screen_name(0x7F), "P8")

    def test_the_rom_check_names_what_is_wrong(self) -> None:
        good = {"start_room": 0x77, "start_y": 0x8D, "foe_counts": [1, 4, 5, 6]}
        self.assertEqual(D.check_rom(good), [])
        self.assertEqual(len(D.check_rom({**good, "start_room": 0x00, "foe_counts": [1, 2, 3, 4]})), 2)

    @unittest.skipIf(B.extract_binary(ROOT, B.LEVEL_BLOCK_OW_NAME) is None, "needs ext/Original.nes")
    def test_the_dump_of_the_real_rom_is_consistent(self) -> None:
        tables = D.collect(ROOT)
        self.assertEqual(D.check_rom(tables["overworld"]), [])
        self.assertEqual(len(tables["overworld"]["screens"]), 128)
        self.assertEqual([level["start_room"] for level in tables["underworld"]][:2], [0x73, 0x7D])
        self.assertIn("## Level 9", D.markdown(tables))


class GoldenSceneTests(unittest.TestCase):
    def test_every_scene_has_a_stored_fingerprint(self) -> None:
        import golden
        stored = golden.load_stored()
        self.assertEqual(sorted(stored), sorted(golden.SCENES))
        for digest in stored.values():
            self.assertRegex(digest, r"^[0-9a-f]{64}$")

    def test_scene_arguments_are_ones_screenshot_accepts(self) -> None:
        import golden
        known = {"--room", "--uw", "--level", "--vbls", "--keys", "--cave", "--quest"}
        for name, args in golden.SCENES.items():
            self.assertTrue({a for a in args if a.startswith("--")} <= known, name)


if __name__ == "__main__":
    unittest.main()
