# The Legend of Zelda for Atari ST

This project is a native Atari ST adaptation of The Legend of Zelda built around the original Zelda 1 disassembly work. It produces a stock TOS `.PRG` for a 512KB Atari ST (320x200, 16 colours) that runs in Hatari, and reads its graphics, rooms, palettes and text from a ROM image you supply yourself.

This project builds on the disassembly work of Aldo Núñez, whose reverse-engineering efforts and documentation helped establish the foundation for this codebase.

## Status

An early but playable slice, not yet a complete game.

**You can already:**

- walk all 128 overworld screens with the original movement and collision, and scroll between them
- go into the first cave, hear the old man's speech and take the wooden sword
- enter Level 1 and explore its rooms: locked doors, bombable and false walls, shutters that open when the monsters die
- fight stalfos, keese, gels, ropes and goriya with the sword and its beam, plant bombs, and pick up the drops
- collect keys, hearts, rupees, bombs and the level's items, and take the stairs to the cellar with the bow

**Not there yet:** sound, the inventory screen and item use, the boss and several dungeon monsters, the real overworld monsters, other caves and shops, and the other eight dungeons.

Controls: arrow keys or `W` `A` `S` `D` to walk, `Space` to swing the sword, `B` to drop a bomb, `Esc` to quit.

## Roadmap

1. Finish Level 1: the remaining monsters (wallmasters, traps, the boss), secret triggers, the triforce piece and real weapon art
2. The rest of the overworld: the real monsters, shops and other caves, the inventory screen and the B-button items
3. The other eight dungeons on the same underworld engine
4. YM2149 audio, title and game-over screens, saving

The full feature list, known gaps and a longer roadmap are in `atari_st/README.md`.

## Project layout

- `atari_st/` - the Atari ST port: 68000 source, the ROM-to-ST asset pipeline, tests and a headless Hatari test harness
- `src/` - the original Zelda 1 disassembly, kept as the reference for the port
- `ext/` - where you put your own ROM image (`Original.nes`); it is gitignored and never committed

## Build

From the repository root:

```sh
make -C atari_st all
make -C atari_st check
```

See `atari_st/README.md` for prerequisites, build details, and Hatari launch instructions.

## Credits

Aldo Núñez and his disassembly work are an important foundation for this project.
