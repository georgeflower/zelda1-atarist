| Monsters that move by rules of their own, ported from Z_04.asm.
|
|   Tektites and boulders jump (UpdateTektiteOrBoulder), leevers and zoras burrow (UpdateBlueLeever,
|   UpdateRedLeever, UpdateZora, UpdateBurrower), peahats fly (UpdatePeahat, MoveFlyer, BoundFlyer), a ghini
|   walks like a wanderer with turn rate $FF (UpdateGhini), and the boulder set lets boulders fall from the
|   top of the screen (UpdateBoulderSet). A zora is made in the water of a screen that has one (CheckZora).
|
| ENEMY_GHOST says what a monster is not at the moment: bit 0, weapons pass through it; bit 1, it harms nobody.
| A leever under the ground, a zora under the water or a peahat in the air has the first, a burrowed one both.
| ENEMY_STATE, ENEMY_TIMER and ENEMY_STEP keep the game's own ObjState, ObjTimer and Flyer_ObjTurns.

    .equ GHOST_NOHIT, 1
    .equ GHOST_NOHARM, 2
    .equ NES_TEKTITE, 0x0d
    .equ NES_BOULDER, 0x20
    .equ NES_RED_LEEVER, 0x10
    .equ MAX_BOULDERS, 3
    .equ ZORA_TRIES, 13
    .equ ZORA_FIRE_TIMER, 0xfd

| d5 = monster. Returns d0.w = its NES object type.
enemy_nes_type:
    move.l %a0, -(%sp)
    ltab mon_table, %a0
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    lsl.w #3, %d0
    adda.w %d0, %a0
    moveq #0, %d0
    move.b (%a0), %d0
    movea.l (%sp)+, %a0
    rts

| d5 = monster, d7 = its behaviour. Called every frame in place of the walkers' generic step. Returns
| d0.w = 1 when the monster has moved itself, 0 when the caller is to move it along the grid (a blue
| leever, with d4 set to the frames it takes over a pixel, and a ghini).
mover_update:
    cmp.w #BEH_TEKTITE, %d7
    beq mv_jumper
    cmp.w #BEH_BOULDER, %d7
    beq mv_jumper
    cmp.w #BEH_LEEVER, %d7
    beq mv_leever
    cmp.w #BEH_ZORA, %d7
    beq mv_zora
    cmp.w #BEH_PEAHAT, %d7
    beq mv_peahat
    cmp.w #BEH_BOULDER_SET, %d7
    beq mv_boulder_set
    cmp.w #BEH_POLS, %d7
    beq dmon_pols
    cmp.w #BEH_WIZZROBE, %d7
    beq boss_wizzrobe_f
    cmp.w #BEH_MANHANDLA, %d7
    beq boss_manhandla_f
    cmp.w #BEH_GOHMA, %d7
    beq boss_gohma_f
    cmp.w #BEH_DIGDOGGER, %d7
    beq boss_dig_f
    cmp.w #BEH_GLEEOK, %d7
    beq boss_gleeok_f
    cmp.w #BEH_GLEEOK_HEAD, %d7
    beq boss_ghead_f
    cmp.w #BEH_GLEEOK_FLYER, %d7
    beq boss_gflyer_f
    cmp.w #BEH_LANMOLA, %d7
    beq boss_lanmola_f
    cmp.w #BEH_PATRA, %d7
    beq boss_patra_f
    cmp.w #BEH_PATRA_CHILD, %d7
    beq boss_pchild_f
    cmp.w #BEH_GANON, %d7
    beq boss_ganon_f
    cmp.w #BEH_ZELDA, %d7
    beq boss_zelda_f
    cmp.w #BEH_FIRE, %d7
    beq boss_fire_f
    cmp.w #BEH_ARMOS, %d7
    beq owspec_armos_ai
    cmp.w #BEH_WHIRLWIND, %d7
    beq owspec_whirl_ai
    cmp.w #BEH_FAIRY, %d7
    beq owspec_fairy_ai
    move.l %d1, -(%sp)                  | a ghini turns toward Link whenever the dice allow
    move.w #0xff, %d1
    cmp.w #BEH_BUBBLE, %d7
    bne 1f
    moveq #0x40, %d1                    | a bubble at rate $40
1:
    bsr wander_tick
    move.l (%sp)+, %d1
    moveq #0, %d0
    rts

| Finishing touches for a mover just placed. d5 = monster, d0.w = its behaviour.
mover_init:
    movem.l %d0-%d1/%a0, -(%sp)
    cmp.w #BEH_TEKTITE, %d0
    beq 1f
    cmp.w #BEH_BOULDER, %d0
    beq 1f
    cmp.w #BEH_LEEVER, %d0
    beq 2f
    cmp.w #BEH_PEAHAT, %d0
    beq 3f
    cmp.w #BEH_BOULDER_SET, %d0
    bne 9f
    lea OFF_ENEMY_GHOST(%a5), %a0       | the set is never seen or hurt
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    bra 9f
1:  bsr rand8                           | InitTektite: a random heading, and a wait of four frames for each step of it
    and.w #3, %d0
    lea tektite_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
    lsl.b #2, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 9f
2:  move.b #5, OFF_RED_LEEVER_LONG(%a5) | InitLeever
    bra 9f
3:  move.b #DIR_UP, OFF_ENEMY_DIR(%a5, %d5.w)   | InitPeahat: up at first, and from a slow start
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #0x1f, 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

tektite_dirs:
    .byte 0x01, 0x02, 0x05, 0x0a
jumper_yoffsets:
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x00, 0x00, 0xe0, 0xe0, 0x00
jumper_start:
    .byte 0xfd, 0xfc, 0xfe, 0x00
jumper_bases:
    .byte 0, 11, 22, 0
jumper_accel:
    .byte 0x00, 0x40, 0x40, 0x00, 0x00, 0x40, 0x40, 0x00, 0x00, 0x30, 0x30
    .byte 0x00, 0x80, 0x80, 0x00, 0x00, 0x80, 0x80, 0x00, 0x00, 0x50, 0x50
    .byte 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x00
    .align 2

| ------------------------------------------------------------ tektites and boulders
| A jumper sits for a while, then turns toward Link and jumps: one pixel sideways a frame, and up and down
| under an acceleration that depends on its kind and heading, until it comes down within two pixels of where
| the jump was to land. Nothing on the ground stops one; only the bounds of the room turn it round. A boulder
| always heads downward, cannot be hurt, and is gone once it has fallen past $F0.
|
| ENEMY_STATE 0 sitting, 1 jumping. ENEMY_TIMER the wait, ENEMY_JY and ENEMY_JF the vertical speed (whole
| pixels, signed, and a fraction), ENEMY_TGT where the jump lands, ENEMY_REV the jumps in a row that ran into a bound.
mv_jumper:
    movem.l %d1-%d3/%d6/%a0-%a1, -(%sp)
    bsr enemy_nes_type
    moveq #2, %d6                       | the kind: 0 blue tektite, 1 red tektite, 2 boulder
    cmp.b #NES_BOULDER, %d0
    beq 1f
    moveq #0, %d6
    move.b %d0, %d6
    sub.b #NES_TEKTITE, %d6
1:  moveq #0, %d0
    cmp.w #2, %d6
    bne 2f
    moveq #GHOST_NOHIT, %d0
2:  lea OFF_ENEMY_GHOST(%a5), %a0
    move.b %d0, 0(%a0, %d5.w)
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 50f

    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | sitting
    beq 3f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 90f
3:  bsr turn_towards8                   | time to jump: one step toward Link
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #DIR_HORIZONTAL, %d0
    bne 4f
    moveq #DIR_RIGHT, %d0               | a heading with no sideways part gets one toward Link
    move.b OFF_LINK_X(%a5), %d1
    cmp.b OFF_ENEMY_X(%a5, %d5.w), %d1
    bhs 31f
    moveq #DIR_LEFT, %d0
31: or.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
4:  move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
5:  lea OFF_ENEMY_REV(%a5), %a1          | SetUpJump: after two bumps in a row, turn away from Link
    cmpi.b #2, 0(%a1, %d5.w)
    blo 51f
    eori.b #3, OFF_ENEMY_DIR(%a5, %d5.w)
    clr.b 0(%a1, %d5.w)
51: bsr jumper_down
    moveq #0, %d0
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    lea jumper_yoffsets(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    add.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    lea OFF_ENEMY_TGT(%a5), %a0
    move.b %d0, 0(%a0, %d5.w)
    lea jumper_start(%pc), %a0
    lea OFF_ENEMY_JY(%a5), %a1
    move.b 0(%a0, %d6.w), 0(%a1, %d5.w)
    lea OFF_ENEMY_JF(%a5), %a1
    clr.b 0(%a1, %d5.w)
    bra 90f

50: bsr flyer_bound_h_or_v              | jumping: a bound of the room turns it round and starts the jump over
    tst.w %d0
    bne 52f
    lea OFF_ENEMY_REV(%a5), %a1
    addq.b #1, 0(%a1, %d5.w)
    bra 5b
52: bsr jumper_down
    lea OFF_ENEMY_REV(%a5), %a1
    clr.b 0(%a1, %d5.w)
    lea jumper_bases(%pc), %a0          | the acceleration for this kind and heading
    moveq #0, %d0
    move.b 0(%a0, %d6.w), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    add.w %d1, %d0
    lea jumper_accel(%pc), %a0
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    lea OFF_ENEMY_JY(%a5), %a0          | Jumper_MoveY: the old speed moves it, then the speed grows
    lea OFF_ENEMY_JF(%a5), %a1
    move.b 0(%a0, %d5.w), %d0
    add.b %d0, OFF_ENEMY_Y(%a5, %d5.w)
    move.b 0(%a1, %d5.w), %d1
    add.b %d2, %d1
    bcc 53f
    addq.b #1, %d0
53: cmp.b #2, %d0                       | at most two pixels a frame going down
    blt 54f
    cmp.b #0x80, %d1
    blo 54f
    moveq #2, %d0
    moveq #0, %d1
54: move.b %d0, 0(%a0, %d5.w)
    move.b %d1, 0(%a1, %d5.w)
    btst #1, OFF_ENEMY_DIR(%a5, %d5.w)  | one pixel sideways a frame
    beq 55f
    subq.b #1, OFF_ENEMY_X(%a5, %d5.w)
    bra 56f
55: addq.b #1, OFF_ENEMY_X(%a5, %d5.w)
56: tst.b %d0
    bmi 90f                             | still rising
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0 | coming down: landed within two pixels of the target?
    lea OFF_ENEMY_TGT(%a5), %a1
    sub.b 0(%a1, %d5.w), %d0
    ext.w %d0
    bpl 57f
    neg.w %d0
57: cmp.w #3, %d0
    bhs 90f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)   | down: sit for a while (a boulder not at all)
    moveq #0, %d0
    cmp.w #2, %d6
    beq 59f
    bsr rand8
    add.b #0x10, %d0
    cmp.b #0x20, %d0
    bhs 58f
    sub.b #0x40, %d0
58: tst.w %d6
    beq 59f                             | a blue tektite waits that long
    and.b #0x7f, %d0
    move.b %d0, %d3
    bsr rand8
    cmp.b #0xa0, %d0
    blo 581f
    and.b #0x0f, %d3                    | a red one is often quicker
581: move.b %d3, %d0
59: move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)

90: lea OFF_ENEMY_ANIMC(%a5), %a0       | the legs: a boulder turns every six frames, a tektite every sixteen
    moveq #6, %d0                       | while it sits with a long wait ahead
    cmp.w #2, %d6
    beq 92f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 99f
    cmpi.b #0x21, OFF_ENEMY_TIMER(%a5, %d5.w)
    blo 99f
    moveq #0x10, %d0
92: subq.b #1, 0(%a0, %d5.w)
    bne 99f
    move.b %d0, 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    eori.b #1, 0(%a0, %d5.w)
99: cmp.w #2, %d6
    bne 9f
    cmpi.b #0xf0, OFF_ENEMY_Y(%a5, %d5.w)
    blo 9f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)  | a boulder that has fallen off the screen
    tst.b OFF_BOULDERS(%a5)
    beq 9f
    subq.b #1, OFF_BOULDERS(%a5)
9:  movem.l (%sp)+, %d1-%d3/%d6/%a0-%a1
    moveq #1, %d0
    rts

| A boulder (kind d6 = 2) always heads downward.
jumper_down:
    cmp.w #2, %d6
    bne 1f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #3, %d0
    or.b #4, %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
1:  rts

| BoundFlyer for a jumper: boulders are only held in sideways. d6 = kind. Returns d0.w = 0 when it was turned.
flyer_bound_h_or_v:
    cmp.w #2, %d6
    beq flyer_bound_h
    bra flyer_bound

| ------------------------------------------------------------ flying
| BoundDirectionHorizontally / BoundDirectionVertically: a monster that is past a bound of the room and
| heading further out has its heading cancelled. d5 = monster, d3.w = 1 to look at the sideways bounds only.
| Returns d0.w = 1 when it is free to go on, 0 when a bound is in its way.
bound_by_room:
    movem.l %d1-%d2/%d4, -(%sp)
    moveq #1, %d0
    moveq #0, %d4
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    beq 9f
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    moveq #DIR_LEFT, %d2
    cmp.b OFF_OBJ_LEFT(%a5), %d1
    blo 1f
    moveq #DIR_RIGHT, %d2
    cmp.b OFF_OBJ_RIGHT(%a5), %d1
    blo 2f
1:  and.b %d4, %d2
    beq 2f
    moveq #0, %d4
2:  tst.w %d3
    bne 5f
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    moveq #DIR_UP, %d2
    cmp.b OFF_OBJ_UP(%a5), %d1
    blo 3f
    moveq #DIR_DOWN, %d2
    cmp.b OFF_OBJ_DOWN(%a5), %d1
    blo 5f
3:  and.b %d4, %d2
    beq 5f
    moveq #0, %d4
5:  tst.b %d4
    bne 9f
    moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d2/%d4
    rts

| BoundFlyer: a monster held up by a bound is turned right round. Returns d0.w = 1 when it was free, else 0.
flyer_bound:
    move.l %d3, -(%sp)
    moveq #0, %d3
    bra 1f
flyer_bound_h:                          | boulders are only held in sideways
    move.l %d3, -(%sp)
    moveq #1, %d3
1:  bsr bound_by_room
    move.l (%sp)+, %d3
    tst.w %d0
    bne 9f
    bsr reverse_dir8
    moveq #0, %d0
9:  rts

| ReverseObjDir8. d5 = monster.
reverse_dir8:
    movem.l %d0/%a0, -(%sp)
    bsr keese_ring_index
    addq.w #4, %d0
    and.w #7, %d0
    lea keese_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    movem.l (%sp)+, %d0/%a0
    rts

| MoveFlyer: the speed's top three bits fill the position fraction, and a carry moves it a pixel along its
| heading, wherever that leads; then BoundFlyer.
flyer_move:
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
4:  lea OFF_ENEMY_DIST(%a5), %a0
    addq.b #1, 0(%a0, %d5.w)
    bsr flyer_bound
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| The flying state machine of keese, peahats and the like. ENEMY_STATE: 0 speed up, 1 decide, 2 chase Link,
| 3 wander, 4 slow down, 5 rest. ENEMY_STEP the turns still to make, ENEMY_TIMER the wait between them or the
| rest. d1 = the roll that picks chasing, d2 = the roll that picks wandering (else it slows down), d3 = the
| top speed's upper three bits.
flyer_control:
    movem.l %d0-%d4/%a0, -(%sp)
    lea OFF_ENEMY_SPEED(%a5), %a0
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
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | resting
    bne 9f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
10: addq.b #1, 0(%a0, %d5.w)            | Flyer_SpeedUp
    bra 12f
11: subq.b #1, 0(%a0, %d5.w)            | Flyer_SlowDown
12: move.b 0(%a0, %d5.w), %d4
    and.b #0xe0, %d4
    bne 13f
    bsr rand8                           | too slow to fly: rest for $40 to $7F frames
    and.b #0x3f, %d0
    or.b #0x40, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
    move.b #5, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
13: cmp.b %d3, %d4
    blo 9f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
20: bsr rand8                           | decide what to do next, for six turns
    moveq #2, %d4
    cmp.b %d1, %d0
    bhs 21f
    moveq #3, %d4
    cmp.b %d2, %d0
    bhs 21f
    moveq #4, %d4
21: move.b %d4, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #6, OFF_ENEMY_STEP(%a5, %d5.w)
    bra 9f
30: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | Flyer_Chase
    bne 9f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 31f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
31: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr turn_towards8
    bra 9f
40: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | Flyer_Wander
    bne 9f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 41f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 9f
41: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr keese_turn_random
9:  movem.l (%sp)+, %d0-%d4/%a0
    rts


| TurnTowardsPlayer8. d5 = monster. If Link lies one step either side of its heading or straight ahead it keeps
| going; otherwise it turns one step, toward Link where that is not a turn away from him.
turn_towards8:
    movem.l %d0-%d4/%d6-%d7/%a0, -(%sp)
    moveq #0, %d4                       | the direction to Link
    move.b OFF_CHASE_X(%a5), %d0
    cmp.b OFF_ENEMY_X(%a5, %d5.w), %d0
    beq 1f
    bhi 11f
    moveq #DIR_LEFT, %d4
    bra 1f
11: moveq #DIR_RIGHT, %d4
1:  move.b OFF_CHASE_Y(%a5), %d0
    cmp.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    beq 2f
    bhi 21f
    or.b #DIR_UP, %d4
    bra 2f
21: or.b #DIR_DOWN, %d4
2:  bsr keese_ring_index                | d0.w = where its heading sits in the ring of eight
    move.w %d0, %d1
    lea keese_dirs(%pc), %a0
    move.w %d1, %d2                     | one step right of its heading, the heading, one step left
    addq.w #1, %d2
    moveq #2, %d3
3:  move.w %d2, %d0
    and.w #7, %d0
    cmp.b 0(%a0, %d0.w), %d4
    beq 9f                              | Link is that way already
    subq.w #1, %d2
    dbra %d3, 3b
    move.w %d1, %d2                     | the first of the three, from the left, that shares a part with Link's direction
    subq.w #1, %d2                      | and together with it is no wider than 90 degrees
    moveq #2, %d3
4:  move.w %d2, %d0
    and.w #7, %d0
    move.b 0(%a0, %d0.w), %d6
    move.b %d6, %d7
    and.b %d4, %d7
    beq 5f
    or.b %d4, %d6
    cmp.b #7, %d6
    blo 8f
5:  addq.w #1, %d2
    dbra %d3, 4b
    move.w %d1, %d0                     | none: one step to the right
    addq.w #1, %d0
    and.w #7, %d0
8:  move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0
    rts

| ---------------------------------------------------------------------- peahats
| A peahat flies like a keese at up to $A0 and is only to be hit when it rests; it hurts Link all the time.
mv_peahat:
    movem.l %d1-%d3/%a0, -(%sp)
    move.w #0xb0, %d1
    move.w #0x20, %d2
    move.w #0xa0, %d3
    bsr flyer_control
    bsr flyer_move
    moveq #GHOST_NOHIT, %d0
    cmpi.b #5, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 1f
    moveq #0, %d0
1:  lea OFF_ENEMY_GHOST(%a5), %a0
    move.b %d0, 0(%a0, %d5.w)
    movem.l (%sp)+, %d1-%d3/%a0
    moveq #1, %d0
    rts

| ---------------------------------------------------------------------- burrowers
| Blue leevers and zoras go round six states: 0 under, 1 mound, 2 and 3 and 4 up, 5 mound, each for a time of
| its own (UpdateBurrower). Only a leever in state 3 and a zora in states 2 to 4 can hit and be hit.
burrower_times:
    .byte 0x80, 0x20, 0x0f, 0xff, 0x10, 0x60
burrower_anims:
    .byte 0x10, 0x0b, 0x01, 0x05, 0x01, 0x0b
leever_periods:                         | frames over a pixel in each state: the speeds $08, $0A, $10, $20, $10, $0A
    .byte 8, 6, 4, 2, 4, 6
red_times:
    .byte 0x00, 0x10, 0x08, 0xff, 0x08, 0x10
red_anims:
    .byte 0x10, 0x08, 0x08, 0x05, 0x08, 0x08

burrower_step:
    movem.l %d0-%d1/%a0, -(%sp)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 1f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 3f
1:  cmpi.b #MON_ZORA, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 2f
    cmpi.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 2f
    moveq #3, %d0                       | the zora comes up showing Link its back when it is below him, else its front
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    cmp.b OFF_LINK_Y(%a5), %d1
    bhs 21f
    moveq #2, %d0
21: move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
2:  moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    addq.b #1, %d0
    cmp.b #6, %d0
    blo 22f
    moveq #0, %d0
22: move.b %d0, OFF_ENEMY_STATE(%a5, %d5.w)
    lea burrower_times(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_TIMER(%a5, %d5.w)
3:  moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    lea burrower_anims(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    lea OFF_ENEMY_ANIMC(%a5), %a0
    subq.b #1, 0(%a0, %d5.w)
    bne 4f
    move.b %d0, 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    eori.b #1, 0(%a0, %d5.w)
4:  movem.l (%sp)+, %d0-%d1/%a0
    rts

mv_leever:
    movem.l %d1/%d6/%a0-%a1, -(%sp)
    bsr enemy_nes_type
    cmp.b #NES_RED_LEEVER, %d0
    beq 5f
    move.w #0xa0, %d1                   | a blue leever walks the grid like a wanderer (turn rate $A0)
    bsr wander_tick
    bsr burrower_step
    moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    lea leever_periods(%pc), %a0        | at a pace that depends on its state; the caller moves it
    moveq #0, %d4
    move.b 0(%a0, %d0.w), %d4
    moveq #(GHOST_NOHIT + GHOST_NOHARM), %d1
    cmp.b #3, %d0
    bne 1f
    moveq #0, %d1
1:  lea OFF_ENEMY_GHOST(%a5), %a0
    move.b %d1, 0(%a0, %d5.w)
    movem.l (%sp)+, %d1/%d6/%a0-%a1
    moveq #0, %d0
    rts
5:  bsr red_leever
    movem.l (%sp)+, %d1/%d6/%a0-%a1
    moveq #1, %d0
    rts

| UpdateRedLeever. It waits under the ground until the long timer has run out and fewer than two are about, then
| comes up 40 pixels ahead of Link (or behind him), runs at him until something is in its way, and sinks again.
red_leever:
    movem.l %d0-%d3/%d6/%a0-%a1, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    bne 20f
    tst.b OFF_RED_LEEVER_LONG(%a5)
    bne 9f
    cmpi.b #2, OFF_RED_LEEVERS(%a5)
    bhs 9f
    bsr red_leever_place                | d0.w = 1 when it came out of the ground
    tst.w %d0
    beq 9f
    bsr red_cycle                       | on to state 1
    bra 40f
20: cmp.b #3, %d0
    bne 30f
    clr.b 0(%a0, %d5.w)                 | running: it can hurt and be hurt
    bsr red_ahead
    tst.w %d0
    bne 25f
    move.w OFF_FRAME_COUNTER(%a5), %d0  | half a pixel a frame (speed $20)
    add.w %d5, %d0
    btst #0, %d0
    bne 26f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    btst #0, %d0
    beq 21f
    addq.b #1, OFF_ENEMY_X(%a5, %d5.w)
21: btst #1, %d0
    beq 22f
    subq.b #1, OFF_ENEMY_X(%a5, %d5.w)
22: btst #2, %d0
    beq 23f
    addq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
23: btst #3, %d0
    beq 26f
    subq.b #1, OFF_ENEMY_Y(%a5, %d5.w)
26: move.b #0xff, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 40f
25: bsr red_cycle
    bra 40f
30: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 31f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 40f
31: bsr red_cycle
40: moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    lea red_anims(%pc), %a1
    move.b 0(%a1, %d0.w), %d0
    lea OFF_ENEMY_ANIMC(%a5), %a1
    subq.b #1, 0(%a1, %d5.w)
    bne 9f
    move.b %d0, 0(%a1, %d5.w)
    lea OFF_ENEMY_ANIMF(%a5), %a1
    eori.b #1, 0(%a1, %d5.w)
9:  movem.l (%sp)+, %d0-%d3/%d6/%a0-%a1
    rts

| The next of the red leever's six states, with the timer it brings. A leever that has come full circle is no
| longer among the active ones.
red_cycle:
    movem.l %d0/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    addq.b #1, %d0
    cmp.b #6, %d0
    blo 1f
    tst.b OFF_RED_LEEVERS(%a5)
    beq 2f
    subq.b #1, OFF_RED_LEEVERS(%a5)
2:  moveq #0, %d0
1:  move.b %d0, OFF_ENEMY_STATE(%a5, %d5.w)
    lea red_times(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_TIMER(%a5, %d5.w)
    movem.l (%sp)+, %d0/%a0
    rts

| Where a red leever may come up: 40 pixels in front of Link, or behind him a third of the time, on a tile it
| can stand on and not too near the top of the screen. Returns d0.w = 1 and places it, or 0.
red_leever_place:
    movem.l %d1-%d3/%d6/%a0, -(%sp)
    move.b OFF_LINK_DIR(%a5), %d6
    bsr rand8
    cmp.b #0xc0, %d0
    blo 1f
    bsr opposite_dir
1:  moveq #0, %d2
    moveq #0, %d3
    move.b %d6, %d0
    and.b #DIR_VERTICAL, %d0
    beq 3f
    move.b OFF_LINK_X(%a5), %d2         | above or below Link
    moveq #0x28, %d1
    btst #3, %d6
    beq 2f
    moveq #-0x28, %d1
2:  move.b OFF_LINK_Y(%a5), %d3
    add.b %d1, %d3
    and.b #0xf0, %d3
    or.b #0x0d, %d3
    cmp.b #0x5d, %d3
    blo 8f
    cmp.b #0xe0, %d3
    bhs 8f
    bra 5f
3:  move.b OFF_LINK_Y(%a5), %d3         | to Link's left or right
    cmp.b #0x5d, %d3
    blo 8f
    moveq #0x28, %d1
    btst #1, %d6
    beq 4f
    moveq #-0x28, %d1
4:  move.b OFF_LINK_X(%a5), %d2
    add.b %d1, %d2
    and.b #0xf8, %d2
    moveq #0, %d0                       | wrapped round the edge of the screen?
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d1
    move.b %d2, %d1
    sub.w %d1, %d0
    bpl 41f
    neg.w %d0
41: cmp.w #0x30, %d0
    bhs 8f
5:  bsr enemy_blocked_at                | the tile has to be one it can come out of
    tst.w %d0
    bne 8f
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bsr opposite_dir                    | and it faces Link
    move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
    addq.b #1, OFF_RED_LEEVERS(%a5)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    move.b #1, 0(%a0, %d5.w)
    move.b #2, OFF_RED_LEEVER_LONG(%a5) | the next one may come in 20 frames
    moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d3/%d6/%a0
    rts

| d5 = a running red leever. Returns d0.w = 1 when a bound of the room or a tile is in its way.
red_ahead:
    movem.l %d1-%d4, -(%sp)
    moveq #0, %d3
    bsr bound_by_room
    tst.w %d0
    beq 8f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    btst #0, %d1
    beq 1f
    addq.w #1, %d2
1:  btst #1, %d1
    beq 2f
    subq.w #1, %d2
2:  btst #2, %d1
    beq 3f
    addq.w #1, %d3
3:  btst #3, %d1
    beq 4f
    subq.w #1, %d3
4:  bsr box_blocked
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d4
    rts

| Is the 16x16 box at (d2, d3) outside the play area, or does any tile it touches block? Returns d0.w = 1 if so.
box_blocked:
    movem.l %d1-%d7, -(%sp)
    move.w %d3, %d4
    sub.w #(NES_PLAY_AREA_TOP - 3), %d4
    bmi 8f
    move.w %d4, %d6
    add.w #15, %d6
    lsr.w #3, %d6                       | last row
    lsr.w #3, %d4                       | first row
    move.w %d2, %d5
    move.w %d2, %d7
    add.w #15, %d7
    lsr.w #3, %d7                       | last column
    lsr.w #3, %d5                       | first column
    cmp.w #(PLAY_AREA_ROWS - 1), %d6
    bhi 8f
    cmp.w #(PLAY_AREA_COLS - 1), %d7
    bhi 8f
    move.w %d5, %d1
1:  move.w %d1, %d5
2:  move.w %d4, %d2
    move.w %d5, %d3
    bsr fetch_tile
    bsr tile_blocks
    tst.w %d0
    bne 9f
    addq.w #1, %d5
    cmp.w %d7, %d5
    bls 2b
    addq.w #1, %d4
    cmp.w %d6, %d4
    bls 1b
    moveq #0, %d0
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d7
    rts

| ------------------------------------------------------------------ zoras
| UpdateZora: a zora goes through the burrower's states, spitting a fireball at Link when it is two frames into
| state 3, and is gone when it sinks away for good. One that is killed does not come back.
mv_zora:
    movem.l %d1/%a0, -(%sp)
    bsr burrower_step
    cmpi.b #3, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 1f
    cmpi.b #ZORA_FIRE_TIMER, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 1f
    bsr zora_fire
    move.b #0x20, OFF_ENEMY_TIMER(%a5, %d5.w)
1:  tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 2f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    clr.b OFF_ZORA_ACTIVE(%a5)
    bra 9f
2:  moveq #(GHOST_NOHIT + GHOST_NOHARM), %d1
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    cmp.b #2, %d0
    blo 3f
    cmp.b #4, %d0
    bhi 3f
    moveq #0, %d1
3:  lea OFF_ENEMY_GHOST(%a5), %a0
    move.b %d1, 0(%a0, %d5.w)
9:  movem.l (%sp)+, %d1/%a0
    moveq #1, %d0
    rts

| CheckZora, once a frame on the overworld: a screen with water that has no zora yet makes one, on one of the
| water tiles (the NES tiles $8D to $98) among the squares of 13 random tries.
zora_check:
    tst.b OFF_LEVEL(%a5)
    bne 9f
    tst.b OFF_ZORA_ACTIVE(%a5)
    bne 9f
    movem.l %d0-%d4/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lsl.w #4, %d0
    ltab ow_room_info, %a0
    btst #1, 1(%a0, %d0.w)
    beq 8f
    bsr enemy_find_slot
    tst.w %d0
    bmi 8f
    moveq #(ZORA_TRIES - 1), %d4
1:  bsr rand8
    move.w %d0, %d2
    and.w #0xf0, %d2                    | a square away from the left and right edges
    beq 7f
    cmp.w #0xf0, %d2
    beq 7f
    bsr rand8
    and.w #0x0f, %d0
    lsl.w #4, %d0
    cmp.w #0x50, %d0                    | and clear of the top and the bottom
    blo 7f
    cmp.w #0xe0, %d0
    bhs 7f
    or.w #0x0d, %d0
    move.w %d0, %d3
    bsr tile_at
    cmp.w #0x8d, %d0
    blo 7f
    cmp.w #0x99, %d0
    bhs 7f
    moveq #MON_ZORA, %d1
    moveq #DIR_DOWN, %d4
    bsr enemy_make
    tst.w %d0
    bmi 8f
    move.b #1, OFF_ZORA_ACTIVE(%a5)
    bra 8f
7:  dbra %d4, 1b
8:  movem.l (%sp)+, %d0-%d4/%a0
9:  rts

| d2.w = X, d3.w = Y in pixels. Returns d0.w = the NES tile under the foot of a monster standing there.
tile_at:
    movem.l %d1-%d5, -(%sp)
    move.w %d2, %d4
    lsr.w #3, %d4
    cmp.w #(PLAY_AREA_COLS - 1), %d4
    bls 1f
    moveq #(PLAY_AREA_COLS - 1), %d4
1:  move.w %d3, %d5
    add.w #0x0b, %d5
    sub.w #NES_PLAY_AREA_TOP, %d5
    bpl 2f
    clr.w %d5
2:  lsr.w #3, %d5
    cmp.w #(PLAY_AREA_ROWS - 1), %d5
    bls 3f
    moveq #(PLAY_AREA_ROWS - 1), %d5
3:  move.w %d5, %d2
    move.w %d4, %d3
    bsr fetch_tile
    movem.l (%sp)+, %d1-%d5
    rts

| ------------------------------------------------------------------ boulders
| UpdateBoulderSet. The set is a monster nobody sees. Whenever its timer has run out and fewer than three
| boulders are rolling, a boulder starts at the top of the screen, on the half Link is in, and the set waits
| a random time ((rand + 8) AND $1F frames).
mv_boulder_set:
    movem.l %d1-%d4/%a0, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 1f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f
1:  cmpi.b #MAX_BOULDERS, OFF_BOULDERS(%a5)
    blo 2f
    bsr rand8
    add.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 9f
2:  bsr enemy_find_slot
    tst.w %d0
    bmi 9f
    bsr rand8
    move.w %d0, %d2
    cmpi.b #0x80, OFF_LINK_X(%a5)
    bhs 3f
    and.w #0x7f, %d2
    bra 4f
3:  or.w #0x80, %d2
4:  moveq #0x40, %d3
    moveq #MON_BOULDER, %d1
    moveq #DIR_DOWN, %d4
    bsr enemy_make
    tst.w %d0
    bmi 9f
    addq.b #1, OFF_BOULDERS(%a5)
    bsr rand8
    add.b #8, %d0
    and.b #0x1f, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
9:  movem.l (%sp)+, %d1-%d4/%a0
    moveq #1, %d0
    rts

| ------------------------------------------------------------------ making monsters
| Returns d0.w = a slot a new monster can take, or -1. A dead monster's slot will do; so will one more at the
| end, unless monsters are still to walk in from the edge (their slots are spoken for).
enemy_find_slot:
    movem.l %d1-%d2, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_COUNT(%a5), %d2
    tst.b OFF_EDGE_PENDING(%a5)
    beq 1f
    move.b OFF_EDGE_NEXT(%a5), %d2
    and.w #0xff, %d2
1:  moveq #0, %d1
2:  cmp.w %d2, %d1
    bhs 3f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    beq 8f
    addq.w #1, %d1
    bra 2b
3:  tst.b OFF_EDGE_PENDING(%a5)
    bne 7f
    cmpi.b #MAX_ENEMIES, OFF_ENEMY_COUNT(%a5)
    bhs 7f
    moveq #0, %d1
    move.b OFF_ENEMY_COUNT(%a5), %d1
8:  move.w %d1, %d0
    bra 9f
7:  moveq #-1, %d0
9:  movem.l (%sp)+, %d1-%d2
    rts

| A new monster: d1.w = its index in mon_table, d2.w = X, d3.w = Y, d4.b = heading. Returns d0.w = its slot or -1.
enemy_make:
    movem.l %d1-%d6/%a0, -(%sp)
    bsr enemy_find_slot
    tst.w %d0
    bmi 9f
    move.w %d0, %d6
    cmp.b OFF_ENEMY_COUNT(%a5), %d6
    blo 1f
    move.b %d6, %d0
    addq.b #1, %d0
    move.b %d0, OFF_ENEMY_COUNT(%a5)
1:  move.w %d6, %d5
    bsr enemy_slot_reset
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b %d1, OFF_ENEMY_TYPE(%a5, %d5.w)
    ltab mon_table, %a0
    lsl.w #3, %d1
    move.b 1(%a0, %d1.w), OFF_ENEMY_HP(%a5, %d5.w)
    move.b #1, OFF_ENEMY_ACTIVE(%a5, %d5.w)
    bsr enemy_init_special
    move.w %d6, %d0
9:  movem.l (%sp)+, %d1-%d6/%a0
    rts

| Everything a slot remembers about its last monster is forgotten. d5 = the slot.
enemy_slot_reset:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_ENEMY_HURT(%a5, %d5.w)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_STUN(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_TURN(%a5), %a0
    clr.b 0(%a0, %d5.w)
    clr.b 8(%a0, %d5.w)
    clr.b 16(%a0, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    moveq #7, %d0
1:  clr.b 0(%a0, %d5.w)
    lea 8(%a0), %a0
    dbra %d0, 1b
    movem.l (%sp)+, %d0/%a0
    rts

| A monster has been killed: a red leever stops counting among the active ones. Returns d0.w = 1 when the
| kill counts toward the screen's (a zora's does not).
mover_died:
    movem.l %d1/%a0, -(%sp)
    bsr enemy_nes_type
    cmp.b #NES_RED_LEEVER, %d0
    bne 1f
    tst.b OFF_RED_LEEVERS(%a5)
    beq 1f
    subq.b #1, OFF_RED_LEEVERS(%a5)
1:  cmp.b #0x1e, %d0
    beq 2f                              | an armos is not one of the screen's monsters either
    cmp.b #0x11, %d0
    seq %d0
    and.w #1, %d0
    eori.w #1, %d0
    bra 3f
2:  moveq #0, %d0
3:  movem.l (%sp)+, %d1/%a0
    rts

| ------------------------------------------------------------------ drawing
    .equ MODE_TEKTITE, 9
    .equ MODE_LEEVER, 10
    .equ MODE_ZORA, 11
    .equ MODE_PEAHAT, 12
    .equ MODE_GHINI, 13
    .equ MODE_BOULDER, 14

| draw_enemies: d3 = the monster, d2.w = its mode (9 up). Returns d1.w = the image to show (-1: nothing) and
| d5.w = 1 when it is to be mirrored. d0 (the monster's type) is kept.
mover_frame:
    movem.l %d0/%d2/%a0, -(%sp)
    moveq #0, %d1
    moveq #0, %d5
    cmp.w #MODE_TEKTITE, %d2
    beq 10f
    cmp.w #MODE_LEEVER, %d2
    beq 20f
    cmp.w #MODE_ZORA, %d2
    beq 30f
    cmp.w #MODE_PEAHAT, %d2
    beq 40f
    cmp.w #MODE_GHINI, %d2
    beq 50f
    cmp.w #MODE_BOULDER, %d2
    beq 60f
    bra 80f
10: tst.b OFF_ENEMY_STATE(%a5, %d3.w)   | a tektite: crouched, or one of two while it sits long, or stretched in the air
    bne 11f
    cmpi.b #0x21, OFF_ENEMY_TIMER(%a5, %d3.w)
    blo 9f
    lea OFF_ENEMY_ANIMF(%a5), %a0
    move.b 0(%a0, %d3.w), %d1
    bra 9f
11: moveq #1, %d1
    bra 9f
20: moveq #0, %d0                       | a leever: two pictures for each state from 1 to 5
    move.b OFF_ENEMY_STATE(%a5, %d3.w), %d0
    beq 80f
    subq.w #1, %d0
    add.w %d0, %d0
    lea OFF_ENEMY_ANIMF(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d3.w), %d1
    add.w %d0, %d1
    bra 9f
30: moveq #0, %d0                       | a zora: the mound, or when up its front or back
    move.b OFF_ENEMY_STATE(%a5, %d3.w), %d0
    beq 80f
    cmp.b #2, %d0
    blo 31f
    cmp.b #4, %d0
    bhi 31f
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d1
    bne 9f
31: subq.w #1, %d0
    add.w %d0, %d0
    lea OFF_ENEMY_ANIMF(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d3.w), %d1
    add.w %d0, %d1
    bra 9f
40: lea OFF_ENEMY_DIST(%a5), %a0        | a peahat beats its wings as fast as it flies
    move.b 0(%a0, %d3.w), %d1
    and.w #1, %d1
    bra 9f
50: move.b OFF_ENEMY_DIR(%a5, %d3.w), %d0   | a ghini: the back going up, else the front; mirrored toward its side
    btst #3, %d0
    beq 51f
    btst #1, %d0
    beq 9f
    moveq #1, %d5
    bra 9f
51: moveq #1, %d1
    btst #0, %d0
    beq 9f
    moveq #1, %d5
    bra 9f
60: lea OFF_ENEMY_ANIMF(%a5), %a0       | a boulder turns over
    move.b 0(%a0, %d3.w), %d1
    and.w #1, %d1
    bra 9f
80: moveq #-1, %d1
9:  movem.l (%sp)+, %d0/%d2/%a0
    rts

| A monster d5 is shoved four pixels a frame along ENEMY_SHOVE (d6) whatever lies in the way, as far as the
| bounds of the room. Used by the ones that jump or fly.
enemy_free_shove:
    movem.l %d0-%d4, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #3, %d4
1:  move.w %d2, %d0
    move.w %d3, %d1
    btst #0, %d6
    beq 11f
    addq.w #1, %d2
11: btst #1, %d6
    beq 12f
    subq.w #1, %d2
12: btst #2, %d6
    beq 13f
    addq.w #1, %d3
13: btst #3, %d6
    beq 14f
    subq.w #1, %d3
14: cmp.b OFF_OBJ_LEFT(%a5), %d2
    blo 8f
    cmp.b OFF_OBJ_RIGHT(%a5), %d2
    bhs 8f
    cmp.b OFF_OBJ_UP(%a5), %d3
    blo 8f
    cmp.b OFF_OBJ_DOWN(%a5), %d3
    bhs 8f
    dbra %d4, 1b
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bra 9f
8:  move.b %d0, OFF_ENEMY_X(%a5, %d5.w)  | it stops at the last square inside
    move.b %d1, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d4
    rts

| The game's long timers count tenths of a second: the red leevers' one steps down every tenth frame.
long_timers:
    move.l %d0, -(%sp)
    moveq #0, %d0
    move.w OFF_FRAME_COUNTER(%a5), %d0
    divu.w #10, %d0
    swap %d0
    tst.w %d0
    bne 9f
    tst.b OFF_RED_LEEVER_LONG(%a5)
    beq 9f
    subq.b #1, OFF_RED_LEEVER_LONG(%a5)
9:  move.l (%sp)+, %d0
    rts

| d5 = monster. Z clear (NE) when weapons pass through it just now.
enemy_untouchable:
    move.l %a0, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    btst #0, 0(%a0, %d5.w)
    movea.l (%sp)+, %a0
    rts
