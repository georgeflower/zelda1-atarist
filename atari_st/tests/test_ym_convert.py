from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import ym_convert  # noqa: E402


class YmConvertTests(unittest.TestCase):
    def test_converts_the_digidrum_engine(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            ym_convert.convert(ROOT / "music" / "ymplay.h", out)
            self.assertEqual(sorted(p.name for p in out.iterdir()), ["music_engine.bin"])
            self.assertEqual(len((out / "music_engine.bin").read_bytes()), 594 * 2)


if __name__ == "__main__":
    unittest.main()
