#!/usr/bin/env python3
"""Pack every track the game can play into one bank the 68000 music player reads.

Input
  * every song, jingle and effect, ripped from the ROM with nes_music_rip.py.

The register stream is the MOD/XM -> YM tool's game-kit format, see music/ymplay.h and
music.s (`music_step`):  per frame  A = bit7 "B follows" | mask R0-R6,  B = bit7 "trigger follows" |
mask R7-R13,  [trigger = ((voice + 1) << 6) | drum, 63 = stop],  then one byte per set mask bit.

Outputs (in --out-dir)
  music_bank.bin        .w tracks, .w 0, then 16-byte entries, then the streams (see BANK below)
  music_drum_table.bin  one digidrum table for all tracks (the engine is initialised with it once)
  music_ids.inc         .equ for every track id, MUS_TRACKS, MUS_NONE

Without a ROM (or without py65) every track is empty: the game still builds and runs, silently.
"""
from __future__ import annotations

import argparse
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

NREGS = 14

# kind of a track: how the player uses it
SONG, OVERLAY_A, OVERLAY_B, OVERLAY_C = 0, 1, 2, 3  # C: noise effects (R6, R10 and the noise gate on voice C)

# The low-life beep repeats whenever it has finished, so the original's pause after the beep is part of
# it: 6 frames of sound, then silence until frame 19 (the engine's own length) before it may start again.
KEEP_FRAMES = {"SFX_HEART_WARNING": 19}

# (id name, kind, rip stem, shown in music_ids.inc as). Order = track id.
TRACK_LIST: list[tuple[str, int, str]] = [
    ("MUS_OVERWORLD", SONG, "song_overworld"),
    ("MUS_DUNGEON", SONG, "song_dungeon"),
    ("MUS_LEVEL9", SONG, "song_level9"),
    ("MUS_TITLE", SONG, "song_title"),
    ("MUS_ENDING", SONG, "song_ending"),
    ("MUS_ITEM", SONG, "song_item"),
    ("MUS_TRIFORCE", SONG, "song_triforce"),
    ("MUS_GANON", SONG, "song_ganon"),
    ("MUS_ZELDA", SONG, "song_zelda"),
    ("MUS_GAMEOVER", SONG, "jingle_game_over"),
    ("MUS_DEATH", SONG, "jingle_link_dies"),
    ("SFX_PARRY", OVERLAY_A, "sfx_parry"),
    ("SFX_HARMED", OVERLAY_A, "sfx_harmed"),
    ("SFX_MAGIC", OVERLAY_A, "sfx_magic"),
    ("SFX_KEY", OVERLAY_A, "sfx_key"),
    ("SFX_HEART", OVERLAY_A, "sfx_heart"),
    ("SFX_BOMB", OVERLAY_A, "sfx_bomb_set"),
    ("SFX_HEART_WARNING", OVERLAY_A, "sfx_heart_warning"),
    ("SFX_RUPEE", OVERLAY_B, "jingle_rupee"),
    ("SFX_ITEM_APPEARS", OVERLAY_B, "jingle_item_appears"),
    ("SFX_SECRET", OVERLAY_B, "jingle_secret"),
    ("SFX_ITEM_TAKEN", OVERLAY_B, "jingle_item_taken"),
    ("SFX_RECORDER", OVERLAY_B, "jingle_recorder"),
    ("SFX_MONSTER_DIED", OVERLAY_B, "jingle_monster_died"),
    ("SFX_SWORD", OVERLAY_C, "sfx_sword"),
    ("SFX_ARROW", OVERLAY_C, "sfx_arrow"),
    ("SFX_FLAME", OVERLAY_C, "sfx_flame"),
    ("SFX_STAIRS", OVERLAY_C, "sfx_stairs"),
    ("SFX_BOMB_BLAST", OVERLAY_C, "sfx_bomb_blast"),
    # The DPCM samples (SampleRequest): a digidrum on voice C, one track each
    ("SMP_BEAM", OVERLAY_C, "smp_sword_beam"),
    ("SMP_BOSS_HIT", OVERLAY_C, "smp_boss_hit"),
    ("SMP_DOOR", OVERLAY_C, "smp_door"),
    ("SMP_HURT", OVERLAY_C, "smp_link_hurt"),
    ("SMP_ROAR_BIG", OVERLAY_C, "smp_roar_big"),
    ("SMP_ROAR_LOW", OVERLAY_C, "smp_roar_low"),
    ("SMP_ROAR_WAIL", OVERLAY_C, "smp_roar_wail"),
]
OVERWORLD_ID = 0
MAX_DRUMS = 62  # trigger code 63 stops a drum

ENTRY_BYTES = 16
HEADER_BYTES = 4


# --------------------------------------------------------------------------- stream format


def pack_stream(regs: list[list[int]], trig: list[int], loop_frame: int) -> tuple[bytes, int]:
    """The game-kit delta stream (no timer effects). The loop frame starts with a full refresh."""
    uses_env = any((r[8] | r[9] | r[10]) & 16 for r in regs)
    out = bytearray()
    cur: list[int] | None = None
    loop_offset = 0
    for f, r in enumerate(regs):
        if f == loop_frame:
            loop_offset = len(out)
            cur = None
        mask = 0
        for k in range(NREGS - 1):
            if cur is None or r[k] != cur[k]:
                mask |= 1 << k
        if uses_env and r[13] != 0xFF:
            mask |= 1 << 13
        a = mask & 0x7F
        b = (mask >> 7) & 0x7F
        t = trig[f]
        if b or t:
            a |= 0x80
        out.append(a)
        if b or t:
            out.append(b | (0x80 if t else 0))
        if t:
            out.append(t)
        for k in range(NREGS):
            if mask & (1 << k):
                out.append(r[k] & 0xFF)
        cur = r
    return bytes(out), loop_offset


def unpack_stream(data: bytes, frames: int) -> tuple[list[list[int]], list[int]]:
    """Inverse of pack_stream: registers per frame (R13 = 0xFF unless written) and the trigger bytes."""
    regs = []
    trigs = []
    cur = [0] * NREGS
    p = 0
    for _ in range(frames):
        cur[13] = 0xFF
        a = data[p]
        p += 1
        mask = a & 0x7F
        t = 0
        if a & 0x80:
            b = data[p]
            p += 1
            mask |= (b & 0x7F) << 7
            if b & 0x80:
                t = data[p]
                p += 1
        for k in range(NREGS):
            if mask & (1 << k):
                cur[k] = data[p]
                p += 1
        regs.append(list(cur))
        trigs.append(t)
    return regs, trigs


# --------------------------------------------------------------------------- digidrum table


@dataclass(frozen=True)
class Drum:
    pcm: bytes  # 4-bit samples, one per byte
    code: int  # MFP prescaler code 1..7
    count: int  # MFP data register 1..255


def parse_drum_table(table: bytes) -> list[Drum]:
    (n,) = struct.unpack(">H", table[:2])
    drums = []
    for i in range(n):
        off, length, code, count = struct.unpack(">IHBB", table[2 + i * 8 : 10 + i * 8])
        drums.append(Drum(bytes(table[off : off + length]), code, count))
    return drums


def pack_drum_table(drums: list[Drum]) -> bytes:
    head = 2 + len(drums) * 8
    body = bytearray()
    entries = bytearray()
    for d in drums:
        entries += struct.pack(">IHBB", head + len(body), len(d.pcm), d.code, d.count)
        body += bytes(v & 15 for v in d.pcm)
    out = struct.pack(">H", len(drums)) + bytes(entries) + bytes(body)
    return out + (b"\0" if len(out) & 1 else b"")


# --------------------------------------------------------------------------- the bank


@dataclass
class Track:
    name: str
    kind: int
    stream: bytes = b""
    frames: int = 0
    loop_frame: int = 0
    loop_offset: int = 0
    loops: bool = False
    sample: bool = False  # a DPCM sample: its digidrum may not be cut by the song's own drums
    note: str = ""


@dataclass
class Bank:
    tracks: list[Track]
    drums: list[Drum] = field(default_factory=list)

    def to_bytes(self) -> bytes:
        head = bytearray(struct.pack(">HH", len(self.tracks), 0))
        base = HEADER_BYTES + ENTRY_BYTES * len(self.tracks)
        body = bytearray()
        for t in self.tracks:
            if t.frames:
                offset = base + len(body)
                body += t.stream
                if len(body) & 1:
                    body += b"\0"
            else:
                offset = 0
            head += struct.pack(
                ">IIHHBBH", offset, t.loop_offset, t.frames, t.loop_frame, t.kind, 1 if t.loops else 0, 1 if t.sample else 0
            )
        return bytes(head) + bytes(body)

    def ids_inc(self) -> str:
        lines = ["| generated by music_pack.py: track ids of music_bank.bin"]
        for i, t in enumerate(self.tracks):
            tail = f"   | {t.note}" if t.note else ""
            lines.append(f"    .equ {t.name}, {i}{tail}")
        lines.append(f"    .equ MUS_TRACKS, {len(self.tracks)}")
        lines.append("    .equ MUS_NONE, 255")
        return "\n".join(lines) + "\n"


def _trim_tail(regs: list[list[int]], trig: list[int], voices: tuple[int, ...], keep: int) -> int:
    """Number of frames to keep: drop trailing frames in which none of `voices` makes a sound."""
    n = len(regs)
    while n > keep and all(regs[n - 1][8 + v] == 0 for v in voices) and not trig[n - 1]:
        n -= 1
    return n


def sample_stream(pcm: bytes) -> "rip.GameTrack":
    """A DPCM sample as a track: the drum starts on frame 0 and the track lasts as long as the drum does.

    Voice C is the drum's. R10 stays non-zero and the mixer has voice C's tone and noise off, so the effect
    owns the voice (music_merge) and the song's bass cannot buzz under the sample.
    """
    import nes_music_rip as rip

    frames = -(-len(pcm) * 50 * 10 // int(rip.DRUM_RATE * 10)) + 1
    regs = [[0] * 14 for _ in range(frames)]
    for r in regs:
        r[7], r[10], r[13] = 0xFF, 1, 0xFF
    trig = [0] * frames
    trig[0] = (3 << 6) | 0  # voice C, the track's only drum
    return rip.GameTrack(regs, trig, [pcm], 0, False)


def build_bank(
    prg: bytes | None,
    clock: str = "pal",
    tri_volume: int = 13,
    log=print,
) -> Bank:
    """`prg` is the ROM's PRG (None: every track stays empty)."""
    tracks = [Track(name, kind) for name, kind, _ in TRACK_LIST]
    drums: list[Drum] = []
    if prg is None:
        return Bank(tracks, drums)

    import nes_music_rip as rip  # imported late: needs py65 only when there is a ROM

    ripped = rip.rip_all(prg)
    samples = rip.rip_samples(prg, clock)
    clk = rip.CPU_CLOCK[clock]
    drum_index: dict[Drum, int] = {d: i for i, d in enumerate(drums)}
    for track, (name, kind, stem) in zip(tracks, TRACK_LIST):
        if stem in samples:
            game = sample_stream(samples[stem])
        elif kind == OVERLAY_C:
            game = rip.to_effect_stream(ripped[stem], clk, clock)
        else:
            game = rip.to_game_stream(ripped[stem], clk, clock, tri_volume)
        regs, trig = game.regs, list(game.trig)
        n = len(regs)
        if stem in samples:
            track.sample = True  # runs as long as the drum does
        elif kind == SONG and not game.looped:
            n = _trim_tail(regs, trig, (0, 1, 2), 2)
        elif kind == OVERLAY_C:
            n = _trim_tail(regs, trig, (2,), 1)  # the effect sounds on voice C's volume register (R10)
        elif kind != SONG:
            n = _trim_tail(regs, trig, (kind - 1,), 1)
        n = max(n, min(KEEP_FRAMES.get(name, 0), len(regs)))
        loop_frame = game.loop_frame if game.looped else 0
        regs, trig = regs[:n], trig[:n]
        if loop_frame >= n:
            loop_frame = 0
        # renumber this track's drums into the shared table
        local_to_global: dict[int, int] = {}
        for i, pcm in enumerate(game.drums):
            d = Drum(pcm, rip.DRUM_PREDIV_CODE, rip.DRUM_COUNT)
            if d not in drum_index:
                if len(drums) >= MAX_DRUMS:
                    raise SystemExit("more digidrums than the 6-bit trigger can address")
                drum_index[d] = len(drums)
                drums.append(d)
            local_to_global[i] = drum_index[d]
        trig = [((t & 0xC0) | local_to_global[t & 63]) if t else 0 for t in trig]
        stream, loop_offset = pack_stream(regs, trig, loop_frame)
        track.stream, track.frames, track.loop_frame = stream, n, loop_frame
        track.loop_offset, track.loops = loop_offset, game.looped
        track.note = f"{stem}, {n} frames, {len(stream)} bytes" + (", loops" if game.looped else "")
        log(f"  {name:20} {n:5} frames {len(stream):6} bytes  {'loop@' + str(loop_frame) if game.looped else 'one-shot'}")
    return Bank(tracks, drums)


def write_outputs(bank: Bank, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "music_bank.bin").write_bytes(bank.to_bytes())
    (out_dir / "music_drum_table.bin").write_bytes(pack_drum_table(bank.drums))
    (out_dir / "music_ids.inc").write_text(bank.ids_inc(), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rom", type=Path, help="Zelda 1 .nes ROM; without it the bank is empty")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--clock", choices=("pal", "ntsc"), default="pal")
    parser.add_argument("--require-rom", action="store_true", help="fail instead of building a silent bank")
    args = parser.parse_args()

    prg = None
    if args.rom and args.rom.exists():
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        try:
            import py65  # noqa: F401
        except ImportError:
            if args.require_rom:
                raise SystemExit("py65 is required to rip the music: pip install py65")
            print("music_pack: py65 is not installed; the bank is empty (pip install py65)")
        else:
            import nes_music_rip as rip

            prg = rip.load_prg(args.rom)
    elif args.require_rom:
        raise SystemExit("music_pack: no ROM")
    else:
        print("music_pack: no ROM; the bank is empty")

    print(f"music_pack: {'ripping the ROM music' if prg else 'silent bank'}")
    bank = build_bank(prg, args.clock)
    write_outputs(bank, args.out_dir)
    total = len(bank.to_bytes()) + len(pack_drum_table(bank.drums))
    print(f"music_pack: {sum(1 for t in bank.tracks if t.frames)}/{len(bank.tracks)} tracks, "
          f"{len(bank.drums)} digidrums, {total} bytes")


if __name__ == "__main__":
    main()
