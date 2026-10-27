| Combat and pickups: the sword, damage in both directions, monster drops and
| the items lying on the floor.
|
| Simplification against the original, to be revisited: one sword damage.

    .equ SCAN_SPACE, 0x39           | A: the sword, like the joystick's fire button
    .equ SCAN_CTRL, 0x1d            | B: the selected item, like Alternate
    .equ SCAN_ALT, 0x38
    .equ ATTACK_FRAMES, 12
    .equ BEAM_PHASE, 3              | ATTACK value of the third phase, when the shot leaves
    .equ SWORD_REACH, 12
    .equ ENEMY_HURT_FRAMES, 32      | ObjInvincibilityTimer $10, counted down every second frame
    .equ LINK_HURT_FRAMES, 48       | $18, likewise: about 0.8 seconds
    .equ LINK_SHOVE_PIXELS, 32
    .equ CONTACT_RANGE, 10
    .equ PICKUP_RANGE, 9
    .equ ITEM_SLOTS, 3
    .equ KILL_CYCLE_LENGTH, 10
    .equ ROOM_ITEM_HIDDEN, 3
    .equ TRIGGER_KILL_ITEM, 7

    .equ ITEM_BOMBS, 0x00
    .equ ITEM_BLUE_CANDLE, 0x06
    .equ ITEM_BOOMERANG, 0x1d
    .equ ITEM_BOW, 0x0a
    .equ LIFT_FRAMES, 128            | ItemLiftTimer: the original holds the item up for $80 frames
    .equ ITEM_WOOD_SWORD, 0x01
    .equ ITEM_FIVE_RUPEES, 0x0f
    .equ ITEM_RUPEE, 0x18
    .equ ITEM_KEY, 0x19
    .equ ITEM_HEART_CONTAINER, 0x1a
    .equ ITEM_TRIFORCE, 0x1b
    .equ ITEM_COMPASS, 0x16
    .equ ITEM_MAP, 0x17
    .equ ENDING_HOLD_FRAMES, 48      | UpdateMode12EndLevel_Sub0: Link holds the piece up
    .equ ENDING_FLASH_FRAMES, 48     | Sub1: the screen flashes
    .equ ENDING_HEART_FRAMES, 21     | World_FillHearts adds 6 of 248 a frame: a heart takes ~43 frames
    .equ ENDING_CURTAIN_FRAMES, 5    | UpdateWorldCurtainEffect: a step every 4-5 frames
    .equ ENDING_CURTAIN_STEPS, 16    | from column $20 and column 1 to the middle
    .equ ENDING_PAUSE_FRAMES, 128    | Sub4: the black room with Link and the piece
    .equ ITEM_LINK_LIFT, 0x3f        | the item picture of Link with his arms up (not an item)
    .equ ITEM_LIFTED, 4              | the triforce piece over Link's head: drawn, never picked up
    .equ ITEM_WHITE_SWORD, 0x02
    .equ ITEM_MAGIC_SWORD, 0x03
    .equ ITEM_FOOD, 0x04
    .equ ITEM_RECORDER, 0x05
    .equ ITEM_RED_CANDLE, 0x07
    .equ ITEM_ARROW, 0x08
    .equ ITEM_SILVER_ARROW, 0x09
    .equ ITEM_MAGIC_KEY, 0x0b
    .equ ITEM_RAFT, 0x0c
    .equ ITEM_LADDER, 0x0d
    .equ ITEM_ROD, 0x10
    .equ ITEM_BOOK, 0x11
    .equ ITEM_BLUE_RING, 0x12
    .equ ITEM_RED_RING, 0x13
    .equ ITEM_BRACELET, 0x14
    .equ ITEM_LETTER, 0x15
    .equ ITEM_MAGIC_SHIELD, 0x1c
    .equ ITEM_MAGIC_BOOMERANG, 0x1e
    .equ ITEM_BLUE_POTION, 0x1f
    .equ ITEM_RED_POTION, 0x20
    .equ ITEM_CLOCK, 0x21
    .equ ITEM_HEART, 0x22
    .equ ITEM_FAIRY, 0x23
    .equ HELP_KILLS, 10
    .equ FAIRY_KILLS, 0x10

| ------------------------------------------------------------------- sword
| The joystick's fire button and Space start a swing, once per press, when Link
| owns a sword.
sword_input:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_SPACE(%a0)
    bne 1f
    move.b OFF_JOY0(%a5), %d0
    or.b OFF_JOY1(%a5), %d0
    bpl 2f                      | fire is bit 7
1:  tst.b OFF_SPACE_HELD(%a5)
    bne 9f
    move.b #1, OFF_SPACE_HELD(%a5)
    tst.b OFF_HAS_SWORD(%a5)
    beq 9f
    tst.b OFF_SWORD_BLOCK(%a5)
    bne 9f                      | a flashing bubble has touched it
    tst.b OFF_SWORD_LOCK(%a5)
    bne 9f                      | a red bubble has locked it
    tst.b OFF_ATTACK(%a5)
    bne 9f
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    clr.b OFF_ATTACK_ROD(%a5)
    move.b #ATTACK_FRAMES, OFF_ATTACK(%a5)
    sfx SFX_SWORD
    bra 9f
2:  clr.b OFF_SPACE_HELD(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

| The blade's position: d1.w = X, d2.w = Y, d0.w = frame (up, down, left, right).
sword_pos:
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b OFF_LINK_DIR(%a5), %d0
    btst #0, %d0
    beq 1f
    add.w #SWORD_REACH, %d1
    moveq #3, %d0
    rts
1:  btst #1, %d0
    beq 2f
    sub.w #SWORD_REACH, %d1
    moveq #2, %d0
    rts
2:  btst #2, %d0
    beq 3f
    add.w #SWORD_REACH, %d2
    moveq #1, %d0
    rts
3:  sub.w #SWORD_REACH, %d2
    moveq #0, %d0
    rts

erase_sword:
    tst.b OFF_SWORD_VALID(%a5)
    beq 9f
    move.l %d0, -(%sp)
    move.l OFF_SWORD_ERASE_OFFSET(%a5), %d0
    bsr erase_at
    clr.b OFF_SWORD_VALID(%a5)
    move.l (%sp)+, %d0
9:  rts

draw_sword:
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    moveq #0, %d3
    move.b OFF_ATTACK(%a5), %d3
    beq 9f
    moveq #(ATTACK_FRAMES - 1), %d4
    sub.w %d3, %d4              | 0 for the frame the swing starts on
    beq 9f                      | the sword is not out yet
    moveq #0, %d3               | extended for eight frames, then drawn back in
    cmp.w #8, %d4
    ble 1f
    moveq #8, %d3
    cmp.w #9, %d4
    beq 1f
    moveq #16, %d3
1:  bsr sword_pos                | d0 = which way it points
    move.w %d0, %d5
    add.w %d0, %d0
    add.w %d0, %d3
    moveq #3, %d0                       | the rod's pictures follow the three swords'
    tst.b OFF_ATTACK_ROD(%a5)
    bne 5f
    moveq #0, %d0
    move.b OFF_HAS_SWORD(%a5), %d0
    subq.w #1, %d0
    bpl 5f
    moveq #0, %d0
5:  lsl.w #2, %d0
    add.w %d0, %d5
    lea sword_offsets(%pc), %a0
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    move.b 0(%a0, %d3.w), %d4
    ext.w %d4
    add.w %d4, %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b 1(%a0, %d3.w), %d4
    ext.w %d4
    add.w %d4, %d2
    mulu.w #SPRITE_FRAME_BYTES, %d5
    ltab sword_sprites, %a0
    adda.l %d5, %a0
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.l %d1, OFF_SWORD_ERASE_OFFSET(%a5)
    move.b #1, OFF_SWORD_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d5/%a0-%a1
    rts

| PlayerToWeaponOffsetsX/Y for the three drawn phases (fully out, drawn back,
| almost in), each as X, Y for up, down, left, right.
sword_offsets:
    .byte -1, -10, 1, 13, -11, 3, 11, 3
    .byte -1, -9, 1, 9, -7, 3, 7, 3
    .byte -1, -1, 1, 5, -3, 3, 3, 3
    .align 2

| ------------------------------------------------------------- sword beam
| With all hearts full a swing also sends the sword flying (MakeSwordShot wants the last heart's partial at
| $80 or more, and the lightest blow takes it to $7F, so half a heart short is already too little), at three pixels a frame, until it leaves the room's bounds or hits a monster (it flies over trees, stones and walls).
    .equ BEAM_SPEED, 3
    .equ BEAM_LEAD, 16

beam_launch:
    movem.l %d0-%d4, -(%sp)
    tst.b OFF_BEAM_ACTIVE(%a5)
    bne 9f
    tst.b OFF_SPARK_K(%a5)
    bne 9f                      | the last shot is still spreading out
    moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    add.w %d0, %d0
    moveq #0, %d1
    move.b OFF_HP_HALVES(%a5), %d1
    cmp.w %d0, %d1
    blo 9f
    bsr sword_pos
    cmp.w #3, %d0               | start the shot a full sprite ahead of Link
    bne 1f
    addq.w #(BEAM_LEAD - SWORD_REACH), %d1
    bra 4f
1:  cmp.w #2, %d0
    bne 2f
    subq.w #(BEAM_LEAD - SWORD_REACH), %d1
    bra 4f
2:  cmp.w #1, %d0
    bne 3f
    addq.w #(BEAM_LEAD - SWORD_REACH), %d2
    bra 4f
3:  subq.w #(BEAM_LEAD - SWORD_REACH), %d2
4:  move.w %d2, %d3
    move.w %d1, %d2
    move.b %d2, OFF_BEAM_X(%a5)
    move.b %d3, OFF_BEAM_Y(%a5)
    move.b OFF_LINK_DIR(%a5), OFF_BEAM_DIR(%a5)
    move.b #1, OFF_BEAM_ACTIVE(%a5)
    sfx SMP_BEAM
9:  movem.l (%sp)+, %d0-%d4
    rts

beam_update:
    movem.l %d0-%d6/%a0, -(%sp)
    tst.b OFF_SPARK_K(%a5)
    beq 0f
    addq.b #1, OFF_SPARK_K(%a5)
    cmpi.b #SPARK_LAST, OFF_SPARK_K(%a5)
    bls 0f
    clr.b OFF_SPARK_K(%a5)
0:  tst.b OFF_BEAM_ACTIVE(%a5)
    beq 9f
    moveq #0, %d2
    move.b OFF_BEAM_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_BEAM_Y(%a5), %d3
    moveq #0, %d6
    move.b OFF_BEAM_DIR(%a5), %d6

    | MoveShot: BoundByRoomWithA looks at the room's bounds only (a weapon's offsets: X+$B < left or
    | X-$C >= right, Y+$F < up or Y-$12 >= down) and then the shot flies on whatever tiles lie in its way,
    | trees, stones and walls included. The bound is met before the move, so the spark opens where it stands.
    moveq #0, %d1
    btst #0, %d6
    bne 10f
    btst #1, %d6
    beq 20f
10: move.b %d2, %d1
    add.b #0x0b, %d1
    cmp.b OFF_OBJ_LEFT(%a5), %d1
    blo 8f
    sub.b #0x17, %d1
    cmp.b OFF_OBJ_RIGHT(%a5), %d1
    bhs 8f
    bra 21f
20: move.b %d3, %d1
    add.b #0x0f, %d1
    cmp.b OFF_OBJ_UP(%a5), %d1
    blo 8f
    sub.b #0x21, %d1
    cmp.b OFF_OBJ_DOWN(%a5), %d1
    bhs 8f
21: btst #0, %d6
    beq 1f
    addq.w #BEAM_SPEED, %d2
    bra 4f
1:  btst #1, %d6
    beq 2f
    subq.w #BEAM_SPEED, %d2
    bra 4f
2:  btst #2, %d6
    beq 3f
    addq.w #BEAM_SPEED, %d3
    bra 4f
3:  subq.w #BEAM_SPEED, %d3

4:  move.w %d2, %d4
    move.w %d3, %d5
    move.b %d4, OFF_BEAM_X(%a5)
    move.b %d5, OFF_BEAM_Y(%a5)

    moveq #0, %d6                       | monsters in the way
5:  cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 7f
    tst.b OFF_ENEMY_HURT(%a5, %d6.w)
    bne 7f
    exg %d5, %d6
    bsr enemy_untouchable
    exg %d5, %d6
    bne 7f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d6.w), %d0
    sub.w %d4, %d0
    bpl 51f
    neg.w %d0
51: cmp.w #SWORD_REACH, %d0
    bhs 7f
    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d6.w), %d0
    sub.w %d5, %d0
    bpl 52f
    neg.w %d0
52: cmp.w #SWORD_REACH, %d0
    bhs 7f
    move.w %d6, %d5
    move.b OFF_BEAM_DIR(%a5), OFF_ENEMY_SHOVE(%a5, %d5.w)
    bsr set_sword_damage
    move.b #HIT_SWORD, OFF_HIT_TYPE(%a5)
    move.b OFF_BEAM_DIR(%a5), OFF_HIT_DIR(%a5)
    bsr hit_enemy
    bra 8f
7:  addq.w #1, %d6
    bra 5b
8:  clr.b OFF_BEAM_ACTIVE(%a5)
    move.b OFF_BEAM_X(%a5), OFF_SPARK_X(%a5)
    move.b OFF_BEAM_Y(%a5), OFF_SPARK_Y(%a5)
    move.b #SPARK_FIRST, OFF_SPARK_K(%a5)
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

erase_beam:
    tst.b OFF_BEAM_VALID(%a5)
    beq 9f
    move.l %d0, -(%sp)
    move.l OFF_BEAM_ERASE_OFFSET(%a5), %d0
    bsr erase_at
    clr.b OFF_BEAM_VALID(%a5)
    move.l (%sp)+, %d0
9:  rts

draw_beam:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    tst.b OFF_BEAM_ACTIVE(%a5)
    beq 9f
    moveq #3, %d0                       | frame: up, down, left, right
    move.b OFF_BEAM_DIR(%a5), %d3
    btst #0, %d3
    bne 1f
    moveq #2, %d0
    btst #1, %d3
    bne 1f
    moveq #1, %d0
    btst #2, %d3
    bne 1f
    moveq #0, %d0
1:  lsl.w #2, %d0                       | four palette rows per direction, cycled every frame
    move.w OFF_FRAME_COUNTER(%a5), %d1
    and.w #3, %d1
    add.w %d1, %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab beam_sprites, %a0
    adda.l %d0, %a0
    moveq #0, %d1
    moveq #0, %d2
    move.b OFF_BEAM_X(%a5), %d1
    move.b OFF_BEAM_Y(%a5), %d2
    btst #3, %d3
    bne 2f
    btst #2, %d3
    bne 2f
    addq.w #3, %d2                      | a sideways shot is drawn three pixels lower
2:  bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.l %d1, OFF_BEAM_ERASE_OFFSET(%a5)
    move.b #1, OFF_BEAM_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| ------------------------------------------------------------------ effects
| The sword shot's spark (slots 0-3, one per corner) and the bomb's cloud (slot 4
| in the middle, 5-7 the puffs round it) are drawn from fx_sprites.
erase_effects:
    movem.l %d0/%d3/%a0-%a1, -(%sp)
    lea OFF_FX_ERASE_OFFSETS(%a5), %a0
    lea OFF_FX_VALID(%a5), %a1
    moveq #0, %d3
1:  tst.b 0(%a1, %d3.w)
    beq 2f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at
    clr.b 0(%a1, %d3.w)
2:  addq.w #1, %d3
    cmp.w #36, %d3
    blo 1b
    movem.l (%sp)+, %d0/%d3/%a0-%a1
    rts

| d0.w = frame in fx_sprites, d1.w = X, d2.w = Y, d6.w = slot.
fx_put:
    movem.l %d0/%a0, -(%sp)
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab fx_sprites, %a0
    adda.l %d0, %a0
    bsr fx_put_a0
    movem.l (%sp)+, %d0/%a0
    rts

| The same with the picture's address in a0.
fx_put_a0:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.w %d6, %d0
    lsl.w #2, %d0
    lea OFF_FX_ERASE_OFFSETS(%a5), %a2
    move.l %d1, 0(%a2, %d0.w)
    lea OFF_FX_VALID(%a5), %a2
    move.b #1, 0(%a2, %d6.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

draw_effects:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    bsr block_draw_f
    moveq #0, %d7
    move.b OFF_SPARK_K(%a5), %d7
    beq 5f
    moveq #3, %d6               | the corners: 3 up-left, 2 down-left, 1 down-right, 0 up-right
1:  moveq #0, %d1
    move.b OFF_SPARK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_SPARK_Y(%a5), %d2
    cmp.w #2, %d6
    bhs 2f
    add.w %d7, %d1
    bra 3f
2:  sub.w %d7, %d1
3:  cmp.w #1, %d6
    blo 4f
    cmp.w #2, %d6
    bhi 4f
    add.w %d7, %d2
    bra 41f
4:  sub.w %d7, %d2
41: move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #3, %d0
    move.w %d6, %d3
    lsl.w #2, %d3
    add.w %d3, %d0
    addq.w #2, %d0
    bsr fx_put
    subq.w #1, %d6
    bpl 1b

5:  tst.b OFF_FIRE_STATE(%a5)
    beq 55f
    moveq #8, %d6
    moveq #0, %d1
    move.b OFF_FIRE_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_FIRE_Y(%a5), %d2
    move.w OFF_FRAME_COUNTER(%a5), %d0
    lsr.w #2, %d0
    and.w #1, %d0
    add.w #FX_FIRE, %d0         | the flame turns round every four frames
    bsr fx_put
55: tst.b OFF_UW_PERSON(%a5)
    beq 57f
    tst.b OFF_GRUMBLE_ON(%a5)
    bne 57f                     | no bonfires for Grumble
    tst.b OFF_LEVEL(%a5)
    beq 57f
    moveq #9, %d6               | the old man's two bonfires
56: move.w OFF_FRAME_COUNTER(%a5), %d0
    lsr.w #2, %d0
    and.w #1, %d0
    add.w #FX_FIRE, %d0
    move.w #0xa8, %d1
    cmp.w #10, %d6
    beq 58f
    move.w #0x48, %d1
58: move.w #CAVE_PERSON_Y, %d2
    bsr fx_put
    addq.w #1, %d6
    cmp.w #10, %d6
    bls 56b
57: moveq #0, %d7
    move.b OFF_CLOUD_TIMER(%a5), %d7
    beq 9f
    moveq #0, %d5               | the first part of the cloud, then the thinner one
    cmp.w #BOMB_AFTER_FRAMES, %d7
    bhi 6f
    moveq #1, %d5
6:  moveq #4, %d6
    moveq #0, %d1
    move.b OFF_CLOUD_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_CLOUD_Y(%a5), %d2
    move.w %d5, %d0
    bsr fx_put
    lea cloud_puffs(%pc), %a0
    btst #0, (OFF_FRAME_COUNTER + 1)(%a5)
    beq 7f
    lea 6(%a0), %a0
7:  moveq #2, %d4
8:  addq.w #1, %d6
    moveq #0, %d1
    move.b OFF_CLOUD_X(%a5), %d1
    move.b (%a0)+, %d3
    ext.w %d3
    add.w %d3, %d1
    moveq #0, %d2
    move.b OFF_CLOUD_Y(%a5), %d2
    move.b (%a0)+, %d3
    ext.w %d3
    add.w %d3, %d2
    move.w %d5, %d0
    bsr fx_put
    dbra %d4, 8b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| BombCloudOffsetsX/Y: where the three puffs go round the bomb, in two sets
| that take turns every frame.
cloud_puffs:
    .byte -7, -13, 14, 0, 7, 14
    .byte 7, -13, -13, 0, -7, 14
    .align 2

| Link blinks while he is invincible.
draw_link_blink:
    btst #1, OFF_LINK_HURT(%a5)
    bne 9f
    bsr draw_link
9:  rts

| ------------------------------------------------------------ per-frame logic
update_combat:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    bsr lift_update
    bsr ending_update
    tst.b OFF_LINK_HURT(%a5)
    beq 1f
    subq.b #1, OFF_LINK_HURT(%a5)
1:  tst.b OFF_ATTACK(%a5)
    beq 2f
    bsr sword_hits
    cmpi.b #BEAM_PHASE, OFF_ATTACK(%a5)
    bne 11f
    tst.b OFF_ATTACK_ROD(%a5)
    beq 12f
    bsr rod_launch
    bra 11f
12: bsr beam_launch
11: subq.b #1, OFF_ATTACK(%a5)
    bne 2f
    clr.b OFF_ATTACK_ROD(%a5)
2:  bsr enemy_contact
    bsr item_pickup
    bsr items_age
    bsr fairy_fly
    bsr beam_update
    bsr fire_update
    bsr block_update_f
    bsr bomb_tick
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f                      | a cellar is not one of the level's rooms
    bsr uw_check_clear
9:  movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| CheckMonsterStabbingCollision: the blade fully out (PlayerToWeaponOffsets of state 2, as sword_offsets) has its
| middle 6 across and 8 along from its corner, a monster 8 and 8, and they touch when nearer than $C across the
| blade and $10 along it. Per direction (up, down, left, right): the X and Y to add to Link's to meet a monster's,
| then how near it must be in X and in Y.
sword_box:
    .byte -1+6-8, -10+8-8, 12, 16
    .byte 1+6-8, 13+8-8, 12, 16
    .byte -11+8-8, 3+6-8, 16, 12
    .byte 11+8-8, 3+6-8, 16, 12

| Every enemy the blade touches takes a hit, the box of sword_box.
sword_hits:
    movem.l %d0-%d6/%a0, -(%sp)
    cmpi.b #(ATTACK_FRAMES - 1), OFF_ATTACK(%a5)
    bhi 9f                      | the blade only cuts while it is fully out
    cmpi.b #4, OFF_ATTACK(%a5)
    blo 9f
    bsr sword_pos               | d0 = which way it points
    lsl.w #2, %d0
    lea sword_box(%pc, %d0.w), %a0
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    move.b (%a0)+, %d3
    ext.w %d3
    add.w %d3, %d1              | d1, d2 = the X and Y a monster would have with its middle on the blade's
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    move.b (%a0)+, %d3
    ext.w %d3
    add.w %d3, %d2
    moveq #0, %d4
    move.b (%a0)+, %d4          | d4, d6 = how near it has to be in X and in Y
    moveq #0, %d6
    move.b (%a0), %d6
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 10f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 8f
    bsr enemy_untouchable
    bne 8f                      | burrowed, submerged or flying high: the blade passes through
    move.w %d1, %d0
    bsr enemy_dx                | d3 = how far the blade is from the monster's body
    cmp.w %d4, %d3
    bhs 8f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d2, %d3
    bpl 3f
    neg.w %d3
3:  cmp.w %d6, %d3
    bhs 8f
    movem.l %d1-%d2/%d4/%d6, -(%sp)    | a kill uses them (kill_enemy) and the next monster needs them
    move.b OFF_LINK_DIR(%a5), OFF_ENEMY_SHOVE(%a5, %d5.w)
    bsr set_sword_damage
    tst.b OFF_ATTACK_ROD(%a5)
    beq 4f
    move.b #ROD_STAB_HITS, OFF_HIT_DAMAGE(%a5)
4:  bsr enemy_behaviour
    cmp.w #BEH_DODONGO, %d0
    bne 41f
    clr.b OFF_HIT_DAMAGE(%a5)
    bsr dodongo_sword           | only a stunned Dodongo is hurt, and it dies
    bra 7f
41: move.b #HIT_SWORD, OFF_HIT_TYPE(%a5)
    move.b OFF_LINK_DIR(%a5), OFF_HIT_DIR(%a5)
    bsr hit_enemy
7:  movem.l (%sp)+, %d1-%d2/%d4/%d6
8:  addq.w #1, %d5
    bra 1b
10: bsr boss_person_hit_f           | the old man between his fires
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

| Enemy d5 takes a hit and is killed when its hit points run out.
hit_enemy:
    movem.l %d0/%a0, -(%sp)
    bsr enemy_behaviour
    cmp.w #BEH_TRAP, %d0
    beq 5f
    cmp.w #BEH_DODONGO, %d0
    beq 5f                              | nor a Dodongo, except by the sword when a bomb has stunned it
    cmp.w #BEH_MOLDORM, %d0
    beq 61f
    cmp.w #BEH_GLEEOK_HEAD, %d0
    beq 61f
    cmp.w #BEH_LANMOLA, %d0
    beq 61f
    cmp.w #BEH_PATRA, %d0
    beq 61f
    cmp.w #BEH_PATRA_CHILD, %d0
    beq 61f
    cmp.w #BEH_GANON, %d0
    beq 61f
    cmp.w #BEH_FIRE, %d0
    beq 61f
    cmp.w #BEH_MANHANDLA, %d0
    bne 6f
61: clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)   | a Moldorm segment or a Manhandla hand is hurt but not knocked about
6:  movem.l (%sp)+, %d0/%a0
    bra 1f
5:  movem.l (%sp)+, %d0/%a0
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)   | nothing hurts a blade trap
    rts
1:  bsr dmon_hit_filter                 | a darknut's shield, or a weapon the monster shrugs off
    beq 11f
    rts
11: move.b #ENEMY_HURT_FRAMES, OFF_ENEMY_HURT(%a5, %d5.w)
    bsr boss_hit_cry_f                  | a boss cries out when it is struck (bosses.s)
    move.l %d1, -(%sp)
    moveq #1, %d1                       | the hit's weight: set by the weapon, one by default
    tst.b OFF_HIT_DAMAGE(%a5)
    beq 2f
    move.b OFF_HIT_DAMAGE(%a5), %d1
2:  clr.b OFF_HIT_DAMAGE(%a5)
    move.b OFF_ENEMY_HP(%a5, %d5.w), %d0
    cmp.b %d1, %d0
    bls 3f
    sub.b %d1, %d0
    move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
    move.l (%sp)+, %d1
    bra dmon_survived                   | a zol or vire falls apart
3:  move.l (%sp)+, %d1
    bsr enemy_behaviour
    cmp.w #BEH_MOLDORM, %d0
    beq moldorm_died
    cmp.w #BEH_LANMOLA, %d0
    beq moldorm_died                    | a worm of Lanmola loses its tail the same way
    cmp.w #BEH_GANON, %d0
    beq boss_ganon_died_f               | Ganon turns brown, or burns to ashes
    cmp.w #BEH_GLEEOK_HEAD, %d0
    beq boss_ghead_died_f               | a head cut off becomes a flying one
    bra kill_enemy

| The sword's weight in hits: SwordDamagePoints is $10, $20, $40 for the wooden, white and magic sword.
set_sword_damage:
    move.l %d0, -(%sp)
    moveq #1, %d0
    move.b OFF_HAS_SWORD(%a5), %d0      | the grade 1 to 3: 1, 2 or 4 hits' worth
    subq.b #1, %d0
    bpl 1f
    moveq #0, %d0
1:  and.w #3, %d0
    move.b sword_hits_table(%pc, %d0.w), OFF_HIT_DAMAGE(%a5)
    move.l (%sp)+, %d0
    rts

sword_hits_table:
    .byte 1, 2, 4, 4

| A Moldorm segment has run out of hit points. It does not die: it comes back with fresh ones, and the worm's tail
| segment is what is lost instead (UpdateMoldorm swaps them), so the worm shrinks from the tail until only the
| head is left, and that one dies for good. d5 = the segment.
moldorm_died:
    movem.l %d0-%d2, -(%sp)
    move.w %d5, %d1
    and.w #0xfc, %d1                    | the worm's lowest slot
    move.w %d1, %d2
    addq.w #(MOLDORM_SEGMENTS - 1), %d2 | its head
    move.w %d1, %d0
1:  tst.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
    bne 2f
    addq.w #1, %d0
    cmp.w %d2, %d0
    bls 1b
2:  cmp.w %d2, %d0
    beq 3f                              | only the head is left: that is the end of the worm
    move.b #MOLDORM_HP_REVIVED, OFF_ENEMY_HP(%a5, %d5.w)
    clr.b OFF_ENEMY_ACTIVE(%a5, %d0.w)  | the tail goes
    sfx SFX_MONSTER_DIED
    bra 9f
3:  bsr kill_enemy
9:  movem.l (%sp)+, %d0-%d2
    rts

| Remove enemy d5, count the kill and roll for a drop the way HandleMonsterDied
| and SetUpDroppedItem do. Ten kills in a row without being hurt guarantee a
| drop (a bomb if the tenth was a bomb kill, else five rupees), and the
| sixteenth is a fairy.
kill_enemy:
    sfx SFX_MONSTER_DIED
    bsr boss_death_cry_f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    bsr dmon_died                           | a like-like lets go of Link
    bsr mover_died                          | a red leever stops being counted; a zora's death is not the screen's
    tst.w %d0
    beq 0f
    addq.b #1, OFF_ROOM_KILLS(%a5)         | the screen remembers it (RoomKillCount)
0:    addq.b #1, OFF_WORLD_KILLS(%a5)
    cmpi.b #HELP_KILLS, OFF_HELP_COUNT(%a5)
    bhs 1f
    addq.b #1, OFF_HELP_COUNT(%a5)
    cmpi.b #HELP_KILLS, OFF_HELP_COUNT(%a5)
    bne 1f
    tst.b OFF_HIT_BY_BOMB(%a5)
    beq 1f
    addq.b #1, OFF_HELP_VALUE(%a5)
1:  moveq #0, %d0                       | the column moves on before the lookup
    move.b OFF_KILL_CYCLE(%a5), %d0
    addq.w #1, %d0
    cmp.w #KILL_CYCLE_LENGTH, %d0
    blo 2f
    moveq #0, %d0
2:  move.b %d0, OFF_KILL_CYCLE(%a5)

    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    moveq #3, %d1
    cmpi.b #0xff, %d0
    beq 4f
    ltab mon_table, %a0
    lsl.w #3, %d0
    moveq #0, %d1
    move.b 4(%a0, %d0.w), %d1
    cmpi.b #0xff, %d1
    beq 9f                      | this kind never drops anything
    tst.w %d5
    bne 4f
    cmpi.b #0x2a, 0(%a0, %d0.w)
    beq 9f                      | a stalfos in the first slot may carry the room's item
4:  move.w %d1, %d2
    mulu.w #KILL_CYCLE_LENGTH, %d2
    moveq #0, %d0
    move.b OFF_KILL_CYCLE(%a5), %d0
    add.w %d0, %d2
    ltab drop_table, %a0
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d2           | d2 = the item the table offers
    cmpi.b #FAIRY_KILLS, OFF_WORLD_KILLS(%a5)
    bne 5f
    moveq #ITEM_FAIRY, %d2
    bra 7f
5:  cmpi.b #HELP_KILLS, OFF_HELP_COUNT(%a5)
    blo 6f
    moveq #ITEM_FIVE_RUPEES, %d2
    tst.b OFF_HELP_VALUE(%a5)
    beq 7f
    moveq #ITEM_BOMBS, %d2
7:  clr.b OFF_HELP_COUNT(%a5)
    clr.b OFF_HELP_VALUE(%a5)
    bra 8f
6:  bsr rand8
    ltab drop_rates, %a0
    cmp.b 0(%a0, %d1.w), %d0
    bhs 9f
8:  move.b %d2, %d0
    bsr spawn_drop
9:  rts

| Drop item d0.b where enemy d5 died, if there is a picture for it and a free slot.
spawn_drop:
    movem.l %d1-%d2/%a0, -(%sp)
    ltab item_index, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    cmpi.b #0xff, %d1
    beq 9f
    moveq #1, %d1                       | slot 0 belongs to the room's item
1:  tst.b OFF_ITEM_ACTIVE(%a5, %d1.w)
    beq 2f
    addq.w #1, %d1
    cmp.w #ITEM_SLOTS, %d1
    blo 1b
    bra 9f
2:  move.b %d0, OFF_ITEM_ID(%a5, %d1.w)
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    move.b %d2, OFF_ITEM_X(%a5, %d1.w)
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    move.b %d2, OFF_ITEM_Y(%a5, %d1.w)
    move.b #1, OFF_ITEM_ACTIVE(%a5, %d1.w)
    lea OFF_ITEM_LIFE(%a5), %a0
    move.b #0xff, 0(%a0, %d1.w)
    cmp.b #ITEM_FAIRY, %d0
    bne 9f
    lea OFF_FAIRY_STATE(%a5), %a0       | SetUpFairyObject: facing up, speed $7F
    clr.b 0(%a0, %d1.w)
    lea OFF_FAIRY_FRAC(%a5), %a0
    clr.b 0(%a0, %d1.w)
    lea OFF_FAIRY_TURNS(%a5), %a0
    clr.b 0(%a0, %d1.w)
    lea OFF_FAIRY_TIMER(%a5), %a0
    clr.b 0(%a0, %d1.w)
    lea OFF_FAIRY_SPEED(%a5), %a0
    move.b #0x7f, 0(%a0, %d1.w)
    lea OFF_FAIRY_DIR(%a5), %a0
    move.b #8, 0(%a0, %d1.w)
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| ------------------------------------------------------------- Link's health
enemy_contact:
    movem.l %d0-%d5/%a0, -(%sp)
    tst.b OFF_LINK_HURT(%a5)
    bne 9f
    tst.b OFF_INV_CLOCK(%a5)
    bne 9f                      | with the clock nothing can touch him
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    lea OFF_ENEMY_STUN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    bne 8f                      | a stunned monster does no harm
    lea OFF_ENEMY_GHOST(%a5), %a0
    btst #1, 0(%a0, %d5.w)
    bne 8f                      | nor does one under the ground or the water
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    bsr enemy_dx                | d3 = how far Link is from the monster's body
    cmp.w #CONTACT_RANGE, %d3
    bhs 8f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    sub.w %d0, %d3
    bpl 3f
    neg.w %d3
3:  cmp.w #CONTACT_RANGE, %d3
    bhs 8f

    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    ltab mon_table, %a0
    lsl.w #3, %d0
    moveq #0, %d1
    move.b 3(%a0, %d0.w), %d1
4:  bsr dmon_contact                | bubbles harm nobody, a like-like swallows him instead of shoving
    move.w %d0, %d4
    bne 41f
    bsr link_knockback
41: cmp.w #1, %d4
    beq 8f
    bsr hurt_link
    bra 9f
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d5/%a0
    rts

| Enemy d5 has touched Link: a wallmaster takes hold of him, anything else
| shoves him away and turns round.
link_knockback:
    movem.l %d0-%d2, -(%sp)
    bsr wallmaster_grab
    tst.w %d0
    bne 9f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    bsr link_shove_from
    bsr enemy_behaviour
    cmp.w #BEH_GHINI, %d0
    beq 1f
    cmp.w #BEH_TEKTITE, %d0
    bhs 9f                      | jumpers, flyers and burrowers keep their way
1:  move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    move.b %d0, %d2
    and.b #(DIR_RIGHT + DIR_DOWN), %d0
    add.b %d0, %d0
    and.b #(DIR_LEFT + DIR_UP), %d2
    lsr.b #1, %d2
    or.b %d2, %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d2
    rts

| Link is shoved away from the point (d0.w, d2.w).
link_shove_from:
    movem.l %d0-%d4, -(%sp)
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    sub.w %d0, %d1
    move.w %d1, %d0                 | d0 = how far right of it Link is
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w %d2, %d1
    move.w %d1, %d2                 | d2 = how far below
    move.w %d0, %d1
    bpl 1f
    neg.w %d1
1:  move.w %d2, %d3
    bpl 2f
    neg.w %d3
2:  | A step in progress has to be finished along its own axis.
    tst.b OFF_COMMIT(%a5)
    beq 3f
    move.b OFF_LINK_DIR(%a5), %d4
    and.b #DIR_VERTICAL, %d4
    bne 5f
    bra 4f
3:  cmp.w %d3, %d1
    bgt 4f
5:  moveq #DIR_DOWN, %d1
    tst.w %d2
    bpl 6f
    moveq #DIR_UP, %d1
    bra 6f
4:  moveq #DIR_RIGHT, %d1
    tst.w %d0
    bpl 6f
    moveq #DIR_LEFT, %d1
6:  move.b %d1, OFF_LINK_SHOVE_DIR(%a5)
    move.b #LINK_SHOVE_PIXELS, OFF_LINK_SHOVE(%a5)
    movem.l (%sp)+, %d0-%d4
    rts

| d1.w = half hearts of damage. Every level of ring halves the blow (Link_BeHarmed), so the life is
| kept in 128ths of a half heart: HP_HALVES is the count rounded up, HP_FRAC what is missing from it.
hurt_link:
    move.l %d0, -(%sp)
    sfx SMP_HURT                        | Link_BeHarmed's DPCM cry
    sfx SFX_HARMED
    move.b #LINK_HURT_FRAMES, OFF_LINK_HURT(%a5)
    clr.b OFF_WORLD_KILLS(%a5)          | being hurt starts the kill streak over
    clr.b OFF_HELP_COUNT(%a5)
    clr.b OFF_HELP_VALUE(%a5)
    moveq #0, %d0
    move.w %d1, %d0
    lsl.w #7, %d0
    moveq #0, %d1
    move.b OFF_INV_RING(%a5), %d1
    lsr.w %d1, %d0                      | the ring: half the damage, or a quarter
    moveq #0, %d1
    move.b OFF_HP_FRAC(%a5), %d1
    add.w %d1, %d0
    move.w %d0, %d1
    and.b #127, %d1
    move.b %d1, OFF_HP_FRAC(%a5)
    lsr.w #7, %d0                       | whole half hearts lost
    moveq #0, %d1
    move.b OFF_HP_HALVES(%a5), %d1
    sub.w %d0, %d1
    bgt 1f
    moveq #0, %d1
1:  move.b %d1, OFF_HP_HALVES(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    tst.b %d1
    bne 9f
    clr.b OFF_HP_FRAC(%a5)
    bsr link_dies
9:  move.l (%sp)+, %d0
    rts

| d1.w = half hearts to give back, up to his containers' worth.
heal_link:
    movem.l %d0/%d2, -(%sp)
    moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    add.w %d0, %d0
    moveq #0, %d2
    move.b OFF_HP_HALVES(%a5), %d2
    and.w #0xff, %d1
    add.w %d1, %d2
    cmp.w %d0, %d2
    bls 1f
    move.w %d0, %d2
    clr.b OFF_HP_FRAC(%a5)
1:  move.b %d2, OFF_HP_HALVES(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    movem.l (%sp)+, %d0/%d2
    rts

| Link's tunic takes on the ring's colour. (Filled in with the Link art.)
link_ring_colour:
    rts

| Out of hearts: he is dead. The frame is finished, then death.s takes the screen (the main loop calls death_begin).
link_dies:
    move.b #1, OFF_DYING(%a5)
    rts

| ---------------------------------------------------------------------- bombs
| Space drops a bomb in front of Link. When the fuse runs out it hurts monsters
| nearby and blows open a bombable wall next to it.
    .equ BOMB_FUSE, 48              | state 2: the bomb itself
    .equ BOMB_CLOUD_FRAMES, 36      | states 3 and 4: the cloud
    .equ BOMB_AFTER_FRAMES, 12      | state 4: the cloud is thinning out
    .equ BOMB_DAMAGE, 4             | $40 damage points, in sword hits
    .equ SPARK_FIRST, 2
    .equ SPARK_LAST, 23
    .equ FX_FIRE, 18                | the flame's two pictures in fx_sprites
    .equ FIRE_MOVE_FRAMES, 32       | 16 pixels at half a pixel a frame
    .equ FIRE_STAND_FRAMES, 63
    .equ FIRE_RANGE, 14
    .equ BOMB_RANGE, 24
    .equ BOMB_LANE_X, 0x78
    .equ BOMB_LANE_Y, 0x8d
    .equ BOMB_DOOR_SLACK, 0x20
    .equ BOMB_DOOR_TYPE, 4

| Control or Alternate use the B item (items.s says what each one does).
b_item_input:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_CTRL(%a0)
    bne 1f
    tst.b SCAN_ALT(%a0)
    beq 8f
1:  tst.b OFF_B_HELD(%a5)
    bne 9f
    move.b #1, OFF_B_HELD(%a5)
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    bsr b_item_fix
    moveq #0, %d0
    move.b OFF_B_ITEM(%a5), %d0
    bsr b_item_use
    bra 9f
8:  clr.b OFF_B_HELD(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

place_bomb:
    movem.l %d0-%d2, -(%sp)
    tst.b OFF_INV_BOMBS(%a5)
    beq 9f
    tst.b OFF_BOMB_TIMER(%a5)
    bne 9f
    subq.b #1, OFF_INV_BOMBS(%a5)
    sfx SFX_BOMB
    move.b #1, OFF_HUD_DIRTY(%a5)
    bsr sword_pos
    tst.w %d1
    bpl 3f
    moveq #0, %d1
3:  cmp.w #0x00f0, %d1
    ble 4f
    move.w #0x00f0, %d1
4:  cmp.w #0x003e, %d2
    bge 5f
    move.w #0x003e, %d2
5:  cmp.w #0x00dd, %d2
    ble 6f
    move.w #0x00dd, %d2
6:  move.b %d1, OFF_BOMB_X(%a5)
    move.b %d2, OFF_BOMB_Y(%a5)
    move.b #BOMB_FUSE, OFF_BOMB_TIMER(%a5)
9:  movem.l (%sp)+, %d0-%d2
    rts

erase_bomb:
    tst.b OFF_BOMB_VALID(%a5)
    beq 9f
    move.l %d0, -(%sp)
    move.l OFF_BOMB_ERASE_OFFSET(%a5), %d0
    bsr erase_at
    clr.b OFF_BOMB_VALID(%a5)
    move.l (%sp)+, %d0
9:  rts

draw_bomb:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    tst.b OFF_BOMB_TIMER(%a5)
    beq 9f
    ltab item_index, %a0
    moveq #0, %d1
    move.b ITEM_BOMBS(%a0), %d1
    cmpi.b #0xff, %d1
    beq 9f
    mulu.w #SPRITE_FRAME_BYTES, %d1
    ltab item_sprites, %a0
    adda.l %d1, %a0
    moveq #0, %d1
    moveq #0, %d2
    move.b OFF_BOMB_X(%a5), %d1
    move.b OFF_BOMB_Y(%a5), %d2
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.l %d1, OFF_BOMB_ERASE_OFFSET(%a5)
    move.b #1, OFF_BOMB_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| The fuse runs out into a cloud that lasts BOMB_CLOUD_FRAMES: for the first
| BOMB_BLAST_FRAMES it hurts every monster near it (and the screen flashes),
| and when the second part starts it blows open a bombable wall.
bomb_tick:
    bsr dodongo_bomb_tick       | a Dodongo eats a bomb at its mouth, or is stunned by the cloud
    tst.b OFF_BOMB_TIMER(%a5)
    beq 1f
    subq.b #1, OFF_BOMB_TIMER(%a5)
    bne 9f
    move.b OFF_BOMB_X(%a5), OFF_CLOUD_X(%a5)
    move.b OFF_BOMB_Y(%a5), OFF_CLOUD_Y(%a5)
    move.b #BOMB_CLOUD_FRAMES, OFF_CLOUD_TIMER(%a5)
    sfx SFX_BOMB_BLAST
1:  tst.b OFF_CLOUD_TIMER(%a5)
    beq 8f
    cmpi.b #BOMB_AFTER_FRAMES, OFF_CLOUD_TIMER(%a5)
    bhi 2f
    bne 3f
    bsr bomb_open_wall
    bsr ow_bomb_secret_far                  | on the overworld, a rock wall
    bra 3f
2:  bsr bomb_hurt_enemies
3:  subq.b #1, OFF_CLOUD_TIMER(%a5)
8:  bsr bomb_flash
9:  rts

| Every monster within BOMB_RANGE of the cloud that is not already hurt takes
| four hits' worth of damage.
bomb_hurt_enemies:
    movem.l %d0-%d5, -(%sp)
    move.b #1, OFF_HIT_BY_BOMB(%a5)
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 5f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 4f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 4f
    bsr enemy_untouchable
    bne 4f
    moveq #0, %d1
    move.b OFF_CLOUD_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_CLOUD_Y(%a5), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    sub.w %d1, %d3
    bpl 2f
    neg.w %d3
2:  cmp.w #BOMB_RANGE, %d3
    bhs 4f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d2, %d3
    bpl 3f
    neg.w %d3
3:  cmp.w #BOMB_RANGE, %d3
    bhs 4f
    move.b #HIT_BOMB, OFF_HIT_TYPE(%a5)
    clr.b OFF_HIT_DIR(%a5)
    bsr dmon_hit_filter                 | some monsters shrug a bomb off
    bne 4f
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    moveq #0, %d0
    move.b OFF_ENEMY_HP(%a5, %d5.w), %d0
    cmp.w #BOMB_DAMAGE, %d0
    bhi 31f
    moveq #1, %d0               | it has less than that left: the hit below finishes it
    bra 32f
31: sub.w #(BOMB_DAMAGE - 1), %d0
32: move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
    move.b #HIT_BOMB, OFF_HIT_TYPE(%a5)
    clr.b OFF_HIT_DIR(%a5)
    bsr hit_enemy
4:  addq.w #1, %d5
    bra 1b
5:  clr.b OFF_HIT_BY_BOMB(%a5)
    movem.l (%sp)+, %d0-%d5
    rts

| The screen goes grey for four frames, twice, as the cloud opens.
bomb_flash:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_CLOUD_TIMER(%a5), %d0
    sub.w #BOMB_AFTER_FRAMES, %d0
    moveq #0, %d1               | 1 when this frame is grey
    cmp.w #19, %d0
    blt 1f
    cmp.w #22, %d0
    bgt 1f
    moveq #1, %d1
    bra 2f
1:  cmp.w #14, %d0
    blt 2f
    cmp.w #17, %d0
    bgt 2f
    moveq #1, %d1
2:  cmp.b OFF_FLASH_ON(%a5), %d1
    beq 9f
    move.b %d1, OFF_FLASH_ON(%a5)
    bsr cur_palette
    movea.l #PALETTE_BASE, %a1
    moveq #15, %d2
3:  moveq #0, %d0
    move.w (%a0)+, %d0
    tst.b %d1
    beq 4f
    move.w %d0, -(%sp)          | grey = the mean of the three channels
    lsr.w #8, %d0
    and.w #7, %d0
    move.w (%sp), %d1
    lsr.w #4, %d1
    and.w #7, %d1
    add.w %d1, %d0
    move.w (%sp)+, %d1
    and.w #7, %d1
    add.w %d1, %d0
    divu.w #3, %d0
    and.w #7, %d0
    move.w %d0, %d1
    lsl.w #4, %d1
    or.w %d1, %d0
    lsl.w #4, %d1
    or.w %d1, %d0
    moveq #1, %d1
4:  move.w %d0, (%a1)+
    dbra %d2, 3b
9:  movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| Entering another room: the bomb, its cloud and the shot's spark stay behind
| (the grey flash is undone).
clear_bomb:
    movem.l %d0/%a0-%a1, -(%sp)
    clr.b OFF_BOMB_TIMER(%a5)
    clr.b OFF_FIRE_STATE(%a5)
    clr.b OFF_CANDLE_USED(%a5)
    clr.b OFF_BLOCK_STATE(%a5)
    clr.b OFF_CLOUD_TIMER(%a5)
    clr.b OFF_SPARK_K(%a5)
    tst.b OFF_FLASH_ON(%a5)
    beq 9f
    clr.b OFF_FLASH_ON(%a5)
    bsr cur_palette
    movea.l #PALETTE_BASE, %a1
    moveq #15, %d0
1:  move.w (%a0)+, (%a1)+
    dbra %d0, 1b
9:  movem.l (%sp)+, %d0/%a0-%a1
    rts

| ---------------------------------------------------------------------- candle
| The blue candle lights a flame 16 pixels in front of Link once in each room.
| It creeps ahead 16 pixels at half a pixel a frame, then stands for 63 frames,
| burning every monster it touches.
use_candle:
    movem.l %d0-%d2, -(%sp)
    cmpi.b #2, OFF_INV_CANDLE(%a5)
    beq 0f                              | the red candle can be lit as often as he likes
    tst.b OFF_CANDLE_USED(%a5)
    bne 9f
0:    tst.b OFF_FIRE_STATE(%a5)
    bne 9f
    move.b #1, OFF_CANDLE_USED(%a5)
    bsr uw_light_room_far
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
5:  move.b %d1, OFF_FIRE_X(%a5)
    move.b %d2, OFF_FIRE_Y(%a5)
    move.b %d0, OFF_FIRE_DIR(%a5)
    move.b #FIRE_MOVE_FRAMES, OFF_FIRE_TIMER(%a5)
    move.b #1, OFF_FIRE_STATE(%a5)
    sfx SFX_FLAME
9:  movem.l (%sp)+, %d0-%d2
    rts

fire_update:
    movem.l %d0-%d6, -(%sp)
    move.b OFF_FIRE_STATE(%a5), %d0
    beq 9f
    subq.b #1, OFF_FIRE_TIMER(%a5)
    cmp.b #1, %d0
    bne 7f
    btst #0, (OFF_FRAME_COUNTER + 1)(%a5)
    bne 6f                      | a pixel every other frame
    moveq #0, %d2
    move.b OFF_FIRE_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_FIRE_Y(%a5), %d3
    move.b OFF_FIRE_DIR(%a5), %d6
    btst #0, %d6
    beq 11f
    addq.w #1, %d2
    bra 15f
11: btst #1, %d6
    beq 12f
    subq.w #1, %d2
    bra 15f
12: btst #2, %d6
    beq 13f
    addq.w #1, %d3
    bra 15f
13: subq.w #1, %d3
15: move.w %d2, -(%sp)
    move.w %d3, -(%sp)
    btst #0, %d6
    beq 16f
    addq.w #8, %d2
16: btst #2, %d6
    beq 17f
    addq.w #8, %d3
17: bsr enemy_blocked_at
    move.w (%sp)+, %d3
    move.w (%sp)+, %d2
    tst.w %d0
    bne 18f                     | a wall: it stays where it is
    move.b %d2, OFF_FIRE_X(%a5)
    move.b %d3, OFF_FIRE_Y(%a5)
6:  tst.b OFF_FIRE_TIMER(%a5)
    bne 8f
18: move.b #2, OFF_FIRE_STATE(%a5)
    move.b #FIRE_STAND_FRAMES, OFF_FIRE_TIMER(%a5)
    bra 8f
7:  cmpi.b #1, OFF_FIRE_TIMER(%a5)
    bne 71f
    bsr ow_fire_secret_far                  | a flame on its last frames burns a tree
71: tst.b OFF_FIRE_TIMER(%a5)
    bne 8f
    clr.b OFF_FIRE_STATE(%a5)
    bra 9f

8:  moveq #0, %d5                   | burn what it touches
21: cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 29f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 29f
    bsr enemy_untouchable
    bne 29f
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    moveq #0, %d1
    move.b OFF_FIRE_X(%a5), %d1
    sub.w %d1, %d0
    bpl 22f
    neg.w %d0
22: cmp.w #FIRE_RANGE, %d0
    bhs 29f
    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    moveq #0, %d1
    move.b OFF_FIRE_Y(%a5), %d1
    sub.w %d1, %d0
    bpl 23f
    neg.w %d0
23: cmp.w #FIRE_RANGE, %d0
    bhs 29f
    move.b OFF_FIRE_DIR(%a5), OFF_ENEMY_SHOVE(%a5, %d5.w)
    move.b #HIT_FIRE, OFF_HIT_TYPE(%a5)
    move.b OFF_FIRE_DIR(%a5), OFF_HIT_DIR(%a5)
    bsr hit_enemy
29: addq.w #1, %d5
    bra 21b
9:  movem.l (%sp)+, %d0-%d6
    rts

bomb_open_wall:
    movem.l %d0-%d6/%a0-%a2, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    moveq #0, %d1
    move.b OFF_CLOUD_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_CLOUD_Y(%a5), %d2
    | Which wall is the bomb next to?
    move.w %d2, %d3
    sub.w #BOMB_LANE_Y, %d3
    bpl 6f
    neg.w %d3
6:  cmp.w #BOMB_DOOR_SLACK, %d3
    bhs 7f
    cmp.w #0x00b8, %d1
    blo 61f
    moveq #0, %d6               | east
    bra 8f
61: cmp.w #0x0038, %d1
    bhi 7f
    moveq #1, %d6               | west
    bra 8f
7:  move.w %d1, %d3
    sub.w #BOMB_LANE_X, %d3
    bpl 71f
    neg.w %d3
71: cmp.w #BOMB_DOOR_SLACK, %d3
    bhs 9f
    cmp.w #0x00a5, %d2
    blo 72f
    moveq #2, %d6               | south
    bra 8f
72: cmp.w #0x0075, %d2
    bhi 9f
    moveq #3, %d6               | north

8:  moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lvtab ROOM_INDEX, %a0
    moveq #0, %d3
    move.b 0(%a0, %d0.w), %d3
    cmpi.b #0xff, %d3
    beq 9f
    mulu.w #UW_DOOR_RECORD_BYTES, %d3
    lvtab DOORS, %a1
    adda.l %d3, %a1
    cmpi.b #BOMB_DOOR_TYPE, 0(%a1, %d6.w)
    bne 9f
    uwlea OPEN, %a2
    btst %d6, 0(%a2, %d0.w)
    bne 9f
    move.w %d6, %d2
    bsr uw_open_door_pair
    sfx SFX_SECRET              | the wall blows open
    bsr uw_redraw_room
9:  movem.l (%sp)+, %d0-%d6/%a0-%a2
    rts

| ---------------------------------------------------------------------- items
| A dropped item lasts $FF counts, one every second frame.
items_age:
    movem.l %d0-%d1/%a0, -(%sp)
    btst #0, OFF_FRAME_COUNTER+1(%a5)
    beq 9f
    lea OFF_ITEM_LIFE(%a5), %a0
    moveq #1, %d1
1:  cmpi.b #1, OFF_ITEM_ACTIVE(%a5, %d1.w)
    bne 2f
    subq.b #1, 0(%a0, %d1.w)
    bne 2f
    clr.b OFF_ITEM_ACTIVE(%a5, %d1.w)
2:  addq.w #1, %d1
    cmp.w #ITEM_SLOTS, %d1
    blo 1b
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| The fairy a monster dropped does not stand still: it flies like the ROM's (UpdateFairyObject: ControlFairyFlight and
| MoveFlyer). It speeds up from $7F to $A0, then wanders: six turns, one every $10 frames (left, right or straight on by
| 45 degrees, by the odds $50 / $50 / $60 in 256), and again. A step of the speed's top three bits is added to a fraction
| each frame and a carry moves it one pixel along its heading (right 1, left 2, down 4, up 8). The room's bounds turn it round.
fairy_fly:
    movem.l %d1, -(%sp)
    moveq #1, %d1
1:  cmpi.b #1, OFF_ITEM_ACTIVE(%a5, %d1.w)
    bne 2f
    cmpi.b #ITEM_FAIRY, OFF_ITEM_ID(%a5, %d1.w)
    bne 2f
    bsr fairy_step
2:  addq.w #1, %d1
    cmp.w #ITEM_SLOTS, %d1
    blo 1b
    movem.l (%sp)+, %d1
    rts

| d1.w = the item slot.
fairy_step:
    movem.l %d0/%d2-%d3/%a0-%a1, -(%sp)
    lea OFF_FAIRY_TIMER(%a5), %a0
    tst.b 0(%a0, %d1.w)
    beq 1f
    subq.b #1, 0(%a0, %d1.w)
1:  lea OFF_FAIRY_STATE(%a5), %a1
    move.b 0(%a1, %d1.w), %d0
    bne 2f
    lea OFF_FAIRY_SPEED(%a5), %a0       | state 0: faster each frame, up to $A0
    addq.b #1, 0(%a0, %d1.w)
    move.b 0(%a0, %d1.w), %d2
    andi.b #0xe0, %d2
    cmpi.b #0xa0, %d2
    blo 8f
    move.b #1, 0(%a1, %d1.w)
    bra 8f
2:  cmp.b #1, %d0
    bne 3f
    move.b #3, 0(%a1, %d1.w)            | state 1: six turns of wandering
    lea OFF_FAIRY_TURNS(%a5), %a0
    move.b #6, 0(%a0, %d1.w)
    bra 8f
3:  tst.b 0(%a0, %d1.w)                 | state 3: a turn when the timer has run out
    bne 8f
    lea OFF_FAIRY_TURNS(%a5), %a0
    subq.b #1, 0(%a0, %d1.w)
    bne 4f
    move.b #1, 0(%a1, %d1.w)
    bra 8f
4:  lea OFF_FAIRY_TIMER(%a5), %a0
    move.b #0x10, 0(%a0, %d1.w)
    bsr rand8
    moveq #0, %d2
    lea OFF_FAIRY_DIR(%a5), %a0
    move.b 0(%a0, %d1.w), %d3
5:  cmp.b fairy_dirs(%pc, %d2.w), %d3
    beq 6f
    addq.w #1, %d2
    cmp.w #8, %d2
    blo 5b
    moveq #0, %d2
6:  cmp.b #0xa0, %d0
    bhs 7f
    addq.w #1, %d2
    cmp.b #0x50, %d0
    bhs 7f
    subq.w #2, %d2
7:  and.w #7, %d2
    move.b fairy_dirs(%pc, %d2.w), 0(%a0, %d1.w)
8:  bsr fairy_move
    movem.l (%sp)+, %d0/%d2-%d3/%a0-%a1
    rts

fairy_dirs:
    .byte 0x08, 0x09, 0x01, 0x05, 0x04, 0x06, 0x02, 0x0a      | Directions8
    .align 2

fairy_move:
    movem.l %d0/%d2-%d3/%a0-%a1, -(%sp)
    lea OFF_FAIRY_SPEED(%a5), %a0
    move.b 0(%a0, %d1.w), %d2
    andi.b #0xe0, %d2
    lea OFF_FAIRY_FRAC(%a5), %a0
    add.b %d2, 0(%a0, %d1.w)
    bcc 9f
    lea OFF_FAIRY_DIR(%a5), %a0
    move.b 0(%a0, %d1.w), %d2
    btst #0, %d2
    beq 1f
    addq.b #1, OFF_ITEM_X(%a5, %d1.w)
1:  btst #1, %d2
    beq 2f
    subq.b #1, OFF_ITEM_X(%a5, %d1.w)
2:  btst #2, %d2
    beq 3f
    addq.b #1, OFF_ITEM_Y(%a5, %d1.w)
3:  btst #3, %d2
    beq 4f
    subq.b #1, OFF_ITEM_Y(%a5, %d1.w)
4:  move.b OFF_ITEM_X(%a5, %d1.w), %d0      | BoundFlyer: out of the room's bounds turns it round
    cmp.b OFF_OBJ_LEFT(%a5), %d0
    bls 5f
    cmp.b OFF_OBJ_RIGHT(%a5), %d0
    bhs 5f
    move.b OFF_ITEM_Y(%a5, %d1.w), %d0
    cmp.b OFF_OBJ_UP(%a5), %d0
    bls 5f
    cmp.b OFF_OBJ_DOWN(%a5), %d0
    blo 9f
5:  moveq #0, %d0
6:  cmp.b fairy_dirs_m(%pc, %d0.w), %d2
    beq 7f
    addq.w #1, %d0
    cmp.w #8, %d0
    blo 6b
    moveq #0, %d0
7:  addq.w #4, %d0
    and.w #7, %d0
    move.b fairy_dirs_m(%pc, %d0.w), 0(%a0, %d1.w)
9:  movem.l (%sp)+, %d0/%d2-%d3/%a0-%a1
    rts
fairy_dirs_m:
    .byte 0x08, 0x09, 0x01, 0x05, 0x04, 0x06, 0x02, 0x0a


clear_items:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_FOOD_TIMER(%a5)
    lea OFF_ITEM_ACTIVE(%a5), %a0
    moveq #(ITEM_SLOTS - 1), %d0
1:  clr.b (%a0)+
    dbra %d0, 1b
    lea OFF_ITEM_ERASE_VALID(%a5), %a0
    moveq #(ITEM_SLOTS - 1), %d0
2:  clr.b (%a0)+
    dbra %d0, 2b
    movem.l (%sp)+, %d0/%a0
    rts

erase_items:
    movem.l %d0/%d3/%a0, -(%sp)
    lea OFF_ITEM_ERASE_OFFSETS(%a5), %a0
    moveq #0, %d3
1:  tst.b OFF_ITEM_ERASE_VALID(%a5, %d3.w)
    beq 2f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at
    clr.b OFF_ITEM_ERASE_VALID(%a5, %d3.w)
2:  addq.w #1, %d3
    cmp.w #ITEM_SLOTS, %d3
    blo 1b
    movem.l (%sp)+, %d0/%d3/%a0
    rts

draw_items:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    moveq #0, %d3
1:  move.b OFF_ITEM_ACTIVE(%a5, %d3.w), %d0
    beq 8f
    cmp.b #ROOM_ITEM_HIDDEN, %d0
    beq 8f
    cmp.b #1, %d0
    bne 10f
    lea OFF_ITEM_LIFE(%a5), %a0
    move.b 0(%a0, %d3.w), %d1
    cmp.b #0xf0, %d1
    blo 10f
    btst #0, %d1
    beq 8f                      | a new drop flickers
10: moveq #0, %d0
    move.b OFF_ITEM_ID(%a5, %d3.w), %d0
    ltab item_index, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    cmpi.b #0xff, %d1
    beq 8f
    mulu.w #SPRITE_FRAME_BYTES, %d1
    ltab item_sprites, %a0
    adda.l %d1, %a0
    moveq #0, %d1
    moveq #0, %d2
    move.b OFF_ITEM_X(%a5, %d3.w), %d1
    move.b OFF_ITEM_Y(%a5, %d3.w), %d2
    bsr sprite_offset
    tst.w %d4
    bmi 8f
    move.w %d3, %d0
    lsl.w #2, %d0
    lea OFF_ITEM_ERASE_OFFSETS(%a5), %a2
    move.l %d1, 0(%a2, %d0.w)
    move.b #1, OFF_ITEM_ERASE_VALID(%a5, %d3.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
8:  addq.w #1, %d3
    cmp.w #ITEM_SLOTS, %d3
    blo 1b
    movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| Put the room's own item on the floor. d0.w = room id, a1 = its uw_room_info
| record. Items that were already collected stay gone, and a trigger-7 item
| waits for the monsters to die.
uw_setup_item:
    movem.l %d1-%d2/%a0, -(%sp)
    cmpi.b #0xff, 2(%a1)
    beq 9f
    uwlea FLAGS, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    btst #1, %d1
    bne 9f
    moveq #2, %d2
    cmpi.b #TRIGGER_KILL_ITEM, OFF_ROOM_TRIGGER(%a5)
    bne 1f
    btst #0, %d1
    bne 1f
    moveq #ROOM_ITEM_HIDDEN, %d2
1:  move.b %d2, OFF_ITEM_ACTIVE(%a5)
    move.b 2(%a1), OFF_ITEM_ID(%a5)
    move.b 3(%a1), OFF_ITEM_X(%a5)
    move.b 4(%a1), OFF_ITEM_Y(%a5)
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| MoveAndDrawRoomItem: while the room's item lies on the floor and the first monster is a like-like, a stalfos or a
| gibdo, the item rides along with it (AnimateRoomItemOnMonster puts it where object 1 is). A hidden item does not
| move, and once the monster is dead the item stays where it fell. Called every frame after the monsters have moved.
room_item_follow:
    cmpi.b #2, OFF_ITEM_ACTIVE(%a5)     | the room's item, visible and not taken
    bne 9f
    tst.b OFF_ENEMY_ACTIVE(%a5)         | the first monster is alive
    beq 9f
    tst.b OFF_LEVEL(%a5)
    beq 9f                              | the overworld has no such carriers
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    move.b OFF_ENEMY_TYPE(%a5), %d0
    cmp.b #MON_LIKELIKE, %d0
    beq 1f
    cmp.b #MON_STALFOS, %d0
    beq 1f
    cmp.b #MON_GIBDO, %d0
    bne 9f
1:  move.b OFF_ENEMY_X(%a5), OFF_ITEM_X(%a5)
    move.b OFF_ENEMY_Y(%a5), OFF_ITEM_Y(%a5)
9:  rts

item_pickup:
    movem.l %d0-%d4/%a0, -(%sp)
    moveq #0, %d3
1:  move.b OFF_ITEM_ACTIVE(%a5, %d3.w), %d0
    beq 8f
    cmp.b #ROOM_ITEM_HIDDEN, %d0
    beq 8f
    cmp.b #ITEM_LIFTED, %d0
    beq 8f
    cmp.b #ITEM_FOOD_STATE, %d0
    beq 8f
    cmp.b #1, %d0
    bne 10f
    lea OFF_ITEM_LIFE(%a5), %a0
    cmpi.b #0xf0, 0(%a0, %d3.w)
    bhs 8f                      | too soon after the drop to be picked up
10: moveq #0, %d1
    move.b OFF_ITEM_X(%a5, %d3.w), %d1
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d0, %d1
    bpl 2f
    neg.w %d1
2:  cmp.w #PICKUP_RANGE, %d1
    bhs 8f
    moveq #0, %d1
    move.b OFF_ITEM_Y(%a5, %d3.w), %d1
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    addq.w #3, %d0
    sub.w %d0, %d1
    bpl 3f
    neg.w %d1
3:  cmp.w #PICKUP_RANGE, %d1
    bhs 8f

    moveq #0, %d0
    move.b OFF_ITEM_ID(%a5, %d3.w), %d0
    bsr take_item
    cmpi.b #2, OFF_ITEM_ACTIVE(%a5, %d3.w)
    bne 4f
    moveq #0, %d1                       | the room's item stays collected
    move.b OFF_ROOM_ID(%a5), %d1
    tst.b OFF_IN_CELLAR(%a5)
    beq 5f
    move.b OFF_CELLAR_ROOM(%a5), %d1
5:  uwlea FLAGS, %a0
    moveq #1, %d0
    tst.b OFF_LEVEL(%a5)
    bne 6f
    lea OFF_OW_KILLS(%a5), %a0          | an overworld screen's item (the heart of P6, the bracelet)
    moveq #6, %d0
6:  bset %d0, 0(%a0, %d1.w)
4:  cmpi.b #LIFT_FRAMES, OFF_LIFT_TIMER(%a5)
    bne 41f                             | this very pickup started a lift: the item goes over his head
    move.b OFF_LINK_X(%a5), OFF_ITEM_X(%a5, %d3.w)
    move.b OFF_LINK_Y(%a5), %d0
    sub.b #16, %d0
    move.b %d0, OFF_ITEM_Y(%a5, %d3.w)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5, %d3.w)
    bra 8f
41: clr.b OFF_ITEM_ACTIVE(%a5, %d3.w)
8:  addq.w #1, %d3
    cmp.w #ITEM_SLOTS, %d3
    blo 1b
    movem.l (%sp)+, %d0-%d4/%a0
    rts

| TakeItem outside the overworld's walking mode: Link holds the new item up for $80 frames, halted,
| while the monsters stand still. item_pickup puts the item over his head.
lift_begin:
    move.b #LIFT_FRAMES, OFF_LIFT_TIMER(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    rts

lift_update:
    tst.b OFF_LIFT_TIMER(%a5)
    beq 9f
    subq.b #1, OFF_LIFT_TIMER(%a5)
    bne 9f
    clr.b OFF_LINK_HELD(%a5)
    movem.l %d0/%a0, -(%sp)
    lea OFF_ITEM_ACTIVE(%a5), %a0
    moveq #(ITEM_SLOTS - 1), %d0
1:  cmpi.b #ITEM_LIFTED, (%a0)
    bne 2f
    clr.b (%a0)
2:  addq.l #1, %a0
    dbra %d0, 1b
    movem.l (%sp)+, %d0/%a0
9:  rts

| Apply the effect of item d0.b to Link's counters. Items without an effect
| here yet (weapons, ...) are simply collected.
take_item:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    move.b #1, OFF_HUD_DIRTY(%a5)
0:  cmp.b #ITEM_KEY, %d0
    bne 1f
    sfx SFX_KEY
    cmpi.b #9, OFF_INV_KEYS(%a5)
    bhs 9f
    addq.b #1, OFF_INV_KEYS(%a5)
    bra 9f
1:  cmp.b #ITEM_RUPEE, %d0
    bne 2f
    moveq #1, %d1
    bra 5f
2:  cmp.b #ITEM_FIVE_RUPEES, %d0
    bne 3f
    moveq #5, %d1
5:  sfx SFX_RUPEE
    moveq #0, %d2
    move.b OFF_INV_RUPEES(%a5), %d2
    add.w %d1, %d2
    cmp.w #255, %d2
    bls 6f
    move.w #255, %d2
6:  move.b %d2, OFF_INV_RUPEES(%a5)
    bra 9f
3:  cmp.b #ITEM_BOMBS, %d0
    bne 4f
    sfx SFX_ITEM_TAKEN
    moveq #0, %d2
    move.b OFF_INV_BOMBS(%a5), %d2
    addq.w #4, %d2
    moveq #0, %d1
    move.b OFF_MAX_BOMBS(%a5), %d1
    cmp.w %d1, %d2
    bls 7f
    move.w %d1, %d2
7:  move.b %d2, OFF_INV_BOMBS(%a5)
    bra 9f
4:  cmp.b #ITEM_HEART, %d0
    bne 8f
    sfx SFX_HEART
    moveq #0, %d1
    move.b OFF_HEART_CONTAINERS(%a5), %d1
    add.w %d1, %d1
    moveq #0, %d2
    move.b OFF_HP_HALVES(%a5), %d2
    addq.w #2, %d2
    cmp.w %d1, %d2
    bls 41f
    move.w %d1, %d2
41: move.b %d2, OFF_HP_HALVES(%a5)
    bra 9f
8:  cmp.b #ITEM_HEART_CONTAINER, %d0
    bne 10f
    cmpi.b #HUD_HEART_SLOTS, OFF_HEART_CONTAINERS(%a5)
    bhs 9f
    jingle MUS_ITEM
    addq.b #1, OFF_HEART_CONTAINERS(%a5)
    moveq #0, %d1
    move.b OFF_HEART_CONTAINERS(%a5), %d1
    add.w %d1, %d1
    move.b %d1, OFF_HP_HALVES(%a5)
    bra 9f
10: cmp.b #ITEM_TRIFORCE, %d0
    bne 22f
    move.b #1, OFF_TRIFORCE(%a5)
    moveq #0, %d1                       | the level's piece is recorded
    move.b OFF_LEVEL(%a5), %d1
    subq.w #1, %d1
    moveq #1, %d2
    lsl.b %d1, %d2
    or.b %d2, OFF_TRIFORCE_PIECES(%a5)
    jingle MUS_TRIFORCE
    move.b #1, OFF_ENDING_PHASE(%a5)    | the end-of-level sequence (mode $12 of the original)
    move.b #ENDING_HOLD_FRAMES, OFF_ENDING_TIMER(%a5)
    clr.b OFF_ENDING_STEP(%a5)
    move.b #1, OFF_LINK_HELD(%a5)       | he stands holding it up
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    bsr clear_enemies                   | HideObjectSprites: only Link and the piece stay
    bsr show_background                 | and nothing of theirs is left on the screens
    clr.b OFF_BEAM_ACTIVE(%a5)
    clr.b OFF_FIRE_STATE(%a5)
    clr.b OFF_BOMB_TIMER(%a5)
    clr.b OFF_CLOUD_TIMER(%a5)
    bra 9f
    | The map and the compass belong to the level they were found in (TakeClass0Complex).
22: cmp.b #ITEM_MAP, %d0
    beq 23f
    cmp.b #ITEM_COMPASS, %d0
    bne 40f
23: moveq #0, %d1
    move.b OFF_LEVEL(%a5), %d1
    beq 9f
    subq.w #1, %d1
    and.w #7, %d1
    moveq #1, %d2
    lsl.b %d1, %d2
    cmp.b #ITEM_MAP, %d0
    bne 24f
    or.b %d2, OFF_INV_MAP(%a5)
    bra 25f
24: or.b %d2, OFF_INV_COMPASS(%a5)
25: sfx SFX_ITEM_TAKEN
9:  bsr b_item_fix
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

    | Everything else is looked up the way TakeItem does: ItemIdToSlot says which byte of the Items
    | block it goes into and ItemIdToDescriptor how (class 0: you have it, 1: an amount to add,
    | 2: a grade, which only ever goes up).
40: cmp.b #ITEM_FAIRY, %d0
    bne 41f
    moveq #6, %d1                       | a fairy is worth three hearts
    bsr heal_link
    sfx SFX_HEART
    bra 9b
41: moveq #0, %d1
    move.b %d0, %d1
    ltab item_slot, %a0
    moveq #0, %d2
    move.b 0(%a0, %d1.w), %d2
    ltab item_desc, %a0
    move.b 0(%a0, %d1.w), %d1
    lea OFF_ITEMS(%a5), %a1
    adda.w %d2, %a1                     | a1 = the Items byte
    move.b %d1, %d2
    and.b #0x0f, %d2                    | the value
    lsr.b #4, %d1                       | the class
    beq 43f
    cmp.b #2, %d1
    beq 44f
    bhi 45f
    add.b (%a1), %d2                    | class 1: an amount, never past $FF
    bcc 46f
    move.b #0xff, %d2
46: cmp.b #ITEM_BLUE_POTION, %d0
    bne 47f
    cmp.b #3, %d2                       | two bottles at most
    blo 47f
    moveq #2, %d2
47: move.b %d2, (%a1)
    sfx SFX_ITEM_TAKEN
    bra 9b
45: move.b #0xff, (%a1)
    bra 9b
44: cmp.b (%a1), %d2                    | class 2: a lower grade changes nothing
    blo 48f
    move.b %d2, (%a1)
    cmp.b #ITEM_BLUE_RING, %d0
    blo 48f
    cmp.b #ITEM_RED_RING, %d0
    bhi 48f
    bsr link_ring_colour
48: jingle MUS_ITEM
    cmp.b #ITEM_RED_POTION, %d0
    beq 9b                              | a bottle of the red stuff is not held up
    bsr lift_begin
    bra 9b
43: move.b %d2, (%a1)                   | class 0: it is his
    cmp.b #ITEM_CLOCK, %d0
    beq 49f
    jingle MUS_ITEM
    bsr lift_begin
    bra 9b
49: sfx SFX_ITEM_TAKEN                  | the clock stops the monsters at once and is not held up
    bra 9b

| The end of the level, UpdateMode12EndLevel_Full: Link holds the triforce piece up
| (phase 1), the screen flashes (2), his hearts fill one by one (3), a curtain closes
| the room from both sides (4), a pause on the black room (5), and then he is back
| at the level's entrance on the overworld.
ending_update:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    move.b OFF_ENDING_PHASE(%a5), %d2
    beq 9f
    | the piece hovers 16 pixels above Link; the other slots are empty
    move.b #ITEM_TRIFORCE, OFF_ITEM_ID(%a5)
    move.b OFF_LINK_X(%a5), OFF_ITEM_X(%a5)
    move.b OFF_LINK_Y(%a5), %d0
    sub.b #16, %d0
    move.b %d0, OFF_ITEM_Y(%a5)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5)
    clr.b (OFF_ITEM_ACTIVE + 1)(%a5)
    clr.b (OFF_ITEM_ACTIVE + 2)(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    cmp.b #3, %d2
    beq 30f                             | the hearts have their own timing
    subq.b #1, OFF_ENDING_TIMER(%a5)
    cmp.b #2, %d2
    bhi 4f
    bne 20f                             | phase 1: hold
    bra 3f
    | phase 2: the backdrop flashes white every 4 frames
3:  movea.l #PALETTE_BASE, %a1
    bsr cur_palette
    move.b OFF_ENDING_TIMER(%a5), %d0
    beq 31f
    btst #2, %d0
    beq 32f
    move.w #0x0777, (%a1)
    bra 9f
32: move.w (%a0), (%a1)
    bra 9f
31: move.w (%a0), (%a1)             | the flash is over
    move.b #3, OFF_ENDING_PHASE(%a5)
    clr.b OFF_ENDING_TIMER(%a5)
    bra 9f
20: tst.b OFF_ENDING_TIMER(%a5)
    bne 9f
    move.b #2, OFF_ENDING_PHASE(%a5)
    move.b #ENDING_FLASH_FRAMES, OFF_ENDING_TIMER(%a5)
    bra 9f
    | phase 3: a half heart at a time until he has all his hearts
30: moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    add.w %d0, %d0
    cmp.b OFF_HP_HALVES(%a5), %d0
    bhi 33f
    move.b #4, OFF_ENDING_PHASE(%a5)
    clr.b OFF_ENDING_STEP(%a5)
    move.b #ENDING_CURTAIN_FRAMES, OFF_ENDING_TIMER(%a5)
    bra 9f
33: tst.b OFF_ENDING_TIMER(%a5)
    beq 34f
    subq.b #1, OFF_ENDING_TIMER(%a5)
    bra 9f
34: addq.b #1, OFF_HP_HALVES(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    sfx SFX_HEART
    move.b #ENDING_HEART_FRAMES, OFF_ENDING_TIMER(%a5)
    bra 9f
4:  cmp.b #4, %d2
    bne 5f
    | phase 4: the curtain
    tst.b OFF_ENDING_TIMER(%a5)
    bne 9f
    moveq #0, %d0
    move.b OFF_ENDING_STEP(%a5), %d0
    bsr curtain_column                  | the left edge, then the right edge
    moveq #31, %d1
    sub.w %d0, %d1
    move.w %d1, %d0
    bsr curtain_column
    addq.b #1, OFF_ENDING_STEP(%a5)
    move.b #ENDING_CURTAIN_FRAMES, OFF_ENDING_TIMER(%a5)
    cmpi.b #ENDING_CURTAIN_STEPS, OFF_ENDING_STEP(%a5)
    blo 9f
    move.b #5, OFF_ENDING_PHASE(%a5)
    move.b #ENDING_PAUSE_FRAMES, OFF_ENDING_TIMER(%a5)
    bra 9f
5:  tst.b OFF_ENDING_TIMER(%a5)         | phase 5: the pause, then out
    bne 9f
    clr.b OFF_ENDING_PHASE(%a5)
    clr.b OFF_LINK_HELD(%a5)
    clr.b OFF_ITEM_ACTIVE(%a5)
    bsr uw_leave_level
9:  movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| d0.w = a column of the playfield (0-31, 8 pixels wide): blank it in the clean room
| and in both screens, so Link's erasing keeps it black. Keeps every register.
curtain_column:
    movem.l %d0-%d2/%a0, -(%sp)
    move.w %d0, %d1
    lsr.w #1, %d1
    lsl.w #3, %d1                       | the 16-pixel group, 8 bytes each
    and.w #1, %d0
    add.w %d0, %d1                      | the left or the right byte of its words
    add.w #PLAYFIELD_ORIGIN, %d1
    .macro curtain_buffer off
    movea.l \off(%a5), %a0
    adda.w %d1, %a0
    move.w #(PLAYFIELD_HEIGHT - 1), %d2
1:  clr.b (%a0)
    clr.b 2(%a0)
    clr.b 4(%a0)
    clr.b 6(%a0)
    lea SCREEN_STRIDE(%a0), %a0
    dbra %d2, 1b
    .endm
    curtain_buffer OFF_BG_CUR
    curtain_buffer OFF_SCREEN_PTR
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 9f
    curtain_buffer OFF_BG_NEXT
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| ---------------------------------------------------- rooms and their shutters
| Once the last monster of an underworld room has died the room counts as
| cleared: its shutters open for good, and a trigger-7 item shows up.
uw_check_clear:
    movem.l %d0-%d1/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    uwlea FLAGS, %a0
    btst #0, 0(%a0, %d0.w)
    bne 9f
    cmpi.b #TRIGGER_RINGLEADER, OFF_ROOM_TRIGGER(%a5)
    bne 0f
    tst.b OFF_ENEMY_COUNT(%a5)
    beq 0f
    tst.b OFF_ENEMY_ACTIVE(%a5)
    bne 0f
    moveq #0, %d1                   | CheckSecretTriggerRingleader: the first monster is gone, so the rest die with it
5:  cmp.b OFF_ENEMY_COUNT(%a5), %d1
    bhs 0f
    cmpi.b #1, OFF_ENEMY_ACTIVE(%a5, %d1.w)
    bne 6f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    sfx SFX_MONSTER_DIED
6:  addq.w #1, %d1
    bra 5b
0:  moveq #0, %d1
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d1
    bhs 2f
    cmpi.b #1, OFF_ENEMY_ACTIVE(%a5, %d1.w)
    beq 9f                      | a blade trap (2) is not a monster to kill
    addq.w #1, %d1
    bra 1b
2:  cmpi.b #TRIGGER_MONEY_OR_LIFE, OFF_ROOM_TRIGGER(%a5)
    bne 4f
    move.b 0(%a0, %d0.w), %d1       | CheckSecretTriggerMoneyOrLife: the shutters wait until the man (or the stash) is gone
    and.b #0x0c, %d1                | UW_FLAG_PERSON, the stash taken
    beq 9f
4:  tst.b OFF_ROOM_TRIGGER(%a5)
    cmpi.b #TRIGGER_PUSH_BLOCK, OFF_ROOM_TRIGGER(%a5)
    beq 3f                      | this room's shutters wait for the block
    bsr uw_open_shutters
    tst.w %d1
    beq 3f
    bsr uw_redraw_room
3:  tst.b OFF_ROOM_UNSUPPORTED(%a5)
    bne 9f                      | monsters not ported yet: the room never counts as cleared
    bset #0, 0(%a0, %d0.w)
    cmpi.b #ROOM_ITEM_HIDDEN, OFF_ITEM_ACTIVE(%a5)
    bne 9f
    move.b #2, OFF_ITEM_ACTIVE(%a5)
    sfx SFX_ITEM_APPEARS
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| ---------------------------------------------------------------- push block
| A room with a push block (attribute D bit 6) has one that gives way once the monsters are dead:
| Link has to stand against it, lined up, and keep pushing for 16 frames. It
| then slides 16 pixels, a pixel a frame (UpdateBlock), drawn as a sprite over the room; when it lands a trigger-4
| room's shutters open for good and a trigger-5 room shows its stairs. BLOCK_X/Y are the origin of its top-left tile
| (the source while it slides).
    .equ TRIGGER_PUSH_BLOCK, 4
    .equ TRIGGER_RINGLEADER, 2
    .equ TRIGGER_MONEY_OR_LIFE, 6
    .equ BLOCK_TILE, 0xb0
    .equ BLOCK_ROW_Y, 0x40          | the top of the play area, where tile row 0 starts
    .equ BLOCK_PUSH_FRAMES, 16

| The routines (block_setup, block_push_tick, block_update, block_slide, block_land, block_draw) are at the end of the
| program, in bosses.s, where the code cluster has room; the near code calls them through the stubs of dmon.s.

| d0.w = room id. Marks every shutter of the room open; d1.w = 1 if one changed.
uw_open_shutters:
    movem.l %d0/%d2-%d3/%a0-%a2, -(%sp)
    moveq #0, %d3
    lvtab ROOM_INDEX, %a0
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d2
    lvtab DOORS, %a1
    adda.l %d2, %a1
    uwlea OPEN, %a2
    moveq #3, %d2
1:  cmpi.b #DOOR_SHUTTER, 0(%a1, %d2.w)
    bne 2f
    btst %d2, 0(%a2, %d0.w)
    bne 2f
    bset %d2, 0(%a2, %d0.w)
    moveq #1, %d3
2:  dbra %d2, 1b
8:  move.w %d3, %d1
    beq 9f
    sfx SFX_SECRET              | the shutters open
    sfx SMP_DOOR                | and the door sample (PrepareWriteHorizontalDoorTransferRecords)
9:  movem.l (%sp)+, %d0/%d2-%d3/%a0-%a2
    rts
