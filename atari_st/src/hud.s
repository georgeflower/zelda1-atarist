| The status ribbon.
|
| An 8x8 tile is exactly one byte of an ST bitplane word, so HUD glyphs are
| stored as eight rows of four bytes and drawn with plain byte stores -- no
| shifting, and no need to go through the sprite blitter.

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
    movem.l (%sp)+, %d0-%d4
    rts

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
    ltab hud_items, %a0         | the pictures are in B item order: sword, bomb, boomerang, candle
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    moveq #(HUD_B_COL + 1), %d1
    moveq #1, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    moveq #2, %d2
    bsr draw_hud_tile_ptr
1:  tst.b OFF_HAS_SWORD(%a5)
    beq 9f
    ltab hud_items, %a0
    moveq #(HUD_A_COL + 1), %d1
    moveq #1, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    moveq #2, %d2
    bsr draw_hud_tile_ptr
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

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

    addq.w #1, %d1
    moveq #HUD_X, %d0
    bsr draw_hud_tile

    | divu.w divides the whole 32-bit register, so clear it down to the byte
    | the caller actually passed.
    and.l #0xFF, %d4
    divu.w #10, %d4
    move.l %d4, %d5
    swap %d5                    | remainder: the units digit
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
