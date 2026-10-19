| The overworld's hidden spots: a bomb that opens a rock wall, fire that burns a tree, and a rock or gravestone that
| Link pushes aside (TileObjectTypes $62-$67; UpdateRockWall, UpdateTree and UpdateRockOrGravestone in the ROM).
|
| tools/build_assets.py draws every such spot as the plain square it looks like and lists it in room_secrets, one
| record of eight bytes per screen:
|   0 type    1 the spot's square (row * 16 + column)    2 what it turns into (a cave entrance, stairs, or the
|   bare floor under a rock)    3, 4 the stairs a pushed rock uncovers: their square and metatile    5, 6 the
|   rock's metatile one square above / below the spot (0xff: that would be outside the screen)
|
| Finding a secret changes room_maps, which lives in RAM like the rest of the program: the screens are drawn
| from it, and fetch_tile finds the collision tiles in it. A cave or a stair then works through check_warps like
| any other. The room flags of OW_KILLS remember what was found (bit 7: secret found, bit 5: a rock was pushed).
|
| A rock or gravestone moves for as long as Link stays on the screen. The ROM lays the screen out again every time
| he comes in, so it is back where it was, and render_room puts it there: ow_secret_undo takes the squares of
| the push back. The stairs under a rock stay for good (CheckShortcut), those under a gravestone do not.

    .equ SECRET_NONE, 0
    .equ SECRET_BOMB, 1
    .equ SECRET_TREE, 2
    .equ SECRET_ROCK, 3
    .equ SECRET_GRAVE, 4
    .equ SECRET_BYTES, 8
    .equ SECRET_FOUND, 7                | OW_KILLS bit: the secret of the screen was found
    .equ SECRET_PUSHED, 5               | OW_KILLS bit: its rock was pushed
    .equ SECRET_REACH, 16               | how close the bomb or the flame has to be (DoObjectsCollide $10)
    .equ SECRET_ROW_Y, 0x40             | the screen's top row of squares starts here

| Returns a0 = the record of the current screen, d0.w = its type.
ow_secret_record:
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lsl.w #3, %d0
    ltab room_secrets, %a0
    adda.w %d0, %a0
    moveq #0, %d0
    move.b (%a0), %d0
    rts

| Puts metatile d2.b on square d1.w of screen d0.b. Returns the metatile that was there in d0.w.
ow_set_square:
    move.l %a0, -(%sp)
    and.l #0xff, %d0
    mulu.w #ROOM_BYTES, %d0
    add.l %d1, %d0
    ltab room_maps, %a0
    adda.l %d0, %a0
    moveq #0, %d0
    move.b (%a0), %d0
    move.b %d2, (%a0)
    movea.l (%sp)+, %a0
    rts

| The same, and the old metatile goes into the list ow_secret_undo works through. Changes no register.
ow_set_square_for_now:
    movem.l %d0/%d3/%a0, -(%sp)
    move.b %d0, OFF_OWS_UNDO_ROOM(%a5)
    bsr ow_set_square
    moveq #0, %d3
    move.b OFF_OWS_UNDO_N(%a5), %d3
    add.w %d3, %d3
    lea OFF_OWS_UNDO(%a5), %a0
    move.b %d1, 0(%a0, %d3.w)
    move.b %d0, 1(%a0, %d3.w)
    addq.b #1, OFF_OWS_UNDO_N(%a5)
    movem.l (%sp)+, %d0/%d3/%a0
    rts

| render_room calls this before it draws: a rock that was pushed in the screen he left goes back.
ow_secret_undo:
    tst.b OFF_OWS_UNDO_N(%a5)
    beq 9f
    tst.b OFF_OWS_FRESH(%a5)
    beq 1f
    clr.b OFF_OWS_FRESH(%a5)            | this is the draw that shows the push itself
    rts
1:  movem.l %d0-%d4/%a0, -(%sp)
    moveq #0, %d3
    move.b OFF_OWS_UNDO_N(%a5), %d3
    clr.b OFF_OWS_UNDO_N(%a5)
    lea OFF_OWS_UNDO(%a5), %a0
2:  subq.w #1, %d3                      | last in, first out: a square that changed twice ends as it began
    bmi 3f
    move.w %d3, %d4
    add.w %d4, %d4
    moveq #0, %d1
    move.b 0(%a0, %d4.w), %d1
    moveq #0, %d2
    move.b 1(%a0, %d4.w), %d2
    move.b OFF_OWS_UNDO_ROOM(%a5), %d0
    bsr ow_set_square
    bra 2b
3:  movem.l (%sp)+, %d0-%d4/%a0
9:  rts

| The screen has changed: draw it again and show it.
ow_secret_redraw:
    movem.l %d0/%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    movea.l OFF_BG_CUR(%a5), %a1
    move.b #1, OFF_OWS_FRESH(%a5)       | (render_room must not take the change back)
    bsr render_room_far
    clr.b OFF_OWS_FRESH(%a5)
    bsr show_background_far
    clr.b OFF_ERASE_VALID(%a5)
    movem.l (%sp)+, %d0/%a1
    rts

| a0 = the record, d1.w and d2.w = where the bomb or flame is. Returns d0.w = 1 when it is next to the spot.
ow_secret_touched:
    movem.l %d3-%d4, -(%sp)
    moveq #0, %d3
    move.b 1(%a0), %d3
    move.w %d3, %d4
    and.w #15, %d4
    lsl.w #4, %d4                       | the spot's X
    lsr.w #4, %d3
    lsl.w #4, %d3
    add.w #SECRET_ROW_Y, %d3            | and Y
    sub.w %d4, %d1
    bpl 1f
    neg.w %d1
1:  sub.w %d3, %d2
    bpl 2f
    neg.w %d2
2:  moveq #0, %d0
    cmp.w #SECRET_REACH, %d1
    bhs 9f
    cmp.w #SECRET_REACH, %d2
    bhs 9f
    moveq #1, %d0
9:  movem.l (%sp)+, %d3-%d4
    rts

| a0 = the record. The spot turns into what it hides, for good, once.
ow_secret_open:
    movem.l %d0-%d2/%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lea OFF_OW_KILLS(%a5), %a1
    bset #SECRET_FOUND, 0(%a1, %d0.w)
    bne 9f                              | it has been found
    moveq #0, %d1
    move.b 1(%a0), %d1
    moveq #0, %d2
    move.b 2(%a0), %d2
    bsr ow_set_square
    bsr ow_secret_redraw
    sfx SFX_SECRET
9:  movem.l (%sp)+, %d0-%d2/%a1
    rts

| The bomb's cloud has opened (bomb_tick): is it next to a rock wall?
ow_bomb_secret:
    tst.b OFF_LEVEL(%a5)
    bne 9f
    movem.l %d0-%d2/%a0, -(%sp)
    bsr ow_secret_record
    cmp.b #SECRET_BOMB, %d0
    bne 8f
    moveq #0, %d1
    move.b OFF_CLOUD_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_CLOUD_Y(%a5), %d2
    bsr ow_secret_touched
    tst.w %d0
    beq 8f
    bsr ow_secret_open
8:  movem.l (%sp)+, %d0-%d2/%a0
9:  rts

| A flame is about to die (fire_update): has it burnt a tree?
ow_fire_secret:
    tst.b OFF_LEVEL(%a5)
    bne 9f
    movem.l %d0-%d2/%a0, -(%sp)
    bsr ow_secret_record
    cmp.b #SECRET_TREE, %d0
    bne 8f
    moveq #0, %d1
    move.b OFF_FIRE_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_FIRE_Y(%a5), %d2
    bsr ow_secret_touched
    tst.w %d0
    beq 8f
    bsr ow_secret_open
8:  movem.l (%sp)+, %d0-%d2/%a0
9:  rts

| Link walks into something and cannot go on (link_pixel), d1.b = the direction. A rock (with the power bracelet)
| or a gravestone gives way when he stands level with it and pushes straight up or down at it.
ow_push_secret:
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    bsr ow_secret_record
    cmp.b #SECRET_ROCK, %d0
    blo 9f
    cmp.b #SECRET_GRAVE, %d0
    bhi 9f
    beq 1f
    tst.b OFF_INV_BRACELET(%a5)         | a gravestone needs nothing, a rock needs the bracelet
    beq 9f
1:  moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2
    tst.b OFF_OWS_UNDO_N(%a5)
    beq 2f
    cmp.b OFF_OWS_UNDO_ROOM(%a5), %d2
    beq 9f                              | it has moved already
2:  moveq #0, %d2
    move.b 1(%a0), %d2                  | the spot's square
    move.w %d2, %d3
    and.w #15, %d3
    lsl.w #4, %d3
    moveq #0, %d4
    move.b OFF_LINK_X(%a5), %d4
    cmp.w %d3, %d4
    bne 9f                              | level with it
    lsr.w #4, %d2
    lsl.w #4, %d2
    add.w #SECRET_ROW_Y, %d2            | its Y
    moveq #0, %d4
    move.b OFF_LINK_Y(%a5), %d4
    addq.w #3, %d4
    sub.w %d2, %d4
    bmi 4f
    cmp.w #0x11, %d4                    | he stands below it: it goes up
    bhs 9f
    cmp.b #DIR_UP, %d1
    bne 9f
    moveq #5, %d5
    moveq #-16, %d3
    bra 5f
4:  neg.w %d4
    cmp.w #0x11, %d4                    | above it: it goes down
    bhs 9f
    cmp.b #DIR_DOWN, %d1
    bne 9f
    moveq #6, %d5
    moveq #16, %d3
5:  moveq #0, %d2
    move.b 0(%a0, %d5.w), %d2           | its metatile where it ends
    cmp.b #0xff, %d2
    beq 9f
    move.l %d2, %d5                     | d5 = that metatile
    clr.b OFF_OWS_UNDO_N(%a5)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    moveq #0, %d1
    move.b 1(%a0), %d1                  | the spot becomes floor
    move.b 2(%a0), %d2
    bsr ow_set_square_for_now
    add.w %d3, %d1                      | and the rock stands on the square next to it
    move.b %d5, %d2
    bsr ow_set_square_for_now
    moveq #0, %d1
    move.b 3(%a0), %d1                  | the stairs
    move.b 4(%a0), %d2
    cmpi.b #SECRET_GRAVE, (%a0)
    bne 6f
    bsr ow_set_square_for_now           | (gone when he comes back)
    bra 7f
6:  bsr ow_set_square                   | (there for good)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lea OFF_OW_KILLS(%a5), %a1
    bset #SECRET_PUSHED, 0(%a1, %d0.w)
7:  bsr ow_secret_redraw
    sfx SFX_SECRET
9:  movem.l (%sp)+, %d0-%d5/%a0-%a1
    rts
