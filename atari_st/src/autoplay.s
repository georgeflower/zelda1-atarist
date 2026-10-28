| Development-only autoplay (ZELDA_AUTOPLAY=1): a scripted player for the playthrough audit (Phase 2). Not in the game:
| the whole file is assembled only when DEV_AUTOPLAY is set. The ROM side of the audit (tools/refnes/rom_play.mjs) plays
| the same policy, so what happens in a room can be compared:
|   Link cannot be hurt and holds the magic sword; each frame he walks at the nearest monster that can be killed (not a
|   bubble or a blade trap) and swings the sword (Space, held for 8 frames of every 16) when it is less than 26 away.
|   He closes in on the shorter axis first while both distances are over 8.
| It runs after poll_keyboard, so it writes the key table the game then reads.
    .if DEV_AUTOPLAY

autoplay:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    tst.b OFF_GAME_MODE(%a5)
    bne 90f
    move.b #3, OFF_HAS_SWORD(%a5)
    move.b #0x60, OFF_LINK_HURT(%a5)
    move.b #12, OFF_HP_HALVES(%a5)
    lea OFF_KEY_STATES(%a5), %a0
    clr.b SCAN_UP(%a0)
    clr.b SCAN_DOWN(%a0)
    clr.b SCAN_LEFT(%a0)
    clr.b SCAN_RIGHT(%a0)
    clr.b SCAN_CTRL(%a0)
    .ifeq DEV_AUTOPLAY - 2
    bra 90f                             | ZELDA_AUTOPLAY=idle: he only stands there, to watch the monsters
    .endif
    ltab mon_table, %a1
    lea OFF_ENEMY_CLOUD(%a5), %a2
    move.w #0x7fff, %d7                 | distance of the best monster so far
    moveq #0, %d4
    move.b OFF_LINK_X(%a5), %d4
    moveq #0, %d5
    move.b OFF_LINK_Y(%a5), %d5
    moveq #0, %d3                       | monster number
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d3
    bhs 5f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d3.w)
    beq 4f
    tst.b (%a2, %d3.w)
    bne 4f
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d3.w), %d0
    lsl.w #3, %d0
    move.b (%a1, %d0.w), %d0            | its NES type
    cmp.b #0x2b, %d0
    blo 2f
    cmp.b #0x2d, %d0
    bls 4f                              | bubbles
2:  cmp.b #0x49, %d0
    beq 4f
    cmp.b #0x4a, %d0
    beq 4f                              | blade traps
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    sub.w %d4, %d1                      | dx
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d2
    sub.w %d5, %d2                      | dy
    move.w %d1, %d0
    bpl 3f
    neg.w %d0
3:  move.w %d2, %d6
    bpl 6f
    neg.w %d6
6:  add.w %d6, %d0                      | |dx| + |dy|
    cmp.w %d7, %d0
    bhs 4f
    move.w %d0, %d7
    move.w %d1, %d6                     | the best one's dx and dy, in one long
    swap %d6
    move.w %d2, %d6
    movea.l %d6, %a3
4:  addq.b #1, %d3
    bra 1b
5:  cmp.w #0x7fff, %d7
    beq 90f                             | nothing to kill
    move.l %a3, %d1
    swap %d1
    move.l %a3, %d2
    move.w %d1, %d3
    bpl 7f
    neg.w %d3                           | |dx|
7:  move.w %d2, %d4
    bpl 8f
    neg.w %d4                           | |dy|
8:  cmp.w #8, %d3
    ble 20f                             | in line vertically: close in on y
    cmp.w #8, %d4
    ble 30f                             | in line horizontally: close in on x
    cmp.w %d4, %d3
    blt 30f                             | |dx| < |dy|: line up on x first
20: tst.w %d2
    bgt 21f
    move.b #1, SCAN_UP(%a0)
    bra 40f
21: move.b #1, SCAN_DOWN(%a0)
    bra 40f
30: tst.w %d1
    bgt 31f
    move.b #1, SCAN_LEFT(%a0)
    bra 40f
31: move.b #1, SCAN_RIGHT(%a0)
40: cmp.w #26, %d7
    bge 90f
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #15, %d0
    cmp.w #8, %d0
    bge 90f
    move.b #1, SCAN_CTRL(%a0)
90: movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

    .endif
