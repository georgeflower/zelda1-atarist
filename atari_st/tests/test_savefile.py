"""ZELDA.SAV: the Python model of tools/savefile.py against what save.s and globals.s say, and the model's own round trip."""
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

import savefile as S  # noqa: E402


class SaveFileLayout(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = S.from_sources()

    def test_the_constants_are_those_of_save_s(self):
        for name, value in [("SAVE_RECS", S.RECORDS), ("SAVE_REC_BYTES", S.RECORD_BYTES), ("SAVE_HEADER_BYTES", S.HEADER_BYTES),
                            ("SAVE_FILE_BYTES", S.FILE_BYTES), ("SAVE_OLD_BYTES", S.OLD_BYTES),
                            ("SAVE_EXT_BYTES", S.EXT_BYTES), ("SAVE_OLD_VERSION", S.OLD_VERSION), ("SAVE_EXT_OFFSET", S.OLD_BYTES), ("SAVE_VERSION", S.VERSION), ("SAVE_SEED", S.SEED),
                            ("SAVE_MAGIC", struct.unpack(">I", S.MAGIC)[0]), ("REC_STATE", S.STATE_OFFSET)]:
            self.assertEqual(self.src[name], value, name)

    def test_the_variable_holds_the_file(self):
        self.assertEqual(self.src["gvars"]["SAVE_FILE"], S.FILE_BYTES)

    def test_the_state_fields_are_those_of_the_table(self):
        self.assertEqual([(n, int(s)) for n, s in self.src["fields"]], S.FIELDS)

    def test_every_field_is_a_variable_of_that_size_or_a_slice_of_one(self):
        gvars = self.src["gvars"]
        for name, size in S.FIELDS:
            self.assertIn(name, gvars, name)
            self.assertLessEqual(size, gvars[name], name)
            if size > 1:
                self.assertEqual(size, gvars[name], name)      # tables go whole

    def test_the_state_fits_its_record(self):
        self.assertLessEqual(S.STATE_OFFSET + sum(size for _, size in S.FIELDS), S.RECORD_BYTES)

    def test_the_patch_log_holds_what_secrets_s_logs(self):
        secrets = (S.SRC / "secrets.s").read_text(encoding="utf-8")
        self.assertIn(f".equ PATCH_MAX, {S.PATCH_MAX}", secrets)
        self.assertEqual(dict(S.FIELDS)["PATCHES"], 4 * S.PATCH_MAX)
        self.assertEqual(self.src["gvars"]["PATCHES"], 4 * S.PATCH_MAX)


class SaveFileModel(unittest.TestCase):
    def test_a_new_file_is_good_and_has_three_free_profiles(self):
        data = S.make_file()
        self.assertEqual(len(data), S.FILE_BYTES)
        records = S.parse(data)
        self.assertEqual([r[0] for r in records], [0, 0, 0])

    def test_a_profile_round_trips(self):
        record = S.make_record("ZELDA", deaths=7, state={"INV_RUPEES": bytes([99]), "ITEMS": bytes([1, 4])})
        records = S.parse(S.make_file([record]))
        self.assertEqual(records[0][0], 1)
        self.assertEqual(records[0][1], 7)
        self.assertEqual(list(records[0][8:16]), [0x23, 0x0E, 0x15, 0x0D, 0x0A, 0x24, 0x24, 0x24])     # Z E L D A + 3 spaces
        self.assertEqual(records[0][S.field_offset("INV_RUPEES")], 99)
        self.assertEqual(records[0][S.field_offset("ITEMS") + 1], 4)

    def test_what_save_read_refuses(self):
        good = bytearray(S.make_file([S.make_record()]))
        self.assertIsNotNone(S.parse(bytes(good)))
        self.assertIsNone(S.parse(bytes(good[:-1])))
        broken = bytearray(good)
        broken[S.HEADER_BYTES + 100] ^= 1
        self.assertIsNone(S.parse(bytes(broken)))              # the checksum
        broken = bytearray(good)
        broken[0] = ord("X")
        self.assertIsNone(S.parse(bytes(broken)))              # the letters
        broken = bytearray(good)
        broken[5] = 3
        self.assertIsNone(S.parse(bytes(broken)))              # the version

    def test_the_flags_of_levels_7_to_9_round_trip(self):
        ext = [bytes([i + 1]) * S.EXT_BYTES for i in range(S.RECORDS)]
        records, back = S.parse_all(S.make_file([S.make_record()], ext))
        self.assertEqual(back, ext)
        broken = bytearray(S.make_file([S.make_record()], ext))
        broken[S.OLD_BYTES + 5] ^= 1
        self.assertIsNone(S.parse(bytes(broken)))              # the checksum covers them

    def test_a_file_of_version_1_is_still_read_with_empty_flags(self):
        old = S.make_file([S.make_record("LINK", deaths=2)], old=True)
        self.assertEqual(len(old), S.OLD_BYTES)
        records, ext = S.parse_all(old)
        self.assertEqual(records[0][1], 2)
        self.assertEqual(ext, [bytes(S.EXT_BYTES)] * S.RECORDS)
        self.assertIsNone(S.parse(old[:-2]))
        wrong = bytearray(S.make_file([S.make_record()]))[:S.OLD_BYTES]
        self.assertIsNone(S.parse(bytes(wrong)))               # version 2 needs its flags

    def test_the_flag_records_are_the_two_world_flag_tables(self):
        gvars = self.src["gvars"] if hasattr(self, "src") else S.from_sources()["gvars"]
        self.assertEqual(gvars["UW_OPEN_B"] + gvars["UW_FLAGS_B"], S.EXT_BYTES)

    def test_the_checksum_wraps_at_sixteen_bits(self):
        self.assertEqual(S.checksum(b"\xff\xff" * 3), (S.SEED + 3 * 0xFFFF) & 0xFFFF)


if __name__ == "__main__":
    unittest.main()
