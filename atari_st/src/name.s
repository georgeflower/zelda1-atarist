| Typing a character's name on the register screen (filesel.s, mode E) with the keyboard, beside the ROM's letter board.
| Included last: the code between filesel.s and save.s has no reach to spare.

| Register your name (UpdateModeERegister). The keyboard types too (file_typed): a letter, digit or sign goes into the
| name as A puts the board's letter in, Backspace rubs out the one before, and Return (Start) on a name moves the heart
| down to END, where Return again registers.
file_register_update:
    move.b OFF_FILE_PRESSED(%a5), %d0
    cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    bne 2f
    clr.b OFF_KEY_TYPED(%a5)
    btst #4, %d0                        | Start on END (A does it too: it has nothing else to do there)
    bne file_register_end
    btst #7, %d0
    bne file_register_end
    bra 3f
2:  btst #4, %d0
    beq 1f
    clr.b OFF_KEY_TYPED(%a5)
    bsr file_click                      | Start on a name: on to END
    move.b #FILE_END, OFF_FILE_SEL(%a5)
    clr.b OFF_FILE_COL(%a5)
    bsr file_heart_show
    bra file_cursors
1:  bsr file_typed
    bsr file_directions
3:  bsr file_ef_select
    bsr file_cursors
    cmpi.b #FILE_END, OFF_FILE_SEL(%a5)
    beq 9f
    move.b OFF_FILE_PRESSED(%a5), %d0
    andi.b #(BTN_A + BTN_B), %d0
    beq 9f
    cmp.b #BTN_A, %d0
    bne file_name_next                  | B, or both: the cursor moves on without a letter
    moveq #0, %d0
    move.b OFF_FILE_BOARD(%a5), %d0
    ltab file_char_map, %a0
    move.b 0(%a0, %d0.w), %d0           | the letter the cursor is on
    bsr file_name_put
file_name_next:
    move.b OFF_FILE_COL(%a5), %d0
    addq.b #1, %d0
    andi.b #7, %d0                      | after the eighth it is the first again
    move.b %d0, OFF_FILE_COL(%a5)
    bsr file_cursors
9:  rts

| The NES character d0.b into the chosen slot's name where its cursor is, on the screen too, with the letter's click.
| The cursor stays.
file_name_put:
    movem.l %d0-%d3/%d7/%a0, -(%sp)
    move.l %d0, -(%sp)
    moveq #SFX_BOMB, %d0                | Tune0Request = $20: the click of a letter
    bsr music_play_xf
    move.l (%sp)+, %d0
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
    movem.l (%sp)+, %d0-%d3/%d7/%a0
    rts

| The key typed since the last frame (KEY_TYPED), read through TOS' own keyboard tables so that every country's layout
| gives its own letters: A-Z (either case), 0-9, the space and the board's signs - . , ! ' & go into the name and move
| its cursor on; Backspace moves it back and blanks that place. Anything else is left alone.
file_typed:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    moveq #0, %d1
    move.b OFF_KEY_TYPED(%a5), %d1
    beq 9f
    clr.b OFF_KEY_TYPED(%a5)
    cmp.b #0x0e, %d1                    | Backspace
    bne 1f
    move.b OFF_FILE_COL(%a5), %d0
    subq.b #1, %d0
    andi.b #7, %d0
    move.b %d0, OFF_FILE_COL(%a5)
    moveq #FILE_BLANK_TILE, %d0
    bsr file_name_put
    bsr file_cursors
    bra 9f
1:  movea.l OFF_KEY_TABLES(%a5), %a0    | the table without Shift, or with it while either Shift is down
    lea OFF_KEY_STATES(%a5), %a1
    move.b SCAN_LSHIFT(%a1), %d0
    or.b SCAN_RSHIFT(%a1), %d0
    beq 2f
    movea.l (OFF_KEY_TABLES + 4)(%a5), %a0
2:  move.l %a0, %d0
    beq 9f                              | (no tables: Keytbl gave none)
    move.b 0(%a0, %d1.w), %d0           | the character
    ltab file_typed_signs, %a0
3:  move.b (%a0)+, %d1                  | a sign of the board, or the space
    beq 4f
    cmp.b %d1, %d0
    beq 8f
    addq.l #1, %a0
    bra 3b
4:  cmp.b #'a', %d0
    blo 5f
    cmp.b #'z', %d0
    bhi 9f
    sub.b #('a' - 'A'), %d0
5:  cmp.b #'A', %d0
    blo 6f
    cmp.b #'Z', %d0
    bhi 9f
    sub.b #('A' - 0x0a), %d0            | the font's codes: the letters follow the digits
    bra 7f
6:  cmp.b #'0', %d0
    blo 9f
    cmp.b #'9', %d0
    bhi 9f
    sub.b #'0', %d0
7:  bsr file_name_put
    bsr file_name_next
    bra 9f
8:  move.b (%a0), %d0
    bra 7b
9:  movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| The characters typed that are not letters or digits, and their tiles (ModeE_CharMap's signs); 0 ends.
    .section .rodata
file_typed_signs:
    .byte ' ', 0x24, '-', 0x62, '.', 0x63, ',', 0x28, '!', 0x29, 0x27, 0x2a, '&', 0x2b, 0
    .even
    .section .text

| TOS' keyboard tables (XBIOS Keytbl with no change): the layout of the machine's own keyboard, for file_typed.
file_key_tables:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    moveq #-1, %d0
    move.l %d0, -(%sp)
    move.l %d0, -(%sp)
    move.l %d0, -(%sp)
    move.w #16, -(%sp)
    trap #14
    lea 14(%sp), %sp
    movea.l %d0, %a0
    move.l (%a0)+, OFF_KEY_TABLES(%a5)
    move.l (%a0), (OFF_KEY_TABLES + 4)(%a5)
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

