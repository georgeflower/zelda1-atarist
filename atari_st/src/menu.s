| The inventory screen: Tab freezes the game and shows what the ROM's submenu shows (Z_05.asm UpdateMenu*,
| DrawSubmenuItems, UpdateSubmenuSelection), laid out as the NES has it in the end: the inventory fills the 22 tile
| rows of the play area and the status ribbon sits below it.
|
|   the picture     INVENTORY, the box of the B item with "USE B BUTTON FOR THIS", the box of the eight B items, and, on
|                   the overworld, the empty triforce (the pieces Link has are filled in as UpdateMenuStartOW does) or, in a
|                   dungeon, the sheet map with MAP and COMPASS beside it. tools/submenu.py makes it from the ROM's transfer
|                   buffers; draw_tile_abs puts it on the screen cell by cell.
|   the sprites     the items at the places of SubmenuItemXs, the chosen one again in the B box, the flashing cursor and,
|                   in a dungeon, the dot on the room Link is in (frames of menu_sprites).
|   the sheet map   one cell per room: unvisited rooms are the solid mark, a visited one is the mark that shows its open
|                   doorways (tile $E2 + the doorway mask), the rotation and the mask of the level as the ROM has them.
|
| Left and Right move the cursor over the nine slots as FindAndSelectOccupiedItemSlot does (the boomerang first, the bow's own
| slot is skipped) and put that item on B; Tab goes back. It is drawn straight onto the visible screen like the caves, so
| double buffering is off while it is open; the room under it stays in bg_cur and is put back on closing.

    .equ SCAN_TAB, 0x0f
    .equ SCAN_LEFT_ARROW, 0x4b
    .equ SCAN_RIGHT_ARROW, 0x4d
    .equ SCAN_A_KEY, 0x1e
    .equ SCAN_D_KEY, 0x20

    .equ MENU_TAB, 1
    .equ MENU_LEFT, 2
    .equ MENU_RIGHT, 4

    .equ MENU_SLOTS, 9                  | the slots of the cursor: 0 boomerang, 1 bomb, 2 arrow and bow, 3 (the bow, skipped), 4-8
    .equ MENU_BOW_SLOT, 3
    .equ MENU_SLOT_LIMIT, 0x12          | DrawSubmenuItems draws the item slots 1 to $11
    .equ MENU_LETTER_SLOT, 0x0f
    .equ MENU_COLS, 32
    .equ MENU_ROWS, 22
    .equ MENU_FIRST_COL, 4              | the picture starts four tile columns in on the 320-pixel screen
    .equ MENU_CURSOR_ROW_TOP, ((0x36 + SUBMENU_SPRITE_DY) / 8)   | the cells the cursor stands on (an item's box is 2x2 cells)
    .equ MENU_CURSOR_ROW_BOTTOM, ((0x46 + SUBMENU_SPRITE_DY) / 8)

| Called by update_play once Link and the sprites are erased: Tab opens the screen.
menu_check_open:
    movem.l %d0/%a0, -(%sp)
    tst.b OFF_EXIT_REQUESTED(%a5)       | Esc: the question (quit.s); only while the game is walking
    beq 0f
    tst.b OFF_GAME_MODE(%a5)
    bne 0f
    bsr quit_open
    bra 9f
0:
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
    tst.b OFF_LEVEL(%a5)
    beq 1f
    moveq #0, %d0                       | the room he is in is part of the map, however he got there
    move.b OFF_ROOM_ID(%a5), %d0
    bsr uw_mark_visited
1:  move.b #1, OFF_HUD_DIRTY(%a5)       | the ribbon goes below the picture
    bsr menu_draw
    bra 9f
8:  bclr #0, OFF_MENU_KEYS(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

update_menu:
    movem.l %d0-%d2/%a0, -(%sp)
    tst.b OFF_EXIT_REQUESTED(%a5)       | Esc closes the screen; the game is walking again and asks next frame
    beq 0f
    bsr menu_close
    bra 9f
0:
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
5:  move.b OFF_JOY0(%a5), %d1           | the joystick walks the cursor too (an emulator's cursor keys come as joystick packets)
    or.b OFF_JOY1(%a5), %d1
    btst #2, %d1
    beq 51f
    or.b #MENU_LEFT, %d0
51: btst #3, %d1
    beq 52f
    or.b #MENU_RIGHT, %d0
52: move.b OFF_MENU_KEYS(%a5), %d1
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
    beq 8f
    bsr menu_close
    bra 9f
8:  move.w OFF_FRAME_COUNTER(%a5), %d0  | the cursor flashes between two palette rows, eight frames each
    and.w #8, %d0
    lsr.w #3, %d0
    cmp.b OFF_MENU_PHASE(%a5), %d0
    beq 9f
    move.b %d0, OFF_MENU_PHASE(%a5)
    bsr menu_cursor_redraw
9:  movem.l (%sp)+, %d0-%d2/%a0
    rts

| The slot of the cursor for each B code, and the B code of each slot (0 for the bow's own slot, which cannot be chosen).
menu_code_slot:
    .byte 0, 1, 0, 4, 2, 5, 6, 7, 8, 7    | the letter sits where the potion would
menu_slot_code:
    .byte B_BOOMERANG, B_BOMB, B_BOW, 0, B_CANDLE, B_RECORDER, B_FOOD, B_POTION, B_ROD
    .align 2

| d0.w = the slot the cursor is on: that of the B item (0, where the boomerang goes, when there is none).
menu_selected:
    moveq #0, %d0
    move.b OFF_B_ITEM(%a5), %d0
    cmp.w #B_LAST, %d0
    bhi 1f
    move.b (menu_code_slot, %pc, %d0.w), %d0
    rts
1:  moveq #0, %d0
    rts

| Move the cursor to the next slot that holds an item Link can use, d1.w = -1 or 1, and put the item on B
| (FindAndSelectOccupiedItemSlot: at most nine slots, wrapping round; the arrow's slot counts only with the bow).
menu_move:
    movem.l %d0-%d3/%a0, -(%sp)
    bsr menu_selected
    move.w %d0, %d2
    moveq #(MENU_SLOTS - 1), %d3
1:  add.w %d1, %d2
    bpl 2f
    moveq #(MENU_SLOTS - 1), %d2
2:  cmp.w #MENU_SLOTS, %d2
    blo 3f
    moveq #0, %d2
3:  cmp.w #MENU_BOW_SLOT, %d2
    beq 5f
    bsr menu_slot_code_of
    bsr b_item_owned
    tst.w %d0
    bne 4f
5:  dbra %d3, 1b
    bra 9f                              | nothing else to choose
4:  bsr menu_slot_code_of
    cmp.b OFF_B_ITEM(%a5), %d0
    beq 9f                              | only the one he had
    move.b %d0, OFF_B_ITEM(%a5)
    sfx SFX_RUPEE                       | the selection click
    move.b #1, OFF_HUD_DIRTY(%a5)
    bsr menu_draw
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

| d2.w = a slot of the cursor. Returns d0.w = its B code (a0 is lost): the potion's place holds the letter while there is no potion.
menu_slot_code_of:
    lea menu_slot_code(%pc), %a0
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d0
    cmp.w #B_POTION, %d0
    bne 9f
    tst.b OFF_INV_POTION(%a5)
    bne 9f
    tst.b OFF_INV_LETTER(%a5)
    beq 9f
    moveq #B_LETTER, %d0
9:  rts

menu_close:
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    bsr menu_clear                      | nothing of the picture or of the ribbon below it stays
    bsr show_background_far             | the room as it was, without sprites
    bsr clear_erase_state_far
    move.b #1, OFF_HUD_DIRTY(%a5)
    rts

| The whole screen goes black.
menu_clear:
    movem.l %d0-%d4/%a0, -(%sp)
    movea.l OFF_SCREEN_PTR(%a5), %a0
    moveq #0, %d0
    moveq #0, %d1
    moveq #0, %d2
    moveq #0, %d3
    move.w #(SCREEN_LONGS / 4 - 1), %d4
1:  move.l %d0, (%a0)+
    move.l %d1, (%a0)+
    move.l %d2, (%a0)+
    move.l %d3, (%a0)+
    dbra %d4, 1b
    movem.l (%sp)+, %d0-%d4/%a0
    rts

menu_draw:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d0  | the cursor's colour, so that update_menu knows when it turns over
    and.w #8, %d0
    lsr.w #3, %d0
    move.b %d0, OFF_MENU_PHASE(%a5)
    bsr menu_clear
    bsr menu_picture
    tst.b OFF_LEVEL(%a5)
    bne 1f
    bsr menu_triforce
    bra 2f
1:  bsr menu_sheet_map
2:  bsr menu_items
    bsr menu_b_item
    bsr menu_cursor
    bsr menu_dot
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| a0 = the cells of the picture that belongs to where Link is: the overworld's, or a dungeon's.
menu_picture_base:
    ltab menu_cells, %a0
    tst.b OFF_LEVEL(%a5)
    beq 1f
    adda.w #SUBMENU_PICTURE_BYTES, %a0
1:  rts

| The picture, cell by cell (the static part: what the ROM's transfer buffers write).
menu_picture:
    movem.l %d0-%d2/%a0-%a3, -(%sp)
    bsr menu_picture_base
    movea.l %a0, %a3
    ltab menu_tiles, %a2
    moveq #0, %d2
1:  moveq #MENU_FIRST_COL, %d1
2:  moveq #0, %d0
    move.w (%a3)+, %d0
    lea 0(%a2, %d0.l), %a0
    bsr draw_tile_abs
    addq.w #1, %d1
    cmp.w #(MENU_FIRST_COL + MENU_COLS), %d1
    blo 2b
    addq.w #1, %d2
    cmp.w #MENU_ROWS, %d2
    blo 1b
    movem.l (%sp)+, %d0-%d2/%a0-%a3
    rts

| One cell of the static picture again: d1.w = column, d2.w = row (of the picture).
menu_cell:
    movem.l %d0/%a0-%a1, -(%sp)
    bsr menu_picture_base
    move.w %d2, %d0
    lsl.w #5, %d0
    add.w %d1, %d0
    add.w %d0, %d0
    move.w 0(%a0, %d0.w), %d0
    andi.l #0xffff, %d0
    ltab menu_tiles, %a0
    adda.l %d0, %a0
    addq.w #MENU_FIRST_COL, %d1
    bsr draw_tile_abs
    subq.w #MENU_FIRST_COL, %d1
    movem.l (%sp)+, %d0/%a0-%a1
    rts

| A tile written at run time: d0.b = the NES tile number, d1.w = column, d2.w = row, a3 = the glyphs of the picture.
menu_glyph:
    movem.l %d0/%a0, -(%sp)
    andi.w #0xff, %d0
    add.w %d0, %d0
    move.w 0(%a3, %d0.w), %d0
    andi.l #0xffff, %d0
    ltab menu_tiles, %a0
    adda.l %d0, %a0
    addq.w #MENU_FIRST_COL, %d1
    bsr draw_tile_abs
    subq.w #MENU_FIRST_COL, %d1
    movem.l (%sp)+, %d0/%a0
    rts

| ------------------------------------------------------------------------------------------------ the overworld's triforce
| UpdateMenuStartOW: every piece Link has turns its three tiles (TriforceTriforceBufReplacements) into the full ones; a tile that
| was a half ($E5, $E6) becomes the solid $F5. The four rows of the transfer buffers are one block of memory, which
| TriforceTransferBufOffsets indexes, so the work is done on a copy of it.
menu_triforce:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    suba.w #SUBMENU_TRIFORCE_MEMORY, %sp
    movea.l %sp, %a1
    ltab menu_tri_memory, %a0
    moveq #(SUBMENU_TRIFORCE_MEMORY - 1), %d0
1:  move.b (%a0)+, (%a1)+
    dbra %d0, 1b
    movea.l %sp, %a1
    ltab menu_tri_offsets, %a2
    ltab menu_tri_replace, %a3
    moveq #0, %d5
    move.b OFF_TRIFORCE_PIECES(%a5), %d5
    moveq #1, %d6                       | the level's bit
    moveq #0, %d4                       | the tile slot, 0 to $17
2:  moveq #2, %d3                       | three tiles to a piece
3:  move.b %d5, %d0
    and.b %d6, %d0
    beq 6f                              | he does not have this piece
    moveq #0, %d0
    move.b 0(%a2, %d4.w), %d0
    lea 4(%a1, %d0.w), %a4
    move.b (%a4), %d1
    cmp.b #0xe5, %d1
    beq 4f
    cmp.b #0xe6, %d1
    beq 4f
    move.b 0(%a3, %d4.w), (%a4)
    bra 6f
4:  move.b #0xf5, (%a4)
6:  addq.w #1, %d4
    dbra %d3, 3b
    add.b %d6, %d6
    bne 2b
    ltab menu_glyphs, %a3
    ltab menu_tri_rows, %a2             | the four rows: column, row, length, where their tiles start
    moveq #3, %d7
7:  moveq #0, %d1
    move.b (%a2)+, %d1
    moveq #0, %d2
    move.b (%a2)+, %d2
    moveq #0, %d3
    move.b (%a2)+, %d3
    moveq #0, %d0
    move.b (%a2)+, %d0
    lea 0(%a1, %d0.w), %a4
    subq.w #1, %d3
8:  move.b (%a4)+, %d0
    bsr menu_glyph
    addq.w #1, %d1
    dbra %d3, 8b
    dbra %d7, 7b
    adda.w #SUBMENU_TRIFORCE_MEMORY, %sp
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| ---------------------------------------------------------------------------------------------------- the dungeon's sheet map
| Submenu_WriteSheetMapRowTransferRecord: a cell for each room of the 16x8 level, the mark of a visited room being $E2 plus
| its doorway mask (up, down, left, right from bit 3 to bit 0: a door that is open, or one that was opened), the plain $F5 for
| the rest. The row is rotated right by LevelInfo_SubmenuMapRotation, and LevelInfo_SubmenuMapMask says which cells of the
| screen may show a room at all (bit 7 - row of the byte of the column).
menu_sheet_map:
    movem.l %d0-%d7/%a0-%a4, -(%sp)
    moveq #0, %d7
    move.b OFF_LEVEL(%a5), %d7
    subq.w #1, %d7                      | 0 to 8
    ltab menu_map_rotation, %a0
    moveq #0, %d6
    move.b 0(%a0, %d7.w), %d6           | the rotation
    ltab menu_map_mask, %a1
    lsl.w #4, %d7
    adda.w %d7, %a1                     | this level's sixteen mask bytes
    lvtab ROOM_INDEX, %a2
    lvtab DOORS, %a4
    ltab menu_glyphs, %a3
    adda.w #SUBMENU_GLYPH_BYTES, %a3
    moveq #0, %d5                       | the map row
1:  moveq #0, %d4                       | the map column
2:  move.w %d4, %d3                     | the room that shows here
    sub.w %d6, %d3
    and.w #15, %d3
    move.w %d5, %d0
    lsl.w #4, %d0
    add.w %d0, %d3                      | d3 = its room id
    move.w #0xf5, %d0                   | a room not to be shown, or one Link has not been in
    moveq #7, %d1
    sub.w %d5, %d1
    btst %d1, 0(%a1, %d4.w)
    beq 8f
    uwlea FLAGS, %a0
    btst #UW_FLAG_VISITED, 0(%a0, %d3.w)
    beq 8f
    moveq #0, %d1
    move.b 0(%a2, %d3.w), %d1           | the stored room
    cmp.b #0xff, %d1
    beq 8f
    mulu.w #UW_DOOR_RECORD_BYTES, %d1
    uwlea OPEN, %a0
    moveq #0, %d7
    move.b 0(%a0, %d3.w), %d7           | the doors opened for good
    lea 0(%a4, %d1.l), %a0              | the room's four door types: E, W, S, N
    moveq #0, %d2                       | the doorway mask
    moveq #3, %d1
3:  move.b 0(%a0, %d1.w), %d0
    beq 4f                              | open
    cmp.b #4, %d0
    blo 5f                              | a wall, a false wall: no way through
    btst %d1, %d7
    beq 5f                              | a door that has not been opened
4:  bset %d1, %d2
5:  dbra %d1, 3b
    add.w #0xe2, %d2
    move.w %d2, %d0
8:  move.w %d4, %d1
    add.w #SUBMENU_MAP_COL, %d1
    move.w %d5, %d2
    add.w #SUBMENU_MAP_ROW, %d2
    bsr menu_glyph
    addq.w #1, %d4
    cmp.w #16, %d4
    blo 2b
    addq.w #1, %d5
    cmp.w #8, %d5
    blo 1b
    movem.l (%sp)+, %d0-%d7/%a0-%a4
    rts

| -------------------------------------------------------------------------------------------------------------- the sprites
| A frame of menu_sprites on the screen: d1.w = the frame, d2.w = the NES x of its left edge, d3.w = the NES y the sprite is given
| (its top line is one below, and the picture starts one line above the NES's first line of tile row 8: SUBMENU_SPRITE_DY).
menu_frame:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    ltab menu_sprites, %a0
    andi.l #0xffff, %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    adda.l %d1, %a0
    add.w #SUBMENU_SPRITE_DY, %d3
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
    moveq #(SPRITE_HEIGHT - 1), %d7
    bsr draw_sprite_rows
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| d0.w = a slot, d5.b = what Link has of it (not 0): d1.w = the frame of its picture (one for the value 1, one for 2, one for the
| rest).
menu_frame_of:
    movem.l %d0/%a0, -(%sp)
    mulu.w #3, %d0
    cmp.b #1, %d5
    beq 1f
    addq.w #1, %d0
    cmp.b #2, %d5
    beq 1f
    addq.w #1, %d0
1:  ltab menu_slot_frames, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    movem.l (%sp)+, %d0/%a0
    rts

| d5.b = 1 when Link has the compass (slot $10) or the map (slot $11, d4.w) of the level he is in (HasCompass, HasMap).
menu_level_item:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d5
    tst.b OFF_LEVEL(%a5)
    beq 9f
    moveq #0, %d0
    move.b OFF_LEVEL(%a5), %d0
    subq.w #1, %d0
    and.w #7, %d0
    moveq #1, %d1
    lsl.b %d0, %d1
    move.b OFF_INV_COMPASS(%a5), %d0
    cmp.w #0x11, %d4
    bne 1f
    move.b OFF_INV_MAP(%a5), %d0
1:  and.b %d1, %d0
    beq 9f
    moveq #1, %d5
9:  movem.l (%sp)+, %d0-%d1
    rts

| DrawSubmenuItems: the boomerang (the magic one first), then slots 1 to $11 at their places.
menu_items:
    movem.l %d0-%d5/%a0-%a3, -(%sp)
    lea OFF_ITEMS(%a5), %a3
    moveq #SUBMENU_FRAME_MAGIC_BOOMERANG, %d1
    tst.b 30(%a3)
    bne 1f
    moveq #SUBMENU_FRAME_BOOMERANG, %d1
    tst.b 29(%a3)
    beq 2f
1:  move.w #SUBMENU_BOOMERANG_X, %d2
    move.w #SUBMENU_BOOMERANG_Y, %d3
    bsr menu_frame
2:  moveq #1, %d4                       | the item slot
3:  moveq #0, %d5
    move.b 0(%a3, %d4.w), %d5
    cmp.w #0x10, %d4
    blo 5f
    bsr menu_level_item
5:  tst.b %d5
    beq 8f
    cmp.w #MENU_LETTER_SLOT, %d4
    bne 6f
    tst.b 7(%a3)                        | the letter makes room for a potion
    bne 8f
6:  move.w %d4, %d0
    bsr menu_frame_of
    ltab menu_slot_x, %a0
    moveq #0, %d2
    move.b 0(%a0, %d4.w), %d2
    ltab menu_slot_y, %a0
    moveq #0, %d3
    move.b 0(%a0, %d4.w), %d3
    bsr menu_frame
8:  addq.w #1, %d4
    cmp.w #MENU_SLOT_LIMIT, %d4
    blo 3b
    movem.l (%sp)+, %d0-%d5/%a0-%a3
    rts

| The item on B again in its box (UpdateSubmenuSelection: the picture of the slot the cursor is on).
menu_b_item:
    movem.l %d0-%d5/%a0, -(%sp)
    tst.b OFF_B_ITEM(%a5)
    beq 9f
    bsr menu_selected
    tst.w %d0
    bne 1f
    moveq #SUBMENU_FRAME_MAGIC_BOOMERANG, %d1
    tst.b OFF_INV_MAGIC_BOOMERANG(%a5)
    bne 3f
    moveq #SUBMENU_FRAME_BOOMERANG, %d1
    tst.b OFF_INV_BOOMERANG(%a5)
    bne 3f
    bra 9f
1:  cmpi.b #B_LETTER, OFF_B_ITEM(%a5)
    bne 11f
    moveq #MENU_LETTER_SLOT, %d0        | the letter is slot $F, drawn where the potion would be
11: lea OFF_ITEMS(%a5), %a0
    moveq #0, %d5
    move.b 0(%a0, %d0.w), %d5
    beq 9f
    bsr menu_frame_of
3:  move.w #SUBMENU_B_BOX_X, %d2
    move.w #SUBMENU_B_BOX_Y, %d3
    bsr menu_frame
9:  movem.l (%sp)+, %d0-%d5/%a0
    rts

| The cursor over the slot of the B item, in the colour of the moment.
menu_cursor:
    movem.l %d0-%d3/%a0, -(%sp)
    bsr menu_selected
    move.w %d0, %d1
    ltab menu_cursor_x, %a0
    moveq #0, %d2
    move.b 0(%a0, %d1.w), %d2
    move.w #0x36, %d3
    cmp.w #5, %d1
    blo 1f
    move.w #0x46, %d3
1:  moveq #SUBMENU_FRAME_CURSOR_A, %d1
    move.w OFF_FRAME_COUNTER(%a5), %d0
    and.w #8, %d0
    beq 2f
    moveq #SUBMENU_FRAME_CURSOR_B, %d1
2:  bsr menu_frame
    movem.l (%sp)+, %d0-%d3/%a0
    rts

| The cursor changed colour: the four cells under it from the picture, the items again (it stands over one) and the cursor.
menu_cursor_redraw:
    movem.l %d0-%d2/%a0, -(%sp)
    bsr menu_selected
    ltab menu_cursor_x, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    lsr.w #3, %d1                       | the column of its first cell
    moveq #MENU_CURSOR_ROW_TOP, %d2
    cmp.w #5, %d0
    blo 1f
    moveq #MENU_CURSOR_ROW_BOTTOM, %d2
1:  bsr menu_cell
    addq.w #1, %d1
    bsr menu_cell
    addq.w #1, %d2
    bsr menu_cell
    subq.w #1, %d1
    bsr menu_cell
    bsr menu_items
    bsr menu_cursor
    movem.l (%sp)+, %d0-%d2/%a0
    rts

| In a dungeon the dot on the room Link is in (UpdateMenuScrollDownUW): x = $62 + the room's column * 8, moved by the map's
| rotation, y = $69 + its row * 8. Not in a cellar.
menu_dot:
    movem.l %d0-%d3/%a0, -(%sp)
    tst.b OFF_LEVEL(%a5)
    beq 9f
    tst.b OFF_IN_CELLAR(%a5)
    bne 9f
    moveq #0, %d0
    move.b OFF_LEVEL(%a5), %d0
    subq.w #1, %d0
    ltab menu_map_rotation, %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1           | the rotation
    moveq #0, %d2
    move.b OFF_ROOM_ID(%a5), %d2
    move.w %d2, %d3
    and.w #15, %d2
    lsl.w #3, %d2                       | the column * 8
    cmp.w #8, %d1
    bhs 1f
    lsl.w #3, %d1
    add.w %d1, %d2                      | a short rotation moves it right
    bra 2f
1:  moveq #16, %d0
    sub.w %d1, %d0
    lsl.w #3, %d0
    sub.w %d0, %d2                      | a long one is a negative one
2:  add.w #SUBMENU_MARKER_X, %d2
    andi.w #0xff, %d2
    and.w #0xf0, %d3
    lsr.w #1, %d3
    add.w #SUBMENU_MARKER_Y, %d3
    moveq #SUBMENU_FRAME_DOT, %d1
    bsr menu_frame
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts
