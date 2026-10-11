| Combat and pickups: the sword, damage in both directions, monster drops and
| the items lying on the floor.
|
| Simplifications against the original, to be revisited: one sword damage,
| no knock-back or shove, and a placeholder blade sprite.

    .equ SCAN_SPACE, 0x39
    .equ ATTACK_FRAMES, 12
    .equ SWORD_REACH, 12
    .equ ENEMY_HURT_FRAMES, 12
    .equ LINK_HURT_FRAMES, 40
    .equ CONTACT_RANGE, 10
    .equ PICKUP_RANGE, 9
    .equ ITEM_SLOTS, 3
    .equ KILL_CYCLE_LENGTH, 10
    .equ ROOM_ITEM_HIDDEN, 3
    .equ TRIGGER_KILL_ITEM, 7

    .equ ITEM_BOMBS, 0x00
    .equ ITEM_FIVE_RUPEES, 0x0f
    .equ ITEM_RUPEE, 0x18
    .equ ITEM_KEY, 0x19
    .equ ITEM_HEART_CONTAINER, 0x1a
    .equ ITEM_HEART, 0x22
    .equ MAX_BOMBS, 8

| ------------------------------------------------------------------- sword
| Space starts a swing, once per key press, when Link owns a sword.
sword_input:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_SPACE(%a0)
    beq 2f
    tst.b OFF_SPACE_HELD(%a5)
    bne 9f
    move.b #1, OFF_SPACE_HELD(%a5)
    tst.b OFF_HAS_SWORD(%a5)
    beq 9f
    tst.b OFF_ATTACK(%a5)
    bne 9f
    tst.b OFF_GAME_MODE(%a5)
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
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    tst.b OFF_ATTACK(%a5)
    beq 9f
    bsr sword_pos
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab sword_sprites, %a0
    adda.l %d0, %a0
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.l %d1, OFF_SWORD_ERASE_OFFSET(%a5)
    move.b #1, OFF_SWORD_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| Link blinks while he is invincible.
draw_link_blink:
    btst #1, OFF_LINK_HURT(%a5)
    bne 9f
    bsr draw_link
9:  rts

| ------------------------------------------------------------ per-frame logic
update_combat:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    tst.b OFF_LINK_HURT(%a5)
    beq 1f
    subq.b #1, OFF_LINK_HURT(%a5)
1:  tst.b OFF_ATTACK(%a5)
    beq 2f
    bsr sword_hits
    subq.b #1, OFF_ATTACK(%a5)
2:  bsr enemy_contact
    bsr item_pickup
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
    bsr hit_enemy
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

| Enemy d5 takes a hit and is killed when its hit points run out.
hit_enemy:
    move.b #ENEMY_HURT_FRAMES, OFF_ENEMY_HURT(%a5, %d5.w)
    move.b OFF_ENEMY_HP(%a5, %d5.w), %d0
    cmp.b #1, %d0
    bls kill_enemy
    subq.b #1, %d0
    move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
    rts

| Remove enemy d5 and roll for a drop from the table row of its group.
kill_enemy:
    clr.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    moveq #3, %d1
    cmpi.b #0xff, %d0
    beq 1f
    ltab mon_table, %a0
    lsl.w #3, %d0
    moveq #0, %d1
    move.b 4(%a0, %d0.w), %d1
    cmpi.b #0xff, %d1
    beq 9f                      | this kind never drops anything
1:  bsr rand8
    ltab drop_rates, %a0
    cmp.b 0(%a0, %d1.w), %d0
    bhs 4f
    mulu.w #KILL_CYCLE_LENGTH, %d1
    moveq #0, %d0
    move.b OFF_KILL_CYCLE(%a5), %d0
    add.w %d0, %d1
    ltab drop_table, %a0
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    bsr spawn_drop
4:  moveq #0, %d0
    move.b OFF_KILL_CYCLE(%a5), %d0
    addq.w #1, %d0
    cmp.w #KILL_CYCLE_LENGTH, %d0
    blo 5f
    moveq #0, %d0
5:  move.b %d0, OFF_KILL_CYCLE(%a5)
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
9:  movem.l (%sp)+, %d1-%d2/%a0
    rts

| ------------------------------------------------------------- Link's health
enemy_contact:
    movem.l %d0-%d5/%a0, -(%sp)
    tst.b OFF_LINK_HURT(%a5)
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
4:  bsr hurt_link
    bra 9f
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d5/%a0
    rts

| d1.w = half hearts of damage
hurt_link:
    move.l %d0, -(%sp)
    move.b #LINK_HURT_FRAMES, OFF_LINK_HURT(%a5)
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
    move.b #START_X, OFF_LINK_X(%a5)
    move.b #START_Y, OFF_LINK_Y(%a5)
    move.b #START_DIR, OFF_LINK_DIR(%a5)
    bsr enter_room
    move.b #1, OFF_HUD_DIRTY(%a5)
    movem.l (%sp)+, %d0-%d1
    rts

| ---------------------------------------------------------------------- bombs
| B drops a bomb in front of Link. When the fuse runs out it hurts monsters
| nearby and blows open a bombable wall next to it.
    .equ SCAN_B, 0x30
    .equ BOMB_FUSE, 80
    .equ BOMB_RANGE, 24
    .equ BOMB_LANE_X, 0x78
    .equ BOMB_LANE_Y, 0x8d
    .equ BOMB_DOOR_SLACK, 0x20
    .equ BOMB_DOOR_TYPE, 4

bomb_input:
    movem.l %d0-%d2/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_B(%a0)
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

bomb_tick:
    tst.b OFF_BOMB_TIMER(%a5)
    beq 9f
    subq.b #1, OFF_BOMB_TIMER(%a5)
    bne 9f
    bsr bomb_explode
9:  rts

bomb_explode:
    movem.l %d0-%d6/%a0-%a2, -(%sp)
    moveq #0, %d1
    move.b OFF_BOMB_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_BOMB_Y(%a5), %d2

    moveq #0, %d5               | monsters within reach are hit hard
1:  moveq #0, %d1               | killing a monster clobbers d1 and d2
    move.b OFF_BOMB_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_BOMB_Y(%a5), %d2
    cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 5f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 4f
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
    move.b #1, OFF_ENEMY_HP(%a5, %d5.w)
    clr.b OFF_ENEMY_HURT(%a5, %d5.w)
    bsr hit_enemy
4:  addq.w #1, %d5
    bra 1b

5:  tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    moveq #0, %d1               | killing monsters clobbered these
    move.b OFF_BOMB_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_BOMB_Y(%a5), %d2
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
    bset %d6, 0(%a2, %d0.w)
    bsr uw_redraw_room
9:  movem.l (%sp)+, %d0-%d6/%a0-%a2
    rts

| ---------------------------------------------------------------------- items
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
    moveq #0, %d0
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
    moveq #0, %d1
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
    cmp.b #ITEM_KEY, %d0
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
    bne 9f
    cmpi.b #HUD_HEART_SLOTS, OFF_HEART_CONTAINERS(%a5)
    bhs 9f
    addq.b #1, OFF_HEART_CONTAINERS(%a5)
    moveq #0, %d1
    move.b OFF_HEART_CONTAINERS(%a5), %d1
    add.w %d1, %d1
    move.b %d1, OFF_HP_HALVES(%a5)
9:  movem.l (%sp)+, %d0-%d2
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
    tst.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    bne 9f
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
