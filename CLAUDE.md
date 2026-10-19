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

Current scope: the whole overworld is walkable (128 screens) with its monsters,
the first cave and the wooden sword, **Level 1 (the Eagle)** is playable to the
boss Aquamentus and the triforce piece, and **Level 2 (the Moon)** to the Dodongo,
its heart container and the triforce piece. **Levels 3 to 9** are built too (rooms,
layouts, items, every monster and boss of those levels, up to Ganon and Zelda's thanks) but only partly play-tested.
Every item of the original's inventory is in the code. Everything else (
the title and save) is future work, see section 14 and
`atari_st/PLAN.md`.

The repository root also contains the original disassembly the port is built on
(`src/Z_00.asm` .. `Z_07.asm`, aldonunez's labelled NES disassembly). It is the
**reference for every behaviour**: when you need a number (speed, timer,
damage, tile id, table), read it from there rather than guessing.

## 1.1 Versions

The port has versions `0.NN` (current: **0.33**, file `VERSION`), one per milestone, with a line in `CHANGELOG.md` and a git tag on
the commit that finishes it. A big change (a dungeon, a mechanic family, a package of `atari_st/PLAN.md`) takes the next number; fixes
and docs ride along. When you finish one: bump `VERSION`, the "Version" line of `README.md`, the status line of `atari_st/PLAN.md`
and add the `CHANGELOG.md` entry, in the same PR; tag it after the merge. The next step is named in `atari_st/PLAN.md` section 2.1.

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
ext/Original.nes         your ROM (gitignored), 131088 bytes; built and tested with The Legend of Zelda (Europe) (Rev 1)
atari_st/                the port
  Makefile               build: assets -> as -> ld -> objcopy -> PRG
  link.ld                linker script: .text, .data, then .rodata, single flat section
  README.md              user-facing docs: features, known gaps, roadmap, notes
  src/*.s                68000 code (one assembly unit, main.s .includes the rest)
  tools/*.py             asset pipeline, PRG packer, Hatari screenshot harness
  tests/*.py             unittest suites (142 tests); tests/golden/frames.json = golden frame hashes
  music/                 the YM2149 digidrum player (ymplay.h); the songs are ripped from the ROM
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
| `enemy.s` | monster spawn (overworld monsters come out of a spawn cloud: `cloud_begin`/`cloud_tick`; screens with edge spawns use `edge_spawn_tick`), walker AI (16-px lanes), shove, draw, `sprite_offset`, `rand8` |
| `dmon.s` | the dungeon monsters of Levels 3-8 (darknuts, gibdo, zol, vire, pols voice, like-like, bubbles, wizzrobes), `mon_mask` (which weapons hurt what), `STEP_PATTERNS`, and the `farstub` trampoline macro + list |
| `bosses.s` | Manhandla, Gohma, Digdogger, Gleeok, Lanmola, Patra, Ganon, Zelda and her fires (included last; its `*_bf` stubs reach back into main.s), the boss sprite pool (`bp_add`, `boss_pool_draw`), pre-shifted narrow art (`draw_pre`), the baked Gleeok body, rupee stashes and Grumble (`boss_room_init`, `stash_bake`, `grumble_bake`, `boss_misc_update`) |
| `ai.s` | per-monster behaviours (rope, goriya incl. the blue one, wallmaster, Aquamentus, keese, blade trap, **Dodongo, Moldorm**), projectile system, **Link's boomerang** |
| `movers.s` | the overworld monsters with rules of their own: tektites and boulders (jumps), leevers and zoras (burrowing), peahats, ghinis, the boulder set |
| `items.s` | the B items beyond bombs/boomerang/candle (bow and arrows, rod, recorder, food, potion), Link's shots, heart fill, the `b_*` tables |
| `secrets.s` | the overworld's hidden spots: `ow_bomb_secret_far`/`ow_fire_secret_far` hooks (bomb cloud, flame), `ow_push_secret` (Link blocked by a rock or gravestone), `ow_secret_undo` (called by `render_room`), patching `room_maps` in place |
| `owspec.s` | the overworld's special objects (M4): Lost Woods/Hills mazes, ladder, raft and docks, armos, the recorder's whirlwind and pond, fairy ponds; its `owspec_*_far` stubs sit in `main.s` |
| `combat.s` | sword, beam, bombs, candle, drops/kill counters, `take_item`, HP/knock-back, rings, shield, clock, effects (spark/cloud), push block, shutters, triforce ending, the ringleader trigger |
| `hud.s` | status ribbon, hearts, counters, A/B boxes (`hud_items`) |
| `menu.s` | Tab inventory screen (MODE_MENU): 2x4 grid of B items plus a row of carried items |
| `uw.s` | underworld rooms, doors, stairs/cellar, level entry/exit, `uw_select_level`, `debug_keys` (K) |
| `input.s` | IKBD interrupt handler (`ikbd_isr`) + parser (`poll_keyboard`): scancodes, joystick, mouse skip |
| `music.s` | music and sound effects replayed from the VBL hook: four register-stream contexts (song, effect over voice A, effect over voice B, noise effect over voice C) read from one bank, merged and written to the PSG (+ digidrum engine in `.data`) |

`atari_st/tools`:

| file | role |
| --- | --- |
| `build_assets.py` | ROM -> ST data: tiles, rooms, palette, HUD glyphs, caves, writes `build/generated/*.bin` and `assets.inc`; stops without the ROM (no stand-in art); `--verify-only` |
| `underworld.py` | Level tile rooms (LayOutRoom port), doors, cellars, reachable rooms |
| `actors.py` | monsters, items, drops, sprites (sword, beam, effects, boomerang, HUD icons), per-room records |
| `make_prg.py` | wraps the flat binary into a TOS PRG header (`--check` validates) |
| `screenshot.py` | **headless Hatari harness**: runs the PRG, injects keys, pokes variables, dumps RAM, decodes framebuffer to PNG, prints a state report and a `FRAMEHASH`; `--room`, `--uw`/`--level` build a dev PRG into `build/dev` |
| `golden.py` | golden frames: runs twenty fixed scenes through `screenshot.py` and compares `FRAMEHASH` with `tests/golden/frames.json` (`--update`, `--only`, `--png-dir`); skipped without Hatari, `TOS` and the ROM; `make golden-update` |
| `dump_tables.py` | dumps the ROM tables the port is built from (overworld screens, all nine dungeons' rooms, monster lists) as `build/dump/tables.json` and `tables.md`; checks the ROM |
| `check_reach.py` | run after every link: fails the build if an `ltab` symbol is missing or a branch or PC-relative operand does not fit 16 bits (reads `build/zelda_st.lst`) |
| `dev_run.sh` | build with a start room + capture (needs `$TOS`) |
| `compare_render.py`, `render_map.py` | diff the renderer against a Python render; render maps |
| `ym_convert.py` | converts the player header into `music_engine.bin` (the digidrum engine) |
| `music_pack.py` | packs every track ripped from the ROM (via `nes_music_rip.py`) into `music_bank.bin`, one shared `music_drum_table.bin` and `music_ids.inc`. Without the ROM or `py65` the bank is empty and the game silent |
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
- **Linux / cloud sessions** (Claude Code on the web) build and test the same way with plain `make` and `python3`:
  `binutils-m68k-linux-gnu` (binutils 2.42), Hatari 2.4.1 and `etos512us.img` (EmuTOS 1.4, 60 Hz) as `TOS`. With EmuTOS the
  game starts running at about VBL 170 (`FRAME_COUNTER` is about N-170); with TOS 1.04 it is about 700. `gh` talks REST only
  (`gh api repos/.../pulls`): GraphQL is blocked there. Everything needs `ext/Original.nes`; without it the build stops (there is no stand-in art)
  and the golden frames skip.

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
installing or removing it rebuilds the bank. Without ROM or `py65` the bank is empty and the game silent.

Makefile variables: `TOOLCHAIN_PREFIX` (default `m68k-linux-gnu-`), `PYTHON`
(`python3`). Environment for the tools: `TOS` (path to a TOS image, needed by the
screenshot harness), `HATARI` (binary, default `hatari`), and the **dev-start
variables** below.

Nothing in the port is drawn, written or composed separately from the ROM (the credits page for the port is the one text
of its own): a build without `ext/Original.nes` stops with a message, and `build/generated/asset_manifest.txt` says
`source=ROM-derived ...`. Do not add stand-in art for anything that is not available: read it from the ROM.

### Dev start variables (BAKED INTO THE BUILD - important)

- `ZELDA_START_UW=0x74` starts inside a dungeon in room `$74`, with the sword
  (Link at X `$78`, Y `$8D`); `ZELDA_START_LEVEL=2` picks the dungeon (default 1).
- `ZELDA_START_ROOM=0x37` starts in another overworld room.
- They write `DEV_START_UW`/`DEV_START_LEVEL`/`DEV_START_ENTRANCE`/`START_ROOM_ID` into `build/generated/assets.inc`
  (`DEV_START_ENTRANCE` is the overworld screen of that level's stairs, where leaving comes out).
- `screenshot.py --room 0x3c` / `--uw 0x0e --level 2` do this for you into `build/dev`, leaving `build/` alone.
  The Makefile tracks both variables in `build/dev_start.stamp`, so changing them
  (including unsetting them) regenerates the assets on the next `make`; no `touch`
  is needed. Any change to `actors.py`, `underworld.py`, etc. regenerates assets
  too, using **whatever env is set then**.
- **Finish with a default build**: `unset ZELDA_START_UW ZELDA_START_ROOM ZELDA_START_LEVEL; make all`.
  To confirm, `grep -E 'DEV_START_UW|START_ROOM_ID' build/generated/assets.inc`
  should show `START_ROOM_ID, 0x77` and `DEV_START_UW, 255`; otherwise the owner's
  PRG starts in a dungeon.

## 5. Testing

### Unit tests
`atari_st/tests/` (`test_build_assets.py`, `test_actors.py`, `test_ym_convert.py`,
`test_nes_music_rip.py` (needs `py65` for the ROM part, `ZELDA_ROM` or `ext/Original.nes`),
`test_dump_tables.py` (the table dump, and that every golden scene has a stored hash),
`test_music_player.py` (the packer, and `music.s` run on `machine68k` through `tests/music_harness.s`; needs the m68k binutils and `pip install machine68k`, the real-bank part also the ROM and `py65`),
...). Run `python -m unittest discover -s atari_st\tests` (142 tests at the time of
writing). They cover the asset pipeline and tables; the 68000 music player is the one piece of
68000 code with unit tests. `test_actors.py` also holds the Makefile-vs-`build_assets.UW_LEVELS` check and the
reach-check listing parser.

### Golden frames (`tools/golden.py`, `tests/golden/frames.json`)
Thirty-two fixed scenes (overworld start, the Level 2 entrance, Level 1 start and Aquamentus, Level 2 start, Dodongo,
Moldorm, traps, goriyas, old man, and Levels 3-8: a crowded room, a dark room, a rupee stash, Grumble, a dark crowd; Level 9: a Lanmola room, a Patra room, Ganon's room, Zelda's room and Zelda's thanks) are run through `screenshot.py` (dev builds in `build/dev` via `--room`/`--uw`/`--level`) and
the `FRAMEHASH` (SHA-256 of pixel indices plus palette) is compared with the stored one. **Hashes, not images**: the frames are
Nintendo's artwork, so the tests keep no images. (Screenshots are not kept in the repository; the owner has a zip of the early ones.) Runs are deterministic. After a change that moves pixels on purpose: look at
`build/golden/<scene>.png`, then `make golden-update` and commit `frames.json`. `make check` runs it and skips quietly without
Hatari, `TOS` or the ROM. A scene that needs different input uses `--keys` in its `SCENES` entry. **Scenes where monsters move at random
(`uw2_goriyas`, `uw4_dark`) depend on how long the PRG takes to load**: the harness captures at an absolute VBL, so a PRG of another size
shows another frame of the walk. After a change that only moves the code, expect those two to change and re-record them.

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

- `--vbls N`: capture at VBL N. The game only starts running after the OS has booted:
  roughly **700 VBLs** with TOS 1.04, about **170** with EmuTOS; use `--vbls` beyond that.
  `FRAME_COUNTER` in the report is the game's own frame count (about N-610 with TOS 1.04, N-170 with EmuTOS).
- `--room 0x3c`, `--uw 0x0e --level 2`: build a dev PRG for that start into `build/dev` and run it.
- The report ends with `FRAMEHASH`, and the run prints a warning on a bus/address error; a **Line-F or other
  exception** shows in the log as a second copy of the variable block at RAM `$3D6` (EmuTOS saves the stack there) and
  as the harness refusing "the globals marker more than once". That is what a wrapped 16-bit branch looks like (section 6).
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
- Each run is a fresh emulation. With the same input, EmuTOS and the same build the runs have been
  deterministic (identical hashes), but do not compare positions across builds or different key schedules
  as one trajectory.
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
- **50 Hz test**: pass EmuTOS German (`etos512de.img`) as `TOS`; the report then shows `SYNC_MODE=0xfe (50 Hz)`. The US images give
  `0xfc` (60 Hz). Compare `FRAME_COUNTER` at two `--vbls` (it must advance one per VBL) and count `reg=0x0` writes with `--trace psg_write`
  (one per music tick: 600 of 600 VBLs at 50 Hz, 500 at 60 Hz). The report also prints a `PALETTE` line with the 16 colours on show.
- Hatari quirks: `--memsize 4` with TOS 1.04 bus-errors during TOS's own RAM test
  (use `--memsize 1`); Hatari here runs at **60 Hz** (133,600 cycles per frame).

## 6. Memory map, registers and conventions of the 68000 code

- `a5` = the variable block (`globals`), offsets `OFF_<NAME>` generated by the
  `gvar NAME, size` macro in `globals.s` (longs first, `galign` before long
  arrays; the harness parses the same file). `a6` = `table_anchor`, **reserved for
  the whole run**; read-only tables are reached with the **`ltab sym, %aN`** macro
  (`lea sym - table_anchor(%a6), %aN`). Nothing else may use `a6`.
- **Tables**: `ltab sym, %aN` is `move.l #(sym - table_anchor), %aN` + `adda.l %a6, %aN` (flags untouched): a 32-bit
  distance, so tables may sit anywhere in the image and in any order. `table_anchor` sits just before `fx_sprites`.
  `tools/check_reach.py` fails the build when a symbol named in an `ltab` is missing. The tables of each dungeon are
  reached through pointers instead: `uw_select_level` (d0.b = level 1..`LEVEL_COUNT`) copies the eight table
  distances of a 40-byte `level_table` record (`levels.inc`, generated) into `OFF_UWP_*` and the start data into
  `OFF_UWL_BYTES`; code loads them with **`lvtab NAME, %aN`** (`lvtab ROOMS, %a2`). The tables are
  `room_index rooms doors tiles tile_nes room_info cellar_maps cellar_info`, built per level as `uw<N>_<table>.bin`
  (`UW_LEVELS` in the Makefile and in `build_assets.py`; a test keeps them equal). `room_palette` must stay the first
  `.rodata` table (the reach check uses it as the end of the code). `init_anchor` and `init_pointers` sit mid-code.
- **Code is the limit.** A `bsr`/`bra`/`Bcc` and an operand `(label,%pc)` span a signed 16 bits. **GNU as does not
  report overflow, not even for an explicit `.w`: it wraps the displacement** (binutils 2.42 `-m68000`), so the program
  jumps into the wrong place; ld says nothing either. Level 2 hit it: `bsr draw_hud`, `bsr update_menu` and
  `bsr minimap_tick` in `main.s` were 32,786 to 32,972 bytes from their targets and the game died with a Line-F
  exception at start (the symptom in the harness: see section 5). `check_reach.py` now reads the assembler listing
  (`build/zelda_st.lst`, `as -al`), computes each branch and PC-relative distance against the linked symbols, and fails
  the build on any that does not fit; it prints the tightest three (315 bytes to spare after Level 9, 479 after Levels 3-8, 86 after Level 2, so
  **expect it to fail as soon as you add code**). Fix: route the call through a `*_far` stub (`bra target`) placed in
  the middle of the image in `main.s` before `.include "link.s"` (`clear_erase_state_far`, `show_background_far`,
  `draw_hud_far`, `update_menu_far`, `minimap_tick_far`), and call the stub. Data that nothing branches into
  (tables, text, sprite banks) goes after `room_palette` in `.rodata` and costs nothing.
- **Image layout** (`link.ld`): `_start` (a `bra.w`), then `.data` (stack, `globals`, `music_old_vbl`, `ikbd_state`,
  `ymdrum_code`), then the code (`.text`, `.text.late`), then `.rodata`. Code reaches `.data` by PC-relative
  displacement, so the modules that do (`input.s`, `music.s`, `video.s`, `_start`) are included first in `main.s`.
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
`fx_sprites`): slots 0-3 spark corners, 4-7 bomb cloud, 8 candle flame; 36 slots in all, 12.. are the boss pool's
(`bp_add` pieces, drawn by `boss_pool_draw` after `draw_effects`).
Scrolls, caves and the menu bypass double buffering (`dbl_end` / `dbl_enter`).

`update_play` order: erase everything -> `menu_check_open` -> `sword_input` ->
`b_item_input` -> `link_update` -> `uw_person_update` -> `items_update` (potion, recorder, food,
Link's shots' bookkeeping) -> `boss_misc_update` (rupee stash, Grumble) -> `chase_target_update` -> `update_enemies` -> `update_combat` (sword
hits, beam, enemy contact, item pickup, beam/fire/block/bomb ticks incl. the Dodongo's bomb check,
room clear) -> `update_projectiles` -> draw items, bomb, enemies, projectiles, Link (blinks when
hurt), beam, effects, `boss_draw` (Gleeok, boss pool), sword -> `present_frame`.

Frame budget at 8 MHz: ~133,600 cycles (60 Hz) - the sprite blitter shifts at run
time (no pre-shifted copies; only the bosses' narrow pieces are pre-shifted). A sprite costs
~8k cycles to draw and ~1.7k to erase, so a room of seven or more monsters needs two VBLs. `catch_up`
(`main.s`, called after `FRAME_COUNTER` is incremented) sees from `FR_CLOCK` (`$462`) that two VBLs passed and runs
`update_play` once more with `SKIP_DRAW` set (no erase, no draw, no present, boss pool cleared), so the game speed
stays that of 60 Hz and only the picture runs at 30 Hz; at most one extra pass, never during scrolls or menus.
`LATE_FRAMES` counts the passes (the harness prints it); `FRAME_COUNTER` ~ VBLs - 170 means the loop kept up.

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
- **Palette per mode**: `room_palette` is the overworld's; `level_palettes` holds nine more (one per dungeon, 32 bytes each). A
  dungeon keeps every overworld colour in its slot and swaps in the 1-3 colours the overworld lacks (Levels 3-9), because Link,
  items, effects, the HUD, the cellar walls and the minimap (slots named in `hud.s`, `underworld.PROTECTED_SLOTS`) are baked once
  by slot number. `underworld.palette_lookup` builds a level's table; `palette_sync` (video.s, each frame) loads the one for
  `OFF_LEVEL`; code that restores the colours after a flash calls `cur_palette` (a0 = current table). A level's monsters must be
  baked with the level's own rows when its dungeon is added.
- Sprites: 16x16, 4 planes + 1 mask word, **160 bytes** (`SPRITE_FRAME_BYTES`). Narrow
  NES items (8 wide) are centred in the 16 px frame. `draw_sprite` (a0 frame, a1
  dest, d0 shift), `erase_at` restores from `BG_CUR` (the clean room).
- HUD glyphs are 8x8 (`draw_hud_tile`, byte stores, no shifting); `text_glyphs`
  maps NES text codes (digits 0-9, A-Z = `$0A`-`$23`, space `$24`, `.`=`$2C`,
  `-`=`$2F`) to glyphs; `menu_text` converts ASCII.
- `hud_items.bin`: icons for A/B boxes, 2 tiles each, in the order of `actors.HUD_ITEM_IDS` (sword, bomb, boomerang,
  candle, compass, map, bow, recorder, food, blue and red potion, rod, magic boomerang, red candle, white and magical
  sword, arrows, raft, book, rings, ladder, magic key, bracelet, magic shield, letter); `b_icons` in `items.s` maps a
  B code to its icon.

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
- **Spawning (overworld)**: a screen places its monsters on `SpawnPosList` squares for Link's direction (not within `$22` of him) when the scroll
  ends, each in the ROM's spawn cloud (`InitObject` metastate 1): the cloud lasts the slot number in frames (an octorok `(slot + 1) * $10`) and then
  six frames for each of its second and third pictures (bomb item frames `$70`, `$72`, `$74`; `fx_sprites` 0, 1 and 20). Meanwhile the monster has
  `ENEMY_ACTIVE` 0 and its `ENEMY_CLOUD` is 1-3, so nothing moves, hits or draws it. `mon_cloud.bin` (per monster: 0 none, 1 short, 2 long) is
  derived from the ROM by `actors.rom_spawn_clouds` (initialisers that end in `ResetObjMetastate` have none). Screens whose attribute F has bit 3
  set (20 of them around the start) place nothing: monsters come in one by one at a square of a counter-clockwise ring, with no cloud, and not
  closer to Link than `EDGE_SAFE_DIST`. The ROM waits 0 / 20-50 frames and keeps only `$22` away; the `EDGE_*` equates in `main.s` are a gentler
  version the owner asked for. The dungeons' monsters still appear at once.
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
  rupees), 16th kill = fairy; `WorldKillCycle` advances **before** the
  lookup; table rows per monster group, rates `DropItemRates`; being hurt resets the
  counters. Drops live `$FF` counts every 2nd frame, flicker and can't be taken for 30
  frames. Bomb pickup +4 (cap 8).
- **Boomerang** (`UpdateArrowOrBoomerang`, `WieldBoomerang`): placed 16 px ahead, 3 px/frame
  for 49 px (limit `$31`) or until blocked, 3-frame spark, slow phase (1 px/frame, `$10`
  frames), then returns to Link (a wall only stops it while flying out: in the slow phase it stays put and the phase still runs out); one at a time; stun `ObjStunTimer` `$10` = 160 frames;
  kills monsters with HP 0 (gel, keese); picks up items; traps/boss ignore it. Art:
  item slot `$1D` tiles `$36,$38,$3A` + spark `$3C`, spin cycle `{0,1,2,1,0,1,2,1}` with
  flips. Stunned monsters do nothing and do no contact damage (`ENEMY_STUN`).
- **Holding an item up** (`TakeItem` with `ItemLiftTimer`, `lift_begin` / `lift_update` in combat.s, `LIFT_TIMER`): the wooden sword, the
  boomerang, the bow and the candle play the item fanfare (`MUS_ITEM`), then Link stands arms-up for `LIFT_FRAMES` (128, the original's `$80`)
  with the item 16 px over his head (an `ITEM_LIFTED` slot, drawn by `draw_items`; `draw_link` shows the arms-up picture). `LINK_HELD` freezes
  him, `update_enemies` and the cave walking are skipped while it runs. The original only lifts outside walking mode (caves, cellars); the
  boomerang found in a room is lifted here on purpose, at the owner's request.
- **Candle**: blue candle, fire 16 px ahead, creeps 16 px at half a pixel/frame, stands 63
  frames, burns monsters within 14 px (1 hit), once per room (`CANDLE_USED`); the red candle has no limit.
- **Blade traps** (`InitTrap_Full`, `UpdateTrap_Full`): Level 1 room `$22`, Level 2 room `$3F` (with four keese). Type `$4A` = 4
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
- **Overworld hidden spots** (`secrets.s`, ROM `UpdateRockWall`/`UpdateTree`/`UpdateRockOrGravestone`, `CheckTileObject`): the layouts hide
  six marker squares (38-43, primaries `$E5-$EA`); `build_assets.decode_overworld` draws them as the squares the ROM swaps in (19, 27, 25,
  20, 44, 44) and writes `room_secrets.bin`, one 8-byte record per screen (type, the spot's square `row*16+col`, what it becomes, the stairs'
  square and metatile, the rock's metatile one square above and below). Quest-2-only spots (attr F >> 6 = 2) get no record. Finding one
  patches `room_maps` in RAM (the PRG is RAM-resident) and redraws with `render_room` + `show_background`, so `fetch_tile` and `check_warps`
  see the new tile. The room flags are `OW_KILLS` (bit 7 secret found, bit 5 rock pushed; the low three bits stay the kill count). A
  pushed rock or gravestone is undone by `ow_secret_undo` when `render_room` next draws (the ROM lays a screen out afresh on every
  entry); the stairs under a rock are permanent, those under a gravestone are not (`CheckShortcut`). The triggers: bomb cloud open
  (`bomb_tick`, within 16 px), flame on its last frame (`fire_update`, timer 1), Link blocked going up or down (`link_pixel`). The spot's
  Y is `row*16+$40`. The module sits after `uw.s` and the near modules reach it through four stubs in `main.s`: anything put between
  `.text+$88c` and `uw_person_update` eats the 16-bit reach budget of `bsr uw_person_update` (185 bytes left).
- **Secret triggers** (`LevelBlock` attr F & 7): 1 kill all -> open shutters, 4 push block,
  7 kill all -> item appears; others in `Z_05.asm` (`CheckSecretTrigger`).
- **Level 1 rooms** (reachable from `$73`): `$22` traps, `$23` goriya+key, `$33` stalfos+key,
  `$35` Aquamentus + heart container, `$36` triforce, `$41` old man (`$4C` person, see
  **Dungeon people**), `$42` gels + push block, `$43` map room, `$44` goriyas + **boomerang**, `$45`
  wallmasters, `$52` keese, `$53` stalfos, `$54` keese + compass, `$63`, `$72` keese,
  `$73` start, `$74` stalfos; cellar `$7F` (bow, 4 keese).
- **Level 2 rooms** (18, from `$7D`; `tools/dump_tables.py` lists any level): `$7D` start, `$0D` triforce (reached through `$0E`),
  `$0E` **Dodongo** + heart container, `$1E` 5 red goriyas, `$1F` old man ("DODONGO DISLIKES SMOKE."), `$2E` ropes, `$2F` gels + 5 rupees,
  `$3E` **Moldorm** + key, `$3F` 4 traps + 4 keese, `$4E` ropes + key, `$4F` 3 **blue goriyas** + magic boomerang, `$5E` red goriyas
  with a **ringleader** (trigger 2), `$5F` gels + map, `$6C`/`$6D`/`$6E`/`$7E` ropes (+ keys), `$6F` gels + compass. Entered from overworld
  `$3C` (`uw_enter_level` stores that screen in `CAVE_SOURCE_ROOM`; the dev start uses `DEV_START_ENTRANCE`).
- **Levels 3-8** (built by the same pipeline; `UW_LEVELS := 1 2 3 4 5 6 7 8`, entered from the overworld by the level number
  in `room_attr_b`; the dev start takes `ZELDA_START_LEVEL`). Room record (16 bytes): 0 monster count, 1 trigger (bits 0-2
  trigger, bit 5 Grumble, bit 6 rupee stash, bit 7 push block), 2 item, 3/4 item X/Y, 5 unsupported monsters (bit 7: the room
  is dark), 6-13 monsters, 14-15 person text offset. Dark rooms (`ROOM_DARK`, `uw_dark_fill`) show nothing but Link, monsters
  and effects until the candle is used (`uw_light_room`, `ROOM_LIT`). Rupee stash: `stash_bake` paints the rupees into the room
  and `boss_misc_update` collects them (`UW_FLAGS` bit 2). Grumble (`GRUMBLE_ON`): blocks the doorway tile until fed (food
  on his tile), then `UW_FLAGS` bit 1. Gleeok's body is baked into the room (`uw_bake_boss`, `GLEEOK_GONE` after death);
  necks and heads come from the boss pool, one segment per neck when there are four necks (`GLEEOK_SEGS`). The "more bombs" and "life or money" men are
  ported (see Dungeon people below). Checked in Hatari with scripted input (`--keys`, monsters poked in front of Link's sword):
  the second Digdogger (recorder, one little one, its death, the heart container and taking it), the stash gone for good after
  leaving and coming back, Pols Voice and Vire moving. Not checked: the first Digdogger's three little ones, a Vire dying into keese,
  scrolling between dark rooms (the maze-like rooms need the ladder or bombs to leave from the start spot).
  **Keys and moats**: a locked door (types 5, 6) opens with a key, and the magic key (`INV_MAGIC_KEY`) opens it without using one up
  (the HUD shows "XA" for it); Level 9 has 16 locked doors and 4 keys, it is the magic key's level (`test_every_room...` in
  `test_build_assets.py` replays the doors of all levels). The moat (NES tile `$F4`) is crossed with the ladder: with it Link
  walks over `UW_MOAT_TILE` (the ladder itself is not drawn). Moat rooms that cut doors off from each other: Level 4 `$01 $21 $30`,
  5 `$46 $66`, 6 `$19 $1A`, 7 `$18 $49 $5A`, 9 `$23 $40 $56 $65`.
- **Level 9** (`UW_LEVELS := 1 2 3 4 5 6 7 8 9`; the monsters live in `bosses.s`, the dungeon people and the door man in `uw.s`): 57 rooms,
  a ten-entry cellar array, the old men from person table C, and the man at the door (record trigger bit 4) who opens only
  with all eight triforce pieces. **Lanmola** (`$3A` blue, `$3B` red; `BEH_LANMOLA`): two worms of four segments that start at
  ($40,$8D) and uncoil as the head's headings go down the body; the head decides at every square. **Patra** (`$47`/`$48`, children
  `$25`/`$26`; `BEH_PATRA`, `BEH_PATRA_CHILD`): `_room_info` expands one eye into the eye plus seven children (`PATRA_CHILDREN`); the
  children come out one at a time and orbit it (`patra_cos`, `PATRA_MAN` flips the radii every $FF frames); the eye is proof
  until none is left (`patra_kids`), everything is hurt by the sword only. **Ganon** (`$3E`, `BEH_GANON`): `ganon_tick`, called by
  `boss_misc_update` because `LINK_HELD` skips `update_enemies`, runs the scene (`GANON_SCENE` 1 dark room, 2 the Triforce of
  Courage held up); he is drawn from the boss pool (`BP_GANON` frames, ten blue and ten brown pictures plus the ashes), hides,
  teleports (`ganon_relocate`) and throws fire; a sword blow turns him brown (`ganon_died` the first time), a silver arrow into a
  brown Ganon kills him (`ganon_filter`), he burns solid for `$50` frames, then the ash pile (it stays) and the **Triforce of Power** (item `$0E`, drawn from Level 9's
  sprite table) lies on it at `$A0`; the burst rays are not ported (trigger 7 hides the room item until then). **Zelda** (`$37`, `BEH_ZELDA`) comes with four
  guard fires (`$3F`, `BEH_FIRE`, killable, half a heart): `_room_info` expands the one Zelda into five monsters, `zelda_init` and
  `fire_init` put them at the ROM's places. `dmon_zelda` starts the scene when Link stands at X `$70`..`$80`, Y `$95`; `zelda_tick`
  (`ZELDA_SCENE` 1-8, run by `boss_misc_update`) plays the fanfare (`MUS_ZELDA`), the curtain (`curtain_column`), the thanks typed
  by `cave_talk` (the texts are appended to `cave_text.bin`, `ENDING_TEXT_THANKS`/`ENDING_TEXT_PEACE` in `assets.inc`), the two
  triforce pieces with the flashing backdrop (`MUS_ENDING` after it) and the closing words. Scenes 8-11 are the credits: `CREDIT_PAGES` (`build_assets.py`: three lines a page, the staff of the ROM's
  `CreditsTextLines`, then "ATARI ST PORT / BY Q", "YOU ARE GREAT", "END OF / THE LEGEND OF ZELDA") are typed one after the other by
  `cave_talk` in the black room (`zelda_credit_pages`, `ENDING_CREDIT_n`), `ZELDA_CREDIT_WAIT` frames apart, the last stays (Esc quits; the
  original's scrolling wall, the ash pile and the Second Quest restart are not ported).
  Silver Arrow and Red Ring are in cellars. `MUS_GANON` plays when Ganon appears and again when he burns. Not hooked: the boss roars. Checked in Hatari: Lanmola (all eight segments, room clears, item appears),
  Patra (the seven children, then the eye with one hit point left, room clears), the door man with all pieces (silent, shutters open)
  and without (his words), Ganon's and Zelda's scenes. Not checked: a human-speed fight with any of them.
- **Blue goriya** (`$05`): throws whenever its timer reaches 0, no `$23`/`$77` roll (`goriya_ai` reads the NES type from `mon_table`).
  **Ringleader** (`TRIGGER_RINGLEADER`, `uw_check_clear`): when slot 0 is dead, kill the others and open the shutters.
- **Dodongo** (`$32`, `BEH_DODONGO`, `MODE_DODONGO`; ROM `UpdateDodongo`): a wanderer (turn rate `$20`) whose X is shifted by `$10` when it
  does not face left (it is two sprites wide: `draw_dodongo`, second erase offsets `ENEMY_ERASE2_OFFSETS`). State 0 walks, 1 is
  bloated, 2 is stunned. It eats a ticking bomb that reaches its mouth (`dodongo_bomb_tick`, limits per direction) and dies after two; a
  bomb cloud in range stuns it for `$20` frames, the sword kills a stunned one (`dodongo_sword`) and it leaves a bomb; otherwise hits do
  nothing. Pictures `dodongo_images`/`dodongo_flips` (palette row 3, the bloated ones are mirror layout).
- **Moldorm** (`$41`, `BEH_MOLDORM`; ROM `Moldorm_*`, `Flyer_*`): the ROM has ten segments; **this port has two worms of four** (the engine has
  eight monster slots; `MOLDORM_SEGMENTS` in `ai.s` is per worm, `actors.MOLDORM_SEGMENTS = 8` in total, expanded in `_room_info`). The head
  (slot & 3 = 3) steers (`moldorm_steer`: chase or wander states 2/3, eight turns `$10` frames apart, then `Flyer_MoldormDecideState` rand >= `$40` =
  chase); every time its timer is re-armed to `$10` each segment below takes the old heading of the one above (`ENEMY_OLDDIR`); speed `$80`
  (half a pixel a frame, `ENEMY_SPEED/FRAC`); a wall bounce is kept in `ENEMY_BOUNCE` until the next turn. A killed segment comes back once with
  `$20` HP and the tail is removed instead; the head dies for good (`moldorm_died`). Drawn as tile `$44`, palette row 2.
- **Overworld movers** (`movers.s`): tektites and boulders jump (`UpdateTektiteOrBoulder`), leevers and zoras burrow
  (`ENEMY_GHOST`: bit 0 weapons pass through, bit 1 harms nobody), peahats fly, ghinis wander at rate `$FF`, the boulder set drops boulders.
- **Dungeon people** (`$4B..$52` in the room list; `actors.dungeon_people`): the speech is picked through
  `UnderworldPersonTextSelectorsA/B` (`Z_01.asm`, by level) and `PersonTextAddrs`, appended to `cave_text.bin` after the
  first cave's speech; the room record is 16 bytes and byte 14 is the speech offset (`$FF` = nobody). `uw_spawn` calls
  `uw_person_begin` (`uw.s`): `UW_PERSON` 1 while speaking (Link held, `cave_talk` types the text), 2 afterwards.
  `uw_bake_person` draws the man into the room buffers, `draw_effects` the two flames, `link_collide` blocks Link
  going up past Y `$8E`. Not ported: hitting him to make the flames shoot; the flame is the candle flame art.
  Two people do more than talk (room record byte 13 = `PERSON_KIND_BOMBS`/`PERSON_KIND_MONEY` in a room with no monsters, `UW_PERSON_KIND`):
  the "more bombs" man (`$4F`, but only in the levels whose people are table A, 5 and 7; Link must be level with him) sells +4
  `MAX_BOMBS` (a variable now, starts at 8, `combat.s` uses it) and a refill for 100 rupees; the "life or money" man (`$51`, the same
  words in every level, selector `$36`; no First Quest room has him) offers a heart container at X `$58` (it costs a container
  at four or more, and a heart) or 50 rupees at X `$98`. Taking either sets `UW_PERSON` 3 (a pause, then he and the flames go) and
  `UW_FLAG_PERSON` (`UW_FLAGS` bit 3), which `uw_bake_person` honours.
- **Items** (`items.s`, `take_item` in `combat.s`; ROM: `ItemIdToSlot`, `ItemIdToDescriptor`, the Items block): `globals.s` mirrors
  the ROM's item slots (`OFF_ITEMS + slot`, `INV_*` names); `take_item` is table driven (`item_slot`, `item_desc`, generated by
  `actors.py`: slot, grade or amount, cap). Item ids: `00` bomb, `01` wood sword, `02` white sword, `03` magic sword, `04` food,
  `05` recorder, `06` blue candle, `07` red candle, `08` arrow, `09` silver arrow, `0A` bow, `0B` magic key, `0C` raft, `0D` ladder,
  `0F` 5 rupees, `10` red potion, `11` book, `12` blue ring, `13` red ring, `14` bracelet, `15` letter, `16` compass, `17` map,
  `18` rupee, `19` key, `1A` heart container, `1B` triforce, `1C` magic shield, `1D` boomerang, `1E` magic boomerang, `1F` blue
  potion, `20` red potion, `21` clock, `22` heart, `23` fairy (`ITEM_COUNT` = `$24`).
  Swords have grades (white/magic = 2/4 times the wooden sword's damage, own swing art and A box). **B codes** (`B_*` in `items.s`):
  1 bombs, 2 boomerang (magic one too), 3 candle, 4 bow (needs the arrows too: `b_slots` says which slots each code needs),
  5 recorder, 6 food, 7 potion, 8 rod; `b_item_owned`, `b_item_fix` (keeps `B_ITEM` on something owned), `b_item_use` dispatch,
  `b_icons`. Link's own shots (`lshot_*`, projectile kinds `PK_L*`): arrows fly 3 px/frame, cost a rupee, hit for `$20` (silver `$40`),
  spark at the end; the rod's shot is slower (`$A0`) and becomes a flame at a wall with the book. Potion: `HEART_FILL` refills a
  half heart every 21 frames with Link held. Food: put down 16 px ahead, `CHASE_X/Y` (`ChaseTarget`) points the monsters
  that chase Link at it for `$FF` frames. Recorder: the tune and `FLUTE_TIMER`, then `owspec_recorder` (pond in `$42`, whirlwind elsewhere). **Rings** halve / quarter the
  damage (`HP_FRAC`, 128ths of a half heart) and recolour Link; the **magic shield** parries fireballs and sword shots; the
  **clock** (`INV_CLOCK`) freezes the monsters and makes Link untouchable until he leaves the screen; the fairy gives three hearts.
  The **Tab screen** (`menu.s`) shows a 2x4 grid of the B items plus a row of what is carried, table driven (Left/Right).
  Nothing in the game hands out most of these yet: the shops and caves are not ported (`debug_keys` K gives keys, bombs, the
  candle; the harness can poke any `INV_*`).
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
  yet: title/Ganon/game-over songs (the Zelda and ending songs play in Zelda's room), parry and magic,
  the sea ambience, and the DPCM samples (never ripped). The streams are for 50 Hz; at
  60 Hz (`$FF820A` bit 1 clear) every 6th VBL holds them (`MUS_SKIP`).
- **B item** (`B_ITEM`, codes in the **Items** bullet above): `b_item_fix` keeps it on something owned. The **inventory screen**
  lists the owned B items; Left/Right moves the "B" label. Opening it freezes everything.
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
- Underworld: `LevelBlockUW1Q1.dat` (levels 1-6; levels 7-9 use `LevelBlockUW2Q1.dat`), `LevelInfoUW<N>.dat` per level, 6 tables x 128 (A,B = doors/palettes, C = monster list +
  count class, D = layout id & `$3F`, E = item & `$1F`, F = secret/position). Monster list id =
  `(C & $3F) | ($40 if D & $80)`; `foe_counts` give the group size; item position index =
  `(F & $30) >> 4`.
- Mon table (`mon_table.bin`, 8 bytes/monster): nes type, hp, period, damage, drop row, flies,
  draw mode, behaviour. Monsters ported (`actors.MONSTER_TYPES`): `05`/`06` goriya (blue/red), `15` gel, `1B` keese, `28` rope, `2A`
  stalfos, `27` wallmaster, `3D` Aquamentus, `49` trap, `31`/`32` Dodongo, `41` Moldorm segment, and the overworld's `01`/`02` lynel,
  `03`/`04` moblin, `07`-`0A` octorok, tektites, leevers, zoras, peahats, ghinis, boulders (`movers.s`).
  **`MAX_ENEMIES` is 8**: the per-monster arrays are indexed `d8(%a5,%dn)` (they must start below offset 128) and some code
  uses stride-8 accesses between them (`8(%a0,%d5.w)` from `ENEMY_TURN` to `ENEMY_WANT`), so raising it is a refactor; a worm
  or a group of traps takes slots from the room's other monsters (`_room_info` truncates to eight). `mon_art.bin` gives, per monster, the first frame of its
  art in `mon_sprites` (octoroks have six images; `proj_sprites` ends with the rock and four arrows, `PF_ROCK`/`PF_ARROW`). `mon_sprites` is the last table, past the
  anchor's reach, found through the `MON_SPR` pointer set by `init_pointers`. The overworld
  has `ow_room_info.bin` (128 x 16 bytes: count, flags, monster indices from byte 6) that
  `spawn_from_record` in `enemy.s` shares with the underworld's `uw_room_info`. Draw modes in `actors.py`
  (`MODE_*`), behaviours `BEH_*` in `ai.s` (keep both in step).
- Tests parse and recompute these tables, so changing a table size usually needs the test
  updated (e.g. `proj_sprites` is 32 frames, `fx_sprites` 20, `beam_sprites` 16, `sword_sprites` 4).

## 12. How to add things (recipes)

- **New monster**: add its NES type to `MONSTER_TYPES`, `MONSTER_PERIOD/DAMAGE/DRAW`,
  optionally `MONSTER_BEHAVIOUR` (+ a `BEH_*` equate in `ai.s` and a dispatch in
  `update_enemies`), and a draw mode if needed; the room records pick it up automatically.
  Update `test_actors.py` expectations (and the monster counts / `mon_table` size). `make` runs the reach check: if it names a
  branch, add a `*_far` stub (section 6). A monster with two sprites needs a second erase offset (`ENEMY_ERASE2_OFFSETS`, as the
  Dodongo does); keep `BEH_*` in `ai.s` and `BEHAVIOUR_*` in `actors.py` in step (`test_actors` checks the numbers).
- **New floor item**: it is table driven: `ItemIdToSlot`/`ItemIdToDescriptor` come from the ROM into `item_slot`/`item_desc`;
  add an effect to `take_item` (combat.s) only for something the descriptor cannot express.
- **New B item**: add a `B_*` code (and bump `B_LAST`) in `items.s`, a row in `b_slots` and `b_icons`, a `b_item_use` case,
  an icon in `HUD_ITEM_IDS`, and its place in the grid in `menu.s`.
- **New dungeon** (levels 3-9): put the number in `UW_LEVELS` in `build_assets.py` **and** `UW_LEVELS :=` in the Makefile (a test
  compares them), read the dungeon's `LevelInfoUW<N>.dat`, check its palette (`underworld.palette_lookup`; its monsters' sprite
  rows must be baked with the level's own rows), then add the monsters it needs and play every room with
  `screenshot.py --uw <room> --level N`. The entrance is the overworld screen whose attribute B is the level number
  (`build_assets.dungeon_entrance`). Add a golden scene.
- **New sound event**: call `sfx SFX_NAME` (an effect over voice A, B or C, ids in the generated
  `build/generated/music_ids.inc`, names in `tools/music_pack.py` `TRACK_LIST`) or `jingle MUS_NAME` (an event song
  that replaces the area music until it ends) at the place in the 68000 code where it happens; both macros
  keep every register. A new track: add it to `TRACK_LIST` and `nes_music_rip.py` `TRACKS`, and bump nothing
  else (the bank, ids and tests follow). `gvar` values must stay plain numbers (the screenshot harness
  parses them), so write `gvar NAME, 96`, not `gvar NAME, (3 * X)`.
- **New variable**: `gvar` at the **end** of `globals.s` (never insert in the middle of the
  front arrays); `OFF_NAME` is then available; add it to the harness report if useful.
- **New asset table**: field in `ActorData`, writer in `build_assets.py`, entry in the Makefile
  `GENERATED` list, `.incbin` in `main.s` after the anchor, nothing else (no placeholder).

## 13. Lessons learned / pitfalls

- Rebuilds with a dev env leave a dungeon start baked in (section 4).
- Hatari at 60 Hz: use the VBL-latch logic in `present_frame`/`wait_vbl`; don't change it casually.
- The ST has a 16x16 shift blitter at run time; keep sprite counts modest per frame.
- Tab/menu: drawing straight to the visible screen is fine because nothing else runs.
- `replace`-style edits in a big `.s` file: the numeric local labels (`1:`, `2:`...) are reused
  per routine, so check the nearest following definition when you add a branch.
- **A 16-bit branch that does not fit wraps silently** (section 6). Symptom: the game dies at once or in some state, the harness says
  the globals marker is found twice (EmuTOS's saved stack at `$3D6`). `check_reach.py` now catches it at build time; do not
  disable it. To debug one by hand: break on the exception, then compare the faulting PC with `objdump -d build/zelda_st.elf`.
- A previous crash class: a `dbra` loop whose counter register is also used by a called routine
  that does not save it. Check callee save lists.
- When the user asks "check internet and source": the disassembly in `src/` was sufficient every
  time so far; read it first.

## 14. Status and what is next

Done: the overworld (all 128 screens) with octoroks, moblins, lynels, tektites, leevers, zoras, peahats, ghinis and boulders (walking,
shooting, edge spawns, kill history); the first cave; Level 1 (doors/keys/shutters/bombable and false walls, stairs + cellar, stalfos,
keese, gels, ropes, goriyas, wallmasters, Aquamentus, blade traps, push blocks, triforce ending, map and compass with the minimap, the
old man in `$41`); **Level 2** (18 rooms, blue goriyas, Dodongo, Moldorm worms, trap+keese room, the ringleader room, the magic
boomerang, heart container, triforce); **Levels 3-8** (rooms, layouts, items, darknuts, vire, zol, pols voice, like-like,
wizzrobes, bubbles, gibdos, Manhandla, Gohma, Digdogger, Gleeok, rupee stashes, Grumble, dark rooms, the catch-up pass); **Level 9** (Lanmola, Patra, Ganon with the Triforce of Power, Zelda's room, the thanks and the credits); the multi-level pipeline (`level_table`, `uw_select_level`); every item of the original's
inventory in the code (swords of three grades, bow and arrows, rod, potions, food, recorder, rings, magic shield, clock, fairy); drops with
kill counters, knock-back and invincibility; the HUD with the A/B boxes and the Tab inventory screen; YM2149 music and effects; the
M0 tooling (table dump, 16-bit reach check, golden frames).

Open items (user-visible gaps): a play-through of Levels 3-9 (M6-M9); the old man's flames shooting when he is hit; the overworld map on the ribbon; the stairs-type push block
(trigger 5); visible block slide animation; the waterfall and the sea sound; the rest of the sound (title, ending, game-over and
boss music, DPCM); title/game-over/save (M10). The Moldorm is two worms of four, not one of ten; the Dodongo and Moldorm have no death
cloud. Level 2's Dodongo kill, Moldorm segment deaths and ringleader room are verified by reading and loading, not by play-through.
Unmeasured: free memory on a 512 KB machine.

The full plan for everything still missing (hidden bomb/fire spots, enemies, caves, items, all nine
dungeons and bosses, title/save) is `atari_st/PLAN.md`. Scope decision: First Quest only, the Second
Quest is deferred. Its tables are decoded from a user-supplied ROM; do not commit the ROM.

## 15. Persistent notes also kept in the repo memory (VS Code agent memory)

`/memories/repo/*.md` in the VS Code workspace store: build notes, references, the underworld port
notes and the overworld format notes. Their durable content is mirrored in this file.
