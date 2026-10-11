| The Legend of Zelda -- Atari ST overworld engine.
|
| Link and the room grid keep NES coordinates internally (X 0..255,
| Y $40..$EF), so every constant lifted from the disassembly -- the room
| bounds, the collision hotspot offsets, the unwalkable tile threshold --
| is used exactly as the 6502 used it. Conversion to ST screen coordinates
| happens only at draw time.
|
| Screen layout:
|     y   0.. 23   HUD ribbon, three 8-pixel tile rows, full 320 wide
|     y  24..199   playfield, 256x176, x = 32..287

    .include "assets.inc"
    .include "globals.s"
    .if UW_ROOM_BYTES != 704
    .error "globals.s sizes the underworld map buffers as 704 bytes"
    .endif

| A6 holds table_anchor for the whole run. The read-only tables total more than
| a signed 16-bit PC-relative displacement can reach from the code, so they are
| addressed as signed offsets from an anchor placed in the middle of them.
    .macro ltab sym, reg
    lea \sym - table_anchor(%a6), \reg
    .endm

| ------------------------------------------------------------ screen geometry
    .equ SCREEN_STRIDE, 160
    .equ SCREEN_BYTES, 32000
    .equ SCREEN_LONGS, (SCREEN_BYTES / 4)

    .equ HUD_ROWS, 3
    .equ HUD_HEIGHT, (HUD_ROWS * 8)
    .equ PLAYFIELD_TOP, HUD_HEIGHT
    .equ PLAYFIELD_HEIGHT, (MAP_HEIGHT * 16)
    .equ PLAYFIELD_BYTES, (MAP_WIDTH * 8)
    .equ PLAYFIELD_LEFT, ((SCREEN_STRIDE - PLAYFIELD_BYTES) / 2)
    .equ PLAYFIELD_ORIGIN, (PLAYFIELD_TOP * SCREEN_STRIDE + PLAYFIELD_LEFT)
| The NES status bar occupies the first $40 lines; the play area follows it.
    .equ NES_PLAY_AREA_TOP, 0x40
| Mapping a NES Y to a screen line, including the two-pixel drop the overworld
| gives Link in Z_07.asm.
    .equ LINK_DRAW_OFFSET_Y, 2
    .equ LINK_Y_BIAS, (NES_PLAY_AREA_TOP - PLAYFIELD_TOP - LINK_DRAW_OFFSET_Y)

| Three full screens: the one being displayed, the clean render of the current
| room, and the room being scrolled in.
    .equ BUFFER_COUNT, 3
    .equ BUFFER_ALLOC, (BUFFER_COUNT * SCREEN_BYTES + 256)

| ------------------------------------------------------------------- sprites
    .equ SPRITE_HEIGHT, 16
    .equ SPRITE_ROW_BYTES, 10       | four bitplane words plus an opacity mask
    .equ SPRITE_SPAN_BYTES, 16      | a 16px sprite at any X touches two groups

| ------------------------------------------------------------------ movement
| InitLinkSpeed gives Link a quarter-speed of $60, i.e. 1.5 pixels a frame.
    .equ LINK_QSPEED, 0x60
    .equ LINK_SUBPIXEL_SHIFT, 6
    .equ LINK_SUBPIXEL_MASK, ((1 << LINK_SUBPIXEL_SHIFT) - 1)
    .equ LINK_ANIM_PERIOD, 6
| GetCollidableTile starts the hotspot $B pixels below the object's top.
    .equ HOTSPOT_Y_OFFSET, 0x0B
    .equ HOTSPOT_STEP, 8
    .equ HOTSPOT_RIGHT_STEP, 0x10
    .equ HOTSPOT_DOWN_LIMIT, 0xDD
    .equ HOTSPOT_LEFT_LIMIT, 0x10
    .equ HOTSPOT_RIGHT_LIMIT, 0xF0
| EnsureObjectAligned snaps X to a multiple of 8 and Y to a multiple of 8 plus 5.
    .equ ALIGN_MASK, 0xF8
    .equ ALIGN_Y_BIAS, 0x05
    .equ PLAY_AREA_COLS, 32
    .equ PLAY_AREA_ROWS, 22

| ----------------------------------------------------------------- scrolling
| 16 pixels a step keeps every copy byte-aligned, so no bit shifting is needed.
    .equ SCROLL_STEP_PIXELS, 16
    .equ SCROLL_STEP_BYTES, 8
    .equ SCROLL_STEPS_H, MAP_WIDTH
    .equ SCROLL_STEPS_V, MAP_HEIGHT

    .equ MODE_PLAY, 0
    .equ MODE_SCROLL, 1
    .equ MODE_CAVE, 2

| PlayerScreenEdgeBounds (Z_07.asm): Link leaves the overworld screen when he
| reaches these coordinates. ObjectRoomBoundsOW is for other objects, not Link.
    .equ LINK_EDGE_LEFT, 0x00
    .equ LINK_EDGE_RIGHT, 0xf0
    .equ LINK_EDGE_UP, 0x3d
    .equ LINK_EDGE_DOWN, 0xdd

    .equ MAX_ENEMIES, 8
    .equ ENEMY_TEMPLATE_07, 0x07

| ---------------------------------------------------------------- caves
    .equ CAVE_ENTRANCE_TILE, 0x24
    .equ CAVE_ROOM_BOUND_LEFT, 0x21
    .equ CAVE_ROOM_BOUND_RIGHT, 0xd0
    .equ CAVE_ROOM_BOUND_UP, 0x5e
    .equ CAVE_ROOM_BOUND_DOWN, 0xbd
    .equ CAVE_START_Y, 0xad
    .equ CAVE_RETURN_Y, 0x5c
    .equ CAVE_EXIT_HALF_WIDTH, 0x10

| ------------------------------------------------------------------ HUD slots
    .equ HUD_COUNTER_COL, 4
    .equ HUD_HEART_COL, 26
    .equ HUD_HEARTS_PER_ROW, 8
    .equ HUD_HEART_SLOTS, 16

| -------------------------------------------------------------- ST hardware
    .equ VIDEO_BASE_HI, 0x00ff8201
    .equ VIDEO_BASE_MID, 0x00ff8203
    .equ VIDEO_BASE_LOW, 0x00ff820d
    .equ PALETTE_BASE, 0x00ff8240
    .equ SHIFT_MODE, 0x00ff8260
    .equ FR_CLOCK, 0x00000462
    .equ IKBD_ACIA_STATUS, 0x00fffc00
    .equ IKBD_ACIA_DATA, 0x00fffc02
    .equ MFP_IERB, 0x00fffa09
    .equ MFP_IMRB, 0x00fffa15
    .equ MFP_IKBD_BIT, 0x40

    .equ GEMDOS_PTERM0, 0x00
    .equ GEMDOS_MALLOC, 0x48
    .equ GEMDOS_MSHRINK, 0x4a
    .equ GEMDOS_SUPER, 0x20

    .equ STACK_BYTES, 4096
    .equ BP_TEXT_LEN, 12
    .equ BP_DATA_LEN, 20
    .equ BP_BSS_LEN, 28
    .equ BASEPAGE_BYTES, 256

    .section .text
    .globl _start
_start:
    lea globals(%pc), %a5
    | room_palette is the first read-only table and close enough for a PC-relative
    | lea; the anchor in the middle of the tables is then a link-time constant away.
    lea room_palette(%pc), %a6
    adda.l #(table_anchor - room_palette), %a6
    | Clear the variable block before anything is stored in it; bsr leaves the
    | stack alone, so the basepage is still at 4(sp) afterwards.
    bsr init_state

    | GEMDOS passes the basepage at 4(sp).
    movea.l 4(%sp), %a0
    move.l %a0, OFF_BASEPAGE(%a5)

    | Pexec hands the program the whole TPA, so Malloc has nothing left to give
    | and returns 0. Release everything past the program image with Mshrink --
    | but move onto our own stack first, because the GEMDOS-supplied stack sits
    | at the top of that region and Malloc would hand it straight back to us.
    lea stack_top(%pc), %sp

    move.l BP_TEXT_LEN(%a0), %d0
    add.l BP_DATA_LEN(%a0), %d0
    add.l BP_BSS_LEN(%a0), %d0
    addi.l #BASEPAGE_BYTES, %d0
    move.l %d0, -(%sp)
    move.l %a0, -(%sp)
    clr.w -(%sp)
    move.w #GEMDOS_MSHRINK, -(%sp)
    trap #1
    lea 12(%sp), %sp

    | ST hardware registers and system variables are supervisor-only;
    | a desktop-launched PRG starts in user mode and would bus error.
    clr.l -(%sp)
    move.w #GEMDOS_SUPER, -(%sp)
    trap #1
    addq.l #6, %sp
    move.l %d0, OFF_OLD_SSP(%a5)

    bsr init_buffers
    bsr init_video
    .if DEV_START_UW != 255
    | Development shortcut: start inside the level, with a sword and a key.
    move.b #UW_LEVEL, OFF_LEVEL(%a5)
    move.b #UW_BOUND_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_BOUND_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_BOUND_DOWN(%a5)
    move.b #UW_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #UW_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #UW_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #UW_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b #DEV_START_UW, OFF_ROOM_ID(%a5)
    move.b #0x78, OFF_LINK_X(%a5)
    move.b #0x8d, OFF_LINK_Y(%a5)
    move.b #1, OFF_HAS_SWORD(%a5)
    .endif
    bsr enter_room
    bsr draw_hud

main_loop:
    bsr wait_vbl
    bsr poll_keyboard
    bsr debug_keys
    tst.b OFF_EXIT_REQUESTED(%a5)
    bne exit_program
    addq.w #1, OFF_FRAME_COUNTER(%a5)

    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 1f
    cmp.b #MODE_SCROLL, %d0
    beq 2f
    bsr update_cave
    bra 3f
1:  bsr update_play
    bra 3f
2:  bsr update_scroll
3:  tst.b OFF_HUD_DIRTY(%a5)
    beq main_loop
    bsr draw_hud
    bra main_loop

exit_program:
    bsr restore_video
    bra terminate

no_memory:
    | Nothing has been reprogrammed yet, so just hand the machine back.
terminate:
    move.l OFF_OLD_SSP(%a5), -(%sp)
    move.w #GEMDOS_SUPER, -(%sp)
    trap #1
    addq.l #6, %sp

    move.w #GEMDOS_PTERM0, -(%sp)
    trap #1

| ---------------------------------------------------------------------------
init_state:
    | Zero the whole variable block, then set what needs a non-zero start.
    lea globals(%pc), %a0
    move.w #(GLOBALS_BYTES - 1), %d7
    moveq #0, %d0
1:  move.b %d0, (%a0)+
    dbra %d7, 1b

    move.b #START_ROOM_ID, OFF_ROOM_ID(%a5)
    move.b #START_X, OFF_LINK_X(%a5)
    move.b #START_Y, OFF_LINK_Y(%a5)
    move.b #START_DIR, OFF_LINK_DIR(%a5)
    move.b #MODE_PLAY, OFF_GAME_MODE(%a5)
    move.b #3, OFF_HEART_CONTAINERS(%a5)
    move.b #6, OFF_HP_HALVES(%a5)
    move.w #0xace1, OFF_RNG(%a5)
    move.b #ROOM_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.b #ROOM_BOUND_RIGHT, OFF_OBJ_RIGHT(%a5)
    move.b #ROOM_BOUND_UP, OFF_OBJ_UP(%a5)
    move.b #ROOM_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    move.b #LINK_EDGE_LEFT, OFF_BOUND_LEFT(%a5)
    move.b #LINK_EDGE_RIGHT, OFF_BOUND_RIGHT(%a5)
    move.b #LINK_EDGE_UP, OFF_BOUND_UP(%a5)
    move.b #LINK_EDGE_DOWN, OFF_BOUND_DOWN(%a5)
    rts

init_buffers:
    move.l #BUFFER_ALLOC, -(%sp)
    move.w #GEMDOS_MALLOC, -(%sp)
    trap #1
    addq.l #6, %sp
    tst.l %d0
    beq no_memory

    | The shifter wants its base on a 256-byte boundary, and a screen is an
    | exact multiple of 256, so aligning once aligns all three buffers.
    add.l #255, %d0
    and.l #0xffffff00, %d0
    move.l %d0, OFF_SCREEN_PTR(%a5)
    add.l #SCREEN_BYTES, %d0
    move.l %d0, OFF_BG_CUR(%a5)
    add.l #SCREEN_BYTES, %d0
    move.l %d0, OFF_BG_NEXT(%a5)

    movea.l OFF_SCREEN_PTR(%a5), %a0
    move.l #(BUFFER_COUNT * SCREEN_LONGS - 1), %d7
    moveq #0, %d0
1:  move.l %d0, (%a0)+
    subq.l #1, %d7
    bpl 1b
    rts

| Render the current room into bg_cur and show it.
enter_room:
    clr.b OFF_COMMIT(%a5)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    movea.l OFF_BG_CUR(%a5), %a1
    tst.b OFF_LEVEL(%a5)
    bne 1f
    bsr render_room
    bra 2f
1:  bsr uw_render_current
2:  bsr spawn_room_enemies
    bsr show_background
    clr.b OFF_ERASE_VALID(%a5)
    bsr draw_link
    bsr draw_enemies
    rts

enter_cave:
    clr.b OFF_COMMIT(%a5)
    bsr clear_enemies
    movea.l OFF_BG_CUR(%a5), %a1
    bsr render_cave_room
    bsr show_background
    clr.b OFF_ERASE_VALID(%a5)
    bsr draw_link
    rts

| Copy the whole playfield from bg_cur to the visible screen.
show_background:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l #PLAYFIELD_ORIGIN, %a0
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l #PLAYFIELD_ORIGIN, %a1
    move.w #PLAYFIELD_HEIGHT, %d0
    move.w #PLAYFIELD_BYTES, %d1
    bsr blit_rect
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

update_play:
    bsr erase_bomb
    bsr erase_sword
    bsr erase_items
    bsr erase_enemies
    bsr erase_sprite
    bsr sword_input
    bsr bomb_input
    bsr link_update
    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 3f
    cmp.b #MODE_SCROLL, %d0
    beq update_scroll       | a room transition started this frame
    rts                      | cave entry already redrew the new background
3:
    bsr update_enemies
    bsr update_combat
    bsr draw_items
    bsr draw_bomb
    bsr draw_enemies
    bsr draw_link_blink
    bsr draw_sword
    rts

    .include "video.s"
    .include "sprite.s"
    .include "enemy.s"
    .include "combat.s"
    .include "link.s"
    .include "uw.s"
    .include "hud.s"
    .include "input.s"

| ---------------------------------------------------------------------------
    .section .rodata
    .align 2
hud_tiles:
    .incbin "hud_tiles.bin"
link_sprites:
    .incbin "link_sprites.bin"
enemy_sprites:
    .incbin "enemy_sprites.bin"
metatile_tiles:
    .incbin "metatile_tiles.bin"
uw_tiles:
    .incbin "uw_tiles.bin"
uw_tile_nes:
    .incbin "uw_tile_nes.bin"
uw_room_index:
    .incbin "uw_room_index.bin"
    .align 2
uw_door_cells:
    .incbin "uw_door_cells.bin"
    .align 2
uw_doors:
    .incbin "uw_doors.bin"
    .align 2
uw_rooms:
    .incbin "uw_rooms.bin"
    .align 2
table_anchor:
    | Actor tables sit right after the anchor, so they are within reach of
    | the signed 16-bit displacement from it.
mon_sprites:
    .incbin "mon_sprites.bin"
item_sprites:
    .incbin "item_sprites.bin"
sword_sprites:
    .incbin "sword_sprites.bin"
mon_table:
    .incbin "mon_table.bin"
item_index:
    .incbin "item_index.bin"
drop_table:
    .incbin "drop_table.bin"
drop_rates:
    .incbin "drop_rates.bin"
uw_room_info:
    .incbin "uw_room_info.bin"
uw_cellar_info:
    .incbin "uw_cellar_info.bin"
    .align 2
uw_cellar_maps:
    .incbin "uw_cellar_maps.bin"
    .align 2
metatiles:
    .incbin "metatiles.bin"
| room_maps is by far the largest table, so it goes last: every label above it
| has to stay inside the 68000's signed 16-bit PC-relative displacement.
room_maps:
    .incbin "room_maps.bin"

    .section .data
    .align 2
    | Lets the test harness locate the variable block in a RAM dump.
globals_marker:
    .ascii "ZELDAST1"
globals:
    .space GLOBALS_BYTES

    | The stack lives in .data rather than after .rodata because _start reaches
    | it with a PC-relative lea, which the 68000 limits to a signed 16-bit
    | displacement. .data is emitted before the big tables, so it stays in range.
    .align 2
stack_bottom:
    .space STACK_BYTES
stack_top:
