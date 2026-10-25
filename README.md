# The Legend of Zelda for Atari ST

A port of Zelda 1 to the Atari ST. It's written in 68000 assembly and runs as a normal TOS `.PRG` on an ST with 1 MB of RAM (320x200, 16 colours). I run it in Hatari.

There is no game data in this repo. You have to bring your own ROM and put it in `ext/Original.nes`. The graphics, rooms, music and texts are all read from it when you build. The ROM is gitignored and should never be committed.

I'm making this together with an AI (Claude, from Anthropic). I decide what to build and what to fix, Claude writes most of the code and the tools. The behaviour follows aldonunez's disassembly of the original, which is in `src/`.

## Status

Work in progress. Both quests are in: the whole overworld, all nine dungeons up to Ganon and Zelda, every item, title and story, file select, death and continue, saving to `ZELDA.SAV`, the credits and the music. Expect bugs. There is a short list of what is left in [`atari_st/PLAN.md`](atari_st/PLAN.md).

The Second Quest starts when you make a file called ZELDA (like the original), or when you finish the game. Both quests are in one `.PRG` of about 700 KB, so you need 1 MB of RAM. It fits on a 720 KB disk together with the save file.

## Controls

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D`, joystick | walk |
| `Space`, joystick fire | sword (A) |
| `Ctrl` or `Alternate` | B item: bombs, boomerang, candle, bow, recorder, food, potion or rod |
| `Tab` | inventory screen (Left/Right to choose the B item) |
| `K` | debug: a key, four bombs and the candle |
| `Esc` | quit |

## Build

The build runs in Linux or WSL (there is no native Windows make). From the repository root:

```sh
make -C atari_st all
make -C atari_st check
```

`atari_st/README.md` has what you need to install, how to start it in Hatari and how the tests work.

## Layout

- `atari_st/` - the port: 68000 source, the tools that turn the ROM into ST data, tests and a headless Hatari harness
- `src/` - the original Zelda 1 disassembly, used as the reference
- `ext/` - where your ROM goes (gitignored)
- `AGENTS.md` / `CLAUDE.md` - notes for AI assistants working on the project (same file twice)

## Credits

Based on aldonunez's labelled Zelda 1 disassembly and camthesaxman's zeldasource. The zeldadungeon.net walkthrough was used for checking levels and items. Zelda is Nintendo's; this is a fan project and has nothing to do with them.
