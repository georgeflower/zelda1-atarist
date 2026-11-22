| Link under the dungeon's outer rim. On the NES Link is hidden where the room's outer wall is: eight blank sprites at the
| top and bottom doorways' rows (WriteBlankPrioritySprites) take his place on those lines, and the screen's left column is
| blanked. The port drew him over the bricks when he stood in a doorway on his way out. link_rim puts the clean room back
| over the parts of him that lie in the outer 16 pixels of the playfield, on every side, so that he goes in under the
| door's opening. Called by draw_link (through link_rim_f) in a dungeon room in play; it uses ERASE_OFFSET, which
| draw_link has just set. Included after zol.s, at the end of the code.

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
