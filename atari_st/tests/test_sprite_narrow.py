"""draw_sprite_narrow (src/narrow.s) draws what draw_sprite does, for every shift, on machine68k."""
from __future__ import annotations

import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AS = "m68k-linux-gnu-as"
LD = "m68k-linux-gnu-ld"
OBJCOPY = "m68k-linux-gnu-objcopy"
BASE = 0x1000
SCREEN = 0x20000
STRIDE = 160
FRAME_BYTES = 160

HARNESS = """
    .equ SPRITE_HEIGHT, 16
    .equ SCREEN_STRIDE, 160
    .text
    bra.w h_wide
    bra.w h_narrow
h_wide:
    bsr draw_sprite
    bra.s .
h_narrow:
    bsr draw_sprite_narrow
    bra.s .
draw_sprite_bf:
    bra draw_sprite
"""


def toolchain_ok() -> bool:
    if not all(shutil.which(t) for t in (AS, LD, OBJCOPY)):
        return False
    try:
        import machine68k  # noqa: F401
    except ImportError:
        return False
    return True


def blitter_source() -> str:
    """The macros and draw_sprite of sprite.s (the rest of that file needs the whole game), then narrow.s."""
    text = (ROOT / "src" / "sprite.s").read_text(encoding="utf-8")
    text = text[: text.index("| Put back the background the sprite covered last frame.")]
    return HARNESS + text + (ROOT / "src" / "narrow.s").read_text(encoding="utf-8")


@unittest.skipUnless(toolchain_ok(), "needs the m68k binutils and machine68k")
class NarrowBlitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        import machine68k as m

        cls.m = m
        cls.tmp = tempfile.TemporaryDirectory()
        tmp = Path(cls.tmp.name)
        (tmp / "h.s").write_text(blitter_source(), encoding="utf-8")
        subprocess.run([AS, "-m68000", "-o", str(tmp / "h.o"), str(tmp / "h.s")], check=True, capture_output=True)
        subprocess.run([LD, f"-Ttext={BASE:#x}", "-nostdlib", "-e", "0", "-o", str(tmp / "h.elf"), str(tmp / "h.o")],
                       check=True, capture_output=True)
        subprocess.run([OBJCOPY, "-O", "binary", str(tmp / "h.elf"), str(tmp / "h.bin")], check=True)
        cls.image = (tmp / "h.bin").read_bytes()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def draw(self, entry: int, frame: bytes, background: bytes, shift: int, group: int) -> bytes:
        """Run one blitter over a copy of the background; returns the screen area afterwards."""
        m = self.m
        machine = m.Machine(m.CPUType.M68000, 512)
        mem, cpu = machine.mem, machine.cpu
        mem.w_block(BASE, self.image)
        mem.w_block(0x10000, frame)
        mem.w_block(SCREEN, background)
        cpu.set_instr_hook_callback(lambda pc: machine.abort_execute() if mem.r16(pc) == 0x60FE else None)
        R = m.Register
        cpu.w_sr(0x2700)
        cpu.w_sp(0x70000)
        cpu.w_pc(BASE + entry)
        cpu.w_reg(R.A0, 0x10000)
        cpu.w_reg(R.A1, SCREEN + group * 8)
        cpu.w_reg(R.D0, shift)
        machine.execute(1_000_000)
        return bytes(mem.r8(SCREEN + i) for i in range(len(background)))

    @staticmethod
    def narrow_frame(rng: random.Random) -> bytes:
        """Sixteen lines of four plane words and a mask word, the picture in columns 4 to 11 only (as _monster_image's
        narrow layout makes them); where the mask is clear the planes are clear too."""
        out = bytearray()
        for _ in range(16):
            mask = rng.getrandbits(16) & 0x0FF0
            planes = [rng.getrandbits(16) & mask for _ in range(4)]
            for word in planes + [mask]:
                out += word.to_bytes(2, "big")
        return bytes(out)

    def test_every_shift_gives_the_same_pixels_as_the_general_blit(self) -> None:
        rng = random.Random(20261101)
        for _ in range(6):
            frame = self.narrow_frame(rng)
            background = bytes(rng.getrandbits(8) for _ in range(STRIDE * 18))
            for shift in range(16):
                for group in (0, 2, 5):
                    wide = self.draw(0, frame, background, shift, group)
                    narrow = self.draw(4, frame, background, shift, group)
                    self.assertEqual(narrow, wide, f"shift {shift}, group {group}")

    def test_the_blit_leaves_the_other_group_alone_at_the_ends(self) -> None:
        rng = random.Random(7)
        frame = self.narrow_frame(rng)
        background = bytes(rng.getrandbits(8) for _ in range(STRIDE * 18))
        for shift, untouched in ((0, 8), (4, 8), (12, 0), (15, 0)):
            after = self.draw(4, frame, background, shift, 3)
            for line in range(16):
                row = line * STRIDE + 3 * 8
                self.assertEqual(after[row + untouched: row + untouched + 8], background[row + untouched: row + untouched + 8],
                                 f"shift {shift}, line {line}")


if __name__ == "__main__":
    unittest.main()
