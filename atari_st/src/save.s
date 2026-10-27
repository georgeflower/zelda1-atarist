| The saved games: ZELDA.SAV, read by GEMDOS when the program starts and written when something about a profile changes
| (a name is registered, a profile is deleted, the player chooses SAVE after a death).
|
| The file is a header (the letters ZSAV, the version, a checksum of everything after it), three records of 640 bytes, one
| for each profile, and three of 256 bytes after them, one for each profile too: the world flags of Levels 7 to 9 (the ROM keeps
| one set of flags for Levels 1 to 6 and another for 7 to 9: UW_OPEN_B and UW_FLAGS_B). A file of version 1 has no such
| records; it is still read, with those flags empty. A record holds: what the file menu shows of it (active, deaths, quest, ring, the hearts value and the partial heart,
| the name) and the state of the game as the ROM keeps it in its Items block and world flags, which is the items, the
| counters, the flags of the 128 overworld screens and of the 128 rooms of the dungeons, and the list of the changes
| that secrets have made to the overworld's screens (secrets.s), so that a loaded game finds them open.
| SAVE_FILE is the file as it is on the disk, in the variable block, so it is read and written in one piece. A record
| is the ROM's "file A"; the menu works on the copies of the slot arrays (SLOT_*, "save slot info"); RETRY and the
| start of a game take them from here.
|
| A new file is written under another name (ZELDA.TMP) and then renamed, so that a full disk or a reset leaves the
| old one. A file that is not there, is not the right size, or does not add up is no file: the three slots are free.

    .equ SAVE_RECS, 3
    .equ SAVE_REC_BYTES, 640
    .equ SAVE_HEADER_BYTES, 8
    .equ SAVE_EXT_BYTES, 256
    .equ SAVE_OLD_BYTES, 1928               | version 1: the header and the three records
    .equ SAVE_EXT_OFFSET, 1928              | where the three records of Levels 7-9's flags start
    .equ SAVE_FILE_BYTES, 2696
    .equ SAVE_VERSION, 2
    .equ SAVE_OLD_VERSION, 1
    .equ SAVE_MAGIC, 0x5a534156             | "ZSAV"
    .equ SAVE_SEED, 0x5a5a
    .equ REC_ACTIVE, 0
    .equ REC_DEATHS, 1
    .equ REC_QUEST, 2
    .equ REC_RING, 3
    .equ REC_HEARTS, 4                      | two bytes
    .equ REC_NAME, 8                        | eight tiles
    .equ REC_STATE, 16

    .equ GEMDOS_FCREATE, 0x3c
    .equ GEMDOS_FOPEN, 0x3d
    .equ GEMDOS_FCLOSE, 0x3e
    .equ GEMDOS_FREAD, 0x3f
    .equ GEMDOS_FWRITE, 0x40
    .equ GEMDOS_FDELETE, 0x41
    .equ GEMDOS_FRENAME, 0x56

    .if SAVE_OLD_BYTES != (SAVE_HEADER_BYTES + SAVE_RECS * SAVE_REC_BYTES)
    .error "SAVE_OLD_BYTES is the header and the three records"
    .endif
    .if SAVE_EXT_OFFSET != SAVE_OLD_BYTES
    .error "the flags of Levels 7-9 follow the records"
    .endif
    .if SAVE_FILE_BYTES != (SAVE_EXT_OFFSET + SAVE_RECS * SAVE_EXT_BYTES)
    .error "SAVE_FILE_BYTES is the header, the three records and the three flag records"
    .endif
    .if OFF_UW_FLAGS_B != (OFF_UW_OPEN_B + 128) || SAVE_EXT_BYTES != 256
    .error "a flag record is UW_OPEN_B then UW_FLAGS_B"
    .endif
    .if GLOBALS_BYTES > 32767
    .error "save_fields reaches the variables by a signed 16-bit offset"
    .endif

| ------------------------------------------------------------------------------------------------------ starting up
| Once, before the title: the slots as the disk has them.
save_init:
    bsr filesel_reset_slots
    bsr save_read
    tst.w %d0
    beq 9f
    bra save_recs_to_views
9:  rts

| ----------------------------------------------------------------------------------------------------------- records
| d0.w = a slot: a0 = its record.
save_rec_addr:
    move.l %d0, -(%sp)
    andi.l #0xffff, %d0
    mulu.w #SAVE_REC_BYTES, %d0
    lea (OFF_SAVE_FILE + SAVE_HEADER_BYTES)(%a5), %a0
    adda.l %d0, %a0
    move.l (%sp)+, %d0
    rts

| d0.w = a slot: a0 = its record of the flags of Levels 7-9.
save_ext_addr:
    move.l %d0, -(%sp)
    andi.l #0xffff, %d0
    lsl.l #8, %d0                       | SAVE_EXT_BYTES
    lea (OFF_SAVE_FILE + SAVE_EXT_OFFSET)(%a5), %a0
    adda.l %d0, %a0
    move.l (%sp)+, %d0
    rts

| The flags of Levels 7-9 (UW_OPEN_B, UW_FLAGS_B) into the slot d0.w's flag record ...
save_ext_store:
    movem.l %d1/%a0-%a1, -(%sp)
    bsr save_ext_addr
    lea OFF_UW_OPEN_B(%a5), %a1
    move.w #(SAVE_EXT_BYTES - 1), %d1
1:  move.b (%a1)+, (%a0)+
    dbra %d1, 1b
    movem.l (%sp)+, %d1/%a0-%a1
    rts

| ... and back.
save_ext_load:
    movem.l %d1/%a0-%a1, -(%sp)
    bsr save_ext_addr
    lea OFF_UW_OPEN_B(%a5), %a1
    move.w #(SAVE_EXT_BYTES - 1), %d1
1:  move.b (%a0)+, (%a1)+
    dbra %d1, 1b
    movem.l (%sp)+, %d1/%a0-%a1
    rts

| The slot d0.w as the menu has it goes into its record.
save_views_to_rec:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    move.w %d0, %d2
    bsr save_rec_addr
    lea OFF_SLOT_ACTIVE(%a5), %a1
    move.b 0(%a1, %d2.w), REC_ACTIVE(%a0)
    lea OFF_SLOT_DEATHS(%a5), %a1
    move.b 0(%a1, %d2.w), REC_DEATHS(%a0)
    lea OFF_SLOT_QUEST(%a5), %a1
    move.b 0(%a1, %d2.w), REC_QUEST(%a0)
    lea OFF_SLOT_RING(%a5), %a1
    move.b 0(%a1, %d2.w), REC_RING(%a0)
    move.w %d2, %d1
    add.w %d1, %d1
    lea OFF_SLOT_HEARTS(%a5), %a1
    move.b 0(%a1, %d1.w), REC_HEARTS(%a0)
    move.b 1(%a1, %d1.w), (REC_HEARTS + 1)(%a0)
    lea OFF_SLOT_NAMES(%a5), %a1
    lsl.w #3, %d2
    adda.w %d2, %a1
    lea REC_NAME(%a0), %a2
    moveq #7, %d1
1:  move.b (%a1)+, (%a2)+
    dbra %d1, 1b
    movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

| The record of the slot d0.w goes to the menu's arrays; a profile that is not in use is a free slot.
save_rec_to_view:
    movem.l %d0-%d2/%a0-%a2, -(%sp)
    move.w %d0, %d2
    bsr save_rec_addr
    tst.b REC_ACTIVE(%a0)
    bne 1f
    bsr file_clear_slot
    bra 9f
1:  lea OFF_SLOT_ACTIVE(%a5), %a1
    move.b #1, 0(%a1, %d2.w)
    lea OFF_SLOT_DEATHS(%a5), %a1
    move.b REC_DEATHS(%a0), 0(%a1, %d2.w)
    lea OFF_SLOT_QUEST(%a5), %a1
    move.b REC_QUEST(%a0), 0(%a1, %d2.w)
    lea OFF_SLOT_RING(%a5), %a1
    move.b REC_RING(%a0), 0(%a1, %d2.w)
    move.w %d2, %d1
    add.w %d1, %d1
    lea OFF_SLOT_HEARTS(%a5), %a1
    move.b REC_HEARTS(%a0), 0(%a1, %d1.w)
    move.b (REC_HEARTS + 1)(%a0), 1(%a1, %d1.w)
    lea OFF_SLOT_NAMES(%a5), %a1
    lsl.w #3, %d2
    adda.w %d2, %a1
    lea REC_NAME(%a0), %a2
    moveq #7, %d1
2:  move.b (%a2)+, (%a1)+
    dbra %d1, 2b
9:  movem.l (%sp)+, %d0-%d2/%a0-%a2
    rts

save_recs_to_views:
    movem.l %d0, -(%sp)
    moveq #0, %d0
1:  bsr save_rec_to_view
    addq.w #1, %d0
    cmp.w #SAVE_RECS, %d0
    blo 1b
    movem.l (%sp)+, %d0
    rts

| The record of the slot d0.w is a free file again.
save_delete:
    movem.l %d0/%d1/%a0, -(%sp)
    bsr save_rec_addr
    move.w #(SAVE_REC_BYTES / 2 - 1), %d1
1:  clr.w (%a0)+
    dbra %d1, 1b
    bsr save_ext_addr
    move.w #(SAVE_EXT_BYTES - 1), %d1
2:  clr.b (%a0)+
    dbra %d1, 2b
    movem.l (%sp)+, %d0/%d1/%a0
    rts

| ------------------------------------------------------------------------------------------------- the state of a game
| What a record holds of the game: (offset in the variable block, bytes); a pair of zeros ends the list.
    .set save_state_bytes, 0
    .macro sfield name, size
    .word OFF_\name, \size
    .set save_state_bytes, save_state_bytes + \size
    .endm

    .even
save_fields:
    sfield ITEMS, 32
    sfield INV_RUPEES, 1
    sfield INV_KEYS, 1
    sfield HEART_CONTAINERS, 1
    sfield HP_HALVES, 1
    sfield HP_FRAC, 1
    sfield MAX_BOMBS, 1
    sfield B_ITEM, 1
    sfield TRIFORCE_PIECES, 1
    sfield INV_MAP, 1
    sfield INV_COMPASS, 1
    sfield TELE_INDEX, 1
    sfield PATCH_N, 1
    sfield PATCHES, 192
    sfield OW_KILLS, 128
    sfield UW_OPEN, 128
    sfield UW_FLAGS, 128
    .word 0, 0
    .if save_state_bytes > (SAVE_REC_BYTES - REC_STATE)
    .error "A record is too small for the state of the game"
    .endif

| a1 = a record's state: the game's variables go into it.
save_fields_store:
    movem.l %d0-%d1/%a0-%a2, -(%sp)
    lea save_fields(%pc), %a0
1:  move.w (%a0)+, %d0
    move.w (%a0)+, %d1
    beq 9f
    lea 0(%a5, %d0.w), %a2
    subq.w #1, %d1
2:  move.b (%a2)+, (%a1)+
    dbra %d1, 2b
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%a0-%a2
    rts

| ... and back.
save_fields_load:
    movem.l %d0-%d1/%a0-%a2, -(%sp)
    lea save_fields(%pc), %a0
1:  move.w (%a0)+, %d0
    move.w (%a0)+, %d1
    beq 9f
    lea 0(%a5, %d0.w), %a2
    subq.w #1, %d1
2:  move.b (%a1)+, (%a2)+
    dbra %d1, 2b
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%a0-%a2
    rts

| ... and the variables are cleared.
save_fields_clear:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    lea save_fields(%pc), %a0
1:  move.w (%a0)+, %d0
    move.w (%a0)+, %d1
    beq 9f
    lea 0(%a5, %d0.w), %a1
    subq.w #1, %d1
2:  clr.b (%a1)+
    dbra %d1, 2b
    bra 1b
9:  lea OFF_UW_OPEN_B(%a5), %a1         | and the flags of Levels 7-9
    move.w #(SAVE_EXT_BYTES - 1), %d1
3:  clr.b (%a1)+
    dbra %d1, 3b
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| The changes secrets made to the overworld's screens go back, last first: the maps are as the ROM made them.
save_world_reset:
    movem.l %d0-%d3/%a0, -(%sp)
    moveq #0, %d3
    move.b OFF_PATCH_N(%a5), %d3
    lea OFF_PATCHES(%a5), %a0
1:  subq.w #1, %d3
    bmi 9f
    move.w %d3, %d0
    lsl.w #2, %d0
    moveq #0, %d1
    move.b 1(%a0, %d0.w), %d1           | the square
    moveq #0, %d2
    move.b 2(%a0, %d0.w), %d2           | the metatile that was on it
    move.b 0(%a0, %d0.w), %d0           | the screen
    bsr ow_set_square_raw
    bra 1b
9:  clr.b OFF_PATCH_N(%a5)
    movem.l (%sp)+, %d0-%d3/%a0
    rts

| The list that was loaded is made again.
save_world_replay:
    movem.l %d0-%d3/%a0, -(%sp)
    moveq #0, %d3
    lea OFF_PATCHES(%a5), %a0
1:  cmp.b OFF_PATCH_N(%a5), %d3
    bhs 9f
    move.w %d3, %d0
    lsl.w #2, %d0
    moveq #0, %d1
    move.b 1(%a0, %d0.w), %d1
    moveq #0, %d2
    move.b 3(%a0, %d0.w), %d2           | the metatile that is on it
    move.b 0(%a0, %d0.w), %d0
    bsr ow_set_square_raw
    addq.w #1, %d3
    bra 1b
9:  movem.l (%sp)+, %d0-%d3/%a0
    rts

| The overworld of the quest d0.b (0 First, 1 Second): OFF_QUEST says which game runs, and the tables the Second Quest changes
| (quest_tables: the screens, their attributes, monsters and secrets) are swapped with quest_patch's bytes when they are in the
| other quest's state; swapping twice puts everything back. Called while no hidden-spot change is in place (after
| save_world_reset) and before the screen is drawn.
quest_apply:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    move.b %d0, OFF_QUEST(%a5)
    cmp.b OFF_QUEST_APPLIED(%a5), %d0
    beq 9f
    move.b %d0, OFF_QUEST_APPLIED(%a5)
    ltab quest_patch, %a0
    ltab quest_tables, %a1
1:  move.w (%a0)+, %d1
    bmi 9f                              | $FFFF ends the list
    lsl.w #2, %d1
    movea.l 0(%a1, %d1.w), %a2
    adda.l %a6, %a2                     | the table
    moveq #0, %d3
    move.w (%a0)+, %d3
    adda.l %d3, %a2                     | the run's place in it
    move.w (%a0)+, %d4
    subq.w #1, %d4
2:  move.b (%a2), %d0
    move.b (%a0), (%a2)+
    move.b %d0, (%a0)+
    dbra %d4, 2b
    bra 1b
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| A new profile in slot d0.w: the game as it starts, in its record. (The variables are left cleared.)
save_new_game:
    movem.l %d0/%a0-%a1, -(%sp)
    bsr save_world_reset
    bsr save_fields_clear
    move.b #3, OFF_HEART_CONTAINERS(%a5)
    move.b #6, OFF_HP_HALVES(%a5)
    move.b #8, OFF_MAX_BOMBS(%a5)
    bsr save_views_to_rec
    bsr save_rec_addr
    lea REC_STATE(%a0), %a1
    bsr save_fields_store
    bsr save_ext_store
    movem.l (%sp)+, %d0/%a0-%a1
    rts

| The game of the slot d0.w starts: its record goes into the variables, Link is at the start.
save_load_game:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    bsr save_world_reset
    lea OFF_SLOT_QUEST(%a5), %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1           | the profile's quest: the overworld is put in its state
    move.l %d0, -(%sp)
    move.l %d1, %d0
    bsr quest_apply
    move.l (%sp)+, %d0
    bsr save_rec_addr
    lea REC_STATE(%a0), %a1
    bsr save_fields_load
    bsr save_ext_load
    bsr save_world_replay
    bsr game_reset_position
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| SAVE (UpdateModeDSave): the hearts are filled up to the containers, the menu's copy of the profile is brought up to
| date and everything goes into the record and onto the disk. d0.w = the slot. A slot that is not in use (the
| development builds start without a profile) is left alone.
save_store_game:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    move.w %d0, %d2
    lea OFF_SLOT_ACTIVE(%a5), %a0
    tst.b 0(%a0, %d2.w)
    beq 9f
    moveq #0, %d0
    move.b OFF_HEART_CONTAINERS(%a5), %d0
    move.w %d0, %d1
    add.w %d1, %d1
    move.b %d1, OFF_HP_HALVES(%a5)
    clr.b OFF_HP_FRAC(%a5)
    subq.b #1, %d0                      | the hearts value: containers less one, and as many full hearts
    move.b %d0, %d1
    lsl.b #4, %d1
    or.b %d0, %d1
    move.w %d2, %d0
    add.w %d0, %d0
    lea OFF_SLOT_HEARTS(%a5), %a0
    move.b %d1, 0(%a0, %d0.w)
    move.b #0xff, 1(%a0, %d0.w)
    lea OFF_SLOT_RING(%a5), %a0
    move.b OFF_INV_RING(%a5), 0(%a0, %d2.w)
    move.w %d2, %d0
    bsr save_views_to_rec
    bsr save_rec_addr
    lea REC_STATE(%a0), %a1
    bsr save_fields_store
    bsr save_ext_store
    bsr save_write
9:  movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| ------------------------------------------------------------------------------------------------------------- disk
| The checksum of everything after the header, in d0.w. d1.w = the number of 16-bit words, less one.
save_checksum:
    movem.l %d1/%a0, -(%sp)
    lea (OFF_SAVE_FILE + SAVE_HEADER_BYTES)(%a5), %a0
    move.w #SAVE_SEED, %d0
1:  add.w (%a0)+, %d0
    dbra %d1, 1b
    movem.l (%sp)+, %d1/%a0
    rts

| ZELDA.SAV into SAVE_FILE. d0.w = 1 when there was one and it is good, otherwise 0 and the records are free.
| (GEMDOS keeps d3 to d7 and the address registers a3 to a6.)
save_read:
    movem.l %d1-%d5/%a0-%a2, -(%sp)
    moveq #0, %d5
    clr.w -(%sp)                        | read only
    pea save_name(%pc)
    move.w #GEMDOS_FOPEN, -(%sp)
    trap #1
    addq.l #8, %sp
    tst.l %d0
    bmi 8f
    move.w %d0, %d3
    pea OFF_SAVE_FILE(%a5)
    move.l #SAVE_FILE_BYTES, -(%sp)
    move.w %d3, -(%sp)
    move.w #GEMDOS_FREAD, -(%sp)
    trap #1
    lea 12(%sp), %sp
    move.l %d0, %d4
    move.w %d3, -(%sp)
    move.w #GEMDOS_FCLOSE, -(%sp)
    trap #1
    addq.l #4, %sp
    cmpi.l #SAVE_MAGIC, OFF_SAVE_FILE(%a5)
    bne 8f
    cmp.l #SAVE_FILE_BYTES, %d4
    beq 4f
    cmp.l #SAVE_OLD_BYTES, %d4          | a file of version 1: the records only, no flags yet for Levels 7-9
    bne 8f
    cmpi.w #SAVE_OLD_VERSION, (OFF_SAVE_FILE + 4)(%a5)
    bne 8f
    move.w #((SAVE_OLD_BYTES - SAVE_HEADER_BYTES) / 2 - 1), %d1
    bsr save_checksum
    cmp.w (OFF_SAVE_FILE + 6)(%a5), %d0
    bne 8f
    lea (OFF_SAVE_FILE + SAVE_EXT_OFFSET)(%a5), %a0
    move.w #(SAVE_RECS * SAVE_EXT_BYTES - 1), %d1
3:  clr.b (%a0)+
    dbra %d1, 3b
    moveq #1, %d5
    bra 8f
4:  cmpi.w #SAVE_VERSION, (OFF_SAVE_FILE + 4)(%a5)
    bne 8f
    move.w #((SAVE_FILE_BYTES - SAVE_HEADER_BYTES) / 2 - 1), %d1
    bsr save_checksum
    cmp.w (OFF_SAVE_FILE + 6)(%a5), %d0
    bne 8f
    moveq #1, %d5
8:  tst.w %d5
    bne 9f
    lea OFF_SAVE_FILE(%a5), %a0         | not a file: three free profiles
    move.w #(SAVE_FILE_BYTES / 2 - 1), %d1
7:  clr.w (%a0)+
    dbra %d1, 7b
9:  move.w %d5, %d0
    movem.l (%sp)+, %d1-%d5/%a0-%a2
    rts

| SAVE_FILE onto the disk as ZELDA.SAV.
save_write:
    movem.l %d0-%d5/%a0-%a2, -(%sp)
    move.l #SAVE_MAGIC, OFF_SAVE_FILE(%a5)
    move.w #SAVE_VERSION, (OFF_SAVE_FILE + 4)(%a5)
    move.w #((SAVE_FILE_BYTES - SAVE_HEADER_BYTES) / 2 - 1), %d1
    bsr save_checksum
    move.w %d0, (OFF_SAVE_FILE + 6)(%a5)
    clr.w -(%sp)                        | an ordinary file
    pea save_tmp_name(%pc)
    move.w #GEMDOS_FCREATE, -(%sp)
    trap #1
    addq.l #8, %sp
    tst.l %d0
    bmi 9f
    move.w %d0, %d3
    pea OFF_SAVE_FILE(%a5)
    move.l #SAVE_FILE_BYTES, -(%sp)
    move.w %d3, -(%sp)
    move.w #GEMDOS_FWRITE, -(%sp)
    trap #1
    lea 12(%sp), %sp
    move.l %d0, %d4
    move.w %d3, -(%sp)
    move.w #GEMDOS_FCLOSE, -(%sp)
    trap #1
    addq.l #4, %sp
    cmp.l #SAVE_FILE_BYTES, %d4
    beq 1f
    pea save_tmp_name(%pc)              | the disk is full: the old file stays
    move.w #GEMDOS_FDELETE, -(%sp)
    trap #1
    addq.l #6, %sp
    bra 9f
1:  pea save_name(%pc)                  | the old one goes, the new one takes its name
    move.w #GEMDOS_FDELETE, -(%sp)
    trap #1
    addq.l #6, %sp
    pea save_name(%pc)
    pea save_tmp_name(%pc)
    clr.w -(%sp)
    move.w #GEMDOS_FRENAME, -(%sp)
    trap #1
    lea 12(%sp), %sp
9:  movem.l (%sp)+, %d0-%d5/%a0-%a2
    rts

save_name:
    .asciz "ZELDA.SAV"
save_tmp_name:
    .asciz "ZELDA.TMP"
    .even
