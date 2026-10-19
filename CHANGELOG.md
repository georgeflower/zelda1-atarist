# Changelog

Versions are milestones of the Atari ST port (`0.NN`), tagged on the commit that finishes them. A big change (a dungeon,
a new mechanic family, a milestone package of `atari_st/PLAN.md`) gets its own version; fixes and docs ride along with the
version they belong to. The current version is **0.34**.

## 0.34 (2026-10-19) - the title screen and the story (M10, part a)
- The game starts at the ROM's title: the waterfall's waves and crest (`UpdateWaterfallAnimation`), the glowing Triforce (`TriforceGlowingColors`), 512
  frames, then the 14-step fade (`DemoPhase0Subphase1Palettes` and `Delays`). The story follows: the first page scrolls in, rests 256 frames, the parade
  of the treasures scrolls up with the items above their names (1408 steps, one every other frame), Link with the sign and the fairy, 256 frames and
  56 more, then the title again, with its song (`MUS_TITLE`) playing throughout. Return (or the keypad Enter or the joystick button) starts the game at
  any time; it goes straight into the game for now, the file menu is next (M10 part b).
- Everything is read from the ROM at build time (`tools/intro.py`): the nametable transfer streams (the `bins.xml` offsets of two of them are 139 bytes
  off for the Rev 1 ROM; `transfer_streams` checks them and otherwise searches the ROM), the pattern blocks, the palette records, the sprite tables and the
  item-to-picture tables, replayed on a model of the PPU. Each screen gets its own 16 colours (the eight NES rows merged, the fade steps keep every
  colour in its slot). 174 title tiles, 64 story tiles, 59 sprite frames, 45 parade records.
- `intro.s` (`MODE_INTRO`): the picture lives in a ring of 200 lines in `BG_CUR`, a line per scroll step, copied into the hidden screen over two frames
  and shown; still items are drawn into the ring as their lines come in, the flashing and fluttering ones and the waterfall are sprites. About
  one frame in a hundred takes a VBL more while the parade's animated items are on screen (the scroll copy is 130,000 cycles).
  `begin_game` is the old start-up code (the dev-start block, `enter_room`, the HUD), now also what Start runs. Development builds
  (`ZELDA_START_ROOM`, `ZELDA_START_UW`, `ZELDA_START_CAVE` or `ZELDA_SKIP_INTRO`, the screenshot harness's scenes among them) skip the title (`DEV_SKIP_INTRO`).
- `music_update` leaves the title alone (no area music in `MODE_INTRO`). `tests/test_intro.py` checks the generated tables; `screenshot.py` knows Return.
  The golden scenes `title`, `title_fade`, `story_page` and `story_parade` were added; all scenes depending on the PRG's size were re-recorded.

## 0.33.2 (2026-10-19) - monsters come out of clouds, and walk in at a fair distance
- Overworld monsters are put down in the ROM's spawn cloud: `InitObject` gives every object metastate 1, and the cloud (bomb item frames `$70`, `$72`, `$74`)
  runs for the slot number in frames (an octorok: `(slot + 1) * $10`, "octorok spawn clouds last longer"), then six frames a picture. The monster stands
  still, cannot be hurt and does not hurt (`ENEMY_CLOUD`, `cloud_begin`, `cloud_tick`, `mon_cloud.bin`). Which types get a cloud is read from the ROM:
  `actors.rom_spawn_clouds` follows the initialiser of each type in `InitObject_JumpTable` and leaves out the ones that end in `ResetObjMetastate`
  (leevers, zoras, peahats, boulders, ghinis, Gohma, Ganon). The dungeons' monsters still appear at once; the same table can be switched on for them later.
- Screens with edge spawns (I7, I8 and the other 18 of the start region) never had the ROM's `IsDistanceSafeToSpawn`: a monster could walk in on the
  square Link stood on. A square within the keep-away distance of him is skipped now. Asked for gentler: the first monster waits 30 frames, the next come
  40 to 70 frames apart (the ROM: at once, then 20 to 50), a square that is too close is tried again after 10 frames, and the keep-away is `$48` (the ROM's `$22`).
  The numbers are `EDGE_*` equates in `main.s`.
- `fx_sprites` has a third cloud picture (21 frames); golden frames `ow_entrance_l2`, `ow_grave_returns` (a monster leaving its cloud) and the two
  random-walk ones were re-recorded.

## 0.33.1 (2026-10-19) - nothing but the ROM's own art and music
- The song `zelda_intro_by_qum` is gone from the repository (header, notes, `MUSIC_OVERWORLD`, `--overworld`, `--song-dir`, the shipped-song
  tests). The overworld plays the ROM's theme like every other track; `ym_convert.py` only converts the digidrum engine of `ymplay.h`.
  Without the ROM (or `py65`) the music bank is empty and the game silent.
- The placeholder fallback of the asset pipeline is gone (procedural tiles, rooms, the one-room dungeon, the stand-in palette, `--require-source`):
  a build without `ext/Original.nes` stops with a message. The overworld blob monster (type 255 and `enemy_sprites.bin`) is gone too; it had
  not been spawned for a long time.
- The fireball (Aquamentus and the zora) was a circle drawn by `actors.py`. It is now the ROM's: tile `$44`, half width (`ObjectTypeToAttributes` `$E3`),
  with the attributes `FrameCounter & 3`, so it flashes through the four sprite palettes one a frame (`PF_FIREBALL` has four frames).
- Unit tests that needed the stand-ins now use the ROM and skip without it. `uw1_aquamentus` (the fireballs), `uw2_goriyas` and `uw4_dark`
  (random walks that move with the PRG's size, see `AGENTS.md`) were re-recorded.
- README names the ROM the port is built and tested with (*The Legend of Zelda (Europe) (Rev 1)*).

## 0.33 (2026-10-19) - overworld specials (M4)
- New module `owspec.s` (monsters `$1E` armos, `$2E` whirlwind, `$2F` fairy are made by code; `actors.py` has their rows, art and draw
  modes `MODE_ARMOS`, `MODE_FAIRY`; the behaviours `BEH_ARMOS`, `BEH_WHIRLWIND`, `BEH_FAIRY` run through `mover_update`).
- Lost Woods (`$61`) and Lost Hills (`$1B`): the direction sequences of `CheckMazes`, a wrong move sends Link back, the secret tune on success.
- Ladder: it appears under Link on a gap and lets him cross one square of water, also on the P6 screen where the free-standing heart container sits on water.
  Raft: the docks at P4 and F6 take him along the ferry routes with the raft.
- Armos: twelve screens of them. A blocked step into an armos tile wakes it (fade of `$3F` frames, no weapon touches it), it walks like a goriya and
  hurts for a whole heart; the square under it becomes floor, or stairs in the seven secret rooms `$24 $0B $1C $22 $34 $3D $4E`; `$24` leaves the Power
  Bracelet at the spot. The ROM's room-tile patch (`ow_set_square`) makes the change permanent for stairs and undone on the next layout otherwise.
- Recorder: in screen `$42` (C5) the pond water cycles through `PondCycleColors`, can be walked on at step ten, and the stairs into Level 7 appear (the
  water is ST palette index `POND_IDX`, cycled from `pond_colors`). Elsewhere the whirlwind (`SummonWhirlwind`, `TeleportYs`, `WhirlwindPrevRoomIdList`)
  carries Link to the entrance of the next dungeon whose triforce piece he owns, scrolls, and sets him down at X `$80`; Link is not drawn while it carries him.
- Fairy ponds (`$39`, `$43`): the fairy waits at the pond, hearts orbit while Link is held and his life is refilled, then released.
- `room_secrets.bin` ends with 16 extra bytes (pond stairs metatile and square, `(armos, floor, stairs)` per palette slot, `$FF`), unit-tested.
- The boss pool can draw item pictures (`BP_ITEM`), used for the heart ring. `*_far` stubs in `main.s` for `goriya_ai`, `uw_person_update`, `owspec_init`
  (the tightest branch has 648 bytes left).
- Four golden scenes (`ow_armos_stairs`, `ow_fairy_pond`, `ow_pond_stairs`, `ow_whirlwind_carries`); `uw2_goriyas` and `uw4_dark` were re-recorded
  (random monster moves; the frames still show the same scenes). Fixed `test_dump_tables` to know `--cave`.
- Not done: the waterfall and the sea sound.

## 0.32 (2026-10-19) - caves, shops and people (M3)
- All twenty overworld cave types work, driven by `cave_table.bin` (16 bytes a cave: flags, who, three wares, three prices, speech and
  hint offsets), which `build_assets.py` reads from the ROM's `LevelBlockAttrsE`, text selectors and prices. The person (old man,
  old woman, shopkeeper, moblin) is a sprite, so he can flicker; `caves.s` holds the state machine of `UpdateCavePerson`.
- Gifts: the wooden sword, "take any one" (red potion or heart container, the other vanishes), the white sword (5 hearts) and the magic
  sword (12 hearts; without them nothing happens), the letter. Shops with the rupee tag and prices on the price row, paid for with
  the rupee drip; the medicine woman wakes when Link shows her the letter (B); paid hints, whose speech depends on the ware; the money
  making game (ten rupees to play, +/- amounts in a random order); the door repair charge (20 rupees, once); the moblins' rupees.
- Given things stay given: `OW_KILLS` bit 4 marks types `$6A`-`$6D`, `$71`, `$72` and `$7B`-`$7D`; the shops, hints and the money game
  come back. After a take the person, the other wares and the tag flicker for `$40` frames and vanish.
- Take-any-road: the second cave room with its three stairs (the middle one is white, as the palette has it); they lead to the next but
  one of the rooms `$1D $23 $49 $79`, and Link comes out at that screen's cave.
- Rupees are paid out and taken one every other frame with the heart blip (`RUPEES_ADD`, `RUPEES_SUB`), in every mode. The status bar
  shows three-digit counts (it showed garbage above 99 rupees).
- Link now enters a cave at X `$70`, as in the ROM, so the middle ware is not in his way.
- `screenshot.py --cave` (and `ZELDA_START_CAVE`) starts inside the cave behind the start screen, for the scripted checks.
- Differences from the ROM: B opens the medicine woman's shop (the B-item menu has no letter), the money game's six orders are
  equally likely, wares are touched within 6 pixels of their column.
- Fourteen golden scenes (`cave_*`) and `test_cave_table_follows_the_rom`.

## 0.31 (2026-10-19) - hidden bomb, fire and push spots (M1)
- The overworld's six marker squares are drawn as the squares they imitate (rock, rock wall, tree, gravestone), as the ROM does; the
  marker art is gone from every screen. `build_assets.py` writes `room_secrets.bin` (128 records of 8 bytes) with the 43 spots of
  the First Quest: 22 bomb walls, 16 trees, 4 bracelet rocks, 1 gravestone. Spots tagged for the Second Quest only stay scenery.
- A bomb whose cloud opens within 16 pixels of a rock wall turns it into a cave entrance; a flame on its last frames burns a tree
  into stairs; Link pushes a gravestone, or a rock with the power bracelet, straight up or down and the stairs appear. The secret
  tune plays; the caves and stairs lead through `check_warps` like any other (what is inside them is milestone M3).
- Found secrets are kept in the room flags (`OW_KILLS` bit 7) and stay open. A pushed rock or gravestone goes back to its place when
  Link leaves the screen, as in the ROM; the stairs under the rock stay, those under the gravestone do not.
- `secrets.s`; the screens are patched in place in `room_maps` (the PRG is RAM-resident), so scrolling and `fetch_tile` need no change.
  Four far stubs in `main.s` keep the 16-bit reach.
- Differences from the ROM: the pushed stone jumps one square instead of sliding; the revealed bomb wall is the ordinary cave
  entrance square at once (the ROM shows four black tiles until the screen is laid out again); armos stay with M4.
- Seven new golden scenes (`ow_bomb_wall`, `ow_bomb_miss`, `ow_tree_burnt`, `ow_rock_pushed`, `ow_rock_no_bracelet`,
  `ow_grave_pushed`, `ow_grave_returns`) and five unit tests.
- Fix, Ganon's death (checked in Hatari with a silver arrow): he burns solid for the `$50` frames the ROM draws him (he flickered), the ash pile
  keeps the ROM's colours (orange, brown, red; it had white specks), stays on the floor under the Triforce of Power instead of vanishing
  when the item appears, and the brown Ganon is a darker red-brown, no longer a bright orange that read as a Dodongo. Two golden scenes
  (`uw9_ganon_brown`, `uw9_ganon_ashes`). Not ported: the eight burst rays that fly out of the ashes.

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
  takes two VBLs. Golden scenes for Levels 3-8. `SCREENSHOTS/` folder (taken out of the repository again later; it stays in the history).

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
