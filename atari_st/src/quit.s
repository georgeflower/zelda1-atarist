| quit.s - Esc: the question before the game ends, and the How to play page.
|
| Both are pages of MODE_QUIT (QUIT_PAGE): 0 is the Esc question with the keys listed above it, 1 is How to play, which
| the Help key opens while Link walks, and which a new character sees before the first screen (filesel_play: no sword,
| no deaths). The fire button, Return, Enter, Control, Shift, Space, Help or Esc closes it.
|
| Esc used to leave the game at once. Now, while Link is walking about (MODE_PLAY: the overworld or a dungeon room), it
| stops the game and shows three lines on a black screen, the way the inventory does (menu.s):
|
|     QUIT WITHOUT SAVING     back to TOS, the slot as the last save left it
|     SAVE AND QUIT           the game saved as the SAVE choice of the death menu does (save_store_game), then TOS
|     BACK TO GAME            the room as it was (Esc does the same)
|
| Up and Down (or W and S, or the joystick) move the heart; Return, the keypad's Enter, Ctrl, Space or the joystick's button
| choose. The request is the OFF_EXIT_REQUESTED input.s sets on Esc; menu_check_open turns it into the question once the
| sprites are erased (the screen is then a clean room, as the Tab screen needs it), update_menu hands it on when it was
| pressed in the inventory, and a scroll or a cave keeps it until Link is walking again. The title, the story and the death
| screens have nothing to save, and main_loop ends the game there at once.

    .equ QUIT_UP, 1
    .equ QUIT_DOWN, 2
    .equ QUIT_CHOOSE, 4
    .equ QK_W, 0x11
    .equ QK_S, 0x1f
    .equ QK_RETURN, 0x1c
    .equ QK_ENTER, 0x72
    .equ QK_CTRL, 0x1d
    .equ QUIT_LINES, 3
    .equ QUIT_COL, 11                   | the words; the heart stands two cells before them
    .equ QUIT_FIRST_ROW, 17             | below the keys
    .equ QUIT_ROW_STEP, 2

    farstub menu_clear_qf, menu_clear
    farstub exit_program_qf, exit_program

| Help was pressed while Link walks, or a new character starts: How to play (as quit_open).
quit_help_open:
    move.b #1, OFF_QUIT_PAGE(%a5)
    bra 1f

| Esc was pressed while Link walks: the question (called with the hidden screen holding the room, sprites erased).
quit_open:
    clr.b OFF_QUIT_PAGE(%a5)
1:  movem.l %d0-%d2/%a0-%a1, -(%sp)
    clr.b OFF_EXIT_REQUESTED(%a5)
    clr.b OFF_HELP_REQUESTED(%a5)
    move.b #MODE_QUIT, OFF_GAME_MODE(%a5)
    clr.b OFF_QUIT_SEL(%a5)
    bsr quit_read_keys
    move.b %d0, OFF_QUIT_KEYS(%a5)      | a key that is still down from before does not choose
    bsr menu_clear_qf                   | (the hidden screen, if the game draws double-buffered)
    bsr quit_draw
    bsr dbl_end_df                      | show it
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| The keys that count, as bits: QUIT_UP, QUIT_DOWN, QUIT_CHOOSE. Returns d0.b.
quit_read_keys:
    movem.l %d1/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    moveq #0, %d0
    move.b OFF_JOY0(%a5), %d1
    or.b OFF_JOY1(%a5), %d1
    tst.b SCAN_UP(%a0)
    bne 1f
    tst.b QK_W(%a0)
    bne 1f
    btst #0, %d1
    beq 2f
1:  or.b #QUIT_UP, %d0
2:  tst.b SCAN_DOWN(%a0)
    bne 3f
    tst.b QK_S(%a0)
    bne 3f
    btst #1, %d1
    beq 4f
3:  or.b #QUIT_DOWN, %d0
4:  tst.b QK_RETURN(%a0)
    bne 5f
    tst.b QK_ENTER(%a0)
    bne 5f
    tst.b QK_CTRL(%a0)
    bne 5f
    tst.b SCAN_SPACE(%a0)
    bne 5f
    btst #7, %d1
    beq 6f
5:  or.b #QUIT_CHOOSE, %d0
6:  movem.l (%sp)+, %d1/%a0
    rts

| Every frame while the question is up.
update_quit:
    movem.l %d0-%d2/%a0, -(%sp)
    tst.b OFF_EXIT_REQUESTED(%a5)       | Esc again: back to the game
    bne 0f
    tst.b OFF_QUIT_PAGE(%a5)
    beq 1f
    tst.b OFF_HELP_REQUESTED(%a5)       | How to play: Help again closes it too
    bne 0f
1:  clr.b OFF_HELP_REQUESTED(%a5)
    bsr quit_read_keys
    move.b OFF_QUIT_KEYS(%a5), %d1
    move.b %d0, OFF_QUIT_KEYS(%a5)
    not.b %d1
    and.b %d1, %d0                      | the keys that went down this frame
    tst.b OFF_QUIT_PAGE(%a5)
    beq 10f
    btst #2, %d0                        | How to play: a choosing key closes it
    beq 9f
0:  bsr quit_close
    bra 9f
10:
    move.b OFF_QUIT_SEL(%a5), %d2
    btst #0, %d0
    beq 2f
    subq.b #1, %d2
    bpl 2f
    moveq #(QUIT_LINES - 1), %d2
2:  btst #1, %d0
    beq 3f
    addq.b #1, %d2
    cmp.b #QUIT_LINES, %d2
    blo 3f
    moveq #0, %d2
3:  cmp.b OFF_QUIT_SEL(%a5), %d2
    beq 4f
    move.b %d2, OFF_QUIT_SEL(%a5)
    bsr quit_draw_hearts
4:  btst #2, %d0
    beq 9f
    tst.b %d2
    beq quit_leave                      | QUIT WITHOUT SAVING
    cmp.b #1, %d2
    bne 5f
    moveq #0, %d0                       | SAVE AND QUIT
    move.b OFF_PROFILE(%a5), %d0
    bsr save_store_game
    bra quit_leave
5:  bsr quit_close                      | BACK TO GAME
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

quit_leave:
    bsr exit_program_qf                 | (it does not come back)

| The room again, as menu_close puts it back.
quit_close:
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    clr.b OFF_EXIT_REQUESTED(%a5)
    clr.b OFF_HELP_REQUESTED(%a5)
    bsr menu_clear_qf
    bsr show_background_df
    bsr clear_erase_state_df
    move.b #1, OFF_HUD_DIRTY(%a5)
    rts

| The page: its lines, and for the question the three choices and the heart.
quit_draw:
    movem.l %d0-%d2/%a0, -(%sp)
    ltab quit_keys_page, %a0
    tst.b OFF_QUIT_PAGE(%a5)
    beq 1f
    ltab quit_help_page, %a0
1:  moveq #0, %d2
    move.b (%a0)+, %d2                  | each line: its row, its column, the text
    bmi 2f
    moveq #0, %d1
    move.b (%a0)+, %d1
    bsr text_draw
    bra 1b
2:  tst.b OFF_QUIT_PAGE(%a5)
    beq 3f
    movem.l (%sp)+, %d0-%d2/%a0
    rts
3:  lea quit_text(%pc), %a0
    moveq #QUIT_FIRST_ROW, %d2
    moveq #(QUIT_LINES - 1), %d0
1:  moveq #QUIT_COL, %d1
    bsr text_draw                       | (leaves a0 at the next line)
    addq.w #QUIT_ROW_STEP, %d2
    dbra %d0, 1b
    movem.l (%sp)+, %d0-%d2/%a0
    bra quit_draw_hearts

| The heart on the line chosen, a blank on the others.
quit_draw_hearts:
    movem.l %d0-%d3, -(%sp)
    moveq #0, %d3
1:  moveq #HUD_BLANK, %d0
    cmp.b OFF_QUIT_SEL(%a5), %d3
    bne 2f
    moveq #HUD_HEART_FULL, %d0
2:  moveq #(QUIT_COL - 2), %d1
    move.w %d3, %d2
    mulu.w #QUIT_ROW_STEP, %d2
    add.w #QUIT_FIRST_ROW, %d2
    bsr draw_hud_tile_df
    addq.w #1, %d3
    cmp.w #QUIT_LINES, %d3
    blo 1b
    movem.l (%sp)+, %d0-%d3
    rts

| a0 = a string of capitals, digits, spaces and commas ending in 0, d1.w = the column, d2.w = the row (of the 8x8 cells of the whole
| screen): the letters of the status ribbon (the ROM's own codes, through text_glyphs), drawn on the screen being drawn to. Keeps every
| register but a0 (past the 0).
text_draw:
    movem.l %d0-%d1/%a1, -(%sp)
    ltab text_glyphs, %a1
1:  moveq #0, %d0
    move.b (%a0)+, %d0
    beq 9f
    cmp.b #0x20, %d0
    bne 2f
    moveq #0x24, %d0                    | the ROM's code for a space
    bra 4f
2:  cmp.b #0x2c, %d0                    | ","
    bne 5f
    moveq #0x28, %d0                    | the ROM's comma
    bra 4f
5:  cmp.b #0x41, %d0                    | "A"
    blo 3f
    sub.b #(0x41 - 0x0a), %d0           | the ROM's codes: the letters follow the digits
    bra 4f
3:  sub.b #0x30, %d0
4:  move.b 0(%a1, %d0.w), %d0           | and the ribbon's tile for the code
    bsr draw_hud_tile_df
    addq.w #1, %d1
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%a1
    rts

| The pages: row, column, text; $FF ends. Rows and columns are the 8x8 cells of the screen (40 x 25). They sit in .rodata,
| behind the code, where they cost the 16-bit reach of the code nothing (ltab reaches them).
    .section .rodata
quit_keys_page:
    .byte 1, 17
    .asciz "PAUSED"
    .byte 4, 5
    .asciz "WALK"
    .byte 4, 17
    .asciz "ARROWS, WASD, STICK"
    .byte 6, 5
    .asciz "SWORD"
    .byte 6, 17
    .asciz "FIRE, CTRL, SHIFT"
    .byte 8, 5
    .asciz "USE ITEM"
    .byte 8, 17
    .asciz "SPACE, ALT"
    .byte 10, 5
    .asciz "INVENTORY"
    .byte 10, 17
    .asciz "TAB"
    .byte 12, 5
    .asciz "CHOOSE"
    .byte 12, 17
    .asciz "ENTER, FIRE"
    .byte 14, 5
    .asciz "HELP PAGE"
    .byte 14, 17
    .asciz "HELP"
    .byte 0xff
quit_help_page:
    .byte 2, 14
    .asciz "HOW TO PLAY"
    .byte 5, 5
    .asciz "WALK"
    .byte 5, 17
    .asciz "ARROWS, W A S D"
    .byte 6, 17
    .asciz "OR THE JOYSTICK"
    .byte 8, 5
    .asciz "SWORD"
    .byte 8, 17
    .asciz "FIRE, CTRL, SHIFT"
    .byte 10, 5
    .asciz "USE ITEM"
    .byte 10, 17
    .asciz "SPACE, ALT"
    .byte 12, 5
    .asciz "INVENTORY"
    .byte 12, 17
    .asciz "TAB"
    .byte 13, 17
    .asciz "LEFT, RIGHT PICK"
    .byte 15, 5
    .asciz "CHOOSE"
    .byte 15, 17
    .asciz "ENTER, FIRE"
    .byte 17, 5
    .asciz "SAVE, QUIT"
    .byte 17, 17
    .asciz "ESC"
    .byte 19, 5
    .asciz "THIS PAGE"
    .byte 19, 17
    .asciz "HELP"
    .byte 22, 15
    .asciz "PRESS FIRE"
    .byte 0xff
    .even
    .section .text
quit_text:
    .asciz "QUIT WITHOUT SAVING"
    .asciz "SAVE AND QUIT"
    .asciz "BACK TO GAME"
    .even
