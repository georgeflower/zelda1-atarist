from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import build_assets  # noqa: E402


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
        palette = build_assets.build_palette_map(build_assets.PLACEHOLDER_NES_PALETTE)
        self.assertEqual(len(palette.st_colors), build_assets.ST_PALETTE_SIZE)
        for row in range(build_assets.PALETTE_ROWS):
            for pixel in range(build_assets.PALETTE_ROW_COLORS):
                self.assertLess(palette.index(row, pixel), build_assets.ST_PALETTE_SIZE)

    def test_pixel_zero_is_the_shared_backdrop_in_every_row(self) -> None:
        palette = build_assets.build_palette_map(build_assets.PLACEHOLDER_NES_PALETTE)
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
        palette = build_assets.build_palette_map(build_assets.PLACEHOLDER_NES_PALETTE)
        frame = build_assets.build_sprite_frame(self._solid_tiles(), palette, 4, 0, flip=False)
        self.assertEqual(len(frame), build_assets.SPRITE_FRAME_BYTES)
        mask = int.from_bytes(frame[8:10], "big")
        self.assertEqual(mask, 0x8000)

    def test_horizontal_flip_mirrors_the_row(self) -> None:
        palette = build_assets.build_palette_map(build_assets.PLACEHOLDER_NES_PALETTE)
        frame = build_assets.build_sprite_frame(self._solid_tiles(), palette, 4, 0, flip=True)
        mask = int.from_bytes(frame[8:10], "big")
        self.assertEqual(mask, 0x0001)


ROM_ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomOverworldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.bundle = build_assets.load_assets(ROM_ROOT, require_source=True)

    def test_whole_overworld_is_decoded(self) -> None:
        rooms = self.bundle.rooms
        self.assertEqual(len(rooms), build_assets.OW_ROOM_COUNT)
        for room in rooms:
            self.assertEqual(len(room), build_assets.OW_ROOM_COLS * build_assets.OW_ROOM_ROWS)
            self.assertLess(max(room), len(self.bundle.metatiles))
        # All 121 unique layouts are in use; a 6-bit id would only reach 64.
        self.assertEqual(len(set(self.bundle.room_attrs_d[r] & 0x7F for r in range(len(rooms)))), 121)
        self.assertGreaterEqual(len({tuple(room) for room in rooms}), 100)

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

    def test_placeholder_underworld_is_consistent(self) -> None:
        import underworld

        uw = underworld.build_placeholder()
        self.assertEqual(len(uw.rooms[0]), underworld.UW_ROOM_BYTES)
        self.assertEqual(len(uw.tile_bank), len(uw.tile_nes) * 32)


@unittest.skipUnless((ROM_ROOT / "ext" / "Original.nes").exists(), "needs ext/Original.nes")
class RomUnderworldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.uw = build_assets.load_assets(ROM_ROOT, require_source=True).uw

    def test_level_one_has_seventeen_rooms_from_the_start_room(self) -> None:
        stored = [room for room, index in enumerate(self.uw.room_index) if index != 0xFF]
        self.assertEqual(len(stored), 17)
        self.assertIn(self.uw.start_room, stored)
        self.assertEqual(self.uw.start_room, 0x73)

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
class RomActorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        import actors

        cls.actors = actors
        cls.data = build_assets.load_assets(ROM_ROOT, require_source=True).uw.actors

    def test_every_monster_has_eight_frames_and_a_table_row(self) -> None:
        count = len(self.actors.MONSTER_TYPES)
        self.assertEqual(len(self.data.mon_table), count * 8)
        self.assertEqual(
            len(self.data.mon_sprites), count * self.actors.MONSTER_IMAGES * 2 * build_assets.SPRITE_FRAME_BYTES
        )

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

        uw = build_assets.load_assets(ROM_ROOT, require_source=True).uw
        record = self.data.room_info[uw.room_index[0x74]]
        stalfos = self.actors.MONSTER_TYPES.index(0x2A)
        self.assertEqual(list(record[6:11]), [stalfos] * 5)
        self.assertEqual(record[0], 5)

    def test_level_one_has_one_treasure_cellar_below_room_22(self) -> None:
        import underworld

        uw = build_assets.load_assets(ROM_ROOT, require_source=True).uw
        self.assertEqual(len(uw.cellar_maps), 1)
        self.assertEqual(len(uw.cellar_maps[0]), underworld.UW_ROOM_BYTES)
        dest_a, dest_b, _position, item, _x, _y, room, kind = uw.cellar_info[0]
        self.assertEqual((dest_a, dest_b), (0x22, 0x22))
        self.assertEqual(item, 0x0A)            # the bow
        self.assertEqual((room, kind), (0x7F, 1))
        self.assertIn(0x0A, self.actors.ITEM_IDS)

    def test_floor_items_have_art(self) -> None:
        for item_id in self.actors.ITEM_IDS:
            self.assertNotEqual(self.data.item_index[item_id], 0xFF)
        self.assertEqual(
            len(self.data.item_sprites), len(self.actors.ITEM_IDS) * build_assets.SPRITE_FRAME_BYTES
        )


class OutputTests(unittest.TestCase):
    def test_placeholder_generation_and_verification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source_root = Path(tmpdir) / "source"
            source_root.mkdir()
            out_dir = Path(tmpdir) / "out"

            bundle = build_assets.load_assets(source_root)
            self.assertIn("placeholder", bundle.source_note)

            build_assets.write_outputs(out_dir, bundle)
            build_assets.verify_outputs(out_dir)

            include_text = (out_dir / "assets.inc").read_text(encoding="utf-8")
            manifest_text = (out_dir / "asset_manifest.txt").read_text(encoding="utf-8")
            self.assertIn("room_palette:", include_text)
            self.assertIn("walkable_tiles:", include_text)
            self.assertIn("source=generated placeholder CHR", manifest_text)

    def test_metatile_tiles_match_the_decoded_quads(self) -> None:
        # The runtime derives collision tiles from this table, so it has to hold the
        # raw NES tile indices in the same order the metatiles were built from.
        with tempfile.TemporaryDirectory() as tmpdir:
            source_root = Path(tmpdir) / "source"
            source_root.mkdir()
            out_dir = Path(tmpdir) / "out"

            bundle = build_assets.load_assets(source_root)
            build_assets.write_outputs(out_dir, bundle)

            emitted = list((out_dir / "metatile_tiles.bin").read_bytes())
            expected = [tile for _, quad in bundle.metatiles for tile in quad]
            self.assertEqual(emitted, expected)

    def test_room_maps_are_emitted_row_major(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source_root = Path(tmpdir) / "source"
            source_root.mkdir()
            out_dir = Path(tmpdir) / "out"

            bundle = build_assets.load_assets(source_root)
            build_assets.write_outputs(out_dir, bundle)

            emitted = list((out_dir / "room_maps.bin").read_bytes())
            self.assertEqual(emitted, [value for room in bundle.rooms for value in room])

    def test_missing_output_file_fails_verification(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            source_root = Path(tmpdir) / "source"
            source_root.mkdir()
            out_dir = Path(tmpdir) / "out"

            build_assets.write_outputs(out_dir, build_assets.load_assets(source_root))
            (out_dir / "link_sprites.bin").unlink()
            with self.assertRaises(SystemExit):
                build_assets.verify_outputs(out_dir)


if __name__ == "__main__":
    unittest.main()
