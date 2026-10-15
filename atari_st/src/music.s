| Overworld music: a packed YM2149 register stream replayed from the VBL.
|
| The stream and the digidrum engine come from the MOD/XM -> YM tool; see
| music/ymplay.h for the format. This is a port of its ymplay_step and
| ymplay_write. The engine (position independent, self-modifying 68000 code in
| .data) owns MFP Timer D and plays the 4-bit drum samples.
|
| The VBL handler chains to TOS' own, so _frclock keeps counting. The main loop
| only flips MUS_ON; while it is off the PSG is silenced and the song waits.

    .include "music.inc"

    .equ PSG_SELECT, 0x00ff8800
    .equ VBL_VECTOR, 0x00000070

    .equ YMDRUM_INIT, 0
    .equ YMDRUM_EXIT, 4
    .equ YMDRUM_START, 8
    .equ YMDRUM_STOP, 12
    .equ YMDRUM_TAB, 24
    .equ YMDRUM_VOICE, 28
    .equ YMDRUM_IDX, 30
    .equ YMDRUM_SEL, 46
    .equ YMDRUM_ACT, 47

| Supervisor mode, A6 = table_anchor.
music_init:
    movem.l %d0/%a0-%a1, -(%sp)
    lea ymdrum_code(%pc), %a0
    move.l %a0, OFF_MUS_ENGINE(%a5)

    movea.l %a6, %a1
    adda.l #(music_drums - table_anchor), %a1
    move.l %a1, %d0
    move.w %d0, (YMDRUM_TAB + 2)(%a0)
    swap %d0
    move.w %d0, YMDRUM_TAB(%a0)
    jsr YMDRUM_INIT(%a0)

    movea.l %a6, %a1
    adda.l #(music_data - table_anchor), %a1
    move.l %a1, OFF_MUS_DATA(%a5)
    move.l %a1, OFF_MUS_PTR(%a5)
    move.b #0xff, (OFF_MUS_REG + 7)(%a5)
    move.b #0xff, (OFF_MUS_REG + 13)(%a5)

    lea music_old_vbl(%pc), %a0
    move.l VBL_VECTOR, (%a0)
    lea music_vbl(%pc), %a0
    move.l %a0, VBL_VECTOR
    movem.l (%sp)+, %d0/%a0-%a1
    rts

music_exit:
    movem.l %d0-%d1/%a0-%a2, -(%sp)
    move.l music_old_vbl(%pc), VBL_VECTOR
    clr.b OFF_MUS_ON(%a5)
    movea.l OFF_MUS_ENGINE(%a5), %a0
    jsr YMDRUM_EXIT(%a0)
    bsr music_silence
    movea.l #PSG_SELECT, %a2
    move.b #7, (%a2)
    move.b #0xff, 2(%a2)
    movem.l (%sp)+, %d0-%d1/%a0-%a2
    rts

| The song plays only in the overworld proper, not in caves or the dungeon.
music_update:
    moveq #0, %d0
    tst.b OFF_LEVEL(%a5)
    bne 1f
    cmp.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    beq 1f
    moveq #1, %d0
1:  move.b %d0, OFF_MUS_ON(%a5)
    rts

music_vbl:
    movem.l %d0-%d3/%a0-%a2/%a5, -(%sp)
    lea globals(%pc), %a5
    tst.b OFF_MUS_ON(%a5)
    beq 1f
    btst #1, 0x00ff820a         | sync mode bit: set for 50 Hz
    bne 3f
    move.b OFF_MUS_SKIP(%a5), %d0
    addq.b #1, %d0
    cmp.b #6, %d0
    blo 4f
    moveq #0, %d0
4:  move.b %d0, OFF_MUS_SKIP(%a5)
    beq 2f                      | every sixth VBL holds the song so 60 Hz keeps its tempo
3:  bsr music_step
    bsr music_write
    bra 2f
1:  bsr music_silence
2:  movem.l (%sp)+, %d0-%d3/%a0-%a2/%a5
    move.l music_old_vbl(%pc), -(%sp)
    rts                         | on into TOS' own VBL handler

| Advance the stream by one frame into MUS_REG.
music_step:
    movea.l OFF_MUS_PTR(%a5), %a0
    clr.b OFF_MUS_TRIG(%a5)
    move.b #0xff, (OFF_MUS_REG + 13)(%a5)   | 0xff: leave the envelope shape alone
    moveq #0, %d0
    move.b (%a0)+, %d0
    move.w %d0, %d1
    and.w #0x7f, %d1
    btst #7, %d0
    beq 1f
    moveq #0, %d2
    move.b (%a0)+, %d2
    move.w %d2, %d3
    and.w #0x7f, %d3
    lsl.w #7, %d3
    or.w %d3, %d1
    btst #7, %d2
    beq 1f
    move.b (%a0)+, OFF_MUS_TRIG(%a5)
1:  lea OFF_MUS_REG(%a5), %a1
    moveq #13, %d2
2:  lsr.w #1, %d1
    bcc 3f
    move.b (%a0)+, (%a1)
3:  addq.l #1, %a1
    dbra %d2, 2b

    move.w OFF_MUS_FRAME(%a5), %d0
    addq.w #1, %d0
    cmp.w #MUSIC_FRAMES, %d0
    blo 4f
    move.w #MUSIC_LOOP_FRAME, %d0
    movea.l OFF_MUS_DATA(%a5), %a0
    adda.l #MUSIC_LOOP_OFFSET, %a0
4:  move.w %d0, OFF_MUS_FRAME(%a5)
    move.l %a0, OFF_MUS_PTR(%a5)
    rts

| Write MUS_REG to the PSG and start or stop the frame's digidrum.
| MUS_TRIG: 0 none, else ((voice + 1) << 6) | drum, drum 63 = stop.
music_write:
    moveq #0, %d0
    move.b OFF_MUS_TRIG(%a5), %d0
    move.w %d0, %d1
    and.w #63, %d1
    cmp.w #63, %d1
    bne 1f
    movea.l OFF_MUS_ENGINE(%a5), %a0
    jsr YMDRUM_STOP(%a0)
1:  move.w %sr, %d3
    ori.w #0x0600, %sr          | the drum timer must not interleave with the writes
    movea.l OFF_MUS_ENGINE(%a5), %a0
    moveq #-1, %d2              | the volume register a running drum owns is left alone
    tst.b YMDRUM_ACT(%a0)
    beq 2f
    moveq #0, %d2
    move.b YMDRUM_SEL(%a0), %d2
2:  lea OFF_MUS_REG(%a5), %a1
    movea.l #PSG_SELECT, %a2
    moveq #0, %d0
3:  move.b (%a1)+, %d1
    cmp.b %d2, %d0
    beq 5f
    cmp.b #13, %d0
    bne 4f
    cmp.b #0xff, %d1
    beq 5f
4:  move.b %d0, (%a2)
    move.b %d1, 2(%a2)
5:  addq.b #1, %d0
    cmp.b #14, %d0
    bne 3b
    move.w %d3, %sr

    moveq #0, %d0
    move.b OFF_MUS_TRIG(%a5), %d0
    beq 9f
    move.w %d0, %d1
    and.w #63, %d1
    cmp.w #63, %d1
    beq 9f
    lsr.w #6, %d0
    subq.w #1, %d0
    movea.l OFF_MUS_ENGINE(%a5), %a0
    move.w %d0, YMDRUM_VOICE(%a0)
    move.w %d1, YMDRUM_IDX(%a0)
    jsr YMDRUM_START(%a0)
9:  rts

music_silence:
    movea.l OFF_MUS_ENGINE(%a5), %a0
    tst.b YMDRUM_ACT(%a0)
    beq 1f
    jsr YMDRUM_STOP(%a0)
1:  movea.l #PSG_SELECT, %a2
    moveq #8, %d0
2:  move.b %d0, (%a2)
    clr.b 2(%a2)
    addq.b #1, %d0
    cmp.b #11, %d0
    bne 2b
    rts
