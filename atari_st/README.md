Atari STFM / Hatari port
========================

A native Atari ST port of The Legend of Zelda, built on top of aldonunez's NES
disassembly in `src/`. It runs as a stock TOS `.PRG` on a 512KB ST in 320x200
sixteen-colour mode, and reads all of its graphics, room layouts, palettes and
text out of a ROM you supply yourself.

Status: an early but playable vertical slice. You can walk the whole
overworld, fetch the wooden sword from the first cave, enter Level 1 and fight
through most of it. It is not yet a complete game: there is no sound, no
inventory screen, only one dungeon, and no way to win.

How to play
-----------

| Key | Action |
| --- | --- |
| arrow keys or `W` `A` `S` `D` | walk (in 8-pixel grid steps, like the original) |
| `Space` | swing the sword (once you have it) |
| `B` | drop a bomb (once you have some) |
| `K` | debug: one key and four bombs |
| `Esc` | quit |

A typical run:

1. The game opens on the first overworld screen, just below a cave. Walk up
   into it, wait for the old man to finish speaking, and take the wooden
   sword. Walk out through the bottom doorway.
2. Walk to the Level 1 entrance (overworld room `$37`) and go down the stairs.
3. In the dungeon, kill the monsters with the sword (and its beam while your
   hearts are full), pick up keys, open locked doors, bomb the bombable walls,
   and step on the staircase in room `$22` to reach the cellar with the bow.
4. Leave the dungeon by walking off the bottom of its first room.

Implemented
-----------

Platform and rendering

- native Motorola 68000 program emitted as a TOS `.PRG`, VBL-paced for STFM
  timing
- 16x16 masked sprites shifted at run time; one shared ST palette covers every
  NES background and sprite palette row
- double-buffered play frames with per-sprite erase from a clean background
  copy, so busy rooms neither flicker nor lose Link; scrolls and caves draw
  straight to the visible screen
- keyboard input through the IKBD ACIA
- status ribbon: hearts (with halves), rupee, key and bomb counters, in the
  original glyphs

Overworld

- all 128 screens decoded from the original data: room layouts, 16x16 squares,
  per-area palette
- Link's movement follows the original: 8-pixel grid steps, the collision
  hotspot and the walkable-tile exception list, the two-column test on
  vertical moves, and the original screen-edge coordinates
- 16-pixel stepped scrolling between screens in all four directions
- cave entry and exit. The first cave is rebuilt from the original cave layout
  with the old man, his two bonfires, his speech typed out character by
  character, and the wooden sword on the floor. Other caves are the same room
  without a person
- the game starts just below the first cave; dying refills the hearts and
  returns Link there
- repeated-template rooms (template `$07`) spawn simple wandering placeholder
  blobs, so the overworld has something to hit

Level 1 (underworld)

- the 17 rooms reachable from the start room, rebuilt from the original room
  layout routines (walls, doors, floor), with the original collision
- doors: open doorways, locked doors (cost a key), bombable walls (open with a
  bomb), false walls (walk through), and shutters that stay shut until the
  room's monsters are dead
- the staircase room (`$22`) and the cellar below it, rebuilt from the
  original cellar layout, with the bow on the floor and four keese
- monsters spawned from the original room data: stalfos, keese, gels, ropes
  and goriya, drawn from the original sprites with their own animation rules
  and hit points; they wander on the grid and bite for their original damage
- the room's items appear on the floor (a trigger-7 room's item appears when
  the monsters are dead) and stay collected

Combat and items

- sword: hurts monsters, and killed monsters roll the original drop table
  (hearts, rupees, bombs)
- sword beam: with full hearts, or half a heart short, a swing also fires a
  beam that flies until it hits a wall or a monster
- bombs: a fuse, then damage to nearby monsters and to bombable walls
- pickups with their effects: keys, hearts, heart containers, rupees, bombs
  and the wooden sword. Maps, compasses, the bow and similar items are
  collected but do nothing yet
- Link is invincible and blinks for a short time after being hurt

Tooling

- asset pipeline from the ROM to ST data (see below) with a placeholder
  fallback so the target still builds without any ROM
- unit tests for the asset pipeline
- headless Hatari harness that captures the framebuffer to a PNG, drives
  scripted key input, and can poke variables

Known gaps
----------

Things that behave differently from the original, or are stand-ins:

- sword and bomb art is placeholder, there is no explosion cloud, no sword
  beam spark, and the bonfires do not flicker
- monsters wander randomly: no rope charge, goriya boomerangs, knock-back or
  stun
- wallmasters, the boss (Aquamentus) and traps are not spawned, so rooms with
  them never count as cleared (their shutters still open once the monsters
  that do spawn are dead). The boss room's heart container therefore never
  appears, and picking up the triforce piece does nothing yet
- push-block and other secret triggers are not implemented; the shutters of
  such rooms open when the monsters die instead
- `K` is a debug key standing in for the shops and secrets that give keys and
  bombs
- the overworld's real monsters are not ported; only the placeholder blobs
- the HUD does not show the sword or any other item

Roadmap
-------

Near term (finish Level 1)

1. the remaining Level 1 monsters and behaviours: wallmasters, traps,
   Aquamentus, rope charging, goriya boomerangs, knock-back
2. push-block and other secret triggers
3. the triforce piece, the ending of the level, and the heart container
4. real sword, beam and bomb art and the bomb explosion
5. map and compass use, and the dungeon map on the ribbon

Then the rest of the overworld

6. the real overworld monsters (octoroks, tektites, moblins, leevers,
   zoras and so on) and their behaviours
7. the other caves: shops, hints, money-making games, doors that charge,
   shortcut stairs, and the secrets under trees, rocks and armos
8. the inventory subscreen, item selection and the B-button item, with the
   boomerang, bow and arrows, candles, recorder, raft, ladder, rings and
   the magic items
9. the animated pond (palette cycling)

Then the game around it

10. the other eight dungeons, reusing the underworld engine
11. YM2149 audio from the song and sound-effect scripts already listed in
    `bins.xml`
12. title screen, game-over and continue, saving and the second quest
13. a disk image / floppy-friendly build and a check on real STFM timing

Prerequisites
-------------

- Python 3
- GNU m68k binutils with `m68k-linux-gnu-as`, `ld`, and `objcopy`
- Hatari (or another TOS-compatible emulator) for execution

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

Put a `(U) (PRG0)` or `(PRG1)` ROM image at `ext/Original.nes`. The build reads
it through `src/bins.xml`, whose offsets are relative to the start of PRG ROM
because Zelda uses CHR-RAM and stores its graphics inside PRG. `ext/` and
`*.nes` are both gitignored, so the ROM never enters version control.

Without it the build still succeeds, but prints a warning and emits
procedurally generated placeholder art. Pass `--require-source` to
`tools/build_assets.py` to make a missing ROM a hard error instead.

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
- **underworld**: rebuilds Level 1's rooms from the original layout routines
  (`tools/underworld.py`), including doors, the cellar below the stairs room
  and the level's palette, as 32x22 tile maps over a shared tile bank
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

`make check` runs the asset unit tests, verifies the generated files against the
manifest, and validates the PRG header.

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
An event of the form `700:=ENEMY_X.0=120` pokes a byte of a variable instead,
and `ZELDA_START_UW=0x72` starts inside Level 1 in that room.

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
  36KB of tables would otherwise push the variable block out of reach.
- With the underworld the tables total well over 32KB, so code reaches them
  through `a6`, a register that holds `table_anchor` (a label in the middle of
  the tables) for the whole run; the `ltab` macro in `main.s` writes the
  offset. Nothing else may use `a6`.
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

Licensing notes
---------------

- No proprietary ROM image or extracted Zelda asset is committed here.
- If you provide `ext/Original.nes`, you are responsible for ensuring you may
  lawfully possess and use that source data.
- The converter and 68000 source are open build inputs; generated artifacts
  stay out of version control.
