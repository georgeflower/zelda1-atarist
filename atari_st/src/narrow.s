| The same for a narrow picture: eight pixels wide, in the middle of its sixteen (columns 4 to 11: the gels, the
| fairy, a Lanmola's segments). Where the shift keeps it all in one group of the screen's sixteen pixels (shift 0 to
| 4: the left group, shift 12 to 15: the right one) only that group is merged and the shifting is by words; in the
| other seven positions of the sixteen it spans two and draw_sprite does it.
| a0 = frame data, a1 = top-left group in the destination, d0.w = shift 0..15
draw_sprite_narrow:
    cmp.w #4, %d0
    bls 10f
    cmp.w #11, %d0
    bls draw_sprite_bf
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #16, %d6
    sub.w %d0, %d6                      | the right group: shift left by 16 less the shift
    addq.l #8, %a1
    moveq #(SPRITE_HEIGHT - 1), %d7
2:  movem.w (%a0)+, %d1-%d5
    lsl.w %d6, %d1
    lsl.w %d6, %d2
    lsl.w %d6, %d3
    lsl.w %d6, %d4
    lsl.w %d6, %d5
    not.w %d5
    and.w %d5, (%a1)
    or.w %d1, (%a1)+
    and.w %d5, (%a1)
    or.w %d2, (%a1)+
    and.w %d5, (%a1)
    or.w %d3, (%a1)+
    and.w %d5, (%a1)
    or.w %d4, (%a1)+
    adda.w #(SCREEN_STRIDE - 8), %a1
    dbra %d7, 2b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts
10: movem.l %d0-%d7/%a0-%a1, -(%sp)
    moveq #(SPRITE_HEIGHT - 1), %d7
3:  movem.w (%a0)+, %d1-%d5
    lsr.w %d0, %d1
    lsr.w %d0, %d2
    lsr.w %d0, %d3
    lsr.w %d0, %d4
    lsr.w %d0, %d5
    not.w %d5
    and.w %d5, (%a1)
    or.w %d1, (%a1)+
    and.w %d5, (%a1)
    or.w %d2, (%a1)+
    and.w %d5, (%a1)
    or.w %d3, (%a1)+
    and.w %d5, (%a1)
    or.w %d4, (%a1)+
    adda.w #(SCREEN_STRIDE - 8), %a1
    dbra %d7, 3b
    movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts
