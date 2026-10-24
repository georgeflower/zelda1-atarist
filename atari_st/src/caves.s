| Caves, shops and the people in them (UpdateCavePerson and InitCave of the original).
|
| The twenty overworld cave types sit in cave_table, sixteen bytes each (see build_caves in
| tools/build_assets.py): the cave flags, who stands there, the three wares and prices, and where
| the speech starts in cave_text. A cave type is ((attribute B & $FC) - $40) / 4; attribute $50 is
| the take-any-road room, which has a second layout and three staircases.
|
| The person's states follow the original's: he talks (CS_TALK), then Link chooses by touching a
| ware (CS_CHOOSE). What comes of it depends on the cave: a gift or a purchase (CS_DELAY, the
| person and the wares flicker for $40 frames and vanish), a paid hint (CS_HINT, a second speech),
| a wager (CS_SHOW), or the moblin's rupees (CS_SHOW). The potion seller waits for the letter
| (CS_LETTER). Rupees owed or earned drip through RUPEES_ADD and RUPEES_SUB, one every other frame.

    .equ CS_NONE, 0
    .equ CS_TALK, 1                 | the speech is being typed
    .equ CS_CHOOSE, 2               | Link may touch a ware
    .equ CS_HINT, 3                 | the hint is being typed
    .equ CS_DELAY, 4                | something was taken: the cave flickers, then empties
    .equ CS_SHOW, 5                 | nothing more happens, the person stays
    .equ CS_LETTER, 6               | the medicine woman waits for the letter

    .equ CF_PICK, 0x01
    .equ CF_PAY, 0x02
    .equ CF_WARES, 0x04
    .equ CF_PRICES, 0x08
    .equ CF_HINT, 0x10
    .equ CF_MONEY, 0x20
    .equ CF_HEARTS, 0x40
    .equ CF_MINUS, 0x80

    .equ CAVE_TYPES, 20
    .equ CAVE_NO_WARE, 0x3f
    .equ CAVE_WARE_TAKEN, 0xff
    .equ CAVE_ENTRY_X, 0x70         | Link comes in at ($70, $DD)
    .equ CAVE_STAIRS_Y, 0x9d
    .equ CAVE_ICON_X, 0x30
    .equ CAVE_ICON_Y, 0xab
    .equ CAVE_PRICE_COL, 12
    .equ CAVE_PRICE_ROW, 17
    .equ CAVE_TOUCH_X, 6
    .equ CAVE_TOUCH_Y, 6
    .equ CAVE_DELAY_FRAMES, 0x40
    .equ CAVE_FLAG_BIT, 4           | OW_KILLS: this cave has given what it had
    .equ CAVE_TYPE_DOOR, 7          | $71: the door repair charge
    .equ CAVE_TYPE_WHITE, 2         | $6C: five hearts for the white sword
    .equ CAVE_TYPE_POTION, 10       | $74: the medicine woman
    .equ CAVE_TYPE_MONEY, 6         | $70: the money making game
    .equ CAVE_DOOR_CHARGE, 20
    .equ CAVE_WHO_MOBLIN, 3
    .equ CODE_X, 0x21
    .equ CODE_BLANK, 0x24
    .equ CODE_MINUS, 0x2f
    .equ CODE_PLUS_SIGN, 0x2b
    | The types that remember (6A-6D, 71, 72, 7B-7D): a bit for each cave index.
    .equ CAVE_PERSISTENT, 0x000e018f

| Set up the cave Link just entered. enter_cave has already cleared the items.
cave_setup:
    movem.l %d0-%d3/%a0-%a1, -(%sp)
    clr.b OFF_CAVE_PERSON(%a5)
    clr.b OFF_CAVE_TEXT_ON(%a5)
    clr.b OFF_CAVE_STATE(%a5)
    clr.b OFF_CAVE_ICON(%a5)
    clr.b OFF_CAVE_ROOMKIND(%a5)
    lea OFF_CAVE_SPR_VALID(%a5), %a0
    clr.b (%a0)+
    clr.b (%a0)
    move.b #CAVE_ENTRY_X, OFF_LINK_X(%a5)
    moveq #0, %d1
    move.b OFF_CAVE_SOURCE_ROOM(%a5), %d1       | d1 = the screen the cave is behind
    ltab room_attr_b, %a0
    moveq #0, %d0
    move.b 0(%a0, %d1.w), %d0
    and.w #0x00fc, %d0
    cmp.w #0x50, %d0
    bne 1f
    move.b #1, OFF_CAVE_ROOMKIND(%a5)
1:  sub.w #0x40, %d0
    bmi 9f
    lsr.w #2, %d0                               | d0 = the cave's index
    cmp.w #CAVE_TYPES, %d0
    bhs 9f
    move.b %d0, OFF_CAVE_TYPE(%a5)
    move.l #CAVE_PERSISTENT, %d2
    btst %d0, %d2
    beq 2f
    lea OFF_OW_KILLS(%a5), %a1
    btst #CAVE_FLAG_BIT, 0(%a1, %d1.w)
    bne 9f                                      | it gave already: only the bonfires are left
2:  lsl.w #4, %d0
    ltab cave_table, %a0
    adda.w %d0, %a0                             | a0 = the cave's record
    move.b (%a0), OFF_CAVE_FLAGS(%a5)
    move.b 1(%a0), OFF_CAVE_WHO(%a5)
    lea OFF_CAVE_ITEMS(%a5), %a1
    move.b 2(%a0), (%a1)+
    move.b 3(%a0), (%a1)+
    move.b 4(%a0), (%a1)
    lea OFF_CAVE_PRICES(%a5), %a1
    move.b 5(%a0), (%a1)+
    move.b 6(%a0), (%a1)+
    move.b 7(%a0), (%a1)
    move.w 8(%a0), OFF_CAVE_TEXT_IDXW(%a5)
    move.b #1, OFF_CAVE_PERSON(%a5)
    cmpi.b #CAVE_TYPE_POTION, OFF_CAVE_TYPE(%a5)
    bne 3f
    cmpi.b #2, OFF_INV_LETTER(%a5)
    beq 3f
    move.b #CS_LETTER, OFF_CAVE_STATE(%a5)      | she says nothing until she is shown the letter
    bra 9f
3:  bsr cave_open
9:  movem.l (%sp)+, %d0-%d3/%a0-%a1
    rts

| The wares and prices appear and the person starts to speak.
cave_open:
    movem.l %d0-%d3/%a0, -(%sp)
    move.b #CS_TALK, OFF_CAVE_STATE(%a5)
    btst #5, OFF_CAVE_FLAGS(%a5)                | CF_MONEY
    beq 1f
    cmpi.b #CAVE_WHO_MOBLIN, OFF_CAVE_WHO(%a5)
    beq 1f
    bsr cave_money_setup
1:  bsr cave_wares_setup
    btst #3, OFF_CAVE_FLAGS(%a5)                | CF_PRICES
    beq 2f
    move.b #1, OFF_CAVE_ICON(%a5)
2:  move.b #1, OFF_CAVE_TEXT_ON(%a5)
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_ROW0, OFF_CAVE_TEXT_ROW(%a5)
    move.b #CAVE_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    movem.l (%sp)+, %d0-%d3/%a0
    rts

| The prices go on the screen once the room is drawn (enter_cave draws it after cave_setup).
cave_dress:
    movem.l %d0, -(%sp)
    tst.b OFF_CAVE_ICON(%a5)
    beq 9f
    moveq #CODE_X, %d0
    bsr cave_draw_prices
9:  movem.l (%sp)+, %d0
    rts

cave_ware_x:
    .byte 0x58, 0x78, 0x98
cave_who_frame:
    .byte 0, 3, 4, 5            | the old man, the old woman, the shopkeeper, the moblin
    .align 2

| The three wares become item objects on the floor.
cave_wares_setup:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    btst #2, OFF_CAVE_FLAGS(%a5)                | CF_WARES
    beq 9f
    lea cave_ware_x(%pc), %a0
    lea OFF_CAVE_ITEMS(%a5), %a1
    moveq #0, %d1
1:  moveq #0, %d0
    move.b 0(%a1, %d1.w), %d0
    cmp.b #CAVE_NO_WARE, %d0
    beq 2f
    cmp.b #CAVE_WARE_TAKEN, %d0
    beq 2f
    move.b %d0, OFF_ITEM_ID(%a5, %d1.w)
    move.b 0(%a0, %d1.w), OFF_ITEM_X(%a5, %d1.w)
    move.b #CAVE_ITEM_Y, OFF_ITEM_Y(%a5, %d1.w)
    move.b #2, OFF_ITEM_ACTIVE(%a5, %d1.w)
2:  addq.w #1, %d1
    cmp.w #3, %d1
    blo 1b
9:  movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| The money making game: three amounts in a random order, a loss of 10 or 40, a loss of 10 and a win of 20
| or 50 (the original weighs its six orders a little unevenly; here they are equally likely).
cave_money_setup:
    movem.l %d0-%d5/%a0-%a1, -(%sp)
    bsr rand8
    and.l #0xff, %d0
    divu.w #6, %d0
    swap %d0                                    | the remainder: which order
    mulu.w #3, %d0
    lea cave_orders(%pc), %a0
    adda.w %d0, %a0
    bsr rand8
    moveq #10, %d3                              | the first amount: a loss of 10 or 40
    btst #0, %d0
    beq 1f
    moveq #40, %d3
1:  moveq #20, %d5                              | the third: a win of 20 or 50
    btst #1, %d0
    beq 2f
    moveq #50, %d5
2:  moveq #10, %d4                              | the second: a loss of 10
    lea OFF_CAVE_AMOUNTS(%a5), %a1
    moveq #2, %d2
3:  moveq #0, %d0
    move.b (%a0)+, %d0
    move.w %d3, %d1
    tst.w %d0
    beq 4f
    move.w %d4, %d1
    cmp.w #1, %d0
    beq 4f
    move.w %d5, %d1
4:  move.b %d1, (%a1)+
    dbra %d2, 3b
    movem.l (%sp)+, %d0-%d5/%a0-%a1
    rts

cave_orders:
    .byte 0, 1, 2, 1, 2, 0, 2, 0, 1, 0, 2, 1, 2, 1, 0, 1, 0, 2
    .align 2

| d0.b = the character to put before the prices ("X", or a blank). Draws "X  nnn  nnn  nnn" on the price row.
cave_draw_prices:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    lea -16(%sp), %sp
    movea.l %sp, %a1
    move.b %d0, (%a1)+
    lea OFF_CAVE_PRICES(%a5), %a0
    moveq #0, %d2
1:  move.b #CODE_BLANK, (%a1)+
    moveq #0, %d0
    move.b 0(%a0, %d2.w), %d0
    bsr cave_format_price
    addq.w #1, %d2
    cmp.w #3, %d2
    blo 1b
    move.b #0xff, (%a1)
    movea.l %sp, %a0
    moveq #CAVE_PRICE_COL, %d1
    moveq #CAVE_PRICE_ROW, %d2
    bsr uw_put_codes
    lea 16(%sp), %sp
    movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| d0.w = a price: three text codes go to (a1)+, leading zeros blank, and a minus where the first digit
| would be when the cave's flags ask for one (a three digit price loses it, as in the original).
cave_format_price:
    movem.l %d0-%d4, -(%sp)
    tst.w %d0
    bne 1f
    move.b #CODE_BLANK, (%a1)+
    move.b #CODE_BLANK, (%a1)+
    move.b #CODE_BLANK, (%a1)+
    bra 9f
1:  and.l #0xff, %d0
    divu.w #100, %d0
    move.w %d0, %d1                             | hundreds
    swap %d0
    and.l #0xffff, %d0
    divu.w #10, %d0
    move.w %d0, %d2                             | tens
    swap %d0
    move.w %d0, %d3                             | ones
    tst.w %d1
    bne 2f
    moveq #CODE_BLANK, %d4                      | no hundreds: a blank, and no tens is one more
    tst.w %d2
    bne 3f
    moveq #CODE_BLANK, %d2
    bra 3f
2:  move.w %d1, %d4
3:  btst #7, OFF_CAVE_FLAGS(%a5)                | CF_MINUS
    beq 5f
    cmp.b #CODE_BLANK, %d2
    bne 4f
    moveq #CODE_MINUS, %d2
    bra 5f
4:  cmp.b #CODE_BLANK, %d4
    bne 5f
    moveq #CODE_MINUS, %d4
5:  move.b %d4, (%a1)+
    move.b %d2, (%a1)+
    move.b %d3, (%a1)+
9:  movem.l (%sp)+, %d0-%d4
    rts

| Blank the speech and the price row.
cave_wipe_text:
    movem.l %d0-%d3, -(%sp)
    moveq #CAVE_TEXT_COL0, %d1
    moveq #CAVE_TEXT_ROW0, %d2
    moveq #24, %d0
    moveq #3, %d3
    bsr uw_wipe
    movem.l (%sp)+, %d0-%d3
    rts

cave_wipe_prices:
    movem.l %d0-%d3, -(%sp)
    moveq #CAVE_PRICE_COL, %d1
    moveq #CAVE_PRICE_ROW, %d2
    moveq #13, %d0
    moveq #1, %d3
    bsr uw_wipe
    movem.l (%sp)+, %d0-%d3
    rts

| d0.w = rupees owed: add to what is already being paid.
cave_post_debit:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d1
    move.b OFF_RUPEES_SUB(%a5), %d1
    add.w %d0, %d1
    cmp.w #255, %d1
    bls 1f
    move.w #255, %d1
1:  move.b %d1, OFF_RUPEES_SUB(%a5)
    movem.l (%sp)+, %d0-%d1
    rts

cave_post_credit:
    movem.l %d0-%d1, -(%sp)
    moveq #0, %d1
    move.b OFF_RUPEES_ADD(%a5), %d1
    add.w %d0, %d1
    cmp.w #255, %d1
    bls 1f
    move.w #255, %d1
1:  move.b %d1, OFF_RUPEES_ADD(%a5)
    movem.l (%sp)+, %d0-%d1
    rts

| The cave has given what it had: it remembers (the types that do).
cave_set_flag:
    movem.l %d0/%a0, -(%sp)
    moveq #0, %d0
    move.b OFF_CAVE_SOURCE_ROOM(%a5), %d0
    lea OFF_OW_KILLS(%a5), %a0
    bset #CAVE_FLAG_BIT, 0(%a0, %d0.w)
    movem.l (%sp)+, %d0/%a0
    rts


| ----------------------------------------------------------------- the person's states
| One frame of the person's logic. Link's position is the one of the last frame.
cave_update:
    movem.l %d0-%d5/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.b OFF_CAVE_STATE(%a5), %d0
    beq 9f
    subq.w #1, %d0
    add.w %d0, %d0
    lea cave_states(%pc), %a0
    move.w 0(%a0, %d0.w), %d0
    jsr 0(%a0, %d0.w)
9:  movem.l (%sp)+, %d0-%d5/%a0-%a2
    rts

cave_states:
    .word cs_talk - cave_states
    .word cs_choose - cave_states
    .word cs_hint - cave_states
    .word cs_delay - cave_states
    .word cs_show - cave_states
    .word cs_letter - cave_states

cs_show:
    rts

| The speech is over: choose a ware, or (the door repair man) charge.
cs_talk:
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 9f
    btst #0, OFF_CAVE_FLAGS(%a5)                | CF_PICK
    beq 1f
    move.b #CS_CHOOSE, OFF_CAVE_STATE(%a5)
    rts
1:  move.b #CS_SHOW, OFF_CAVE_STATE(%a5)
    cmpi.b #CAVE_TYPE_DOOR, OFF_CAVE_TYPE(%a5)
    bne 9f
    moveq #CAVE_DOOR_CHARGE, %d0
    bsr cave_post_debit
    bsr cave_set_flag
9:  rts

cs_hint:
    tst.b OFF_CAVE_TEXT_ON(%a5)
    bne 9f
    move.b #CS_SHOW, OFF_CAVE_STATE(%a5)
9:  rts

| The medicine woman is shown the letter by pressing B with the letter selected as the B item (inventory screen).
cs_letter:
    cmpi.b #1, OFF_INV_LETTER(%a5)
    bne 8f
    cmpi.b #B_LETTER, OFF_B_ITEM(%a5)
    bne 8f                                      | the letter has to be the item on B
    lea OFF_KEY_STATES(%a5), %a0
    tst.b SCAN_CTRL(%a0)
    bne 1f
    tst.b SCAN_ALT(%a0)
    beq 8f
1:  tst.b OFF_CAVE_B(%a5)
    bne 9f
    move.b #1, OFF_CAVE_B(%a5)
    move.b #2, OFF_INV_LETTER(%a5)              | the letter is used: her shop opens
    sfx SFX_SECRET
    bsr cave_open
    bra cave_dress
8:  clr.b OFF_CAVE_B(%a5)
9:  rts

| Something was taken: the wares flicker while the person does, then the cave is quiet.
cs_delay:
    moveq #2, %d2                               | the wares show
    btst #0, OFF_FRAME_COUNTER+1(%a5)
    beq 1f
    moveq #ROOM_ITEM_HIDDEN, %d2                | every other frame they do not
1:  subq.b #1, OFF_CAVE_TIMER(%a5)
    bne 2f
    moveq #0, %d2                               | time is up: all gone
    clr.b OFF_CAVE_PERSON(%a5)
    clr.b OFF_CAVE_ICON(%a5)
    move.b #CS_NONE, OFF_CAVE_STATE(%a5)
2:  lea OFF_ITEM_ACTIVE(%a5), %a0
    moveq #2, %d1
3:  move.b 0(%a0, %d1.w), %d0
    cmp.b #2, %d0
    beq 4f
    cmp.b #ROOM_ITEM_HIDDEN, %d0
    bne 5f
4:  move.b %d2, 0(%a0, %d1.w)
5:  dbra %d1, 3b
    rts

| Link may touch a ware (the same column, and within a few pixels of its row).
cs_choose:
    tst.b OFF_RUPEES_SUB(%a5)
    bne 9f                                      | still paying
    lea cave_ware_x(%pc), %a0
    lea OFF_CAVE_ITEMS(%a5), %a1
    moveq #2, %d3
1:  moveq #0, %d0
    move.b 0(%a1, %d3.w), %d0
    cmp.b #CAVE_NO_WARE, %d0
    beq 8f
    cmp.b #CAVE_WARE_TAKEN, %d0
    beq 8f
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #0, %d2
    move.b 0(%a0, %d3.w), %d2
    sub.w %d2, %d1
    bpl 2f
    neg.w %d1
2:  cmp.w #CAVE_TOUCH_X, %d1
    bhi 8f
    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    addq.w #3, %d1
    sub.w #CAVE_ITEM_Y, %d1
    bpl 3f
    neg.w %d1
3:  cmp.w #CAVE_TOUCH_Y, %d1
    blo 7f
8:  dbra %d3, 1b
9:  rts
7:  bra cave_picked

| Ware d3.w was touched.
cave_picked:
    move.b %d3, OFF_CAVE_CHOSEN(%a5)
    moveq #0, %d2
    move.b OFF_CAVE_FLAGS(%a5), %d2
    lea OFF_CAVE_PRICES(%a5), %a2
    moveq #0, %d4
    move.b 0(%a2, %d3.w), %d4                   | d4 = its price
    move.w %d2, %d0
    and.w #0x30, %d0
    beq 4f                                      | a gift or a shop
    btst #4, %d2
    bne 1f
    cmpi.b #CAVE_WHO_MOBLIN, OFF_CAVE_WHO(%a5)
    beq cave_giveaway
    bra cave_wager
1:  moveq #0, %d0                               | a hint: for its price
    move.b OFF_INV_RUPEES(%a5), %d0
    cmp.w %d4, %d0
    blo 9f
    move.w %d4, %d0
    bsr cave_post_debit
    bra cave_hint
4:  btst #6, %d2                                | CF_HEARTS
    beq 5f
    moveq #5, %d1
    cmpi.b #CAVE_TYPE_WHITE, OFF_CAVE_TYPE(%a5)
    beq 6f
    moveq #12, %d1
6:  cmp.b OFF_HEART_CONTAINERS(%a5), %d1
    bhi 9f                                      | not enough hearts: he does not give it
5:  btst #1, %d2                                | CF_PAY
    beq 7f
    moveq #0, %d0
    move.b OFF_INV_RUPEES(%a5), %d0
    cmp.w %d4, %d0
    blo 9f                                      | too poor
    move.w %d4, %d0
    bsr cave_post_debit
7:  bsr cave_set_flag
    lea OFF_CAVE_ITEMS(%a5), %a0
    moveq #0, %d0
    move.b 0(%a0, %d3.w), %d0
    move.b #CAVE_WARE_TAKEN, 0(%a0, %d3.w)
    move.w %d3, -(%sp)
    bsr take_item
    move.w (%sp)+, %d3
    cmpi.b #LIFT_FRAMES, OFF_LIFT_TIMER(%a5)
    bne 8f                                      | held up, or just taken
    move.b OFF_LINK_X(%a5), OFF_ITEM_X(%a5, %d3.w)
    move.b OFF_LINK_Y(%a5), %d0
    sub.b #16, %d0
    move.b %d0, OFF_ITEM_Y(%a5, %d3.w)
    move.b #ITEM_LIFTED, OFF_ITEM_ACTIVE(%a5, %d3.w)
    bra 3f
8:  clr.b OFF_ITEM_ACTIVE(%a5, %d3.w)
3:  bsr cave_wipe_text
    bsr cave_wipe_prices
    move.b #CAVE_DELAY_FRAMES, OFF_CAVE_TIMER(%a5)
    move.b #CS_DELAY, OFF_CAVE_STATE(%a5)
9:  rts

| The hint: the old woman's second speech, picked by the ware.
cave_hint:
    ltab cave_table, %a0
    moveq #0, %d0
    move.b OFF_CAVE_TYPE(%a5), %d0
    lsl.w #4, %d0
    adda.w %d0, %a0
    moveq #0, %d0
    move.b OFF_CAVE_CHOSEN(%a5), %d0
    add.w %d0, %d0
    move.w 10(%a0, %d0.w), OFF_CAVE_TEXT_IDXW(%a5)
    bclr #3, OFF_CAVE_FLAGS(%a5)                | the price tag and the rupee by it are gone
    clr.b OFF_CAVE_ICON(%a5)
    bsr cave_wipe_text
    bsr cave_wipe_prices
    move.b #1, OFF_CAVE_TEXT_ON(%a5)
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_ROW0, OFF_CAVE_TEXT_ROW(%a5)
    move.b #CAVE_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    move.b #CS_HINT, OFF_CAVE_STATE(%a5)
    rts

| The money making game: ten rupees to play, then the amounts are shown and the chosen one applies.
cave_wager:
    moveq #0, %d0
    move.b OFF_INV_RUPEES(%a5), %d0
    cmp.w #10, %d0
    blo 9f
    sfx SFX_KEY
    lea OFF_CAVE_AMOUNTS(%a5), %a0
    lea OFF_CAVE_PRICES(%a5), %a1
    move.b (%a0)+, (%a1)+
    move.b (%a0)+, (%a1)+
    move.b (%a0)+, (%a1)+
    moveq #CODE_X, %d0
    bsr cave_draw_prices
    ltab text_glyphs, %a0
    moveq #0, %d0
    move.b CODE_PLUS_SIGN(%a0), %d0             | the glyph of a plus
    move.w %d0, %d5
    lea OFF_CAVE_AMOUNTS(%a5), %a1
    moveq #0, %d3
1:  moveq #0, %d4
    move.b 0(%a1, %d3.w), %d4
    cmp.w #20, %d4
    beq 2f
    cmp.w #50, %d4
    bne 3f
2:  move.w %d5, %d0                             | a win is marked with a plus where the format put a minus
    move.w %d3, %d1
    lsl.w #2, %d1
    add.w #(CAVE_PRICE_COL + 2), %d1
    moveq #CAVE_PRICE_ROW, %d2
    bsr uw_put_glyph
3:  addq.w #1, %d3
    cmp.w #3, %d3
    blo 1b
    moveq #0, %d3
    move.b OFF_CAVE_CHOSEN(%a5), %d3
    moveq #0, %d0
    move.b 0(%a1, %d3.w), %d0
    cmp.w #20, %d0
    beq 4f
    cmp.w #50, %d0
    beq 4f
    bsr cave_post_debit
    bra 5f
4:  bsr cave_post_credit
5:  move.b #CS_SHOW, OFF_CAVE_STATE(%a5)
9:  rts

| A moblin hands out the middle amount.
cave_giveaway:
    sfx SFX_KEY
    bsr cave_set_flag
    moveq #CODE_BLANK, %d0
    bsr cave_draw_prices
    moveq #0, %d0
    move.b (OFF_CAVE_PRICES + 1)(%a5), %d0
    bsr cave_post_credit
    move.b #CS_SHOW, OFF_CAVE_STATE(%a5)
    rts

| ----------------------------------------------------------------- the person and the rupee tag
| They are sprites over the clean room, so that they can flicker.
cave_sprites_erase:
    movem.l %d0/%d3/%a0-%a1, -(%sp)
    lea OFF_CAVE_SPR_OFFS(%a5), %a0
    lea OFF_CAVE_SPR_VALID(%a5), %a1
    moveq #1, %d3
1:  tst.b 0(%a1, %d3.w)
    beq 2f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at_far
    clr.b 0(%a1, %d3.w)
2:  dbra %d3, 1b
    movem.l (%sp)+, %d0/%d3/%a0-%a1
    rts

cave_sprites_draw:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    cmpi.b #CS_DELAY, OFF_CAVE_STATE(%a5)
    bne 1f
    btst #0, OFF_FRAME_COUNTER+1(%a5)
    bne 9f                                      | every other frame nothing of it is drawn
1:  tst.b OFF_CAVE_PERSON(%a5)
    beq 2f
    moveq #0, %d0
    move.b OFF_CAVE_WHO(%a5), %d0
    lea cave_who_frame(%pc), %a0
    move.b 0(%a0, %d0.w), %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab cave_sprites, %a0
    adda.l %d0, %a0
    moveq #0, %d1
    move.w #CAVE_DOOR_CENTER, %d1
    moveq #0, %d2
    move.w #CAVE_PERSON_Y, %d2
    moveq #0, %d3
    bsr cave_draw_one
2:  tst.b OFF_CAVE_ICON(%a5)
    beq 9f
    ltab item_index, %a0
    moveq #0, %d0
    move.b ITEM_RUPEE(%a0), %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab item_sprites, %a0
    adda.l %d0, %a0
    moveq #0, %d1
    move.w #CAVE_ICON_X, %d1
    moveq #0, %d2
    move.w #CAVE_ICON_Y, %d2
    moveq #1, %d3
    bsr cave_draw_one
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| a0 = the picture, d1.w = X, d2.w = Y, d3.w = which of the two.
cave_draw_one:
    bsr sprite_offset_far
    tst.w %d4
    bmi 9f
    move.w %d3, %d0
    lsl.w #2, %d0
    lea OFF_CAVE_SPR_OFFS(%a5), %a2
    move.l %d1, 0(%a2, %d0.w)
    lea OFF_CAVE_SPR_VALID(%a5), %a2
    move.b #1, 0(%a2, %d3.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite_far
9:  rts

| ----------------------------------------------------------------- the take-any-road room
| Link on one of the three staircases (Y $9D, X $50, $80 or $B0) goes down to another of the four rooms with
| a shortcut: the one that many places on in the list.
cave_stairs:
    movem.l %d0-%d3/%a0, -(%sp)
    tst.b OFF_CAVE_ROOMKIND(%a5)
    beq 9f
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    sub.w #CAVE_STAIRS_Y, %d0
    bpl 1f
    neg.w %d0
1:  cmp.w #4, %d0
    bhi 9f
    moveq #0, %d1
    move.b OFF_LINK_X(%a5), %d1
    moveq #1, %d2
    move.w #0x50, %d0
    bsr cave_near
    beq 3f
    moveq #2, %d2
    move.w #0x80, %d0
    bsr cave_near
    beq 3f
    moveq #3, %d2
    move.w #0xb0, %d0
    bsr cave_near
    bne 9f
3:  ltab cave_shortcuts, %a0
    moveq #0, %d3
    move.b OFF_CAVE_SOURCE_ROOM(%a5), %d0
    moveq #0, %d1
4:  cmp.b 0(%a0, %d1.w), %d0
    beq 5f
    addq.w #1, %d1
    cmp.w #4, %d1
    blo 4b
    moveq #0, %d1
5:  add.w %d2, %d1
    and.w #3, %d1
    move.b 0(%a0, %d1.w), OFF_CAVE_SOURCE_ROOM(%a5)
    sfx SFX_STAIRS
    bsr leave_cave
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

| d1.w = X, d0.w = a column: Z set when they are within 4 pixels.
cave_near:
    sub.w %d1, %d0
    bpl 1f
    neg.w %d0
1:  cmp.w #4, %d0
    bhi 2f
    moveq #0, %d0
    rts
2:  moveq #1, %d0
    rts

| ----------------------------------------------------------------- the rupee drip
| RupeesToAdd and RupeesToSubtract pay out one rupee every other frame, with the little blip.
rupee_drip:
    movem.l %d0-%d1, -(%sp)
    move.b OFF_RUPEES_ADD(%a5), %d0
    or.b OFF_RUPEES_SUB(%a5), %d0
    beq 9f
    moveq #0, %d1
    move.b OFF_INV_RUPEES(%a5), %d1
    bne 1f
    clr.b OFF_RUPEES_SUB(%a5)                   | nothing left to pay with
1:  cmp.w #255, %d1
    bne 2f
    clr.b OFF_RUPEES_ADD(%a5)                   | the purse is full
2:  btst #0, OFF_FRAME_COUNTER+1(%a5)
    bne 9f
    tst.b OFF_RUPEES_ADD(%a5)
    beq 3f
    subq.b #1, OFF_RUPEES_ADD(%a5)
    addq.b #1, OFF_INV_RUPEES(%a5)
    sfx SFX_HEART
    move.b #1, OFF_HUD_DIRTY(%a5)
3:  tst.b OFF_RUPEES_SUB(%a5)
    beq 9f
    subq.b #1, OFF_RUPEES_SUB(%a5)
    subq.b #1, OFF_INV_RUPEES(%a5)
    sfx SFX_HEART
    move.b #1, OFF_HUD_DIRTY(%a5)
9:  movem.l (%sp)+, %d0-%d1
    rts
