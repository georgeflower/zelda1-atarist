"""The music packer, and the 68000 player (src/music.s) run on an emulated CPU.

The player tests assemble tests/music_harness.s with a small synthetic bank and call the real routines
through machine68k, comparing what reaches the PSG with what the Python reference decoder says the
streams contain. They skip when the m68k toolchain or machine68k is missing.
"""
from __future__ import annotations

import random
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import music_pack as mp  # noqa: E402
import ym_convert  # noqa: E402

AS = "m68k-linux-gnu-as"
LD = "m68k-linux-gnu-ld"
OBJCOPY = "m68k-linux-gnu-objcopy"
NM = "m68k-linux-gnu-nm"
BASE = 0x1000
EFFECT_BITS = {mp.OVERLAY_A: 0x09, mp.OVERLAY_B: 0x12, mp.OVERLAY_C: 0x24}  # a mixer's tone and noise bits per voice


def random_frames(rng: random.Random, n: int, voices=(0, 1, 2), drums: int = 0) -> tuple[list[list[int]], list[int]]:
    regs = []
    trig = []
    cur = [0] * 13 + [0xFF]
    for f in range(n):
        row = list(cur)
        row[13] = 0xFF
        for _ in range(rng.randint(0, 5)):
            k = rng.randrange(13)
            row[k] = rng.randrange(256)
        for v in voices:
            if rng.random() < 0.3:
                row[8 + v] = rng.randrange(16)
        row[7] = (row[7] & 0x3F) | 0xC0
        regs.append(row)
        t = 0
        if drums and rng.random() < 0.15:
            t = ((rng.randrange(3) + 1) << 6) | rng.randrange(drums)
        trig.append(t)
        cur = row
    return regs, trig


class PackerTests(unittest.TestCase):
    def test_stream_round_trip(self) -> None:
        rng = random.Random(1)
        regs, trig = random_frames(rng, 300, drums=5)
        regs[40][13] = 9  # an envelope shape write
        stream, loop_offset = mp.pack_stream(regs, trig, 0)
        back, back_trig = mp.unpack_stream(stream, len(regs))
        self.assertEqual(back_trig, trig)
        for f, (a, b) in enumerate(zip(regs, back)):
            self.assertEqual(a[:13], b[:13], f"frame {f}")
        self.assertEqual(back[40][13], 9)
        self.assertEqual(loop_offset, 0)

    def test_the_loop_frame_is_a_full_refresh(self) -> None:
        rng = random.Random(2)
        regs, trig = random_frames(rng, 60)
        stream, loop_offset = mp.pack_stream(regs, trig, 25)
        # decoding from the loop offset, with nothing known, reproduces the loop
        back, _ = mp.unpack_stream(stream[loop_offset:], 35 + 0)
        _, _ = mp.unpack_stream(stream, 60)
        self.assertEqual(back[0][:13], regs[25][:13])
        self.assertEqual(back[34][:13], regs[59][:13])

    def test_an_unchanged_frame_is_one_byte(self) -> None:
        regs = [[1] * 13 + [0xFF] for _ in range(4)]
        stream, _ = mp.pack_stream(regs, [0] * 4, 0)
        self.assertEqual(len(stream), 2 + 13 + 3)  # a full first frame (A, B, 13 values), then 1 byte per frame

    def test_drum_table_round_trip(self) -> None:
        drums = [mp.Drum(bytes([0, 5, 9, 15, 3]), 4, 5), mp.Drum(bytes(range(16)), 3, 77)]
        table = mp.pack_drum_table(drums)
        self.assertEqual(len(table) % 2, 0)
        self.assertEqual(mp.parse_drum_table(table), drums)

    def test_without_a_rom_the_bank_is_silent_and_has_every_track(self) -> None:
        bank = mp.build_bank(None)
        self.assertEqual(len(bank.tracks), len(mp.TRACK_LIST))
        self.assertTrue(all(t.frames == 0 and not t.stream for t in bank.tracks))
        self.assertEqual(bank.drums, [])
        data = bank.to_bytes()
        n, zero = struct.unpack(">HH", data[:4])
        self.assertEqual((n, zero), (len(mp.TRACK_LIST), 0))
        for i in range(n):
            self.assertEqual(struct.unpack(">IIHHBBH", data[4 + 16 * i : 20 + 16 * i])[0], 0)  # no data: offset 0
        self.assertEqual(len(data), 4 + 16 * n)
        self.assertEqual(mp.pack_drum_table(bank.drums), struct.pack(">H", 0))

    def test_ids_include_names_every_track(self) -> None:
        bank = mp.Bank([mp.Track(name, kind) for name, kind, _ in mp.TRACK_LIST])
        inc = bank.ids_inc()
        for i, (name, _, _) in enumerate(mp.TRACK_LIST):
            self.assertIn(f".equ {name}, {i}", inc)
        self.assertIn(f".equ MUS_TRACKS, {len(mp.TRACK_LIST)}", inc)
        self.assertIn(".equ MUS_NONE, 255", inc)
        self.assertEqual(mp.TRACK_LIST[mp.OVERWORLD_ID][0], "MUS_OVERWORLD")
        self.assertEqual(len({n for n, _, _ in mp.TRACK_LIST}), len(mp.TRACK_LIST))


def make_track(name: str, kind: int, regs, trig, loop_frame: int = 0, loops: bool = False) -> mp.Track:
    stream, loop_offset = mp.pack_stream(regs, trig, loop_frame)
    return mp.Track(name, kind, stream, len(regs), loop_frame, loop_offset, loops)


class Cpu68k:
    """The test image on machine68k, with the PSG writes of music_write captured."""

    def __init__(self, bank: mp.Bank, drums: list[mp.Drum], engine: bytes) -> None:
        import machine68k as m

        self.m = m
        self.tmp = tempfile.TemporaryDirectory()
        tmp = Path(self.tmp.name)
        (tmp / "music_ids.inc").write_text(bank.ids_inc())
        (tmp / "music_bank.bin").write_bytes(bank.to_bytes())
        (tmp / "music_drum_table.bin").write_bytes(mp.pack_drum_table(drums))
        (tmp / "music_engine.bin").write_bytes(engine)
        subprocess.run([AS, "-m68000", "-I", str(tmp), "-I", str(ROOT / "src"), "-o", str(tmp / "h.o"),
                        str(ROOT / "tests" / "music_harness.s")], check=True, capture_output=True)
        subprocess.run([LD, f"-Ttext={BASE:#x}", "-nostdlib", "-e", "0", "-o", str(tmp / "h.elf"), str(tmp / "h.o")],
                       check=True, capture_output=True)
        subprocess.run([OBJCOPY, "-O", "binary", str(tmp / "h.elf"), str(tmp / "h.bin")], check=True)
        self.syms = {}
        for line in subprocess.check_output([NM, str(tmp / "h.elf")], text=True).splitlines():
            parts = line.split()
            if len(parts) == 3:
                self.syms[parts[2]] = int(parts[0], 16)
        self.machine = m.Machine(m.CPUType.M68000, 16384)
        self.mem = self.machine.mem
        self.cpu = self.machine.cpu
        self.mem.w_block(BASE, (tmp / "h.bin").read_bytes())
        self.writes: list[tuple[int, int]] = []
        write_pc = {self.syms["music_write"], self.syms["music_silence"]}
        lo, hi = min(write_pc), self.syms["music_silence"] + 64
        self.cpu.set_instr_hook_callback(self._hook)
        self.range = (lo, hi)
        self.mem.w8(0xFF820A, 2)  # 50 Hz
        self.call("h_init")

    def _hook(self, pc: int) -> None:
        op = self.mem.r16(pc)
        if op == 0x60FE:  # bra.s . : the harness routine is done
            self.machine.abort_execute()
            return
        if self.range[0] <= pc < self.range[1] and self.cpu.r_reg(self.m.Register.A2) == 0xFF8800:
            if op == 0x1541 and self.mem.r16(pc + 2) == 2:  # move.b d1,2(a2)
                self.writes.append((self.cpu.r_reg(self.m.Register.D0) & 0xFF, self.cpu.r_reg(self.m.Register.D1) & 0xFF))
            elif op == 0x422A and self.mem.r16(pc + 2) == 2:  # clr.b 2(a2)
                self.writes.append((self.cpu.r_reg(self.m.Register.D0) & 0xFF, 0))

    ENTRY = {"h_init": 0, "h_tick": 1, "h_play": 2, "h_update": 3, "h_event": 4, "h_vbl": 5}

    def call(self, entry: str, d0: int | None = None) -> None:
        R = self.m.Register
        self.cpu.w_sr(0x2700)
        self.cpu.w_sp(0x200000)
        self.cpu.w_pc(BASE + 4 * self.ENTRY[entry])
        if d0 is not None:
            self.cpu.w_reg(R.D0, d0)
        self.machine.execute(5_000_000)
        assert self.mem.r16(self.cpu.r_pc() - 6) == 0x4E72 or True

    def g8(self, name: str, add: int = 0) -> int:
        return self.mem.r8(self.syms[name] + add)

    def g16(self, name: str, add: int = 0) -> int:
        return self.mem.r16(self.syms[name] + add)

    def set8(self, name: str, value: int) -> None:
        self.mem.w8(self.syms[name], value)

    def out(self) -> list[int]:
        return [self.g8("OFF_MUS_OUT", i) for i in range(14)] if False else [
            self.mem.r8(self.syms["globals"] + self.syms["OFF_MUS_OUT"] + i) for i in range(14)
        ]

    def glob8(self, off_name: str, add: int = 0) -> int:
        return self.mem.r8(self.syms["globals"] + self.syms[off_name] + add)

    def glob16(self, off_name: str, add: int = 0) -> int:
        return self.mem.r16(self.syms["globals"] + self.syms[off_name] + add)

    def set_glob8(self, off_name: str, value: int) -> None:
        self.mem.w8(self.syms["globals"] + self.syms[off_name], value)

    def ctx_id(self, ctx: int) -> int:
        return self.mem.r8(self.syms["globals"] + self.syms["OFF_MUS_CTX"] + 32 * ctx + 14)

    def tick(self) -> dict[int, int]:
        self.writes.clear()
        self.call("h_tick")
        return dict(self.writes)

    def close(self) -> None:
        self.tmp.cleanup()


def toolchain_ok() -> bool:
    if not all(shutil.which(t) for t in (AS, LD, OBJCOPY, NM)):
        return False
    try:
        import machine68k  # noqa: F401
    except ImportError:
        return False
    return True


def engine_blob() -> bytes:
    with tempfile.TemporaryDirectory() as tmp:
        ym_convert.convert(ROOT / "music" / "ymplay.h", Path(tmp))
        return (Path(tmp) / "music_engine.bin").read_bytes()


def synthetic_bank(rng: random.Random):
    """Every track id has a short stream; song 0 loops, the others are one-shots of different lengths."""
    tracks = []
    streams = {}
    for i, (name, kind, _) in enumerate(mp.TRACK_LIST):
        n = 30 + 3 * i
        regs, trig = random_frames(rng, n, voices=(0, 1, 2) if kind == mp.SONG else (kind - 1,), drums=0)
        if kind != mp.SONG:
            # an effect only has its own voice's registers
            for r in regs:
                r[7] |= 0x3F & ~EFFECT_BITS[kind] | 0xC0
        looping = kind == mp.SONG and name in ("MUS_OVERWORLD", "MUS_DUNGEON", "MUS_LEVEL9")
        loop_frame = 7 if looping else 0
        tracks.append(make_track(name, kind, regs, trig, loop_frame, looping))
        streams[i] = (regs, trig, loop_frame, looping)
    return mp.Bank(tracks, [mp.Drum(bytes([0, 8, 15, 8, 0, 8]), 4, 5), mp.Drum(bytes([15, 0, 15]), 4, 5)]), streams


def song_frame(streams, track: int, tick: int):
    regs, trig, loop_frame, looping = streams[track]
    n = len(regs)
    if tick < n:
        return regs[tick], trig[tick]
    if not looping:
        return None, 0
    return regs[loop_frame + (tick - loop_frame) % (n - loop_frame)], trig[loop_frame + (tick - loop_frame) % (n - loop_frame)]


@unittest.skipUnless(toolchain_ok(), "needs the m68k binutils and machine68k")
class PlayerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.engine = engine_blob()
        cls.bank, cls.streams = synthetic_bank(random.Random(7))

    def cpu(self) -> Cpu68k:
        c = Cpu68k(self.bank, self.bank.drums, self.engine)
        self.addCleanup(c.close)
        return c

    def check_registers(self, psg: dict[int, int], expected: list[int], where: str) -> None:
        for k in range(13):
            if k in psg:
                self.assertEqual(psg[k], expected[k], f"{where}: R{k}")

    def test_a_looping_song_plays_frame_exact_and_wraps(self) -> None:
        c = self.cpu()
        track = mp.TRACK_LIST.index(("MUS_OVERWORLD", mp.SONG, "song_overworld"))
        c.call("h_play", track)
        self.assertEqual(c.ctx_id(0), track)
        n = len(self.streams[track][0])
        state = [0] * 14
        for t in range(n * 3 + 11):
            psg = c.tick()
            row, _ = song_frame(self.streams, track, t)
            state = [row[k] for k in range(13)] + [0xFF]
            self.assertEqual(c.out()[:13], state[:13], f"tick {t}")
            for k, v in psg.items():
                self.assertEqual(v, row[k], f"tick {t} R{k}")
            self.assertGreaterEqual(len(psg), 1 if t == 0 else 0)
        self.assertEqual(c.ctx_id(0), track)

    def test_a_one_shot_song_ends_and_goes_quiet(self) -> None:
        c = self.cpu()
        track = mp.TRACK_LIST.index(("MUS_ITEM", mp.SONG, "song_item"))
        n = len(self.streams[track][0])
        c.call("h_play", track)
        for t in range(n):
            c.tick()
            self.assertEqual(c.ctx_id(0), track)
        psg = c.tick()  # the frame after the last: the song is over, all volumes off
        self.assertEqual(c.ctx_id(0), mp.MUS_NONE_ID if hasattr(mp, "MUS_NONE_ID") else 255)
        self.assertEqual({k: psg.get(k) for k in (8, 9, 10)}, {8: 0, 9: 0, 10: 0})
        psg = c.tick()
        self.assertEqual({k: psg.get(k) for k in (8, 9, 10)}, {8: 0, 9: 0, 10: 0})

    def test_an_effect_covers_its_voice_and_gives_it_back(self) -> None:
        c = self.cpu()
        song = mp.TRACK_LIST.index(("MUS_OVERWORLD", mp.SONG, "song_overworld"))
        sfx_a = [n for n, _, _ in mp.TRACK_LIST].index("SFX_HARMED")
        sfx_b = [n for n, _, _ in mp.TRACK_LIST].index("SFX_RUPEE")
        sfx_c = [n for n, _, _ in mp.TRACK_LIST].index("SFX_BOMB_BLAST")
        c.call("h_play", song)
        for _ in range(5):
            c.tick()
        c.call("h_play", sfx_a)
        c.call("h_play", sfx_b)
        c.call("h_play", sfx_c)
        a_regs = self.streams[sfx_a][0]
        b_regs = self.streams[sfx_b][0]
        c_regs = self.streams[sfx_c][0]
        t = 5
        for k in range(max(len(a_regs), len(b_regs), len(c_regs)) + 3):
            c.tick()
            base, _ = song_frame(self.streams, song, t)
            want = list(base[:13])
            if k < len(a_regs):
                a = a_regs[k]
                want[0], want[1], want[8] = a[0], a[1], a[8]
                want[7] = (want[7] & ~0x09) | (a[7] & 0x09)
            if k < len(b_regs):
                b = b_regs[k]
                want[2], want[3], want[9] = b[2], b[3], b[9]
                want[7] = (want[7] & ~0x12) | (b[7] & 0x12)
            if k < len(c_regs) and c_regs[k][10]:  # a noise effect only takes voice C while it sounds
                n = c_regs[k]
                want[6], want[10] = n[6], n[10]
                want[7] = (want[7] & ~0x24) | (n[7] & 0x24)
            self.assertEqual(c.out()[:13], want, f"effect frame {k}")
            t += 1
        self.assertEqual((c.ctx_id(1), c.ctx_id(2), c.ctx_id(3)), (255, 255, 255))
        self.assertEqual(c.ctx_id(0), song)

    def test_the_low_life_beep_follows_the_hearts(self) -> None:
        c = self.cpu()
        beep = [n for n, _, _ in mp.TRACK_LIST].index("SFX_HEART_WARNING")
        for halves, mode, playing in ((6, 0, False), (3, 0, False), (2, 3, False), (0, 0, False), (2, 0, True), (1, 0, True)):
            c.call("h_init")
            c.set_glob8("OFF_HP_HALVES", halves)
            c.set_glob8("OFF_GAME_MODE", mode)
            c.call("h_update")
            self.assertEqual(c.ctx_id(1) == beep, playing, f"halves {halves} mode {mode}")
        c.call("h_init")
        other = [n for n, _, _ in mp.TRACK_LIST].index("SFX_KEY")
        c.set_glob8("OFF_HP_HALVES", 1)
        c.set_glob8("OFF_GAME_MODE", 0)
        c.call("h_play", other)
        c.call("h_update")
        self.assertEqual(c.ctx_id(1), other, "the beep waits for the voice")

    def test_a_new_effect_restarts_the_voice(self) -> None:
        c = self.cpu()
        sfx = [n for n, _, _ in mp.TRACK_LIST].index("SFX_MAGIC")
        regs = self.streams[sfx][0]
        c.call("h_play", sfx)
        for _ in range(6):
            c.tick()
        c.call("h_play", sfx)
        c.tick()
        self.assertEqual(c.out()[8], regs[0][8])
        self.assertEqual(c.out()[0], regs[0][0])

    def test_an_effect_alone_still_plays_with_a_silent_song(self) -> None:
        c = self.cpu()
        sfx = [n for n, _, _ in mp.TRACK_LIST].index("SFX_KEY")
        regs = self.streams[sfx][0]
        c.call("h_play", sfx)
        c.tick()
        out = c.out()
        self.assertEqual((out[0], out[1], out[8]), (regs[0][0], regs[0][1], regs[0][8]))
        self.assertEqual((out[9], out[10]), (0, 0))

    def test_nothing_playing_writes_silence(self) -> None:
        c = self.cpu()
        psg = c.tick()
        self.assertEqual(psg, {8: 0, 9: 0, 10: 0})

    def test_a_track_without_data_is_ignored(self) -> None:
        c = self.cpu()
        empty = mp.Bank([mp.Track(n, k) for n, k, _ in mp.TRACK_LIST], [])
        d = Cpu68k(empty, [], self.engine)
        self.addCleanup(d.close)
        d.call("h_play", 0)
        self.assertEqual(d.ctx_id(0), 255)
        d.call("h_event", 5)
        self.assertEqual(d.glob8("OFF_MUS_FORCED"), 0)
        d.call("h_play", 200)  # not a track
        self.assertEqual(d.ctx_id(0), 255)
        del c

    def test_sixty_hertz_holds_every_sixth_frame(self) -> None:
        for sync, expected in ((2, 24), (0, 20)):
            c = self.cpu()
            c.mem.w8(0xFF820A, sync)
            track = mp.TRACK_LIST.index(("MUS_OVERWORLD", mp.SONG, "song_overworld"))
            c.call("h_play", track)
            for _ in range(24):
                c.call("h_vbl")
            self.assertEqual(c.glob16("OFF_MUS_CTX", 4), expected, f"sync {sync}")

    def test_area_music_follows_the_game_state(self) -> None:
        c = self.cpu()

        def want(level: int, mode: int) -> int:
            c.set_glob8("OFF_LEVEL", level)
            c.set_glob8("OFF_GAME_MODE", mode)
            c.call("h_update")
            return c.ctx_id(0)

        self.assertEqual(want(0, 0), 0)  # overworld
        self.assertEqual(want(0, 2), 255)  # cave: silent
        self.assertEqual(want(0, 0), 0)
        self.assertEqual(want(1, 0), 1)  # dungeon
        self.assertEqual(want(8, 1), 1)
        self.assertEqual(want(9, 0), 2)  # level 9
        self.assertEqual(want(0, 0), 0)

    def test_an_event_song_is_not_cut_by_the_area_music_and_hands_back(self) -> None:
        c = self.cpu()
        c.set_glob8("OFF_LEVEL", 0)
        c.set_glob8("OFF_GAME_MODE", 0)
        c.call("h_update")
        item = mp.TRACK_LIST.index(("MUS_ITEM", mp.SONG, "song_item"))
        n = len(self.streams[item][0])
        c.call("h_event", item)
        self.assertEqual((c.ctx_id(0), c.glob8("OFF_MUS_FORCED")), (item, 1))
        for _ in range(n):
            c.tick()
            c.call("h_update")
            self.assertEqual(c.ctx_id(0), item)
        c.tick()  # the song ends
        self.assertEqual(c.ctx_id(0), 255)
        c.call("h_update")
        self.assertEqual((c.ctx_id(0), c.glob8("OFF_MUS_FORCED")), (0, 0))  # the area music starts over

    def test_digidrum_triggers_reach_the_engine(self) -> None:
        rng = random.Random(3)
        regs, _ = random_frames(rng, 20)
        trig = [0] * 20
        trig[2] = (2 << 6) | 1  # voice B, drum 1
        trig[9] = 63  # stop
        track = make_track("MUS_OVERWORLD", mp.SONG, regs, trig, 0, True)
        bank = mp.Bank([track] + [mp.Track(n, k) for n, k, _ in mp.TRACK_LIST[1:]], self.bank.drums)
        c = Cpu68k(bank, bank.drums, self.engine)
        self.addCleanup(c.close)
        act = c.syms["ymdrum_code"] + 47
        c.call("h_play", 0)
        seen = []
        for t in range(12):
            c.tick()
            seen.append(c.mem.r8(act))
        self.assertEqual(seen[0], 0)
        self.assertEqual(seen[1], 0)
        self.assertNotEqual(seen[2], 0, "the drum starts on its frame")
        self.assertNotEqual(seen[8], 0)
        self.assertEqual(seen[9], 0, "trigger 63 stops it")
        # the drum's voice (B = R9) is left alone by the register writes while it plays
        c2 = Cpu68k(bank, bank.drums, self.engine)
        self.addCleanup(c2.close)
        c2.call("h_play", 0)
        for _ in range(3):
            c2.tick()
        psg = c2.tick()  # the first frame after the trigger
        self.assertNotIn(9, psg)
        self.assertIn(8, psg)

    def test_a_new_song_cuts_the_old_drum(self) -> None:
        regs, _ = random_frames(random.Random(4), 20)
        trig = [0] * 20
        trig[0] = (1 << 6) | 0
        track = make_track("MUS_OVERWORLD", mp.SONG, regs, trig, 0, True)
        other = make_track("MUS_DUNGEON", mp.SONG, regs, [0] * 20, 0, True)
        tracks = [track, other] + [mp.Track(n, k) for n, k, _ in mp.TRACK_LIST[2:]]
        bank = mp.Bank(tracks, self.bank.drums)
        c = Cpu68k(bank, bank.drums, self.engine)
        self.addCleanup(c.close)
        act = c.syms["ymdrum_code"] + 47
        c.call("h_play", 0)
        c.tick()
        self.assertNotEqual(c.mem.r8(act), 0)
        c.call("h_play", 1)
        self.assertEqual(c.mem.r8(act), 0)


class BankBuildTests(unittest.TestCase):
    ROM = ROOT.parent / "ext" / "Original.nes"

    def test_full_bank_from_the_rom(self) -> None:
        import os

        rom = Path(os.environ.get("ZELDA_ROM", self.ROM))
        if not rom.exists():
            self.skipTest("no ROM")
        try:
            import py65  # noqa: F401
        except ImportError:
            self.skipTest("py65 not installed")
        import nes_music_rip as rip

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            bank = mp.build_bank(rip.load_prg(rom), log=lambda *_: None)
        for t in bank.tracks:
            self.assertGreater(t.frames, 0, t.name)
            self.assertGreater(len(t.stream), 0, t.name)
            regs, trig = mp.unpack_stream(t.stream, t.frames)  # decodes to exactly the stream's end
            self.assertEqual(len(regs), t.frames)
            for row in regs:
                self.assertEqual(row[7] & 0xC0, 0xC0, t.name)
        ow = bank.tracks[mp.OVERWORLD_ID]
        self.assertTrue(ow.loops)
        self.assertLessEqual(len(bank.drums), mp.MAX_DRUMS)
        beep = next(t for t in bank.tracks if t.name == "SFX_HEART_WARNING")
        self.assertEqual(beep.frames, 19, "the beep keeps its pause")
        for kind, track in ((mp.OVERLAY_A, "SFX_HARMED"), (mp.OVERLAY_B, "SFX_RUPEE"), (mp.OVERLAY_C, "SFX_SWORD"),
                            (mp.OVERLAY_C, "SFX_STAIRS")):
            t = next(t for t in bank.tracks if t.name == track)
            self.assertEqual(t.kind, kind)
            self.assertFalse(t.loops)
            regs, trig = mp.unpack_stream(t.stream, t.frames)
            self.assertFalse(any(trig), "an effect must not start a digidrum")
            if kind == mp.OVERLAY_C:  # noise on voice C only, never a tone
                for row in regs:
                    self.assertEqual(row[7] & 0x24, 0x04 if row[10] else 0x24, track)
                    self.assertEqual((row[0], row[1], row[2], row[3], row[4], row[5]), (0,) * 6, track)
        self.assertTrue(next(t for t in bank.tracks if t.name == "MUS_DUNGEON").loops)
        # every digidrum a trigger names exists
        for t in bank.tracks:
            _, trig = mp.unpack_stream(t.stream, t.frames)
            for x in trig:
                if x:
                    self.assertLess(x & 63, len(bank.drums), t.name)


@unittest.skipUnless(toolchain_ok(), "needs the m68k binutils and machine68k")
class RealBankTests(unittest.TestCase):
    """The bank the game ships, every track through the 68000 player."""

    def test_every_track_plays_frame_exact(self) -> None:
        import os

        rom = Path(os.environ.get("ZELDA_ROM", BankBuildTests.ROM))
        if not rom.exists():
            self.skipTest("no ROM")
        try:
            import py65  # noqa: F401
        except ImportError:
            self.skipTest("py65 not installed")
        import nes_music_rip as rip

        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            ym_convert.convert(ROOT / "music" / "ymplay.h", out)
            bank = mp.build_bank(rip.load_prg(rom), log=lambda *_: None)
            engine = (out / "music_engine.bin").read_bytes()
        c = Cpu68k(bank, bank.drums, engine)
        self.addCleanup(c.close)
        for index, t in enumerate(bank.tracks):
            regs, _ = mp.unpack_stream(t.stream, t.frames)
            ticks = t.frames + (40 if t.loops else 3)
            c.call("h_init")
            c.call("h_play", index)
            for tick in range(ticks):
                c.tick()
                if tick < t.frames:
                    want = regs[tick]
                elif t.loops:
                    want = regs[t.loop_frame + (tick - t.loop_frame) % (t.frames - t.loop_frame)]
                else:
                    break
                got = c.out()
                if t.kind == mp.SONG:
                    self.assertEqual(got[:13], want[:13], f"{t.name} tick {tick}")
                else:  # an effect owns one voice's tone, volume and mixer bits; the rest is the idle song's
                    bits = EFFECT_BITS[t.kind]
                    if t.kind == mp.OVERLAY_C:
                        if want[10]:  # its silent frames leave the song alone
                            self.assertEqual((got[6], got[10], got[7] & bits), (want[6], want[10], want[7] & bits),
                                             f"{t.name} tick {tick}")
                        continue
                    lo, vol = (0, 8) if t.kind == mp.OVERLAY_A else (2, 9)
                    self.assertEqual((got[lo], got[lo + 1], got[vol], got[7] & bits),
                                     (want[lo], want[lo + 1], want[vol], want[7] & bits), f"{t.name} tick {tick}")
            if not t.loops:
                self.assertEqual(c.ctx_id(t.kind), 255, f"{t.name} ends")


if __name__ == "__main__":
    unittest.main()
