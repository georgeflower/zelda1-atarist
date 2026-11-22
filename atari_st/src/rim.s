| Link under the dungeon's outer rim. On the NES Link is hidden where the room's outer wall is: eight blank sprites at the
| top and bottom doorways' rows (WriteBlankPrioritySprites) take his place on those lines, and the screen's left column is
| blanked. The port drew him over the bricks when he stood in a doorway on his way out. link_rim puts the clean room back
| over the parts of him that lie in the outer 16 pixels of the playfield, on every side, so that he goes in under the
| door's opening. Called by draw_link (through link_rim_f) in a dungeon room in play; it uses ERASE_OFFSET, which
| draw_link has just set. Included after zol.s, at the end of the code.

    farstub link_rows_r, draw_sprite_rows
    farstub shut_redraw_r, uw_redraw_room

    .equ RIM_TOP_END, (PLAYFIELD_TOP + 16)                  | the first line below the top rim
    .equ RIM_BOTTOM, (PLAYFIELD_TOP + 176 - 16)              | the first line of the bottom rim
    .equ RIM_LEFT_GROUP, (PLAYFIELD_LEFT / 8)                | the 16-pixel group of the left rim
    .equ RIM_RIGHT_GROUP, (PLAYFIELD_LEFT / 8 + 15)          | and of the right one

link_rim:
    cmpi.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bne 99f
    tst.b OFF_IN_CELLAR(%a5)
    bne 99f
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    move.l OFF_ERASE_OFFSET(%a5), %d0
    divu.w #SCREEN_STRIDE, %d0                  | low word: Link's first line, high word: the byte of his group
    moveq #0, %d1
    move.w %d0, %d1                             | d1 = line
    swap %d0
    moveq #0, %d2
    move.w %d0, %d2
    lsr.w #3, %d2                               | d2 = his first group (he covers it and the next)
    moveq #15, %d5                              | sixteen lines
1:  cmp.w #200, %d1
    bhs 9f
    move.w %d1, %d3
    mulu.w #SCREEN_STRIDE, %d3                  | d3 = the line's offset
    cmp.w #RIM_TOP_END, %d1
    blo 2f
    cmp.w #RIM_BOTTOM, %d1
    bhs 2f
    | a side: the rim's group only, where he covers it
    move.w %d2, %d4
    cmp.w #RIM_LEFT_GROUP, %d4
    beq 3f
    addq.w #1, %d4
    cmp.w #RIM_LEFT_GROUP, %d4
    beq 3f
    cmp.w #RIM_RIGHT_GROUP, %d4
    beq 3f
    subq.w #1, %d4
    cmp.w #RIM_RIGHT_GROUP, %d4
    beq 3f
    bra 8f
2:  move.w %d2, %d4                             | the top or bottom rim: both his groups
    bsr 50f
    addq.w #1, %d4
3:  bsr 50f
8:  addq.w #1, %d1
    dbra %d5, 1b
9:  movem.l (%sp)+, %d0-%d5/%a0-%a1
99: rts

| copy group d4.w of the line at d3.l from the clean room into the screen being drawn
50: movea.l OFF_BG_CUR(%a5), %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    moveq #0, %d0
    move.w %d4, %d0
    lsl.w #3, %d0
    add.l %d3, %d0
    adda.l %d0, %a0
    adda.l %d0, %a1
    move.l (%a0)+, (%a1)+
    move.l (%a0), (%a1)
    rts

| Link above the play area's first line (after a scroll down the overworld leaves him at Y $3D until he walks; a dungeon's
| top doorway): only his lines inside the play area are drawn, so he is not invisible there, as he was, and not over the
| ribbon. a0 = his frame (draw_link has picked it). Sets ERASE_OFFSET for the lines drawn.
link_clipped:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w #LINK_Y_BIAS, %d1                     | his first line on the screen
    moveq #PLAYFIELD_TOP, %d3
    sub.w %d1, %d3                              | d3 = the lines above the play area
    cmp.w #SPRITE_HEIGHT, %d3
    blt 1f
    clr.b OFF_ERASE_VALID(%a5)                  | all of him is: nothing to draw
    bra 9f
1:  move.w %d3, %d4
    mulu.w #(SPRITE_FRAME_BYTES / SPRITE_HEIGHT), %d4
    adda.l %d4, %a0                             | the frame's first line in the play area
    moveq #(SPRITE_HEIGHT - 1), %d7
    sub.w %d3, %d7                              | the lines left, less one
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    add.w #(PLAYFIELD_LEFT * 2), %d0
    move.w %d0, %d2
    and.w #15, %d2
    lsr.w #4, %d0
    lsl.w #3, %d0
    add.l #(PLAYFIELD_TOP * SCREEN_STRIDE), %d0
    move.l %d0, OFF_ERASE_OFFSET(%a5)
    move.b #1, OFF_ERASE_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d0, %a1
    move.w %d2, %d0
    bsr link_rows_r
    tst.b OFF_LEVEL(%a5)
    beq 9f
    bsr link_rim
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| ------------------------------------------------------------------------------------------- the shutter behind Link
| InitMode_EnterRoom and UpdateDoors: a shutter Link comes in by stands open during the scroll (uw_build_map, from
| UW_ENTER_MASK) and shuts behind him once he is in, with the door sound. In a room already cleared the ROM shuts it all
| the same and CheckShutters opens it again a moment later, so the port does that too (SHUT_FORCE). Called every frame of
| play by uw_person_update; uw_commit_next starts it (SHUT_PHASE 1), uw_render_next stops it.
    .equ SHUT_WAIT, 2           | frames of play before it shuts (UpdateDoors' first frame, plus one)
    .equ SHUT_AGAIN, 24         | frames shut before a cleared room's shutter opens again

shut_tick:
    tst.b OFF_SHUT_PHASE(%a5)
    beq 99f
    tst.b OFF_LEVEL(%a5)
    beq 98f
    tst.b OFF_IN_CELLAR(%a5)
    bne 98f
    subq.b #1, OFF_SHUT_T(%a5)
    bne 99f
    movem.l %d0-%d3/%a0-%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    cmpi.b #2, OFF_SHUT_PHASE(%a5)
    beq 20f
    | phase 1: the door he came in by, if it is a shutter, shuts
    move.b OFF_UW_ENTER_MASK(%a5), %d1
    moveq #0, %d2
1:  btst %d2, %d1
    bne 2f
    addq.w #1, %d2
    cmp.w #4, %d2
    blo 1b
    bra 8f
2:  lvtab ROOM_INDEX, %a0
    moveq #0, %d3
    move.b 0(%a0, %d0.w), %d3
    cmpi.b #0xff, %d3
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d3
    lvtab DOORS, %a1
    adda.l %d3, %a1
    cmpi.b #DOOR_SHUTTER, 0(%a1, %d2.w)
    bne 8f
    bclr %d2, OFF_UW_ENTER_MASK(%a5)
    uwlea OPEN, %a0
    btst %d2, 0(%a0, %d0.w)
    beq 3f
    bset %d2, OFF_SHUT_FORCE(%a5)       | a cleared room: shut for a moment, then open again
    move.b #2, OFF_SHUT_PHASE(%a5)
    move.b #SHUT_AGAIN, OFF_SHUT_T(%a5)
    bra 4f
3:  clr.b OFF_SHUT_PHASE(%a5)
4:  sfx SMP_DOOR
    bsr shut_redraw_r
    bra 9f
20: clr.b OFF_SHUT_FORCE(%a5)           | phase 2: open again
    clr.b OFF_SHUT_PHASE(%a5)
    sfx SMP_DOOR
    bsr shut_redraw_r
    bra 9f
8:  clr.b OFF_SHUT_PHASE(%a5)
9:  movem.l (%sp)+, %d0-%d3/%a0-%a1
99: rts
98: clr.b OFF_SHUT_PHASE(%a5)
    rts

| -------------------------------------------------------------------------------------------- the block's slide
| The block slides a pixel a frame (UpdateBlock) and Link, still pushing, walks faster: the map already has the block
| where it will land, so nothing held him and he walked into its picture (krs saw both overlap, then part). The block
| is solid on the NES: while it slides he is kept at its back. Called by block_update every frame of the slide.
block_link_clamp:
    movem.l %d0-%d3, -(%sp)
    moveq #0, %d0
    move.b OFF_BLOCK_FRAME(%a5), %d0
    moveq #0, %d1
    move.b OFF_BLOCK_X(%a5), %d1                | where the block's picture is now
    moveq #0, %d2
    move.b OFF_BLOCK_Y(%a5), %d2
    subq.w #3, %d2                              | as a Link Y (his grid lines are 3 above the tiles')
    move.b OFF_BLOCK_DIR(%a5), %d3
    btst #0, %d3
    beq 1f
    add.w %d0, %d1
1:  btst #1, %d3
    beq 2f
    sub.w %d0, %d1
2:  btst #2, %d3
    beq 3f
    add.w %d0, %d2
3:  btst #3, %d3
    beq 4f
    sub.w %d0, %d2
4:  moveq #0, %d0
    and.b #(DIR_LEFT + DIR_RIGHT), %d3
    beq 20f
    | sideways: only if he is level with it
    move.b OFF_LINK_Y(%a5), %d0
    sub.w %d2, %d0
    bpl 5f
    neg.w %d0
5:  cmp.w #16, %d0
    bhs 9f
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    btst #1, %d3
    beq 6f
    add.w #16, %d1                              | pushed left: Link no further left than its right side
    cmp.w %d1, %d0
    bhs 9f
    move.b %d1, OFF_LINK_X(%a5)
    bra 8f
6:  sub.w #16, %d1                              | pushed right: no further right than its left side
    cmp.w %d1, %d0
    bls 9f
    move.b %d1, OFF_LINK_X(%a5)
    bra 8f
20: move.b OFF_LINK_X(%a5), %d0                 | up or down: only if he is in line with it
    sub.w %d1, %d0
    bpl 21f
    neg.w %d0
21: cmp.w #16, %d0
    bhs 9f
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    btst #3, OFF_BLOCK_DIR(%a5)
    beq 22f
    add.w #16, %d2                              | pushed up: no higher than its bottom
    cmp.w %d2, %d0
    bhs 9f
    move.b %d2, OFF_LINK_Y(%a5)
    bra 8f
22: sub.w #16, %d2                              | pushed down: no lower than its top
    cmp.w %d2, %d0
    bls 9f
    move.b %d2, OFF_LINK_Y(%a5)
8:  moveq #0, %d0                               | his step now ends on the grid line ahead of where he stands
    move.b OFF_LINK_X(%a5), %d0
    btst #0, %d3
    bne 81f
    btst #1, %d3
    bne 82f
    move.b OFF_LINK_Y(%a5), %d0
    addq.b #3, %d0                              | (his grid lines are at Y AND 7 = 5)
    btst #3, OFF_BLOCK_DIR(%a5)
    bne 82f
81: neg.b %d0                                   | right or down: up to the next multiple of 8
82: and.b #7, %d0                               | left or up: back to the last one
    move.b %d0, OFF_COMMIT(%a5)
9:  movem.l (%sp)+, %d0-%d3
    rts
