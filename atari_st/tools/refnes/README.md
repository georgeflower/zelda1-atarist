# refnes: ROM reference harness

Headless NES emulation (jsnes) used to compare the original ROM against the port, room by room.
Needs `ext/Original.nes` (never committed) and `npm install` in this directory.

- `rom_rooms.mjs [out.json] [--quest 1|2] [--level N]`: enter all 128 rooms of a level in the ROM and record monsters, room item, door state and tiles.
- `port_rooms.py`: dump the same facts from the port's generated tables to `build/refnes/port_rooms.json`.
- `compare.py`: compare monsters and items (with normalisation for groups and the ROM's quirks).
- `compare_tiles.py`, `compare_ow_tiles.py`: compare underworld and overworld room tiles.

Output goes to `atari_st/build/refnes/` (gitignored).

## Play-through audit (rooms played, not just laid out)

The same scripted player plays every monster room in the ROM and in the port, and the outcomes are compared.
The player is invincible, holds the magic sword, comes in at the bottom door, walks at the nearest monster and swings. In the port it is
`src/autoplay.s`, a development-only build (`ZELDA_AUTOPLAY=1`; `idle` makes Link stand still, to watch the monsters; never in the game).

- `rom_play.mjs [out.json] [--quest 1|2] [--level N] [--rooms ...] [--frames N] [--idle]`: the ROM side (jsnes).
- `port_play.py [out.json] [--quest 1|2] [--level N] [--rooms ...] [--frames N] [--idle] [--name auto0]`: the port side (Hatari, needs `TOS`). One dev build and run per room; `--name` picks the build directory, so two workers can run at once.
- `compare_play.py [--idle] [--rom ..] [--port ..] [--notes]`: what must agree: the monsters of a room, the room item at the start, the doors after a clear, and (idle) how fast each kind of monster moves. How long the player takes, and whether it gets stuck on a block, depend on the player and are only notes.
- `run_phase2.sh LEVEL [QUEST]`: one dungeon, fight then idle, ROM then port.

It found two things in the port that the per-room tables could not show: the wizzrobes were moved twice, and shutters opened in rooms whose trigger never opens them.

## Small probes

- `respawn_probe.mjs [dungeon|partial|boss|reenter|overworld|all]`: clears a room in the ROM, leaves it and comes back, and prints the room history, the room's world flags and kill count and what is made on re-entry. It shows when monsters return in the dungeons (once the room is out of the last six entered; bosses never; kills of a room not cleared are kept; leaving a dungeon clears the history) and in the overworld.
- `ladder_test.mjs LEVEL ROOM X Y DIR [FRAMES]`: puts Link in a room of the ROM with the ladder and walks him one way; prints the moat and where he stops (on the ladder's square: it carries him one square, never two).
- `zol_colour.mjs LEVEL ROOM TYPE`: the palette on screen and the colours of a monster in the ROM, and a picture (`PPM=file.ppm`). Sprite palette row 3 is each dungeon's own, which is why a Zol is black in Level 4.
