| The monsters of Levels 3 to 8 that are too big for dmon.s's neighbourhood: the wizzrobes, Manhandla, and the
| other bosses. This file sits at the very end of the code, so everything it calls in the rest of the program goes
| through the trampolines below (and the routines dmon.s calls here through its own).

    .purgem sfx
    .macro sfx id
    move.l %d0, -(%sp)
    moveq #\id, %d0
    bsr music_play_bf
    move.l (%sp)+, %d0
    .endm

    farstub enemy_make_bf, enemy_make
    farstub enemy_out_of_bounds_bf, enemy_out_of_bounds
    farstub enemy_square_blocked_bf, enemy_square_blocked
    farstub fetch_tile_bf, fetch_tile
    farstub kill_enemy_bf, kill_enemy
    farstub rand8_bf, rand8
    farstub tile_blocks_bf, tile_blocks
    farstub walker_fire_bf, walker_fire
    farstub zora_fire_bf, zora_fire
    farstub keese_ai_bf, keese_ai
    farstub mon_art_ptr_bf, mon_art_ptr
    farstub sprite_offset_bf, sprite_offset
    farstub draw_sprite_bf, draw_sprite
    farstub music_play_bf, music_play
    farstub uw_redraw_room_bf, uw_redraw_room
    farstub take_item_bf, take_item
    farstub enemy_cell_blocked_bf, enemy_cell_blocked
    farstub opposite_dir_bf, opposite_dir

| ---------------------------------------------------------------- wizzrobes
| Wizzrobes (UpdateBlueWizzrobe, UpdateRedWizzrobe). ENEMY_GHOST is set while one is not drawn: weapons pass through
| it and it does Link no harm, which stands in for the original's drawing and colliding only on every other frame.
|
| Blue: walks (a pixel every other frame, turning toward Link every $40 steps) while ENEMY_TIMER runs down from
| $70-$FF, pauses for 15 frames, then picks a diagonal and slides $20 pixels that way (ENEMY_DIST left) through
| whatever is there. It shoots when it stands level with Link and faces him.
| Red: ENEMY_STATE counts down every frame; $C0-$FF it fades in, $80-$BF it is solid (and shoots at $B0), $40-$7F
| fades out, $00-$3F it is gone. At $FF it picks a new square around Link and a new heading.
|
| d5 = monster. Returns d0.w = 0: the caller does not move it.
dmon_wizzrobe:
    movem.l %d1-%d4/%d6/%a0, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    clr.b 0(%a0, %d5.w)
    tst.b OFF_INV_CLOCK(%a5)
    bne 90f                             | frozen: it stands and shows
    cmpi.b #MON_WIZ_RED, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq 40f
    | ---- blue
    moveq #0, %d0
    move.b OFF_ENEMY_TIMER(%a5, %d5.w), %d0
    bne 10f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)    | timer 0: sliding, or finished
    beq 5f
    subq.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bsr wiz_slide
    bra 80f
5:  bsr wiz_align_rand
    bsr wiz_turn_link
    bra 80f
10: cmp.b #0x10, %d0
    bhs 20f
    cmp.b #1, %d0
    bne 11f
    bsr wiz_choose_target
    bra 80f
11: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 80f
20: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    bne 21f
    addq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bsr wiz_turn_check
    bsr wiz_walk
    bra 80f
21: bsr wiz_turn_check
80: tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 82f
    bsr wiz_try_shoot
    bra 90f
82: lea OFF_ENEMY_GHOST(%a5), %a0
    move.w OFF_FRAME_COUNTER(%a5), %d0  | sliding: shown every other frame
    btst #0, %d0
    beq 90f
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    bra 90f
    | ---- red
40: subq.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    moveq #0, %d6
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d6
    move.w %d6, %d0
    lsr.w #6, %d0
    beq 49f                             | $00-$3F: gone
    cmp.w #2, %d0
    beq 45f
    blo 41f
    cmp.b #0xff, %d6                    | $C0-$FF
    beq 60f
    bra 46f
41: cmp.b #0x7f, %d6                    | $40-$7F: fading out, and $30 frames shorter than it looks
    bne 46f
    move.b #0x4f, OFF_ENEMY_STATE(%a5, %d5.w)
46: btst #0, %d6                        | fading: shown every other frame
    beq 90f
49: move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    bra 90f
45: cmp.b #0xb0, %d6
    bne 90f
    bsr walker_fire_bf                     | solid: at $B0 it shoots the way it faces
    tst.w %d0
    beq 90f
    sfx SFX_MAGIC
    bra 90f
60: | $FF: a new place near Link. If it is no good, the state wraps to 0 and tries again next frame.
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    bsr rand8_bf
    move.w %d0, %d6
    move.w %d6, %d1
    and.w #3, %d1
    lea red_dirs(%pc), %a0
    move.b 0(%a0, %d1.w), OFF_ENEMY_DIR(%a5, %d5.w)
    and.w #15, %d6
    lea red_offsets_x(%pc), %a0
    moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    move.b 0(%a0, %d6.w), %d1
    ext.w %d1
    add.w %d1, %d2
    and.w #0xf0, %d2
    lea red_offsets_y(%pc), %a0
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    add.w #3, %d3
    move.b 0(%a0, %d6.w), %d1
    ext.w %d1
    add.w %d1, %d3
    and.w #0xf0, %d3
    sub.w #3, %d3
    cmp.w #0x5d, %d3
    blo 69f
    cmp.w #0xc4, %d3
    bhs 69f
    bsr enemy_square_blocked_bf
    tst.w %d0
    bne 69f
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bra 91f
69: addq.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
91: lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
90: movem.l (%sp)+, %d1-%d4/%d6/%a0
    moveq #0, %d0
    rts

red_dirs:
    .byte DIR_DOWN, DIR_UP, DIR_RIGHT, DIR_LEFT
red_offsets_x:
    .byte 0x00, 0x00, 0xe0, 0x20, 0x00, 0x00, 0xc0, 0x40, 0x00, 0x00, 0xd0, 0x30, 0x00, 0x00, 0xb0, 0x50
red_offsets_y:
    .byte 0xe0, 0x20, 0x00, 0x00, 0xc0, 0x40, 0x00, 0x00, 0xd0, 0x30, 0x00, 0x00, 0xb0, 0x50, 0x00, 0x00
wiz_lead_x:
    .byte 0x0f, 0x00, 0x00, 0x04, 0x08, 0x00, 0x00, 0x04, 0x08, 0x00
wiz_lead_y:
    .byte 0x04, 0x04, 0x00, 0x08, 0x08, 0x08, 0x00, 0xf8, 0x00, 0x00
wiz_jump_dirs:
    .byte 0x0a, 0x09, 0x06, 0x05
wiz_jump_dx:
    .byte 0xe0, 0x20, 0xe0, 0x20
wiz_jump_dy:
    .byte 0xe0, 0xe0, 0x20, 0x20
    .balign 2

| Blue wizzrobe: the timer for the next walk, and the square it stands on.
wiz_align_rand:
    bsr rand8_bf
    or.b #0x70, %d0
    move.b %d0, OFF_ENEMY_TIMER(%a5, %d5.w)
| Jump to the nearest square corner.
wiz_align:
    movem.l %d0, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    add.w #8, %d0
    and.w #0xf0, %d0
    move.b %d0, OFF_ENEMY_X(%a5, %d5.w)
    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d0
    add.w #8, %d0
    and.w #0xf0, %d0
    sub.w #3, %d0
    move.b %d0, OFF_ENEMY_Y(%a5, %d5.w)
    movem.l (%sp)+, %d0
    rts

| Every $40 steps it turns toward Link: sideways, then up or down.
wiz_turn_check:
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    and.b #0x3f, %d0
    bne 9f
wiz_turn_link:
    movem.l %d1-%d2, -(%sp)
    moveq #0, %d1
    moveq #0, %d2
    btst #6, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 5f
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    move.b OFF_LINK_X(%a5), %d2
    moveq #DIR_LEFT, %d0
    cmp.w %d2, %d1
    bhs 8f
    moveq #DIR_RIGHT, %d0
    bra 8f
5:  move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    move.b OFF_LINK_Y(%a5), %d2
    moveq #DIR_UP, %d0
    cmp.w %d2, %d1
    bhs 8f
    moveq #DIR_DOWN, %d0
8:  cmp.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    beq 7f
    move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr wiz_align
7:  movem.l (%sp)+, %d1-%d2
9:  rts

| One pixel along the heading (eight ways).
wiz_step:
    movem.l %d0-%d2, -(%sp)
    moveq #0, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    btst #0, %d0
    beq 1f
    addq.w #1, %d1
1:  btst #1, %d0
    beq 2f
    subq.w #1, %d1
2:  btst #2, %d0
    beq 3f
    addq.w #1, %d2
3:  btst #3, %d0
    beq 4f
    subq.w #1, %d2
4:  add.b %d1, OFF_ENEMY_X(%a5, %d5.w)
    add.b %d2, OFF_ENEMY_Y(%a5, %d5.w)
    movem.l (%sp)+, %d0-%d2
    rts

| The tile under the leading edge of the heading. Returns d0.w = NES tile id, $FF outside the room.
wiz_lead_tile:
    movem.l %d1-%d3/%a0, -(%sp)
    moveq #0, %d1
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1
    subq.w #1, %d1
    cmp.w #9, %d1
    bhi 8f
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    lea wiz_lead_x(%pc), %a0
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    add.w %d0, %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    add.w #0x0b, %d3
    lea wiz_lead_y(%pc), %a0
    move.b 0(%a0, %d1.w), %d0
    ext.w %d0
    add.w %d0, %d3
    sub.w #NES_PLAY_AREA_TOP, %d3
    bmi 8f
    lsr.w #3, %d3
    lsr.w #3, %d2
    cmp.w #(PLAY_AREA_ROWS - 1), %d3
    bhi 8f
    cmp.w #(PLAY_AREA_COLS - 1), %d2
    bhi 8f
    move.w %d2, %d1
    move.w %d3, %d2
    move.w %d1, %d3
    bsr fetch_tile_bf
    bra 9f
8:  move.w #0xff, %d0
9:  movem.l (%sp)+, %d1-%d3/%a0
    rts

| Walking one pixel: a wall turns it about, a block or water or a door sends it sliding through.
wiz_walk:
    bsr wiz_step
wiz_walk_check:
    bsr wiz_lead_tile
    move.w %d0, %d1
    bsr tile_blocks_bf
    tst.w %d0
    beq 9f
    move.w %d1, %d0
    and.w #0xfc, %d0
    cmp.w #0xb0, %d0
    beq 5f
    cmp.w #0xf4, %d0
    bhs 5f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0   | a wall: flip the heading and step back
    move.b %d0, %d1
    and.b #0x0c, %d1
    beq 2f
    eor.b #0x0c, %d0
2:  move.b %d0, %d1
    and.b #0x03, %d1
    beq 3f
    eor.b #0x03, %d0
3:  move.b %d0, OFF_ENEMY_DIR(%a5, %d5.w)
    bra wiz_step
5:  bsr wiz_begin_slide
9:  rts

wiz_begin_slide:
    move.b #0x20, OFF_ENEMY_STATE(%a5, %d5.w)
    eor.b #0x40, OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bra wiz_align

| One pixel of a slide. It stops at the edge of the room.
wiz_slide:
    movem.l %d0/%d2-%d3, -(%sp)
    bsr wiz_step
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    bsr enemy_out_of_bounds_bf
    tst.w %d0
    beq 9f
    bsr wiz_back                        | out of the room: the slide ends here
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0/%d2-%d3
    rts

| Undo the last step.
wiz_back:
    movem.l %d0-%d2, -(%sp)
    moveq #0, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    btst #0, %d0
    beq 1f
    subq.w #1, %d1
1:  btst #1, %d0
    beq 2f
    addq.w #1, %d1
2:  btst #2, %d0
    beq 3f
    subq.w #1, %d2
3:  btst #3, %d0
    beq 4f
    addq.w #1, %d2
4:  add.b %d1, OFF_ENEMY_X(%a5, %d5.w)
    add.b %d2, OFF_ENEMY_Y(%a5, %d5.w)
    movem.l (%sp)+, %d0-%d2
    rts

| The walk is over: look for a place $20 pixels away on a diagonal to slide to.
wiz_choose_target:
    movem.l %d1-%d4/%a0, -(%sp)
    bsr rand8_bf
    and.w #3, %d0
    move.w %d0, %d4
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    lea wiz_jump_dx(%pc), %a0
    move.b 0(%a0, %d4.w), %d1
    ext.w %d1
    add.w %d1, %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    lea wiz_jump_dy(%pc), %a0
    move.b 0(%a0, %d4.w), %d1
    ext.w %d1
    add.w %d1, %d3
    and.w #0xff, %d2
    and.w #0xff, %d3
    bsr enemy_square_blocked_bf
    tst.w %d0
    beq 5f
    bsr wiz_align_rand                  | no room there: line up and walk on
    bra 9f
5:  lea wiz_jump_dirs(%pc), %a0
    move.b 0(%a0, %d4.w), OFF_ENEMY_DIR(%a5, %d5.w)
    bsr wiz_begin_slide
9:  movem.l (%sp)+, %d1-%d4/%a0
    rts

| Every $20 frames, if it faces Link along its own row or column, it shoots.
wiz_try_shoot:
    movem.l %d0-%d3, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #0x1f, %d0
    bne 9f
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    and.w #0xf0, %d1
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    and.w #0xf0, %d2
    cmp.w %d1, %d2
    bne 5f
    moveq #DIR_LEFT, %d3                | same row: left if it stands to Link's right
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    cmp.b OFF_LINK_X(%a5), %d1
    bhs 4f
    moveq #DIR_RIGHT, %d3
    bra 4f
5:  moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    and.w #0xf0, %d1
    moveq #0, %d2
    move.b OFF_LINK_X(%a5), %d2
    cmp.w %d1, %d2
    bne 9f
    moveq #DIR_UP, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    cmp.b OFF_LINK_Y(%a5), %d1
    bhs 4f
    moveq #DIR_DOWN, %d3
4:  cmp.b OFF_ENEMY_DIR(%a5, %d5.w), %d3
    bne 9f
    bsr walker_fire_bf
    tst.w %d0
    beq 9f
    sfx SFX_MAGIC
9:  movem.l (%sp)+, %d0-%d3
    rts

| The picture: two steps (a pair for up) and a flip to the left; none while it is not drawn.
dmon_wizzrobe_frame:
    movem.l %d2, -(%sp)
    lea OFF_ENEMY_GHOST(%a5), %a0
    moveq #-1, %d1
    moveq #0, %d5
    tst.b 0(%a0, %d3.w)
    bne 9f
    move.w %d4, %d1
    lsr.w #2, %d1
    and.w #1, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #3, %d2
    beq 5f
    addq.w #2, %d1                      | facing up: pictures 2 and 3
    bra 9f
5:  btst #1, %d2
    beq 9f
    moveq #1, %d5
9:  movem.l (%sp)+, %d2
    rts

| ------------------------------------------------------------------ Manhandla
| UpdateManhandla: a body (ENEMY_STEP 0) with four hands (1 up, 2 down, 3 left, 4 right), each a monster of its own
| with hit points of its own. The body steers and the hands ride on it, so the whole moves as one; it wanders in
| eight directions, turning toward Link or at random every $10 frames, and speeds up (by half a pixel a frame)
| every time a hand dies. When the last hand is gone the body dies too. Hands that are not hit by the boomerang
| or fire shoot a fireball now and then, when their picture changes. The body's ENEMY_SPEED/STATE are the speed
| (low and high), ENEMY_FRAC its fraction, ENEMY_ANIMC the picture counter, ENEMY_TIMER the turn timer;
| ENEMY_ANIMF of every piece is the picture of its animation, 0 or 1.
manhandla_init:
    movem.l %d0-%d4/%d6/%a0-%a1, -(%sp)
    tst.b OFF_BOSS_BUSY(%a5)
    bne 9f                              | one of the hands put down below
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #0x80, 0(%a0, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bsr rand8_bf
    and.w #7, %d0
    lea dirs8(%pc), %a0
    move.b 0(%a0, %d0.w), %d4
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
    move.b #1, OFF_BOSS_BUSY(%a5)
    moveq #1, %d6
1:  moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    lea manhandla_dx(%pc), %a0
    move.b 0(%a0, %d6.w), %d0
    ext.w %d0
    add.w %d0, %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    lea manhandla_dy(%pc), %a0
    move.b 0(%a0, %d6.w), %d0
    ext.w %d0
    add.w %d0, %d3
    moveq #MON_MANHANDLA, %d1
    bsr enemy_make_bf
    tst.w %d0
    bmi 2f
    move.b %d6, OFF_ENEMY_STEP(%a5, %d0.w)
2:  addq.w #1, %d6
    cmp.w #5, %d6
    blo 1b
    clr.b OFF_BOSS_BUSY(%a5)
9:  movem.l (%sp)+, %d0-%d4/%d6/%a0-%a1
    rts

dirs8:
    .byte DIR_RIGHT, DIR_LEFT, DIR_DOWN, DIR_UP, (DIR_RIGHT + DIR_DOWN), (DIR_RIGHT + DIR_UP), (DIR_LEFT + DIR_DOWN), (DIR_LEFT + DIR_UP)
manhandla_dx:
    .byte 0, 0, 0, -16, 16
manhandla_dy:
    .byte 0, -16, 16, 0, 0
manhandla_images:                       | the first picture of each piece in the art: body, up, down, left, right
    .byte 4, 0, 6, 2, 2
    .balign 2

| d5 = a Manhandla piece. Only the body does anything.
dmon_manhandla:
    movem.l %d1-%d4/%d6-%d7/%a0-%a1, -(%sp)
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 90f
    moveq #0, %d6                       | pixels to move this frame
    tst.b OFF_INV_CLOCK(%a5)
    bne 40f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 5f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 20f
5:  move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr rand8_bf
    cmp.b #0x80, %d0
    bhs 6f
    and.w #7, %d0                       | at random
    lea dirs8(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    bra 20f
6:  moveq #0, %d1                       | or toward Link, a pixel level counting as level
    moveq #0, %d2
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    sub.w %d3, %d0
    cmp.w #8, %d0
    ble 61f
    moveq #DIR_RIGHT, %d1
    bra 62f
61: cmp.w #-8, %d0
    bge 62f
    moveq #DIR_LEFT, %d1
62: moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d3, %d0
    cmp.w #8, %d0
    ble 63f
    or.b #DIR_DOWN, %d1
    bra 64f
63: cmp.w #-8, %d0
    bge 64f
    or.b #DIR_UP, %d1
64: tst.b %d1
    beq 20f
    move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
20: lea OFF_ENEMY_SPEED(%a5), %a0       | the speed's fraction (low byte and $E0) piles up; its carry adds a pixel
    moveq #0, %d1
    move.b 0(%a0, %d5.w), %d1
    and.w #0xe0, %d1
    lea OFF_ENEMY_FRAC(%a5), %a0
    moveq #0, %d2
    move.b 0(%a0, %d5.w), %d2
    add.w %d1, %d2
    move.b %d2, 0(%a0, %d5.w)
    lsr.w #8, %d2
    moveq #0, %d6
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d6
    add.w %d2, %d6
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    move.w %d6, %d1
    beq 30f
    subq.w #1, %d1
21: btst #0, %d4
    beq 22f
    addq.w #1, %d2
22: btst #1, %d4
    beq 23f
    subq.w #1, %d2
23: btst #2, %d4
    beq 24f
    addq.w #1, %d3
24: btst #3, %d4
    beq 25f
    subq.w #1, %d3
25: dbra %d1, 21b
30: | bounce off the room's bounds, a hand's width in from them
    moveq #0, %d0
    move.b OFF_OBJ_LEFT(%a5), %d0
    add.w #16, %d0
    cmp.w %d0, %d2
    bge 31f
    move.w %d0, %d2
    and.b #(0xff - DIR_LEFT), %d4
    or.b #DIR_RIGHT, %d4
31: moveq #0, %d0
    move.b OFF_OBJ_RIGHT(%a5), %d0
    sub.w #16, %d0
    cmp.w %d0, %d2
    ble 32f
    move.w %d0, %d2
    and.b #(0xff - DIR_RIGHT), %d4
    or.b #DIR_LEFT, %d4
32: moveq #0, %d0
    move.b OFF_OBJ_UP(%a5), %d0
    add.w #16, %d0
    cmp.w %d0, %d3
    bge 33f
    move.w %d0, %d3
    and.b #(0xff - DIR_UP), %d4
    or.b #DIR_DOWN, %d4
33: moveq #0, %d0
    move.b OFF_OBJ_DOWN(%a5), %d0
    sub.w #16, %d0
    cmp.w %d0, %d3
    ble 34f
    move.w %d0, %d3
    and.b #(0xff - DIR_DOWN), %d4
    or.b #DIR_UP, %d4
34: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
40: | the picture changes with distance travelled and a little luck
    bsr rand8_bf
    and.w #3, %d0
    add.w %d6, %d0
    lea OFF_ENEMY_ANIMC(%a5), %a0
    add.b %d0, 0(%a0, %d5.w)
    moveq #0, %d1
    move.b 0(%a0, %d5.w), %d1
    lsr.w #4, %d1
    and.w #1, %d1                       | the new picture
    lea OFF_ENEMY_ANIMF(%a5), %a0
    moveq #0, %d6
    move.b 0(%a0, %d5.w), %d6           | the old one
    move.b %d1, 0(%a0, %d5.w)
    moveq #0, %d2
    cmp.w %d6, %d1
    beq 41f
    tst.w %d1
    bne 41f
    moveq #1, %d2                       | back to picture 0: the hands may spit
41: moveq #0, %d6                       | now the hands: put each where it belongs and give it the picture
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    moveq #0, %d4
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d4
50: cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 90f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 59f
    cmpi.b #MON_MANHANDLA, OFF_ENEMY_TYPE(%a5, %d6.w)
    bne 59f
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d6.w), %d0
    beq 59f
    lea manhandla_dx(%pc), %a0
    move.b 0(%a0, %d0.w), %d7
    ext.w %d7
    add.w %d3, %d7
    move.b %d7, OFF_ENEMY_X(%a5, %d6.w)
    lea manhandla_dy(%pc), %a0
    move.b 0(%a0, %d0.w), %d7
    ext.w %d7
    add.w %d4, %d7
    move.b %d7, OFF_ENEMY_Y(%a5, %d6.w)
    move.b OFF_ENEMY_DIR(%a5, %d5.w), OFF_ENEMY_DIR(%a5, %d6.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    move.b %d1, 0(%a0, %d6.w)
    tst.w %d2
    beq 59f
    bsr rand8_bf
    cmp.b #0xe0, %d0
    blo 59f
    bsr manhandla_spit
59: addq.w #1, %d6
    bra 50b
90: movem.l (%sp)+, %d1-%d4/%d6-%d7/%a0-%a1
    moveq #1, %d0
    rts

| Hand d6 spits a fireball at Link (the room never holds more than four of them).
manhandla_spit:
    movem.l %d0-%d4/%d6-%d7/%a0, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a0
    moveq #0, %d0
    moveq #(MAX_PROJ - 1), %d1
1:  cmpi.b #PK_FIREBALL, 0(%a0, %d1.w)
    bne 2f
    addq.w #1, %d0
2:  dbra %d1, 1b
    cmp.w #4, %d0
    bhs 9f
    move.w %d5, -(%sp)
    move.w %d6, %d5
    bsr zora_fire_bf
    move.w (%sp)+, %d5
9:  movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0
    rts

| d5 = a Manhandla piece that has just been killed. A hand makes the rest faster; the last one takes the body with it.
manhandla_died:
    movem.l %d0-%d3/%d5/%a0, -(%sp)
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    beq 9f                              | the body itself
    moveq #0, %d0                       | hands left
    moveq #-1, %d2                      | the body's slot
    moveq #0, %d1
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d1
    bhs 5f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d1.w)
    beq 2f
    cmpi.b #MON_MANHANDLA, OFF_ENEMY_TYPE(%a5, %d1.w)
    bne 2f
    tst.b OFF_ENEMY_STEP(%a5, %d1.w)
    bne 3f
    move.w %d1, %d2
    bra 2f
3:  addq.w #1, %d0
2:  addq.w #1, %d1
    bra 1b
5:  tst.w %d2
    bmi 9f
    lea OFF_ENEMY_SPEED(%a5), %a0       | half a pixel a frame faster
    moveq #0, %d1
    move.b 0(%a0, %d2.w), %d1
    add.w #0x80, %d1
    move.b %d1, 0(%a0, %d2.w)
    lsr.w #8, %d1
    add.b %d1, OFF_ENEMY_STATE(%a5, %d2.w)
    tst.w %d0
    bne 9f
    move.w %d2, %d5                     | the last hand is gone: so is the body
    bsr kill_enemy_bf
9:  movem.l (%sp)+, %d0-%d3/%d5/%a0
    rts

| ------------------------------------------------------------------ Gohma
| UpdateGohma: an eye (ENEMY_STEP 0) with a leg on each side (1 left, 2 right), which are monsters of their own that
| nothing hurts and that are alive for good (ENEMY_ACTIVE 2: never counted for the room). The eye walks $20 pixels
| (half a pixel a frame) right, left or down, and back; after every second leg of the round trip it picks another way.
| It blinks, and now and then opens ($80 frames: half open, open, half open); only an arrow flying up into it when it
| is fully open (state 3) hurts. It spits a fireball at Link every $41 frames.
| Per slot: ENEMY_STATE the eye's picture, ENEMY_TIMER the fireball timer, ENEMY_TURN "keep going this way",
| ENEMY_DIST the pixels walked, ENEMY_FRAC the move accumulator, ENEMY_SPEED the legs walked, ENEMY_WANT the count to
| the next opening, ENEMY_BOUNCE the opening's timer, ENEMY_ANIMC the blink counter.
gohma_init:
    movem.l %d0-%d4/%d6/%a0, -(%sp)
    tst.b OFF_BOSS_BUSY(%a5)
    bne 9f                              | one of the legs put down below
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    move.b #DIR_DOWN, OFF_ENEMY_DIR(%a5, %d5.w)
    lea OFF_ENEMY_TURN(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_DIST(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_WANT(%a5), %a0
    move.b #0x60, 0(%a0, %d5.w)
    lea OFF_ENEMY_BOUNCE(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    move.b #1, OFF_BOSS_BUSY(%a5)
    moveq #MON_GOHMA_LEG_BLUE, %d1
    cmpi.b #MON_GOHMA_RED, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    moveq #MON_GOHMA_LEG_RED, %d1
1:  move.w %d1, %d6
    moveq #1, %d4                       | leg 1, then leg 2
2:  moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.w %d6, %d1
    move.w %d4, -(%sp)
    move.w %d6, -(%sp)
    moveq #DIR_DOWN, %d4
    bsr enemy_make_bf
    move.w (%sp)+, %d6
    move.w (%sp)+, %d4
    tst.w %d0
    bmi 3f
    move.b %d4, OFF_ENEMY_STEP(%a5, %d0.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d0.w)
3:  addq.w #1, %d4
    cmp.w #3, %d4
    blo 2b
    clr.b OFF_BOSS_BUSY(%a5)
9:  movem.l (%sp)+, %d0-%d4/%d6/%a0
    rts

| d5 = a Gohma piece. Only the eye does anything; the eye puts the legs beside itself.
dmon_gohma:
    movem.l %d1-%d4/%d6/%a0-%a1, -(%sp)
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 90f
    tst.b OFF_INV_CLOCK(%a5)
    bne 60f
    lea OFF_ENEMY_TURN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    bne 20f
    bsr rand8_bf                        | pick the way: right from $B0, left from $60, else down
    moveq #DIR_RIGHT, %d1
    cmp.b #0xb0, %d0
    bhs 10f
    moveq #DIR_LEFT, %d1
    cmp.b #0x60, %d0
    bhs 10f
    moveq #DIR_DOWN, %d1
10: move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
    addq.b #1, 0(%a0, %d5.w)
    bra 40f
20: lea OFF_ENEMY_FRAC(%a5), %a1        | half a pixel a frame
    moveq #0, %d0
    move.b 0(%a1, %d5.w), %d0
    add.w #0x80, %d0
    move.b %d0, 0(%a1, %d5.w)
    btst #8, %d0
    beq 40f
    lea OFF_ENEMY_DIST(%a5), %a1
    addq.b #1, 0(%a1, %d5.w)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    btst #0, %d4
    beq 21f
    addq.w #1, %d2
21: btst #1, %d4
    beq 22f
    subq.w #1, %d2
22: btst #2, %d4
    beq 23f
    addq.w #1, %d3
23: btst #3, %d4
    beq 24f
    subq.w #1, %d3
24: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    cmpi.b #0x20, 0(%a1, %d5.w)
    bne 40f
    clr.b 0(%a1, %d5.w)                 | $20 pixels: turn back
    move.b %d4, %d1
    and.b #(DIR_RIGHT + DIR_DOWN), %d1
    add.b %d1, %d1
    and.b #(DIR_LEFT + DIR_UP), %d4
    lsr.b #1, %d4
    or.b %d4, %d1
    move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a1
    move.b 0(%a1, %d5.w), %d0
    addq.b #1, 0(%a1, %d5.w)
    btst #0, %d0
    beq 40f
    clr.b 0(%a0, %d5.w)                 | after the second leg of a round trip: another way
40: lea OFF_ENEMY_WANT(%a5), %a0        | the eye
    lea OFF_ENEMY_BOUNCE(%a5), %a1
    tst.b 0(%a0, %d5.w)
    bne 41f
    move.b #0x80, 0(%a1, %d5.w)         | open it for $80 frames
    bsr rand8_bf
    or.b #0xc0, %d0
    move.b %d0, 0(%a0, %d5.w)
41: move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    beq 42f
    subq.b #1, 0(%a0, %d5.w)
42: moveq #0, %d0
    move.b 0(%a1, %d5.w), %d0
    beq 50f
    subq.b #1, 0(%a1, %d5.w)
    moveq #2, %d1                       | half open at both ends of the opening, open between
    cmp.b #0x70, %d0
    bhs 43f
    cmp.b #0x10, %d0
    blo 43f
    moveq #3, %d1
43: move.b %d1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 55f
50: lea OFF_ENEMY_ANIMC(%a5), %a0       | shut: blinks between pictures 0 and 1
    addq.b #1, 0(%a0, %d5.w)
    cmpi.b #8, 0(%a0, %d5.w)
    bne 51f
    clr.b 0(%a0, %d5.w)
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d0
    and.b #1, %d0
    eor.b #1, %d0
    move.b %d0, OFF_ENEMY_STATE(%a5, %d5.w)
51: cmpi.b #2, OFF_ENEMY_STATE(%a5, %d5.w)
    blo 55f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)   | it has just closed
55: subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 60f
    move.b #0x41, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr zora_fire_bf
60: moveq #0, %d6                       | the legs, one on each side of the eye
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    moveq #0, %d4
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d4
61: cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 90f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 69f
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d6.w), %d0
    beq 69f
    move.b OFF_ENEMY_TYPE(%a5, %d6.w), %d1
    cmp.b #MON_GOHMA_LEG_BLUE, %d1
    beq 62f
    cmp.b #MON_GOHMA_LEG_RED, %d1
    bne 69f
62: move.w %d3, %d2
    sub.w #16, %d2
    cmp.w #1, %d0
    beq 63f
    add.w #32, %d2
63: move.b %d2, OFF_ENEMY_X(%a5, %d6.w)
    move.b %d4, OFF_ENEMY_Y(%a5, %d6.w)
69: addq.w #1, %d6
    bra 61b
90: movem.l (%sp)+, %d1-%d4/%d6/%a0-%a1
    moveq #1, %d0
    rts

| d5 = the eye, just killed: the legs go with it.
gohma_died:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d0
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d0
    bhs 9f
    move.b OFF_ENEMY_TYPE(%a5, %d0.w), %d1
    cmp.b #MON_GOHMA_LEG_BLUE, %d1
    beq 2f
    cmp.b #MON_GOHMA_LEG_RED, %d1
    bne 3f
2:  clr.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
3:  addq.w #1, %d0
    bra 1b
9:  movem.l (%sp)+, %d0-%d1
    rts

| --------------------------------------------------------------- Digdogger
| UpdateDigdogger. A big one is four monsters: the one in the top left corner (ENEMY_STEP 0, which counts for the
| room and does the thinking) and three pieces (STEP 1 right, 2 below, 3 below right) that follow it and are not
| counted. Nothing hurts any of them; the recorder splits the big one ($40 frames later) into little ones (type
| MON_DIG_KID), three of them, or one for the ROM's second kind (MON_DIGDOGGER2). A little one is a monster with
| 8 hit points of its own.
| Both kinds fly in eight directions: the speed is a 16-bit number (ENEMY_STATE whole, ENEMY_SPEED fraction) that
| rises by one a frame to a target (ENEMY_DIST whole, ENEMY_TURN fraction) and then falls to another one
| (ENEMY_WANT 0 rising, 1 falling): big ones between $40 and $80, little ones between $140 and $180 (1.25 to 1.5
| pixels a frame). Every $10 frames (ENEMY_TIMER) it turns at random or toward Link; ENEMY_FRAC is the
| accumulator of the speed's fraction, ENEMY_ANIMC counts down the $40 frames after the recorder.
dig_init:
    movem.l %d0-%d4/%d6/%a0, -(%sp)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #0x3f, 0(%a0, %d5.w)
    lea OFF_ENEMY_TURN(%a5), %a0
    move.b #0x80, 0(%a0, %d5.w)
    lea OFF_ENEMY_DIST(%a5), %a0
    clr.b 0(%a0, %d5.w)
    cmpi.b #MON_DIG_KID, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    move.b #1, 0(%a0, %d5.w)            | a little one aims at $0180
1:  lea OFF_ENEMY_WANT(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bsr rand8_bf
    and.w #7, %d0
    lea dirs8(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    cmpi.b #MON_DIG_KID, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq 9f
    tst.b OFF_BOSS_BUSY(%a5)
    bne 9f
    move.b #1, OFF_BOSS_BUSY(%a5)       | a big one: put its three other quarters down
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d6
    and.w #0xff, %d6
    moveq #1, %d4
2:  moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.w %d6, %d1
    move.w %d4, -(%sp)
    move.w %d6, -(%sp)
    moveq #DIR_DOWN, %d4
    bsr enemy_make_bf
    move.w (%sp)+, %d6
    move.w (%sp)+, %d4
    tst.w %d0
    bmi 3f
    move.b %d4, OFF_ENEMY_STEP(%a5, %d0.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d0.w)
3:  addq.w #1, %d4
    cmp.w #4, %d4
    blo 2b
    clr.b OFF_BOSS_BUSY(%a5)
9:  movem.l (%sp)+, %d0-%d4/%d6/%a0
    rts

| The recorder: every big Digdogger that has not been played to starts counting down.
dig_flute:
    movem.l %d0-%d1/%a0, -(%sp)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    moveq #0, %d0
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d0
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
    beq 2f
    tst.b OFF_ENEMY_STEP(%a5, %d0.w)
    bne 2f
    move.b OFF_ENEMY_TYPE(%a5, %d0.w), %d1
    cmp.b #MON_DIGDOGGER, %d1
    beq 3f
    cmp.b #MON_DIGDOGGER2, %d1
    bne 2f
3:  tst.b 0(%a0, %d0.w)
    bne 2f
    move.b #0x40, 0(%a0, %d0.w)
2:  addq.w #1, %d0
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| d5 = a Digdogger piece. Returns d0.w = 1: it moves itself.
dmon_dig:
    movem.l %d1-%d4/%d6-%d7/%a0-%a1, -(%sp)
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 90f                             | a quarter goes where the corner puts it
    moveq #0, %d7                       | d7 = 1 for a little one
    cmpi.b #MON_DIG_KID, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    moveq #1, %d7
1:  tst.b OFF_INV_CLOCK(%a5)
    bne 60f
    lea OFF_ENEMY_ANIMC(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 5f
    subq.b #1, 0(%a0, %d5.w)            | the recorder has played: it stands there, then splits
    beq dig_split
    bra 60f
5:  moveq #0, %d1                       | the speed, whole and fraction
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d1
    lsl.w #8, %d1
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b 0(%a0, %d5.w), %d1
    moveq #0, %d2                       | the target
    lea OFF_ENEMY_DIST(%a5), %a1
    move.b 0(%a1, %d5.w), %d2
    lsl.w #8, %d2
    lea OFF_ENEMY_TURN(%a5), %a1
    move.b 0(%a1, %d5.w), %d2
    lea OFF_ENEMY_WANT(%a5), %a1
    tst.b 0(%a1, %d5.w)
    bne 51f
    addq.w #1, %d1                      | rising
    cmp.w %d2, %d1
    bne 52f
    move.b #1, 0(%a1, %d5.w)
    moveq #0x40, %d2
    bra 53f
51: subq.w #1, %d1                      | falling
    cmp.w %d2, %d1
    bne 52f
    clr.b 0(%a1, %d5.w)
    move.w #0x80, %d2
53: move.w %d7, %d0                     | the new target: a little one's is a whole pixel higher
    lsl.w #8, %d0
    add.w %d0, %d2
    lea OFF_ENEMY_TURN(%a5), %a1
    move.b %d2, 0(%a1, %d5.w)
    lsr.w #8, %d2
    lea OFF_ENEMY_DIST(%a5), %a1
    move.b %d2, 0(%a1, %d5.w)
52: move.b %d1, 0(%a0, %d5.w)
    lsr.w #8, %d1
    move.b %d1, OFF_ENEMY_STATE(%a5, %d5.w)
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | turn every $10 frames
    beq 6f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 20f
6:  move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr rand8_bf
    cmp.b #0x80, %d0
    bhs 61f
    and.w #7, %d0                       | at random
    lea dirs8(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_DIR(%a5, %d5.w)
    bra 20f
61: moveq #0, %d1                       | or toward Link, a pixel level counting as level
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    sub.w %d3, %d0
    cmp.w #8, %d0
    ble 62f
    moveq #DIR_RIGHT, %d1
    bra 63f
62: cmp.w #-8, %d0
    bge 63f
    moveq #DIR_LEFT, %d1
63: moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    sub.w %d3, %d0
    cmp.w #8, %d0
    ble 64f
    or.b #DIR_DOWN, %d1
    bra 65f
64: cmp.w #-8, %d0
    bge 65f
    or.b #DIR_UP, %d1
65: tst.b %d1
    beq 20f
    move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
20: lea OFF_ENEMY_SPEED(%a5), %a0       | the fraction ($E0 of it) piles up; its carry adds a pixel
    moveq #0, %d1
    move.b 0(%a0, %d5.w), %d1
    and.w #0xe0, %d1
    lea OFF_ENEMY_FRAC(%a5), %a0
    moveq #0, %d2
    move.b 0(%a0, %d5.w), %d2
    add.w %d1, %d2
    move.b %d2, 0(%a0, %d5.w)
    lsr.w #8, %d2
    moveq #0, %d6
    move.b OFF_ENEMY_STATE(%a5, %d5.w), %d6
    add.w %d2, %d6                      | pixels to move
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    move.w %d6, %d1
    beq 30f
    subq.w #1, %d1
21: btst #0, %d4
    beq 22f
    addq.w #1, %d2
22: btst #1, %d4
    beq 23f
    subq.w #1, %d2
23: btst #2, %d4
    beq 24f
    addq.w #1, %d3
24: btst #3, %d4
    beq 25f
    subq.w #1, %d3
25: dbra %d1, 21b
30: moveq #0, %d6                       | bounce off the room's bounds (a big one needs 16 more on the right and below)
    tst.w %d7
    bne 31f
    moveq #16, %d6
31: moveq #0, %d0
    move.b OFF_OBJ_LEFT(%a5), %d0
    cmp.w %d0, %d2
    bge 32f
    move.w %d0, %d2
    and.b #(0xff - DIR_LEFT), %d4
    or.b #DIR_RIGHT, %d4
32: moveq #0, %d0
    move.b OFF_OBJ_RIGHT(%a5), %d0
    sub.w %d6, %d0
    cmp.w %d0, %d2
    ble 33f
    move.w %d0, %d2
    and.b #(0xff - DIR_RIGHT), %d4
    or.b #DIR_LEFT, %d4
33: moveq #0, %d0
    move.b OFF_OBJ_UP(%a5), %d0
    cmp.w %d0, %d3
    bge 34f
    move.w %d0, %d3
    and.b #(0xff - DIR_UP), %d4
    or.b #DIR_DOWN, %d4
34: moveq #0, %d0
    move.b OFF_OBJ_DOWN(%a5), %d0
    sub.w %d6, %d0
    cmp.w %d0, %d3
    ble 35f
    move.w %d0, %d3
    and.b #(0xff - DIR_DOWN), %d4
    or.b #DIR_UP, %d4
35: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
60: tst.w %d7                           | a big one: the other three quarters
    bne 90f
    moveq #0, %d3
    move.b OFF_ENEMY_X(%a5, %d5.w), %d3
    moveq #0, %d4
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d4
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d7
    moveq #0, %d6
61: cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 90f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 69f
    cmp.b OFF_ENEMY_TYPE(%a5, %d6.w), %d7
    bne 69f
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d6.w), %d0
    beq 69f
    moveq #0, %d1                       | the corner: 1 is to the right, 2 below, 3 both
    moveq #0, %d2
    btst #0, %d0
    beq 62f
    moveq #16, %d1
62: btst #1, %d0
    beq 63f
    moveq #16, %d2
63: add.w %d3, %d1
    add.w %d4, %d2
    move.b %d1, OFF_ENEMY_X(%a5, %d6.w)
    move.b %d2, OFF_ENEMY_Y(%a5, %d6.w)
69: addq.w #1, %d6
    bra 61b
90: movem.l (%sp)+, %d1-%d4/%d6-%d7/%a0-%a1
    moveq #1, %d0
    rts

| d5 = a big Digdogger that has been played to: it and its quarters go, and little ones take its place.
dig_split:
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #3, %d6                       | how many children: three, or one for the second kind
    cmpi.b #MON_DIGDOGGER2, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    moveq #1, %d6
1:  move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d7
    moveq #0, %d0
2:  cmp.b OFF_ENEMY_COUNT(%a5), %d0     | the quarters leave with their corner
    bhs 4f
    cmp.b OFF_ENEMY_TYPE(%a5, %d0.w), %d7
    bne 3f
    clr.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
3:  addq.w #1, %d0
    bra 2b
4:  sfx SFX_MONSTER_DIED
    move.b #1, OFF_BOSS_BUSY(%a5)
5:  moveq #MON_DIG_KID, %d1
    movem.l %d2-%d3/%d6, -(%sp)
    moveq #DIR_DOWN, %d4
    bsr enemy_make_bf
    movem.l (%sp)+, %d2-%d3/%d6
    subq.w #1, %d6
    bne 5b
    clr.b OFF_BOSS_BUSY(%a5)
    movem.l (%sp)+, %d1-%d4/%d6-%d7/%a0-%a1
    moveq #1, %d0
    rts

| ----------------------------------------------------------------- Gleeok
| UpdateGleeok. The body (type MON_GLEEOK2/3/4: two, three or four necks) stays at ($7C, $6F) and is drawn, like
| the necks, from the boss sprite pool: every frame the pieces put their pictures into BP_FRAME/X/Y (bp_add) and
| boss_pool_draw (called after the effects are drawn) paints them in effect slots 12 up, which erase like any other
| effect. The body is a monster nothing hurts; touching it hurts Link. Each neck's head is a monster (MON_GLEEOK_HEAD,
| ENEMY_STEP the neck's number): only the sword hurts it, $A0 points of it (ten hits of the wooden sword). Per head:
| ENEMY_TIMER the delay before it starts, ENEMY_TURN and ENEMY_DIST the horizontal and vertical way (0 forward,
| else back), ENEMY_BOUNCE the count to four, ENEMY_ANIMC and ENEMY_ANIMF the counts to $0C and 6 that turn it.
| A head moves a pixel every fourth frame and now and then spits a fireball (one at a time). Cut off, it flies
| about as a head of its own (MON_GLEEOK_FLYER, a keese's flight, harmless to weapons) and shoots. When the last
| neck is gone the body dies, and the flying heads with it.
    .equ GLEEOK_BODY_X, 0x7c
    .equ GLEEOK_BODY_Y, 0x6f
    .equ GLEEOK_HEAD_Y, 0x83
    .equ BP_MAX, 24
    .equ BP_FIRST_SLOT, 12              | the effect slot of pool entry 0
    .equ GLEEOK_PICTURE, 1              | the body picture that is painted into the room

| d0.w = image, d1.w = X, d2.w = Y. Adds a picture to this frame's pool.
bp_add:
    movem.l %d3/%a0, -(%sp)
    moveq #0, %d3
    move.b OFF_BP_COUNT(%a5), %d3
    cmp.w #BP_MAX, %d3
    bhs 9f
    lea OFF_BP_FRAME(%a5), %a0
    move.b %d0, 0(%a0, %d3.w)
    lea OFF_BP_X(%a5), %a0
    move.b %d1, 0(%a0, %d3.w)
    lea OFF_BP_Y(%a5), %a0
    move.b %d2, 0(%a0, %d3.w)
    addq.b #1, OFF_BP_COUNT(%a5)
9:  movem.l (%sp)+, %d3/%a0
    rts

| d0.w = image, d1.w = X, d2.w = Y, a1 = the buffer to paint into. Returns d1.l = the byte offset it went to, d4.w = -1
| when it is off the playfield. The images from BP_SEGMENT up (a neck segment, a head) are eight pixels wide and come
| pre-shifted, one table of 16 shifts after the body's pictures (the art's frame 28 and 60): no shifting at run time, and
| a segment is only its middle eight lines. A frame has no time for more.
    .equ BP_SEGMENT, 12
    .equ BP_HEAD, 13
    .equ BP_PRE_FRAME, 28               | the art's first pre-shifted frame (after 14 images of two frames)
bp_paint:
    movem.l %d0/%d2/%d3/%d5-%d7/%a0-%a3, -(%sp)
    movea.l %a1, %a3
    move.w %d0, %d5
    move.w %d1, %d3
    move.w %d2, %d6
    moveq #MON_GLEEOK2, %d0
    add.w %d0, %d0
    bsr mon_art_ptr_bf
    moveq #0, %d7
    move.w 0(%a0, %d0.w), %d7           | the art's first frame
    moveq #0, %d1
    move.w %d3, %d1
    moveq #0, %d2
    move.w %d6, %d2
    bsr sprite_offset_bf
    tst.w %d4
    bmi 9f
    movea.l %a3, %a1
    adda.l %d1, %a1
    cmp.w #BP_SEGMENT, %d5
    bhs 1f
    add.w %d5, %d5                      | a piece of the body: the plain copy of the image
    add.w %d5, %d7
    mulu.w #SPRITE_FRAME_BYTES, %d7
    movea.l OFF_MON_SPR(%a5), %a0
    adda.l %d7, %a0
    move.w %d4, %d0
    bsr draw_sprite_bf
    bra 9f
1:  add.w #BP_PRE_FRAME, %d7
    moveq #15, %d3                      | lines to draw, less one
    cmp.w #BP_HEAD, %d5
    bne 2f
    add.w #32, %d7                      | the head's tables follow the segment's
    bra 3f
2:  moveq #7, %d3
3:  move.w %d4, %d0
    add.w %d0, %d0
    add.w %d0, %d7                      | two frames a shift
    mulu.w #SPRITE_FRAME_BYTES, %d7
    movea.l OFF_MON_SPR(%a5), %a0
    adda.l %d7, %a0
    cmp.w #15, %d3
    beq 4f
    lea (4 * 20)(%a0), %a0              | the segment: lines 4 to 11
    lea (4 * SCREEN_STRIDE)(%a1), %a1
4:  move.w %d3, %d7
    bsr draw_pre
9:  movem.l (%sp)+, %d0/%d2/%d3/%d5-%d7/%a0-%a3
    rts

| A pre-shifted picture: a0 = its lines (twenty bytes each: four plane words and the inverted mask for each of two
| groups), a1 = the destination, d4.w = the shift (up to 8: the second group is empty), d7.w = lines less one.
draw_pre:
    movem.l %d1-%d5/%d7/%a0-%a1, -(%sp)
    cmp.w #8, %d4
    bhi 3f
1:  movem.w (%a0)+, %d1-%d5
    and.w %d5, (%a1)
    or.w %d1, (%a1)+
    and.w %d5, (%a1)
    or.w %d2, (%a1)+
    and.w %d5, (%a1)
    or.w %d3, (%a1)+
    and.w %d5, (%a1)
    or.w %d4, (%a1)+
    lea 10(%a0), %a0
    lea (SCREEN_STRIDE - 8)(%a1), %a1
    dbra %d7, 1b
    bra 9f
3:  movem.w (%a0)+, %d1-%d5
    and.w %d5, (%a1)
    or.w %d1, (%a1)+
    and.w %d5, (%a1)
    or.w %d2, (%a1)+
    and.w %d5, (%a1)
    or.w %d3, (%a1)+
    and.w %d5, (%a1)
    or.w %d4, (%a1)+
    movem.w (%a0)+, %d1-%d5
    and.w %d5, (%a1)
    or.w %d1, (%a1)+
    and.w %d5, (%a1)
    or.w %d2, (%a1)+
    and.w %d5, (%a1)
    or.w %d3, (%a1)+
    and.w %d5, (%a1)
    or.w %d4, (%a1)+
    lea (SCREEN_STRIDE - 16)(%a1), %a1
    dbra %d7, 3b
9:  movem.l (%sp)+, %d1-%d5/%d7/%a0-%a1
    rts

| Draws the pool and empties it.
boss_pool_draw:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    moveq #0, %d6
1:  cmp.b OFF_BP_COUNT(%a5), %d6
    bhs 9f
    lea OFF_BP_FRAME(%a5), %a0
    moveq #0, %d0
    move.b 0(%a0, %d6.w), %d0
    lea OFF_BP_X(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d6.w), %d1
    lea OFF_BP_Y(%a5), %a0
    moveq #0, %d2
    move.b 0(%a0, %d6.w), %d2
    movea.l OFF_SCREEN_PTR(%a5), %a1
    bsr bp_paint
    tst.w %d4
    bmi 2f
    move.w %d6, %d0
    add.w #BP_FIRST_SLOT, %d0
    lsl.w #2, %d0
    lea OFF_FX_ERASE_OFFSETS(%a5), %a0
    move.l %d1, 0(%a0, %d0.w)
    lea (OFF_FX_VALID + BP_FIRST_SLOT)(%a5), %a0
    move.b #1, 0(%a0, %d6.w)
2:  addq.w #1, %d6
    bra 1b
9:  clr.b OFF_BP_COUNT(%a5)
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| a1 = a buffer a dungeon room has just been drawn into, d0 = the room: if a Gleeok lives there its body (the
| first of its three pictures) is painted into it, so that the body costs nothing per frame. The room is
| redrawn without it when it dies (gleeok_died).
gleeok_bake:
    movem.l %d0-%d2/%d6/%a0/%a1, -(%sp)
    moveq #3, %d6
1:  lea gleeok_body_pieces(%pc), %a0
    move.w %d6, %d1
    add.w %d1, %d1
    moveq #0, %d2
    move.b 1(%a0, %d1.w), %d2           | Y
    move.b 0(%a0, %d1.w), %d1           | X
    and.w #0xff, %d1
    moveq #(GLEEOK_PICTURE * 4), %d0
    add.w %d6, %d0
    bsr bp_paint
    dbra %d6, 1b
    movem.l (%sp)+, %d0-%d2/%d6/%a0/%a1
    rts

| d5 = the body, just put down.
gleeok_init:
    movem.l %d0-%d4/%d6-%d7/%a0-%a2, -(%sp)
    tst.b OFF_BOSS_BUSY(%a5)
    bne 9f
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    move.b #GLEEOK_BODY_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #GLEEOK_BODY_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_GLEEOK_DEAD(%a5)
    clr.b OFF_GLEEOK_GONE(%a5)
    clr.b OFF_BP_COUNT(%a5)
    clr.b OFF_GLEEOK_ANIM(%a5)
    clr.b (OFF_GLEEOK_ANIM + 1)(%a5)
    moveq #0, %d7
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d7
    sub.w #MON_GLEEOK2, %d7
    addq.w #2, %d7                      | the number of necks
    move.b #3, OFF_GLEEOK_SEGS(%a5)     | a neck's segments: two, but one with four necks
    cmp.w #4, %d7
    bne 0f
    move.b #2, OFF_GLEEOK_SEGS(%a5)
0:
    move.b #1, OFF_BOSS_BUSY(%a5)
    moveq #0, %d6
1:  moveq #MON_GLEEOK_HEAD, %d1
    move.w #GLEEOK_BODY_X, %d2
    move.w #GLEEOK_HEAD_Y, %d3
    moveq #DIR_DOWN, %d4
    movem.l %d6-%d7, -(%sp)
    bsr enemy_make_bf
    movem.l (%sp)+, %d6-%d7
    tst.w %d0
    bmi 3f
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d0.w)     | a head is no monster of the room: the body is
    move.b %d6, OFF_ENEMY_STEP(%a5, %d0.w)
    move.w %d6, %d1                             | its delay: 0, 12, 24, 36 steps
    mulu.w #12, %d1
    move.b %d1, OFF_ENEMY_TIMER(%a5, %d0.w)
    lea OFF_ENEMY_ANIMC(%a5), %a0
    move.b #6, 0(%a0, %d0.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    move.b #3, 0(%a0, %d0.w)
    lea OFF_ENEMY_BOUNCE(%a5), %a0
    clr.b 0(%a0, %d0.w)
    moveq #0, %d1                               | necks 0 and 2 start back in X, 1 and 3 in Y
    moveq #0, %d2
    btst #0, %d6
    bne 2f
    moveq #-1, %d1
    bra 21f
2:  moveq #-1, %d2
21: lea OFF_ENEMY_TURN(%a5), %a0
    move.b %d1, 0(%a0, %d0.w)
    lea OFF_ENEMY_DIST(%a5), %a0
    move.b %d2, 0(%a0, %d0.w)
3:  addq.w #1, %d6
    cmp.w %d7, %d6
    blo 1b
    clr.b OFF_BOSS_BUSY(%a5)
    lea OFF_GSEG_X(%a5), %a0            | the middle segments hang straight down from the body
    lea OFF_GSEG_Y(%a5), %a1
    moveq #11, %d1
4:  move.b #GLEEOK_BODY_X, 0(%a0, %d1.w)
    moveq #0, %d2
    move.w %d1, %d2
    divu.w #3, %d2
    swap %d2                            | segment 0 to 2 of its neck
    lea gleeok_seg_y(%pc), %a2
    move.b 0(%a2, %d2.w), 0(%a1, %d1.w)
    dbra %d1, 4b
9:  movem.l (%sp)+, %d0-%d4/%d6-%d7/%a0-%a2
    rts

gleeok_seg_y:
    .byte 0x74, 0x79, 0x7e
    .balign 2

| One fireball at a time, from monster d5.
gleeok_fire:
    movem.l %d0/%a0, -(%sp)
    lea OFF_PROJ_KIND(%a5), %a0
    moveq #7, %d0
1:  cmpi.b #PK_FIREBALL, (%a0)+
    beq 9f
    dbra %d0, 1b
    bsr zora_fire_bf
9:  movem.l (%sp)+, %d0/%a0
    rts

gleeok_body_pieces:
    .byte 0x74, 0x57, 0x84, 0x57, 0x74, 0x67, 0x84, 0x67     | the body's four pieces: X, Y
gleeok_pictures:
    .byte 1, 0, 1, 2                    | which of its three pictures the body shows, in turn

| d5 = the body. It is part of the room's picture (gleeok_bake) and does nothing. Returns d0.w = 1.
dmon_gleeok:
    moveq #1, %d0
    rts

| d5 = a head on its neck. Returns d0.w = 1.
dmon_ghead:
    movem.l %d1-%d4/%d6/%a0-%a1, -(%sp)
    tst.b OFF_INV_CLOCK(%a5)
    bne 40f
    moveq #0, %d1
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d1
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #3, %d0
    cmp.w %d1, %d0
    bne 40f                             | one neck a frame
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 5f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 30f
5:  moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    lea OFF_ENEMY_TURN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 51f
    subq.w #2, %d2
51: addq.w #1, %d2
    lea OFF_ENEMY_DIST(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 52f
    subq.w #2, %d3
52: addq.w #1, %d3
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    lea OFF_ENEMY_BOUNCE(%a5), %a0
    addq.b #1, 0(%a0, %d5.w)
    cmpi.b #4, 0(%a0, %d5.w)
    blo 30f
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_ANIMC(%a5), %a0       | every four steps: count toward a turn
    addq.b #1, 0(%a0, %d5.w)
    cmpi.b #0x0c, 0(%a0, %d5.w)
    blo 53f
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_TURN(%a5), %a1
    not.b 0(%a1, %d5.w)
53: lea OFF_ENEMY_ANIMF(%a5), %a0
    addq.b #1, 0(%a0, %d5.w)
    cmpi.b #6, 0(%a0, %d5.w)
    blo 30f
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_DIST(%a5), %a1
    not.b 0(%a1, %d5.w)
30: bsr rand8_bf                        | and now and then it spits
    cmp.b #0x20, %d0
    bhs 40f
    bsr gleeok_fire
40: moveq #0, %d6                       | the neck: the base, and three segments that follow the line from body to head
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d6
    move.w %d6, %d1
    add.w %d1, %d1
    add.w %d6, %d1                      | the neck's first segment in GSEG_X/Y
    move.w %d6, %d4
    add.w %d4, %d4
    add.w %d6, %d4                      | 3 * neck
    moveq #1, %d3                       | the segment's number, 1 to 3
41: moveq #0, %d0
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0
    sub.w #GLEEOK_BODY_X, %d0
    muls.w %d3, %d0
    divs.w #3, %d0
    add.w #GLEEOK_BODY_X, %d0           | where the segment belongs
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    sub.w #GLEEOK_BODY_Y, %d1
    muls.w %d3, %d1
    divs.w #3, %d1
    add.w #GLEEOK_BODY_Y, %d1
    move.w %d4, %d2
    add.w %d3, %d2
    subq.w #1, %d2                      | its place in the arrays
    lea OFF_GSEG_X(%a5), %a0
    moveq #0, %d6
    move.b 0(%a0, %d2.w), %d6           | the segment drifts a pixel a frame toward it
    cmp.w %d0, %d6
    beq 42f
    blo 421f
    subq.w #2, %d6
421: addq.w #1, %d6
42: move.b %d6, 0(%a0, %d2.w)
    move.w %d6, %d0
    lea OFF_GSEG_Y(%a5), %a0
    moveq #0, %d6
    move.b 0(%a0, %d2.w), %d6
    cmp.w %d1, %d6
    beq 43f
    blo 431f
    subq.w #2, %d6
431: addq.w #1, %d6
43: move.b %d6, 0(%a0, %d2.w)
    move.w %d0, %d1                     | d1 = X, d2 = Y for the pool
    move.w %d6, %d2
    moveq #BP_SEGMENT, %d0
    bsr bp_add
    addq.w #1, %d3
    moveq #0, %d0
    move.b OFF_GLEEOK_SEGS(%a5), %d0
    cmp.w %d0, %d3
    blo 41b
    moveq #0, %d1                       | and the head itself, over its neck
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    moveq #BP_HEAD, %d0
    bsr bp_add
    movem.l (%sp)+, %d1-%d4/%d6/%a0-%a1
    moveq #1, %d0
    rts

| d5 = a head that has just lost its last hit point.
gleeok_head_died:
    movem.l %d0-%d2/%d6-%d7, -(%sp)
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    moveq #1, %d1
    lsl.b %d0, %d1
    or.b %d1, OFF_GLEEOK_DEAD(%a5)      | this neck is gone
    move.b #MON_GLEEOK_FLYER, OFF_ENEMY_TYPE(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b OFF_ENEMY_HP(%a5, %d5.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)      | at flying speed, deciding where to go
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #0xbf, 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    moveq #0, %d6                       | find the body, and how many necks it had
    moveq #-1, %d7
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d6
    bhs 3f
    move.b OFF_ENEMY_TYPE(%a5, %d6.w), %d0
    cmp.b #MON_GLEEOK2, %d0
    blo 2f
    cmp.b #MON_GLEEOK4, %d0
    bhi 2f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d6.w)
    beq 2f
    move.w %d6, %d7
    sub.b #MON_GLEEOK2, %d0
    addq.b #2, %d0                      | the necks
    moveq #1, %d1
    lsl.b %d0, %d1
    subq.b #1, %d1                      | the mask of them all
    cmp.b OFF_GLEEOK_DEAD(%a5), %d1
    bne 3f
    move.w %d5, -(%sp)                  | the last neck: the body dies
    move.w %d6, %d5
    bsr kill_enemy_bf
    move.w (%sp)+, %d5
    bra 3f
2:  addq.w #1, %d6
    bra 1b
3:  movem.l (%sp)+, %d0-%d2/%d6-%d7
    rts

| d5 = the body, dead: the heads (flying or not) go with it.
gleeok_died:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d0
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d0
    bhs 9f
    move.b OFF_ENEMY_TYPE(%a5, %d0.w), %d1
    cmp.b #MON_GLEEOK_HEAD, %d1
    beq 2f
    cmp.b #MON_GLEEOK_FLYER, %d1
    bne 3f
2:  clr.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
3:  addq.w #1, %d0
    bra 1b
9:  clr.b OFF_BP_COUNT(%a5)
    clr.b OFF_GLEEOK_DEAD(%a5)
    move.b OFF_ROOM_ID(%a5), %d0        | the room is drawn again without the body
    or.b #0x80, %d0
    move.b %d0, OFF_GLEEOK_GONE(%a5)
    bsr uw_redraw_room_bf
    movem.l (%sp)+, %d0-%d1
    rts

| d5 = a flying head.
dmon_gflyer:
    bsr keese_ai_bf
    movem.l %d0, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    bne 1f
    bsr rand8_bf
    cmp.b #0x20, %d0
    bhs 1f
    bsr gleeok_fire
1:  movem.l (%sp)+, %d0
    moveq #1, %d0
    rts

| ------------------------------------------------------------------ Lanmola
| UpdateLamnola. Two worms of four segments (the ROM has ten, in two worms of five). Every segment starts at
| ($40, $8D); only the heads (slots 3 and 7 of the worm's four) have a heading, and the others get theirs as the
| head's go down the body, one step each time it has gone eight pixels, so the worm uncoils. A segment moves
| one pixel a frame (the blue Lanmola) or two (the red) along its heading, ENEMY_DIR, which is 0 until it is told.
| At a square of the 16-pixel grid the head chooses: half the time it turns toward Link (sideways if Link
| faces that way, else up or down), else it keeps on or turns to one side, 75% of the time to up or left;
| a way that is shut turns it on to the next that is not back the way it came.
    .equ LANMOLA_START_X, 0x40
    .equ LANMOLA_START_Y, 0x8d

lanmola_init:
    movem.l %d0, -(%sp)
    move.b #LANMOLA_START_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #LANMOLA_START_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_DIR(%a5, %d5.w)
    move.w %d5, %d0
    and.w #3, %d0
    cmp.w #3, %d0
    bne 9f
    move.b #DIR_UP, OFF_ENEMY_DIR(%a5, %d5.w)
9:  movem.l (%sp)+, %d0
    rts

| d5 = a segment. Returns d0.w = 1: the generic walking is not to run.
dmon_lanmola:
    movem.l %d1/%d4, -(%sp)
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    beq 90f                             | not told to go yet
    moveq #1, %d1
    cmpi.b #MON_LANMOLA_RED, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 1f
    moveq #2, %d1
1:  btst #0, %d4
    beq 2f
    add.b %d1, OFF_ENEMY_X(%a5, %d5.w)
2:  btst #1, %d4
    beq 3f
    sub.b %d1, OFF_ENEMY_X(%a5, %d5.w)
3:  btst #2, %d4
    beq 4f
    add.b %d1, OFF_ENEMY_Y(%a5, %d5.w)
4:  btst #3, %d4
    beq 5f
    sub.b %d1, OFF_ENEMY_Y(%a5, %d5.w)
5:  move.w %d5, %d1
    and.w #3, %d1
    cmp.w #3, %d1
    bne 90f
    bsr lanmola_head
90: movem.l (%sp)+, %d1/%d4
    moveq #1, %d0
    rts

| The head, d5, has moved: pass the headings down the body at every eight pixels, and choose a new one at a square.
lanmola_head:
    movem.l %d0-%d7/%a0, -(%sp)
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.w %d2, %d0
    and.w #7, %d0
    bne 99f
    move.w %d3, %d0
    addq.w #3, %d0
    and.w #7, %d0
    bne 99f
    move.w %d5, %d1
    and.w #0xfc, %d1                    | the worm's lowest slot
    lea OFF_ENEMY_DIR(%a5), %a0
    moveq #2, %d0
1:  move.b 1(%a0, %d1.w), 0(%a0, %d1.w)
    addq.w #1, %d1
    dbra %d0, 1b
    move.w %d2, %d0
    and.w #15, %d0
    bne 99f
    move.w %d3, %d0
    addq.w #3, %d0
    and.w #15, %d0
    bne 99f
    moveq #0, %d1
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d1   | d1 = the heading it has
    move.w %d1, %d6
    bsr opposite_dir_bf
    not.w %d6
    and.w #15, %d6
    move.w %d6, %d4                     | d4 = the headings it may take: not straight back
    bsr rand8_bf
    cmp.b #0x80, %d0
    bhs 20f
    moveq #1, %d6                       | toward Link: right or left ...
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    cmp.w %d2, %d0
    bhs 11f
    moveq #2, %d6
11: moveq #4, %d7                       | ... and down or up
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    cmp.w %d3, %d0
    bhs 12f
    moveq #8, %d7
12: move.w %d6, %d0
    and.w %d4, %d0
    beq 13f                             | sideways is the way it came: go up or down
    move.b OFF_LINK_DIR(%a5), %d0
    and.b %d6, %d0
    bne 40f                             | Link faces that way: sideways
13: move.w %d7, %d6
    bra 40f
20: move.w %d1, %d6                     | a random turn: keep on, or one of the two sides
    bsr rand8_bf
    move.w %d0, %d7
    cmp.b #0x80, %d7
    bhs 40f
21: lsr.b #1, %d6
    bcc 22f
    moveq #8, %d6
22: move.w %d6, %d0
    and.w %d4, %d0
    beq 21b
    cmp.b #0x40, %d7
    bhs 40f
    moveq #0x40, %d7
    bra 21b
40: moveq #3, %d7                       | the way chosen; while it is shut, the next one that is not back
41: move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr enemy_cell_blocked_bf
    tst.w %d0
    beq 99f
42: lsr.b #1, %d6
    bcc 43f
    moveq #8, %d6
43: move.w %d6, %d0
    and.w %d4, %d0
    beq 42b
    dbra %d7, 41b
99: movem.l (%sp)+, %d0-%d7/%a0
    rts

| ------------------------------------------------------- the rupee stash and Grumble
| Things a dungeon room has that are not monsters. The ten rupees (InitRupeeStash: a pyramid, taken one at a time
| by walking over them, and once one is taken the stash is gone for good) are painted into the room like Gleeok's
| body, and the room is drawn again without a rupee that Link has taken (STASH_MASK says which are left). Grumble
| (InitGrumble) stands at ($78, $80) as a moblin the room draws, blocks Link (link_collide) and eats the food that
| is put down beside him; then he goes, for good (room flag bit 1).
    .equ STASH_COUNT, 10
    .equ GRUMBLE_X, 0x78
    .equ GRUMBLE_Y, 0x80
    .equ GRUMBLE_REACH, 0x10
stash_x:
    .byte 0x78, 0x70, 0x80, 0x60, 0x70, 0x80, 0x90, 0x70, 0x80, 0x78
stash_y:
    .byte 0x70, 0x80, 0x80, 0x90, 0x90, 0x90, 0x90, 0xa0, 0xa0, 0xb0

| d0.b = room, a1 = its record (the room has just been entered): what is on its floor and who stands in it.
boss_room_init:
    movem.l %d0-%d2/%a0, -(%sp)
    clr.b OFF_GRUMBLE_ON(%a5)
    move.b 1(%a1), %d1
    lea OFF_UW_FLAGS(%a5), %a0
    btst #5, %d1
    beq 1f
    btst #1, 0(%a0, %d0.w)
    bne 1f                              | he has been fed
    move.b #1, OFF_GRUMBLE_ON(%a5)
1:  btst #6, %d1
    beq 9f
    move.b %d0, %d2
    or.b #0x80, %d2
    cmp.b OFF_STASH_ROOM(%a5), %d2
    beq 9f
    move.b %d2, OFF_STASH_ROOM(%a5)
    move.w #0x3ff, %d1
    btst #2, 0(%a0, %d0.w)
    beq 8f
    moveq #0, %d1                       | one was taken on an earlier visit: the rest are gone
8:  move.w %d1, OFF_STASH_MASK(%a5)
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| d0.w = a room: d1.w = the rupees of its stash that are on the floor.
stash_mask_for:
    movem.l %d2/%a0, -(%sp)
    move.b %d0, %d2
    or.b #0x80, %d2
    cmp.b OFF_STASH_ROOM(%a5), %d2
    bne 1f
    move.w OFF_STASH_MASK(%a5), %d1
    bra 9f
1:  move.w #0x3ff, %d1
    lea OFF_UW_FLAGS(%a5), %a0
    btst #2, 0(%a0, %d0.w)
    beq 9f
    moveq #0, %d1
9:  movem.l (%sp)+, %d2/%a0
    rts

| d0.w = room, a1 = the buffer it has just been drawn into: its rupees.
stash_bake:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    movea.l %a1, %a3
    bsr stash_mask_for
    move.w %d1, %d7
    ltab item_index, %a0
    moveq #0, %d0
    move.b ITEM_RUPEE(%a0), %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab item_sprites, %a2
    adda.l %d0, %a2
    moveq #0, %d6
1:  btst %d6, %d7
    beq 2f
    lea stash_x(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d6.w), %d1
    lea stash_y(%pc), %a0
    moveq #0, %d2
    move.b 0(%a0, %d6.w), %d2
    bsr sprite_offset_bf
    tst.w %d4
    bmi 2f
    movea.l %a3, %a1
    adda.l %d1, %a1
    movea.l %a2, %a0
    move.w %d4, %d0
    bsr draw_sprite_bf
2:  addq.w #1, %d6
    cmp.w #STASH_COUNT, %d6
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| d0.w = room, a1 = the buffer it has just been drawn into: Grumble, unless he has been fed.
grumble_bake:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    lea OFF_UW_FLAGS(%a5), %a0
    btst #1, 0(%a0, %d0.w)
    bne 9f
    movea.l %a1, %a3
    moveq #MON_MOBLIN, %d0
    add.w %d0, %d0
    bsr mon_art_ptr_bf
    moveq #0, %d7
    move.w 0(%a0, %d0.w), %d7
    addq.w #4, %d7                      | the moblin facing down: image 2, the plain copy
    mulu.w #SPRITE_FRAME_BYTES, %d7
    movea.l OFF_MON_SPR(%a5), %a2
    adda.l %d7, %a2
    moveq #0, %d1
    move.w #GRUMBLE_X, %d1
    moveq #0, %d2
    move.w #GRUMBLE_Y, %d2
    bsr sprite_offset_bf
    tst.w %d4
    bmi 9f
    movea.l %a3, %a1
    adda.l %d1, %a1
    movea.l %a2, %a0
    move.w %d4, %d0
    bsr draw_sprite_bf
9:  movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| Once a frame: Link on a rupee takes it, the food beside Grumble is eaten.
boss_misc_update:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    tst.b OFF_GRUMBLE_ON(%a5)
    beq 5f
    cmpi.b #ITEM_FOOD_STATE, (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
    bne 5f
    moveq #0, %d1
    move.b (OFF_ITEM_X + FOOD_SLOT)(%a5), %d1
    sub.w #GRUMBLE_X, %d1
    bpl 1f
    neg.w %d1
1:  cmp.w #GRUMBLE_REACH, %d1
    bhi 5f
    moveq #0, %d1
    move.b (OFF_ITEM_Y + FOOD_SLOT)(%a5), %d1
    sub.w #GRUMBLE_Y, %d1
    bpl 2f
    neg.w %d1
2:  cmp.w #GRUMBLE_REACH, %d1
    bhi 5f
    clr.b OFF_FOOD_TIMER(%a5)           | he eats it: the food is gone, and so is he
    clr.b (OFF_ITEM_ACTIVE + FOOD_SLOT)(%a5)
    clr.b OFF_INV_FOOD(%a5)
    clr.b OFF_GRUMBLE_ON(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    lea OFF_UW_FLAGS(%a5), %a0
    bset #1, 0(%a0, %d0.w)
    sfx SFX_SECRET
    bsr uw_redraw_room_bf
    bra 9f
5:  move.b %d0, %d2
    or.b #0x80, %d2
    cmp.b OFF_STASH_ROOM(%a5), %d2
    bne 9f
    move.w OFF_STASH_MASK(%a5), %d7
    beq 9f
    moveq #0, %d6
6:  btst %d6, %d7
    beq 8f
    lea stash_x(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d6.w), %d1
    moveq #0, %d3
    move.b OFF_LINK_X(%a5), %d3
    sub.w %d1, %d3
    bpl 61f
    neg.w %d3
61: cmp.w #9, %d3
    bhs 8f
    lea stash_y(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d6.w), %d1
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    sub.w %d1, %d3
    bpl 62f
    neg.w %d3
62: cmp.w #9, %d3
    bhs 8f
    bclr %d6, %d7                       | Link has it
    move.w %d7, OFF_STASH_MASK(%a5)
    lea OFF_UW_FLAGS(%a5), %a0
    bset #2, 0(%a0, %d0.w)
    moveq #ITEM_RUPEE, %d0
    bsr take_item_bf
    bsr uw_redraw_room_bf
    bra 9f
8:  addq.w #1, %d6
    cmp.w #STASH_COUNT, %d6
    blo 6b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts
