from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import actors  # noqa: E402
import build_assets as B  # noqa: E402


class ActorTableTests(unittest.TestCase):
    def test_every_monster_has_the_data_the_tables_need(self) -> None:
        for nes_type in actors.MONSTER_TYPES:
            self.assertIn(nes_type, actors.MONSTER_PERIOD)
            self.assertIn(nes_type, actors.MONSTER_DAMAGE)
            self.assertIn(nes_type, actors.MONSTER_DRAW)

    def test_behaviours_belong_to_known_monsters(self) -> None:
        for nes_type in actors.MONSTER_BEHAVIOUR:
            self.assertIn(nes_type, actors.MONSTER_TYPES)

    def test_behaviour_numbers_match_the_assembly_equates(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "src" / "ai.s").read_text(encoding="utf-8")
        for name in ("WANDER", "ROPE", "GORIYA", "WALLMASTER", "BOSS", "KEESE", "TRAP", "GEL"):
            match = re.search(rf"\.equ BEH_{name}, (\d+)", source)
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), getattr(actors, f"BEHAVIOUR_{name}"), name)

    def test_a_gel_walks_a_pixel_a_frame_and_rests_between_squares(self) -> None:
        # quarter-speed $40 (UpdateNormalZolOrGel); the rests are the game's ZolGelDelays
        self.assertEqual(actors.MONSTER_PERIOD[0x15], 1)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x15], actors.BEHAVIOUR_GEL)
        source = (Path(__file__).resolve().parents[1] / "src" / "ai.s").read_text(encoding="utf-8")
        self.assertIn(".byte 0x08, 0x18, 0x28, 0x38", source)

    def test_projectile_sprites_cover_shots_and_the_boss(self) -> None:
        data = actors.build_placeholder()
        # 8 boomerang turns and its spark, 2 fireball frames, 4 images of 4 boss pieces.
        self.assertEqual(len(data.proj_sprites), 27 * B.SPRITE_FRAME_BYTES)
        self.assertEqual(len(data.mon_table) % 8, 0)

    def test_effect_sprites_have_every_frame_the_game_indexes(self) -> None:
        data = actors.build_placeholder()
        self.assertEqual(len(data.sword_sprites), 4 * B.SPRITE_FRAME_BYTES)
        self.assertEqual(len(data.beam_sprites), 16 * B.SPRITE_FRAME_BYTES)   # direction x palette row
        self.assertEqual(len(data.fx_sprites), 20 * B.SPRITE_FRAME_BYTES)     # 2 clouds, 4 corners x 4 rows, 2 fires

    def test_trap_rooms_hold_four_or_six_traps(self) -> None:
        trap = actors.MONSTER_TYPES.index(0x49)
        attrs = ([0x0A], [0x80], [0], [0])      # list id $4A: attribute C & $3F plus $40 from attribute D
        record = actors._room_info(0, attrs, [3, 5, 6, 8], bytes(64))
        self.assertEqual(list(record[6:10]), [trap] * 4)
        self.assertEqual(record[0], 4)

    def test_the_push_block_flag_is_bit_7_of_the_trigger_byte(self) -> None:
        # attribute D bit 6 makes FindAndCreatePushBlockObject run, whatever the secret trigger is
        # (room $22, the bow room, has the block but trigger 0; room $42 has block and trigger 4)
        for attr_d, attr_f, want in ((0xDA, 0x00, 0x80), (0x62, 0x04, 0x84), (0x1F, 0x07, 0x07), (0x80, 0x00, 0x00)):
            record = actors._room_info(0, ([0], [attr_d], [0], [attr_f]), [3, 5, 6, 8], bytes(64))
            self.assertEqual(record[1], want, f"D {attr_d:#x} F {attr_f:#x}")


if __name__ == "__main__":
    unittest.main()
