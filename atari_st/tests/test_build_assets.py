from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
import sys
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import build_assets  # noqa: E402


# A fixture for the palette and sprite helper tests (sixteen distinct colours); nothing of it is shipped.
TEST_NES_PALETTE = bytes(
    (
        0x0F, 0x30, 0x00, 0x12,
        0x0F, 0x16, 0x27, 0x36,
        0x0F, 0x1A, 0x37, 0x17,
        0x0F, 0x29, 0x02, 0x22,
        0x0F, 0x0C, 0x1C, 0x2C,
        0x0F, 0x30, 0x27, 0x17,
        0x0F, 0x16, 0x27, 0x30,
        0x0F, 0x0C, 0x1C, 0x2C,
    )
)


def _write_fake_rom(root: Path, blobs: dict[str, bytes]) -> None:
    """Lay the named blobs into a synthetic iNES image at PRG-relative offsets."""
    (root / "src").mkdir(exist_ok=True)
    (root / "ext").mkdir(exist_ok=True)

    trainer = bytes([0xAA]) * 512
    prg_rom = bytearray([0x55]) * (64 * 1024)
    entries = []
    offset = 0x100
    for name, data in blobs.items():
        prg_rom[offset : offset + len(data)] = data
        entries.append(f"<Binary Offset='{offset}' Length='{len(data)}' FileName='{name}'/>")
        offset += len(data)

    (root / "src" / "bins.xml").write_text(f"<Binaries>{''.join(entries)}</Binaries>", encoding="utf-8")
    (root / "ext" / "Original.nes").write_bytes(
        b"NES\x1a" + bytes([4, 0, 0x04]) + bytes(9) + trainer + bytes(prg_rom)
    )


class LevelIncludeTests(unittest.TestCase):
    def test_boss_room_and_stairs_use_separate_level_record_bytes(self) -> None:
        level = SimpleNamespace(
            level=5, key="5", start_room=0x65, start_y=0xDD, triforce_room=0x14,
            map_col0=2, cellar_info=[b""], boss_room=0x15, stairs_first=120,
        )
        record = build_assets.level_include([level]).split("level_table:\n", 1)[1]
        data = record.split("    .byte ", 1)[1].split("\n", 1)[0].strip()
        self.assertEqual(
            [int(value.strip(), 0) for value in data.split(",")],
            [0x65, 0xDD, 0x14, 2, 1, 0x15, 120, 0],
        )
        self.assertIn('.asciz "LEVEL5.DAT"', record)       # then the name of the level's file
        self.assertEqual(build_assets.LEVEL_RECORD_BYTES, 8 + build_assets.LEVEL_NAME_BYTES)


class ExtractionTests(unittest.TestCase):
    def test_bins_offsets_are_prg_relative(self) -> None:
        # Zelda uses CHR-RAM, so the iNES header reports zero CHR banks and every
        # blob lives inside PRG ROM. Offsets are therefore relative to the end of
        # the header plus trainer, not to the end of PRG.
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            marker = bytes(range(32))
            _write_fake_rom(root, {"dat/Marker.dat": marker})
            self.assertEqual(build_assets.extract_binary(root, "dat/Marker.dat"), marker)

    def test_invalid_rom_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "src").mkdir()
            (root / "ext").mkdir()
            (root / "src" / "bins.xml").write_text(
                "<Binaries><Binary Offset='0' Length='704' FileName='dat/CommonBackgroundPatterns.dat'/></Binaries>",
                encoding="utf-8",
            )
            (root / "ext" / "Original.nes").write_bytes(b"BAD!")

            with self.assertRaises(ValueError):
                build_assets.load_assets(root)


class DisassemblyParsingTests(unittest.TestCase):
    def test_asm_byte_table_parsing(self) -> None:
        asm = "\n".join(
            [
                "Preceding:",
                "    .BYTE $01",
                "",
                "Wanted:",
                "    .BYTE $DB, $5B, $5B",
                "    .BYTE $1B, $0E",
                "",
                "Next:",
                "    .BYTE $FF",
            ]
        )
        self.assertEqual(
            build_assets.parse_asm_byte_table("\n" + asm, "Wanted"), [0xDB, 0x5B, 0x5B, 0x1B, 0x0E]
        )

    def test_column_directory_entries_become_blob_offsets(self) -> None:
        asm = "\nColumnDirectoryOW:\n    .BYTE $D8, $9B, $0D, $9C, $3E, $9C\n"
        self.assertEqual(build_assets.parse_column_directory(asm), [0, 0x35, 0x66])

    def test_column_repeat_flag_draws_a_square_twice(self) -> None:
        # Bit 7 opens the column, bit 6 marks a square that is drawn twice.
        heap = [0x80 | 0x40 | 0x05, 0x06] + [0x07] * 20
        squares = build_assets.decode_column(heap, 0, 0)
        self.assertEqual(len(squares), build_assets.OW_ROOM_ROWS)
        self.assertEqual(squares[:3], [0x05, 0x05, 0x06])

    def test_square_quads_are_reordered_from_column_major(self) -> None:
        primary = [0] * 0x40
        primary[0x10] = 0x40
        # WriteSquareOW stores (col,row), (col,row+1), (col+1,row), (col+1,row+1).
        self.assertEqual(
            build_assets.square_to_tiles(0x10, primary, []), (0x40, 0x42, 0x41, 0x43)
        )

        secondary = [0x10, 0x11, 0x12, 0x13]
        self.assertEqual(
            build_assets.square_to_tiles(0, [], secondary), (0x10, 0x12, 0x11, 0x13)
        )


class PaletteTests(unittest.TestCase):
    def test_all_eight_nes_rows_share_one_st_palette(self) -> None:
        palette = build_assets.build_palette_map(TEST_NES_PALETTE)
        self.assertEqual(len(palette.st_colors), build_assets.ST_PALETTE_SIZE)
        for row in range(build_assets.PALETTE_ROWS):
            for pixel in range(build_assets.PALETTE_ROW_COLORS):
                self.assertLess(palette.index(row, pixel), build_assets.ST_PALETTE_SIZE)

    def test_pixel_zero_is_the_shared_backdrop_in_every_row(self) -> None:
        palette = build_assets.build_palette_map(TEST_NES_PALETTE)
        backdrop = palette.index(0, 0)
        for row in range(build_assets.PALETTE_ROWS):
            self.assertEqual(palette.index(row, 0), backdrop)

    def test_duplicate_nes_colours_share_one_st_entry(self) -> None:
        # Row 1 pixel 1 repeats row 0 pixel 1, so both must land on the same entry.
        nes_palette = bytes([0x0F, 0x30, 0x00, 0x12] + [0x0F, 0x30, 0x16, 0x27] + [0x0F] * 24)
        palette = build_assets.build_palette_map(nes_palette)
        self.assertEqual(palette.index(0, 1), palette.index(1, 1))

    def test_more_than_sixteen_colours_is_rejected(self) -> None:
        # Seventeen distinct colours cannot fit the ST's single 16-entry palette.
        nes_palette = bytes([0x0F] + list(range(0x01, 0x20)) + [0x0F] * 12)[:32]
        with self.assertRaises(SystemExit):
            build_assets.build_palette_map(nes_palette)


class CollisionTests(unittest.TestCase):
    def test_tiles_below_the_threshold_are_walkable(self) -> None:
        self.assertFalse(build_assets.tile_is_blocking(0x00))
        self.assertFalse(build_assets.tile_is_blocking(build_assets.OW_FIRST_UNWALKABLE_TILE - 1))

    def test_tiles_at_or_above_the_threshold_block(self) -> None:
        self.assertTrue(build_assets.tile_is_blocking(build_assets.OW_FIRST_UNWALKABLE_TILE))
        self.assertTrue(build_assets.tile_is_blocking(0xFF))

    def test_exception_list_stays_walkable(self) -> None:
        # GetCollidableTile rewrites these to a walkable value before the test,
        # even though they sort above ObjectFirstUnwalkableTile.
        for tile in build_assets.OW_WALKABLE_TILES:
            self.assertGreaterEqual(tile, build_assets.OW_FIRST_UNWALKABLE_TILE)
            self.assertFalse(build_assets.tile_is_blocking(tile))


class SpriteTests(unittest.TestCase):
    def _solid_tiles(self) -> list[list[list[int]]]:
        tiles = [[[0] * 8 for _ in range(8)] for _ in range(256)]
        # Mark only the leftmost column of the top-left tile so flipping is visible.
        for row in range(8):
            tiles[0][row][0] = 1
        return tiles

    def test_frame_is_masked_where_the_nes_pixel_is_transparent(self) -> None:
        palette = build_assets.build_palette_map(TEST_NES_PALETTE)
        frame = build_assets.build_sprite_frame(self._solid_tiles(), palette, 4, 0, flip=False)
        self.assertEqual(len(frame), build_assets.SPRITE_FRAME_BYTES)
        mask = int.from_bytes(frame[8:10], "big")
        self.assertEqual(mask, 0x8000)

    def test_horizontal_flip_mirrors_the_row(self) -> None:
        palette = build_assets.build_palette_map(TEST_NES_PALETTE)
        frame = build_assets.build_sprite_frame(self._solid_tiles(), palette, 4, 0, flip=True)
        mask = int.from_bytes(frame[8:10], "big")
        self.assertEqual(mask, 0x0001)


ROM_ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomOverworldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = build_assets.load_assets(ROM_ROOT)

    def test_whole_overworld_is_decoded(self) -> None:
        rooms = self.bundle.rooms
        self.assertEqual(len(rooms), build_assets.OW_ROOM_COUNT)
        for room in rooms:
            self.assertEqual(len(room), build_assets.OW_ROOM_COLS * build_assets.OW_ROOM_ROWS)
            self.assertLess(max(room), len(self.bundle.metatiles))
        # All 121 unique layouts are in use; a 6-bit id would only reach 64.
        self.assertEqual(len(set(self.bundle.room_attrs_d[r] & 0x7F for r in range(len(rooms)))), 121)
        self.assertGreaterEqual(len({tuple(room) for room in rooms}), 100)

    def _secrets(self):
        records = {}
        data = self.bundle.room_secrets
        size = build_assets.OW_SECRET_BYTES
        self.assertEqual(len(data), build_assets.OW_ROOM_COUNT * size + build_assets.OW_EXTRA_BYTES + build_assets.OW_FLUTE_BYTES)
        for room in range(build_assets.OW_ROOM_COUNT):
            record = data[room * size : (room + 1) * size]
            if record[0]:
                records[room] = record
        return records

    def test_secret_markers_are_drawn_as_the_squares_they_imitate(self) -> None:
        # The markers' own tiles ($E5-$EE: squares 38-43) must not reach a screen; the ROM draws the plain square.
        marker_tiles = set(range(0xE5, 0xEE))
        for _, quad in self.bundle.metatiles:
            self.assertFalse(marker_tiles & set(quad), quad)

    def test_secret_records_match_the_first_quest_spots(self) -> None:
        records = self._secrets()
        kinds = [record[0] for record in records.values()]
        self.assertEqual(kinds.count(build_assets.OW_SECRET_ROCK), 4)       # 1D, 23, 49 and 79
        self.assertEqual(kinds.count(build_assets.OW_SECRET_GRAVE), 1)      # 21
        self.assertEqual(sorted(room for room, r in records.items() if r[0] == build_assets.OW_SECRET_ROCK),
                         [0x1D, 0x23, 0x49, 0x79])
        self.assertEqual(sorted(room for room, r in records.items() if r[0] == build_assets.OW_SECRET_GRAVE), [0x21])
        self.assertEqual(kinds.count(build_assets.OW_SECRET_BOMB), 22)
        self.assertEqual(kinds.count(build_assets.OW_SECRET_TREE), 16)
        # Spots of the second quest only (attribute F bits 6-7 = 2) are plain scenery here.
        for room, record in records.items():
            self.assertNotEqual(self.bundle.room_attrs_f[room] >> 6, build_assets.QUEST_SECOND_ONLY, hex(room))
        self.assertNotIn(0x00, records)     # room 0's bomb wall belongs to the second quest

    def test_secret_records_point_inside_the_screen_and_at_real_metatiles(self) -> None:
        count = len(self.bundle.metatiles)
        squares = build_assets.OW_ROOM_COLS * build_assets.OW_ROOM_ROWS
        for room, record in self._secrets().items():
            kind, spot, after, stairs_at, stairs, above, below, spare = record
            self.assertLess(spot, squares, hex(room))
            self.assertLess(after, count, hex(room))
            self.assertEqual(spare, 0)
            if kind in (build_assets.OW_SECRET_ROCK, build_assets.OW_SECRET_GRAVE):
                self.assertLess(stairs_at, squares, hex(room))
                self.assertLess(stairs, count, hex(room))
                for moved, edge in ((above, spot < build_assets.OW_ROOM_COLS),
                                    (below, spot >= squares - build_assets.OW_ROOM_COLS)):
                    self.assertEqual(moved == 0xFF, edge, hex(room))
                    if not edge:
                        self.assertLess(moved, count, hex(room))
            else:
                self.assertEqual((stairs_at, stairs, above, below), (0, 0, 0, 0), hex(room))

    def _extra(self):
        data = self.bundle.room_secrets
        first = build_assets.OW_ROOM_COUNT * build_assets.OW_SECRET_BYTES
        return data[first : first + build_assets.OW_EXTRA_BYTES]

    def test_the_extra_table_holds_the_pond_stairs_and_the_armos_squares(self) -> None:
        extra = self._extra()
        count = len(self.bundle.metatiles)
        self.assertEqual(len(extra), build_assets.OW_EXTRA_BYTES)
        self.assertEqual(extra[1], build_assets.POND_STAIRS_SQUARE)
        self.assertLess(extra[0], count)
        end = extra.index(0xFF, 2)
        self.assertEqual((end - 2) % 3, 0)
        self.assertGreaterEqual(end - 2, 3)             # at least one armos metatile (one per palette slot)
        self.assertEqual(set(extra[end + 1:]), {0})     # padding
        for i in range(2, end, 3):
            armos, floor, stairs = extra[i : i + 3]
            self.assertEqual(sorted(self.bundle.metatiles[armos][1]), list(build_assets.ARMOS_TILES))
            self.assertNotEqual(sorted(self.bundle.metatiles[floor][1]), list(build_assets.ARMOS_TILES))
            self.assertLess(stairs, count)

    def test_the_armos_and_the_pond_screen_are_where_the_rom_has_them(self) -> None:
        armos = {self._extra()[i] for i in range(2, self._extra().index(0xFF, 2), 3)}
        screens = [room for room, grid in enumerate(self.bundle.rooms) if armos & set(grid)]
        self.assertEqual(len(screens), 12)
        for room in (0x24, 0x0B, 0x1C, 0x22, 0x34, 0x3D, 0x4E):      # SecretArmosRoomIds
            self.assertIn(room, screens)
        grid = self.bundle.rooms[build_assets.POND_ROOM]
        pond = grid[build_assets.POND_STAIRS_SQUARE]
        self.assertNotEqual(pond, self._extra()[0])     # the water is still water until the tune

    def test_the_rock_in_a_diamond_uncovers_its_middle(self) -> None:
        # Room 79: the pushable rock is the left corner of a ring of four, and the stairs lie in the middle.
        record = self._secrets()[0x79]
        self.assertEqual(record[1], 5 * 16 + 8)     # the rock
        self.assertEqual(record[3], 5 * 16 + 9)     # the stairs
        # The gravestone of room 21 stands on the stairs it uncovers.
        grave = self._secrets()[0x21]
        self.assertEqual(grave[1], grave[3])

    def test_start_position_comes_from_level_info(self) -> None:
        self.assertEqual(self.bundle.start_room, 0x77)
        self.assertEqual(self.bundle.start_y, 0x8D)
        self.assertEqual(build_assets.LINK_START_X, 0x78)


class UnderworldGeometryTests(unittest.TestCase):
    def test_door_faces_cover_twelve_distinct_tiles_inside_the_map(self) -> None:
        import underworld

        for direction in range(4):
            cells = underworld.door_cells(direction)
            self.assertEqual(len(set(cells)), underworld.DOOR_TILE_COUNT)
            self.assertTrue(all(0 <= cell < underworld.UW_ROOM_BYTES for cell in cells))

    def test_door_types_come_from_the_attribute_bytes(self) -> None:
        import underworld

        # Level 1's start room: attrs A=$A2, B=$03 -> N key door, S open, E/W open.
        self.assertEqual(
            [underworld.door_type(0xA2, 0x03, d) for d in range(4)], [0, 0, 0, 5]
        )

    def test_minimap_window_is_centred_and_wraps_past_column_fifteen(self) -> None:
        import underworld

        # Columns 1..6 (level 1): six wide, so one spare column each side.
        self.assertEqual(underworld.minimap_first_column([0x41, 0x22, 0x36, 0x73]), 0)
        # Level 2 spans columns 12..15 and 0: the window starts before column 12.
        first = underworld.minimap_first_column([0x7D, 0x0D, 0x0E, 0x1F, 0x70, 0x6C])
        self.assertEqual(first, 11)
        for room in (0x7D, 0x0D, 0x0E, 0x1F, 0x70, 0x6C):
            self.assertLess(((room & 15) - first) & 15, 8)
        with self.assertRaises(SystemExit):
            underworld.minimap_first_column([0x00, 0x04, 0x08])    # needs ten columns


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomUnderworldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.uw = build_assets.load_assets(ROM_ROOT).uw

    def test_level_one_has_seventeen_rooms_from_the_start_room(self) -> None:
        stored = [room for room, index in enumerate(self.uw.room_index) if index != 0xFF]
        self.assertEqual(len(stored), 17)
        self.assertIn(self.uw.start_room, stored)
        self.assertEqual(self.uw.start_room, 0x73)

    def test_level_one_map_window_holds_every_room_and_the_triforce_marker(self) -> None:
        stored = [room for room, index in enumerate(self.uw.room_index) if index != 0xFF]
        for room in stored:
            self.assertLess((room - self.uw.map_col0) & 15, 8)
        self.assertEqual(self.uw.triforce_room, 0x36)
        self.assertIn(self.uw.triforce_room, stored)

    def test_locked_door_has_a_different_open_face(self) -> None:
        import underworld

        index = self.uw.room_index[0x73]
        room = self.uw.rooms[index]
        north_closed = [room[underworld._col_major_to_cell(c)] for c in underworld.door_cells(3)]
        self.assertNotEqual(north_closed, self.uw.open_faces[index][3])

    def test_every_room_uses_tiles_the_bank_holds(self) -> None:
        for room in self.uw.rooms:
            self.assertLess(max(room), len(self.uw.tile_nes))


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomAllDungeonsTests(unittest.TestCase):
    ROOMS = {1: 17, 2: 18, 3: 18, 4: 20, 5: 23, 6: 25, 7: 33, 8: 25, 9: 57}

    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = build_assets.load_assets(ROM_ROOT)

    def test_every_dungeon_has_its_rooms_and_a_triforce_room_among_them(self) -> None:
        for level, count in self.ROOMS.items():
            uw = self.bundle.levels[level - 1]
            stored = [room for room, index in enumerate(uw.room_index) if index != 0xFF]
            self.assertEqual(len(stored), count, level)
            self.assertIn(uw.triforce_room, stored, level)
            self.assertIn(uw.start_room, stored, level)

    def test_levels_with_a_stairs_block_carry_the_four_stairs_tiles_in_their_bank(self) -> None:
        # CheckSecretTriggerBlockStairs: trigger 5 (Levels 4, 5, 6, 7 and 9) puts tiles $70-$73 at ($D0, $60)
        for level in range(1, 10):
            uw = self.bundle.levels[level - 1]
            if level in (4, 5, 6, 7, 9):
                self.assertGreater(uw.stairs_first, 0, level)
                self.assertEqual(uw.tile_nes[uw.stairs_first : uw.stairs_first + 4], bytes(range(0x70, 0x74)), level)
            else:
                self.assertEqual(uw.stairs_first, 0, level)

    STEP = (1, -1, 16, -16)
    OPPOSITE = (1, 0, 3, 2)

    def _reach(self, uw, opened):
        """The rooms Link gets to from the start through the doors (E, W, S, N) and the tunnels, with these locked doors open."""
        def door(room, direction):
            return uw.door_types[uw.room_index[room]][direction]

        tunnels = [(c[0], c[1]) for c in uw.cellar_info if c[0] < 128 and c[1] < 128]
        seen, todo = {uw.start_room}, [uw.start_room]
        while todo:
            room = todo.pop()
            for direction in range(4):
                kind = door(room, direction)
                target = room + self.STEP[direction]
                if kind == 1 or not 0 <= target < 128 or uw.room_index[target] == 0xFF:
                    continue
                if direction < 2 and target // 16 != room // 16:
                    continue
                pair = frozenset(((room, direction), (target, self.OPPOSITE[direction])))
                if kind in (5, 6) and pair not in opened:
                    continue
                if target not in seen:
                    seen.add(target)
                    todo.append(target)
            for a, b in tunnels:
                for here, there in ((a, b), (b, a)):
                    if room == here and there not in seen:
                        seen.add(there)
                        todo.append(there)
        return seen

    def _locked_pairs(self, uw):
        pairs = set()
        for room in range(128):
            if uw.room_index[room] == 0xFF:
                continue
            for direction in range(4):
                target = room + self.STEP[direction]
                if uw.door_types[uw.room_index[room]][direction] in (5, 6) and 0 <= target < 128:
                    pairs.add(frozenset(((room, direction), (target, self.OPPOSITE[direction]))))
        return pairs

    def test_every_room_of_every_dungeon_can_be_reached_through_its_doors(self) -> None:
        for level, count in self.ROOMS.items():
            uw = self.bundle.levels[level - 1]
            everything = self._reach(uw, self._locked_pairs(uw))
            self.assertEqual(len(everything), count, (level, sorted(map(hex, everything))))

    def test_the_keys_of_levels_one_to_eight_are_enough_to_open_every_room(self) -> None:
        # Level 9 has sixteen locked doors and four keys: it is the magic key's level
        for level in range(1, 9):
            uw = self.bundle.levels[level - 1]
            locked = sorted(self._locked_pairs(uw), key=sorted)
            keys_in = lambda rooms: sum(
                1 for r in rooms if uw.actors.room_info[uw.room_index[r]][2] == 0x19
            ) + sum(1 for c in uw.cellar_info if c[3] == 0x19 and (c[0] in rooms or c[1] in rooms))
            best, todo, done = 0, [frozenset()], set()
            while todo:
                opened = todo.pop()
                if opened in done:
                    continue
                done.add(opened)
                reached = self._reach(uw, opened)
                best = max(best, len(reached))
                if keys_in(reached) - len(opened) > 0:
                    todo.extend(opened | {pair} for pair in locked
                                if pair not in opened and any(room in reached for room, _ in pair))
            self.assertEqual(best, self.ROOMS[level], level)

    def test_level_nine_needs_the_magic_key_and_nothing_else_for_its_doors(self) -> None:
        uw = self.bundle.levels[8]
        self.assertGreater(len(self._locked_pairs(uw)), sum(
            1 for r in range(128) if uw.room_index[r] != 0xFF and uw.actors.room_info[uw.room_index[r]][2] == 0x19))

    def test_no_room_of_any_dungeon_holds_an_unported_monster(self) -> None:
        for level in self.ROOMS:
            uw = self.bundle.levels[level - 1]
            for record in uw.actors.room_info:
                self.assertEqual(record[5] & 0x1F, 0, (level, record.hex()))

    def test_rooms_carry_the_boss_roar_of_attribute_e_in_bits_5_and_6(self) -> None:
        roars = {}
        for level in self.ROOMS:
            uw = self.bundle.levels[level - 1]
            roars[level] = sorted({(r[5] >> 5) & 3 for r in uw.actors.room_info})
        self.assertIn(1, roars[1])      # Aquamentus' roar is heard around his room
        self.assertIn(2, roars[2])      # Dodongo's
        self.assertIn(3, roars[5])      # Digdogger's
        self.assertEqual(self.bundle.levels[0].boss_room, 0x35)
        self.assertEqual(self.bundle.levels[8].boss_room, 0x42)


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomLevelPaletteTests(unittest.TestCase):
    """Risk R1: every dungeon must fit the 16 ST colours without disturbing what is baked once for all modes."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = build_assets.load_assets(ROM_ROOT)

    def _true_overworld(self):
        """The overworld's palette as the ROM has it: the shown one has its ground a little darker (OW_GROUND_ST), the dungeons' do not."""
        shown = self.bundle.palette
        ground = build_assets.nes_color_to_st(build_assets.OW_GROUND_NES)
        colours = tuple(ground if c == build_assets.OW_GROUND_ST else c for c in shown.st_colors)
        return build_assets.PaletteMap(st_colors=colours, table=shown.table)

    def test_every_level_has_a_sixteen_colour_palette(self) -> None:
        self.assertEqual(len(self.bundle.level_palettes), 9)
        for palette in self.bundle.level_palettes:
            self.assertEqual(len(palette), build_assets.ST_PALETTE_SIZE)

    def test_level_one_uses_the_overworld_palette_unchanged(self) -> None:
        self.assertEqual(self.bundle.level_palettes[0], self._true_overworld().st_colors)

    def test_a_level_differs_from_the_overworld_only_in_what_it_chooses_itself(self) -> None:
        # Level 2 shares every colour but sprite palette row 3, which a dungeon chooses itself (a Zol, a Dodongo wear it):
        # the monsters are baked with the overworld's row 3, so the level puts its colours into those three slots.
        import underworld

        base = self._true_overworld()
        row3 = {base.table[underworld.SPRITE_ROW3][pixel] for pixel in (1, 2, 3)}
        for slot, colour in enumerate(self.bundle.level_palettes[1]):
            if slot not in row3:
                self.assertEqual(colour, base.st_colors[slot], f"slot {slot}")

    def test_the_slots_other_code_relies_on_never_change(self) -> None:
        import underworld

        base = self._true_overworld()
        fixed = {base.table[row][pixel] for row in underworld.PROTECTED_ROWS for pixel in range(4)}
        fixed |= set(underworld.PROTECTED_SLOTS)
        for level, palette in enumerate(self.bundle.level_palettes, 1):
            for slot in fixed:
                self.assertEqual(palette[slot], base.st_colors[slot], f"level {level} slot {slot}")

    def test_each_level_shows_every_colour_it_needs(self) -> None:
        import underworld

        for level, palette in enumerate(self.bundle.level_palettes, 1):
            info = build_assets.require_binary(ROM_ROOT, f"dat/LevelInfoUW{level}.dat")
            nes = info[build_assets.LEVEL_INFO_PALETTE_OFFSET : build_assets.LEVEL_INFO_PALETTE_OFFSET + 32]
            table, colors = underworld.palette_lookup(self._overworld(), self._true_overworld(), nes)
            self.assertEqual(colors, palette)
            for row in range(8):
                for pixel in range(4):
                    wanted = build_assets.nes_color_to_st(nes[0] if pixel == 0 else nes[row * 4 + pixel])
                    self.assertEqual(palette[table[row][pixel]], wanted, f"level {level} row {row} pixel {pixel}")

    @staticmethod
    def _overworld() -> bytes:
        info = build_assets.require_binary(ROM_ROOT, build_assets.LEVEL_INFO_OW_NAME)
        return info[build_assets.LEVEL_INFO_PALETTE_OFFSET : build_assets.LEVEL_INFO_PALETTE_OFFSET + 32]


class PaletteSlotCodeTests(unittest.TestCase):
    def test_the_minimap_colours_are_protected_slots(self) -> None:
        import re
        import underworld

        source = (Path(__file__).resolve().parents[1] / "src" / "hud.s").read_text(encoding="utf-8")
        for name in ("MM_ROOM", "MM_LINK", "MM_FLASH_A", "MM_FLASH_B", "MM_GOT"):
            slot = int(re.search(rf"\.equ {name}, (\d+)", source).group(1))
            self.assertIn(slot, underworld.PROTECTED_SLOTS, name)


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomActorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        import actors

        cls.actors = actors
        cls.data = build_assets.load_assets(ROM_ROOT).uw.actors

    def test_every_monster_has_eight_frames_and_a_table_row(self) -> None:
        count = len(self.actors.MONSTER_TYPES)
        self.assertEqual(len(self.data.mon_table), count * 8)
        frames = len(self.data.mon_sprites) // build_assets.SPRITE_FRAME_BYTES
        self.assertEqual(len(self.data.mon_sprites) % build_assets.SPRITE_FRAME_BYTES, 0)
        self.assertEqual(len(self.data.mon_art), count * 2)
        for index, nes_type in enumerate(self.actors.MONSTER_TYPES):
            start = int.from_bytes(self.data.mon_art[index * 2 : index * 2 + 2], "big")
            _, images, mode = self.actors.MONSTER_DRAW[nes_type]
            used = images if mode in self.actors.FRAME_MODES or images == self.actors.OCTOROK_IMAGES else self.actors.MONSTER_IMAGES
            self.assertLessEqual(start + used * 2, frames, nes_type)

    def test_the_slow_and_fast_octorok_share_their_art(self) -> None:
        index = {t: i for i, t in enumerate(self.actors.MONSTER_TYPES)}
        start = lambda t: self.data.mon_art[index[t] * 2 : index[t] * 2 + 2]
        self.assertEqual(start(0x07), start(0x08))

    def test_overworld_records_count_and_index_known_monsters(self) -> None:
        info = build_assets.load_assets(ROM_ROOT).ow_room_info
        self.assertEqual(len(info), 128 * self.actors.OW_ROOM_INFO_BYTES)
        for room in range(128):
            record = info[room * 16 : room * 16 + 16]
            self.assertLessEqual(record[0], self.actors.OW_MAX_MONSTERS)
            for monster in record[6 : 6 + record[0]]:
                self.assertIn(self.actors.MONSTER_TYPES[monster], self.actors.OVERWORLD_LISTED)
        self.assertEqual(info[0x78 * 16], 4)        # four red octoroks
        self.assertGreaterEqual(info[0x05 * 16], 1)

    def test_monster_periods_are_never_zero(self) -> None:
        for row in range(len(self.actors.MONSTER_TYPES)):
            self.assertGreaterEqual(self.data.mon_table[row * 8 + 2], 1)

    def test_room_records_have_a_fixed_size_and_known_monsters(self) -> None:
        for record in self.data.room_info:
            self.assertEqual(len(record), self.actors.ROOM_INFO_BYTES)
            for monster in record[6 : 6 + record[0]]:
                self.assertLess(monster, len(self.actors.MONSTER_TYPES))

    def test_stalfos_room_lists_five_stalfos(self) -> None:
        import underworld  # noqa: F401

        uw = build_assets.load_assets(ROM_ROOT).uw
        record = self.data.room_info[uw.room_index[0x74]]
        stalfos = self.actors.MONSTER_TYPES.index(0x2A)
        self.assertEqual(list(record[6:11]), [stalfos] * 5)
        self.assertEqual(record[0], 5)

    def test_level_one_has_one_treasure_cellar_below_room_22(self) -> None:
        import underworld

        uw = build_assets.load_assets(ROM_ROOT).uw
        self.assertEqual(len(uw.cellar_maps), 1)
        self.assertEqual(len(uw.cellar_maps[0]), underworld.UW_ROOM_BYTES)
        dest_a, dest_b, _position, item, _x, _y, room, kind = uw.cellar_info[0]
        self.assertEqual((dest_a, dest_b), (0x22, 0x22))
        self.assertEqual(item, 0x0A)            # the bow
        self.assertEqual((room, kind), (0x7F, 1))
        self.assertIn(0x0A, self.actors.ITEM_IDS)

    def test_old_man_says_the_famous_line(self) -> None:
        bundle = build_assets.load_assets(ROM_ROOT)
        letters = {0x0A + n: chr(ord("A") + n) for n in range(26)}
        letters.update({0x24: " ", 0x25: " ", 0x29: "!", 0x2A: "'", 0x2C: "."})
        cave = bundle.cave_text[: build_assets.PERSON_TEXT_BYTES]   # the dungeon people's speeches follow it
        text = "".join(letters[code & 0x3F] for code in cave)
        self.assertEqual(" ".join(text.split()), "IT'S DANGEROUS TO GO ALONE! TAKE THIS.")
        self.assertEqual(cave[-1] & 0xC0, 0xC0)               # the last character ends the speech
        # the usual cave, then the take-any-road room
        self.assertEqual(len(bundle.cave_map), 2 * build_assets.OW_ROOM_COLS * build_assets.OW_ROOM_ROWS)

    def _speech(self, bundle, offset: int) -> str:
        letters = {0x0A + n: chr(ord("A") + n) for n in range(26)}
        letters.update({0x24: " ", 0x25: " ", 0x28: ",", 0x29: "!", 0x2A: "'", 0x2C: ".", 0x2E: "?", 0x2F: "-"})
        out = []
        while True:
            code = bundle.cave_text[offset]
            offset += 1
            out.append(code & 0x3F)
            if code & 0xC0 == 0xC0:
                break
        return " ".join("".join(letters.get(code, str(code)) if code >= 10 else str(code) for code in out).split())

    def test_cave_table_follows_the_rom(self) -> None:
        bundle = build_assets.load_assets(ROM_ROOT)
        table = bundle.cave_table
        self.assertEqual(len(table), build_assets.CAVE_TYPES * build_assets.CAVE_RECORD_BYTES)

        def record(cave_type: int) -> bytes:
            start = (cave_type - 0x6A) * build_assets.CAVE_RECORD_BYTES
            return table[start : start + build_assets.CAVE_RECORD_BYTES]

        def speech(cave_type: int, at: int = 8) -> str:
            return self._speech(bundle, int.from_bytes(record(cave_type)[at : at + 2], "big"))

        wood = record(0x6A)                                           # the wooden sword: pick up, wares shown
        self.assertEqual((wood[0], wood[1], tuple(wood[2:5])), (0x05, 0, (0x3F, 0x01, 0x3F)))
        self.assertEqual(speech(0x6A), "IT'S DANGEROUS TO GO ALONE! TAKE THIS.")
        self.assertEqual(record(0x6C)[0] & 0x40, 0x40)                # the heart requirement
        self.assertEqual(record(0x6D)[0] & 0x40, 0x40)
        self.assertEqual(record(0x6B)[2:5], bytes((0x20, 0x3F, 0x1A)))
        self.assertEqual(speech(0x6B), "TAKE ANY ONE YOU WANT.")
        self.assertEqual(speech(0x6E), "TAKE ANY ROAD YOU WANT.")
        self.assertEqual(speech(0x71), "PAY ME FOR THE DOOR REPAIR CHARGE.")
        money = record(0x70)                                          # the money making game: minus signs, three rupees
        self.assertEqual((money[0], tuple(money[2:5]), tuple(money[5:8])), (0xAD, (0x18,) * 3, (10, 10, 10)))
        shop = record(0x77)                                           # a shop: magic shield, bombs, arrow
        self.assertEqual((shop[0], shop[1], tuple(shop[2:5]), tuple(shop[5:8])), (0x0F, 2, (0x1C, 0x00, 0x08), (130, 20, 80)))
        potion = record(0x74)                                         # the medicine woman
        self.assertEqual((potion[1], tuple(potion[2:5]), tuple(potion[5:8])), (1, (0x1F, 0x3F, 0x20), (40, 0, 68)))
        hint = record(0x75)                                           # pay for a hint: the ware picks the speech
        self.assertEqual(tuple(hint[5:8]), (5, 10, 20))
        self.assertEqual(speech(0x75, 14), "GO UP,UP, THE MOUNTAIN AHEAD.")
        self.assertEqual(speech(0x76, 12), "GO NORTH,WEST,SOUTH, WEST TO THE FOREST OF MAZE.")
        moblin = record(0x7B)                                         # a moblin hands out the middle rupee
        self.assertEqual((moblin[1], tuple(moblin[5:8])), (3, (0, 30, 0)))
        self.assertEqual(speech(0x7B), "IT'S A SECRET TO EVERYBODY.")
        self.assertEqual(bundle.cave_shortcuts, bytes((0x1D, 0x23, 0x49, 0x79)))

    def test_level_one_old_man_sits_in_room_41_with_his_own_speech(self) -> None:
        bundle = build_assets.load_assets(ROM_ROOT)
        uw = bundle.uw
        letters = {0x0A + n: chr(ord("A") + n) for n in range(26)}
        letters.update({0x24: " ", 0x25: " ", 0x2C: "."})
        offset = int.from_bytes(uw.actors.room_info[uw.room_index[0x41]][14:16], "big")
        self.assertGreaterEqual(offset, build_assets.PERSON_TEXT_BYTES)
        speech = bytearray()
        for code in bundle.cave_text[offset:]:
            speech.append(code)
            if code & 0xC0 == 0xC0:
                break
        text = "".join(letters[code & 0x3F] for code in speech)
        self.assertEqual(" ".join(text.split()), "EASTMOST PENNINSULA IS THE SECRET.")
        others = [
            index
            for index, record in enumerate(uw.actors.room_info)
            if index != uw.room_index[0x41] and int.from_bytes(record[14:16], "big") != self.actors.NO_PERSON
        ]
        self.assertEqual(others, [])

    def test_link_lifting_the_triforce_has_a_picture(self) -> None:
        # the end-of-level sequence draws Link with both arms up: item picture $3F, a symmetric pair of tiles
        frame_bytes = build_assets.SPRITE_FRAME_BYTES
        index = self.data.item_index[self.actors.LINK_LIFT_ID]
        self.assertNotEqual(index, 0xFF)
        frame = self.data.item_sprites[index * frame_bytes : (index + 1) * frame_bytes]
        masks = [int.from_bytes(frame[row * 10 + 8 : row * 10 + 10], "big") for row in range(16)]
        self.assertTrue(any(masks), "the picture is not blank")
        for mask in masks:  # left and right halves are mirror images
            self.assertEqual(mask >> 8, int(f"{mask & 255:08b}"[::-1], 2))

    def test_inventory_icons_follow_the_b_item_codes_then_compass_and_map(self) -> None:
        # items.s (b_icons, a_icons), menu.s (passive_icons) and hud.s index hud_items directly
        ids = self.actors.HUD_ITEM_IDS
        self.assertEqual(ids[:4], (0x01, 0x00, 0x1D, 0x06))  # sword, bomb, boomerang, candle: the first B codes
        self.assertEqual(ids[4:7], (0x16, 0x17, 0x0A))  # compass, map, bow
        expected = {  # icon index -> item id, as the 68000 tables use them
            7: 0x05, 8: 0x04, 9: 0x1F, 10: 0x20, 11: 0x10, 12: 0x1E, 13: 0x07, 14: 0x02, 15: 0x03,
            18: 0x0C, 19: 0x11, 20: 0x12, 21: 0x13, 22: 0x0D, 23: 0x0B, 24: 0x14, 25: 0x1C, 26: 0x15,
        }
        for icon, item in expected.items():
            self.assertEqual(ids[icon], item, f"icon {icon}")
        self.assertEqual(len(self.data.hud_items), len(ids) * 2 * build_assets.HUD_TILE_BYTES)
        for icon in range(len(ids)):
            tiles = self.data.hud_items[icon * 64 : (icon + 1) * 64]
            self.assertTrue(any(tiles), f"icon {icon} is blank")

    def test_floor_items_have_art(self) -> None:
        for item_id in self.actors.ITEM_IDS:
            self.assertNotEqual(self.data.item_index[item_id], 0xFF)
        self.assertEqual(
            len(self.data.item_sprites), len(self.actors.ITEM_IDS) * build_assets.SPRITE_FRAME_BYTES
        )


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class OutputTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = build_assets.load_assets(ROM_ROOT)

    def test_a_build_without_a_rom_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source_root = Path(tmpdir) / "source"
            source_root.mkdir()
            with self.assertRaises(SystemExit) as raised:
                build_assets.load_assets(source_root)
            self.assertIn("nothing is drawn separately", str(raised.exception))

    def test_generation_and_verification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            out_dir = Path(tmpdir) / "out"
            self.assertIn("ROM-derived", self.bundle.source_note)

            build_assets.write_outputs(out_dir, self.bundle)
            build_assets.verify_outputs(out_dir)

            include_text = (out_dir / "assets.inc").read_text(encoding="utf-8")
            manifest_text = (out_dir / "asset_manifest.txt").read_text(encoding="utf-8")
            self.assertIn("room_palette:", include_text)
            self.assertIn("level_palettes:", include_text)
            self.assertIn("walkable_tiles:", include_text)
            self.assertIn("source=ROM-derived", manifest_text)
            self.assertFalse((out_dir / "enemy_sprites.bin").exists(), "no hand-drawn monster picture is emitted")

    def test_metatile_tiles_match_the_decoded_quads(self) -> None:
        # The runtime derives collision tiles from this table, so it has to hold the
        # raw NES tile indices in the same order the metatiles were built from.
        with tempfile.TemporaryDirectory() as tmpdir:
            out_dir = Path(tmpdir) / "out"
            build_assets.write_outputs(out_dir, self.bundle)

            emitted = list((out_dir / "metatile_tiles.bin").read_bytes())
            expected = [tile for _, quad in self.bundle.metatiles for tile in quad]
            self.assertEqual(emitted, expected)

    def test_room_maps_are_emitted_row_major(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            out_dir = Path(tmpdir) / "out"
            build_assets.write_outputs(out_dir, self.bundle)

            emitted = list((out_dir / "room_maps.bin").read_bytes())
            self.assertEqual(emitted, [value for room in self.bundle.rooms for value in room])

    def test_missing_output_file_fails_verification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            out_dir = Path(tmpdir) / "out"
            build_assets.write_outputs(out_dir, self.bundle)
            (out_dir / "link_sprites.bin").unlink()
            with self.assertRaises(SystemExit):
                build_assets.verify_outputs(out_dir)


if __name__ == "__main__":
    unittest.main()
