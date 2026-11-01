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
    farstub credits_begin_bf, credits_begin
    farstub mon_art_ptr_bf, mon_art_ptr
    farstub sprite_offset_bf, sprite_offset
    farstub draw_sprite_bf, draw_sprite
    farstub music_play_bf, music_play
    farstub uw_redraw_room_bf, uw_redraw_room
    farstub take_item_bf, take_item
    farstub enemy_cell_blocked_bf, enemy_cell_blocked
    farstub opposite_dir_bf, opposite_dir
    farstub keese_turn_to_link_bf, keese_turn_to_link
    farstub keese_turn_random_bf, keese_turn_random
    farstub flyer_bound_bf, flyer_bound
    farstub uw_light_room_bf, uw_light_room
    farstub cave_talk_bf, cave_talk
    farstub curtain_column_bf, curtain_column
    farstub cur_palette_bf, cur_palette
    farstub draw_hud_tile_bf, draw_hud_tile
    farstub music_event_bf, music_event
    farstub fireball_aim_xy_bf, fireball_aim_xy
    farstub uw_open_shutters_bf, uw_open_shutters
    farstub uw_render_map_bf, uw_render_map
    farstub show_background_bf, show_background
    farstub fx_put_a0_bf, fx_put_a0
    farstub rock_update_bf, rock_update
    farstub rock_draw_bf, rock_draw
    farstub fireball_spawn_xy_bf, fireball_spawn_xy
    farstub enemy_behaviour_bf, enemy_behaviour

| ---------------------------------------------------------------- the bosses' voices (DPCM samples)
| A boss has been placed in its room: its roar (the Init routines' SampleRequest). d5 = monster. Keeps every
| register. The ambient roar of the rooms around the boss is music_roar_tick's.
spawn_roar:
    movem.l %d0-%d1/%a0, -(%sp)
    bsr enemy_behaviour_bf
    moveq #SMP_ROAR_BIG, %d1
    cmp.w #BEH_BOSS, %d0                | Aquamentus
    beq 1f
    cmp.w #BEH_GLEEOK, %d0
    beq 1f
    moveq #SMP_ROAR_LOW, %d1
    cmp.w #BEH_DODONGO, %d0
    beq 1f
    cmp.w #BEH_GOHMA, %d0
    beq 1f
    moveq #SMP_ROAR_WAIL, %d1
    cmp.w #BEH_MANHANDLA, %d0
    beq 1f
    cmp.w #BEH_DIGDOGGER, %d0
    beq 1f
    cmp.w #BEH_PATRA, %d0
    beq 1f
    moveq #SMP_BOSS_HIT, %d1            | Ganon's shout (InitGanon asks for the boss-hit sample)
    cmp.w #BEH_GANON, %d0
    bne 9f
1:  move.l %d1, %d0
    bsr music_play_bf
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| Enemy d5 has taken a hit: the bosses that cry out when they are struck (PlayBossHitCryIfNeeded) do so with
| the boss-hit sample. The same sample is the death cry of the rest (PlayBossDeathCry), see boss_death_cry.
boss_hit_cry:
    movem.l %d0/%a0, -(%sp)
    bsr enemy_behaviour_bf
    cmp.w #BEH_BOSS, %d0                | Aquamentus
    beq 1f
    cmp.w #BEH_MANHANDLA, %d0
    beq 1f
    cmp.w #BEH_GOHMA, %d0
    beq 1f
    cmp.w #BEH_GLEEOK_HEAD, %d0
    beq 1f
    cmp.w #BEH_PATRA, %d0
    beq 1f
    cmp.w #BEH_GANON, %d0
    bne 9f
1:  sfx SMP_BOSS_HIT
9:  movem.l (%sp)+, %d0/%a0
    rts

| The Dodongo and Digdogger cry only when they die (UpdateDodongoState1_Bloated_Sub_Die, L_Digdogger_AfterFlute);
| the others cried with the blow that killed them.
boss_death_cry:
    movem.l %d0/%a0, -(%sp)
    bsr enemy_behaviour_bf
    cmp.w #BEH_DODONGO, %d0
    beq 1f
    cmp.w #BEH_DIGDOGGER, %d0
    bne 9f
1:  sfx SMP_BOSS_HIT
9:  movem.l (%sp)+, %d0/%a0
    rts

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
| d5 = monster. Returns d0.w = 1: it has moved itself, the caller does not move it.
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
    moveq #1, %d0                       | it has moved itself (a 0 would let the walkers' step push it on as well)
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
    move.b #0x80, OFF_ENEMY_X(%a5, %d5.w)   | InitGohma: it starts at ($80, $70) whatever the room list says
    move.b #0x70, OFF_ENEMY_Y(%a5, %d5.w)
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
    .equ BP_GANON, 0x40                 | pool pictures from here are Ganon's (his art's frames)
    .equ BP_ITEM, 0xc0                  | and from here an item's: the number less BP_ITEM is the index in item_sprites
    .equ BP_HEAD, 13
    .equ BP_PRE_FRAME, 28               | the art's first pre-shifted frame (after 14 images of two frames)
bp_paint:
    movem.l %d0/%d2/%d3/%d5-%d7/%a0-%a3, -(%sp)
    movea.l %a1, %a3
    move.w %d0, %d5
    move.w %d1, %d3
    move.w %d2, %d6
    cmp.w #BP_ITEM, %d5
    blo 8f
    sub.w #BP_ITEM, %d5                 | an item's picture: the pond fairy's hearts
    moveq #0, %d1
    move.w %d3, %d1
    moveq #0, %d2
    move.w %d6, %d2
    bsr sprite_offset_bf
    tst.w %d4
    bmi 9f
    movea.l %a3, %a1
    adda.l %d1, %a1
    mulu.w #SPRITE_FRAME_BYTES, %d5
    ltab item_sprites, %a0
    adda.l %d5, %a0
    move.w %d4, %d0
    bsr draw_sprite_bf
    bra 9f
8:  moveq #MON_GLEEOK2, %d0
    cmp.w #BP_GANON, %d5
    blo 0f
    moveq #MON_GANON, %d0               | pieces from BP_GANON up are Ganon's: the frame is the number less BP_GANON
0:  add.w %d0, %d0
    bsr mon_art_ptr_bf
    moveq #0, %d7
    move.w 0(%a0, %d0.w), %d7           | the art's first frame
    cmp.w #BP_GANON, %d5
    blo 2f
    sub.w #BP_GANON, %d5
    add.w %d5, %d7
    moveq #0, %d5                       | and from here on it is a plain piece
2:
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

| ------------------------------------------------------------------ Patra
| UpdatePatra and its children. The eye starts at ($80, $70) facing up, speeds up from $1F to $40 (a quarter of a
| pixel a frame), then chooses again and again (Flyer_PatraDecideState: chase Link, or wander, eight turns of $10
| frames each; ENEMY_STATE is the flying state 0 speed up, 1 decide, 2 chase, 3 wander). Round it fly the children,
| each at a whole angle of 32 to the circle (ENEMY_STEP) and a fraction (ENEMY_FRAC), going round at $70 / 256 of a
| step a frame (the second kind $60). They come out at the top one at a time, each when the first has gone another
| eighth of the way round. The ROM has eight; this port has seven (eight monster slots), so one place stays empty.
| The orbit is the original's integrated circle written as a position: X = eye X + RX cos a, Y = eye Y + RY sin a.
| The radii are $2C and $2C (or $2C and $16 in the second maneuver) for the first kind of child, $18 and $18 (or $30
| and $30) for the second, and they glide to the new ones; the maneuver flips every $FF frames (the ROM's table has
| $50 for the second one but always reads the first). The eye is proof against everything but the sword, and
| against that while a child is left (dmon_hit_filter asks patra_kids).
    .equ PATRA_X, 0x80
    .equ PATRA_Y, 0x70
    .equ PATRA_SPEED_START, 0x1f
    .equ PATRA_SPEED_MAX, 0x40
    .equ PATRA_START_ANGLE, 0x18
    .equ PATRA_SPIN_1, 0x70
    .equ PATRA_SPIN_2, 0x60

patra_starts:
    .byte 0x14, 0x10, 0x0c, 0x08, 0x04, 0x00, 0x1c
patra_cos:
    .byte 127, 125, 117, 106, 90, 71, 49, 25, 0, -25, -49, -71, -90, -106, -117, -125
    .byte -127, -125, -117, -106, -90, -71, -49, -25, 0, 25, 49, 71, 90, 106, 117, 125
    .align 2

patra_init:
    movem.l %d0/%a0, -(%sp)
    move.b #PATRA_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #PATRA_Y, OFF_ENEMY_Y(%a5, %d5.w)
    move.b #DIR_UP, OFF_ENEMY_DIR(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_SPEED(%a5), %a0
    move.b #PATRA_SPEED_START, 0(%a0, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    clr.b OFF_PATRA_MAN(%a5)
    move.b #0xff, OFF_PATRA_MTIMER(%a5)
    moveq #0x2c, %d0
    cmpi.b #MON_PATRA_EYE, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq 1f
    moveq #0x18, %d0
1:  move.b %d0, OFF_PATRA_RX(%a5)
    move.b %d0, OFF_PATRA_RY(%a5)
    movem.l (%sp)+, %d0/%a0
    rts

pchild_init:
    movem.l %a0, -(%sp)
    move.b #PATRA_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #PATRA_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)       | waiting to come out; it is neither seen nor felt until it has
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_FRAC(%a5), %a0
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    movem.l (%sp)+, %a0
    rts

| Returns d2.w = how many children are left.
patra_kids:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d2
    moveq #1, %d0
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d0
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d0.w)
    beq 2f
    move.b OFF_ENEMY_TYPE(%a5, %d0.w), %d1
    cmp.b #MON_PATRA_CHILD, %d1
    beq 3f
    cmp.b #MON_PATRA_CHILD2, %d1
    bne 2f
3:  addq.w #1, %d2
2:  addq.w #1, %d0
    bra 1b
9:  movem.l (%sp)+, %d0-%d1
    rts

| d0.b = a radius, d2.b = the one it is going to: a step towards it.
patra_glide:
    cmp.b %d2, %d0
    beq 9f
    blo 1f
    subq.b #1, %d0
    rts
1:  addq.b #1, %d0
9:  rts

| d5 = the eye. Returns d0.w = 1: it moves itself.
dmon_patra:
    movem.l %d1-%d4/%a0-%a1, -(%sp)
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
    bra 40f
10: addq.b #1, 0(%a0, %d5.w)                | Flyer_SpeedUp
    cmpi.b #PATRA_SPEED_MAX, 0(%a0, %d5.w)
    blo 60f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
20: bsr rand8_bf                            | Flyer_PatraDecideState
    moveq #2, %d1
    cmp.b #0x40, %d0
    bhs 21f
    moveq #3, %d1
21: move.b %d1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #8, OFF_ENEMY_STEP(%a5, %d5.w)
    bra 60f
30: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 60f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 31f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
31: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr keese_turn_to_link_bf
    bra 60f
40: tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 60f
    subq.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    bne 41f
    move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bra 60f
41: move.b #0x10, OFF_ENEMY_TIMER(%a5, %d5.w)
    bsr keese_turn_random_bf
60: moveq #0, %d1                           | MoveFlyer: a pixel whenever the speed fills the fraction
    move.b 0(%a0, %d5.w), %d1
    and.b #0xe0, %d1
    moveq #0, %d2
    move.b 0(%a1, %d5.w), %d2
    add.w %d1, %d2
    move.b %d2, 0(%a1, %d5.w)
    cmp.w #0x100, %d2
    blo 70f
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
    bsr flyer_bound_bf
70: tst.b OFF_PATRA_MTIMER(%a5)             | the maneuver
    beq 71f
    subq.b #1, OFF_PATRA_MTIMER(%a5)
    bra 72f
71: eori.b #1, OFF_PATRA_MAN(%a5)
    move.b #0xff, OFF_PATRA_MTIMER(%a5)
72: move.b OFF_PATRA_MAN(%a5), %d1
    cmpi.b #MON_PATRA_EYE, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 74f
    moveq #0x2c, %d2                        | the first kind of child: wide, and round or squashed
    moveq #0x2c, %d3
    tst.b %d1
    beq 76f
    moveq #0x16, %d3
    bra 76f
74: moveq #0x18, %d2                        | the second: a small circle or a large one
    tst.b %d1
    beq 75f
    moveq #0x30, %d2
75: move.w %d2, %d3
76: move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #3, %d0
    bne 99f
    move.b OFF_PATRA_RX(%a5), %d0
    bsr patra_glide
    move.b %d0, OFF_PATRA_RX(%a5)
    move.b OFF_PATRA_RY(%a5), %d0
    move.b %d3, %d2
    bsr patra_glide
    move.b %d0, OFF_PATRA_RY(%a5)
99: movem.l (%sp)+, %d1-%d4/%a0-%a1
    moveq #1, %d0
    rts

| d5 = a child. Returns d0.w = 1.
dmon_pchild:
    movem.l %d1-%d4/%a0, -(%sp)
    lea OFF_ENEMY_FRAC(%a5), %a0
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 20f
    cmp.w #1, %d5
    beq 10f                                 | the first one comes out at once
    tst.b OFF_ENEMY_ACTIVE+1(%a5)
    beq 10f                                 | (the first is dead: nothing to wait for)
    tst.b OFF_ENEMY_STATE+1(%a5)
    beq 99f                                 | the first is not out yet
    move.w %d5, %d1
    subq.w #2, %d1
    lea patra_starts(%pc), %a1
    move.b OFF_ENEMY_STEP+1(%a5), %d0
    cmp.b 0(%a1, %d1.w), %d0                | the first child is where this one is to appear after
    bne 99f
10: move.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #PATRA_START_ANGLE, OFF_ENEMY_STEP(%a5, %d5.w)
    clr.b 0(%a0, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a1
    clr.b 0(%a1, %d5.w)
20: moveq #0, %d0                           | the angle goes down by the child's rate, a whole 32 to the circle
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    lsl.w #8, %d0
    move.b 0(%a0, %d5.w), %d0
    move.w #PATRA_SPIN_1, %d1
    cmpi.b #MON_PATRA_CHILD, OFF_ENEMY_TYPE(%a5, %d5.w)
    beq 21f
    move.w #PATRA_SPIN_2, %d1
21: sub.w %d1, %d0
    and.w #0x1fff, %d0
    move.b %d0, 0(%a0, %d5.w)
    lsr.w #8, %d0
    move.b %d0, OFF_ENEMY_STEP(%a5, %d5.w)
    lea patra_cos(%pc), %a1
    moveq #0, %d2
    move.b OFF_PATRA_RX(%a5), %d2
    move.b 0(%a1, %d0.w), %d3               | cos of the angle
    ext.w %d3
    muls.w %d2, %d3
    asr.w #7, %d3
    moveq #0, %d4
    move.b OFF_ENEMY_X(%a5), %d4            | the eye is the first monster
    add.w %d4, %d3
    cmp.w #0x10, %d3
    bge 22f
    moveq #0x10, %d3
22: cmp.w #0xe0, %d3
    ble 23f
    move.w #0xe0, %d3
23: move.b %d3, OFF_ENEMY_X(%a5, %d5.w)
    sub.w #8, %d0                           | the sine is the cosine a quarter turn back
    and.w #31, %d0
    moveq #0, %d2
    move.b OFF_PATRA_RY(%a5), %d2
    move.b 0(%a1, %d0.w), %d3
    ext.w %d3
    muls.w %d2, %d3
    asr.w #7, %d3
    moveq #0, %d4
    move.b OFF_ENEMY_Y(%a5), %d4
    add.w %d4, %d3
    cmp.w #0x50, %d3
    bge 24f
    moveq #0x50, %d3
24: cmp.w #0xc8, %d3
    ble 25f
    move.w #0xc8, %d3
25: move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
99: movem.l (%sp)+, %d1-%d4/%a0
    moveq #1, %d0
    rts

| ------------------------------------------------------------------ Ganon
| UpdateGanon. Ganon is a 32x32 body of four pictures, drawn from the boss sprite pool; the monster itself is the 16x16
| box in the middle of it (ENEMY_X/Y = the body's X and Y plus 8), the one Link's sword and Link himself meet.
| The scene (GANON_SCENE): 1 the room is dark for $40 frames and Link waits, 2 the light comes on and he holds up the
| Triforce of Courage for $C0 frames while Ganon stands there, 0 the fight. In the fight Ganon is invisible, walks
| a pixel every other frame like a blue wizzrobe (turning toward Link every $40 frames) and throws a fireball every $40.
| A sword blow that finds him shows him for $40 frames (ENEMY_TIMER), during which nothing hurts him, and then he
| reappears at ($30 or $B0, $A0). When the sword has used up his hit points he turns brown for $FF steps of two frames
| (ENEMY_STATE counts down), standing still, and only the silver arrow hurts him: it sets him burning (ENEMY_STEP counts
| the phases up), at phase $50 he is a pile of ashes, at $A0 the Triforce of Power lies where they are. If the
| brown runs out he is blue again. ENEMY_ANIMF is his picture (0 to 5), cycling every frame while he is hidden so that a
| blow shows him in a random pose.
    .equ GANON_X, 0x70
    .equ GANON_Y, 0x5d
    .equ GANON_SEEN_FRAMES, 0x40
    .equ GANON_BROWN_TIME, 0xff
    .equ GANON_HP_AGAIN, 15
    .equ GANON_MIN_X, 0x28
    .equ GANON_MAX_X, 0xc0
    .equ GANON_MIN_Y, 0x60
    .equ GANON_MAX_Y, 0xb0
    .equ GANON_BROWN_IMAGES, 10
    .equ GANON_ASHES_FRAME, 40

ganon_images:                           | GanonFrameImages: four pictures for each of the six frames
    .byte 6, 8, 7, 9,  0, 0, 1, 1,  2, 2, 3, 3,  4, 0, 5, 1,  4, 4, 5, 5,  0, 4, 1, 5
ganon_part_dx:
    .byte 0, 16, 0, 16
ganon_part_dy:
    .byte 0, 0, 16, 16
ganon_start_x:
    .byte 0x30, 0xb0

ganon_init:
    movem.l %d0/%a0, -(%sp)
    move.b #(GANON_X + 8), OFF_ENEMY_X(%a5, %d5.w)
    move.b #(GANON_Y + 8), OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    clr.b OFF_ENEMY_TIMER(%a5, %d5.w)
    clr.b OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    clr.b 0(%a0, %d5.w)
    move.b #DIR_LEFT, OFF_ENEMY_DIR(%a5, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    move.b #1, OFF_GANON_SCENE(%a5)
    move.b #0x40, OFF_GANON_TIMER(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    movem.l (%sp)+, %d0/%a0
    rts

| d5 = Ganon, d1 = the weapon. Returns d2.w = 0 when the blow counts (a silver arrow also gets its killing weight).
ganon_filter:
    moveq #1, %d2
    tst.b OFF_GANON_SCENE(%a5)
    bne 9f
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 9f
    cmp.b #HIT_SWORD, %d1
    bne 1f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 9f                              | brown: the sword does nothing
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 9f                              | showing himself: nothing does
    moveq #0, %d2
    rts
1:  cmp.b #HIT_ARROW, %d1
    bne 9f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    beq 9f
    cmpi.b #2, OFF_INV_ARROW(%a5)
    bne 9f                              | only the silver arrow
    move.b #0xff, OFF_HIT_DAMAGE(%a5)
    moveq #0, %d2
9:  rts

| A sword blow that left him alive: he is seen for a while.
ganon_hit:
    move.b #GANON_SEEN_FRAMES, OFF_ENEMY_TIMER(%a5, %d5.w)
    rts

| He has no hit points left. The sword makes him brown (and gives him new ones for the next time); the arrow
| sets him burning.
ganon_died:
    movem.l %a0, -(%sp)
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 1f
    move.b #GANON_HP_AGAIN, OFF_ENEMY_HP(%a5, %d5.w)
    move.b #GANON_BROWN_TIME, OFF_ENEMY_STATE(%a5, %d5.w)
    move.b #GANON_SEEN_FRAMES, OFF_ENEMY_TIMER(%a5, %d5.w)
    bra 9f
1:  move.b #1, OFF_ENEMY_STEP(%a5, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
9:  movem.l (%sp)+, %a0
    rts

| Ganon_RandomizeLocation.
ganon_relocate:
    movem.l %d0/%a0, -(%sp)
    move.b #(0xa0 + 8), OFF_ENEMY_Y(%a5, %d5.w)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #1, %d0
    lea ganon_start_x(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    add.b #8, %d0
    move.b %d0, OFF_ENEMY_X(%a5, %d5.w)
    movem.l (%sp)+, %d0/%a0
    rts

| d5 = Ganon. The fight: hidden, he walks and shoots; brown, he waits. Returns d0.w = 1.
dmon_ganon:
    movem.l %d1-%d4/%a0, -(%sp)
    tst.b OFF_GANON_SCENE(%a5)
    bne 99f
    tst.b OFF_ENEMY_STEP(%a5, %d5.w)
    bne 99f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    bne 50f
    tst.b OFF_ENEMY_TIMER(%a5, %d5.w)
    beq 10f
    subq.b #1, OFF_ENEMY_TIMER(%a5, %d5.w)
    bne 99f
    bsr ganon_relocate                  | the time he was shown is over: he is somewhere else
    bra 99f
10: lea OFF_ENEMY_ANIMF(%a5), %a0       | a new picture every frame, six in a cycle
    move.b 0(%a0, %d5.w), %d0
    addq.b #1, %d0
    cmp.b #6, %d0
    blo 11f
    moveq #0, %d0
11: move.b %d0, 0(%a0, %d5.w)
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #0x3f, %d0
    bne 20f
    bsr ganon_turn                      | every $40 frames: turn toward Link, and fire
    bsr zora_fire_bf
20: move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    bne 99f
    moveq #0, %d2                       | a pixel every other frame
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
24: cmp.w #GANON_MIN_X, %d2             | the room's walls turn him round
    bhs 25f
    move.w #GANON_MIN_X, %d2
    move.b #DIR_RIGHT, %d4
25: cmp.w #GANON_MAX_X, %d2
    bls 26f
    move.w #GANON_MAX_X, %d2
    move.b #DIR_LEFT, %d4
26: cmp.w #GANON_MIN_Y, %d3
    bhs 27f
    move.w #GANON_MIN_Y, %d3
    move.b #DIR_DOWN, %d4
27: cmp.w #GANON_MAX_Y, %d3
    bls 28f
    move.w #GANON_MAX_Y, %d3
    move.b #DIR_UP, %d4
28: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
    bra 99f
50: move.w OFF_FRAME_COUNTER(%a5), %d0  | brown: the count runs down every other frame
    btst #0, %d0
    beq 99f
    subq.b #1, OFF_ENEMY_STATE(%a5, %d5.w)
    bne 99f
    bsr ganon_relocate                  | blue again, and hidden
99: movem.l (%sp)+, %d1-%d4/%a0
    moveq #1, %d0
    rts

| Face Link along the longer of the two ways.
ganon_turn:
    movem.l %d0-%d3, -(%sp)
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    sub.w %d1, %d0                      | + : Link is to the right
    moveq #0, %d2
    move.b OFF_LINK_Y(%a5), %d2
    moveq #0, %d1
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d1
    sub.w %d1, %d2                      | + : below
    move.w %d0, %d1
    bpl 1f
    neg.w %d1
1:  move.w %d2, %d3
    bpl 2f
    neg.w %d3
2:  cmp.w %d3, %d1
    blo 4f
    moveq #DIR_RIGHT, %d1
    tst.w %d0
    bpl 3f
    moveq #DIR_LEFT, %d1
3:  bra 5f
4:  moveq #DIR_DOWN, %d1
    tst.w %d2
    bpl 5f
    moveq #DIR_UP, %d1
5:  move.b %d1, OFF_ENEMY_DIR(%a5, %d5.w)
    movem.l (%sp)+, %d0-%d3
    rts

| Every frame, from boss_misc_update (the monsters are not updated while Link is held): the scene, the burning, and
| Ganon's picture.
ganon_tick:
    movem.l %d0-%d7/%a0, -(%sp)
    cmpi.b #9, OFF_LEVEL(%a5)
    bne 99f
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 99f
    cmpi.b #MON_GANON, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 2f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    bne 3f
2:  addq.w #1, %d5
    bra 1b
3:  move.b OFF_GANON_SCENE(%a5), %d0
    beq 20f
    cmp.b #1, %d0
    bne 10f
    subq.b #1, OFF_GANON_TIMER(%a5)     | scene 1: dark and waiting
    bne 99f
    bsr uw_light_room_bf
    move.b #2, OFF_GANON_SCENE(%a5)
    move.b #0xc0, OFF_GANON_TIMER(%a5)
    moveq #MUS_GANON, %d0               | the first frame of the fade to light: the Triforce/Ganon song
    bsr music_event_bf
    sfx SFX_ITEM_APPEARS
    bra 99f
10: move.b #ITEM_TRIFORCE, (OFF_ITEM_ID + 1)(%a5)   | scene 2: the Triforce of Courage over Link's head
    move.b OFF_LINK_X(%a5), (OFF_ITEM_X + 1)(%a5)
    move.b OFF_LINK_Y(%a5), %d0
    sub.b #16, %d0
    move.b %d0, (OFF_ITEM_Y + 1)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + 1)(%a5)
    lea OFF_ENEMY_ANIMF(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bsr ganon_draw
    subq.b #1, OFF_GANON_TIMER(%a5)
    bne 99f
    clr.b OFF_GANON_SCENE(%a5)
    clr.b (OFF_ITEM_ACTIVE + 1)(%a5)
    clr.b OFF_LINK_HELD(%a5)
    lea OFF_ENEMY_GHOST(%a5), %a0
    clr.b 0(%a0, %d5.w)
    bra 99f
20: moveq #0, %d0                       | the fight; a burning Ganon goes through his phases
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    beq 30f
    addq.b #1, %d0
    bne 21f
    move.b #0xff, %d0
21: move.b %d0, OFF_ENEMY_STEP(%a5, %d5.w)
    cmp.b #0x50, %d0
    bne 22f
    bsr ganon_burst_begin               | Ganon_Dying at phase $50: the ashes, the burst, the cry and the song
22: cmp.b #0x50, %d0
    blo 23f
    cmp.b #0xa0, %d0
    bhs 23f
    bsr ganon_burst_move
23: cmp.b #0xa0, %d0
    bne 30f                             | (the ashes stay, the item lies on them)
    move.b OFF_ENEMY_X(%a5, %d5.w), %d0     | the Triforce of Power lies where the ashes are
    subq.b #1, %d0
    move.b %d0, OFF_ITEM_X(%a5)
    move.b OFF_ENEMY_Y(%a5, %d5.w), OFF_ITEM_Y(%a5)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)     | no monster to kill any more, but the ashes are still drawn
30: bsr ganon_draw
99: movem.l (%sp)+, %d0-%d7/%a0
    rts

| Ganon_Dying at phase $50 (d5 = Ganon): the ashes are where the clouds and the rays start, eight rays set off from
| (X + 4, Y + 4) of them, the eight clouds start 8 pixels out, and the boss-death cry and the Ganon song play.
ganon_burst_begin:
    movem.l %d0-%d3/%a0-%a1, -(%sp)
    move.b #8, OFF_GANON_CLOUD(%a5)
    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    subq.b #1, %d1                      | the ashes sit at (X - 1, Y) of the body's middle
    addq.b #4, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    addq.b #4, %d2
    lea OFF_GANON_RAY_X(%a5), %a0
    lea OFF_GANON_RAY_Y(%a5), %a1
    moveq #7, %d3
1:  move.b %d1, 0(%a0, %d3.w)
    move.b %d2, 0(%a1, %d3.w)
    dbra %d3, 1b
    sfx SMP_BOSS_HIT                    | PlayBossDeathCry
    moveq #MUS_GANON, %d0
    bsr music_event_bf
    movem.l (%sp)+, %d0-%d3/%a0-%a1
    rts

ganon_ray_dirs:                         | GanonBurstDirs: right, left, down, down-right, down-left, up, up-right, up-left
    .byte 0x01, 0x02, 0x04, 0x05, 0x06, 0x08, 0x09, 0x0a

| Once a frame during the burst (d5 = Ganon): the clouds draw in by a pixel every eight frames, the rays move a pixel
| along their headings: the four straight ones (slots 2, 3, 4 and 7) every frame, the diagonals three frames in four, so
| the burst spreads in a rough circle.
ganon_burst_move:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d4
    tst.b OFF_GANON_CLOUD(%a5)
    beq 1f
    move.w %d4, %d0
    and.w #7, %d0
    bne 1f
    subq.b #1, OFF_GANON_CLOUD(%a5)
1:  lea ganon_ray_dirs(%pc), %a0
    lea OFF_GANON_RAY_X(%a5), %a1
    lea OFF_GANON_RAY_Y(%a5), %a2
    moveq #7, %d3
2:  cmp.w #3, %d3
    blo 3f                              | rays 3 to 6 (slots 5, 6, 8, 9) but the straight one at 5 (slot 7)
    cmp.w #5, %d3
    beq 3f
    move.w %d4, %d0
    and.w #3, %d0
    beq 9f                              | this diagonal rests this frame
3:  move.b 0(%a0, %d3.w), %d0
    btst #0, %d0
    beq 4f
    addq.b #1, 0(%a1, %d3.w)
4:  btst #1, %d0
    beq 5f
    subq.b #1, 0(%a1, %d3.w)
5:  btst #2, %d0
    beq 6f
    addq.b #1, 0(%a2, %d3.w)
6:  btst #3, %d0
    beq 9f
    subq.b #1, 0(%a2, %d3.w)
9:  dbra %d3, 2b
    movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| d5 = Ganon, burning at phase $50 to $9F: the eight clouds round the ashes and the eight rays, into the boss pool.
ganon_burst_draw:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    moveq #0, %d6
    move.b OFF_GANON_CLOUD(%a5), %d6    | how far out the clouds are
    moveq #0, %d4
    move.b OFF_ENEMY_X(%a5, %d5.w), %d4
    subq.w #1, %d4                      | the ashes' X
    moveq #0, %d5
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d5 | and Y (d5 is Ganon no more)
    move.w #(BP_GANON + 42), %d7        | the medium cloud, the low one from distance 5 down
    cmp.w #6, %d6
    bhs 1f
    move.w #(BP_GANON + 44), %d7
1:  lea ganon_cloud_dx(%pc), %a0
    moveq #7, %d3
2:  move.w %d4, %d1
    move.b 0(%a0, %d3.w), %d0           | -1, 0 or 1: which way out
    ext.w %d0
    muls.w %d6, %d0
    add.w %d0, %d1
    move.w %d5, %d2
    move.b 8(%a0, %d3.w), %d0
    ext.w %d0
    muls.w %d6, %d0
    add.w %d0, %d2
    move.w %d7, %d0
    bsr bp_add
    dbra %d3, 2b
    move.w OFF_FRAME_COUNTER(%a5), %d7
    and.w #3, %d7                       | the flash: a palette row a frame
    lea OFF_GANON_RAY_X(%a5), %a1
    lea OFF_GANON_RAY_Y(%a5), %a2
    moveq #7, %d3
3:  moveq #0, %d1
    move.b 0(%a1, %d3.w), %d1
    moveq #0, %d2
    move.b 0(%a2, %d3.w), %d2
    move.w %d3, %d0
    lsl.w #3, %d0                       | 8 frames a ray
    move.w %d7, %d6
    add.w %d6, %d6
    add.w %d6, %d0                      | and 2 a palette row
    add.w #(BP_GANON + 46), %d0
    bsr bp_add
    dbra %d3, 3b
    movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

ganon_cloud_dx:                         | the four corners, the top and bottom, the left and right: dx then dy
    .byte -1, 1, -1, 1, 0, 0, -1, 1
    .byte -1, -1, 1, 1, -1, 1, 0, 0
    .even

| d5 = Ganon: his four pictures, or his ashes, into the boss pool.
ganon_draw:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #0, %d6                       | 0: blue pictures, 10: brown
    tst.b OFF_GANON_SCENE(%a5)
    bne 5f
    moveq #0, %d0
    move.b OFF_ENEMY_STEP(%a5, %d5.w), %d0
    beq 3f
    cmp.b #0x50, %d0                    | burning: brown and flashing, then ashes
    bhs 7f
    moveq #GANON_BROWN_IMAGES, %d6      | (Ganon_Dying draws him whole every frame: only the brown state flickers)
    bra 5f
3:  tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    beq 4f
    moveq #GANON_BROWN_IMAGES, %d6      | brown: whole above $30, flickering below
    cmpi.b #0x30, OFF_ENEMY_STATE(%a5, %d5.w)
    bhs 5f
    move.w OFF_FRAME_COUNTER(%a5), %d0
    btst #0, %d0
    beq 99f
    bra 5f
4:  tst.b OFF_ENEMY_TIMER(%a5, %d5.w)   | blue: seen only while he has just been struck
    beq 99f
5:  moveq #0, %d4
    lea OFF_ENEMY_ANIMF(%a5), %a0
    move.b 0(%a0, %d5.w), %d4
    lsl.w #2, %d4
    moveq #3, %d3
60: move.w %d3, %d7
    add.w %d4, %d7
    lea ganon_images(%pc), %a0
    moveq #0, %d0
    move.b 0(%a0, %d7.w), %d0
    add.w %d6, %d0
    add.w %d0, %d0                      | each picture is stored plain and then mirrored
    btst #0, %d3
    beq 61f
    addq.w #1, %d0                      | the right-hand pictures are the mirrored ones
61: add.w #BP_GANON, %d0
    lea ganon_part_dx(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d3.w), %d1
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    add.w %d2, %d1
    subq.w #8, %d1
    lea ganon_part_dy(%pc), %a0
    moveq #0, %d2
    move.b 0(%a0, %d3.w), %d2
    moveq #0, %d7
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d7
    add.w %d7, %d2
    subq.w #8, %d2
    bsr bp_add
    dbra %d3, 60b
    bra 99f
7:  moveq #0, %d1                       | the ashes, at (X + 7, Y + 8) of his body
    move.b OFF_ENEMY_X(%a5, %d5.w), %d1
    subq.w #1, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d2
    move.w #(BP_GANON + GANON_ASHES_FRAME), %d0
    bsr bp_add
    cmp.b #0xa0, OFF_ENEMY_STEP(%a5, %d5.w)
    bhs 99f
    bsr ganon_burst_draw                | the clouds and rays, for the 80 frames the phase takes to reach $A0
99: movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| ------------------------------------------------------------------------------ Zelda
| The last room of Level 9 (InitZelda, UpdateZelda, and mode $13 of the original): Zelda stands at ($78,$88) with four
| fires round her (killable, half a heart on contact) and does nothing until Link comes level with her: X $70..$80 and
| Y $95. Then he is put at ($88,$88) facing her, the Zelda fanfare plays for $80 frames, the room is furled away by a
| curtain, she thanks him in typed letters, and Link and she stand with a triforce piece over each head while the
| backdrop flashes. The credits wall follows. Link is held for all of it, so the scene is
| run from zelda_tick, by boss_misc_update, and not from the monster. ZELDA_SCENE: 1 fanfare, 2 curtain, 3 thanks being
| typed, 4 pause, 5 flash, 6 pause, 7 final words being typed, 8 they stay up, 9 the credits wall (credits.s) has taken over.
    .equ ZELDA_X, 0x78
    .equ ZELDA_Y, 0x88
    .equ ZELDA_LINK_X, 0x88
    .equ ZELDA_LINK_Y, 0x88
    .equ ZELDA_FANFARE_FRAMES, 0x80
    .equ ZELDA_THANKS_WAIT, 0x50
    .equ ZELDA_FLASH_FRAMES, 0xc0
    .equ ZELDA_FLASH_FROM, 0x40
    .equ ZELDA_PEACE_DELAY, 0x40
    .equ ZELDA_TEXT_DELAY, 10
    .equ ZELDA_CREDIT_WAIT, 0xb0

zelda_fire_x:
    .byte 0x60, 0x70, 0x80, 0x90
zelda_fire_y:
    .byte 0xb5, 0x9d, 0x9d, 0xb5
zelda_flash_colours:                    | EndingFlashColors $0F $12 $16 $2A as the ST shows them
    .word 0x0000, 0x0026, 0x0600, 0x00a3

zelda_init:
    movem.l %a0, -(%sp)
    move.b #ZELDA_X, OFF_ENEMY_X(%a5, %d5.w)
    move.b #ZELDA_Y, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
    move.b #2, OFF_ENEMY_ACTIVE(%a5, %d5.w)     | she is no monster to kill
    movem.l (%sp)+, %a0
    rts

| The fires take the places of GuardFireXs/Ys, in the order they come after Zelda in the room's list.
fire_init:
    movem.l %d0/%a0, -(%sp)
    move.w %d5, %d0
    subq.w #1, %d0
    and.w #3, %d0
    lea zelda_fire_x(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_X(%a5, %d5.w)
    lea zelda_fire_y(%pc), %a0
    move.b 0(%a0, %d0.w), OFF_ENEMY_Y(%a5, %d5.w)
    movem.l (%sp)+, %d0/%a0
    rts

dmon_fire:
    moveq #1, %d0                       | a fire stands where it is
    rts

| d5 = Zelda. UpdateZelda state 0. Returns d0.w = 1.
dmon_zelda:
    movem.l %d1, -(%sp)
    tst.b OFF_ZELDA_SCENE(%a5)
    bne 8f
    move.b OFF_LINK_X(%a5), %d1
    cmp.b #0x70, %d1
    blo 8f
    cmp.b #0x81, %d1
    bhs 8f
    cmpi.b #0x95, OFF_LINK_Y(%a5)
    bne 8f
    move.b #1, OFF_ZELDA_SCENE(%a5)
    move.b #ZELDA_FANFARE_FRAMES, OFF_ZELDA_TIMER(%a5)
    move.b #1, OFF_LINK_HELD(%a5)
    move.b #ZELDA_LINK_X, OFF_LINK_X(%a5)
    move.b #ZELDA_LINK_Y, OFF_LINK_Y(%a5)
    move.b #DIR_LEFT, OFF_LINK_DIR(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    move.l %d0, -(%sp)
    moveq #MUS_ZELDA, %d0
    bsr music_event_bf
    move.l (%sp)+, %d0
8:  movem.l (%sp)+, %d1
    moveq #1, %d0
    rts

| d0.w = where the words are in cave_text. Starts them being typed by cave_talk.
zelda_say:
    move.w %d0, OFF_CAVE_TEXT_IDXW(%a5)
    move.b #1, OFF_CAVE_TEXT_ON(%a5)
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_ROW0, OFF_CAVE_TEXT_ROW(%a5)
    move.b #ZELDA_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    clr.b OFF_CAVE_TEXT_PEACE(%a5)
    rts

| The last words: "FINALLY," at the ROM's ($22AC), then the other two lines further down (cave_talk places them).
zelda_say_peace:
    bsr zelda_say
    move.b #1, OFF_CAVE_TEXT_PEACE(%a5)
    move.b #16, OFF_CAVE_TEXT_COL(%a5)
    move.b #16, OFF_CAVE_TEXT_ROW(%a5)
    rts

| The fires are gone from the picture (and still count as the room's monsters: nothing here may clear the room).
zelda_hide_fires:
    movem.l %d5/%a0, -(%sp)
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    cmpi.b #MON_ZELDA_FIRE, OFF_ENEMY_TYPE(%a5, %d5.w)
    bne 2f
    clr.b OFF_ENEMY_Y(%a5, %d5.w)
    lea OFF_ENEMY_GHOST(%a5), %a0
    move.b #(GHOST_NOHIT + GHOST_NOHARM), 0(%a0, %d5.w)
2:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d5/%a0
    rts

| The thanks, wiped from the black room so the last words can take its place: blank glyphs over three lines.
zelda_wipe_text:
    movem.l %d0-%d2/%d6/%d7, -(%sp)
    moveq #CAVE_TEXT_ROW0, %d6
1:  moveq #CAVE_TEXT_COL0, %d7
2:  moveq #0, %d0
    move.w %d7, %d1
    move.w %d6, %d2
    bsr draw_hud_tile_bf
    move.l OFF_SCREEN_PTR(%a5), -(%sp)  | and into the clean room, to survive Link's erasing
    move.l OFF_BG_CUR(%a5), OFF_SCREEN_PTR(%a5)
    moveq #0, %d0
    move.w %d7, %d1
    move.w %d6, %d2
    bsr draw_hud_tile_bf
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 3f
    move.l OFF_SCREEN_PTR(%a5), -(%sp)
    move.l OFF_BG_NEXT(%a5), OFF_SCREEN_PTR(%a5)
    moveq #0, %d0
    move.w %d7, %d1
    move.w %d6, %d2
    bsr draw_hud_tile_bf
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
3:  addq.w #1, %d7
    cmp.w #(CAVE_TEXT_COL0 + 24), %d7
    blo 2b
    addq.w #1, %d6
    cmp.w #(CAVE_TEXT_ROW0 + 3), %d6
    blo 1b
    movem.l (%sp)+, %d0-%d2/%d6/%d7
    rts

| A triforce piece over Link's head and over Zelda's: item slots 0 and 1, held up.
zelda_triforces:
    move.l %d0, -(%sp)
    move.b #ITEM_TRIFORCE, OFF_ITEM_ID(%a5)
    move.b OFF_LINK_X(%a5), OFF_ITEM_X(%a5)
    move.b OFF_LINK_Y(%a5), %d0
    sub.b #16, %d0
    move.b %d0, OFF_ITEM_Y(%a5)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5)
    move.b #ITEM_TRIFORCE, (OFF_ITEM_ID + 1)(%a5)
    move.b #ZELDA_X, (OFF_ITEM_X + 1)(%a5)
    move.b #(ZELDA_Y - 16), (OFF_ITEM_Y + 1)(%a5)
    move.b #ITEM_LIFTED, (OFF_ITEM_ACTIVE + 1)(%a5)
    move.l (%sp)+, %d0
    rts

| Once a frame, from boss_misc_update.
zelda_tick:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    moveq #0, %d0
    move.b OFF_ZELDA_SCENE(%a5), %d0
    beq 99f
    cmp.b #5, %d0
    blo 1f
    bsr zelda_triforces                 | from the flash on, both pieces are up
1:  cmp.b #1, %d0
    bne 10f
    subq.b #1, OFF_ZELDA_TIMER(%a5)     | 1: the fanfare
    bne 99f
    bsr zelda_hide_fires
    move.b #2, OFF_ZELDA_SCENE(%a5)
    clr.b OFF_ZELDA_STEP(%a5)
    move.b #1, OFF_ZELDA_TIMER(%a5)
    bra 99f
10: cmp.b #2, %d0
    bne 20f
    subq.b #1, OFF_ZELDA_TIMER(%a5)     | 2: the curtain, a column from each side every few frames
    bne 99f
    moveq #0, %d0
    move.b OFF_ZELDA_STEP(%a5), %d0
    bsr curtain_column_bf
    moveq #31, %d1
    sub.w %d0, %d1
    move.w %d1, %d0
    bsr curtain_column_bf
    addq.b #1, OFF_ZELDA_STEP(%a5)
    move.b #ENDING_CURTAIN_FRAMES, OFF_ZELDA_TIMER(%a5)
    cmpi.b #ENDING_CURTAIN_STEPS, OFF_ZELDA_STEP(%a5)
    blo 99f
    move.b #3, OFF_ZELDA_SCENE(%a5)
    move.w #ENDING_TEXT_THANKS, %d0
    bsr zelda_say
    bra 99f
20: cmp.b #3, %d0
    bne 30f
    bsr cave_talk_bf                    | 3: "THANKS LINK, YOU'RE THE HERO OF HYRULE."
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 99f
    move.b #4, OFF_ZELDA_SCENE(%a5)
    move.b #ZELDA_THANKS_WAIT, OFF_ZELDA_TIMER(%a5)
    bra 99f
30: cmp.b #4, %d0
    bne 40f
    subq.b #1, OFF_ZELDA_TIMER(%a5)     | 4: a pause of $50 frames
    bne 99f
    bsr zelda_wipe_text
    move.b #5, OFF_ZELDA_SCENE(%a5)
    clr.b OFF_ZELDA_TIMER(%a5)
    bra 99f
40: cmp.b #5, %d0
    bne 50f
    addq.b #1, OFF_ZELDA_TIMER(%a5)     | 5: $C0 frames, the backdrop flashing from the $40th
    moveq #0, %d1
    move.b OFF_ZELDA_TIMER(%a5), %d1
    cmp.w #ZELDA_FLASH_FROM, %d1
    blo 99f
    movea.l #PALETTE_BASE, %a1
    bsr cur_palette_bf
    cmp.w #ZELDA_FLASH_FRAMES, %d1
    bhs 41f
    and.w #3, %d1
    add.w %d1, %d1
    lea zelda_flash_colours(%pc), %a0
    move.w 0(%a0, %d1.w), (%a1)
    bra 99f
41: move.w (%a0), (%a1)                 | the flash is over: the level's own backdrop again
    move.b #6, OFF_ZELDA_SCENE(%a5)
    move.b #ZELDA_PEACE_DELAY, OFF_ZELDA_TIMER(%a5)
    moveq #MUS_ENDING, %d0
    bsr music_event_bf
    bra 99f
50: cmp.b #6, %d0
    bne 55f
    subq.b #1, OFF_ZELDA_TIMER(%a5)     | 6: the ending song, and a pause before the words
    bne 99f
    move.b #7, OFF_ZELDA_SCENE(%a5)
    move.w #ENDING_TEXT_PEACE, %d0
    bsr zelda_say_peace
    bra 99f
55: cmp.b #7, %d0
    bne 60f
    bsr cave_talk_bf                    | 7: "PEACE RETURNS TO HYRULE. THIS ENDS THE STORY."
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 99f
    move.b #8, OFF_ZELDA_SCENE(%a5)
    move.b #ZELDA_CREDIT_WAIT, OFF_ZELDA_TIMER(%a5)
    bra 99f
60: cmp.b #8, %d0
    bne 99f
    subq.b #1, OFF_ZELDA_TIMER(%a5)     | 8: the last words stay up, then the credits wall (credits.s)
    bne 99f
    move.b #9, OFF_ZELDA_SCENE(%a5)
    bsr credits_begin_bf
99: movem.l (%sp)+, %d0-%d2/%a0-%a1
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
    move.b 5(%a1), %d2                  | statues that shoot (record byte 5, bits 3-4): every one starts with its timer at 0
    lsr.b #3, %d2
    and.b #3, %d2
    move.b %d2, OFF_ROOM_STATUES(%a5)
    clr.b (OFF_STATUE_T + 0)(%a5)
    clr.b (OFF_STATUE_T + 1)(%a5)
    clr.b (OFF_STATUE_T + 2)(%a5)
    clr.b (OFF_STATUE_T + 3)(%a5)
    move.b 1(%a1), %d1
    uwlea FLAGS, %a0
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
    uwlea FLAGS, %a0
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
    uwlea FLAGS, %a0
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
    bsr ganon_tick
    bsr zelda_tick
    bsr person_fire_tick
    bsr statue_fire_tick
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
    uwlea FLAGS, %a0
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
    uwlea FLAGS, %a0
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

| ------------------------------------------------------------ the old man's flames
| A blow of the sword on the man between the two fires (Person_CheckCollisions) turns the fires on Link for the rest of
| the visit: each flame (UpdateStatues, pattern 2) waits Statue_ObjFireballTimer frames, then, unless the random byte is
| $F0 or more (then it waits 256), starts a wait of $50, $80, $F0 or $60 frames by the byte's low bits and shoots a fireball at
| Link, but not when Link stands within $18 of the flame on both axes.
    .equ PERSON_X, 0x78
    .equ PERSON_FIRE_LEFT_X, 0x48
    .equ PERSON_FIRE_RIGHT_X, 0xa8

| The sword is out: d1.w, d2.w = where a monster would stand with its middle on the blade, d4.w, d6.w = how near it must
| be in X and in Y (sword_hits). Hits the old man if the blade is on him.
person_hit:
    movem.l %d1-%d3, -(%sp)
    tst.b OFF_UW_PERSON(%a5)
    beq 9f
    cmpi.b #3, OFF_UW_PERSON(%a5)
    beq 9f
    tst.b OFF_GRUMBLE_ON(%a5)
    bne 9f
    tst.b OFF_LEVEL(%a5)
    beq 9f
    sub.w #PERSON_X, %d1
    bpl 1f
    neg.w %d1
1:  cmp.w %d4, %d1
    bhs 9f
    sub.w #CAVE_PERSON_Y, %d2
    bpl 2f
    neg.w %d2
2:  cmp.w %d6, %d2
    bhs 9f
    move.b #1, OFF_PERSON_FIRE(%a5)
9:  movem.l (%sp)+, %d1-%d3
    rts

person_fire_tick:
    tst.b OFF_PERSON_FIRE(%a5)
    beq 9f
    tst.b OFF_UW_PERSON(%a5)
    beq 9f
    cmpi.b #3, OFF_UW_PERSON(%a5)
    beq 9f
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #1, %d7                       | the flames, last first as in the ROM
1:  lea OFF_PERSON_FIRE_T(%a5), %a0
    subq.b #1, 0(%a0, %d7.w)
    cmpi.b #0xff, 0(%a0, %d7.w)
    bne 8f                              | not its turn yet
    bsr rand8_bf
    cmp.b #0xf0, %d0
    bhs 8f                              | the wait stays $FF: another 256 frames
    and.w #3, %d0
    lea person_fire_waits(%pc), %a1
    move.b 0(%a1, %d0.w), 0(%a0, %d7.w)
    move.w #PERSON_FIRE_LEFT_X, %d1
    tst.w %d7
    beq 2f
    move.w #PERSON_FIRE_RIGHT_X, %d1
2:  moveq #0, %d0                       | within $18 of the flame on both axes: no shot
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d1, %d0
    cmp.w #0x18, %d0
    bge 3f
    cmp.w #-0x18, %d0
    ble 3f
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    sub.w #CAVE_PERSON_Y, %d0
    cmp.w #0x18, %d0
    bge 3f
    cmp.w #-0x18, %d0
    bgt 8f
3:  addq.w #4, %d1                      | the fireball starts four pixels right of its flame
    move.w #CAVE_PERSON_Y, %d2
    move.w %d7, -(%sp)                  | (the aim leaves its speeds in d6 and d7)
    bsr fireball_aim_xy_bf
    bsr fireball_spawn_xy_bf
    move.w (%sp)+, %d7
8:  dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
9:  rts

person_fire_waits:
    .byte 0x50, 0x80, 0xf0, 0x60

| The statues of the rooms whose layout is $24 (four) or $23 (two) shoot at Link all the time (UpdateStatues, patterns 0
| and 1): the same timers and the same rule as the flames, a fireball from the statue's spot. ROOM_STATUES: 0 none, 1 four, 2 two.
statue_fire_tick:
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    moveq #0, %d6                       | the first of its statues in statue_xs: the four, then the two
    moveq #3, %d7
    move.b OFF_ROOM_STATUES(%a5), %d0
    beq 9f
    cmp.b #2, %d0
    bne 0f
    moveq #4, %d6
    moveq #1, %d7
0:  movem.l %d0-%d7/%a0-%a1, -(%sp)
1:  lea OFF_STATUE_T(%a5), %a0
    subq.b #1, 0(%a0, %d7.w)
    cmpi.b #0xff, 0(%a0, %d7.w)
    bne 8f                              | not its turn yet
    bsr rand8_bf
    cmp.b #0xf0, %d0
    bhs 8f                              | the wait stays $FF: another 256 frames
    and.w #3, %d0
    lea person_fire_waits(%pc), %a1
    move.b 0(%a1, %d0.w), 0(%a0, %d7.w)
    lea statue_xs(%pc), %a1
    move.w %d7, %d0
    add.w %d6, %d0
    moveq #0, %d1
    move.b 0(%a1, %d0.w), %d1           | the statue's X
    moveq #0, %d2
    move.b 8(%a1, %d0.w), %d2           | and Y
    moveq #0, %d0                       | Link within $18 of it on both axes: no shot
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d1, %d0
    cmp.w #0x18, %d0
    bge 3f
    cmp.w #-0x18, %d0
    ble 3f
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    sub.w %d2, %d0
    cmp.w #0x18, %d0
    bge 3f
    cmp.w #-0x18, %d0
    bgt 8f
3:  addq.w #4, %d1                      | the fireball starts four pixels right of its statue
    movem.w %d6-%d7, -(%sp)             | (the aim leaves its speeds in d6 and d7)
    bsr fireball_aim_xy_bf
    bsr fireball_spawn_xy_bf
    movem.w (%sp)+, %d6-%d7
8:  dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
9:  rts

statue_xs:
    .byte 0x24, 0xc8, 0x24, 0xc8, 0x64, 0x88, 0x48, 0xa8
statue_ys:
    .byte 0xc0, 0xbc, 0x64, 0x5c, 0x94, 0x8c, 0x82, 0x86

| ------------------------------------------------------------------ the push block
| (the section of combat.s that says how it works)
block_setup:
    movem.l %d0-%d3, -(%sp)
    clr.b OFF_BLOCK_STATE(%a5)
    clr.b OFF_BLOCK_PUSH(%a5)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    tst.b OFF_ROOM_BLOCK(%a5)
    beq 9f
    moveq #4, %d3                   | FindAndCreatePushBlockObject: row 10, from column 4
1:  moveq #10, %d2
    bsr fetch_tile_bf
    cmp.w #BLOCK_TILE, %d0
    beq 2f
    addq.w #2, %d3
    cmp.w #26, %d3
    blo 1b
    bra 9f
2:  lsl.w #3, %d3
    move.b %d3, OFF_BLOCK_X(%a5)
    move.b #0x90, OFF_BLOCK_Y(%a5)
    move.b #1, OFF_BLOCK_STATE(%a5)
9:  movem.l (%sp)+, %d0-%d3
    rts

| Link is walking into a wall in direction d1.b: is it the block?
block_push_tick:
    movem.l %d0-%d5/%a0, -(%sp)
    cmpi.b #1, OFF_BLOCK_STATE(%a5)
    bne 9f
    move.b %d1, %d5                 | the way he pushes
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    uwlea FLAGS, %a0
    btst #0, 0(%a0, %d0.w)
    beq 9f                          | the monsters are not all dead
    moveq #0, %d2                   | Link, then the block
    move.b OFF_LINK_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_LINK_Y(%a5), %d3
    addq.w #3, %d3
    moveq #0, %d0
    move.b OFF_BLOCK_X(%a5), %d0
    moveq #0, %d1
    move.b OFF_BLOCK_Y(%a5), %d1
    cmp.w %d0, %d2
    bne 3f
    sub.w %d1, %d3                  | level in X: he pushes from below or above
    bpl 1f
    neg.w %d3
    moveq #DIR_DOWN, %d4
    bra 2f
1:  moveq #DIR_UP, %d4
2:  cmp.w #0x11, %d3
    bhs 9f
    bra 5f
3:  cmp.w %d1, %d3
    bne 9f
    sub.w %d0, %d2                  | level in Y: he pushes from the right or the left
    bpl 4f
    neg.w %d2
    moveq #DIR_RIGHT, %d4
    bra 41f
4:  moveq #DIR_LEFT, %d4
41: cmp.w #0x11, %d2
    bhs 9f
5:  cmp.b %d4, %d5
    bne 9f
    move.b #1, OFF_BLOCK_TICK(%a5)
    addq.b #1, OFF_BLOCK_PUSH(%a5)
    cmpi.b #BLOCK_PUSH_FRAMES, OFF_BLOCK_PUSH(%a5)
    blo 9f
    bsr block_slide
9:  movem.l (%sp)+, %d0-%d5/%a0
    rts

| Pushing only counts while it goes on without a break. A block that is sliding moves a pixel a frame (UpdateBlock's
| moving state) and lands after 16.
block_update:
    bsr rock_update_bf                  | (the overworld's rock that slides)
    cmpi.b #3, OFF_BLOCK_STATE(%a5)
    bne 2f
    addq.b #1, OFF_BLOCK_FRAME(%a5)
    cmpi.b #BLOCK_PUSH_FRAMES, OFF_BLOCK_FRAME(%a5)
    blo 2f
    bsr block_land
2:  tst.b OFF_BLOCK_TICK(%a5)
    bne 1f
    clr.b OFF_BLOCK_PUSH(%a5)
1:  clr.b OFF_BLOCK_TICK(%a5)
    rts

| Out: d0.w, d1.w = the block's tile column and row, d4.w, d5.w = where it is going (BLOCK_DIR says which way).
block_geom:
    moveq #0, %d0
    move.b OFF_BLOCK_X(%a5), %d0
    lsr.w #3, %d0
    moveq #0, %d1
    move.b OFF_BLOCK_Y(%a5), %d1
    sub.w #BLOCK_ROW_Y, %d1
    lsr.w #3, %d1
    move.w %d0, %d4
    move.w %d1, %d5
    move.b OFF_BLOCK_DIR(%a5), %d7
    btst #0, %d7
    beq 1f
    addq.w #2, %d4
    rts
1:  btst #1, %d7
    beq 2f
    subq.w #2, %d4
    rts
2:  btst #2, %d7
    beq 3f
    addq.w #2, %d5
    rts
3:  subq.w #2, %d5
    rts

| d6.w = 0..3 (which of the block's four tiles), d0/d1/d4/d5 from block_geom.
| Out: d2.w = its place in the room map where the block is, d3.w = where it is going.
block_cell_index:
    move.w %d1, %d2
    btst #1, %d6
    beq 1f
    addq.w #1, %d2
1:  lsl.w #5, %d2
    add.w %d0, %d2
    btst #0, %d6
    beq 2f
    addq.w #1, %d2
2:  move.w %d5, %d3
    btst #1, %d6
    beq 3f
    addq.w #1, %d3
3:  lsl.w #5, %d3
    add.w %d4, %d3
    btst #0, %d6
    beq 4f
    addq.w #1, %d3
4:  rts

| Draws the clean room again from the map and shows it.
block_render:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    lea OFF_UW_MAP(%a5), %a0
    movea.l OFF_BG_CUR(%a5), %a1
    bsr uw_render_map_bf
    bsr show_background_bf
    clr.b OFF_ERASE_VALID(%a5)
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| The block starts to move 16 pixels the way d5.b says, if the floor there is free. Its picture is taken from the clean
| room and floats over it (effect slot 11, block_draw); the room is drawn without it, and the map says the block is
| already where it will land, so Link cannot walk through it.
block_slide:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    move.b %d5, OFF_BLOCK_DIR(%a5)
    bsr block_geom
    cmp.w #2, %d4
    blt 9f
    cmp.w #29, %d4
    bgt 9f
    cmp.w #2, %d5
    blt 9f
    cmp.w #19, %d5
    bgt 9f
    moveq #3, %d6
5:  move.w %d5, %d2                 | all four tiles there have to be floor
    btst #1, %d6
    beq 51f
    addq.w #1, %d2
51: move.w %d4, %d3
    btst #0, %d6
    beq 52f
    addq.w #1, %d3
52: bsr fetch_tile_bf
    bsr tile_blocks_bf
    tst.w %d0
    bne 9f
    dbra %d6, 5b

    move.b #3, OFF_BLOCK_STATE(%a5)
    clr.b OFF_BLOCK_PUSH(%a5)
    clr.b OFF_BLOCK_FRAME(%a5)
    moveq #0, %d1                   | its picture, from the clean room (the block sits on a 16-pixel column)
    move.b OFF_BLOCK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_BLOCK_Y(%a5), %d2
    subq.w #2, %d2
    bsr sprite_offset_bf
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l %d1, %a0
    lea OFF_BLOCK_SPRITE(%a5), %a1
    moveq #(SPRITE_HEIGHT - 1), %d7
1:  move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.w #-1, (%a1)+              | opaque
    lea (SCREEN_STRIDE - 8)(%a0), %a0
    dbra %d7, 1b
    bsr block_geom                  | d7 was used
    lea OFF_UW_MAP(%a5), %a0        | the room without the block: both places show the floor
    lea OFF_BLOCK_TILES(%a5), %a1
    moveq #3, %d6
6:  bsr block_cell_index
    move.b 0(%a0, %d2.w), 0(%a1, %d6.w)
    move.b 0(%a0, %d3.w), 4(%a1, %d6.w)
    move.b 4(%a1, %d6.w), 0(%a0, %d2.w)
    dbra %d6, 6b
    bsr block_render
    lea OFF_UW_MAP(%a5), %a0
    lea OFF_BLOCK_TILES(%a5), %a1
    moveq #3, %d6
7:  bsr block_cell_index             | and the block is in the map where it will land
    move.b 0(%a1, %d6.w), 0(%a0, %d3.w)
    dbra %d6, 7b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| The block has landed. Trigger 4 opens the room's shutters for good; trigger 5 (CheckSecretTriggerBlockStairs) lays the
| stairs at ($D0, $60), once; in any other room (the bow room's block) the secret tune plays and nothing else happens.
block_land:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    move.b #2, OFF_BLOCK_STATE(%a5)
    clr.b OFF_BLOCK_FRAME(%a5)
    bsr block_geom
    cmpi.b #TRIGGER_PUSH_BLOCK, OFF_ROOM_TRIGGER(%a5)
    bne 7f
    moveq #0, %d0                   | the shutters open and the room is rebuilt (which puts the block back
    move.b OFF_ROOM_ID(%a5), %d0    | where it started: the map is set again below)
    bsr uw_open_shutters_bf
    bsr uw_redraw_room_bf
    bsr block_geom
    bra 8f
7:  sfx SFX_SECRET
8:  lea OFF_UW_MAP(%a5), %a0        | the floor where it was, the block where it is
    lea OFF_BLOCK_TILES(%a5), %a1
    moveq #3, %d6
6:  bsr block_cell_index
    move.b 4(%a1, %d6.w), %d7
    move.b %d7, 0(%a0, %d2.w)
    move.b 0(%a1, %d6.w), 0(%a0, %d3.w)
    dbra %d6, 6b
    cmpi.b #5, OFF_ROOM_TRIGGER(%a5)
    bne 5f
    moveq #0, %d7                   | the stairs: four tiles, column-major, at tile column 26, row 4
    move.b OFF_UW_STAIRS_ID(%a5), %d7
    beq 5f
    move.b %d7, (4 * 32 + 26)(%a0)
    addq.b #1, %d7
    move.b %d7, (5 * 32 + 26)(%a0)
    addq.b #1, %d7
    move.b %d7, (4 * 32 + 27)(%a0)
    addq.b #1, %d7
    move.b %d7, (5 * 32 + 27)(%a0)
5:  lsl.w #3, %d4
    move.b %d4, OFF_BLOCK_X(%a5)
    lsl.w #3, %d5
    add.w #BLOCK_ROW_Y, %d5
    move.b %d5, OFF_BLOCK_Y(%a5)
    bsr block_render
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| While the block slides, its picture is the effect in slot 11, a pixel further each frame.
block_draw:
    bsr rock_draw_bf
    cmpi.b #3, OFF_BLOCK_STATE(%a5)
    bne 9f
    movem.l %d0-%d2/%d6/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_BLOCK_FRAME(%a5), %d0
    moveq #0, %d1
    move.b OFF_BLOCK_X(%a5), %d1
    moveq #0, %d2
    move.b OFF_BLOCK_Y(%a5), %d2
    subq.w #2, %d2
    move.b OFF_BLOCK_DIR(%a5), %d6
    btst #0, %d6
    beq 1f
    add.w %d0, %d1
1:  btst #1, %d6
    beq 2f
    sub.w %d0, %d1
2:  btst #2, %d6
    beq 3f
    add.w %d0, %d2
3:  btst #3, %d6
    beq 4f
    sub.w %d0, %d2
4:  lea OFF_BLOCK_SPRITE(%a5), %a0
    moveq #11, %d6
    bsr fx_put_a0_bf
    movem.l (%sp)+, %d0-%d2/%d6/%a0
9:  rts
