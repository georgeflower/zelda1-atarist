# AGENTS.md - everything an AI assistant needs to work on this project

This file is the single briefing for any coding agent (Claude, Copilot, Codex,
...). `CLAUDE.md` is an identical copy for tools that look for that name. Read it
before researching anything: most questions have been answered here. If you
learn something new and durable, add it here.

## 1. What this is

A native **Atari ST (STFM, 512 KB, 68000)** port of **The Legend of Zelda (NES,
1986)**, written in 68000 assembly (GNU as syntax) and driven by a Python asset
pipeline that reads graphics, rooms, palettes and text from a **ROM you supply
yourself** (`ext/Original.nes`, gitignored, never committed). It produces a stock
TOS `ZELDAST.PRG` that runs in Hatari (and should on real hardware): 320x200,
16 colours, 4-plane interleaved.

Current scope: the whole overworld is walkable (128 screens), the first cave
and the wooden sword, and **Level 1 (the Eagle dungeon)** is playable to the boss
Aquamentus and the triforce piece. Everything else (other 8 dungeons, real
overworld monsters, shops, dungeon people) is future work, see
section 14.

The repository root also contains the original disassembly the port is built on
(`src/Z_00.asm` .. `Z_07.asm`, aldonunez's labelled NES disassembly). It is the
**reference for every behaviour**: when you need a number (speed, timer,
damage, tile id, table), read it from there rather than guessing.

## 2. References and links (provided by the project owner - treat as truth)

- **Code truth, raw**: <https://github.com/camthesaxman/zeldasource> (unlabelled
  `lbl_xxxx` asm, no data labels; e.g.
  <https://raw.githubusercontent.com/camthesaxman/zeldasource/master/bank5.asm>).
  The labelled `src/` in this repo (aldonunez) is the readable cross-check.
- **Aldo Nunez's work**: the `src/` disassembly in this repo; his enhanced
  variant is <https://github.com/aldonunez/Loz_enhanced>.
- **Other projects looked at**: <https://github.com/ArmageddonGames/ZeldaClassic/tree/main>,
  <https://github.com/Matthew-SA/zelda-js> (a JS Zelda 1 clone, handy for
  behaviour cross-checks), and an Atari ST/STFM game example for ST-specific
  code structure: <https://github.com/georgeflower/quanoid-atari-stfm>.
- **Level and map guides** (zeldadungeon.net walkthrough, slug after
  `https://www.zeldadungeon.net/the-legend-of-zelda-walkthrough/`):
  `the-gathering` (= overworld), `level-1-the-eagle`, `level-2-the-moon`,
  `level-3-the-manji`, `level-4-the-snake`, `level-5-the-lizard`,
  `level-6-the-dragon`, `level-7-the-demon`, `level-8-the-lion`,
  `level-9-death-mountain`. Item/sword info:
  <https://www.zeldadungeon.net/wiki/Sword_>.
- Hatari emulator: <https://hatari-emu.org> (version used: **2.6.1**).
- The owner tests `ZELDAST.PRG` (sometimes renamed) in Hatari, and sends
  screenshots/videos with red marks. Overworld start = room `$77`, X `$78`, Y `$8D`
  (ROM LevelInfo); the port opens in front of the first cave (HOME_X `$40`,
  HOME_Y `$5D`).
- The owner wants **fidelity to the original source** for behaviour, and
  Atari-appropriate controls. They iterate by playing, reporting gaps.

## 3. Repository layout

```
build.ps1, util.ps1      PowerShell helpers from the original disassembly project
README.md                short project overview (+ controls)
AGENTS.md / CLAUDE.md    this briefing
src/                     ORIGINAL NES disassembly (Z_00..Z_07.asm, *.inc, bins.xml, dat/)
ext/Original.nes         your ROM (gitignored). (U) PRG0 or PRG1, 131088 bytes
atari_st/                the port
  Makefile               build: assets -> as -> ld -> objcopy -> PRG
  link.ld                linker script: .text, .data, then .rodata, single flat section
  README.md              user-facing docs: features, known gaps, roadmap, notes
  src/*.s                68000 code (one assembly unit, main.s .includes the rest)
  tools/*.py             asset pipeline, PRG packer, Hatari screenshot harness
  tests/*.py             unittest suites (86 tests)
  music/                 YM2149 song source (zelda_intro_by_qum.h) + player (ymplay.h)
  build/                 OUTPUT (gitignored): generated/, ZELDAST.PRG, scratch, shots/
```

`atari_st/src`:

| file | role |
| --- | --- |
| `main.s` | equates, `_start`, main loop, mode dispatch, double buffering, erase state, `.rodata` incbins, `.data` |
| `globals.s` | the variable block (`gvar` macro generates `OFF_*` offsets) |
| `video.s` | init/restore video + IKBD vector, room rendering, scroll composition, `wait_vbl`, HUD palette |
| `sprite.s` | masked 16x16 blitter (`draw_sprite`), `erase_at`, Link drawing |
| `link.s` | input -> direction, grid-step movement, collision, room transitions, caves, scroll |
| `enemy.s` | monster spawn, walker AI (16-px lanes), shove, draw, `sprite_offset`, `rand8` |
| `ai.s` | per-monster behaviours (rope, goriya, wallmaster, Aquamentus, keese, blade trap), projectile system, **Link's boomerang** |
| `combat.s` | sword, beam, bombs, candle, drops/kill counters, pickups, HP/knock-back, effects (spark/cloud), push block, shutters, triforce ending |
| `hud.s` | status ribbon, hearts, counters, A/B boxes (`hud_items`) |
| `menu.s` | Tab inventory screen (MODE_MENU) |
| `uw.s` | underworld rooms, doors, stairs/cellar, level entry/exit, `debug_keys` (K) |
| `input.s` | IKBD interrupt handler (`ikbd_isr`) + parser (`poll_keyboard`): scancodes, joystick, mouse skip |
| `music.s` | music and sound effects replayed from the VBL hook: four register-stream contexts (song, effect over voice A, effect over voice B, noise effect over voice C) read from one bank, merged and written to the PSG (+ digidrum engine in `.data`) |

`atari_st/tools`:

| file | role |
| --- | --- |
| `build_assets.py` | ROM -> ST data: tiles, rooms, palette, HUD glyphs, caves, writes `build/generated/*.bin` and `assets.inc`; placeholder fallback; `--verify-only`, `--require-source` |
| `underworld.py` | Level tile rooms (LayOutRoom port), doors, cellars, reachable rooms |
| `actors.py` | monsters, items, drops, sprites (sword, beam, effects, boomerang, HUD icons), per-room records |
| `make_prg.py` | wraps the flat binary into a TOS PRG header (`--check` validates) |
| `screenshot.py` | **headless Hatari harness**: runs the PRG, injects keys, pokes variables, dumps RAM, decodes framebuffer to PNG, prints a state report |
| `dev_run.sh` | build with a start room + capture (needs `$TOS`) |
| `compare_render.py`, `render_map.py` | diff the renderer against a Python render; render maps |
| `ym_convert.py` | converts the song + player header into `music_data.bin`, `music_engine.bin`, drums, `music.inc` |
| `music_pack.py` | packs the shipped overworld song and every other track ripped from the ROM (via `nes_music_rip.py`) into `music_bank.bin`, one shared `music_drum_table.bin` and `music_ids.inc`. Without the ROM or `py65` the bank holds only the overworld song and the rest stays silent. The Makefile passes `--overworld $(MUSIC_OVERWORLD)`: `rip` (default) is the NES original, `make MUSIC_OVERWORLD=qum` the shipped arrangement (without the ROM the shipped song is always used) |
| `nes_music_rip.py` | runs the ROM's own sound engine (bank 0) in py65 and writes every song, jingle and sound effect as `.ym` (YM6, 50 Hz; noise drums or digidrums). Output is ROM-derived: `*.ym` is gitignored. `--list` shows the tracks |

## 4. The exact toolchain (this is how it is built and tested here)

Host: **Windows 11** with **WSL (Ubuntu)**. There is **no native Windows make**;
everything that builds runs in WSL.

- Packages in WSL: `sudo apt-get install -y python3 binutils-m68k-linux-gnu hatari`
  (sudo worked without a password prompt in this environment).
- Assembler/linker: **`m68k-linux-gnu-as -m68000`**, `m68k-linux-gnu-ld -T link.ld
  -nostdlib -e _start`, `m68k-linux-gnu-objcopy -O binary`. **Not** the
  `m68k-atari-mint` binutils: that `as` (2.30) rejects `.section .text/.data/.rodata`.
- Python: WSL `python3` for the build (`make`), Windows `python` (3.14) also runs
  the unit tests and small image helpers (Pillow is installed there; used to
  crop/zoom PNGs). Pure stdlib otherwise.
- Hatari **2.6.1** installed in WSL (`apt`); a Windows build lives at
  `G:\OneDrive\Download Saved\Nostalgia\hatari-2.6.1_windows64\` which also holds
  the TOS images: `TOSes\ST\104_us.img` (**TOS 1.04 US**, used for all tests).
  From WSL that is
  `/mnt/g/OneDrive/Download Saved/Nostalgia/hatari-2.6.1_windows64/TOSes/ST/104_us.img`.
  Never commit TOS images or the ROM (copyrighted). **EmuTOS 1.4 (512k, `etos512us.img`)
  also works** and was used to check the music: pass it as `--tos`/`TOS`.
- Editor/shell: VS Code, PowerShell as the terminal.

### Build commands

From `atari_st/` (inside WSL) or via `make -C atari_st` from the repo root:

```sh
make all        # assets + assemble + link + PRG  -> build/ZELDAST.PRG
make check      # all + unit tests + asset verify + PRG header check
make clean      # rm -rf build  (deletes scratch scripts in build/ too!)
```

From PowerShell:

```powershell
wsl.exe bash -c "cd /mnt/g/OneDrive/Documents/GitHub/zelda1-atarist/atari_st && make all 2>&1 | tail -20"
python -m unittest discover -s atari_st\tests          # unit tests, Windows python
```

The music bank (`music_bank.bin`, `music_drum_table.bin`, `music_ids.inc`) is built by `music_pack.py` from
`ext/Original.nes`; the Makefile also tracks whether `py65` is importable (`build/music_capability.stamp`), so
installing or removing it rebuilds the bank. Without ROM or `py65` the bank holds only the overworld song.

Makefile variables: `TOOLCHAIN_PREFIX` (default `m68k-linux-gnu-`), `PYTHON`
(`python3`). Environment for the tools: `TOS` (path to a TOS image, needed by the
screenshot harness), `HATARI` (binary, default `hatari`), and the **dev-start
variables** below.

The *"placeholder tiles ... will NOT resemble the original game artwork"* warning is
printed only when the assets are generated without a ROM (`build/generated/asset_manifest.txt`
then says `source=generated placeholder CHR`). With the real ROM it should not appear.

### Dev start variables (BAKED INTO THE BUILD - important)

- `ZELDA_START_UW=0x74` starts inside Level 1 in room `$74`, with the sword
  (Link at X `$78`, Y `$8D`).
- `ZELDA_START_ROOM=0x37` starts in another overworld room.
- They write `DEV_START_UW`/`START_ROOM_ID` into `build/generated/assets.inc`.
  The Makefile tracks both variables in `build/dev_start.stamp`, so changing them
  (including unsetting them) regenerates the assets on the next `make`; no `touch`
  is needed. Any change to `actors.py`, `underworld.py`, etc. regenerates assets
  too, using **whatever env is set then**.
- **Finish with a default build**: `unset ZELDA_START_UW ZELDA_START_ROOM; make all`.
  To confirm, `grep -E 'DEV_START_UW|START_ROOM_ID' build/generated/assets.inc`
  should show `START_ROOM_ID, 0x77` and `DEV_START_UW, 255`; otherwise the owner's
  PRG starts in a dungeon.

## 5. Testing

### Unit tests
`atari_st/tests/` (`test_build_assets.py`, `test_actors.py`, `test_ym_convert.py`,
`test_nes_music_rip.py` (needs `py65` for the ROM part, `ZELDA_ROM` or `ext/Original.nes`),
`test_music_player.py` (the packer, and `music.s` run on `machine68k` through `tests/music_harness.s`; needs the m68k binutils and `pip install machine68k`, the real-bank part also the ROM and `py65`),
...). Run `python -m unittest discover -s atari_st\tests` (86 tests at the time of
writing). They cover the asset pipeline and tables; the 68000 music player is the one piece of
68000 code with unit tests.

### The Hatari harness (`tools/screenshot.py`)
Hatari is run **headless** (`SDL_VIDEODRIVER=dummy`, `--disable-video true`,
`--machine st --memsize 1 --cpu-exact --fast-boot --fast-forward --sound off`).
The PRG is launched by **GEMDOS hard-drive autostart**: it copies the PRG to
`build/shots/hd/ZELDAST.PRG` and passes `--harddrive build/shots/hd --auto
C:\ZELDAST.PRG` (passing the PRG as a plain argument does NOT launch it).
A debugger script (`--parse`) sets a breakpoint on a VBL count, then dumps
`m $ff8200..` (video base), `m $ff8240..` (palette) and `savebin ram.bin 0 $100000`.
The script decodes the 4-plane framebuffer to a PNG and prints one report line.

```sh
export TOS='/mnt/g/OneDrive/Download Saved/Nostalgia/hatari-2.6.1_windows64/TOSes/ST/104_us.img'
python3 tools/screenshot.py --vbls 800 --keys '700:+k,702:-k,710:+space,712:-space' --out build/shot.png
```

- `--vbls N`: capture at VBL N. The program only starts running the game after
  roughly **700 VBLs**; use `--vbls >= 700`. `FRAME_COUNTER` in the report is the
  game's own frame count (about N-610).
- `--keys` is `"<vbl>:+<key>,<vbl>:-<key>,..."`: key press/release events injected
  by **poking the key-state table** in RAM (not through the IKBD), so they test the
  game logic but not `ikbd_isr`. Known keys: `up down left right w a s d k b space
  tab ctrl alt` (extend `SCANCODES` in `screenshot.py` for more).
- **Poke events**: `700:=ENEMY_X.0=120` writes byte 0 of variable `ENEMY_X`;
  `700:=LINK_X=0x78` pokes a plain byte; `.N` indexes arrays. Variable names are
  the `gvar` names in `src/globals.s` (the harness replays the macro to get
  offsets; the block is found in RAM by the marker `ZELDAST1`).
- `--trace psg_write`: logs every YM2149 write (`ym write data reg=0xR val=0xV ... pc=...`) to
  `build/shots/hatari.log`. `music_write` always writes R0..R12 in order from one `pc` (R13 only
  with an envelope shape), the digidrum engine writes the drum's volume register from another;
  group by `pc` and compare frames with `music_pack.unpack_stream` of `build/generated/music_bank.bin`.
  Verified this way: 745 overworld frames, 659 dungeon frames, a bomb effect overlay, digidrum samples.
- `--trace cpu_exception,...`: Hatari trace flags; look for faults whose PC is in
  RAM (app bug) versus ROM `$fcxxxx-$feffff` (TOS internal, harmless; e.g. the
  blitter probe bus error at `$fc0ee2`).
- The report prints a fixed set of variables (edit the list near the bottom of
  `screenshot.py` to add more), `ENEMIES (x,y)...`, `UW_OPEN[...]`, FRAME_COUNTER.
- **Each run is a fresh emulation and timing varies by a few frames**: do not
  compare positions across separate runs as one trajectory.
- Typical scripted tests: key a dev-start build (`ZELDA_START_UW=0x74`), give items
  with `K` (`700:+k,702:-k`) or pokes (`700:=INV_BOOMERANG=1,700:=B_ITEM=2`), act at
  710, capture at 715-800. Room `$74` has 2 stalfos near (0x60,0x6d); `$42` is the
  push-block room (block at X `$70`, Y `$90`; clear monsters by poking
  `ENEMY_ACTIVE.n=0`, stand at X `$80`, hold `left`); `$22` is the trap room (poke
  `LINK_Y=0x5d` to trigger the top traps).

### PowerShell + WSL quirks (cost hours once)
- `wsl.exe bash -lc '...'` run from the terminal tool does **not** expand shell
  variables assigned in the same invocation. **Write a `.sh` file and run it**:
  `wsl.exe bash -c "sed -i 's/\r$//' /mnt/g/.../x.sh; bash /mnt/g/.../x.sh"`.
  Files created by editor tools have **CRLF** endings, which break bash: always
  `sed -i 's/\r$//'` first. A file cannot be re-created with the create tool; pick a
  new name or edit it.
- `... | tail` after `wsl.exe` runs `tail` in PowerShell (not found). Pipe inside
  the WSL command or the script.
- PowerShell has no heredocs; write files with the editor tools.
- `make clean` wipes `atari_st/build/*`, including scratch scripts and probes.
- Hatari quirks: `--memsize 4` with TOS 1.04 bus-errors during TOS's own RAM test
  (use `--memsize 1`); Hatari here runs at **60 Hz** (133,600 cycles per frame).

## 6. Memory map, registers and conventions of the 68000 code

- `a5` = the variable block (`globals`), offsets `OFF_<NAME>` generated by the
  `gvar NAME, size` macro in `globals.s` (longs first, `galign` before long
  arrays; the harness parses the same file). `a6` = `table_anchor`, **reserved for
  the whole run**; read-only tables are reached with the **`ltab sym, %aN`** macro
  (`lea sym - table_anchor(%a6), %aN`). Nothing else may use `a6`.
- The 68000's signed 16-bit displacement limits table reach to +-32 KB from the
  anchor. `table_anchor` sits right after `mon_sprites`: tables before it (assets
  include, `uw_tiles`, `uw_rooms`, ...) must stay within 32 KB back (about 5 KB
  slack), `room_maps` (largest, last) must stay within 32 KB ahead (about 3 KB
  slack). Overflow = assembler "out of range" error. Move tables across the anchor
  if you add data.
- `d8(%a5,%dn)` addressing has an **8-bit displacement**: an array indexed that
  way must start below offset 128 (the per-actor arrays are at the front of
  `globals.s`, `ENEMY_STEP` is the last that fits). For anything else `lea` the
  base first.
- **GAS m68k comment char is `|`** (not `;`), even inside expressions like
  `#(A | B)` -> use `+`. Local labels are **numeric only** (`1:`, `10:`; refer
  `1f`/`1b`); labels like `5a` are invalid. Reusing a number is fine - a forward
  reference binds to the nearest following definition.
- Word/long access at an **odd address = Address Error** (garbage PC). Align.
- `eor.w mem,Dn` is illegal; `moveq` range is -128..127 and sets flags (don't put it
  between a `cmp` and its branch); `movem` does not change flags; `divu.w` divides a
  whole 32-bit register (clear the upper half first).
- Supervisor: a `.PRG` from the desktop starts in **user mode**; ST hardware
  registers and `$0-$7FF` system variables bus-error ("2 bombs") in user mode. The
  program calls GEMDOS `Super(0)` first and restores it before `Pterm0`.
  Bomb count = 68000 exception vector number (2 bus error, 3 address error).
- `Pexec` gives the program the whole TPA so `Malloc` returns 0: `Mshrink` first,
  after moving to a private stack (`stack_top`, in `.data`).
- Everything is one flat section; `link.ld` emits `.data` before `.rodata` so `lea
  globals(%pc)` stays in 16-bit reach.
- Hardware: palette `$FF8240`, video base `$FF8201/03` (+`$FF820D` STE only,
  harmless on ST), shifter mode `$FF8260`, MFP `$FFFAxx`, IKBD ACIA `$FFFC00/02`,
  YM2149 `$FF8800/02`, sync mode `$FF820A` (bit 1: 50 Hz when set).
- Routine convention: save what you clobber with `movem.l`; most routines list the
  registers they take in a header comment. `d5` is "the current monster" in all
  enemy code, `d7`/`a4` = projectile slot / `PROJ_KIND` base in the projectile code.

## 7. The frame loop

`main_loop`: `wait_vbl` -> `frame_begin` -> `poll_keyboard` -> `debug_keys` ->
`music_update` -> dispatch on `GAME_MODE`:

| mode | value | handler |
| --- | --- | --- |
| `MODE_PLAY` | 0 | `update_play` (double buffered) |
| `MODE_SCROLL` | 1 | `update_scroll` (room transition, draws to visible screen) |
| `MODE_CAVE` | 2 | `update_cave` (caves, visible screen) |
| `MODE_MENU` | 3 | `update_menu` (Tab inventory screen, visible screen) |

**Double buffering**: play frames draw into a hidden buffer (`SCREEN_PTR` = buffer
being drawn into, `BG_NEXT` = the other) shown the next frame (`present_frame`
writes the video base before line 260 of 263; `wait_vbl` verifies it). Every
sprite records where it was drawn; the hidden buffer is cleaned using what was
drawn two frames ago (`xchg_state` swaps the `*_ERASE_*` / `OLD_*` arrays in
`swap_erase_state`). **When you add a new sprite**: give it an erase offset (+valid
flag) in `globals.s`, erase it at the top of `update_play`, draw it at the bottom,
add its arrays to `swap_erase_state`, `clear_old_erase_state`, `clear_erase_state`.
The generic route is the **effect slots** (`FX_*`, 12 slots, `fx_put`, drawn from
`fx_sprites`): slots 0-3 spark corners, 4-7 bomb cloud, 8 candle flame.
Scrolls, caves and the menu bypass double buffering (`dbl_end` / `dbl_enter`).

`update_play` order: erase everything -> `menu_check_open` -> `sword_input` ->
`b_item_input` -> `link_update` -> `update_enemies` -> `update_combat` (sword hits,
beam, enemy contact, item pickup, beam/fire/block/bomb ticks, room clear) ->
`update_projectiles` -> draw items, bomb, enemies, projectiles, Link (blinks when
hurt), beam, effects, sword -> `present_frame`.

Frame budget at 8 MHz: ~133,600 cycles (60 Hz) - the sprite blitter shifts at run
time (no pre-shifted copies).

## 8. Screen, coordinates, rendering

- 320x200, planar: 160 bytes/line; HUD ribbon y 0..23 (three 8-px tile rows), playfield
  256x176 at x 32..287, y 24..199. Entities use **NES coordinates** (X 0..255, Y
  `$40`..`$EF`; Link grid X mod 8 = 0, Y mod 8 = 5; overworld Link starts Y `$8D`);
  `sprite_offset` (enemy.s) converts X,Y (d1,d2) to a byte offset + shift (d4 = -1 when
  off the playfield).
- Overworld rooms: 16x11 squares -> `room_maps.bin` + `metatiles.bin` (planar
  metatiles); collision via `fetch_tile` (NES tile ids, `walkable_tiles`).
  Underworld rooms: **32x22 tile maps** `OFF_UW_MAP` (index `row*32+col`, bank ids ->
  `uw_tile_nes` gives the NES tile), rebuilt from stored room data + open doors by
  `uw_build_map`; `uw_redraw_room` re-renders (it REBUILDS the map, so in-place map
  edits such as the pushed block must be re-applied after).
- One ST palette covers all NES background and sprite rows (16 colours, no
  collisions). Sprite palette rows are `LINK_PALETTE_ROW (4) + attribute & 3`.
- Sprites: 16x16, 4 planes + 1 mask word, **160 bytes** (`SPRITE_FRAME_BYTES`). Narrow
  NES items (8 wide) are centred in the 16 px frame. `draw_sprite` (a0 frame, a1
  dest, d0 shift), `erase_at` restores from `BG_CUR` (the clean room).
- HUD glyphs are 8x8 (`draw_hud_tile`, byte stores, no shifting); `text_glyphs`
  maps NES text codes (digits 0-9, A-Z = `$0A`-`$23`, space `$24`, `.`=`$2C`,
  `-`=`$2F`) to glyphs; `menu_text` converts ASCII.
- `hud_items.bin`: icons for A/B boxes, 2 tiles each, order **sword, bomb, boomerang,
  candle** (so B item code n indexes it directly), then **compass, map, bow** (Tab screen).

## 9. Input

- `ikbd_isr` (vector `$118`) queues every IKBD byte in a 256-byte ring
  (`ikbd_state`: head, tail, ring); `poll_keyboard` parses once per frame: scancodes
  into `KEY_STATES[128]` (break = bit 7), joystick event packets (`$FE` port 0 / `$FF`
  port 1 + state byte: bits 0-3 up/down/left/right, bit 7 fire -> `JOY0/JOY1`), mouse
  packets (`$F8-$FB` + 2 bytes) skipped. Joystick reporting is enabled with IKBD
  command `$14` in `init_video`. TOS's handler is restored on exit. (History: polling
  the ACIA once a frame lost key releases -> "Link walks up by himself".)
- `read_input_dir` reduces held keys to one direction: bits right=1, left=2, down=4,
  up=8, **lowest bit wins** (so a stuck Up shows only when nothing else is held); a
  direction pressed this frame wins, else the current one is kept while held.
- **Controls**: arrows / `W A S D` / joystick walk; **`Space` or joystick fire =
  sword (A)**; **`Ctrl` or `Alternate` = B item** (bombs / boomerang / candle, edge
  triggered); **`Tab` = inventory screen**; `K` debug; `Esc` quit. Scancodes: Space
  `$39`, Ctrl `$1D`, Alt `$38`, Tab `$0F`, K `$25`, Esc `$01`.

## 10. Gameplay systems and the original numbers they follow

Where a value is listed it was read from the disassembly (file in `src/`).

- **Movement**: Link moves in 8-px grid steps, decisions only on boundaries; collision
  per `GetCollidableTile` (hotspot `$B` below the top); UW first unwalkable tile `$78`.
- **Walking monsters**: 16-px lanes; turn/choose only when X&15==0 and Y&15==13; blocked
  -> random perpendicular, other perpendicular, reverse, stop. The turns themselves follow the ROM
  (`ai.s`): stalfos/gels `Wanderer_TargetPlayer` (`wander_tick`; rate `$80` / `$20`, turn timer in `ENEMY_TURN`:
  level with Link within 8 px -> straight at him, else sideways toward him when the timer ends); goriya
  `UpdateGoriya` (faces Link only if within `$51` on the longer axis, keeps its heading otherwise; the red
  one throws on rolls `$23`/`$77`, 2 frames in 256, only with `ENEMY_WANT` set at a boundary; the throw timer
  is set when it throws); rope `UpdateRope` (timer `rand&$3F`, `enemy_face_unblocked` never ahead; rush
  only from a boundary); gel moves 1 px/frame and rests `$08/$18/$28/$38` frames at each square edge. Keese: `ControlKeeseFlight`
  state machine (accelerate to `$C0`, chase/wander, slow, rest), fly over blocks, 8 dirs.
- **Damage/invincibility**: Link `ObjInvincibilityTimer` `$18` counted every 2nd frame =
  48 frames, shove 32 px; monsters `$10` = 32 frames, shove up to 64 px at 4 px/frame.
  Damage table `ObjTypeToDamagePoints` (`$80` = half heart, `$01` = one heart).
- **Sword**: phases 1,8,1,1,1 frames; only cuts in state 2; tile `$20` (vertical,
  narrow) / `$82` (horizontal); offsets `PlayerToWeaponOffsetsX/Y` (Z_07). **Beam** (full
  hearts or one half short): launched at phase 3, 3 px/frame, palette cycles with
  `FrameCounter & 3`, spark tile `$30` in 4 corners spreading k=2..23.
- **Bombs**: fuse 48 frames; cloud 36 frames: first 24 damage (radius `$18`, `$40`
  damage = 4 sword hits) + two grey screen flashes (timer 22-19 and 17-14), last 12 open
  a bombable wall; max 8; tiles `$34` (bomb), `$70/$72` clouds. Gone when you leave
  the room (`clear_bomb`).
- **Drops** (`SetUpDroppedItem`, `HandleMonsterDied`, `Link_BeHarmed`): kill counter,
  `HelpDropCount` reaching 10 forces a drop (bomb if the 10th was a bomb kill, else 5
  rupees), 16th kill = fairy (not drawn yet); `WorldKillCycle` advances **before** the
  lookup; table rows per monster group, rates `DropItemRates`; being hurt resets the
  counters. Drops live `$FF` counts every 2nd frame, flicker and can't be taken for 30
  frames. Bomb pickup +4 (cap 8).
- **Boomerang** (`UpdateArrowOrBoomerang`, `WieldBoomerang`): placed 16 px ahead, 3 px/frame
  for 49 px (limit `$31`) or until blocked, 3-frame spark, slow phase (1 px/frame, `$10`
  frames), then returns to Link (a wall only stops it while flying out: in the slow phase it stays put and the phase still runs out); one at a time; stun `ObjStunTimer` `$10` = 160 frames;
  kills monsters with HP 0 (gel, keese); picks up items; traps/boss ignore it. Art:
  item slot `$1D` tiles `$36,$38,$3A` + spark `$3C`, spin cycle `{0,1,2,1,0,1,2,1}` with
  flips. Stunned monsters do nothing and do no contact damage (`ENEMY_STUN`).
- **Candle**: blue candle, fire 16 px ahead, creeps 16 px at half a pixel/frame, stands 63
  frames, burns monsters within 14 px (1 hit), once per room (`CANDLE_USED`).
- **Blade traps** (`InitTrap_Full`, `UpdateTrap_Full`): room `$22` only. Type `$4A` = 4
  traps at (`$20,$5D`)(`$20,$BD`)(`$D0,$5D`)(`$D0,$BD`) (type `$49` makes 6, adding
  (`$40,$8D`)(`$B0,$8D`)); allowed directions `05 09 06 0A 01 02`; trigger when Link is
  within `$0E` on the other axis; out at `$70/64` px/frame until within 5 of the room
  middle (`$78` / `$90`), back at `$20/64`; damage 1 heart; invulnerable; `ENEMY_ACTIVE=2`.
- **Push block** (rooms with attribute D bit 6: `$42` with trigger 4, and `$22`, the bow room, with
  trigger 0; the room record's trigger byte carries it as bit 7, `ROOM_BLOCK`): block tile `$B0` at tile row 10 (found from col 4,
  step 2); push only when the room is cleared (UW_FLAGS bit 0), Link lined up and pushing
  16 frames; it swaps with the floor 16 px beyond. Only trigger-4 rooms open their shutters for good (and
  do not open them on clear); in `$22` the block just moves (secret tune): the stairs sit inside a ring of 8
  blocks and the player pushes the left block up or down to open a gap. Slide is instantaneous (no animation).
- **Triforce ending** (`UpdateMode12EndLevel_Full`; `ending_update` in combat.s, phases in `ENDING_PHASE`):
  taking item `$1B` records the level's piece (`TRIFORCE_PIECES`, bit level-1), starts the end-level song and hides
  monsters; 1 Link holds it up for 48 frames (his arms-up picture is item picture `$3F`, tile `$78`, drawn
  by `draw_link`, the piece floats 16 px above him as item state `ITEM_LIFTED`), 2 the backdrop flashes white for 48 frames, 3 hearts fill a half heart every 21
  frames (heart blip), 4 a curtain blanks one 8-px column from each side every 5 frames for 16 steps
  (`curtain_column` clears it in the clean room and both screens), 5 a 128-frame pause on the black room,
  then `uw_leave_level`. Input is frozen by `LINK_HELD`; the Tab menu is blocked while the phase is non-zero.
- **Map and compass** (`TakeClass0Complex`, `UpdatePositionMarker`): items `$17` (map) and `$16` (compass) set the
  bit of the current level in `INV_MAP` / `INV_COMPASS` (bit level-1, like `TRIFORCE_PIECES`) and play the item-taken blip. The
  dungeon minimap lives in `hud.s` (`draw_minimap`, called by `draw_hud`): the free 32x24 pixel corner left of the counters, each room
  of the level a 4x3 cell with a 3x2 grey box (the NES uses 8x4 cells; this ribbon is 24 lines tall). Boxes show only with the map, Link's
  room is always a green box, and with the compass the triforce room is a box that flashes red/white every 16 frames until the piece
  is taken, then stays dull. The Tab screen shows the same map bigger (`mm_box_big`, 8x3 cells, rows 3-5) between the compass and map icons he owns (`menu_dungeon`). Rooms come from `uw_room_index`; `UW_MAP_COL0` (circular window of 8 columns, centred, from
  `underworld.minimap_first_column`) and `UW_TRIFORCE_ROOM` (LevelInfo) are build equates. `minimap_tick` (main loop) raises
  `HUD_DIRTY` when the room, the items or the flash phase change (`MINIMAP_SIG`). The overworld shows nothing there yet.
- **Secret triggers** (`LevelBlock` attr F & 7): 1 kill all -> open shutters, 4 push block,
  7 kill all -> item appears; others in `Z_05.asm` (`CheckSecretTrigger`).
- **Level 1 rooms** (reachable from `$73`): `$22` traps, `$23` goriya+key, `$33` stalfos+key,
  `$35` Aquamentus + heart container, `$36` triforce, `$41` old man (`$4C` person, see
  **Dungeon people**), `$42` gels + push block, `$43` map room, `$44` goriyas + **boomerang**, `$45`
  wallmasters, `$52` keese, `$53` stalfos, `$54` keese + compass, `$63`, `$72` keese,
  `$73` start, `$74` stalfos; cellar `$7F` (bow, 4 keese).
- **Dungeon people** (`$4B..$52` in the room list; `actors.dungeon_people`): the speech is picked through
  `UnderworldPersonTextSelectorsA/B` (`Z_01.asm`, by level) and `PersonTextAddrs`, appended to `cave_text.bin` after the
  first cave's speech; the room record is 16 bytes and byte 14 is the speech offset (`$FF` = nobody). `uw_spawn` calls
  `uw_person_begin` (`uw.s`): `UW_PERSON` 1 while speaking (Link held, `cave_talk` types the text), 2 afterwards.
  `uw_bake_person` draws the man into the room buffers, `draw_effects` the two flames, `link_collide` blocks Link
  going up past Y `$8E`. Not ported: hitting him to make the flames shoot, the "more bombs" (`$4F`) and
  life-or-money (`$51`) people; the flame is the candle flame art.
- **Item ids** (`ItemIdToSlot`): `00` bomb, `01` wood sword, `06` blue candle, `0A` bow, `0F` 5
  rupees, `16` compass, `17` map, `18` rupee, `19` key, `1A` heart container, `1B`
  triforce, `1D` boomerang, `22` heart, `23` fairy.
- **Music and sound**: YM2149 register streams (the MOD/XM->YM tool's game-kit format) replayed
  from a VBL hook (`music_vbl`, chains to TOS's handler). `music_update` (every frame) picks the
  area song from the state: overworld theme, dungeon theme (level 1-8), level 9 theme, silence in
  caves. Events call `music_play`/`music_event` through the `sfx` and `jingle` macros
  (item pickup, triforce, Link hurt/dead, bomb set and blast, kill, shutters/bombed wall, sword swing,
  boomerang throw, candle flame, stairs/cellar/cave entry, menu click, cave text blips). `jingle` replaces the
  song until it ends (`MUS_FORCED`); `sfx` takes over voice A, B or (noise effects: sword, boomerang, flame,
  stairs, bomb blast, ripped from the Effect channel `$603`) voice C for its length and hands the voice
  back. `music_update` also repeats the low-life beep (`SFX_HEART_WARNING`, 6 frames of beep + the
  original's pause) while `HP_HALVES` is 1-2. Track ids are in the generated `music_ids.inc`. Not hooked
  yet: title/ending/Ganon/Zelda/game-over songs, recorder, parry and magic (no game events for them yet),
  the sea ambience, and the DPCM samples (never ripped). The streams are for 50 Hz; at
  60 Hz (`$FF820A` bit 1 clear) every 6th VBL holds them (`MUS_SKIP`).
- **B item** (`B_ITEM`): 0 nothing, 1 bombs, 2 boomerang, 3 candle; `b_item_fix` keeps it on
  something owned. **Inventory screen** lists owned B items (bombs if count > 0); Left/Right
  moves the "B" label. The bow (`INV_BOW`, item `$0A` from the cellar) is only shown there: it is not a B item until arrows exist. Opening it freezes everything.
- **Debug key K**: +1 key, +4 bombs (cap 8), candle. The owner wants it kept for now.

## 11. Asset pipeline facts

- `bins.xml` offsets are relative to the **start of PRG ROM** (16 + trainer bytes), not
  after PRG: the game uses CHR-RAM. `*.dat` files are cut out of the ROM by the build.
- **Sprite pattern table in the underworld** (`actors._sprite_table`): common sprite block
  tiles `$00-$6F`; **tiles `$70-$8D` are never loaded by the level code - they are what the
  title demo left in CHR RAM** (first `$1E0` bytes of `DemoSpritePatterns.dat` at `$0700`)
  - sword sideways `$82`, bomb clouds `$70/$72/$74`, etc.; `PatternBlockUWSP` at `$8E`,
  per-level block at `$9E`, boss block at `$C0`. Odd tile numbers select the second pattern
  table (misc tiles); 8x16 sprite = tile `n&$FE` and `+1`.
- Item drawing (`Anim_WriteSpecificItemSprites`): tile `$F3` or `$20..$61` = narrow (8 wide,
  centred), `$62..$6B` slim, `<$7C` mirrored pair, else left+right tiles.
- Overworld formats (columns, squares, palettes) are in the memory notes below / `build_assets.py`
  docstrings: `AttrsD & $7F` is the unique room id, bit 7 selects the monster list; column
  heaps `ColumnHeapOW0..9,A..F` are contiguous; `ColumnDirectoryOW` has 16 LE addresses.
- Underworld: `LevelBlockUW1Q1.dat` 6 tables x 128 (A,B = doors/palettes, C = monster list +
  count class, D = layout id & `$3F`, E = item & `$1F`, F = secret/position). Monster list id =
  `(C & $3F) | ($40 if D & $80)`; `foe_counts` give the group size; item position index =
  `(F & $30) >> 4`.
- Mon table (`mon_table.bin`, 8 bytes/monster): nes type, hp, period, damage, drop row, flies,
  draw mode, behaviour. Monsters ported: `06` goriya, `15` gel, `1B` keese, `28` rope, `2A`
  stalfos, `27` wallmaster, `3D` Aquamentus, `49` trap. Draw modes in `actors.py`
  (`MODE_*`), behaviours `BEH_*` in `ai.s` (keep both in step).
- Tests parse and recompute these tables, so changing a table size usually needs the test
  updated (e.g. `proj_sprites` is 27 frames, `fx_sprites` 20, `beam_sprites` 16, `sword_sprites` 4).

## 12. How to add things (recipes)

- **New monster**: add its NES type to `MONSTER_TYPES`, `MONSTER_PERIOD/DAMAGE/DRAW`,
  optionally `MONSTER_BEHAVIOUR` (+ a `BEH_*` equate in `ai.s` and a dispatch in
  `update_enemies`), and a draw mode if needed; the room records pick it up automatically.
  Update `test_actors.py` expectations. Check the `table_anchor` reach after.
- **New floor item**: add the id to `ITEM_IDS` and handle it in `take_item` (combat.s).
- **New B item**: add a `B_*` code, a `b_item_owned` case, a `b_item_input` dispatch, a HUD icon
  id in `HUD_ITEM_IDS` (same index as the code) and a menu entry in `menu.s`.
- **New sound event**: call `sfx SFX_NAME` (an effect over voice A, B or C, ids in the generated
  `build/generated/music_ids.inc`, names in `tools/music_pack.py` `TRACK_LIST`) or `jingle MUS_NAME` (an event song
  that replaces the area music until it ends) at the place in the 68000 code where it happens; both macros
  keep every register. A new track: add it to `TRACK_LIST` and `nes_music_rip.py` `TRACKS`, and bump nothing
  else (the bank, ids and tests follow). `gvar` values must stay plain numbers (the screenshot harness
  parses them), so write `gvar NAME, 96`, not `gvar NAME, (3 * X)`.
- **New variable**: `gvar` at the **end** of `globals.s` (never insert in the middle of the
  front arrays); `OFF_NAME` is then available; add it to the harness report if useful.
- **New asset table**: field in `ActorData`, writer in `build_assets.py`, entry in the Makefile
  `GENERATED` list, `.incbin` in `main.s` after the anchor, placeholder in `build_placeholder`.

## 13. Lessons learned / pitfalls

- Rebuilds with a dev env leave a dungeon start baked in (section 4).
- Hatari at 60 Hz: use the VBL-latch logic in `present_frame`/`wait_vbl`; don't change it casually.
- The ST has a 16x16 shift blitter at run time; keep sprite counts modest per frame.
- Tab/menu: drawing straight to the visible screen is fine because nothing else runs.
- `replace`-style edits in a big `.s` file: the numeric local labels (`1:`, `2:`...) are reused
  per routine, so check the nearest following definition when you add a branch.
- A previous crash class: a `dbra` loop whose counter register is also used by a called routine
  that does not save it. Check callee save lists.
- When the user asks "check internet and source": the disassembly in `src/` was sufficient every
  time so far; read it first.

## 14. Status and what is next

Done in Level 1: overworld + first cave, doors/keys/shutters/bombable and false walls, stairs +
cellar, stalfos/keese/gel/rope/goriya/wallmaster/Aquamentus/blade traps, sword + beam + bombs +
boomerang + candle, drops with kill counters, knock-back and invincibility, push block, triforce
ending, map and compass with the dungeon minimap, the old man in room `$41`, HUD with A/B boxes, Tab inventory screen, YM2149 music and sound effects.

Open items (user-visible gaps): the other dungeon people (more bombs, life or money, fireballs from the old man's flames); the overworld map on the
ribbon; fireball art
(placeholder); the clock and fairy drops; stairs-type push block (trigger 5, not in Level 1);
visible block slide animation; the rest of the sound (title, ending, game-over and boss music, DPCM); then the rest of the overworld (real monsters,
shops, caves, secrets), inventory items (bow/arrows, recorder, ladder, raft, rings, ...), other
eight dungeons, title/game-over/save.

The full plan for everything still missing (hidden bomb/fire spots, enemies, caves, items, all nine
dungeons and bosses, title/save) is `atari_st/PLAN.md`. Scope decision: First Quest only, the Second
Quest is deferred. Its tables are decoded from a user-supplied ROM; do not commit the ROM.

## 15. Persistent notes also kept in the repo memory (VS Code agent memory)

`/memories/repo/*.md` in the VS Code workspace store: build notes, references, the underworld port
notes and the overworld format notes. Their durable content is mirrored in this file.
