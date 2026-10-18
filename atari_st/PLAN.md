# Zelda 1 for Atari ST - plan for all remaining work

Status: **work in progress.** Written as a plan after PR #2; PRs #4 to #18 have since implemented parts of it, listed in section 1.1, and ticked boxes (`[x]`) below show what is done. Scope decision: **First Quest only** for now; the Second Quest is deferred (M13). Written against `georgeflower/zelda1-atarist` after PR #2 (Makefile dev-start stamp) was merged.

How to read this: section 2 is the order of work. Sections 3 to 12 are one work package each, with a checklist and an acceptance test. Section 13 records the decisions, the risks and the checks still open. The appendices hold the data tables, decoded from the PAL (Europe, Rev 1) ROM you supplied. That ROM has the same data layout as the disassembly in `src/` (start room `$77`, start Y `$8D`, same blob offsets), so the tables should apply to the NTSC ROM the build expects as well.

Where I could not confirm something from the disassembly or the ROM, the line says **(verify)**. Section 13 lists them all.

## 1. Where the port stands, and what "all remaining" means

Done (see `AGENTS.md` section 14): the whole 128-screen overworld is walkable; the first cave and wooden sword work; Level 1 is playable from the entrance to the triforce ending (Aquamentus, map and compass with a minimap, the old man, the bow cellar, the push-block rooms); sword, beam, bombs, boomerang and candle work, and picking up a weapon holds it overhead; the Tab inventory screen shows the B items, map, compass and bow; the music and sound effects are the ROM's own; the ST colours switch per dungeon and the game runs at 50 and 60 Hz.

Remaining, in the words of your request:

1. Overworld bomb and fire spots show the wrong symbol: they must look like plain rock or tree and lead to the correct cave or dungeon.
2. Every item you can collect, listed (section 8.1, plus the dungeon and cave tables in appendices C and D).
3. The fairy fountains ("fairy mother", see decision Q1 in section 13.1), all caves and secrets, all bosses, all nine levels.
4. Title/intro screen, player select and save.
5. All overworld enemies with behaviour and location (section 5 and appendices A and B).

### 1.1 Implemented so far (PRs #4 to #18, all merged)

| PR | What | Plan section |
|---|---|---|
| #4, #6 | `nes_music_rip.py`: every song, jingle and sound effect of the ROM ripped to `.ym` by running its own sound engine | M11 |
| #5 | Music player: YM2149 register streams from a VBL hook, four contexts (song, effect over voice A, B, noise effect over voice C), digidrums | M11 |
| #8 | Effect-channel sounds hooked: sword, boomerang, flame, bomb blast, stairs, low-life beep, menu and cave clicks | M11 |
| #9 | The overworld plays the NES original theme by default (`MUSIC_OVERWORLD=qum` keeps the shipped arrangement) | M11 |
| #10 | The bow room's push block (room `$22`) works: follows the ROM's push-block flag, not only trigger 4 | M6 |
| #11 | Triforce ending as in the original: hold, white flash, hearts fill, curtain, pause, back to the overworld | M6, M9 |
| #12, #13 | Map and compass: bit per level in `INV_MAP`/`INV_COMPASS`, dungeon minimap on the ribbon, the same map bigger on the Tab screen | M5, M6 |
| #14 | Dungeon people: the old man in Level 1 room `$41` (speech per level from the ROM, flames, blocks the way up) | M3 (6.3) |
| #15 | Enemy behaviour from the ROM: walkers turn like `Wanderer_TargetPlayer`, goriya (`UpdateGoriya`: faces Link within `$51`, throw rolls `$23`/`$77`), rope, gel (1 px/frame with rests) | M7 |
| #16 | Boomerang no longer sticks at a wall; the bow is shown on the Tab screen (`INV_BOW`) | M5 |
| #17 | Holding an item up (sword, boomerang, bow, candle): fanfare, arms-up Link for `$80` frames | M5 |
| #18 | M0 palette strategy (risk R1): slot-stable per-level palettes for all nine dungeons; M0 PAL check (risk R2): 50 Hz run in Hatari | M0 |

| #20 | Overworld walkers (M2 step 1): octoroks (red, blue, slow, fast), moblins and lynels on their real screens, from a per-screen table (`ow_room_info`); art from the overworld sprite patterns | M2 |
| #21 | Overworld shots (M2 step 2): rock, arrow and sword shot (shoot timers, shot limit 4, parry, bounce), drops through `mon_table`, the edge-spawn ring, the six-screen room history and per-screen kill counts; `table_anchor` moved and `tools/check_reach.py` guards the reach | M2 |

Still open from M0: the table-dump tool, the reach budget (R3) and the golden images. M2 has its first three steps (walkers; shots, edge spawns and kill history; the special movers); armos, gravestones and flying ghinis wait for the room-tile patch overlay. Nothing of M1 (hidden spots) or M4 (overworld specials) has been started, and only the first cave of M3.

## 2. Order of work

| # | Work package | Depends on | Size | Status |
|---|---|---|---|---|
| M0 | Foundations: table-dump tool, palette strategy, PAL timing, regression screenshots | - | S | partly: palettes and PAL done (#18) |
| M1 | **Hidden bomb/fire/push spots fixed** (the visible bug) | M0 | M | not started |
| M2 | Overworld enemies, spawn rules, drops | M0 | L | step 1 done: octoroks, moblins, lynels walk (no shooting yet) |
| M3 | Caves: people, shops, hints, money game, door repair, take-any-road, old woman | M1 | L | first cave and the Level 1 old man |
| M4 | Overworld specials: armos, bracelet rocks, gravestones, docks/raft, ladder, recorder + whirlwind, Lost Woods/Hills, fairy ponds | M1, M2 | L | not started |
| M5 | Items, inventory screen, HUD, every B item and passive item | M3 | L | partly: Level 1 items, HUD, Tab screen |
| M6 | Dungeon engine generalised: doors, dark rooms, stair rooms, triggers, per-level palettes and tiles | M0 | L | partly: Level 1 engine, palettes for all levels |
| M7 | Dungeon monsters (all underworld types) | M6 | XL | partly: 8 types |
| M8 | Bosses | M7 | XL | Aquamentus only |
| M9 | Levels 2 to 9 content, triforce sequence, map/compass minimap | M6, M7, M8 | XL | Level 1 done incl. triforce sequence and minimap |
| M10 | Title/story, file select, name entry, save, continue/death, ending | M5 | L | not started (death returns to the start) |
| M11 | Sound effects and music (player, bank and the Level 1 events done; the rest are hooks, see 12) | any | M | mostly done (#4 to #9) |
| M12 | Polish: PAL 50 Hz, performance, memory, unit tests, docs | all | M | PAL checked (#18); the rest open |
| M13 | Deferred (decided: not now): Second Quest | all | L | deferred |

Reasoning: M1 is first because it is the bug you can see now and it fixes the data model (secret objects per room) that M3, M4 and M9 reuse. M6 comes before the monsters because every dungeon monster needs the room, door and palette machinery to be tested in place. M10 comes late because save files store the inventory, so the inventory must be final first.

## 3. M0 Foundations

- [ ] Commit the ROM table-dump tool (the one used for these appendices) as `atari_st/tools/dump_tables.py`. It reads `ext/Original.nes`, writes JSON and Markdown under `build/`, never writes the ROM anywhere else. Rerunning it keeps this plan checkable.
- [x] **Palette strategy (risk R1).** Done. The overworld uses all 16 ST colours; Levels 3-9 each need 1-3 colours it lacks (3: `$1B $2B $0B`, 4 and 6: `$18 $28 $08`, 5 and 7: `$2A $0A`, 8 and 9: `$10`), Levels 1-2 fit as they are, and no level needs more than 15 on its own. Decision: **one palette per mode, slot-stable.** Every colour keeps the slot it has in the overworld table, because Link, items, effects, the HUD and the cellar walls are baked once with those slot numbers; a level swaps its missing colours into spare slots (background-only ones first, never Link's row, the HUD rows, the cave row or the minimap slots 1, 2, 4, 7, 9). `underworld.palette_lookup` does this and returns the level's 16 ST colours; `build_assets` writes them as `level_palettes` (9 rows). `palette_sync` (video.s, once a frame) loads the table for `OFF_LEVEL`; the flash and ending code restore through `cur_palette`. The title, story and game-over screens will get their own rows in `level_palettes`' successor when they are built (M10). Still to do per level (M6 to M9): bake that level's monsters with its own sprite rows, since the baked monster art takes the overworld's colours.

- [x] **PAL timing (risk R2).** Done in Hatari with EmuTOS 1.4 German (`etos512de.img`, 50 Hz, `SYNC_MODE=0xfe`) against the US image (60 Hz, `0xfc`): over 600 VBLs the game ran exactly 600 frames in both, also with Link swinging the sword among two stalfos, so `present_frame` and `wait_vbl` hold at 50 Hz and never skip a frame; Link covers the same pixels per frame, so speeds and every frame-counted timer (invincibility, bombs, boomerang, lift) behave the same per frame. The music plays one tick per VBL at 50 Hz (600 of 600) and five of six at 60 Hz (500 of 600), as designed. Nothing uses another clock (no MFP timer, no `_hz_200`): the whole game follows the VBL. Q7 stands: the pace follows the monitor. A 50 Hz machine runs at the PAL NES's own speed with music and game in step; a 60 Hz one runs the game at NTSC speed with the music held to PAL tempo. Not tried: a real PAL STFM.

- [ ] **Memory and reach budget (risk R3).** `AGENTS.md` section 6 documents 32 KB reach limits around `table_anchor` (about 5 KB and 3 KB slack). Eight more dungeons, 20 cave types, many monsters and the title screen will not fit without moving tables or adding a second anchor register. Plan this with M6, not at the end.
- [ ] Extend `screenshot.py` with `--room`/`--level` shortcuts that already exist as `ZELDA_START_ROOM`/`ZELDA_START_UW`, and add a golden-image directory (`atari_st/tests/golden/`) for the screens each package changes.
- [ ] Keep every table a unit test can recompute from the ROM, as the current tests do.

## 4. M1 Hidden bomb, fire and push spots (the visible bug)

### 4.1 Cause

The overworld layout stores six special "marker" squares. Their ST art is a placeholder look, which is the "other symbol" you see.

| Square idx | Primary tile | Marker meaning | Object type | Original draws it as | Reveal trigger |
|---|---|---|---|---|---|
| 38 | `$E5` | pushable rock (Power Bracelet) | `$62` | square idx 19 (`$C8`, rock) | Power Bracelet, push vertically |
| 39 | `$E6` | bombable rock wall | `$63` | square idx 27 (`$D8`, rock face) | bomb explosion in bomb slots |
| 40 | `$E7` | burnable tree | `$64` | square idx 25 (`$C4`, tree) | candle fire |
| 41 | `$E8` | pushable gravestone | `$65` | square idx 20 (`$BC`, gravestone) | push |
| 42 | `$E9` | hidden armos A | `$66` | square idx 44 (`$C0`, armos) | touch/wake |
| 43 | `$EA` | hidden armos B | `$67` | square idx 44 (`$C0`, armos) | touch/wake |

`TileObjectTypes` = `$62..$67` and `TileObjectPrimarySquaresOW` = `$C8 $D8 $C4 $BC $C0 $C0` in `Z_05.asm`. On room load, `CheckTileObject` swaps each marker for the "draws as" square and records the object type plus its X/Y in object slot 11. The port's `build_assets.py::square_to_tiles` draws `primary[idx]` directly, so it paints the marker art. No Q1 screen uses idx 42/43; those are second-quest squares.

### 4.2 Fix, in three layers

Layer A, look (build time, small):
- [ ] In `build_assets.py`, remap squares 38..43 to 19, 27, 25, 20, 44, 44 before building `room_maps.bin`/`metatiles.bin`. A rock face then looks like every other rock face on the screen.
- [ ] Emit a new table `room_secrets.bin`: for each of the 128 rooms, up to one record {type `$62..$67`, tile col, tile row, destination class, stairs-position idx (attribute F bits 4-5), quest filter (F bits 6-7)}. Appendix A1 lists all 54 records; 43 apply to Quest 1 (22 bomb walls, 16 trees, 4 bracelet rocks, 1 gravestone).
- [ ] Unit test: for every room, no tile in the built map comes from squares 38..43, and `room_secrets` has exactly the markers the decoder finds.

Layer B, behaviour (runtime):
- [ ] **Bombs** (`$63`, `UpdateRockWall` in `Z_04.asm`): when the bomb cloud is in the damaging window and overlaps the wall tile, replace it with cave square idx 12 (`$24` floor tile in the opening), play the secret-found tune, set the room flag bit 7. The port's cloud already has a "last 12 frames open a bombable wall" phase for dungeons; reuse it with overworld squares.
- [ ] **Candle fire** (`$64`, `UpdateTree`): when the flame (state `$22`, timer below 2) is at the tree, replace it with stairs idx 18 (`$70`) and set the flag. The blue candle can burn once per screen; the red candle without that limit (item 7). Both use the same trigger.
- [ ] **Power Bracelet rock** (`$62`) and **gravestone** (`$65`) (`UpdateRockOrGravestone`): when Link pushes toward it for the original push time and has the bracelet (rock only), slide it one square, stairs idx 18 appear where it stood. Gravestones need no item.
- [ ] **Armos** (`UpdateArmos`/`InitArmosOrFlyingGhini`): the seven rooms `$24 $0B $1C $22 $34 $3D $4E` with armos X `$E0 $B0 $B0 $30 $40 $90 $A0` and Y `$80`. Room `$24` (E3) drops the Power Bracelet at the armos spot; the other six turn the touched armos into stairs. All seven spots exist in the Q1 layouts (checked against the decoded layouts).
- [ ] **Persistence**: room flag bit 7 = secret found. A found secret is drawn already open the next time you enter. The existing room-flag array in the port is the place to put it.
- [ ] **Quest filter**: attribute F bits 6-7 gate hidden secrets only (`IsQuestSecretMismatch` has just three call sites, all in the rock/tree/wall updaters). Value 1 = Quest 1, value 2 = Quest 2. A Q2-only secret in a Q1 game stays a plain rock or tree. Visible caves are not gated by it. **(verify)** that a Q2-tagged visible cave such as G1 is really absent from the Q1 layout and not just untagged.

Layer C, destination (what the opening leads to): each room's attribute B selects it: 1 to 9 = dungeon, `$10` and up = cave type (`$10` = type `$6A`, so `B>>2` minus `$10` indexes the 20 cave types), `$14` = take-any-road. The table in appendix A1 gives the destination per hidden spot. The position of the entrance stairs after the reveal comes from attribute F bits 4-5 through `LevelInfo_ShortcutOrItemPosArray` (four Y/X choices).

### 4.3 Visible versus hidden, per screen

Of the 128 screens, 54 hold a marker (appendix A1). 23 more have a visible cave or dungeon square (idx 12, appendix A2). Another 15 have a destination but nothing drawn for it (appendix A3): four are opened by armos (M2, E4, N4, O5), one by the Recorder (C5, Level 7), one is probably the waterfall (K2), and nine are Second-Quest-only (they are the Recorder spots: in Quest 2 the Recorder opens them, in Quest 1 it summons the whirlwind there). Two screens that also have an armos secret, L1 (Level 5) and C3 (Level 6), additionally show a cave square. **(verify)** in the original which of the two the First Quest uses; the plan assumes the visible square is the entrance and the armos stairs are the extra route.

### 4.4 Acceptance

- [ ] On the Q1 data, screen by screen: no marker art is visible anywhere (golden screenshots for the screens with a marker).
- [ ] Bombing the rock wall at, for example, B1 col 9 row 1 opens cave type `$71` (door repair); burning the tree at I3 col 13 row 6 shows stairs to the "secret to everybody" cave; both stay open after leaving and returning, and a plain wall next to them does nothing.
- [ ] A bomb that detonates elsewhere on the same screen reveals nothing; the same bomb on the marked wall does.
- [ ] A Q2-tagged spot (for example A1 `Level 9`) does nothing in a Q1 save.

## 5. M2 Overworld enemies

### 5.1 Placement rules (from `Z_05.asm`, around the monster-list code)

- Monster list id = `(attribute C & $3F) | (D bit 7 ? $40 : 0)`. Ids below `$62` are templates (one type repeated); `$62` and up index the `ObjLists` table (a list of types in order).
- Count = `LevelInfoOW foe_counts[C >> 6]` = **1, 4, 5 or 6** on the overworld (**3, 5, 6, 8** in dungeons), forced to 1 for template ids `$32..$61` (bosses and non-recurring things).
- The count is reduced by room history (`ModifyObjCountByHistoryOW`): killing monsters, then leaving and coming back, spawns fewer. **(verify the exact rule in the disassembly before porting.)**
- Spawn spots: nine fixed cells per entry direction (`SpawnPosList0..3`, indexed by Link's direction), cycling through `SpawnCycle`, skipping cells that are not safe (`IsSafeToSpawn`).
- Screens whose attribute F bit 3 is set (**edge-spawn**: O1, L5, N5, O5, C6, H6, I6, L6, M6, N6, B7, C7, I7, L7, M7, N7, B8, C8, D8, I8) do not place anything on entry. Monsters come in from the screen border instead, walking a counter-clockwise ring of cells (`FindNextEdgeSpawnCell`).
- Zoras are a room flag (attribute A bit 3), not monster list entries: 37 screens. Sea sound is attribute A bit 2.
- Kill counters and drops are already done in the port; they need the new monster types plugged into the drop table rows (`mon_table.bin` field "drop row").

### 5.2 Monster behaviours (source routine in `Z_04.asm`/`Z_07.asm`; HP in wooden-sword hits, damage as stored)

The HP and damage columns come from `ObjectTypeToHpPairs` and `ObjTypeToDamagePoints`. Behaviour text is a summary to port from the named routine, not a replacement for reading it.

| Type | Name | HP | Dmg | Routine | Behaviour summary |
|---|---|---|---|---|---|
| `$01`/`$02` | Lynel blue / red | 6 / 4 | 2 hearts / 1 heart | `UpdateLynel` | Walks lanes, turns toward Link, fires sword beams. Blue is tougher. Beams are blocked by a facing shield. |
| `$03`/`$04` | Moblin blue / red | 3 / 2 | half heart | `UpdateMoblin` | Walks lanes, throws arrows (`UpdateMonsterArrow`). |
| `$07`..`$0A` | Octorok red slow, red fast, blue slow, blue fast | 1 / 1 / 2 / 2 | half heart | `UpdateOctorock` | Lane walker, stops and spits a rock in its facing direction. Rocks are blocked by a facing shield. |
| `$0D`/`$0E` | Tektite blue / red | 1 | half heart | `UpdateTektiteOrBoulder` | Crouches, then hops in arcs; random direction. |
| `$0F`/`$10` | Leever blue / red | 4 / 2 | 1 heart / half heart | `UpdateBlueLeever`/`UpdateRedLeever` | Burrowed in sand until Link is near, surfaces, chases, sinks again. Blue lingers longer. |
| `$1A` | Peahat | 2 | half heart | `UpdatePeahat` | Flies over any terrain, drifts toward Link; hurt only while its blades are stopped (**verify** the exact phase). |
| `$11` | Zora | 2 | half heart | `UpdateZora` | Surfaces at a water edge near Link, spits a fireball, dives. Only on the 37 Zora screens. |
| `$1E` | Armos | 3 | 1 heart | `UpdateArmos` | Statue; wakes when touched, walks toward Link. Seven of them hide stairs or the bracelet (M1). |
| `$1F`/`$20` | Boulder set / boulder | n/a | half heart | `UpdateBoulderSet` | Death Mountain: boulders fall down columns; cannot be killed. Screens D1, I1, G2, H2, I2, J2. |
| `$21`/`$22` | Ghini / flying Ghini | 9 / n/a | 1 heart | `UpdateGhini`/`UpdateFlyingGhini` | Graveyard (A3 to B5). **verify** wake-up and ringleader rules. |
| `$2F` | Pond fairy | n/a | none | `UpdatePondFairy` | See section 6.4. |
| `$2E` | Whirlwind | n/a | none | `UpdateWhirlwind` | Recorder effect, section 7. |

### 5.3 Where every overworld enemy is

Appendix B1 lists every screen with its monsters and count, plus the Zora, edge-spawn and sea flags. Appendix B2 inverts it: per type, the screens it appears on.

### 5.4 Work items

- [x] **Step 1 (done): data plus plain walkers.** Octorok (`$07`-`$0A`), moblin (`$03`, `$04`) and lynel (`$01`, `$02`) are in `MONSTER_TYPES`; octoroks have their own draw mode (`MODE_OCTOROK`: side, front and back views in two animation sets, art mirrored to face right) and `mon_art` says where each monster's art starts in `mon_sprites` (the slow and fast octorok share it). Red/blue octoroks turn at `$70`/`$A0`, moblins `$A0`, lynels walk like goriyas without throwing. Every overworld screen has a 16-byte record in `ow_room_info.bin` (count, flags for edge-spawn and Zora, monster indices), expanded from the ROM's monster lists. Peahats, leevers, zoras, ghinis, armos, boulders and tektites spawn nothing yet.
- [x] **Step 2 (done): projectiles, edge-spawn ring, kill history.** `walker_shoot`/`walker_fire` (`ai.s`) follow `_TryShooting`: shoot timer `$30`, shot at `$10`, red types start only on a random `>= $F8`, at most 4 shots; rock and sword shot fly 3 px/frame, the arrow 2; damage 1 half-heart (rock, arrow) or 4 (sword shot); Link parries rock and arrow with the sword facing them while standing still (bounce 16 frames); rock and arrow stop at walls, the sword shot does not. `proj_sprites` has 32 frames (rock `PF_ROCK`, arrows `PF_ARROW`). Drops use the ROM rows already in `mon_table` (fairy and clock pickups are still missing). Screens flagged for edge spawning (`FindNextEdgeSpawnCell`) bring monsters in one by one over the border (`edge_spawn_tick`), and `ow_history_count`/`ow_save_kills` keep the last six screens and their kill counts (`ModifyObjCountByHistoryOW`, `SaveKillCountOW`); dying clears the history. Checked in Hatari: kills 2 of 4 in `$78`, leave and return, 2 come back.
- [x] **Step 3 (done): special movers** (`src/movers.s`). Tektite and boulder share `UpdateTektiteOrBoulder` jump physics (`jumper_*` tables from the ROM); blue leever wanders and burrows, red leever surfaces 40 px ahead of or behind Link (`red_leever_place`); peahat is `MoveFlyer` with the `$B0`/`$20` rolls, hittable only in state 5; zora is made by `zora_check` on screens with water (13 tries on tiles `$8D`-`$98`), fires one fireball and is untouchable unless it is up; ghini is the wanderer with `$FF`; boulders come from the boulder set (`$1F`). Weapons pass through anything with `ENEMY_GHOST` bit 0 set, bit 1 means it harms nobody. The room spawn list now cycles like `AssignObjSpawnPositions` (it used to give up after nine spots, so peahat screens came up short).
- [ ] (original item, kept for reference) Add each type to `MONSTER_TYPES` in `actors.py` with the HP/damage above, sprite frames from the CHR data, a draw mode and a behaviour in `ai.s` (recipe in `AGENTS.md` section 12).
- [ ] Overworld sprite pattern tables: unlike the underworld, the overworld swaps pattern blocks by region. List the blocks needed (octorok/moblin/lynel/tektite/leever/peahat/zora/ghini/armos/boulders) and load them at room entry.
- [ ] Build `room_monsters.bin` for the overworld the same way `actors.py` builds it for dungeon rooms, including the edge-spawn flag and the Zora flag.
- [ ] Drops: extend the drop table rows for every new type; fairy (kill 16) and clock drops need their pickups (section 8).
- [x] Projectiles: rock, arrow, sword shot done (M2 step 2); fireball still placeholder art.
- [ ] Acceptance: screenshot a screen of each type with the monster present; unit test that every screen's list expands to the same types as appendix B1; Hatari scripts that check one behaviour per type (for example a Leever surfacing within N frames of Link standing in sand).

## 6. M3 Caves, shops and people

All 20 overworld cave types are listed with their ROM text, items, prices and screens in appendix C. Cave type = `$6A + index`; an overworld screen's attribute B (`>> 2`, minus `$10`) picks the index.

### 6.1 Cave record and flags

Each cave has three item bytes and three prices in `LevelBlockOW` attribute E (`E[i*3..]`, prices at `E[60+i*3..]`) plus a text selector byte. The top two bits of each of those four bytes are flag bits; `InitCave` combines them into one `CaveFlags` byte:

| Bit | Meaning | Taken from |
|---|---|---|
| `$01` | choose / pick up one item | text selector bits 7-6 (`$40` pick up, `$80` pay) |
| `$02` | pay for it | text selector, `$80` |
| `$04` | show the items | third item byte, `$40` |
| `$08` | show prices | third item byte, `$80` |
| `$10` | hint-giver | second item byte, `$40` |
| `$20` | money game | second item byte, `$80` |
| `$40` | heart requirement (5 containers for the white sword, 12 for the magical sword) | first item byte, `$40` |
| `$80` | negative amounts | first item byte, `$80` |

Three item slots are drawn at X `$58 $78 $98`; the person stands at (`$78`, `$80`). Cave rooms use game modes `$B`/`$C` (enter/exit), cellars mode `9`.

### 6.2 What each cave does

- [x] `$6A` start cave (H8): "IT'S DANGEROUS TO GO ALONE! TAKE THIS." gives the Wooden Sword free. Already done.
- [ ] `$6B` "TAKE ANY ONE YOU WANT": Red Potion (left) or Heart Container (right), free, take one and the other vanishes. Q1 screens: P3, M3, H5, L8 (appendix C). **(verify)** the left item is the second potion, not a different potion id.
- [ ] `$6C` White Sword (K1): needs 5 heart containers. `$6D` Magical Sword (B3 in Q1, behind a pushable gravestone): needs 12.
- [ ] `$6E` "TAKE ANY ROAD YOU WANT": four Power-Bracelet-rock caves (N2, D3, J5, J8). Entering sends Link to the next of the four rooms `$1D $23 $49 $79` (the four-entry shortcut array in the overworld level info); the choice depends on which of the three exits he takes.
- [ ] `$6F` (M2): "SECRET IS IN THE TREE AT THE DEAD-END."
- [ ] `$70` money game: you need at least 10 rupees; three boxes show +/- amounts picked from a random permutation; picking 20 or 50 adds, anything else subtracts. Six screens.
- [ ] `$71` door repair: 20 rupees are taken once per room (the room flag is set so it does not repeat). Ten screens.
- [ ] `$72` Letter, "SHOW THIS TO THE OLD WOMAN" (O1; B2 is Q2).
- [ ] `$73` "MEET THE OLD MAN AT THE GRAVE." (F8).
- [ ] `$74` potion shop, "BUY MEDICINE BEFORE YOU GO": Blue (Life) Potion 40, Red (2nd) Potion 68. Needs the Letter shown first (the letter is used from the B-item box; it changes the selected slot to the potion). **(verify)** exactly when the old woman appears and when she refuses.
- [ ] `$75` (K2) and `$76` (A8) "PAY ME AND I'LL TALK": three prices (5/10/20 and 10/30/50); which price you pay picks the text. K2 (5/10/20): the first two say "THIS AIN'T ENOUGH TO TALK.", 20 says "GO UP,UP, THE MOUNTAIN AHEAD." (Lost Hills). A8 (10/30/50): 10 says "THIS AIN'T ENOUGH...", 30 says "GO NORTH,WEST,SOUTH, WEST TO THE FOREST OF MAZE." (Lost Woods), 50 says "BOY, YOU'RE RICH!". Mapping read from `HintCaveTextSelectors0/1`. **(verify)** whether the "not enough" answers still take the rupees.
- [ ] `$77`, `$78`, `$79`, `$7A` shops "BUY SOMETHIN' WILL YA!" / "BOY, THIS IS REALLY EXPENSIVE!": Magical Shield (160 / 130 / 90), Bombs 20, Arrow 80, Key (100 / 80), Blue Candle 60, Bait (100 / 60), Small Heart 10, Blue Ring 250.
- [ ] `$7B`, `$7C`, `$7D` "IT'S A SECRET TO EVERYBODY": free rupees, 30, 100 or 10 depending on the type. Eighteen screens.
- [ ] Persistence rules: types `$6A`..`$6D`, `$72` and `$7B`+ remember "taken" in the room flags; the shop types do not.
- [ ] Text: the 38 ROM texts are in `texts.json` (appendix E). They use the NES text codes; the port already has `text_glyphs` and `menu_text`.
- [ ] Rupee/price HUD: `FormatDecimalByte` style three-digit prices, the rupee icon at (`$30`, `$AB`), and the `RupeesToAdd`/`RupeesToSubtract` drip counters (the counter ticks up or down one per frame with a sound, not instantly).
- [ ] Acceptance: one scripted Hatari run per cave type; unit test that the table `cave_table.bin` equals the ROM bytes.

### 6.3 Dungeon people

Done (#14): the Level 1 old man in room `$41`; the other levels' old men come with their levels (the speech is picked per level from the ROM). Old men in dungeons (types `$4B..$52`) say one hint each (texts appear per level in the appendix D tables). Special ones: the bomb-capacity men in Level 5 (`$17`) and Level 7 (`$48`) (type `$4F`, an offer flagged as taken in the room once used), the Level 9 entrance man (shutters open once all eight triforce pieces are held), the "life or money" man (`$51`, trigger 6), the rupee-stash rooms (`$35`), and Grumble (`$36`, level 7, blocks a door until given bait).

### 6.4 Fairy fountains ("fairy mother")

The original has two **fairy ponds**: J4 (`$39`) and D5 (`$43`), overworld monster type `$2F` (`UpdatePondFairy`). Link walks to the pond edge (Y `$AD`, X `$70..$80`), is held in place, hearts fly up around the fairy while all his hearts refill, then he is released. The fairy lives only on those two screens. There is no character called "fairy mother" in this ROM; I take your request to mean these fountains. You confirmed this (decision Q1 in section 13.1).

- [ ] `UpdatePondFairy` states 0 to 3 (wait at edge, fill hearts, show hearts for `$50` frames, release), the circling heart sprites, the water palette.
- [ ] Heart refill uses `World_IsFillingHearts` (a per-frame fill with the heart-beep sound).
- [ ] Fairy item `$23` (drop after 16 kills) is a separate thing: it flies to Link and refills hearts **(verify the amount)**. The kill-counter code is done; the pickup and art are not.
- [ ] Text hint in the ROM that relates: "THERE ARE SECRETS WHERE FAIRIES DON'T LIVE." (Level 6 old man).

## 7. M4 Overworld specials

- [ ] **Power Bracelet rocks** (7 in the data; the 4 that apply to Quest 1 hide the take-any-road caves N2, D3, J5, J8; J1, B2 and L2 are Quest 2 only): push vertically with the bracelet. Needs the Power Bracelet from armos at E3.
- [ ] **Gravestones** (A3 is Quest 2 only, B3 is Quest 1 and hides the Magical Sword cave): push to reveal stairs.
- [ ] **Armos**: waking behaviour, the seven secret spots (M1), the Power Bracelet drop at E3, 12 armos screens (L1 8, E2 8, M2 8, C3 12, E3 10, F3 8, D4 10, E4 6, M4 8, N4 2, O5 2, E8 8).
- [ ] **Candle trees** (18 in the data: 12 both quests, 4 Q1 only, 2 Q2 only) and **bomb walls** (27: 16 both, 6 Q1 only, 5 Q2 only); see M1. A Quest 1 game uses 16 trees and 22 bomb walls.
- [ ] **Raft and docks**: dock objects (`UpdateDock`, `$61`) at P4 (`$3F`) and F6 (`$55`) (`SetupTileObjectOW`); needs the Raft (item `$0C`); moving along a ferry route over water.
- [ ] **Overworld heart container item** on P6 (`$5F`): a free-standing item at X `$C0`, Y `$90`, created by `CreateRoomObjects` only in overworld mode and only in that room; it sits on water and needs the Stepladder. Not a cave.
- [ ] **Stepladder**: the six ladder screens `LadderRoomsOW` = `$17 $18 $19 $27 $4F $5F` (H2, I2, J2, H3, P5, P6); the ladder appears under Link when he walks onto a gap, and allows one-square water crossings (`ObjectFirstUnwalkableTile` logic, drawing at `LadderSlot`).
- [ ] **Recorder** (`WieldFlute`): in screen C5 (`$42`) it starts the pond colour cycle (12 steps) and raises the Level 7 stairs at col 6 row 9. In ten other Q1 screens (`FluteRoomSecretsOW`: `$06 $29 $2B $30 $3A $3C $58 $60 $6E $72`) it summons the **whirlwind**, which carries Link to the entrance of a dungeon whose triforce piece he owns, cycling by facing direction (`SummonWhirlwind`, `TeleportYs`). Whirlwind object `$2E`.
- [ ] **Lost Woods** (screen `$61`, B7): leave by going up, left, down, left in that order; a wrong move sends you back in; exit east is always allowed. **Lost Hills** (screen `$1B`, L2): go up four times; exit west is always allowed. Both play a secret tune on success (`CheckMazes`, `ForestMazeDirs` `08 02 04 02`, `MountainMazeDirs` `08 08 08 08`; direction bits 1 right, 2 left, 4 down, 8 up).
- [ ] **Zoras**: 37 screens, water enemy, section 5.
- [ ] **Boulders** (Death Mountain), **waterfall** (K2, walk into it **(verify)**), **sea sound** on 17 screens.
- [ ] **Screen-edge exits and wrapping**: the port already has the 128-screen walk; check `exit_x`/`exit_row` per screen (attributes A and F) for the cave-exit position.
- [ ] Acceptance: Hatari scripts per mechanic (bracelet push, ladder across H2, raft ride at P4, recorder in C5, maze sequence in B7).

## 8. M5 Items, inventory and HUD

### 8.1 Every item you can collect

Item ids are those of `ItemIdToSlot` in `Z_01.asm`; `00..23` hex. "Where" uses the Q1 data.

| Id | Item | Where it comes from | Notes |
|---|---|---|---|
| `$00` | Bombs | shop 20 rupees; dungeon rooms; drops | +4, max 8; capacity upgrade men in Levels 5 and 7 |
| `$01` | Wooden Sword | cave H8 | done |
| `$02` | White Sword | cave K1 | 5 containers |
| `$03` | Magical Sword | cave B3 (gravestone) | 12 containers; id 3 also means "no item" in dungeon rooms |
| `$04` | Bait | shops 100 / 60 | feeds Grumble and distracts monsters |
| `$05` | Recorder | Level 5 stairs room `$04` | see section 7 |
| `$06` | Blue Candle | shop 60 | one flame per screen; lights dark rooms **(verify)** |
| `$07` | Red Candle | Level 7 stairs room `$4A` | unlimited flames |
| `$08` | Arrow | shop 80 | needs the Bow; costs 1 rupee a shot |
| `$09` | Silver Arrow | Level 9 stairs room `$4F` | strong arrows; Ganon |
| `$0A` | Bow | Level 1 stairs room `$7F` | done as a pickup |
| `$0B` | Magical Key | Level 8 stairs room `$0F` | opens every locked door |
| `$0C` | Raft | Level 3 stairs room `$0F`, entered by the stairs in room `$69` (the eight-Darknut room) | confirmed by the Zelda Dungeon Level 3 walkthrough; the room's destination attributes (A and B = `$69`) hold the link, see 9.1 |
| `$0D` | Stepladder | Level 4 stairs room `$60` | |
| `$0E` | Triforce of Power | Ganon's room `$42` | |
| `$0F` | 5 Rupees | dungeon rooms, drops | |
| `$10` | Magical Rod | Level 6 stairs room `$75` | shoots a beam; with the Book it shoots fire |
| `$11` | Book of Magic | Level 8 stairs room `$6F` | |
| `$12` | Blue Ring | shop 250 (E4, behind armos) | half damage |
| `$13` | Red Ring | Level 9 stairs room `$00` | quarter damage |
| `$14` | Power Bracelet | armos at E3 | |
| `$15` | Letter | cave O1 | to the old woman |
| `$16` | Compass | each dungeon | shows the triforce room |
| `$17` | Map | each dungeon | reveals the layout; Level 9 uses the "9" slots |
| `$18` | Rupee | drops, caves | |
| `$19` | Key | dungeons, shop 100 / 80 | |
| `$1A` | Heart Container | 8 dungeon rooms (appendix D); 4 caves of type `$6B` (P3, M3, H5, L8); 1 floating item on screen P6 (`$5F`, X `$C0`, Y `$90`, reached with the Stepladder) | 13 in total, so 3 + 13 = 16 hearts; matches the Zelda Dungeon heart container page |
| `$1B` | Triforce piece | rooms in appendix D | eight, one per dungeon |
| `$1C` | Magical Shield | shops 160 / 130 / 90 | blocks magic and rocks |
| `$1D` | Boomerang | Level 1 room `$44` | done |
| `$1E` | Magical Boomerang | Level 2 room `$4F` | longer range |
| `$1F` | Blue (Life) Potion | potion shop 40 | |
| `$20` | Red (2nd) Potion | potion shop 68; cave `$6B` | |
| `$21` | Clock | drop | freezes monsters |
| `$22` | Small Heart | drop; shop 10 | |
| `$23` | Fairy | drop | |

Also tracked in the inventory (not items): rupees, keys, hearts and partial heart, `MaxBombs`, the `InvTriforce` bit set, `InvMap`/`InvCompass` (+ "9" versions), the Letter state (0, 1, 2).

### 8.2 Work items

- [ ] Done for bombs, wooden sword, blue candle, bow, boomerang, rupee, 5 rupees, key, heart container, triforce piece, compass, map and heart (the Level 1 set); still to do for the rest: `take_item` in `combat.s` for each id; `ITEM_IDS` in `actors.py`; icons for the inventory and for floor items (the NES draws narrow, slim and wide items differently; see `AGENTS.md` section 11).
- [ ] Done: bombs, boomerang and candle as B items; the Tab screen lists them with the map, the compass and the bow (not yet a B item). Still to do: B-item list: bombs, boomerang(s), bow and arrow pair, candle(s), recorder, bait, letter/potion, rod (and book). The Tab screen needs the real layout (eight B slots, passive items on the right, triforce frame, map and compass when owned). `DrawSubmenuItems`, `SubmenuItemXs` in `Z_05.asm` give positions.
- [ ] Passive effects: shield size, rings (damage division in `Link_BeHarmed`), Power Bracelet, Raft, Ladder, Magical Key, Book of Magic, white/magic sword damage and beam range.
- [ ] Done: heart containers from the dungeon, the half-heart damage unit, the low-hearts beep, refill at the triforce. Still to do: container count up to 16, partial heart, low-hearts beep, the half-heart damage unit `$80`, refill by fairy or pond.
- [ ] Bomb capacity upgrade and `MaxBombs` handling.
- [x] HUD: the minimap on the ribbon in dungeons (map/compass, #12), the level label, the B/A boxes, key count, bomb count, rupee count. (The overworld has no map on the ribbon yet.)
- [ ] Acceptance: a debug key that gives every item; one golden screenshot of a full inventory screen; unit test that every id has a descriptor row.

## 9. M6 Dungeon engine and levels 2 to 9

### 9.1 General systems still to generalise

- [ ] Palettes, start room/Y, triforce room and the minimap window are built for Level 1 (`UW_*` equates, #12, #18); still to do for the rest: Level load: per-level info block (palettes, pattern block, foe counts, start room/Y, triforce room, cellar array of up to ten rooms, boss room, minimap rotation/mask). Level info bytes are at `LevelInfo_*` in `Variables.inc`.
- [ ] **Dark rooms** (attribute E bit 7): Level 4 has seven, Level 5 five, Level 6 six, Level 7 three, Level 8 four, Level 9 ten (appendix D). The screen stays dark until a candle flame lights it **(verify)**.
- [ ] **Boss roar** (attribute E bits 5-6): 1 Dodongo-type sound, 2 Digdogger-type, 3 Gleeok-type, plays while the boss room is entered and the boss lives (`CheckBossSoundEffectUW`).
- [ ] **Secret triggers** (attribute F bits 0-2): 0 none; 1 kill all, shutters open; 2 kill the ringleader, shutters open; 3 last boss; 4 push block, door opens; 5 push block, stairs open (not in Level 1); 6 life-or-money; 7 kill all, item appears.
- [ ] **Door types**: open, wall, locked, shutter, bombable (false wall), key; the port has them for Level 1. Check that every level uses only these.
- [ ] **Stair links come from the data, not the info array.** Level 3's cellar array in the level info is empty, yet its raft stairs work in the original. The port should build every stair link from the destination attributes (A = left stairs, B = right stairs) of each layout-62 or layout-63 room and the stair square in the room that holds it, instead of relying on `CellarRoomIdArray`.
- [ ] **Stair rooms**: layout 62 joins two dungeon rooms (left stairs use attribute A as destination, right stairs use B); layout 63 is an item cellar with four blue keese. The cellar array (up to ten rooms) holds them; Level 9 has eight.
- [ ] **Level 9 entry**: all eight triforce pieces needed (`InvTriforce == $FF`).
- [ ] **Per-level palette** is done for all nine levels (#18: `level_palettes`, `palette_sync`); pattern blocks, per-level monster art and the death-palette series are not. **Per-level palette and pattern blocks** (risk R1): load at level entry. Death-palette series (`LevelInfo_DeathPaletteSeries`).
- [ ] Map reveal and the room flags for items, doors and shutters work in Level 1 (#12). Still to do: **Whirlwind exit**, **map reveal**, **visited rooms** (rooms marked visited on the Map), **room flags** (item taken, boss dead, door opened).
- [x] **End-of-level sequence** (mode `$12`), done in #11 as `ending_update` (hold 48 frames, white flash 48, hearts fill, curtain, 128-frame pause, back to the entrance): hold the triforce piece overhead, curtain closing, music, return to the dungeon entrance on the overworld. Marked open in `AGENTS.md`. The triforce fanfare (`MUS_TRIFORCE`) already plays on pickup; the sequence should time itself to it instead of `TRIFORCE_FRAMES`.

### 9.2 Collectibles, dark rooms, bosses and people per level

(Detailed room tables are in appendix D. Room numbers are hex; stair rooms are marked.)

| Level | Collectibles (item: rooms) | Dark rooms | Bosses and mini-bosses (room) | Old men / special people |
|---|---|---|---|---|
| 1 | Boomerang: $44; Bow: $7F (stairs); Compass: $54; Heart Container: $35; Map: $43; Triforce piece: $36; Key: $23, $33, $45, $53, $72, $74 | - | Aquamentus ($35) | $41: old man: "EASTMOST PENNINSULA / IS THE SECRET." |
| 2 | Compass: $6F; Heart Container: $0E; Magical Boomerang: $4F; Map: $5F; Triforce piece: $0D; 5 Rupees: $2F; Bombs: $1E, $3F; Key: $3E, $4E, $6C, $7E | - | Dodongo (2) ($0E); Moldorm ($3E) | $1F: old man: "DODONGO DISLIKES SMOKE." |
| 3 | Compass: $5A; Heart Container: $4D; Map: $4C; Raft: $0F (stairs); Triforce piece: $3D; 5 Rupees: $5D; Bombs: $4A, $5B, $69; Key: $2A, $49, $4B, $6B, $7B | - | Manhandla ($4D) | $2B: old man: "DID YOU GET THE SWORD / FROM THE OLD MAN ON / TOP OF THE WATERFALL?" |
| 4 | Compass: $62; Heart Container: $13; Map: $21; Stepladder: $60 (stairs); Triforce piece: $03; Key: $01, $40, $51, $70 | $01, $02, $21, $30, $40, $50, $62 | Manhandla ($10); Gleeok (3 heads) ($13) | $00: old man: "WALK INTO THE / WATERFALL."; $11: Rupee stash |
| 5 | Compass: $37; Heart Container: $24; Map: $46; Recorder: $04 (stairs); Triforce piece: $14; 5 Rupees: $57; Bombs: $56, $65; Key: $16, $26, $27, $47, $55, $66, $77 | $27, $37, $46, $57, $66 | Digdogger (2) ($24); Dodongo (1) ($56) | $15: old man: "SECRET POWER IS SAID / TO BE IN THE ARROW."; $17: old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS."; $67: old man: "DIGDOGGER HATES / CERTAIN KIND OF SOUND." |
| 6 | Compass: $68; Heart Container: $1C; Magical Rod: $75 (stairs); Map: $19; Triforce piece: $0C; 5 Rupees: $28; Bombs: $3C; Key: $1A, $29, $2D, $58, $7A | $1A, $29, $2D, $39, $3C, $7A | Gleeok (4 heads) ($18); Gohma (blue) ($1C) | $0B: old man: "THERE ARE SECRETS WHERE / FAIRIES DON'T LIVE."; $6A: old man: "AIM AT THE EYES / OF GOHMA." |
| 7 | Compass: $5A; Heart Container: $2A; Map: $18; Red Candle: $4A (stairs); Triforce piece: $2B; 5 Rupees: $09, $38, $58; Bombs: $0B, $0C, $1B, $68, $69, $6C, $7A; Key: $0A, $3A, $6D, $78 | $18, $5A, $6A | Moldorm ($0B); Dodongo (1) ($0C); Digdogger (1) ($1C); Aquamentus ($2A); Digdogger (1) ($39); Moldorm ($3A); Dodongo (1) ($58); Digdogger (2) ($6C); Moldorm ($7A) | $08: Rupee stash; $28: Grumble (the 'Grumble, grumble' man); $48: old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS."; $5B: old man: "THERE'S A SECRET IN / THE TIP OF THE NOSE." |
| 8 | Book of Magic: $6F (stairs); Compass: $5F; Heart Container: $3C; Magical Key: $0F (stairs); Map: $2E; Triforce piece: $2C; 5 Rupees: $4E, $6E, $7D; Bombs: $0E, $1D, $3F; Key: $4B, $4C, $5C, $5D, $5E, $7F | $4B, $5D, $5F, $7F | Gohma (red) ($1E); Manhandla ($2E); Gleeok (1 head) ($3C); Gohma (red) ($4D); Manhandla ($6E); Manhandla ($7D) | $2D: Rupee stash; $3B: old man: "10TH ENEMY HAS THE BOMB."; $3D: old man: "SPECTACLE ROCK IS / AN ENTRANCE TO DEATH." |
| 9 | Compass: $35; Map: $27; Red Ring: $00 (stairs); Silver Arrow: $4F (stairs); Triforce of Power: $42; 5 Rupees: $12, $15, $26, $34, $40, $44, $62; Bombs: $11, $16, $23, $25, $37; Key: $47, $56, $57, $61 | $01, $13, $15, $24, $33, $41, $42, $50, $57, $65 | Lanmola (blue) ($11); Lanmola (red) ($12); Patra (2) ($16); Patra (1) ($21); Patra (2) ($27); Zelda ($32); Ganon ($42); Patra (1) ($52); Lanmola (red) ($55); Patra (1) ($61); Lanmola (blue) ($74) | $02: old man: "EYES OF SKULL / HAS A SECRET."; $06: old man: "GO TO THE NEXT ROOM."; $43: old man: "PATRA HAS THE MAP."; $66: old man: "ONES WHO DOES NOT HAVE / TRIFORCE CAN'T GO IN." |

### 9.3 Notes per level (what is special)

- **Level 1** (done, including the triforce sequence, the bow cellar and the push-block rooms): the old man at `$41` is in too (speech, flames, blocking; no fireballs) (the map and compass, the dungeon minimap on the ribbon and the Tab screen are in).
- **Level 2**: Dodongo boss room `$0E` takes bombs; Moldorm mini-boss `$3E`; Magical Boomerang from the Goriya room `$4F`; eight rope rooms.
- **Level 3**: Manhandla boss; the Raft is down the stairs in the eight-Darknut room `$69` (stairs room `$0F`); the old man asks about "the sword from the old man on top of the waterfall".
- **Level 4**: seven dark rooms; Vire and Zol rooms; Manhandla at `$10` then Gleeok (3 heads) at `$13`; stepladder in the cellar `$60`.
- **Level 5**: Recorder in cellar `$04`; Digdogger boss (needs the recorder); Dodongo room `$56`; Gibdo and Pols Voice rooms; Darknut rooms; a bomb capacity man at `$17`.
- **Level 6**: Magical Rod in cellar `$75`; Wizzrobe-heavy; Gleeok (4 heads) mini-boss `$18`; Gohma (blue) boss `$1C`; Like Like rooms.
- **Level 7**: Red Candle in cellar `$4A`; Grumble room `$28`; three Digdogger rooms, three Dodongo rooms, three Moldorm rooms; Aquamentus boss `$2A`; bomb capacity man `$48`; 33 rooms.
- **Level 8**: Magical Key `$0F` and Book of Magic `$6F` in cellars; Gohma (red) twice; Manhandla three times; Gleeok (1 head) boss `$3C`; Darknut-heavy; the "life or money" man.
- **Level 9**: 57 rooms plus eight stair rooms; Lanmola rooms; Patra rooms; Ganon `$42` (drops the Triforce of Power); Zelda `$32`; Silver Arrow `$4F` and Red Ring `$00` in cellars; entrance man needs all eight triforce pieces.

### 9.4 Acceptance

- [ ] For every level: reachability script (from the start room, collect keys and items by scripted inputs) proves all rooms can be reached; golden screenshot of each room's door and wall set (compare the room-render diff tool `compare_render.py`).
- [ ] The decoded reachable set equals the walkthrough room counts **(verify)** against the zeldadungeon pages listed in `AGENTS.md`.

## 10. M7 Dungeon monsters and M8 bosses

### 10.1 Underworld monsters

| Type | Name | HP | Dmg | Routine | Behaviour summary |
|---|---|---|---|---|---|
| `$05`/`$06` | Goriya blue / red | 5 / 3 | 1 heart / half | `UpdateGoriya` | Walks, throws a boomerang that returns. Done for red (#15: facing and throw rolls as in the ROM). |
| `$0B`/`$0C` | Darknut red / blue | 4 / 8 | 1 / 2 hearts | `UpdateDarknut` | Armoured: front hits blocked, side or back hurts; blue is tougher. |
| `$12` | Vire | 4 | 1 heart | `UpdateVire` | Hops; splits into two Keese when killed. |
| `$13` | Zol | 2 | 1 heart | `UpdateZol` | Slow; splits into two Gel when killed. |
| `$14`/`$15` | Gel | 0 | half | `UpdateGel` | Small hopper; dies to anything. Done (#15: 1 px/frame with the rests of `ZolGelDelays`). |
| `$16` | Pols Voice | 10 | 2 hearts | `UpdatePolsVoice` | Jumps; killed by arrows (sword hurts little) **(verify)**. |
| `$17` | Like Like | 9 | 1 heart | `UpdateLikeLike` | Swallows Link and eats the Magical Shield. |
| `$1B`..`$1D` | Keese blue / red / black | 0 | half | `UpdateKeese` | Done for blue. |
| `$23`/`$24` | Wizzrobe blue / red | 10 / 4 | 2 / 1 hearts | `UpdateBlueWizzrobe`/`UpdateRedWizzrobe` | Appears, shoots magic, vanishes and reappears elsewhere (red); the blue one is tougher and moves differently **(verify both patterns in `Z_04.asm`)**. |
| `$27` | Wallmaster | 2 | half | `UpdateWallmaster` | Comes out of walls, carries Link to the dungeon entrance. Done. |
| `$28` | Rope | 1 | half | `UpdateRope` | Charges along rows/columns. Done (#15: turns and rush from tile boundaries). |
| `$2A` | Stalfos | 2 | half | `UpdateStalfos` | Done. |
| `$2B`..`$2D` | Bubble black / blue / red | n/a | none | `UpdateBubble` | Bounces around; contact stops Link from using the sword for a while, the colour decides how **(verify)**. |
| `$30` | Gibdo | 7 | 2 hearts | `UpdateGibdo` | Slow mummy. |
| `$49`/`$4A` | Trap 6 / 4 | n/a | 1 heart | `UpdateTrap` | Done. |
| `$3F`/`$40` | Guard fire / standing fire | 1 / n/a | half | `UpdateGuardFire`, `UpdateStandingFire` | Fire in "life or money" and other rooms. |

### 10.2 Bosses

| Boss | Type | HP | Dmg | Where | Behaviour summary | What hurts it |
|---|---|---|---|---|---|---|
| Aquamentus | `$3D` | 6 | 1 heart | Level 1 `$35`, Level 7 `$2A` | Walks sideways, spits three fireballs in a spread. Done for Level 1. | sword to the head |
| Dodongo | `$31`/`$32` | 15 (special) | 1 heart | Level 2 `$0E` (one), Levels 5 `$56` and 7 `$0C`, `$58` (three each) | Swallows bombs, bloats, explodes. | bombs in the mouth; sword when stunned **(verify)** |
| Manhandla | `$3C` | 4 | 1 heart | Level 3 `$4D`, Level 4 `$10`, Level 8 `$2E`, `$6E`, `$7D` | Four hands that speed up as they are killed. | sword on the hands |
| Gohma | `$33`/`$34` | 6 / 2 | 2 hearts | Level 6 boss `$1C` (blue), Level 8 `$1E`, `$4D` (red) | Crab with an eye that opens; shoots fireballs. | arrows on the open eye |
| Digdogger | `$38`/`$39` | 15 (special) | 2 hearts | Level 5 `$24`, Level 7 `$1C`, `$39`, `$6C` | Big one splits into small ones when the recorder plays. | the Recorder, then sword on the small ones |
| Gleeok | `$42`..`$45`, heads `$46` | 10 | 1 heart | Level 4 `$13` (3 heads), Level 6 `$18` (4), Level 8 `$3C` (1) | Dragon whose heads detach and fly; neck must be hit. | sword on the neck |
| Moldorm | `$41` | 2 | half | Level 2 `$3E`, Level 7 `$0B`, `$3A`, `$7A` | Segmented worm moving at the walls. | sword on the tail |
| Lanmola | `$3A`/`$3B` | 2 | 2 hearts | Level 9 `$11`, `$12`, `$55`, `$74` | Sand worm that bursts out of the floor in a chain. | sword on the head |
| Patra | `$47`/`$48`, children `$25`/`$26` | 11 | 2 hearts | Level 9 `$16`, `$21`, `$27`, `$52`, `$61` | Eye ringed by children. | sword on the eye after the children |
| Ganon | `$3E` | 15 (special) | 4 hearts | Level 9 `$42` | Teleporting; invisible until hurt; throws fire. | Silver Arrow to finish |
| Zelda | `$37` | n/a | none | Level 9 `$32` | The end scene; drives the win-game mode. | n/a |
| Rupee stash | `$35` | n/a | none | Levels 4 `$11`, 7 `$08`, 8 `$2D` | A room full of rupees; **(verify)** the trigger. | |
| Grumble | `$36` | n/a | none | Level 7 `$28` | Fed with bait. | Bait |

"15" in the HP column marks a monster that uses a special hit rule in the original. HP units are wooden-sword hits.

### 10.3 Work items

- [ ] For each type: sprite frames, behaviour routine, hit rule, drop row, test.
- [ ] Boss music and roars, boss-dead flag and the heart container or triforce that appears after (secret trigger 7 and 3). `MUS_GANON` is in the music bank; the roars are DPCM or noise effects that are not ripped yet.
- [ ] Gleeok head object (`UpdateGleeokHead`), Patra child orbit, Moldorm segment chain: these need new multi-object structures in `enemy.s`.
- [ ] Acceptance: one scripted fight per boss in Hatari with the dev-start variable for that room; check the kill sets the room flag and spawns the reward.

## 11. M10 Title, player select, save and ending

### 11.1 Title and intro (game mode 0, `Z_02.asm`)

- Phase 0: title picture, animated waterfall (`UpdateWaterfallAnimation`, wave and crest sprites), glowing triforce (`TriforceGlowingColors`), the title song. Press Start skips.
- Phase 1: the story scroll: lines of text scroll up the screen (`DemoLineAttrs`, `DemoLineTextAddrs`), then a parade of the items on both sides (`DemoLeftItemIds`, `DemoRightItemIds`), Link and the stationary fairy, then back to the title. Start at any time goes on to the file menu (mode 1).
- [ ] Palettes for title and story (`TitlePaletteTransferRecord`, `StoryPaletteTransferRecord`, risk R1); nametable data and tiles from the ROM; keep copyright text out of the repo (the pipeline reads it from the ROM at build).
- [ ] Skip logic: `SkippedDemo`, the `TransferredDemoPatterns` flag.

### 11.2 Player select, register, eliminate (modes 1, E, F)

- Mode 1 file menu: three slots, each showing the name (8 chars), hearts, death count and a Link sprite. Cursor sprite, up/down to choose, Start to enter. Fourth and fifth rows: REGISTER YOUR NAME and ELIMINATION MODE.
- Mode E register: a character board (the characters in `ModeE_CharMap`) with a cursor, 8 name characters, an END choice. A new slot starts with 3 heart containers and 2 hearts, max bombs 8. The name `ZELDA` sets the quest number to 1 (Second Quest).
- Mode F elimination: choose a slot to delete (`DeleteSlot` blanks the name and clears the file), END returns to mode E.
- [ ] Controls: Atari equivalents of Start/Select/A/B (the port uses Space for A, Ctrl/Alt for B, Tab for inventory; choose Return for Start and Tab for Select **(Q3)**).
- [ ] Button repeat timing for the character board (`ModeE_HandleDirectionButton`, `ResetButtonRepeatState`).

### 11.3 Save, continue, death

- Save data (per slot): name (8), items block (`$28` bytes, hearts at offsets `$18`/`$19`, max bombs at `$25`), death count, quest number, world flags (`$180` bytes: three blocks, overworld and two dungeon blocks), checksum. The NES writes "file B", validates the checksum, then copies it to "file A" (`UpdateModeDSave`, `CopyFileBToFileA`).
- [ ] **On the ST:** store `ZELDA.SAV` next to the PRG through GEMDOS (Fcreate/Fwrite/Fclose, rename-over for atomic update), read it at startup, show the empty slots if it is missing. This works on a hard-drive or a floppy image; Hatari's hard-drive folder is already used by the test harness.
- [ ] Death (mode `$11`): Link spins and falls, the screen fades, `Death` palette series; death count incremented.
- [ ] Continue question (mode 8): three choices CONTINUE (mode 3, back to the start of the dungeon or the overworld start, with 3 hearts), SAVE (mode D) and RETRY (back to the title). The cursor flashes `$40` frames after Start. Hearts are reset to the minimum after the choice.
- [ ] Autosave points: in the original only the SAVE choice at the continue screen saves; keep that.

### 11.4 Winning

- Music for this and the other screens is already in the bank (`MUS_TITLE`, `MUS_ZELDA`, `MUS_ENDING`, `MUS_GAMEOVER`, hook with `music_event`/`music_play`). Mode `$13`: curtain effect, Zelda's text box "THANKS LINK, YOU'RE THE HERO OF HYRULE...", Link and Zelda holding the triforces, "FINALLY PEACE RETURNS TO HYRULE. THIS ENDS THE STORY.", ash pile where Ganon was, credits (`DrawCredits`), then the game restarts the same slot as a Second Quest profile (`SwitchProfileToSecondQuest` clears world flags and sets the quest number).
- [ ] Credits text is in the ROM; the pipeline reads it from there.

## 12. M11 Sound, M12 polish, M13 Second Quest

- [ ] M11 sound: list every `SongRequest`, `Tune0Request`, `Tune1Request`, `SampleRequest` value in the disassembly; write a YM2149 version for each: title, overworld (done), underworld, boss, death, ending, secret found, item get, level end, low health beep, sword, beam, bomb, hurt, rupee, key, door, boss roar, Zora and water sounds. Use the existing `ym_convert.py` and `music/` player; two AY channels may be needed for effects over music. `tools/nes_music_rip.py` already records all 9 songs, 8 jingles and 7 sound effects from the ROM as `.ym` (noise drums or digidrums, PAL pitch); `tools/music_pack.py` packs them (plus the shipped overworld song) into the bank that `music.s` plays: area music follows the state (overworld, dungeon, level 9, caves silent) and item, triforce, hurt, death, bomb, kill, rupee, key, heart and shutter events are hooked, and so are the Effect-channel sounds (sword, boomerang, flame, stairs, bomb blast, ripped as noise on voice C), the low-life beep, the menu click and the cave text blips. Still open: title, ending, Ganon, Zelda and game-over songs, recorder, parry, magic, sea ambience, boss roars, DPCM samples (`SampleRequest`) and the sounds of enemies that do not exist yet.
- [ ] M12 (PAL 50 Hz checked in #18, the rest open): PAL and speed (R2), performance of 8 enemies plus projectiles at 8 MHz, memory map (R3), full unit test suite update (`test_build_assets.py`, `test_actors.py`), docs update in `AGENTS.md`/`CLAUDE.md` section 14, `README.md`, a `make check` that covers the new tables, a release build (stock TOS PRG).
- [ ] M13 Second Quest (**deferred by your decision, not now**): the ROM contains `LevelBlockUW1Q2`/`UW2Q2` and the overworld patch (`PatchQ2Rooms` in `Z_06.asm`). Different dungeon layouts, item places, entrances and the Q2-tagged secrets in appendix A. Triggered by naming a profile ZELDA or by winning the game.

## 13. Risks, questions for you, and things to verify

### 13.1 Decisions made

| # | Question | Decision |
|---|---|---|
| Q1 | "Fairy mother" | The two fairy fountains, J4 and D5 (section 6.4). |
| Q2 | Second Quest | Not now. First Quest only; M13 is deferred. |
| Q3 | Start and Select keys | Return = Start, Tab = Select. |
| Q4 | Where the Raft is | Down the stairs in Level 3 room `$69` (eight Darknuts), in stairs room `$0F`. Confirmed by the Zelda Dungeon Level 3 walkthrough and by the decoded data: room `$0F` has destinations A = B = `$69`. |
| Q5 | Sixteenth heart | Eight dungeon hearts, four cave hearts (P3, M3, H5, L8) and one item on screen P6 (`$5F`) that needs the Stepladder: 13 containers, 16 hearts. Matches the Zelda Dungeon heart container page. |
| Q6 | Where the plan lives | `atari_st/PLAN.md`, with pointers in `AGENTS.md`, `CLAUDE.md` section 14 and `atari_st/README.md`. |
| Q7 | Pace | Frame-based: the pace follows the monitor (60 Hz = NTSC speed, 50 Hz = PAL speed). Checked in Hatari at 50 Hz (section 3, PAL timing): no dropped frames, music in step. |

### 13.2 Risks

- **R1 Palettes.** Settled for the dungeons: slot-stable per-level palettes (section 3). The title and story screens still need their own rows when they are built.
- **R2 PAL / 50 Hz.** Verified in a 50 Hz Hatari (section 3); a real PAL STFM is untried. The music is tuned for 50 Hz and skips one in six VBLs at 60 Hz.
- **R3 Memory and addressing reach.** After step 2 the anchor sits just before `fx_sprites` (about 5 KB back, 6 KB ahead) and `tools/check_reach.py` fails the build when an `ltab` table is out of the signed 16-bit range (GNU as silently wraps instead). The image now starts with `.data` and the code can grow by about 30 KB (`AGENTS.md` section 6). Eight more levels will not fit without re-planning.
- **R4 Sprite budget.** 16x16 masked sprites with runtime shifting; Gleeok, Patra and Moldorm are multi-object bosses and can blow the frame budget at 8 MHz.
- **R5 Copyright.** All ROM-derived data stays out of the repo. The dump tool and the generated tables here are for planning; commit the tool, not its output.

### 13.3 Everything marked "verify"

1. Visible Q2-tagged caves in the Q1 layout (section 4.2): the quest filter may apply only to hidden secrets.
2. Whether L1 and C3 use the visible cave square or the armos stairs (section 4.3).
3. History-based reduction of monster counts (section 5.1).
4. Peahat vulnerability phase, Ghini rules (section 5.2).
5. Whether the K2 waterfall column (square 54) is the entrance of cave `$75` (section 7).
6. Potion shop and letter rules, hint prices that take money (section 6.2).
7. Take-any-one left item identity (section 6.2).
8. Candle lights dark rooms (section 8.1, 9.1).
9. Underworld behaviour notes: Pols Voice, Wizzrobe, Bubble, Dodongo rules (section 10).
10. Group sizes in the dungeon tables are the pre-history counts (3, 5, 6, 8). They match the Level 3 walkthrough (five Darknuts in `$59`, eight in `$69`). Compare the port's current Level 1 room data with these tables once.
11. Door-reachable room counts (17, 18, 18, 20, 23, 25, 33, 25 and 57 plus the stair rooms) against the walkthrough maps.

## Appendix: method

- ROM: `Legend_of_Zelda_The_Europe_Rev_1`, PAL, 131,088 bytes. Checks passed: start room `$77`, start Y `$8D`, overworld group sizes `[1, 4, 5, 6]`, caves match known game content.
- Offsets come from `src/bins.xml` (relative to PRG start). The decoder imports the repo's own `build_assets.py` and `underworld.py`, so these tables use the same column, square and door decoding as the port.
- HP and damage come from `ObjectTypeToHpPairs` and `ObjTypeToDamagePoints` in the disassembly, not the ROM; HP is in wooden-sword hits.
- Screens are named column letter A to P and row 1 to 8 (A1 = room `$00`, P8 = `$7F`, H8 = start `$77`).
- Dungeon room sets: every room reachable from the start room through non-wall doors, plus rooms reached through stair rooms. A room not listed there is not in that level.

## Appendix A1: all hidden marker squares (bomb wall, tree, rock, gravestone)

Pixel y includes the `$40` offset of the playfield. Leads-to is attribute B of the screen. "item/none" means the screen has no destination (a plain secret object).

| Screen | ROM id | Kind | Tile col,row | Pixel x,y | Leads to | Quest | Stairs-pos idx |
|---|---|---|---|---|---|---|---|
| A1 | $00 | rock wall (bomb) | 10,4 | 160,128 | Level 9 | Q2 | 0 |
| B1 | $01 | rock wall (bomb) | 9,1 | 144,80 | cave idx 7 (type $71) | both | 0 |
| C1 | $02 | rock wall (bomb) | 6,4 | 96,128 | cave idx 10 (type $74) | Q2 | 0 |
| D1 | $03 | rock wall (bomb) | 7,4 | 112,128 | cave idx 7 (type $71) | both | 0 |
| F1 | $05 | rock wall (bomb) | 5,6 | 80,160 | Level 9 | Q1 | 0 |
| H1 | $07 | rock wall (bomb) | 10,4 | 160,128 | cave idx 7 (type $71) | both | 0 |
| J1 | $09 | rock (Power Bracelet) | 4,5 | 64,144 | cave idx 3 (type $6D) | Q2 | 2 |
| N1 | $0D | rock wall (bomb) | 9,1 | 144,80 | cave idx 10 (type $74) | both | 0 |
| A2 | $10 | rock wall (bomb) | 9,1 | 144,80 | cave idx 6 (type $70) | both | 0 |
| B2 | $11 | rock (Power Bracelet) | 8,5 | 128,144 | cave idx 8 (type $72) | Q2 | 2 |
| C2 | $12 | rock wall (bomb) | 8,1 | 128,80 | cave idx 15 (type $79) | both | 0 |
| D2 | $13 | rock wall (bomb) | 2,1 | 32,80 | cave idx 17 (type $7B) | both | 0 |
| E2 | $14 | rock wall (bomb) | 12,1 | 192,80 | cave idx 7 (type $71) | both | 0 |
| F2 | $15 | rock wall (bomb) | 12,1 | 192,80 | cave idx 14 (type $78) | Q2 | 0 |
| G2 | $16 | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| I2 | $18 | rock wall (bomb) | 12,3 | 192,112 | cave idx 10 (type $74) | Q2 | 0 |
| J2 | $19 | rock wall (bomb) | 4,3 | 64,112 | Level 7 | Q2 | 0 |
| L2 | $1B | rock (Power Bracelet) | 12,5 | 192,144 | Level 5 | Q2 | 2 |
| N2 | $1D | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 0 |
| O2 | $1E | rock wall (bomb) | 12,1 | 192,80 | cave idx 7 (type $71) | both | 0 |
| A3 | $20 | gravestone (push) | 6,5 | 96,144 | cave idx 1 (type $6B) | Q2 | 3 |
| B3 | $21 | gravestone (push) | 9,5 | 144,144 | cave idx 3 (type $6D) | Q1 | 2 |
| D3 | $23 | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 1 |
| G3 | $26 | rock wall (bomb) | 3,1 | 48,80 | cave idx 15 (type $79) | both | 0 |
| H3 | $27 | rock wall (bomb) | 14,1 | 224,80 | cave idx 10 (type $74) | Q1 | 0 |
| I3 | $28 | tree (candle fire) | 13,6 | 208,160 | cave idx 17 (type $7B) | both | 0 |
| M3 | $2C | rock wall (bomb) | 9,6 | 144,160 | cave idx 1 (type $6B) | Q1 | 0 |
| N3 | $2D | rock wall (bomb) | 5,1 | 80,80 | cave idx 17 (type $7B) | both | 0 |
| D4 | $33 | rock wall (bomb) | 10,1 | 160,80 | cave idx 10 (type $74) | both | 0 |
| G5 | $46 | tree (candle fire) | 9,7 | 144,176 | cave idx 15 (type $79) | both | 0 |
| H5 | $47 | tree (candle fire) | 11,7 | 176,176 | cave idx 1 (type $6B) | Q1 | 0 |
| I5 | $48 | tree (candle fire) | 13,2 | 208,96 | cave idx 17 (type $7B) | both | 0 |
| J5 | $49 | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 0 |
| L5 | $4B | tree (candle fire) | 11,2 | 176,96 | cave idx 10 (type $74) | both | 0 |
| N5 | $4D | tree (candle fire) | 13,6 | 208,160 | cave idx 15 (type $79) | both | 0 |
| B6 | $51 | tree (candle fire) | 9,6 | 144,160 | cave idx 19 (type $7D) | both | 0 |
| D6 | $53 | tree (candle fire) | 6,6 | 96,160 | cave idx 18 (type $7C) | Q2 | 0 |
| G6 | $56 | tree (candle fire) | 10,6 | 160,160 | cave idx 19 (type $7D) | both | 0 |
| L6 | $5B | tree (candle fire) | 2,6 | 32,160 | cave idx 19 (type $7D) | both | 0 |
| C7 | $62 | tree (candle fire) | 8,2 | 128,96 | cave idx 18 (type $7C) | Q1 | 0 |
| D7 | $63 | tree (candle fire) | 6,6 | 96,160 | cave idx 7 (type $71) | both | 0 |
| H7 | $67 | rock wall (bomb) | 7,1 | 112,80 | cave idx 17 (type $7B) | Q1 | 0 |
| I7 | $68 | tree (candle fire) | 2,6 | 32,160 | cave idx 7 (type $71) | both | 0 |
| K7 | $6A | tree (candle fire) | 12,6 | 192,160 | cave idx 7 (type $71) | both | 0 |
| L7 | $6B | tree (candle fire) | 8,6 | 128,160 | cave idx 18 (type $7C) | Q1 | 0 |
| M7 | $6C | tree (candle fire) | 5,2 | 80,96 | Level 8 | Q2 | 0 |
| N7 | $6D | tree (candle fire) | 10,2 | 160,96 | Level 8 | Q1 | 0 |
| B8 | $71 | rock wall (bomb) | 5,1 | 80,80 | cave idx 17 (type $7B) | Q1 | 0 |
| G8 | $76 | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| I8 | $78 | tree (candle fire) | 4,6 | 64,160 | cave idx 10 (type $74) | both | 0 |
| J8 | $79 | rock (Power Bracelet) | 8,5 | 128,144 | cave idx 4 (type $6E) (take-any-road) | both | 2 |
| L8 | $7B | rock wall (bomb) | 9,1 | 144,80 | cave idx 1 (type $6B) | Q1 | 0 |
| M8 | $7C | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| N8 | $7D | rock wall (bomb) | 6,1 | 96,80 | cave idx 7 (type $71) | both | 0 |

(54 hidden marker squares in total.)

## Appendix A2: screens with a visible cave or dungeon entrance (square idx 12)

| Screen | ROM id | Leads to | Entrance square (col,row) | Quest tag |
|---|---|---|---|---|
| E1 | $04 | cave idx 10 (type $74) | 12,1 | both |
| K1 | $0A | cave idx 2 (type $6C) | 2,1 | both |
| L1 | $0B | Level 5 | 7,4 | both |
| M1 | $0C | cave idx 14 (type $78) | 8,1 | both |
| O1 | $0E | cave idx 8 (type $72) | 5,4 | both |
| P1 | $0F | cave idx 18 (type $7C) | 8,4 | both |
| P2 | $1F | cave idx 6 (type $70) | 6,4 | both |
| C3 | $22 | Level 6 | 7,4, 8,4 | both |
| F3 | $25 | cave idx 13 (type $77) | 10,1 | both |
| P3 | $2F | cave idx 1 (type $6B) | 6,4 | both |
| H4 | $37 | Level 1 | 7,4 | both |
| M4 | $3C | Level 2 | 7,4 | both |
| E5 | $44 | cave idx 13 (type $77) | 4,1 | both |
| F5 | $45 | Level 4 | 8,4 | both |
| K5 | $4A | cave idx 13 (type $77) | 11,1 | both |
| O6 | $5E | cave idx 14 (type $78) | 7,1 | both |
| E7 | $64 | cave idx 10 (type $74) | 7,1 | both |
| G7 | $66 | cave idx 14 (type $78) | 7,1 | both |
| P7 | $6F | cave idx 13 (type $77) | 3,1 | both |
| A8 | $70 | cave idx 12 (type $76) | 11,1 | both |
| E8 | $74 | Level 3 | 8,4 | both |
| F8 | $75 | cave idx 9 (type $73) | 2,1 | both |
| H8 | $77 | cave idx 0 (type $6A) | 4,1 | both |

## Appendix A3: screens with a destination but nothing drawn for it

| Screen | ROM id | Leads to | Why it is not drawn | Quest tag |
|---|---|---|---|---|
| G1 | $06 | cave idx 1 (type $6B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| K2 | $1A | cave idx 11 (type $75) | waterfall column (idx 54) at col 6; walk into it (verify) | both |
| M2 | $1C | cave idx 5 (type $6F) | touch the armos at the listed spot (see 4.2) | both |
| J3 | $29 | cave idx 10 (type $74) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| L3 | $2B | cave idx 19 (type $7D) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| A4 | $30 | Level 6 | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| E4 | $34 | cave idx 16 (type $7A) | touch the armos at the listed spot (see 4.2) | both |
| K4 | $3A | cave idx 1 (type $6B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| N4 | $3D | cave idx 17 (type $7B) | touch the armos at the listed spot (see 4.2) | both |
| C5 | $42 | Level 7 | play the Recorder at the pond edge; stairs rise at col 6, row 9 | both |
| O5 | $4E | cave idx 19 (type $7D) | touch the armos at the listed spot (see 4.2) | both |
| I6 | $58 | cave idx 17 (type $7B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| A7 | $60 | cave idx 6 (type $70) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| O7 | $6E | cave idx 19 (type $7D) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| C8 | $72 | cave idx 7 (type $71) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |

## Appendix B1: every overworld screen, its enemies and flags

Counts are before the room-history reduction. "enemies enter from screen edge" means no initial placement (section 5.1).

| Screen | ROM id | Monsters (count x type) | Notes |
|---|---|---|---|
| A1 | $00 | none | - |
| B1 | $01 | 4x Lynel (red) | - |
| C1 | $02 | 4x Lynel (red) | - |
| D1 | $03 | Boulder set | - |
| E1 | $04 | 6x Lynel (blue) | - |
| F1 | $05 | 2x Lynel (blue), Leever (blue), 2x Lynel (red), Leever (red) | - |
| G1 | $06 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| H1 | $07 | Lynel (red) | - |
| I1 | $08 | Boulder set | - |
| J1 | $09 | none | - |
| K1 | $0A | Lynel (blue) | Zoras in water |
| L1 | $0B | Leever (red) | 8 armos |
| M1 | $0C | 6x Tektite (red) | - |
| N1 | $0D | 6x Tektite (red) | - |
| O1 | $0E | none | enemies enter from screen edge; sea sound |
| P1 | $0F | none | sea sound |
| A2 | $10 | 4x Lynel (blue) | - |
| B2 | $11 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| C2 | $12 | 6x Lynel (blue) | - |
| D2 | $13 | 2x Lynel (blue), 2x Lynel (red) | - |
| E2 | $14 | 4x Lynel (red) | 8 armos |
| F2 | $15 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| G2 | $16 | Boulder set | - |
| H2 | $17 | Boulder set | Zoras in water |
| I2 | $18 | Boulder set | Zoras in water |
| J2 | $19 | Boulder set | Zoras in water |
| K2 | $1A | 6x Tektite (red) | Zoras in water |
| L2 | $1B | none | - |
| M2 | $1C | none | 8 armos |
| N2 | $1D | 6x Peahat | sea sound |
| O2 | $1E | 6x Tektite (red) | Zoras in water; sea sound |
| P2 | $1F | 6x Peahat | sea sound |
| A3 | $20 | Ghini | - |
| B3 | $21 | Ghini | - |
| C3 | $22 | Lynel (red) | 12 armos |
| D3 | $23 | 4x Lynel (red) | - |
| E3 | $24 | none | 10 armos |
| F3 | $25 | 4x Peahat | 8 armos |
| G3 | $26 | 6x Peahat | Zoras in water |
| H3 | $27 | 6x Peahat | Zoras in water |
| I3 | $28 | 6x Peahat | Zoras in water |
| J3 | $29 | 4x Leever (red) | - |
| K3 | $2A | 6x Leever (blue) | - |
| L3 | $2B | 2x Leever (blue), 3x Peahat, Leever (red) | - |
| M3 | $2C | 4x Tektite (red) | - |
| N3 | $2D | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| O3 | $2E | 4x Octorok (blue, slow) | Zoras in water; sea sound |
| P3 | $2F | none | - |
| A4 | $30 | Ghini | - |
| B4 | $31 | Ghini | - |
| C4 | $32 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| D4 | $33 | none | 10 armos |
| E4 | $34 | 4x Leever (blue) | 6 armos |
| F4 | $35 | none | Zoras in water |
| G4 | $36 | none | Zoras in water |
| H4 | $37 | Octorok (red, fast) | - |
| I4 | $38 | Octorok (blue, slow), 5x Octorok (red, fast) | Zoras in water |
| J4 | $39 | Pond fairy | - |
| K4 | $3A | 2x Leever (blue), 3x Peahat, Leever (red) | - |
| L4 | $3B | 4x Leever (blue) | - |
| M4 | $3C | Octorok (blue, fast) | 8 armos |
| N4 | $3D | 4x Moblin (blue) | 2 armos |
| O4 | $3E | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| P4 | $3F | Octorok (blue, slow) | Zoras in water; sea sound |
| A5 | $40 | Ghini | - |
| B5 | $41 | Ghini | - |
| C5 | $42 | Moblin (red) | - |
| D5 | $43 | Pond fairy | - |
| E5 | $44 | 4x Octorok (red, slow) | Zoras in water |
| F5 | $45 | Peahat | - |
| G5 | $46 | none | Zoras in water |
| H5 | $47 | none | Zoras in water |
| I5 | $48 | 4x Leever (red) | Zoras in water |
| J5 | $49 | Octorok (blue, slow), 5x Octorok (red, fast) | - |
| K5 | $4A | 6x Tektite (blue) | - |
| L5 | $4B | 6x Moblin (red) | enemies enter from screen edge |
| M5 | $4C | 3x Octorok (red, fast), 2x Octorok (blue, slow) | - |
| N5 | $4D | 4x Moblin (blue) | enemies enter from screen edge |
| O5 | $4E | 4x Moblin (blue) | enemies enter from screen edge; 2 armos |
| P5 | $4F | 2x Octorok (blue, fast), 3x Octorok (red, slow) | Zoras in water; sea sound |
| A6 | $50 | 5x Lynel (red) | - |
| B6 | $51 | 5x Moblin (blue) | - |
| C6 | $52 | 2x Moblin (blue), 2x Moblin (red) | enemies enter from screen edge |
| D6 | $53 | 3x Moblin (blue), 2x Moblin (red) | - |
| E6 | $54 | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| F6 | $55 | Octorok (red, slow) | Zoras in water |
| G6 | $56 | 4x Octorok (red, slow) | Zoras in water |
| H6 | $57 | 2x Octorok (red, fast), 2x Octorok (red, slow) | enemies enter from screen edge |
| I6 | $58 | 2x Octorok (red, fast), 2x Octorok (red, slow) | enemies enter from screen edge |
| J6 | $59 | 4x Peahat | Zoras in water |
| K6 | $5A | 4x Octorok (red, slow) | Zoras in water |
| L6 | $5B | 2x Moblin (blue), 2x Moblin (red) | enemies enter from screen edge |
| M6 | $5C | 4x Moblin (blue) | enemies enter from screen edge |
| N6 | $5D | 4x Moblin (blue) | enemies enter from screen edge |
| O6 | $5E | 5x Moblin (blue) | - |
| P6 | $5F | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| A7 | $60 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| B7 | $61 | 5x Moblin (blue) | enemies enter from screen edge |
| C7 | $62 | 5x Moblin (blue) | enemies enter from screen edge |
| D7 | $63 | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | - |
| E7 | $64 | 3x Octorok (red, fast), 2x Octorok (blue, slow) | - |
| F7 | $65 | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| G7 | $66 | 2x Octorok (red, fast), 2x Octorok (red, slow) | - |
| H7 | $67 | 4x Octorok (red, slow) | - |
| I7 | $68 | 4x Octorok (red, slow) | enemies enter from screen edge |
| J7 | $69 | 4x Octorok (red, slow) | Zoras in water |
| K7 | $6A | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| L7 | $6B | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | enemies enter from screen edge |
| M7 | $6C | 4x Moblin (red) | enemies enter from screen edge |
| N7 | $6D | 4x Moblin (red) | enemies enter from screen edge |
| O7 | $6E | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | - |
| P7 | $6F | Octorok (blue, slow), 4x Octorok (red, fast) | Zoras in water; sea sound |
| A8 | $70 | 4x Peahat | - |
| B8 | $71 | 5x Moblin (blue) | enemies enter from screen edge |
| C8 | $72 | 3x Moblin (blue), Moblin (red) | enemies enter from screen edge |
| D8 | $73 | 4x Moblin (blue) | enemies enter from screen edge |
| E8 | $74 | Tektite (red) | 8 armos |
| F8 | $75 | 2x Leever (blue), 3x Peahat, Leever (red) | Zoras in water |
| G8 | $76 | 4x Tektite (red) | - |
| H8 | $77 | none | - |
| I8 | $78 | 4x Octorok (red, slow) | enemies enter from screen edge |
| J8 | $79 | 5x Tektite (blue) | - |
| K8 | $7A | 4x Tektite (blue) | - |
| L8 | $7B | 6x Leever (red) | Zoras in water; sea sound |
| M8 | $7C | 6x Leever (red) | Zoras in water; sea sound |
| N8 | $7D | 4x Octorok (blue, slow) | Zoras in water; sea sound |
| O8 | $7E | 4x Octorok (red, fast) | Zoras in water; sea sound |
| P8 | $7F | Octorok (blue, slow) | Zoras in water; sea sound |

## Appendix B2: overworld enemies by type

| Type | Name | HP (sword hits) | Damage | Screens (count) |
|---|---|---|---|---|
| $01 | Lynel (blue) | 6 | 2 hearts | E1 (6), F1 (2), G1 (2), K1, A2 (4), B2 (2), C2 (6), D2 (2), F2 (2), C4 (2), A7 (2) |
| $02 | Lynel (red) | 4 | 1 heart | B1 (4), C1 (4), F1 (2), G1 (2), H1, B2 (2), D2 (2), E2 (4), F2 (2), C3, D3 (4), C4 (2), A6 (5), A7 (2) |
| $03 | Moblin (blue) | 3 | half heart | N4 (4), N5 (4), O5 (4), B6 (5), C6 (2), D6 (3), L6 (2), M6 (4), N6 (4), O6 (5), B7 (5), C7 (5), D7, L7, O7, B8 (5), C8 (3), D8 (4) |
| $04 | Moblin (red) | 2 | half heart | C5, L5 (6), C6 (2), D6 (2), L6 (2), D7 (3), L7 (3), M7 (4), N7 (4), O7 (3), C8 |
| $07 | Octorok (red, slow) | 1 | half heart | E5 (4), P5 (3), E6 (2), F6, G6 (4), H6 (2), I6 (2), K6 (4), F7 (2), G7 (2), H7 (4), I7 (4), J7 (4), K7 (2), I8 (4) |
| $08 | Octorok (red, fast) | 1 | half heart | N3 (3), H4, I4 (5), O4 (3), J5 (5), M5 (3), E6 (2), H6 (2), I6 (2), P6 (3), E7 (3), F7 (2), G7 (2), K7 (2), P7 (4), O8 (4) |
| $09 | Octorok (blue, slow) | 2 | half heart | N3 (2), O3 (4), I4, O4 (2), P4, J5, M5 (2), P6 (2), E7 (2), P7, N8 (4), P8 |
| $0A | Octorok (blue, fast) | 2 | half heart | M4, P5 (2), D7 (2), L7 (2), O7 (2) |
| $0D | Tektite (blue) | 1 | half heart | K5 (6), J8 (5), K8 (4) |
| $0E | Tektite (red) | 1 | half heart | M1 (6), N1 (6), K2 (6), O2 (6), M3 (4), E8, G8 (4) |
| $0F | Leever (blue) | 4 | 1 heart | F1, K3 (6), L3 (2), E4 (4), K4 (2), L4 (4), F8 (2) |
| $10 | Leever (red) | 2 | half heart | F1, L1, J3 (4), L3, K4, I5 (4), F8, L8 (6), M8 (6) |
| $1A | Peahat | 2 | half heart | G1 (2), B2 (2), F2 (2), N2 (6), P2 (6), F3 (4), G3 (6), H3 (6), I3 (6), L3 (3), C4 (2), K4 (3), F5, J6 (4), A7 (2), A8 (4), F8 (3) |
| $1F | Boulder set | 15 | half heart | D1, I1, G2, H2, I2, J2 |
| $21 | Ghini | 9 | 1 heart | A3, B3, A4, B4, A5, B5 |
| $2F | Pond fairy | 15 | none | J4, D5 |

Zora screens (water enemy, not in the monster list): K1, H2, I2, J2, K2, O2, G3, H3, I3, N3, O3, F4, G4, I4, O4, P4, E5, G5, H5, I5, P5, E6, F6, G6, J6, K6, P6, F7, J7, K7, P7, F8, L8, M8, N8, O8, P8

Edge-spawn screens: O1, L5, N5, O5, C6, H6, I6, L6, M6, N6, B7, C7, I7, L7, M7, N7, B8, C8, D8, I8

## Appendix C: all 20 cave types

Items are listed left / middle / right. "(none)" means an empty slot. Prices are in rupees. Screens are tagged [Q1] or [Q2] when the secret that leads to them applies to one quest only.

| Idx | Type | Text | Items (left / middle / right) | Prices | Used by (screen, ROM id) |
|---|---|---|---|---|---|
| 0 | $6A | "IT'S DANGEROUS TO GO / ALONE! TAKE THIS." | (none) / Wooden Sword / (none) | 0/0/0 | H8(77) |
| 1 | $6B | "TAKE ANY ONE YOU WANT." | Red (2nd) Potion / (none) / Heart Container | 0/0/0 | G1(06) [Q2], A3(20) [Q2], M3(2C) [Q1], P3(2F), K4(3A) [Q2], H5(47) [Q1], L8(7B) [Q1] |
| 2 | $6C | "MASTER USING IT AND / YOU CAN HAVE THIS." | (none) / White Sword / (none) | 0/0/0 | K1(0A) |
| 3 | $6D | "MASTER USING IT AND / YOU CAN HAVE THIS." | (none) / Magical Sword / (none) | 0/0/0 | J1(09) [Q2], B3(21) [Q1] |
| 4 | $6E | "TAKE ANY ROAD YOU WANT." | (none) / (none) / (none) | 0/0/0 | N2(1D), D3(23), J5(49), J8(79) |
| 5 | $6F | "SECRET IS IN THE TREE / AT THE DEAD-END." | (none) / (none) / (none) | 0/0/0 | M2(1C) |
| 6 | $70 | "LET'S PLAY MONEY / MAKING GAME." | Rupee / Rupee / Rupee | 10/10/10 | A2(10), G2(16), P2(1F), A7(60) [Q2], G8(76), M8(7C) |
| 7 | $71 | "PAY ME FOR THE DOOR / REPAIR CHARGE." | (none) / (none) / (none) | 0/0/0 | B1(01), D1(03), H1(07), E2(14), O2(1E), D7(63), I7(68), K7(6A), C8(72) [Q2], N8(7D) |
| 8 | $72 | "SHOW THIS TO THE / OLD WOMAN." | (none) / Letter / (none) | 0/0/0 | O1(0E), B2(11) [Q2] |
| 9 | $73 | "MEET THE OLD MAN / AT THE GRAVE." | (none) / (none) / (none) | 0/0/0 | F8(75) |
| 10 | $74 | "BUY MEDICINE BEFORE / YOU GO." | Blue (Life) Potion / (none) / Red (2nd) Potion | 40/0/68 | C1(02) [Q2], E1(04), N1(0D), I2(18) [Q2], H3(27) [Q1], J3(29) [Q2], D4(33), L5(4B), E7(64), I8(78) |
| 11 | $75 | "PAY ME AND I'LL TALK." | Rupee / Rupee / Rupee | 5/10/20 | K2(1A) |
| 12 | $76 | "PAY ME AND I'LL TALK." | Rupee / Rupee / Rupee | 10/30/50 | A8(70) |
| 13 | $77 | "BUY SOMETHIN' WILL YA!" | Magical Shield / Bombs / Arrow | 130/20/80 | F3(25), E5(44), K5(4A), P7(6F) |
| 14 | $78 | "BUY SOMETHIN' WILL YA!" | Magical Shield / Key / Blue Candle | 160/100/60 | M1(0C), F2(15) [Q2], O6(5E), G7(66) |
| 15 | $79 | "BOY, THIS IS / REALLY EXPENSIVE!" | Magical Shield / Bait / Small Heart | 90/100/10 | C2(12), G3(26), G5(46), N5(4D) |
| 16 | $7A | "BOY, THIS IS / REALLY EXPENSIVE!" | Key / Blue Ring / Bait | 80/250/60 | E4(34) |
| 17 | $7B | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/30/0 | D2(13), I3(28), N3(2D), N4(3D), I5(48), I6(58) [Q2], H7(67) [Q1], B8(71) [Q1] |
| 18 | $7C | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/100/0 | P1(0F), D6(53) [Q2], C7(62) [Q1], L7(6B) [Q1] |
| 19 | $7D | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/10/0 | L3(2B) [Q2], O5(4E), B6(51), G6(56), L6(5B), O7(6E) [Q2] |

## Appendix D: all nine dungeons

Dark = attribute E bit 7. Secret trigger = attribute F bits 0-2. Room items come from attribute E bits 0-4 (3 = nothing).

#### Level 1

Start room $73; triforce room $36; boss room $35; stair rooms $7F; 17 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $22 | (none) | - |  | Trap (4) |
| $23 | Key | kill all, item appears |  | 3x Goriya (red) |
| $33 | Key | - |  | 3x Stalfos |
| $35 | Heart Container | kill all, item appears |  | Aquamentus |
| $36 | Triforce piece | - |  | - |
| $41 | (none) | - |  | old man: "EASTMOST PENNINSULA / IS THE SECRET." |
| $42 | (none) | push block, door opens |  | 3x Gel |
| $43 | Map | - |  | 5x Gel |
| $44 | Boomerang | kill all, item appears |  | 3x Goriya (red) |
| $45 | Key | - |  | 8x Wallmaster |
| $52 | (none) | kill all, shutters open |  | 6x Keese (blue) |
| $53 | Key | kill all, item appears |  | 5x Stalfos |
| $54 | Compass | - |  | 8x Keese (blue) |
| $63 | (none) | - |  | 3x Stalfos |
| $72 | Key | kill all, item appears |  | 3x Keese (blue) |
| $73 | (none) | - |  | - |
| $74 | Key | - |  | 5x Stalfos |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $7F | 63 | Bow | $22 / $22 |

#### Level 2

Start room $7D; triforce room $0D; boss room $0E; stair rooms none; 18 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $0D | Triforce piece | - |  | - |
| $0E | Heart Container | kill all, item appears |  | Dodongo (2) |
| $1E | Bombs | kill all, item appears |  | 5x Goriya (red) |
| $1F | (none) | - |  | old man: "DODONGO DISLIKES SMOKE." |
| $2E | (none) | kill all, shutters open |  | 8x Rope |
| $2F | 5 Rupees | kill all, item appears |  | 5x Gel |
| $3E | Key | kill all, item appears |  | Moldorm |
| $3F | Bombs | - |  | Trap (4), 4x Keese (blue) |
| $4E | Key | kill all, item appears |  | 5x Rope |
| $4F | Magical Boomerang | kill all, item appears |  | 3x Goriya (blue) |
| $5E | (none) | kill the ringleader, shutters open |  | 5x Goriya (red) |
| $5F | Map | - |  | 5x Gel |
| $6C | Key | - |  | 6x Rope |
| $6D | (none) | kill all, shutters open |  | 5x Rope |
| $6E | (none) | - |  | 3x Rope |
| $6F | Compass | - |  | 6x Gel |
| $7D | (none) | - |  | - |
| $7E | Key | kill all, item appears |  | 5x Rope |

#### Level 3

Start room $7C; triforce room $3D; boss room $4D; stair rooms $0F; 18 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $2A | Key | kill all, shutters open |  | 8x Keese (blue) |
| $2B | (none) | - |  | old man: "DID YOU GET THE SWORD / FROM THE OLD MAN ON / TOP OF THE WATERFALL?" |
| $3B | (none) | push block, door opens |  | Trap (4), 2x Zol |
| $3D | Triforce piece | - |  | - |
| $49 | Key | - |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $4A | Bombs | kill all, item appears |  | 5x Keese (blue) |
| $4B | Key | kill all, item appears |  | 3x Zol |
| $4C | Map | - |  | Trap (4), 2x Zol |
| $4D | Heart Container | kill all, item appears |  | Manhandla |
| $59 | (none) | kill all, shutters open |  | 5x Darknut (red) |
| $5A | Compass | - |  | Trap (4), 4x Keese (blue) |
| $5B | Bombs | kill all, item appears |  | 3x Darknut (red) |
| $5C | (none) | kill all, shutters open |  | 3x Darknut (red) |
| $5D | 5 Rupees | kill all, item appears |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $69 | Bombs | kill all, item appears |  | 8x Darknut (red) |
| $6B | Key | kill all, item appears |  | 5x Zol |
| $7B | Key | - |  | 6x Zol |
| $7C | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $0F | 63 | Raft | $69 / $69 |

#### Level 4

Start room $71; triforce room $03; boss room $13; stair rooms $60; 20 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $00 | (none) | - |  | old man: "WALK INTO THE / WATERFALL." |
| $01 | Key | - | yes | 8x Keese (blue) |
| $02 | (none) | - | yes | Trap (6) |
| $03 | Triforce piece | - |  | - |
| $10 | (none) | kill all, shutters open |  | Manhandla |
| $11 | (none) | - |  | Rupee stash |
| $12 | (none) | push block, door opens |  | 5x Vire |
| $13 | Heart Container | kill all, item appears |  | Gleeok (3 heads) |
| $20 | (none) | - |  | 5x Vire |
| $21 | Map | - | yes | 5x Gel |
| $30 | (none) | - | yes | 2x Bubble (black), 3x Vire |
| $31 | (none) | kill all, shutters open |  | 5x Vire |
| $32 | (none) | push block, stairs open |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $40 | Key | - | yes | 5x Zol |
| $50 | (none) | - | yes | 5x Vire |
| $51 | Key | - |  | 8x Keese (blue) |
| $61 | (none) | - |  | 3x Vire |
| $62 | Compass | - | yes | 5x Vire |
| $70 | Key | kill all, item appears |  | 8x Keese (blue) |
| $71 | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $60 | 63 | Stepladder | $32 / $32 |

#### Level 5

Start room $76; triforce room $14; boss room $24; stair rooms $04, $07; 23 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $05 | (none) | push block, stairs open |  | 6x Darknut (blue) |
| $06 | (none) | - |  | - |
| $14 | Triforce piece | - |  | - |
| $15 | (none) | - |  | old man: "SECRET POWER IS SAID / TO BE IN THE ARROW." |
| $16 | Key | - |  | 8x Keese (blue) |
| $17 | (none) | - |  | old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS." |
| $24 | Heart Container | kill all, item appears |  | Digdogger (2) |
| $25 | (none) | - |  | 5x Pols Voice |
| $26 | Key | kill all, item appears |  | 5x Gibdo |
| $27 | Key | - | yes | 2x Pols Voice, 2x Gibdo, 2x Keese (blue) |
| $34 | (none) | kill all, shutters open |  | 6x Gibdo |
| $37 | Compass | kill all, item appears | yes | 3x Darknut (red) |
| $46 | Map | - | yes | - |
| $47 | Key | kill all, item appears |  | 5x Gibdo |
| $55 | Key | kill all, item appears |  | 5x Zol |
| $56 | Bombs | kill all, item appears |  | 3x Dodongo (1) |
| $57 | 5 Rupees | kill all, item appears | yes | 5x Zol |
| $64 | (none) | - |  | 5x Darknut (blue) |
| $65 | Bombs | - |  | 5x Gibdo |
| $66 | Key | kill all, shutters open | yes | 3x Gibdo |
| $67 | (none) | - |  | old man: "DIGDOGGER HATES / CERTAIN KIND OF SOUND." |
| $76 | (none) | - |  | - |
| $77 | Key | kill all, item appears |  | 5x Pols Voice |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $04 | 63 | Recorder | $05 / $05 |
| $07 | 62 | (none) | $64 / $06 |

#### Level 6

Start room $79; triforce room $0C; boss room $1C; stair rooms $08, $75; 25 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $09 | (none) | push block, stairs open |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $0A | (none) | kill all, shutters open |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $0B | (none) | - |  | old man: "THERE ARE SECRETS WHERE / FAIRIES DON'T LIVE." |
| $0C | Triforce piece | - |  | - |
| $18 | (none) | kill all, shutters open |  | Gleeok (4 heads) |
| $19 | Map | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $1A | Key | - | yes | 6x Wizzrobe (red) |
| $1B | (none) | kill all, shutters open |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $1C | Heart Container | kill all, item appears |  | Gohma (blue) |
| $1D | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $28 | 5 Rupees | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $29 | Key | - | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $2C | (none) | - |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $2D | Key | kill all, item appears | yes | 2x Bubble (black), 3x Vire |
| $38 | (none) | push block, door opens |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $39 | (none) | kill all, shutters open | yes | 5x Vire |
| $3A | (none) | push block, stairs open |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $3C | Bombs | kill all, item appears | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $48 | (none) | - |  | Trap (6) |
| $58 | Key | kill all, item appears |  | 8x Keese (blue) |
| $68 | Compass | kill all, item appears |  | 5x Zol |
| $6A | (none) | - |  | old man: "AIM AT THE EYES / OF GOHMA." |
| $78 | (none) | kill the ringleader, shutters open |  | 5x Wizzrobe (red) |
| $79 | (none) | - |  | - |
| $7A | Key | kill all, item appears | yes | 5x Wizzrobe (red) |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $08 | 62 | (none) | $3A / $1D |
| $75 | 63 | Magical Rod | $09 / $09 |

#### Level 7

Start room $79; triforce room $2B; boss room $2A; stair rooms $4A, $7B; 33 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $08 | (none) | - |  | Rupee stash |
| $09 | 5 Rupees | kill all, item appears |  | 3x Goriya (blue), 3x Goriya (red) |
| $0A | Key | kill all, shutters open |  | 5x Goriya (blue) |
| $0B | Bombs | kill all, item appears |  | Moldorm |
| $0C | Bombs | kill all, item appears |  | 3x Dodongo (1) |
| $0D | (none) | push block, stairs open |  | 3x Bubble (black), 5x Wallmaster |
| $18 | Map | kill all, shutters open | yes | 2x Bubble (black), 3x Goriya (blue), 3x Keese (blue) |
| $19 | (none) | kill all, shutters open |  | 6x Goriya (blue) |
| $1A | (none) | - |  | 3x Goriya (blue), 3x Goriya (red) |
| $1B | Bombs | kill all, item appears |  | 6x Goriya (blue) |
| $1C | (none) | kill all, shutters open |  | Digdogger (1) |
| $28 | (none) | - |  | Grumble (the 'Grumble, grumble' man) |
| $29 | (none) | - |  | 3x Goriya (blue), 3x Goriya (red) |
| $2A | Heart Container | kill all, item appears |  | Aquamentus |
| $2B | Triforce piece | - |  | - |
| $38 | 5 Rupees | kill all, item appears |  | 3x Goriya (blue), 3x Goriya (red) |
| $39 | (none) | - |  | Digdogger (1) |
| $3A | Key | kill all, item appears |  | Moldorm |
| $48 | (none) | - |  | old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS." |
| $49 | (none) | kill all, shutters open |  | 2x Bubble (black), 3x Goriya (blue), 3x Keese (blue) |
| $58 | 5 Rupees | kill all, item appears |  | 3x Dodongo (1) |
| $59 | (none) | kill all, shutters open |  | 3x Goriya (blue), 3x Goriya (red) |
| $5A | Compass | - | yes | 8x Stalfos |
| $5B | (none) | - |  | old man: "THERE'S A SECRET IN / THE TIP OF THE NOSE." |
| $68 | Bombs | kill all, item appears |  | Trap (4), 4x Keese (blue) |
| $69 | Bombs | kill all, item appears |  | 5x Goriya (blue) |
| $6A | (none) | kill the ringleader, shutters open | yes | 8x Keese (blue) |
| $6B | (none) | kill all, shutters open |  | 6x Goriya (blue) |
| $6C | Bombs | kill all, item appears |  | Digdogger (2) |
| $6D | Key | - |  | 8x Stalfos |
| $78 | Key | - |  | 5x Rope |
| $79 | (none) | - |  | - |
| $7A | Bombs | kill all, item appears |  | Moldorm |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $4A | 63 | Red Candle | $1A / $1A |
| $7B | 62 | (none) | $29 / $0D |

#### Level 8

Start room $7E; triforce room $2C; boss room $3C; stair rooms $0F, $2F, $6F; 25 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $0E | Bombs | kill all, item appears |  | 5x Darknut (red) |
| $1D | Bombs | kill all, item appears |  | 5x Pols Voice |
| $1E | (none) | kill all, shutters open |  | Gohma (red) |
| $1F | (none) | kill all, shutters open |  | 2x Pols Voice, 2x Darknut (blue), 2x Darknut (red) |
| $2C | Triforce piece | - |  | - |
| $2D | (none) | - |  | Rupee stash |
| $2E | Map | kill all, item appears |  | Manhandla |
| $3B | (none) | - |  | old man: "10TH ENEMY HAS THE BOMB." |
| $3C | Heart Container | kill all, item appears |  | Gleeok (1 head) |
| $3D | (none) | - |  | old man: "SPECTACLE ROCK IS / AN ENTRANCE TO DEATH." |
| $3E | (none) | kill all, shutters open |  | 6x Darknut (blue) |
| $3F | Bombs | kill all, item appears |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $4B | Key | kill all, shutters open | yes | 6x Darknut (red) |
| $4C | Key | kill all, shutters open |  | 8x Pols Voice |
| $4D | (none) | kill all, shutters open |  | Gohma (red) |
| $4E | 5 Rupees | kill all, item appears |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $5C | Key | kill all, item appears |  | 3x Darknut (red) |
| $5D | Key | - | yes | 2x Pols Voice, 2x Gibdo, 2x Keese (blue) |
| $5E | Key | kill all, item appears |  | 5x Darknut (blue) |
| $5F | Compass | - | yes | 8x Pols Voice |
| $6E | 5 Rupees | kill all, item appears |  | Manhandla |
| $7C | (none) | - |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $7D | 5 Rupees | kill all, item appears |  | Manhandla |
| $7E | (none) | - |  | - |
| $7F | Key | - | yes | 3x Bubble (black), 2x Zol, 3x Keese (blue) |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $0F | 63 | Magical Key | $1F / $1F |
| $2F | 62 | (none) | $4C / $3F |
| $6F | 63 | Book of Magic | $7C / $7C |

#### Level 9

Start room $76; triforce room $32; boss room $42; stair rooms $00, $4F, $60, $67, $70, $72, $75, $77; 57 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $01 | (none) | - | yes | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $02 | (none) | - |  | old man: "EYES OF SKULL / HAS A SECRET." |
| $03 | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $04 | (none) | - |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $05 | (none) | push block, stairs open |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $06 | (none) | - |  | old man: "GO TO THE NEXT ROOM." |
| $07 | (none) | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $10 | (none) | push block, stairs open |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $11 | Bombs | kill all, item appears |  | Lanmola (blue) |
| $12 | 5 Rupees | kill all, item appears |  | Lanmola (red) |
| $13 | (none) | - | yes | 2x Bubble (black), 2x Zol, 2x Like Like |
| $14 | (none) | - |  | 5x Like Like |
| $15 | 5 Rupees | kill all, item appears | yes | 3x Wizzrobe (blue) |
| $16 | Bombs | kill all, item appears |  | Patra (2) |
| $17 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $20 | (none) | - |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $21 | (none) | - |  | Patra (1) |
| $22 | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $23 | Bombs | - |  | 8x Gel |
| $24 | (none) | - | yes | 5x Vire |
| $25 | Bombs | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $26 | 5 Rupees | kill all, item appears |  | 8x Gel |
| $27 | Map | kill all, item appears |  | Patra (2) |
| $30 | (none) | push block, stairs open |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $31 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $32 | (none) | kill all, shutters open |  | Zelda |
| $33 | (none) | - | yes | 8x Gel |
| $34 | 5 Rupees | kill all, item appears |  | 8x Keese (blue) |
| $35 | Compass | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $36 | (none) | - |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $37 | Bombs | kill all, item appears |  | 6x Vire |
| $40 | 5 Rupees | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $41 | (none) | - | yes | Trap (4), 4x Like Like |
| $42 | Triforce of Power | last boss | yes | Ganon |
| $43 | (none) | - |  | old man: "PATRA HAS THE MAP." |
| $44 | 5 Rupees | kill all, item appears |  | 6x Wizzrobe (red) |
| $45 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $46 | (none) | - |  | 6x Wizzrobe (blue) |
| $47 | Key | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $50 | (none) | kill all, shutters open | yes | 5x Zol |
| $51 | (none) | kill all, shutters open |  | 6x Like Like |
| $52 | (none) | kill all, shutters open |  | Patra (1) |
| $53 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $54 | (none) | - |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $55 | (none) | - |  | Lanmola (red) |
| $56 | Key | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $57 | Key | kill all, item appears | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $61 | Key | - |  | Patra (1) |
| $62 | 5 Rupees | kill all, item appears |  | 8x Keese (blue) |
| $63 | (none) | - |  | 5x Zol |
| $64 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $65 | (none) | - | yes | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $66 | (none) | - |  | old man: "ONES WHO DOES NOT HAVE / TRIFORCE CAN'T GO IN." |
| $71 | (none) | - |  | - |
| $73 | (none) | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $74 | (none) | - |  | Lanmola (blue) |
| $76 | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $00 | 63 | Red Ring | $07 / $07 |
| $4F | 63 | Silver Arrow | $10 / $10 |
| $60 | 62 | (none) | $14 / $55 |
| $67 | 62 | (none) | $30 / $04 |
| $70 | 62 | (none) | $63 / $05 |
| $72 | 62 | (none) | $71 / $74 |
| $75 | 62 | (none) | $20 / $61 |
| $77 | 62 | (none) | $52 / $03 |

## Appendix E: the 38 ROM texts

| Index | Selector (x2) | Text |
|---|---|---|
| 0 | $00 | IT'S DANGEROUS TO GO / ALONE! TAKE THIS.|
| 1 | $02 | MASTER USING IT AND / YOU CAN HAVE THIS.|
| 2 | $04 | TAKE ANY ROAD YOU WANT.|
| 3 | $06 | SECRET IS IN THE TREE / AT THE DEAD-END.|
| 4 | $08 | LET'S PLAY MONEY / MAKING GAME.|
| 5 | $0A | PAY ME FOR THE DOOR / REPAIR CHARGE.|
| 6 | $0C | SHOW THIS TO THE / OLD WOMAN.|
| 7 | $0E | MEET THE OLD MAN / AT THE GRAVE.|
| 8 | $10 | BUY MEDICINE BEFORE / YOU GO.|
| 9 | $12 | PAY ME AND I'LL TALK.|
| 10 | $14 | THIS AIN'T ENOUGH / TO TALK.|
| 11 | $16 | GO UP,UP, / THE MOUNTAIN AHEAD.|
| 12 | $18 | GO NORTH,WEST,SOUTH, / WEST TO THE FOREST / OF MAZE.|
| 13 | $1A | BOY, YOU'RE RICH!|
| 14 | $1C | BUY SOMETHIN' WILL YA!|
| 15 | $1E | BOY, THIS IS / REALLY EXPENSIVE!|
| 16 | $20 | TAKE ANY ONE YOU WANT.|
| 17 | $22 | IT'S A SECRET / TO EVERYBODY.|
| 18 | $24 | GRUMBLE,GRUMBLE...|
| 19 | $26 | EASTMOST PENNINSULA / IS THE SECRET.|
| 20 | $28 | DODONGO DISLIKES SMOKE.|
| 21 | $2A | DID YOU GET THE SWORD / FROM THE OLD MAN ON / TOP OF THE WATERFALL?|
| 22 | $2C | WALK INTO THE / WATERFALL.|
| 23 | $2E | SECRET POWER IS SAID / TO BE IN THE ARROW.|
| 24 | $30 | DIGDOGGER HATES / CERTAIN KIND OF SOUND.|
| 25 | $32 | I BET YOU'D LIKE / TO HAVE MORE BOMBS.|
| 26 | $34 | IF YOU GO IN THE / DIRECTION OF THE ARROW.|
| 27 | $36 | LEAVE YOUR LIFE / OR MONEY.|
| 28 | $38 | THERE ARE SECRETS WHERE / FAIRIES DON'T LIVE.|
| 29 | $3A | AIM AT THE EYES / OF GOHMA.|
| 30 | $3C | SOUTH OF ARROW MARK / HIDES A SECRET.|
| 31 | $3E | THERE'S A SECRET IN / THE TIP OF THE NOSE.|
| 32 | $40 | SPECTACLE ROCK IS / AN ENTRANCE TO DEATH.|
| 33 | $42 | 10TH ENEMY HAS THE BOMB.|
| 34 | $44 | ONES WHO DOES NOT HAVE / TRIFORCE CAN'T GO IN.|
| 35 | $46 | PATRA HAS THE MAP.|
| 36 | $48 | GO TO THE NEXT ROOM.|
| 37 | $4A | EYES OF SKULL / HAS A SECRET.|
