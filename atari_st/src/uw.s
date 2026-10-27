| Underworld: tile rooms, doors, and the way in and out of a level.
|
| tools/underworld.py rebuilds the 32x22 tile map LayOutRoom makes for every
| room of the level, with the doors shown closed. Here a copy of the current
| room is patched with the doors that are open and drawn tile by tile; the
| copy is also what collision reads, so an opened door becomes walkable.

    .equ DOOR_SHUTTER, 7
    .equ DOORWAY_LANE_X, 0x78       | where a vertical doorway sits
    .equ DOORWAY_LANE_Y, 0x8d       | where a horizontal doorway sits
    .equ DOORWAY_SLACK, 6
    .equ SCAN_K, 0x25
    .equ SCAN_T, 0x14

| Temporary: K hands out a key, bombs and the candle, until every source of them exists.
debug_keys:
    bsr debug_room_toggle
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_K(%a0)
    beq 2f
    tst.b OFF_K_HELD(%a5)
    bne 9f
    move.b #1, OFF_K_HELD(%a5)
    move.b #1, OFF_INV_CANDLE(%a5)
    cmpi.b #8, OFF_INV_BOMBS(%a5)
    bhs 3f
    addq.b #4, OFF_INV_BOMBS(%a5)
3:  bsr b_item_fix
    cmpi.b #9, OFF_INV_KEYS(%a5)
    bhs 9f
    addq.b #1, OFF_INV_KEYS(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    bra 9f
2:  clr.b OFF_K_HELD(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

| T switches the room id on the ribbon on and off (edge triggered, like K).
debug_room_toggle:
    move.l %a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_T(%a0)
    beq 2f
    tst.b OFF_T_HELD(%a5)
    bne 9f
    move.b #1, OFF_T_HELD(%a5)
    eori.b #1, OFF_DEBUG_ROOM(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    bra 9f
2:  clr.b OFF_T_HELD(%a5)
9:  movea.l (%sp)+, %a0
    rts

| A room is stored as 16x11 squares, each a number into the level's quad table (four bank ids: top-left,
| top-right, bottom-left, bottom-right). a2 = the 176 square numbers, a1 = the 704-cell map to fill.
uw_unpack_room:
    movem.l %d0-%d3/%a0-%a3, -(%sp)
    lvtab QUADS, %a3
    moveq #(UW_SQUARE_ROWS - 1), %d3
1:  movea.l %a1, %a0
    moveq #(UW_SQUARE_COLS - 1), %d2
2:  moveq #0, %d0
    move.b (%a2)+, %d0
    lsl.w #2, %d0
    move.l 0(%a3, %d0.w), %d1
    move.w %d1, UW_COLS(%a0)        | the low word is the bottom pair
    swap %d1
    move.w %d1, (%a0)+              | the high word the top pair
    dbra %d2, 2b
    lea (2 * UW_COLS)(%a1), %a1
    dbra %d3, 1b
    movem.l (%sp)+, %d0-%d3/%a0-%a3
    rts

| Copy a stored room into a map and patch in its open doors.
|
| d0.w = room id, d1.b = doors to show open, a0 = destination map
uw_build_map:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    lvtab ROOM_INDEX, %a1
    moveq #0, %d2
    move.b 0(%a1, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 9f
    move.w %d2, %d3                 | stored room number
    mulu.w #UW_PACKED_BYTES, %d2
    lvtab ROOMS, %a2
    adda.l %d2, %a2
    movea.l %a0, %a1
    bsr uw_unpack_room

    uwlea OPEN, %a1
    moveq #0, %d7
    move.b 0(%a1, %d0.w), %d7       | doors opened for good
    move.b %d1, %d5
    or.b %d7, %d5                   | d5 = doors standing open
    lvtab DOORS, %a2
    mulu.w #UW_DOOR_RECORD_BYTES, %d3
    adda.l %d3, %a2                 | four door types, then four open faces
    ltab uw_door_cells, %a3
    moveq #0, %d6                   | direction: 0 E, 1 W, 2 S, 3 N
2:  moveq #0, %d0
    move.b 0(%a2, %d6.w), %d0
    cmpi.b #DOOR_SHUTTER, %d0
    bne 21f
    btst %d6, %d7                   | a shutter opens once its room is cleared
    bne 3f
    bra 8f
21: cmpi.b #4, %d0
    blo 8f                          | open or wall: the stored map already shows it
    btst %d6, %d5
    beq 8f
3:  move.w %d6, %d0
    mulu.w #12, %d0
    lea 4(%a2), %a1
    adda.w %d0, %a1                 | the open face for this direction
    move.w %d0, %d4
    add.w %d4, %d4
    lea 0(%a3, %d4.w), %a4          | its twelve map offsets
    moveq #11, %d4
4:  move.w (%a4)+, %d0
    move.b (%a1)+, 0(%a0, %d0.w)
    dbra %d4, 4b
8:  addq.w #1, %d6
    cmp.w #4, %d6
    blo 2b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| False walls (door types 2 and 3) are drawn as wall but can be walked through,
| so once the room is drawn their doorway tiles go into the map Link collides
| with.
|
| d0.w = room id, a0 = map already rendered
uw_open_false_walls:
    movem.l %d0-%d6/%a1-%a4, -(%sp)
    lvtab ROOM_INDEX, %a1
    moveq #0, %d2
    move.b 0(%a1, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 9f
    mulu.w #UW_DOOR_RECORD_BYTES, %d2
    lvtab DOORS, %a2
    adda.l %d2, %a2
    ltab uw_door_cells, %a3
    moveq #0, %d6
1:  moveq #0, %d0
    move.b 0(%a2, %d6.w), %d0
    cmpi.b #2, %d0
    blo 8f
    cmpi.b #3, %d0
    bhi 8f
    move.w %d6, %d0
    mulu.w #12, %d0
    lea 4(%a2), %a1
    adda.w %d0, %a1
    move.w %d0, %d4
    add.w %d4, %d4
    lea 0(%a3, %d4.w), %a4
    moveq #11, %d4
2:  move.w (%a4)+, %d0
    move.b (%a1)+, 0(%a0, %d0.w)
    dbra %d4, 2b
8:  addq.w #1, %d6
    cmp.w #4, %d6
    blo 1b
9:  movem.l (%sp)+, %d0-%d6/%a1-%a4
    rts

| Draw one map tile. a0 = map pointer (advanced), a2 = screen destination,
| a3 = tile bank. A tile is eight rows of one byte per bitplane, so it is
| stored with plain byte moves into either half of the 16-pixel group.
uw_draw_tile:
    moveq #0, %d0
    move.b (%a0)+, %d0
    lsl.w #5, %d0
    lea 0(%a3, %d0.w), %a4
    moveq #7, %d5
1:  move.b (%a4)+, 0(%a2)
    move.b (%a4)+, 2(%a2)
    move.b (%a4)+, 4(%a2)
    move.b (%a4)+, 6(%a2)
    adda.w #SCREEN_STRIDE, %a2
    dbra %d5, 1b
    suba.w #(SCREEN_STRIDE * 8), %a2
    rts

| a0 = map, a1 = destination buffer
uw_render_map:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    adda.l #PLAYFIELD_ORIGIN, %a1
    lvtab TILES, %a3
    moveq #(UW_ROWS - 1), %d7
1:  movea.l %a1, %a2
    moveq #(UW_COLS / 2 - 1), %d6
2:  bsr uw_draw_tile
    addq.l #1, %a2
    bsr uw_draw_tile
    addq.l #7, %a2
    dbra %d6, 2b
    adda.l #(SCREEN_STRIDE * 8), %a1
    dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| Build and draw the current room. d0.w = room id, a1 = destination buffer
uw_render_current:
    movem.l %d1/%a0, -(%sp)
    bsr uw_mark_visited
    lea OFF_UW_MAP(%a5), %a0
    move.b OFF_UW_ENTER_MASK(%a5), %d1
    bsr uw_build_map
    lea OFF_UW_MAP(%a5), %a0
    bsr uw_render_map
    lea OFF_UW_MAP(%a5), %a0
    bsr uw_open_false_walls
    bsr uw_dark_fill
    bsr uw_bake_person
    bsr uw_bake_boss
    movem.l (%sp)+, %d1/%a0
    rts

| The room d0.w has been entered: the sheet map of the inventory screen shows it from now on
| (bit 5 of the room's flags, the ROM's "visited").
    .equ UW_FLAG_VISITED, 5
uw_mark_visited:
    movem.l %d0/%a0, -(%sp)
    andi.w #0x7f, %d0
    uwlea FLAGS, %a0
    bset #UW_FLAG_VISITED, 0(%a0, %d0.w)
    movem.l (%sp)+, %d0/%a0
    rts

| Build and draw the room Link is about to scroll into.
| d0.w = room id, d1.b = direction Link is travelling, a1 = destination buffer
uw_render_next:
    movem.l %d1-%d3/%a0, -(%sp)
    clr.b OFF_STASH_ROOM(%a5)           | Link is leaving a room: its rupees are no longer on show
    clr.b OFF_ROOM_LIT(%a5)             | and a room he lit is dark again
    | The door Link comes in through is the opposite one; E/W and S/N swap.
    move.b %d1, %d2
    and.b #5, %d2
    add.b %d2, %d2
    move.b %d1, %d3
    and.b #10, %d3
    lsr.b #1, %d3
    or.b %d3, %d2
    move.b %d2, OFF_UW_NEXT_MASK(%a5)
    move.b %d2, %d1
    lea OFF_UW_MAP_NEXT(%a5), %a0
    bsr uw_build_map
    lea OFF_UW_MAP_NEXT(%a5), %a0
    bsr uw_render_map
    lea OFF_UW_MAP_NEXT(%a5), %a0
    bsr uw_open_false_walls
    bsr uw_dark_fill
    bsr uw_bake_person
    bsr uw_bake_boss
    movem.l (%sp)+, %d1-%d3/%a0
    rts

| The scroll has finished: the room that was drawn off screen is now current.
uw_commit_next:
    movem.l %d0/%a0-%a1, -(%sp)
    lea OFF_UW_MAP_NEXT(%a5), %a0
    lea OFF_UW_MAP(%a5), %a1
    move.w #(UW_ROOM_BYTES / 4 - 1), %d0
1:  move.l (%a0)+, (%a1)+
    dbra %d0, 1b
    move.b OFF_UW_NEXT_MASK(%a5), OFF_UW_ENTER_MASK(%a5)
    movem.l (%sp)+, %d0/%a0-%a1
    rts

| ---------------------------------------------------------------- dungeon people
| Some rooms hold an old man between two bonfires. Like the first cave's, he is part of
| the room's picture, and his speech is typed out by cave_talk while Link stands still
| (InitUnderworldPerson, UpdatePersonState_Textbox). Walking up to him is stopped at
| Y $8E (CheckPersonBlocking), see link_collide. Hitting him, which makes the flames
| shoot, is not ported.
    .equ UW_PERSON_DELAY, 10        | frames before the first letter

| The room's record (a1) names a speech: start it. Link is held until it is over. d0.w = room id.
| The record's byte 13 says what else the man does (see the wares below).
uw_person_begin:
    movem.l %d1/%a2, -(%sp)
    uwlea FLAGS, %a2
    btst #UW_FLAG_PERSON, 0(%a2, %d0.w)
    bne 9f                              | he has given what he had, and is gone
    move.b #1, OFF_UW_PERSON(%a5)
    clr.b OFF_PERSON_FIRE(%a5)          | a visit starts with the fires quiet
    clr.b OFF_PERSON_FIRE_T(%a5)
    clr.b (OFF_PERSON_FIRE_T + 1)(%a5)
    move.b #1, OFF_CAVE_TEXT_ON(%a5)
    move.w 14(%a1), OFF_CAVE_TEXT_IDXW(%a5)
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_ROW0, OFF_CAVE_TEXT_ROW(%a5)
    move.b #UW_PERSON_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    clr.b OFF_UW_PERSON_KIND(%a5)
    clr.b OFF_UW_PERSON_WARES(%a5)
    tst.b (%a1)
    bne 9f                              | a room with monsters keeps a monster in byte 13
    move.b 13(%a1), %d1
    cmp.b #UW_KIND_BOMBS, %d1
    beq 1f
    cmp.b #UW_KIND_MONEY, %d1
    bne 9f
1:  move.b %d1, OFF_UW_PERSON_KIND(%a5)
9:  movem.l (%sp)+, %d1/%a2
    rts

| Once per frame: the letters, and Link's release when the last one is down. UW_PERSON: 1 speaking, 2 done
| (the man stays; one who sells something shows it and waits for Link to step on it), 3 something was taken.
uw_person_update:
    movem.l %d0-%d3/%a0-%a2, -(%sp)
    move.b OFF_UW_PERSON(%a5), %d0
    beq 90f
    cmp.b #3, %d0
    beq 30f
    tst.b OFF_UW_PERSON_KIND(%a5)
    beq 10f
    bsr uw_wares_show
10: cmp.b #1, %d0
    bne 20f
    bsr cave_talk_far
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 90f
    move.b #2, OFF_UW_PERSON(%a5)
    tst.b OFF_GRUMBLE_ON(%a5)
    beq 11f
    clr.b OFF_UW_PERSON(%a5)           | Grumble is a moblin, not an old man by two fires
11: clr.b OFF_LINK_HELD(%a5)
    bra 90f
20: tst.b OFF_UW_PERSON_KIND(%a5)
    beq 90f
    bsr uw_wares_sense
    bra 90f
30: subq.b #1, OFF_UW_PERSON_TIMER(%a5)    | 3: a pause, and then he and his fires are gone for good
    bne 90f
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    uwlea FLAGS, %a0
    bset #UW_FLAG_PERSON, 0(%a0, %d0.w)
    clr.b OFF_UW_PERSON(%a5)
    clr.b OFF_UW_PERSON_KIND(%a5)
    bsr uw_redraw_room
90: movem.l (%sp)+, %d0-%d3/%a0-%a2
    rts

| ---------------------------------------------------------- the men who sell
| The man who sells room for four more bombs (InitUnderworldPersonA, type $4F, in Levels 5 and 7) shows a rupee
| at ($78,$98) with "-100" under it; the man of "life or money" (type $51) a heart container at ($58,$98)
| with "-1" and a rupee at ($98,$98) with "-50". Link takes an offer by standing on it: his X is the item's and
| his Y within 6 of $98. What he gives is gone from the man (UW_FLAGS bit 3), who vanishes after a pause.
    .equ UW_KIND_BOMBS, 1
    .equ UW_KIND_MONEY, 2
    .equ UW_FLAG_PERSON, 3
    .equ UW_WARES_Y, 0x98
    .equ UW_PRICE_ROW, 17
    .equ UW_BOMBS_COST, 100
    .equ UW_MONEY_COST, 50
    .equ UW_TAKEN_PAUSE, 0x40

uw_price_bombs:
    .byte 0x2f, 1, 0, 0, 0xff
uw_price_life:
    .byte 0x2f, 1, 0xff
uw_price_money:
    .byte 0x2f, 5, 0, 0xff

| The prices once, the goods every frame (the item slots are drawn as held up: not to be picked up).
uw_wares_show:
    movem.l %d0-%d2/%a0, -(%sp)
    tst.b OFF_UW_PERSON_WARES(%a5)
    bne 1f
    move.b #1, OFF_UW_PERSON_WARES(%a5)
    cmpi.b #UW_KIND_BOMBS, OFF_UW_PERSON_KIND(%a5)
    bne 2f
    lea uw_price_bombs(%pc), %a0
    moveq #17, %d1
    moveq #UW_PRICE_ROW, %d2
    bsr uw_put_codes
    bra 1f
2:  lea uw_price_life(%pc), %a0
    moveq #15, %d1
    moveq #UW_PRICE_ROW, %d2
    bsr uw_put_codes
    lea uw_price_money(%pc), %a0
    moveq #22, %d1
    moveq #UW_PRICE_ROW, %d2
    bsr uw_put_codes
1:  cmpi.b #UW_KIND_BOMBS, OFF_UW_PERSON_KIND(%a5)
    bne 3f
    move.b #ITEM_RUPEE, OFF_ITEM_ID(%a5)
    move.b #0x78, OFF_ITEM_X(%a5)
    move.b #UW_WARES_Y, OFF_ITEM_Y(%a5)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5)
    bra 9f
3:  move.b #ITEM_HEART_CONTAINER, OFF_ITEM_ID(%a5)
    move.b #0x58, OFF_ITEM_X(%a5)
    move.b #UW_WARES_Y, OFF_ITEM_Y(%a5)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5)
    move.b #ITEM_RUPEE, (OFF_ITEM_ID + 1)(%a5)
    move.b #0x98, (OFF_ITEM_X + 1)(%a5)
    move.b #UW_WARES_Y, (OFF_ITEM_Y + 1)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + 1)(%a5)
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| Is Link standing on an offer, and can he pay?
uw_wares_sense:
    movem.l %d0-%d2, -(%sp)
    move.b OFF_LINK_Y(%a5), %d1
    sub.b #UW_WARES_Y, %d1
    bpl 1f
    neg.b %d1
1:  cmp.b #6, %d1
    bhs 9f
    move.b OFF_LINK_X(%a5), %d0
    cmpi.b #UW_KIND_BOMBS, OFF_UW_PERSON_KIND(%a5)
    bne 4f
    cmp.b #0x78, %d0
    bne 9f
    cmpi.b #UW_BOMBS_COST, OFF_INV_RUPEES(%a5)
    blo 9f
    sub.b #UW_BOMBS_COST, OFF_INV_RUPEES(%a5)
    move.b OFF_MAX_BOMBS(%a5), %d1
    addq.b #4, %d1                      | four more bombs to carry, and the bag is full
    move.b %d1, OFF_MAX_BOMBS(%a5)
    move.b %d1, OFF_INV_BOMBS(%a5)
    bra 8f
4:  cmp.b #0x98, %d0
    bne 5f
    cmpi.b #UW_MONEY_COST, OFF_INV_RUPEES(%a5)
    blo 9f
    sub.b #UW_MONEY_COST, OFF_INV_RUPEES(%a5)
    bra 7f
5:  cmp.b #0x58, %d0
    bne 9f
    cmpi.b #4, OFF_HEART_CONTAINERS(%a5)
    blo 6f
    subq.b #1, OFF_HEART_CONTAINERS(%a5)    | a heart container and a heart are given up
    move.b OFF_HP_HALVES(%a5), %d1
    cmp.b #3, %d1
    bhs 51f
    moveq #1, %d1
    bra 52f
51: subq.b #2, %d1
52: move.b %d1, OFF_HP_HALVES(%a5)
    bra 7f
6:  move.b #1, OFF_HP_HALVES(%a5)       | with so few, he gives up what is left: one more blow kills
7:  moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    bsr uw_open_shutters                | ShutterTrigger
8:  sfx SFX_KEY
    clr.b OFF_ITEM_ACTIVE(%a5)
    clr.b (OFF_ITEM_ACTIVE + 1)(%a5)
    moveq #CAVE_TEXT_COL0, %d1          | his words and the prices are blanked
    moveq #CAVE_TEXT_ROW0, %d2
    moveq #24, %d0
    moveq #3, %d3
    bsr uw_wipe
    moveq #15, %d1
    moveq #UW_PRICE_ROW, %d2
    moveq #10, %d0
    moveq #1, %d3
    bsr uw_wipe
    move.b #3, OFF_UW_PERSON(%a5)
    move.b #UW_TAKEN_PAUSE, OFF_UW_PERSON_TIMER(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
9:  movem.l (%sp)+, %d0-%d2
    rts

| d0.w = a glyph, d1.w = column, d2.w = row: drawn into the screen, the clean room and the other buffer
| (as cave_talk does, so Link's erasing leaves it).
uw_put_glyph:
    movem.l %d0-%d2, -(%sp)
    bsr draw_hud_tile_far
    move.l OFF_SCREEN_PTR(%a5), -(%sp)
    move.l OFF_BG_CUR(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile_far
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 9f
    move.l OFF_SCREEN_PTR(%a5), -(%sp)
    move.l OFF_BG_NEXT(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile_far
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
9:  movem.l (%sp)+, %d0-%d2
    rts

| a0 = text codes ended by $FF, d1.w = column, d2.w = row.
uw_put_codes:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    ltab text_glyphs, %a1
1:  moveq #0, %d0
    move.b (%a0)+, %d0
    cmp.b #0xff, %d0
    beq 9f
    move.b 0(%a1, %d0.w), %d0
    bsr uw_put_glyph
    addq.w #1, %d1
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| Blank d0.w columns by d3.w rows from column d1.w, row d2.w.
uw_wipe:
    movem.l %d0-%d6, -(%sp)
    move.w %d0, %d4                     | the width
    move.w %d1, %d5                     | the first column
    subq.w #1, %d3
1:  move.w %d5, %d1
    move.w %d4, %d6
2:  moveq #0, %d0
    bsr uw_put_glyph
    addq.w #1, %d1
    subq.w #1, %d6
    bne 2b
    addq.w #1, %d2
    dbra %d3, 1b
    movem.l (%sp)+, %d0-%d6
    rts

| Paint the old man into the room just drawn. d0.w = room id, a1 = the buffer it went to.
uw_bake_person:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    uwlea FLAGS, %a0
    btst #UW_FLAG_PERSON, 0(%a0, %d0.w)
    bne 9f                              | he gave what he had: not in this room any more
    movea.l %a1, %a2
    bsr uw_room_info_ptr
    tst.w %d1
    bmi 9f
    cmpi.w #0xffff, 14(%a1)
    beq 9f
    ltab cave_sprites, %a0              | picture 0 is the old man
    moveq #0, %d1
    move.w #CAVE_DOOR_CENTER, %d1
    moveq #0, %d2
    move.w #CAVE_PERSON_Y, %d2
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    movea.l %a2, %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite_far
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| A dark room (record byte 5, bit 7) is drawn black until the candle lights it: the walls, floor and doors vanish,
| the sprites do not (a dark room's background palette fades out in the original). d0.w = room id, a1 = buffer.
uw_dark_fill:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    tst.b OFF_ROOM_LIT(%a5)
    bne 9f
    movea.l %a1, %a2
    bsr uw_room_info_ptr
    tst.w %d1
    bmi 9f
    tst.b 5(%a1)
    bpl 9f
    adda.l #PLAYFIELD_ORIGIN, %a2
    moveq #0, %d0                       | eight zero longs: d0-d6 and a3
    moveq #0, %d1
    moveq #0, %d2
    moveq #0, %d3
    moveq #0, %d4
    moveq #0, %d5
    moveq #0, %d6
    suba.l %a3, %a3
    move.w #(UW_ROWS * 8 - 1), %d7
1:  lea 128(%a2), %a0                   | the line is 256 pixels: 128 bytes, cleared back to front
    movem.l %d0-%d6/%a3, -(%a0)
    movem.l %d0-%d6/%a3, -(%a0)
    movem.l %d0-%d6/%a3, -(%a0)
    movem.l %d0-%d6/%a3, -(%a0)
    lea SCREEN_STRIDE(%a2), %a2
    dbra %d7, 1b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| The candle has been lit: a dark room shows itself.
uw_light_room:
    movem.l %d0/%a1, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_ROOM_LIT(%a5)
    bne 9f
    tst.b OFF_ROOM_DARK(%a5)
    beq 9f
    move.b #1, OFF_ROOM_LIT(%a5)
    bsr uw_redraw_room
9:  movem.l (%sp)+, %d0/%a1
    rts

| Paint what a dungeon room has besides its tiles into the room just drawn: a living Gleeok's body, the rupee
| stash, Grumble. d0.w = room id, a1 = the buffer it went to.
uw_bake_boss:
    movem.l %d0-%d2/%a0-%a3, -(%sp)
    movea.l %a1, %a2
    bsr uw_room_info_ptr
    tst.w %d1
    bmi 9f
    movea.l %a1, %a3
    move.b 1(%a3), %d2
    btst #6, %d2
    beq 1f
    movea.l %a2, %a1
    bsr boss_stash_bake_f
1:  btst #5, %d2
    beq 2f
    movea.l %a2, %a1
    bsr boss_grumble_bake_f
2:  uwlea FLAGS, %a0
    btst #0, 0(%a0, %d0.w)
    bne 9f                              | the room is won
    move.b %d0, %d1
    or.b #0x80, %d1
    cmp.b OFF_GLEEOK_GONE(%a5), %d1
    beq 9f                              | its Gleeok has just died
    moveq #0, %d1
    move.b (%a3), %d1                   | the monsters of the room
    beq 9f
    subq.w #1, %d1
    lea 6(%a3), %a0
3:  move.b (%a0)+, %d2
    cmp.b #MON_GLEEOK2, %d2
    blo 4f
    cmp.b #MON_GLEEOK4, %d2
    bhi 4f
    movea.l %a2, %a1
    bsr boss_bake_f
    bra 9f
4:  dbra %d1, 3b
9:  movem.l (%sp)+, %d0-%d2/%a0-%a3
    rts

| A door has opened: redraw the room behind Link.
uw_redraw_room:
    movem.l %d0/%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    movea.l OFF_BG_CUR(%a5), %a1
    bsr uw_render_current
    bsr show_background_far
    clr.b OFF_ERASE_VALID(%a5)
    movem.l (%sp)+, %d0/%a1
    rts

| Open door d2 (0 E, 1 W, 2 S, 3 N) of room d0 for good, and the matching door
| of the room on its other side, so it is still open when Link comes back.
uw_open_door_pair:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    uwlea OPEN, %a2
    bset %d2, 0(%a2, %d0.w)
    move.w %d0, %d3
    moveq #1, %d4
    tst.w %d2
    beq 1f
    moveq #-1, %d4
    cmp.w #1, %d2
    beq 1f
    moveq #16, %d4
    cmp.w #2, %d2
    beq 1f
    moveq #-16, %d4
1:  add.w %d4, %d3
    bmi 9f
    cmp.w #0x7f, %d3
    bhi 9f
    lvtab ROOM_INDEX, %a0
    moveq #0, %d1
    move.b 0(%a0, %d3.w), %d1
    cmpi.b #0xff, %d1
    beq 9f
    mulu.w #UW_DOOR_RECORD_BYTES, %d1
    lvtab DOORS, %a1
    adda.l %d1, %a1
    move.w %d2, %d1
    eori.w #1, %d1                  | the far side's door faces back
    moveq #0, %d4
    move.b 0(%a1, %d1.w), %d4
    cmpi.b #4, %d4
    blo 9f
    cmpi.b #DOOR_SHUTTER, %d4
    beq 9f
    bset %d1, 0(%a2, %d3.w)
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| Link is pushing against a doorway.
|
| d1.b = direction. Returns d0.w = 1 when he may walk through. A locked door
| opens (and uses a key) instead of passing him on the same frame.
uw_try_door:
    movem.l %d1-%d6/%a0-%a2, -(%sp)
    tst.b OFF_IN_CELLAR(%a5)
    bne 8f                          | a cellar has no doors
    moveq #0, %d2                   | 0 E, 1 W, 2 S, 3 N
    btst #0, %d1
    bne 1f
    moveq #1, %d2
    btst #1, %d1
    bne 1f
    moveq #2, %d2
    btst #2, %d1
    bne 1f
    moveq #3, %d2

1:  | Link has to be lined up with the doorway and pressed against it.
    moveq #0, %d3
    moveq #0, %d4
    cmp.w #2, %d2
    bhs 4f
    move.b OFF_LINK_Y(%a5), %d3
    sub.w #DOORWAY_LANE_Y, %d3
    move.b OFF_LINK_X(%a5), %d4
    tst.w %d2
    bne 2f
    cmp.w #0xc8, %d4
    blo 8f
    bra 6f
2:  cmp.w #0x29, %d4
    bhi 8f
    bra 6f
4:  move.b OFF_LINK_X(%a5), %d3
    sub.w #DOORWAY_LANE_X, %d3
    move.b OFF_LINK_Y(%a5), %d4
    cmp.w #2, %d2
    bne 5f
    cmp.w #0xb1, %d4
    blo 8f
    bra 6f
5:  cmp.w #0x66, %d4
    bhi 8f
6:  tst.w %d3
    bpl 7f
    neg.w %d3
7:  cmp.w #DOORWAY_SLACK, %d3
    bhi 8f

    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lvtab ROOM_INDEX, %a0
    moveq #0, %d5
    move.b 0(%a0, %d0.w), %d5
    cmpi.b #0xff, %d5
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d5
    lvtab DOORS, %a1
    adda.l %d5, %a1
    moveq #0, %d6
    move.b 0(%a1, %d2.w), %d6       | door type
    tst.b %d6
    beq 9f                          | open doorway
    cmpi.b #DOOR_SHUTTER, %d6
    bne 21f
    uwlea OPEN, %a2
    btst %d2, 0(%a2, %d0.w)         | shut until the room is cleared
    bne 9f
    bra 8f
21: cmpi.b #1, %d6
    beq 8f                          | a solid wall
    cmpi.b #4, %d6
    blo 9f                          | a false wall can be walked through
    uwlea OPEN, %a2
    move.b 0(%a2, %d0.w), %d5
    btst %d2, %d5
    bne 9f                          | already opened
    cmpi.b #4, %d6
    beq 8f                          | bombable: needs a bomb
    tst.b OFF_INV_MAGIC_KEY(%a5)
    bne 22f                         | the magic key opens every door and is never used up
    tst.b OFF_INV_KEYS(%a5)
    beq 8f
    subq.b #1, OFF_INV_KEYS(%a5)
22: bsr uw_open_door_pair
    sfx SMP_DOOR                    | the door sample plays for keys and shutters
    move.b #1, OFF_HUD_DIRTY(%a5)
    bsr uw_redraw_room
    bra 8f

9:  cmp.w #2, %d2
    bhs 10f
    move.b #DOORWAY_LANE_Y, OFF_LINK_Y(%a5)
    bra 11f
10: move.b #DOORWAY_LANE_X, OFF_LINK_X(%a5)
11: moveq #1, %d0
    bra 12f
8:  moveq #0, %d0
12: movem.l (%sp)+, %d1-%d6/%a0-%a2
    rts

| Make dungeon d0.b (1 to LEVEL_COUNT) the current one: OFF_LEVEL, and the pointers to its tables and
| its start room, start Y, triforce room, minimap column and cellar count from level_table (levels.inc): the
| First Quest's dungeons are its records 0 to 8, the Second Quest's (OFF_QUEST) 9 to 17.
uw_select_level:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    move.b %d0, OFF_LEVEL(%a5)
    clr.w OFF_UW_BLOCK(%a5)             | Levels 1-6 share one set of world flags, 7-9 another (LevelInfo_WorldFlagsAddr)
    cmp.b #7, %d0
    blo 5f
    move.w #UW_B_DELTA, OFF_UW_BLOCK(%a5)
5:
    and.w #0x00ff, %d0
    subq.w #1, %d0
    tst.b OFF_QUEST(%a5)
    beq 0f
    add.w #LEVEL_COUNT, %d0
0:  mulu.w #LEVEL_RECORD_BYTES, %d0
    ltab level_table, %a0
    adda.w %d0, %a0
    lea OFF_UWP_ROOM_INDEX(%a5), %a1
    moveq #9, %d1
1:  move.l (%a0)+, %d0
    add.l %a6, %d0                  | the record holds distances from table_anchor
    move.l %d0, (%a1)+
    dbra %d1, 1b
    move.l (%a0)+, (%a1)+           | start room, start Y, triforce room, minimap column
    move.l (%a0)+, (%a1)+           | cellar count, padding
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| Walk down the stairs of an overworld entrance into level d0.b.
uw_enter_level:
    move.b OFF_ROOM_ID(%a5), OFF_CAVE_SOURCE_ROOM(%a5)
    bsr uw_select_level

| Link starts the level over: the first room, at the bottom, walking up. This
| is also where a wallmaster takes him.
uw_warp_to_start:
    move.b #1, OFF_WARPED(%a5)
    move.b #UW_BOUND_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_BOUND_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_BOUND_DOWN(%a5)
    move.b #UW_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b OFF_UW_START_ROOM(%a5), OFF_ROOM_ID(%a5)
    move.b #START_X, OFF_LINK_X(%a5)
    | The game starts Link at $DD, below the doorway, and walks him up; here he
    | simply begins at the bottom of the room.
    move.b #UW_BOUND_DOWN, OFF_LINK_Y(%a5)
    move.b #DIR_UP, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_UW_ENTER_MASK(%a5)
    bsr enter_room_far
    rts

| Link walked off the edge of the level: back out to the overworld entrance.
uw_leave_level:
    movem.l %d0-%d2, -(%sp)
    clr.b OFF_UW_PERSON(%a5)
    move.b #1, OFF_WARPED(%a5)
    clr.b OFF_LEVEL(%a5)
    move.b #LINK_EDGE_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #LINK_EDGE_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #LINK_EDGE_UP, OFF_BOUND_UP(%a5)
    move.b #LINK_EDGE_DOWN, OFF_BOUND_DOWN(%a5)
    move.b #ROOM_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #ROOM_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #ROOM_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #ROOM_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b OFF_CAVE_SOURCE_ROOM(%a5), OFF_ROOM_ID(%a5)
    moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2
    bsr compute_cave_exit_position
    move.b %d0, OFF_LINK_X(%a5)
    move.b %d1, OFF_LINK_Y(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    move.b #1, OFF_EXIT_GUARD(%a5)
    bsr enter_room_far
    movem.l (%sp)+, %d0-%d2
    rts

| ----------------------------------------------------------------- cellars
| A stairs square takes Link down to a cellar: a room outside the level's door
| grid whose two destination rooms are the rooms its stairs lead back to.
    .equ CELLAR_LADDER_LEFT, 0x30
    .equ CELLAR_LADDER_RIGHT, 0xc0
    .equ CELLAR_START_Y, 0x5d
    .equ CELLAR_EXIT_Y, 0x41
    .equ CELLAR_MIDDLE_X, 0x80

uw_enter_cellar:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lvtab CELLAR_INFO, %a0
    moveq #0, %d4
1:  cmp.b OFF_UW_CELLARS(%a5), %d4
    bhs 9f                          | no cellar below this room
    move.w %d4, %d1
    lsl.w #3, %d1
    cmp.b 0(%a0, %d1.w), %d0
    beq 2f
    cmp.b 1(%a0, %d1.w), %d0
    beq 2f
    addq.w #1, %d4
    bra 1b
2:  adda.w %d1, %a0                 | a0 = the cellar's record
    move.b OFF_ROOM_ID(%a5), OFF_CELLAR_SOURCE(%a5)
    move.b 6(%a0), OFF_CELLAR_ROOM(%a5)
    addq.b #1, %d4
    move.b %d4, OFF_IN_CELLAR(%a5)
    subq.b #1, %d4
    sfx SFX_STAIRS

    | Link comes down the ladder on the side he came from.
    move.b #CELLAR_LADDER_LEFT, %d1
    cmp.b (%a0), %d0
    beq 3f
    move.b #CELLAR_LADDER_RIGHT, %d1
3:  move.b %d1, OFF_LINK_X(%a5)
    move.b #CELLAR_START_Y, OFF_LINK_Y(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_COMMIT(%a5)
    move.b #1, OFF_WARPED(%a5)
    move.b #LINK_EDGE_UP, OFF_BOUND_UP(%a5)
    move.b #CELLAR_START_Y, OFF_OBJ_UP(%a5)

    | The cellar's picture and its collision map are one and the same.
    move.w %d4, %d1
    mulu.w #UW_PACKED_BYTES, %d1
    lvtab CELLAR_MAPS, %a2
    adda.l %d1, %a2
    lea OFF_UW_MAP(%a5), %a1
    bsr uw_unpack_room
    lea OFF_UW_MAP(%a5), %a0
    movea.l OFF_BG_CUR(%a5), %a1
    bsr uw_render_map
    bsr show_background_far
    clr.b OFF_ERASE_VALID(%a5)

    | The cellar is full of keese, whatever else lies in it.
    bsr clear_enemies
    bsr clear_items
    clr.b OFF_ROOM_TRIGGER(%a5)
    clr.b OFF_ROOM_UNSUPPORTED(%a5)
    clr.b OFF_ROOM_DARK(%a5)
    clr.b OFF_ROOM_ROAR(%a5)
    lea cellar_keese(%pc), %a1
    ltab mon_table, %a2
    moveq #MON_KEESE, %d1
    lsl.w #3, %d1
    moveq #3, %d3
5:  move.b 0(%a1, %d3.w), %d0
    move.b %d0, OFF_ENEMY_X(%a5, %d3.w)
    move.b 4(%a1, %d3.w), %d0
    move.b %d0, OFF_ENEMY_Y(%a5, %d3.w)
    move.b #MON_KEESE, OFF_ENEMY_TYPE(%a5, %d3.w)
    move.b 1(%a2, %d1.w), %d0
    move.b %d0, OFF_ENEMY_HP(%a5, %d3.w)
    move.b #1, OFF_ENEMY_ACTIVE(%a5, %d3.w)
    moveq #1, %d0
    lsl.b %d3, %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d3.w)
    move.l %d5, -(%sp)
    move.w %d3, %d5
    bsr enemy_init_special_far
    move.l (%sp)+, %d5
    dbra %d3, 5b
    move.b #4, OFF_ENEMY_COUNT(%a5)

    | The treasure, unless it has been taken.
    lvtab CELLAR_INFO, %a0
    move.w %d4, %d1
    lsl.w #3, %d1
    adda.w %d1, %a0
    cmpi.b #0xff, 3(%a0)
    beq 9f
    uwlea FLAGS, %a2
    moveq #0, %d1
    move.b 6(%a0), %d1
    btst #1, 0(%a2, %d1.w)
    bne 9f
    move.b #2, OFF_ITEM_ACTIVE(%a5)
    move.b 3(%a0), OFF_ITEM_ID(%a5)
    move.b 4(%a0), OFF_ITEM_X(%a5)
    move.b 5(%a0), OFF_ITEM_Y(%a5)
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| Link climbed the cellar's ladder: back up to the room on that side.
uw_leave_cellar:
    movem.l %d0-%d2/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_IN_CELLAR(%a5), %d0
    subq.w #1, %d0
    lsl.w #3, %d0
    lvtab CELLAR_INFO, %a0
    adda.w %d0, %a0
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    move.b (%a0), %d2
    cmp.w #CELLAR_MIDDLE_X, %d1
    blo 1f
    move.b 1(%a0), %d2
1:  move.b %d2, OFF_ROOM_ID(%a5)
    move.b 2(%a0), %d1              | where the stairs are in that room
    move.b %d1, %d2
    and.b #0xf0, %d2
    move.b %d2, OFF_LINK_X(%a5)
    lsl.b #4, %d1
    or.b #0x0d, %d1
    move.b %d1, OFF_LINK_Y(%a5)
    clr.b OFF_IN_CELLAR(%a5)
    sfx SFX_STAIRS
    move.b #UW_BOUND_UP, OFF_BOUND_UP(%a5)
    move.b #UW_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_UW_ENTER_MASK(%a5)
    move.b #1, OFF_WARPED(%a5)
    move.b #1, OFF_EXIT_GUARD(%a5)
    bsr enter_room_far
    movem.l (%sp)+, %d0-%d2/%a0
    rts

cellar_keese:
    .byte 0x20, 0x60, 0x90, 0xd0    | X
    .byte 0x9d, 0x5d, 0x7d, 0x9d    | Y

| CheckWarps: standing square on an entrance opening takes Link underground.
check_warps:
    movem.l %d0-%d3/%a0, -(%sp)
    move.b OFF_LINK_X(%a5), %d0
    and.b #0x0f, %d0
    bne 8f
    move.b OFF_LINK_Y(%a5), %d0
    tst.b OFF_LEVEL(%a5)
    beq 7f
    cmp.b #UW_BOUND_UP, %d0         | the stairs a push block uncovers sit in the top row: the ROM lets Link rest on
    beq 6f                          | $5D there (it stops him when he would cross the bound), the port stops him at the bound
7:  and.b #0x0f, %d0
    cmp.b #0x0d, %d0
    bne 8f
6:
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    add.w #HOTSPOT_Y_OFFSET, %d2
    sub.w #NES_PLAY_AREA_TOP, %d2
    lsr.w #3, %d2
    moveq #0, %d3
    move.b OFF_LINK_X(%a5), %d3
    lsr.w #3, %d3
    bsr fetch_tile
    tst.b OFF_LEVEL(%a5)
    beq 0f
    | Underworld: a stairs square leads down to a cellar.
    cmp.w #0x70, %d0
    blo 8f
    cmp.w #0x74, %d0
    bhs 8f
    tst.b OFF_EXIT_GUARD(%a5)
    bne 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    bsr uw_enter_cellar
    bra 9f
0:  cmp.w #CAVE_ENTRANCE_TILE, %d0
    beq 1f
    cmp.w #0x88, %d0
    beq 1f
    cmp.w #0x70, %d0
    blo 8f
    cmp.w #0x74, %d0
    bhs 8f
1:  tst.b OFF_EXIT_GUARD(%a5)
    bne 9f                          | still standing where he stepped out

    ltab room_attr_b, %a0
    moveq #0, %d1
    move.b OFF_ROOM_ID(%a5), %d1
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    and.w #0x00fc, %d0
    beq 9f                          | nothing behind this square
    cmp.w #0x40, %d0
    blo 5f
    bsr start_cave_entry
    bra 9f
5:  lsr.w #2, %d0                   | the level number
    beq 9f
    cmp.w #LEVEL_COUNT, %d0
    bhi 9f                          | the other dungeons are not built yet
    bsr uw_enter_level
    bra 9f
8:  clr.b OFF_EXIT_GUARD(%a5)
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts
