| The file menu: player select (game mode 1 of the ROM), register your name (mode E) and elimination mode (mode F),
| Z_02.asm. Start on the title brings it up (intro.s).
|
| player select   three slots with their names, hearts and death counts, each with a Link beside it (the Second Quest's
|                 sword in his hand when the name was ZELDA); a heart marks the choice. Select (Tab) moves it on over the
|                 slots that are in use and the two options below them, REGISTER YOUR NAME and ELIMINATION MODE; Start
|                 (Return) takes the choice: a slot starts the game, the options bring up the other two screens. The
|                 arrow keys move the heart too, and the joystick's button is Start here.
| register        the slots that are free have a name field. The letters of the board (arrows, with the ROM's repeat
|                 timing: $10 frames before the first repeat, 8 after) go into the name with A (Space); B (Ctrl, Alt)
|                 skips a letter; Select moves on to the next free slot and finally END; Start on END makes every
|                 free slot with a name a profile of 3 hearts (the name ZELDA is the Second Quest) and goes back.
| elimination     Select moves over all the slots and END; Start on a slot deletes it, on END it is back to REGISTER.
|
| tools/filesel.py makes the pictures (tile cells of the ROM's nametables), the glyphs the menu writes into them and the
| sprites. The picture is drawn into the hidden screen (SCREEN_PTR), which stays as it is: the clean copy; the same picture
| is on show (BG_NEXT), with the text, the heart and the block cursors on it. Whatever moves is put back from the clean
| copy first. The slots live in the variable block (SLOT_*); save.s keeps them in ZELDA.SAV.
|
| continue       the question after a death (game mode 8, FILE_CONTINUE): CONTINUE, SAVE and RETRY with a heart beside the
|                 choice (Select, Down and Up move it); Start or A makes the word flash for FILE_FLASH_FRAMES, then death.s
|                 carries it out.

    .equ INTRO_PHASE_MENU, 2              | INTRO_PHASE for the file menu: update_intro hands the frame to filesel_update

    .equ FILE_SELECT, 0
    .equ FILE_REGISTER, 1
    .equ FILE_ELIMINATE, 2
    .equ FILE_CONTINUE, 3                 | the question after a death (game mode 8): CONTINUE, SAVE or RETRY
    .equ FILE_END, 3                      | the fourth choice: REGISTER YOUR NAME on the select screen, END on the others

    .equ BTN_RIGHT, 0x01                  | the buttons as the NES reads them: ButtonsDown
    .equ BTN_LEFT, 0x02
    .equ BTN_DOWN, 0x04
    .equ BTN_UP, 0x08
    .equ BTN_START, 0x10
    .equ BTN_SELECT, 0x20
    .equ BTN_B, 0x40
    .equ BTN_A, 0x80

    .equ FILE_NAME_X, 0x70                | the name cursor's x on the first character (ModeEandF_SetUpCursorSprites)
    .equ FILE_BOARD_FIRST_X, 0x30
    .equ FILE_BOARD_FIRST_Y, 0x87
    .equ FILE_BOARD_RIGHT_END, 0xe0       | ModeE_HandleDirectionButton
    .equ FILE_BOARD_LEFT_END, 0x20
    .equ FILE_BOARD_CELLS, 0x2c           | 11 columns, 4 rows
    .equ FILE_BOARD_COLS, 11
    .equ FILE_FIRST_REPEAT, 0x10          | frames before a held direction repeats, then 8
    .equ FILE_REPEAT, 8
    .equ FILE_FLASH_FRAMES, 64            | the word chosen on the continue question flashes for $40 frames
    .equ FILE_CONT_WORD_BYTES, 11         | column, row, length and eight tiles
    .equ FILE_NEW_HEARTS, 0x22            | a new profile: 3 heart containers, all of them full (RegisterEnd: STA ($C0), Y)
    .equ FILE_NEW_PARTIAL, 0xff

| ----------------------------------------------------------------------------------------------------- the slots
| All three slots empty: the names are spaces, REGISTER and ELIMINATION can always be chosen.
filesel_reset_slots:
    movem.l %d0/%a0, -(%sp)
    lea OFF_SLOT_NAMES(%a5), %a0
    moveq #23, %d0
1:  move.b #FILE_BLANK_TILE, (%a0)+
    dbra %d0, 1b
    lea OFF_SLOT_ACTIVE(%a5), %a0
    clr.b (%a0)+
    clr.b (%a0)+
    clr.b (%a0)+
    move.b #1, (%a0)+
    move.b #1, (%a0)+
    lea OFF_SLOT_HEARTS(%a5), %a0
    clr.w (%a0)+
    clr.w (%a0)+
    clr.w (%a0)+
    clr.b OFF_PROFILE(%a5)
    moveq #2, %d0
    lea OFF_SLOT_DEATHS(%a5), %a0
1:  clr.b (%a0)+
    dbra %d0, 1b
    moveq #2, %d0
    lea OFF_SLOT_QUEST(%a5), %a0
1:  clr.b (%a0)+
    dbra %d0, 1b
    moveq #2, %d0
    lea OFF_SLOT_RING(%a5), %a0
1:  clr.b (%a0)+
    dbra %d0, 1b
    movem.l (%sp)+, %d0/%a0
    rts

| The slot d0.w is as FormatFileA leaves a file: no name, no hearts, no deaths, the first quest.
file_clear_slot:
    movem.l %d0-%d1/%a0, -(%sp)
    andi.l #0xffff, %d0
    lea OFF_SLOT_ACTIVE(%a5), %a0
    clr.b 0(%a0, %d0.l)
    lea OFF_SLOT_DEATHS(%a5), %a0
    clr.b 0(%a0, %d0.l)
    lea OFF_SLOT_QUEST(%a5), %a0
    clr.b 0(%a0, %d0.l)
    lea OFF_SLOT_RING(%a5), %a0
    clr.b 0(%a0, %d0.l)
    move.w %d0, %d1
    add.w %d1, %d1
    lea OFF_SLOT_HEARTS(%a5), %a0
    clr.b 0(%a0, %d1.w)
    clr.b 1(%a0, %d1.w)
    lsl.w #3, %d0
    lea OFF_SLOT_NAMES(%a5), %a0
    adda.w %d0, %a0
    moveq #7, %d1
1:  move.b #FILE_BLANK_TILE, (%a0)+
    dbra %d1, 1b
    movem.l (%sp)+, %d0-%d1/%a0
    rts

| ----------------------------------------------------------------------------------------------------- the buttons
| d0.b = the buttons that are down, laid out as the NES has them. A is Space or the joystick's button, B is Ctrl or Alt,
| Start is Return, Select is Tab; the arrows (and W, A, S, D) and the joystick are the direction pad.
    .macro file_key scan, bit
    tst.b \scan(%a0)
    beq 1f
    ori.b #\bit, %d0
1:
    .endm

file_buttons:
    movem.l %d1/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    moveq #0, %d0
    file_key SCAN_RIGHT, BTN_RIGHT
    file_key SCAN_D, BTN_RIGHT
    file_key SCAN_LEFT, BTN_LEFT
    file_key SCAN_A, BTN_LEFT
    file_key SCAN_DOWN, BTN_DOWN
    file_key SCAN_S, BTN_DOWN
    file_key SCAN_UP, BTN_UP
    file_key SCAN_W, BTN_UP
    file_key SCAN_RETURN, BTN_START
    file_key SCAN_KEYPAD_ENTER, BTN_START
    file_key SCAN_TAB, BTN_SELECT
    file_key SCAN_SPACE, BTN_A
    file_key SCAN_CTRL, BTN_B
    file_key SCAN_ALT, BTN_B
    move.b OFF_JOY0(%a5), %d1
    or.b OFF_JOY1(%a5), %d1
    btst #0, %d1
    beq 1f
    ori.b #BTN_UP, %d0
1:  btst #1, %d1
    beq 2f
    ori.b #BTN_DOWN, %d0
2:  btst #2, %d1
    beq 3f
    ori.b #BTN_LEFT, %d0
3:  btst #3, %d1
    beq 4f
    ori.b #BTN_RIGHT, %d0
4:  tst.b %d1
    bpl 5f
    ori.b #BTN_A, %d0
5:  movem.l (%sp)+, %d1/%a0
    rts

| FILE_DOWN and FILE_PRESSED (what went down since the last frame), the way ButtonsPressed is.
file_read_buttons:
    move.l %d1, -(%sp)
    bsr file_buttons
    move.b OFF_FILE_DOWN(%a5), %d1
    move.b %d0, OFF_FILE_DOWN(%a5)
    not.b %d1
    and.b %d0, %d1
    move.b %d1, OFF_FILE_PRESSED(%a5)
    move.l (%sp)+, %d1
    rts

file_click:
    moveq #SFX_RUPEE, %d0               | Tune1Request = 1: the tune of a rupee taken
    bra music_play_far

| ------------------------------------------------------------------------------------------------------- the text
| One 8x8 tile of the menu's font into both screens: d0.b = the NES tile number, d1.w = column, d2.w = row (the ST
| screen's grid of 8x8 cells), d3.w = the style (0 the text's palette row, 1 the hearts'). Nothing changes.
file_glyph:
    movem.l %d0-%d3/%a0-%a1, -(%sp)
    ltab file_glyphs, %a0
    andi.w #0xff, %d0
    add.w %d0, %d0
    tst.w %d3
    beq 1f
    adda.w #FILE_GLYPH_STYLE_BYTES, %a0
1:  move.w 0(%a0, %d0.w), %d0
    ltab file_tiles, %a0
    adda.w %d0, %a0
    move.l OFF_SCREEN_PTR(%a5), -(%sp)
    bsr draw_hud_tile_ptr_far            | the clean copy
    move.l OFF_BG_NEXT(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile_ptr_far            | and the screen on show
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
    movem.l (%sp)+, %d0-%d3/%a0-%a1
    rts


| The tile of the heart slot d6.w of a slot's hearts (FormatHeartsInTextBuf): slot 0 is the end of the top row, 8 the
| end of the bottom row, and the hearts the player has fill from the first of the bottom row. d4.b = the hearts value
| (containers less one in the top nibble, full hearts less one in the bottom one), d5.b = the partial heart.
| Returns d0.b = the tile.
file_heart_tile:
    movem.l %d1-%d2, -(%sp)
    moveq #FILE_BLANK_TILE, %d0
    tst.b %d4
    beq 9f
    moveq #0, %d1
    move.b %d4, %d1
    lsr.w #4, %d1
    moveq #15, %d2
    sub.w %d1, %d2                      | $F less the containers: the first slot with a heart
    cmp.w %d2, %d6
    blo 9f
    moveq #15, %d2
    moveq #15, %d1
    and.b %d4, %d1
    sub.w %d1, %d2                      | $F less the hearts: where the partial heart is
    moveq #FILE_HEART_EMPTY, %d0
    cmp.w %d2, %d6
    bhi 7f                              | past it the hearts are full
    blo 9f                              | before it they are empty
    tst.b %d5
    beq 9f
    cmp.b #0x80, %d5
    bhs 7f
    moveq #FILE_HEART_HALF, %d0
    bra 9f
7:  move.b #FILE_HEART_FULL, %d0
9:  movem.l (%sp)+, %d1-%d2
    rts

| The row of the first line of slot d7.w on the select screen, in d2.w.
file_slot_row:
    move.w %d7, %d2
    mulu.w #3, %d2
    add.w #FILE_SEL_NAME_ROW, %d2
    rts

| A slot's two lines on the select screen: the name, a dash and the hearts, and under the name the death count
| (InitMode1_FillAndTransferSlotTiles, InitMode1_Sub6). d0.w = the slot.
file_slot_line:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    move.w %d0, %d7
    bsr file_slot_row
    movea.w %d2, %a1                    | a1 keeps the row of the name
    lea OFF_SLOT_NAMES(%a5), %a0
    move.w %d7, %d0
    lsl.w #3, %d0
    adda.w %d0, %a0
    move.w #FILE_SEL_NAME_COL, %d1
    moveq #0, %d3
    moveq #7, %d6
1:  move.b (%a0)+, %d0
    bsr file_glyph
    addq.w #1, %d1
    dbra %d6, 1b
    move.b #FILE_DASH_TILE, %d0
    bsr file_glyph

    move.w %d7, %d0
    add.w %d0, %d0
    lea OFF_SLOT_HEARTS(%a5), %a0
    moveq #0, %d4
    move.b 0(%a0, %d0.w), %d4
    moveq #0, %d5
    move.b 1(%a0, %d0.w), %d5
    moveq #1, %d3
    moveq #0, %d6
2:  bsr file_heart_tile
    cmp.w #8, %d6
    bhs 3f
    moveq #7, %d1
    sub.w %d6, %d1
    move.w %a1, %d2
    bra 4f
3:  moveq #15, %d1
    sub.w %d6, %d1
    move.w %a1, %d2
    addq.w #1, %d2
4:  add.w #FILE_SEL_HEART_COL, %d1
    bsr file_glyph
    addq.w #1, %d6
    cmp.w #16, %d6
    blo 2b

    | the death count: three characters, FormatDecimalByte's blanks in front, nothing at all for a free slot
    lea OFF_SLOT_DEATHS(%a5), %a0
    moveq #0, %d0
    move.b 0(%a0, %d7.w), %d0
    divu.w #10, %d0
    move.l %d0, %d6
    swap %d6                            | the ones
    andi.l #0xffff, %d0
    divu.w #10, %d0
    move.l %d0, %d5
    swap %d5                            | the tens
    andi.l #0xffff, %d0                 | the hundreds
    moveq #FILE_BLANK_TILE, %d4
    tst.w %d0
    beq 5f
    move.w %d0, %d4
5:  tst.w %d0
    bne 6f
    tst.w %d5
    bne 6f
    moveq #FILE_BLANK_TILE, %d5
6:  tst.w %d6
    bne 8f
    cmp.w #FILE_BLANK_TILE, %d4
    bne 7f
    cmp.w #FILE_BLANK_TILE, %d5
    bne 7f
    lea OFF_SLOT_ACTIVE(%a5), %a0
    tst.b 0(%a0, %d7.w)
    bne 7f
    moveq #FILE_BLANK_TILE, %d6
    bra 8f
7:  moveq #0, %d6
8:  move.w #FILE_SEL_NAME_COL, %d1
    move.w %a1, %d2
    addq.w #1, %d2
    moveq #0, %d3
    move.b %d4, %d0
    bsr file_glyph
    addq.w #1, %d1
    move.b %d5, %d0
    bsr file_glyph
    addq.w #1, %d1
    move.b %d6, %d0
    bsr file_glyph
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| The three name fields of the register and elimination screens.
file_name_fields:
    movem.l %d0-%d7/%a0, -(%sp)
    lea OFF_SLOT_NAMES(%a5), %a0
    moveq #0, %d7
1:  move.w #FILE_REG_NAME_COL, %d1
    move.w %d7, %d2
    mulu.w #3, %d2
    add.w #FILE_REG_NAME_ROW, %d2
    moveq #0, %d3
    moveq #7, %d6
2:  move.b (%a0)+, %d0
    bsr file_glyph
    addq.w #1, %d1
    dbra %d6, 2b
    addq.w #1, %d7
    cmp.w #3, %d7
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0
    rts

| ---------------------------------------------------------------------------------------------------------- sprites
| One of file_sprites on the screen on show: d1.w = the frame, d2.w = the NES x of its left edge, d3.w = the NES y the
| sprite is given (its top line is one below). Nothing changes.
file_draw_frame:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    ltab file_sprites, %a0
    andi.l #0xffff, %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    adda.l %d1, %a0
    add.w #(1 - INTRO_WINDOW_TOP), %d3
    andi.l #0xffff, %d3
    mulu.w #SCREEN_STRIDE, %d3
    movea.l OFF_BG_NEXT(%a5), %a1
    adda.l %d3, %a1
    add.w #(PLAYFIELD_LEFT * 2), %d2    | the picture's x on the 320-pixel screen
    move.w %d2, %d0
    andi.w #15, %d0
    lsr.w #4, %d2
    lsl.w #3, %d2
    adda.w %d2, %a1
    moveq #(SPRITE_HEIGHT - 1), %d7
    bsr draw_sprite_rows
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| The offset in a screen of the byte column that holds NES x d2.w (a multiple of 8) on screen line d3.w, in d0.l.
file_cell_offset:
    move.l %d4, -(%sp)
    move.w %d2, %d0
    add.w #(PLAYFIELD_LEFT * 2), %d0
    lsr.w #3, %d0                       | the column of bytes
    move.w %d0, %d4
    lsr.w #1, %d4
    lsl.w #3, %d4                       | eight bytes a group of 16 pixels
    btst #0, %d0
    beq 1f
    addq.w #1, %d4
1:  moveq #0, %d0
    move.w %d3, %d0
    mulu.w #SCREEN_STRIDE, %d0
    andi.l #0xffff, %d4
    add.l %d4, %d0
    move.l (%sp)+, %d4
    rts

| d6.w lines of the byte column at NES x d2.w (a multiple of 8), from screen line d3.w, put back from the clean copy.
file_restore:
    movem.l %d0/%d6/%a0-%a1, -(%sp)
    bsr file_cell_offset
    movea.l OFF_SCREEN_PTR(%a5), %a0
    adda.l %d0, %a0
    movea.l OFF_BG_NEXT(%a5), %a1
    adda.l %d0, %a1
    subq.w #1, %d6
1:  move.b (%a0), (%a1)
    move.b 2(%a0), 2(%a1)
    move.b 4(%a0), 4(%a1)
    move.b 6(%a0), 6(%a1)
    lea SCREEN_STRIDE(%a0), %a0
    lea SCREEN_STRIDE(%a1), %a1
    dbra %d6, 1b
    movem.l (%sp)+, %d0/%d6/%a0-%a1
    rts

| The block cursor: eight lines of FILE_BLOCK_COLOUR at NES x d2.w (a multiple of 8) from screen line d3.w, behind
| whatever the picture has there (the sprite has the background's priority).
file_block:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    bsr file_cell_offset
    movea.l OFF_SCREEN_PTR(%a5), %a0
    adda.l %d0, %a0
    movea.l OFF_BG_NEXT(%a5), %a1
    adda.l %d0, %a1
    moveq #7, %d7
1:  move.b (%a0), %d0
    move.b 2(%a0), %d1
    move.b 4(%a0), %d2
    move.b 6(%a0), %d3
    move.b %d0, %d4
    or.b %d1, %d4
    or.b %d2, %d4
    or.b %d3, %d4
    not.b %d4                           | the pixels of the picture's backdrop
    .if FILE_BLOCK_COLOUR & 1
    or.b %d4, %d0
    .endif
    .if FILE_BLOCK_COLOUR & 2
    or.b %d4, %d1
    .endif
    .if FILE_BLOCK_COLOUR & 4
    or.b %d4, %d2
    .endif
    .if FILE_BLOCK_COLOUR & 8
    or.b %d4, %d3
    .endif
    move.b %d0, (%a1)
    move.b %d1, 2(%a1)
    move.b %d2, 4(%a1)
    move.b %d3, 6(%a1)
    lea SCREEN_STRIDE(%a0), %a0
    lea SCREEN_STRIDE(%a1), %a1
    dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| Block cursor d6.w (0 the name's, 1 the board's) goes to NES x d2.w (-1 for none) on screen line d3.w.
file_block_move:
    movem.l %d0-%d6/%a0, -(%sp)
    lea OFF_FILE_BLK(%a5), %a0
    lsl.w #2, %d6
    adda.w %d6, %a0
    cmp.w (%a0), %d2
    bne 1f
    cmp.w 2(%a0), %d3
    beq 9f
1:  move.w (%a0), %d4
    bmi 2f
    move.w %d2, -(%sp)
    move.w %d3, -(%sp)
    move.w %d4, %d2
    move.w 2(%a0), %d3
    moveq #8, %d6
    bsr file_restore
    move.w (%sp)+, %d3
    move.w (%sp)+, %d2
2:  move.w %d2, (%a0)
    move.w %d3, 2(%a0)
    tst.w %d2
    bmi 9f
    bsr file_block
9:  movem.l (%sp)+, %d0-%d6/%a0
    rts

| The heart that marks the choice, on the y the choice has (the white one in elimination mode).
file_heart_show:
    movem.l %d0-%d6/%a0, -(%sp)
    cmpi.b #FILE_SELECT, OFF_FILE_SCREEN(%a5)
    bne 1f
    move.w #FILE_SEL_HEART_X, %d4
    ltab file_select_ys, %a0
    bra 2f
1:  cmpi.b #FILE_CONTINUE, OFF_FILE_SCREEN(%a5)
    bne 11f
    move.w #FILE_CONT_HEART_X, %d4
    ltab file_continue_ys, %a0
    bra 2f
11: move.w #FILE_REG_HEART_X, %d4
    ltab file_register_ys, %a0
2:  moveq #0, %d0
    move.b OFF_FILE_SEL(%a5), %d0
    moveq #0, %d5
    move.b 0(%a0, %d0.w), %d5           | the new y
    moveq #0, %d3
    move.b OFF_FILE_HEART_Y(%a5), %d3
    beq 3f
    add.w #(1 - INTRO_WINDOW_TOP), %d3  | the old heart: its two byte columns come back
    moveq #16, %d6
    move.w %d4, %d2
    andi.w #0xfff8, %d2
    bsr file_restore
    addq.w #8, %d2
    bsr file_restore
3:  move.b %d5, OFF_FILE_HEART_Y(%a5)
    moveq #FILE_FRAME_HEART, %d1
    cmpi.b #FILE_ELIMINATE, OFF_FILE_SCREEN(%a5)
    bne 4f
    moveq #FILE_FRAME_HEART_WHITE, %d1
4:  move.w %d4, %d2
    move.w %d5, %d3
    bsr file_draw_frame
    movem.l (%sp)+, %d0-%d6/%a0
    rts

| The Links beside the slots, each with the Second Quest's sword when the profile has one (Mode1_WriteLinkSprites). The
| sword is behind Link.
file_links:
    movem.l %d0-%d7/%a0, -(%sp)
    move.w #FILE_SEL_LINK_X, %d4
    move.w #FILE_SEL_LINK_Y, %d5
    cmpi.b #FILE_SELECT, OFF_FILE_SCREEN(%a5)
    beq 1f
    move.w #FILE_REG_LINK_X, %d4
    move.w #FILE_REG_LINK_Y, %d5
1:  moveq #0, %d7
2:  lea OFF_SLOT_QUEST(%a5), %a0
    tst.b 0(%a0, %d7.w)
    beq 3f
    moveq #FILE_FRAME_SWORD, %d1
    move.w %d4, %d2
    add.w #FILE_SWORD_DX, %d2
    move.w %d5, %d3
    add.w #FILE_SWORD_DY, %d3
    bsr file_draw_frame
3:  lea OFF_SLOT_RING(%a5), %a0
    moveq #FILE_FRAME_LINK, %d1
    add.b 0(%a0, %d7.w), %d1
    move.w %d4, %d2
    move.w %d5, %d3
    bsr file_draw_frame
    add.w #FILE_LINK_STEP, %d5
    addq.w #1, %d7
    cmp.w #3, %d7
    blo 2b
    movem.l (%sp)+, %d0-%d7/%a0
    rts

| ------------------------------------------------------------------------------------------------ bringing it up
| d0.b = the screen: FILE_SELECT, FILE_REGISTER or FILE_ELIMINATE.
filesel_begin:
    move.b %d0, OFF_FILE_SCREEN(%a5)
    move.b #INTRO_PHASE_MENU, OFF_INTRO_PHASE(%a5)
    bsr intro_black
    bsr intro_clear_all
    ltab file_cells, %a0
    moveq #0, %d1
    move.b OFF_FILE_SCREEN(%a5), %d1
    mulu.w #FILE_PICTURE_BYTES, %d1
    adda.l %d1, %a0
    ltab file_tiles, %a2
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
    bsr intro_copy                      | the clean copy
    movea.l OFF_BG_NEXT(%a5), %a2
    bsr intro_copy                      | and the screen on show

    clr.b OFF_FILE_HEART_Y(%a5)
    lea OFF_FILE_BLK(%a5), %a0
    moveq #-1, %d0
    move.l %d0, (%a0)+
    move.l %d0, (%a0)+
    clr.b OFF_FILE_COL(%a5)
    clr.b OFF_FILE_BOARD(%a5)
    clr.b OFF_FILE_HOLDING(%a5)
    clr.b OFF_FILE_HELD(%a5)
    clr.b OFF_FILE_REPEAT_SUB(%a5)
    clr.b OFF_FILE_REPEAT_T(%a5)
    move.b #FILE_BOARD_FIRST_X, OFF_FILE_BOARD_X(%a5)
    move.b #FILE_BOARD_FIRST_Y, OFF_FILE_BOARD_Y(%a5)
    bsr file_read_buttons               | a key that is still down from the last screen does not count
    clr.b OFF_FILE_PRESSED(%a5)

    lea OFF_SLOT_ACTIVE(%a5), %a0
    moveq #0, %d1
    move.b OFF_FILE_SCREEN(%a5), %d0
    bne 4f

    | select: the heart starts on the first slot in use, or on REGISTER
3:  tst.b 0(%a0, %d1.w)
    bne 6f
    addq.w #1, %d1
    bra 3b
6:  move.b %d1, OFF_FILE_SEL(%a5)
    moveq #0, %d0
7:  bsr file_slot_line
    addq.w #1, %d0
    cmp.w #3, %d0
    blo 7b
    bra 9f

    | register: the first slot that is free, or END
4:  cmp.b #FILE_CONTINUE, %d0
    beq file_continue_begin
    cmp.b #FILE_REGISTER, %d0
    bne 8f
5:  cmp.w #FILE_END, %d1
    beq 8f
    tst.b 0(%a0, %d1.w)
    beq 8f
    addq.w #1, %d1
    bra 5b
8:  cmp.b #FILE_REGISTER, OFF_FILE_SCREEN(%a5)
    beq 10f
    moveq #0, %d1                       | elimination: the first slot
10: move.b %d1, OFF_FILE_SEL(%a5)
    bsr file_name_fields
9:  bsr file_links
    bsr file_heart_show
    ltab file_palette, %a0
    bra intro_set_palette

| ------------------------------------------------------------------------------------------------------ each frame
filesel_update:
    bsr file_read_buttons
    move.b OFF_FILE_SCREEN(%a5), %d0
    beq file_select_update
    cmp.b #FILE_REGISTER, %d0
    beq file_register_update
    cmp.b #FILE_CONTINUE, %d0
    beq file_continue_update
    bra file_eliminate_update

| Player select (UpdateMode1Menu).
file_select_update:
    move.b OFF_FILE_PRESSED(%a5), %d0
    btst #4, %d0                        | Start (the joystick's button is Start here)
    bne 5f
    btst #7, %d0
    bne 5f
    moveq #1, %d2
    btst #5, %d0                        | Select
    bne 1f
    btst #2, %d0
    bne 1f
    moveq #-1, %d2
    btst #3, %d0
    bne 1f
    rts
1:  bsr file_click
    moveq #0, %d1
    move.b OFF_FILE_SEL(%a5), %d1
    lea OFF_SLOT_ACTIVE(%a5), %a0
2:  add.w %d2, %d1                      | on to the next choice that is on: a slot in use, or an option
    bge 3f
    moveq #4, %d1
3:  cmp.w #5, %d1
    blo 4f
    moveq #0, %d1
4:  tst.b 0(%a0, %d1.w)
    beq 2b
    move.b %d1, OFF_FILE_SEL(%a5)
    bra file_heart_show

5:  moveq #0, %d0
    move.b OFF_FILE_SEL(%a5), %d0
    cmp.b #FILE_END, %d0
    blo filesel_play
    bne 6f
    moveq #FILE_REGISTER, %d0           | REGISTER YOUR NAME
    bra filesel_begin
6:  moveq #FILE_ELIMINATE, %d0          | ELIMINATION MODE
    bra filesel_begin

| The slot d0 was chosen: the game starts with it.
filesel_play:
    move.b %d0, OFF_PROFILE(%a5)
    bsr save_load_game                  | the profile's game, Link at the start
    bsr intro_leave
    bra begin_game_far

| Select on the register and elimination screens (UpdateModeEandF_Idle): on to the next choice. In mode E the slots
| that are in use are passed over, and the name goes back to its first character.
file_ef_select:
    btst #5, OFF_FILE_PRESSED(%a5)
    beq 9f
1:  bsr file_click
    moveq #0, %d1
    move.b OFF_FILE_SEL(%a5), %d1
    addq.w #1, %d1
    cmp.w #4, %d1
    blo 2f
    moveq #0, %d1
2:  move.b %d1, OFF_FILE_SEL(%a5)
    cmpi.b #FILE_REGISTER, OFF_FILE_SCREEN(%a5)
    bne 3f
    clr.b OFF_FILE_COL(%a5)
    cmp.w #FILE_END, %d1
    beq 3f
    lea OFF_SLOT_ACTIVE(%a5), %a0
    tst.b 0(%a0, %d1.w)
    bne 1b
3:  bsr file_heart_show
9:  rts

| Register your name (UpdateModeERegister).
file_register_update:
    move.b OFF_FILE_PRESSED(%a5), %d0
    cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    bne 2f
    btst #4, %d0                        | Start on END (A does it too: it has nothing else to do there)
    bne file_register_end
    btst #7, %d0
    bne file_register_end
    bra 3f
2:  bsr file_directions
3:  bsr file_ef_select
    bsr file_cursors
    cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    beq 9f
    move.b OFF_FILE_PRESSED(%a5), %d0
    andi.b #(BTN_A + BTN_B), %d0
    beq 9f
    cmp.b #BTN_A, %d0
    bne 4f                              | B, or both: the cursor moves on without a letter
    moveq #SFX_BOMB, %d0                | Tune0Request = $20: the click of a letter
    bsr music_play_far
    moveq #0, %d0
    move.b OFF_FILE_BOARD(%a5), %d0
    ltab file_char_map, %a0
    move.b 0(%a0, %d0.w), %d0           | the letter the cursor is on
    moveq #0, %d7
    move.b OFF_FILE_SEL(%a5), %d7
    moveq #0, %d1
    move.b OFF_FILE_COL(%a5), %d1
    move.w %d7, %d2
    lsl.w #3, %d2
    add.w %d1, %d2
    lea OFF_SLOT_NAMES(%a5), %a0
    move.b %d0, 0(%a0, %d2.w)
    add.w #FILE_REG_NAME_COL, %d1
    move.w %d7, %d2
    mulu.w #3, %d2
    add.w #FILE_REG_NAME_ROW, %d2
    moveq #0, %d3
    bsr file_glyph
4:  move.b OFF_FILE_COL(%a5), %d0
    addq.b #1, %d0
    andi.b #7, %d0                      | after the eighth it is the first again
    move.b %d0, OFF_FILE_COL(%a5)
    bsr file_cursors
9:  rts

| The block cursors: the name's (on the character that is next) and the board's, flashing every 8 frames, and gone
| while END is chosen.
file_cursors:
    movem.l %d0-%d6/%a0, -(%sp)
    moveq #0, %d5
    cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    beq 1f
    btst #3, OFF_INTRO_FRAME+1(%a5)
    beq 1f
    moveq #1, %d5
1:  moveq #-1, %d2
    moveq #0, %d3
    tst.b %d5
    beq 2f
    moveq #0, %d0
    move.b OFF_FILE_SEL(%a5), %d0
    ltab file_register_ys, %a0
    move.b 0(%a0, %d0.w), %d3
    andi.w #0xff, %d3
    add.w #(1 - INTRO_WINDOW_TOP), %d3
    moveq #0, %d2
    move.b OFF_FILE_COL(%a5), %d2
    lsl.w #3, %d2
    add.w #FILE_NAME_X, %d2
2:  moveq #0, %d6
    bsr file_block_move
    moveq #-1, %d2
    moveq #0, %d3
    tst.b %d5
    beq 3f
    moveq #0, %d2
    move.b OFF_FILE_BOARD_X(%a5), %d2
    moveq #0, %d3
    move.b OFF_FILE_BOARD_Y(%a5), %d3
    add.w #(1 - INTRO_WINDOW_TOP), %d3
3:  moveq #1, %d6
    bsr file_block_move
    movem.l (%sp)+, %d0-%d6/%a0
    rts

| The direction pad moves the board's cursor, repeating the way ModeE_HandleDirections does: a held direction repeats
| after $10 frames and then every 8.
file_directions:
    move.b OFF_FILE_DOWN(%a5), %d0
    andi.b #0x0f, %d0
    bne 1f
    clr.b OFF_FILE_HOLDING(%a5)         | ResetButtonRepeatState
    clr.b OFF_FILE_REPEAT_SUB(%a5)
    clr.b OFF_FILE_REPEAT_T(%a5)
    rts
1:  tst.b OFF_FILE_HOLDING(%a5)
    bne 2f
    move.b %d0, OFF_FILE_HELD(%a5)
    addq.b #1, OFF_FILE_HOLDING(%a5)
2:  cmp.b OFF_FILE_HELD(%a5), %d0
    beq 3f
    clr.b OFF_FILE_HOLDING(%a5)         | another button than before: the repeat starts again
    clr.b OFF_FILE_REPEAT_SUB(%a5)
    clr.b OFF_FILE_REPEAT_T(%a5)
3:  tst.b OFF_FILE_REPEAT_T(%a5)
    beq 4f
    subq.b #1, OFF_FILE_REPEAT_T(%a5)
    rts
4:  moveq #FILE_REPEAT, %d1
    tst.b OFF_FILE_REPEAT_SUB(%a5)
    bne 5f
    moveq #FILE_FIRST_REPEAT, %d1
5:  move.b %d1, OFF_FILE_REPEAT_T(%a5)
    cmp.b #BTN_RIGHT, %d0
    beq file_board_right
    cmp.b #BTN_LEFT, %d0
    beq file_board_left
    cmp.b #BTN_DOWN, %d0
    beq file_board_down
    cmp.b #BTN_UP, %d0
    beq file_board_up
    rts

file_board_right:
    addq.b #1, OFF_FILE_BOARD(%a5)
    move.b OFF_FILE_BOARD_X(%a5), %d1
    add.b #0x10, %d1
    cmp.b #FILE_BOARD_RIGHT_END, %d1
    bne 1f
    move.b #FILE_BOARD_FIRST_X, OFF_FILE_BOARD_X(%a5)
    moveq #0, %d2
    bsr file_cycle_y                    | off the right end: the next row, and to the top of the board after the last
    tst.b %d3
    beq file_direction_done
    clr.b OFF_FILE_BOARD(%a5)
    bra file_direction_done
1:  move.b %d1, OFF_FILE_BOARD_X(%a5)
    bra file_direction_done

file_board_left:
    subq.b #1, OFF_FILE_BOARD(%a5)
    move.b OFF_FILE_BOARD_X(%a5), %d1
    sub.b #0x10, %d1
    cmp.b #FILE_BOARD_LEFT_END, %d1
    bne 1f
    move.b #0xd0, OFF_FILE_BOARD_X(%a5)
    moveq #3, %d2
    bsr file_cycle_y
    tst.b %d3
    beq file_direction_done
    move.b #(FILE_BOARD_CELLS - 1), OFF_FILE_BOARD(%a5)
    bra file_direction_done
1:  move.b %d1, OFF_FILE_BOARD_X(%a5)
    bra file_direction_done

file_board_down:
    add.b #FILE_BOARD_COLS, OFF_FILE_BOARD(%a5)
    moveq #0, %d2
    bsr file_cycle_y
    tst.b %d3
    beq file_direction_done
    sub.b #FILE_BOARD_CELLS, OFF_FILE_BOARD(%a5)
    bra file_direction_done

file_board_up:
    sub.b #FILE_BOARD_COLS, OFF_FILE_BOARD(%a5)
    moveq #3, %d2
    bsr file_cycle_y
    tst.b %d3
    beq file_direction_done
    add.b #FILE_BOARD_CELLS, OFF_FILE_BOARD(%a5)

file_direction_done:
    move.b #1, OFF_FILE_REPEAT_SUB(%a5)
    bra file_click

| CycleCharBoardCursorY: the board's cursor one row down (d2.w = 0) or up (3); d3.b = 1 when it went round.
file_cycle_y:
    ltab file_board_ys, %a0
    move.b OFF_FILE_BOARD_Y(%a5), %d1
    add.b 0(%a0, %d2.w), %d1
    moveq #0, %d3
    cmp.b 1(%a0, %d2.w), %d1
    bne 1f
    move.b 2(%a0, %d2.w), %d1
    moveq #1, %d3
1:  move.b %d1, OFF_FILE_BOARD_Y(%a5)
    rts

| Start on END: every free slot with a name in it becomes a profile of three hearts, and the Second Quest's when the name
| begins with ZELDA; then the select screen comes up again.
file_register_end:
    moveq #0, %d7
1:  lea OFF_SLOT_ACTIVE(%a5), %a0
    tst.b 0(%a0, %d7.w)
    bne 6f                              | a slot in use keeps what it has
    lea OFF_SLOT_NAMES(%a5), %a1
    move.w %d7, %d0
    lsl.w #3, %d0
    adda.w %d0, %a1
    moveq #7, %d1
2:  cmpi.b #FILE_BLANK_TILE, (%a1)+
    bne 3f
    dbra %d1, 2b
    bra 6f                              | only spaces: still free
3:  move.b #1, 0(%a0, %d7.w)
    lea OFF_SLOT_HEARTS(%a5), %a0
    move.w %d7, %d0
    add.w %d0, %d0
    move.b #FILE_NEW_HEARTS, 0(%a0, %d0.w)
    move.b #FILE_NEW_PARTIAL, 1(%a0, %d0.w)
    lea OFF_SLOT_DEATHS(%a5), %a0
    clr.b 0(%a0, %d7.w)
    lea OFF_SLOT_RING(%a5), %a0
    clr.b 0(%a0, %d7.w)
    lea OFF_SLOT_QUEST(%a5), %a0
    clr.b 0(%a0, %d7.w)
    lea OFF_SLOT_NAMES(%a5), %a1
    move.w %d7, %d0
    lsl.w #3, %d0
    adda.w %d0, %a1
    ltab file_zelda, %a2
    moveq #4, %d1
4:  cmpm.b (%a2)+, (%a1)+
    bne 5f
    dbra %d1, 4b
    move.b #1, 0(%a0, %d7.w)            | ZELDA: the Second Quest
5:  move.w %d7, %d0
    bsr save_new_game                   | its game, and the disk has the profile at once
6:  addq.w #1, %d7
    cmp.w #3, %d7
    blo 1b
    bsr save_write
    moveq #FILE_SELECT, %d0
    bra filesel_begin

| Elimination mode (UpdateModeFElimination).
file_eliminate_update:
    move.b OFF_FILE_PRESSED(%a5), %d0
    cmp.b #BTN_START, %d0
    beq 1f
    cmp.b #BTN_A, %d0
    beq 1f
    bra file_ef_select
1:  cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    bne file_delete_slot
    moveq #FILE_REGISTER, %d0           | END: back to registering
    bra filesel_begin

| DeleteSlot: the slot is wiped and its name blanked on the screen.
file_delete_slot:
    moveq #SFX_HARMED, %d0
    bsr music_play_far
    moveq #0, %d7
    move.b OFF_FILE_SEL(%a5), %d7
    move.w %d7, %d0
    bsr file_clear_slot
    move.w #FILE_REG_NAME_COL, %d1
    move.w %d7, %d2
    mulu.w #3, %d2
    add.w #FILE_REG_NAME_ROW, %d2
    moveq #0, %d3
    moveq #7, %d6
1:  moveq #FILE_BLANK_TILE, %d0
    bsr file_glyph
    addq.w #1, %d1
    dbra %d6, 1b
    move.w %d7, %d0
    bsr save_delete                     | the file on the disk is as the ROM leaves it, at once
    bra save_write

| ---------------------------------------------------------------------------------- the question after a death
| Three words, CONTINUE, SAVE and RETRY, and the heart (UpdateMode8ContinueQuestion_Full). Select (or the arrows) moves
| the heart on, Start (or A) takes the choice: the word flashes for $40 frames, between its own colour and the hearts',
| and then death.s does what it says. FILE_SEL is the choice (the submode of the ROM).
file_continue_begin:
    clr.b OFF_FILE_SEL(%a5)
    clr.b OFF_FILE_FLASH(%a5)
    bsr file_heart_show
    ltab file_palette, %a0
    bra intro_set_palette

file_continue_update:
    tst.b OFF_FILE_FLASH(%a5)
    bne file_continue_flash
    move.b OFF_FILE_PRESSED(%a5), %d0
    btst #4, %d0                        | Start
    bne 5f
    btst #7, %d0                        | the joystick's button
    bne 5f
    moveq #1, %d2
    btst #5, %d0                        | Select
    bne 1f
    btst #2, %d0
    bne 1f
    moveq #-1, %d2
    btst #3, %d0
    bne 1f
    rts
1:  bsr file_click
    moveq #0, %d1
    move.b OFF_FILE_SEL(%a5), %d1
    add.w %d2, %d1
    bge 2f
    moveq #2, %d1
2:  cmp.w #3, %d1
    blo 3f
    moveq #0, %d1
3:  move.b %d1, OFF_FILE_SEL(%a5)
    bra file_heart_show
5:  move.b #FILE_FLASH_FRAMES, OFF_FILE_FLASH(%a5)
    rts

file_continue_flash:
    subq.b #1, OFF_FILE_FLASH(%a5)
    beq file_continue_go
    moveq #0, %d3
    move.b OFF_FILE_FLASH(%a5), %d3
    lsr.b #2, %d3
    andi.w #1, %d3                      | every four frames the other colour
    moveq #0, %d0
    move.b OFF_FILE_SEL(%a5), %d0
    mulu.w #FILE_CONT_WORD_BYTES, %d0
    ltab file_continue_words, %a0
    adda.w %d0, %a0
    moveq #0, %d1
    move.b (%a0)+, %d1
    moveq #0, %d2
    move.b (%a0)+, %d2
    moveq #0, %d4
    move.b (%a0)+, %d4
    subq.w #1, %d4
1:  moveq #0, %d0
    move.b (%a0)+, %d0
    bsr file_glyph
    addq.w #1, %d1
    dbra %d4, 1b
    rts

file_continue_go:
    bsr music_stop_far                  | SilenceAllSound
    clr.b OFF_MUS_FORCED(%a5)
    moveq #0, %d0
    move.b OFF_FILE_SEL(%a5), %d0
    beq death_continue
    subq.b #1, %d0
    beq death_save
    bra death_retry
