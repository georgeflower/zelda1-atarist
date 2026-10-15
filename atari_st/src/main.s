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
    .include "music_ids.inc"
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

| Sound: sfx plays an effect over the music, jingle an event song that replaces it
| (music.s). Neither disturbs any register.
    .macro sfx id
    move.l %d0, -(%sp)
    moveq #\id, %d0
    bsr music_play
    move.l (%sp)+, %d0
    .endm

    .macro jingle id
    move.l %d0, -(%sp)
    moveq #\id, %d0
    bsr music_event
    move.l (%sp)+, %d0
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
    .equ MODE_MENU, 3

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
    .equ CAVE_ROOM_BOUND_UP, 0x95
    .equ CAVE_ROOM_BOUND_DOWN, 0xbd
    .equ CAVE_START_Y, 0xbd
    .equ CAVE_RETURN_Y, 0x5c
    .equ CAVE_DOOR_CENTER, 0x78
    .equ CAVE_EXIT_HALF_WIDTH, 0x08
    .equ CAVE_EXIT_Y, 0xc5
    .equ CAVE_PERSON_Y, 0x80
    .equ CAVE_ITEM_Y, 0x98
    .equ CAVE_TEXT_COL0, 8
    .equ CAVE_TEXT_ROW0, 8
    .equ CAVE_TEXT_DELAY, 6

| The game opens in front of the first cave, not at the start the data names.
    .if START_ROOM_ID == 0x77
    .equ HOME_X, 0x40
    .equ HOME_Y, 0x5d
    .else
    .equ HOME_X, START_X
    .equ HOME_Y, START_Y
    .endif

| ------------------------------------------------------------------ HUD slots
    .equ HUD_COUNTER_COL, 4
    .equ HUD_HEART_COL, 26
    .equ HUD_HEARTS_PER_ROW, 8
    .equ HUD_HEART_SLOTS, 16

| -------------------------------------------------------------- ST hardware
    .equ VIDEO_BASE_HI, 0x00ff8201
    .equ VIDEO_BASE_MID, 0x00ff8203
    .equ VIDEO_BASE_LOW, 0x00ff820d
    .equ VIDEO_COUNTER_HI, 0x00ff8205
    .equ VIDEO_COUNTER_MID, 0x00ff8207
    .equ VIDEO_COUNTER_LOW, 0x00ff8209
    .equ VIDEO_COUNTER_HI, 0x00ff8205
    .equ VIDEO_COUNTER_MID, 0x00ff8207
    .equ VIDEO_COUNTER_LOW, 0x00ff8209
    .equ PALETTE_BASE, 0x00ff8240
    .equ SHIFT_MODE, 0x00ff8260
    .equ FR_CLOCK, 0x00000462
    .equ IKBD_ACIA_STATUS, 0x00fffc00
    .equ IKBD_ACIA_DATA, 0x00fffc02
    .equ MFP_IERB, 0x00fffa09
    .equ MFP_IMRB, 0x00fffa15
    .equ MFP_IKBD_BIT, 0x40
    .equ MFP_ISRB, 0x00fffa11
    .equ MIDI_ACIA_STATUS, 0x00fffc04
    .equ MIDI_ACIA_DATA, 0x00fffc06
    .equ IKBD_VECTOR, 0x00000118

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
    bsr music_init
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
    move.b #0x37, OFF_CAVE_SOURCE_ROOM(%a5)     | the level 1 entrance, where leaving comes out
    .endif
    bsr enter_room
    bsr draw_hud

main_loop:
    bsr wait_vbl
    bsr frame_begin
    bsr poll_keyboard
    bsr debug_keys
    bsr music_update
    tst.b OFF_EXIT_REQUESTED(%a5)
    bne exit_program
    addq.w #1, OFF_FRAME_COUNTER(%a5)

    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 1f
    cmp.b #MODE_SCROLL, %d0
    beq 2f
    cmp.b #MODE_MENU, %d0
    beq 4f
    bsr update_cave
    bra 3f
4:  bsr update_menu
    bra 3f
1:  bsr update_play
    bra 3f
2:  bsr update_scroll
3:  bsr minimap_tick
    tst.b OFF_HUD_DIRTY(%a5)
    beq main_loop
    bsr draw_hud
    tst.b OFF_DBL_ACTIVE(%a5)
    beq main_loop
    bsr swap_screens            | the other buffer needs the new ribbon too
    bsr draw_hud
    bsr swap_screens
    bra main_loop

exit_program:
    bsr music_exit
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
    move.b #HOME_X, OFF_LINK_X(%a5)
    move.b #HOME_Y, OFF_LINK_Y(%a5)
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
    clr.b OFF_CAVE_FIRE_VALID(%a5)
    bsr clear_enemies
    bsr clear_items
    sfx SFX_STAIRS
    bsr cave_setup
    bsr cave_redraw
    clr.b OFF_ERASE_VALID(%a5)
    bsr draw_link
    rts

| The first cave (type $40) has the old man, who gives the wooden sword.
cave_setup:
    movem.l %d0/%a0, -(%sp)
    clr.b OFF_CAVE_PERSON(%a5)
    clr.b OFF_CAVE_TEXT_ON(%a5)
    tst.b OFF_HAS_SWORD(%a5)
    bne 9f
    ltab room_attr_b, %a0
    moveq #0, %d0
    move.b OFF_CAVE_SOURCE_ROOM(%a5), %d0
    move.b 0(%a0, %d0.w), %d0
    and.w #0x00fc, %d0
    cmp.w #0x40, %d0
    bne 9f
    move.b #1, OFF_CAVE_PERSON(%a5)
    move.b #1, OFF_CAVE_TEXT_ON(%a5)
    clr.b OFF_CAVE_TEXT_IDX(%a5)
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_ROW0, OFF_CAVE_TEXT_ROW(%a5)
    move.b #CAVE_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    move.b #2, OFF_ITEM_ACTIVE(%a5)
    move.b #ITEM_WOOD_SWORD, OFF_ITEM_ID(%a5)
    move.b #CAVE_DOOR_CENTER, OFF_ITEM_X(%a5)
    move.b #CAVE_ITEM_Y, OFF_ITEM_Y(%a5)
9:  movem.l (%sp)+, %d0/%a0
    rts

| Draw the cave room with its bonfires and, while he is there, the old man.
cave_redraw:
    movem.l %d0-%d2, -(%sp)
    movea.l OFF_BG_CUR(%a5), %a1
    bsr render_cave_room
    tst.b OFF_CAVE_PERSON(%a5)
    beq 1f
    moveq #0, %d0
    move.w #CAVE_DOOR_CENTER, %d1
    move.w #CAVE_PERSON_Y, %d2
    bsr cave_bake_sprite
1:  bsr show_background
    bsr draw_cave_fires
    movem.l (%sp)+, %d0-%d2
    rts

| The bonfires flicker: their picture turns round every six frames. They are
| drawn over the clean room each frame rather than baked into it.
erase_cave_fires:
    movem.l %d0/%d3/%a0, -(%sp)
    tst.b OFF_CAVE_FIRE_VALID(%a5)
    beq 9f
    lea OFF_CAVE_FIRE_OFFSETS(%a5), %a0
    moveq #1, %d3
1:  move.w %d3, %d0
    lsl.w #2, %d0
    move.l 0(%a0, %d0.w), %d0
    bsr erase_at
    dbra %d3, 1b
    clr.b OFF_CAVE_FIRE_VALID(%a5)
9:  movem.l (%sp)+, %d0/%d3/%a0
    rts

draw_cave_fires:
    movem.l %d0-%d4/%a0-%a2, -(%sp)
    moveq #0, %d0
    move.w OFF_FRAME_COUNTER(%a5), %d0
    divu.w #6, %d0
    and.w #1, %d0
    addq.w #1, %d0              | cave_sprites: 1 the fire, 2 the fire turned round
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab cave_sprites, %a0
    adda.l %d0, %a0
    lea OFF_CAVE_FIRE_OFFSETS(%a5), %a2
    moveq #0, %d3
1:  moveq #0, %d1
    move.w #0x48, %d1
    tst.w %d3
    beq 2f
    move.w #0xa8, %d1
2:  move.w #CAVE_PERSON_Y, %d2
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    move.w %d3, %d0
    lsl.w #2, %d0
    move.l %d1, 0(%a2, %d0.w)
    movea.l OFF_SCREEN_PTR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
    addq.w #1, %d3
    cmp.w #2, %d3
    blo 1b
    move.b #1, OFF_CAVE_FIRE_VALID(%a5)
9:  movem.l (%sp)+, %d0-%d4/%a0-%a2
    rts

| Paint cave sprite d0 into the clean room, so erasing Link never wipes it.
| d1.w = X, d2.w = Y
cave_bake_sprite:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    mulu.w #SPRITE_FRAME_BYTES, %d0
    ltab cave_sprites, %a0
    adda.l %d0, %a0
    bsr sprite_offset
    tst.w %d4
    bmi 9f
    movea.l OFF_BG_CUR(%a5), %a1
    adda.l %d1, %a1
    move.w %d4, %d0
    bsr draw_sprite
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| The old man's speech, one character every few frames. Link stands still
| until it is finished.
cave_talk:
    movem.l %d0-%d4/%a0-%a1, -(%sp)
    tst.b OFF_CAVE_TEXT_ON(%a5)
    beq 9f
    subq.b #1, OFF_CAVE_TEXT_TIMER(%a5)
    bne 9f
    ltab cave_text, %a0
    ltab text_glyphs, %a1
1:  moveq #0, %d0
    move.b OFF_CAVE_TEXT_IDX(%a5), %d0
    moveq #0, %d4
    move.b 0(%a0, %d0.w), %d4
    addq.b #1, OFF_CAVE_TEXT_IDX(%a5)
    move.w %d4, %d3
    and.w #0x3f, %d3
    cmp.w #0x25, %d3            | a space that takes no time
    bne 2f
    addq.b #1, OFF_CAVE_TEXT_COL(%a5)
    bra 1b
2:  moveq #0, %d0
    move.b 0(%a1, %d3.w), %d0
    moveq #0, %d1
    move.b OFF_CAVE_TEXT_COL(%a5), %d1
    moveq #0, %d2
    move.b OFF_CAVE_TEXT_ROW(%a5), %d2
    bsr draw_hud_tile
    move.l OFF_SCREEN_PTR(%a5), -(%sp)  | and into the clean room, to survive Link's erasing
    move.l OFF_BG_CUR(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
    sfx SFX_HEART                       | the text blip
    addq.b #1, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    and.w #0xc0, %d4
    beq 9f
    move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    cmp.w #0x80, %d4
    bne 3f
    move.b #(CAVE_TEXT_ROW0 + 1), OFF_CAVE_TEXT_ROW(%a5)
    bra 9f
3:  cmp.w #0x40, %d4
    bne 4f
    move.b #(CAVE_TEXT_ROW0 + 2), OFF_CAVE_TEXT_ROW(%a5)
    bra 9f
4:  clr.b OFF_CAVE_TEXT_ON(%a5)     | the last line: he has finished
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
    rts

| Once the sword is in Link's hands the old man and his words are gone.
cave_check_taken:
    tst.b OFF_CAVE_PERSON(%a5)
    beq 9f
    tst.b OFF_HAS_SWORD(%a5)
    beq 9f
    clr.b OFF_CAVE_PERSON(%a5)
    bsr cave_redraw
    clr.b OFF_ERASE_VALID(%a5)
9:  rts

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
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 9f
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l #PLAYFIELD_ORIGIN, %a0
    movea.l OFF_BG_NEXT(%a5), %a1
    adda.l #PLAYFIELD_ORIGIN, %a1
    move.w #PLAYFIELD_HEIGHT, %d0
    move.w #PLAYFIELD_BYTES, %d1
    bsr blit_rect
    bsr clear_erase_state
9:  movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

| ---------------------------------------------------------- double buffering
| Playing frames draw into a hidden buffer that is shown on the next frame, so
| the beam never catches a sprite between its erase and its redraw. SCREEN_PTR
| is always the buffer being drawn into; BG_NEXT is the other one. Scrolls and
| caves draw straight to the visible screen instead (DBL_ACTIVE = 0), and then
| SCREEN_PTR is the visible buffer and BG_NEXT is scratch space again.

| d0 = screen address
set_video_base:
    movea.l #VIDEO_BASE_LOW, %a0
    move.b %d0, (%a0)
    lsr.l #8, %d0
    movea.l #VIDEO_BASE_MID, %a0
    move.b %d0, (%a0)
    lsr.l #8, %d0
    movea.l #VIDEO_BASE_HI, %a0
    move.b %d0, (%a0)
    rts

| The shifter takes the base at the end of the frame, so it has to be written
| before the next frame starts drawing into the buffer that is on show now.
| wait_vbl checks that the write made it in time.
present_frame:
    movem.l %d0/%a0, -(%sp)
    move.l OFF_SCREEN_PTR(%a5), %d0
    move.l %d0, OFF_PRESENT_BASE(%a5)
    move.b #1, OFF_PRESENT_PENDING(%a5)
    bsr set_video_base
    movem.l (%sp)+, %d0/%a0
    rts

swap_screens:
    move.l %d0, -(%sp)
    move.l OFF_SCREEN_PTR(%a5), %d0
    move.l OFF_BG_NEXT(%a5), OFF_SCREEN_PTR(%a5)
    move.l %d0, OFF_BG_NEXT(%a5)
    move.l (%sp)+, %d0
    rts

frame_begin:
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    movem.l %d0/%a0, -(%sp)
    tst.b OFF_DBL_ACTIVE(%a5)
    bne 2f
    bsr dbl_enter
2:  bsr swap_screens
    bsr swap_erase_state
    movem.l (%sp)+, %d0/%a0
9:  rts

| Leave double buffering for a frame type that writes to the visible screen.
dbl_end:
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 9f
    movem.l %d0/%a0, -(%sp)
    move.l OFF_SCREEN_PTR(%a5), %d0     | already erased down to the bare room
    bsr set_video_base
    clr.b OFF_DBL_ACTIVE(%a5)
    movem.l (%sp)+, %d0/%a0
9:  rts

| Make the hidden buffer a clean copy of the visible one, with the room redrawn over it.
dbl_enter:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    movea.l OFF_SCREEN_PTR(%a5), %a0
    movea.l OFF_BG_NEXT(%a5), %a1
    move.w #(SCREEN_LONGS / 4 - 1), %d0
1:  move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    move.l (%a0)+, (%a1)+
    dbra %d0, 1b
    movea.l OFF_BG_CUR(%a5), %a0
    adda.l #PLAYFIELD_ORIGIN, %a0
    movea.l OFF_BG_NEXT(%a5), %a1
    adda.l #PLAYFIELD_ORIGIN, %a1
    move.w #PLAYFIELD_HEIGHT, %d0
    move.w #PLAYFIELD_BYTES, %d1
    bsr blit_rect
    bsr clear_old_erase_state
    move.b #1, OFF_DBL_ACTIVE(%a5)
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

    .macro xchg_state first, second, count
    lea OFF_\first(%a5), %a0
    lea OFF_\second(%a5), %a1
    moveq #(\count - 1), %d0
1:  move.b (%a0), %d1
    move.b (%a1), (%a0)+
    move.b %d1, (%a1)+
    dbra %d0, 1b
    .endm

    .macro clear_state name, count
    lea OFF_\name(%a5), %a0
    moveq #(\count - 1), %d0
1:  clr.b (%a0)+
    dbra %d0, 1b
    .endm

| What the sprites erased this frame are is what was drawn two frames ago.
swap_erase_state:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    xchg_state ENEMY_ERASE_VALID, OLD_ENEMY_ERASE_VALID, 8
    xchg_state ENEMY_ERASE_OFFSETS, OLD_ENEMY_ERASE_OFFSETS, 32
    xchg_state PROJ_ERASE_VALID, OLD_PROJ_ERASE_VALID, 8
    xchg_state PROJ_ERASE_OFFSETS, OLD_PROJ_ERASE_OFFSETS, 32
    xchg_state ITEM_ERASE_VALID, OLD_ITEM_ERASE_VALID, 3
    xchg_state ITEM_ERASE_OFFSETS, OLD_ITEM_ERASE_OFFSETS, 12
    xchg_state SWORD_VALID, OLD_SWORD_VALID, 1
    xchg_state SWORD_ERASE_OFFSET, OLD_SWORD_ERASE_OFFSET, 4
    xchg_state BOMB_VALID, OLD_BOMB_VALID, 1
    xchg_state BOMB_ERASE_OFFSET, OLD_BOMB_ERASE_OFFSET, 4
    xchg_state ERASE_VALID, OLD_ERASE_VALID, 1
    xchg_state ERASE_OFFSET, OLD_ERASE_OFFSET, 4
    xchg_state BEAM_VALID, OLD_BEAM_VALID, 1
    xchg_state BEAM_ERASE_OFFSET, OLD_BEAM_ERASE_OFFSET, 4
    xchg_state FX_VALID, OLD_FX_VALID, 12
    xchg_state FX_ERASE_OFFSETS, OLD_FX_ERASE_OFFSETS, 48
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

clear_old_erase_state:
    movem.l %d0/%a0, -(%sp)
    clear_state OLD_ENEMY_ERASE_VALID, 8
    clear_state OLD_PROJ_ERASE_VALID, 8
    clear_state OLD_ITEM_ERASE_VALID, 3
    clr.b OFF_OLD_SWORD_VALID(%a5)
    clr.b OFF_OLD_BOMB_VALID(%a5)
    clr.b OFF_OLD_ERASE_VALID(%a5)
    clr.b OFF_OLD_BEAM_VALID(%a5)
    clear_state OLD_FX_VALID, 12
    movem.l (%sp)+, %d0/%a0
    rts

clear_erase_state:
    movem.l %d0/%a0, -(%sp)
    bsr clear_old_erase_state
    clear_state ENEMY_ERASE_VALID, 8
    clear_state PROJ_ERASE_VALID, 8
    clear_state ITEM_ERASE_VALID, 3
    clr.b OFF_SWORD_VALID(%a5)
    clr.b OFF_BOMB_VALID(%a5)
    clr.b OFF_ERASE_VALID(%a5)
    clr.b OFF_BEAM_VALID(%a5)
    clear_state FX_VALID, 12
    movem.l (%sp)+, %d0/%a0
    rts

update_play:
    bsr erase_beam
    bsr erase_effects
    bsr erase_bomb
    bsr erase_sword
    bsr erase_items
    bsr erase_enemies
    bsr erase_projectiles
    bsr erase_sprite
    bsr menu_check_open
    tst.b OFF_GAME_MODE(%a5)
    bne 4f                   | the inventory screen is up
    bsr sword_input
    bsr b_item_input
    bsr link_update
    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 3f
    bsr dbl_end
    cmp.b #MODE_SCROLL, %d0
    beq update_scroll       | a room transition started this frame
    rts                      | cave entry already redrew the new background
4:  rts
3:
    bsr update_enemies
    bsr update_combat
    bsr update_projectiles
    bsr draw_items
    bsr draw_bomb
    bsr draw_enemies
    bsr draw_projectiles
    bsr draw_link_blink
    bsr draw_beam
    bsr draw_effects
    bsr draw_sword
    bra present_frame


    .include "video.s"
    .include "sprite.s"
    .include "ai.s"
    .include "enemy.s"
    .include "combat.s"
    .include "link.s"
    .include "uw.s"
    .include "hud.s"
    .include "menu.s"
    .include "input.s"
    .include "music.s"

| ---------------------------------------------------------------------------
    .section .rodata
    .align 2
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
mon_sprites:
    .incbin "mon_sprites.bin"
item_sprites:
    .incbin "item_sprites.bin"
    .align 2
table_anchor:
    | Every table is reached from here by a signed 16-bit displacement, so the
    | anchor sits in the middle of them: the tables before it are about 32K
    | back and those after it have the other half to grow into.
hud_tiles:
    .incbin "hud_tiles.bin"
link_sprites:
    .incbin "link_sprites.bin"
enemy_sprites:
    .incbin "enemy_sprites.bin"
metatile_tiles:
    .incbin "metatile_tiles.bin"
    .align 2
sword_sprites:
    .incbin "sword_sprites.bin"
beam_sprites:
    .incbin "beam_sprites.bin"
fx_sprites:
    .incbin "fx_sprites.bin"
proj_sprites:
    .incbin "proj_sprites.bin"
hud_items:
    .incbin "hud_items.bin"
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
cave_map:
    .incbin "cave_map.bin"
cave_text:
    .incbin "cave_text.bin"
text_glyphs:
    .incbin "text_glyphs.bin"
    .align 2
cave_sprites:
    .incbin "cave_sprites.bin"
metatiles:
    .incbin "metatiles.bin"
| room_maps is by far the largest table, so it goes last: every label above it
| has to stay inside the 68000's signed 16-bit PC-relative displacement.
room_maps:
    .incbin "room_maps.bin"
    .align 2
music_drums:
    .incbin "music_drum_table.bin"
    .align 2
music_bank:
    .incbin "music_bank.bin"

    .section .data
    .align 2
    | Lets the test harness locate the variable block in a RAM dump.
globals_marker:
    .ascii "ZELDAST1"
globals:
    .space GLOBALS_BYTES

    | The digidrum engine writes to itself, so it has to live in RAM.
    .align 2
ymdrum_code:
    .incbin "music_engine.bin"
music_old_vbl:
    .long 0
    | head, tail, then the ring the IKBD interrupt fills (see ikbd_isr)
ikbd_state:
    .space 258

    | The stack lives in .data rather than after .rodata because _start reaches
    | it with a PC-relative lea, which the 68000 limits to a signed 16-bit
    | displacement. .data is emitted before the big tables, so it stays in range.
    .align 2
stack_bottom:
    .space STACK_BYTES
stack_top:
