# Changelog

Versions are milestones of the Atari ST port (`0.NN`), tagged on the commit that finishes them. A big change (a dungeon,
a new mechanic family, a milestone package of `atari_st/PLAN.md`) gets its own version; fixes and docs ride along with the
version they belong to. The current version is **0.30**.

## 0.30 (2026-10-19) - doors, moats, play-through checks
- The magic key opens every locked door without being used up (Level 9 has 16 locked doors and 4 keys); the HUD shows "XA".
- The ladder crosses moats (NES tile `$F4`): rooms in Levels 4-7 and 9 are cut in two by one. Not drawn yet.
- `test_build_assets.py` replays the doors of every dungeon: all rooms reachable, Levels 1-8 have enough keys.
- Scripted Hatari checks of Levels 3-9 (second Digdogger, Lanmola, Patra, stash, door man, Pols Voice, Vire); what was and was not
  checked is in `AGENTS.md`. New golden scene `uw1_magic_key_door`.
- Versions and this changelog; `atari_st/PLAN.md` brought up to date with the next step.

## 0.29 - credits, Ganon's music, two more people (PR #30)
- Credits after Zelda's closing words: typed three-line pages (the ROM's staff, "ATARI ST PORT / BY Q", "YOU ARE GREAT",
  "END OF THE LEGEND OF ZELDA"); the last page stays.
- `MUS_GANON` plays when Ganon appears and when he burns.
- The "more bombs" man (Levels 5 and 7: 100 rupees, +4 max bombs, refill) and the "life or money" man (heart container or 50
  rupees); max bombs is a variable. Room record byte 13 says which man it is.
- Golden scenes `uw5_bombs_man`, `uw9_credits_port`.

## 0.28 - Ganon and Zelda (PR #29)
- Ganon: dark room, Triforce of Courage, hiding and teleporting, fire, brown after a sword blow, the silver arrow kills him, ashes
  and the Triforce of Power.
- Zelda's room, the four guard fires and the thanks scene: fanfare, curtain, typed thanks, the two triforce pieces with the
  flashing backdrop, the closing words.

## 0.27 - Level 9 (PR #29)
- The dungeon: 57 rooms, a ten-entry cellar array, person table C, the door man who lets Link by with all eight pieces.
- Lanmola (two worms of four) and Patra (the eye and seven children that go round it).

## 0.26 - stashes, Grumble, dark rooms (PR #27, #28)
- Rupee stashes, Grumble, dark rooms (the candle lights them) and a catch-up pass that keeps the game speed when a crowded room
  takes two VBLs. Golden scenes for Levels 3-8. `SCREENSHOTS/` folder.

## 0.25 - the bosses of Levels 3-8 (PR #27)
- Manhandla, Gohma, Digdogger (the recorder splits it) and Gleeok; `bosses.s` with far trampolines, a boss sprite pool.

## 0.24 - Levels 3 to 8 (PR #27)
- The dungeons' rooms, layouts, doors and items from the ROM tables; darknuts, vires, zols, pols voice, like-likes, bubbles,
  gibdos and the wizzrobes with their magic.

## 0.23 - foundations (PR #25, #26)
- `dump_tables.py`, the listing-based 16-bit reach check, `screenshot.py --room/--uw/--level`, golden frames; both READMEs,
  `AGENTS.md`/`CLAUDE.md` and `PLAN.md` refreshed.

## 0.22 - Level 2 (PR #24)
- Per-level tables (`level_table`, `uw_select_level`), the 18 rooms, blue goriyas, Dodongo, Moldorm, traps, the ringleader room.

## 0.21 - items and power-ups (PR #23)
- The ROM's Items block, table-driven `take_item`: white and magic sword, bow and arrows, rod, potions, food, recorder, red candle,
  magic boomerang, rings, magic shield, clock, fairy; the 2x4 Tab grid.

## 0.20 - overworld movers (PR #22)
- Tektites, leevers, zoras, peahats, ghinis and boulders; image layout with `.data` first.

## 0.19 - shots and spawn rules (PR #21)
- Overworld shots, the edge-spawn ring and the room kill history.

## 0.18 - overworld walkers (PR #19, #20)
- Octoroks, moblins and lynels on their real screens; `PLAN.md` records what had been implemented.

## 0.17 - palettes and 50 Hz (PR #18)
- Per-level palettes and the PAL timing check.

## 0.16 - items held up (PR #16, #17)
- The boomerang no longer sticks at a wall; the sword, boomerang, bow and candle are held up when taken.

## 0.15 - monsters turn like the ROM's (PR #15)

## 0.14 and earlier (PR #1 to #14)
- The vertical slice (overworld, Link, the first cave and sword), the dev-start switches, `PLAN.md`, the ROM's music and sound
  effects ripped to `.ym` and played from a VBL hook, Level 1 complete: the bow room's push block, the triforce ending, map and
  compass with the minimap, the Tab screen, the old man in room `$41`.
