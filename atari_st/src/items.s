| The B button's items beyond the bombs, the boomerang and the candle: the bow with its arrows, the
| recorder, the food, the potion and the magic rod, and the table that says which of them Link owns.
| The ROM's WieldItem_JumpTable picks them in the order boomerang, bomb, arrow, (bow), candle,
| flute, food, potion, rod; the B codes below are this port's numbering of the same list.

    .equ B_NOTHING, 0
    .equ B_BOMB, 1
    .equ B_BOOMERANG, 2
    .equ B_CANDLE, 3
    .equ B_BOW, 4
    .equ B_RECORDER, 5
    .equ B_FOOD, 6
    .equ B_POTION, 7
    .equ B_ROD, 8
    .equ B_LAST, 8

    .equ ARROW_FLY_SPEED, 192           | WieldWeapon: QSpeed $C0, three pixels a frame
    .equ MAGIC_FLY_SPEED, 160           | the rod's shot is slower: $A0
    .equ LSHOT_LEAD, 16                 | a shot starts a sprite ahead of Link
    .equ LSHOT_RANGE, 11                | CheckMonsterShotCollision's threshold
    .equ ARROW_HITS, 2                  | $20 damage points: two sword hits' worth; silver arrows $40
    .equ MAGIC_HITS, 2                  | the rod's shot is $20 too, and the rod itself
    .equ ROD_STAB_HITS, 2
    .equ FOOD_FRAMES, 255               | the food lasts $FF frames
    .equ FOOD_SLOT, 2                   | and takes the last item slot
    .equ ITEM_FOOD_STATE, 5             | ITEM_ACTIVE value of food on the floor: drawn, never picked up
    .equ FLUTE_FRAMES, 0x98             | FluteTimer
    .equ HEART_FILL_FRAMES, 21          | World_FillHearts: a half heart every 21 frames
    .equ SPARK_FRAMES_SHOT, 3

| The Items byte(s) each B code needs: slot, second slot, and whether both are needed (the bow needs
| arrows) or either will do (the boomerang or the magic one).
b_slots:
    .byte 0, 0, 0
    .byte 1, 1, 0                       | bombs
    .byte 29, 30, 0                     | boomerang, magic boomerang
    .byte 4, 4, 0                       | candle
    .byte 3, 2, 1                       | bow, arrows
    .byte 5, 5, 0                       | recorder
    .byte 6, 6, 0                       | food
    .byte 7, 7, 0                       | potion
    .byte 8, 8, 0                       | rod
    .align 2

| The ribbon and inventory picture of each B code (hud_items order, tools/actors.py HUD_ITEM_IDS).
b_icons:
    .byte 0, 1, 2, 3, 6, 7, 8, 9, 11
    .align 2

| d0.w = B code. Returns d0.w = 1 when Link owns what it needs.
b_item_owned:
    movem.l %d1-%d2/%a0-%a1, -(%sp)
    cmp.w #B_LAST, %d0
    bhi 8f
    tst.w %d0
    beq 8f
    lea b_slots(%pc), %a0
    move.w %d0, %d1
    add.w %d0, %d1
    add.w %d0, %d1
    adda.w %d1, %a0
    lea OFF_ITEMS(%a5), %a1
    moveq #0, %d1
    move.b (%a0)+, %d1
    move.b 0(%a1, %d1.w), %d2
    moveq #0, %d1
    move.b (%a0)+, %d1
    move.b 0(%a1, %d1.w), %d1
    tst.b (%a0)
    bne 5f
    or.b %d1, %d2                       | either one
    beq 8f
    bra 7f
5:  tst.b %d2                           | both
    beq 8f
    tst.b %d1
    beq 8f
7:  moveq #1, %d0
    bra 9f
8:  moveq #0, %d0
9:  movem.l (%sp)+, %d1-%d2/%a0-%a1
    rts

| d0.w = B code. Returns d0.w = its picture in hud_items: a red candle, a magic boomerang and a red
| potion look different from the first ones.
b_icon:
    movem.l %d1/%a0, -(%sp)
    lea b_icons(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    cmp.w #B_BOOMERANG, %d0
    bne 1f
    tst.b OFF_INV_MAGIC_BOOMERANG(%a5)
    beq 9f
    moveq #12, %d1
    bra 9f
1:  cmp.w #B_CANDLE, %d0
    bne 2f
    cmpi.b #2, OFF_INV_CANDLE(%a5)
    bne 9f
    moveq #13, %d1
    bra 9f
2:  cmp.w #B_POTION, %d0
    bne 9f
    cmpi.b #2, OFF_INV_POTION(%a5)
    bne 9f
    moveq #10, %d1
9:  move.w %d1, %d0
    movem.l (%sp)+, %d1/%a0
    rts

| The B button never rests on something Link does not have: it moves to the first thing he does, or
| to nothing.
b_item_fix:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d0
    move.b OFF_B_ITEM(%a5), %d0
    bsr b_item_owned
    tst.w %d0
    bne 9f
    moveq #1, %d1
1:  move.w %d1, %d0
    bsr b_item_owned
    tst.w %d0
    bne 2f
    addq.w #1, %d1
    cmp.w #B_LAST, %d1
    bls 1b
    moveq #0, %d1
2:  cmp.b OFF_B_ITEM(%a5), %d1
    beq 9f
    move.b %d1, OFF_B_ITEM(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
9:  movem.l (%sp)+, %d0-%d1
    rts

| d0.w = the B code: do what the button does.
b_item_use:
    cmp.w #B_BOMB, %d0
    bne 2f
    bra place_bomb
2:  cmp.w #B_BOOMERANG, %d0
    bne 3f
    bra throw_boomerang
3:  cmp.w #B_CANDLE, %d0
    bne 4f
    bra use_candle
4:  cmp.w #B_BOW, %d0
    bne 5f
    bra use_bow
5:  cmp.w #B_RECORDER, %d0
    bne 6f
    bra use_recorder
6:  cmp.w #B_FOOD, %d0
    bne 7f
    bra use_food
7:  cmp.w #B_POTION, %d0
    bne 8f
    bra use_potion
8:  cmp.w #B_ROD, %d0
    bne 9f
    bra use_rod
9:  rts

| ------------------------------------------------------------ shots of Link's
| Where a shot of Link's starts: a sprite ahead of him. Returns d1.w = X, d2.w = Y, d0.b = his direction.
lshot_origin:
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b OFF_LINK_DIR(%a5), %d0
    btst #0, %d0
    beq 2f
    add.w #LSHOT_LEAD, %d1
    rts
2:  btst #1, %d0
    beq 3f
    sub.w #LSHOT_LEAD, %d1
    rts
3:  btst #2, %d0
    beq 4f
    add.w #LSHOT_LEAD, %d2
    rts
4:  sub.w #LSHOT_LEAD, %d2
    rts

| Launch a shot of kind d3.b at speed d4.w in Link's direction. Returns d0.w = -1 when there is no
| room for it (no free slot, or a wall right in front of him).
lshot_launch:
    movem.l %d1-%d2/%d5/%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    bsr proj_alloc
    tst.w %d0
    bmi 9f
    move.w %d0, %d5
    bsr lshot_origin
    movem.l %d2-%d3, -(%sp)
    move.w %d2, %d3                     | enemy_blocked_at wants d2 = X, d3 = Y
    move.w %d1, %d2
    bsr enemy_blocked_at
    movem.l (%sp)+, %d2-%d3
    tst.w %d0
    bne 8f
    move.b %d3, PJ_KIND(%a4, %d5.w)
    move.b %d1, PJ_X(%a4, %d5.w)
    move.b %d2, PJ_Y(%a4, %d5.w)
    move.b OFF_LINK_DIR(%a5), %d0
    move.b %d0, PJ_DIR(%a4, %d5.w)
    clr.b PJ_FRACX(%a4, %d5.w)
    clr.b PJ_FRACY(%a4, %d5.w)
    clr.b PJ_QX(%a4, %d5.w)
    clr.b PJ_QY(%a4, %d5.w)
    clr.b PJ_TIMER(%a4, %d5.w)
    and.b #DIR_VERTICAL, %d0
    bne 6f
    move.b %d4, PJ_QX(%a4, %d5.w)
    bra 7f
6:  move.b %d4, PJ_QY(%a4, %d5.w)
7:  moveq #0, %d0
    bra 9f
8:  moveq #-1, %d0
9:  movem.l (%sp)+, %d1-%d2/%d5/%a4
    rts

| Is a shot of kind d3.b in the air? Returns d0.w = 1 if so.
lshot_in_flight:
    movem.l %d1/%a4, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a4
    moveq #(MAX_PROJ - 1), %d1
1:  cmp.b 0(%a4, %d1.w), %d3
    beq 8f
    dbra %d1, 1b
    moveq #0, %d0
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1/%a4
    rts

| The bow: an arrow costs a rupee (WieldArrow) and one flies at a time.
use_bow:
    movem.l %d0/%d3-%d4, -(%sp)
    tst.b OFF_INV_BOW(%a5)
    beq 9f
    tst.b OFF_INV_ARROW(%a5)
    beq 9f
    tst.b OFF_INV_RUPEES(%a5)
    beq 9f
    moveq #PK_LARROW, %d3
    bsr lshot_in_flight
    tst.w %d0
    bne 9f
    move.w #ARROW_FLY_SPEED, %d4
    bsr lshot_launch
    tst.w %d0
    bmi 9f
    subq.b #1, OFF_INV_RUPEES(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    sfx SFX_ARROW
9:  movem.l (%sp)+, %d0/%d3-%d4
    rts

| The rod swings like the sword and always sends its magic shot out at the third phase.
use_rod:
    tst.b OFF_ATTACK(%a5)
    bne 9f
    move.b #1, OFF_ATTACK_ROD(%a5)
    move.b #ATTACK_FRAMES, OFF_ATTACK(%a5)
    sfx SFX_SWORD
9:  rts

rod_launch:
    movem.l %d0/%d3-%d4, -(%sp)
    moveq #PK_LMAGIC, %d3
    bsr lshot_in_flight
    tst.w %d0
    bne 9f
    move.w #MAGIC_FLY_SPEED, %d4
    bsr lshot_launch
    tst.w %d0
    bmi 9f
    sfx SFX_MAGIC
9:  movem.l (%sp)+, %d0/%d3-%d4
    rts

| A shot of Link's (kind d0.b in slot d7, a4 = PROJ_KIND): it flies until a wall or a monster stops it.
lshot_update:
    movem.l %d0-%d6, -(%sp)
    cmp.b #PK_LARROW_SPARK, %d0
    beq 40f
    bsr proj_move
    tst.w %d0
    bne 30f                         | the edge of the room
    bsr shot_blocked
    tst.w %d0
    bne 30f                         | a wall
    moveq #0, %d2
    move.b PJ_X(%a4, %d7.w), %d2
    moveq #0, %d3
    move.b PJ_Y(%a4, %d7.w), %d3
    bsr lshot_collide
    tst.w %d0
    beq 9f
    cmpi.b #PK_LMAGIC, PJ_KIND(%a4, %d7.w)
    beq 31f
30: cmpi.b #PK_LMAGIC, PJ_KIND(%a4, %d7.w)
    beq 32f
31: move.b #PK_LARROW_SPARK, PJ_KIND(%a4, %d7.w)    | an arrow, or a shot that struck something, sparks and goes
    move.b #SPARK_FRAMES_SHOT, PJ_TIMER(%a4, %d7.w)
    bra 9f
32: tst.b OFF_INV_BOOK(%a5)             | the rod's shot at a wall: with the book it becomes a flame
    beq 31b
    bsr lshot_fire
    clr.b PJ_KIND(%a4, %d7.w)
    bra 9f
40: subq.b #1, PJ_TIMER(%a4, %d7.w)
    bne 9f
    clr.b PJ_KIND(%a4, %d7.w)
9:  movem.l (%sp)+, %d0-%d6
    rts

| The book turns the magic shot into fire where it stops: a flame stands there for a while.
lshot_fire:
    tst.b OFF_FIRE_STATE(%a5)
    bne 9f
    move.b PJ_X(%a4, %d7.w), OFF_FIRE_X(%a5)
    move.b PJ_Y(%a4, %d7.w), OFF_FIRE_Y(%a5)
    move.b PJ_DIR(%a4, %d7.w), OFF_FIRE_DIR(%a5)
    move.b #FIRE_STAND_FRAMES, OFF_FIRE_TIMER(%a5)
    move.b #2, OFF_FIRE_STATE(%a5)
    sfx SFX_FLAME
9:  rts

| The shot at (d2, d3) hits a monster: returns d0.w = 1 when it did. The weight of the blow is the
| arrow's (silver ones double), or the magic shot's.
lshot_collide:
    movem.l %d1-%d6/%a0, -(%sp)
    moveq #0, %d6
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 8f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 7f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 7f
    bsr enemy_behaviour
    cmp.w #BEH_TRAP, %d0
    beq 7f
    bsr enemy_untouchable
    bne 7f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    sub.w %d2, %d0
    bpl 2f
    neg.w %d0
2:  cmp.w #LSHOT_RANGE, %d0
    bhs 7f
    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    sub.w %d3, %d0
    bpl 3f
    neg.w %d0
3:  cmp.w #LSHOT_RANGE, %d0
    bhs 7f
    moveq #1, %d6
    moveq #MAGIC_HITS, %d1
    cmpi.b #PK_LARROW, PJ_KIND(%a4, %d7.w)
    bne 4f
    moveq #ARROW_HITS, %d1
    cmpi.b #2, OFF_INV_ARROW(%a5)
    bne 4f
    add.w %d1, %d1                  | silver arrows: $40
4:  move.b %d1, OFF_HIT_DAMAGE(%a5)
    move.b #HIT_MAGIC, OFF_HIT_TYPE(%a5)
    cmpi.b #PK_LARROW, PJ_KIND(%a4, %d7.w)
    bne 41f
    move.b #HIT_ARROW, OFF_HIT_TYPE(%a5)
41: move.b PJ_DIR(%a4, %d7.w), OFF_HIT_DIR(%a5)
    move.b PJ_DIR(%a4, %d7.w), OFF_ENEMY_SHOVE(%a5, %d5.w)
    movem.l %d2-%d3, -(%sp)
    bsr hit_enemy
    movem.l (%sp)+, %d2-%d3
    bra 8f
7:  addq.w #1, %d5
    bra 1b
8:  move.w %d6, %d0
    movem.l (%sp)+, %d1-%d6/%a0
    rts

| Which picture a shot of Link's draws as: d0.b = its kind. Returns d0.b = the monster shot kind whose
| picture it borrows (an arrow, the sword shot), or 0 for a spark.
lshot_picture:
    cmp.b #PK_LARROW, %d0
    bne 1f
    moveq #PK_ARROW, %d0
    rts
1:  cmp.b #PK_LMAGIC, %d0
    bne 2f
    moveq #PK_SWORDSHOT, %d0
    rts
2:  moveq #0, %d0
    rts

| --------------------------------------------------------------------- potion
| WieldPotion: one dose is used and his hearts fill, a half heart at a time, with the game paused.
use_potion:
    tst.b OFF_INV_POTION(%a5)
    beq 9f
    tst.b OFF_HEART_FILL(%a5)
    bne 9f
    subq.b #1, OFF_INV_POTION(%a5)
    move.b #1, OFF_HEART_FILL(%a5)
    move.b #HEART_FILL_FRAMES, OFF_HEART_FILL_T(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    clr.b OFF_ATTACK(%a5)
9:  rts

heart_fill_update:
    tst.b OFF_HEART_FILL(%a5)
    beq 9f
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    add.w %d0, %d0
    cmp.b OFF_HP_HALVES(%a5), %d0
    bhi 1f
    clr.b OFF_HEART_FILL(%a5)           | full: play on
    clr.b OFF_LINK_HELD(%a5)
    clr.b OFF_HP_FRAC(%a5)
    bra 8f
1:  subq.b #1, OFF_HEART_FILL_T(%a5)
    bne 8f
    move.b #HEART_FILL_FRAMES, OFF_HEART_FILL_T(%a5)
    moveq #1, %d1
    bsr heal_link
    sfx SFX_HEART
8:  movem.l (%sp)+, %d0-%d1
9:  rts

| -------------------------------------------------------------------- recorder
| WieldFlute: the tune plays and the flute timer runs. (The whirlwind and the secrets it opens belong
| to the overworld specials.)
use_recorder:
    tst.b OFF_FLUTE_TIMER(%a5)
    bne 9f
    move.b #FLUTE_FRAMES, OFF_FLUTE_TIMER(%a5)
    jingle SFX_RECORDER
    bsr boss_dig_flute_f                | a big Digdogger splits up
9:  rts

flute_update:
    tst.b OFF_FLUTE_TIMER(%a5)
    beq 9f
    subq.b #1, OFF_FLUTE_TIMER(%a5)
9:  rts

| ------------------------------------------------------------------------ food
| WieldFood: it is put down in front of Link and every monster that chases him chases it instead,
| until it is gone $FF frames later.
use_food:
    movem.l %d0-%d2, -(%sp)
    tst.b OFF_FOOD_TIMER(%a5)
    bne 9f
    tst.b (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
    bne 9f                              | a drop is lying in the slot
    bsr lshot_origin
    move.b #ITEM_FOOD, (OFF_ITEM_ID + FOOD_SLOT)(%a5)
    move.b %d1, (OFF_ITEM_X + FOOD_SLOT)(%a5)
    move.b %d2, (OFF_ITEM_Y + FOOD_SLOT)(%a5)
    move.b #ITEM_FOOD_STATE, (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
    move.b #FOOD_FRAMES, OFF_FOOD_TIMER(%a5)
9:  movem.l (%sp)+, %d0-%d2
    rts

food_update:
    tst.b OFF_FOOD_TIMER(%a5)
    beq 9f
    subq.b #1, OFF_FOOD_TIMER(%a5)
    bne 9f
    clr.b (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
9:  rts

| ChaseTarget: where the monsters that chase are heading, Link or the food.
chase_target_update:
    tst.b OFF_FOOD_TIMER(%a5)
    beq 1f
    cmpi.b #ITEM_FOOD_STATE, (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
    bne 1f
    move.b (OFF_ITEM_X + FOOD_SLOT)(%a5), OFF_CHASE_X(%a5)
    move.b (OFF_ITEM_Y + FOOD_SLOT)(%a5), OFF_CHASE_Y(%a5)
    rts
1:  move.b OFF_LINK_X(%a5), OFF_CHASE_X(%a5)
    move.b OFF_LINK_Y(%a5), OFF_CHASE_Y(%a5)
    rts

| Everything the items need once a frame.
items_update:
    bsr heart_fill_update
    bsr flute_update
    bra food_update
