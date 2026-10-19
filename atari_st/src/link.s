| Link: input, collision, movement, animation and room transitions.
|
| The collision rules are GetCollidableTile's, from Z_07.asm: a hotspot $B
| pixels below Link's top, pushed 8 or $10 pixels towards the direction of
| travel, is turned into an 8x8 tile coordinate; the tile there blocks if it
| sorts at or above ObjectFirstUnwalkableTile and is not one of the nine
| exceptions in WalkableTiles.

link_update:
    movem.l %d0-%d4, -(%sp)
    tst.b OFF_LINK_HELD(%a5)
    bne 9f                      | a wallmaster is carrying him
    tst.b OFF_LINK_EATEN(%a5)
    bne 9f                      | a like-like has him: he can only swing
    tst.b OFF_LINK_SHOVE(%a5)
    beq 0f
    tst.b OFF_COMMIT(%a5)
    bne 0f                      | finish the step he is on first
    bsr link_shove
    bra 9f
0:  tst.b OFF_ATTACK(%a5)
    bne 9f                      | Link stands still during a sword swing
    bsr read_input_dir
    move.b %d0, %d4             | d4 = direction held, 0 for none
    tst.b OFF_COMMIT(%a5)
    bne 1f
    tst.b %d4
    beq 8f                      | nothing held and no step in progress
1:  moveq #0, %d0
    move.b OFF_LINK_POS_FRAC(%a5), %d0
    add.w #LINK_QSPEED, %d0
    move.w %d0, %d2
    and.w #LINK_SUBPIXEL_MASK, %d2
    move.b %d2, OFF_LINK_POS_FRAC(%a5)
    lsr.w #LINK_SUBPIXEL_SHIFT, %d0
    clr.b OFF_WARPED(%a5)
    subq.w #1, %d0
    bmi 7f                      | not a whole pixel yet
2:  move.w %d0, -(%sp)
    bsr link_pixel
    move.w (%sp)+, %d0
    tst.w %d2
    bne 7f                      | stopped
    cmp.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bne 9f                      | a scroll or a cave took over
    tst.b OFF_WARPED(%a5)
    bne 9f
    dbra %d0, 2b
7:  bsr link_animate
8:  bsr check_warps
9:  movem.l (%sp)+, %d0-%d4
    rts

| One pixel of Link's movement.
|
| Like the 6502, Link walks whole 8-pixel grid steps: the key and the tile
| ahead are only looked at on a grid boundary, and a step that has begun is
| finished even if the key is let go. That is what lets him end up exactly
| on an entrance, where CheckWarps looks for him.
|
| d4.b = direction held (0 for none). Returns d2.w = 1 when he stops.
link_pixel:
    movem.l %d0-%d1/%d3, -(%sp)
    moveq #0, %d2
    tst.b OFF_COMMIT(%a5)
    bne 6f                      | part-way through a step

    tst.b OFF_LINK_SHOVE(%a5)
    bne 5f                      | being knocked back: no new step
    tst.b %d4
    beq 5f                      | key let go on a boundary
    move.b %d4, %d1

    | Turning onto the other axis snaps the perpendicular coordinate to the
    | grid, which is what EnsureObjectAligned does for the 6502.
    move.b OFF_LINK_DIR(%a5), %d0
    move.b %d1, OFF_LINK_DIR(%a5)
    move.b %d0, %d3
    eor.b %d1, %d3
    and.b #DIR_VERTICAL, %d3
    beq 1f                      | same axis as before, nothing to align
    move.b %d1, %d3
    and.b #DIR_VERTICAL, %d3
    beq 2f
    move.b OFF_LINK_X(%a5), %d3
    and.b #ALIGN_MASK, %d3
    move.b %d3, OFF_LINK_X(%a5)
    bra 1f
2:  move.b OFF_LINK_Y(%a5), %d3
    and.b #ALIGN_MASK, %d3
    or.b #ALIGN_Y_BIAS, %d3
    move.b %d3, OFF_LINK_Y(%a5)

1:  bsr link_collide
    tst.w %d0
    beq 3f
    tst.b OFF_LEVEL(%a5)
    beq 5f                      | blocked: keep facing the wall
    bsr block_push_tick         | a block may give way
    bsr uw_try_door             | a locked door may open
    bra 5f
3:  bsr grid_distance
    move.b %d0, OFF_COMMIT(%a5)
6:  move.b OFF_LINK_DIR(%a5), %d1
    bsr link_step_pixel
    tst.b OFF_COMMIT(%a5)
    beq 9f                      | a scroll or warp reset the step
    subq.b #1, OFF_COMMIT(%a5)
    bsr check_warps
    bra 9f
5:  moveq #1, %d2
9:  movem.l (%sp)+, %d0-%d1/%d3
    rts

| Knock-back: four pixels a frame until the shove is spent, or Link meets a
| wall or the edge of the room. Link never leaves the room this way.
link_shove:
    movem.l %d0-%d1/%d3, -(%sp)
    moveq #3, %d3
1:  tst.b OFF_LINK_SHOVE(%a5)
    beq 9f
    move.b OFF_LINK_SHOVE_DIR(%a5), %d1
    bsr link_shove_pixel
    tst.w %d0
    bne 8f
    subq.b #1, OFF_LINK_SHOVE(%a5)
    dbra %d3, 1b
    bra 9f
8:  clr.b OFF_LINK_SHOVE(%a5)
9:  movem.l (%sp)+, %d0-%d1/%d3
    rts

| d1.b = direction. Returns d0.w = 1 when Link cannot go that way.
link_shove_pixel:
    movem.l %d2-%d3, -(%sp)
    moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    move.b %d1, %d0
    and.b #DIR_VERTICAL, %d0
    bne 5f
    move.b %d2, %d0
    and.b #7, %d0
    bne 1f                      | the tile is only looked at on a grid boundary
    bsr link_collide
    tst.w %d0
    bne 8f
1:  btst #0, %d1
    beq 2f
    cmp.b OFF_OBJ_RIGHT(%a5), %d2
    bhs 8f
    addq.b #1, OFF_LINK_X(%a5)
    bra 7f
2:  cmp.b OFF_OBJ_LEFT(%a5), %d2
    bls 8f
    subq.b #1, OFF_LINK_X(%a5)
    bra 7f
5:  move.b %d3, %d0
    addq.b #3, %d0
    and.b #7, %d0
    bne 6f
    bsr link_collide
    tst.w %d0
    bne 8f
6:  btst #2, %d1
    beq 3f
    cmp.b OFF_OBJ_DOWN(%a5), %d3
    bhs 8f
    addq.b #1, OFF_LINK_Y(%a5)
    bra 7f
3:  cmp.b OFF_OBJ_UP(%a5), %d3
    bls 8f
    subq.b #1, OFF_LINK_Y(%a5)
7:  moveq #0, %d0
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d2-%d3
    rts

| Pixels from Link to the next grid boundary in direction d1.b (a whole 8
| when he is already on one). Sideways boundaries are at X mod 8 = 0 and
| vertical ones at Y mod 8 = 5. Returns d0.w.
grid_distance:
    movem.l %d1-%d2, -(%sp)
    moveq #0, %d2
    btst #0, %d1
    beq 1f
    move.b OFF_LINK_X(%a5), %d2
    and.w #7, %d2
    moveq #8, %d0
    sub.w %d2, %d0
    bra 9f
1:  btst #1, %d1
    beq 2f
    move.b OFF_LINK_X(%a5), %d0
    and.w #7, %d0
    bne 9f
    moveq #8, %d0
    bra 9f
2:  move.b OFF_LINK_Y(%a5), %d2
    addq.b #3, %d2
    and.w #7, %d2               | (Y - 5) mod 8
    btst #2, %d1
    beq 3f
    moveq #8, %d0
    sub.w %d2, %d0
    bra 9f
3:  move.w %d2, %d0
    bne 9f
    moveq #8, %d0
9:  movem.l (%sp)+, %d1-%d2
    rts

| Collect the held direction keys and reduce them to a single direction.
|
| Returns d0.b = one of the DIR_ bits, or 0.
read_input_dir:
    movem.l %d1-%d2/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    moveq #0, %d0

    tst.b SCAN_RIGHT(%a0)
    bne 1f
    tst.b SCAN_D(%a0)
    beq 2f
1:  ori.b #DIR_RIGHT, %d0
2:  tst.b SCAN_LEFT(%a0)
    bne 3f
    tst.b SCAN_A(%a0)
    beq 4f
3:  ori.b #DIR_LEFT, %d0
4:  tst.b SCAN_DOWN(%a0)
    bne 5f
    tst.b SCAN_S(%a0)
    beq 6f
5:  ori.b #DIR_DOWN, %d0
6:  tst.b SCAN_UP(%a0)
    bne 7f
    tst.b SCAN_W(%a0)
    beq 8f
7:  ori.b #DIR_UP, %d0
8:  move.b OFF_JOY0(%a5), %d1       | the joystick adds to the keys
    or.b OFF_JOY1(%a5), %d1
    btst #0, %d1
    beq 81f
    ori.b #DIR_UP, %d0
81: btst #1, %d1
    beq 82f
    ori.b #DIR_DOWN, %d0
82: btst #2, %d1
    beq 83f
    ori.b #DIR_LEFT, %d0
83: btst #3, %d1
    beq 84f
    ori.b #DIR_RIGHT, %d0
84:
    | A direction pressed this frame wins, so turning is immediate. Otherwise
    | keep the current one while it is still held.
    move.b OFF_PREV_INPUT_DIR(%a5), %d1
    move.b %d0, OFF_PREV_INPUT_DIR(%a5)
    move.b %d0, %d2
    not.b %d1
    and.b %d1, %d2
    beq 9f
    move.b %d2, %d0
    bra 10f
9:  move.b OFF_LINK_DIR(%a5), %d1
    and.b %d0, %d1
    beq 10f
    move.b %d1, %d0
10: | Keep only the lowest set bit so exactly one direction survives.
    move.b %d0, %d1
    neg.b %d1
    and.b %d1, %d0
    movem.l (%sp)+, %d1-%d2/%a0
    rts

| Test the tile Link would walk into.
|
| d1.b = direction. Returns d0.w = 0 when walkable, 1 when blocked.
link_collide:
    movem.l %d1-%d5, -(%sp)
    tst.b OFF_UW_PERSON(%a5)
    beq 0f
    btst #3, %d1                | DIR_UP: the old man is in the way
    beq 0f
    cmpi.b #0x8e, OFF_LINK_Y(%a5)
    bhs 0f
    moveq #1, %d0
    movem.l (%sp)+, %d1-%d5
    rts
0:  moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    add.w #HOTSPOT_Y_OFFSET, %d2
    moveq #0, %d3
    move.b OFF_LINK_X(%a5), %d3

    move.b %d1, %d4
    and.b #DIR_VERTICAL, %d4
    beq 3f                      | horizontal: adjust X instead

    btst #2, %d1                | DIR_DOWN
    beq 2f
    cmp.w #HOTSPOT_DOWN_LIMIT, %d2
    bhs 5f                      | already low in the room: take Y as it is
    add.w #HOTSPOT_STEP, %d2
    bra 5f
2:  sub.w #HOTSPOT_STEP, %d2
    bra 5f

3:  btst #0, %d1                | DIR_RIGHT
    beq 4f
    cmp.w #HOTSPOT_RIGHT_LIMIT, %d3
    bhs 5f
    add.w #HOTSPOT_RIGHT_STEP, %d3
    bra 5f
4:  cmp.w #HOTSPOT_LEFT_LIMIT, %d3
    blo 5f
    sub.w #HOTSPOT_STEP, %d3

5:  | Turn the hotspot into a column and row of the 32x22 tile play area.
    and.w #ALIGN_MASK, %d3
    lsr.w #3, %d3
    cmp.w #(PLAY_AREA_COLS - 1), %d3
    bls 6f
    moveq #(PLAY_AREA_COLS - 1), %d3
6:  sub.w #NES_PLAY_AREA_TOP, %d2
    bpl 7f
    moveq #0, %d2
7:  lsr.w #3, %d2
    cmp.w #(PLAY_AREA_ROWS - 1), %d2
    bls 8f
    moveq #(PLAY_AREA_ROWS - 1), %d2
8:  bsr fetch_tile
    move.w %d0, %d5

    | Moving vertically also looks at the next column along and keeps the
    | higher tile, because blocking tiles sort after walkable ones.
    move.b %d1, %d4
    and.b #DIR_VERTICAL, %d4
    beq 9f
    cmp.w #(PLAY_AREA_COLS - 1), %d3
    bhs 9f
    addq.w #1, %d3
    bsr fetch_tile
    cmp.w %d5, %d0
    bls 9f
    move.w %d0, %d5

9:  move.w %d5, %d0
    move.b %d5, OFF_HOTSPOT_TILE(%a5)
    bsr tile_blocks
    movem.l (%sp)+, %d1-%d5
    rts

| Look up the background tile at a play-area cell.
|
| d2.w = row 0..21, d3.w = column 0..31. Returns d0.w = NES tile index.
| The room map stores 16x16 squares, and metatile_tiles keeps the four 8x8
| tiles each square is built from, so no per-room tile grid is needed.
fetch_tile:
    tst.b OFF_LEVEL(%a5)
    bne fetch_tile_uw
    movem.l %d1-%d3/%a0, -(%sp)
    moveq #0, %d0
    move.w %d2, %d0
    lsr.w #1, %d0
    mulu.w #MAP_WIDTH, %d0
    moveq #0, %d1
    move.w %d3, %d1
    lsr.w #1, %d1
    add.l %d1, %d0
    moveq #0, %d1
    move.b OFF_ROOM_ID(%a5), %d1
    mulu.w #ROOM_BYTES, %d1
    add.l %d1, %d0
    ltab room_maps, %a0
    adda.l %d0, %a0
    moveq #0, %d0
    move.b (%a0), %d0

    | Quads are stored top-left, top-right, bottom-left, bottom-right.
    lsl.w #2, %d0
    move.w %d2, %d1
    and.w #1, %d1
    add.w %d1, %d1
    add.w %d1, %d0
    move.w %d3, %d1
    and.w #1, %d1
    add.w %d1, %d0
    ltab metatile_tiles, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    move.w %d1, %d0
    movem.l (%sp)+, %d1-%d3/%a0
    rts

| Underworld: the tile comes straight from the copy of the room's map.
fetch_tile_uw:
    movem.l %d1/%a0, -(%sp)
    moveq #0, %d0
    move.w %d2, %d0
    lsl.w #5, %d0
    add.w %d3, %d0
    lea OFF_UW_MAP(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    lvtab TILE_NES, %a0
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    movem.l (%sp)+, %d1/%a0
    rts

| d0.w = NES tile index. Returns d0.w = 1 if the tile blocks movement.
tile_blocks:
    tst.b OFF_LEVEL(%a5)
    bne 7f
    movem.l %d1-%d2/%a0, -(%sp)
    ltab walkable_tiles, %a0
    moveq #(WALKABLE_TILE_COUNT - 1), %d2
1:  cmp.b (%a0)+, %d0
    beq 8f                      | on the exception list, so walkable regardless
    dbra %d2, 1b
    cmp.w #FIRST_UNWALKABLE_TILE, %d0
    blo 8f
    moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| The underworld has no walkable-tile exceptions, only a threshold.
7:  cmp.w #UW_FIRST_UNWALKABLE_TILE, %d0
    blo 6f
    moveq #1, %d0
    rts
6:  moveq #0, %d0
    rts

| Move Link one pixel along d1.b; crossing the room bound starts a scroll.
link_step_pixel:
    movem.l %d2-%d4, -(%sp)
    moveq #0, %d3
    btst #0, %d1
    beq 2f
    move.b OFF_LINK_X(%a5), %d3
    addq.w #1, %d3
    moveq #0, %d4
    move.b OFF_BOUND_RIGHT(%a5), %d4
    cmp.w %d4, %d3
    bgt 6f
    move.b %d3, OFF_LINK_X(%a5)
    bra 9f
6:  move.b %d4, OFF_LINK_X(%a5)
    bsr start_scroll
    bra 9f

2:  btst #1, %d1
    beq 3f
    move.b OFF_LINK_X(%a5), %d3
    subq.w #1, %d3
    moveq #0, %d4
    move.b OFF_BOUND_LEFT(%a5), %d4
    cmp.w %d4, %d3
    blt 7f
    move.b %d3, OFF_LINK_X(%a5)
    bra 9f
7:  move.b %d4, OFF_LINK_X(%a5)
    bsr start_scroll
    bra 9f

3:  btst #2, %d1
    beq 4f
    move.b OFF_LINK_Y(%a5), %d3
    addq.w #1, %d3
    moveq #0, %d4
    move.b OFF_BOUND_DOWN(%a5), %d4
    cmp.w %d4, %d3
    bgt 8f
    move.b %d3, OFF_LINK_Y(%a5)
    bra 9f
8:  move.b %d4, OFF_LINK_Y(%a5)
    bsr start_scroll
    bra 9f

4:  move.b OFF_LINK_Y(%a5), %d3
    subq.w #1, %d3
    moveq #0, %d4
    move.b OFF_BOUND_UP(%a5), %d4
    cmp.w %d4, %d3
    blt 5f
    move.b %d3, OFF_LINK_Y(%a5)
    bra 9f
5:  move.b %d4, OFF_LINK_Y(%a5)
    bsr start_scroll

9:  movem.l (%sp)+, %d2-%d4
    rts

link_animate:
    subq.b #1, OFF_LINK_ANIM_COUNTER(%a5)
    bhi 9f
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    eori.b #1, OFF_LINK_ANIM_FRAME(%a5)
9:  rts

| d2.w = overworld room id. Returns d0.w = cave exit X, d1.w = cave exit Y.
compute_cave_exit_position:
    movem.l %d2-%d3/%a0, -(%sp)
    ltab room_attr_a, %a0
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d0
    andi.w #0x00f0, %d0

    ltab room_attr_f, %a0
    moveq #0, %d1
    move.b 0(%a0, %d2.w), %d1
    andi.w #0x0007, %d1
    lsl.w #4, %d1
    addi.w #0x004d, %d1

    movem.l (%sp)+, %d2-%d3/%a0
    rts

start_cave_entry:
    movem.l %d0-%d2, -(%sp)
    move.b OFF_ROOM_ID(%a5), OFF_CAVE_SOURCE_ROOM(%a5)
    move.b OFF_LINK_X(%a5), OFF_CAVE_DOOR_X(%a5)
    move.b #CAVE_DOOR_CENTER, OFF_LINK_X(%a5)
    move.b #CAVE_START_Y, OFF_LINK_Y(%a5)
    move.b #DIR_UP, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_LINK_ANIM_FRAME(%a5)
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    move.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    bsr enter_cave_far
    movem.l (%sp)+, %d0-%d2
    rts

leave_cave:
    movem.l %d0-%d2, -(%sp)
    move.b OFF_CAVE_SOURCE_ROOM(%a5), OFF_ROOM_ID(%a5)
    moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2
    bsr compute_cave_exit_position
    move.b %d0, OFF_LINK_X(%a5)
    move.b %d1, OFF_LINK_Y(%a5)
    move.b #1, OFF_EXIT_GUARD(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_LINK_ANIM_FRAME(%a5)
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bsr enter_room_far
    movem.l (%sp)+, %d0-%d2
    rts

update_cave:
    movem.l %d0-%d3, -(%sp)
    bsr erase_items
    bsr erase_sprite
    bsr erase_cave_fires_far
    bsr cave_talk_far
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 2f                      | Link waits while the old man speaks
    tst.b OFF_LIFT_TIMER(%a5)
    bne 4f                      | and while he holds the new item up
    bsr read_input_dir
    move.b %d0, %d1
    beq 1f
    move.b %d1, OFF_LINK_DIR(%a5)
    bsr cave_advance
    bsr link_animate
1:  cmp.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    bne 9f
    bsr item_pickup
    bsr cave_check_taken_far
4:  bsr lift_update
2:  bsr draw_cave_fires_far
    bsr draw_items
    bsr draw_link
9:  movem.l (%sp)+, %d0-%d3
    rts

| Advance Link inside the simplified cave room with plain rectangular bounds.
| d1.b = direction.
cave_advance:
    movem.l %d0/%d2-%d4, -(%sp)
    moveq #0, %d0
    move.b OFF_LINK_POS_FRAC(%a5), %d0
    add.w #LINK_QSPEED, %d0
    move.w %d0, %d2
    and.w #LINK_SUBPIXEL_MASK, %d2
    move.b %d2, OFF_LINK_POS_FRAC(%a5)
    lsr.w #LINK_SUBPIXEL_SHIFT, %d0
    beq 9f

    cmpi.b #CAVE_ROOM_BOUND_DOWN, OFF_LINK_Y(%a5)
    bls 0f
    btst #2, %d1                | in the doorway Link can only go up or down
    bne 0f
    btst #3, %d1
    beq 9f
0:  moveq #0, %d3
    btst #0, %d1
    beq 2f
    move.b OFF_LINK_X(%a5), %d3
    add.w %d0, %d3
    cmp.w #CAVE_ROOM_BOUND_RIGHT, %d3
    ble 1f
    move.w #CAVE_ROOM_BOUND_RIGHT, %d3
1:  move.b %d3, OFF_LINK_X(%a5)
    bra 9f

2:  btst #1, %d1
    beq 3f
    move.b OFF_LINK_X(%a5), %d3
    sub.w %d0, %d3
    cmp.w #CAVE_ROOM_BOUND_LEFT, %d3
    bge 4f
    move.w #CAVE_ROOM_BOUND_LEFT, %d3
4:  move.b %d3, OFF_LINK_X(%a5)
    bra 9f

3:  btst #2, %d1
    beq 5f
    move.b OFF_LINK_Y(%a5), %d3
    add.w %d0, %d3
    moveq #0, %d4               | only the doorway leads out
    move.b OFF_LINK_X(%a5), %d4
    sub.w #CAVE_DOOR_CENTER, %d4
    bpl 31f
    neg.w %d4
31: cmp.w #CAVE_EXIT_HALF_WIDTH, %d4
    bhi 32f
    cmp.w #CAVE_EXIT_Y, %d3
    blt 6f
    bsr leave_cave
    bra 9f
32: cmp.w #CAVE_ROOM_BOUND_DOWN, %d3
    ble 6f
    move.w #CAVE_ROOM_BOUND_DOWN, %d3
6:  move.b %d3, OFF_LINK_Y(%a5)
    bra 9f

5:  move.b OFF_LINK_Y(%a5), %d3
    sub.w %d0, %d3
    cmp.w #CAVE_ROOM_BOUND_UP, %d3
    bge 7f
    move.w #CAVE_ROOM_BOUND_UP, %d3
7:  move.b %d3, OFF_LINK_Y(%a5)

9:  movem.l (%sp)+, %d0/%d2-%d4
    rts

| Begin walking into the next room. d1.b = the direction Link is leaving in.
|
| NextRoomIdOffsets adds -16/+16/-1/+1, so the map is a 16-wide grid; a move
| that would leave it is refused rather than wrapping onto the far side.
start_scroll:
    movem.l %d0/%d2-%d3/%a0-%a1, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 0f
    tst.b OFF_IN_CELLAR(%a5)
    beq 1f
    btst #3, %d1                | in a cellar only the ladder up leads anywhere
    beq 9f
    bsr uw_leave_cellar
    bra 9f
1:  bsr uw_try_door             | a closed door keeps Link in the room
    tst.w %d0
    beq 9f
0:  moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2

    btst #0, %d1
    beq 2f
    move.w %d2, %d3
    and.w #(ROOM_GRID_WIDTH - 1), %d3
    cmp.w #(ROOM_GRID_WIDTH - 1), %d3
    beq 9f
    addq.w #1, %d2
    move.b OFF_BOUND_LEFT(%a5), OFF_SCROLL_TO_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_TO_Y(%a5)
    bra 8f

2:  btst #1, %d1
    beq 3f
    move.w %d2, %d3
    and.w #(ROOM_GRID_WIDTH - 1), %d3
    beq 9f
    subq.w #1, %d2
    move.b OFF_BOUND_RIGHT(%a5), OFF_SCROLL_TO_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_TO_Y(%a5)
    bra 8f

3:  btst #2, %d1
    beq 4f
    cmp.w #(ROOM_COUNT - ROOM_GRID_WIDTH), %d2
    blo 5f
    tst.b OFF_LEVEL(%a5)
    beq 9f
    bsr uw_leave_level          | off the bottom of a level is the way out
    bra 9f
5:  add.w #ROOM_GRID_WIDTH, %d2
    move.b OFF_LINK_X(%a5), OFF_SCROLL_TO_X(%a5)
    move.b OFF_BOUND_UP(%a5), OFF_SCROLL_TO_Y(%a5)
    bra 8f

4:  cmp.w #ROOM_GRID_WIDTH, %d2
    bhs 6f
    tst.b OFF_LEVEL(%a5)
    beq 9f
    bsr uw_leave_level
    bra 9f
6:  sub.w #ROOM_GRID_WIDTH, %d2
    move.b OFF_LINK_X(%a5), OFF_SCROLL_TO_X(%a5)
    move.b OFF_BOUND_DOWN(%a5), OFF_SCROLL_TO_Y(%a5)

8:  tst.b OFF_LEVEL(%a5)
    beq 7f
    lvtab ROOM_INDEX, %a0     | the neighbour has to be part of the level
    cmpi.b #0xff, 0(%a0, %d2.w)
    beq 9f
7:  move.b %d2, OFF_NEXT_ROOM_ID(%a5)
    bsr dbl_end_far             | the scroll composes straight onto the visible screen
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    move.b %d1, OFF_SCROLL_DIR(%a5)
    move.b OFF_LINK_X(%a5), OFF_SCROLL_FROM_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_FROM_Y(%a5)
    clr.w OFF_SCROLL_STEP(%a5)
    move.b #MODE_SCROLL, OFF_GAME_MODE(%a5)
    clr.b OFF_ERASE_VALID(%a5)
    move.w %d2, %d0
    movea.l OFF_BG_NEXT(%a5), %a1
    tst.b OFF_LEVEL(%a5)
    bne 10f
    bsr render_room
    bra 9f
10: bsr uw_render_next
9:  movem.l (%sp)+, %d0/%d2-%d3/%a0-%a1
    rts

update_scroll:
    movem.l %d0-%d2, -(%sp)
    addq.w #1, OFF_SCROLL_STEP(%a5)
    move.w OFF_SCROLL_STEP(%a5), %d0
    move.b OFF_SCROLL_DIR(%a5), %d1
    and.b #DIR_VERTICAL, %d1
    bne 1f
    bsr compose_horizontal
    move.w #SCROLL_STEPS_H, %d2
    bra 2f
1:  bsr compose_vertical
    move.w #SCROLL_STEPS_V, %d2
2:  bsr scroll_link_position
    bsr draw_link
    cmp.w OFF_SCROLL_STEP(%a5), %d2
    bhi 9f
    bsr finish_scroll
9:  movem.l (%sp)+, %d0-%d2
    rts

| Slide Link across while the world moves under him. His screen position and
| his room position share a mapping, so interpolating one does both.
scroll_link_position:
    movem.l %d0-%d4, -(%sp)
    move.w OFF_SCROLL_STEP(%a5), %d3
    move.b OFF_SCROLL_DIR(%a5), %d4
    and.b #DIR_VERTICAL, %d4
    bne 1f
    move.w #SCROLL_STEPS_H, %d4
    bra 2f
1:  move.w #SCROLL_STEPS_V, %d4

2:  moveq #0, %d0
    move.b OFF_SCROLL_FROM_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_SCROLL_TO_X(%a5), %d1
    sub.w %d0, %d1
    muls.w %d3, %d1
    divs.w %d4, %d1
    add.w %d1, %d0
    move.b %d0, OFF_LINK_X(%a5)

    moveq #0, %d0
    move.b OFF_SCROLL_FROM_Y(%a5), %d0
    moveq #0, %d1
    move.b OFF_SCROLL_TO_Y(%a5), %d1
    sub.w %d0, %d1
    muls.w %d3, %d1
    divs.w %d4, %d1
    add.w %d1, %d0
    move.b %d0, OFF_LINK_Y(%a5)

    movem.l (%sp)+, %d0-%d4
    rts

finish_scroll:
    | The final compose already put the whole new room on screen, so the room
    | that was being scrolled in simply becomes the current one.
    move.l OFF_BG_CUR(%a5), %d0
    move.l OFF_BG_NEXT(%a5), %d1
    move.l %d1, OFF_BG_CUR(%a5)
    move.l %d0, OFF_BG_NEXT(%a5)
    move.b OFF_NEXT_ROOM_ID(%a5), OFF_ROOM_ID(%a5)
    move.b OFF_SCROLL_TO_X(%a5), OFF_LINK_X(%a5)
    move.b OFF_SCROLL_TO_Y(%a5), OFF_LINK_Y(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    tst.b OFF_LEVEL(%a5)
    beq 1f
    bsr uw_commit_next
1:  bsr spawn_room_enemies
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    rts
