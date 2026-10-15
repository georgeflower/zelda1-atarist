| Monster behaviour beyond wandering, and the projectiles monsters throw.
|
| Ropes charge along a line at Link, goriyas throw boomerangs, wallmasters
| come out of the walls and carry Link back to the start of the level, and
| Aquamentus walks to and fro breathing fireballs. The rules are the ones in
| Z_04.asm (UpdateRope, UpdateGoriya, UpdateWallmaster, UpdateAquamentus).

    .equ BEH_WANDER, 0
    .equ BEH_ROPE, 1
    .equ BEH_GORIYA, 2
    .equ BEH_WALLMASTER, 3
    .equ BEH_BOSS, 4
    .equ BEH_KEESE, 5
    .equ BEH_TRAP, 6

    .equ ENEMY_SHOVE_FRAMES, 16     | 64 pixels at 4 a frame
    .equ MAX_PROJ, 8
    .equ PK_BOOMERANG, 1            | flying out
    .equ PK_RETURNING, 2            | coming back to the goriya
    .equ PK_FIREBALL, 3
    .equ PK_PART, 4                 | a piece of Aquamentus

| Field offsets from PROJ_KIND; each field is a row of MAX_PROJ bytes.
    .equ PJ_KIND, 0
    .equ PJ_X, 8
    .equ PJ_Y, 16
    .equ PJ_DIR, 24                 | a boss piece keeps its number here
    .equ PJ_QX, 32                  | speed along each axis, in 1/64 pixel a frame
    .equ PJ_QY, 40
    .equ PJ_FRACX, 48
    .equ PJ_FRACY, 56
    .equ PJ_TIMER, 64               | boomerang: frames left going out; fireball: frames before it moves
    .equ PJ_OWNER, 72               | the monster that threw it; a fireball keeps its Y drift here
    .equ PJ_ERASE_VALID, 80
    .equ PJ_OLD_ERASE_VALID, 88
    .equ PJ_ERASE_OFFSETS, 96
    .equ PJ_OLD_ERASE_OFFSETS, 128
    .if (OFF_OLD_PROJ_ERASE_OFFSETS - OFF_PROJ_KIND) != PJ_OLD_ERASE_OFFSETS
    .error "globals.s lays the projectile fields out differently from ai.s"
    .endif

    .equ PF_FIREBALL, 4             | frames in proj_sprites
    .equ PF_BOSS, 6
    .equ PF_HIDDEN, 0xff

    .equ BOOMERANG_QSPEED, 0xa0     | 2.5 pixels a frame
    .equ BOOMERANG_FRAMES, 33       | about $51 pixels out
    .equ BOOMERANG_RANGE, 0x51
    .equ PROJ_RANGE, 10
    .equ WALLMASTER_GAP, 0x60
    .equ WALLMASTER_TILE, 16
    .equ BOSS_START_X, 0xb0
    .equ BOSS_START_Y, 0x80
    .equ BOSS_LEFT_LIMIT, 0x88
    .equ BOSS_RIGHT_LIMIT, 0xc8

| ------------------------------------------------------------ small helpers
| d5 = monster. Returns d0.w = its behaviour (BEH_*). Clobbers a0.
enemy_behaviour:
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmpi.b #0xff, %d0
    beq 1f
    lsl.w #3, %d0
    ltab mon_table, %a0
    move.b 7(%a0, %d0.w), %d0
    rts
1:  moveq #0, %d0
    rts

| Finishing touches for a monster just placed: wallmasters wait inside the
| walls and Aquamentus starts where the original puts him. d5 = monster.
enemy_init_special:
    movem.l %d0-%d1/%a0, -(%sp)
    bsr enemy_behaviour
    cmp.w #BEH_WALLMASTER, %d0
    bne 1f
    clr.b OFF_ENEMY_X(%a5, %d5.w)
    clr.b OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
1:  cmp.w #BEH_BOSS, %d0
    bne 5f
    move.b #BOSS_START_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #BOSS_START_Y, OFF_ENEMY_Y(%a5, %d5.w)
    move.b #DIR_LEFT, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #0x30, OFF_ENEMY_STATE(%a5, %d5.w)   | frames until the first fireballs
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    moveq #1, %d1
2:  bsr proj_alloc
    tst.w %d0
    bmi 9f
    lea OFF_PROJ_KIND(%a5), %a0
    move.b #PK_PART, PJ_KIND(%a0, %d0.w)
    move.b %d1, PJ_DIR(%a0, %d0.w)
    move.b %d5, PJ_OWNER(%a0, %d0.w)
    move.b #PF_HIDDEN, PJ_TIMER(%a0, %d0.w)
    addq.w #1, %d1
    cmp.w #4, %d1
    blo 2b
    bra 9f
5:  cmp.w #BEH_KEESE, %d0
    bne 6f
    lea OFF_ENEMY_SPEED(%a5), %a0   | a keese starts slow, at $1F, and picks up speed
    move.b #0x1f, 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    bsr rand8
    and.w #7, %d0
    lea keese_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    bra 9f
6:  cmp.w #BEH_TRAP, %d0
    bne 9f
    lea trap_xs(%pc), %a0           | where InitTrap_Full puts the traps
    move.b 0(%a0, %d5.w), OFF_ENEMY_X(%a5, %d5.w)
    move.b 6(%a0, %d5.w), OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)     | alive for good: it never counts as a monster of the room
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| Returns d0.w = free projectile slot, or -1.
proj_alloc:
    movem.l %d1/%a0, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a0
    moveq #0, %d0
1:  tst.b 0(%a0, %d0.w)
    beq 9f
    addq.w #1, %d0
    cmp.w #MAX_PROJ, %d0
    blo 1b
    moveq #-1, %d0
9:  movem.l (%sp)+, %d1/%a0
    rts

| ---------------------------------------------------------------------- rope
| A rope that comes level with Link, with its square lined up, charges at him
| at three times its walking speed until something stops it.
|
| d5 = monster. Sets ENEMY_STATE to 1 while it charges.
rope_ai:
    movem.l %d0-%d3, -(%sp)
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 9f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    move.b %d2, %d0
    and.b #7, %d0
    bne 9f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b %d3, %d0
    and.b #7, %d0
    cmp.b #5, %d0
    bne 9f
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d2, %d0                  | d0 = how far right of the rope Link is
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w %d3, %d1                  | d1 = how far below
    move.w %d0, %d2
    bpl 1f
    neg.w %d2
1:  cmp.w #8, %d2
    bhs 3f
    moveq #DIR_UP, %d2              | in his column: charge up or down
    tst.w %d1
    bmi 5f
    moveq #DIR_DOWN, %d2
    bra 5f
3:  move.w %d1, %d2
    bpl 4f
    neg.w %d2
4:  cmp.w #8, %d2
    bhs 9f
    moveq #DIR_LEFT, %d2            | in his row: charge left or right
    tst.w %d0
    bmi 5f
    moveq #DIR_RIGHT, %d2
5:  move.b %d2, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d3
    rts

| -------------------------------------------------------------------- goriya
| A goriya that is lined up with Link within $51 pixels turns to face him and
| now and then throws its boomerang, then stands still until it comes back.
|
| d5 = monster. Returns d0.w = 1 while it must not move.
goriya_ai:
    movem.l %d1-%d4, -(%sp)
    moveq #1, %d0
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 9f
    moveq #0, %d0
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 1f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
1:  tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    beq 11f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)   | just turned back from a wall: let it wander a moment
    bra 9f
11: moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    move.b %d1, %d2
    and.b #7, %d2
    bne 9f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b %d3, %d2
    and.b #7, %d2
    cmp.b #5, %d2
    bne 9f
    moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    sub.w %d2, %d1
    neg.w %d1                       | d1 = how far right of the goriya Link is
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    sub.w %d2, %d3
    neg.w %d3                       | d3 = how far below
    move.w %d1, %d2
    bpl 2f
    neg.w %d2
2:  move.w %d3, %d4
    bpl 3f
    neg.w %d4
3:  cmp.w %d2, %d4                  | the longer way decides the direction
    blo 5f
    cmp.w #BOOMERANG_RANGE, %d4
    bhs 9f
    moveq #DIR_UP, %d2
    tst.w %d3
    bmi 7f
    moveq #DIR_DOWN, %d2
    bra 7f
5:  cmp.w #BOOMERANG_RANGE, %d2
    bhs 9f
    moveq #DIR_LEFT, %d2
    tst.w %d1
    bmi 7f
    moveq #DIR_RIGHT, %d2
7:  move.b %d2, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr goriya_throw
9:  movem.l (%sp)+, %d1-%d4
    rts

goriya_throw:
    movem.l %d0-%d1/%a4, -(%sp)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f
    bsr rand8
    cmp.b #32, %d0                  | the original tries every frame at 2 in 256; a grid-aligned call is rarer
    bhs 9f
1:  bsr proj_alloc
    tst.w %d0
    bmi 9f
    lea OFF_PROJ_KIND(%a5), %a4
    move.b #PK_BOOMERANG, PJ_KIND(%a4, %d0.w)
    move.b OFF_ENEMY_X(%a5, %d5.w), PJ_X(%a4, %d0.w)
    move.b OFF_ENEMY_Y(%a5, %d5.w), PJ_Y(%a4, %d0.w)
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    move.b %d1, PJ_DIR(%a4, %d0.w)
    clr.b PJ_FRACX(%a4, %d0.w)
    clr.b PJ_FRACY(%a4, %d0.w)
    clr.b PJ_QX(%a4, %d0.w)
    clr.b PJ_QY(%a4, %d0.w)
    and.b #DIR_VERTICAL, %d1
    bne 2f
    move.b #BOOMERANG_QSPEED, PJ_QX(%a4, %d0.w)
    bra 3f
2:  move.b #BOOMERANG_QSPEED, PJ_QY(%a4, %d0.w)
3:  move.b #BOOMERANG_FRAMES, PJ_TIMER(%a4, %d0.w)
    move.b %d5, PJ_OWNER(%a4, %d0.w)
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d1/%a4
    rts

| ------------------------------------------------------------------ wallmaster
| Wallmasters wait inside the walls. When Link stands against one they come
| out in front of him, crawl seven squares along the wall and go back in;
| one that touches him carries him off to the start of the level.
|
| ENEMY_STATE: 0 inside the wall, 1 crawling, 2 carrying Link.
| ENEMY_TIMER counts the pixels left in the square it is crossing, and
| ENEMY_STEP is its place in wallmaster_dirs; the low three bits are the
| squares crossed so far.
wallmaster_ai:
    movem.l %d0-%d4/%a0, -(%sp)
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 20f
    tst.b OFF_WALL_TIMER(%a5)
    bne 99f
    moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    cmp.w #0x29, %d2
    blo 1f
    cmp.w #0xc8, %d2
    blo 2f
1:  cmp.w #0x6d, %d3                | against a side wall, he has to be within its length
    blo 99f
    cmp.w #0xb5, %d3
    bhs 99f
2:  cmp.w #0x20, %d2
    beq 3f
    cmp.w #0xd0, %d2
    bne 5f
3:  | A side wall: the way along it that decreases is up.
    moveq #0, %d4                   | d4 = offset into wallmaster_dirs
    move.w %d3, %d0                 | d0 = Link's place along the wall
    move.w #0x24, %d1
    tst.b OFF_PREV_INPUT_DIR(%a5)
    beq 31f
    move.w #0x32, %d1
31: cmp.b #DIR_UP, OFF_LINK_DIR(%a5)
    bne 32f
    addq.w #8, %d4
    neg.w %d1
32: add.w %d1, %d0                  | where it comes out along the wall
    clr.w %d1
    cmp.w #0x20, %d2
    beq 33f
    add.w #0x10, %d4
    move.w #0xf0, %d1               | the right-hand wall
33: move.b %d1, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d0, OFF_ENEMY_Y(%a5, %d5.w)
    bra 8f
5:  cmp.w #0x5d, %d3
    beq 6f
    cmp.w #0xbd, %d3
    bne 99f
6:  | The top or bottom wall: the way along it that decreases is left.
    move.w #0x20, %d4
    move.w %d2, %d0
    move.w #0x24, %d1
    tst.b OFF_PREV_INPUT_DIR(%a5)
    beq 61f
    move.w #0x32, %d1
61: cmp.b #DIR_LEFT, OFF_LINK_DIR(%a5)
    bne 62f
    addq.w #8, %d4
    neg.w %d1
62: add.w %d1, %d0
    move.w #0x3d, %d1
    cmp.w #0x5d, %d3
    beq 63f
    add.w #0x10, %d4
    move.w #0xdd, %d1
63: move.b %d0, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d1, OFF_ENEMY_Y(%a5, %d5.w)
8:  move.b %d4, OFF_ENEMY_STEP(%a5, %d5.w)
    bsr wallmaster_face
    move.b #WALLMASTER_TILE, OFF_ENEMY_TIMER(%a5, %d5.w)
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #WALLMASTER_GAP, OFF_WALL_TIMER(%a5)
    bra 99f

20: | Crawling: a pixel every third frame.
    moveq #0, %d1
    move.w OFF_FRAME_COUNTER(%a5), %d1
    add.w %d5, %d1
    divu.w #3, %d1
    swap %d1
    tst.w %d1
    bne 90f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    btst #0, %d1
    beq 21f
    addq.b #1, OFF_ENEMY_X(%a5, %d5.w)
    bra 25f
21: btst #1, %d1
    beq 22f
    subq.b #1, OFF_ENEMY_X(%a5, %d5.w)
    bra 25f
22: btst #2, %d1
    beq 23f
    addq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
    bra 25f
23: subq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
25: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 90f
    move.b #WALLMASTER_TILE, OFF_ENEMY_TIMER(%a5, %d5.w)
    addq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    and.b #7, %d0
    cmp.b #7, %d0
    beq 30f
    bsr wallmaster_face
    bra 90f
30: | The trip is over.
    cmp.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    beq 36f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_X(%a5, %d5.w)
    clr.b OFF_ENEMY_Y(%a5, %d5.w)
    bra 99f
36: clr.b OFF_LINK_HELD(%a5)
    bsr uw_warp_to_start
    bra 99f
90: cmp.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 99f
    moveq #0, %d0                   | the hand carries Link along with it
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    cmp.w #0xf0, %d0
    bls 91f
    move.w #0xf0, %d0
91: cmp.w #0x3d, %d1
    bhs 92f
    move.w #0x3d, %d1
92: cmp.w #0xdd, %d1
    bls 93f
    move.w #0xdd, %d1
93: move.b %d0, OFF_LINK_X(%a5)
    move.b %d1, OFF_LINK_Y(%a5)
99: movem.l (%sp)+, %d0-%d4/%a0
    rts

| Face the way the path says for the current step.
wallmaster_face:
    movem.l %d0/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    lea wallmaster_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    movem.l (%sp)+, %d0/%a0
    rts

| Left wall, right wall, top and bottom, each in its two flavours: the hand
| goes out two squares, along the wall for three and back for three.
wallmaster_dirs:
    .byte 1, 1, 8, 8, 8, 2, 2, 2,  1, 1, 4, 4, 4, 2, 2, 2
    .byte 2, 2, 8, 8, 8, 1, 1, 1,  2, 2, 4, 4, 4, 1, 1, 1
    .byte 4, 4, 2, 2, 2, 8, 8, 8,  4, 4, 1, 1, 1, 8, 8, 8
    .byte 8, 8, 2, 2, 2, 4, 4, 4,  8, 8, 1, 1, 1, 4, 4, 4

| d5 = monster that has just touched Link. A wallmaster crawling in the open
| takes hold of him: returns d0.w = 1 when it did.
wallmaster_grab:
    movem.l %a0, -(%sp)
    bsr enemy_behaviour
    cmp.w #BEH_WALLMASTER, %d0
    bne 8f
    cmp.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 8f
    move.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #1, OFF_LINK_HELD(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    clr.b OFF_COMMIT(%a5)
    moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %a0
    rts

| ------------------------------------------------------------------ Aquamentus
| He walks 7 or 15 pixels one way or the other, a pixel every eighth frame,
| between X $88 and $C7, and breathes three fireballs at Link every $70 to
| $FF frames. d5 = the boss; called every frame.
boss_ai:
    movem.l %d0-%d2, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #7, %d0
    bne 5f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 2f
    bsr rand8
    move.b %d0, %d1
    and.b #0x0f, %d0
    or.b #7, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
    and.b #1, %d1
    addq.b #1, %d1
    move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
    bra 5f
2:  cmp.w #BOSS_LEFT_LIMIT, %d2
    bhs 3f
    move.w #BOSS_LEFT_LIMIT, %d2
    move.b #DIR_RIGHT, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #7, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 4f
3:  cmp.w #BOSS_RIGHT_LIMIT, %d2
    blo 4f
    move.w #(BOSS_RIGHT_LIMIT - 1), %d2
    move.b #DIR_LEFT, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #7, OFF_ENEMY_TIMER(%a5, %d5.w)
4:  btst #1, OFF_ENEMY_DIR(%a5, %d5.w)
    beq 41f
    subq.w #1, %d2
    bra 42f
41: addq.w #1, %d2
42: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
5:  tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    beq 6f
    subq.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
6:  bsr rand8
    or.b #0x70, %d0
    move.b %d0, OFF_ENEMY_STATE(%a5, %d5.w)
    bsr boss_fire
9:  movem.l (%sp)+, %d0-%d2
    rts

| Three fireballs aimed at Link, which fan out as they fly.
boss_fire:
    movem.l %d0-%d4/%d6-%d7/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    addq.w #4, %d1
    sub.w %d1, %d0                  | d0 = how far right of the mouth Link is
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    sub.w %d1, %d2                  | d2 = how far below
    moveq #DIR_RIGHT, %d3
    tst.w %d0
    bpl 1f
    moveq #DIR_LEFT, %d3
    neg.w %d0
1:  moveq #DIR_DOWN, %d4
    tst.w %d2
    bpl 2f
    moveq #DIR_UP, %d4
    neg.w %d2
2:  or.b %d4, %d3                   | d3 = both directions
    moveq #0, %d6
    move.w %d0, %d1
    add.w %d2, %d1
    beq 3f
    lsl.w #3, %d2
    divu.w %d1, %d2                 | angle index 0..8: 8 * |dy| / (|dx| + |dy|)
    move.w %d2, %d6
3:  lea fireball_speeds(%pc), %a0
    move.b 8(%a0, %d6.w), %d7       | vertical speed
    move.b 0(%a0, %d6.w), %d6       | horizontal speed
    moveq #0, %d4
    bsr boss_spawn_fireball
    moveq #1, %d4
    bsr boss_spawn_fireball
    moveq #-1, %d4
    bsr boss_spawn_fireball
    movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0
    rts

| d3 = directions, d6 = horizontal and d7 = vertical speed, d4 = Y drift
boss_spawn_fireball:
    movem.l %d0-%d1/%a4, -(%sp)
    bsr proj_alloc
    tst.w %d0
    bmi 9f
    lea OFF_PROJ_KIND(%a5), %a4
    move.b #PK_FIREBALL, PJ_KIND(%a4, %d0.w)
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    addq.b #4, %d1
    move.b %d1, PJ_X(%a4, %d0.w)
    move.b OFF_ENEMY_Y(%a5, %d5.w), PJ_Y(%a4, %d0.w)
    move.b %d3, PJ_DIR(%a4, %d0.w)
    move.b %d6, PJ_QX(%a4, %d0.w)
    move.b %d7, PJ_QY(%a4, %d0.w)
    clr.b PJ_FRACX(%a4, %d0.w)
    clr.b PJ_FRACY(%a4, %d0.w)
    move.b #0x10, PJ_TIMER(%a4, %d0.w)
    move.b %d4, PJ_OWNER(%a4, %d0.w)
9:  movem.l (%sp)+, %d0-%d1/%a4
    rts

| Horizontal speeds, then the vertical ones from index 8 on, for the nine
| angles between level and straight down (FireballQSpeedsX / Y).
fireball_speeds:
    .byte 0x70, 0x68, 0x60, 0x58, 0x50, 0x3c, 0x26, 0x10
    .byte 0x00, 0x10, 0x26, 0x3c, 0x50, 0x58, 0x60, 0x68, 0x70
    .align 2

| d5 = the boss, d0.w = piece (0 head, 1 right, 2 below, 3 below right).
| Returns d0.w = frame in proj_sprites, or PF_HIDDEN while he blinks.
boss_frame:
    movem.l %d1-%d2, -(%sp)
    btst #1, OFF_ENEMY_HURT(%a5, %d5.w)
    bne 8f
    moveq #0, %d1                   | the walking frames swap every 16 frames
    move.w OFF_FRAME_COUNTER(%a5), %d2
    and.w #0x10, %d2
    bne 1f
    moveq #2, %d1
1:  cmp.b #0x20, OFF_ENEMY_STATE(%a5, %d5.w)
    bhs 2f
    addq.w #1, %d1                  | mouth open just before and while he breathes
2:  lsl.w #2, %d1
    add.w %d1, %d0
    add.w #PF_BOSS, %d0
    bra 9f
8:  move.w #PF_HIDDEN, %d0
9:  movem.l (%sp)+, %d1-%d2
    rts

| Boss piece in slot d7 follows monster d1.
boss_part_update:
    movem.l %d0/%d2-%d3/%d5, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d1.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d1.w), %d3
    moveq #0, %d0
    move.b PJ_DIR(%a4, %d7.w), %d0
    btst #0, %d0
    beq 1f
    add.w #16, %d2
1:  btst #1, %d0
    beq 2f
    add.w #16, %d3
2:  move.b %d2, PJ_X(%a4, %d7.w)
    move.b %d3, PJ_Y(%a4, %d7.w)
    move.w %d1, %d5                 | boss_frame wants the monster in d5
    bsr boss_frame
    move.b %d0, PJ_TIMER(%a4, %d7.w)
    movem.l (%sp)+, %d0/%d2-%d3/%d5
    rts

| ------------------------------------------------------------------ projectiles
update_projectiles:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    tst.b OFF_WALL_TIMER(%a5)
    beq 0f
    subq.b #1, OFF_WALL_TIMER(%a5)
0:  lea OFF_PROJ_KIND(%a5), %a4
    moveq #0, %d7
1:  moveq #0, %d0
    move.b PJ_KIND(%a4, %d7.w), %d0
    beq 8f
    cmp.b #PK_PART, %d0
    beq 50f
    cmp.b #PK_FIREBALL, %d0
    beq 40f
    cmp.b #PK_RETURNING, %d0
    beq 30f

    bsr proj_move                   | a boomerang on its way out
    tst.w %d0
    bne 21f
    subq.b #1, PJ_TIMER(%a4, %d7.w)
    bne 60f
21: move.b #PK_RETURNING, PJ_KIND(%a4, %d7.w)
    bra 60f

30: | Coming back: head for the goriya along whichever way is longer.
    moveq #0, %d1
    move.b PJ_OWNER(%a4, %d7.w), %d1
    tst.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    beq 39f                         | it died with the boomerang out
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d1.w), %d2
    moveq #0, %d3
    move.b PJ_X(%a4, %d7.w), %d3
    sub.w %d3, %d2                  | d2 = dx to the goriya
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d1.w), %d3
    moveq #0, %d0
    move.b PJ_Y(%a4, %d7.w), %d0
    sub.w %d0, %d3                  | d3 = dy
    move.w %d2, %d4
    bpl 31f
    neg.w %d4
31: move.w %d3, %d6
    bpl 32f
    neg.w %d6
32: cmp.w #6, %d4
    bhs 33f
    cmp.w #6, %d6
    bhs 33f
    clr.b OFF_ENEMY_STATE(%a5, %d1.w)       | caught
    bsr rand8
    and.b #0x3f, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d1.w)
39: clr.b PJ_KIND(%a4, %d7.w)
    bra 8f
33: clr.b PJ_QX(%a4, %d7.w)
    clr.b PJ_QY(%a4, %d7.w)
    cmp.w %d6, %d4
    blo 35f
    moveq #DIR_RIGHT, %d0
    tst.w %d2
    bpl 34f
    moveq #DIR_LEFT, %d0
34: move.b %d0, PJ_DIR(%a4, %d7.w)
    move.b #BOOMERANG_QSPEED, PJ_QX(%a4, %d7.w)
    bra 36f
35: moveq #DIR_DOWN, %d0
    tst.w %d3
    bpl 37f
    moveq #DIR_UP, %d0
37: move.b %d0, PJ_DIR(%a4, %d7.w)
    move.b #BOOMERANG_QSPEED, PJ_QY(%a4, %d7.w)
36: bsr proj_move
    bra 60f

40: | A fireball hangs about for a moment, then flies until a wall stops it.
    tst.b PJ_TIMER(%a4, %d7.w)
    beq 41f
    subq.b #1, PJ_TIMER(%a4, %d7.w)
    bra 8f
41: bsr proj_move
    tst.w %d0
    beq 42f
    clr.b PJ_KIND(%a4, %d7.w)
    bra 8f
42: move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    bne 60f
    move.b PJ_Y(%a4, %d7.w), %d0
    add.b PJ_OWNER(%a4, %d7.w), %d0         | fans out a pixel every other frame
    move.b %d0, PJ_Y(%a4, %d7.w)
    bra 60f

50: moveq #0, %d1
    move.b PJ_OWNER(%a4, %d7.w), %d1
    tst.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    bne 51f
    clr.b PJ_KIND(%a4, %d7.w)
    bra 8f
51: bsr boss_part_update
    bra 8f

60: bsr proj_hit_link
8:  addq.w #1, %d7
    cmp.w #MAX_PROJ, %d7
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| Move projectile d7 by its speeds. Returns d0.w = 1 when it reached the edge
| of the room (and stays inside it).
proj_move:
    movem.l %d1-%d4, -(%sp)
    moveq #0, %d4
    moveq #0, %d1
    move.b PJ_QX(%a4, %d7.w), %d1
    beq 5f
    moveq #0, %d2
    move.b PJ_FRACX(%a4, %d7.w), %d2
    add.w %d2, %d1
    move.w %d1, %d2
    and.w #63, %d2
    move.b %d2, PJ_FRACX(%a4, %d7.w)
    lsr.w #6, %d1
    moveq #0, %d3
    move.b PJ_X(%a4, %d7.w), %d3
    btst #1, PJ_DIR(%a4, %d7.w)
    beq 1f
    sub.w %d1, %d3
    bra 2f
1:  add.w %d1, %d3
2:  moveq #0, %d2
    move.b OFF_OBJ_LEFT(%a5), %d2
    cmp.w %d2, %d3
    bge 3f
    move.w %d2, %d3
    moveq #1, %d4
3:  move.b OFF_OBJ_RIGHT(%a5), %d2
    cmp.w %d2, %d3
    ble 4f
    move.w %d2, %d3
    moveq #1, %d4
4:  move.b %d3, PJ_X(%a4, %d7.w)
5:  moveq #0, %d1
    move.b PJ_QY(%a4, %d7.w), %d1
    beq 9f
    moveq #0, %d2
    move.b PJ_FRACY(%a4, %d7.w), %d2
    add.w %d2, %d1
    move.w %d1, %d2
    and.w #63, %d2
    move.b %d2, PJ_FRACY(%a4, %d7.w)
    lsr.w #6, %d1
    moveq #0, %d3
    move.b PJ_Y(%a4, %d7.w), %d3
    btst #3, PJ_DIR(%a4, %d7.w)
    beq 6f
    sub.w %d1, %d3
    bra 7f
6:  add.w %d1, %d3
7:  moveq #0, %d2
    move.b OFF_OBJ_UP(%a5), %d2
    cmp.w %d2, %d3
    bge 71f
    move.w %d2, %d3
    moveq #1, %d4
71: move.b OFF_OBJ_DOWN(%a5), %d2
    cmp.w %d2, %d3
    ble 72f
    move.w %d2, %d3
    moveq #1, %d4
72: move.b %d3, PJ_Y(%a4, %d7.w)
9:  move.w %d4, %d0
    movem.l (%sp)+, %d1-%d4
    rts

| Projectile d7 touching Link hurts him: a boomerang for a whole heart, then
| it turns back; a fireball for half a heart, and it is gone.
proj_hit_link:
    movem.l %d0-%d3, -(%sp)
    tst.b OFF_LINK_HURT(%a5)
    bne 9f
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    move.b PJ_KIND(%a4, %d7.w), %d3
    beq 9f
    cmp.b #PK_FIREBALL, %d3
    bne 1f
    tst.b PJ_TIMER(%a4, %d7.w)
    bne 9f                          | it does no harm until it starts to fly
1:  moveq #0, %d0
    move.b PJ_X(%a4, %d7.w), %d0
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    sub.w %d0, %d1
    bpl 2f
    neg.w %d1
2:  cmp.w #PROJ_RANGE, %d1
    bhs 9f
    moveq #0, %d2
    move.b PJ_Y(%a4, %d7.w), %d2
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w %d2, %d1
    bpl 3f
    neg.w %d1
3:  cmp.w #PROJ_RANGE, %d1
    bhs 9f
    bsr link_shove_from             | d0 = its X, d2 = its Y
    moveq #1, %d1
    cmp.b #PK_FIREBALL, %d3
    beq 4f
    moveq #2, %d1
4:  movem.l %d7/%a4, -(%sp)
    bsr hurt_link
    movem.l (%sp)+, %d7/%a4
    move.b PJ_KIND(%a4, %d7.w), %d3
    beq 9f                          | dying wipes the room's projectiles
    cmp.b #PK_FIREBALL, %d3
    bne 5f
    clr.b PJ_KIND(%a4, %d7.w)
    bra 9f
5:  move.b #PK_RETURNING, PJ_KIND(%a4, %d7.w)
9:  movem.l (%sp)+, %d0-%d3
    rts

erase_projectiles:
    movem.l %d0/%d3/%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    moveq #0, %d3
1:  tst.b PJ_ERASE_VALID(%a4, %d3.w)
    beq 2f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l PJ_ERASE_OFFSETS(%a4, %d0.w), %d0
    bsr erase_at
    clr.b PJ_ERASE_VALID(%a4, %d3.w)
2:  addq.w #1, %d3
    cmp.w #MAX_PROJ, %d3
    blo 1b
    movem.l (%sp)+, %d0/%d3/%a4
    rts

draw_projectiles:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    moveq #0, %d7
1:  moveq #0, %d0
    move.b PJ_KIND(%a4, %d7.w), %d0
    beq 8f
    cmp.b #PK_PART, %d0
    beq 5f
    move.w OFF_FRAME_COUNTER(%a5), %d1
    lsr.w #2, %d1
    cmp.b #PK_FIREBALL, %d0
    beq 4f
    and.w #3, %d1                   | a boomerang spins
    move.w %d1, %d0
    bra 6f
4:  and.w #1, %d1
    add.w #PF_FIREBALL, %d1
    move.w %d1, %d0
    bra 6f
5:  moveq #0, %d0
    move.b PJ_TIMER(%a4, %d7.w), %d0
    cmp.w #PF_HIDDEN, %d0
    beq 8f
6:  mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab proj_sprites, %a0
    adda.l %d0, %a0
    moveq #0, %d1
    move.b PJ_X(%a4, %d7.w), %d1
    moveq #0, %d2
    move.b PJ_Y(%a4, %d7.w), %d2
    bsr sprite_offset
    tst.w %d4
    bmi 8f
    move.w %d7, %d0
    lsl.w #2, %d0
    move.l %d1, PJ_ERASE_OFFSETS(%a4, %d0.w)
    move.b #1, PJ_ERASE_VALID(%a4, %d7.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
8:  addq.w #1, %d7
    cmp.w #MAX_PROJ, %d7
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| The boss's head is drawn here rather than from mon_sprites. d3 = monster.
draw_boss_head:
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    move.w %d3, %d5
    moveq #0, %d0
    bsr boss_frame
    cmp.w #PF_HIDDEN, %d0
    beq 9f
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab proj_sprites, %a0
    adda.l %d0, %a0
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d2
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.w %d3, %d0
    lsl.w #2, %d0
    lea OFF_ENEMY_ERASE_OFFSETS(%a5), %a1
    move.l %d1, 0(%a1, %d0.w)
    move.b #1, OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d5/%a0-%a1
    rts

| ----------------------------------------------------------------------- keese
| Keese fly over everything, in eight directions, in the way ControlKeeseFlight
| does: speed up to $C0, then at random chase Link, wander or slow right down to
| a stop for a while, and start again. ENEMY_STATE is the flying state (0 speed
| up, 1 decide, 2 chase, 3 wander, 4 slow down, 5 rest), ENEMY_TIMER the delay
| before the next turn or the end of a rest, ENEMY_STEP the turns still to make.
keese_dirs:
    .byte 8, 9, 1, 5, 4, 6, 2, 10
    .align 2

keese_ai:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    lea OFF_ENEMY_SPEED(%a5), %a0
    lea OFF_ENEMY_FRAC(%a5), %a1
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 0f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
0:  moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    beq 10f
    cmp.b #1, %d0
    beq 20f
    cmp.b #2, %d0
    beq 30f
    cmp.b #3, %d0
    beq 40f
    cmp.b #4, %d0
    beq 11f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)       | resting
    bne 60f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
10: addq.b #1, 0(%a0, %d5.w)
    bra 12f
11: subq.b #1, 0(%a0, %d5.w)
12: move.b 0(%a0, %d5.w), %d1
    and.b #0xe0, %d1
    bne 13f
    bsr rand8                               | too slow to fly: rest for $40 to $7F frames
    and.b #0x3f, %d0
    or.b #0x40, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
    move.b #5, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
13: cmp.b #0xc0, %d1
    blo 60f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
20: bsr rand8
    moveq #2, %d1
    cmp.b #0xa0, %d0
    bhs 21f
    moveq #3, %d1
    cmp.b #0x20, %d0
    bhs 21f
    moveq #4, %d1
21: move.b %d1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #6, OFF_ENEMY_STEP(%a5, %d5.w)
    bra 60f
30: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 60f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 31f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
31: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr keese_turn_to_link
    bra 60f
40: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 60f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 41f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
41: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr keese_turn_random
60: moveq #0, %d1                           | a pixel whenever the speed fills the fraction
    move.b 0(%a0, %d5.w), %d1
    and.b #0xe0, %d1
    moveq #0, %d2
    move.b 0(%a1, %d5.w), %d2
    add.w %d1, %d2
    move.b %d2, 0(%a1, %d5.w)
    cmp.w #0x100, %d2
    blo 99f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    btst #0, %d4
    beq 61f
    addq.w #1, %d2
61: btst #1, %d4
    beq 62f
    subq.w #1, %d2
62: btst #2, %d4
    beq 63f
    addq.w #1, %d3
63: btst #3, %d4
    beq 64f
    subq.w #1, %d3
64: moveq #0, %d1                           | bounce off the walls of the room
    move.b OFF_OBJ_LEFT(%a5), %d1
    cmp.w %d1, %d2
    bge 65f
    move.w %d1, %d2
    eori.b #3, %d4
65: move.b OFF_OBJ_RIGHT(%a5), %d1
    cmp.w %d1, %d2
    ble 66f
    move.w %d1, %d2
    eori.b #3, %d4
66: move.b OFF_OBJ_UP(%a5), %d1
    cmp.w %d1, %d3
    bge 67f
    move.w %d1, %d3
    eori.b #12, %d4
67: move.b OFF_OBJ_DOWN(%a5), %d1
    cmp.w %d1, %d3
    ble 68f
    move.w %d1, %d3
    eori.b #12, %d4
68: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
99: movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| Returns d0.w = where the keese's direction sits in keese_dirs.
keese_ring_index:
    movem.l %d1/%a0, -(%sp)
    lea keese_dirs(%pc), %a0
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    moveq #7, %d0
1:  cmp.b 0(%a0, %d0.w), %d1
    beq 9f
    dbra %d0, 1b
    moveq #0, %d0
9:  movem.l (%sp)+, %d1/%a0
    rts

| d0.w = a place in keese_dirs (wrapping round): face that way.
keese_set_ring:
    move.l %a0, -(%sp)
    and.w #7, %d0
    lea keese_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    movea.l (%sp)+, %a0
    rts

| Mostly carry on, sometimes turn a notch to one side or the other.
keese_turn_random:
    movem.l %d0-%d1, -(%sp)
    bsr keese_ring_index
    move.w %d0, %d1
    bsr rand8
    cmp.b #0xa0, %d0
    bhs 9f
    cmp.b #0x50, %d0
    blo 1f
    addq.w #1, %d1
    bra 2f
1:  subq.w #1, %d1
2:  move.w %d1, %d0
    bsr keese_set_ring
9:  movem.l (%sp)+, %d0-%d1
    rts

| Turn a notch towards Link.
keese_turn_to_link:
    movem.l %d0-%d4/%a0, -(%sp)
    moveq #0, %d3
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    cmp.w %d1, %d0
    beq 1f
    bhi 11f
    moveq #DIR_LEFT, %d3
    bra 1f
11: moveq #DIR_RIGHT, %d3
1:  moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    cmp.w %d1, %d0
    beq 2f
    bhi 21f
    or.b #DIR_UP, %d3
    bra 2f
21: or.b #DIR_DOWN, %d3
2:  tst.b %d3
    beq 9f
    lea keese_dirs(%pc), %a0
    moveq #7, %d4
3:  cmp.b 0(%a0, %d4.w), %d3
    beq 4f
    dbra %d4, 3b
    bra 9f
4:  bsr keese_ring_index
    sub.w %d0, %d4
    and.w #7, %d4
    beq 9f
    cmp.w #4, %d4
    bhi 5f
    addq.w #1, %d0
    bra 6f
5:  subq.w #1, %d0
6:  bsr keese_set_ring
9:  movem.l (%sp)+, %d0-%d4/%a0
    rts

| ----------------------------------------------------------------------- traps
| A blade trap waits in its corner (or the middle of a side wall) until Link is
| level with it, then flies at him as far as the room's middle line and creeps
| back, as UpdateTrap_Full does. ENEMY_STATE: 0 waiting, 1 flying out at $70/64
| of a pixel a frame, 2 coming home at $20/64. ENEMY_STEP is the coordinate it
| started from, ENEMY_FRAC the fraction of a pixel carried over.
    .equ TRAP_OUT_SPEED, 0x70
    .equ TRAP_BACK_SPEED, 0x20
    .equ TRAP_SENSE, 0x0e
    .equ TRAP_MIDDLE_X, 0x78
    .equ TRAP_MIDDLE_Y, 0x90
    .equ TRAP_STOP, 5

trap_ai:
    movem.l %d0-%d4/%d6/%a0, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 5f

    moveq #0, %d1                   | waiting: is Link level with it, either way?
    move.b OFF_LINK_Y(%a5), %d1
    sub.w %d3, %d1
    bpl 1f
    neg.w %d1
1:  cmp.w #TRAP_SENSE, %d1
    bhs 2f
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    cmp.w %d2, %d1
    beq 2f
    bhi 12f
    moveq #DIR_LEFT, %d4
    bra 13f
12: moveq #DIR_RIGHT, %d4
13: move.w %d2, %d1
    bra 4f
2:  moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    sub.w %d2, %d1
    bpl 21f
    neg.w %d1
21: cmp.w #TRAP_SENSE, %d1
    bhs 9f
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    cmp.w %d3, %d1
    beq 9f
    bhi 22f
    moveq #DIR_UP, %d4
    bra 23f
22: moveq #DIR_DOWN, %d4
23: move.w %d3, %d1
4:  move.b %d1, OFF_ENEMY_STEP(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
    lea trap_dirs(%pc), %a0
    and.b 0(%a0, %d5.w), %d4        | each trap only goes the ways its corner allows
    beq 9f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bra 9f

5:  moveq #TRAP_OUT_SPEED, %d0      | flying out or coming home
    cmpi.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 51f
    moveq #TRAP_BACK_SPEED, %d0
51: lea OFF_ENEMY_FRAC(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d5.w), %d1
    add.w %d1, %d0
    move.w %d0, %d1
    and.w #63, %d1
    move.b %d1, 0(%a0, %d5.w)
    lsr.w #6, %d0                   | whole pixels this frame
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    btst #0, %d4
    beq 52f
    add.w %d0, %d2
    bra 6f
52: btst #1, %d4
    beq 53f
    sub.w %d0, %d2
    bra 6f
53: btst #2, %d4
    beq 54f
    add.w %d0, %d3
    bra 6f
54: sub.w %d0, %d3
6:  move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.w %d2, %d1                 | the coordinate it travels along, and where it is bound
    move.w #TRAP_MIDDLE_X, %d0
    and.b #(DIR_UP + DIR_DOWN), %d4
    beq 61f
    move.w %d3, %d1
    move.w #TRAP_MIDDLE_Y, %d0
61: cmpi.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    beq 7f
    sub.w %d0, %d1
    bpl 62f
    neg.w %d1
62: cmp.w #TRAP_STOP, %d1
    bhs 9f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d6
    bsr opposite_dir
    move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bra 9f
7:  moveq #0, %d0                   | home again (or past it): settle exactly on the start
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    move.b %d4, %d6
    and.b #(DIR_LEFT + DIR_UP), %d6
    bne 71f
    cmp.w %d0, %d1
    blo 9f
    bra 72f
71: cmp.w %d0, %d1
    bhi 9f
72: clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    and.b #(DIR_UP + DIR_DOWN), %d4
    bne 73f
    move.b %d0, OFF_ENEMY_X(%a5, %d5.w)
    bra 9f
73: move.b %d0, OFF_ENEMY_Y(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%d6/%a0
    rts

| TrapXs, TrapYs (together) and TrapAllowedDirs.
trap_xs:
    .byte 0x20, 0x20, 0xd0, 0xd0, 0x40, 0xb0
    .byte 0x5d, 0xbd, 0x5d, 0xbd, 0x8d, 0x8d
trap_dirs:
    .byte 0x05, 0x09, 0x06, 0x0a, 0x01, 0x02
    .align 2