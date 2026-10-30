"""The LZ4 packer of the dungeon files (tools/lzpack.py) and its 68000 decoder (src/lz.s) run on machine68k."""
from __future__ import annotations

import random
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import lzpack  # noqa: E402

AS = "m68k-linux-gnu-as"
LD = "m68k-linux-gnu-ld"
OBJCOPY = "m68k-linux-gnu-objcopy"
BASE = 0x1000
MEMORY_KB = 512


def samples() -> list[tuple[str, bytes]]:
    rng = random.Random(7)
    noise = bytes(rng.randrange(256) for _ in range(3000))
    tiles = bytes(rng.randrange(4) for _ in range(400)) * 12
    return [
        ("empty", b""),
        ("one byte", b"\x42"),
        ("short", b"abcabcabcabcabc"),
        ("noise", noise),
        ("a long run (length bytes of 255)", bytes(3000)),
        ("a long literal run then repeats", noise + noise[:900] + noise[100:1500]),
        ("a pattern 160 bytes apart", (bytes(range(160)) * 5) + bytes(7) + bytes(range(160)) * 3),
        ("tiles", tiles),
        ("overlapping match (offset 1, 2, 3)", b"x" + b"y" * 40 + b"zq" * 30 + b"abc" * 25),
        ("a far match (65535 back)", noise[:200] + bytes(65535 - 200) + noise[:200]),
    ]


class PackerTests(unittest.TestCase):
    def test_every_sample_comes_back(self) -> None:
        for name, data in samples():
            with self.subTest(name):
                self.assertEqual(lzpack.unpack(lzpack.pack(data)), data)

    def test_repeats_get_smaller_and_noise_stays_close_to_its_size(self) -> None:
        self.assertLess(len(lzpack.pack(bytes(3000))), 30)
        noise = bytes(random.Random(3).randrange(256) for _ in range(2000))
        self.assertLess(len(lzpack.pack(noise)), len(noise) + len(noise) // 255 + 8)

    def test_the_block_ends_with_a_sequence_that_has_literals_only(self) -> None:
        data = b"abcdabcdabcdabcd"            # ends in a match: a closing token with no literals must follow
        packed = lzpack.pack(data)
        self.assertEqual(packed[-1], 0)
        self.assertEqual(lzpack.unpack(packed), data)

    def test_the_margin_is_at_least_the_gain_and_never_negative(self) -> None:
        for name, data in samples():
            packed = lzpack.pack(data)
            self.assertGreaterEqual(lzpack.margin(packed), len(data) - len(packed), name)

    def test_unpacking_in_place_with_the_margin_never_overwrites_unread_data(self) -> None:
        for name, data in samples():
            packed = lzpack.pack(data)
            size = len(packed) + max(lzpack.margin(packed), 0)
            area = bytearray(size)
            start = size - len(packed)
            area[start:] = packed
            read, out = start, 0
            for lit_at, lit, offset, length, consumed in lzpack._walk(packed):
                for k in range(lit):
                    area[out] = area[start + lit_at + k]
                    out += 1
                for _ in range(length):
                    area[out] = area[out - offset]
                    out += 1
                self.assertLessEqual(out, start + consumed, name)       # the output has not reached the unread bytes
            self.assertEqual(bytes(area[: len(data)]), data, name)


def toolchain_ok() -> bool:
    if not all(shutil.which(t) for t in (AS, LD, OBJCOPY)):
        return False
    try:
        import machine68k  # noqa: F401
    except ImportError:
        return False
    return True


class Decoder:
    """The decoder (src/lz.s through tests/lz_harness.s) on machine68k."""

    @classmethod
    def setUpClass(cls) -> None:
        import machine68k as m

        cls.m = m
        cls.tmp = tempfile.TemporaryDirectory()
        tmp = Path(cls.tmp.name)
        subprocess.run([AS, "-m68000", "-I", str(ROOT / "src"), "-o", str(tmp / "h.o"), str(ROOT / "tests" / "lz_harness.s")],
                       check=True, capture_output=True)
        subprocess.run([LD, f"-Ttext={BASE:#x}", "-nostdlib", "-e", "0", "-o", str(tmp / "h.elf"), str(tmp / "h.o")],
                       check=True, capture_output=True)
        subprocess.run([OBJCOPY, "-O", "binary", str(tmp / "h.elf"), str(tmp / "h.bin")], check=True)
        cls.image = (tmp / "h.bin").read_bytes()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def run_decoder(self, packed: bytes, size: int, packed_at: int, out_at: int) -> tuple[bytes, int]:
        """Unpack `packed` (put at `packed_at`) to `out_at` on the CPU; returns the `size` bytes made and the end address."""
        m = self.m
        machine = m.Machine(m.CPUType.M68000, MEMORY_KB)
        mem, cpu = machine.mem, machine.cpu
        mem.w_block(BASE, self.image)
        mem.w_block(packed_at, packed)
        cpu.set_instr_hook_callback(lambda pc: machine.abort_execute() if mem.r16(pc) == 0x60FE else None)
        R = m.Register
        cpu.w_sr(0x2700)
        cpu.w_sp(0x70000)
        cpu.w_pc(BASE)
        cpu.w_reg(R.A0, packed_at)
        cpu.w_reg(R.A1, out_at)
        cpu.w_reg(R.A2, packed_at + len(packed))
        machine.execute(200_000_000)
        end = cpu.r_reg(R.A1)
        return bytes(mem.r8(out_at + i) for i in range(size)), end



@unittest.skipUnless(toolchain_ok(), "needs the m68k binutils and machine68k")
class DecoderTests(Decoder, unittest.TestCase):
    def test_every_sample_unpacks_to_what_was_packed(self) -> None:
        for name, data in samples():
            with self.subTest(name):
                packed = lzpack.pack(data)
                made, end = self.run_decoder(packed, len(data), 0x20000, 0x40000)
                self.assertEqual(made, data)
                self.assertEqual(end, 0x40000 + len(data))

    def test_in_place_over_the_packed_data_as_the_loader_does_it(self) -> None:
        for name, data in samples():
            with self.subTest(name):
                packed = lzpack.pack(data)
                size = len(packed) + max(lzpack.margin(packed), 8) + 1
                size += size % 2
                base = 0x30000
                at = (base + size - len(packed)) & ~1
                made, end = self.run_decoder(packed, len(data), at, base)
                self.assertEqual(made, data)
                self.assertEqual(end, base + len(data))

    def test_the_decoder_leaves_the_bytes_around_the_output_alone(self) -> None:
        data = bytes(random.Random(5).randrange(7) for _ in range(900))
        packed = lzpack.pack(data)
        m = self.m
        machine = m.Machine(m.CPUType.M68000, MEMORY_KB)
        mem = machine.mem
        mem.w_block(0x50000 - 8, bytes([0xAA]) * (len(data) + 16))
        mem.w_block(BASE, self.image)
        mem.w_block(0x20000, packed)
        machine.cpu.set_instr_hook_callback(lambda pc: machine.abort_execute() if mem.r16(pc) == 0x60FE else None)
        R = m.Register
        machine.cpu.w_sr(0x2700)
        machine.cpu.w_sp(0x70000)
        machine.cpu.w_pc(BASE)
        machine.cpu.w_reg(R.A0, 0x20000)
        machine.cpu.w_reg(R.A1, 0x50000)
        machine.cpu.w_reg(R.A2, 0x20000 + len(packed))
        machine.execute(50_000_000)
        self.assertEqual([mem.r8(0x50000 - 1 - i) for i in range(8)], [0xAA] * 8)
        self.assertEqual([mem.r8(0x50000 + len(data) + i) for i in range(8)], [0xAA] * 8)


ROM = ROOT.parent / "ext" / "Original.nes"


@unittest.skipUnless(toolchain_ok() and ROM.exists(), "needs the m68k binutils, machine68k and the ROM")
class LevelFileTests(Decoder, unittest.TestCase):
    """Every dungeon's real file, unpacked by the 68000 code in the place and the way the loader does."""

    def test_every_level_file_unpacks_in_place_to_its_image(self) -> None:
        import build_assets as B

        bundle = B.load_assets(ROOT.parent)
        with tempfile.TemporaryDirectory() as out_dir:
            out = Path(out_dir)
            B.write_underworld(out, bundle)
            buffer_bytes = int((out / "level_buffer.inc").read_text().split()[2].rstrip(","))
            names = [B.level_file_name(level) for level in bundle.levels]
            self.assertEqual(len(names), 2 * len(B.UW_LEVELS))
            for name in names:
                with self.subTest(name):
                    data = (out / name).read_bytes()
                    self.assertEqual(data[:4], B.LEVEL_FILE_MAGIC)
                    size = int.from_bytes(data[6:8], "big")
                    self.assertEqual(len(data), 8 + size)
                    base = 0x20000
                    at = (base + buffer_bytes - size) & ~1
                    made, end = self.run_decoder(data[8:], 0, at, base)
                    image_size = end - base
                    made, _ = self.run_decoder(data[8:], image_size, at, base)
                    self.assertEqual(made[:4], B.LEVEL_IMAGE_MAGIC)
                    self.assertEqual(int.from_bytes(made[6:8], "big"), image_size)
                    self.assertEqual(made, lzpack.unpack(data[8:]))
                    self.assertLessEqual(image_size, buffer_bytes)


if __name__ == "__main__":
    unittest.main()
