Atari STFM / Hatari port
========================

A native Atari ST port of The Legend of Zelda, built on top of aldonunez's NES
disassembly in `src/`. It runs as a stock TOS `.PRG` on a 512KB ST in 320x200
sixteen-colour mode, and reads all of its graphics, room layouts, palettes and
text out of a ROM you supply yourself.

Status: an early but playable vertical slice. You can walk the whole
overworld, fetch the wooden sword from the first cave, and fight through
Level 1 to Aquamentus and the triforce piece. It is not yet a complete game:
there is only one dungeon, and no way to win.

How to play
-----------

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D` or the joystick | walk (in 8-pixel grid steps, like the original) |
| `Space`, joystick fire | the sword, the NES A button (once you have it) |
| `Ctrl` or `Alternate` | the B item: bombs, the boomerang or the candle |
| `Tab` | the inventory screen: Left and Right choose the B item, `Tab` goes back |
| `K` | debug: one key, four bombs and the candle |
| `Esc` | quit |

The two item boxes on the ribbon show what each button holds: the sword under
A once you have picked it up, and the chosen B item under B. The boomerang is
in Level 1 (room `$44`, in the goriyas' room); the candle only comes from `K`
for now.

A typical run:

1. The game opens on the first overworld screen, just below a cave. Walk up
   into it, wait for the old man to finish speaking, and take the wooden
   sword. Walk out through the bottom doorway.
2. Walk to the Level 1 entrance (overworld room `$37`) and go down the stairs.
3. In the dungeon, kill the monsters with the sword (and its beam while your
   hearts are full), pick up keys, open locked doors, bomb the bombable walls,
   and step on the staircase in room `$22` to reach the cellar with the bow.
4. Leave the dungeon by walking off the bottom of its first room, or fight
   on: Aquamentus is in room `$35` and the triforce piece in room `$36`.

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
- the overworld plays a YM2149 song (digidrums included) from a VBL hook
- status ribbon: hearts (with halves), rupee, key and bomb counters, in the
  original glyphs, and the B and A item boxes
- the IKBD joystick (either port) can walk Link and fire the sword

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
  room's monsters are dead. A door that has been opened stays open from both
  sides
- the staircase room (`$22`) and the cellar below it, rebuilt from the
  original cellar layout, with the bow on the floor and four keese
- monsters spawned from the original room data: stalfos, keese, gels, ropes,
  goriya, wallmasters and Aquamentus, drawn from the original art with their
  own animation rules and hit points, and biting for their original damage
- goriyas that line up with Link turn to face him and throw boomerangs that
  fly out, hurt him, and come back; ropes charge once they are level with him;
  wallmasters come out of the walls when Link stands against them and carry
  him back to the level's first room; Aquamentus paces his end of room `$35`
  and breathes three fanned fireballs. Killing him reveals the heart container
- walking monsters keep to the 16-pixel lanes of the room: they only turn on a
  square boundary and look at the whole square ahead, so they never overlap
  blocks. Keese fly over everything instead, in eight directions: they speed
  up, then chase Link or wander for a few turns, slow to a stop, rest, and
  start again
- the triforce piece ends the level: full hearts, a flashing screen, and Link is
  back at the entrance on the overworld
- the room's items appear on the floor (a trigger-7 room's item appears when
  the monsters are dead) and stay collected

Combat and items

- sword: drawn from the original tiles in its four phases, and it only cuts
  while fully out; killed monsters roll the original drop table (hearts,
  rupees, bombs, the clock and fairy are not drawn yet) with its kill counter:
  ten kills without being hurt guarantee a drop, a bomb if the tenth was a
  bomb kill, five rupees otherwise. Drops flicker, wait about half a second
  before they can be taken, and vanish after about eight
- sword beam: with full hearts, or half a heart short, the third phase of a
  swing fires a beam that flashes through the four sprite palettes until it
  hits a wall or a monster, and then spreads out as the original's spark
- bombs: 48 frames of fuse, then a 36-frame cloud (four sprites, three puffs
  that swap sides every frame): for the first 24 the screen flashes grey twice
  and every monster near it takes four hits' worth of damage, at the start of
  the last 12 a bombable wall opens. A bomb stays in the room it was dropped in
- blade traps (room `$22`): four of them wait in the corners until Link is
  level with them, fly at him as far as the middle of the room, and creep home;
  they hurt for a whole heart and nothing hurts them
- the cave bonfires flicker, turning round every six frames
- boomerang: thrown the way Link faces from 16 pixels ahead, it flies three
  pixels a frame for about 49 pixels (or until a wall), sparks, hangs about
  for 16 frames and comes back; one at a time. A monster it touches is
  stunned for 160 frames (it freezes and does no harm), or killed outright
  if it has no hit points to speak of (keese, gels); it also picks up items.
  Traps and Aquamentus ignore it
- blue candle: a flame 16 pixels ahead that creeps another 16 pixels, stands
  for 63 frames and burns the monsters it touches; once in each room
- inventory screen (`Tab`): freezes the game and lists the bombs, boomerang
  and candle Link owns; Left and Right move the B label
- push block (room `$42`): once the monsters are dead, stand against the
  block, lined up, and push for 16 frames. It swaps places with the floor
  beyond it and the room's shutters open for good (they no longer open when
  the last monster dies)
- pickups with their effects: keys, hearts, heart containers, rupees, bombs,
  the boomerang, the candle and the wooden sword. Maps, compasses, the bow
  and similar items are collected but do nothing yet
- Link is invincible and blinks for about 0.8 seconds after being hurt (the
  original's $18 timer ticks every second frame), and is knocked back 32
  pixels; monsters are knocked back up to 64 pixels when the sword hits them
  and are invincible for about half a second. Aquamentus and the keese are
  never knocked back

Tooling

- asset pipeline from the ROM to ST data (see below) with a placeholder
  fallback so the target still builds without any ROM
- unit tests for the asset pipeline
- headless Hatari harness that captures the framebuffer to a PNG, drives
  scripted key input, and can poke variables

Known gaps
----------

Things that behave differently from the original, or are stand-ins:

- fireball art is placeholder (Aquamentus himself is original)
- monsters wander randomly apart from the behaviours above; the clock is not
  Link's yet
- the push block slides in one jump rather than visibly, and only the
  trigger-4 kind (open the shutters) exists; the stairs kind is not needed in
  Level 1
- the triforce piece is not shown being held up, and the level's completion is
  not yet recorded anywhere
- `K` is a debug key standing in for the shops and secrets that give keys,
  bombs and the candle
- the overworld's real monsters are not ported; only the placeholder blobs
- the inventory screen only lists the B items; there is no map, compass or
  other item yet, and no map on the ribbon
- the song is written for 50 Hz; on a 60 Hz display every sixth frame holds
  it back so the tempo stays right

Roadmap
-------

Near term (finish Level 1)

1. the triforce piece held up, and the level's completion recorded
2. fireball art
3. map and compass use, and the dungeon map on the ribbon
4. the old man in room `$41` and the other dungeon people

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
- The IKBD interrupt vector (`$118`) is replaced by a handler that queues every
  byte in a ring buffer; the main loop parses the queue once a frame. The ACIA
  holds a single byte, so polling it lost key releases and left Link walking.
  The previous vector is restored on exit.
- The tables are reached through `a6` = `table_anchor`, now placed after
  `mon_sprites`: the tables before it must stay within 32KB back and
  `room_maps` within 32KB ahead. Growing them past that makes the assembler
  complain about an out-of-range displacement.

Licensing notes
---------------

- No proprietary ROM image or extracted Zelda asset is committed here.
- If you provide `ext/Original.nes`, you are responsible for ensuring you may
  lawfully possess and use that source data.
- The converter and 68000 source are open build inputs; generated artifacts
  stay out of version control.
