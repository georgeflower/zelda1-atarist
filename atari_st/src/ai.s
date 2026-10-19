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
    .equ BEH_GEL, 7
    .equ BEH_OCTOROK, 8
    .equ BEH_MOBLIN, 9
    .equ BEH_LYNEL, 10
    .equ BEH_OCTOROK_BLUE, 11
    .equ BEH_TEKTITE, 12            | the movers of movers.s
    .equ BEH_LEEVER, 13
    .equ BEH_ZORA, 14
    .equ BEH_PEAHAT, 15
    .equ BEH_GHINI, 16
    .equ BEH_BOULDER, 17
    .equ BEH_BOULDER_SET, 18
    .equ BEH_DODONGO, 19            | Dodongo and Moldorm are handled before the movers' test
    .equ BEH_MOLDORM, 20
    .equ BEH_POLS, 21               | the dungeon monsters of dmon.s (they pass through mover_update)
    .equ BEH_WIZZROBE, 22
    .equ BEH_BUBBLE, 23
    .equ BEH_MANHANDLA, 24
    .equ BEH_GOHMA, 25
    .equ BEH_DIGDOGGER, 26
    .equ BEH_GLEEOK, 27
    .equ BEH_GLEEOK_HEAD, 28
    .equ BEH_GLEEOK_FLYER, 29
    .equ BEH_LANMOLA, 30
    .equ BEH_PATRA, 31
    .equ BEH_PATRA_CHILD, 32
    .equ BEH_GANON, 33
    .equ BEH_ZELDA, 34
    .equ BEH_FIRE, 35               | the fires that guard Zelda
    .equ MODE_DODONGO, 16           | draw modes (tools/actors.py MODE_*)
    .equ MODE_MOLDORM, 17

    .equ ENEMY_SHOVE_FRAMES, 16     | 64 pixels at 4 a frame
    .equ MAX_PROJ, 8
    .equ PK_BOOMERANG, 1            | flying out
    .equ PK_RETURNING, 2            | coming back to the goriya
    .equ PK_FIREBALL, 3
    .equ PK_PART, 4                 | a piece of Aquamentus
    .equ PK_LBOOM, 5                | Link's boomerang: flying out
    .equ PK_LBOOM_SPARK, 6          | it hit a wall, or reached its limit
    .equ PK_LBOOM_SLOW, 7           | and hangs about
    .equ PK_LBOOM_BACK, 8           | on its way back to Link
    .equ PK_ROCK, 9                 | an octorok's rock
    .equ PK_ARROW, 10               | a moblin's arrow
    .equ PK_SWORDSHOT, 11           | a lynel's sword shot
    .equ PK_LARROW, 12              | Link's arrow
    .equ PK_LARROW_SPARK, 13        | it struck something
    .equ PK_LMAGIC, 14              | the rod's magic shot

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

    .equ PF_BOOM_SPARK, 8           | frames in proj_sprites: 0-7 the boomerang turning, 8 its spark
    .equ PF_FIREBALL, 9
    .equ PF_BOSS, 11
    .equ PF_ROCK, 27                | after the 16 boss pieces: the rock, then four arrows (up, down, left, right)
    .equ PF_ARROW, 28
    .equ SHOT_LIMIT, 4              | ActiveMonsterShots
    .equ SHOT_SPEED, 192            | a rock or sword shot flies 3 pixels a frame, an arrow 2
    .equ ARROW_SPEED, 128
    .equ SHOT_BOUNCE_FRAMES, 16     | a parried shot is pushed back 2 pixels a frame for this long
    .equ SHOOT_TIME, 0x30
    .equ SHOOT_AT, 0x10
    .equ PF_HIDDEN, 0xff

    .equ BOOM_SPEED, 3              | pixels a frame out, two coming back
    .equ BOOM_MAGIC_FRAMES, 85
    .equ BOOM_OUT_FRAMES, 17        | about 49 pixels, the wooden boomerang's reach
    .equ BOOM_SPARK_FRAMES, 3
    .equ BOOM_SLOW_FRAMES, 16
    .equ BOOM_BACK_SPEED, 2
    .equ BOOM_HIT_RANGE, 11
    .equ STUN_FRAMES, 160           | ObjStunTimer $10, counted every tenth frame

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
    and.w #0xff, %d0                | (the index was shifted into the high byte: 32 monsters and more)
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
    cmpi.b #MON_RED_KEESE, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 51f
    move.b #0x7f, 0(%a0, %d5.w)     | a red one is quicker off the mark
51: lea OFF_ENEMY_FRAC(%a5), %a0
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
    bne 7f
    lea trap_xs(%pc), %a0           | where InitTrap_Full puts the traps
    move.b 0(%a0, %d5.w), OFF_ENEMY_X(%a5, %d5.w)
    move.b 6(%a0, %d5.w), OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)     | alive for good: it never counts as a monster of the room
    bra 9f
7:  cmp.w #BEH_DODONGO, %d0
    bne 71f
    bsr rand8                       | InitDodongo: face left or right at random
    moveq #DIR_RIGHT, %d1
    cmp.b #0x80, %d0
    blo 70f
    moveq #DIR_LEFT, %d1
70: move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    lea OFF_ENEMY_WANT(%a5), %a0
    clr.b 0(%a0, %d5.w)             | no bombs swallowed yet
    bra 9f
71: cmp.w #BEH_MOLDORM, %d0
    bne 72f
    bsr moldorm_init
    bra 9f
72: cmp.w #BEH_TEKTITE, %d0
    blo 9f
    cmp.w #BEH_POLS, %d0
    blo 73f
    bsr dmon_init
    bra 9f
73: bsr mover_init
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
    and.b #15, %d0
    bne 9f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b %d3, %d0
    and.b #15, %d0
    cmp.b #13, %d0
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

| ------------------------------------------------------------ wandering
| Z_04.asm Wanderer_TargetPlayer. At every square boundary a wanderer rolls
| against its turn rate: with a roll at or under it, a monster level with
| Link (within 8 pixels across or along) turns straight toward him; otherwise,
| or when it is not level, it turns toward him sideways once its turn timer has
| run out. Every turn sets the timer to a random value. Walls are dealt with
| by the caller (enemy_choose_dir). Stalfos use rate $80 and gels $20, so a
| stalfos closes in on Link and a gel mostly keeps going.

| A monster stands exactly on a square boundary. d5 = monster; returns d0.w = 1.
enemy_at_boundary:
    move.l %d1, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    and.b #15, %d1
    bne 9f
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    and.b #15, %d1
    cmp.b #13, %d1
    bne 9f
    moveq #1, %d0
9:  move.l (%sp)+, %d1
    rts

| d5 = monster, d1.w = turn rate. Runs the turn timer, then the turn.
wander_tick:
    movem.l %d0-%d4/%a0, -(%sp)
    move.w %d1, %d4
    lea OFF_ENEMY_TURN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 1f
    subq.b #1, 0(%a0, %d5.w)
1:  bsr enemy_at_boundary
    tst.w %d0
    beq 9f
    bsr rand8
    cmp.b %d0, %d4
    blo 5f                          | rolled over the rate: only the timer can turn it
    moveq #0, %d1
    move.b OFF_CHASE_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    sub.w %d2, %d1
    bpl 2f
    neg.w %d1
2:  cmp.w #9, %d1
    blo 20f                         | in his column: turn vertically
    moveq #0, %d1
    move.b OFF_CHASE_Y(%a5), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    sub.w %d2, %d1
    bpl 3f
    neg.w %d1
3:  cmp.w #9, %d1
    blo 30f                         | in his row: turn horizontally
5:  clr.b 8(%a0, %d5.w)             | not aiming at him
    tst.b 0(%a0, %d5.w)
    bne 9f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #DIR_VERTICAL, %d0
    bne 30f                         | it was going up or down: now sideways
20: moveq #DIR_UP, %d0              | toward Link, up or down
    move.b OFF_CHASE_Y(%a5), %d1
    cmp.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    blo 40f
    moveq #DIR_DOWN, %d0
    bra 40f
30: moveq #DIR_RIGHT, %d0           | toward Link, left or right
    move.b OFF_CHASE_X(%a5), %d1
    cmp.b OFF_ENEMY_X(%a5, %d5.w), %d1
    bhs 40f
    moveq #DIR_LEFT, %d0
40: move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr rand8
    move.b %d0, 0(%a0, %d5.w)       | the next turn comes when this runs out
    move.b #1, 8(%a0, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%a0
    rts

| ------------------------------------------------------------------ gels
| UpdateNormalZolOrGel: a gel crosses a square at a pixel a frame and then
| rests at its edge for $08, $18, $28 or $38 frames (ENEMY_TIMER), turning at
| rate $20. d5 = monster. Returns d0.w = 1 while it rests.
gel_ai:
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 1f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
1:  moveq #1, %d0
    cmpi.b #5, OFF_ENEMY_TIMER(%a5, %d5.w)
    bhs 9f
    move.w #0x20, %d1
    bsr wander_tick
    moveq #0, %d0
9:  rts

| After a gel has stepped: at a square boundary with nothing running it rests.
gel_pause:
    movem.l %d0/%a0, -(%sp)
    bsr enemy_behaviour
    cmp.w #BEH_GEL, %d0
    bne 9f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f
    bsr enemy_at_boundary
    tst.w %d0
    beq 9f
    bsr rand8
    and.w #3, %d0
    lea gel_delays(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_TIMER(%a5, %d5.w)
9:  movem.l (%sp)+, %d0/%a0
    rts

gel_delays:
    .byte 0x08, 0x18, 0x28, 0x38
    .align 2

| ---------------------------------------------------------------------- rope
| UpdateRope: whenever its timer (a random 0 to $3F frames) has run out and
| it is not charging, a rope on a square boundary turns to a free side: a
| random one of the two across, the other, then straight back, never ahead.
rope_turn:
    movem.l %d0/%a0, -(%sp)
    lea OFF_ENEMY_TURN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 1f
    subq.b #1, 0(%a0, %d5.w)
    bra 9f
1:  tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 9f                          | charging
    bsr rand8
    and.b #0x3f, %d0
    move.b %d0, 0(%a0, %d5.w)
    bsr enemy_at_boundary
    tst.w %d0
    beq 9f
    bsr enemy_face_unblocked
9:  movem.l (%sp)+, %d0/%a0
    rts

| d5 = monster on a square boundary: face the first free way of Walker_GetNextAltDir.
enemy_face_unblocked:
    movem.l %d0-%d4/%d6, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #0, %d1
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    bsr rand8
    and.w #1, %d0
    moveq #0, %d6
    move.b %d1, %d6
    and.b #DIR_VERTICAL, %d6
    bne 1f
    moveq #DIR_DOWN, %d6            | going sideways: up or down, at random
    bra 2f
1:  moveq #DIR_RIGHT, %d6           | going up or down: left or right
2:  lsl.b %d0, %d6
    move.w %d6, %d4
    bsr enemy_cell_blocked
    tst.w %d0
    beq 8f
    move.w %d4, %d6
    bsr opposite_dir                | the other side
    move.w %d6, %d4
    bsr enemy_cell_blocked
    tst.w %d0
    beq 8f
    move.w %d1, %d6
    bsr opposite_dir                | straight back
    move.w %d6, %d4
    bsr enemy_cell_blocked
    tst.w %d0
    bne 9f
8:  move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%d6
    rts

| -------------------------------------------------------------------- goriya
| UpdateGoriya. At every square boundary a goriya with Link within $51 pixels
| along the longer of the two ways turns to face him and wants to throw its
| boomerang; otherwise it keeps its heading and only turns at walls. A red
| goriya acts on the wish only when its roll comes up $23 or $77, two frames
| in 256, and not before its timer has run out; a blue one (type $05) throws as
| soon as its timer allows. After a throw it stands still until the boomerang is back.
|
| d5 = monster. Returns d0.w = 1 while it must not move.
goriya_ai:
    movem.l %d1-%d4/%a0, -(%sp)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 1f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
1:  tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 8f                          | its boomerang is out
    lea OFF_ENEMY_TURN(%a5), %a0
    bsr enemy_at_boundary
    tst.w %d0
    beq 6f                          | between squares: the wish stays as it was
    clr.b 8(%a0, %d5.w)
    moveq #0, %d1
    move.b OFF_CHASE_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    sub.w %d2, %d1                  | d1 = how far right of the goriya Link is
    moveq #0, %d3
    move.b OFF_CHASE_Y(%a5), %d3
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    sub.w %d2, %d3                  | d3 = how far below
    move.w %d1, %d2
    bpl 2f
    neg.w %d2
2:  move.w %d3, %d4
    bpl 3f
    neg.w %d4
3:  cmp.w %d2, %d4                  | the longer way decides the direction
    blo 5f
    cmp.w #BOOMERANG_RANGE, %d4
    bhs 6f
    moveq #DIR_UP, %d2
    tst.w %d3
    bmi 7f
    moveq #DIR_DOWN, %d2
    bra 7f
5:  cmp.w #BOOMERANG_RANGE, %d2
    bhs 6f
    moveq #DIR_LEFT, %d2
    tst.w %d1
    bmi 7f
    moveq #DIR_RIGHT, %d2
7:  move.b %d2, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #1, 8(%a0, %d5.w)
6:  tst.b 8(%a0, %d5.w)
    beq 9f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f
    bsr enemy_behaviour
    cmp.w #BEH_LYNEL, %d0
    beq 9f                          | a lynel does not throw
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    lsl.w #3, %d0
    ltab mon_table, %a0
    cmpi.b #0x05, 0(%a0, %d0.w)
    beq 4f                          | a blue goriya throws whenever it wants and its timer allows
    bsr rand8
    cmp.b #0x23, %d0
    beq 4f
    cmp.b #0x77, %d0
    bne 9f
4:  bsr goriya_throw
9:  moveq #0, %d0
    movem.l (%sp)+, %d1-%d4/%a0
    rts
8:  moveq #1, %d0
    movem.l (%sp)+, %d1-%d4/%a0
    rts

goriya_throw:
    movem.l %d0-%d1/%a4, -(%sp)
    bsr proj_alloc
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
    lea OFF_ENEMY_TURN(%a5), %a4
    clr.b 8(%a4, %d5.w)             | the wish is spent
    bsr rand8
    and.b #0x3f, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)     | and it waits this long before the next throw
9:  movem.l (%sp)+, %d0-%d1/%a4
    rts

| ------------------------------------------------------- overworld shooters
| _TryShooting. An octorok, moblin or lynel that wants to shoot (it has turned toward Link, see
| wander_tick and goriya_ai) starts a $30-frame pause, standing still, and shoots at $10 if it
| still wants to. The blue ones (types 1, 3, 9, $A) start the pause as soon as they want to, the red
| ones only on a roll of $F8 or more. A monster that is hurt does not shoot. A rock flies as an
| octorok's, an arrow as a moblin's, a sword shot as a lynel's; at most SHOT_LIMIT are in the air.
|
| d5 = monster. Returns d0.w = 1 while it must stand still.
walker_shoot:
    movem.l %d1-%d4/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    lsl.w #3, %d0
    ltab mon_table, %a2
    move.b 0(%a2, %d0.w), %d2       | the monster's NES type
    lea OFF_ENEMY_SHOOT(%a5), %a1
    lea OFF_ENEMY_TURN(%a5), %a0
    cmp.b #1, %d2
    beq 1f
    cmp.b #3, %d2
    beq 1f
    cmp.b #9, %d2
    beq 1f
    cmp.b #10, %d2
    beq 1f
    tst.b 0(%a1, %d5.w)
    bne 1f                          | already in the middle of one
    bsr rand8
    cmp.b #0xf8, %d0
    blo 8f
1:  moveq #0, %d1
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 2f
    move.b 0(%a1, %d5.w), %d1
    subq.w #1, %d1
    bpl 2f
    tst.b 8(%a0, %d5.w)
    beq 8f
    moveq #SHOOT_TIME, %d1
2:  move.b %d1, 0(%a1, %d5.w)
    beq 8f
    cmp.b #SHOOT_AT, %d1
    bne 7f
    lea OFF_ENEMY_STUN(%a5), %a1
    tst.b 0(%a1, %d5.w)
    bne 7f
    bsr walker_fire
    tst.w %d0
    beq 8f
    clr.b 8(%a0, %d5.w)
7:  moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d4/%a0-%a2
    rts

| d5 = the shooter. Launches its shot in the direction it faces from where it stands. Returns
| d0.w = 1 if there was room for one.
walker_fire:
    movem.l %d1-%d3/%a0/%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    moveq #0, %d1                   | shots already in the air
    moveq #0, %d2
1:  move.b PJ_KIND(%a4, %d2.w), %d3
    cmp.b #PK_ROCK, %d3
    blo 2f
    cmp.b #PK_SWORDSHOT, %d3
    bhi 2f                          | Link's own shots do not count
    addq.w #1, %d1
2:  addq.w #1, %d2
    cmp.w #MAX_PROJ, %d2
    blo 1b
    cmp.w #SHOT_LIMIT, %d1
    bhs 8f
    bsr enemy_behaviour             | which shot is the monster's own?
    move.w #SHOT_SPEED, %d2
    moveq #PK_ROCK, %d1
    cmp.w #BEH_MOBLIN, %d0
    bne 3f
    moveq #PK_ARROW, %d1
    move.w #ARROW_SPEED, %d2
    bra 4f
3:  cmp.w #BEH_LYNEL, %d0
    beq 31f
    cmp.w #BEH_WIZZROBE, %d0            | a wizzrobe's magic flies like the lynel's sword shot
    bne 4f
31: moveq #PK_SWORDSHOT, %d1
4:  bsr proj_alloc
    tst.w %d0
    bmi 8f
    move.b %d1, PJ_KIND(%a4, %d0.w)
    clr.b PJ_OWNER(%a4, %d0.w)          | 2 marks the red wizzrobe's, which costs four hearts
    cmpi.b #MON_WIZ_RED, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 41f
    move.b #2, PJ_OWNER(%a4, %d0.w)
41:
    move.b OFF_ENEMY_X(%a5, %d5.w), PJ_X(%a4, %d0.w)
    move.b OFF_ENEMY_Y(%a5, %d5.w), PJ_Y(%a4, %d0.w)
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d3
    move.b %d3, PJ_DIR(%a4, %d0.w)
    clr.b PJ_FRACX(%a4, %d0.w)
    clr.b PJ_FRACY(%a4, %d0.w)
    clr.b PJ_QX(%a4, %d0.w)
    clr.b PJ_QY(%a4, %d0.w)
    clr.b PJ_TIMER(%a4, %d0.w)
    and.b #DIR_VERTICAL, %d3
    bne 6f
    move.b %d2, PJ_QX(%a4, %d0.w)
    bra 7f
6:  move.b %d2, PJ_QY(%a4, %d0.w)
7:  moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d3/%a0/%a4
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
    bsr fireball_aim
    moveq #0, %d4
    bsr boss_spawn_fireball
    moveq #1, %d4
    bsr boss_spawn_fireball
    moveq #-1, %d4
    bsr boss_spawn_fireball
    movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0
    rts

| A zora spits a single fireball at Link.
zora_fire:
    movem.l %d0-%d4/%d6-%d7/%a0, -(%sp)
    bsr fireball_aim
    moveq #0, %d4
    bsr boss_spawn_fireball
    movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0
    rts

| The way from monster d5's mouth to Link: d3 = the directions, d6 = horizontal and d7 = vertical speed.
fireball_aim:
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
    cmp.b #PK_LARROW, %d0
    blo 0f
    bsr lshot_update                | Link's arrow or magic shot
    bra 8f
0:  cmp.b #PK_ROCK, %d0
    bhs 70f
    cmp.b #PK_LBOOM, %d0
    blo 0f
    bsr link_boom_update
    bra 8f
0:  cmp.b #PK_FIREBALL, %d0
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
    bra 8f

70: | A monster's shot (rock, arrow, sword shot). Parried, it is pushed back and fades.
    tst.b PJ_TIMER(%a4, %d7.w)
    bne 75f
    bsr proj_move
    tst.w %d0
    bne 79f                         | the edge of the room
    cmpi.b #PK_SWORDSHOT, PJ_KIND(%a4, %d7.w)
    beq 60b                         | a sword shot flies through walls
    bsr shot_blocked
    tst.w %d0
    bne 79f                         | rocks and arrows stop at a wall
    bra 60b
75: addq.b #1, PJ_TIMER(%a4, %d7.w)
    cmpi.b #(SHOT_BOUNCE_FRAMES + 1), PJ_TIMER(%a4, %d7.w)
    bhs 79f
    moveq #0, %d2
    move.b PJ_X(%a4, %d7.w), %d2
    moveq #0, %d3
    move.b PJ_Y(%a4, %d7.w), %d3
    move.b PJ_OWNER(%a4, %d7.w), %d1    | the way Link faced
    btst #0, %d1
    beq 76f
    addq.w #2, %d2
76: btst #1, %d1
    beq 77f
    subq.w #2, %d2
77: btst #2, %d1
    beq 78f
    addq.w #2, %d3
78: btst #3, %d1
    beq 72f
    subq.w #2, %d3
72: moveq #0, %d0
    move.b OFF_OBJ_LEFT(%a5), %d0
    cmp.w %d0, %d2
    blt 79f
    move.b OFF_OBJ_RIGHT(%a5), %d0
    cmp.w %d0, %d2
    bgt 79f
    move.b OFF_OBJ_UP(%a5), %d0
    cmp.w %d0, %d3
    blt 79f
    move.b OFF_OBJ_DOWN(%a5), %d0
    cmp.w %d0, %d3
    bgt 79f
    move.b %d2, PJ_X(%a4, %d7.w)
    move.b %d3, PJ_Y(%a4, %d7.w)
    bra 8f
79: clr.b PJ_KIND(%a4, %d7.w)
8:  addq.w #1, %d7
    cmp.w #MAX_PROJ, %d7
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| Is the tile a rock or arrow (projectile d7) has run into a wall? Like Link's shot, the leading
| edge counts: 8 pixels past the origin going right or down. Returns d0.w = 1 when blocked.
shot_blocked:
    movem.l %d1-%d3, -(%sp)
    moveq #0, %d2
    move.b PJ_X(%a4, %d7.w), %d2
    moveq #0, %d3
    move.b PJ_Y(%a4, %d7.w), %d3
    move.b PJ_DIR(%a4, %d7.w), %d1
    btst #0, %d1
    beq 1f
    addq.w #8, %d2
1:  btst #2, %d1
    beq 2f
    addq.w #8, %d3
2:  bsr enemy_blocked_at
    movem.l (%sp)+, %d1-%d3
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
    tst.b OFF_INV_CLOCK(%a5)
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
    cmp.b #PK_ROCK, %d3
    bhs shot_meets_link
    cmp.b #PK_FIREBALL, %d3
    bne 31f
    tst.b OFF_INV_MAGIC_SHIELD(%a5) | the magic shield stops fireballs too
    bne shot_meets_link
31: bsr link_shove_from             | d0 = its X, d2 = its Y
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

| A monster's shot (d3 = its kind) has reached Link, who is not invincible. Rocks and arrows
| bounce off him when he stands idle facing them; anything else costs hearts (a rock or
| arrow half a heart, a sword shot two) and is gone.
shot_meets_link:
    tst.b OFF_ATTACK(%a5)
    bne 5f                          | not idle: no parrying
    cmp.b #PK_ROCK, %d3
    bhs 51f
    cmp.b #PK_FIREBALL, %d3
    bne 5f
    bra 52f                         | (a fireball only gets here with the shield)
51: cmp.b #PK_SWORDSHOT, %d3
    bne 52f
    tst.b OFF_INV_MAGIC_SHIELD(%a5)
    beq 5f                          | only the magic shield stops a sword shot
52:
    move.b OFF_LINK_DIR(%a5), %d1
    or.b PJ_DIR(%a4, %d7.w), %d1
    and.b #0x0c, %d1
    cmp.b #0x0c, %d1
    beq 4f
    move.b OFF_LINK_DIR(%a5), %d1
    or.b PJ_DIR(%a4, %d7.w), %d1
    and.b #0x03, %d1
    cmp.b #0x03, %d1
    bne 5f                          | not facing each other
4:  sfx SFX_PARRY
    cmp.b #PK_FIREBALL, %d3
    bne 41f
    clr.b PJ_KIND(%a4, %d7.w)       | a fireball just goes out
    bra 9f
41: move.b OFF_LINK_DIR(%a5), PJ_OWNER(%a4, %d7.w)  | the way it is pushed back
    move.b #1, PJ_TIMER(%a4, %d7.w)
    bra 9f
5:  bsr link_shove_from
    moveq #1, %d1
    cmp.b #PK_SWORDSHOT, %d3
    bne 6f
    moveq #4, %d1
    cmpi.b #2, PJ_OWNER(%a4, %d7.w)
    bne 6f
    moveq #8, %d1
6:  movem.l %d7/%a4, -(%sp)
    bsr hurt_link
    movem.l (%sp)+, %d7/%a4
    clr.b PJ_KIND(%a4, %d7.w)
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
    cmp.b #PK_LARROW, %d0
    blo 19f
    cmp.b #PK_LARROW_SPARK, %d0         | Link's arrow and magic shot borrow the monsters' pictures
    bne 18f
    moveq #PF_BOOM_SPARK, %d0
    bra 6f
18: bsr lshot_picture
    bra 20f
19: cmp.b #PK_ROCK, %d0
    bhs 20f
    cmp.b #PK_LBOOM_SPARK, %d0
    bne 3f
    moveq #PF_BOOM_SPARK, %d0
    bra 6f
3:  move.w OFF_FRAME_COUNTER(%a5), %d1
    cmp.b #PK_FIREBALL, %d0
    beq 4f
    lsr.w #1, %d1
    and.w #7, %d1                   | a boomerang spins: two frames to each turn
    move.w %d1, %d0
    bra 6f
4:  lsr.w #2, %d1
    and.w #1, %d1
    add.w #PF_FIREBALL, %d1
    move.w %d1, %d0
    bra 6f
20: | a monster's shot: which way it points picks the picture
    move.b PJ_DIR(%a4, %d7.w), %d3
    moveq #0, %d5                   | 0 up, 1 down, 2 left, 3 right
    btst #3, %d3
    bne 21f
    moveq #1, %d5
    btst #2, %d3
    bne 21f
    moveq #2, %d5
    btst #1, %d3
    bne 21f
    moveq #3, %d5
21: moveq #0, %d1
    move.b PJ_X(%a4, %d7.w), %d1
    moveq #0, %d2
    move.b PJ_Y(%a4, %d7.w), %d2
    cmp.b #PK_ROCK, %d0
    bne 22f
    move.w #PF_ROCK, %d0
    ltab proj_sprites, %a0
    bra 25f
22: cmp.w #2, %d5
    blo 23f
    addq.w #3, %d2                  | a sideways shot is drawn three pixels lower
23: cmp.b #PK_ARROW, %d0
    bne 24f
    move.w %d5, %d0
    add.w #PF_ARROW, %d0
    ltab proj_sprites, %a0
    bra 25f
24: move.w %d5, %d0                 | a sword shot: the beam's picture, a palette row a frame
    lsl.w #2, %d0
    move.w OFF_FRAME_COUNTER(%a5), %d3
    and.w #3, %d3
    add.w %d3, %d0
    ltab beam_sprites, %a0
25: mulu.w #SPRITE_FRAME_BYTES, %d0
    adda.l %d0, %a0
    bra 63f
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
63: bsr sprite_offset
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
64: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bsr flyer_bound                             | a bound of the room turns it right round (BoundFlyer)
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
    bra turn_towards8

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

| -------------------------------------------------------------- Link's boomerang
| Thrown the way Link faces from 16 pixels in front of him, it flies three
| pixels a frame for about 49 pixels, or until a wall stops it, sparks for
| three frames, hangs about at a pixel a frame, and then comes back to him.
| A monster it touches is stunned (or killed, if it has no hit points to speak
| of) and it turns back at once. Items it touches are picked up.
throw_boomerang:
    movem.l %d0-%d3/%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    moveq #(MAX_PROJ - 1), %d0
1:  move.b 0(%a4, %d0.w), %d1
    cmp.b #PK_LBOOM, %d1
    blo 2f
    cmp.b #PK_LBOOM_BACK, %d1
    bls 9f                          | only one at a time
2:  dbra %d0, 1b
    bsr proj_alloc
    tst.w %d0
    bmi 9f
    move.w %d0, %d3
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b OFF_LINK_DIR(%a5), %d0
    btst #0, %d0
    beq 2f
    add.w #16, %d1
    bra 5f
2:  btst #1, %d0
    beq 3f
    sub.w #16, %d1
    bra 5f
3:  btst #2, %d0
    beq 4f
    add.w #16, %d2
    bra 5f
4:  sub.w #16, %d2
5:  move.b #PK_LBOOM, PJ_KIND(%a4, %d3.w)
    move.b %d1, PJ_X(%a4, %d3.w)
    move.b %d2, PJ_Y(%a4, %d3.w)
    move.b %d0, PJ_DIR(%a4, %d3.w)
    moveq #BOOM_OUT_FRAMES, %d0
    tst.b OFF_INV_MAGIC_BOOMERANG(%a5)
    beq 6f
    moveq #BOOM_MAGIC_FRAMES, %d0       | BoomerangLimits: $31 for the wooden one, $FF for the magic one
6:  move.b %d0, PJ_TIMER(%a4, %d3.w)
    sfx SFX_ARROW
9:  movem.l (%sp)+, %d0-%d3/%a4
    rts

| Projectile d7 (kind d0) of the boomerang, a4 = PROJ_KIND.
link_boom_update:
    movem.l %d0-%d6, -(%sp)
    move.w %d0, %d5
    moveq #0, %d2
    move.b PJ_X(%a4, %d7.w), %d2
    moveq #0, %d3
    move.b PJ_Y(%a4, %d7.w), %d3
    moveq #0, %d6
    move.b PJ_DIR(%a4, %d7.w), %d6
    cmp.w #PK_LBOOM_BACK, %d5
    beq 50f
    cmp.w #PK_LBOOM_SPARK, %d5
    beq 40f

    moveq #BOOM_SPEED, %d4          | flying out, or hanging about
    cmp.w #PK_LBOOM_SLOW, %d5
    bne 11f
    moveq #1, %d4
11: btst #0, %d6
    beq 12f
    add.w %d4, %d2
    bra 15f
12: btst #1, %d6
    beq 13f
    sub.w %d4, %d2
    bra 15f
13: btst #2, %d6
    beq 14f
    add.w %d4, %d3
    bra 15f
14: sub.w %d4, %d3
15: move.w %d2, -(%sp)
    move.w %d3, -(%sp)
    btst #0, %d6                    | a wall is met by the leading edge
    beq 16f
    addq.w #8, %d2
16: btst #2, %d6
    beq 17f
    addq.w #8, %d3
17: bsr enemy_blocked_at
    move.w (%sp)+, %d3
    move.w (%sp)+, %d2
    tst.w %d0
    beq 19f
    cmp.w #PK_LBOOM_SLOW, %d5
    bne 30f                         | a wall stops it flying out; hanging about it just stays put
    bra 20f
19: move.b %d2, PJ_X(%a4, %d7.w)
    move.b %d3, PJ_Y(%a4, %d7.w)
20: subq.b #1, PJ_TIMER(%a4, %d7.w)
    bne 60f
    cmp.w #PK_LBOOM_SLOW, %d5
    beq 18f
30: move.b #PK_LBOOM_SPARK, PJ_KIND(%a4, %d7.w)
    move.b #BOOM_SPARK_FRAMES, PJ_TIMER(%a4, %d7.w)
    bra 60f
18: move.b #PK_LBOOM_BACK, PJ_KIND(%a4, %d7.w)
    bra 60f

40: subq.b #1, PJ_TIMER(%a4, %d7.w)
    bne 60f
    move.b #PK_LBOOM_SLOW, PJ_KIND(%a4, %d7.w)
    move.b #BOOM_SLOW_FRAMES, PJ_TIMER(%a4, %d7.w)
    bra 60f

50: moveq #0, %d0                   | back to Link, along both axes at once
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d2, %d0
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w %d3, %d1
    move.w %d0, %d4
    bpl 51f
    neg.w %d4
51: cmp.w #8, %d4
    bhi 53f
    move.w %d1, %d4
    bpl 52f
    neg.w %d4
52: cmp.w #8, %d4
    bhi 53f
    clr.b PJ_KIND(%a4, %d7.w)       | caught
    bra 9f
53: moveq #BOOM_BACK_SPEED, %d4
    tst.w %d0
    beq 54f
    bmi 55f
    cmp.w %d4, %d0
    bhs 56f
    move.w %d0, %d4
56: add.w %d4, %d2
    bra 54f
55: neg.w %d0
    moveq #BOOM_BACK_SPEED, %d4
    cmp.w %d4, %d0
    bhs 57f
    move.w %d0, %d4
57: sub.w %d4, %d2
54: moveq #BOOM_BACK_SPEED, %d4
    tst.w %d1
    beq 58f
    bmi 59f
    cmp.w %d4, %d1
    bhs 62f
    move.w %d1, %d4
62: add.w %d4, %d3
    bra 58f
59: neg.w %d1
    moveq #BOOM_BACK_SPEED, %d4
    cmp.w %d4, %d1
    bhs 63f
    move.w %d1, %d4
63: sub.w %d4, %d3
58: move.b %d2, PJ_X(%a4, %d7.w)
    move.b %d3, PJ_Y(%a4, %d7.w)

60: bsr boom_collide                | d2, d3 = where it is now
    tst.w %d0
    beq 9f
    cmp.b #PK_LBOOM_BACK, PJ_KIND(%a4, %d7.w)
    beq 9f
    move.b #PK_LBOOM_BACK, PJ_KIND(%a4, %d7.w)
9:  movem.l (%sp)+, %d0-%d6
    rts

| The boomerang at (d2, d3) meets monsters and items. Returns d0.w = 1 when it
| struck a monster.
boom_collide:
    movem.l %d1-%d6/%a0, -(%sp)
    moveq #0, %d6                   | the result
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 8f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 7f
    bsr enemy_behaviour
    cmp.w #BEH_TRAP, %d0
    beq 7f
    cmp.w #BEH_BOSS, %d0
    beq 7f
    bsr enemy_untouchable
    bne 7f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    sub.w %d2, %d0
    bpl 2f
    neg.w %d0
2:  cmp.w #BOOM_HIT_RANGE, %d0
    bhs 7f
    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    sub.w %d3, %d0
    bpl 3f
    neg.w %d0
3:  cmp.w #BOOM_HIT_RANGE, %d0
    bhs 7f
    moveq #1, %d6
    bsr dmon_boomerang_hurts            | a darknut or a gohma only turns it back
    tst.w %d0
    beq 7f
    tst.b OFF_ENEMY_HP(%a5, %d5.w)
    bne 4f
    move.b #1, OFF_ENEMY_HP(%a5, %d5.w) | no hit points to speak of: one touch kills it
    clr.b OFF_ENEMY_HURT(%a5, %d5.w)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    movem.l %d2-%d3, -(%sp)
    bsr hit_enemy
    movem.l (%sp)+, %d2-%d3
    bra 7f
4:  lea OFF_ENEMY_STUN(%a5), %a0
    move.b #STUN_FRAMES, 0(%a0, %d5.w)
7:  addq.w #1, %d5
    bra 1b
8:  move.b OFF_LINK_X(%a5), %d1      | items: the boomerang takes them as Link would
    move.b OFF_LINK_Y(%a5), %d4
    move.b %d2, OFF_LINK_X(%a5)
    move.b %d3, OFF_LINK_Y(%a5)
    bsr item_pickup
    move.b %d1, OFF_LINK_X(%a5)
    move.b %d4, OFF_LINK_Y(%a5)
    move.w %d6, %d0
    movem.l (%sp)+, %d1-%d6/%a0
    rts

| ------------------------------------------------------------------ Dodongo
| UpdateDodongo. A Dodongo is two squares long when it goes sideways (its X is the left end); nothing
| but a bomb touches it. ENEMY_STATE: 0 walking, 1 bloated (it swallowed a bomb), 2 stunned (a bomb blew up
| beside it). ENEMY_STEP is the bloated substate, ENEMY_TIMER the wait in it (and in the stun), ENEMY_WANT
| the bombs it has swallowed. A bomb that is ticking beside its mouth is eaten; two of those finish it. A
| bomb's cloud next to it stuns it for $20 frames, and the sword kills a stunned one (and it leaves a bomb).
    .equ DODONGO_STUN_FRAMES, 0x20
    .equ DODONGO_BOMBS_TO_DIE, 2

| d5 = monster. Returns d0.w = 1 while it must stand still.
dodongo_ai:
    movem.l %d1-%d3/%a0, -(%sp)
    moveq #0, %d1
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d1
    beq 1f
    cmp.b #1, %d1
    beq 20f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)  | stunned
    bne 8f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    bra 8f
1:  cmpi.b #0x20, OFF_ENEMY_X(%a5, %d5.w)   | near the left wall it faces right
    bhs 11f
    move.b #DIR_RIGHT, OFF_ENEMY_DIR(%a5, %d5.w)
11: moveq #0, %d2                           | Wanderer_TargetPlayer sees the end of the body that leads
    cmpi.b #DIR_LEFT, OFF_ENEMY_DIR(%a5, %d5.w)
    beq 12f
    moveq #16, %d2
12: add.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.w #0x20, %d1                       | turn rate $20
    bsr wander_tick
    sub.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    moveq #0, %d0
    bra 9f
20: moveq #0, %d1                           | bloated: the substates wait $20, $40, $40 frames
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d1
    cmp.b #4, %d1
    beq 29f
    cmp.b #3, %d1
    beq 28f
    moveq #0, %d2
    move.b OFF_ENEMY_TIMER(%a5, %d5.w), %d2
    cmp.b #1, %d2
    beq 25f
    tst.b %d2
    bne 26f
    lea dodongo_waits(%pc), %a0             | the timer has run out: arm it for this substate
    move.b 0(%a0, %d1.w), OFF_ENEMY_TIMER(%a5, %d5.w)
    tst.b %d1
    bne 26f
    clr.b OFF_BOMB_TIMER(%a5)               | the swallowed bomb is gone
    lea OFF_ENEMY_WANT(%a5), %a0
    addq.b #1, 0(%a0, %d5.w)
    bra 26f
25: addq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)   | on to the next substate
    cmpi.b #2, OFF_ENEMY_STEP(%a5, %d5.w)
    blo 26f
    lea OFF_ENEMY_WANT(%a5), %a0
    cmpi.b #DODONGO_BOMBS_TO_DIE, 0(%a0, %d5.w)
    bhs 26f
    move.b #4, OFF_ENEMY_STEP(%a5, %d5.w)   | one bomb is not enough: it walks again
26: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 8f
28: bsr kill_enemy                          | the second bomb: it is dead
    bra 8f
29: clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d3/%a0
    rts

dodongo_waits:
    .byte 0x20, 0x40, 0x40, 0x00
    .align 2

| The sword has struck Dodongo d5: only a stunned one is hurt, and it dies on the spot, leaving a bomb.
dodongo_sword:
    cmpi.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 9f
    move.b #10, OFF_HELP_COUNT(%a5)         | HelpDropCount and HelpDropValue $0A: the drop is a bomb
    move.b #10, OFF_HELP_VALUE(%a5)
    bsr kill_enemy
9:  rts

| Every frame: a Dodongo that is walking swallows a ticking bomb that is by its mouth, and is stunned by a
| bomb's cloud next to it (Dodongo_CheckBombHit). The bomb's hotspot is its origin plus 8 in both ways, the
| Dodongo's the same, with 8 more across when it faces sideways.
dodongo_bomb_tick:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #0, %d7                           | d7 = 1 for the bomb itself, 0 for its cloud
    move.b OFF_BOMB_X(%a5), %d1
    move.b OFF_BOMB_Y(%a5), %d2
    tst.b OFF_BOMB_TIMER(%a5)
    bne 0f
    tst.b OFF_CLOUD_TIMER(%a5)
    beq 9f
    move.b OFF_CLOUD_X(%a5), %d1
    move.b OFF_CLOUD_Y(%a5), %d2
    bra 1f
0:  moveq #1, %d7
1:  and.w #0x00ff, %d1
    and.w #0x00ff, %d2
    addq.w #8, %d1
    addq.w #8, %d2                          | the bomb's hotspot
    moveq #0, %d5
2:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 8f
    bsr enemy_behaviour
    cmp.w #BEH_DODONGO, %d0
    bne 8f
    moveq #0, %d3                           | the Dodongo's hotspot, as a distance from the bomb's
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    addq.w #8, %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #3, %d0
    beq 3f
    addq.w #8, %d3
3:  sub.w %d1, %d3                          | d3 = across
    moveq #0, %d4
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d4
    addq.w #8, %d4
    sub.w %d2, %d4                          | d4 = along
    lea dodongo_bomb_limits(%pc), %a0       | the bomb needs to be within -12/+12 (its cloud) or -16/+17 (itself)
    move.w %d7, %d0
    add.w %d0, %d0
    move.b 0(%a0, %d0.w), %d6               | the positive limit
    ext.w %d6
    move.b 1(%a0, %d0.w), %d0               | the negative limit
    ext.w %d0
    cmp.w %d6, %d3
    bge 8f
    cmp.w %d0, %d3
    blt 8f
    cmp.w %d6, %d4
    bge 8f
    cmp.w %d0, %d4
    blt 8f
    tst.w %d7
    bne 4f
    move.b #2, OFF_ENEMY_STATE(%a5, %d5.w)  | the cloud: stunned
    move.b #DODONGO_STUN_FRAMES, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 8f
4:  moveq #0, %d0                           | the bomb: is it at the mouth?
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    lsr.w #1, %d0                           | 0 right, 1 left, 2 down, 4 up
    lea dodongo_mouth(%pc), %a0
    move.b 0(%a0, %d0.w), %d6               | across: negative, positive limits
    ext.w %d6
    cmp.w %d6, %d3
    blt 8f
    move.b 5(%a0, %d0.w), %d6
    ext.w %d6
    cmp.w %d6, %d3
    bge 8f
    move.b 10(%a0, %d0.w), %d6              | along
    ext.w %d6
    cmp.w %d6, %d4
    blt 8f
    move.b 15(%a0, %d0.w), %d6
    ext.w %d6
    cmp.w %d6, %d4
    bge 8f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)  | swallowed: it bloats
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_BOMB_TIMER(%a5)
8:  addq.w #1, %d5
    bra 2b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| (positive, negative) limits, the cloud's and the bomb's; then the mouth by facing: DodongoMouthNegativeLimits0,
| DodongoMouthPositiveLimits0, DodongoMouthNegativeLimits1 and DodongoMouthPositiveLimits1, five each
dodongo_bomb_limits:
    .byte 0x0c, 0xf4, 0x11, 0xf0
dodongo_mouth:
    .byte 0xf0, 0x00, 0xf8, 0xff, 0xf8      | across, lower limit
    .byte 0x00, 0x10, 0x08, 0xff, 0x08      | across, upper limit
    .byte 0xfc, 0xfc, 0xf0, 0xff, 0x00      | along, lower limit
    .byte 0x04, 0x04, 0x00, 0xff, 0x10      | along, upper limit
    .align 2

| How far the monster's body is from a column: Dodongo is two squares wide when it faces sideways. d5 = monster,
| d0.w = the column. Returns d3.w = the distance to the nearer end. Keeps everything else.
enemy_dx:
    movem.l %d0-%d2/%a0, -(%sp)
    move.w %d0, %d2
    bsr enemy_behaviour
    moveq #0, %d1
    cmp.w #BEH_DODONGO, %d0
    bne 1f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #3, %d0
    beq 1f
    moveq #16, %d1
1:  moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    sub.w %d2, %d3
    bpl 2f
    neg.w %d3
2:  tst.w %d1
    beq 9f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    add.w %d1, %d0
    sub.w %d2, %d0
    bpl 3f
    neg.w %d0
3:  cmp.w %d0, %d3
    bls 9f
    move.w %d0, %d3
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| ------------------------------------------------------------------ Moldorm
| Two worms of four segments (the original has five each; this port has eight monster slots). Each segment is a
| monster; the head (slots 3 and 7) steers like a flyer (Flyer_Chase, Flyer_Wander, Flyer_MoldormDecideState)
| and every $10 frames each segment below it takes over the heading the one above had, so the body follows the
| head's track. They all move at speed $80, half a pixel a frame. ENEMY_DIR 0 means the segment has not been
| told where to go yet. ENEMY_STATE is the head's flying state (2 or 3: chase or wander), ENEMY_STEP its turns
| left, ENEMY_TIMER the delay between them; ENEMY_OLDDIR is the heading a segment had before the last turn.
    .equ MOLDORM_START_X, 0x80
    .equ MOLDORM_START_Y, 0x70
    .equ MOLDORM_SPEED, 0x80
    .equ MOLDORM_SEGMENTS, 4
    .equ MOLDORM_HP_REVIVED, 2          | a segment that "dies" comes back with $20 hit points

moldorm_init:
    movem.l %d0-%d1/%a0, -(%sp)
    move.b #MOLDORM_START_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #MOLDORM_START_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_DIR(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    move.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_OLDDIR(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_BOUNCE(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #MOLDORM_SPEED, 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    move.w %d5, %d0
    and.w #3, %d0
    cmp.w #(MOLDORM_SEGMENTS - 1), %d0
    bne 9f
    bsr rand8                           | a head starts off in a random one of the eight directions
    and.w #7, %d0
    lea keese_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
    lea OFF_ENEMY_OLDDIR(%a5), %a0
    move.b %d0, 0(%a0, %d5.w)
    move.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| d5 = a segment. The head steers and hands its heading down; every segment moves.
moldorm_ai:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    tst.b OFF_ENEMY_DIR(%a5, %d5.w)
    beq 9f
    move.w %d5, %d0
    and.w #3, %d0
    cmp.w #(MOLDORM_SEGMENTS - 1), %d0
    bne 5f
    bsr moldorm_steer
5:  bsr moldorm_move
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| ControlMoldormFlight for a head: turn (towards Link when chasing, at random when wandering) a number of times,
| $10 frames apart, then choose again; each turn hands the headings down the body.
moldorm_steer:
    movem.l %d0-%d2/%a0, -(%sp)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 0f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
0:  tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 5f                          | between turns
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 1f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 3f                          | out of turns: decide what to do next
1:  move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    cmpi.b #3, OFF_ENEMY_STATE(%a5, %d5.w)
    beq 2f
    bsr turn_towards8
    bra 5f
2:  bsr keese_turn_random
    bra 5f
3:  bsr rand8                       | Flyer_MoldormDecideState: chase (state 2) or wander (3), eight turns
    moveq #2, %d1
    cmp.b #0x40, %d0
    bhs 4f
    moveq #3, %d1
4:  move.b %d1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #8, OFF_ENEMY_STEP(%a5, %d5.w)
    move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    lea OFF_ENEMY_DIR(%a5), %a0
    tst.b -1(%a0, %d5.w)
    beq 9f                          | the segment below has not been told to go yet
5:  cmpi.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f                          | the delay was only just armed: hand the headings down
    lea OFF_ENEMY_BOUNCE(%a5), %a0
    move.b 0(%a0, %d5.w), %d0
    beq 6f
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)   | the bounce off a wall takes effect now
    clr.b 0(%a0, %d5.w)
6:  lea OFF_ENEMY_OLDDIR(%a5), %a0
    lea OFF_ENEMY_DIR(%a5), %a1
    move.w %d5, %d1
    subq.w #(MOLDORM_SEGMENTS - 1), %d1     | the lowest segment of this worm
    moveq #(MOLDORM_SEGMENTS - 2), %d2
7:  move.b 1(%a0, %d1.w), %d0
    move.b %d0, 0(%a0, %d1.w)
    move.b %d0, 0(%a1, %d1.w)
    addq.w #1, %d1
    dbra %d2, 7b
    move.b OFF_ENEMY_DIR(%a5, %d5.w), 0(%a0, %d5.w)
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| Dodongo's images (five directions in a set, the fourth unused): walking, walking again, bloated; and whether
| each is mirrored (DodongoFrameImages, DodongoFrameHFlips and the bloated pair).
dodongo_images:
    .byte 0, 1, 6, 0, 8,  2, 3, 6, 0, 8,  4, 5, 7, 0, 9
dodongo_flips:
    .byte 0, 1, 0, 0, 0,  0, 1, 1, 0, 1,  0, 1, 0, 0, 0

| Dodongo_Draw. d3 = monster, d0.w = its monster index. A sideways Dodongo is two sprites: the left half at X and
| the right half 16 along (its picture number's other half, which has the low bit flipped).
draw_dodongo:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    move.w %d0, %d7
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    lsr.w #1, %d2                           | five-way direction: 0 right, 1 left, 2 down, 4 up
    cmp.w #4, %d2
    bhi 99f
    move.w OFF_FRAME_COUNTER(%a5), %d4
    moveq #0, %d6                           | the set of five: 0 walking, 5 walking again, 10 bloated
    moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d3.w), %d0
    beq 1f
    cmp.b #1, %d0
    beq 2f
    btst #5, %d4                            | stunned: the picture changes every $20 frames
    beq 5f
    moveq #5, %d6
    bra 5f
1:  btst #3, %d4                            | walking: every 8 frames
    beq 5f
    moveq #5, %d6
    bra 5f
2:  moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d3.w), %d0
    beq 1b                                  | just swallowed: still walks as usual
    cmp.b #2, %d0
    beq 21f
    cmp.b #3, %d0
    beq 21f
    moveq #10, %d6                          | bloated
    bra 5f
21: btst #1, %d4                            | fading out: two frames drawn, two not
    beq 99f
5:  add.w %d2, %d6
    lea dodongo_images(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d6.w), %d1
    lea dodongo_flips(%pc), %a0
    moveq #0, %d5
    move.b 0(%a0, %d6.w), %d5
    move.w %d1, %d6                         | d6 = the picture number
    bsr dodongo_frame                       | a0 = the sprite frame of picture d6, mirrored if d5
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d2
    sub.l %a2, %a2
    bsr dodongo_put
    tst.w %d0
    beq 99f
    move.b #1, OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d0
    and.b #3, %d0
    beq 99f                                 | facing up or down: one sprite
    eor.w #1, %d6                           | the other half
    bsr dodongo_frame
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    add.w #16, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d2
    lea 1(%a2), %a2                         | the second sprite
    bsr dodongo_put
    tst.w %d0
    beq 99f
    move.b #3, OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
99: movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| d6.w = picture number, d5.w = 1 to mirror it, d7.w = monster index. Returns a0 = the frame in mon_sprites.
dodongo_frame:
    movem.l %d0-%d1/%a1, -(%sp)
    move.w %d6, %d1
    add.w %d1, %d1
    add.w %d5, %d1
    bsr mon_art_ptr
    move.w %d7, %d0
    add.w %d0, %d0
    add.w 0(%a0, %d0.w), %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    movea.l OFF_MON_SPR(%a5), %a0
    adda.l %d1, %a0
    movem.l (%sp)+, %d0-%d1/%a1
    rts

| a0 = frame, d1.w = X, d2.w = Y, d3 = monster, a2 = 0 for its first sprite, 1 for the second (it keeps its own
| erase offset). Returns d0.w = 1 when it was drawn, 0 when it is off the playfield.
dodongo_put:
    movem.l %d1-%d2/%d4/%a0-%a2, -(%sp)
    bsr sprite_offset
    tst.w %d4
    bmi 8f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l %a2, %d2
    lea OFF_ENEMY_ERASE_OFFSETS(%a5), %a2
    tst.w %d2
    beq 1f
    lea OFF_ENEMY_ERASE2_OFFSETS(%a5), %a2
1:  move.l %d1, 0(%a2, %d0.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
    movem.l (%sp)+, %d1-%d2/%d4/%a0-%a2
    moveq #1, %d0
    rts
8:  movem.l (%sp)+, %d1-%d2/%d4/%a0-%a2
    moveq #0, %d0
    rts

| MoveFlyer for a segment: the speed's top three bits fill the position fraction, and a carry moves it a pixel
| along its heading. A room bound that is in the way does not turn a segment: a head only keeps the opposite
| heading for its next turn (DeferBounce), the rest carry on.
moldorm_move:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    lea OFF_ENEMY_SPEED(%a5), %a0
    lea OFF_ENEMY_FRAC(%a5), %a1
    moveq #0, %d1
    move.b 0(%a0, %d5.w), %d1
    and.b #0xe0, %d1
    moveq #0, %d2
    move.b 0(%a1, %d5.w), %d2
    add.w %d1, %d2
    move.b %d2, 0(%a1, %d5.w)
    cmp.w #0x100, %d2
    blo 9f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    btst #0, %d4
    beq 1f
    addq.b #1, OFF_ENEMY_X(%a5, %d5.w)
1:  btst #1, %d4
    beq 2f
    subq.b #1, OFF_ENEMY_X(%a5, %d5.w)
2:  btst #2, %d4
    beq 3f
    addq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
3:  btst #3, %d4
    beq 4f
    subq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
4:  move.l %d3, -(%sp)
    moveq #0, %d3
    bsr bound_by_room
    move.l (%sp)+, %d3
    tst.w %d0
    bne 9f                          | free to go on
    move.w %d5, %d0
    and.w #3, %d0
    cmp.w #(MOLDORM_SEGMENTS - 1), %d0
    bne 9f                          | only a head remembers the bounce
    bsr keese_ring_index
    addq.w #4, %d0
    and.w #7, %d0
    lea keese_dirs(%pc), %a0
    lea OFF_ENEMY_BOUNCE(%a5), %a1
    move.b 0(%a0, %d0.w), 0(%a1, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts
