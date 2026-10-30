"""The floppy image maker (tools/make_disk.py): what goes in comes out, and an image that is too full is refused."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import make_disk as D  # noqa: E402


class DiskTests(unittest.TestCase):
    def test_files_of_every_size_read_back(self) -> None:
        files = [("ZELDAST.PRG", bytes(range(256)) * 1200), ("LEVEL1.DAT", b"x"), ("LEVEL9Q.DAT", bytes(1024)),
                 ("EMPTY.DAT", b""), ("A.B", b"abc" * 700)]
        image = D.build_disk(files)
        self.assertEqual(len(image), 720 * 1024)
        self.assertEqual(D.read_disk(image), dict(files))

    def test_the_boot_sector_describes_a_720_kb_disk(self) -> None:
        boot = D.build_disk([])[:512]
        self.assertEqual(int.from_bytes(boot[11:13], "little"), 512)      # bytes a sector
        self.assertEqual(boot[13], 2)                                       # sectors a cluster
        self.assertEqual(int.from_bytes(boot[19:21], "little"), 1440)       # sectors
        self.assertEqual(boot[21], 0xF9)
        self.assertEqual(int.from_bytes(boot[24:26], "little"), 9)          # sectors a track
        self.assertEqual(int.from_bytes(boot[26:28], "little"), 2)          # sides

    def test_a_disk_that_is_full_is_refused(self) -> None:
        with self.assertRaises(D.DiskFull):
            D.build_disk([("BIG.DAT", bytes(800 * 1024))])

    def test_names_are_eight_dot_three(self) -> None:
        self.assertEqual(D.short_name("zelda.prg"), b"ZELDA   PRG")
        with self.assertRaises(ValueError):
            D.short_name("LONGERNAME.PRG")


if __name__ == "__main__":
    unittest.main()
