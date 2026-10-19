# The Legend of Zelda for Atari ST

A native Atari ST port of The Legend of Zelda, built around aldonunez's Zelda 1 disassembly. It produces a stock TOS `.PRG` for a 512KB Atari ST (320x200, 16 colours) that runs in Hatari, and reads all of its graphics, room layouts, palettes and text from a ROM you supply yourself.

This repository's full feature list, known gaps, roadmap, build notes and testing details live in [`atari_st/README.md`](atari_st/README.md). The detailed implementation plan is in [`atari_st/PLAN.md`](atari_st/PLAN.md).

## Status

An early but playable slice, not yet a complete game: the whole overworld and the first cave, and Level 1 up to Aquamentus and the triforce piece.

**You can already:**

- walk all 128 overworld screens with the original movement and collision, and scroll between them
- go into the first cave, hear the old man's speech and take the wooden sword
- explore Level 1: locked doors, bombable and false walls, shutters, the push block, the stairs to the cellar
- fight stalfos, keese, gels, ropes, goriyas, wallmasters, blade traps and Aquamentus with the sword and its beam, bombs, the boomerang and the candle, and pick up the drops
- open the inventory screen and choose the B item
- find the map and the compass and read the dungeon minimap on the ribbon and on the inventory screen
- meet the old man in the first dungeon's room `$41` and read his hint
- hear the music and sound effects, ripped from the ROM's own sound engine at build time: overworld, dungeon and Level 9 themes, the item and triforce fanfares, Link's death jingle, and effects for sword, boomerang, flame, bomb, stairs, pickups, hurt, the low-life beep, menu clicks and cave text

**Not there yet:** the other dungeon people, the old man's fireballs, the title, ending and game-over music, boss roars, the real overworld monsters, other caves and shops, and the other eight dungeons.

## Controls

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D`, joystick | walk |
| `Space`, joystick fire | the sword (A) |
| `Ctrl` or `Alternate` | the B item: bombs, boomerang or candle |
| `Tab` | inventory screen (Left/Right choose the B item) |
| `K` | debug: a key, four bombs and the candle |
| `Esc` | quit |

## Project layout

- `atari_st/` - the Atari ST port: 68000 source, the ROM-to-ST asset pipeline, tests and a headless Hatari test harness. Its [`README.md`](atari_st/README.md) has the full feature list, known gaps and roadmap
- `src/` - the original Zelda 1 disassembly, kept as the reference for the port
- `ext/` - where you put your own ROM image; it is gitignored
- `AGENTS.md` / `CLAUDE.md` - the briefing for contributors and AI assistants: exact toolchain, testing, references, code conventions

## Build

From the repository root (the build runs in WSL or Linux; there is no native Windows make):

```sh
make -C atari_st all
make -C atari_st check
```

See [`atari_st/README.md`](atari_st/README.md) for prerequisites, Hatari launch and the test harness.

## Credits

Built from aldonunez’s labelled Zelda 1 disassembly and camthesaxman’s zeldasource, cross-checked against the zeldadungeon.net walkthrough, with the graphics, rooms and music read from a ROM you supply yourself.
