# refnes: ROM reference harness

Headless NES emulation (jsnes) used to compare the original ROM against the port, room by room.
Needs `ext/Original.nes` (never committed) and `npm install` in this directory.

- `rom_rooms.mjs [out.json] [--quest 1|2] [--level N]`: enter all 128 rooms of a level in the ROM and record monsters, room item, door state and tiles.
- `port_rooms.py`: dump the same facts from the port's generated tables to `build/refnes/port_rooms.json`.
- `compare.py`: compare monsters and items (with normalisation for groups and the ROM's quirks).
- `compare_tiles.py`, `compare_ow_tiles.py`: compare underworld and overworld room tiles.

Output goes to `atari_st/build/refnes/` (gitignored).
