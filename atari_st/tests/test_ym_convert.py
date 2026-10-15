from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import ym_convert  # noqa: E402


class YmConvertTests(unittest.TestCase):
    def test_converts_the_shipped_song(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            ym_convert.convert(
                ROOT / "music" / "zelda_intro_by_qum.h", ROOT / "music" / "ymplay.h", out
            )
            self.assertEqual(len((out / "music_data.bin").read_bytes()), 11713)
            self.assertEqual(len((out / "music_drums.bin").read_bytes()), 256)
            self.assertEqual(len((out / "music_engine.bin").read_bytes()), 594 * 2)
            inc = (out / "music.inc").read_text()
            self.assertIn("MUSIC_FRAMES, 4174", inc)
            self.assertIn("MUSIC_LOOP_FRAME, 1392", inc)
            self.assertIn("MUSIC_LOOP_OFFSET, 3628", inc)

    def test_stream_decodes_to_exactly_the_frame_count(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            ym_convert.convert(
                ROOT / "music" / "zelda_intro_by_qum.h", ROOT / "music" / "ymplay.h", out
            )
            data = (out / "music_data.bin").read_bytes()
            pos = 0
            for _ in range(4174):
                first = data[pos]
                pos += 1
                mask = first & 0x7F
                if first & 0x80:
                    second = data[pos]
                    pos += 1
                    mask |= (second & 0x7F) << 7
                    if second & 0x80:
                        pos += 1
                pos += bin(mask).count("1")
            self.assertEqual(pos, len(data))


if __name__ == "__main__":
    unittest.main()
