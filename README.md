# The Legend of Zelda for Atari ST

A native Atari ST port of The Legend of Zelda, built around aldonunez's Zelda 1 disassembly. It produces a stock TOS `.PRG` for a 512KB Atari ST (320x200, 16 colours) that runs in Hatari, and reads its graphics, rooms, palettes and text from a ROM image you supply yourself (`ext/Original.nes`, never committed).

## Status

An early but playable slice, not yet a complete game: the whole overworld and the first cave, and Level 1 up to Aquamentus and the triforce piece.

**You can already:**

- walk all 128 overworld screens with the original movement and collision, and scroll between them
- go into the first cave, hear the old man's speech and take the wooden sword
- explore Level 1: locked doors, bombable and false walls, shutters, the push block, the stairs to the cellar
- fight stalfos, keese, gels, ropes, goriyas, wallmasters, blade traps and Aquamentus with the sword and its beam, bombs, the boomerang and the candle, and pick up the drops
- open the inventory screen and choose the B item
- find the map and the compass and read the dungeon minimap on the ribbon
- hear the music and sound effects, ripped from the ROM's own sound engine at build time: overworld, dungeon and Level 9 themes, the item and triforce fanfares, Link's death jingle, and effects for hits, bombs, kills, rupees, keys, hearts and opening shutters

**Not there yet:** the dungeon people, the map and compass in the inventory screen, the title, ending and game-over music, boss roars, the real overworld monsters, other caves and shops, and the other eight dungeons.

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

- `atari_st/` - the Atari ST port: 68000 source, the ROM-to-ST asset pipeline, tests and a headless Hatari test harness. Its `README.md` has the full feature list, known gaps and roadmap
- `src/` - the original Zelda 1 disassembly, kept as the reference for the port
- `ext/` - where you put your own ROM image; it is gitignored
- `AGENTS.md` / `CLAUDE.md` - the briefing for contributors and AI assistants: exact toolchain, testing, references, code conventions

## Build

From the repository root (the build runs in WSL or Linux; there is no native Windows make):

```sh
make -C atari_st all
make -C atari_st check
```

See `atari_st/README.md` for prerequisites, Hatari launch and the test harness.

## Credits

This project builds on the disassembly work of Aldo Nunez, whose reverse-engineering and documentation are the foundation of this code base.
