| Variable block layout.
|
| Offsets are generated rather than hand-counted so adding a variable cannot
| silently overlap its neighbour. Longs come first, then words, then bytes,
| so everything that needs even alignment gets it.

    .set gvar_offset, 0

    .macro gvar name, size=1
    .equ OFF_\name, gvar_offset
    .set gvar_offset, gvar_offset + \size
    .endm

    .macro galign
    .set gvar_offset, ((gvar_offset + 1) / 2) * 2
    .endm

    gvar SCREEN_PTR, 4          | visible screen
    gvar BG_CUR, 4              | clean render of the current room
    gvar BG_NEXT, 4             | room being scrolled in
    gvar BASEPAGE, 4
    gvar OLD_SSP, 4
    gvar ERASE_OFFSET, 4        | where the sprite was drawn last frame

    | Per-actor arrays come first: they are indexed as d8(a5,dn), whose
    | displacement is only a signed byte, so every one has to start below 128.
    gvar ENEMY_X, 8
    gvar ENEMY_Y, 8
    gvar ENEMY_DIR, 8
    gvar ENEMY_ACTIVE, 8
    gvar ENEMY_ERASE_VALID, 8
    gvar ENEMY_TYPE, 8          | monster index
    gvar ENEMY_HP, 8
    gvar ENEMY_HURT, 8          | frames left of knock-back invincibility
    gvar ITEM_X, 3
    gvar ITEM_Y, 3
    gvar ITEM_ID, 3
    gvar ITEM_ACTIVE, 3         | 0 none, 1 drop, 2 the room's item
    gvar ITEM_ERASE_VALID, 3
    gvar ENEMY_SHOVE, 8         | direction an enemy is being knocked back in, 0 for none
    gvar ENEMY_STATE, 8         | per-monster behaviour state
    gvar ENEMY_TIMER, 8         | per-monster countdown
    gvar ENEMY_STEP, 8          | wallmaster: where it is along its path

    galign
    gvar ENEMY_ERASE_OFFSETS, 32
    gvar ITEM_ERASE_OFFSETS, 12
    gvar SWORD_ERASE_OFFSET, 4
    gvar BOMB_ERASE_OFFSET, 4
    | What was drawn into the other screen buffer one frame earlier, so it can be erased there.
    gvar OLD_ENEMY_ERASE_OFFSETS, 32
    gvar OLD_ITEM_ERASE_OFFSETS, 12
    gvar OLD_SWORD_ERASE_OFFSET, 4
    gvar OLD_BOMB_ERASE_OFFSET, 4
    gvar OLD_ERASE_OFFSET, 4
    gvar BEAM_ERASE_OFFSET, 4
    gvar OLD_BEAM_ERASE_OFFSET, 4
    gvar RNG, 2

    gvar FRAME_COUNTER, 2
    gvar SCROLL_STEP, 2

    gvar ROOM_ID, 1
    gvar NEXT_ROOM_ID, 1
    gvar LINK_X, 1
    gvar LINK_Y, 1
    gvar LINK_DIR, 1
    gvar LINK_ANIM_FRAME, 1
    gvar LINK_ANIM_COUNTER, 1
    gvar LINK_POS_FRAC, 1
    gvar PREV_INPUT_DIR, 1
    gvar GAME_MODE, 1
    gvar SCROLL_DIR, 1
    gvar SCROLL_FROM_X, 1
    gvar SCROLL_FROM_Y, 1
    gvar SCROLL_TO_X, 1
    gvar SCROLL_TO_Y, 1
    gvar ERASE_VALID, 1
    gvar HUD_DIRTY, 1
    gvar EXIT_REQUESTED, 1
    gvar HEART_CONTAINERS, 1
    gvar HP_HALVES, 1           | Link's life in half hearts
    gvar HIT_DAMAGE, 1          | hits' worth of the blow hit_enemy is about to deal; 0 means one
    gvar HP_FRAC, 1             | how far below that count he really is, in 128ths of a half heart (a ring halves the blows)
    gvar INV_RUPEES, 1
    gvar INV_KEYS, 1
    gvar HOTSPOT_TILE, 1
    gvar CAVE_SOURCE_ROOM, 1
    gvar CAVE_DOOR_X, 1
    gvar ENEMY_COUNT, 1
    gvar ITEMS, 32              | the original's Items block, one byte per item slot (sword grade, bombs, ...)
    .equ OFF_HAS_SWORD, OFF_ITEMS + 0           | sword grade: 0 none, 1 wood, 2 white, 3 magic
    .equ OFF_INV_BOMBS, OFF_ITEMS + 1
    .equ OFF_INV_ARROW, OFF_ITEMS + 2           | 0 none, 1 wooden, 2 silver
    .equ OFF_INV_BOW, OFF_ITEMS + 3
    .equ OFF_INV_CANDLE, OFF_ITEMS + 4          | 1 blue (once a screen), 2 red
    .equ OFF_INV_RECORDER, OFF_ITEMS + 5
    .equ OFF_INV_FOOD, OFF_ITEMS + 6
    .equ OFF_INV_POTION, OFF_ITEMS + 7          | 0 none, 1 blue, 2 red (two bottles at most)
    .equ OFF_INV_ROD, OFF_ITEMS + 8
    .equ OFF_INV_RAFT, OFF_ITEMS + 9
    .equ OFF_INV_BOOK, OFF_ITEMS + 10
    .equ OFF_INV_RING, OFF_ITEMS + 11           | 0 none, 1 blue, 2 red
    .equ OFF_INV_LADDER, OFF_ITEMS + 12
    .equ OFF_INV_MAGIC_KEY, OFF_ITEMS + 13
    .equ OFF_INV_BRACELET, OFF_ITEMS + 14
    .equ OFF_INV_LETTER, OFF_ITEMS + 15
    .equ OFF_INV_CLOCK, OFF_ITEMS + 21          | the clock: monsters freeze until Link leaves the screen
    .equ OFF_INV_BOOMERANG, OFF_ITEMS + 29
    .equ OFF_INV_MAGIC_BOOMERANG, OFF_ITEMS + 30
    .equ OFF_INV_MAGIC_SHIELD, OFF_ITEMS + 31
    gvar ATTACK, 1              | frames left of a sword swing
    gvar SWORD_VALID, 1
    gvar SPACE_HELD, 1
    gvar LINK_HURT, 1           | frames of invincibility after a hit
    gvar LINK_SHOVE, 1          | pixels of knock-back still to go
    gvar LINK_SHOVE_DIR, 1
    gvar KILL_CYCLE, 1          | WorldKillCycle: picks the column of the drop table
    gvar ROOM_TRIGGER, 1
    gvar ROOM_UNSUPPORTED, 1    | living monsters this port cannot draw yet
    gvar OBJ_LEFT, 1            | room bounds for objects other than Link
    gvar OBJ_RIGHT, 1
    gvar OBJ_UP, 1
    gvar OBJ_DOWN, 1
    gvar BOMB_TIMER, 1          | frames until the bomb goes off, 0 when none
    gvar BOMB_X, 1
    gvar BOMB_Y, 1
    gvar BOMB_VALID, 1
    gvar B_HELD, 1
    gvar JOY0, 1                | IKBD joystick state: bits 0-3 up, down, left, right; bit 7 fire
    gvar JOY1, 1
    gvar IKBD_PKT, 1            | which byte of a joystick or mouse packet comes next
    gvar CAVE_PERSON, 1         | the old man is still in the cave
    gvar CAVE_TEXT_ON, 1        | his speech is still being typed, and Link is halted
    gvar CAVE_TEXT_COL, 1
    gvar CAVE_TEXT_ROW, 1
    gvar CAVE_TEXT_TIMER, 1
    gvar DBL_ACTIVE, 1          | 1 while play frames alternate between two screen buffers
    gvar OLD_ENEMY_ERASE_VALID, 8
    gvar OLD_ITEM_ERASE_VALID, 3
    gvar OLD_SWORD_VALID, 1
    gvar OLD_BOMB_VALID, 1
    gvar OLD_ERASE_VALID, 1
    gvar BEAM_ACTIVE, 1         | the sword's shot flying through the room
    gvar BEAM_X, 1
    gvar BEAM_Y, 1
    gvar BEAM_DIR, 1
    gvar BEAM_VALID, 1
    gvar OLD_BEAM_VALID, 1
    gvar IN_CELLAR, 1           | cellar index + 1 while Link is in a cellar
    gvar CELLAR_SOURCE, 1       | the room whose stairs he took
    gvar CELLAR_ROOM, 1         | the cellar's own room id, for its item flag
    gvar OLD_SCREEN_HI, 1
    gvar OLD_SCREEN_MID, 1
    gvar OLD_SCREEN_LOW, 1
    gvar OLD_SHIFT_MODE, 1
    gvar OLD_IERB, 1
    gvar OLD_IMRB, 1
    gvar LEVEL, 1               | 0 overworld, otherwise the underworld level
    gvar BOUND_LEFT, 1          | room bounds for the current world
    gvar BOUND_RIGHT, 1
    gvar BOUND_UP, 1
    gvar BOUND_DOWN, 1
    gvar EXIT_GUARD, 1          | set when Link has just stepped out of a cave or level
    gvar UW_ENTER_MASK, 1       | door held open because Link came through it
    gvar UW_NEXT_MASK, 1
    gvar WARPED, 1              | Link changed world during this step
    gvar COMMIT, 1              | pixels left in the grid step Link is making

    galign
    gvar OLD_PALETTE, 32
    gvar KEY_STATES, 128
    gvar UW_OPEN, 128           | doors opened, one mask per room id
    gvar UW_FLAGS, 128          | per room: bit 0 enemies cleared, bit 1 item taken
    galign
    gvar UW_MAP, 704            | UW_ROOM_BYTES; the test harness parses plain numbers
    gvar UW_MAP_NEXT, 704

    | Music: three register-stream contexts (song, voice A effect, voice B effect), see music.s
    galign
    .equ MUSC_SIZE, 32
    gvar MUS_CTX, 128          | 4 * MUSC_SIZE; the screenshot harness parses plain numbers
    gvar MUS_BANK, 4           | music_bank, as an absolute address
    gvar MUS_ENGINE, 4
    gvar MUS_OUT, 14           | the PSG registers R0-R13 as last merged
    gvar MUS_TRIG, 1           | the frame's digidrum trigger
    gvar MUS_FORCED, 1         | an event song (item, triforce, ...) owns the song context

    galign
    gvar PRESENT_BASE, 4       | buffer handed to the shifter at the end of the last play frame
    gvar PRESENT_PENDING, 1    | wait_vbl still has to confirm the shifter took it

    | Projectiles: one row of eight per field, in the order ai.s indexes them from PROJ_KIND.
    galign
    gvar PROJ_KIND, 8
    gvar PROJ_X, 8
    gvar PROJ_Y, 8
    gvar PROJ_DIR, 8
    gvar PROJ_QX, 8
    gvar PROJ_QY, 8
    gvar PROJ_FRACX, 8
    gvar PROJ_FRACY, 8
    gvar PROJ_TIMER, 8
    gvar PROJ_OWNER, 8
    gvar PROJ_ERASE_VALID, 8
    gvar OLD_PROJ_ERASE_VALID, 8
    gvar PROJ_ERASE_OFFSETS, 32
    gvar OLD_PROJ_ERASE_OFFSETS, 32
    gvar WALL_TIMER, 1         | frames before the next wallmaster may come out of a wall
    gvar LINK_HELD, 1          | a wallmaster has him
    gvar TRIFORCE, 1           | the level's triforce piece is his
    gvar ENDING_TIMER, 1       | frames left of the triforce celebration
    gvar ENEMY_SPEED, 8        | keese: flying speed
    gvar ENEMY_FRAC, 8         | keese: position fraction
    gvar MUS_SKIP, 1           | counts VBLs at 60 Hz; the song is written for 50
    gvar WORLD_KILLS, 1        | WorldKillCount
    gvar HELP_COUNT, 1         | HelpDropCount: kills since Link was last hurt, up to 10
    gvar HELP_VALUE, 1         | the tenth was a bomb kill: the help drop is a bomb
    gvar HIT_BY_BOMB, 1        | the hit being dealt comes from a bomb
    gvar ITEM_LIFE, 3          | a dropped item's lifetime: $FF counting down every second frame
    gvar CLOUD_TIMER, 1        | frames left of the bomb's cloud
    gvar CLOUD_X, 1
    gvar CLOUD_Y, 1
    gvar FLASH_ON, 1           | the screen is grey for the bomb's flash
    gvar SPARK_K, 1            | the sword shot's spark: how far its corners have spread, 0 for none
    gvar SPARK_X, 1
    gvar SPARK_Y, 1

    | Effect sprites (spark corners and cloud puffs) have a slot each for erasing.
    galign
    gvar FX_ERASE_OFFSETS, 144
    gvar OLD_FX_ERASE_OFFSETS, 144
    gvar FX_VALID, 36
    gvar OLD_FX_VALID, 36
    gvar CAVE_FIRE_OFFSETS, 8  | where the two bonfires were drawn, to put the cave floor back
    gvar CAVE_FIRE_VALID, 1

    galign
    gvar OLD_IKBD_VEC, 4       | TOS' own IKBD interrupt handler

    gvar B_ITEM, 1             | what the B button uses: 0 nothing, 1 bombs, 2 boomerang, 3 candle
    gvar CANDLE_USED, 1        | the candle can be lit once in a room
    gvar MENU_KEYS, 1          | keys the inventory screen saw last frame: 1 tab, 2 left, 4 right
    gvar FIRE_STATE, 1         | the candle's flame: 0 none, 1 moving, 2 standing
    gvar FIRE_X, 1
    gvar FIRE_Y, 1
    gvar FIRE_DIR, 1
    gvar FIRE_TIMER, 1
    gvar BLOCK_STATE, 1        | the room's push block: 0 none, 1 waiting, 2 pushed, 3 sliding
    gvar BLOCK_X, 1
    gvar BLOCK_Y, 1
    gvar BLOCK_PUSH, 1         | frames Link has been pushing it
    gvar BLOCK_TICK, 1         | he pushed it this frame
    gvar ENEMY_STUN, 8         | frames a monster stays stunned
    gvar ENDING_PHASE, 1       | the triforce ending: 0 none, 1 hold, 2 flash, 3 hearts, 4 curtain, 5 pause
    gvar TRIFORCE_PIECES, 1    | bit n: the triforce piece of level n+1 is his (InvTriforce)
    gvar ENDING_STEP, 1        | curtain columns closed from each side so far
    gvar ROOM_BLOCK, 1         | the underworld room has a push block (attribute D bit 6)
    gvar INV_MAP, 1            | bit n: he has the map of level n+1 (InvMap)
    gvar INV_COMPASS, 1        | bit n: he has the compass of level n+1 (InvCompass)
    galign
    gvar MINIMAP_SIG, 2        | what the ribbon's map last showed: room id, flags, blink phase
    gvar UW_PERSON, 1          | the dungeon room's old man: 0 nobody, 1 speaking, 2 has spoken
    galign
    gvar ENEMY_TURN, 8         | frames until a wanderer may turn toward Link again (ObjTurnTimer)
    gvar ENEMY_WANT, 8         | a goriya that has Link in range (ObjWantsToShoot)
    gvar ENEMY_SHOOT, 8        | an overworld walker's shooting timer: $30 down to 0, it shoots at $10 (ObjShootTimer)
    gvar LIFT_TIMER, 1         | frames left of Link holding a new weapon up (ItemLiftTimer)

    gvar PAL_LEVEL, 1          | the level whose palette the ST is showing (0 = overworld); palette_sync follows OFF_LEVEL

    gvar ROOM_HIST, 6          | the last six overworld screens entered (RoomHistory)
    gvar ROOM_HIST_I, 1        | where the next one goes (CurRoomHistoryIndex)
    gvar ROOM_KILLS, 1         | monsters killed on this screen so far (RoomKillCount)
    gvar ROOM_OBJ, 1           | how many monsters this screen started with (RoomObjCount)
    gvar SPAWNED_ROOM, 1       | the overworld screen whose monsters are on show
    gvar SPAWNED_VALID, 1      | SPAWNED_ROOM holds one
    gvar EDGE_PENDING, 1       | monsters still to walk in from the edge of the screen
    gvar EDGE_NEXT, 1          | the slot the next one takes
    gvar EDGE_TIMER, 1         | tenths of a second until the next one comes (MonstersFromEdgesLongTimer)
    gvar EDGE_CELL, 1          | the last edge square a monster came in at (CurEdgeSpawnCell), 0 = the first one, $40
    gvar OW_KILLS, 128         | per overworld screen, the room flags: low three bits the kills remembered, bit 7 a secret found, bit 5 a rock pushed
    gvar OWS_UNDO_N, 1         | squares a pushed rock or gravestone changed (secrets.s), to put back when he leaves
    gvar OWS_UNDO_ROOM, 1      | the screen they belong to
    gvar OWS_FRESH, 1          | the next render_room shows the push, it does not undo it
    gvar OWS_UNDO, 32          | up to sixteen (square, metatile) pairs (a screen full of armos)
    | The movers (movers.s): per-monster fields of tektites, boulders, leevers, zoras and peahats. They are
    | one block so clear_enemies can wipe them together; the four counters follow the eight rows.
    gvar ENEMY_GHOST, 8        | bit 0: weapons pass through it; bit 1: it does Link no harm (burrowed, submerged, flying high)
    gvar ENEMY_ANIMC, 8        | animation counter (ObjAnimCounter)
    gvar ENEMY_ANIMF, 8        | animation frame, 0 or 1 (ObjAnimFrame)
    gvar ENEMY_JY, 8           | a jumper's vertical speed, whole pixels (signed)
    gvar ENEMY_JF, 8           | and its fraction
    gvar ENEMY_REV, 8          | how many jumps in a row ran into a room bound (Jumper_ObjReversalCount)
    gvar ENEMY_TGT, 8          | where the jump is to land (Jumper_ObjTargetY)
    gvar ENEMY_DIST, 8         | a flyer's distance travelled (Flyer_ObjDistTraveled)
    gvar RED_LEEVER_LONG, 1    | RedLeeverLongTimer, in tenths of a second
    gvar RED_LEEVERS, 1        | ActiveRedLeeverCount
    gvar ZORA_ACTIVE, 1        | ZoraActive
    gvar BOULDERS, 1           | ActiveBoulders
    gvar ATTACK_ROD, 1         | the swing is the rod's
    gvar HEART_FILL, 1         | a potion is filling his hearts
    gvar HEART_FILL_T, 1
    gvar FLUTE_TIMER, 1        | the recorder's tune is playing
    gvar FOOD_TIMER, 1         | the food is on the floor
    gvar CHASE_X, 1            | ChaseTargetX/Y: Link, or the food
    gvar CHASE_Y, 1
    galign
    gvar EDGE_REC, 4           | the record of the screen whose monsters are coming in from the edge
    gvar MON_SPR, 4            | the monster pictures in use: the overworld's (mon_sprites, found at start-up, see init_pointers) or the dungeon's
    | The tables of the dungeon Link is in, set by uw_select_level from level_table (levels.inc), in this order.
    gvar UWP_ROOM_INDEX, 4
    gvar UWP_ROOMS, 4
    gvar UWP_DOORS, 4
    gvar UWP_TILES, 4
    gvar UWP_TILE_NES, 4
    gvar UWP_ROOM_INFO, 4
    gvar UWP_CELLAR_MAPS, 4
    gvar UWP_CELLAR_INFO, 4
    gvar UWP_MON_ART, 4
    gvar UWP_QUADS, 4
    gvar UWL_BYTES, 8
    .equ OFF_UW_START_ROOM, OFF_UWL_BYTES + 0
    .equ OFF_UW_START_Y, OFF_UWL_BYTES + 1
    .equ OFF_UW_TRIFORCE_ROOM, OFF_UWL_BYTES + 2
    .equ OFF_UW_MAP_COL0, OFF_UWL_BYTES + 3
    .equ OFF_UW_CELLARS, OFF_UWL_BYTES + 4
    .equ OFF_UW_BOSS_ROOM, OFF_UWL_BYTES + 5
    .equ OFF_UW_STAIRS_ID, OFF_UWL_BYTES + 6     | the first of the four stairs tiles in the level's bank (0 = none)

    | A Dodongo is two sprites wide: the second one's erase offsets, and Moldorm's chain fields.
    galign
    gvar ENEMY_ERASE2_OFFSETS, 32
    gvar OLD_ENEMY_ERASE2_OFFSETS, 32
    gvar ENEMY_OLDDIR, 8       | a Moldorm segment's previous heading, which the segment below it takes up
    gvar ENEMY_BOUNCE, 8       | a Moldorm head's heading after bouncing off a wall, kept for the next turn (Moldorm_ObjBounceDir)

    galign
    gvar CAVE_TEXT_IDXW, 2     | where the next letter is in cave_text (a word: the dungeons' speeches add up to more than 255)

    | Weapons and the dungeon monsters (dmon.s).
    gvar HIT_TYPE, 1           | the damage type of the blow hit_enemy is about to deal (HIT_*): which weapon it is
    gvar HIT_DIR, 1            | and the way the weapon points, for the darknuts' shields
    gvar DRAW_DY, 1            | pixels (signed) to draw the monster lower than it stands: the vire's hops
    gvar SWORD_BLOCK, 1        | frames left that a bubble keeps Link from swinging his sword
    gvar LINK_EATEN, 1         | a like-like has him: he cannot walk, but he can swing
    gvar EATER, 1              | the like-like's slot
    gvar EATEN_FRAMES, 1       | frames since it caught him, to the shield's loss
    gvar BOSS_BUSY, 1          | a boss is putting its pieces down: they are not bosses themselves
    | The boss sprite pool (Gleeok's body and necks): up to 24 pictures a frame, drawn in effect slots 12 up.
    gvar BP_FRAME, 24          | the image in the body's art
    gvar BP_X, 24
    gvar BP_Y, 24
    gvar BP_COUNT, 1
    gvar GLEEOK_DEAD, 1        | the necks that have been cut off, a bit each
    gvar GLEEOK_ANIM, 2        | the body's picture timer and picture
    gvar GSEG_X, 12            | the middle segments of the four necks, three each
    gvar GSEG_Y, 12
    gvar SKIP_DRAW, 1          | the update that is running draws nothing (see catch_up)
    galign
    gvar LATE_FRAMES, 2        | how many times a slow frame was caught up
    gvar LAST_CLOCK, 4         | the VBL clock when the last frame began
    gvar ROOM_DARK, 1          | this room is dark by nature (bit 7), until it is lit
    gvar ROOM_LIT, 1           | the candle has lit it
    gvar STASH_ROOM, 1         | the rupee stash's room (bit 7 set) while its rupees are on the floor
    gvar GRUMBLE_ON, 1        | Grumble stands in this room, waiting for food
    galign
    gvar STASH_MASK, 2         | the rupees of the stash still lying there, a bit each
    gvar GLEEOK_GONE, 1        | the room (bit 7 set) whose Gleeok has just died: the room is drawn without its body
    gvar PATRA_MAN, 1          | Patra's maneuver: 0 or 1, flipping every $FF frames (the children's radii follow it)
    gvar PATRA_MTIMER, 1
    gvar PATRA_RX, 1           | the radii the children orbit at now, and so on towards the maneuver's
    gvar PATRA_RY, 1
    gvar GANON_SCENE, 1        | Ganon's room: 1 the room is dark and Link waits, 2 he holds up the Triforce of Courage, 0 the fight
    gvar GANON_TIMER, 1
    gvar ZELDA_SCENE, 1        | Zelda's room: 0 nothing yet, 1-8 the scene (zelda_tick in bosses.s)
    gvar ZELDA_TIMER, 1
    gvar ZELDA_STEP, 1
    gvar MAX_BOMBS, 1          | what Link can carry: 8, and four more for each offer of the "more bombs" man
    gvar UW_PERSON_KIND, 1     | the man in this room: 0 only talks, 1 sells bomb capacity, 2 life or money
    gvar UW_PERSON_WARES, 1    | his prices and goods are on show
    gvar UW_PERSON_TIMER, 1    | the frames before he vanishes, once something was taken
    gvar GLEEOK_SEGS, 1        | one more than the middle segments a neck has: its pictures are drawn as the frame allows
    gvar CAVE_TYPE, 1          | the cave's index in cave_table
    gvar CAVE_STATE, 1         | the person's state, CS_* in caves.s
    gvar CAVE_FLAGS, 1         | the cave flags: pick up, pay, show wares and prices, hint, money game, hearts, minus signs
    gvar CAVE_WHO, 1           | 0 old man, 1 old woman, 2 shopkeeper, 3 moblin
    gvar CAVE_CHOSEN, 1        | the ware Link touched
    gvar CAVE_TIMER, 1         | frames until the cave empties after something was taken
    gvar CAVE_ROOMKIND, 1      | 0 the usual cave, 1 the take-any-road room
    gvar CAVE_ICON, 1          | the price tag's rupee is on show
    gvar CAVE_B, 1             | B was down last frame (the letter)
    gvar RUPEES_ADD, 1         | rupees still to be paid out, one every other frame
    gvar RUPEES_SUB, 1         | rupees still to be paid
    gvar CAVE_ITEMS, 3         | the wares (id, $3F none, $FF taken)
    gvar CAVE_PRICES, 3
    gvar CAVE_AMOUNTS, 3       | the money game's hidden amounts
    gvar CAVE_SPR_VALID, 2     | the person and the rupee tag were drawn
    galign
    gvar CAVE_SPR_OFFS, 8
    gvar RAFT_STATE, 1         | 0 none, 1 the raft takes Link down to the dock, 2 up and off the screen
    gvar RAFT_REST, 1          | he has just been brought to the dock: no new ride until he moves
    gvar LADDER_SHOWN, 1       | the ladder is on show in item slot 2
    gvar MAZE_STEP, 1          | the Lost Woods / Lost Hills: how many of the four moves were right
    gvar HOT_COL, 1            | the tile link_collide last looked at: its column and row in the 32x22 tile grid
    gvar HOT_ROW, 1
    gvar WHIRL_TELE, 1         | the whirlwind and Link: 1 carries him off, 4 reached the edge, 3 on its way, 2 sets him down
    gvar WHIRL_SUMMONED, 1     | SummonedWhirlwind
    gvar TELE_INDEX, 1         | TeleportingLevelIndex: the level whose entrance the next whirlwind goes to, less one
    gvar POND_CYCLE, 1         | SecretColorCycle: the recorder's pond in screen $42, 1 to $B while the water changes
    gvar POND_WALK, 1          | the water can be walked on (ObjectFirstUnwalkableTile is $99)
    gvar FAIRY_ON, 1           | bit n: heart n of the pond fairy is out
    gvar ENEMY_CLOUD, 8        | per monster: 0, or the picture (1-3) of the spawn cloud it is still in; it neither moves nor harms nor can be hurt
    gvar ENEMY_CLOUD_T, 8      | frames left of that picture (ObjTimer)
    galign
    gvar FAIRY_ANG, 16         | each heart's angle: whole in the high byte, fraction in the low
    gvar INTRO_TOP, 2          | the title and the story (intro.s): the scroll, CurVScroll counted on from the first page
    gvar INTRO_STEP, 2         | lines the parade has scrolled (ScrolledLineCount)
    gvar INTRO_TIMER, 2        | DemoTimer, counted in frames
    gvar INTRO_FRAME, 2        | FrameCounter
    gvar INTRO_RING, 2         | the ring slot of the window's top line
    gvar INTRO_PHASE, 1        | DemoPhase: 0 the title, 1 the story
    gvar INTRO_SUB, 1          | DemoSubphase
    gvar INTRO_FADE, 1         | DemoPhase0Subphase1Cycle
    gvar INTRO_FADE_T, 1       | DemoPhase0Subphase1Timer
    gvar INTRO_GLOW_T, 1       | TriforceGlowTimer
    gvar INTRO_GLOW_I, 1       | TriforceGlowCycle
    gvar INTRO_WAVES, 3        | TitleWaveYs
    gvar INTRO_KEYS, 1         | Start was down last frame
    | The file menu (filesel.s): the three slots the player can choose from, and the screen's state.
    gvar FILE_SCREEN, 1        | 0 player select (mode 1), 1 register your name (mode E), 2 elimination (mode F)
    gvar FILE_SEL, 1           | CurSaveSlot: 0-2 a slot, 3 REGISTER (select) or END, 4 ELIMINATION
    gvar FILE_DOWN, 1          | ButtonsDown, laid out like the NES's: A B Select Start Up Down Left Right
    gvar FILE_PRESSED, 1       | ButtonsPressed
    gvar FILE_COL, 1           | the character of the name the next letter goes to (NameCharOffset)
    gvar FILE_BOARD, 1         | CharBoardIndex
    gvar FILE_BOARD_X, 1       | ObjX+1, ObjY+1: the character board's cursor
    gvar FILE_BOARD_Y, 1
    gvar FILE_HOLDING, 1       | StillHoldingButton
    gvar FILE_HELD, 1          | HeldButton
    gvar FILE_REPEAT_SUB, 1    | SubsequentButtonRepeat
    gvar FILE_REPEAT_T, 1      | ButtonRepeatTimer
    gvar FILE_HEART_Y, 1       | the NES y of the heart on show, 0 for none
    gvar PROFILE, 1            | the slot being played
    gvar SLOT_ACTIVE, 5        | IsSaveSlotActive: the slots, then the two options (always on)
    gvar SLOT_NAMES, 24        | Names: eight tiles each, $24 is a space
    galign
    gvar SLOT_HEARTS, 6        | SaveSlotHearts: the hearts value and the partial heart of each
    gvar SLOT_DEATHS, 3        | DeathCounts
    gvar SLOT_QUEST, 3         | QuestNumbers
    gvar SLOT_RING, 3          | the ring Link wears (0 none, 1 blue, 2 red)
    galign
    gvar FILE_BLK, 8           | the two block cursors on show: x and screen line of each, -1 for none
    | Link's death (death.s) and the saved games (save.s).
    gvar DYING, 1              | link_dies was called: the frame ends, then death_begin takes over
    gvar DEATH_PHASE, 1        | see death.s
    gvar DEATH_TURNS, 1        | DeathModeCounter: the turns Link still has to make
    gvar DEATH_STEP, 1         | the fade's step
    gvar DEATH_SPARK, 1        | DeathModeCounter again: how long the spark lasts
    gvar DEATH_VIS, 1          | Link is drawn this frame (he flashes)
    gvar FILE_FLASH, 1         | the frames the chosen word of the continue question still flashes (ObjTimer+1), 0 for none
    gvar PATCH_N, 1            | the secrets the overworld screens have been changed by (secrets.s)
    galign
    gvar DEATH_T, 2            | ObjTimer+11: the frames to wait
    gvar DEATH_LINE, 2         | the lines of the playfield that are red
    gvar DEATH_W, 64           | for each colour slot, the two pixel masks that say where it goes (W0 then W1)
    gvar PATCHES, 192          | room, square, the metatile that was there and the one that is: 48 of them
    gvar SAVE_FILE, 2696       | ZELDA.SAV as it is on the disk: 8 bytes of header, three records of 640, three of 256 (the flags of Levels 7-9)
    gvar FAIRY_STATE, 3        | a dropped fairy's flight (ControlFairyFlight), one per item slot: 0 speeding up, 1 deciding, 3 wandering
    gvar FAIRY_SPEED, 3
    gvar FAIRY_FRAC, 3
    gvar FAIRY_TURNS, 3
    gvar FAIRY_TIMER, 3
    gvar FAIRY_DIR, 3
    gvar HELD_DIRS, 1            | every direction held this frame (a diagonal has two bits)
    gvar MENU_PHASE, 1           | which of the cursor's two colours the inventory screen shows
    gvar PERSON_FIRE, 1          | the old man was hit: his two flames shoot (PersonFireballsEnabled)
    gvar PERSON_FIRE_T, 2        | each flame's wait before its next shot (Statue_ObjFireballTimer)
    gvar BLOCK_DIR, 1            | the way the push block slides (the pushing direction, DIR_* bits)
    gvar BLOCK_FRAME, 1          | frames it has slid, 0..16 (BLOCK_STATE 3 while it slides)
    gvar BLOCK_TILES, 8          | its four tiles, then the four floor tiles it slides onto
    galign
    gvar BLOCK_SPRITE, 160       | the block's picture, grabbed from the clean room, drawn as effect slot 11 while it slides
    gvar ROOM_ROAR, 1            | attribute E's sound index of this dungeon room: 0 none, 1-3 the boss roar it can hear
    gvar ROAR_TIMER, 1           | frames until the ambient roar sounds again (SampleCounter)
    gvar ROAR_ROOM, 1            | the room the roar timer was started in, $FF outside the dungeons
    gvar GANON_CLOUD, 1          | Ganon_ObjCloudDist: how far from the ashes the eight clouds of the burst are, 8 down to 0
    gvar GANON_RAY_X, 8          | the burst's eight rays (Ganon_SetUpBurstRays): X and Y of each
    gvar GANON_RAY_Y, 8
    gvar ROCK_STATE, 1           | a pushed rock or gravestone is sliding (secrets.s rock_*): 0 no, 1 yes
    gvar ROCK_FRAME, 1           | frames it has slid, 0..32 (half a pixel each)
    gvar ROCK_DIR, 1             | the way it slides: DIR_UP or DIR_DOWN
    gvar ROCK_X, 1               | where it began: X and Y of its square
    gvar ROCK_Y, 1
    gvar LADDER_DIR, 1           | the dungeon's ladder over a moat (owspec.s uw_ladder_*): the way it points (DIR_*)
    gvar LADDER_STATE, 1         | 1 laid down in front of Link, 2 he stands on it (ObjState of the ladder)
    gvar LADDER_ROOM, 1          | the room it was laid in
    gvar CAVE_TEXT_PEACE, 1      | cave_talk is typing the ending's last words: three lines placed as the ROM does, 8 frames a letter, no blip on spaces
    gvar QUEST, 1                | the quest of the game that runs (QuestNumbers of its slot): 0 First, 1 Second; set by quest_apply
    gvar QUEST_APPLIED, 1        | the quest the overworld's tables are in now (quest_apply swaps the Second Quest's differences in and out)
    gvar DEBUG_ROOM, 1           | T toggles it: the ribbon shows the room id (RM-xx, or CL-xx in a cellar)
    gvar T_HELD, 1               | T was down last frame (edge trigger)
    gvar ENEMY_BOMBS, 8          | the bombs a Dodongo has swallowed (Dodongo_ObjBombHits); not ENEMY_WANT, which wander_tick clears
    gvar SWORD_LOCK, 1           | SwordBlocked: a red bubble ($2D) has locked the sword until a blue one ($2C) or a full refill of hearts frees it
    galign
    gvar UW_BLOCK, 2             | what to add to the address of UW_OPEN / UW_FLAGS: 0 in Levels 1-6, UW_B_DELTA in Levels 7-9
    gvar UW_OPEN_B, 128          | doors opened in the rooms of Levels 7-9 (the ROM keeps one set of world flags for Levels 1-6, another
    gvar UW_FLAGS_B, 128         | for 7-9, LevelInfo_WorldFlagsAddr: every room id exists in both groups, so the two must not be mixed)
    gvar PICKUP_DROPS, 1         | set while the boomerang takes items: the room's own item is not for it
    gvar HOLD_SKIP, 1            | counts VBLs at 60 Hz: every sixth one passes without a game update, so 60 Hz plays at the speed of 50
    galign
    gvar LEVEL_BUF, 4            | the level buffer (loader.s): the LEVEL<n>.DAT of the dungeon Link is in, read there
    gvar MON_SPR_LV, 4           | the monster pictures of that dungeon (in the buffer)
    gvar MON_SPR_OW, 4           | the overworld's, resident; MON_SPR is the set in use: mon_spr_select follows OFF_LEVEL
    gvar LOAD_KEY, 2             | which record's file the buffer holds: the record number + 1, 0 = none
    gvar HOME_SCREEN, 4          | the three screens as init_buffers left them: the one TOS gave the program, then two of our own,
    gvar HOME_CUR, 4             | (the intro and the credits move them about and put them back; these three stay in a row)
    gvar HOME_NEXT, 4
    gvar QUIT_SEL, 1             | the Esc menu: the line the heart is on
    gvar QUIT_KEYS, 1            | the keys it saw down last frame (quit.s)
    gvar MENU_CAVE, 1            | the inventory screen was opened inside a cave (Tab there shows the letter to the old woman): menu_close goes back to it
    gvar FILE_CONFIRM, 1         | the continue question's "are you sure" about RETRY is on show (filesel.s)
    galign
    gvar IVP, 68                 | where each table of INTRO.DAT is while the buffer holds it (INTRO_TABLE_COUNT longs; ivtab, loader.s)
    .equ GLOBALS_BYTES, gvar_offset
    .ifdef INTRO_TABLE_COUNT           | (the unit-test harnesses do not read level_buffer.inc)
    .if OFF_IVP + 4 * INTRO_TABLE_COUNT != GLOBALS_BYTES
    .error "IVP is 4 bytes for each table of INTRO.DAT: keep gvar IVP in step with INTRO_TABLES in build_assets.py"
    .endif
    .endif

| The world flags of the dungeon Link is in: UW_OPEN and UW_FLAGS belong to Levels 1-6, the two arrays at the end to Levels 7-9, the
| same distance from them both (uw_select_level sets UW_BLOCK). uwlea OPEN, %a0 / uwlea FLAGS, %a0 leaves the flags alone.
    .equ UW_B_DELTA, OFF_UW_OPEN_B - OFF_UW_OPEN
    .if (OFF_UW_FLAGS_B - OFF_UW_FLAGS) != UW_B_DELTA
    .error "UW_OPEN_B and UW_FLAGS_B must lie as far from UW_OPEN and UW_FLAGS as each other"
    .endif
    .macro uwlea name, reg
    lea OFF_UW_\name(%a5), \reg
    adda.w OFF_UW_BLOCK(%a5), \reg
    .endm
