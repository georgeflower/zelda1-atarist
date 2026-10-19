from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import actors  # noqa: E402
import build_assets as B  # noqa: E402


ROM_ROOT = Path(__file__).resolve().parents[2]
HAS_ROM = (ROM_ROOT / "ext" / "Original.nes").exists()
_ROM_ACTORS = None


def rom_actors():
    """The ROM's tables of level 1: nothing in the port is drawn or invented separately, so there is no stand-in."""
    global _ROM_ACTORS
    if _ROM_ACTORS is None:
        _ROM_ACTORS = B.load_assets(ROM_ROOT).uw.actors
    return _ROM_ACTORS


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
        for name in ("WANDER", "ROPE", "GORIYA", "WALLMASTER", "BOSS", "KEESE", "TRAP", "GEL",
                     "OCTOROK", "MOBLIN", "LYNEL", "OCTOROK_BLUE", "TEKTITE", "LEEVER", "ZORA",
                     "PEAHAT", "GHINI", "BOULDER", "BOULDER_SET", "DODONGO", "MOLDORM"):
            match = re.search(rf"\.equ BEH_{name}, (\d+)", source)
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), getattr(actors, f"BEHAVIOUR_{name}"), name)

    def test_every_behaviour_and_draw_mode_number_matches_the_assembly(self) -> None:
        src = Path(__file__).resolve().parents[1] / "src"
        text = "\n".join(path.read_text(encoding="utf-8") for path in src.glob("*.s"))
        names = [n for n in dir(actors) if n.startswith("BEHAVIOUR_")]
        self.assertGreaterEqual(len(names), 30)
        for name in names:
            match = re.search(rf"\.equ BEH_{name[len('BEHAVIOUR_'):]}, (\d+)", text)
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), getattr(actors, name), name)
        modes = [n for n in dir(actors) if n.startswith("MODE_") and isinstance(getattr(actors, n), int)
                 and getattr(actors, n) >= actors.MODE_DARKNUT]       # the ones dmon.s draws
        self.assertGreaterEqual(len(modes), 10)
        for name in modes:
            match = re.search(rf"\.equ {name}, (\d+)", text)
            self.assertIsNotNone(match, name)
            self.assertEqual(int(match.group(1)), getattr(actors, name), name)

    def test_the_later_dungeons_monsters_have_data_and_a_behaviour(self) -> None:
        for nes_type in (0x16, 0x23, 0x24, 0x3C, 0x38, 0xFB, 0x18, 0x43, 0x44, 0x45, 0xF9, 0x46):
            if nes_type in actors.MONSTER_TYPES:
                self.assertIn(nes_type, actors.MONSTER_BEHAVIOUR, hex(nes_type))
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x43], actors.BEHAVIOUR_GLEEOK)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0xF9], actors.BEHAVIOUR_GLEEOK_HEAD)

    def test_a_gleeok_art_ends_with_two_pre_shifted_tables(self) -> None:
        # image 12 (a neck segment) and 13 (a head) are followed by 16 shifts of 16 two-group rows of 20 bytes each,
        # which the boss sprite pool's shift-free blitter indexes by frame (28 + 32 * image + 2 * shift)
        rows = [[3] * 8 + [-1] * 8 for _ in range(16)]
        table = actors._preshift_narrow(rows)
        self.assertEqual(len(table), 16 * 16 * 20)
        self.assertEqual(len(table) % actors.FRAME_BYTES, 0)
        self.assertEqual(len(table) // actors.FRAME_BYTES, 32)
        first = table[:20]                       # shift 0: the left group is eight columns, the right group empty
        self.assertEqual(first[8:10], (0x00FF).to_bytes(2, "big"))
        self.assertEqual(first[18:20], (0xFFFF).to_bytes(2, "big"))
        last = table[15 * 320 : 15 * 320 + 20]   # shift 15: one column in the left group, seven in the right
        self.assertEqual(last[8:10], (0xFFFE).to_bytes(2, "big"))
        self.assertEqual(last[18:20], (0x01FF).to_bytes(2, "big"))

    def test_the_stash_and_grumble_rooms_mark_their_trigger_byte(self) -> None:
        attrs = ([0x35], [0x00], [0], [0])
        record = actors._room_info(0, attrs, [1, 4, 5, 6], bytes(64))
        self.assertTrue(record[1] & 0x40, "bit 6: a rupee stash")
        self.assertEqual(record[0], 0)           # no monster to kill
        self.assertEqual(record[5], 0)           # and nothing unsupported
        attrs = ([0x36], [0x00], [0], [0])
        record = actors._room_info(0, attrs, [1, 4, 5, 6], bytes(64))
        self.assertTrue(record[1] & 0x20, "bit 5: Grumble")
        self.assertEqual(record[5], 0)
        self.assertEqual((actors.RUPEE_STASH, actors.GRUMBLE), (0x35, 0x36))

    def test_b_item_tables_agree_with_the_b_codes(self) -> None:
        src = Path(__file__).resolve().parents[1] / "src"
        items = (src / "items.s").read_text(encoding="utf-8")
        last = int(re.search(r"\.equ B_LAST, (\d+)", items).group(1))

        def bytes_of(label: str, text: str) -> list[int]:
            block = re.search(rf"^{label}:\n((?:\s+\.byte [^\n]*\n)+)", text, re.M).group(1)
            return [int(v, 0) for line in block.splitlines() for v in line.split("|")[0].replace(".byte", "").split(",")]

        slots = bytes_of("b_slots", items)
        self.assertEqual(len(slots), 3 * (last + 1))          # slot, second slot, "both needed" per code
        icons = bytes_of("b_icons", items)
        self.assertEqual(len(icons), last + 1)
        for code in range(1, last + 1):
            self.assertLess(icons[code], len(actors.HUD_ITEM_IDS))
            self.assertLess(slots[3 * code], 32)
            self.assertLess(slots[3 * code + 1], 32)
        menu = (src / "menu.s").read_text(encoding="utf-8")
        names = re.search(r"menu_names:\n(.*?)\s+\.align", menu, re.S).group(1)
        self.assertEqual(len(re.findall(r"\.asciz", names)), last)
        # a name plus its padding is ten bytes, so menu_draw can index the table by code * 10
        total = sum(len(m) + 1 for m in re.findall(r'\.asciz "([^"]*)"', names)) + sum(
            int(n) for n in re.findall(r"\.space (\d+)", names))
        self.assertEqual(total, 10 * last)

    def test_overworld_walkers_are_listed_with_their_data(self) -> None:
        for nes_type in actors.OVERWORLD_MONSTERS:
            self.assertIn(nes_type, actors.MONSTER_TYPES)
            self.assertIn(nes_type, actors.MONSTER_BEHAVIOUR)
        # blue lynel hits for two hearts, red for one; octoroks and moblins for half a heart
        self.assertEqual(actors.MONSTER_DAMAGE[0x01], 4)
        self.assertEqual(actors.MONSTER_DAMAGE[0x02], 2)
        self.assertEqual(actors.MONSTER_DAMAGE[0x07], 1)

    def test_overworld_screens_name_their_monsters_from_the_list_ids(self) -> None:
        foe_counts = [1, 4, 5, 6]
        lists = [[0x07, 0x07, 0x0B, 0x01]]          # list id $62: two octoroks, something unported, a lynel
        # attribute C & $3F = $22 plus attribute D bit 7 is list $62; the top two bits pick the foe count
        self.assertEqual(actors.overworld_room_types(lists, 0x22 | (1 << 6), 0x80, foe_counts), [0x07, 0x07, 0x0B, 0x01])
        # a single type fills the whole count: four red octoroks
        self.assertEqual(actors.overworld_room_types(lists, 0x07 | (1 << 6), 0x00, foe_counts), [0x07] * 4)
        self.assertEqual(actors.overworld_room_types(lists, 0x00, 0x00, foe_counts), [])

    def test_the_movers_are_listed_with_their_behaviours_and_damage(self) -> None:
        for nes_type, behaviour in ((0x0D, actors.BEHAVIOUR_TEKTITE), (0x0E, actors.BEHAVIOUR_TEKTITE),
                                    (0x0F, actors.BEHAVIOUR_LEEVER), (0x10, actors.BEHAVIOUR_LEEVER),
                                    (0x11, actors.BEHAVIOUR_ZORA), (0x1A, actors.BEHAVIOUR_PEAHAT),
                                    (0x21, actors.BEHAVIOUR_GHINI), (0x20, actors.BEHAVIOUR_BOULDER),
                                    (0x1F, actors.BEHAVIOUR_BOULDER_SET)):
            self.assertIn(nes_type, actors.OVERWORLD_MONSTERS)
            self.assertEqual(actors.MONSTER_BEHAVIOUR[nes_type], behaviour, hex(nes_type))
        # ObjTypeToDamagePoints: the boulder set hurts nobody, peahats and zoras one half heart
        self.assertEqual(actors.MONSTER_DAMAGE[0x1F], 0)
        self.assertEqual(actors.MONSTER_DAMAGE[0x1A], 1)
        self.assertEqual(actors.MONSTER_DAMAGE[0x21], 2)
        self.assertIn(0x1A, actors.MONSTER_FLYERS)

    def test_armos_whirlwind_and_fairy_are_listed_but_only_the_armos_has_art_on_the_screens(self) -> None:
        for nes_type, behaviour, mode in ((0x1E, actors.BEHAVIOUR_ARMOS, actors.MODE_ARMOS),
                                          (0x2E, actors.BEHAVIOUR_WHIRLWIND, None),
                                          (0x2F, actors.BEHAVIOUR_FAIRY, actors.MODE_FAIRY)):
            self.assertIn(nes_type, actors.MONSTER_TYPES)
            self.assertEqual(actors.MONSTER_BEHAVIOUR[nes_type], behaviour, hex(nes_type))
            if mode is not None:
                self.assertEqual(actors.MONSTER_DRAW[nes_type][2], mode, hex(nes_type))
        # the whirlwind and the fairy are made by code, never listed for a screen as walkers; the armos hurts
        self.assertIn(0x1E, actors.OVERWORLD_ART)
        self.assertIn(0x2E, actors.OVERWORLD_ART)
        self.assertNotIn(0x2F, actors.OVERWORLD_ART)
        self.assertIn(0x2F, actors.OVERWORLD_LISTED)
        self.assertEqual(actors.MONSTER_DAMAGE[0x1E], 2)
        self.assertEqual(actors.MONSTER_DAMAGE[0x2E], 0)
        self.assertEqual(actors.MONSTER_DAMAGE[0x2F], 0)
        self.assertEqual(len(actors.FAIRY_TILES), 2)

    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_every_monster_has_a_picture_start(self) -> None:
        data = rom_actors()
        self.assertEqual(len(data.mon_art), 2 * (len(data.mon_table) // 8))

    def test_a_gel_walks_a_pixel_a_frame_and_rests_between_squares(self) -> None:
        # quarter-speed $40 (UpdateNormalZolOrGel); the rests are the game's ZolGelDelays
        self.assertEqual(actors.MONSTER_PERIOD[0x15], 1)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x15], actors.BEHAVIOUR_GEL)
        source = (Path(__file__).resolve().parents[1] / "src" / "ai.s").read_text(encoding="utf-8")
        self.assertIn(".byte 0x08, 0x18, 0x28, 0x38", source)

    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_projectile_sprites_cover_shots_and_the_boss(self) -> None:
        data = rom_actors()
        # 8 boomerang turns and its spark, 4 fireball frames, 4 images of 4 boss pieces, a rock, 4 arrows.
        self.assertEqual(len(data.proj_sprites), 34 * B.SPRITE_FRAME_BYTES)
        self.assertEqual(len(data.mon_table) % 8, 0)

    def test_shot_frames_follow_the_boss_pieces_in_proj_sprites(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "src" / "ai.s").read_text(encoding="utf-8")
        equ = {name: int(value) for name, value in re.findall(r"\.equ (\w+), (\d+)", source)}
        self.assertEqual(equ["PF_ARROW"], equ["PF_ROCK"] + 1)
        # rock + four arrows are the last five frames of the 34-frame table
        self.assertEqual(equ["PF_ARROW"] + 4, 34)
        self.assertEqual(equ["PF_BOSS"], equ["PF_FIREBALL"] + 4)
        self.assertEqual((equ["PK_ROCK"], equ["PK_ARROW"], equ["PK_SWORDSHOT"]), (9, 10, 11))
        self.assertEqual(equ["SHOT_LIMIT"], 4)
        # the sword shot flies as fast as the rock, the arrow slower (1/64 px per frame)
        self.assertEqual((equ["SHOT_SPEED"], equ["ARROW_SPEED"]), (192, 128))

    def test_the_reach_check_finds_ltab_symbols(self) -> None:
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import check_reach
        self.assertEqual(check_reach.LTAB.match("    ltab room_maps, %a0 | note").group(1), "room_maps")
        self.assertIsNone(check_reach.LTAB.match("    lea room_maps(%pc), %a0"))

    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_effect_sprites_have_every_frame_the_game_indexes(self) -> None:
        data = rom_actors()
        self.assertEqual(len(data.sword_sprites), 16 * B.SPRITE_FRAME_BYTES)  # four directions x (three swords + the rod)
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

    def test_a_lone_moldorm_becomes_two_worms_of_four_segments(self) -> None:
        segment = actors.MONSTER_TYPES.index(0x41)
        attrs = ([0x22], [0x80], [0], [0])      # list id $62, the first of the ObjLists: here a single Moldorm
        record = actors._room_info(0, attrs, [1, 4, 5, 6], bytes(64), lists=[[0x41]])
        self.assertEqual(list(record[6:6 + actors.MOLDORM_SEGMENTS]), [segment] * actors.MOLDORM_SEGMENTS)
        self.assertEqual(record[0], actors.MOLDORM_SEGMENTS)

    def test_the_new_monsters_have_their_tables(self) -> None:
        for nes_type in (0x05, 0x31, 0x32, 0x41):
            self.assertIn(nes_type, actors.MONSTER_TYPES)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x31], actors.BEHAVIOUR_DODONGO)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x41], actors.BEHAVIOUR_MOLDORM)

    def test_level_nine_monsters_have_their_tables_and_behaviours(self) -> None:
        pairs = {0x3A: actors.BEHAVIOUR_LANMOLA, 0x3B: actors.BEHAVIOUR_LANMOLA, 0x47: actors.BEHAVIOUR_PATRA,
                 0x48: actors.BEHAVIOUR_PATRA, 0x25: actors.BEHAVIOUR_PATRA_CHILD, 0x26: actors.BEHAVIOUR_PATRA_CHILD,
                 0x3E: actors.BEHAVIOUR_GANON, 0x37: actors.BEHAVIOUR_ZELDA, 0x3F: actors.BEHAVIOUR_FIRE}
        for nes_type, behaviour in pairs.items():
            self.assertIn(nes_type, actors.MONSTER_TYPES, hex(nes_type))
            self.assertEqual(actors.MONSTER_BEHAVIOUR[nes_type], behaviour, hex(nes_type))
        self.assertEqual(actors.MONSTER_DAMAGE[0x37], 0, "Zelda touches nobody")
        self.assertEqual(actors.MONSTER_HURT[0x37], 0, "and nothing touches her")
        self.assertEqual(actors.MONSTER_DAMAGE[0x3E], 8, "Ganon: ObjTypeToDamagePoints $04, four hearts")

    def test_zelda_comes_with_four_guard_fires_and_patra_with_seven_children(self) -> None:
        zelda = actors.MONSTER_TYPES.index(0x37)
        fire = actors.MONSTER_TYPES.index(0x3F)
        record = actors._room_info(0, ([0x37], [0x00], [0], [0]), [1, 4, 5, 6], bytes(64))   # list id $37: one Zelda
        self.assertEqual(record[0], 5)
        self.assertEqual(list(record[6:11]), [zelda] + [fire] * 4)
        self.assertEqual(record[5] & 0x7F, 0, "nothing unsupported")
        eye = actors.MONSTER_TYPES.index(0x47)
        child = actors.MONSTER_TYPES.index(0x25)
        record = actors._room_info(0, ([0x07], [0x80], [0], [0]), [1, 4, 5, 6], bytes(64))   # list id $47
        self.assertEqual(list(record[6:6 + 1 + actors.PATRA_CHILDREN]), [eye] + [child] * actors.PATRA_CHILDREN)

    def test_ganons_room_keeps_its_item_hidden_until_he_is_ashes(self) -> None:
        record = actors._room_info(0, ([0x3E], [0x00], [0], [0x03]), [1, 4, 5, 6], bytes(64))
        self.assertEqual(record[1] & 7, 7)
        self.assertEqual(record[0], 1)

    def test_the_ending_texts_are_the_originals(self) -> None:
        source = (Path(__file__).resolve().parents[2] / "src" / "Z_02.asm").read_text(encoding="utf-8")
        block = source.split("ThanksText:", 1)[1].split("InitMode13_Sub2:", 1)[0]
        original = bytes(int(h, 16) for h in re.findall(r"\$([0-9A-F]{2})", block))
        self.assertEqual(B.ENDING_THANKS_TEXT, original)
        self.assertEqual(B.ENDING_PEACE_TEXT[-1] & 0xC0, 0xC0, "the last letter ends the speech")
        self.assertEqual(B.ENDING_TEXTS, B.ENDING_THANKS_TEXT + B.ENDING_PEACE_TEXT + b"".join(B.CREDIT_TEXTS))
        self.assertTrue(B.AssetBundle.__dataclass_fields__["cave_text"].default.endswith(B.ENDING_TEXTS))

    def test_every_credits_page_fits_three_lines_and_the_port_is_credited(self) -> None:
        self.assertEqual(len(B.CREDIT_TEXTS), len(B.CREDIT_PAGES))
        for page, text in zip(B.CREDIT_PAGES, B.CREDIT_TEXTS):
            self.assertLessEqual(len(page), 3)
            self.assertTrue(all(len(line) <= 24 for line in page), page)      # the width cave_talk's wipe clears
            self.assertEqual(text[-1] & 0xC0, 0xC0)
            self.assertEqual(sum(1 for code in text if code & 0xC0 == 0xC0), 1, "one speech to a page")
        self.assertIn(("ATARI ST PORT", " ", "BY Q"), B.CREDIT_PAGES)
        self.assertEqual(B.CREDIT_PAGES[-1][-1], "THE LEGEND OF ZELDA")
        bosses = (Path(__file__).resolve().parents[1] / "src" / "bosses.s").read_text(encoding="utf-8")
        table = re.search(r"zelda_credit_pages:\n((?:\s+\.word .*\n)+)", bosses).group(1)
        self.assertEqual(re.findall(r"ENDING_CREDIT_(\d+)", table), [str(n) for n in range(len(B.CREDIT_PAGES))])

    def test_the_bomb_and_money_men_are_marked_in_byte_13_of_a_room_without_monsters(self) -> None:
        bombs = actors._room_info(0, ([0x0F], [0x80], [0], [0]), [1, 4, 5, 6], bytes(64), person=100, level=5)
        self.assertEqual((bombs[0], bombs[13]), (0, actors.PERSON_KIND_BOMBS))
        talker = actors._room_info(0, ([0x0F], [0x80], [0], [0]), [1, 4, 5, 6], bytes(64), person=100, level=3)
        self.assertEqual(talker[13], 0xFF, "in a table-B level $4F is only a talker")
        money = actors._room_info(0, ([0x11], [0x80], [0], [0]), [1, 4, 5, 6], bytes(64), person=100, level=5)
        self.assertEqual(money[13], actors.PERSON_KIND_MONEY)
        self.assertEqual(int.from_bytes(money[14:16], "big"), 100)

    def test_the_makefile_and_the_asset_builder_build_the_same_levels(self) -> None:
        make = (Path(__file__).resolve().parents[1] / "Makefile").read_text(encoding="utf-8")
        levels = tuple(int(n) for n in re.search(r"^UW_LEVELS := ([\d ]+)$", make, re.M).group(1).split())
        self.assertEqual(levels, tuple(B.UW_LEVELS))

    def test_the_reach_check_catches_a_branch_that_wraps(self) -> None:
        import tempfile
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import check_reach
        symbols = {"game_start": 0x2000, "near": 0x2100, "far": 0x2000 + 0x8100}
        listing = "\n".join([
            " 10 0000 4E71      \t    nop",
            " 11 0002 6100 00FA \t    bsr near",
            " 12 0006 6100 8100 \t    bsr far",            # 32,768 + bytes away: gas wraps it without a word
            " 13 000a 6700 0004 \t    beq.s far",
            " 14 000e 41FA 0000 \t    lea near(%pc), %a0",
        ])
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.lst"
            path.write_text(listing + "\n", encoding="utf-8")
            failures, checked, tight = check_reach.check_displacements(path, symbols)
        self.assertEqual(checked, 4)
        self.assertEqual(len(failures), 2)          # the word branch and the short one
        self.assertTrue(failures[0].startswith("bsr far"))
        self.assertEqual(tight[0][0] < 0, True)


if __name__ == "__main__":
    unittest.main()
