Atari STFM / Hatari port
========================

A native Atari ST port of The Legend of Zelda, built on top of aldonunez's NES
disassembly in `src/`. It runs as a stock TOS `.PRG` on a 512KB ST in 320x200
sixteen-colour mode, and reads all of its graphics, room layouts, palettes and
text out of a ROM you supply yourself.

Status: a playable game with eight dungeons. You can walk the whole overworld,
fetch the wooden sword from the first cave, fight the overworld's monsters,
and play Level 1 (to Aquamentus) and Level 2 (to the Dodongo, the heart
container and the triforce piece) as in the original; Levels 3 to 9 are built
with their rooms, items, monsters and bosses (up to Ganon and Zelda) but not yet played through. Every item the game has
is in the code, but most can only be found in the dungeons and caves that are
not ported yet. It is not yet a complete game: the shops and
most caves and saving are missing.

How to play
-----------

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D` or the joystick | walk (in 8-pixel grid steps, like the original) |
| `Space`, joystick fire | the sword, the NES A button (once you have it) |
| `Ctrl` or `Alternate` | the B item: bombs, boomerang, candle, bow, recorder, food, potion or rod |
| `Tab` | the inventory screen: Left and Right choose the B item, `Tab` goes back |
| `K` | debug: one key, four bombs and the candle |
| `Esc` | quit |

The two item boxes on the ribbon show what each button holds: the sword under
A (wooden, white or magical, as you earn it) and the chosen B item under B. The
boomerang is in Level 1 (room `$44`, in the goriyas' room), the magic boomerang
in Level 2 (room `$4F`); the candle, potions, rings and the like come from
caves and shops that are not ported yet, so for now only `K` (and pokes in the
test harness) give them.

A typical run:

1. The game opens on the first overworld screen, just below a cave. Walk up
   into it, wait for the old man to finish speaking, and take the wooden
   sword. Walk out through the bottom doorway.
2. Walk to the Level 1 entrance (overworld room `$37`) and go down the stairs.
   Level 2's entrance is on overworld room `$3C`.
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
- keyboard input through an IKBD interrupt that queues every byte, so no key
  release is ever missed
- YM2149 music and sound effects from a VBL hook: the NES original overworld theme, the ROM's
  dungeon and Level 9 themes, event fanfares and effects laid over the
  music (digidrums included): sword, boomerang, flame, bomb, stairs, pickups, hurt,
  the low-life beep and the menu and cave-text clicks. Everything is ripped from
  `ext/Original.nes` at build time with the ROM's own sound engine; without `py65` the game is silent
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
- cave entry and exit. All twenty kinds of cave are built from the ROM's
  tables: the old man and his sword, "take any one", the white and magic
  sword (five and twelve hearts), take-any-road with its three stairs, the
  letter, the medicine woman (she wakes when B shows her the letter), paid
  hints, the money making game, the door repair charge, the shops with their
  prices and the moblins' free rupees. What was given stays gone; rupees
  are paid out and taken one at a time with the little blip
- the game starts just below the first cave; dying refills the hearts and
  returns Link there
- octoroks, moblins and lynels walk on the screens where the original puts them
  and shoot as in the original (rocks, arrows, the lynel's sword shot; the
  sword parries rocks and arrows); the monsters of a screen stand in a spawn
  cloud for a moment before they move (octoroks longer), screens with edge
  spawns bring them in from the border one at a time instead, and monsters you kill stay dead for a few screens (the
  original's room history); the other overworld monsters are still missing

Overworld monsters

- octoroks (red, blue, slow, fast), moblins and lynels, tektites (the jump
  physics of the original), leevers (they burrow up and down), zoras and their
  fireballs, peahats, ghinis and the boulder screens, each on the screens where
  the original puts them. The shots (rock, arrow, sword shot) parry and bounce
  as in the original, screens with edge spawns bring the monsters in from the
  border, and killed monsters stay dead for a few screens (the room history)
- not yet: armos and the gravestone ghinis (the room-tile patch they need now exists, see
  "Hidden spots" below)

Hidden spots (overworld)

- the 43 spots of the First Quest, from the ROM's marker squares: 22 rock walls that a
  bomb opens (the cloud has to open within 16 pixels of the wall), 16 trees that a
  candle's (or the book's) flame burns into stairs, 4 rocks that need the power bracelet
  and 1 gravestone, which Link pushes straight up or down while standing level with
  them; the stairs they uncover are where the ROM puts them (attribute F bits 4-5)
- the secret tune plays, the spot becomes a cave entrance or stairs and works like any
  other (`check_warps`); the screens are patched in place (`room_maps` is in RAM) and
  `room_secrets` says what to patch. Found secrets stay open (room flag bit 7); a
  pushed rock or gravestone is back when Link returns, as in the original (the stairs
  under the rock stay, those under the gravestone do not)
- not like the original: the stone jumps one square instead of sliding, and the second
  quest's spots (attribute F bits 6-7) are plain scenery

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
  blocks. They turn as the original does: stalfos work their way toward Link,
  goriyas face him only when he is within $51 pixels and then throw on a
  2-in-256 roll each frame, ropes turn to a free side now and then, and gels
  cross a square at a pixel a frame and rest at its edge. Keese fly over everything instead, in eight directions: they speed
  up, then chase Link or wander for a few turns, slow to a stop, rest, and
  start again
- the old man in room `$41` stands between two flames and types out "EASTMOST
  PENNINSULA IS THE SECRET." while Link is held; Link cannot walk past him. The
  speech comes from the original dungeon-people tables. The flames do not shoot
  when he is hit. The "more bombs" man (Levels 5 and 7: 100 rupees for room for four
  more bombs) and the "life or money" man (a heart container or 50 rupees) are in
- the wooden sword, the boomerang, the bow and the candle are held up with the item
  fanfare when taken: Link stands still with his arms raised and the item over his
  head for about two seconds, and the monsters wait
- the triforce piece ends the level as in the original: Link holds it up, the screen
  flashes, his hearts fill one by one, a curtain closes the room, and he is back at
  the entrance on the overworld
- the room's items appear on the floor (a trigger-7 room's item appears when
  the monsters are dead) and stay collected

Level 2 (underworld)

- the 18 rooms reachable from the start room `$7D`, with their items and
  secrets from the ROM: the compass (`$6F`), the map (`$5F`), bombs, keys, five
  rupees, the magic boomerang (`$4F`), the heart container (`$0E`) and the
  triforce piece (`$0D`); the old man in `$1F` ("DODONGO DISLIKES SMOKE.");
  the cellar rooms; the level's own palette
- the dungeon is chosen through `level_table`: the tables of every level are
  built by the asset pipeline (`UW_LEVELS` in the Makefile and `build_assets.py`,
  kept equal by a test) and `uw_select_level` points the engine at them, so the
  next dungeon is data
- new monsters from the ROM: the blue goriya (throws boomerangs whenever its
  timer runs out), the **Dodongo** (walks lanes; swallows a lit bomb at its
  mouth and bloats, two bombs kill it; a bomb cloud near it stuns it for $20
  frames and the sword kills a stunned one, leaving a bomb), the **Moldorm**
  (worms of segments: the head steers toward Link or wanders, eight turns at a
  time, and every segment takes the heading of the one before it; a killed
  segment comes back once and the tail is removed instead, the head dies for
  good), blade traps (four or six to a room) and the keese that share
  their room, and the ringleader room (kill the leader and the rest go with it
  and the shutters open)
- stairs between the overworld and the level work both ways: Level 2 is entered
  from screen `$3C` and leaves back to it

Level 9 (Death Mountain)

- 57 rooms, the ten-entry cellar array (Silver Arrow and Red Ring are in cellars), the old men, and the man at the
  door who lets Link through only with all eight triforce pieces
- Lanmola (blue and red): two worms of four segments that uncoil from the left of the room, the head choosing a new
  way at every square and turning toward Link half the time (ROM `UpdateLamnola`; the original has ten segments)
- Patra (both kinds): an eye with seven children (eight in the original) that come out one at a time and orbit it;
  only the sword hurts them, the eye is proof until the children are gone
- Ganon: Link holds the Triforce of Courage up in the dark room, then Ganon hides, teleports and throws fire; the sword
  turns him brown, a silver arrow into a brown Ganon kills him, he burns to ashes and the Triforce of Power lies there
- Zelda (room `$32`) and the four fires that guard her: stand level with her (X `$70`..`$80`, Y `$95`) and the scene
  runs: the Zelda fanfare, the curtain, her thanks typed out, the two triforce pieces over Link and Zelda while the
  backdrop flashes, then the closing words. Then the credits, a page of three lines at a time (the staff, "ATARI ST PORT / BY Q", "END OF THE LEGEND OF ZELDA"); the last page stays, Esc quits.

Levels 3 to 8 (underworld)

- every room of the six dungeons, with its doors, items, secrets and palette, from the ROM
  tables; the dungeons are entered from the overworld by the level number of the stairs
- monsters: red and blue darknuts (a head-on sword blow is turned aside), gibdos, zols and
  vires (a blow that does not kill leaves two gels or two keese), pols voice (hops, an arrow
  kills it), like-likes (swallow Link and the magic shield), wizzrobes (red and blue),
  bubbles (stop the sword for a while)
- bosses: Manhandla (four hands that speed up), Gohma (blue and red; arrows at the open
  eye), Digdogger (the recorder splits it) and Gleeok (one to four necks; the body is baked
  into the room, necks and heads are drawn from a pool of pre-shifted pieces)
- rupee stash rooms, Grumble (fed with food to open the way) and dark rooms (black until
  the candle is used)
- rooms with seven or more monsters take two VBLs to draw: the game then runs its update
  once more without drawing, so the speed stays that of 60 Hz and only the picture drops to
  30 Hz (`catch_up`)

Combat and items

- sword: drawn from the original tiles in its four phases, and it only cuts
  while fully out; killed monsters roll the original drop table (hearts,
  rupees, bombs, the clock and the fairy) with its kill counter:
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
- the rest of Link's items, from the ROM's Items block (`items.s`, tables
  generated from `ItemIdToSlot` and `ItemIdToDescriptor`): the white and the
  magical sword (one, two and four hits' worth, with their own swing art and
  A box); the bow, which spends a rupee per arrow (silver arrows hit for double);
  the magic rod, which swings and fires a magic shot (with the book the shot
  becomes a flame at a wall); the red candle (as often as you like); the magic
  boomerang (longer reach); the potion (the hearts refill, one half heart every
  21 frames, while Link stands still); food (monsters that chase Link chase it
  instead for $FF frames); the recorder (plays its tune; the whirlwind is not
  in); the blue and red rings (damage halved or quartered, Link recoloured);
  the magic shield (parries fireballs and sword shots); the clock (freezes the
  monsters until the screen changes, and nothing can hurt Link meanwhile); the
  fairy (three hearts); the clock and fairy are also drops
- inventory screen (`Tab`): freezes the game and shows a 2x4 grid of the B
  items Link owns, plus a row of what he carries; Left and Right move
  the B label
- push block (room `$42`): once the monsters are dead, stand against the
  block, lined up, and push for 16 frames. It swaps places with the floor
  beyond it and the room's shutters open for good (they no longer open when
  the last monster dies)
- pickups with their effects: keys, hearts, heart containers, rupees, bombs,
  and every item above, plus the map and the compass
- the dungeon map in the corner of the ribbon: the level's rooms as grey boxes
  once you have the map, a green box where Link is, and with the compass the
  triforce room flashing until you take the piece
- Link is invincible and blinks for about 0.8 seconds after being hurt (the
  original's $18 timer ticks every second frame), and is knocked back 32
  pixels; monsters are knocked back up to 64 pixels when the sword hits them
  and are invincible for about half a second. Aquamentus and the keese are
  never knocked back

Tooling

- asset pipeline from the ROM to ST data (see below); every picture, room, text and sound is read from
  the ROM, nothing is drawn or recreated separately, and a build without the ROM stops with a message
- `tools/dump_tables.py` writes the ROM tables the port is built from (all
  overworld screens, every room of the nine dungeons, the monster lists) as JSON
  and Markdown under `build/dump`
- `tools/check_reach.py`, run after every link, fails the build when a table
  name is missing or when a branch or PC-relative operand does not fit 16 bits
  (GNU as wraps those silently); see "Notes on the ST implementation"
- golden frames: `tools/golden.py` runs twenty fixed scenes in Hatari and compares a
  hash of each screen with `tests/golden/frames.json` (see Testing)
- unit tests for the asset pipeline, and for the music packer and the 68000 music
  player (run on `machine68k`, every track checked frame by frame)
- headless Hatari harness that captures the framebuffer to a PNG, drives
  scripted key input, and can poke variables

Known gaps
----------

Things that behave differently from the original, or are stand-ins:

- Levels 3 to 9 were checked by loading every room in Hatari, by scripted runs (the second
  Digdogger and its heart container, Lanmola, Patra, a stash left and re-entered, the door
  man, the magic key on a locked door, the ladder over a moat) and by a test that replays every
  level's doors; nobody has played them through at human speed. Not checked: the first
  Digdogger's three little ones, a Vire dying into keese, scrolling between dark rooms. The
  ladder is not drawn: with it Link just walks over the moat
- the Moldorm is two worms of four segments, not one of ten, because the engine
  has eight monster slots; the Dodongo and the Moldorm leave no death cloud
- Level 2's Dodongo bomb and sword kill, the Moldorm's segment deaths and the
  ringleader room were checked by reading the code against the ROM and by
  loading every room in Hatari, but not played through
- most items cannot be found yet: the caves and shops that give the candle, the
  potions, rings, shield, recorder, food and rod are not ported (`K` and the
  harness's pokes stand in), and the recorder plays its tune without the whirlwind
- the push block slides in one jump rather than visibly, and only the
  trigger-4 kind (open the shutters) exists
- `K` is a debug key standing in for the shops and secrets that give keys,
  bombs and the candle
- overworld armos and gravestone ghinis are not ported (milestones M2 and M4 in `PLAN.md`); the hidden spots open, but
  most of the caves and stairs behind them are empty until M3, and a pushed stone jumps one square instead of sliding
- the old man's fireballs are not in; the overworld has no map on the ribbon
- the game follows the display: 50 Hz (PAL) plays at the PAL NES's speed, checked in Hatari with no dropped frames; 60 Hz runs the game at NTSC speed
- the song is written for 50 Hz; on a 60 Hz display every sixth frame holds
  it back so the tempo stays right
- all runs so far were in Hatari with 1 MB; the memory left on a 512 KB machine
  is not measured

Roadmap
-------

The detailed plan, with the data tables behind it, is in [`PLAN.md`](PLAN.md).

Next, in the order of `PLAN.md`

1. the caves behind the overworld's hidden spots (M1 is done): shops, hints, money-making games, doors that charge, shortcut
   stairs (M3), which is also where the items the engine already has come from
2. armos, gravestones and the rest of the overworld specials (M4): the raft,
   the ladder, the recorder's whirlwind, the animated pond
3. the other seven dungeons, now that a level is data (M6 to M9): per level the
   monsters, the boss and the palette rows of its sprites
4. game-over and continue, saving (the title and file menu are done), the ending; the missing
   songs (title, ending, game over, boss roars) (M10, M11)
5. a check on real STFM timing and memory, a release build (M12)

The Second Quest is deferred.

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

Put a 131,088-byte iNES ROM image at `ext/Original.nes` (the port is built and tested with *The Legend of
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
- **underworld**: rebuilds each level's rooms (`UW_LEVELS`: 1 and 2 so far) from
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

The golden frames are ten such scenes (`tools/golden.py`): each prints a hash of
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
  one. The code cluster is full: today the tightest reference has 86 bytes to
  spare. A module that has to call across the image goes through a `*_far` stub
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
