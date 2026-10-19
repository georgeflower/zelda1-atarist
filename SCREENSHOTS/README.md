# Screenshots

Frames captured from the Atari ST port running in Hatari (headless harness, `atari_st/tools/screenshot.py`), 320x200 as the ST shows them.
They were saved at the owner's request. The pictures show the port rendering the original game's artwork (read from a ROM the owner
supplies), so they are Nintendo's artwork: treat them as illustration, not as part of the licensed source. The golden-frame tests still store
hashes only (`atari_st/tests/golden/frames.json`).

| folder | what |
|---|---|
| `level-sweeps-1/` | the first full-room sweeps of the dungeons built so far, one frame per room |
| `level-sweeps-3-8/` | sweep of every room of Levels 3 to 8 (`L<level>_<room>.png`) |
| `rooms/` | single rooms looked at in detail while building (`L<level>_<room>.png`: crowded, dark, stash, Grumble, bosses) |
| `golden-scenes/`, `golden-build/` | the golden-frame scenes (overworld start, Level 1-8 scenes) |
| `working-shots/`, `build-shots/` | the shots taken while developing each feature (items, bow, map, minimap, clock, the push block, ...) |

Duplicates (identical pixels) were dropped when this folder was made.
