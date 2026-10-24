from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import nes_music_rip as rip  # noqa: E402

RESET = (0x4017, 0xFF)  # the game writes this at the start of every frame


def play(apu: rip.Apu, first: list[tuple[int, int]], frames: int) -> list[rip.Frame]:
    out = []
    for f in range(frames):
        out.append(apu.step([RESET] + (first if f == 0 else [])))
    return out


class ApuModelTests(unittest.TestCase):
    def test_pulse_note_ends_with_its_length_counter(self) -> None:
        # length index 1 = 254 half-frame clocks, two per frame (one is the reset clock): 127 frames
        frames = play(rip.Apu(), [(0x4000, 0x9F), (0x4002, 0x10), (0x4003, 0x08)], 140)
        audible = [i for i, fr in enumerate(frames) if fr.pulse[0][0] > 0]
        self.assertEqual(audible, list(range(127)))
        self.assertEqual(frames[0].pulse[0], (15, 0x10, 2))

    def test_short_pulse_note_is_cut_after_one_frame(self) -> None:
        # length index 3 = 2 clocks (the "end of tune" write): audible this frame, gone next frame
        frames = play(rip.Apu(), [(0x4000, 0x9F), (0x4002, 0x10), (0x4003, 0x18)], 4)
        self.assertEqual([fr.pulse[0][0] > 0 for fr in frames], [True, False, False, False])

    def test_pulse_below_period_8_is_muted(self) -> None:
        frames = play(rip.Apu(), [(0x4000, 0x9F), (0x4002, 0x07), (0x4003, 0x08)], 2)
        self.assertEqual(frames[0].pulse[0][0], 0)

    def test_envelope_decays_when_not_constant_volume(self) -> None:
        frames = play(rip.Apu(), [(0x4000, 0x86), (0x4002, 0x20), (0x4003, 0x08)], 60)
        levels = [fr.pulse[0][0] for fr in frames]
        self.assertGreaterEqual(levels[0], 14)
        self.assertEqual(levels, sorted(levels, reverse=True))
        self.assertEqual(levels[-1], 0)

    def test_triangle_linear_counter_makes_short_notes(self) -> None:
        # control bit clear + reload 31: 31 quarter clocks, four per frame
        frames = play(rip.Apu(), [(0x4008, 0x1F), (0x400A, 0x40), (0x400B, 0x08)], 12)
        self.assertEqual([i for i, fr in enumerate(frames) if fr.tri], list(range(8)))

    def test_triangle_with_control_bit_sustains(self) -> None:
        frames = play(rip.Apu(), [(0x4008, 0xFF), (0x400A, 0x40), (0x400B, 0x08)], 60)
        self.assertTrue(all(fr.tri == 0x40 for fr in frames))

    def test_noise_hit_lengths(self) -> None:
        # $4000-style write for noise: const volume 12; length index 3 (2) vs 11 (10)
        short = play(rip.Apu(), [(0x400C, 0x1C), (0x400E, 0x03), (0x400F, 0x18)], 4)
        long_ = play(rip.Apu(), [(0x400C, 0x1C), (0x400E, 0x03), (0x400F, 0x58)], 8)
        self.assertEqual([fr.noise[0] for fr in short], [12, 0, 0, 0])
        self.assertEqual([fr.noise[0] > 0 for fr in long_], [True] * 5 + [False] * 3)
        self.assertTrue(short[0].noise_hit and not short[1].noise_hit)

    def test_disabled_channel_stays_silent(self) -> None:
        apu = rip.Apu()
        frames = [apu.step([RESET, (0x4015, 0x00), (0x4000, 0x9F), (0x4002, 0x10), (0x4003, 0x08)])]
        self.assertEqual(frames[0].pulse[0][0], 0)


class ConversionTests(unittest.TestCase):
    def test_volume_is_monotonic_and_bounded(self) -> None:
        values = [rip.ym_volume(v) for v in range(16)]
        self.assertEqual(values[0], 0)
        self.assertEqual(values, sorted(values))
        self.assertTrue(all(1 <= v <= 15 for v in values[1:]))

    def test_tone_period_matches_the_pitch(self) -> None:
        # NES timer for A4 (440 Hz) on the PAL clock, pulse: clock / (16 * (t + 1))
        timer = round(rip.CPU_CLOCK["pal"] / (16 * 440)) - 1
        period = rip.tone_period(timer, rip.CPU_CLOCK["pal"])
        self.assertAlmostEqual(rip.YM_CLOCK / (16 * period), 440, delta=440 * 0.01)
        # the triangle plays an octave lower for the same timer value
        self.assertAlmostEqual(
            rip.tone_period(timer, rip.CPU_CLOCK["pal"], 1), 2 * period, delta=2
        )

    def test_period_is_folded_into_12_bits(self) -> None:
        self.assertLessEqual(rip.tone_period(0x7FF, rip.CPU_CLOCK["pal"], 1), 4095)

    def test_noise_pieces_cover_the_hit(self) -> None:
        pieces = rip.noise_lfsr_samples(3, 0, rip.CPU_CLOCK["pal"], "pal", 12, 5)
        self.assertEqual(len(pieces), 5)
        total = sum(len(p) for p in pieces)
        self.assertAlmostEqual(total, 5 * rip.DRUM_RATE / rip.YM_RATE, delta=1)
        level = rip.ym_volume(12, rip.NOISE_BASE)
        whole = b"".join(pieces)
        self.assertEqual(set(whole), {0, level})
        ones = sum(1 for b in whole if b)
        self.assertTrue(0.3 < ones / len(whole) < 0.7)  # noise, not a stuck level

    def _hit(self, length: int) -> rip.Rip:
        frames = [rip.Frame() for _ in range(length + 6)]
        for i, fr in enumerate(frames):
            fr.pulse[0] = (10, 0x40, 2)
        for f in range(2, 2 + length):
            frames[f].noise = (12, 3, 0)
        frames[2].noise_hit = True
        return rip.Rip(frames, 0, False)

    def test_find_drums(self) -> None:
        drums = rip.find_drums(self._hit(5).frames)
        self.assertEqual([(d.start, d.frames) for d in drums], [(2, 5)])

    def test_noise_mode_puts_the_drum_on_voice_c(self) -> None:
        regs, samples = rip.to_ym_registers(self._hit(5), rip.CPU_CLOCK["pal"], "pal", "noise", 13)
        self.assertEqual(samples, [])
        for f in range(2, 7):
            self.assertEqual(regs[f][7] & 0x20, 0)  # noise enabled on C
            self.assertGreater(regs[f][6], 0)
            self.assertGreater(regs[f][10], 0)
        self.assertEqual(regs[1][7] & 0x20, 0x20)
        self.assertEqual(regs[7][7] & 0x20, 0x20)

    def test_digidrum_mode_triggers_every_frame_with_its_own_piece(self) -> None:
        regs, samples = rip.to_ym_registers(self._hit(5), rip.CPU_CLOCK["pal"], "pal", "digidrum", 13)
        self.assertEqual(len(samples), 5)
        voice_bits = {(regs[f][1] >> 4) & 3 for f in range(2, 7)}
        self.assertEqual(len(voice_bits), 1)
        voice = voice_bits.pop() - 1
        self.assertIn(voice, (0, 1, 2))
        for k, f in enumerate(range(2, 7)):
            r = regs[f]
            self.assertEqual(r[1] & 0xC0, 0x40)  # effect type: digidrum
            self.assertEqual(r[6] >> 5, rip.DRUM_PREDIV_CODE)
            self.assertEqual(r[14], rip.DRUM_COUNT)
            self.assertEqual(r[8 + voice], k)
            self.assertTrue(r[7] & (1 << voice))  # no tone under the drum
            self.assertEqual(r[7] & 0x38, 0x38)  # YM noise generator stays off
        self.assertEqual(regs[1][1] & 0xF0, 0)
        self.assertEqual(regs[7][1] & 0xF0, 0)

    def test_the_drum_takes_the_quietest_voice(self) -> None:
        hit = self._hit(2)
        for fr in hit.frames:
            fr.pulse[0] = (15, 0x40, 2)
            fr.pulse[1] = (15, 0x50, 2)
        for fr in hit.frames[2:4]:
            fr.tri = 0x100  # voice C plays, at the (low) volume given below
        regs, _ = rip.to_ym_registers(hit, rip.CPU_CLOCK["pal"], "pal", "digidrum", 5)
        self.assertEqual((regs[2][1] >> 4) & 3, 3)  # voice C (tri volume 5) is the quietest

    def test_game_stream_triggers_each_drum_once_with_the_whole_sample(self) -> None:
        hit = self._hit(5)
        track = rip.to_game_stream(hit, rip.CPU_CLOCK["pal"], "pal", 13)
        self.assertEqual(len(track.regs), len(hit.frames))
        self.assertTrue(all(len(row) == 14 and row[13] == 0xFF for row in track.regs))
        self.assertEqual([f for f, x in enumerate(track.trig) if x], [2])
        self.assertEqual(len(track.drums), 1)
        self.assertAlmostEqual(len(track.drums[0]), 5 * rip.DRUM_RATE / rip.YM_RATE, delta=1)
        voice = (track.trig[2] >> 6) - 1
        self.assertIn(voice, (0, 1, 2))
        self.assertEqual(track.trig[2] & 63, 0)
        for f in range(2, 7):
            self.assertTrue(track.regs[f][7] & (1 << voice), "no tone under the drum")
        self.assertEqual(track.regs[1][7] & 0x38, 0x38)  # the YM noise generator stays off

    def test_effect_stream_is_noise_on_voice_c_only(self) -> None:
        frames = [rip.Frame(noise=(0, 5, 0)), rip.Frame(noise=(15, 5, 0)), rip.Frame(noise=(4, 12, 0))]
        g = rip.to_effect_stream(rip.Rip(frames, 0, False), rip.CPU_CLOCK["pal"], "pal")
        self.assertEqual([r[7] for r in g.regs], [0xFF, 0xDF, 0xDF])
        self.assertEqual(g.regs[0][10], 0)
        self.assertEqual(g.regs[1][10], rip.ym_volume(15, rip.NOISE_BASE))
        self.assertLess(g.regs[2][10], g.regs[1][10])
        self.assertEqual(g.regs[1][6], rip.noise_register(5, rip.CPU_CLOCK["pal"], "pal"))
        self.assertEqual((g.trig, g.drums, g.looped), ([0, 0, 0], [], False))
        self.assertTrue(all(len(r) == 14 and r[13] == 0xFF for r in g.regs))

    def test_equal_hits_share_one_drum(self) -> None:
        hit = self._hit(1)
        again = self._hit(1)
        merged = rip.Rip(hit.frames + again.frames, 0, False)
        track = rip.to_game_stream(merged, rip.CPU_CLOCK["pal"], "pal", 13)
        self.assertEqual(len(track.drums), 1)
        self.assertEqual(sum(1 for x in track.trig if x), 2)


class YmFileTests(unittest.TestCase):
    def test_round_trip_and_layout(self) -> None:
        regs = [[(f * 16 + r) & 0xFF for r in range(16)] for f in range(7)]
        samples = [bytes([0, 5, 9, 15]), bytes([1, 2])]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "t.ym"
            rip.write_ym(path, regs, 3, samples, "Title", "Author", "Comment")
            data = path.read_bytes()
            self.assertEqual(data[:12], b"YM6!LeOnArD!")
            self.assertEqual(data[-4:], b"End!")
            expected = 34 + (4 + 4) + (4 + 2) + len("Title\0Author\0Comment\0") + 16 * 7 + 4
            self.assertEqual(len(data), expected)
            back = rip.read_ym(path)
        self.assertEqual(back["frames"], 7)
        self.assertEqual(back["loop"], 3)
        self.assertEqual((back["clock"], back["rate"]), (2_000_000, 50))
        self.assertEqual(back["samples"], samples)
        self.assertEqual(back["strings"], ["Title", "Author", "Comment"])
        self.assertEqual(back["regs"], regs)


class DpcmTests(unittest.TestCase):
    def test_the_dmc_counter_moves_by_two_per_bit_lsb_first(self) -> None:
        self.assertEqual(rip.dmc_decode(bytes([0b00000101]), 64), [66, 64, 66, 64, 62, 60, 58, 56])

    def test_the_dmc_counter_stops_at_its_ends(self) -> None:
        self.assertEqual(max(rip.dmc_decode(b"\xff" * 40, 64)), 126)       # +2 only up to 125: even values stop at 126
        self.assertGreaterEqual(min(rip.dmc_decode(b"\x00" * 40, 64)), 0)

    def test_a_sample_becomes_a_digidrum_of_the_right_length(self) -> None:
        levels = [64 + (10 if (i // 8) % 2 else -10) for i in range(33_000)]       # a 2 kHz square wave, one second
        pcm = rip.dmc_to_drum(levels, 33_000.0)
        self.assertEqual(len(pcm), int(33_000 * rip.DRUM_RATE / 33_000.0))
        self.assertTrue(all(v < 16 for v in pcm))
        self.assertGreater(max(pcm), min(pcm) + 3)
        low, high = rip.YM_LEVELS[min(pcm)], rip.YM_LEVELS[max(pcm)]
        self.assertLess(low, 0.15 * rip.YM_LEVELS[-1] * 1.0 + 1)
        self.assertGreater(high, 0.4 * rip.YM_LEVELS[-1])

    def test_the_sample_tables_are_the_roms(self) -> None:
        asm = (ROOT.parent / "src" / "Z_00.asm").read_text()

        def table(label: str) -> list[int]:
            body = asm.split(f"\n{label}:\n", 1)[1].split("\n\n", 1)[0]
            return [int(x.strip().lstrip("$"), 16) for line in body.splitlines() for x in line.split(".BYTE")[1].split(",")]

        self.assertEqual([x[2] for x in rip.SAMPLES], table("SampleAddrs"))
        self.assertEqual([x[3] for x in rip.SAMPLES], table("SampleLengths"))
        self.assertEqual([x[4] for x in rip.SAMPLES], table("SampleRates"))
        self.assertEqual([x[1] for x in rip.SAMPLES], [1 << i for i in range(7)])


ROM = Path(os.environ.get("ZELDA_ROM", ROOT.parent / "ext" / "Original.nes"))


@unittest.skipUnless(ROM.exists(), "no ROM (set ZELDA_ROM or put it in ext/Original.nes)")
class RomTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        try:
            import py65  # noqa: F401
        except ImportError:
            raise unittest.SkipTest("py65 not installed")
        cls.prg = rip.load_prg(ROM)

    def rip(self, stem: str, max_frames: int = 30000) -> rip.Rip:
        _, kind, value, _ = next(t for t in rip.TRACKS if t[0] == stem)
        return rip.rip_track(rip.SoundCpu(self.prg), kind, value, max_frames)

    def test_overworld_loops_and_has_percussion(self) -> None:
        r = self.rip("song_overworld")
        self.assertTrue(r.looped)
        self.assertTrue(0 < r.loop_frame < len(r.frames))
        self.assertGreater(len(rip.find_drums(r.frames)), 20)
        # the first chord is B-flat major over a B-flat bass: voice A D4, voice B Bb4, triangle Bb2 (PAL pitch)
        regs, _ = rip.to_ym_registers(r, rip.CPU_CLOCK["pal"], "pal", "noise", 13)
        freq = [rip.YM_CLOCK / (16 * (regs[1][2 * v] | (regs[1][2 * v + 1] << 8))) for v in range(3)]
        for got, want in zip(freq, (293.66, 466.16, 116.54)):
            self.assertAlmostEqual(got / want, 1.0, delta=0.02)

    def test_jingle_ends_and_game_over_repeats(self) -> None:
        self.assertFalse(self.rip("jingle_secret").looped)
        self.assertTrue(self.rip("jingle_game_over").looped)

    def test_effect_sounds_are_short_noise_only_one_shots(self) -> None:
        # the Effect channel (request $603): noise only, a sword swing is ~10 frames, a bomb blast ~24
        for stem, lo, hi in (("sfx_sword", 8, 30), ("sfx_arrow", 4, 30), ("sfx_flame", 20, 60),
                             ("sfx_stairs", 40, 80), ("sfx_bomb_blast", 20, 50)):
            r = self.rip(stem)
            self.assertFalse(r.looped, stem)
            self.assertTrue(lo <= len(r.frames) <= hi, f"{stem} {len(r.frames)} frames")
            self.assertTrue(all(f.pulse[0][0] == f.pulse[1][0] == 0 and f.tri == 0 for f in r.frames), stem)
            self.assertTrue(any(f.noise[0] for f in r.frames), stem)
            g = rip.to_effect_stream(r, rip.CPU_CLOCK["pal"], "pal")
            self.assertEqual(len(g.regs), len(r.frames))
            self.assertEqual(g.drums, [])
            for row, frame in zip(g.regs, r.frames):
                self.assertEqual(row[7], 0xDF if frame.noise[0] else 0xFF, stem)
                self.assertEqual(row[10] > 0, frame.noise[0] > 0, stem)
                self.assertTrue(row[6] == 0 or 1 <= row[6] <= 31, stem)

    def test_the_seven_dpcm_samples_are_sounds_not_silence(self) -> None:
        samples = rip.rip_samples(self.prg)
        self.assertEqual(list(samples), [x[0] for x in rip.SAMPLES])
        for stem, pcm in samples.items():
            seconds = len(pcm) / rip.DRUM_RATE
            self.assertTrue(0.03 < seconds < 1.2, (stem, seconds))
            self.assertGreater(len(set(pcm)), 4, f"{stem} uses a range of volume steps")
            self.assertTrue(all(v < 16 for v in pcm))
        # the hurt cry is a few frames, the Digdogger wail the longest
        self.assertLess(len(samples["smp_link_hurt"]), 600)
        self.assertEqual(max(samples, key=lambda k: len(samples[k])), "smp_roar_wail")

    def test_every_track_converts_in_both_drum_modes(self) -> None:
        for stem, kind, value, _ in rip.TRACKS:
            r = rip.rip_track(rip.SoundCpu(self.prg), kind, value, 30000)
            for mode in ("noise", "digidrum"):
                regs, samples = rip.to_ym_registers(r, rip.CPU_CLOCK["pal"], "pal", mode, 13)
                self.assertEqual(len(regs), len(r.frames), stem)
                self.assertLessEqual(len(samples), 32, stem)
                self.assertTrue(all(0 <= x <= 255 for row in regs for x in row), stem)


if __name__ == "__main__":
    unittest.main()
