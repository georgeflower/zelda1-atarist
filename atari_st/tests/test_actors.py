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


class SpawnCloudTests(unittest.TestCase):
    """Which monsters come out of a spawn cloud is read from the ROM's initialisers, not listed by hand."""

    @unittest.skipUnless(HAS_ROM, "needs the ROM")
    def test_the_clouds_follow_the_roms_initialisers(self) -> None:
        clouds = actors.rom_spawn_clouds(ROM_ROOT)
        for octorok in (0x07, 0x08, 0x09, 0x0A):
            self.assertEqual(clouds[octorok], actors.SPAWN_CLOUD_LONG, hex(octorok))
        for walker in (0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x0D, 0x0E, 0x15, 0x1B, 0x28, 0x2A):
            self.assertEqual(clouds[walker], actors.SPAWN_CLOUD_SHORT, hex(walker))
        # leevers, zoras, peahats, boulders, ghinis, Gohma and Ganon are put down without one
        for at_once in (0x0F, 0x10, 0x11, 0x1A, 0x1F, 0x20, 0x22, 0x33, 0x34, 0x3E):
            self.assertEqual(clouds[at_once], actors.SPAWN_CLOUD_NONE, hex(at_once))
        # measured in the ROM's dungeons (tools/refnes/cloud_types.mjs): the wizzrobes, wallmaster, Lanmolas, Manhandla, Moldorm and
        # Gleeok clear their metastate themselves (InitMoldorm and the like store it by hand), the rest wait in the cloud
        for at_once in (0x23, 0x24, 0x27, 0x3A, 0x3B, 0x3C, 0x41, 0x43, 0x44, 0x45):
            self.assertEqual(clouds[at_once], actors.SPAWN_CLOUD_NONE, hex(at_once))
        for in_cloud in (0x2A, 0x2B, 0x31, 0x32, 0x37, 0x38, 0x3D, 0x47, 0x49):
            self.assertEqual(clouds[in_cloud], actors.SPAWN_CLOUD_SHORT, hex(in_cloud))

    @unittest.skipUnless(HAS_ROM, "needs the ROM")
    def test_the_dungeons_monsters_use_the_cloud_like_the_overworlds(self) -> None:
        clouds = actors.rom_spawn_clouds(ROM_ROOT)
        table = actors.monster_cloud_table(ROM_ROOT)
        self.assertEqual(len(table), len(actors.MONSTER_TYPES))
        for nes_type, cloud in zip(actors.MONSTER_TYPES, table):
            self.assertEqual(cloud, clouds.get(nes_type, actors.SPAWN_CLOUD_NONE), hex(nes_type))
        self.assertEqual(table[actors.MONSTER_TYPES.index(0x07)], actors.SPAWN_CLOUD_LONG)
        self.assertEqual(table[actors.MONSTER_TYPES.index(0x03)], actors.SPAWN_CLOUD_SHORT)
        self.assertEqual(table[actors.MONSTER_TYPES.index(0x0F)], actors.SPAWN_CLOUD_NONE)
        self.assertEqual(table[actors.MONSTER_TYPES.index(0x2A)], actors.SPAWN_CLOUD_SHORT)    # a stalfos in a dungeon

    def test_the_edge_walk_in_keeps_a_wider_berth_than_the_rom(self) -> None:
        text = (Path(__file__).resolve().parents[1] / "src" / "main.s").read_text(encoding="utf-8")
        safe = int(re.search(r"\.equ EDGE_SAFE_DIST, (0x[0-9a-fA-F]+|\d+)", text).group(1), 0)
        self.assertGreaterEqual(safe, 0x22)            # IsDistanceSafeToSpawn's $22 is the least it may be
        gap = int(re.search(r"\.equ EDGE_GAP_TICKS, (\d+)", text).group(1))
        self.assertGreaterEqual(gap, 2)                # the ROM waits 2 to 5 tenths of a second between monsters


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
        # the inventory screen's two tables: the ROM's item slot of each B code and the B code of each slot (8 slots, ROM order)
        code_slot = bytes_of("menu_code_slot", menu)
        raw = re.search(r"^menu_slot_code:\n\s+\.byte ([^\n]*)\n", menu, re.M).group(1)
        codes = {name: int(v) for name, v in re.findall(r"\.equ (B_[A-Z]+), (\d+)", items)}
        slot_code = [codes.get(n.strip(), 0) if not n.strip().isdigit() else int(n) for n in raw.split(",")]
        self.assertEqual(len(code_slot), last + 1)
        self.assertEqual(len(slot_code), 9)
        letter = codes["B_LETTER"]
        for code in range(1, last + 1):
            if code == letter:
                continue                                    # the letter sits where the potion would (menu_slot_code_of)
            self.assertIn(code, slot_code)
            self.assertEqual(slot_code[code_slot[code]], code)
        self.assertEqual(code_slot[letter], code_slot[codes["B_POTION"]])
        self.assertEqual(actors.HUD_ITEM_IDS[icons[letter]], 0x15)    # the letter's own picture

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

    def test_a_count_longer_than_its_list_reads_on_into_the_next_list(self) -> None:
        # ObjLists is read straight on: list $68 has five entries, the screens $38 and $49 (foe count 6) take the next list's first one
        lists = [[0x09, 0x08, 0x08, 0x08, 0x08], [0x08, 0x07, 0x08, 0x07]]       # $68 and $69
        self.assertEqual(actors.listed_types(lists, 0x62, 6), [0x09, 0x08, 0x08, 0x08, 0x08, 0x08])
        self.assertEqual(actors.listed_types(lists, 0x63, 4), [0x08, 0x07, 0x08, 0x07])
        self.assertEqual(actors.listed_types(lists, 0x62, 5), lists[0])

    @unittest.skipUnless(HAS_ROM, "needs the ROM")
    def test_screens_38_and_49_have_six_octoroks_as_in_the_rom(self) -> None:
        block = B.require_binary(ROM_ROOT, B.LEVEL_BLOCK_OW_NAME)
        info = B.require_binary(ROM_ROOT, B.LEVEL_INFO_OW_NAME)
        foe = list(info[B.LEVEL_INFO_FOE_COUNTS:B.LEVEL_INFO_FOE_COUNTS + 4])
        size = B.LEVEL_BLOCK_TABLE_SIZE
        lists = actors.overworld_monster_lists(ROM_ROOT)
        for room in (0x38, 0x49):
            types = actors.overworld_room_types(lists, block[2 * size + room], block[3 * size + room], foe)
            self.assertEqual(sorted(types), [0x08] * 5 + [0x09])

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

    def test_the_blade_trap_enemy_s_names_by_index_comes_from_the_build(self) -> None:
        # uw.s keeps the blade traps coming back in a cleared room by their mon_table index; the
        # numbers are generated (a hard-coded one went wrong when the black keese joined the table)
        for name in ("uw.s",):
            source = (Path(__file__).resolve().parents[1] / "src" / name).read_text(encoding="utf-8")
            self.assertIn("MON_TRAP_INDEX", source)
            self.assertNotRegex(source, r"\.equ MON_(TRAP|LANMOLA)_INDEX")
        builder = (Path(__file__).resolve().parents[1] / "tools" / "build_assets.py").read_text(encoding="utf-8")
        self.assertIn("MON_TRAP_INDEX, {uw.actors.mon_index[0x49]}", builder)
        self.assertIn("MON_LANMOLA_INDEX, {uw.actors.mon_index[0x3A]}", builder)

    def test_the_rope_has_its_two_walk_frames_in_every_sprite_palette_row(self) -> None:
        # the Second Quest's rope flashes through the four rows a frame (UpdateRope: attribute = FrameCounter & 3); enemy.s picks
        # image = walk frame + 2 * row, and the First Quest's red row stays what the rope always had
        _, images, mode = actors.MONSTER_DRAW[0x28]
        self.assertEqual((images, mode), (2 * actors.ROPE_PALETTES, actors.MODE_ROPE))
        self.assertIn(actors.MODE_ROPE, actors.FRAME_MODES)
        source = (Path(__file__).resolve().parents[1] / "src" / "enemy.s").read_text(encoding="utf-8")
        self.assertEqual(int(re.search(r"\.equ ROPE_RED_ROW,\s*(\d+)", source).group(1)), actors.ROPE_RED_ROW)
        self.assertEqual(actors.ROPE_PALETTES, 4)

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

    def test_the_flying_ghini_flies_and_the_armos_walks(self) -> None:
        # UpdateArmos is UpdateGoriya (the armos walks, at q-speed $20 or $60 by chance), UpdateFlyingGhini flies; neither is listed for a screen
        self.assertIn(0x22, actors.MONSTER_TYPES)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x22], actors.BEHAVIOUR_ARMOS)
        self.assertEqual(actors.MONSTER_BEHAVIOUR[0x1E], actors.BEHAVIOUR_ARMOS)
        self.assertEqual(actors.MONSTER_DRAW[0x22], actors.MONSTER_DRAW[0x21])   # drawn like a ghini
        self.assertIn(0x22, actors.MONSTER_FLYERS)
        self.assertNotIn(0x1E, actors.MONSTER_FLYERS)
        self.assertIn(0x22, actors.OVERWORLD_ART)
        self.assertNotIn(0x22, actors.OVERWORLD_LISTED)
        self.assertEqual(actors.MONSTER_DAMAGE[0x22], 2)    # ObjTypeToDamagePoints $01
        self.assertNotIn(0x1E, actors.ROM_QSPEED)           # no walker any more

    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_every_monster_has_a_picture_start(self) -> None:
        data = rom_actors()
        self.assertEqual(len(data.mon_art), 2 * (len(data.mon_table) // 8))

    def test_walking_speeds_are_the_roms_q_speeds(self) -> None:
        # A q-speed is a 64th of a pixel a frame, so eight frames cover q/8 pixels: $20 is four, $30 six, $40 eight.
        source = (Path(__file__).resolve().parents[1] / "src" / "enemy.s").read_text(encoding="utf-8")
        row = re.search(r"step_patterns:\n\s*\.byte ([^\n]+)", source).group(1)
        patterns = [int(value, 16) for value in row.split(",")]
        for nes_type, q_speed in actors.ROM_QSPEED.items():
            period = actors.MONSTER_PERIOD[nes_type]
            if period >= actors.PERIOD_PATTERN:
                pixels = bin(patterns[period - actors.PERIOD_PATTERN]).count("1")
            else:
                pixels = 8 // period
            self.assertEqual(pixels * 8, q_speed, f"type {nes_type:#04x}")

    def test_the_fast_octoroks_take_six_pixels_in_eight_frames(self) -> None:
        # InitFastOctorock: q-speed $30, 0.75 pixels a frame (a whole pixel a frame was too fast)
        for nes_type in (0x08, 0x0A):
            self.assertEqual(actors.ROM_QSPEED[nes_type], 0x30)
            self.assertEqual(actors.MONSTER_PERIOD[nes_type], actors.PERIOD_PATTERN + 2)

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
        self.assertEqual(len(data.fx_sprites), 23 * B.SPRITE_FRAME_BYTES)     # 2 clouds, 4 corners x 4 rows, 2 fires, the third cloud, the death spark's two

    def test_trap_rooms_hold_four_or_six_traps(self) -> None:
        trap = actors.MONSTER_TYPES.index(0x49)
        attrs = ([0x0A], [0x80], [0], [0])      # list id $4A: attribute C & $3F plus $40 from attribute D
        record = actors._room_info(0, attrs, [3, 5, 6, 8], bytes(64))
        self.assertEqual(list(record[6:10]), [trap] * 4)
        self.assertEqual(record[0], 4)

    def test_the_push_block_flag_is_bit_7_of_the_trigger_byte(self) -> None:
        # attribute D bit 6 makes FindAndCreatePushBlockObject run, whatever the secret trigger is
        # (room $22, the bow room, has the block but trigger 0; room $42 has block and trigger 4)
        # (attribute D bit 7 makes the list id $40, a list that never comes back: bit 3 as well)
        for attr_d, attr_f, want in ((0xDA, 0x00, 0x88), (0x62, 0x04, 0x84), (0x1F, 0x07, 0x07), (0x80, 0x00, 0x08)):
            record = actors._room_info(0, ([0], [attr_d], [0], [attr_f]), [3, 5, 6, 8], bytes(64))
            self.assertEqual(record[1], want, f"D {attr_d:#x} F {attr_f:#x}")

    def test_statue_rooms_carry_how_many_statues_shoot(self) -> None:
        # byte 5 bits 3-4: attribute D & $3F = $24 is a room of four shooting statues (1), $23 one of two (2), any other layout none;
        # the dark flag (bit 7) and the roar (bits 5-6) stay where they were
        for layout, want in ((0x24, 1), (0x23, 2), (0x25, 0), (0x00, 0)):
            record = actors._room_info(0, ([0], [layout], [0xA0], [0]), [1, 4, 5, 6], bytes(64))
            self.assertEqual((record[5] >> 3) & 3, want, f"layout {layout:#x}")
            self.assertEqual(record[5] & 0xE0, 0xA0, f"layout {layout:#x}")

    def test_bosses_and_single_big_monsters_are_marked_as_never_coming_back(self) -> None:
        # trigger bit 3: the object lists $32-$48 (but not the lanmolas $3A/$3B) stay dead; every other list recurs
        for list_id, never in ((0x01, False), (0x31, False), (0x32, True), (0x3C, True), (0x3A, False), (0x3B, False),
                               (0x48, True), (0x49, False)):
            attrs = ([list_id & 0x3F], [0x80 if list_id & 0x40 else 0], [0], [0])
            record = actors._room_info(0, attrs, [1, 4, 5, 6], bytes(64))
            self.assertEqual(bool(record[1] & 0x08), never, f"list {list_id:#x}")

    def test_a_lone_moldorm_becomes_two_worms_of_five_segments(self) -> None:
        segment = actors.MONSTER_TYPES.index(0x41)
        attrs = ([0x22], [0x80], [0], [0])      # list id $62, the first of the ObjLists: here a single Moldorm
        record = actors._room_info(0, attrs, [1, 4, 5, 6], bytes(64), lists=[[0x41]])
        self.assertEqual(actors.MOLDORM_SEGMENTS, 10)
        self.assertEqual(record[0], actors.MOLDORM_SEGMENTS)
        self.assertEqual(list(record[6:14]), [segment] * 8, "the record holds eight; the spawner repeats the last for the rest")

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

    def test_zelda_comes_with_four_guard_fires_and_patra_with_eight_children(self) -> None:
        zelda = actors.MONSTER_TYPES.index(0x37)
        fire = actors.MONSTER_TYPES.index(0x3F)
        record = actors._room_info(0, ([0x37], [0x00], [0], [0]), [1, 4, 5, 6], bytes(64))   # list id $37: one Zelda
        self.assertEqual(record[0], 5)
        self.assertEqual(list(record[6:11]), [zelda] + [fire] * 4)
        self.assertEqual(record[5] & 0x7F, 0, "nothing unsupported")
        eye = actors.MONSTER_TYPES.index(0x47)
        child = actors.MONSTER_TYPES.index(0x25)
        record = actors._room_info(0, ([0x07], [0x80], [0], [0]), [1, 4, 5, 6], bytes(64))   # list id $47
        self.assertEqual(actors.PATRA_CHILDREN, 8)
        self.assertEqual(record[0], 1 + actors.PATRA_CHILDREN)
        self.assertEqual(list(record[6:14]), [eye] + [child] * 7)

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
        self.assertEqual(B.ENDING_TEXTS, B.ENDING_THANKS_TEXT + B.ENDING_PEACE_TEXT)
        self.assertTrue(B.AssetBundle.__dataclass_fields__["cave_text"].default.endswith(B.ENDING_TEXTS))

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


class SwordTests(unittest.TestCase):
    """The sword's reach and the darknuts' shields follow Z_01.asm and Z_07.asm."""

    SRC = Path(__file__).resolve().parents[1] / "src"
    ROM_SRC = Path(__file__).resolve().parents[2] / "src"

    @staticmethod
    def _bytes(block: str) -> list[int]:
        def value(expr: str) -> int:   # a sum of terms such as -1+6-8
            return sum(int(term.replace(" ", ""), 0) for term in re.findall(r"[+-]?\s*\w+", expr))

        return [value(v) for line in re.findall(r"\.byte ([^|\n]+)", block) for v in line.split(",")]

    def test_the_sword_box_is_the_roms_stabbing_collision(self) -> None:
        z07 = (self.ROM_SRC / "Z_07.asm").read_text(encoding="utf-8")
        offsets = {}
        for axis in ("X", "Y"):
            block = z07.split(f"PlayerToWeaponOffsets{axis}:", 1)[1].split("\n\n", 1)[0]
            values = [int(h, 16) for h in re.findall(r"\$([0-9A-F]{2})", block)]
            offsets[axis] = [v - 256 if v >= 0x80 else v for v in values[4:8]]   # state 2: up, down, left, right
        combat = (self.SRC / "combat.s").read_text(encoding="utf-8")
        drawn = self._bytes(combat.split("sword_offsets:", 1)[1].split(".align", 1)[0])[:8]
        self.assertEqual(drawn, [v for pair in zip(offsets["X"], offsets["Y"]) for v in pair])
        box = self._bytes(combat.split("sword_box:", 1)[1].split("\n\n", 1)[0])
        self.assertEqual(len(box), 16)
        for index in range(4):
            vertical = index < 2
            # CheckMonsterSlenderWeaponCollision2: the blade's middle is +6,+8 (up, down) or +8,+6 (sideways),
            # GetObjectMiddle puts the monster's at +8,+8; CheckMonsterStabbingCollision's thresholds $C and $10
            mid_x, mid_y = (6, 8) if vertical else (8, 6)
            reach = (0x0C, 0x10) if vertical else (0x10, 0x0C)
            expected = [offsets["X"][index] + mid_x - 8, offsets["Y"][index] + mid_y - 8, *reach]
            self.assertEqual(box[4 * index : 4 * index + 4], expected, index)

    def test_a_darknut_turns_aside_only_a_blow_from_the_front(self) -> None:
        dmon = (self.SRC / "dmon.s").read_text(encoding="utf-8")
        shield = dmon.split("| the shield:", 1)[1].split("5:", 1)[0]
        self.assertIn("or.b OFF_ENEMY_DIR(%a5, %d5.w), %d0", shield)
        blocked_by = {int(v, 0) for v in re.findall(r"cmp\.b #(0x[0-9a-fA-F]+), %d0\n\s+beq 7f", shield)}
        self.assertEqual(blocked_by, {0x0C, 0x03})      # HandleMonsterWeaponCollision @CheckDarknut
        right, left, down, up = 1, 2, 4, 8
        opposite = {right: left, left: right, down: up, up: down}
        for darknut in (right, left, down, up):
            for blade in (right, left, down, up):
                blocked = (blade | darknut) in blocked_by
                self.assertEqual(blocked, blade == opposite[darknut], (blade, darknut))


if __name__ == "__main__":
    unittest.main()


class CellarOverrunTests(unittest.TestCase):
    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_level_3_stairs_lead_to_the_raft_room(self):
        """Level 3's cellar array is empty, but CheckWarps goes on reading past it and finds $0F (A and B both $69) 72 bytes on:
        the raft's cellar, below the stairs of room $69. The port has to build that cellar like a listed one."""
        import underworld as U
        blk = U.level_block(ROM_ROOT, 3)
        info = U.level_info(ROM_ROOT, 3)
        a, b, d = blk[0:128], blk[128:256], blk[384:512]
        e = blk[512:640]
        self.assertEqual(U.cellar_rooms(info, d), [])                         # the listed array has nothing
        cellars = U.cellar_rooms(info, d, a, b, info[B.LEVEL_INFO_START_ROOM_ID])
        self.assertEqual(cellars, [0x0F])
        self.assertEqual((a[0x0F], b[0x0F]), (0x69, 0x69))
        self.assertEqual(e[0x0F] & 0x1F, 0x0C)                                # the Raft
        self.assertNotIn(0x0F, U.level_rooms(info[B.LEVEL_INFO_START_ROOM_ID], info, a, b, d))

    @unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
    def test_the_other_levels_keep_the_cellars_their_arrays_list(self):
        import underworld as U
        for quest in (0, 1):
            for level in range(1, 10):
                if (quest, level) == (0, 3):
                    continue
                blk = U.level_block(ROM_ROOT, level, quest)
                info = U.level_info(ROM_ROOT, level, quest)
                a, b, d = blk[0:128], blk[128:256], blk[384:512]
                self.assertEqual(U.cellar_rooms(info, d, a, b, info[B.LEVEL_INFO_START_ROOM_ID]), U.cellar_rooms(info, d),
                                 f"quest {quest + 1} level {level}")


class DodongoBombCountTests(unittest.TestCase):
    def test_bomb_count_is_not_kept_in_a_variable_the_walker_clears(self) -> None:
        """The Dodongo's swallowed bombs (ROM Dodongo_ObjBombHits) must outlive its walks. They once lived in ENEMY_WANT,
        which wander_tick clears at every square boundary, so only two bombs swallowed without a step between them
        killed it and the player needed five or six."""
        source = (Path(__file__).resolve().parents[1] / "src" / "ai.s").read_text(encoding="utf-8")
        start = source.index("dodongo_ai:")
        end = source.index("dodongo_waits:")
        body = source[start:end]
        self.assertNotIn("OFF_ENEMY_WANT", body)
        self.assertIn("OFF_ENEMY_BOMBS", body)
        wander = source[source.index("wander_tick:"):source.index("goriya_ai:")]
        self.assertIn("clr.b ENEMY_STRIDE(%a0, %d5.w)", wander)   # the reason the count needs a variable of its own


@unittest.skipUnless(HAS_ROM, "needs ext/Original.nes")
class RoomItemCarrierTests(unittest.TestCase):
    """MoveAndDrawRoomItem: a like-like, stalfos or gibdo that is the first monster of a room carries its item along."""

    CARRIER_ROOMS = {(1, 0x33): 0x2A, (1, 0x74): 0x2A, (5, 0x65): 0x30, (5, 0x66): 0x30, (7, 0x5A): 0x2A, (7, 0x6D): 0x2A}

    def record(self, level: int, room: int) -> bytes:
        gen = ROM_ROOT / "atari_st" / "build" / "generated"
        index = (gen / f"uw{level}_room_index.bin").read_bytes()
        info = (gen / f"uw{level}_room_info.bin").read_bytes()
        return info[index[room] * 16:(index[room] + 1) * 16]

    def test_the_rooms_the_rom_audit_found_have_a_carrier_first_and_an_item(self) -> None:
        for (level, room), nes_type in self.CARRIER_ROOMS.items():
            record = self.record(level, room)
            self.assertEqual(record[6], actors.MONSTER_TYPES.index(nes_type), f"level {level} room {room:02X}")
            self.assertNotEqual(record[2], 0xFF, f"level {level} room {room:02X} has an item")

    def test_the_follow_routine_handles_exactly_the_rom_carriers(self) -> None:
        source = (Path(__file__).resolve().parents[1] / "src" / "combat.s").read_text(encoding="utf-8")
        body = source[source.index("room_item_follow:"):source.index("item_pickup:")]
        for monster in ("MON_LIKELIKE", "MON_STALFOS", "MON_GIBDO"):
            self.assertIn(monster, body)
        self.assertIn("OFF_ITEM_ACTIVE", body)

