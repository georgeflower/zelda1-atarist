| The overworld's special mechanics (ROM: UpdateDock, CheckLadder, CreateRoomObjects for the heart container on P6).
|
|   raft     the docks of F6 ($55) and P4 ($3F): with the raft Link stands at the dock and is carried across the water
|   ladder   six screens (LadderRoomsOW): with the ladder Link may walk on water, a ladder shows under him
|   heart    the heart container of P6 ($5F), on the island at ($C0, $90)
|
| owspec_room_start is called by spawn_room_enemies for every overworld screen Link comes into, owspec_update
| once per frame from items_update (overworld only).

    .equ RAFT_ITEM, 0x0c
    .equ LADDER_ITEM, 0x0d
    .equ RAFT_SLOT, 2                   | shares the last item slot with the food
    .equ HEART_ITEM, 0x1a
    .equ OW_ITEM_TAKEN, 6               | OW_KILLS bit: the screen's item was taken
    .equ DOCK_LINK_TOP, 0x3d            | Link at the top edge of the dock's screen: the raft takes him down
    .equ DOCK_LINK_BOTTOM, 0x7d         | Link at the dock: the raft takes him up
    .equ RAFT_STEP, 2                   | pixels a frame

owspec_room_start:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_RAFT_STATE(%a5)
    clr.b OFF_RAFT_REST(%a5)
    clr.b OFF_LADDER_SHOWN(%a5)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    cmp.b #0x5f, %d0
    bne 9f
    lea OFF_OW_KILLS(%a5), %a0
    btst #OW_ITEM_TAKEN, 0(%a0, %d0.w)
    bne 9f
    move.b #HEART_ITEM, OFF_ITEM_ID(%a5)
    move.b #0xc0, OFF_ITEM_X(%a5)
    move.b #0x90, OFF_ITEM_Y(%a5)
    move.b #2, OFF_ITEM_ACTIVE(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

owspec_update:
    tst.b OFF_LEVEL(%a5)
    bne 9f
    bsr raft_update
    bsr ladder_update
9:  rts

| ------------------------------------------------------------------------------------------------------ the raft
raft_update:
    movem.l %d0-%d2, -(%sp)
    move.b OFF_RAFT_STATE(%a5), %d0
    bne 5f
    tst.b OFF_INV_RAFT(%a5)
    beq 9f
    moveq #0, %d1
    move.b OFF_ROOM_ID(%a5), %d1
    move.b #0x80, %d2                   | the dock's column: $80 in F6, $60 in P4
    cmp.b #0x55, %d1
    beq 1f
    move.b #0x60, %d2
    cmp.b #0x3f, %d1
    bne 9f
1:  cmp.b OFF_LINK_X(%a5), %d2
    bne 8f
    move.b OFF_LINK_Y(%a5), %d1
    moveq #1, %d0                       | at the top: down
    cmp.b #DOCK_LINK_TOP, %d1
    beq 3f
    moveq #2, %d0                       | at the dock: up
    cmp.b #DOCK_LINK_BOTTOM, %d1
    bne 8f
    tst.b OFF_RAFT_REST(%a5)
    bne 9f                              | he has just been brought here
3:  move.b %d0, OFF_RAFT_STATE(%a5)
    move.b #RAFT_ITEM, (OFF_ITEM_ID + RAFT_SLOT)(%a5)
    move.b %d2, (OFF_ITEM_X + RAFT_SLOT)(%a5)
    addq.b #6, %d1                      | the raft lies 6 pixels under him
    move.b %d1, (OFF_ITEM_Y + RAFT_SLOT)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    cmp.b #1, %d0
    beq 4f
    move.b #DIR_UP, OFF_LINK_DIR(%a5)
4:  sfx SFX_SECRET
    bra 9f
8:  clr.b OFF_RAFT_REST(%a5)
    bra 9f

| riding
5:  cmp.b #1, %d0
    bne 6f
    addq.b #RAFT_STEP, OFF_LINK_Y(%a5)                  | down to the dock
    addq.b #RAFT_STEP, (OFF_ITEM_Y + RAFT_SLOT)(%a5)
    cmpi.b #DOCK_LINK_BOTTOM, OFF_LINK_Y(%a5)
    bne 9f
    move.b #1, OFF_RAFT_REST(%a5)
    bra 7f
6:  subq.b #RAFT_STEP, OFF_LINK_Y(%a5)                  | up, and off the screen
    subq.b #RAFT_STEP, (OFF_ITEM_Y + RAFT_SLOT)(%a5)
    cmpi.b #DOCK_LINK_TOP, OFF_LINK_Y(%a5)
    bne 9f
7:  clr.b OFF_RAFT_STATE(%a5)
    clr.b OFF_LINK_HELD(%a5)
    clr.b (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
    cmp.b #2, %d0
    bne 9f
    moveq #DIR_UP, %d1
    bsr start_scroll                    | the raft leaves the screen at the top
9:  movem.l (%sp)+, %d0-%d2
    rts

| ---------------------------------------------------------------------------------------------------- the ladder
ladder_rooms:
    .byte 0x17, 0x18, 0x19, 0x27, 0x4f, 0x5f
    .even

| Called by link_collide with the tile Link would walk into in d5.w and d0.w = 1 (blocked): in a ladder screen with
| the ladder, water does not block (the ROM puts the ladder down in front of him whenever the square ahead is water).
ow_ladder_ok:
    tst.b OFF_LEVEL(%a5)
    bne 9f
    tst.b OFF_INV_LADDER(%a5)
    beq 9f
    cmp.w #0x8d, %d5
    blo 9f
    cmp.w #0x98, %d5
    bhi 9f
    bsr in_ladder_room
    bne 9f
    moveq #0, %d0
9:  rts

| Z = 1 when the screen is one of the six.
in_ladder_room:
    movem.l %d0-%d1/%a0, -(%sp)
    lea ladder_rooms(%pc), %a0
    move.b OFF_ROOM_ID(%a5), %d1
    moveq #5, %d0
1:  cmp.b (%a0)+, %d1
    beq 2f
    dbra %d0, 1b
    moveq #1, %d0                       | not found: Z = 0
    bra 3f
2:  moveq #0, %d0                       | found: Z = 1
3:  movem.l (%sp)+, %d0-%d1/%a0         | (movem keeps the flags)
    rts

| The ladder is drawn on the square of water Link stands on, or the one he is walking into.
ladder_update:
    movem.l %d0-%d4/%a0, -(%sp)
    tst.b OFF_FOOD_TIMER(%a5)
    bne 9f                              | the food has the slot
    tst.b OFF_INV_LADDER(%a5)
    beq 7f
    bsr in_ladder_room
    bne 7f
    moveq #0, %d3                       | the feet: X + 8, Y + $B
    move.b OFF_LINK_X(%a5), %d3
    addq.w #8, %d3
    moveq #0, %d4
    move.b OFF_LINK_Y(%a5), %d4
    add.w #HOTSPOT_Y_OFFSET, %d4
    bsr 20f
    cmp.w #0x8d, %d0
    blo 1f
    cmp.w #0x98, %d0
    bls 5f
1:  tst.b OFF_COMMIT(%a5)               | on land: the square he is walking into
    beq 7f
    move.b OFF_LINK_DIR(%a5), %d0
    btst #0, %d0
    beq 2f
    addq.w #8, %d3
    bra 4f
2:  btst #1, %d0
    beq 3f
    subq.w #8, %d3
    bra 4f
3:  btst #2, %d0
    beq 31f
    addq.w #8, %d4
    bra 4f
31: subq.w #8, %d4
4:  bsr 20f
    cmp.w #0x8d, %d0
    blo 7f
    cmp.w #0x98, %d0
    bhi 7f
5:  and.w #0xf0, %d3                    | the square's top left
    sub.w #NES_PLAY_AREA_TOP, %d4
    and.w #0xf0, %d4
    add.w #NES_PLAY_AREA_TOP, %d4
    move.b #LADDER_ITEM, (OFF_ITEM_ID + RAFT_SLOT)(%a5)
    move.b %d3, (OFF_ITEM_X + RAFT_SLOT)(%a5)
    move.b %d4, (OFF_ITEM_Y + RAFT_SLOT)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
    move.b #1, OFF_LADDER_SHOWN(%a5)
    bra 9f
7:  tst.b OFF_LADDER_SHOWN(%a5)
    beq 9f
    clr.b OFF_LADDER_SHOWN(%a5)
    clr.b (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
9:  movem.l (%sp)+, %d0-%d4/%a0
    rts

| d3.w = X, d4.w = Y of a point: d0.w = the NES tile there.
20: movem.l %d2-%d3, -(%sp)
    move.w %d4, %d2
    sub.w #NES_PLAY_AREA_TOP, %d2
    bpl 21f
    moveq #0, %d2
21: lsr.w #3, %d2
    cmp.w #(PLAY_AREA_ROWS - 1), %d2
    bls 22f
    moveq #(PLAY_AREA_ROWS - 1), %d2
22: lsr.w #3, %d3
    cmp.w #(PLAY_AREA_COLS - 1), %d3
    bls 23f
    moveq #(PLAY_AREA_COLS - 1), %d3
23: bsr fetch_tile
    movem.l (%sp)+, %d2-%d3
    rts
