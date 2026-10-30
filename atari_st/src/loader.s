| loader.s - reading a dungeon's file into the level buffer.
|
| The image holds only what every part of the game needs. A dungeon's own tables (rooms, doors, tiles, cellars, the
| room records) and the pictures of the monsters it uses are in LEVEL<n>.DAT (LEVEL<n>Q.DAT for the Second Quest), read
| into one buffer when Link goes in (uw_select_level), so the game fits a machine with 512 KB. The files come from
| tools/build_assets.py and must sit next to the .PRG. The buffer is tagged with the record it holds (LOAD_KEY), so
| coming back into the same dungeon, or dying in it and continuing, reads nothing.
|
| Included last in main.s: the code that calls it reaches level_load through a farstub (dmon.s), and it reaches
| the early routines it needs through the stubs below.

    .equ GEMDOS_CCONWS, 0x09
    .equ GEMDOS_CNECIN, 0x08

    farstub music_exit_lf, music_exit
    farstub restore_video_lf, restore_video
    farstub terminate_lf, terminate

| a0 = file name, a1 = where to put it, d0.l = at most how many bytes. Returns d0.l = the bytes read, negative when the
| file is not there. (GEMDOS keeps d3-d7 and a3-a6, so the working values live there.)
file_load:
    movem.l %d3-%d5/%a3, -(%sp)
    move.l %d0, %d4
    movea.l %a1, %a3
    clr.w -(%sp)                        | read only
    move.l %a0, -(%sp)
    move.w #GEMDOS_FOPEN, -(%sp)
    trap #1
    addq.l #8, %sp
    tst.l %d0
    bmi 9f
    move.w %d0, %d3
    move.l %a3, -(%sp)
    move.l %d4, -(%sp)
    move.w %d3, -(%sp)
    move.w #GEMDOS_FREAD, -(%sp)
    trap #1
    lea 12(%sp), %sp
    move.l %d0, %d5
    move.w %d3, -(%sp)
    move.w #GEMDOS_FCLOSE, -(%sp)
    trap #1
    addq.l #4, %sp
    move.l %d5, %d0
9:  movem.l (%sp)+, %d3-%d5/%a3
    rts

| a0 = the name of a level's file (the record's), d2.w = the record number + 1. Reads it into the level buffer and
| tags the buffer. A file that is missing, cut short or another level's ends the game with a message: nothing can
| be played without it.
level_load:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    clr.w OFF_LOAD_KEY(%a5)             | until it is in, the buffer holds nothing
    movea.l OFF_LEVEL_BUF(%a5), %a1
    move.l #LEVEL_BUF_BYTES, %d0
    bsr file_load
    cmp.l #LEVEL_HEADER_BYTES, %d0
    blt 8f
    movea.l OFF_LEVEL_BUF(%a5), %a1
    cmpi.l #0x5a4c564c, (%a1)           | "ZLVL"
    bne 8f
    move.w %d2, %d1
    subq.w #1, %d1
    cmp.w 4(%a1), %d1                   | the record number the file was made for
    bne 8f
    move.w %d2, OFF_LOAD_KEY(%a5)
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts
8:  movem.l (%sp)+, %d0-%d1/%a0-%a1     | a0 = the name again
    bra data_missing

| a0 = the name of the file that could not be used: give the machine back and say so.
data_missing:
    movea.l %a0, %a4                    | (GEMDOS keeps a4)
    bsr music_exit_lf
    bsr restore_video_lf
    pea msg_missing(%pc)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    move.l %a4, -(%sp)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    pea msg_missing2(%pc)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    move.w #GEMDOS_CNECIN, -(%sp)
    trap #1
    addq.l #2, %sp
    bra terminate_lf

msg_missing:
    .asciz "\r\nZelda cannot read "
msg_missing2:
    .asciz ".\r\nThe LEVEL*.DAT files must be in the same folder as ZELDAST.PRG.\r\nPress a key.\r\n"
    .even
