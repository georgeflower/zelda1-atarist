#!/usr/bin/env python3
"""Rip the Zelda 1 music from a ROM you supply and write it as YM2149 ``.ym`` files.

How it works
------------
1. The game's own sound code (``DriveAudio``, bank 0) is run in a small 6502 emulator (py65),
   once per video frame, for every song / jingle request the game can make.
2. Every write to the NES sound chip ($4000-$4017) is logged per frame.
3. A frame-accurate model of the NES sound chip (length counters, envelopes, the triangle's
   linear counter, the frame sequencer the game resets every frame) turns the writes into
   "what is audible in this frame" for pulse 1, pulse 2, triangle and noise.
4. That is mapped to the YM2149 (3 tone voices + 1 noise generator) and written as a YM6 file:
   pulse 1 -> voice A, pulse 2 -> voice B, triangle -> voice C, noise drums either on the noise
   generator (``--drums noise``) or as digidrums (``--drums digidrum``).

The output is derived from the ROM. Do not commit it (``*.ym`` is gitignored).

    python3 atari_st/tools/nes_music_rip.py --rom ext/Original.nes --out-dir build/ym

Needs ``py65`` (``pip install py65``).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from dataclasses import dataclass, field
from pathlib import Path

BANK_SIZE = 0x4000
SENTINEL = 0xFF00  # return address of the call into DriveAudio; never executed

CPU_CLOCK = {"pal": 1_662_607.0, "ntsc": 1_789_773.0}
NOISE_PERIODS = {
    "ntsc": [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068],
    "pal": [4, 8, 14, 30, 60, 88, 118, 148, 188, 236, 354, 472, 708, 944, 1890, 3778],
}
LENGTHS = [
    10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
    12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30,
]

YM_CLOCK = 2_000_000
YM_RATE = 50
# The NES noise channel is white noise at full amplitude, which sounds louder on the YM2149 than the
# same level on a tone. Noise and drum levels are therefore anchored two steps lower than tones.
NOISE_BASE = 12
MFP_CLOCK = 2_457_600
# digidrum playback: prescaler code 4 = /50, count 5 -> 9830.4 Hz
DRUM_PREDIV_CODE, DRUM_PREDIV, DRUM_COUNT = 4, 50, 5
DRUM_RATE = MFP_CLOCK / (DRUM_PREDIV * DRUM_COUNT)

# (file stem, kind, request value, description). Values are what the game stores in the request
# variables ($600 song, $602 tune 1, $604 tune 0); see src/Z_00.asm (DriveSong / DriveTune*).
TRACKS: list[tuple[str, str, int, str]] = [
    ("song_title", "song", 0x80, "Title screen / story"),
    ("song_overworld", "song", 0x01, "Overworld"),
    ("song_dungeon", "song", 0x40, "Dungeon (levels 1-8)"),
    ("song_level9", "song", 0x20, "Level 9"),
    ("song_ending", "song", 0x10, "Ending"),
    ("song_item", "song", 0x08, "Item fanfare (heart container, Triforce piece in cave)"),
    ("song_triforce", "song", 0x04, "End of level (Triforce piece)"),
    ("song_ganon", "song", 0x02, "Ganon / Triforce of Power scene"),
    ("song_zelda", "song", 0x06, "Zelda rescue fanfare"),
    ("jingle_rupee", "tune1", 0x01, "Rupee taken / selection changed"),
    ("jingle_item_appears", "tune1", 0x02, "Item appears"),
    ("jingle_secret", "tune1", 0x04, "Secret found"),
    ("jingle_item_taken", "tune1", 0x08, "Item taken / fairy appears"),
    ("jingle_recorder", "tune1", 0x10, "Recorder (flute)"),
    ("jingle_monster_died", "tune1", 0x20, "Monster died"),
    ("jingle_game_over", "tune1", 0x40, "Game over"),
    ("jingle_link_dies", "tune1", 0x80, "Link dies"),
    ("sfx_parry", "tune0", 0x01, "Parry / sword clink"),
    ("sfx_harmed", "tune0", 0x02, "Link harmed"),
    ("sfx_magic", "tune0", 0x04, "Magic shot"),
    ("sfx_key", "tune0", 0x08, "Key taken"),
    ("sfx_heart", "tune0", 0x10, "Heart taken / text character"),
    ("sfx_bomb_set", "tune0", 0x20, "Bomb set / menu click"),
    ("sfx_heart_warning", "tune0", 0x40, "Low-hearts beep"),
]
REQUEST_ADDR = {"song": 0x600, "tune1": 0x602, "tune0": 0x604}
STATE_ADDR = {"song": 0x609, "tune1": 0x607, "tune0": 0x605}


# --------------------------------------------------------------------------- ROM and 6502


def load_prg(path: Path) -> bytes:
    data = path.read_bytes()
    if data[:4] != b"NES\x1a":
        raise SystemExit(f"{path}: not an iNES ROM")
    prg = data[4] * BANK_SIZE
    start = 16 + (512 if data[6] & 4 else 0)
    if prg < 8 * BANK_SIZE or len(data) < start + prg:
        raise SystemExit(f"{path}: expected 128 KB of PRG (a Zelda 1 ROM)")
    return data[start : start + prg]


def find_drive_audio(bank0: bytes) -> int:
    """Address of DriveAudio: `LDA Paused / BEQ +12 / LDA #0 / STA $4015 / LDA #$0F / STA $4015 / BNE`."""
    pattern = re.compile(rb"\xA5.\xF0\x0C\xA9\x00\x8D\x15\x40\xA9\x0F\x8D\x15\x40\xD0", re.S)
    matches = list(pattern.finditer(bank0))
    if len(matches) != 1:
        raise SystemExit("could not find DriveAudio in bank 0 (is this a Zelda 1 ROM?)")
    return 0x8000 + matches[0].start()


class Memory(list):
    """64 KB address space that logs APU register writes."""

    def __init__(self) -> None:
        super().__init__([0] * 0x10000)
        self.apu_log: list[tuple[int, int]] = []

    def __setitem__(self, addr, value):  # type: ignore[override]
        if isinstance(addr, int) and 0x4000 <= addr <= 0x4017:
            self.apu_log.append((addr, value & 0xFF))
        super().__setitem__(addr, value)


class SoundCpu:
    """The game's sound engine running in a 6502 emulator."""

    def __init__(self, prg: bytes) -> None:
        try:
            from py65.devices.mpu6502 import MPU
        except ImportError as exc:  # pragma: no cover
            raise SystemExit("py65 is required: pip install py65") from exc
        self.mem = Memory()
        bank0 = prg[:BANK_SIZE]
        self.mem[0x8000:0xC000] = list(bank0)
        self.mem[0xC000:0x10000] = list(prg[7 * BANK_SIZE : 8 * BANK_SIZE])
        self.drive_audio = find_drive_audio(bank0)
        self.mpu = MPU(memory=self.mem)

    def request(self, kind: str, value: int) -> None:
        self.mem[REQUEST_ADDR[kind]] = value

    def playing(self, kind: str) -> bool:
        return self.mem[STATE_ADDR[kind]] != 0

    def run_frame(self) -> list[tuple[int, int]]:
        self.mem.apu_log = []
        mpu = self.mpu
        mpu.sp = 0xFD
        mpu.stPushWord(SENTINEL - 1)
        mpu.pc = self.drive_audio
        for _ in range(200_000):
            if mpu.pc == SENTINEL:
                break
            mpu.step()
        else:  # pragma: no cover
            raise RuntimeError("DriveAudio did not return")
        return self.mem.apu_log

    def state_key(self) -> bytes:
        return hashlib.blake2b(bytes(self.mem[0:0x800]), digest_size=16).digest()


# --------------------------------------------------------------------------- NES sound chip model


class _Envelope:
    def __init__(self) -> None:
        self.halt = False  # also "loop"
        self.const = False
        self.vol = 0
        self.start = False
        self.divider = 0
        self.decay = 0

    def set_reg(self, v: int) -> None:
        self.halt = bool(v & 0x20)
        self.const = bool(v & 0x10)
        self.vol = v & 0x0F

    def clock(self) -> None:
        if self.start:
            self.start = False
            self.decay = 15
            self.divider = self.vol
        elif self.divider == 0:
            self.divider = self.vol
            if self.decay > 0:
                self.decay -= 1
            elif self.halt:
                self.decay = 15
        else:
            self.divider -= 1

    def level(self) -> int:
        return self.vol if self.const else self.decay


class _Pulse(_Envelope):
    def __init__(self) -> None:
        super().__init__()
        self.duty = 0
        self.tlo = 0
        self.thi = 0
        self.length = 0
        self.enabled = True

    def write(self, reg: int, v: int) -> None:
        if reg == 0:
            self.duty = v >> 6
            self.set_reg(v)
        elif reg == 2:
            self.tlo = v
        elif reg == 3:
            self.thi = v & 7
            if self.enabled:
                self.length = LENGTHS[v >> 3]
            self.start = True

    @property
    def period(self) -> int:
        return (self.thi << 8) | self.tlo

    def clock_half(self) -> None:
        if self.length and not self.halt:
            self.length -= 1


class _Triangle:
    def __init__(self) -> None:
        self.control = False
        self.reload_value = 0
        self.linear = 0
        self.reload_flag = False
        self.tlo = 0
        self.thi = 0
        self.length = 0
        self.enabled = True

    def write(self, reg: int, v: int) -> None:
        if reg == 8:
            self.control = bool(v & 0x80)
            self.reload_value = v & 0x7F
        elif reg == 0xA:
            self.tlo = v
        elif reg == 0xB:
            self.thi = v & 7
            if self.enabled:
                self.length = LENGTHS[v >> 3]
            self.reload_flag = True

    @property
    def period(self) -> int:
        return (self.thi << 8) | self.tlo

    def clock_quarter(self) -> None:
        if self.reload_flag:
            self.linear = self.reload_value
        elif self.linear:
            self.linear -= 1
        if not self.control:
            self.reload_flag = False

    def clock_half(self) -> None:
        if self.length and not self.control:
            self.length -= 1

    def active(self) -> bool:
        return self.enabled and self.length > 0 and self.linear > 0 and self.period >= 2


class _Noise(_Envelope):
    def __init__(self) -> None:
        super().__init__()
        self.mode = 0
        self.index = 0
        self.length = 0
        self.enabled = True
        self.trigger = False

    def write(self, reg: int, v: int) -> None:
        if reg == 0xC:
            self.set_reg(v)
        elif reg == 0xE:
            self.mode = v >> 7
            self.index = v & 15
        elif reg == 0xF:
            if self.enabled:
                self.length = LENGTHS[v >> 3]
            self.start = True
            self.trigger = True

    def clock_half(self) -> None:
        if self.length and not self.halt:
            self.length -= 1


@dataclass
class Frame:
    """What is audible during one 50/60 Hz frame."""

    pulse: list[tuple[int, int, int]] = field(default_factory=lambda: [(0, 0, 0), (0, 0, 0)])  # (vol, timer, duty)
    tri: int = 0  # timer, 0 = silent
    noise: tuple[int, int, int] = (0, 0, 0)  # (vol, period index, mode)
    noise_hit: bool = False  # the noise length counter was reloaded in this frame


class Apu:
    """Frame-level model of the NES sound chip, driven the way Zelda drives it.

    The game writes $4017 at the start of every frame. That clocks the quarter and half frame
    units once, then the five-step sequencer clocks quarter frames at 1/4, 2/4 (+half) and 3/4
    of the frame before the next reset. So per frame: 4 quarter clocks, 2 half clocks.
    """

    def __init__(self) -> None:
        self.p = [_Pulse(), _Pulse()]
        self.tri = _Triangle()
        self.noise = _Noise()

    def _quarter(self) -> None:
        self.p[0].clock()
        self.p[1].clock()
        self.noise.clock()
        self.tri.clock_quarter()

    def _half(self) -> None:
        self.p[0].clock_half()
        self.p[1].clock_half()
        self.noise.clock_half()
        self.tri.clock_half()

    def _write(self, addr: int, v: int) -> None:
        reg = addr & 0x1F
        if reg < 4:
            self.p[0].write(reg, v)
        elif reg < 8:
            self.p[1].write(reg - 4, v)
        elif reg < 0xC:
            self.tri.write(reg, v)
        elif reg < 0x10:
            self.noise.write(reg, v)
        elif reg == 0x15:
            for chan, bit in ((self.p[0], 1), (self.p[1], 2), (self.tri, 4), (self.noise, 8)):
                chan.enabled = bool(v & bit)
                if not chan.enabled:
                    chan.length = 0
        elif reg == 0x17 and v & 0x80:
            self._quarter()
            self._half()

    def step(self, writes: list[tuple[int, int]]) -> Frame:
        self.noise.trigger = False
        for addr, v in writes:
            self._write(addr, v)
        out = Frame()
        gate = [ch.enabled and ch.length > 0 for ch in self.p]
        noise_gate = self.noise.enabled and self.noise.length > 0
        self._quarter()  # 1/4
        if self.tri.active():
            out.tri = self.tri.period
        self._quarter()  # 2/4
        self._half()
        self._quarter()  # 3/4
        for i, ch in enumerate(self.p):
            vol = ch.level() if gate[i] and ch.period >= 8 else 0
            out.pulse[i] = (vol, ch.period, ch.duty)
        n = self.noise
        out.noise = (n.level() if noise_gate else 0, n.index, n.mode)
        out.noise_hit = n.trigger
        return out


# --------------------------------------------------------------------------- ripping


@dataclass
class Rip:
    frames: list[Frame]
    loop_frame: int
    looped: bool


def rip_track(cpu: SoundCpu, kind: str, value: int, max_frames: int, tail: int = 12) -> Rip:
    cpu.request(kind, value)
    apu = Apu()
    frames: list[Frame] = []
    seen: dict[bytes, int] = {}
    idle = 0
    for index in range(max_frames):
        key = cpu.state_key()
        # An identical engine state while something still plays is the loop point. Once the engine is
        # idle the state repeats trivially, so that is the end of a one-shot track, not a loop.
        if index > 0 and key in seen and idle == 0:
            return Rip(frames, seen[key], True)
        seen[key] = index
        frames.append(apu.step(cpu.run_frame()))
        if not (cpu.playing("song") or cpu.playing("tune0") or cpu.playing("tune1")):
            idle += 1
            if idle > tail:
                break
        else:
            idle = 0
    else:
        raise SystemExit(f"track {kind} {value:#x}: no end or loop within {max_frames} frames")
    return Rip(frames, 0, False)


# --------------------------------------------------------------------------- NES -> YM2149


def ym_volume(level: int, base: int = 14) -> int:
    """NES 0-15 (linear-ish) -> YM 0-15 (about 3 dB per step)."""
    if level <= 0:
        return 0
    return max(1, min(15, round(base + 2 * math.log2(level / 15))))


def tone_period(timer: int, clock: float, octave_shift: int = 0) -> int:
    """YM tone period for an NES timer value (pulse: octave_shift 0, triangle: 1)."""
    period = round((timer + 1) * (1 << octave_shift) * YM_CLOCK / clock)
    while period > 4095:
        period //= 2
    return max(1, period)


def noise_lfsr_samples(
    index: int, mode: int, clock: float, table: str, volume: int, frames: int
) -> list[bytes]:
    """The NES noise channel at `volume` for `frames` video frames, resampled to the digidrum rate.

    Returned as one 4-bit sample (YM volume levels) per frame. Players disagree on whether a drum
    that is still playing is cut, restarted or left alone when the next frame carries no new trigger,
    so every frame triggers its own piece, and each piece ends where its frame ends.
    """
    per_frame = DRUM_RATE / YM_RATE
    count = max(1, round(frames * per_frame))
    step_rate = clock / NOISE_PERIODS[table][index]
    steps_needed = int(count * step_rate / DRUM_RATE) + 2
    shift = 0x2A5B  # the NES register holds an arbitrary state by the time a song plays
    bits = []
    tap = 6 if mode else 1
    for _ in range(steps_needed):
        bits.append(shift & 1)
        feedback = (shift & 1) ^ ((shift >> tap) & 1)
        shift = (shift >> 1) | (feedback << 14)
    level = ym_volume(volume, NOISE_BASE)  # 4-bit sample = the YM volume register value (song attribute bit 2)
    whole = bytes(0 if bits[int(i * step_rate / DRUM_RATE)] else level for i in range(count))
    cuts = [round(k * per_frame) for k in range(frames)] + [count]
    return [whole[cuts[k] : cuts[k + 1]] for k in range(frames)]


@dataclass
class Drum:
    start: int
    frames: int
    key: tuple[int, int, int, int]  # (volume, period index, mode, frames)


def find_drums(frames: list[Frame]) -> list[Drum]:
    drums = []
    for f, frame in enumerate(frames):
        vol, index, mode = frame.noise
        if not (frame.noise_hit and vol > 0):
            continue
        length = 1
        while f + length < len(frames) and frames[f + length].noise[0] > 0 and not frames[f + length].noise_hit:
            length += 1
        drums.append(Drum(f, length, (vol, index, mode, length)))
    return drums


def noise_register(index: int, clock: float, table: str) -> int:
    rate = clock / NOISE_PERIODS[table][index]
    return max(1, min(31, round(YM_CLOCK / 16 / rate)))


def to_ym_registers(
    rip: Rip, clock: float, table: str, drums_mode: str, tri_volume: int
) -> tuple[list[list[int]], list[bytes]]:
    """Returns (one 16-register list per frame, digidrum samples)."""
    frames = rip.frames
    regs = [[0] * 16 for _ in frames]
    volumes = [[0, 0, 0] for _ in frames]
    for f, frame in enumerate(frames):
        r = regs[f]
        mixer = 0xC0 | 0x38  # port bits set, noise off everywhere
        for v in range(2):
            vol, timer, duty = frame.pulse[v]
            vol = ym_volume(vol)
            if vol:
                vol = max(1, vol - {0: 2, 1: 1, 2: 0, 3: 1}[duty])
                period = tone_period(timer, clock)
                r[v * 2], r[v * 2 + 1] = period & 255, period >> 8
            else:
                mixer |= 1 << v
            r[8 + v] = vol
            volumes[f][v] = vol
        if frame.tri:
            period = tone_period(frame.tri, clock, 1)
            r[4], r[5] = period & 255, period >> 8
            r[10] = tri_volume
            volumes[f][2] = tri_volume
        else:
            mixer |= 4
        r[7] = mixer
        r[13] = 0xFF
    samples: list[bytes] = []
    found = find_drums(frames)
    if drums_mode == "noise":
        for d in found:
            for f in range(d.start, d.start + d.frames):
                vol, index, _ = frames[f].noise
                if vol <= 0:
                    continue
                r = regs[f]
                r[6] = noise_register(index, clock, table)
                r[7] &= ~0x20  # noise on voice C (bass); its tone stays if the triangle plays
                r[10] = max(r[10], ym_volume(vol, NOISE_BASE))
    else:
        index_of: dict[tuple[int, int, int, int], int] = {}
        for d in found:
            vol, idx, mode, length = d.key
            if d.key not in index_of:
                if len(samples) + length > 32:
                    raise SystemExit("more than 32 digidrum pieces needed (a sample number is 5 bits)")
                index_of[d.key] = len(samples)
                samples.extend(noise_lfsr_samples(idx, mode, clock, table, vol, length))
            end = min(len(frames), d.start + d.frames)
            voice = min(range(3), key=lambda v: (sum(volumes[f][v] for f in range(d.start, end)), -v))
            for k, f in enumerate(range(d.start, end)):
                r = regs[f]
                r[1] = (r[1] & 0x0F) | 0x40 | ((voice + 1) << 4)  # effect 1: digidrum on `voice`
                r[6] = (r[6] & 0x1F) | (DRUM_PREDIV_CODE << 5)
                r[14] = DRUM_COUNT
                r[8 + voice] = index_of[d.key] + k
                r[7] |= 1 << voice  # the drum owns the voice: no tone under it
    return regs, samples


# --------------------------------------------------------------------------- .ym writer


def write_ym(
    path: Path,
    regs: list[list[int]],
    loop_frame: int,
    samples: list[bytes],
    title: str,
    author: str,
    comment: str,
) -> None:
    """YM6 file, interleaved register data (attribute bit 0), 4-bit digidrums (bit 2), not LHA-packed."""
    out = bytearray(b"YM6!LeOnArD!")
    out += struct.pack(">IIHIHIH", len(regs), 0b101, len(samples), YM_CLOCK, YM_RATE, loop_frame, 0)
    for sample in samples:
        out += struct.pack(">I", len(sample)) + sample
    for text in (title, author, comment):
        out += text.encode("latin-1", "replace") + b"\0"
    for reg in range(16):
        out += bytes(frame[reg] & 0xFF for frame in regs)
    out += b"End!"
    path.write_bytes(bytes(out))


def read_ym(path: Path) -> dict:
    """Minimal YM5/YM6 reader (uncompressed, interleaved or not) used by the tests."""
    data = path.read_bytes()
    assert data[:4] in (b"YM5!", b"YM6!") and data[4:12] == b"LeOnArD!"
    n, attrs, drums, clock, rate, loop, extra = struct.unpack(">IIHIHIH", data[12:34])
    pos = 34 + extra
    samples = []
    for _ in range(drums):
        (size,) = struct.unpack(">I", data[pos : pos + 4])
        samples.append(data[pos + 4 : pos + 4 + size])
        pos += 4 + size
    strings = []
    for _ in range(3):
        end = data.index(b"\0", pos)
        strings.append(data[pos:end].decode("latin-1"))
        pos = end + 1
    block = data[pos : pos + 16 * n]
    if attrs & 1:
        regs = [[block[r * n + f] for r in range(16)] for f in range(n)]
    else:
        regs = [list(block[f * 16 : f * 16 + 16]) for f in range(n)]
    assert data[pos + 16 * n : pos + 16 * n + 4] == b"End!"
    return {"frames": n, "clock": clock, "rate": rate, "loop": loop, "samples": samples, "strings": strings, "regs": regs}


# --------------------------------------------------------------------------- command line


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rom", type=Path, required=True, help="Zelda 1 .nes ROM (PAL or NTSC)")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--clock", choices=("pal", "ntsc"), default="pal",
                        help="NES CPU clock used for pitch: pal = how the PAL ROM sounds on a PAL NES (default)")
    parser.add_argument("--drums", choices=("noise", "digidrum", "both"), default="both",
                        help="noise: YM noise generator on voice C; digidrum: NES noise rendered as digidrums; both: two files")
    parser.add_argument("--only", action="append", help="track stem(s) to rip, e.g. song_overworld")
    parser.add_argument("--max-frames", type=int, default=30000)
    parser.add_argument("--tri-volume", type=int, default=13, help="YM volume of the triangle voice (0-15)")
    parser.add_argument("--list", action="store_true", help="list the tracks and exit")
    args = parser.parse_args()

    if args.list:
        for stem, kind, value, text in TRACKS:
            print(f"{stem:22} {kind:6} request ${value:02X}  {text}")
        return

    prg = load_prg(args.rom)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    modes = ["noise", "digidrum"] if args.drums == "both" else [args.drums]
    manifest = []
    for stem, kind, value, text in TRACKS:
        if args.only and stem not in args.only:
            continue
        cpu = SoundCpu(prg)  # fresh RAM for every track
        rip = rip_track(cpu, kind, value, args.max_frames)
        seconds = len(rip.frames) / YM_RATE
        entry = {"track": stem, "description": text, "frames": len(rip.frames), "seconds": round(seconds, 2),
                 "loop_frame": rip.loop_frame, "loops": rip.looped, "files": []}
        for mode in modes:
            regs, samples = to_ym_registers(rip, CPU_CLOCK[args.clock], args.clock, mode, args.tri_volume)
            name = f"{stem}_{'digi' if mode == 'digidrum' else 'noise'}.ym" if len(modes) > 1 else f"{stem}.ym"
            write_ym(args.out_dir / name, regs, rip.loop_frame, samples,
                     f"Zelda 1 - {text}", "Koji Kondo (NES), ripped", f"nes_music_rip.py, {args.clock} clock, drums={mode}")
            entry["files"].append({"file": name, "drums": mode, "digidrums": len(samples)})
        manifest.append(entry)
        print(f"{stem:22} {len(rip.frames):6} frames {seconds:7.1f} s  loop@{rip.loop_frame if rip.looped else '-':>5}  {text}")
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
