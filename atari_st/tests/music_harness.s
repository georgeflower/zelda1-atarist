| Test image for music.s: the player, the variable block and a bank the test supplies.
| Built by tests/test_music_player.py. The entry points are a jump table at the start of
| the image; each runs one routine and spins on a branch to itself.

    .include "music_ids.inc"
    .equ MODE_CAVE, 2
    .equ MODE_MENU, 3
    .equ MODE_INTRO, 4
    .equ MODE_DEATH, 5
    .include "globals.s"

    .text
    bra.w h_init
    bra.w h_tick
    bra.w h_play
    bra.w h_update
    bra.w h_event
    bra.w h_vbl

h_init:
    lea globals(%pc), %a5
    lea table_anchor(%pc), %a6
    bsr music_init
    lea music_old_vbl(%pc), %a0
    lea h_done(%pc), %a1
    move.l %a1, (%a0)           | where music_vbl chains to
    bra.s .                     | the test stops here
h_tick:
    lea globals(%pc), %a5
    bsr music_tick
    bra.s .                     | the test stops here
h_play:
    lea globals(%pc), %a5
    bsr music_play
    bra.s .                     | the test stops here
h_update:
    lea globals(%pc), %a5
    bsr music_update
    bra.s .                     | the test stops here
h_event:
    lea globals(%pc), %a5
    bsr music_event
    bra.s .                     | the test stops here
h_vbl:
    bsr music_vbl
h_done:
    bra.s .                     | the test stops here

    .include "music.s"

    .align 2
ymdrum_code:
    .incbin "music_engine.bin"
music_old_vbl:
    .long 0
globals:
    .space GLOBALS_BYTES

| The big tables go last, as in main.s, so the PC-relative references above stay in range.
    .align 2
table_anchor:
music_drums:
    .incbin "music_drum_table.bin"
    .align 2
music_bank:
    .incbin "music_bank.bin"
