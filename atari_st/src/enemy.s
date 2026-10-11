| Minimal overworld enemy slice: repeated-template rooms of type $07 spawn a
| handful of simple wandering enemies rendered with a procedural sprite.

spawn_room_enemies:
    movem.l %d0-%d4/%a0, -(%sp)
    bsr clear_enemies

    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    lea room_attr_c(%pc), %a0
    moveq #0, %d1
    move.b 0(%a0, %d0.w), %d1
    move.w %d1, %d2
    andi.w #0x003f, %d2

    lea room_attr_d(%pc), %a0
    btst #7, 0(%a0, %d0.w)
    beq 1f
    ori.w #0x0040, %d2
1:  cmpi.w #ENEMY_TEMPLATE_07, %d2
    bne 9f

    lsr.w #6, %d1
    andi.w #3, %d1
    lea foe_counts(%pc), %a0
    moveq #0, %d2
    move.b 0(%a0, %d1.w), %d2
    cmpi.w #MAX_ENEMIES, %d2
    bls 2f
    moveq #MAX_ENEMIES, %d2
2:  move.b %d2, OFF_ENEMY_COUNT(%a5)
    beq 9f

    moveq #0, %d3
    move.b OFF_LINK_DIR(%a5), %d3
    bsr enemy_spawn_list_index
    lea enemy_spawn_lists(%pc), %a0
    mulu.w #9, %d0
    adda.w %d0, %a0

    moveq #0, %d3
3:  cmp.b OFF_ENEMY_COUNT(%a5), %d3
    bhs 9f
    moveq #0, %d0
    move.b 0(%a0, %d3.w), %d0

    move.w %d0, %d1
    lsl.w #4, %d1
    move.b %d1, OFF_ENEMY_X(%a5, %d3.w)
    andi.w #0x00f0, %d0
    ori.w #0x000d, %d0
    move.b %d0, OFF_ENEMY_Y(%a5, %d3.w)

    move.b #1, OFF_ENEMY_ACTIVE(%a5, %d3.w)
    move.b %d3, %d0
    andi.b #3, %d0
    addq.b #1, %d0
    move.b %d0, OFF_ENEMY_DIR(%a5, %d3.w)
    addq.w #1, %d3
    bra 3b
9:  movem.l (%sp)+, %d0-%d4/%a0
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
    lea OFF_ENEMY_ACTIVE(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
1:  clr.b (%a0)+
    dbra %d0, 1b
    lea OFF_ENEMY_ERASE_VALID(%a5), %a0
    moveq #(MAX_ENEMIES - 1), %d0
2:  clr.b (%a0)+
    dbra %d0, 2b
    movem.l (%sp)+, %d0/%a0
    rts

erase_enemies:
    rts

update_enemies:
    movem.l %d0-%d6, -(%sp)
    move.w OFF_FRAME_COUNTER(%a5), %d6
    moveq #0, %d5
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d5
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d5.w)
    beq 8f
    move.w %d6, %d1
    add.w %d5, %d1
    andi.w #3, %d1
    bne 8f

    moveq #0, %d2
    move.b OFF_ENEMY_X(%a5, %d5.w), %d2
    moveq #0, %d3
    move.b OFF_ENEMY_Y(%a5, %d5.w), %d3
    moveq #0, %d4
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    move.w %d2, %d0
    move.w %d3, %d1
    btst #0, %d4
    beq 2f
    addq.w #1, %d0
    bra 5f
2:  btst #1, %d4
    beq 3f
    subq.w #1, %d0
    bra 5f
3:  btst #2, %d4
    beq 4f
    addq.w #1, %d1
    bra 5f
4:  subq.w #1, %d1
5:  move.w %d0, %d2
    move.w %d1, %d3
    bsr enemy_blocked_at
    tst.w %d0
    beq 6f
    move.b OFF_ENEMY_DIR(%a5, %d5.w), %d4
    addq.b #1, %d4
    andi.b #3, %d4
    bne 7f
    move.b #DIR_UP, %d4
    bra 7f
6:  move.b %d2, OFF_ENEMY_X(%a5, %d5.w)
    move.b %d1, OFF_ENEMY_Y(%a5, %d5.w)
    bra 8f
7:  move.b %d4, OFF_ENEMY_DIR(%a5, %d5.w)
8:  addq.w #1, %d5
    bra 1b
9:  movem.l (%sp)+, %d0-%d6
    rts

enemy_blocked_at:
    movem.l %d1-%d5, -(%sp)
    cmpi.w #ROOM_BOUND_LEFT, %d2
    blt 8f
    cmpi.w #ROOM_BOUND_RIGHT, %d2
    bgt 8f
    cmpi.w #ROOM_BOUND_UP, %d3
    blt 8f
    cmpi.w #ROOM_BOUND_DOWN, %d3
    bgt 8f
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
    bra 9f
8:  moveq #1, %d0
9:  movem.l (%sp)+, %d1-%d5
    rts

draw_enemies:
    movem.l %d0-%d3/%a0-%a1, -(%sp)
    moveq #0, %d3
1:  cmp.b OFF_ENEMY_COUNT(%a5), %d3
    bhs 9f
    tst.b OFF_ENEMY_ACTIVE(%a5, %d3.w)
    beq 8f
    move.w OFF_FRAME_COUNTER(%a5), %d1
    lsr.w #4, %d1
    add.w %d3, %d1
    andi.w #1, %d1
    mulu.w #SPRITE_FRAME_BYTES, %d1
    lea enemy_sprites(%pc), %a0
    adda.l %d1, %a0

    moveq #0, %d1
    move.b OFF_ENEMY_X(%a5, %d3.w), %d1
    add.w #(PLAYFIELD_LEFT * 2), %d1
    move.w %d1, %d2
    and.w #15, %d2
    lsr.w #4, %d1
    lsl.w #3, %d1

    moveq #0, %d0
    move.b OFF_ENEMY_Y(%a5, %d3.w), %d0
    sub.w #LINK_Y_BIAS, %d0
    mulu.w #SCREEN_STRIDE, %d0
    add.l %d0, %d1

    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d2, %d0
    bsr draw_sprite
8:  addq.w #1, %d3
    bra 1b
9:  movem.l (%sp)+, %d0-%d3/%a0-%a1
    rts

enemy_spawn_lists:
    .byte 0x55, 0xb5, 0x78, 0x98, 0x7a, 0x9a, 0x6c, 0xac, 0x8d
    .byte 0x82, 0x63, 0xa3, 0x75, 0x95, 0x77, 0x97, 0x5a, 0xba
    .byte 0xa3, 0x75, 0xb5, 0x96, 0x87, 0x99, 0x7a, 0xba, 0xac
    .byte 0x63, 0x55, 0x95, 0x76, 0x88, 0x79, 0x5a, 0x9a, 0x6c
