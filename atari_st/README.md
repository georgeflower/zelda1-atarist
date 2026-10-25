Atari STFM / Hatari port
========================

A port of The Legend of Zelda to the Atari ST, written in 68000 assembly on top of aldonunez's NES
disassembly in `src/`. It runs as a normal TOS `.PRG` on an ST with 1 MB in 320x200, 16 colours.
All graphics, rooms, palettes, music and text are read from a ROM you supply yourself, nothing is
drawn or made up separately.

It's made together with an AI (Claude, from Anthropic). I decide what to build and fix, Claude
writes most of the code and the tools.

Status
------

Work in progress, expect bugs. Both quests are in: the whole overworld, all nine dungeons up to
Ganon and Zelda, every item, title and story, file select, death and continue, saving, the credits
and the music. The list of what is left is in [`PLAN.md`](PLAN.md).

Everything is one `.PRG` of about 700 KB (both quests), so it needs 1 MB of RAM. It fits on a
720 KB disk together with `ZELDA.SAV`.

How to play
-----------

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D` or the joystick | walk (in 8-pixel steps, like the original) |
| `Space`, joystick fire | the sword (A) |
| `Ctrl` or `Alternate` | the B item: bombs, boomerang, candle, bow, recorder, food, potion or rod |
| `Tab` | the inventory screen (Left/Right choose the B item, `Tab` goes back) |
| `K` | debug: a key, four bombs and the candle |
| `Esc` | quit |

The game starts on the title screen. Press Return, pick a player and make a name. Call it ZELDA
to play the Second Quest, like in the original. The game saves to `ZELDA.SAV` in the current
directory.

What is in it
-------------

- the overworld, all 128 screens, with its monsters, caves, shops, hidden spots, mazes, raft,
  ladder, recorder and fairy ponds
- all nine dungeons of the First Quest and all nine of the Second Quest, with their monsters and
  bosses, doors, keys, push blocks, cellars, dark rooms, map and compass
- every item of the original and the Tab inventory screen laid out like the original
- title, story, file select, name entry, death, continue and save, Zelda's thanks and the credits
- music and sound effects, ripped from the ROM's own sound engine when you build (YM2149), at 50
  and 60 Hz
- double buffering, 16x16 sprites shifted at run time, IKBD keyboard and joystick input

Known differences from the original
-----------------------------------

- the Moldorm is two worms of four segments instead of one of ten (the engine has eight monster
  slots), and the Dodongo and the Moldorm leave no death cloud
- the dungeons' monsters appear at once instead of coming out of a spawn cloud
- `K` is a debug key, it is not in the original
- the song is written for 50 Hz; on a 60 Hz display every sixth frame holds it back so the tempo
  stays right
- it does not fit in 512 KB (the `.PRG` alone is about 700 KB)

Roadmap
-------

What is left is in [`PLAN.md`](PLAN.md), short: more play-testing, a per-level loader for 512 KB
machines and running it on a real ST.

Tools
-----

- the asset pipeline from the ROM to ST data (below); a build without the ROM stops with a message
- `tools/dump_tables.py` writes the ROM tables the port is built from (screens, rooms, monster
  lists) as JSON and Markdown under `build/dump`
- `tools/check_reach.py` runs after every link and fails the build when a table name is missing or
  a branch doesn't fit 16 bits (GNU as wraps those silently, see the notes at the end)
- `tools/golden.py` runs fixed scenes in Hatari and compares a hash of each screen with
  `tests/golden/frames.json`
- unit tests for the pipeline and the music player
- a headless Hatari harness (`tools/screenshot.py`) that takes screenshots, presses keys and pokes
  variables; `--hd-file ZELDA.SAV=file` puts a file on the emulated drive first

Prerequisites
-------------

- Python 3
- GNU m68k binutils with `m68k-linux-gnu-as`, `ld`, and `objcopy`
- Hatari (or another TOS-compatible emulator) for execution; EmuTOS 1.4 (512k) and
  TOS 1.04 both boot the game
- optional: `pip install py65` and your ROM for the full sound bank,
  `pip install machine68k` for the music player tests

Example Debian/Ubuntu packages:

```sh
sudo apt-get install python3 binutils-m68k-linux-gnu hatari
```

Build commands
--------------

From the repository root:

```sh
make -C atari_st all
make -C atari_st check
```

Outputs:

- `atari_st/build/zelda_st.elf`
- `atari_st/build/zelda_st.bin`
- `atari_st/build/ZELDAST.PRG`

Supplying the game data
-----------------------

Put a 131,088-byte iNES ROM image at `ext/Original.nes` (the port is built with *The Legend of
Zelda (Europe) (Rev 1)*, SHA-1 `4a29a5157f1948b2b8c25978ce6d9ff7a3c14708`; the disassembly in `src/` describes the
(U) PRG0/PRG1 images). The build reads
it through `src/bins.xml`, whose offsets are relative to the start of PRG ROM
because Zelda uses CHR-RAM and stores its graphics inside PRG. `ext/` and
`*.nes` are both gitignored, so the ROM never enters version control.

Without it `tools/build_assets.py` (and so `make`) stops with an error: there is no stand-in art.

The asset pipeline
------------------

`atari_st/tools/build_assets.py` is the boundary between NES data and ST data:

- **pattern tables**: rebuilds the background and sprite pattern tables at the
  tile indices the game loads them to, per `CommonPatternVramAddrs` (`Z_02.asm`)
  and `PatternBlockPpuAddrs` (`Z_03.asm`)
- **rooms**: decodes `RoomLayoutsOW.dat`, the `ColumnHeapOW` tables and
  `LevelBlockOW.dat` into 128 screens of 16x11 squares
- **palette**: every colour in all eight NES palette rows -- four background
  and four sprite -- collapses to exactly sixteen distinct ST values with no
  collisions, so one hardware palette covers tiles and sprites at full fidelity
- **collision**: emits the four raw NES tile indices behind each square, which
  is what lets the engine apply `GetCollidableTile`'s rules at 8-pixel
  resolution without storing a tile grid per room
- **underworld**: rebuilds each level's rooms (`UW_LEVELS`, all nine levels of both quests) from
  the original layout routines (`tools/underworld.py`), including doors, the
  cellars and the level's palette, as 32x22 tile maps over a shared tile bank,
  and writes `levels.inc` with one table set per level and `level_table`
- **actors**: monster and item sprites, hit points, drop tables and per-room
  monster and item lists (`tools/actors.py`), plus the cave's rooms, sprites
  and the old man's text
- **output**: planar metatiles, sprite frames with opacity masks, HUD and
  text glyphs, and an assembler include of the constants lifted from the
  disassembly

Screen layout
-------------

```
y   0.. 23   HUD ribbon, three 8-pixel tile rows, full 320 wide
y  24..199   playfield, 256x176, x = 32..287
```

The NES play area is 256x176, which fits the ST's 200 lines exactly once 24 are
given to the status ribbon. Link keeps NES coordinates internally (X 0..255,
Y `$40`..`$EF`) so the constants taken from the disassembly -- room bounds,
hotspot offsets, the unwalkable tile threshold -- are used unchanged.

Testing
-------

`make check` runs the unit tests (assets, actors, the table dump, music packer, the
68000 music player on `machine68k`), verifies the generated files against the
manifest, validates the PRG header, and runs the golden frames. The player tests
skip without the m68k binutils or `machine68k`, the real-bank ones also without the
ROM or `py65`; the golden frames skip without Hatari, an EmuTOS image in `TOS` and
the ROM.

For visual and behavioural checks there is a headless Hatari harness:

```sh
export TOS=/path/to/tos.img
python3 atari_st/tools/screenshot.py --vbls 900 --out build/screen.png
python3 atari_st/tools/screenshot.py --vbls 2600 --trace os_base,cpu_exception \
    --keys "620:+left,1100:-left,1100:+up,1600:-up,1600:+right"
```

It breaks on a VBL count, dumps RAM and the video registers, decodes the
four-bitplane framebuffer to a PNG, reports Link's state, and warns about bus
errors or an early `Pterm0`. Key events are injected by poking the key-state
table, which the harness locates through a marker next to the variable block.
An event of the form `700:=ENEMY_X.0=120` pokes a byte of a variable instead.
`--room 0x3c` starts on that overworld screen and `--uw 0x0e --level 2` inside
that room of that dungeon: the harness builds a matching dev PRG into `build/dev`
(the `ZELDA_START_ROOM`, `ZELDA_START_UW` and `ZELDA_START_LEVEL` switches of the
Makefile bake the start into a build; finish with a plain `make all`).

The golden frames are a set of fixed scenes (`tools/golden.py`): each prints a hash of
the pixels and palette, and `tests/golden/frames.json` holds the expected ones.
The hashes are stored instead of pictures because the pictures would be frames of
Nintendo's artwork; `build/golden/*.png` shows a run. `make golden-update` accepts
a change after you have looked at it.

To check the sound, add `--trace psg_write`: Hatari then logs every write to the
YM2149 in `build/shots/hatari.log` (`ym write data reg=0x.. val=0x..`), including
the digidrum engine's volume writes. The player's writes come from one fixed code
address, so they can be compared frame by frame with the packed streams.

`tools/compare_render.py` closes the loop on the renderer by diffing a captured
framebuffer against a reference render of the same room built in Python; they
should agree byte for byte outside Link's sprite.

Notes on the ST implementation
------------------------------

- A `.PRG` is handed the whole TPA by `Pexec`, so `Malloc` returns 0 until the
  program calls `Mshrink`. That also means moving onto a private stack first,
  since the GEMDOS stack sits in the memory about to be released.
- Everything lands in one flat section, so `link.ld` emits `.data` before
  `.rodata`: the 68000's PC-relative displacement is a signed 16 bits, and the
  tables would otherwise push the variable block out of reach.
- Tables are reached through `a6`, which holds `table_anchor` for the whole run;
  the `ltab` macro writes a 32-bit distance from it, so a table may sit anywhere.
  A dungeon's own tables (rooms, doors, tiles, room records, cellars) are found
  through pointers that `uw_select_level` copies from `level_table` into the
  variable block (the `lvtab` macro), which is what makes a level data.
- Code is the limit. A `bsr`, `bra` or `Bcc` and a `(label,%pc)` operand span a
  signed 16 bits, and GNU as does not complain when they do not fit: it wraps, and
  the program jumps into the wrong place. Level 2 hit it (three main-loop calls
  32 KB from their targets, a crash at start), so `tools/check_reach.py` now
  computes every distance from the assembler listing and fails the build on a bad
  one. The code cluster is nearly full. A module that has to call across the image goes through a `*_far` stub
  (`bra target`) in the middle of the image (`main.s`, before `.include "link.s"`).
  Tables, texts and sprite banks cost nothing, they go after `room_palette`.
- Scroll steps are 16 pixels, exactly one bitplane word, so every copy stays
  byte-aligned and needs no bit shifting.
- Playing frames draw into a hidden screen buffer that is shown on the next
  frame. Each sprite remembers where it was drawn, and the hidden buffer is
  cleaned using what was drawn two frames ago. Scrolls and caves bypass this
  and draw to the visible screen, so the engine switches between the two at
  room transitions. Single-buffered, a busy room made Link vanish because his
  redraw finished after the raster beam had passed him.
- Sprites are shifted at run time rather than pre-shifted at build time.
  Sixteen pre-rotated copies would cost 40KB for Link alone; the shift costs a
  few thousand cycles against a 160,000-cycle frame.
- The IKBD interrupt vector (`$118`) is replaced by a handler that queues every
  byte in a ring buffer; the main loop parses the queue once a frame. The ACIA
  holds a single byte, so polling it lost key releases and left Link walking.
  The previous vector is restored on exit.

Licensing notes
---------------

- No proprietary ROM image or extracted Zelda asset is committed here.
- If you provide `ext/Original.nes`, you are responsible for ensuring you may
  lawfully possess and use that source data.
- The converter and 68000 source are open build inputs; generated artifacts
  stay out of version control.
