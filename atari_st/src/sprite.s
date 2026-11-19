| Masked sprite blitting.
|
| A 16-pixel-wide sprite at an arbitrary X straddles two 16-pixel bitplane
| groups, so each row is widened to a 32-bit value, shifted into place, and
| merged into both groups under the sprite's own opacity mask. Shifting at run
| time rather than pre-shifting at build time costs a few thousand cycles per
| sprite -- negligible against a 160,000-cycle frame -- and avoids spending
| 40KB per character on sixteen pre-rotated copies.

| Merge one 16-pixel group. a2 points at the group's four bitplane words,
| d1..d4 hold the shifted bitplane data and d5 the shifted mask, all in their
| low words. d6 is scratch and a2 advances past the group.
    .macro sprite_merge_group plane
    move.w %d5, %d6
    not.w %d6
    and.w (%a2), %d6
    or.w \plane, %d6
    move.w %d6, (%a2)+
    .endm

| Widen one 16-bit row into a shifted 32-bit value.
    .macro sprite_shift_word reg
    move.w (%a0)+, \reg
    swap \reg
    clr.w \reg
    lsr.l %d0, \reg
    .endm

| a0 = frame data, a1 = top-left group in the destination, d0.w = shift 0..15
| (Speed: the mask is inverted and shifted once a row, with ones shifted in, instead of inverted per group; the
| right-hand group is merged from the low words first, so only one set of swaps is needed; a shift over 8 is done
| as a shift left by 16 - shift, which is cheaper on the 68000. Same pixels as the original per-group version.)
    .macro sprite_merge_rmw plane
    and.w %d5, (%a2)
    or.w \plane, (%a2)+
    .endm
draw_sprite:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    moveq #(SPRITE_HEIGHT - 1), %d7
    cmp.w #8, %d0
    bhi 20f
10: .irp r, %d1, %d2, %d3, %d4               | a rotate right puts the left-hand group's word in the low half
    moveq #0, \r                                | and the right-hand group's in the high half
    move.w (%a0)+, \r
    ror.l %d0, \r
    .endr
    moveq #-1, %d5                      | the inverted mask, ones on both sides
    move.w (%a0)+, %d5
    not.w %d5
    ror.l %d0, %d5
    movea.l %a1, %a2                    | left-hand group: the low words
    sprite_merge_rmw %d1
    sprite_merge_rmw %d2
    sprite_merge_rmw %d3
    sprite_merge_rmw %d4
    swap %d1
    swap %d2
    swap %d3
    swap %d4
    swap %d5
    lea 8(%a1), %a2                     | right-hand group: the high words
    sprite_merge_rmw %d1
    sprite_merge_rmw %d2
    sprite_merge_rmw %d3
    sprite_merge_rmw %d4
    adda.w #SCREEN_STRIDE, %a1
    dbra %d7, 10b
    movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts
20: neg.w %d0
    add.w #16, %d0                      | 16 - shift, to the left
21: .irp r, %d1, %d2, %d3, %d4
    moveq #0, \r
    move.w (%a0)+, \r
    lsl.l %d0, \r
    .endr
    moveq #-1, %d5
    move.w (%a0)+, %d5
    not.w %d5
    rol.l %d0, %d5
    lea 8(%a1), %a2
    sprite_merge_rmw %d1
    sprite_merge_rmw %d2
    sprite_merge_rmw %d3
    sprite_merge_rmw %d4
    swap %d1
    swap %d2
    swap %d3
    swap %d4
    swap %d5
    movea.l %a1, %a2
    sprite_merge_rmw %d1
    sprite_merge_rmw %d2
    sprite_merge_rmw %d3
    sprite_merge_rmw %d4
    adda.w #SCREEN_STRIDE, %a1
    dbra %d7, 21b
    movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts


| Put back the background the sprite covered last frame.
erase_sprite:
    tst.b OFF_ERASE_VALID(%a5)
    beq 9f
    move.l %d0, -(%sp)
    move.l OFF_ERASE_OFFSET(%a5), %d0
    bsr erase_at
    clr.b OFF_ERASE_VALID(%a5)
    move.l (%sp)+, %d0
9:  rts

| Copy one sprite-sized rectangle of clean background back to the screen.
| d0.l = byte offset of its top-left group from the start of a screen buffer.
erase_at:
    movem.l %d0/%d7/%a0-%a1, -(%sp)
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l %d0, %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d0, %a1
    moveq #(SPRITE_HEIGHT - 1), %d7
1:  move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    adda.w #(SCREEN_STRIDE - SPRITE_SPAN_BYTES), %a0
    adda.w #(SCREEN_STRIDE - SPRITE_SPAN_BYTES), %a1
    dbra %d7, 1b
    movem.l (%sp)+, %d0/%d7/%a0-%a1
    rts

| Draw Link at his current position, recording where so the next frame can
| put the background back.
draw_link:
    tst.b OFF_WHIRL_TELE(%a5)
    bne 99f                             | the whirlwind has him: he is not to be seen
    cmp.b #0x40, OFF_LINK_Y(%a5)
    bhs 98f
    clr.b OFF_ERASE_VALID(%a5)          | in the top doorway's outer pixels he would be over the ribbon
    rts
98:
    movem.l %d0-%d2/%a0-%a1, -(%sp)

    | Pick the frame: direction chooses the pair, the walk counter the phase.
    moveq #LINK_FRAME_UP_A, %d0
    move.b OFF_LINK_DIR(%a5), %d1
    btst #0, %d1
    beq 1f
    moveq #LINK_FRAME_RIGHT_A, %d0
    bra 4f
1:  btst #1, %d1
    beq 2f
    moveq #LINK_FRAME_LEFT_A, %d0
    bra 4f
2:  btst #2, %d1
    beq 4f
    moveq #LINK_FRAME_DOWN_A, %d0
4:  add.b OFF_LINK_ANIM_FRAME(%a5), %d0
    moveq #0, %d1
    move.b OFF_INV_RING(%a5), %d1    | the ring's tunic: three sets of eight frames
    lsl.w #3, %d1
    add.w %d1, %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab link_sprites, %a0
    adda.l %d0, %a0
    tst.b OFF_ENDING_PHASE(%a5)
    bne 6f
    tst.b OFF_LIFT_TIMER(%a5)
    beq 5f
6:
    ltab item_index, %a0                | holding the triforce piece up: both arms raised
    moveq #0, %d0
    move.b ITEM_LINK_LIFT(%a0), %d0
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab item_sprites, %a0
    adda.l %d0, %a0
5:

    | Screen X, then split into a group offset and a shift within the group.
    moveq #0, %d0
    move.b OFF_LINK_X(%a5), %d0
    add.w #(PLAYFIELD_LEFT * 2), %d0
    move.w %d0, %d2
    and.w #15, %d2
    lsr.w #4, %d0
    lsl.w #3, %d0

    moveq #0, %d1
    move.b OFF_LINK_Y(%a5), %d1
    sub.w #LINK_Y_BIAS, %d1
    mulu.w #SCREEN_STRIDE, %d1
    add.l %d1, %d0

    move.l %d0, OFF_ERASE_OFFSET(%a5)
    move.b #1, OFF_ERASE_VALID(%a5)

    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d0, %a1
    move.w %d2, %d0
    bsr draw_sprite

    movem.l (%sp)+, %d0-%d2/%a0-%a1
99: rts
