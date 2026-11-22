| The zol's split (Zol_CheckCollisions, UpdateZolState1/2, Gel_Move, Gel_MoveSplitting). Included last, after save.s,
| because the code between secrets.s and save.s has no 16-bit reach to spare; dmon.s and ai.s come here through
| zol_hit_f and gel_split_f, and this file reaches back through its own trampolines.

    farstub zol_enemy_make, enemy_make
    farstub zol_cloud_begin, cloud_begin
    farstub zol_cell_blocked, enemy_cell_blocked

| ------------------------------------------------------------------------------------------------ the zol and its gels
| Zol_CheckCollisions: a zol that a blow hurt but did not kill is given a "big shove" when the blow came along a way it
| can go from where it stands (a horizontal blow on its row's lane, a vertical one on its column's): it runs on at full
| speed (Gel_MoveSplitting, about 4 pixels a frame) until something stops it, and splits there (state 1). Otherwise it
| splits at once (state 2). Nothing touches it while it runs. d5 = the zol.
zol_hit:
    movem.l %d0-%d1/%d6/%a0, -(%sp)
    move.b OFF_ENEMY_SHOVE(%a5, %d5.w), %d6     | the blow's way (CheckMonsterWeaponCollision turns the zol to it)
    bne 1f
    move.b OFF_LINK_DIR(%a5), %d6
1:  moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    and.b #15, %d1
    cmp.b #13, %d1
    bne 2f
    moveq #3, %d0                       | on a row's lane: left and right are its ways
2:  move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    and.b #15, %d1
    bne 3f
    or.b #12, %d0                       | on a column's lane: up and down
3:  and.b %d6, %d0
    bne 4f
    bsr zol_split
    bra 9f
4:  move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #3, 0(%a0, %d5.w)            | (Zol_CheckCollisions looks at nothing outside state 0)
9:  movem.l (%sp)+, %d0-%d1/%d6/%a0
    rts

| UpdateZolState2_Split: the zol goes and two gels come where it was, one each way across its heading (left and right
| when it went up or down, else up and down). Each comes out of a spawn cloud (the ROM makes them with ShootLimited, and
| they appear as monsters do), then slides away for up to four frames (Gel_Move state 1) and settles on the square grid.
zol_split:
    movem.l %d0-%d6, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #DIR_LEFT, %d4
    cmpi.b #DIR_DOWN, OFF_ENEMY_DIR(%a5, %d5.w)
    bhs 1f
    moveq #DIR_UP, %d4
1:  clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    moveq #1, %d6
2:  moveq #MON_GEL, %d1
    bsr zol_enemy_make
    tst.w %d0
    bmi 3f
    move.w %d5, -(%sp)
    move.w %d0, %d5
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)  | Gel_Move state 1: slide for the timer's five frames
    move.b #5, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr zol_cloud_begin
    move.w (%sp)+, %d5
3:  lsr.b #1, %d4                       | the second gel the other way
    dbra %d6, 2b
    movem.l (%sp)+, %d0-%d6
    rts

| gel_ai for a zol or gel not in its normal state 0: the zol's big shove, or a new gel sliding away from where the zol
| split. d5 = the monster. Returns d0.w = 1 (it takes no ordinary step).
gel_split:
    movem.l %d1-%d6, -(%sp)
    moveq #0, %d6
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d6
    cmpi.b #MON_ZOL, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    bsr gel_slide                       | UpdateZolState1_Shove: on until it is blocked, then in two
    tst.w %d0
    beq 8f
    bsr zol_split
    bra 8f
1:  tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 5f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 5f
    bsr gel_slide
    tst.w %d0
    beq 8f
5:  moveq #0, %d2                       | blocked or the time is up: onto the grid, ((X + 8) AND $F0) and
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2 | (((Y + 8) AND $F0) OR $0D), which puts a gel on a row's lane on the one
    addq.w #8, %d2                      | below (as the ROM does), and on to its ordinary life
    and.w #0xf0, %d2
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    addq.w #8, %d3
    and.w #0xf0, %d3
    or.w #0x0d, %d3
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
8:  moveq #1, %d0
    movem.l (%sp)+, %d1-%d6
    rts

| Gel_MoveSplitting: four pixels in the way d6.b, stopped by the room's edge and, where it crosses onto a new square,
| by a square that is shut (both squares when it is between two lanes). Returns d0.w = 1 when it was stopped.
gel_slide:
    movem.l %d1-%d4, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #3, %d4
1:  btst #0, %d6
    beq 2f
    cmp.b OFF_OBJ_RIGHT(%a5), %d2
    bhs 8f
2:  btst #1, %d6
    beq 3f
    cmp.b OFF_OBJ_LEFT(%a5), %d2
    blo 8f
3:  btst #2, %d6
    beq 4f
    cmp.b OFF_OBJ_DOWN(%a5), %d3
    bhs 8f
4:  btst #3, %d6
    beq 5f
    cmp.b OFF_OBJ_UP(%a5), %d3
    blo 8f
5:  move.b %d6, %d0
    and.b #DIR_VERTICAL, %d0
    bne 6f
    move.b %d2, %d0                     | going sideways: at a column's lane, the squares beside it
    and.b #15, %d0
    bne 7f
    move.w %d3, -(%sp)
    addq.w #3, %d3
    and.w #0xf0, %d3
    subq.w #3, %d3                      | the row's lane at or above it
    bsr zol_cell_blocked
    tst.w %d0
    bne 51f
    move.w (%sp), %d1
    and.b #15, %d1
    cmp.b #13, %d1
    beq 51f
    add.w #16, %d3                      | between two lanes: the one below too
    bsr zol_cell_blocked
51: move.w (%sp)+, %d3
    tst.w %d0
    bne 8f
    bra 7f
6:  move.b %d3, %d0                     | going up or down: at a row's lane, the squares above or below it
    and.b #15, %d0
    cmp.b #13, %d0
    bne 7f
    move.w %d2, -(%sp)
    and.w #0xf0, %d2
    bsr zol_cell_blocked
    tst.w %d0
    bne 61f
    move.w (%sp), %d1
    and.b #15, %d1
    beq 61f
    add.w #16, %d2
    bsr zol_cell_blocked
61: move.w (%sp)+, %d2
    tst.w %d0
    bne 8f
7:  btst #0, %d6
    beq 71f
    addq.w #1, %d2
71: btst #1, %d6
    beq 72f
    subq.w #1, %d2
72: btst #2, %d6
    beq 73f
    addq.w #1, %d3
73: btst #3, %d6
    beq 74f
    subq.w #1, %d3
74: dbra %d4, 1b
    moveq #0, %d0
    bra 9f
8:  moveq #1, %d0
9:  move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    movem.l (%sp)+, %d1-%d4
    rts
