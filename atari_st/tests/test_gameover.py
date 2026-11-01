from __future__ import annotations

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import build_assets as B  # noqa: E402
import gameover  # noqa: E402


ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()
_BUNDLE = None


def rom_death():
    global _BUNDLE
    if _BUNDLE is None:
        _BUNDLE = B.load_assets(ROM_ROOT)
    return _BUNDLE.gameover


class DeathMapTests(unittest.TestCase):
    def test_black_stays_and_every_other_colour_goes_to_one_of_the_three(self) -> None:
        colours = [0x000, 0x777, 0x333, 0x117, 0x610, 0x741, 0x755, 0x050, 0x765, 0x620, 0x460, 0x005, 0x247, 0x012, 0x044, 0x076]
        out = gameover.death_map(colours)
        self.assertEqual(out[0], 0)
        self.assertTrue(all(slot in (13, 14, 15) for slot in out[1:]))
        self.assertEqual({slot for slot in out[1:]}, {13, 14, 15})

    def test_the_lighter_a_colour_the_lighter_its_red(self) -> None:
        colours = [0x000] + [(i * 0x111) & 0x777 for i in range(1, 8)] + [0x777] * 8
        colours[1:8] = [0x111, 0x222, 0x333, 0x444, 0x555, 0x666, 0x777]
        out = gameover.death_map(colours)
        reds = out[1:8]
        self.assertEqual(reds, sorted(reds))

    def test_the_shares_are_even(self) -> None:
        colours = [0x000] + [0x111 * (i % 8) + i for i in range(1, 16)]
        out = gameover.death_map(colours)
        counts = [out[1:].count(slot) for slot in (13, 14, 15)]
        self.assertLessEqual(max(counts) - min(counts), 2)

@unittest.skipUnless(HAS_ROM, "needs the ROM")
class DeathDataTests(unittest.TestCase):
    def test_the_colours_are_the_roms(self) -> None:
        data = rom_death()
        self.assertEqual(len(data.colours), 7 * 3)
        steps = [data.colours[3 * (data.constants["COLOURS_STEPS"] + n):3 * (data.constants["COLOURS_STEPS"] + n) + 3] for n in range(4)]
        self.assertEqual(steps[-1], [0, 0, 0])               # the world has faded to black
        self.assertNotEqual(steps[0], steps[1])
        self.assertEqual(data.colours[:3], [0x520, 0x510, 0x732])

    def test_game_over_is_ten_tiles_of_the_roms_text(self) -> None:
        data = rom_death()
        self.assertEqual(data.text, [0x10, 0x0A, 0x16, 0x0E, 0x24, 0x18, 0x1F, 0x0E, 0x1B, 0x24])   # G A M E _ O V E R _
        self.assertEqual(data.constants["TEXT_LEN"], 10)

    def test_three_pictures_that_use_only_the_three_spare_slots(self) -> None:
        data = rom_death()
        size = B.SPRITE_FRAME_BYTES
        self.assertEqual(len(data.sprites), 3 * size)
        for frame in range(3):
            body = data.sprites[frame * size:(frame + 1) * size]
            seen = set()
            for line in range(16):
                p0, p1, p2, p3, mask = struct.unpack(">5H", body[line * 10:line * 10 + 10])
                for bit in range(16):
                    if not (mask >> bit) & 1:
                        continue
                    seen.add(sum(((plane >> bit) & 1) << n for n, plane in enumerate((p0, p1, p2, p3))))
            self.assertTrue(seen, frame)
            self.assertLessEqual(seen, {13, 14, 15}, frame)

    def test_a_map_for_the_overworld_and_each_level(self) -> None:
        data = rom_death()
        self.assertEqual(len(data.maps), 10 * 16)
        for palette in range(10):
            row = data.maps[palette * 16:palette * 16 + 16]
            self.assertEqual(row[0], 0)
            self.assertTrue(all(slot in (13, 14, 15) for slot in row[1:]))

    def test_the_spare_slots_are_free_of_the_hud_link_and_items(self) -> None:
        data = rom_death()
        self.assertEqual(data.constants["SLOT"], 12)
        # the three slots are the top three; nothing else in the game is drawn in them
        self.assertEqual(max(slot for slot in data.maps), 15)


if __name__ == "__main__":
    unittest.main()
