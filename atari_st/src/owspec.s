| The overworld's special mechanics (ROM: UpdateDock, CheckLadder, CreateRoomObjects for the heart container on P6).
|
|   raft     the docks of F6 ($55) and P4 ($3F): with the raft Link stands at the dock and is carried across the water
|   ladder   six screens (LadderRoomsOW): with the ladder Link may walk on water, a ladder shows under him
|   heart    the heart container of P6 ($5F), on the island at ($C0, $90)
|   armos    twelve screens of them: pushing one wakes it (InitArmosOrFlyingGhini); seven hide stairs or the bracelet
|   recorder the whirlwind (SummonWhirlwind) takes Link to the entrance of the next level whose piece he has; in
|            screen $42 the pond of Level 7 turns to land and shows its stairs (UpdateFluteSecret)
|   fairy    the ponds of $39 and $43 (UpdatePondFairy): the hearts fill, eight hearts orbit the fairy
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
    .equ MODE_ARMOS, 35                 | draw modes (tools/actors.py MODE_*)
    .equ MODE_FAIRY, 36
    .equ ARMOS_FADE, 0x3f               | frames an armos takes to rise
    .equ BRACELET_ITEM, 0x14
    .equ POND_ROOM, 0x42                | the First Quest's pond (quest_patch makes the other ten the Second Quest's)
    .equ FLUTE_TABLE, (128 * SECRET_BYTES + 16)   | in room_secrets after the extra bytes: per screen the stairs the recorder reveals, $FF none
    .equ FAIRY_X, 0x78
    .equ FAIRY_Y, 0x7d
    .equ SECRET_RECORDS, (128 * SECRET_BYTES)   | where the extra table of room_secrets starts (build_assets OW_EXTRA_BYTES)

owspec_room_start:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_RAFT_STATE(%a5)
    clr.b OFF_RAFT_REST(%a5)
    clr.b OFF_LADDER_SHOWN(%a5)
    clr.b OFF_WHIRL_SUMMONED(%a5)
    bsr pond_leave                      | the water goes back to what it was
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
    bne uw_ladder_update
    bsr raft_update
    bsr ladder_update
    bsr pond_update
    bsr whirl_update
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
    bne uw_ladder_ok
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

| The dungeons' ladder (CheckLadder and Link_EndMoveAndAnimate, the same routines as the overworld's): when Link is about to
| walk into the moat (NES tile $F4) with the ladder, it is laid down in front of him, 16 pixels long (LinkToLadderOffsetsX/Y:
| up (0,-5), down (0,+19), left (-16,+3), right (+16,+3) from his position), and he may walk along it only, not across. It is put
| away when he is a whole ladder past it, or off its line, or has left the room; the moat beyond gets a new one.
    .equ UW_MOAT, 0xf4
ladder_offset_x:
    .byte 0, 0, -16, 16
ladder_offset_y:
    .byte -5, 19, 3, 3

| link_collide has d5.w = the tile ahead of Link, d0.w = 1 (blocked) and d1.b = his direction. Returns d0.w = 0 to let him on.
uw_ladder_ok:
    tst.b OFF_INV_LADDER(%a5)
    beq 9f
    cmp.w #UW_MOAT, %d5
    bne 9f
    movem.l %d1-%d3/%a0, -(%sp)
    tst.b OFF_LADDER_SHOWN(%a5)
    beq 2f
    move.b OFF_LADDER_DIR(%a5), %d2     | a ladder is down: he may walk along its line, but only up to it
    eor.b %d1, %d2
    and.b #DIR_VERTICAL, %d2
    bne 7f                              | (not the same axis)
    | CheckLadder: moving on without a look at the tiles is for a Link that has not reached the ladder; once he is on it
    | (distance 0) or past it, the moat blocks like any other, so the ladder carries him one square and no further.
    moveq #0, %d2
    moveq #0, %d3
    move.b %d1, %d0
    and.b #DIR_VERTICAL, %d0
    beq 15f
    move.b OFF_LINK_Y(%a5), %d3
    addq.w #3, %d3
    move.b (OFF_ITEM_Y + RAFT_SLOT)(%a5), %d2
    sub.w %d3, %d2                      | the ladder's Y less his: > 0 below him, < 0 above
    btst #3, %d1
    bne 14f
    bra 16f                             | down: the ladder must lie below
14: neg.w %d2                           | up: the ladder must lie above
    bra 16f
15: move.b OFF_LINK_X(%a5), %d3
    move.b (OFF_ITEM_X + RAFT_SLOT)(%a5), %d2
    sub.w %d3, %d2                      | the ladder's X less his
    btst #1, %d1
    beq 16f
    neg.w %d2                           | left: the ladder must lie to the left
16: moveq #1, %d0                       | (blocked again unless it is still ahead)
    tst.w %d2
    bgt 8f
    bne 7f
    | Squarely on an up ladder (case E of CheckLadder): the tile ahead is the water under his top half, so the tile above
    | it decides, as if he stood 8 pixels higher: a moat one square thick lets him off, a thicker one does not.
    btst #3, %d1
    beq 7f
    moveq #0, %d2
    move.b OFF_HOT_ROW(%a5), %d2
    subq.w #1, %d2
    bmi 7f
    moveq #0, %d3
    move.b OFF_LINK_X(%a5), %d3
    lsr.w #3, %d3
    bsr fetch_tile
    bsr tile_blocks
    tst.w %d0
    bne 17f
    addq.w #1, %d3
    bsr fetch_tile
    bsr tile_blocks
    tst.w %d0
    beq 8f
17: moveq #1, %d0
    bra 7f
2:  tst.b OFF_FOOD_TIMER(%a5)
    bne 7f                              | (the food has the slot)
    moveq #0, %d2                       | which of the four: up, down, left, right
    btst #3, %d1
    bne 3f
    moveq #1, %d2
    btst #2, %d1
    bne 3f
    moveq #2, %d2
    btst #1, %d1
    bne 3f
    moveq #3, %d2
3:  lea ladder_offset_x(%pc), %a0
    move.b OFF_LINK_X(%a5), %d0
    add.b 0(%a0, %d2.w), %d0
    move.b %d0, (OFF_ITEM_X + RAFT_SLOT)(%a5)
    lea ladder_offset_y(%pc), %a0
    move.b OFF_LINK_Y(%a5), %d0
    add.b 0(%a0, %d2.w), %d0
    move.b %d0, (OFF_ITEM_Y + RAFT_SLOT)(%a5)
    move.b #LADDER_ITEM, (OFF_ITEM_ID + RAFT_SLOT)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
    move.b %d1, OFF_LADDER_DIR(%a5)
    move.b #1, OFF_LADDER_STATE(%a5)
    move.b #1, OFF_LADDER_SHOWN(%a5)
    move.b OFF_ROOM_ID(%a5), OFF_LADDER_ROOM(%a5)
8:  moveq #0, %d0
    movem.l (%sp)+, %d1-%d3/%a0
    rts
7:  movem.l (%sp)+, %d1-%d3/%a0
9:  rts

| Once a frame in a dungeon: the ladder is put away when the rules say so (CheckLadder).
uw_ladder_update:
    tst.b OFF_LADDER_SHOWN(%a5)
    beq 9f
    movem.l %d0-%d3, -(%sp)
    move.b OFF_ROOM_ID(%a5), %d0
    cmp.b OFF_LADDER_ROOM(%a5), %d0
    bne 5f
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    addq.w #3, %d1
    moveq #0, %d2
    move.b (OFF_ITEM_X + RAFT_SLOT)(%a5), %d2
    moveq #0, %d3
    move.b (OFF_ITEM_Y + RAFT_SLOT)(%a5), %d3
    btst #3, OFF_LADDER_DIR(%a5)
    bne 1f
    btst #2, OFF_LADDER_DIR(%a5)
    beq 2f
1:  cmp.w %d2, %d0                      | vertical: he has to stay in its column
    bne 5f
    sub.w %d3, %d1
    bra 3f
2:  cmp.w %d3, %d1                      | horizontal: and in its row
    bne 5f
    move.w %d0, %d1
    sub.w %d2, %d1
3:  bpl 4f
    neg.w %d1
4:  cmp.w #16, %d1
    blo 6f                              | on it
    bhi 5f                              | past it
    move.b OFF_LINK_DIR(%a5), %d0       | exactly a ladder away: only when he still faces it and has not been on it
    cmp.b OFF_LADDER_DIR(%a5), %d0
    bne 5f
    cmpi.b #1, OFF_LADDER_STATE(%a5)
    beq 7f
5:  clr.b OFF_LADDER_SHOWN(%a5)
    clr.b (OFF_ITEM_ACTIVE + RAFT_SLOT)(%a5)
    bra 7f
6:  move.b #2, OFF_LADDER_STATE(%a5)
7:  movem.l (%sp)+, %d0-%d3
9:  rts

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

| -------------------------------------------------------------------------------------------------------- armos
| CheckPassiveTileObjects: a step blocked by an armos tile ($C0-$C3) wakes the armos on that square, and one blocked by a
| gravestone ($BC-$BF) lets a flying ghini out of it, unless one is rising there already. link_pixel calls this after
| every blocked step on the overworld.
ow_armos_touch:
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    tst.b OFF_LEVEL(%a5)
    bne 9f
    moveq #0, %d0
    move.b OFF_HOTSPOT_TILE(%a5), %d0
    sub.w #0xbc, %d0
    cmp.w #7, %d0
    bhi 9f
    moveq #MON_FGHINI, %d1              | ChooseObjType: tile $C0 and up is an armos, below it a flying ghini
    cmp.w #4, %d0
    blo 4f
    moveq #MON_ARMOS, %d1
4:  moveq #0, %d2
    move.b OFF_HOT_COL(%a5), %d2
    lsr.w #1, %d2
    lsl.w #4, %d2                       | the square's X
    moveq #0, %d3
    move.b OFF_HOT_ROW(%a5), %d3
    lsr.w #1, %d3
    lsl.w #4, %d3
    add.w #(NES_PLAY_AREA_TOP - 3), %d3 | and the Y a monster standing on it has
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 3f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 2f
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmp.b #MON_ARMOS, %d0
    beq 15f
    cmp.b #MON_FGHINI, %d0
    bne 2f
15: cmp.b OFF_ENEMY_X(%a5, %d5.w), %d2
    bne 2f
    cmp.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    beq 9f                              | it is rising there already
2:  addq.w #1, %d5
    bra 1b
3:  moveq #DIR_DOWN, %d4
    bsr enemy_make
9:  movem.l (%sp)+, %d0-%d5/%a0-%a1
    rts

| A shove that ends between two squares would leave the monster off its lane: the walker only looks at the squares ahead (and
| turns) where both X and Y are on the grid, so it would walk on through walls and round the screen. Called from
| enemy_shove on its last frame: d2 = X, d3 = Y (words), d6 = the way it was shoved; back to the last square boundary it
| passed (the one it started from when it passed none). The lanes down and up are at Y = 16 n + 13.
enemy_shove_snap:
    cmpi.b #ENEMY_SHOVE_FRAMES, OFF_ENEMY_HURT(%a5, %d5.w)
    bne 4f                              | only the shove's last frame
    btst #0, %d6
    beq 1f
    and.w #0xfff0, %d2                  | right: down to the boundary
    rts
1:  btst #1, %d6
    beq 2f
    add.w #15, %d2                      | left: up to the boundary
    and.w #0xfff0, %d2
    rts
2:  sub.w #13, %d3
    btst #2, %d6
    bne 3f
    add.w #15, %d3
3:  and.w #0xfff0, %d3
    add.w #13, %d3
4:  rts

armos_rooms:
    .byte 0x24, 0x0b, 0x1c, 0x22, 0x34, 0x3d, 0x4e      | SecretArmosRoomIds
armos_xs:
    .byte 0xe0, 0xb0, 0xb0, 0x30, 0x40, 0x90, 0xa0      | and the X of the armos over the secret (its row is the fifth)
    .even

| Called for a monster just made (d5 = it, d0.w = its behaviour): the three that belong to this file.
owspec_init:
    movem.l %d0/%a0, -(%sp)
    cmp.w #BEH_ARMOS, %d0
    bne 1f
    lea OFF_ENEMY_ANIMC(%a5), %a0
    move.b #ARMOS_FADE, 0(%a0, %d5.w)   | it fades in for $3F frames, and no weapon touches it until then
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #GHOST_NOHIT, 0(%a0, %d5.w)
    bra 9f
1:  move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)     | the whirlwind and the fairy are no monsters of the screen
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    cmp.w #BEH_FAIRY, %d0
    bne 9f
    move.b #FAIRY_X, OFF_ENEMY_X(%a5, %d5.w)    | InitPondFairy
    move.b #FAIRY_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_FAIRY_ON(%a5)
    sfx SFX_ITEM_TAKEN
9:  movem.l (%sp)+, %d0/%a0
    rts

| d5 = the armos or the flying ghini, called from mover_update (a tail jump: d4 = the frames a pixel step takes, d7 = the
| behaviour, both the caller's own). Returns d0.w = 1: it moves itself, 0: the walker code in update_enemies moves it.
| Both rise for $3F frames (InitArmosOrFlyingGhini). A flying ghini then gets speed $1F (EndInitFlyer) and the flying state
| machine (ControlFlyingGhiniFlight: decide rolls $A0 and $08, top speed $A0, MoveFlyer). An armos is no flyer: UpdateArmos
| is UpdateGoriya, so it walks like a goriya (but never throws), at a q-speed InitArmosOrFlyingGhini picks at random when it
| has risen: $20 (a pixel every other frame, the table's period) or $60 (a pixel and a half a frame). The walker code
| already steps a charging rope that fast, so a fast armos borrows it: it is called a rope (d7) that is charging
| (ENEMY_STATE, which goriya_ai reads as "its boomerang is out" and so needs clear while it runs).
owspec_armos_ai:
    movem.l %d1-%d3/%a0, -(%sp)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    move.b 0(%a0, %d5.w), %d1
    beq 5f
    subq.b #1, %d1
    move.b %d1, 0(%a0, %d5.w)
    bne 8f
    cmpi.b #MON_FGHINI, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 3f
    lea OFF_ENEMY_GHOST(%a5), %a0       | a flying ghini leaves no hole behind: weapons hurt it now
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0       | EndInitFlyer
    move.b #0x1f, 0(%a0, %d5.w)
    bra 4f
3:  bsr armos_wake
    moveq #0x20, %d1                    | q-speed $20 if Random < $80, $60 otherwise
    bsr rand8
    cmp.b #0x80, %d0
    blo 2f
    moveq #0x60, %d1
2:  lea OFF_ENEMY_SPEED(%a5), %a0
    move.b %d1, 0(%a0, %d5.w)
4:  lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
8:  moveq #1, %d0
    bra 9f
5:  cmpi.b #MON_FGHINI, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq 6f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    bsr goriya_ai_far                   | the armos turns toward Link like a goriya
    lea OFF_ENEMY_SPEED(%a5), %a0
    cmpi.b #0x60, 0(%a0, %d5.w)
    bne 7f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    moveq #1, %d4                       | a step every frame, and one more every other frame
    moveq #BEH_ROPE, %d7
7:  moveq #0, %d0
    bra 9f
6:  move.w #0xa0, %d1                   | Flyer_GhiniDecideState: chase at >= $A0, wander at >= $08, else slow down
    move.w #0x08, %d2
    move.w #0xa0, %d3
    bsr flyer_control
    bsr flyer_move
    moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d3/%a0
    rts

| The armos has risen (InitArmosOrFlyingGhini): the square it stood on turns to floor, or to stairs when it covered
| the secret of one of the seven screens, or to floor and the power bracelet in $24. d5 = the armos.
armos_wake:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    clr.b 0(%a0, %d5.w)                 | weapons hurt it now
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    lsr.w #4, %d1                       | its column
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    sub.w #(NES_PLAY_AREA_TOP - 3), %d2
    bmi 90f
    lsr.w #4, %d2                       | and row
    cmp.w #10, %d2
    bhi 90f
    cmp.w #15, %d1
    bhi 90f
    move.w %d2, %d6
    lsl.w #4, %d6
    add.w %d1, %d6                      | d6 = the square
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    mulu.w #ROOM_BYTES, %d0
    add.l %d6, %d0
    ltab room_maps, %a0
    adda.l %d0, %a0
    moveq #0, %d4
    move.b (%a0), %d4                   | the metatile there
    ltab room_secrets, %a0
    adda.w #(SECRET_RECORDS + 2), %a0   | (metatile, floor, stairs) for each armos metatile, 0xff at the end
2:  move.b (%a0), %d3
    cmp.b #0xff, %d3
    beq 90f                             | not an armos any more
    cmp.b %d4, %d3
    beq 3f
    addq.l #3, %a0
    bra 2b
3:  move.b 1(%a0), %d4                  | d4 = the floor
    move.b 2(%a0), %d3                  | d3 = the stairs
    moveq #6, %d7
4:  lea armos_rooms(%pc), %a1
    move.b 0(%a1, %d7.w), %d0
    cmp.b OFF_ROOM_ID(%a5), %d0
    bne 5f
    lea armos_xs(%pc), %a1
    move.b 0(%a1, %d7.w), %d0
    lsr.b #4, %d0
    cmp.b %d1, %d0
    bne 5f
    cmp.w #4, %d2
    beq 6f                              | the secret's own armos
5:  dbra %d7, 4b                        | (d7 = -1 when none matched)
6:  tst.w %d7
    bmi 7f
    beq 61f
    moveq #0, %d0                       | stairs, for good
    move.b OFF_ROOM_ID(%a5), %d0
    move.w %d6, %d1
    move.b %d3, %d2
    bsr ow_set_square
    sfx SFX_SECRET
    bra 8f
61: moveq #0, %d0                       | the power bracelet, if it is still there to take
    move.b OFF_ROOM_ID(%a5), %d0
    lea OFF_OW_KILLS(%a5), %a0
    btst #OW_ITEM_TAKEN, 0(%a0, %d0.w)
    bne 7f
    move.b #BRACELET_ITEM, OFF_ITEM_ID(%a5)
    move.b OFF_ENEMY_X(%a5, %d5.w), OFF_ITEM_X(%a5)
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    addq.b #3, %d0
    move.b %d0, OFF_ITEM_Y(%a5)
    move.b #2, OFF_ITEM_ACTIVE(%a5)
    sfx SFX_SECRET
7:  moveq #0, %d0                       | bare floor until he leaves the screen
    move.b OFF_ROOM_ID(%a5), %d0
    move.w %d6, %d1
    move.b %d4, %d2
    bsr ow_set_square_for_now
8:  bsr ow_secret_redraw
90: movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| draw_enemies: d3 = the monster, d2.w = its mode (35 up). Returns d1.w = the image (-1: none), d5.w = mirrored.
| An armos has four: front and back in each of two steps that alternate every six frames; it flickers while it rises.
owspec_frame:
    movem.l %d0/%d2/%a0, -(%sp)
    moveq #0, %d1
    moveq #0, %d5
    cmp.w #MODE_FAIRY, %d2
    beq 5f
    lea OFF_ENEMY_ANIMC(%a5), %a0
    tst.b 0(%a0, %d3.w)
    beq 1f
    btst #0, (OFF_FRAME_COUNTER + 1)(%a5)
    beq 1f
    moveq #-1, %d1
    bra 9f
1:  moveq #0, %d0
    move.w OFF_FRAME_COUNTER(%a5), %d0
    add.w %d3, %d0
    divu.w #6, %d0
    and.w #1, %d0
    add.w %d0, %d0
    move.w %d0, %d1
    btst #3, OFF_ENEMY_DIR(%a5, %d3.w)
    beq 9f
    addq.w #1, %d1                      | facing up: the back
    bra 9f
5:  move.w OFF_FRAME_COUNTER(%a5), %d1  | the fairy's wings: up and down every four frames
    lsr.w #2, %d1
    and.w #1, %d1
9:  movem.l (%sp)+, %d0/%d2/%a0
    rts


| ------------------------------------------------------------------------------------------------------ the fairy
| UpdatePondFairy. The fairy hovers at ($78, $7D). State 0 waits for Link to come to the pond's edge (Y = $AD,
| X from $70 to $80); then he stands still while his hearts fill (1), the hearts go round the fairy a while
| longer (2: $50 frames) and he is free (3). Eight hearts orbit her at 28 pixels, each started when the first one
| has gone another eighth of the way round; the angle is in 1/32 turns with a fraction, less $60/256 a frame.
|
| d5 = the fairy, called from mover_update. Returns d0.w = 1: she moves herself (not at all).
owspec_fairy_ai:
    movem.l %d1-%d2/%a0, -(%sp)
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d1
    bne 5f
    cmpi.b #0xad, OFF_LINK_Y(%a5)
    bne 9f
    move.b OFF_LINK_X(%a5), %d2
    cmp.b #0x70, %d2
    blo 9f
    cmp.b #0x81, %d2
    bhs 9f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #1, OFF_HEART_FILL(%a5)              | World_IsFillingHearts: as with a potion
    move.b #HEART_FILL_FRAMES, OFF_HEART_FILL_T(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_FAIRY_ON(%a5)
    bra 9f
5:  cmp.b #3, %d1
    beq 9f
    cmp.b #1, %d1
    bne 6f
    tst.b OFF_HEART_FILL(%a5)
    bne 7f
    move.b #2, OFF_ENEMY_STATE(%a5, %d5.w)      | full: a little longer
    lea OFF_ENEMY_ANIMC(%a5), %a0
    move.b #0x50, 0(%a0, %d5.w)
    move.b #1, OFF_LINK_HELD(%a5)
    bra 7f
6:  lea OFF_ENEMY_ANIMC(%a5), %a0
    subq.b #1, 0(%a0, %d5.w)
    bne 7f
    move.b #3, OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_LINK_HELD(%a5)
    bra 9f
7:  bsr fairy_hearts
9:  moveq #1, %d0
    movem.l (%sp)+, %d1-%d2/%a0
    rts

heart_starts:
    .byte 0x14, 0x10, 0x0c, 0x08, 0x04, 0x00, 0x1c     | PondHeartStartAngles
heart_ring:                                              | (dx, dy) of an angle at 28 pixels; 0 is east, 8 south
    .byte 0x1c,0x00, 0x1b,0x05, 0x1a,0x0b, 0x17,0x10, 0x14,0x14, 0x10,0x17, 0x0b,0x1a, 0x05,0x1b
    .byte 0x00,0x1c, 0xfb,0x1b, 0xf5,0x1a, 0xf0,0x17, 0xec,0x14, 0xe9,0x10, 0xe6,0x0b, 0xe5,0x05
    .byte 0xe4,0x00, 0xe5,0xfb, 0xe6,0xf5, 0xe9,0xf0, 0xec,0xec, 0xf0,0xe9, 0xf5,0xe6, 0xfb,0xe5
    .byte 0x00,0xe4, 0x05,0xe5, 0x0b,0xe6, 0x10,0xe9, 0x14,0xec, 0x17,0xf0, 0x1a,0xf5, 0x1b,0xfb
    .even

| PondFairy_MoveHearts: each heart that is out turns on, one that is due comes out above the fairy, and all are
| put in the boss sprite pool as the item's picture.
fairy_hearts:
    movem.l %d0-%d5/%a0-%a2, -(%sp)
    ltab item_index, %a0
    moveq #0, %d5
    move.b ITEM_HEART(%a0), %d5
    add.w #BP_ITEM, %d5                         | the heart's picture in the pool
    lea OFF_FAIRY_ANG(%a5), %a0
    moveq #0, %d4                               | the heart
1:  move.w %d4, %d3
    add.w %d3, %d3                              | its angle is at 0(%a0, %d3.w)
    btst %d4, OFF_FAIRY_ON(%a5)
    bne 5f
    tst.w %d4
    beq 4f                                      | the first comes out at once
    btst #0, OFF_FAIRY_ON(%a5)
    beq 8f
    lea heart_starts(%pc), %a1
    move.b -1(%a1, %d4.w), %d0
    cmp.b 0(%a0), %d0                           | has the first one reached this one's angle?
    bne 8f
4:  bset %d4, OFF_FAIRY_ON(%a5)
    move.w #0x1800, 0(%a0, %d3.w)               | north
    bra 6f
5:  sub.w #0x60, 0(%a0, %d3.w)
    and.w #0x1fff, 0(%a0, %d3.w)
6:  move.w 0(%a0, %d3.w), %d0
    lsr.w #8, %d0
    and.w #31, %d0
    add.w %d0, %d0
    lea heart_ring(%pc), %a1
    move.b 0(%a1, %d0.w), %d1
    ext.w %d1
    add.w #FAIRY_X, %d1
    move.b 1(%a1, %d0.w), %d2
    ext.w %d2
    add.w #FAIRY_Y, %d2
    move.w %d5, %d0
    bsr bp_add
8:  addq.w #1, %d4
    cmp.w #8, %d4
    blo 1b
    movem.l (%sp)+, %d0-%d5/%a0-%a2
    rts

| ---------------------------------------------------------------------------------------------------- recorder
| WieldFlute, for the overworld: in the pond's screen the water starts to change; anywhere else the whirlwind
| comes, if Link owns a piece of the triforce.
owspec_recorder:
    movem.l %d0-%d1, -(%sp)
    cmpi.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bne 9f
    bsr flute_stairs
    cmp.w #0x00ff, %d0
    beq 1f
    tst.b OFF_POND_CYCLE(%a5)
    bne 9f
    move.b #1, OFF_POND_CYCLE(%a5)              | InitFluteSecret
    bra 9f
1:  bsr owspec_summon
9:  movem.l (%sp)+, %d0-%d1
    rts

| d0.w = the metatile of the stairs the recorder reveals in this screen, $FF where it summons the whirlwind (WieldFlute:
| FluteRoomSecretsOW, and which of its rooms depends on the quest; the table is room_secrets', patched by quest_apply).
flute_stairs:
    movem.l %d1/%a0, -(%sp)
    ltab room_secrets, %a0
    adda.w #FLUTE_TABLE, %a0
    moveq #0, %d1
    move.b OFF_ROOM_ID(%a5), %d1
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    movem.l (%sp)+, %d1/%a0
    rts

| SummonWhirlwind. TeleportingLevelIndex steps the way Link faces (right or up forward, left or down back); the
| first level from there whose piece he has is the destination, and the whirlwind starts at the left edge on his row.
owspec_summon:
    movem.l %d0-%d6/%a0, -(%sp)
    bsr tele_advance
    moveq #0, %d0
    move.b OFF_TELE_INDEX(%a5), %d0
    and.w #7, %d0
    moveq #1, %d6
    lsl.b %d0, %d6                              | LevelMasks
1:  move.b OFF_TRIFORCE_PIECES(%a5), %d0
    beq 9f                                      | no pieces: nothing comes
    and.b %d6, %d0
    bne 5f
    bsr tele_advance                            | not his: the next one
    move.b OFF_LINK_DIR(%a5), %d0
    and.b #9, %d0
    beq 3f
    rol.b #1, %d6
    bra 1b
3:  ror.b #1, %d6
    bra 1b
5:  tst.b OFF_WHIRL_SUMMONED(%a5)
    bne 9f
    tst.b OFF_WHIRL_TELE(%a5)
    bne 9f
    moveq #MON_WHIRLWIND, %d1
    moveq #0, %d2
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    moveq #DIR_RIGHT, %d4
    bsr enemy_make
    tst.w %d0
    bmi 9f
    move.b #1, OFF_WHIRL_SUMMONED(%a5)
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

tele_advance:
    addq.b #1, OFF_TELE_INDEX(%a5)
    move.b OFF_LINK_DIR(%a5), %d0
    and.b #9, %d0
    bne 9f
    subq.b #2, OFF_TELE_INDEX(%a5)
9:  rts

whirl_prev:
    .byte 0x36, 0x3b, 0x73, 0x44, 0x0a, 0x21, 0x41, 0x6c    | WhirlwindPrevRoomIdList: the screen west of each entrance
tele_ys:
    .byte 0x8d, 0xad, 0x8d, 0x8d, 0xad, 0x8d, 0xad, 0x5d    | TeleportYs
    .even

| d5 = the whirlwind, called from mover_update. It moves two pixels a frame from the left edge. If Link is beside it
| (and it has not got him) it picks him up and takes him along; at the right edge it is gone and the next screen is
| the entrance. At the other end it sets him down in the middle ($80). Returns d0.w = 1 (it moves itself).
owspec_whirl_ai:
    movem.l %d1-%d3, -(%sp)
    addq.b #2, OFF_ENEMY_X(%a5, %d5.w)
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    move.b OFF_WHIRL_TELE(%a5), %d0
    beq 5f
    cmp.b #1, %d0
    beq 2f
    cmp.b #2, %d0
    bne 9f
    move.b %d1, OFF_LINK_X(%a5)                 | being set down: he goes with it as far as the middle
    cmp.b #0x80, %d1
    bne 9f
    clr.b OFF_WHIRL_TELE(%a5)
    clr.b OFF_LINK_HELD(%a5)
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    bra 9f
2:  move.b %d1, OFF_LINK_X(%a5)                 | carried
    bra 6f
5:  moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    sub.w %d1, %d2
    bpl 51f
    neg.w %d2
51: cmp.w #13, %d2
    bhs 6f
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d3, %d2
    bpl 52f
    neg.w %d2
52: cmp.w #13, %d2
    bhs 6f
    move.b #DIR_RIGHT, OFF_LINK_DIR(%a5)        | it has him
    move.b #1, OFF_WHIRL_TELE(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    clr.b OFF_COMMIT(%a5)
6:  cmp.w #0xf0, %d1
    blo 9f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)          | it has crossed the screen
    cmpi.b #1, OFF_WHIRL_TELE(%a5)
    bne 9f
    move.b #4, OFF_WHIRL_TELE(%a5)              | whirl_update takes the next step
9:  moveq #1, %d0
    movem.l (%sp)+, %d1-%d3
    rts

| Every frame on the overworld: the whirlwind that has reached the edge starts the scroll into the entrance's
| screen; once that has arrived it brings the next whirlwind that sets Link down.
whirl_update:
    movem.l %d0-%d4/%a0, -(%sp)
    move.b OFF_WHIRL_TELE(%a5), %d0
    cmp.b #4, %d0
    bne 1f
    move.b #3, OFF_WHIRL_TELE(%a5)
    moveq #0, %d1
    move.b OFF_TELE_INDEX(%a5), %d1
    and.w #7, %d1
    lea whirl_prev(%pc), %a0
    move.b 0(%a0, %d1.w), OFF_ROOM_ID(%a5)      | as if he came from the screen to the west of the entrance
    moveq #DIR_RIGHT, %d1
    bsr start_scroll
    bra 9f
1:  cmp.b #3, %d0
    bne 9f
    cmpi.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bne 9f
    move.b #2, OFF_WHIRL_TELE(%a5)
    moveq #0, %d1
    move.b OFF_TELE_INDEX(%a5), %d1
    and.w #7, %d1
    lea tele_ys(%pc), %a0
    moveq #0, %d3
    move.b 0(%a0, %d1.w), %d3
    clr.b OFF_LINK_X(%a5)
    move.b %d3, OFF_LINK_Y(%a5)
    move.b #DIR_RIGHT, OFF_LINK_DIR(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    moveq #MON_WHIRLWIND, %d1
    moveq #0, %d2
    moveq #DIR_RIGHT, %d4
    bsr enemy_make
9:  movem.l (%sp)+, %d0-%d4/%a0
    rts

| ----------------------------------------------------------------------------------------------------- the pond
| UpdateFluteSecret. After the tune the water of screen $42 changes colour every eighth frame (PondCycleColors);
| at the tenth step the water can be walked on, at the eleventh the stairs show.
pond_update:
    movem.l %d0-%d2/%a0, -(%sp)
    bsr flute_stairs
    cmp.w #0x00ff, %d0
    beq 9f
    move.b OFF_POND_CYCLE(%a5), %d0
    beq 9f
    cmp.b #0x0c, %d0
    bhs 9f
    tst.b OFF_FLUTE_TIMER(%a5)
    bne 9f
    move.w OFF_FRAME_COUNTER(%a5), %d1
    and.w #7, %d1
    cmp.w #4, %d1
    bne 9f
    addq.b #1, OFF_POND_CYCLE(%a5)
    cmp.b #0x0b, %d0
    beq 5f
    and.w #0xff, %d0
    ltab pond_colors, %a0
    move.w %d0, %d1
    add.w %d1, %d1
    move.w 0(%a0, %d1.w), %d2
    movea.l #(PALETTE_BASE + 2 * POND_IDX), %a0
    move.w %d2, (%a0)
    cmp.w #0x0a, %d0
    bne 9f
    move.b #1, OFF_POND_WALK(%a5)
    bra 9f
5:  bsr flute_stairs                            | RevealPondStairs: ($60, $90)
    move.l %d0, %d2                             | the metatile of the stairs in this screen's palette
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lea OFF_OW_KILLS(%a5), %a0
    bset #SECRET_FOUND, 0(%a0, %d0.w)
    ltab room_secrets, %a0
    adda.w #SECRET_RECORDS, %a0
    moveq #0, %d1
    move.b 1(%a0), %d1
    bsr ow_set_square
    bsr ow_secret_redraw
    sfx SFX_SECRET
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| A new screen: the pond's water is what it was.
pond_leave:
    movem.l %d0/%a0-%a1, -(%sp)
    tst.b OFF_POND_CYCLE(%a5)
    beq 9f
    ltab room_palette, %a0
    move.w (2 * POND_IDX)(%a0), %d0
    movea.l #(PALETTE_BASE + 2 * POND_IDX), %a1
    move.w %d0, (%a1)
9:  clr.b OFF_POND_CYCLE(%a5)
    clr.b OFF_POND_WALK(%a5)
    movem.l (%sp)+, %d0/%a0-%a1
    rts
