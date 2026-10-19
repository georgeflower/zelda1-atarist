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
    farstub music_play_bf, music_play

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
