| Link's choice of way from the keys held, and turning in the middle of a step (Z_05 Link_ModifyDir*).
| Kept out at the end, beyond the code that the far stubs reach.

| The way the keys held take Link this frame, d0.b (0: he does not move): Link_ModifyDirAtGridPoint and the
| input filter of Walker_Move. Part-way through a step one key counts, the lowest bit (right, left, down, up),
| and a key across the step is ignored after two keys were held at the grid point. On a grid point one key is
| the way; of two, those he can walk are counted in the order right, left, down, up and the last one wins
| (on the overworld up or down beats a sideways key), none open stops him; in a dungeon with both open he turns
| across the way he faces once, then goes straight on while both are held, except in the columns of the side
| doors and at the top door.
link_choose_dir:
    movem.l %d1-%d5, -(%sp)
    moveq #0, %d0
    move.b OFF_HELD_DIRS(%a5), %d2
    beq 9f
    tst.b OFF_LINK_DOORWAY(%a5)
    beq 0f
    tst.b OFF_COMMIT(%a5)
    bne 73f
    clr.b OFF_LINK_GO_STRAIGHT(%a5) | a grid point with one way in: as one key (Link_ModifyDirAtGridPoint)
    clr.b OFF_LINK_DIAG_STRAIGHT(%a5)
73: move.b OFF_LINK_DIR(%a5), %d0   | in a doorway only along it (Link_ModifyDirInDoorway): the way he faces if
    move.b %d0, %d1                 | held, else its opposite if held
    and.b %d2, %d1
    bne 9f
    move.b %d0, %d1
    and.b #DIR_VERTICAL, %d1
    beq 71f
    eor.b #DIR_VERTICAL, %d0
    bra 72f
71: eor.b #(DIR_RIGHT + DIR_LEFT), %d0
72: move.b %d0, %d1
    and.b %d2, %d1
    bne 9f
    move.b OFF_LINK_DIR(%a5), %d0   | only a key across: on the way he faces, into the room; facing out he
    cmp.b OFF_LINK_DOORWAY(%a5), %d0    | stays (measured: the ROM nudges him a pixel or three, then stops)
    bne 9f
    moveq #0, %d0
    bra 9f
0:  tst.b OFF_COMMIT(%a5)
    beq 2f
    move.b %d2, %d0             | part-way: the lowest key
    move.b %d0, %d1
    neg.b %d1
    and.b %d1, %d0
    tst.b OFF_LINK_GO_STRAIGHT(%a5)
    beq 9f
    move.b OFF_LINK_DIR(%a5), %d1
    move.b %d0, %d3
    eor.b %d1, %d3
    and.b #DIR_VERTICAL, %d3
    beq 9f                      | same axis
    move.b %d0, %d3
    and.b #DIR_VERTICAL, %d3
    beq 1f
    move.b %d1, %d3             | key up or down: across only if he goes sideways
    and.b #DIR_VERTICAL, %d3
    bne 9f
    move.b %d1, %d0
    bra 9f
1:  move.b %d1, %d3             | key sideways: across only if he goes up or down
    and.b #DIR_VERTICAL, %d3
    beq 9f
    move.b %d1, %d0
    bra 9f

2:  clr.b OFF_LINK_GO_STRAIGHT(%a5)
    move.b %d2, %d0
    move.b %d0, %d1
    neg.b %d1
    and.b %d1, %d0
    cmp.b %d0, %d2
    bne 3f
    clr.b OFF_LINK_DIAG_STRAIGHT(%a5)  | one key
    bra 9f
3:  moveq #0, %d3               | d3 = last open way, d4 = how many
    moveq #0, %d4
    moveq #1, %d5
31: move.b %d2, %d0
    and.b %d5, %d0
    beq 32f
    move.b %d5, %d1
    st OFF_COLLIDE_PURE(%a5)
    bsr link_collide_back
    clr.b OFF_COLLIDE_PURE(%a5)
    tst.w %d0
    bne 32f
    move.b %d5, %d3
    addq.b #1, %d4
32: add.b %d5, %d5
    cmp.b #0x10, %d5
    blo 31b
    moveq #0, %d0
    tst.b %d4
    beq 9f                      | neither way open
    st OFF_LINK_GO_STRAIGHT(%a5)
    move.b %d3, %d0
    cmp.b #1, %d4
    beq 33f
    tst.b OFF_LEVEL(%a5)
    bne 4f
33: clr.b OFF_LINK_DIAG_STRAIGHT(%a5)
    bra 9f
4:  move.b OFF_LINK_DIR(%a5), %d1   | dungeon, both open
    move.b OFF_LINK_X(%a5), %d3
    cmp.b #0x20, %d3
    beq 41f
    cmp.b #0xd0, %d3
    bne 42f
41: cmp.b #0x85, OFF_LINK_Y(%a5)    | in the column of a side door: straight on if level with it facing down,
    bne 5f                          | otherwise he turns across whatever he did before
    btst #2, %d1
    beq 5f
    move.b %d1, %d0
    bra 33b
42: tst.b OFF_LINK_DIAG_STRAIGHT(%a5)
    beq 5f
    move.b %d1, %d0             | turned once already: straight on, but at the top door
    cmp.b #0x78, OFF_LINK_X(%a5)
    bne 9f
    cmp.b #0x5d, OFF_LINK_Y(%a5)
    bne 9f
    move.b %d1, %d3
    and.b #(DIR_RIGHT + DIR_LEFT), %d3
    beq 9f
5:  move.b %d1, %d3             | across the way he faces
    and.b #DIR_VERTICAL, %d3
    beq 51f
    moveq #DIR_VERTICAL, %d3
    bra 52f
51: moveq #(DIR_RIGHT + DIR_LEFT), %d3
52: move.b %d2, %d0
    not.b %d3
    and.b %d3, %d0
    st OFF_LINK_DIAG_STRAIGHT(%a5)
9:  movem.l (%sp)+, %d1-%d5
    rts

| Link_ModifyDirOnGridLine, part-way through a step (COMMIT pixels to the line ahead) with key d4.b held:
| the opposite key turns him straight round, to walk back to the line he set out from; a key across the step,
| before he is half-way, sends him back to that line too (ReverseDir), where he stops for the frame like at the
| end of any step. Past half-way, or already walking back, he finishes the step first.
link_turn_in_step:
    movem.l %d0-%d1, -(%sp)
    tst.b OFF_COMMIT(%a5)
    beq 9f
    move.b OFF_LINK_DIR(%a5), %d0
    cmp.b %d4, %d0
    beq 9f
    move.b %d0, %d1
    or.b %d4, %d1
    cmp.b #(DIR_RIGHT + DIR_LEFT), %d1
    beq 1f
    cmp.b #(DIR_UP + DIR_DOWN), %d1
    beq 1f
    tst.b OFF_LINK_BACK(%a5)    | across the step
    bne 9f
    cmp.b #4, OFF_COMMIT(%a5)
    bls 9f                      | half-way or more
    move.b %d0, %d1             | the opposite way: swap the axis' two bits
    and.b #DIR_VERTICAL, %d1
    beq 2f
    eor.b #DIR_VERTICAL, %d0
    bra 3f
2:  eor.b #(DIR_RIGHT + DIR_LEFT), %d0
3:  move.b %d0, OFF_LINK_DIR(%a5)
    bra 4f
1:  move.b %d4, OFF_LINK_DIR(%a5)   | straight round
    eori.b #1, OFF_LINK_BACK(%a5)
4:  moveq #8, %d0
    sub.b OFF_COMMIT(%a5), %d0
    move.b %d0, OFF_COMMIT(%a5)
9:  movem.l (%sp)+, %d0-%d1
    rts

    farstub link_collide_back, link_collide

| Doorways (CheckDoorway, Walker_Move's screen edges): Link walks through the frame of a dungeon door before the
| room scrolls, and after a scroll he walks in from the screen's edge through the frame of the door he came by.
| LINK_DOORWAY holds the direction out through the doorway he stands in (0 on the floor). In it he moves only
| along the door (link_choose_dir), no tile is looked at (link_pixel), and the screen's edge ($00, $F0, $3D, $DD)
| is the limit instead of the floor's; a false wall or a bombed hole still takes him straight on (uw_try_door 2).

| link_step_pixel found the next pixel past the floor's edge: d1.b = direction, d3.w = where it would be,
| d4.w = the edge. Overworld and cellars: he stops there and the screen changes (start_scroll), as before.
link_edge:
    movem.l %d0/%d2, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 80f
    tst.b OFF_IN_CELLAR(%a5)
    bne 80f
    move.b OFF_LINK_DOORWAY(%a5), %d0
    and.b %d1, %d0
    beq 50f
    | in the doorway, going out: on to the screen's edge
    btst #0, %d1
    beq 11f
    move.w #LINK_EDGE_RIGHT, %d2
    cmp.w %d2, %d3
    bgt 40f
    bra 30f
11: btst #1, %d1
    beq 12f
    moveq #LINK_EDGE_LEFT, %d2
    cmp.w %d2, %d3
    blt 40f
    bra 30f
12: btst #2, %d1
    beq 13f
    move.w #LINK_EDGE_DOWN, %d2
    cmp.w %d2, %d3
    bgt 40f
    bra 30f
13: moveq #LINK_EDGE_UP, %d2
    cmp.w %d2, %d3
    blt 40f
30: move.w %d3, %d2
    bsr link_put
    bra 90f
40: bsr link_put                    | at the edge: the next room (CheckScreenEdge)
    bsr start_scroll_back
    bra 90f
50: move.w %d4, %d2                 | at the floor's edge: he stays there unless a door lets him on
    bsr link_put
    bsr uw_try_door_back
    tst.w %d0
    beq 90f
    cmp.w #2, %d0
    beq 60f
    move.b %d1, OFF_LINK_DOORWAY(%a5)
    move.w %d3, %d2                 | into the doorway
    bsr link_put
    bra 90f
60: bsr start_scroll_back
    bra 90f
80: move.w %d4, %d2
    bsr link_put
    bsr start_scroll_back
90: movem.l (%sp)+, %d0/%d2
    rts

| Link's X (d1.b sideways) or Y (up or down) = d2.b.
link_put:
    move.b %d1, %d0
    and.b #DIR_VERTICAL, %d0
    bne 1f
    move.b %d2, OFF_LINK_X(%a5)
    rts
1:  move.b %d2, OFF_LINK_Y(%a5)
    rts

| CheckDoorway, once a frame after the keys were read (d0.b = the way they take him, 0 none): is he still in the
| doorway? Along the door he is while inside its short bounds, or inside its long ones facing out through it
| (DoorwayBoundsMin/MaxUnder and Over); else he is back on the floor.
link_doorway_left:
    movem.l %d0-%d3/%a0, -(%sp)
    move.b OFF_LINK_DOORWAY(%a5), %d1
    beq 9f
    tst.b %d0
    bne 1f
    move.b OFF_LINK_DIR(%a5), %d0   | the way he faces
1:  lea doorway_bounds(%pc), %a0    | up, down, left, right: under min, under max, over min, over max
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    btst #3, %d1
    bne 2f
    addq.l #4, %a0
    btst #2, %d1
    bne 2f
    addq.l #4, %a0
    move.b OFF_LINK_X(%a5), %d2
    btst #1, %d1
    bne 2f
    addq.l #4, %a0
2:  moveq #0, %d3
    move.b (%a0), %d3
    cmp.w %d3, %d2
    blo 3f
    move.b 1(%a0), %d3
    cmp.w %d3, %d2
    blo 9f                          | inside the short bounds: still in it
3:  cmp.b %d1, %d0
    bne 4f                          | not facing out: back on the floor
    move.b 2(%a0), %d3
    cmp.w %d3, %d2
    blo 4f
    move.b 3(%a0), %d3
    cmp.w %d3, %d2
    blo 9f
4:  clr.b OFF_LINK_DOORWAY(%a5)
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

doorway_bounds:
    .byte 0x3d, 0x5c, 0x3d, 0x5e            | up
    .byte 0xbf, 0xde, 0xbd, 0xde            | down
    .byte 0x00, 0x1f, 0x00, 0x21            | left
    .byte 0xd2, 0xf1, 0xcf, 0xf1            | right
    .align 2

| start_scroll in a dungeon, d1.b = direction: the scroll brings him to the screen's edge of the next room,
| the side he comes in by (the walk in follows: scroll_walk).
scroll_to_edge:
    btst #0, %d1
    beq 1f
    move.b #LINK_EDGE_LEFT, OFF_SCROLL_TO_X(%a5)
    rts
1:  btst #1, %d1
    beq 2f
    move.b #LINK_EDGE_RIGHT, OFF_SCROLL_TO_X(%a5)
    rts
2:  btst #2, %d1
    beq 3f
    move.b #LINK_EDGE_UP, OFF_SCROLL_TO_Y(%a5)
    rts
3:  move.b #LINK_EDGE_DOWN, OFF_SCROLL_TO_Y(%a5)
    rts

| The scroll has run its course. d0.w = 1 while he is still to walk in, 0 when the scroll may finish. In a
| dungeon he walks 16 pixels in from the screen's edge first (mode 4: grid offset $18 counted down to the
| limit 8), at his walking speed; LINK_AUTOWALK is $80 + the pixels left, $80 when he has done.
scroll_walk_due:
    moveq #0, %d0
    tst.b OFF_LEVEL(%a5)
    beq 9f
    move.b OFF_LINK_AUTOWALK(%a5), %d0
    bne 1f
    move.b #(0x80 + 16), OFF_LINK_AUTOWALK(%a5)
    moveq #1, %d0
    rts
1:  cmp.b #0x80, %d0
    seq %d0
    addq.b #1, %d0                  | $80: 0 (done), else 1
    and.w #1, %d0
9:  rts

| One frame of the walk in: MoveObject's four quarters of $60 on the fraction, a pixel each carry or borrow,
| in the scroll's direction, until the 16 pixels are walked.
scroll_walk:
    movem.l %d0-%d3, -(%sp)
    move.b OFF_SCROLL_DIR(%a5), %d1
    moveq #3, %d3
1:  move.b OFF_LINK_POS_FRAC(%a5), %d2
    move.b %d1, %d0
    and.b #(DIR_RIGHT + DIR_DOWN), %d0
    beq 2f
    add.b #LINK_QSPEED, %d2
    bra 3f
2:  sub.b #LINK_QSPEED, %d2
3:  scs %d0
    move.b %d2, OFF_LINK_POS_FRAC(%a5)
    tst.b %d0
    beq 8f
    move.b OFF_LINK_AUTOWALK(%a5), %d0
    cmp.b #0x80, %d0
    beq 8f                          | the limit: the fraction turns, he does not move
    subq.b #1, OFF_LINK_AUTOWALK(%a5)
    btst #0, %d1
    beq 4f
    addq.b #1, OFF_LINK_X(%a5)
    bra 8f
4:  btst #1, %d1
    beq 5f
    subq.b #1, OFF_LINK_X(%a5)
    bra 8f
5:  btst #2, %d1
    beq 6f
    addq.b #1, OFF_LINK_Y(%a5)
    bra 8f
6:  subq.b #1, OFF_LINK_Y(%a5)
8:  dbra %d3, 1b
    move.b OFF_LINK_X(%a5), OFF_SCROLL_TO_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_SCROLL_TO_Y(%a5)
    movem.l (%sp)+, %d0-%d3
    rts

| finish_scroll: in a dungeon he now stands in the doorway he came in by (its way out is back the way he came).
link_doorway_entered:
    movem.l %d0, -(%sp)
    clr.b OFF_LINK_DOORWAY(%a5)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    move.b OFF_SCROLL_DIR(%a5), %d0
    move.b %d0, OFF_LINK_DIR(%a5)
    and.b #DIR_VERTICAL, %d0
    beq 1f
    move.b OFF_SCROLL_DIR(%a5), %d0
    eor.b #DIR_VERTICAL, %d0
    bra 2f
1:  move.b OFF_SCROLL_DIR(%a5), %d0
    eor.b #(DIR_RIGHT + DIR_LEFT), %d0
2:  move.b %d0, OFF_LINK_DOORWAY(%a5)
    bsr link_doorway_left           | (a scroll that ended on the floor: not in one)
9:  clr.b OFF_COMMIT(%a5)
    clr.b OFF_LINK_BACK(%a5)
    movem.l (%sp)+, %d0
    rts

    farstub start_scroll_back, start_scroll
    farstub uw_try_door_back, uw_try_door
