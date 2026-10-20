# The Legend of Zelda for Atari ST

A native Atari ST port of The Legend of Zelda, built around aldonunez's Zelda 1 disassembly. It produces a stock TOS `.PRG` for a 512KB Atari ST (320x200, 16 colours) that runs in Hatari, and reads all of its graphics, room layouts, palettes and text from a ROM you supply yourself.

This repository's full feature list, known gaps, roadmap, build notes and testing details live in [`atari_st/README.md`](atari_st/README.md). The detailed implementation plan is in [`atari_st/PLAN.md`](atari_st/PLAN.md).

## Status

**Version 0.35** ([changelog](CHANGELOG.md)). A playable game with all nine dungeons, not yet a complete one: the whole overworld with its monsters, all twenty kinds of cave (shops, hints, the money game, door repair, take-any-road, the medicine woman) and Levels 1 to 9 with their rooms, items, monsters and bosses, up to Ganon, Zelda's thanks and the credits (with a line for the port's author). Levels 1 and 2 have been played through to the triforce piece; Levels 3 to 9 are built from the ROM's tables and load and run in every room (Lanmola, Patra, Ganon and Zelda's scene were each tried in Hatari), but have not been played through yet. The overworld's armos, raft, ladder, recorder (whirlwind and the Level 7 pond), Lost Woods and Lost Hills and the fairy ponds work. The game starts at the title: the waterfall and the glowing Triforce, then the story and the parade of the treasures (Return starts the game at any time). File select, entering a name and saving are still missing, so the game cannot be kept like the original yet.

**You can already:**

- walk all 128 overworld screens with the original movement and collision, and scroll between them
- fight the overworld's octoroks, moblins, lynels, tektites, leevers, zoras, peahats, ghinis and boulders, with their shots, edge spawns and kill history
- go into the first cave, hear the old man's speech and take the wooden sword
- bomb the overworld's rock walls, burn its trees (with the candle) and push its gravestones and bracelet rocks: the hidden stairs and caves open (what is inside most of them is not ported yet)
- explore Levels 1 to 8 (entered from the overworld's dungeon stairs, for instance `$37` and `$3C`): locked doors, bombable and false walls, shutters, push blocks, stairs and cellars, the map, the compass and the minimap, and the old men's hints
- fight stalfos, keese, gels, ropes, goriyas (red and blue), darknuts, vires, zols, pols voice, like-likes, wizzrobes, gibdos, bubbles, wallmasters, blade traps, Aquamentus, the Dodongo (feed it bombs), the Moldorm, Manhandla, Gohma, Digdogger and Gleeok with the sword and its beam, bombs, the boomerang (also the magic one), the candle, the bow and arrows and the magic rod, and pick up the drops (hearts, rupees, bombs, the clock, the fairy)
- use everything the original's inventory holds in the code: white and magical swords, potions, food, the recorder, the rings and the magic shield; most of these can only be found once their caves and shops are ported
- open the inventory screen and choose the B item
- find the map and the compass and read the dungeon minimap on the ribbon and on the inventory screen
- meet the old man in the first dungeon's room `$41` and read his hint
- hear the music and sound effects, ripped from the ROM's own sound engine at build time: overworld, dungeon and Level 9 themes, the item and triforce fanfares, Link's death jingle, and effects for sword, boomerang, flame, bomb, stairs, pickups, hurt, the low-life beep, menu clicks and cave text

**Not there yet:** armos (and the stairs they hide), shops and most caves, the title and game-over music, boss roars, the title screen and saving. The Second Quest is deferred. The plan for all of it is `atari_st/PLAN.md`.

## Controls

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D`, joystick | walk |
| `Space`, joystick fire | the sword (A) |
| `Ctrl` or `Alternate` | the B item: bombs, boomerang, candle, bow, recorder, food, potion or rod |
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
