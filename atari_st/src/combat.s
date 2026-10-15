| Combat and pickups: the sword, damage in both directions, monster drops and
| the items lying on the floor.
|
| Simplifications against the original, to be revisited: one sword damage and
| a placeholder blade sprite.

    .equ SCAN_SPACE, 0x39           | B: the bombs
    .equ SCAN_CTRL, 0x1d            | A, with the joystick's fire button and Alternate
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
    .equ ITEM_WOOD_SWORD, 0x01
    .equ ITEM_FIVE_RUPEES, 0x0f
    .equ ITEM_RUPEE, 0x18
    .equ ITEM_KEY, 0x19
    .equ ITEM_HEART_CONTAINER, 0x1a
    .equ ITEM_TRIFORCE, 0x1b
    .equ TRIFORCE_FRAMES, 150
    .equ ITEM_HEART, 0x22
    .equ ITEM_FAIRY, 0x23
    .equ HELP_KILLS, 10
    .equ FAIRY_KILLS, 0x10
    .equ MAX_BOMBS, 8

| ------------------------------------------------------------------- sword
| The joystick's fire button, Alternate (Control in Hatari) starts a swing, once
| per press, when Link owns a sword.
sword_input:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_ALT(%a0)
    bne 1f
    tst.b SCAN_CTRL(%a0)
    bne 1f
    move.b OFF_JOY0(%a5), %d0
    or.b OFF_JOY1(%a5), %d0
    bpl 2f                      | fire is bit 7
1:  tst.b OFF_SPACE_HELD(%a5)
    bne 9f
    move.b #1, OFF_SPACE_HELD(%a5)
    tst.b OFF_HAS_SWORD(%a5)
    beq 9f
    tst.b OFF_ATTACK(%a5)
    bne 9f
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    move.b #ATTACK_FRAMES, OFF_ATTACK(%a5)
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
| With all hearts full (or short by half a heart) a swing also sends the sword
| flying, at three pixels a frame, until it hits a wall or a monster.
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
    subq.w #1, %d0
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
    bsr enemy_blocked_at
    tst.w %d0
    bne 9f                      | no room for it in front of Link
    move.b %d2, OFF_BEAM_X(%a5)
    move.b %d3, OFF_BEAM_Y(%a5)
    move.b OFF_LINK_DIR(%a5), OFF_BEAM_DIR(%a5)
    move.b #1, OFF_BEAM_ACTIVE(%a5)
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
    btst #0, %d6
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

4:  | A wall is met by the leading edge, 8 pixels past the origin going right or down.
    move.w %d2, %d4
    move.w %d3, %d5
    btst #0, %d6
    beq 41f
    addq.w #8, %d2
41: btst #2, %d6
    beq 42f
    addq.w #8, %d3
42: bsr enemy_blocked_at
    tst.w %d0
    bne 8f
    move.b %d4, OFF_BEAM_X(%a5)
    move.b %d5, OFF_BEAM_Y(%a5)

    moveq #0, %d6                       | monsters in the way
5:  cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 7f
    tst.b OFF_ENEMY_HURT(%a5, %d6.w)
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
    cmp.w #8, %d3
    blo 1b
    movem.l (%sp)+, %d0/%d3/%a0-%a1
    rts

| d0.w = frame in fx_sprites, d1.w = X, d2.w = Y, d6.w = slot.
fx_put:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab fx_sprites, %a0
    adda.l %d0, %a0
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

5:  moveq #0, %d7
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
    bsr ending_update
    tst.b OFF_LINK_HURT(%a5)
    beq 1f
    subq.b #1, OFF_LINK_HURT(%a5)
1:  tst.b OFF_ATTACK(%a5)
    beq 2f
    bsr sword_hits
    cmpi.b #BEAM_PHASE, OFF_ATTACK(%a5)
    bne 11f
    bsr beam_launch
11: subq.b #1, OFF_ATTACK(%a5)
2:  bsr enemy_contact
    bsr item_pickup
    bsr items_age
    bsr beam_update
    bsr bomb_tick
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f                      | a cellar is not one of the level's rooms
    bsr uw_check_clear
9:  movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| Every enemy within SWORD_REACH of the blade on both axes takes a hit.
sword_hits:
    movem.l %d0-%d6/%a0, -(%sp)
    cmpi.b #(ATTACK_FRAMES - 1), OFF_ATTACK(%a5)
    bhi 9f                      | the blade only cuts while it is fully out
    cmpi.b #4, OFF_ATTACK(%a5)
    blo 9f
    bsr sword_pos
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    bne 8f
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    sub.w %d1, %d3
    bpl 2f
    neg.w %d3
2:  cmp.w #SWORD_REACH, %d3
    bhs 8f
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d2, %d3
    bpl 3f
    neg.w %d3
3:  cmp.w #SWORD_REACH, %d3
    bhs 8f
    move.b OFF_LINK_DIR(%a5), OFF_ENEMY_SHOVE(%a5, %d5.w)
    bsr hit_enemy
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

| Enemy d5 takes a hit and is killed when its hit points run out.
hit_enemy:
    movem.l %d0/%a0, -(%sp)
    bsr enemy_behaviour
    cmp.w #BEH_TRAP, %d0
    movem.l (%sp)+, %d0/%a0
    bne 1f
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)   | nothing hurts a blade trap
    rts
1:  move.b #ENEMY_HURT_FRAMES, OFF_ENEMY_HURT(%a5, %d5.w)
    move.b OFF_ENEMY_HP(%a5, %d5.w), %d0
    cmp.b #1, %d0
    bls kill_enemy
    subq.b #1, %d0
    move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
    rts

| Remove enemy d5, count the kill and roll for a drop the way HandleMonsterDied
| and SetUpDroppedItem do. Ten kills in a row without being hurt guarantee a
| drop (a bomb if the tenth was a bomb kill, else five rupees), and the
| sixteenth is a fairy, which this port has no picture for yet.
kill_enemy:
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    addq.b #1, OFF_WORLD_KILLS(%a5)
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
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| ------------------------------------------------------------- Link's health
enemy_contact:
    movem.l %d0-%d5/%a0, -(%sp)
    tst.b OFF_LINK_HURT(%a5)
    bne 9f
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d0, %d3
    bpl 2f
    neg.w %d3
2:  cmp.w #CONTACT_RANGE, %d3
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

    moveq #1, %d1               | blobs bite for a half heart
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmpi.b #0xff, %d0
    beq 4f
    ltab mon_table, %a0
    lsl.w #3, %d0
    moveq #0, %d1
    move.b 3(%a0, %d0.w), %d1
4:  bsr link_knockback
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
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
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

| d1.w = half hearts of damage
hurt_link:
    move.l %d0, -(%sp)
    move.b #LINK_HURT_FRAMES, OFF_LINK_HURT(%a5)
    clr.b OFF_WORLD_KILLS(%a5)          | being hurt starts the kill streak over
    clr.b OFF_HELP_COUNT(%a5)
    clr.b OFF_HELP_VALUE(%a5)
    moveq #0, %d0
    move.b OFF_HP_HALVES(%a5), %d0
    sub.w %d1, %d0
    bgt 1f
    moveq #0, %d0
1:  move.b %d0, OFF_HP_HALVES(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    tst.b %d0
    bne 9f
    bsr link_dies
9:  move.l (%sp)+, %d0
    rts

| Out of hearts: full health and back to the start of the overworld.
link_dies:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    add.w %d0, %d0
    move.b %d0, OFF_HP_HALVES(%a5)
    clr.b OFF_LEVEL(%a5)
    clr.b OFF_IN_CELLAR(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_HURT(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    clr.b OFF_LINK_HELD(%a5)
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    move.b #1, OFF_WARPED(%a5)
    move.b #LINK_EDGE_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #LINK_EDGE_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #LINK_EDGE_UP, OFF_BOUND_UP(%a5)
    move.b #LINK_EDGE_DOWN, OFF_BOUND_DOWN(%a5)
    move.b #ROOM_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #ROOM_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #ROOM_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #ROOM_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b #START_ROOM_ID, OFF_ROOM_ID(%a5)
    move.b #HOME_X, OFF_LINK_X(%a5)
    move.b #HOME_Y, OFF_LINK_Y(%a5)
    move.b #START_DIR, OFF_LINK_DIR(%a5)
    bsr enter_room
    move.b #1, OFF_HUD_DIRTY(%a5)
    movem.l (%sp)+, %d0-%d1
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
    .equ BOMB_RANGE, 24
    .equ BOMB_LANE_X, 0x78
    .equ BOMB_LANE_Y, 0x8d
    .equ BOMB_DOOR_SLACK, 0x20
    .equ BOMB_DOOR_TYPE, 4

bomb_input:
    movem.l %d0-%d2/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_SPACE(%a0)
    beq 2f
    tst.b OFF_B_HELD(%a5)
    bne 9f
    move.b #1, OFF_B_HELD(%a5)
    tst.b OFF_INV_BOMBS(%a5)
    beq 9f
    tst.b OFF_BOMB_TIMER(%a5)
    bne 9f
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    subq.b #1, OFF_INV_BOMBS(%a5)
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
    bra 9f
2:  clr.b OFF_B_HELD(%a5)
9:  movem.l (%sp)+, %d0-%d2/%a0
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
    tst.b OFF_BOMB_TIMER(%a5)
    beq 1f
    subq.b #1, OFF_BOMB_TIMER(%a5)
    bne 9f
    move.b OFF_BOMB_X(%a5), OFF_CLOUD_X(%a5)
    move.b OFF_BOMB_Y(%a5), OFF_CLOUD_Y(%a5)
    move.b #BOMB_CLOUD_FRAMES, OFF_CLOUD_TIMER(%a5)
1:  tst.b OFF_CLOUD_TIMER(%a5)
    beq 8f
    cmpi.b #BOMB_AFTER_FRAMES, OFF_CLOUD_TIMER(%a5)
    bhi 2f
    bne 3f
    bsr bomb_open_wall
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
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    moveq #0, %d0
    move.b OFF_ENEMY_HP(%a5, %d5.w), %d0
    cmp.w #BOMB_DAMAGE, %d0
    bhi 31f
    moveq #1, %d0               | it has less than that left: the hit below finishes it
    bra 32f
31: sub.w #(BOMB_DAMAGE - 1), %d0
32: move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
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
    ltab room_palette, %a0
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
    clr.b OFF_CLOUD_TIMER(%a5)
    clr.b OFF_SPARK_K(%a5)
    tst.b OFF_FLASH_ON(%a5)
    beq 9f
    clr.b OFF_FLASH_ON(%a5)
    ltab room_palette, %a0
    movea.l #PALETTE_BASE, %a1
    moveq #15, %d0
1:  move.w (%a0)+, (%a1)+
    dbra %d0, 1b
9:  movem.l (%sp)+, %d0/%a0-%a1
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
    ltab uw_room_index, %a0
    moveq #0, %d3
    move.b 0(%a0, %d0.w), %d3
    cmpi.b #0xff, %d3
    beq 9f
    mulu.w #UW_DOOR_RECORD_BYTES, %d3
    ltab uw_doors, %a1
    adda.l %d3, %a1
    cmpi.b #BOMB_DOOR_TYPE, 0(%a1, %d6.w)
    bne 9f
    lea OFF_UW_OPEN(%a5), %a2
    btst %d6, 0(%a2, %d0.w)
    bne 9f
    move.w %d6, %d2
    bsr uw_open_door_pair
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

clear_items:
    movem.l %d0/%a0, -(%sp)
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
    lea OFF_UW_FLAGS(%a5), %a0
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

item_pickup:
    movem.l %d0-%d4/%a0, -(%sp)
    moveq #0, %d3
1:  move.b OFF_ITEM_ACTIVE(%a5, %d3.w), %d0
    beq 8f
    cmp.b #ROOM_ITEM_HIDDEN, %d0
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
5:  lea OFF_UW_FLAGS(%a5), %a0
    bset #1, 0(%a0, %d1.w)
4:  clr.b OFF_ITEM_ACTIVE(%a5, %d3.w)
8:  addq.w #1, %d3
    cmp.w #ITEM_SLOTS, %d3
    blo 1b
    movem.l (%sp)+, %d0-%d4/%a0
    rts

| Apply the effect of item d0.b to Link's counters. Items without an effect
| here yet (maps, weapons, ...) are simply collected.
take_item:
    movem.l %d0-%d2, -(%sp)
    move.b #1, OFF_HUD_DIRTY(%a5)
    cmp.b #ITEM_WOOD_SWORD, %d0
    bne 0f
    move.b #1, OFF_HAS_SWORD(%a5)
    bra 9f
0:  cmp.b #ITEM_KEY, %d0
    bne 1f
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
5:  moveq #0, %d2
    move.b OFF_INV_RUPEES(%a5), %d2
    add.w %d1, %d2
    cmp.w #255, %d2
    bls 6f
    move.w #255, %d2
6:  move.b %d2, OFF_INV_RUPEES(%a5)
    bra 9f
3:  cmp.b #ITEM_BOMBS, %d0
    bne 4f
    moveq #0, %d2
    move.b OFF_INV_BOMBS(%a5), %d2
    addq.w #4, %d2
    cmp.w #MAX_BOMBS, %d2
    bls 7f
    moveq #MAX_BOMBS, %d2
7:  move.b %d2, OFF_INV_BOMBS(%a5)
    bra 9f
4:  cmp.b #ITEM_HEART, %d0
    bne 8f
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
    addq.b #1, OFF_HEART_CONTAINERS(%a5)
    moveq #0, %d1
    move.b OFF_HEART_CONTAINERS(%a5), %d1
    add.w %d1, %d1
    move.b %d1, OFF_HP_HALVES(%a5)
    bra 9f
10: cmp.b #ITEM_TRIFORCE, %d0
    bne 9f
    move.b #1, OFF_TRIFORCE(%a5)
    move.b #TRIFORCE_FRAMES, OFF_ENDING_TIMER(%a5)
    move.b #1, OFF_LINK_HELD(%a5)       | he stands holding it up while the screen flashes
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    moveq #0, %d1
    move.b OFF_HEART_CONTAINERS(%a5), %d1
    add.w %d1, %d1
    move.b %d1, OFF_HP_HALVES(%a5)      | the level is won: full hearts
9:  movem.l (%sp)+, %d0-%d2
    rts

| The celebration after the triforce piece: the backdrop flashes, then Link is
| back at the level's entrance on the overworld.
ending_update:
    movem.l %d0/%a0-%a1, -(%sp)
    tst.b OFF_ENDING_TIMER(%a5)
    beq 9f
    subq.b #1, OFF_ENDING_TIMER(%a5)
    movea.l #PALETTE_BASE, %a1
    ltab room_palette, %a0
    move.b OFF_ENDING_TIMER(%a5), %d0
    beq 2f
    btst #2, %d0
    beq 1f
    move.w #0x0777, (%a1)
    bra 9f
1:  move.w (%a0), (%a1)
    bra 9f
2:  move.w (%a0), (%a1)
    clr.b OFF_LINK_HELD(%a5)
    bsr uw_leave_level
9:  movem.l (%sp)+, %d0/%a0-%a1
    rts

| ---------------------------------------------------- rooms and their shutters
| Once the last monster of an underworld room has died the room counts as
| cleared: its shutters open for good, and a trigger-7 item shows up.
uw_check_clear:
    movem.l %d0-%d1/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lea OFF_UW_FLAGS(%a5), %a0
    btst #0, 0(%a0, %d0.w)
    bne 9f
    moveq #0, %d1
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d1
    bhs 2f
    cmpi.b #1, OFF_ENEMY_ACTIVE(%a5, %d1.w)
    beq 9f                      | a blade trap (2) is not a monster to kill
    addq.w #1, %d1
    bra 1b
2:  bsr uw_open_shutters
    tst.w %d1
    beq 3f
    bsr uw_redraw_room
3:  tst.b OFF_ROOM_UNSUPPORTED(%a5)
    bne 9f                      | monsters not ported yet: the room never counts as cleared
    bset #0, 0(%a0, %d0.w)
    cmpi.b #ROOM_ITEM_HIDDEN, OFF_ITEM_ACTIVE(%a5)
    bne 9f
    move.b #2, OFF_ITEM_ACTIVE(%a5)
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| d0.w = room id. Marks every shutter of the room open; d1.w = 1 if one changed.
uw_open_shutters:
    movem.l %d0/%d2-%d3/%a0-%a2, -(%sp)
    moveq #0, %d3
    ltab uw_room_index, %a0
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d2
    ltab uw_doors, %a1
    adda.l %d2, %a1
    lea OFF_UW_OPEN(%a5), %a2
    moveq #3, %d2
1:  cmpi.b #DOOR_SHUTTER, 0(%a1, %d2.w)
    bne 2f
    btst %d2, 0(%a2, %d0.w)
    bne 2f
    bset %d2, 0(%a2, %d0.w)
    moveq #1, %d3
2:  dbra %d2, 1b
8:  move.w %d3, %d1
    movem.l (%sp)+, %d0/%d2-%d3/%a0-%a2
    rts
