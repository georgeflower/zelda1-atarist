| The status ribbon.
|
| An 8x8 tile is exactly one byte of an ST bitplane word, so HUD glyphs are
| stored as eight rows of four bytes and drawn with plain byte stores -- no
| shifting, and no need to go through the sprite blitter.

    .equ HUD_MENU_ROW, 22               | the inventory screen is 22 tile rows high; the ribbon follows it

draw_hud:
    movem.l %d0-%d4, -(%sp)
    clr.b OFF_HUD_DIRTY(%a5)

    moveq #HUD_RUPEE, %d3
    moveq #0, %d4
    move.b OFF_INV_RUPEES(%a5), %d4
    moveq #0, %d2
    bsr draw_hud_counter

    moveq #HUD_KEY, %d3
    moveq #0, %d4
    move.b OFF_INV_KEYS(%a5), %d4
    moveq #1, %d2
    bsr draw_hud_counter
    tst.b OFF_INV_MAGIC_KEY(%a5)
    beq 1f
    moveq #(HUD_COUNTER_COL + 2), %d1   | the magic key: "XA" instead of a count
    moveq #1, %d2
    moveq #HUD_CH_A, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_BLANK, %d0
    bsr draw_hud_tile
1:
    moveq #HUD_BOMB, %d3
    moveq #0, %d4
    move.b OFF_INV_BOMBS(%a5), %d4
    moveq #2, %d2
    bsr draw_hud_counter

    | "LIFE" sits above the two rows of hearts, as it does on the NES.
    moveq #0, %d2
    moveq #HUD_HEART_COL, %d1
    moveq #HUD_L, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_I, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_F, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_E, %d0
    bsr draw_hud_tile

    bsr draw_hud_hearts
    bsr draw_hud_boxes
    bsr draw_minimap
    bsr draw_hud_level
    bsr draw_hud_debug
    movem.l (%sp)+, %d0-%d4
    rts

| "LEVEL-n" in a dungeon (the ROM writes it over the map; the minimap has that corner here), blank on the overworld:
| the free columns between the A box and LIFE, on the row where only a ninth heart would ever be.
    .equ HUD_LEVEL_COL, 19
    .equ HUD_LEVEL_ROW, 1
draw_hud_level:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    ltab text_glyphs, %a1
    lea level_text(%pc), %a0
    moveq #0, %d4
1:  moveq #0, %d0
    move.b 0(%a0, %d4.w), %d0           | the NES code of the letter
    cmp.w #6, %d4
    blo 2f
    move.b OFF_LEVEL(%a5), %d0          | the digit
    bne 2f
    moveq #0x24, %d0                    | no level: a space
    bra 3f
2:  tst.b OFF_LEVEL(%a5)
    bne 3f
    moveq #0x24, %d0
3:  and.w #0x3f, %d0
    move.b 0(%a1, %d0.w), %d0
    move.w %d4, %d1
    add.w #HUD_LEVEL_COL, %d1
    moveq #HUD_LEVEL_ROW, %d2
    bsr draw_hud_tile
    addq.w #1, %d4
    cmp.w #7, %d4
    blo 1b
    movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| T (debug_room_toggle): "RM-37" on the ribbon's top row, left of LIFE, with the room Link is in; "CL-7F" with the cellar's
| own id while he is down one. Blanks when it is off.
    .equ HUD_DEBUG_COL, 19
    .equ HUD_DEBUG_ROW, 0
draw_hud_debug:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    ltab text_glyphs, %a1
    moveq #0, %d3
    move.b OFF_ROOM_ID(%a5), %d3
    lea debug_room_text(%pc), %a0
    tst.b OFF_IN_CELLAR(%a5)
    beq 1f
    move.b OFF_CELLAR_ROOM(%a5), %d3
    lea debug_cellar_text(%pc), %a0
1:  moveq #0, %d4
2:  moveq #0x24, %d0                    | off: a space
    tst.b OFF_DEBUG_ROOM(%a5)
    beq 5f
    cmp.w #3, %d4
    blo 6f
    move.w %d3, %d0                     | the two hex digits are NES codes 0-15
    cmp.w #3, %d4
    bne 7f
    lsr.w #4, %d0
7:  and.w #15, %d0
    bra 5f
6:  move.b 0(%a0, %d4.w), %d0
5:  and.w #0x3f, %d0
    move.b 0(%a1, %d0.w), %d0
    move.w %d4, %d1
    add.w #HUD_DEBUG_COL, %d1
    moveq #HUD_DEBUG_ROW, %d2
    bsr draw_hud_tile
    addq.w #1, %d4
    cmp.w #5, %d4
    blo 2b
    movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

debug_room_text:
    .byte 0x1B, 0x16, 0x2F                     | R M -
debug_cellar_text:
    .byte 0x0C, 0x15, 0x2F                     | C L -
    .align 2

level_text:
    .byte 0x15, 0x0E, 0x1F, 0x0E, 0x15, 0x2F, 0x00     | L E V E L - and the digit's place
    .align 2

| The two item boxes, B and A, between the counters and the hearts. A holds the
| sword once Link has it; B holds the bombs, which Space drops.
    .equ HUD_B_COL, 12
    .equ HUD_A_COL, 16

draw_hud_boxes:
    movem.l %d0-%d3/%a0, -(%sp)
    moveq #HUD_B_COL, %d3
    moveq #HUD_CH_B, %d0
    bsr draw_hud_box
    moveq #HUD_A_COL, %d3
    moveq #HUD_CH_A, %d0
    bsr draw_hud_box

    bsr b_item_fix
    moveq #0, %d0
    move.b OFF_B_ITEM(%a5), %d0
    beq 1f
    bsr b_icon                  | its picture in hud_items (a red candle, magic boomerang, red potion differ)
    ltab hud_items, %a0
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    moveq #(HUD_B_COL + 1), %d1
    moveq #1, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    moveq #2, %d2
    bsr draw_hud_tile_ptr
1:  moveq #0, %d0
    move.b OFF_HAS_SWORD(%a5), %d0
    beq 9f
    lea a_icons(%pc), %a0
    move.b -1(%a0, %d0.w), %d0  | the sword's picture by grade
    ltab hud_items, %a0
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    moveq #(HUD_A_COL + 1), %d1
    moveq #1, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    moveq #2, %d2
    bsr draw_hud_tile_ptr
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

a_icons:
    .byte 0, 14, 15, 15             | wooden, white and magic sword in hud_items
    .align 2

| An empty box whose left edge is column d3.w, labelled with tile d0.w. The
| ribbon is only three rows high, so there is no bottom edge.
draw_hud_box:
    movem.l %d0-%d2, -(%sp)
    move.w %d0, -(%sp)
    move.w %d3, %d1
    moveq #0, %d2
    moveq #HUD_BOX_TL, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    move.w (%sp)+, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_BOX_TR, %d0
    bsr draw_hud_tile
    moveq #1, %d2
2:  move.w %d3, %d1
    moveq #HUD_BOX_SIDE, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_BLANK, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    moveq #HUD_BOX_SIDE, %d0
    bsr draw_hud_tile
    addq.w #1, %d2
    cmp.w #3, %d2
    blo 2b
    movem.l (%sp)+, %d0-%d2
    rts

| One "<icon> X nn" counter. d3.w = icon tile, d4.b = value, d2.w = HUD row.
draw_hud_counter:
    movem.l %d0-%d2/%d4-%d5, -(%sp)
    moveq #HUD_COUNTER_COL, %d1
    move.w %d3, %d0
    bsr draw_hud_tile

    | divu.w divides the whole 32-bit register, so clear it down to the byte
    | the caller actually passed. Three digits (the purse holds up to 255) take the place of the X.
    and.l #0xFF, %d4
    divu.w #100, %d4
    move.l %d4, %d5
    swap %d5                    | the rest below 100
    and.l #0xFFFF, %d5
    addq.w #1, %d1
    moveq #HUD_X, %d0
    tst.w %d4
    beq 1f
    move.w %d4, %d0
    add.w #HUD_DIGIT0, %d0      | the hundreds
1:  bsr draw_hud_tile
    moveq #0, %d4
    move.w %d5, %d4
    divu.w #10, %d4
    move.l %d4, %d5
    swap %d5                    | the units
    addq.w #1, %d1
    move.w %d4, %d0
    and.w #0xFF, %d0
    add.w #HUD_DIGIT0, %d0
    bsr draw_hud_tile

    addq.w #1, %d1
    move.w %d5, %d0
    add.w #HUD_DIGIT0, %d0
    bsr draw_hud_tile
    movem.l (%sp)+, %d0-%d2/%d4-%d5
    rts

draw_hud_hearts:
    movem.l %d0-%d4, -(%sp)
    moveq #0, %d4               | heart slot 0..15
1:  moveq #HUD_HEART_EMPTY, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d3
    and.w #0xFF, %d3
    cmp.w %d3, %d4
    blo 2f
    moveq #HUD_BLANK, %d0       | past the containers Link owns
    bra 4f
2:  move.b OFF_HP_HALVES(%a5), %d3
    and.w #0xFF, %d3
    move.w %d4, %d2
    add.w %d2, %d2
    addq.w #2, %d2              | half hearts needed for this slot to be full
    cmp.w %d2, %d3
    blo 3f
    moveq #HUD_HEART_FULL, %d0
    bra 4f
3:  subq.w #1, %d2
    cmp.w %d2, %d3
    bne 4f
    moveq #HUD_HEART_HALF, %d0

4:  move.w %d4, %d1
    and.w #(HUD_HEARTS_PER_ROW - 1), %d1
    add.w #HUD_HEART_COL, %d1
    move.w %d4, %d2
    lsr.w #3, %d2
    addq.w #1, %d2              | hearts occupy HUD rows 1 and 2
    bsr draw_hud_tile

    addq.w #1, %d4
    cmp.w #HUD_HEART_SLOTS, %d4
    blo 1b
    movem.l (%sp)+, %d0-%d4
    rts

| Draw one 8x8 glyph. d0.w = tile index, d1.w = column 0..39, d2.w = HUD row.
draw_hud_tile:
    movem.l %d0/%a0, -(%sp)
    ltab hud_tiles, %a0
    mulu.w #HUD_TILE_BYTES, %d0
    adda.l %d0, %a0
    bsr draw_hud_tile_ptr
    movem.l (%sp)+, %d0/%a0
    rts

| The same for a tile that is not one of the glyphs: a0 = its eight rows.
draw_hud_tile_ptr:
    cmpi.b #MODE_MENU, OFF_GAME_MODE(%a5)
    bne draw_tile_abs
    addi.w #HUD_MENU_ROW, %d2           | the inventory screen has the ribbon below it
    bsr draw_tile_abs
    subi.w #HUD_MENU_ROW, %d2
    rts

| The same at the row d2.w of the whole screen, whatever the mode.
draw_tile_abs:
    movem.l %d0-%d3/%d7/%a0-%a1, -(%sp)

    movea.l OFF_SCREEN_PTR(%a5), %a1
    move.w %d2, %d3
    mulu.w #(8 * SCREEN_STRIDE), %d3
    adda.l %d3, %a1

    | Two tile columns share one 16-pixel group; the odd one is its low byte.
    move.w %d1, %d3
    lsr.w #1, %d3
    lsl.w #3, %d3
    adda.w %d3, %a1
    btst #0, %d1
    beq 1f
    addq.l #1, %a1

1:  moveq #7, %d7
2:  move.b (%a0)+, 0(%a1)
    move.b (%a0)+, 2(%a1)
    move.b (%a0)+, 4(%a1)
    move.b (%a0)+, 6(%a1)
    adda.w #SCREEN_STRIDE, %a1
    dbra %d7, 2b
    movem.l (%sp)+, %d0-%d3/%d7/%a0-%a1
    rts

| ---------------------------------------------------------------------------
| The dungeon map, in the corner of the ribbon the counters leave free: 32x24 pixels,
| each room a 4x3 cell with a 3x2 box (the NES uses 8x4 cells, but this ribbon is only
| 24 lines tall). Like the original, the layout shows once he has the map of the level,
| his own room is always marked, and the compass marks the triforce room, flashing
| until the piece is his.
    .equ MM_ROOM, 2            | the grey the original draws its rooms in
    .equ MM_LINK, 7            | green
    .equ MM_FLASH_A, 4         | the triforce room, still to be taken: red, then
    .equ MM_FLASH_B, 1         | white
    .equ MM_GOT, 9             | and dull once the piece is his
    .equ MM_COLUMNS, 8

draw_minimap:
    movem.l %d0-%d2/%a3, -(%sp)
    moveq #0, %d2               | blank the corner first
1:  moveq #0, %d1
2:  moveq #HUD_BLANK, %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    cmp.w #4, %d1
    blo 2b
    addq.w #1, %d2
    cmp.w #HUD_ROWS, %d2
    blo 1b
    lea mm_box(%pc), %a3
    bsr minimap_paint
    movem.l (%sp)+, %d0-%d2/%a3
    rts

| Paint the dungeon with the box routine in a3 (mm_box for the ribbon).
minimap_paint:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    tst.b OFF_LEVEL(%a5)
    bne 0f
    bsr mm_overworld            | the overworld's grey map and Link's dot
    bra 9f
0:  moveq #0, %d6
    move.b OFF_LEVEL(%a5), %d6
    subq.w #1, %d6
    and.w #7, %d6
    moveq #1, %d5
    lsl.b %d6, %d5              | this level's bit in the item masks

    move.b OFF_INV_MAP(%a5), %d0
    and.b %d5, %d0
    beq 5f
    lvtab ROOM_INDEX, %a2
    moveq #0, %d3
3:  cmpi.b #0xff, 0(%a2, %d3.w)
    beq 4f
    bsr mm_place
    tst.w %d0
    bmi 4f
    moveq #MM_ROOM, %d2
    jsr (%a3)
4:  addq.w #1, %d3
    cmp.w #128, %d3
    blo 3b

5:  move.b OFF_INV_COMPASS(%a5), %d0
    and.b %d5, %d0
    beq 7f
    moveq #0, %d3
    move.b OFF_UW_TRIFORCE_ROOM(%a5), %d3
    bsr mm_place
    tst.w %d0
    bmi 7f
    moveq #MM_GOT, %d2
    move.b OFF_TRIFORCE_PIECES(%a5), %d4
    and.b %d5, %d4
    bne 6f
    moveq #MM_FLASH_A, %d2
    btst #4, (OFF_FRAME_COUNTER + 1)(%a5)
    beq 6f
    moveq #MM_FLASH_B, %d2
6:  jsr (%a3)

7:  moveq #0, %d3
    move.b OFF_ROOM_ID(%a5), %d3
    bsr mm_place
    tst.w %d0
    bmi 9f
    moveq #MM_LINK, %d2
    jsr (%a3)
9:  movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| The overworld's map (LevelInfoOW's status bar map: 8x4 tiles of the grey tile $F5, and
| the marker tile $3E as a sprite at four pixels a room; UpdatePositionMarker): the whole
| 32x24 corner in grey, every one of the 16x8 screens a 2x3 cell, Link's a 2x2 dot.
mm_overworld:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    movea.l OFF_SCREEN_PTR(%a5), %a0
    cmpi.b #MODE_MENU, OFF_GAME_MODE(%a5)
    bne 0f
    adda.l #(HUD_MENU_ROW * 8 * SCREEN_STRIDE), %a0
0:  moveq #(HUD_HEIGHT - 1), %d7
1:  clr.w (%a0)                 | colour 2 is plane 1 only, two groups of sixteen pixels
    move.w #0xffff, 2(%a0)
    clr.l 4(%a0)
    clr.w 8(%a0)
    move.w #0xffff, 10(%a0)
    clr.l 12(%a0)
    adda.w #SCREEN_STRIDE, %a0
    dbra %d7, 1b
    suba.w #(HUD_HEIGHT * SCREEN_STRIDE), %a0
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    move.w %d0, %d1
    lsr.w #4, %d1               | row 0..7
    and.w #15, %d0              | column 0..15
    mulu.w #(3 * SCREEN_STRIDE), %d1
    adda.l %d1, %a0
    add.w %d0, %d0              | pixel x
    move.w %d0, %d3
    lsr.w #4, %d3
    lsl.w #3, %d3
    adda.w %d3, %a0             | the 16-pixel group
    and.w #15, %d0
    move.w #0xc000, %d3
    lsr.w %d0, %d3              | the two pixels
    move.w %d3, %d4
    not.w %d4
    moveq #MM_LINK, %d2
    moveq #1, %d7               | two lines
2:  movea.l %a0, %a1
    moveq #0, %d5
3:  move.w (%a1), %d6
    and.w %d4, %d6
    btst %d5, %d2
    beq 4f
    or.w %d3, %d6
4:  move.w %d6, (%a1)+
    addq.w #1, %d5
    cmp.w #4, %d5
    blo 3b
    adda.w #SCREEN_STRIDE, %a0
    dbra %d7, 2b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| Room id d3.w -> map cell: d0.w = column, d1.w = row; d0 is -1 when the room lies
| outside the eight columns shown.
mm_place:
    move.w %d3, %d0
    and.w #15, %d0
    moveq #0, %d1
    move.b OFF_UW_MAP_COL0(%a5), %d1
    sub.w %d1, %d0
    and.w #15, %d0
    cmp.w #MM_COLUMNS, %d0
    blo 1f
    moveq #-1, %d0
    rts
1:  move.w %d3, %d1
    lsr.w #4, %d1
    rts

| A 3x2 pixel box in the map cell d0.w (column 0..7), d1.w (row 0..7), colour d2.w.
mm_box:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    movea.l OFF_SCREEN_PTR(%a5), %a0
    cmpi.b #MODE_MENU, OFF_GAME_MODE(%a5)
    bne 0f
    adda.l #(HUD_MENU_ROW * 8 * SCREEN_STRIDE), %a0     | the ribbon is below the inventory screen
0:
    mulu.w #(3 * SCREEN_STRIDE), %d1
    adda.l %d1, %a0
    move.w %d0, %d3
    lsr.w #2, %d3
    lsl.w #3, %d3
    adda.w %d3, %a0             | four cells share a 16-pixel group (8 bytes)
    and.w #3, %d0
    lsl.w #2, %d0
    move.w #0xe000, %d3
    lsr.w %d0, %d3              | the box's three pixels inside the group
    move.w %d3, %d4
    not.w %d4
    moveq #1, %d7               | two lines
1:  movea.l %a0, %a1
    moveq #0, %d5               | plane
2:  move.w (%a1), %d6
    and.w %d4, %d6
    btst %d5, %d2
    beq 3f
    or.w %d3, %d6
3:  move.w %d6, (%a1)+
    addq.w #1, %d5
    cmp.w #4, %d5
    blo 2b
    adda.w #SCREEN_STRIDE, %a0
    dbra %d7, 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| Ask for a ribbon redraw when what the map shows has changed: his room, the map or
| compass arriving, the level changing, or the triforce marker's flash turning over.
minimap_tick:
    movem.l %d0-%d2, -(%sp)
    moveq #0, %d0               | the overworld shows the room Link is in
    moveq #0, %d1
    move.b OFF_LEVEL(%a5), %d1
    bne 4f
    move.b OFF_ROOM_ID(%a5), %d0
    lsl.w #8, %d0
    bra 3f
4:
    subq.w #1, %d1
    and.w #7, %d1
    moveq #1, %d2
    lsl.b %d1, %d2
    move.b OFF_ROOM_ID(%a5), %d0
    lsl.w #8, %d0
    addq.w #1, %d0
    move.b OFF_INV_MAP(%a5), %d1
    and.b %d2, %d1
    beq 1f
    or.w #2, %d0
1:  move.b OFF_INV_COMPASS(%a5), %d1
    and.b %d2, %d1
    beq 3f
    or.w #4, %d0
    move.b OFF_TRIFORCE_PIECES(%a5), %d1
    and.b %d2, %d1
    bne 2f
    move.b (OFF_FRAME_COUNTER + 1)(%a5), %d1
    and.b #16, %d1
    or.b %d1, %d0               | the flash phase
    bra 3f
2:  or.w #8, %d0
3:  tst.b OFF_DEBUG_ROOM(%a5)             | the room id text is part of what the ribbon shows
    beq 5f
    or.w #0x20, %d0
    tst.b OFF_IN_CELLAR(%a5)
    beq 5f
    or.w #0x40, %d0
5:  cmp.w OFF_MINIMAP_SIG(%a5), %d0
    beq 9f
    move.w %d0, OFF_MINIMAP_SIG(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
9:  movem.l (%sp)+, %d0-%d2
    rts
