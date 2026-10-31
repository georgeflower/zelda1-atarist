| Music and sound effects: packed YM2149 register streams replayed from the VBL.
|
| The streams, the bank that holds them and the digidrum engine come from the
| MOD/XM -> YM tool and tools/music_pack.py; see music/ymplay.h for the stream
| format. The player is that tool's ymplay_step / ymplay_write, run for three
| independent streams at once:
|
|     context 0   a song (the area music, or an event song such as the item or
|                triforce fanfare). It owns all three voices and the digidrums.
|     context 1   an effect that takes over voice A (the NES's second sound channel, Tune0)
|     context 2   an effect that takes over voice B (the NES's Tune1 jingles)
|
| Every VBL each running context decodes its next frame into its own copy of
| R0-R13; music_merge lays the effects over the song's registers and
| music_write sends the result to the PSG. An effect that ends hands the voice
| straight back to the song, which kept running underneath.
|
| What plays is decided in two places: music_update (once per frame, from the
| game state: overworld, dungeon, cave) and the music_play / music_event calls
| the game makes when something happens (an item is taken, Link is hurt, ...).
|
| The VBL handler chains to TOS' own, so _frclock keeps counting.
|
| The bank (music_bank.bin):
|     .w tracks, .w 0
|     per track, 16 bytes: .l stream offset from the bank (0 = no data), .l loop offset in the stream,
|                          .w frames, .w loop frame, .b kind (0 song, 1 voice A, 2 voice B, 3 noise effect), .b loops,
|                          .b 0, .b sample (a DPCM sample: its digidrum is not cut by the other contexts' drums)
|     then the streams. The digidrum table is a separate file (music_drums).

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

| A context (MUSC_SIZE bytes, MUS_CTX + 32 * n)
    .equ MUSC_PTR, 0            | .l next byte of the stream
    .equ MUSC_FRAME, 4          | .w frames played
    .equ MUSC_FRAMES, 6         | .w frames in the track
    .equ MUSC_LOOPFRAME, 8      | .w
    .equ MUSC_LOOPPTR, 10       | .l where the stream continues after the last frame
    .equ MUSC_ID, 14            | .b track playing, MUS_NONE when idle
    .equ MUSC_LOOPS, 15         | .b
    .equ MUSC_REGS, 16          | 14 bytes: R0-R13 as last decoded
    .equ MUSC_SAMPLE, 30        | .b the track is a DPCM sample

    .equ BANK_ENTRIES, 4
    .equ BANK_ENTRY_SHIFT, 4
    .equ BANK_OFFSET, 0
    .equ BANK_LOOP, 4
    .equ BANK_FRAMES, 8
    .equ BANK_LOOPFRAME, 10
    .equ BANK_KIND, 12
    .equ BANK_LOOPS, 13
    .equ BANK_SAMPLE, 15

    .equ CTX_SONG, OFF_MUS_CTX
    .equ CTX_A, OFF_MUS_CTX + MUSC_SIZE
    .equ CTX_B, OFF_MUS_CTX + 2 * MUSC_SIZE
    .equ CTX_C, OFF_MUS_CTX + 3 * MUSC_SIZE

| Supervisor mode, A6 = table_anchor.
music_init:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
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
    adda.l #(music_bank - table_anchor), %a1
    move.l %a1, OFF_MUS_BANK(%a5)

    moveq #3, %d1
    lea CTX_SONG(%a5), %a0
1:  bsr music_ctx_end
    lea MUSC_SIZE(%a0), %a0
    dbra %d1, 1b
    clr.b OFF_MUS_FORCED(%a5)

    lea music_old_vbl(%pc), %a0
    move.l VBL_VECTOR, (%a0)
    lea music_vbl(%pc), %a0
    move.l %a0, VBL_VECTOR
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

music_exit:
    movem.l %d0-%d1/%a0-%a2, -(%sp)
    move.l music_old_vbl(%pc), VBL_VECTOR
    movea.l OFF_MUS_ENGINE(%a5), %a0
    jsr YMDRUM_EXIT(%a0)
    bsr music_silence
    movea.l #PSG_SELECT, %a2
    move.b #7, (%a2)
    move.b #0xff, 2(%a2)
    movem.l (%sp)+, %d0-%d1/%a0-%a2
    rts

| ------------------------------------------------------------ what the game asks for

| Once per frame: the area music follows the game state, unless an event song is
| still playing. The overworld proper has its theme, the dungeon levels theirs
| (level 9 has its own), caves are silent.
music_update:
    movem.l %d0-%d1, -(%sp)
    tst.b OFF_MUS_FORCED(%a5)
    beq 1f
    cmpi.b #MUS_NONE, CTX_SONG + MUSC_ID(%a5)
    bne 9f                      | the event song is not over
    clr.b OFF_MUS_FORCED(%a5)
1:  move.b #MUS_NONE, %d0
    cmp.b #MODE_CAVE, OFF_GAME_MODE(%a5)
    beq 3f
    tst.b OFF_MENU_CAVE(%a5)
    bne 3f                      | the inventory screen opened in a cave: caves are silent (kept short: 16-bit reach of the dev start)
    cmp.b #MODE_INTRO, OFF_GAME_MODE(%a5)
    beq 3f                      | the title plays its own song (intro.s), and without one the screen is silent
    cmp.b #MODE_DEATH, OFF_GAME_MODE(%a5)
    beq 3f                      | so does Link's death (death.s); its tune is an event song
    moveq #MUS_OVERWORLD, %d0
    move.b OFF_LEVEL(%a5), %d1
    beq 3f
    moveq #MUS_DUNGEON, %d0
    cmp.b #9, %d1
    bne 3f
    moveq #MUS_LEVEL9, %d0
3:  cmp.b CTX_SONG + MUSC_ID(%a5), %d0
    beq 9f
    cmp.b #MUS_NONE, %d0
    bne 4f
    bsr music_stop
    bra 9f
4:  bsr music_stop
    bsr music_play
9:  bsr music_roar_tick
    | The low-life beep: asked for every frame while Link has one heart or less, it starts again
    | whenever the voice-A effect slot is free (the original plays it when Tune0 is idle).
    move.b OFF_HP_HALVES(%a5), %d0
    beq 8f
    cmp.b #2, %d0
    bhi 8f
    cmp.b #MODE_MENU, OFF_GAME_MODE(%a5)
    beq 8f
    cmpi.b #MUS_NONE, CTX_A + MUSC_ID(%a5)
    bne 8f
    moveq #SFX_HEART_WARNING, %d0
    bsr music_play
8:  movem.l (%sp)+, %d0-%d1
    rts

| The boss's ambient roar (CheckBossSoundEffectUW and the DMC's repeat flag): a dungeon room whose attribute E
| names a roar - the boss's room and those around it - repeats that sample every $A0 frames, from the moment
| Link has come in, for as long as the level's boss room has not been cleared. Rooms without a roar are quiet.
    .equ ROAR_FRAMES, 160
    .if SMP_ROAR_LOW <> SMP_ROAR_BIG + 1 || SMP_ROAR_WAIL <> SMP_ROAR_BIG + 2
    .error "the three roars must follow each other in the bank"
    .endif
music_roar_tick:
    movem.l %d0-%d1/%a0, -(%sp)
    tst.b OFF_LEVEL(%a5)
    bne 1f
    move.b #0xff, OFF_ROAR_ROOM(%a5)    | out of the dungeons: the next one starts afresh
    bra 9f
1:  cmpi.b #MODE_PLAY, OFF_GAME_MODE(%a5)   | the room has been entered
    bne 9f
    move.b OFF_ROOM_ID(%a5), %d0
    cmp.b OFF_ROAR_ROOM(%a5), %d0
    beq 2f
    move.b %d0, OFF_ROAR_ROOM(%a5)      | a new room: its roar sounds at once
    clr.b OFF_ROAR_TIMER(%a5)
2:  moveq #0, %d0
    move.b OFF_ROOM_ROAR(%a5), %d0
    beq 9f
    tst.b OFF_ROAR_TIMER(%a5)
    beq 3f
    subq.b #1, OFF_ROAR_TIMER(%a5)
    bra 9f
3:  moveq #0, %d1
    move.b OFF_UW_BOSS_ROOM(%a5), %d1
    uwlea FLAGS, %a0
    btst #0, 0(%a0, %d1.w)
    bne 9f                              | the boss is dead: the ambient roar is over
    move.b #(ROAR_FRAMES - 1), OFF_ROAR_TIMER(%a5)    | counted down, then sounds again: a period of ROAR_FRAMES
    add.b #(SMP_ROAR_BIG - 1), %d0
    bsr music_play
9:  movem.l (%sp)+, %d0-%d1/%a0
    rts

| An event song (item fanfare, triforce, ...): it replaces the area music, and
| music_update leaves it alone until it has finished. d0.b = track.
music_event:
    bsr music_play
    cmp.b CTX_SONG + MUSC_ID(%a5), %d0
    bne 9f                      | no data for it: the area music plays on
    move.b #1, OFF_MUS_FORCED(%a5)
9:  rts

| Stop the song context (the effects play on).
music_stop:
    movem.l %d0-%d1/%a0, -(%sp)
    move.w %sr, %d1
    ori.w #0x0700, %sr
    lea CTX_SONG(%a5), %a0
    bsr music_ctx_end
    movea.l OFF_MUS_ENGINE(%a5), %a0
    jsr YMDRUM_STOP(%a0)
    move.w %d1, %sr
    movem.l (%sp)+, %d0-%d1/%a0
    rts

| Start track d0.b in the context its kind says, from its first frame. A track
| without data (the bank was built without the ROM) is skipped. Keeps every
| register but d0.
music_play:
    movem.l %d1-%d3/%a0-%a3, -(%sp)
    cmp.b #MUS_TRACKS, %d0
    bhs 9f
    moveq #0, %d1
    move.b %d0, %d1
    lsl.w #BANK_ENTRY_SHIFT, %d1
    movea.l OFF_MUS_BANK(%a5), %a0
    lea BANK_ENTRIES(%a0, %d1.w), %a1
    move.l BANK_OFFSET(%a1), %d2
    beq 9f
    lea 0(%a0, %d2.l), %a2          | the stream
    movea.l %a2, %a3
    adda.l BANK_LOOP(%a1), %a3      | and its loop point
    moveq #0, %d1
    move.b BANK_KIND(%a1), %d1
    move.w %d1, %d2
    lsl.w #5, %d2                   | MUSC_SIZE = 32
    lea CTX_SONG(%a5), %a0
    adda.w %d2, %a0
    cmp.w #3, %d1
    bne 7f
    tst.b MUSC_SAMPLE(%a0)
    beq 7f
    cmpi.b #MUS_NONE, MUSC_ID(%a0)
    beq 7f
    tst.b BANK_SAMPLE(%a1)
    beq 9f                      | a running DPCM sample keeps the voice against a plain noise effect
7:  move.w %sr, %d3
    ori.w #0x0700, %sr
    tst.w %d1
    bne 1f
    movem.l %a0-%a1, -(%sp)         | a new song cuts the old song's drum
    movea.l OFF_MUS_ENGINE(%a5), %a0
    jsr YMDRUM_STOP(%a0)
    movem.l (%sp)+, %a0-%a1
1:  move.l %a2, MUSC_PTR(%a0)
    move.l %a3, MUSC_LOOPPTR(%a0)
    clr.w MUSC_FRAME(%a0)
    move.w BANK_FRAMES(%a1), MUSC_FRAMES(%a0)
    move.w BANK_LOOPFRAME(%a1), MUSC_LOOPFRAME(%a0)
    move.b BANK_LOOPS(%a1), MUSC_LOOPS(%a0)
    move.b %d0, MUSC_ID(%a0)
    move.b BANK_SAMPLE(%a1), MUSC_SAMPLE(%a0)
    move.w %d3, %sr
9:  movem.l (%sp)+, %d1-%d3/%a0-%a3
    rts

| Mark the context at a0 idle and silent.
music_ctx_end:
    move.b #MUS_NONE, MUSC_ID(%a0)
    clr.b MUSC_SAMPLE(%a0)
    clr.b (MUSC_REGS + 8)(%a0)
    clr.b (MUSC_REGS + 9)(%a0)
    clr.b (MUSC_REGS + 10)(%a0)
    move.b #0xff, (MUSC_REGS + 7)(%a0)
    rts

| ------------------------------------------------------------------ the VBL player

music_vbl:
    movem.l %d0-%d5/%a0-%a3/%a5, -(%sp)
    lea globals(%pc), %a5
    btst #1, 0x00ff820a         | sync mode bit: set for 50 Hz
    bne 3f
    move.b OFF_MUS_SKIP(%a5), %d0
    addq.b #1, %d0
    cmp.b #6, %d0
    blo 4f
    moveq #0, %d0
4:  move.b %d0, OFF_MUS_SKIP(%a5)
    beq 2f                      | every sixth VBL holds the music so 60 Hz keeps its tempo
3:  bsr music_tick
2:  movem.l (%sp)+, %d0-%d5/%a0-%a3/%a5
    move.l music_old_vbl(%pc), -(%sp)
    rts                         | on into TOS' own VBL handler

| One music frame: step the running contexts, merge, write. Nothing running: silence.
music_tick:
    clr.b OFF_MUS_TRIG(%a5)
    lea CTX_SONG(%a5), %a3
    moveq #3, %d4
    moveq #0, %d5               | counts the contexts still running
1:  bsr music_step
    cmpi.b #MUS_NONE, MUSC_ID(%a3)
    beq 2f
    addq.w #1, %d5
2:  lea MUSC_SIZE(%a3), %a3
    dbra %d4, 1b
    tst.w %d5
    beq music_silence
    bsr music_merge
    bra music_write

| Advance context a3 by one frame into its MUSC_REGS. Keeps a3.
music_step:
    cmpi.b #MUS_NONE, MUSC_ID(%a3)
    beq 9f
    move.w MUSC_FRAME(%a3), %d0
    cmp.w MUSC_FRAMES(%a3), %d0
    blo 5f
    movea.l %a3, %a0
    bra music_ctx_end           | the track has played to its end
5:  movea.l MUSC_PTR(%a3), %a0
    move.b #0xff, (MUSC_REGS + 13)(%a3)     | 0xff: leave the envelope shape alone
    moveq #0, %d0
    move.b (%a0)+, %d0
    move.w %d0, %d1
    and.w #0x7f, %d1
    btst #7, %d0
    beq 1f
    moveq #0, %d2
    move.b (%a0)+, %d2
    move.w %d2, %d0
    and.w #0x7f, %d0
    lsl.w #7, %d0
    or.w %d0, %d1
    btst #7, %d2
    beq 1f
    move.b (%a0)+, %d3
    tst.b (CTX_C + MUSC_SAMPLE)(%a5)
    beq 6f
    lea CTX_C(%a5), %a1
    cmpa.l %a1, %a3
    bne 1f                      | a sample's drum is not cut or stopped by the other contexts' drums
6:  move.b %d3, OFF_MUS_TRIG(%a5)
1:  lea MUSC_REGS(%a3), %a1
    moveq #13, %d2
2:  lsr.w #1, %d1
    bcc 3f
    move.b (%a0)+, (%a1)
3:  addq.l #1, %a1
    dbra %d2, 2b

    move.w MUSC_FRAME(%a3), %d0
    addq.w #1, %d0
    cmp.w MUSC_FRAMES(%a3), %d0
    bne 4f
    tst.b MUSC_LOOPS(%a3)
    beq 4f
    move.w MUSC_LOOPFRAME(%a3), %d0
    movea.l MUSC_LOOPPTR(%a3), %a0
4:  move.w %d0, MUSC_FRAME(%a3)
    move.l %a0, MUSC_PTR(%a3)
9:  rts

| The song's registers with the effects laid over them: an effect owns its voice's
| tone period, its volume, and the voice's two mixer bits.
    .macro overlay ctx, tone, vol, bits
    cmpi.b #MUS_NONE, \ctx + MUSC_ID(%a5)
    beq 1f
    move.w \ctx + MUSC_REGS + \tone(%a5), OFF_MUS_OUT + \tone(%a5)
    move.b \ctx + MUSC_REGS + \vol(%a5), OFF_MUS_OUT + \vol(%a5)
    move.b OFF_MUS_OUT + 7(%a5), %d0
    and.b #~(\bits), %d0
    move.b \ctx + MUSC_REGS + 7(%a5), %d1
    and.b #\bits, %d1
    or.b %d1, %d0
    move.b %d0, OFF_MUS_OUT + 7(%a5)
1:
    .endm

music_merge:
    lea (CTX_SONG + MUSC_REGS)(%a5), %a0
    lea OFF_MUS_OUT(%a5), %a1
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.w (%a0)+, (%a1)+
    overlay CTX_A, 0, 8, 0x09
    overlay CTX_B, 2, 9, 0x12
    | Kind C, a noise effect: it owns the noise period, voice C's volume and its two mixer bits while
    | it makes a sound; its silent frames leave the song's bass alone.
    cmpi.b #MUS_NONE, CTX_C + MUSC_ID(%a5)
    beq 1f
    tst.b CTX_C + MUSC_REGS + 10(%a5)
    beq 1f
    move.b CTX_C + MUSC_REGS + 6(%a5), OFF_MUS_OUT + 6(%a5)
    move.b CTX_C + MUSC_REGS + 10(%a5), OFF_MUS_OUT + 10(%a5)
    move.b OFF_MUS_OUT + 7(%a5), %d0
    and.b #~0x24, %d0
    move.b CTX_C + MUSC_REGS + 7(%a5), %d1
    and.b #0x24, %d1
    or.b %d1, %d0
    move.b %d0, OFF_MUS_OUT + 7(%a5)
1:  rts

| Write MUS_OUT to the PSG and start or stop the frame's digidrum.
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
2:  lea OFF_MUS_OUT(%a5), %a1
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
