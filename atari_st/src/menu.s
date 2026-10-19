| The inventory screen: Tab freezes the game and shows what Link can put on the
| B button (bombs, boomerang, candle, bow, recorder, food, potion, rod) in two rows of four, and the
| items he only carries (raft, book, ring, ladder, magic key, bracelet, letter, magic shield) below;
| Left and Right choose, Tab goes back.
|
| It is drawn over the playfield with the ribbon's 8x8 glyphs, straight onto
| the visible screen like the caves are, so double buffering is off while it is
| open. The room underneath is untouched in bg_cur and is put back on closing.

    .equ SCAN_TAB, 0x0f
    .equ SCAN_LEFT_ARROW, 0x4b
    .equ SCAN_RIGHT_ARROW, 0x4d
    .equ SCAN_A_KEY, 0x1e
    .equ SCAN_D_KEY, 0x20

    .equ MENU_TAB, 1
    .equ MENU_LEFT, 2
    .equ MENU_RIGHT, 4

    .equ MENU_ICON_ROW, 9           | the top row of cells; the bottom row is four rows lower
    .equ MENU_PASSIVE_ITEMS_ROW, 17

| Called by update_play once Link and the sprites are erased: Tab opens the screen.
menu_check_open:
    movem.l %d0/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_TAB(%a0)
    beq 8f
    btst #0, OFF_MENU_KEYS(%a5)
    bne 9f                      | still the same press
    bset #0, OFF_MENU_KEYS(%a5)
    tst.b OFF_LINK_HELD(%a5)
    bne 9f
    tst.b OFF_ENDING_PHASE(%a5)
    bne 9f
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    move.b #MODE_MENU, OFF_GAME_MODE(%a5)
    bsr dbl_end_far
    bsr menu_draw
    bra 9f
8:  bclr #0, OFF_MENU_KEYS(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

update_menu:
    movem.l %d0-%d2/%a0, -(%sp)
    lea OFF_KEY_STATES(%a5), %a0
    moveq #0, %d0                       | the keys down now
    tst.b SCAN_TAB(%a0)
    beq 1f
    or.b #MENU_TAB, %d0
1:  tst.b SCAN_LEFT_ARROW(%a0)
    bne 2f
    tst.b SCAN_A_KEY(%a0)
    beq 3f
2:  or.b #MENU_LEFT, %d0
3:  tst.b SCAN_RIGHT_ARROW(%a0)
    bne 4f
    tst.b SCAN_D_KEY(%a0)
    beq 5f
4:  or.b #MENU_RIGHT, %d0
5:  move.b OFF_MENU_KEYS(%a5), %d1
    move.b %d0, OFF_MENU_KEYS(%a5)
    not.b %d1
    and.b %d1, %d0                      | the ones that went down this frame
    btst #1, %d0
    beq 6f
    moveq #-1, %d1
    bsr menu_move
6:  btst #2, %d0
    beq 7f
    moveq #1, %d1
    bsr menu_move
7:  btst #0, %d0
    beq 9f
    bsr menu_close
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| Move the B item to the next one Link owns, d1.w = -1 or 1, and redraw.
menu_move:
    movem.l %d0/%d2, -(%sp)
    moveq #0, %d2
    move.b OFF_B_ITEM(%a5), %d2
    moveq #(B_LAST - 1), %d0            | at most all the other items
1:  add.w %d1, %d2
    cmp.w #B_BOMB, %d2
    bhs 2f
    moveq #B_LAST, %d2
2:  cmp.w #B_LAST, %d2
    bls 3f
    moveq #B_BOMB, %d2
3:  movem.l %d0-%d1, -(%sp)
    move.w %d2, %d0
    bsr b_item_owned
    tst.w %d0
    movem.l (%sp)+, %d0-%d1
    bne 4f
    dbra %d0, 1b
    bra 9f                              | nothing else to choose
4:  move.b %d2, OFF_B_ITEM(%a5)
    sfx SFX_RUPEE                       | the selection click
    move.b #1, OFF_HUD_DIRTY(%a5)
    bsr menu_draw
9:  movem.l (%sp)+, %d0/%d2
    rts

menu_close:
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bsr show_background_far             | the room as it was, without sprites
    bsr clear_erase_state_far
    move.b #1, OFF_HUD_DIRTY(%a5)
    rts

menu_draw:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    movea.l OFF_SCREEN_PTR(%a5), %a1    | the playfield goes black
    adda.l #PLAYFIELD_ORIGIN, %a1
    move.w #(PLAYFIELD_HEIGHT - 1), %d7
    moveq #0, %d0
1:  moveq #(PLAYFIELD_BYTES / 4 - 1), %d6
    movea.l %a1, %a2
2:  move.l %d0, (%a2)+
    dbra %d6, 2b
    adda.w #SCREEN_STRIDE, %a1
    dbra %d7, 1b

    lea menu_title(%pc), %a0
    moveq #14, %d1
    moveq #6, %d2
    bsr menu_text
    lea menu_hint1(%pc), %a0
    moveq #6, %d1
    moveq #20, %d2
    bsr menu_text
    lea menu_hint2(%pc), %a0
    moveq #4, %d1
    moveq #22, %d2
    bsr menu_text
    lea menu_hint3(%pc), %a0
    moveq #6, %d1
    moveq #24, %d2
    bsr menu_text

    moveq #B_BOMB, %d3                  | the eight items Link might put on B
3:  move.w %d3, %d0
    bsr b_item_owned
    tst.w %d0
    beq 8f
    move.w %d3, %d4
    subq.w #1, %d4
    move.w %d4, %d5
    lsr.w #2, %d5                       | 0 for the top row of cells, 1 for the bottom one
    and.w #3, %d4
    lea menu_cells(%pc), %a0
    moveq #0, %d6
    move.b 0(%a0, %d4.w), %d6           | d6 = the cell's column
    lsl.w #2, %d5
    add.w #MENU_ICON_ROW, %d5           | d5 = the picture's row
    move.w %d3, %d0
    bsr b_icon
    ltab hud_items, %a0
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    move.w %d6, %d1
    addq.w #1, %d1
    move.w %d5, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    addq.w #1, %d2
    bsr draw_hud_tile_ptr
    lea menu_names(%pc), %a0
    move.w %d3, %d0
    subq.w #1, %d0
    mulu.w #10, %d0
    adda.w %d0, %a0
    move.w %d6, %d1
    move.w %d5, %d2
    addq.w #2, %d2
    bsr menu_text
    cmp.b OFF_B_ITEM(%a5), %d3
    bne 8f
    move.w %d6, %d1                     | the B label marks the chosen one
    addq.w #1, %d1
    move.w %d5, %d2
    subq.w #1, %d2
    moveq #HUD_CH_B, %d0
    bsr draw_hud_tile
8:  addq.w #1, %d3
    cmp.w #B_LAST, %d3
    bls 3b
    bsr menu_passive
7:  bsr menu_dungeon
    movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| The items he carries: a picture each for the ones he owns, in fixed places along one row.
menu_passive:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    lea passive_slots(%pc), %a1
    lea passive_icons(%pc), %a2
    moveq #0, %d4
1:  moveq #0, %d0
    move.b 0(%a1, %d4.w), %d0
    cmp.b #0xff, %d0
    beq 9f
    lea OFF_ITEMS(%a5), %a0
    moveq #0, %d3
    move.b 0(%a0, %d0.w), %d3           | how much of it he has
    beq 8f
    moveq #0, %d0
    move.b 0(%a2, %d4.w), %d0
    cmp.b #20, %d0                      | the ring: the red one has its own picture
    bne 2f
    cmp.b #2, %d3
    bne 2f
    moveq #21, %d0
2:  ltab hud_items, %a0
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    move.w %d4, %d1
    mulu.w #3, %d1
    addq.w #6, %d1
    moveq #MENU_PASSIVE_ITEMS_ROW, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    addq.w #1, %d2
    bsr draw_hud_tile_ptr
8:  addq.w #1, %d4
    bra 1b
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

menu_cells:
    .byte 4, 14, 24, 32
passive_slots:                          | raft, book, ring, ladder, magic key, bracelet, letter, magic shield
    .byte 9, 10, 11, 12, 13, 14, 15, 31, 0xff
passive_icons:
    .byte 18, 19, 20, 22, 23, 24, 26, 25
    .align 2

| In a dungeon the screen also shows its map, and the compass and map icons he owns on either
| side of it (the original's passive items). The map is drawn like the ribbon's, only bigger.
    .equ MENU_PASSIVE_ROW, 3
    .equ MENU_COMPASS_COL, 8
    .equ MENU_MAP_ICON_COL, 29
    .equ HUD_ICON_COMPASS, 4
    .equ HUD_ICON_MAP, 5
    .equ HUD_ICON_BOW, 6

menu_dungeon:
    movem.l %d0-%d6/%a0-%a3, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    moveq #0, %d6
    move.b OFF_LEVEL(%a5), %d6
    subq.w #1, %d6
    and.w #7, %d6
    moveq #1, %d5
    lsl.b %d6, %d5
    move.b OFF_INV_COMPASS(%a5), %d0
    and.b %d5, %d0
    beq 1f
    moveq #HUD_ICON_COMPASS, %d0
    moveq #MENU_COMPASS_COL, %d1
    bsr menu_icon
    lea menu_compass(%pc), %a0
    moveq #(MENU_COMPASS_COL - 3), %d1
    moveq #(MENU_PASSIVE_ROW + 2), %d2
    bsr menu_text
1:  move.b OFF_INV_MAP(%a5), %d0
    and.b %d5, %d0
    beq 2f
    moveq #HUD_ICON_MAP, %d0
    moveq #MENU_MAP_ICON_COL, %d1
    bsr menu_icon
    lea menu_map(%pc), %a0
    moveq #(MENU_MAP_ICON_COL - 1), %d1
    moveq #(MENU_PASSIVE_ROW + 2), %d2
    bsr menu_text
2:  lea mm_box_big(%pc), %a3
    bsr minimap_paint
9:  movem.l (%sp)+, %d0-%d6/%a0-%a3
    rts

| A ribbon item picture (two tiles, top then bottom): d0.w = icon, d1.w = column.
menu_icon:
    movem.l %d0-%d2/%a0, -(%sp)
    ltab hud_items, %a0
    mulu.w #(2 * HUD_TILE_BYTES), %d0
    adda.l %d0, %a0
    moveq #MENU_PASSIVE_ROW, %d2
    bsr draw_hud_tile_ptr
    lea HUD_TILE_BYTES(%a0), %a0
    moveq #(MENU_PASSIVE_ROW + 1), %d2
    bsr draw_hud_tile_ptr
    movem.l (%sp)+, %d0-%d2/%a0
    rts

| Write the string at a0 with the ribbon's glyphs. d1.w = column, d2.w = row.
menu_text:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    ltab text_glyphs, %a1
1:  moveq #0, %d3
    move.b (%a0)+, %d3
    beq 9f
    moveq #0x24, %d4                    | anything unknown is a space
    cmp.b #'0', %d3
    blo 3f
    cmp.b #'9', %d3
    bhi 2f
    move.w %d3, %d4
    sub.w #'0', %d4
    bra 6f
2:  cmp.b #'A', %d3
    blo 3f
    cmp.b #'Z', %d3
    bhi 6f
    move.w %d3, %d4
    sub.w #('A' - 10), %d4
    bra 6f
3:  cmp.b #'.', %d3
    bne 4f
    moveq #0x2c, %d4
    bra 6f
4:  cmp.b #'-', %d3
    bne 6f
    moveq #0x2f, %d4
6:  moveq #0, %d0
    move.b 0(%a1, %d4.w), %d0
    bsr draw_hud_tile
    addq.w #1, %d1
    bra 1b
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

menu_title:
    .asciz "INVENTORY"
menu_compass:
    .asciz "COMPASS"
menu_map:
    .asciz "MAP"
menu_hint1:
    .asciz "ARROWS CHOOSE THE B ITEM"
menu_hint2:
    .asciz "SPACE SWORD   CTRL OR ALT B ITEM"
menu_hint3:
    .asciz "TAB   BACK TO THE GAME"
    | ten bytes each, in B item order
menu_names:
    .asciz "BOMBS"
    .space 4
    .asciz "BOOMERANG"
    .asciz "CANDLE"
    .space 3
    .asciz "BOW"
    .space 6
    .asciz "RECORDER"
    .space 1
    .asciz "FOOD"
    .space 5
    .asciz "POTION"
    .space 3
    .asciz "ROD"
    .space 6
    .align 2
