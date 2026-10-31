| Link's death: game mode $11 of the ROM (Z_05.asm InitMode11 and UpdateMode11Death_Full), then the question of mode 8
| (CONTINUE, SAVE or RETRY, filesel.s shows it) and what each answer does.
|
| link_dies (combat.s) only says that he has died (OFF_DYING); the frame is finished, and the main loop calls death_begin.
| From then on the game is in MODE_DEATH and update_death runs the phases:
|
|     0 blink    the room without anything but Link, who flashes (33 frames)
|     1 remap    the world turns red: the pixels of the room go to the three spare slots, DEATH_LINES lines a frame
|                (the ROM redraws it in a row of tiles a frame), and the death tune plays
|     2 spin     Link turns round, a quarter every 6 frames, four times (the turns of DeathModeCounter)
|     3 fade     the red fades through the four palettes of the level's DeathPaletteSeries, 10 frames apart
|     4 grey     the world is black; Link is grey (Mode11DeadLinkPalette) and stays for 24 frames
|     5 spark    the spark that takes him: 14 frames, the little one for the first nine
|     6 wait     46 frames of black
|     7 text     GAME OVER, 96 frames; then the death count goes up and the question comes
|
| The red world works with slots 13 to 15 of the one ST palette (tools/gameover.py): death_maps says which of the three each
| colour of the room goes to, so remapping a group of 16 pixels is a boolean function of its four bit planes. The world is
| remapped in BG_CUR (so that erasing Link puts back red) and copied to the screen.

    .equ DEATH_BLINK_FRAMES, 33
    .equ DEATH_LINES, 4                   | lines of the playfield remapped a frame (PLAYFIELD_HEIGHT must be a multiple of it)
    .equ DEATH_TURN_FRAMES, 6
    .equ DEATH_TURNS_TOTAL, 4
    .equ DEATH_FADE_FRAMES, 10
    .equ DEATH_FADE_STEPS, 4
    .equ DEATH_GREY_FRAMES, 24
    .equ DEATH_SPARK_FRAMES, 15
    .equ DEATH_SPARK_LITTLE, 6            | UpdateMode11Death_SubA: the little spark while the counter is at least this
    .equ DEATH_WAIT_FRAMES, 46
    .equ DEATH_TEXT_FRAMES, 96
    .equ DEATH_COLOUR_WORDS, 3

    .equ DPH_BLINK, 0
    .equ DPH_REMAP, 1
    .equ DPH_SPIN, 2
    .equ DPH_FADE, 3
    .equ DPH_GREY, 4
    .equ DPH_SPARK, 5
    .equ DPH_WAIT, 6
    .equ DPH_TEXT, 7

    .if (PLAYFIELD_HEIGHT % DEATH_LINES) != 0
    .error "DEATH_LINES has to divide the height of the playfield"
    .endif

| ------------------------------------------------------------------------------------------------------------ start
| The frame in which Link died is finished. Everything but the room goes, Link stays on a screen of his own.
death_begin:
    clr.b OFF_DYING(%a5)
    move.b #MODE_DEATH, OFF_GAME_MODE(%a5)
    bsr music_stop_df                  | SilenceSound
    clr.b OFF_MUS_FORCED(%a5)
    bsr dbl_end_df                     | what is on show stays on show; no more hidden buffer
    bsr show_background_df             | the bare room (the monsters, the items, everything that was drawn goes)
    bsr clear_erase_state_df
    move.b #DPH_BLINK, OFF_DEATH_PHASE(%a5)
    move.w #DEATH_BLINK_FRAMES, OFF_DEATH_T(%a5)
    clr.b OFF_LINK_HURT(%a5)
    bsr draw_link_df
    rts

| ---------------------------------------------------------------------------------------------------------- each frame
update_death:
    move.b OFF_DEATH_PHASE(%a5), %d0
    beq death_blink
    subq.b #1, %d0
    beq death_remap
    subq.b #1, %d0
    beq death_spin
    subq.b #1, %d0
    beq death_fade
    subq.b #1, %d0
    beq death_grey
    subq.b #1, %d0
    beq death_spark
    subq.b #1, %d0
    beq death_wait
    bra death_over

| Phase 0: the invincibility flash. Link is drawn two frames in four.
death_blink:
    bsr erase_sprite_df
    btst #1, OFF_DEATH_T+1(%a5)
    bne 1f
    bsr draw_link_df
1:  subq.w #1, OFF_DEATH_T(%a5)
    bne 9f
    clr.w OFF_DEATH_LINE(%a5)
    bsr death_build_w
    moveq #0, %d0
    bsr death_colours_set               | where the red world starts
    moveq #MUS_DEATH, %d0               | the death tune
    bsr music_event_df
    move.b #DPH_REMAP, OFF_DEATH_PHASE(%a5)
    bsr draw_link_df
9:  rts

| Phase 1: DEATH_LINES more lines of the room go red.
death_remap:
    bsr erase_sprite_df
    move.w OFF_DEATH_LINE(%a5), %d6
    moveq #DEATH_LINES, %d7
    bsr death_remap_lines
    bsr death_copy_lines
    add.w #DEATH_LINES, %d6
    move.w %d6, OFF_DEATH_LINE(%a5)
    cmp.w #PLAYFIELD_HEIGHT, %d6
    blo 1f
    move.b #DPH_SPIN, OFF_DEATH_PHASE(%a5)
    move.b #DEATH_TURNS_TOTAL, OFF_DEATH_TURNS(%a5)
    move.b #DIR_DOWN, OFF_LINK_DIR(%a5)
    clr.w OFF_DEATH_T(%a5)
1:  bsr draw_link_df
    rts

| Phase 2: down, right, up, left, down ...; every turn that ends facing left counts one of the four.
death_spin:
    bsr erase_sprite_df
    tst.b OFF_DEATH_TURNS(%a5)
    beq 8f
    tst.w OFF_DEATH_T(%a5)
    beq 1f
    subq.w #1, OFF_DEATH_T(%a5)
    bra 5f
1:  move.w #(DEATH_TURN_FRAMES - 1), OFF_DEATH_T(%a5)
    move.b OFF_LINK_DIR(%a5), %d0
    lsr.b #2, %d0
    bcs 3f                              | he was facing left
    bne 4f                              | down turns to the right, up to the left
    moveq #DIR_UP, %d0                  | right turns up
    bra 4f
3:  subq.b #1, OFF_DEATH_TURNS(%a5)
    moveq #DIR_DOWN, %d0
4:  move.b %d0, OFF_LINK_DIR(%a5)
5:  bra draw_link_df
8:  move.b #DPH_FADE, OFF_DEATH_PHASE(%a5)
    clr.b OFF_DEATH_STEP(%a5)
    clr.w OFF_DEATH_T(%a5)
    bra draw_link_df

| Phase 3: the red fades away.
death_fade:
    bsr erase_sprite_df
    tst.w OFF_DEATH_T(%a5)
    beq 1f
    subq.w #1, OFF_DEATH_T(%a5)
    bra draw_link_df
1:  moveq #0, %d0
    move.b OFF_DEATH_STEP(%a5), %d0
    addq.b #1, OFF_DEATH_STEP(%a5)
    add.w #DEATH_COLOURS_STEPS, %d0
    bsr death_colours_set
    cmpi.b #DEATH_FADE_STEPS, OFF_DEATH_STEP(%a5)
    bhs 2f
    move.w #(DEATH_FADE_FRAMES - 1), OFF_DEATH_T(%a5)
    bra draw_link_df

    | The world is black: Link turns grey (the sprite palette of Sub9), alone on the screen.
2:  bsr death_clear_world
    moveq #DEATH_COLOURS_LINK, %d0
    bsr death_colours_set
    moveq #DEATH_FRAME_LINK, %d0
    bsr death_draw
    move.b #DPH_GREY, OFF_DEATH_PHASE(%a5)
    move.w #(DEATH_GREY_FRAMES - 1), OFF_DEATH_T(%a5)
    rts

| Phase 4: he stands there grey.
death_grey:
    subq.w #1, OFF_DEATH_T(%a5)
    bne 9f
    moveq #DEATH_COLOURS_SPARK, %d0
    bsr death_colours_set
    move.b #DPH_SPARK, OFF_DEATH_PHASE(%a5)
    move.b #DEATH_SPARK_FRAMES, OFF_DEATH_SPARK(%a5)
9:  rts

| Phase 5: the spark, in the place where Link was.
death_spark:
    bsr erase_sprite_df
    move.b OFF_DEATH_SPARK(%a5), %d1
    subq.b #1, %d1
    move.b %d1, OFF_DEATH_SPARK(%a5)
    beq 7f
    moveq #DEATH_FRAME_SPARK_SMALL, %d0
    cmp.b #(DEATH_SPARK_LITTLE - 1), %d1
    bhs 1f
    moveq #DEATH_FRAME_SPARK_BIG, %d0
1:  bra death_draw
7:  moveq #SFX_HEART, %d0               | Tune0Request = $10, the heart taken
    bsr music_play_df
    move.b #DPH_WAIT, OFF_DEATH_PHASE(%a5)
    move.w #(DEATH_WAIT_FRAMES - 1), OFF_DEATH_T(%a5)
    rts

| Phase 6: black.
death_wait:
    subq.w #1, OFF_DEATH_T(%a5)
    bne 9f
    bsr death_game_over
    move.b #DPH_TEXT, OFF_DEATH_PHASE(%a5)
    move.w #(DEATH_TEXT_FRAMES - 1), OFF_DEATH_T(%a5)
9:  rts

| Phase 7: GAME OVER on show; then the question.
death_over:
    subq.w #1, OFF_DEATH_T(%a5)
    bne 9f
    lea OFF_SLOT_DEATHS(%a5), %a0       | the death count of the profile, up to $FF
    moveq #0, %d0
    move.b OFF_PROFILE(%a5), %d0
    cmpi.b #0xff, 0(%a0, %d0.w)
    beq 1f
    addq.b #1, 0(%a0, %d0.w)
1:  bsr swap_screens_df                | the file menu's way with the buffers (intro_start): SCREEN_PTR hidden
    move.b #MODE_INTRO, OFF_GAME_MODE(%a5)
    moveq #FILE_CONTINUE, %d0
    bsr filesel_begin
    moveq #MUS_GAMEOVER, %d0
    bra music_event_df
9:  rts

| "GAME OVER" (GameOverTransferBuf), in the letters of the cave people's speech.
death_game_over:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    ltab death_text, %a0
    ltab text_glyphs, %a1
    moveq #0, %d4
1:  moveq #0, %d0
    move.b 0(%a0, %d4.w), %d0
    and.w #0x3f, %d0
    move.b 0(%a1, %d0.w), %d0
    move.w %d4, %d1
    add.w #DEATH_TEXT_COL, %d1
    moveq #DEATH_TEXT_ROW, %d2
    bsr draw_hud_tile_df
    addq.w #1, %d4
    cmp.w #DEATH_TEXT_LEN, %d4
    blo 1b
    movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| ---------------------------------------------------------------------------------------------------------- the colours
| The three colours of palette row 3 from death_colours: d0.w = which set of three (DEATH_COLOURS_*).
death_colours_set:
    movem.l %d0/%a0-%a1, -(%sp)
    ltab death_colours, %a0
    mulu.w #(2 * DEATH_COLOUR_WORDS), %d0
    adda.w %d0, %a0
    movea.l #(PALETTE_BASE + 2 * (DEATH_SLOT + 1)), %a1
    move.w (%a0)+, (%a1)+
    move.w (%a0)+, (%a1)+
    move.w (%a0)+, (%a1)+
    movem.l (%sp)+, %d0/%a0-%a1
    rts

| For each colour slot of the palette on show, the two pixel masks that tell which of the three red colours it goes to
| (slot 13 is 1101, 14 is 1110 and 15 is 1111: the first plane is set for 13 and 15, the second for 14 and 15). Black
| (slot 0) stays black. W0 is at OFF_DEATH_W, W1 32 bytes after it.
death_build_w:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.b OFF_LEVEL(%a5), %d0
    lsl.w #4, %d0
    ltab death_maps, %a0
    adda.w %d0, %a0
    lea OFF_DEATH_W(%a5), %a1
    lea (OFF_DEATH_W + 32)(%a5), %a2
    moveq #15, %d2
1:  moveq #0, %d0
    move.b (%a0)+, %d0
    move.w %d0, %d1
    and.w #1, %d1
    neg.w %d1
    move.w %d1, (%a1)+
    lsr.w #1, %d0
    and.w #1, %d0
    neg.w %d0
    move.w %d0, (%a2)+
    dbra %d2, 1b
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

| One output plane of a group of 16 pixels. The minterms of the pixels' low two bits are in d5 (0), d0 (1), d1 (2) and d4
| (3); those of the high two are on the stack (0 to 6), so the colour in slot s, which is q(s & 3) and r(s >> 2), goes to
| the plane when its mask word (the table at a3) says so. d2 collects the plane, d7 one row of four colours and d3 is
| scratch.
    .macro death_term reg, s, woff, first
    .if \first
    move.w \reg, %d7
    and.w (\woff + 2 * \s)(%a3), %d7
    .else
    move.w \reg, %d3
    and.w (\woff + 2 * \s)(%a3), %d3
    or.w %d3, %d7
    .endif
    .endm

    .macro death_plane woff, dest
    death_term %d0, 1, \woff, 1
    death_term %d1, 2, \woff, 0
    death_term %d4, 3, \woff, 0
    and.w (%sp), %d7
    move.w %d7, %d2
    death_term %d5, 4, \woff, 1
    death_term %d0, 5, \woff, 0
    death_term %d1, 6, \woff, 0
    death_term %d4, 7, \woff, 0
    and.w 2(%sp), %d7
    or.w %d7, %d2
    death_term %d5, 8, \woff, 1
    death_term %d0, 9, \woff, 0
    death_term %d1, 10, \woff, 0
    death_term %d4, 11, \woff, 0
    and.w 4(%sp), %d7
    or.w %d7, %d2
    death_term %d5, 12, \woff, 1
    death_term %d0, 13, \woff, 0
    death_term %d1, 14, \woff, 0
    death_term %d4, 15, \woff, 0
    and.w 6(%sp), %d7
    or.w %d7, %d2
    move.w %d2, \dest(%a0)
    .endm

| Lines d6.w to d6.w + d7.w - 1 of the playfield, in BG_CUR, turned red. d6 and d7 stay.
death_remap_lines:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    move.w %d6, %d0
    mulu.w #SCREEN_STRIDE, %d0
    add.l #PLAYFIELD_ORIGIN, %d0
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l %d0, %a0
    lea OFF_DEATH_W(%a5), %a3
    lea -10(%sp), %sp                   | 0 to 6 the minterms of the high bits, 8 the lines still to do
    move.w %d7, 8(%sp)
1:  lea PLAYFIELD_BYTES(%a0), %a1
2:  movem.w (%a0), %d0-%d3
    move.w %d2, %d4                     | the high pixel bits: r0 = neither, r1 = bit 2, r2 = bit 3, r3 = both
    or.w %d3, %d4
    not.w %d4
    move.w %d4, (%sp)
    move.w %d2, %d4
    and.w %d3, %d4
    move.w %d4, 6(%sp)
    eor.w %d4, %d2
    move.w %d2, 2(%sp)
    eor.w %d4, %d3
    move.w %d3, 4(%sp)
    move.w %d0, %d4                     | and the low ones: q3 = both (d4), q0 = neither (d5), q1 (d0), q2 (d1)
    and.w %d1, %d4
    move.w %d0, %d5
    or.w %d1, %d5
    not.w %d5
    eor.w %d4, %d0
    eor.w %d4, %d1
    move.w %d5, %d6                     | planes 2 and 3 are set for all three colours: wherever a pixel is not black
    and.w (%sp), %d6
    not.w %d6
    move.w %d6, 4(%a0)
    move.w %d6, 6(%a0)
    death_plane 0, 0
    death_plane 32, 2
    addq.l #8, %a0
    cmpa.l %a1, %a0
    bne 2b
    lea (SCREEN_STRIDE - PLAYFIELD_BYTES)(%a0), %a0
    subq.w #1, 8(%sp)
    bne 1b
    lea 10(%sp), %sp
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| The same lines from BG_CUR to the screen on show.
death_copy_lines:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    move.w %d6, %d0
    mulu.w #SCREEN_STRIDE, %d0
    add.l #PLAYFIELD_ORIGIN, %d0
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l %d0, %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d0, %a1
    move.w %d7, %d0
    move.w #PLAYFIELD_BYTES, %d1
    bsr blit_rect_df
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| The playfield black, in the clean room and on the screen on show.
death_clear_world:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l #PLAYFIELD_ORIGIN, %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l #PLAYFIELD_ORIGIN, %a1
    moveq #0, %d0
    move.w #(PLAYFIELD_HEIGHT - 1), %d1
1:  moveq #(PLAYFIELD_BYTES / 4 - 1), %d2
2:  move.l %d0, (%a0)+
    move.l %d0, (%a1)+
    dbra %d2, 2b
    lea (SCREEN_STRIDE - PLAYFIELD_BYTES)(%a0), %a0
    lea (SCREEN_STRIDE - PLAYFIELD_BYTES)(%a1), %a1
    dbra %d1, 1b
    clr.b OFF_ERASE_VALID(%a5)
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| A picture of death_sprites (DEATH_FRAME_*) where Link stands, to be taken away by erase_sprite like Link himself.
death_draw:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    ltab death_sprites, %a0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    adda.l %d0, %a0
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    add.w #(PLAYFIELD_LEFT * 2), %d0
    move.w %d0, %d2
    and.w #15, %d2
    lsr.w #4, %d0
    lsl.w #3, %d0
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w #LINK_Y_BIAS, %d1
    mulu.w #SCREEN_STRIDE, %d1
    add.l %d1, %d0
    move.l %d0, OFF_ERASE_OFFSET(%a5)
    move.b #1, OFF_ERASE_VALID(%a5)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d0, %a1
    move.w %d2, %d0
    bsr draw_sprite_df
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| ------------------------------------------------------------------------------------------------------ the question
| Link starts again: no bombs thrown, nothing in the way, at the start of the overworld; d0 is not used.
game_reset_position:
    movem.l %d0/%a0, -(%sp)
    lea OFF_ROOM_HIST(%a5), %a0         | ClearRoomHistory: every screen starts afresh
    moveq #5, %d0
0:  clr.b (%a0)+
    dbra %d0, 0b
    clr.b OFF_ROOM_HIST_I(%a5)
    bsr uw_kills_clear_df
    clr.b OFF_LEVEL(%a5)
    bsr mon_spr_select_df
    clr.b OFF_PAL_LEVEL(%a5)
    clr.b OFF_IN_CELLAR(%a5)
    clr.b OFF_ATTACK(%a5)
    clr.b OFF_LINK_HURT(%a5)
    clr.b OFF_LINK_SHOVE(%a5)
    clr.b OFF_LINK_HELD(%a5)
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_LINK_POS_FRAC(%a5)
    clr.b OFF_DYING(%a5)
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
    move.b #1, OFF_HUD_DIRTY(%a5)
    movem.l (%sp)+, %d0/%a0
    rts

| CONTINUE: three full hearts (HeartValues AND $F0 OR 2, HeartPartial $FF), the same level, the same everything he has.
| In the overworld he is at the start; in a dungeon at its entrance.
death_continue:
    move.b OFF_LEVEL(%a5), %d0
    move.b %d0, -(%sp)
    move.b #6, OFF_HP_HALVES(%a5)
    clr.b OFF_HP_FRAC(%a5)
    bsr game_reset_position
    move.b (%sp)+, %d0                  | the level he died in
death_restart:
    clr.b OFF_SWORD_LOCK(%a5)           | a new life starts with a free sword
    move.b %d0, OFF_LEVEL(%a5)
    beq 2f
    bsr uw_select_level_df              | the level's tables are in the buffer (a load may have changed the quest, a screen may have used it)
2:  bsr mon_spr_select_df
    move.b %d0, OFF_PAL_LEVEL(%a5)
    bsr intro_leave
    tst.b OFF_LEVEL(%a5)
    bne 1f
    bsr enter_room_df
    bra 2f
1:  bsr uw_warp_to_start_df
2:  bra draw_hud_df

    farstub uw_warp_to_start_df, uw_warp_to_start     | 32-bit stubs: the code between here and these two has grown past 16 bits
    farstub draw_hud_df, draw_hud_far
    farstub enter_room_df, enter_room_far
    farstub draw_sprite_df, draw_sprite_far
    farstub blit_rect_df, blit_rect_far
    farstub erase_sprite_df, erase_sprite_far
    farstub draw_link_df, draw_link_far
    farstub clear_erase_state_df, clear_erase_state_far
    farstub show_background_df, show_background_far
    farstub music_stop_df, music_stop_far
    farstub mon_spr_select_df, mon_spr_select
    farstub uw_kills_clear_df, uw_kills_clear
    farstub uw_select_level_df, uw_select_level
    farstub dbl_end_df, dbl_end_far
    farstub music_play_df, music_play_far
    farstub swap_screens_df, swap_screens_far
    farstub music_event_df, music_event_far
    farstub draw_hud_tile_df, draw_hud_tile_far

| SAVE: the hearts are filled up to the containers, the profile is written, and the file menu comes back.
death_save:
    moveq #0, %d0
    move.b OFF_PROFILE(%a5), %d0
    bsr save_store_game
    moveq #FILE_SELECT, %d0
    bra filesel_begin

| RETRY: the game as the profile has it (what was saved, the secrets found since forgotten), and Link starts again: at the
| overworld's start, or in the first room of the dungeon he died in. No menu. A development build has no profile and
| does what CONTINUE does.
death_retry:
    moveq #0, %d0
    move.b OFF_PROFILE(%a5), %d0
    lea OFF_SLOT_ACTIVE(%a5), %a0
    tst.b 0(%a0, %d0.w)
    beq death_continue
    move.b OFF_LEVEL(%a5), -(%sp)
    bsr save_load_game
    move.b (%sp)+, %d0
    bra death_restart
