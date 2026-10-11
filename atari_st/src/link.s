| Link: input, collision, movement, animation and room transitions.
|
| The collision rules are GetCollidableTile's, from Z_07.asm: a hotspot $B
| pixels below Link's top, pushed 8 or $10 pixels towards the direction of
| travel, is turned into an 8x8 tile coordinate; the tile there blocks if it
| sorts at or above ObjectFirstUnwalkableTile and is not one of the nine
| exceptions in WalkableTiles.

link_update:
    movem.l %d0-%d3, -(%sp)
    bsr read_input_dir
    move.b %d0, %d1
    beq 8f                      | nothing held: stand still

    | Turning onto the other axis snaps the perpendicular coordinate to the
    | grid, which is what EnsureObjectAligned does for the 6502.
    move.b OFF_LINK_DIR(%a5), %d2
    move.b %d1, OFF_LINK_DIR(%a5)
    move.b %d2, %d3
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
    bsr try_enter_cave
    tst.w %d0
    bne 8f                      | cave entry switched modes and redrew already
    bra 7f                      | blocked: keep animating, do not move
3:
    bsr link_advance
7:  bsr link_animate
8:  movem.l (%sp)+, %d0-%d3
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
8:
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
    moveq #0, %d2
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
    lea room_maps(%pc), %a0
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
    lea metatile_tiles(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    move.w %d1, %d0
    movem.l (%sp)+, %d1-%d3/%a0
    rts

| d0.w = NES tile index. Returns d0.w = 1 if the tile blocks movement.
tile_blocks:
    movem.l %d1-%d2/%a0, -(%sp)
    lea walkable_tiles(%pc), %a0
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

| Advance Link by the whole pixels the sub-pixel accumulator has earned.
| d1.b = direction.
link_advance:
    movem.l %d0/%d2-%d3, -(%sp)
    moveq #0, %d0
    move.b OFF_LINK_POS_FRAC(%a5), %d0
    add.w #LINK_QSPEED, %d0
    move.w %d0, %d2
    and.w #LINK_SUBPIXEL_MASK, %d2
    move.b %d2, OFF_LINK_POS_FRAC(%a5)
    lsr.w #LINK_SUBPIXEL_SHIFT, %d0
    beq 9f

    moveq #0, %d3
    btst #0, %d1
    beq 2f
    move.b OFF_LINK_X(%a5), %d3
    add.w %d0, %d3
    cmp.w #ROOM_BOUND_RIGHT, %d3
    bgt 6f
    move.b %d3, OFF_LINK_X(%a5)
    bra 9f
6:  move.b #ROOM_BOUND_RIGHT, OFF_LINK_X(%a5)
    bsr start_scroll
    bra 9f

2:  btst #1, %d1
    beq 3f
    move.b OFF_LINK_X(%a5), %d3
    sub.w %d0, %d3
    cmp.w #ROOM_BOUND_LEFT, %d3
    blt 7f
    move.b %d3, OFF_LINK_X(%a5)
    bra 9f
7:  move.b #ROOM_BOUND_LEFT, OFF_LINK_X(%a5)
    bsr start_scroll
    bra 9f

3:  btst #2, %d1
    beq 4f
    move.b OFF_LINK_Y(%a5), %d3
    add.w %d0, %d3
    cmp.w #ROOM_BOUND_DOWN, %d3
    bgt 8f
    move.b %d3, OFF_LINK_Y(%a5)
    bra 9f
8:  move.b #ROOM_BOUND_DOWN, OFF_LINK_Y(%a5)
    bsr start_scroll
    bra 9f

4:  move.b OFF_LINK_Y(%a5), %d3
    sub.w %d0, %d3
    cmp.w #ROOM_BOUND_UP, %d3
    blt 5f
    move.b %d3, OFF_LINK_Y(%a5)
    bra 9f
5:  move.b #ROOM_BOUND_UP, OFF_LINK_Y(%a5)
    bsr start_scroll

9:  movem.l (%sp)+, %d0/%d2-%d3
    rts

link_animate:
    subq.b #1, OFF_LINK_ANIM_COUNTER(%a5)
    bhi 9f
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    eori.b #1, OFF_LINK_ANIM_FRAME(%a5)
9:  rts

| Trigger the minimal cave mode when Link pushes up into an overworld cave.
|
| d1.b = attempted direction. Returns d0.w = 1 when a cave was entered.
try_enter_cave:
    movem.l %d1-%d2/%a0, -(%sp)
    cmp.b #DIR_UP, %d1
    bne 8f
    moveq #0, %d0
    move.b OFF_HOTSPOT_TILE(%a5), %d0
    cmp.w #CAVE_ENTRANCE_TILE, %d0
    beq 1f
    cmp.w #0x00da, %d0
    beq 1f
    cmp.w #0x00e6, %d0
    beq 1f
    cmp.w #0x00e7, %d0
    beq 1f
    cmp.w #0x00e8, %d0
    beq 1f
    cmp.w #0x00e9, %d0
    bne 8f
1:

    lea room_attr_b(%pc), %a0
    moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d0
    andi.w #0x00fc, %d0
    cmpi.w #0x0040, %d0
    blo 8f

    bsr start_cave_entry
    moveq #1, %d0
    bra 9f

8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| d2.w = overworld room id. Returns d0.w = cave exit X, d1.w = cave exit Y.
compute_cave_exit_position:
    movem.l %d2-%d3/%a0, -(%sp)
    lea room_attr_a(%pc), %a0
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d0
    andi.w #0x00f0, %d0

    lea room_attr_f(%pc), %a0
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
    move.b #CAVE_START_Y, OFF_LINK_Y(%a5)
    move.b #DIR_UP, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_LINK_ANIM_FRAME(%a5)
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    move.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    bsr enter_cave
    movem.l (%sp)+, %d0-%d2
    rts

leave_cave:
    movem.l %d0-%d2, -(%sp)
    move.b OFF_CAVE_SOURCE_ROOM(%a5), OFF_ROOM_ID(%a5)
    move.b OFF_CAVE_DOOR_X(%a5), OFF_LINK_X(%a5)
    move.b #CAVE_RETURN_Y, OFF_LINK_Y(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_LINK_ANIM_FRAME(%a5)
    move.b #LINK_ANIM_PERIOD, OFF_LINK_ANIM_COUNTER(%a5)
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bsr enter_room
    movem.l (%sp)+, %d0-%d2
    rts

update_cave:
    movem.l %d0-%d3, -(%sp)
    bsr erase_sprite
    bsr read_input_dir
    move.b %d0, %d1
    beq 1f
    move.b %d1, OFF_LINK_DIR(%a5)
    bsr cave_advance
    bsr link_animate
1:  cmp.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    bne 9f
    bsr draw_link
9:  movem.l (%sp)+, %d0-%d3
    rts

| Advance Link inside the simplified cave room with plain rectangular bounds.
| d1.b = direction.
cave_advance:
    movem.l %d0/%d2-%d5, -(%sp)
    moveq #0, %d0
    move.b OFF_LINK_POS_FRAC(%a5), %d0
    add.w #LINK_QSPEED, %d0
    move.w %d0, %d2
    and.w #LINK_SUBPIXEL_MASK, %d2
    move.b %d2, OFF_LINK_POS_FRAC(%a5)
    lsr.w #LINK_SUBPIXEL_SHIFT, %d0
    beq 9f

    moveq #0, %d3
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
    cmp.w #CAVE_ROOM_BOUND_DOWN, %d3
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
    cmp.w #CAVE_ROOM_BOUND_UP, %d3
    bne 9f
    moveq #0, %d4
    move.b OFF_LINK_X(%a5), %d4
    moveq #0, %d5
    move.b OFF_CAVE_DOOR_X(%a5), %d5
    sub.w %d5, %d4
    bpl 8f
    neg.w %d4
8:  cmp.w #CAVE_EXIT_HALF_WIDTH, %d4
    bhi 9f
    bsr leave_cave

9:  movem.l (%sp)+, %d0/%d2-%d5
    rts

| Begin walking into the next room. d1.b = the direction Link is leaving in.
|
| NextRoomIdOffsets adds -16/+16/-1/+1, so the map is a 16-wide grid; a move
| that would leave it is refused rather than wrapping onto the far side.
start_scroll:
    movem.l %d0/%d2-%d3, -(%sp)
    moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2

    btst #0, %d1
    beq 2f
    move.w %d2, %d3
    and.w #(ROOM_GRID_WIDTH - 1), %d3
    cmp.w #(ROOM_GRID_WIDTH - 1), %d3
    beq 9f
    addq.w #1, %d2
    move.b #ROOM_BOUND_LEFT, OFF_SCROLL_TO_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_TO_Y(%a5)
    bra 8f

2:  btst #1, %d1
    beq 3f
    move.w %d2, %d3
    and.w #(ROOM_GRID_WIDTH - 1), %d3
    beq 9f
    subq.w #1, %d2
    move.b #ROOM_BOUND_RIGHT, OFF_SCROLL_TO_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_TO_Y(%a5)
    bra 8f

3:  btst #2, %d1
    beq 4f
    cmp.w #(ROOM_COUNT - ROOM_GRID_WIDTH), %d2
    bhs 9f
    add.w #ROOM_GRID_WIDTH, %d2
    move.b OFF_LINK_X(%a5), OFF_SCROLL_TO_X(%a5)
    move.b #ROOM_BOUND_UP, OFF_SCROLL_TO_Y(%a5)
    bra 8f

4:  cmp.w #ROOM_GRID_WIDTH, %d2
    blo 9f
    sub.w #ROOM_GRID_WIDTH, %d2
    move.b OFF_LINK_X(%a5), OFF_SCROLL_TO_X(%a5)
    move.b #ROOM_BOUND_DOWN, OFF_SCROLL_TO_Y(%a5)

8:  move.b %d2, OFF_NEXT_ROOM_ID(%a5)
    move.b %d1, OFF_SCROLL_DIR(%a5)
    move.b OFF_LINK_X(%a5), OFF_SCROLL_FROM_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_FROM_Y(%a5)
    clr.w OFF_SCROLL_STEP(%a5)
    move.b #MODE_SCROLL, OFF_GAME_MODE(%a5)
    clr.b OFF_ERASE_VALID(%a5)
    move.w %d2, %d0
    movea.l OFF_BG_NEXT(%a5), %a1
    bsr render_room
9:  movem.l (%sp)+, %d0/%d2-%d3
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
    bsr spawn_room_enemies
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    rts
