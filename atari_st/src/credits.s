| The credits wall: the scroll that ends the game (Z_02.asm UpdateMode13WinGame_Sub3 and Sub4).
|
| After Zelda's last words the screen scrolls up one line every other frame, 600 lines (CreditsLastVscrollList), and the
| wall of bricks with the staff in it goes by: "STAFF", the names, "ANOTHER QUEST WILL START FROM HERE.", "PRESS THE START
| BUTTON." and the copyright. Then the black screen with the ash pile of Ganon and the Triforce of Power stays. Start
| goes back to the title (the Second Quest, where the ROM goes, is not in this port).
|
| It works like the story of the intro (intro.s): a ring of 200 lines holds the window, and a line of the strip
| (tools/credits.py) is drawn into it for each line of scroll. The ending song is still playing when it begins: it is
| an event song, so it goes on in MODE_INTRO. Phase INTRO_PHASE_CREDITS of OFF_INTRO_PHASE; OFF_INTRO_SUB 0 builds the
| first window, 1 scrolls, 2 is the last screen.

    .equ INTRO_PHASE_CREDITS, 4
    .equ CREDITS_STEPS, 600
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
    bra credits_to_title
1:  btst #0, (OFF_INTRO_FRAME + 1)(%a5)
    beq 90f
    bsr credits_step                    | the picture moves up a line, on every other frame
    addq.w #1, OFF_INTRO_STEP(%a5)
    cmp.w #CREDITS_STEPS, OFF_INTRO_STEP(%a5)
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
    bsr dbl_end_far                     | what is on show stays on show; no hidden buffer of the game
    bsr swap_screens_far                | the intro's way with the buffers: SCREEN_PTR is the hidden one
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
    bsr set_video_base_far
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
    movem.l %d0-%d2/%a0/%a2, -(%sp)
    move.w %d1, %d2
    lsr.w #3, %d2
    cmp.w #CREDITS_ROWS, %d2
    bhs 8f
    move.w %d1, %d0
    andi.w #7, %d0                      | the line in the tile
    add.w %d2, %d2
    ltab credits_map, %a0
    move.w 0(%a0, %d2.w), %d2           | the row's offset in credits_rows
    ltab credits_rows, %a0
    adda.w %d2, %a0
    ltab credits_tiles, %a2
    bsr intro_row_line
    bra 9f
8:  moveq #31, %d2
    moveq #0, %d0
7:  move.l %d0, (%a1)+
    dbra %d2, 7b
9:  movem.l (%sp)+, %d0-%d2/%a0/%a2
    rts

| Start on the last screen: the title again, with its song.
credits_to_title:
    bsr music_stop_far
    clr.b OFF_MUS_FORCED(%a5)
    bsr intro_title_begin
    moveq #MUS_TITLE, %d0
    bra music_event_far
