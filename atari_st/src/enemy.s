| Monsters: spawning, wandering and drawing.
|
| Overworld rooms of template $07 still get the simple procedural blobs (type
| 255). Underworld rooms spawn the monsters listed for them, drawn with the
| original sprite art. Hit points, damage and drops live in combat.s.

| d0.b = a pseudo-random byte
rand8:
    move.w OFF_RNG(%a5), %d0
    lsr.w #1, %d0
    bcc 1f
    eori.w #0xb400, %d0
1:  move.w %d0, OFF_RNG(%a5)
    move.l %d1, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d1
    eor.w %d1, %d0
    move.l (%sp)+, %d1
    and.w #0xff, %d0
    rts

spawn_room_enemies:
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    bsr clear_enemies
    bsr clear_items
    tst.b OFF_LEVEL(%a5)
    bne uw_spawn

    bsr ow_save_kills               | the screen just left remembers how many died there
    moveq #0, %d0                   | overworld: the screen's record in ow_room_info
    move.b OFF_ROOM_ID(%a5), %d0
    move.w %d0, %d1
    lsl.w #4, %d1
    ltab ow_room_info, %a1
    adda.w %d1, %a1
    bsr ow_history_count            | d1 = how many monsters, once the history has had its say
    move.b %d1, OFF_ROOM_OBJ(%a5)
    clr.b OFF_ROOM_KILLS(%a5)
    move.b %d0, OFF_SPAWNED_ROOM(%a5)
    move.b #1, OFF_SPAWNED_VALID(%a5)
    clr.b OFF_EDGE_PENDING(%a5)
    btst #0, 1(%a1)
    beq spawn_counted
    tst.w %d1                       | these screens place nothing: the monsters walk in from the edge
    beq 9f
    move.b %d1, OFF_ENEMY_COUNT(%a5)
    move.b %d1, OFF_EDGE_PENDING(%a5)
    clr.b OFF_EDGE_NEXT(%a5)
    clr.b OFF_EDGE_TIMER(%a5)
    move.l %a1, OFF_EDGE_REC(%a5)
    bra 9f
9:  movem.l (%sp)+, %d0-%d7/%a0-%a2
    rts

| Underworld: place the monsters the room lists on the first safe spawn spots.
uw_spawn:
    clr.b OFF_UW_PERSON(%a5)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    bsr uw_room_info_ptr
    tst.w %d1
    bmi 9b
    cmpi.b #0xff, 14(%a1)
    beq 0f
    bsr uw_person_begin             | an old man waits here with something to say
0:
    move.b 1(%a1), %d2
    move.b %d2, %d3
    and.b #7, %d2
    move.b %d2, OFF_ROOM_TRIGGER(%a5)
    rol.b #1, %d3                   | bit 7 of the record: the room has a push block
    and.b #1, %d3
    move.b %d3, OFF_ROOM_BLOCK(%a5)
    move.b 5(%a1), OFF_ROOM_UNSUPPORTED(%a5)
    bsr uw_setup_item
    bsr block_setup
    lea OFF_UW_FLAGS(%a5), %a2
    btst #0, 0(%a2, %d0.w)
    bne 9b                      | already cleared: they stay dead
    bra spawn_from_record

| a1 = a room record (monster count at 0, monster indices from 6): place them
| on the first safe spawn spots. Used by both worlds.
spawn_from_record:
    moveq #0, %d1
    move.b (%a1), %d1           | monsters to place
spawn_counted:                  | d1 = how many
    tst.w %d1
    beq 9b

    moveq #0, %d3
    move.b OFF_LINK_DIR(%a5), %d3
    bsr enemy_spawn_list_index
    lea enemy_spawn_lists(%pc), %a0
    mulu.w #9, %d0
    adda.w %d0, %a0

    moveq #0, %d4               | spawn spots tried
    moveq #0, %d5               | monsters placed
1:  cmp.w #72, %d4                | the list goes round and round until every monster has a safe spot
    bhs 8f
    cmp.w %d1, %d5
    bhs 8f
    moveq #0, %d0
    moveq #0, %d0
    move.w %d4, %d0
    divu.w #9, %d0
    swap %d0                        | spot = tries mod 9
    move.b 0(%a0, %d0.w), %d0
    addq.w #1, %d4
    move.w %d0, %d6
    lsl.w #4, %d6
    and.w #0x00ff, %d6          | X
    move.w %d0, %d7
    and.w #0x00f0, %d7
    or.w #0x000d, %d7           | Y

    move.w %d6, %d2
    move.w %d7, %d3
    bsr enemy_square_blocked
    tst.w %d0
    bne 1b

    moveq #0, %d0               | not on top of Link
    move.b OFF_LINK_X(%a5), %d0
    sub.w %d6, %d0
    bpl 2f
    neg.w %d0
2:  cmp.w #0x22, %d0
    bhs 3f
    moveq #0, %d0
    move.b OFF_LINK_Y(%a5), %d0
    sub.w %d7, %d0
    bpl 4f
    neg.w %d0
4:  cmp.w #0x22, %d0
    blo 1b

3:  move.b %d6, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d7, OFF_ENEMY_Y(%a5, %d5.w)
    moveq #0, %d0
    move.b 6(%a1, %d5.w), %d0   | monster index from the room record
    move.b %d0, OFF_ENEMY_TYPE(%a5, %d5.w)
    ltab mon_table, %a2
    lsl.w #3, %d0
    move.b 1(%a2, %d0.w), %d0
    move.b %d0, OFF_ENEMY_HP(%a5, %d5.w)
    move.b #1, OFF_ENEMY_ACTIVE(%a5, %d5.w)
    move.b %d5, %d0
    andi.b #3, %d0
    moveq #1, %d2
    lsl.b %d0, %d2
    move.b %d2, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr enemy_init_special
    addq.w #1, %d5
    bra 1b
8:  move.b %d5, OFF_ENEMY_COUNT(%a5)
    bra 9b

| ModifyObjCountByHistoryOW. d0 = the screen, a1 = its record. Returns d1.w = the number of monsters
| it starts with. A screen entered within the last six keeps what is left of its monsters (its kill
| count is taken off); one that was cleared and has since dropped out of that history starts afresh.
| The screen then goes into the history.
ow_history_count:
    movem.l %d2-%d3/%a0, -(%sp)
    moveq #0, %d1
    move.b (%a1), %d1
    lea OFF_ROOM_HIST(%a5), %a0
    moveq #5, %d2
1:  cmp.b 0(%a0, %d2.w), %d0
    beq 2f
    dbra %d2, 1b
    lea OFF_OW_KILLS(%a5), %a0      | not among the last six
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    and.b #7, %d2
    cmp.b #7, %d2
    bne 3f
    and.b #0xf8, 0(%a0, %d0.w)      | all of them were killed: they come back
    bra 5f
2:  lea OFF_OW_KILLS(%a5), %a0
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    and.b #7, %d2
3:  tst.b %d2
    beq 5f
    cmp.b #7, %d2
    beq 4f                          | cleared, and still in the history: nobody is here
    sub.w %d2, %d1
    bpl 5f
4:  moveq #0, %d1
5:  lea OFF_ROOM_HIST(%a5), %a0     | note the screen, unless it is there already
    moveq #5, %d2
6:  cmp.b 0(%a0, %d2.w), %d0
    beq 9f
    dbra %d2, 6b
    moveq #0, %d2
    move.b OFF_ROOM_HIST_I(%a5), %d2
    move.b %d0, 0(%a0, %d2.w)
    addq.b #1, %d2
    cmp.b #6, %d2
    blo 7f
    moveq #0, %d2
7:  move.b %d2, OFF_ROOM_HIST_I(%a5)
9:  movem.l (%sp)+, %d2-%d3/%a0
    rts

| SaveKillCountOW, for the screen whose monsters were last shown: its remembered kills grow by the
| ones made here, and become 7 (everyone) when they were all of the screen's monsters.
ow_save_kills:
    tst.b OFF_SPAWNED_VALID(%a5)
    beq 9f
    movem.l %d0-%d3/%a0, -(%sp)
    moveq #0, %d3
    move.b OFF_SPAWNED_ROOM(%a5), %d3
    lea OFF_OW_KILLS(%a5), %a0
    move.b 0(%a0, %d3.w), %d1
    move.b %d1, %d2
    and.b #7, %d2                   | what was remembered
    and.b #0xf8, %d1
    move.b OFF_ROOM_KILLS(%a5), %d0
    cmp.b OFF_ROOM_OBJ(%a5), %d0
    bhs 1f
    and.b #7, %d0
    add.b %d2, %d0
    cmp.b #7, %d0
    blo 2f
1:  moveq #7, %d0
2:  or.b %d0, %d1
    move.b %d1, 0(%a0, %d3.w)
    movem.l (%sp)+, %d0-%d3/%a0
9:  rts

| Once a frame: the next monster of a screen that spawns them at its edge comes in, a few tenths of a
| second after the last, on the next free square of the ring that runs counter-clockwise round the
| screen (FindNextEdgeSpawnCell).
edge_spawn_tick:
    tst.b OFF_EDGE_PENDING(%a5)
    beq 9f
    movem.l %d0-%d7/%a0-%a2, -(%sp)
    tst.b OFF_EDGE_TIMER(%a5)
    beq 2f
    moveq #0, %d0
    move.w OFF_FRAME_COUNTER(%a5), %d0
    divu.w #10, %d0
    swap %d0
    tst.w %d0
    bne 8f
    subq.b #1, OFF_EDGE_TIMER(%a5)
    bra 8f
2:  bsr edge_next_cell              | d0 = the square
    move.w %d0, %d6
    and.w #15, %d6
    lsl.w #4, %d6                   | X
    move.w %d0, %d7
    and.w #0xf0, %d7
    sub.w #3, %d7                   | Y
    moveq #0, %d5
    move.b OFF_EDGE_NEXT(%a5), %d5
    movea.l OFF_EDGE_REC(%a5), %a1
    moveq #0, %d0
    move.b 6(%a1, %d5.w), %d0       | monster index from the screen's record
    move.b %d6, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d7, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d0, OFF_ENEMY_TYPE(%a5, %d5.w)
    ltab mon_table, %a2
    lsl.w #3, %d0
    move.b 1(%a2, %d0.w), OFF_ENEMY_HP(%a5, %d5.w)
    move.b #1, OFF_ENEMY_ACTIVE(%a5, %d5.w)
    move.b %d5, %d0
    andi.b #3, %d0
    moveq #1, %d2
    lsl.b %d0, %d2
    move.b %d2, OFF_ENEMY_DIR(%a5, %d5.w)
    bsr enemy_init_special
    addq.b #1, OFF_EDGE_NEXT(%a5)
    subq.b #1, OFF_EDGE_PENDING(%a5)
    bsr rand8
    and.b #3, %d0
    addq.b #2, %d0
    move.b %d0, OFF_EDGE_TIMER(%a5) | the next one comes 20 to 50 frames later
8:  movem.l (%sp)+, %d0-%d7/%a0-%a2
9:  rts

| FindNextEdgeSpawnCell. Returns d0.w = the next square of the screen's border (row in the high
| nibble, column in the low) whose tile can be walked on (below $84, which leaves out sand).
edge_next_cell:
    movem.l %d1-%d5, -(%sp)
    moveq #0, %d4
    move.b OFF_EDGE_CELL(%a5), %d4
    bne 0f
    moveq #0x40, %d4
0:  move.w %d4, %d1
1:  move.w %d1, %d2
    and.w #15, %d2
    moveq #0x10, %d3
    tst.w %d2
    beq 2f                          | the left edge: down
    moveq #-0x10, %d3
    cmp.w #15, %d2
    bne 3f                          | the right edge: up
2:  add.w %d3, %d1
    and.w #0xff, %d1
3:  move.w %d1, %d2
    and.w #0xf0, %d2
    cmp.w #0xe0, %d2
    bne 4f
    addq.w #1, %d1                  | the bottom: right
    bra 5f
4:  cmp.w #0x40, %d2
    bne 5f
    subq.w #1, %d1                  | the top: left
5:  and.w #0xff, %d1
    move.w %d1, %d2
    and.w #0xf0, %d2
    sub.w #NES_PLAY_AREA_TOP, %d2
    lsr.w #3, %d2                   | the tile row
    move.w %d1, %d3
    and.w #15, %d3
    add.w %d3, %d3                  | the tile column
    bsr fetch_tile
    cmp.w #0x84, %d0
    blo 9f
    cmp.b %d4, %d1
    bne 1b
9:  move.b %d1, OFF_EDGE_CELL(%a5)
    moveq #0, %d0
    move.b %d1, %d0
    movem.l (%sp)+, %d1-%d5
    rts

| d0.w = room id. Returns a1 = its record in uw_room_info and d1.w = 0, or
| d1.w = -1 when the room is not part of the level.
uw_room_info_ptr:
    movem.l %d2/%a0, -(%sp)
    lvtab ROOM_INDEX, %a0
    moveq #0, %d2
    move.b 0(%a0, %d0.w), %d2
    cmpi.b #0xff, %d2
    beq 1f
    mulu.w #UW_INFO_BYTES, %d2
    lvtab ROOM_INFO, %a1
    adda.l %d2, %a1
    moveq #0, %d1
    bra 2f
1:  moveq #-1, %d1
2:  movem.l (%sp)+, %d2/%a0
    rts

enemy_spawn_list_index:
    moveq #0, %d0
    btst #0, %d3
    bne 9f
    moveq #1, %d0
    btst #1, %d3
    bne 9f
    moveq #2, %d0
    btst #2, %d3
    bne 9f
    moveq #3, %d0
9:  rts

clear_enemies:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_ENEMY_COUNT(%a5)
    clr.b OFF_BEAM_ACTIVE(%a5)
    bsr clear_bomb
    lea OFF_ENEMY_ACTIVE(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
1:  clr.b (%a0)+
    dbra %d0, 1b
    lea OFF_ENEMY_ERASE_VALID(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
2:  clr.b (%a0)+
    dbra %d0, 2b
    lea OFF_ENEMY_HURT(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
3:  clr.b (%a0)+
    dbra %d0, 3b
    lea OFF_ENEMY_SHOVE(%a5), %a0
    moveq #(MAX_ENEMIES * 3 - 1), %d0
4:  clr.b (%a0)+
    dbra %d0, 4b
    lea OFF_PROJ_KIND(%a5), %a0
    moveq #(MAX_PROJ - 1), %d0
5:  clr.b (%a0)+
    dbra %d0, 5b
    lea OFF_ENEMY_STUN(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
6:  clr.b (%a0)+
    dbra %d0, 6b
    lea OFF_ENEMY_TURN(%a5), %a0            | turn timers, want-to-shoot flags and shoot timers
    moveq #(MAX_ENEMIES * 3 - 1), %d0
7:  clr.b (%a0)+
    dbra %d0, 7b
    clr.b OFF_WALL_TIMER(%a5)
    lea OFF_ENEMY_GHOST(%a5), %a0               | the movers' fields: eight rows and four counters
    moveq #(MAX_ENEMIES * 8 + 4 - 1), %d0
8:  clr.b (%a0)+
    dbra %d0, 8b
    movem.l (%sp)+, %d0/%a0
    rts

erase_enemies:
    movem.l %d0/%d3/%a0, -(%sp)
    lea OFF_ENEMY_ERASE_OFFSETS(%a5), %a0
    moveq #0, %d3
1:  tst.b OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
    beq 2f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at
    btst #1, OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
    beq 3f
    move.w %d3, %d0                 | a second sprite (the Dodongo's other half)
    lsl.w #2, %d0
    lea OFF_ENEMY_ERASE2_OFFSETS(%a5), %a0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at
    lea OFF_ENEMY_ERASE_OFFSETS(%a5), %a0
3:  clr.b OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
2:  addq.w #1, %d3
    cmp.w #MAX_ENEMIES, %d3
    blo 1b
    movem.l (%sp)+, %d0/%d3/%a0
    rts

update_enemies:
    movem.l %d0-%d7/%a0-%a1, -(%sp)
    tst.b OFF_LIFT_TIMER(%a5)
    bne 9f                      | Link is holding something up: everything waits
    bsr edge_spawn_tick         | a monster walks in from the edge, if one is due
    bsr zora_check              | and a zora rises in the water of a screen that has some
    bsr long_timers             | the leevers' timer runs in tenths of a second
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    tst.b OFF_ENEMY_HURT(%a5, %d5.w)
    beq 2f
    subq.b #1, OFF_ENEMY_HURT(%a5, %d5.w)
    cmp.b #ENEMY_SHOVE_FRAMES, OFF_ENEMY_HURT(%a5, %d5.w)
    blo 2f                      | the shove is over; it flashes on but carries on
    bsr enemy_behaviour
    cmp.w #BEH_MOLDORM, %d0
    beq 2f                      | a Moldorm segment is not knocked about: it swims on while it flashes
    bsr enemy_shove
    bra 8f

2:  tst.b OFF_INV_CLOCK(%a5)
    bne 8f                      | the clock: every monster stands still
    lea OFF_ENEMY_STUN(%a5), %a0
    tst.b 0(%a0, %d5.w)
    beq 29f
    subq.b #1, 0(%a0, %d5.w)    | stunned: it does nothing at all
    bra 8f
29: moveq #4, %d4               | frames between pixel steps
    moveq #0, %d7               | behaviour
    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d5.w), %d0
    cmpi.b #0xff, %d0
    beq 3f
    ltab mon_table, %a0
    lsl.w #3, %d0
    moveq #0, %d4
    move.b 2(%a0, %d0.w), %d4
    move.b 7(%a0, %d0.w), %d7
    cmp.w #BEH_TRAP, %d7
    bne 20f
    bsr trap_ai
    bra 8f
20: cmp.w #BEH_WALLMASTER, %d7
    bne 21f
    bsr wallmaster_ai
    bra 8f
21: cmp.w #BEH_BOSS, %d7
    bne 22f
    bsr boss_ai
    bra 8f
22: cmp.w #BEH_KEESE, %d7
    bne 222f
    bsr keese_ai
    bra 8f
222: cmp.w #BEH_MOLDORM, %d7
    bne 223f
    bsr moldorm_ai              | a segment of Moldorm steers (the head) and swims
    bra 8f
223: cmp.w #BEH_DODONGO, %d7
    bne 221f
    bsr dodongo_ai
    tst.w %d0
    bne 8f                      | bloated or stunned
    bra 3f
221: cmp.w #BEH_TEKTITE, %d7
    blo 24f
    bsr mover_update            | tektites, leevers, zoras, peahats, ghinis and the boulders
    tst.w %d0
    bne 8f
    bra 3f
24: cmp.w #BEH_ROPE, %d7
    bne 23f
    bsr rope_turn
    bsr rope_ai
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    beq 3f
    moveq #1, %d4               | charging: a pixel every frame, and more
    bra 3f
23: cmp.w #BEH_GORIYA, %d7
    bne 25f
    bsr goriya_ai
    tst.w %d0
    bne 8f                      | waiting for its boomerang
    bra 3f
25: cmp.w #BEH_GEL, %d7
    bne 26f
    bsr gel_ai
    tst.w %d0
    bne 8f                      | resting at the edge of a square
    bra 3f
26: cmp.w #BEH_LYNEL, %d7
    bne 27f
    bsr goriya_ai               | a lynel walks like a goriya
    bsr walker_shoot            | and shoots sword shots
    tst.w %d0
    bne 8f                      | standing still to shoot
    bra 3f
27: moveq #0x70, %d1            | a red octorok turns toward Link at rate $70
    cmp.w #BEH_OCTOROK, %d7
    beq 28f
    move.w #0xa0, %d1           | blue octoroks and moblins at $A0
    cmp.w #BEH_OCTOROK_BLUE, %d7
    beq 28f
    cmp.w #BEH_MOBLIN, %d7
    beq 28f
    move.w #0x80, %d1           | a stalfos at $80
    cmp.w #BEH_WANDER, %d7
    bne 3f
28: bsr wander_tick
    cmp.w #BEH_WANDER, %d7
    beq 3f                      | stalfos do not shoot
    bsr walker_shoot            | octoroks shoot rocks, moblins arrows
    tst.w %d0
    bne 8f
3:  moveq #0, %d1
    move.w OFF_FRAME_COUNTER(%a5), %d1
    add.w %d5, %d1
    divu.w %d4, %d1
    swap %d1
    tst.w %d1
    bne 8f

    move.w %d7, %d1             | d1 keeps the behaviour: only ropes charge
    moveq #1, %d7               | pixels to move this frame
    cmp.w #BEH_ROPE, %d1
    bne 31f
    tst.b OFF_ENEMY_STATE(%a5, %d5.w)
    beq 31f
    move.w OFF_FRAME_COUNTER(%a5), %d0
    add.w %d5, %d0
    btst #0, %d0
    beq 31f
    moveq #2, %d7               | a charging rope makes one and a half pixels a frame
31: moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #0, %d6
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d6
    and.l #0xffff, %d1
    cmp.w #BEH_DODONGO, %d1
    bne 311f
    move.b %d6, %d0             | a Dodongo going any way but left is steered by its leading end, 16 along
    and.b #0x0d, %d0
    beq 311f
    add.w #16, %d2
    or.l #0x00010000, %d1       | and remembers to give the 16 back
311:

    | Monsters keep to the lanes of a 16-pixel grid. Only when a square has been
    | crossed may one turn, and it has to find the square ahead open.
    move.b %d2, %d0
    and.b #15, %d0
    bne 4f
    move.b %d3, %d0
    and.b #15, %d0
    cmp.b #13, %d0
    bne 4f
    move.w %d6, %d4             | the heading was chosen by the monster's own turning above;
    bsr enemy_choose_dir        | all that is left here is the square ahead being shut
    tst.w %d6
    beq 45f
    cmp.b %d4, %d6
    beq 4f
    cmp.w #BEH_ROPE, %d1
    bne 4f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)       | a charging rope stops
    bra 4f
45: cmp.w #BEH_ROPE, %d1
    bne 8f
    clr.b OFF_ENEMY_STATE(%a5, %d5.w)       | boxed in: stand still
    bra 8f

4:  btst #0, %d6
    beq 5f
    addq.w #1, %d2
    bra 10f
5:  btst #1, %d6
    beq 6f
    subq.w #1, %d2
    bra 10f
6:  btst #2, %d6
    beq 62f
    addq.w #1, %d3
    bra 10f
62: subq.w #1, %d3
10: btst #16, %d1
    beq 101f
    sub.w #16, %d2
101: move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    move.b %d6, OFF_ENEMY_DIR(%a5, %d5.w)
    subq.w #1, %d7
    bgt 31b
    bsr gel_pause               | a gel rests at the edge of the square it has crossed
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d7/%a0-%a1
    rts

| Knock-back for enemy d5: four pixels a frame along the way it was hit, stopping
| at a wall. A monster caught between squares is only shoved along its own lane.
enemy_shove:
    movem.l %d0-%d4/%d6/%a0, -(%sp)
    moveq #0, %d6
    move.b OFF_ENEMY_SHOVE(%a5, %d5.w), %d6
    beq 9f
    bsr enemy_behaviour
    cmp.w #BEH_BOSS, %d0
    beq 4f                      | Aquamentus and the keese are never shoved
    cmp.w #BEH_KEESE, %d0
    beq 4f
    cmp.w #BEH_ZORA, %d0
    beq 4f                      | nor are a zora and the boulder set
    cmp.w #BEH_BOULDER_SET, %d0
    beq 4f
    cmp.w #BEH_TEKTITE, %d0
    beq 5f                      | tektites and peahats are shoved wherever they stand
    cmp.w #BEH_PEAHAT, %d0
    beq 5f
    cmp.w #BEH_LEEVER, %d0
    bne 6f
    bsr enemy_nes_type
    cmp.b #NES_RED_LEEVER, %d0
    bne 6f
5:  bsr enemy_free_shove
    bra 9f
6:    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    move.b %d2, %d0
    and.b #15, %d0
    bne 11f
    move.b %d3, %d0
    and.b #15, %d0
    cmp.b #13, %d0
    beq 12f
11: move.b OFF_ENEMY_DIR(%a5, %d5.w), %d0
    and.b #DIR_VERTICAL, %d0
    move.b %d6, %d1
    and.b #DIR_VERTICAL, %d1
    cmp.b %d0, %d1
    bne 3f                      | across its lane: no shove
12: moveq #3, %d4
1:  move.b %d2, %d0
    and.b #15, %d0
    bne 2f
    move.b %d3, %d0
    and.b #15, %d0
    cmp.b #13, %d0
    bne 2f
    bsr enemy_cell_blocked      | at a square boundary the next square has to be open
    tst.w %d0
    bne 3f
2:  btst #0, %d6
    beq 21f
    addq.w #1, %d2
    bra 25f
21: btst #1, %d6
    beq 22f
    subq.w #1, %d2
    bra 25f
22: btst #2, %d6
    beq 23f
    addq.w #1, %d3
    bra 25f
23: subq.w #1, %d3
25: dbra %d4, 1b
    move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    bra 9f
3:  move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d3, OFF_ENEMY_Y(%a5, %d5.w)
    clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
    bra 9f
4:  clr.b OFF_ENEMY_SHOVE(%a5, %d5.w)
9:  movem.l (%sp)+, %d0-%d4/%d6/%a0
    rts

| d6.b = the opposite of direction d6.b
opposite_dir:
    move.l %d0, -(%sp)
    move.b %d6, %d0
    and.b #(DIR_RIGHT + DIR_DOWN), %d6
    add.b %d6, %d6
    and.b #(DIR_LEFT + DIR_UP), %d0
    lsr.b #1, %d0
    or.b %d0, %d6
    move.l (%sp)+, %d0
    rts

| A monster at a square boundary (d2 = X, d3 = Y) wants to go d6. If the square
| ahead is shut it tries a random side, then the other side, then straight back,
| as Walker_GetNextAltDir does. Returns d6 = the way to go, 0 when boxed in.
enemy_choose_dir:
    movem.l %d0-%d1/%d4, -(%sp)
    move.w %d6, %d1                 | the way it was facing
    moveq #0, %d4
1:  bsr enemy_cell_blocked
    tst.w %d0
    beq 9f
    addq.w #1, %d4
    cmp.w #2, %d4
    blo 2f
    beq 3f
    cmp.w #3, %d4
    beq 4f
    moveq #0, %d6
    bra 9f
2:  bsr rand8
    and.w #1, %d0
    move.w %d1, %d6
    and.b #DIR_VERTICAL, %d6
    bne 21f
    moveq #DIR_DOWN, %d6            | facing sideways: a random way up or down
    lsl.b %d0, %d6
    bra 1b
21: moveq #DIR_RIGHT, %d6           | facing up or down: a random way left or right
    lsl.b %d0, %d6
    bra 1b
3:  bsr opposite_dir                | the other side
    bra 1b
4:  move.w %d1, %d6                 | straight back
    bsr opposite_dir
    bra 1b
9:  movem.l (%sp)+, %d0-%d1/%d4
    rts

| The square one step from (d2, d3) in direction d6. Returns d0.w = 1 when it
| is not free.
enemy_cell_blocked:
    movem.l %d2-%d3, -(%sp)
    btst #0, %d6
    beq 1f
    add.w #16, %d2
    bra 5f
1:  btst #1, %d6
    beq 2f
    sub.w #16, %d2
    bra 5f
2:  btst #2, %d6
    beq 3f
    add.w #16, %d3
    bra 5f
3:  btst #3, %d6
    beq 4f
    sub.w #16, %d3
    bra 5f
4:  moveq #1, %d0
    bra 9f
5:  bsr enemy_square_blocked
9:  movem.l (%sp)+, %d2-%d3
    rts

| The 16x16 square whose origin is (d2, d3): is it outside the room, or does
| any of its four tiles block? Returns d0.w = 1 when it is no place for a
| walking monster.
enemy_square_blocked:
    movem.l %d1-%d5, -(%sp)
    tst.b OFF_LEVEL(%a5)
    bne 0f
    bsr enemy_out_of_bounds_ow
    bra 1f
0:  bsr enemy_out_of_bounds
1:  tst.w %d0
    bne 9f
    move.w %d3, %d4
    sub.w #(NES_PLAY_AREA_TOP - 3), %d4
    bmi 8f
    lsr.w #3, %d4                   | first tile row
    move.w %d2, %d5
    lsr.w #3, %d5                   | first tile column
    cmp.w #(PLAY_AREA_ROWS - 2), %d4
    bhi 8f
    cmp.w #(PLAY_AREA_COLS - 2), %d5
    bhi 8f
    moveq #3, %d1
1:  move.w %d4, %d2
    btst #1, %d1
    beq 2f
    addq.w #1, %d2
2:  move.w %d5, %d3
    btst #0, %d1
    beq 3f
    addq.w #1, %d3
3:  bsr fetch_tile
    bsr tile_blocks
    tst.w %d0
    bne 9f
    dbra %d1, 1b
    moveq #0, %d0
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d5
    rts

| d2.w = X, d3.w = Y. Returns d0.w = 1 outside the room's object bounds.
enemy_out_of_bounds:
    move.l %d1, -(%sp)
    moveq #1, %d0
    moveq #0, %d1
    move.b OFF_OBJ_LEFT(%a5), %d1
    cmp.w %d1, %d2
    blt 9f
    move.b OFF_OBJ_RIGHT(%a5), %d1
    cmp.w %d1, %d2
    bgt 9f
    move.b OFF_OBJ_UP(%a5), %d1
    cmp.w %d1, %d3
    blt 9f
    move.b OFF_OBJ_DOWN(%a5), %d1
    cmp.w %d1, %d3
    bgt 9f
    moveq #0, %d0
9:  move.l (%sp)+, %d1
    rts

| The overworld's version of the bounds: a monster may stop on the square next to a bound, because
| BoundByRoom only stops it going on through it (left bound $11 still lets it reach lane $10, up bound
| $4E lane $4D). Monsters that walk in from the edge need this to get going.
enemy_out_of_bounds_ow:
    move.l %d1, -(%sp)
    moveq #1, %d0
    moveq #0, %d1
    move.b OFF_OBJ_LEFT(%a5), %d1
    subq.w #1, %d1
    cmp.w %d1, %d2
    blt 9f
    move.b OFF_OBJ_RIGHT(%a5), %d1
    cmp.w %d1, %d2
    bgt 9f
    move.b OFF_OBJ_UP(%a5), %d1
    subq.w #1, %d1
    cmp.w %d1, %d3
    blt 9f
    move.b OFF_OBJ_DOWN(%a5), %d1
    cmp.w %d1, %d3
    bgt 9f
    moveq #0, %d0
9:  move.l (%sp)+, %d1
    rts

enemy_blocked_at:
    movem.l %d1-%d5, -(%sp)
    bsr enemy_out_of_bounds
    tst.w %d0
    bne 9f
    move.w %d2, %d4
    andi.w #0x00f8, %d4
    lsr.w #3, %d4
    cmpi.w #(PLAY_AREA_COLS - 1), %d4
    bls 1f
    moveq #(PLAY_AREA_COLS - 1), %d4
1:  move.w %d3, %d5
    addi.w #0x000b, %d5
    subi.w #NES_PLAY_AREA_TOP, %d5
    bpl 2f
    clr.w %d5
2:  lsr.w #3, %d5
    cmpi.w #(PLAY_AREA_ROWS - 1), %d5
    bls 3f
    moveq #(PLAY_AREA_ROWS - 1), %d5
3:  move.w %d5, %d2
    move.w %d4, %d3
    bsr fetch_tile
    bsr tile_blocks
9:  movem.l (%sp)+, %d1-%d5
    rts

draw_enemies:
    movem.l %d0-%d6/%a0-%a2, -(%sp)
    moveq #0, %d3
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d3
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d3.w)
    beq 8f
    btst #1, OFF_ENEMY_HURT(%a5, %d3.w)
    bne 8f                      | blink while hurt

    moveq #0, %d0
    move.b OFF_ENEMY_TYPE(%a5, %d3.w), %d0
    cmpi.b #0xff, %d0
    beq 2f

    | Underworld monster. Its mode says which of its images to show and whether
    | to mirror it, the way the original's update routines choose.
    ltab mon_table, %a0
    move.w %d0, %d1
    lsl.w #3, %d1
    moveq #0, %d2
    move.b 6(%a0, %d1.w), %d2   | mode
    move.w OFF_FRAME_COUNTER(%a5), %d4
    add.w %d3, %d4              | desynchronise the monsters
    moveq #0, %d1               | image
    moveq #0, %d5               | 1 = mirrored
    tst.w %d2
    beq 10f
    cmp.w #1, %d2
    beq 11f
    cmp.w #2, %d2
    beq 12f
    cmp.w #3, %d2
    beq 13f
    cmp.w #5, %d2
    beq 30f
    cmp.w #6, %d2
    beq 32f
    cmp.w #7, %d2
    beq 19f                     | the blade trap has one picture
    cmp.w #8, %d2
    beq 33f
    cmp.w #MODE_MOLDORM, %d2
    beq 19f                     | a Moldorm segment has one picture
    cmp.w #MODE_DODONGO, %d2
    bne 36f
    bsr draw_dodongo            | two sprites wide, drawn and remembered for erasing by its own routine
    bra 8f
36: cmp.w #MODE_TEKTITE, %d2
    blo 37f
    bsr mover_frame             | the movers pick their own pictures
    tst.w %d1
    bmi 8f
    bra 19f
37: move.w %d4, %d1             | keese: wings beat
    lsr.w #2, %d1
    and.w #1, %d1
    bra 19f
10: move.w %d4, %d6             | walker: walk frame
    lsr.w #3, %d6
    and.w #1, %d6
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #2, %d2
    beq 14f
    moveq #2, %d1               | facing down: the flip alternates
    move.w %d6, %d5
    bra 19f
14: btst #3, %d2
    beq 15f
    moveq #3, %d1               | facing up
    move.w %d6, %d5
    bra 19f
15: move.w %d6, %d1             | sideways, flipped to face left
    btst #1, %d2
    beq 19f
    moveq #1, %d5
    bra 19f
11: move.w %d4, %d5             | stalfos: the flip alternates
    lsr.w #3, %d5
    and.w #1, %d5
    bra 19f
12: move.w %d4, %d1             | rope: walk frame, flipped to face left
    lsr.w #3, %d1
    and.w #1, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #1, %d2
    beq 19f
    moveq #1, %d5
    bra 19f
13: move.w %d4, %d1             | gel: two images, swapped every two frames
    lsr.w #1, %d1
    and.w #1, %d1
    bra 19f
30: tst.b OFF_ENEMY_STATE(%a5, %d3.w)
    beq 8f                      | a wallmaster inside the wall is not seen
    move.w %d4, %d1             | open and closed hand, swapped every eight frames
    lsr.w #3, %d1
    and.w #1, %d1
    bra 19f
32: bsr draw_boss_head         | Aquamentus is drawn from his own pieces
    bra 8f
33: move.w %d4, %d1             | octorok: two animation sets, swapped every eight frames
    lsr.w #3, %d1
    and.w #1, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_DIR(%a5, %d3.w), %d2
    btst #2, %d2
    beq 34f
    addq.w #2, %d1              | facing down: the front
    bra 19f
34: btst #3, %d2
    beq 35f
    addq.w #4, %d1              | facing up: the back
    bra 19f
35: btst #0, %d2
    beq 19f
    moveq #1, %d5               | its side view looks left; mirror it to face right
19: add.w %d1, %d1
    add.w %d5, %d1              | frame within the monster's art
    ltab mon_art, %a0
    add.w %d0, %d0
    add.w 0(%a0, %d0.w), %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    movea.l OFF_MON_SPR(%a5), %a0
    adda.l %d1, %a0
    bra 4f

2:  move.w OFF_FRAME_COUNTER(%a5), %d1
    lsr.w #4, %d1
    add.w %d3, %d1
    andi.w #1, %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    ltab enemy_sprites, %a0
    adda.l %d1, %a0

4:  moveq #0, %d1
    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d2
    bsr sprite_offset
    tst.w %d4
    bmi 8f
    move.w %d3, %d0
    lsl.w #2, %d0
    lea OFF_ENEMY_ERASE_OFFSETS(%a5), %a2
    move.l %d1, 0(%a2, %d0.w)
    move.b #1, OFF_ENEMY_ERASE_VALID(%a5, %d3.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
8:  addq.w #1, %d3
    bra 1b
9:  movem.l (%sp)+, %d0-%d6/%a0-%a2
    rts

| NES coordinates to a screen offset. d1.w = X, d2.w = Y.
| Returns d1.l = byte offset of the sprite's top-left group and d4.w = shift
| within the group, or d4.w = -1 when the sprite would leave the playfield.
sprite_offset:
    movem.l %d0/%d2, -(%sp)
    moveq #-1, %d4
    cmp.w #0x00f1, %d1
    bhs 9f                      | also catches X below zero
    cmp.w #0x003e, %d2
    blt 9f
    cmp.w #0x00df, %d2
    bge 9f
    add.w #(PLAYFIELD_LEFT * 2), %d1
    move.w %d1, %d4
    and.w #15, %d4
    lsr.w #4, %d1
    lsl.w #3, %d1
    sub.w #LINK_Y_BIAS, %d2
    mulu.w #SCREEN_STRIDE, %d2
    add.l %d2, %d1
9:  movem.l (%sp)+, %d0/%d2
    rts

enemy_spawn_lists:
    .byte 0x55, 0xb5, 0x78, 0x98, 0x7a, 0x9a, 0x6c, 0xac, 0x8d
    .byte 0x82, 0x63, 0xa3, 0x75, 0x95, 0x77, 0x97, 0x5a, 0xba
    .byte 0xa3, 0x75, 0xb5, 0x96, 0x87, 0x99, 0x7a, 0xba, 0xac
    .byte 0x63, 0x55, 0x95, 0x76, 0x88, 0x79, 0x5a, 0x9a, 0x6c
