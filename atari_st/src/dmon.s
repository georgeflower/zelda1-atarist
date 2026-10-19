| The monsters of Levels 3 to 8, ported from Z_04.asm: what hurts them, how they split, hop and grab, and how
| they are drawn.
|
|   Darknuts turn aside a sword that meets their shield head on (InitDarknut, HandleMonsterWeaponCollision),
|   zols leave two gels and vires two keese when a blow does not kill them, a pols voice hops (UpdatePolsVoice)
|   and dies to a single arrow, a like-like swallows Link until it dies (UpdateLikeLike), and a bubble
|   keeps him from swinging his sword for a while (UpdateBubble).
|
| mon_mask says which weapons hurt a monster; the weapons name themselves in HIT_TYPE before hit_enemy.


| farstub name, target: a trampoline to a routine out of reach of a 16-bit branch. It pushes its own address, adds
| the distance to the target (a constant the assembler works out) and returns into it, so the caller's return
| address stays on the stack and no register is touched (the flags are). The code is bigger than 64 KB, so modules
| that sit far from each other call through these, placed near the callers.
    .macro farstub name, target
\name:
    pea 1f(%pc)
1:  addi.l #(\target - 1b), (%sp)
    rts
    .endm

    .equ HIT_SWORD, 0x01
    .equ HIT_BOOMERANG, 0x02
    .equ HIT_ARROW, 0x04
    .equ HIT_BOMB, 0x08
    .equ HIT_MAGIC, 0x10
    .equ HIT_FIRE, 0x20
    .equ MASK_SHIELD, 7             | bit 7 of a monster's mask: the shield
    .equ MASK_ARROW_KILLS, 6        | bit 6: an arrow kills it outright
    .equ SWORD_BLOCK_FRAMES, 160    | SwordBlockedLongTimer $10, in tenths of a second
    .equ EATEN_SHIELD_FRAMES, 0x60  | a like-like takes the magic shield after this many frames
    .equ POLS_STEPS_SHORT, 0x30
    .equ POLS_STEPS_LONG, 0x70
    .equ POLS_HOP_FRAMES, 28
    .equ MODE_DARKNUT, 18           | draw modes (tools/actors.py MODE_*)
    .equ MODE_VIRE, 19
    .equ MODE_ZOL, 20
    .equ MODE_LIKELIKE, 21
    .equ MODE_WIZZROBE, 22
    .equ MODE_BUBBLE, 23
    .equ MODE_MANHANDLA, 24
    .equ MODE_GOHMA, 25
    .equ MODE_GOHMA_LEG, 26
    .equ MODE_DIGDOGGER, 27
    .equ MODE_DIGBIG, 28

| Called once a frame from update_enemies.
dmon_tick:
    tst.b OFF_SWORD_BLOCK(%a5)
    beq 9f
    subq.b #1, OFF_SWORD_BLOCK(%a5)
9:  rts

| ------------------------------------------------------------------ what hurts
| d5 = the monster about to be hurt. Returns NE when the blow is turned aside (HIT_TYPE was set by the
| weapon, and is used up either way).
dmon_hit_filter:
    movem.l %d0-%d2/%a0, -(%sp)
    moveq #0, %d1
    move.b OFF_HIT_TYPE(%a5), %d1
    beq 8f                              | no weapon named: it is not turned aside
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmpi.b #0xff, %d0
    beq 8f                              | the overworld's blobs
    cmp.b #MON_MANHANDLA, %d0
    bne 3f
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 3f
    bra 72f                             | the body of a Manhandla takes no harm: only its hands die
3:  cmp.b #MON_GOHMA_BLUE, %d0
    beq 31f
    cmp.b #MON_GOHMA_RED, %d0
    bne 4f
31: cmp.b #HIT_ARROW, %d1               | Gohma's eye hurts only from an arrow flying up into it when it is fully open
    bne 4f
    cmpi.b #3, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 7f
    cmpi.b #DIR_UP, OFF_HIT_DIR(%a5)
    bne 7f
4:  ltab mon_mask, %a0
    move.b 0(%a0, %d0.w), %d2
    move.b %d2, %d0
    and.b %d1, %d0
    and.b #0x3f, %d0
    beq 7f                              | none of its weak points
    cmp.b #HIT_SWORD, %d1
    bne 5f
    btst #MASK_SHIELD, %d2
    beq 5f
    move.b OFF_HIT_DIR(%a5), %d0        | the shield: the sword and the darknut face each other
    or.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    cmp.b #0x0c, %d0
    beq 7f
    cmp.b #0x03, %d0
    beq 7f
5:  cmp.b #HIT_ARROW, %d1
    bne 8f
    btst #MASK_ARROW_KILLS, %d2
    beq 8f
    move.b #0xff, OFF_HIT_DAMAGE(%a5)   | an arrow kills a pols voice
8:  clr.b OFF_HIT_TYPE(%a5)
    moveq #0, %d0
    bra 9f
7:  cmp.b #HIT_BOMB, %d1
    beq 71f
    cmp.b #HIT_FIRE, %d1
    beq 71f
    sfx SFX_PARRY                       | all but fire and bombs ring off it
71: clr.b OFF_HIT_DAMAGE(%a5)
72: clr.b OFF_HIT_DAMAGE(%a5)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    clr.b OFF_HIT_TYPE(%a5)
    moveq #1, %d0
9:  tst.w %d0
    movem.l (%sp)+, %d0-%d2/%a0         | movem leaves the flags alone
    rts

| d5 = a monster that took a blow and is still alive: a zol falls into two gels, a vire into two keese.
dmon_survived:
    movem.l %d0-%d6/%a0, -(%sp)
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmp.b #MON_ZOL, %d0
    beq 1f
    cmp.b #MON_VIRE, %d0
    bne 9f
    moveq #0, %d2                       | a vire: two red keese where it stood
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    moveq #1, %d6
2:  moveq #MON_RED_KEESE, %d1
    moveq #DIR_UP, %d4
    bsr enemy_make
    bsr dmon_unhurt
    dbra %d6, 2b
    bra 9f
1:  moveq #0, %d2                       | a zol: two gels, one going each way across its heading
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #DIR_LEFT, %d4
    cmpi.b #DIR_DOWN, OFF_ENEMY_DIR(%a5, %d5.w)
    bhs 3f
    moveq #DIR_UP, %d4
3:  clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    moveq #MON_GEL, %d1
    bsr enemy_make
    bsr dmon_unhurt
    lsr.b #1, %d4
    moveq #MON_GEL, %d1
    bsr enemy_make
    bsr dmon_unhurt
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

| d0.w = a slot enemy_make returned (or -1): the new monster cannot be struck by the blow that made it.
dmon_unhurt:
    tst.w %d0
    bmi 9f
    move.b #ENEMY_SHOVE_FRAMES, OFF_ENEMY_HURT(%a5, %d0.w)
9:  rts

| Does the boomerang stun or hurt the monster d5? Returns d0.w = 1 when it does.
dmon_boomerang_hurts:
    movem.l %d1/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d1
    cmpi.b #0xff, %d1
    beq 8f
    and.w #0xff, %d1
    ltab mon_mask, %a0
    move.b 0(%a0, %d1.w), %d0
    and.w #HIT_BOOMERANG, %d0
    bra 9f
8:  moveq #HIT_BOOMERANG, %d0
9:  movem.l (%sp)+, %d1/%a0
    rts

| ------------------------------------------------------------ contact with Link
| d5 = a monster touching Link, d1.w = the damage it does. Returns d0.w = 0 for the usual shove and harm, 1 when it
| harms nobody (a bubble), 2 when it harms him but does not shove him (a like-like has hold of him).
dmon_contact:
    movem.l %d1-%d2, -(%sp)
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d2
    cmpi.b #0xff, %d2
    beq 8f
    cmp.b #MON_BUBBLE, %d2
    bne 1f
    move.b #SWORD_BLOCK_FRAMES, OFF_SWORD_BLOCK(%a5)   | the sword stops working for a while
    moveq #1, %d0
    bra 9f
1:  cmp.b #MON_LIKELIKE, %d2
    bne 8f
    tst.b OFF_LINK_EATEN(%a5)
    bne 2f
    move.b #1, OFF_LINK_EATEN(%a5)      | it swallows him
    move.b %d5, OFF_EATER(%a5)
    clr.b OFF_EATEN_FRAMES(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    clr.b OFF_COMMIT(%a5)
2:  moveq #2, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d2
    rts

| d5 = a monster that has just been killed: if it held Link, he is free.
dmon_died:
    cmpi.b #MON_MANHANDLA, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq boss_manhandla_died_f
    cmpi.b #MON_GOHMA_BLUE, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq boss_gohma_died_f
    cmpi.b #MON_GOHMA_RED, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq boss_gohma_died_f
    tst.b OFF_LINK_EATEN(%a5)
    beq 9f
    cmp.b OFF_EATER(%a5), %d5
    bne 9f
    clr.b OFF_LINK_EATEN(%a5)
9:  rts

| Called for every monster before it moves. Returns d0.w = 1 when it does nothing else this frame: a like-like
| that has Link rides on him (a few pixels ahead, so the sword still reaches it), and takes his magic shield
| after $60 frames.
dmon_eater:
    moveq #0, %d0
    tst.b OFF_LINK_EATEN(%a5)
    beq 9f
    cmp.b OFF_EATER(%a5), %d5
    bne 9f
    movem.l %d1-%d2, -(%sp)
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b OFF_LINK_DIR(%a5), %d0
    btst #0, %d0
    beq 1f
    addq.w #4, %d1
    bra 4f
1:  btst #1, %d0
    beq 2f
    subq.w #4, %d1
    bra 4f
2:  btst #2, %d0
    beq 3f
    addq.w #4, %d2
    bra 4f
3:  subq.w #4, %d2
4:  move.b %d1, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d2, OFF_ENEMY_Y(%a5, %d5.w)
    cmpi.b #0xc0, OFF_EATEN_FRAMES(%a5)
    bhs 5f
    addq.b #1, OFF_EATEN_FRAMES(%a5)
    cmpi.b #EATEN_SHIELD_FRAMES, OFF_EATEN_FRAMES(%a5)
    blo 5f
    clr.b OFF_INV_MAGIC_SHIELD(%a5)     | the shield goes, and stays gone
5:  movem.l (%sp)+, %d1-%d2
    moveq #1, %d0
9:  rts

| ------------------------------------------------------------ setting up
| d5 = the monster, d0.w = its behaviour (21 up).
dmon_init:
    movem.l %d0-%d1/%a0, -(%sp)
    cmp.w #BEH_BUBBLE, %d0
    bne 1f
    lea OFF_ENEMY_GHOST(%a5), %a0       | weapons pass through a bubble, and it is never a monster to kill
    move.b #GHOST_NOHIT, 0(%a0, %d5.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)
    bra 9f
1:  cmp.w #BEH_MANHANDLA, %d0
    bne 11f
    bsr boss_manhandla_init_f
    bra 9f
11: cmp.w #BEH_GOHMA, %d0
    bne 12f
    bsr boss_gohma_init_f
    bra 9f
12: cmp.w #BEH_DIGDOGGER, %d0
    bne 2f
    bsr boss_dig_init_f
    bra 9f
2:  cmp.w #BEH_POLS, %d0
    bne 9f
    bsr rand8
    and.w #3, %d0
    lea pols_dirs(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #POLS_STEPS_SHORT, OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

pols_dirs:
    .byte DIR_RIGHT, DIR_LEFT, DIR_DOWN, DIR_UP

| ------------------------------------------------------------------ pols voice
| It walks a straight line, a pixel every other frame, for $30 or $70 steps, then hops on the spot for 28
| frames and sets off in a new direction. ENEMY_STATE 0 walking, 1 hopping; ENEMY_TIMER the steps left, or the
| frames of the hop so far. The square it stands on is checked as it crosses a boundary: shut, and it turns about.
| d5 = monster. Returns d0.w = 1: it moves itself.
dmon_pols:
    movem.l %d1-%d3/%d6/%a0, -(%sp)
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 50f
    move.w OFF_FRAME_COUNTER(%a5), %d0
    add.w %d5, %d0
    btst #0, %d0
    bne 90f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 10f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)      | the distance is covered: hop
    bra 90f
10: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #0, %d6
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d6
    move.b %d2, %d0
    and.b #15, %d0
    bne 15f
    move.b %d3, %d0
    and.b #15, %d0
    cmp.b #13, %d0
    bne 15f
    bsr enemy_cell_blocked              | at a square boundary: is the next square open?
    tst.w %d0
    beq 15f
    bsr opposite_dir                    | no: about face
    move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
15: btst #0, %d6
    beq 16f
    addq.w #1, %d2
    bra 19f
16: btst #1, %d6
    beq 17f
    subq.w #1, %d2
    bra 19f
17: btst #2, %d6
    beq 18f
    addq.w #1, %d3
    bra 19f
18: subq.w #1, %d3
19: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bra 90f
50: move.b OFF_ENEMY_TIMER(%a5, %d5.w), %d0 | hopping
    addq.b #1, %d0
    cmp.b #POLS_HOP_FRAMES, %d0
    blo 51f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)           | landed: line up with a square and pick a new way
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    add.w #8, %d2
    and.w #0xf0, %d2
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    add.w #8, %d3
    and.w #0xf0, %d3
    sub.w #3, %d3
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bsr rand8
    move.w %d0, %d1
    and.w #3, %d1
    lea pols_dirs(%pc), %a0
    move.b 0(%a0, %d1.w), OFF_ENEMY_DIR(%a5, %d5.w)
    moveq #POLS_STEPS_SHORT, %d1
    and.b #0x40, %d0
    add.b %d0, %d1
    move.b %d1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 90f
51: move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
90: movem.l (%sp)+, %d1-%d3/%d6/%a0
    moveq #1, %d0
    rts

| ---------------------------------------------------------------- drawing
| draw_enemies: d3 = the monster, d2.w = its mode (MODE_DARKNUT up), d4.w = the frame counter plus the slot.
| Returns d1.w = the image to show (-1: nothing) and d5.w = 1 when it is to be mirrored, and sets DRAW_DY when
| the monster is drawn lower or higher than it stands. d0 (the monster's type) and d2 are kept.
dmon_frame:
    movem.l %d0/%d2/%d4/%d6/%a0, -(%sp)
    moveq #0, %d1
    moveq #0, %d5
    sub.w #MODE_DARKNUT, %d2
    beq 10f
    subq.w #1, %d2
    beq 20f
    subq.w #1, %d2
    beq 30f
    subq.w #1, %d2
    beq 40f
    subq.w #1, %d2
    beq 50f
    subq.w #1, %d2
    beq 60f
    subq.w #1, %d2
    beq 70f
    subq.w #1, %d2
    beq 80f
    subq.w #1, %d2
    beq 85f
    subq.w #1, %d2
    beq 86f
    bra 87f

10: move.w %d4, %d6                     | a darknut: the step changes every eight frames
    lsr.w #3, %d6
    and.w #1, %d6
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #2, %d2
    beq 11f
    moveq #1, %d1                       | down
    bra 14f
11: btst #3, %d2
    beq 12f
    moveq #2, %d1                       | up: the second step is the first, mirrored
    tst.w %d6
    beq 14f
    moveq #1, %d5
    bra 14f
12: btst #1, %d2
    beq 14f
    moveq #1, %d5                       | sideways, mirrored to face left
14: tst.w %d6
    beq 99f
    addq.w #3, %d1
    bra 99f

20: moveq #0, %d6                       | a vire: a new picture every ten frames, and it hops as it goes sideways
    move.w %d4, %d6
    divu.w #10, %d6
    and.w #1, %d6
    move.w %d6, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #3, %d2
    beq 21f
    addq.w #2, %d1
21: and.b #3, %d2
    beq 99f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d3.w), %d2
    and.w #15, %d2
    lea vire_hops(%pc), %a0
    move.b 0(%a0, %d2.w), OFF_DRAW_DY(%a5)
    bra 99f

30: move.w %d4, %d1                     | a zol or pols voice: two pictures, swapped every eight frames
    lsr.w #3, %d1
    and.w #1, %d1
    cmpi.b #MON_POLS, OFF_ENEMY_TYPE(%a5, %d3.w)
    bne 99f
    tst.b OFF_ENEMY_STATE(%a5, %d3.w)
    beq 99f
    moveq #0, %d6                       | in the air: up by t * (28 - t) / 9
    move.b OFF_ENEMY_TIMER(%a5, %d3.w), %d6
    moveq #POLS_HOP_FRAMES, %d2
    sub.w %d6, %d2
    bmi 99f
    mulu.w %d6, %d2
    divu.w #9, %d2
    neg.b %d2
    move.b %d2, OFF_DRAW_DY(%a5)
    bra 99f

40: move.w %d4, %d1                     | a like-like: four pictures, eight frames each
    lsr.w #3, %d1
    and.w #3, %d1
    tst.b OFF_LINK_EATEN(%a5)
    beq 99f
    cmp.b OFF_EATER(%a5), %d3
    bne 99f
    moveq #0, %d1                       | with Link inside it climbs to the last picture and stays
    move.b OFF_EATEN_FRAMES(%a5), %d1
    lsr.w #3, %d1
    cmp.w #3, %d1
    bls 99f
    moveq #3, %d1
    bra 99f

50: bsr boss_wizzrobe_frame_f             | a wizzrobe
    bra 99f

60: move.w %d4, %d1                     | a bubble: a new palette row every frame
    and.w #3, %d1
    bra 99f

70: lea OFF_ENEMY_ANIMF(%a5), %a0       | a Manhandla piece: ANIMF holds the picture of its animation
    moveq #0, %d1
    move.b 0(%a0, %d3.w), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_STEP(%a5, %d3.w), %d2
    lea manhandla_images(%pc), %a0
    moveq #0, %d6
    move.b 0(%a0, %d2.w), %d6
    add.w %d6, %d1
    cmp.w #4, %d2
    bne 99f
    moveq #1, %d5                       | the right hand is the left one turned round
    bra 99f

80: move.b OFF_ENEMY_STATE(%a5, %d3.w), %d1    | Gohma's eye: the picture is its state
    and.w #3, %d1
    bra 99f

85: move.w %d4, %d1                     | its legs: a step every 16 frames, the second leg a step behind
    lsr.w #4, %d1
    moveq #0, %d6
    move.b OFF_ENEMY_STEP(%a5, %d3.w), %d6
    subq.w #1, %d6
    add.w %d6, %d1
    and.w #1, %d1
    bra 99f

86: move.w %d4, %d1                     | a little Digdogger: two pictures, swapped every eight frames
    lsr.w #3, %d1
    and.w #1, %d1
    bra 99f

87: moveq #0, %d1                       | a quarter of a big one: its place in the square is its picture
    move.b OFF_ENEMY_STEP(%a5, %d3.w), %d1
    and.w #3, %d1
99: movem.l (%sp)+, %d0/%d2/%d4/%d6/%a0
    rts

| The vire's hop: how far above the ground it is at each pixel of a square (the running total of
| VireJumpOffsets).
vire_hops:
    .byte 0, -3, -5, -6, -7, -7, -8, -8, -8, -7, -7, -6, -5, -3, 0, 0

| Trampolines to the bosses' code at the end of the image (bosses.s).
    farstub boss_wizzrobe_f, dmon_wizzrobe
    farstub boss_wizzrobe_frame_f, dmon_wizzrobe_frame
    farstub boss_manhandla_f, dmon_manhandla
    farstub boss_manhandla_init_f, manhandla_init
    farstub boss_manhandla_died_f, manhandla_died
    farstub boss_gohma_f, dmon_gohma
    farstub boss_gohma_init_f, gohma_init
    farstub boss_gohma_died_f, gohma_died
    farstub boss_dig_f, dmon_dig
    farstub boss_dig_init_f, dig_init
    farstub boss_dig_flute_f, dig_flute
