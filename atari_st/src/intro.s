| The title screen, the story and the parade of the treasures: game mode 0 of the ROM (Z_02.asm UpdateMode0Demo).
|
| Phase 0 is the title: the waterfall's waves and crest run, the Triforce glows, and after 512 frames the picture fades
| through the palettes of DemoPhase0Subphase1Palettes. Phase 1 is the story: the first page scrolls in from below, waits,
| and then the lines of the treasure parade scroll up with the items beside them. Start (Return) leaves for the game at
| any time; when the story is over the title comes back.
|
| tools/intro.py makes the tables. The pictures are tile tables and cell maps, drawn a line at a time into a ring of
| 200 lines (the 128 bytes of a 256-pixel line) the way the PPU would have scrolled them; the ring is copied into the
| hidden screen, the sprites are drawn over it, and the screen is shown. The screen shows the NES lines 24 to 223.
|
| The three screen buffers are used differently here: SCREEN_PTR is the hidden one (drawn into), BG_NEXT the one on
| show, BG_CUR the ring. intro_leave puts them back the way the game has them.

    .equ INTRO_RING_LINES, 200
    .equ INTRO_LINE_BYTES, 128
    .equ INTRO_TITLE_ROWS, 25
    .equ INTRO_WINDOW_TOP, 24             | the NES line on the first screen line
    .equ INTRO_TITLE_FRAMES, 512          | DemoTimer counts every other frame up to 256
    .equ INTRO_STORY_WAIT, 256            | AnimateDemoPhase1Subphase1 and 3 wait for DemoTimer to wrap
    .equ INTRO_STORY_LAST, 57             | AnimateDemoPhase1Subphase4: until DemoTimer is $39
    .equ INTRO_TOP_START, 16              | CurVScroll when the story starts
    .equ INTRO_TOP_REST, 248              | where the first page stops: page A at scroll 8
    .equ INTRO_STEPS, 1408                | ScrolledLineCount: five pages and a half; the last count does not scroll
    .equ INTRO_SPLIT, 100                 | the first frame of a screen copies this many lines, the second the rest and the sprites
    .equ INTRO_WAVES, 3
    .equ INTRO_WAVE_FIRST, 0xb6           | UpdateWaterfallAnimation's start values
    .equ INTRO_WAVE_LAST, 0xe3
    .equ INTRO_WAVE_WRAP, 0xb2
    .equ INTRO_CREST_Y, 0xa8
    .equ INTRO_GLOW_STEPS, 8
    .equ INTRO_FADE_LAST, FADE_STEPS
    .equ INTRO_SCREEN_LEFT, PLAYFIELD_LEFT | the 256-pixel picture sits 16 bytes in on the 320-pixel screen
    .equ INTRO_FALL_LINE, 145              | the lines the waves and the crest sweep: from the crest's top
    .equ INTRO_FALL_LINES, 55              | down to the bottom of the window
    .equ INTRO_FALL_BYTE, ((WATERFALL_X / 16) * 8)
    .equ KIND_FLASH, 1                     | how an item animates (tools/intro.py): 0 not at all, 1 flashing, 2 the fairy
    .equ SCAN_RETURN, 0x1c
    .equ SCAN_KEYPAD_ENTER, 0x72

| ------------------------------------------------------------------------------------------------ entering and leaving
| Called once, with the machine as init has left it: show the title and start its music.
intro_start:
    bsr hide_cursor                     | TOS' cursor must not blink on the screen it gave us
    bsr save_init                       | the slots as ZELDA.SAV has them
    move.b #MODE_INTRO, OFF_GAME_MODE(%a5)
    move.b #1, OFF_INTRO_KEYS(%a5)      | a Start that is still down from before does not count
    bsr swap_screens_xf                    | SCREEN_PTR is the hidden screen from here on
    bsr intro_title_begin
    moveq #MUS_TITLE, %d0
    bra music_event_xf

| ESC f: TOS' text cursor off. The screen it is drawn on (v_bas_ad) is the first of the game's buffers (init_buffers).
hide_cursor:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    move.l #0x1b660000, -(%sp)          | "ESC f", and the end of the string
    pea (%sp)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    lea 10(%sp), %sp
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

| Everything the game expects of the screens, restored: the buffers clean and in their places, the game's colours.
intro_leave:
    bsr music_stop_xf
    clr.b OFF_MUS_FORCED(%a5)
    bsr intro_black
    bsr intro_clear_all
    move.l OFF_HOME_SCREEN(%a5), OFF_SCREEN_PTR(%a5)
    move.l OFF_HOME_NEXT(%a5), OFF_BG_NEXT(%a5)
    move.l OFF_SCREEN_PTR(%a5), %d0
    bsr set_video_base_xf
    clr.b OFF_PRESENT_PENDING(%a5)
    clr.b OFF_INTRO_KEYS(%a5)
    clr.b OFF_GAME_MODE(%a5)
    bsr cur_palette_xf
    bra intro_set_palette

intro_black:
    movem.l %d7/%a1, -(%sp)
    movea.l #PALETTE_BASE, %a1
    moveq #15, %d7
1:  clr.w (%a1)+
    dbra %d7, 1b
    movem.l (%sp)+, %d7/%a1
    rts

| Zero the three buffers.
intro_clear_all:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    lea OFF_HOME_SCREEN(%a5), %a1
    moveq #(BUFFER_COUNT - 1), %d2
2:  movea.l (%a1)+, %a0
    move.w #(SCREEN_BYTES / 16 - 1), %d1
    moveq #0, %d0
1:  move.l %d0, (%a0)+
    move.l %d0, (%a0)+
    move.l %d0, (%a0)+
    move.l %d0, (%a0)+
    dbra %d1, 1b
    dbra %d2, 2b
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| a0 = 16 colours, put in the palette registers.
intro_set_palette:
    movem.l %d7/%a0-%a1, -(%sp)
    movea.l #PALETTE_BASE, %a1
    moveq #15, %d7
1:  move.w (%a0)+, (%a1)+
    dbra %d7, 1b
    movem.l (%sp)+, %d7/%a0-%a1
    rts

| Start was pressed (Return, the keypad's Enter or the joystick's button), once per press: d0.b is non-zero then.
intro_check_start:
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_RETURN(%a0)
    bne 1f
    tst.b SCAN_KEYPAD_ENTER(%a0)
    bne 1f
    move.b OFF_JOY0(%a5), %d0
    or.b OFF_JOY1(%a5), %d0
    bmi 1f
    clr.b OFF_INTRO_KEYS(%a5)
    moveq #0, %d0
    rts
1:  moveq #0, %d0
    tst.b OFF_INTRO_KEYS(%a5)
    bne 9f
    move.b #1, OFF_INTRO_KEYS(%a5)
    moveq #1, %d0
9:  rts

| ---------------------------------------------------------------------------------------------------------- the ring
| One line of a row of tile cells.
| a0 = the row (32 words, each the byte offset of a tile in the table at a2), d0.w = the line in the tile (0-7),
| a1 = where the 128 bytes go. a1 comes back after them; everything else is as it was.
intro_row_line:
    movem.l %d0-%d4/%a0/%a3-%a4, -(%sp)
    lsl.w #2, %d0                       | four plane bytes a line
    moveq #15, %d3
1:  move.w (%a0)+, %d1
    lea 0(%a2, %d1.w), %a3
    adda.w %d0, %a3
    move.w (%a0)+, %d1
    lea 0(%a2, %d1.w), %a4
    adda.w %d0, %a4
    moveq #3, %d4                       | the two tiles side by side make one 16-pixel group: a word for each plane
2:  move.b (%a3)+, %d1
    lsl.w #8, %d1
    move.b (%a4)+, %d1
    move.w %d1, (%a1)+
    dbra %d4, 2b
    dbra %d3, 1b
    movem.l (%sp)+, %d0-%d4/%a0/%a3-%a4
    rts

| The ring's address of a slot: d0.w = slot 0-199 -> a1.
intro_ring_slot:
    move.l %d0, -(%sp)
    andi.l #0xffff, %d0
    lsl.l #7, %d0
    movea.l OFF_BG_CUR(%a5), %a1
    adda.l %d0, %a1
    move.l (%sp)+, %d0
    rts

| Copy window lines d1.w .. d1.w + d2.w - 1 (d2 at least 1) from the ring to the screen at a2. Nothing changes.
intro_copy:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    move.w OFF_INTRO_RING(%a5), %d3
    add.w %d1, %d3
    cmp.w #INTRO_RING_LINES, %d3
    blo 1f
    sub.w #INTRO_RING_LINES, %d3
1:  move.w %d3, %d0
    bsr intro_ring_slot                 | a1 = the first source line
    movea.l %a1, %a0
    movea.l OFF_BG_CUR(%a5), %a3
    adda.l #(INTRO_RING_LINES * INTRO_LINE_BYTES), %a3     | the end of the ring
    andi.l #0xffff, %d1
    mulu.w #SCREEN_STRIDE, %d1
    adda.l %d1, %a2
    adda.w #INTRO_SCREEN_LEFT, %a2
    subq.w #1, %d2
    move.w %d2, -(%sp)                  | the count lives on the stack: the copy needs every data register
2:  movem.l (%a0)+, %d0-%d7
    movem.l %d0-%d7, (%a2)
    movem.l (%a0)+, %d0-%d7
    movem.l %d0-%d7, 32(%a2)
    movem.l (%a0)+, %d0-%d7
    movem.l %d0-%d7, 64(%a2)
    movem.l (%a0)+, %d0-%d7
    movem.l %d0-%d7, 96(%a2)
    adda.w #SCREEN_STRIDE, %a2
    cmpa.l %a3, %a0
    blo 3f
    movea.l OFF_BG_CUR(%a5), %a0
3:  subq.w #1, (%sp)
    bpl 2b
    addq.l #2, %sp
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| Show what is in the hidden screen, then make the other one the hidden one.
intro_present:
    bsr present_frame_xf
    bra swap_screens_xf

| ----------------------------------------------------------------------------------------------------- sprites
| Like draw_sprite, for some of the 16 lines: a0 = the data of the first line to draw, a1 = where it goes,
| d0.w = shift 0-15, d7.w = lines - 1.
draw_sprite_rows:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
1:  sprite_shift_word %d1
    sprite_shift_word %d2
    sprite_shift_word %d3
    sprite_shift_word %d4
    sprite_shift_word %d5
    swap %d1
    swap %d2
    swap %d3
    swap %d4
    swap %d5
    movea.l %a1, %a2
    sprite_merge_group %d1
    sprite_merge_group %d2
    sprite_merge_group %d3
    sprite_merge_group %d4
    swap %d1
    swap %d2
    swap %d3
    swap %d4
    swap %d5
    lea 8(%a1), %a2
    sprite_merge_group %d1
    sprite_merge_group %d2
    sprite_merge_group %d3
    sprite_merge_group %d4
    adda.w #SCREEN_STRIDE, %a1
    dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| A frame of intro_sprites in the hidden screen. d1.w = frame, d2.w = the NES x of its left edge, d3.w = the screen line
| of its top (below 0 or past 199 means partly or wholly off the screen). Nothing changes.
intro_draw_frame:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #0, %d6                       | the first line to draw
    tst.w %d3
    bge 1f
    move.w %d3, %d6
    neg.w %d6
1:  cmp.w #SPRITE_HEIGHT, %d6
    bhs 9f
    move.w #(INTRO_RING_LINES - 1), %d7
    sub.w %d3, %d7                      | the last line of the sprite that fits
    cmp.w #(SPRITE_HEIGHT - 1), %d7
    ble 2f
    moveq #(SPRITE_HEIGHT - 1), %d7
2:  sub.w %d6, %d7                      | the number of lines, less one
    blt 9f
    ltab intro_sprites, %a0
    andi.l #0xffff, %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    adda.l %d1, %a0
    move.w %d6, %d1
    mulu.w #SPRITE_ROW_BYTES, %d1
    adda.w %d1, %a0
    add.w %d6, %d3                      | the screen line of the first line drawn
    andi.l #0xffff, %d3
    mulu.w #SCREEN_STRIDE, %d3
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d3, %a1
    add.w #(PLAYFIELD_LEFT * 2), %d2    | the picture's x on the 320-pixel screen
    move.w %d2, %d0
    andi.w #15, %d0
    lsr.w #4, %d2
    lsl.w #3, %d2
    adda.w %d2, %a1
    bsr draw_sprite_rows
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| ------------------------------------------------------------------------------------------------------ the title
intro_title_begin:
    bsr intro_black
    bsr intro_clear_all
    ltab title_cells, %a0
    ltab title_tiles, %a2
    movea.l OFF_BG_CUR(%a5), %a1
    moveq #(INTRO_TITLE_ROWS - 1), %d5
1:  moveq #0, %d0
2:  bsr intro_row_line
    addq.w #1, %d0
    cmp.w #8, %d0
    blo 2b
    adda.w #64, %a0
    dbra %d5, 1b
    clr.w OFF_INTRO_RING(%a5)
    moveq #0, %d1
    move.w #INTRO_RING_LINES, %d2
    movea.l OFF_SCREEN_PTR(%a5), %a2
    bsr intro_copy
    movea.l OFF_BG_NEXT(%a5), %a2
    bsr intro_copy
    clr.b OFF_INTRO_PHASE(%a5)
    clr.b OFF_INTRO_SUB(%a5)
    clr.w OFF_INTRO_TIMER(%a5)
    clr.b OFF_INTRO_FADE(%a5)
    clr.b OFF_INTRO_FADE_T(%a5)
    clr.b OFF_INTRO_GLOW_T(%a5)
    clr.b OFF_INTRO_GLOW_I(%a5)
    move.b #INTRO_WAVE_FIRST, OFF_INTRO_WAVES(%a5)
    move.b #0xc8, (OFF_INTRO_WAVES + 1)(%a5)
    move.b #0xd8, (OFF_INTRO_WAVES + 2)(%a5)
    ltab title_palette, %a0
    bra intro_set_palette

intro_title_update:
    tst.b OFF_INTRO_SUB(%a5)
    bne 5f

    | Sub-phase 0: the title waits about 512 frames, the Triforce glowing.
    addq.w #1, OFF_INTRO_TIMER(%a5)
    cmp.w #INTRO_TITLE_FRAMES, OFF_INTRO_TIMER(%a5)
    blo 1f
    move.b #1, OFF_INTRO_SUB(%a5)
    clr.b OFF_INTRO_FADE(%a5)
    clr.b OFF_INTRO_FADE_T(%a5)
1:  tst.b OFF_INTRO_GLOW_T(%a5)
    bne 4f
    moveq #0, %d0
    move.b OFF_INTRO_GLOW_I(%a5), %d0
    add.w %d0, %d0
    ltab glow_colours, %a0
    move.w 0(%a0, %d0.w), PALETTE_BASE + 2 * GLOW_SLOT
    move.b #6, OFF_INTRO_GLOW_T(%a5)
    addq.b #1, OFF_INTRO_GLOW_I(%a5)
    cmp.b #INTRO_GLOW_STEPS, OFF_INTRO_GLOW_I(%a5)
    bne 4f
    move.b #0x10, OFF_INTRO_GLOW_T(%a5)
    clr.b OFF_INTRO_GLOW_I(%a5)
4:  subq.b #1, OFF_INTRO_GLOW_T(%a5)
    bra 8f

    | Sub-phase 1: the fade. A step lasts as long as its delay says; the last one hands over to the story at once.
5:  tst.b OFF_INTRO_FADE_T(%a5)
    bne 7f
    moveq #0, %d0
    move.b OFF_INTRO_FADE(%a5), %d0
    ltab fade_palettes, %a0
    move.w %d0, %d1
    lsl.w #5, %d1
    adda.w %d1, %a0
    bsr intro_set_palette
    ltab fade_delays, %a0
    move.b 0(%a0, %d0.w), OFF_INTRO_FADE_T(%a5)
    addq.b #1, OFF_INTRO_FADE(%a5)
    cmp.b #INTRO_FADE_LAST, OFF_INTRO_FADE(%a5)
    blo 7f
    bra intro_story_begin
7:  subq.b #1, OFF_INTRO_FADE_T(%a5)

8:  bsr intro_waterfall
    bra intro_title_draw

| The waves run down the fall two lines a frame and start again at the top (UpdateSpritesForWaterfallWave).
intro_waterfall:
    lea OFF_INTRO_WAVES(%a5), %a0
    moveq #(INTRO_WAVES - 1), %d1
1:  move.b (%a0), %d0
    addq.b #2, %d0
    cmp.b #INTRO_WAVE_LAST, %d0
    blo 2f
    move.b #INTRO_WAVE_WRAP, %d0
2:  move.b %d0, (%a0)+
    dbra %d1, 1b
    rts

| Put the clean picture back where the waves and the crest were, then draw them and show the screen.
intro_title_draw:
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l #(INTRO_FALL_LINE * INTRO_LINE_BYTES + INTRO_FALL_BYTE), %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l #(INTRO_FALL_LINE * SCREEN_STRIDE + INTRO_SCREEN_LEFT + INTRO_FALL_BYTE), %a1
    moveq #(INTRO_FALL_LINES - 1), %d7
1:  move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    adda.w #(INTRO_LINE_BYTES - 24), %a0
    adda.w #(SCREEN_STRIDE - 24), %a1
    dbra %d7, 1b

    | The crest, then the waves, back to front: the sprite the ROM has first is in front.
    move.w OFF_INTRO_FRAME(%a5), %d0
    andi.w #8, %d0                      | the other picture every 16 frames
    lsr.w #2, %d0                       | 0 or 2
    move.w #CREST_FRAME_0, %d1
    add.w %d0, %d1
    move.w #(INTRO_CREST_Y + 1 - INTRO_WINDOW_TOP), %d3
    bsr intro_title_pair
    moveq #(INTRO_WAVES - 1), %d6
2:  moveq #0, %d4
    lea OFF_INTRO_WAVES(%a5), %a0
    move.b 0(%a0, %d6.w), %d4
    moveq #0, %d0
    cmp.w #0xb9, %d4
    blo 3f
    moveq #2, %d0
    cmp.w #0xc2, %d4
    blo 3f
    moveq #4, %d0
3:  move.w #WAVE_FRAME_0, %d1
    add.w %d0, %d1
    move.w %d4, %d3
    addq.w #1, %d3
    sub.w #INTRO_WINDOW_TOP, %d3
    bsr intro_title_pair
    dbra %d6, 2b
    bra intro_present

| d1.w = the first of two frames side by side, d3.w = the line: draw both at the waterfall.
intro_title_pair:
    move.w #WATERFALL_X, %d2
    bsr intro_draw_frame
    addq.w #1, %d1
    move.w #(WATERFALL_X + 16), %d2
    bra intro_draw_frame

| ------------------------------------------------------------------------------------------------------- the story
intro_story_begin:
    bsr intro_black
    bsr intro_clear_all
    clr.w OFF_INTRO_RING(%a5)
    move.w #INTRO_TOP_START, OFF_INTRO_TOP(%a5)
    clr.w OFF_INTRO_TIMER(%a5)
    clr.w OFF_INTRO_STEP(%a5)
    move.b #1, OFF_INTRO_PHASE(%a5)
    clr.b OFF_INTRO_SUB(%a5)

    | The window's 200 lines as the story starts.
    moveq #0, %d4
    move.w #(INTRO_TOP_START + INTRO_WINDOW_TOP), %d5
1:  move.w %d4, %d0
    bsr intro_ring_slot
    move.w %d5, %d1
    bsr intro_story_line
    addq.w #1, %d5
    addq.w #1, %d4
    cmp.w #INTRO_RING_LINES, %d4
    blo 1b
    ltab story_palette, %a0
    bra intro_set_palette

intro_story_update:
    moveq #0, %d0
    move.b OFF_INTRO_SUB(%a5), %d0
    cmp.b #1, %d0
    beq 20f
    cmp.b #3, %d0
    beq 20f
    cmp.b #4, %d0
    beq 30f

    | The scroll moves on every other frame.
    btst #0, (OFF_INTRO_FRAME + 1)(%a5)
    beq 90f
    cmp.b #2, %d0
    beq 10f

    | Sub-phase 0: the first page comes up from below until it rests at scroll 8 of the next page.
    bsr intro_story_step
    cmp.w #INTRO_TOP_REST, OFF_INTRO_TOP(%a5)
    bne 90f
    move.b #1, OFF_INTRO_SUB(%a5)
    clr.w OFF_INTRO_TIMER(%a5)
    bra 90f

    | Sub-phase 2: the parade scrolls up, to the half page after the fifth.
10: addq.w #1, OFF_INTRO_STEP(%a5)
    cmp.w #INTRO_STEPS, OFF_INTRO_STEP(%a5)
    beq 11f
    bsr intro_story_step
    bra 90f
11: move.b #3, OFF_INTRO_SUB(%a5)
    clr.w OFF_INTRO_TIMER(%a5)
    bra 90f

    | Sub-phases 1 and 3: a wait of 256 frames.
20: addq.w #1, OFF_INTRO_TIMER(%a5)
    cmp.w #INTRO_STORY_WAIT, OFF_INTRO_TIMER(%a5)
    blo 90f
    addq.b #1, OFF_INTRO_SUB(%a5)
    clr.w OFF_INTRO_TIMER(%a5)
    bra 90f

    | Sub-phase 4: a last moment, then the title again.
30: addq.w #1, OFF_INTRO_TIMER(%a5)
    cmp.w #INTRO_STORY_LAST, OFF_INTRO_TIMER(%a5)
    blo 90f
    bra intro_title_begin

    | The screen is built over two frames: the upper part of the window, then the rest and the animated items, shown.
90: moveq #0, %d1
    move.w #INTRO_SPLIT, %d2
    movea.l OFF_SCREEN_PTR(%a5), %a2
    btst #0, (OFF_INTRO_FRAME + 1)(%a5)
    bne intro_copy
    move.w #INTRO_SPLIT, %d1
    move.w #(INTRO_RING_LINES - INTRO_SPLIT), %d2
    bsr intro_copy
    bsr intro_draw_items
    bra intro_present

| One line of scroll: the picture moves up a line, and the line that comes in at the bottom is drawn into the ring in
| the slot the line that left the top had.
intro_story_step:
    movem.l %d0-%d1/%a1, -(%sp)
    addq.w #1, OFF_INTRO_TOP(%a5)
    move.w OFF_INTRO_RING(%a5), %d0
    bsr intro_ring_slot
    addq.w #1, %d0
    cmp.w #INTRO_RING_LINES, %d0
    blo 1f
    moveq #0, %d0
1:  move.w %d0, OFF_INTRO_RING(%a5)
    move.w OFF_INTRO_TOP(%a5), %d1
    add.w #(INTRO_WINDOW_TOP + INTRO_RING_LINES - 1), %d1       | the strip line at the bottom of the window
    bsr intro_story_line
    movem.l (%sp)+, %d0-%d1/%a1
    rts

| The 128 bytes of one line of the story's strip: d1.w = the line, a1 = where it goes (a1 moves on). The rows past the
| story's last are blank.
intro_story_line:
    movem.l %d0-%d2/%a0/%a2, -(%sp)
    move.w %d1, %d2
    lsr.w #3, %d2
    sub.w #STORY_FIRST_ROW, %d2
    blt 8f
    cmp.w #STORY_ROW_COUNT, %d2
    bhs 8f
    move.w %d1, %d0
    andi.w #7, %d0                      | the line in the tile
    add.w %d2, %d2
    ltab story_map, %a0
    move.w 0(%a0, %d2.w), %d2           | the row's offset in story_rows
    ltab story_rows, %a0
    adda.w %d2, %a0
    ltab story_tiles, %a2
    bsr intro_row_line
    bra 9f
8:  moveq #31, %d2
    moveq #0, %d0
7:  move.l %d0, (%a1)+
    dbra %d2, 7b
9:  movem.l (%sp)+, %d0-%d2/%a0/%a2
    suba.w #INTRO_LINE_BYTES, %a1
    bsr intro_overlay_line
    adda.w #INTRO_LINE_BYTES, %a1
    rts

| The treasures that do not move or change are part of the picture: each line of the strip that one of them covers
| gets the matching line of its sprite drawn over it as the line is made.
| d1.w = the strip line, a1 = the start of its 128 bytes in the ring. Nothing changes.
intro_overlay_line:
    movem.l %d0-%d7/%a0-%a3, -(%sp)
    movea.l %a1, %a3
    ltab intro_spawns, %a2
    move.w #(INTRO_SPAWNS - 1), %d6
1:  move.w (%a2)+, %d3                  | the strip line of its top
    move.w (%a2)+, %d2                  | its x
    move.w (%a2)+, %d4                  | its first picture
    tst.w (%a2)+                        | how it animates: only the still ones are in the picture
    bne 9f
    move.w %d1, %d5
    sub.w %d3, %d5                      | the line of the sprite
    blt 9f
    cmp.w #SPRITE_HEIGHT, %d5
    bge 9f
    ltab intro_sprites, %a0
    andi.l #0xffff, %d4
    mulu.w #SPRITE_FRAME_BYTES, %d4
    adda.l %d4, %a0
    mulu.w #SPRITE_ROW_BYTES, %d5
    adda.w %d5, %a0
    movea.l %a3, %a1
    move.w %d2, %d0
    andi.w #15, %d0                     | the shift
    lsr.w #4, %d2
    lsl.w #3, %d2
    adda.w %d2, %a1
    moveq #0, %d7                       | one line
    bsr draw_sprite_rows
9:  dbra %d6, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a3
    rts

| The treasures that flash or flutter are drawn over the hidden screen every frame.
intro_draw_items:
    movem.l %d0-%d7/%a0, -(%sp)
    ltab intro_spawns, %a0
    move.w #(INTRO_SPAWNS - 1), %d7
1:  move.w (%a0)+, %d3                  | the strip line of its top
    move.w (%a0)+, %d2                  | its x
    move.w (%a0)+, %d1                  | its first picture
    move.w (%a0)+, %d4                  | how it animates
    sub.w OFF_INTRO_TOP(%a5), %d3
    sub.w #INTRO_WINDOW_TOP, %d3        | the screen line
    cmp.w #-16, %d3
    ble 9f
    cmp.w #INTRO_RING_LINES, %d3
    bge 9f
    tst.w %d4
    beq 9f                              | (it is in the picture)
    move.w OFF_INTRO_FRAME(%a5), %d5
    cmp.w #KIND_FLASH, %d4
    bne 3f
    lsr.w #3, %d5                       | the flashing ones change every 8 frames
    bra 4f
3:  lsr.w #2, %d5                       | the fairy every 4
4:  andi.w #1, %d5
    add.w %d5, %d1
    bsr intro_draw_frame
9:  dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0
    rts

| ---------------------------------------------------------------------------------------------------------- per frame
| Once a frame in game mode MODE_INTRO.
update_intro:
    addq.w #1, OFF_INTRO_FRAME(%a5)
    cmpi.b #INTRO_PHASE_CREDITS, OFF_INTRO_PHASE(%a5)
    beq credits_update                  | the credits wall (credits.s)
    cmpi.b #INTRO_PHASE_MENU, OFF_INTRO_PHASE(%a5)
    bhs filesel_update                  | the file menu (filesel.s)
    bsr intro_check_start
    tst.b %d0
    bne intro_to_menu
    tst.b OFF_INTRO_PHASE(%a5)
    bne intro_story_update
    bra intro_title_update

| Start: the title song stops and the file menu comes up.
intro_to_menu:
    bsr music_stop_xf
    clr.b OFF_MUS_FORCED(%a5)
    moveq #FILE_SELECT, %d0
    bra filesel_begin
