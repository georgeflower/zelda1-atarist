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
    gvar ENEMY_TYPE, 8          | monster index, 255 for the overworld blobs
    gvar ENEMY_HP, 8
    gvar ENEMY_HURT, 8          | frames left of knock-back invincibility
    gvar ITEM_X, 3
    gvar ITEM_Y, 3
    gvar ITEM_ID, 3
    gvar ITEM_ACTIVE, 3         | 0 none, 1 drop, 2 the room's item
    gvar ITEM_ERASE_VALID, 3

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
    gvar INV_RUPEES, 1
    gvar INV_KEYS, 1
    gvar INV_BOMBS, 1
    gvar HOTSPOT_TILE, 1
    gvar CAVE_SOURCE_ROOM, 1
    gvar CAVE_DOOR_X, 1
    gvar ENEMY_COUNT, 1
    gvar HAS_SWORD, 1
    gvar ATTACK, 1              | frames left of a sword swing
    gvar SWORD_VALID, 1
    gvar SPACE_HELD, 1
    gvar LINK_HURT, 1           | frames of invincibility after a hit
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
    gvar CAVE_PERSON, 1         | the old man is still in the cave
    gvar CAVE_TEXT_ON, 1        | his speech is still being typed, and Link is halted
    gvar CAVE_TEXT_IDX, 1
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
    gvar K_HELD, 1
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

    .equ GLOBALS_BYTES, gvar_offset
