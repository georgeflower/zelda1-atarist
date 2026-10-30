| lz.s - the LZ4 block decoder the dungeon files are packed for (tools/lzpack.py makes them; loader.s uses it).

| a0 = the packed data, a2 = where it ends, a1 = where to put the unpacked bytes (below a0, or the same). Returns a1 = the
| end of what was made. LZ4's block format: a token (literal count high, match length - 4 low; 15 means more bytes follow,
| added until one is not 255), the literals, then, unless the data is over, the match's offset (two bytes, low first, back
| from the output) and its extra length. Uses d0-d2, a0, a1, a3.
lz_unpack:
1:  moveq #0, %d1
    moveq #0, %d2
    move.b (%a0)+, %d1                  | the token
    move.w %d1, %d0
    lsr.w #4, %d0                       | literals
    cmp.w #15, %d0
    bne 3f
2:  move.b (%a0)+, %d2
    add.w %d2, %d0
    cmp.b #255, %d2
    beq 2b
3:  subq.w #1, %d0
    bmi 5f
4:  move.b (%a0)+, (%a1)+
    dbra %d0, 4b
5:  cmpa.l %a2, %a0
    bhs 9f                              | the last sequence has no match
    move.b (%a0)+, %d2                  | offset, low byte first
    move.b (%a0)+, %d0
    lsl.w #8, %d0
    move.b %d2, %d0
    moveq #0, %d2
    move.w %d0, %d2
    movea.l %a1, %a3
    suba.l %d2, %a3
    move.w %d1, %d0
    andi.w #15, %d0
    cmp.w #15, %d0
    bne 7f
    moveq #0, %d1
6:  move.b (%a0)+, %d1
    add.w %d1, %d0
    cmp.b #255, %d1
    beq 6b
7:  addq.w #3, %d0                      | + 4, less one for dbra
8:  move.b (%a3)+, (%a1)+
    dbra %d0, 8b
    bra 1b
9:  rts
