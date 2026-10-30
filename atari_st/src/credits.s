| The credits wall: the scroll that ends the game (Z_02.asm UpdateMode13WinGame_Sub3 and Sub4).
|
| After Zelda's last words the screen scrolls up one line every other frame, 600 lines (CreditsLastVscrollList; 720 in the
| Second Quest, whose credits are another strip, with the player's name and death count in it), and the wall of bricks
| with the staff in it goes by: "STAFF", the names, "ANOTHER QUEST WILL START FROM HERE.", "PRESS THE START BUTTON." and
| the copyright. Then the black screen with the ash pile of Ganon and the Triforce of Power stays. Start goes to the file
| menu with the profile reset to a Second Quest one, as the ROM does (after a Second Quest it starts that again).
|
| It works like the story of the intro (intro.s): a ring of 200 lines holds the window, and a line of the strip
| (tools/credits.py) is drawn into it for each line of scroll. The ending song is still playing when it begins: it is
| an event song, so it goes on in MODE_INTRO. Phase INTRO_PHASE_CREDITS of OFF_INTRO_PHASE; OFF_INTRO_SUB 0 builds the
| first window, 1 scrolls, 2 is the last screen.

| Far calls of the late modules (intro, credits, filesel, death, save): 32-bit stubs, because main.s's *_far stubs are more than 32 KB
| from the end of the code. One block, in the middle of them.
    farstub begin_game_xf, begin_game
    farstub cur_palette_xf, cur_palette
    farstub dbl_end_xf, dbl_end
    farstub draw_hud_tile_ptr_xf, draw_hud_tile_ptr
    farstub music_event_xf, music_event
    farstub music_play_xf, music_play
    farstub music_stop_xf, music_stop
    farstub present_frame_xf, present_frame
    farstub set_video_base_xf, set_video_base
    farstub swap_screens_xf, swap_screens

    .equ INTRO_PHASE_CREDITS, 4
    .equ CREDITS_STEPS, 600
    .equ CREDITS_STEPS2, 720              | the Second Quest's CreditsLastScreenList / CreditsLastVscrollList: 3 * 240
    .equ CREDITS_NAME_CELL, 9             | the name's eight tiles in line $11, and the death count's three
    .equ CREDITS_DEATH_CELL, 19
    .equ CREDITS_GLYPHS, 0x30
    .equ CREDITS_START_WAIT, 0x40         | ObjTimer of Sub4: the player cannot skip ahead for $40 frames
    .equ CREDITS_ASH_X, 0x78
    .equ CREDITS_ASH_LINE, (0x88 + 1 - INTRO_WINDOW_TOP)    | sprites are drawn a line below their Y

| Zelda's scene is over (bosses.s zelda_tick runs inside the game's own frame, so the work waits for the next).
credits_begin:
    move.b #MODE_INTRO, OFF_GAME_MODE(%a5)
    move.b #INTRO_PHASE_CREDITS, OFF_INTRO_PHASE(%a5)
    clr.b OFF_INTRO_SUB(%a5)
    move.b #1, OFF_INTRO_KEYS(%a5)      | a Start that is still down does not count
    rts

| Once a frame in MODE_INTRO, phase INTRO_PHASE_CREDITS (from update_intro).
credits_update:
    move.b OFF_INTRO_SUB(%a5), %d0
    beq credits_init
    cmp.b #2, %d0
    bne 1f
    cmp.w #CREDITS_START_WAIT, OFF_INTRO_TIMER(%a5)     | the last screen: Start leaves, after a moment
    bhs 2f
    addq.w #1, OFF_INTRO_TIMER(%a5)
    bra 90f
2:  bsr intro_check_start
    tst.b %d0
    beq 90f
    bra credits_to_menu
1:  btst #0, (OFF_INTRO_FRAME + 1)(%a5)
    beq 90f
    bsr credits_step                    | the picture moves up a line, on every other frame
    addq.w #1, OFF_INTRO_STEP(%a5)
    move.w #CREDITS_STEPS, %d0
    tst.b OFF_QUEST(%a5)
    beq 3f
    move.w #CREDITS_STEPS2, %d0
3:  cmp.w OFF_INTRO_STEP(%a5), %d0
    bne 90f
    move.b #2, OFF_INTRO_SUB(%a5)       | and stops
    clr.w OFF_INTRO_TIMER(%a5)

    | The screen is built over two frames, as the story's: the upper part of the window, then the rest and the sprites.
90: moveq #0, %d1
    move.w #INTRO_SPLIT, %d2
    movea.l OFF_SCREEN_PTR(%a5), %a2
    btst #0, (OFF_INTRO_FRAME + 1)(%a5)
    bne intro_copy
    move.w #INTRO_SPLIT, %d1
    move.w #(INTRO_RING_LINES - INTRO_SPLIT), %d2
    bsr intro_copy
    cmpi.b #2, OFF_INTRO_SUB(%a5)
    bne intro_present
    bsr credits_last_sprites
    bra intro_present

| The black screen with what is left of Ganon and the Triforce of Power, which flashes.
credits_last_sprites:
    movem.l %d0-%d3, -(%sp)
    move.w #CREDITS_FRAME_ASH, %d1
    move.w #CREDITS_ASH_X, %d2
    move.w #CREDITS_ASH_LINE, %d3
    bsr intro_draw_frame
    move.w #CREDITS_FRAME_TRIFORCE, %d1
    move.w OFF_INTRO_FRAME(%a5), %d0
    lsr.w #3, %d0                       | the flashing ones change every 8 frames
    andi.w #1, %d0
    add.w %d0, %d1
    bsr intro_draw_frame
    movem.l (%sp)+, %d0-%d3
    rts

| The first window: the black room with what Zelda said, both screens, and the colours of the ending.
credits_init:
    bsr intro_data_f                    | the credits' pictures replace the dungeon in the buffer
    tst.b OFF_QUEST(%a5)
    beq 2f
    bsr credits_name                    | the Second Quest's line with the player's name and death count
2:  bsr credits_save                    | the win is on the disk before the first line scrolls
    bsr dbl_end_xf                     | what is on show stays on show; no hidden buffer of the game
    bsr swap_screens_xf                | the intro's way with the buffers: SCREEN_PTR is the hidden one
    bsr intro_black
    bsr intro_clear_all
    clr.w OFF_INTRO_RING(%a5)
    clr.w OFF_INTRO_TOP(%a5)
    clr.w OFF_INTRO_STEP(%a5)
    moveq #0, %d4
    move.w #INTRO_WINDOW_TOP, %d5
1:  move.w %d4, %d0
    bsr intro_ring_slot
    move.w %d5, %d1
    bsr credits_line
    addq.w #1, %d5
    addq.w #1, %d4
    cmp.w #INTRO_RING_LINES, %d4
    blo 1b
    moveq #0, %d1
    move.w #INTRO_RING_LINES, %d2
    movea.l OFF_SCREEN_PTR(%a5), %a2
    bsr intro_copy
    movea.l OFF_BG_NEXT(%a5), %a2
    bsr intro_copy
    move.l OFF_BG_NEXT(%a5), %d0
    bsr set_video_base_xf
    move.b #1, OFF_INTRO_SUB(%a5)
    ltab credits_palette, %a0
    bra intro_set_palette

| One line of scroll (intro_story_step's way): the window moves down the strip, and the line that comes in at the bottom
| goes into the slot of the one that left the top.
credits_step:
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
    bsr credits_line
    movem.l (%sp)+, %d0-%d1/%a1
    rts

| The 128 bytes of one line of the credits' strip: d1.w = the line, a1 = where it goes (a1 moves on). Rows past the
| strip's last are blank.
credits_line:
    movem.l %d0-%d3/%a0/%a2, -(%sp)
    move.w %d1, %d2
    lsr.w #3, %d2
    tst.b OFF_QUEST(%a5)
    bne 5f
    cmp.w #CREDITS_ROWS, %d2
    bhs 8f
    ivtab credits_map, %a0
    bra 6f
5:  cmp.w #CREDITS_ROWS2, %d2
    bhs 8f
    ivtab credits_map2, %a0
6:  move.w %d1, %d0
    andi.w #7, %d0                      | the line in the tile
    add.w %d2, %d2
    move.w 0(%a0, %d2.w), %d2           | the row's offset in credits_rows
    ivtab credits_rows, %a0
    tst.b OFF_QUEST(%a5)
    beq 4f
    ivtab credits_rows2, %a0
4:  adda.w %d2, %a0
    ivtab credits_tiles, %a2
    bsr intro_row_line
    bra 9f
8:  moveq #31, %d2
    moveq #0, %d0
7:  move.l %d0, (%a1)+
    dbra %d2, 7b
9:  movem.l (%sp)+, %d0-%d3/%a0/%a2
    rts

| The Second Quest's line $11 holds the player's name (eight tiles from cell 9) and death count (three from cell 19, leading
| zeros blank), which the ROM puts in as it draws the line. The strip has the line blank; the cells of its row are patched here,
| from glyphs of the name's colours (credits_glyphs: a tile offset for each NES code below $30).
credits_name:
    movem.l %d0-%d5/%a0-%a4, -(%sp)
    ivtab credits_map2, %a0
    move.w (CREDITS_NAME_ROW * 2)(%a0), %d0
    ivtab credits_rows2, %a1
    adda.w %d0, %a1                     | the row's 32 cells
    ivtab credits_glyphs, %a2
    moveq #0, %d4
    move.b OFF_PROFILE(%a5), %d4
    move.w %d4, %d5
    lsl.w #3, %d5
    lea OFF_SLOT_NAMES(%a5), %a3
    adda.w %d5, %a3
    lea (CREDITS_NAME_CELL * 2)(%a1), %a4
    moveq #7, %d1
1:  moveq #0, %d0
    move.b (%a3)+, %d0
    cmp.w #CREDITS_GLYPHS, %d0
    blo 2f
    moveq #0x24, %d0                    | a tile the picture has no glyph for is a space
2:  add.w %d0, %d0
    move.w 0(%a2, %d0.w), (%a4)+
    dbra %d1, 1b
    lea OFF_SLOT_DEATHS(%a5), %a3       | FormatDecimalByte: three digits, leading zeros blank
    moveq #0, %d0
    move.b 0(%a3, %d4.w), %d0
    divu.w #100, %d0
    move.w %d0, %d2                     | hundreds
    swap %d0
    andi.l #0xFFFF, %d0
    divu.w #10, %d0
    move.w %d0, %d3                     | tens
    swap %d0                            | ones
    tst.w %d2
    bne 3f
    moveq #0x24, %d2
    tst.w %d3
    bne 3f
    moveq #0x24, %d3
3:  lea (CREDITS_DEATH_CELL * 2)(%a1), %a4
    add.w %d2, %d2
    move.w 0(%a2, %d2.w), (%a4)+
    add.w %d3, %d3
    move.w 0(%a2, %d3.w), (%a4)+
    add.w %d0, %d0
    move.w 0(%a2, %d0.w), (%a4)+
    movem.l (%sp)+, %d0-%d5/%a0-%a4
    rts

| Start on the last screen (UpdateMode13WinGame_Sub4): the ROM silences everything, turns the profile into a Second Quest one
| (SwitchProfileToSecondQuest: the world flags and the items cleared, three full hearts, eight bombs, the quest number 1),
| saves it as mode D does and goes to mode 0 submode 1, the file menu, without the title and its demo (that is what
| SkippedDemo is for). The Second Quest itself is not in this port: the slot starts the First Quest afresh.
credits_to_menu:
    bsr music_stop_xf
    clr.b OFF_MUS_FORCED(%a5)
    bsr credits_save                    | (done when the credits began; again, in case a development build skipped it)
    lea OFF_SLOT_ACTIVE(%a5), %a0       | the two options are always on (a development build never read the file)
    move.b #1, 3(%a0)
    move.b #1, 4(%a0)
    moveq #FILE_SELECT, %d0
    bra filesel_begin

| The game is won: the profile becomes a Second Quest one (SwitchProfileToSecondQuest: the world flags and the items cleared,
| three hearts, eight bombs, quest number 1) and goes to ZELDA.SAV. The ROM saves when Start is pressed (mode D); here it is
| done as the credits begin, so that quitting during them (or a crash) cannot lose the win. The credits themselves read
| OFF_QUEST (the quest that was played), the name and the death count, none of which this changes.
credits_save:
    bsr save_world_reset                | the screens as the ROM made them
    bsr save_fields_clear               | the items and the flags of the world
    move.b #3, OFF_HEART_CONTAINERS(%a5)
    move.b #8, OFF_MAX_BOMBS(%a5)
    moveq #0, %d0
    move.b OFF_PROFILE(%a5), %d0
    lea OFF_SLOT_QUEST(%a5), %a0
    move.b #1, 0(%a0, %d0.w)
    bra save_store_game                 | the hearts filled, the record written (a slot that is not in use is left alone)
