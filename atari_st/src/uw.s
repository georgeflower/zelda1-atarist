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

| Temporary: K hands out a key and bombs, until every source of them exists.
debug_keys:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_K(%a0)
    beq 2f
    tst.b OFF_K_HELD(%a5)
    bne 9f
    move.b #1, OFF_K_HELD(%a5)
    cmpi.b #8, OFF_INV_BOMBS(%a5)
    bhs 3f
    addq.b #4, OFF_INV_BOMBS(%a5)
3:  cmpi.b #9, OFF_INV_KEYS(%a5)
    bhs 9f
    addq.b #1, OFF_INV_KEYS(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    bra 9f
2:  clr.b OFF_K_HELD(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

| Copy a stored room into a map and patch in its open doors.
|
| d0.w = room id, d1.b = doors to show open, a0 = destination map
uw_build_map:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    ltab uw_room_index, %a1
    moveq #0, %d2
    move.b 0(%a1, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 9f
    move.w %d2, %d3                 | stored room number
    mulu.w #UW_ROOM_BYTES, %d2
    ltab uw_rooms, %a2
    adda.l %d2, %a2
    movea.l %a0, %a1
    move.w #(UW_ROOM_BYTES / 4 - 1), %d4
1:  move.l (%a2)+, (%a1)+
    dbra %d4, 1b

    lea OFF_UW_OPEN(%a5), %a1
    moveq #0, %d7
    move.b 0(%a1, %d0.w), %d7       | doors opened for good
    move.b %d1, %d5
    or.b %d7, %d5                   | d5 = doors standing open
    ltab uw_doors, %a2
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
    ltab uw_room_index, %a1
    moveq #0, %d2
    move.b 0(%a1, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 9f
    mulu.w #UW_DOOR_RECORD_BYTES, %d2
    ltab uw_doors, %a2
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
    ltab uw_tiles, %a3
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
    lea OFF_UW_MAP(%a5), %a0
    move.b OFF_UW_ENTER_MASK(%a5), %d1
    bsr uw_build_map
    lea OFF_UW_MAP(%a5), %a0
    bsr uw_render_map
    lea OFF_UW_MAP(%a5), %a0
    bsr uw_open_false_walls
    movem.l (%sp)+, %d1/%a0
    rts

| Build and draw the room Link is about to scroll into.
| d0.w = room id, d1.b = direction Link is travelling, a1 = destination buffer
uw_render_next:
    movem.l %d1-%d3/%a0, -(%sp)
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

| A door has opened: redraw the room behind Link.
uw_redraw_room:
    movem.l %d0/%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    movea.l OFF_BG_CUR(%a5), %a1
    bsr uw_render_current
    bsr show_background
    clr.b OFF_ERASE_VALID(%a5)
    movem.l (%sp)+, %d0/%a1
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
    ltab uw_room_index, %a0
    moveq #0, %d5
    move.b 0(%a0, %d0.w), %d5
    cmpi.b #0xff, %d5
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d5
    ltab uw_doors, %a1
    adda.l %d5, %a1
    moveq #0, %d6
    move.b 0(%a1, %d2.w), %d6       | door type
    tst.b %d6
    beq 9f                          | open doorway
    cmpi.b #DOOR_SHUTTER, %d6
    bne 21f
    lea OFF_UW_OPEN(%a5), %a2
    btst %d2, 0(%a2, %d0.w)         | shut until the room is cleared
    bne 9f
    bra 8f
21: cmpi.b #1, %d6
    beq 8f                          | a solid wall
    cmpi.b #4, %d6
    blo 9f                          | a false wall can be walked through
    lea OFF_UW_OPEN(%a5), %a2
    move.b 0(%a2, %d0.w), %d5
    btst %d2, %d5
    bne 9f                          | already opened
    cmpi.b #4, %d6
    beq 8f                          | bombable: needs a bomb
    tst.b OFF_INV_KEYS(%a5)
    beq 8f
    subq.b #1, OFF_INV_KEYS(%a5)
    bset %d2, %d5
    move.b %d5, 0(%a2, %d0.w)
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

| Walk down the stairs of an overworld entrance into level UW_LEVEL.
uw_enter_level:
    move.b #1, OFF_WARPED(%a5)
    move.b OFF_ROOM_ID(%a5), OFF_CAVE_SOURCE_ROOM(%a5)
    move.b #UW_LEVEL, OFF_LEVEL(%a5)
    move.b #UW_BOUND_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_BOUND_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_BOUND_DOWN(%a5)
    move.b #UW_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b #UW_START_ROOM, OFF_ROOM_ID(%a5)
    move.b #START_X, OFF_LINK_X(%a5)
    | The game starts Link at $DD, below the doorway, and walks him up; here he
    | simply begins at the bottom of the room.
    move.b #UW_BOUND_DOWN, OFF_LINK_Y(%a5)
    move.b #DIR_UP, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_UW_ENTER_MASK(%a5)
    bsr enter_room
    rts

| Link walked off the edge of the level: back out to the overworld entrance.
uw_leave_level:
    movem.l %d0-%d2, -(%sp)
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
    bsr enter_room
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
    ltab uw_cellar_info, %a0
    moveq #0, %d4
1:  cmp.w #CELLAR_COUNT, %d4
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
    mulu.w #UW_ROOM_BYTES, %d1
    ltab uw_cellar_maps, %a1
    adda.l %d1, %a1
    lea OFF_UW_MAP(%a5), %a2
    move.w #(UW_ROOM_BYTES / 4 - 1), %d1
4:  move.l (%a1)+, (%a2)+
    dbra %d1, 4b
    lea OFF_UW_MAP(%a5), %a0
    movea.l OFF_BG_CUR(%a5), %a1
    bsr uw_render_map
    bsr show_background
    clr.b OFF_ERASE_VALID(%a5)

    | The cellar is full of keese, whatever else lies in it.
    bsr clear_enemies
    bsr clear_items
    clr.b OFF_ROOM_TRIGGER(%a5)
    clr.b OFF_ROOM_UNSUPPORTED(%a5)
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
    dbra %d3, 5b
    move.b #4, OFF_ENEMY_COUNT(%a5)

    | The treasure, unless it has been taken.
    ltab uw_cellar_info, %a0
    move.w %d4, %d1
    lsl.w #3, %d1
    adda.w %d1, %a0
    cmpi.b #0xff, 3(%a0)
    beq 9f
    lea OFF_UW_FLAGS(%a5), %a2
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
    ltab uw_cellar_info, %a0
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
    move.b #UW_BOUND_UP, OFF_BOUND_UP(%a5)
    move.b #UW_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_UW_ENTER_MASK(%a5)
    move.b #1, OFF_WARPED(%a5)
    move.b #1, OFF_EXIT_GUARD(%a5)
    bsr enter_room
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
    and.b #0x0f, %d0
    cmp.b #0x0d, %d0
    bne 8f

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
    cmp.w #0x50, %d0
    beq 9f                          | shortcut caves are not done yet
    bsr start_cave_entry
    bra 9f
5:  lsr.w #2, %d0                   | the level number
    cmp.w #UW_LEVEL, %d0
    bne 9f
    bsr uw_enter_level
    bra 9f
8:  clr.b OFF_EXIT_GUARD(%a5)
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts
