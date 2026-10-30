| loader.s - reading a dungeon's file into the level buffer.
|
| The image holds only what every part of the game needs. A dungeon's own tables (rooms, doors, tiles, cellars, the
| room records) and the pictures of the monsters it uses are in LEVEL<n>.DAT (LEVEL<n>Q.DAT for the Second Quest), packed
| (LZ4), read and unpacked into one buffer when Link goes in (uw_select_level), so the game fits a machine with 512 KB
| and the files a floppy. The files come from tools/build_assets.py and must sit next to the .PRG. The buffer is tagged with the record it holds (LOAD_KEY), so
| coming back into the same dungeon, or dying in it and continuing, reads nothing.
|
| Included last in main.s: the code that calls it reaches level_load through a farstub (dmon.s), and it reaches
| the early routines it needs through the stubs below.

    .equ GEMDOS_CCONWS, 0x09
    .equ GEMDOS_CNECIN, 0x08

    farstub music_exit_lf, music_exit
    farstub restore_video_lf, restore_video
    farstub terminate_lf, terminate

| d3 = the file's handle, a3 = where, d0.l = how many bytes. Returns d0.l = the bytes read, negative on an error. (GEMDOS
| keeps d3-d7 and a3-a6, so the working values live there.)
file_read:
    move.l %a3, -(%sp)
    move.l %d0, -(%sp)
    move.w %d3, -(%sp)
    move.w #GEMDOS_FREAD, -(%sp)
    trap #1
    lea 12(%sp), %sp
    rts

file_close:
    move.w %d3, -(%sp)
    move.w #GEMDOS_FCLOSE, -(%sp)
    trap #1
    addq.l #4, %sp
    rts

| a0 = the name of a level's file (the record's), d2.w = the record number + 1. Reads it, unpacks it into the level buffer
| and tags the buffer. A file that is missing, cut short, another level's or not made for this build ends the game with a
| message: nothing can be played without it.
|
| The file is eight bytes (ZLVZ, the record number, the size of the packed data) and the packed data. The packed data is
| read into the end of the buffer and unpacked from the front, over itself (the buffer was made big enough for that by
| tools/build_assets.py): the whole level in one read, nothing else in memory to hold it.
level_load:
    movem.l %d0-%d5/%a0-%a4, -(%sp)
    clr.w OFF_LOAD_KEY(%a5)             | until it is in, the buffer holds nothing
    movea.l %a0, %a4                    | the name
    move.w %d2, %d5
    clr.w -(%sp)                        | read only
    move.l %a4, -(%sp)
    move.w #GEMDOS_FOPEN, -(%sp)
    trap #1
    addq.l #8, %sp
    move.l %d0, %d3
    bmi 8f
    movea.l OFF_LEVEL_BUF(%a5), %a3     | the header goes to the start of the buffer, which is unpacked over later
    moveq #8, %d0
    bsr file_read
    moveq #8, %d1
    cmp.l %d1, %d0
    bne 7f
    cmpi.l #0x5a4c565a, (%a3)           | "ZLVZ"
    bne 7f
    move.w %d5, %d1
    subq.w #1, %d1
    cmp.w 4(%a3), %d1                   | the record number the file was made for
    bne 7f
    moveq #0, %d4
    move.w 6(%a3), %d4                  | the bytes of packed data
    adda.l #LEVEL_BUF_BYTES, %a3
    suba.l %d4, %a3
    move.l %a3, %d0
    bclr #0, %d0                        | (an even address for the disk)
    movea.l %d0, %a3
    move.l %d4, %d0
    bsr file_read
    cmp.l %d4, %d0
    bne 7f
    bsr file_close
    movea.l %a3, %a0                    | unpack: from the end of the buffer to its start
    lea (%a3,%d4.l), %a2
    movea.l OFF_LEVEL_BUF(%a5), %a1
    bsr lz_unpack
    movea.l OFF_LEVEL_BUF(%a5), %a0
    suba.l %a0, %a1                     | the bytes made
    cmpi.l #0x5a4c564c, (%a0)           | "ZLVL"
    bne 8f
    moveq #0, %d1
    move.w 6(%a0), %d1                  | the size the image says it has
    move.l %a1, %d0
    cmp.l %d1, %d0
    bne 8f
    cmp.l #LEVEL_HEADER_BYTES, %d1
    blt 8f
    move.w %d5, OFF_LOAD_KEY(%a5)
    movem.l (%sp)+, %d0-%d5/%a0-%a4
    rts
7:  bsr file_close
8:  movea.l %a4, %a0                    | the name again
    bra data_missing

    .include "lz.s"

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
    .asciz ".\r\nKeep the LEVEL*.DAT files in the\r\nsame folder as ZELDAST.PRG.\r\nPress a key.\r\n"
    .even

| Out of memory (init_buffers): the game wants its buffers (BUFFER_ALLOC) from what is left after the program is loaded. Say
| what it needs and what there is, in KB, in lines of at most 40 characters, then end the run.
no_memory_report:
    move.l #-1, -(%sp)                  | Malloc(-1): the biggest block there is
    move.w #GEMDOS_MALLOC, -(%sp)
    trap #1
    addq.l #6, %sp
    move.l %d0, %d3
    pea msg_memory(%pc)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    move.l #BUFFER_ALLOC, %d0
    bsr print_kb
    pea msg_memory2(%pc)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    move.l %d3, %d0
    bsr print_kb
    pea msg_memory3(%pc)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    move.w #GEMDOS_CNECIN, -(%sp)
    trap #1
    addq.l #2, %sp
    bra terminate_lf

| d0.l = bytes: print them as kilobytes (a number under 10000) with GEMDOS Cconws. (Uses d0-d2, a0-a2, a4.)
print_kb:
    moveq #10, %d1
    lsr.l %d1, %d0
    lea -8(%sp), %sp
    lea 7(%sp), %a4
    clr.b (%a4)
1:  divu.w #10, %d0
    swap %d0
    add.b #0x30, %d0
    move.b %d0, -(%a4)
    clr.w %d0
    swap %d0
    bne 1b
    move.l %a4, -(%sp)
    move.w #GEMDOS_CCONWS, -(%sp)
    trap #1
    addq.l #6, %sp
    lea 8(%sp), %sp
    rts

msg_memory:
    .asciz "\r\nZelda needs more memory.\r\nIt needs "
msg_memory2:
    .asciz " KB free and there are "
msg_memory3:
    .asciz " KB.\r\nPress a key.\r\n"
    .even
