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
    .include "level_buffer.inc"
    .include "music_ids.inc"
    .include "globals.s"
    .if UW_ROOM_BYTES != 704
    .error "globals.s sizes the underworld map buffers as 704 bytes"
    .endif

| A6 holds table_anchor for the whole run. The read-only tables total more than
| a signed 16-bit displacement can reach, so a table is found as the anchor plus a 32-bit
| link-time distance (twelve cycles more than a lea with a 16-bit displacement, and no limit on how
| far from the anchor, or from each other, the tables may sit). The condition codes are untouched.
    .macro ltab sym, reg
    move.l #(\sym - table_anchor), \reg
    adda.l %a6, \reg
    .endm

| ivtab name, reg: the address of one of INTRO.DAT's tables (title, story, credits, file menu), which intro_data_load put in
| the variable block while the buffer holds that file.
    .macro ivtab name, reg
    movea.l (OFF_IVP + 4 * IV_\name)(%a5), \reg
    .endm

| lvtab name, reg: the address of the current dungeon's table (room_index, rooms, doors, tiles, tile_nes,
| room_info, cellar_maps or cellar_info), which uw_select_level put in the variable block.
    .macro lvtab name, reg
    movea.l OFF_UWP_\name(%a5), \reg
    .endm

| Sound: sfx plays an effect over the music, jingle an event song that replaces it
| (music.s). Neither disturbs any register.
    .macro sfx id
    move.l %d0, -(%sp)
    moveq #\id, %d0
    bsr music_play_far
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
| room, and the room being scrolled in. The first is the screen TOS gave the
| program (Physbase), so only two are asked for, in one block with the level
| buffer behind them (loader.s).
    .equ BUFFER_COUNT, 3
    .equ BUFFER_ALLOC, ((BUFFER_COUNT - 1) * SCREEN_BYTES + 256 + LEVEL_BUF_BYTES)
    .equ XBIOS_PHYSBASE, 2
    .if (OFF_BG_CUR != OFF_SCREEN_PTR + 4) + (OFF_BG_NEXT != OFF_SCREEN_PTR + 8)
    .error "init_buffers and the intro read SCREEN_PTR, BG_CUR and BG_NEXT as three longs in a row"
    .endif

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
    .equ MODE_INTRO, 4              | the title, the story and the parade of the treasures (intro.s)
    .equ MODE_DEATH, 5              | Link's death, from the red world to GAME OVER (death.s)
    .equ MODE_QUIT, 6               | Esc: "quit without saving / save and quit / back to game" over the room (quit.s)

| PlayerScreenEdgeBounds (Z_07.asm): Link leaves the overworld screen when he
| reaches these coordinates. ObjectRoomBoundsOW is for other objects, not Link.
    .equ LINK_EDGE_LEFT, 0x00
    .equ LINK_EDGE_RIGHT, 0xf0
    .equ LINK_EDGE_UP, 0x3d
    .equ LINK_EDGE_DOWN, 0xdd

    .equ MAX_ENEMIES, 11
    | The per-monster arrays of globals.s are MAX_ENEMIES long and lie side by side: a few routines reach the next one
    | by adding the stride to a base (ENEMY_TURN -> ENEMY_WANT -> ENEMY_SHOOT).
    .equ ENEMY_STRIDE, MAX_ENEMIES
    .if (OFF_ENEMY_Y - OFF_ENEMY_X != MAX_ENEMIES) + (OFF_ENEMY_WANT - OFF_ENEMY_TURN != ENEMY_STRIDE) + (OFF_ENEMY_SHOOT - OFF_ENEMY_WANT != ENEMY_STRIDE) + (OFF_ENEMY_ERASE_OFFSETS + MAX_ENEMIES * 4 != OFF_ITEM_ERASE_OFFSETS)
    .error "globals.s sizes the per-monster arrays for another MAX_ENEMIES"
    .endif
    | Monsters that walk in from the edge of a screen (the overworld screens whose attribute F has bit 3). The ROM lets the
    | first one in at once, the next 20 to 50 frames after it (2 to 5 tenths of a second) and keeps them only $22 away from
    | Link, which on the first screens next to the start puts them on top of him. These are the gentler values asked for:
    | a wait before the first, 40 to 70 frames between them, a retry in 10 frames when the square is too close, and a
    | wider berth (the ROM's numbers are 0, 2 + rand & 3, 2 + rand & 3 and $22).
    .equ EDGE_FIRST_TICKS, 3
    .equ EDGE_GAP_TICKS, 4
    .equ EDGE_RETRY_TICKS, 1
    .equ EDGE_SAFE_DIST, 0x48
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

| Where Link starts: the ROM's, X $78 (InitMode3_Sub8) and the level's StartY ($8D on the overworld), facing up.
    .equ HOME_X, START_X
    .equ HOME_Y, START_Y

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
    .equ MFP_IPRB, 0x00fffa0d
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

    | The image starts with .data (variables and stack, see link.ld), then the code, so the first
    | instruction is this jump over them.
    .section .text.boot, "ax"
    .globl _start
_start:
    bra.w game_start

    .section .text
game_start:
    lea globals(%pc), %a5
    | The table anchor is set up by a routine at the very end of the code (init_anchor),
    | which is the only place close enough to the tables for a PC-relative lea.
    bsr init_anchor_far
    | Clear the variable block before anything is stored in it; bsr leaves the
    | stack alone, so the basepage is still at 4(sp) afterwards.
    bsr init_state
    bsr init_pointers

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
    .if DEV_SKIP_INTRO
    bsr begin_game
    .else
    bsr intro_start_far
    .endif
    bra main_loop

| Everything that sets the game up once the title is over (or at once, in a development build).
begin_game:
    clr.b OFF_SWORD_LOCK(%a5)           | UpdateMode1Menu_Sub1: a chosen slot starts with SwordBlocked 0
    .if DEV_SKIP_INTRO
    moveq #DEV_QUEST, %d0               | a development build has no profile: its quest is a build setting
    bsr quest_apply_mid
    .endif
    .if DEV_START_UW != 255
    | Development shortcut: start inside the level, with a sword and a key.
    moveq #DEV_START_LEVEL, %d0
    bsr uw_select_level_mid
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
    .if DEV_AUTOPLAY
    move.b #UW_BOUND_DOWN, OFF_LINK_Y(%a5)   | the audit's player comes in at the bottom door (where the port puts Link after a door), as in the ROM
    .endif
    move.b #1, OFF_HAS_SWORD(%a5)
    move.b #DEV_START_ENTRANCE, OFF_CAVE_SOURCE_ROOM(%a5)   | the level's entrance, where leaving comes out
    .endif
    bsr enter_room
    .if DEV_START_CAVE
    bsr start_cave_entry_far            | development shortcut: start inside the cave behind the start screen
    .endif
    bsr draw_hud_far
    rts

    | init_anchor itself is the last routine of the code (just before the read-only tables, see below); game_start
    | reaches it through this trampoline, a 32-bit jump that touches no register. These three sit in front of the
    | modules because game_start's 16-bit branches could not reach them past the modules any more.
init_anchor_far:
    pea 1f(%pc)
1:  addi.l #(init_anchor - 1b), (%sp)
    rts

    | The monster pictures are the last table, past what the anchor can address, so they are found
    | through a pointer: the anchor plus a link-time distance.
init_pointers:
    movea.l %a6, %a0
    adda.l #(mon_sprites - table_anchor), %a0
    move.l %a0, OFF_MON_SPR_OW(%a5)
    move.l %a0, OFF_MON_SPR(%a5)
    rts

uw_select_level_mid:                    | the dev start's other call, the same
    pea 1f(%pc)
1:  addi.l #(uw_select_level - 1b), (%sp)
    rts

quest_apply_mid:                        | the dev start's call (a 32-bit stub: begin_game is far from the stubs in the middle)
    pea 1f(%pc)
1:  addi.l #(quest_apply - 1b), (%sp)
    rts

main_loop:
    bsr wait_vbl
    btst #1, 0xffff820a         | sync mode bit: set for 50 Hz
    bne.s 7f
    addq.b #1, OFF_HOLD_SKIP(%a5)
    cmp.b #6, OFF_HOLD_SKIP(%a5)
    blo.s 7f
    clr.b OFF_HOLD_SKIP(%a5)
    move.l FR_CLOCK, OFF_LAST_CLOCK(%a5)    | a held VBL is not a late frame
    bra main_loop               | 60 Hz plays at the speed of 50: one update in six is left out, like the music's tick
7:
    bsr frame_begin
    bsr palette_sync
    bsr poll_keyboard
    bsr debug_keys_far
    .if DEV_AUTOPLAY
    bsr autoplay_far
    .endif
    bsr music_update
    tst.b OFF_EXIT_REQUESTED(%a5)
    beq.s 71f
    move.b OFF_GAME_MODE(%a5), %d0              | Esc asks inside a game (menu_check_open); the title, the story and the
    subq.b #MODE_INTRO, %d0                     | death have nothing to save and quit at once
    cmp.b #2, %d0                               | (MODE_INTRO and MODE_DEATH follow each other)
    blo exit_program
71:    addq.w #1, OFF_FRAME_COUNTER(%a5)
    bsr catch_up

    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 1f
    cmp.b #MODE_SCROLL, %d0
    beq 2f
    cmp.b #MODE_MENU, %d0
    beq 4f
    cmp.b #MODE_INTRO, %d0
    beq 5f
    cmp.b #MODE_DEATH, %d0
    beq 6f
    cmp.b #MODE_QUIT, %d0
    beq 9f
    bsr update_cave_far
    bra 3f
4:  bsr update_menu_far
    bra 3f
5:  bsr update_intro_far
    bra main_loop
6:  bsr update_death_far
    bra main_loop
9:  bsr update_quit_far
    bra main_loop
1:  bsr update_play
    bra 3f
2:  bsr update_scroll_far
3:  bsr rupee_drip_far
    bsr minimap_tick_far
    tst.b OFF_HUD_DIRTY(%a5)
    beq 8f
    bsr draw_hud_far
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 8f
    bsr swap_screens            | the other buffer needs the new ribbon too
    bsr draw_hud_far
    bsr swap_screens
8:  tst.b OFF_DYING(%a5)
    beq main_loop
    bsr death_begin_far         | the frame in which Link died is on the screen; now it is his death's
    bra main_loop

| A frame that took two VBLs (a room full of monsters costs more than one) would run the game at half speed. The
| game runs its update once more without drawing anything, so the speed stays that of 60 Hz and only the picture
| is shown at 30 Hz. At most one pass: a long pause (a room being built) is not caught up.
| The two passes must see consecutive FRAME_COUNTER values: the late pass runs with the value main_loop has just
| made, and the counter moves on before the real pass. (It used to move first, so both passes saw the same value and,
| while every frame was late, the counter only ever had one parity: a monster that steps "every other frame" then
| stepped on every pass or on none, the Aquamentus's fireballs fanned twice as fast or not at all. A sword beam
| triggers it: its DPCM sample takes enough time from the main loop to make each frame late.)
catch_up:
    movem.l %d0-%d1, -(%sp)
    move.l FR_CLOCK, %d0
    move.l OFF_LAST_CLOCK(%a5), %d1
    move.l %d0, OFF_LAST_CLOCK(%a5)
    sub.l %d1, %d0
    cmp.l #2, %d0
    blo 9f
    cmp.l #3, %d0
    bhi 9f
    tst.b OFF_GAME_MODE(%a5)
    bne 9f
    move.b #1, OFF_SKIP_DRAW(%a5)
    addq.w #1, OFF_LATE_FRAMES(%a5)
    bsr update_play
    clr.b OFF_SKIP_DRAW(%a5)
    addq.w #1, OFF_FRAME_COUNTER(%a5)   | the real pass is the next frame of the game
9:  movem.l (%sp)+, %d0-%d1
    rts

exit_program:
    bsr music_exit
    bsr restore_video
    bra terminate

no_memory:
    | Nothing has been reprogrammed yet: say how much memory it takes and has (loader.s, far away), which then ends the run.
    pea 1f(%pc)
1:  addi.l #(no_memory_report - 1b), (%sp)
    rts
terminate:
    move.l OFF_OLD_SSP(%a5), -(%sp)
    move.w #GEMDOS_SUPER, -(%sp)
    trap #1
    addq.l #6, %sp

    move.w #GEMDOS_PTERM0, -(%sp)
    trap #1

| ---------------------------------------------------------------------------
    .if MODE_PLAY != 0
    .error "init_state leaves GAME_MODE as the clear made it"
    .endif
    .if (OFF_HEART_CONTAINERS & 1) + (OFF_OBJ_RIGHT & 1) + (OFF_BOUND_RIGHT & 1) + (OFF_LINK_X & 1)
    .error "init_state stores two bytes at a time: the pairs must start on even addresses"
    .endif
    .if (OFF_HP_HALVES - OFF_HEART_CONTAINERS != 1) + (OFF_OBJ_UP - OFF_OBJ_RIGHT != 1) + (OFF_BOUND_UP - OFF_BOUND_RIGHT != 1) + (OFF_LINK_Y - OFF_LINK_X != 1)
    .error "init_state stores two bytes at a time: the pairs must be next to each other"
    .endif
init_state:
    | Zero the whole variable block, then set what needs a non-zero start.
    lea globals(%pc), %a0
    move.w #(GLOBALS_BYTES - 1), %d7
    moveq #0, %d0
1:  move.b %d0, (%a0)+
    dbra %d7, 1b

    move.b #START_ROOM_ID, OFF_ROOM_ID(%a5)
    move.w #((HOME_X << 8) + HOME_Y), OFF_LINK_X(%a5)         | X, Y (next to each other, on an even address)
    move.b #START_DIR, OFF_LINK_DIR(%a5)
    | (MODE_PLAY is 0, which the clear above did)
    move.b #8, OFF_MAX_BOMBS(%a5)
    move.w #((3 << 8) + 6), OFF_HEART_CONTAINERS(%a5)       | heart containers, HP_HALVES (next to each other, on an even address)
    move.w #0xace1, OFF_RNG(%a5)
    move.b #ROOM_BOUND_LEFT, OFF_OBJ_LEFT(%a5)
    move.w #((ROOM_BOUND_RIGHT << 8) + ROOM_BOUND_UP), OFF_OBJ_RIGHT(%a5)       | right, up
    move.b #ROOM_BOUND_DOWN, OFF_OBJ_DOWN(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    move.b #LINK_EDGE_LEFT, OFF_BOUND_LEFT(%a5)
    move.w #((LINK_EDGE_RIGHT << 8) + LINK_EDGE_UP), OFF_BOUND_RIGHT(%a5)       | right, up
    move.b #LINK_EDGE_DOWN, OFF_BOUND_DOWN(%a5)
    rts

init_buffers:
    | The screen TOS has on show is the first buffer (the shifter is pointed back at it when the program ends).
    move.w #XBIOS_PHYSBASE, -(%sp)
    trap #14
    addq.l #2, %sp
    move.l %d0, OFF_SCREEN_PTR(%a5)

    move.l #BUFFER_ALLOC, -(%sp)
    move.w #GEMDOS_MALLOC, -(%sp)
    trap #1
    addq.l #6, %sp
    tst.l %d0
    beq no_memory

    | The shifter wants its base on a 256-byte boundary, and a screen is an
    | exact multiple of 256, so aligning once aligns both of ours.
    add.l #255, %d0
    and.l #0xffffff00, %d0
    move.l %d0, OFF_BG_CUR(%a5)
    add.l #SCREEN_BYTES, %d0
    move.l %d0, OFF_BG_NEXT(%a5)
    add.l #SCREEN_BYTES, %d0
    move.l %d0, OFF_LEVEL_BUF(%a5)      | behind the screens: the level buffer (loader.s)

    | SCREEN_PTR, BG_CUR and BG_NEXT are three longs in a row: keep them as the home of the three
    | buffers (the intro and the credits move them about and put them back), and make all three black.
    movem.l OFF_SCREEN_PTR(%a5), %d1-%d3
    movem.l %d1-%d3, OFF_HOME_SCREEN(%a5)
    lea OFF_SCREEN_PTR(%a5), %a1
    moveq #(BUFFER_COUNT - 1), %d6
2:  movea.l (%a1)+, %a0
    move.w #(SCREEN_LONGS - 1), %d7
    moveq #0, %d0
1:  move.l %d0, (%a0)+
    dbra %d7, 1b
    dbra %d6, 2b
    rts

| Render the current room into bg_cur and show it.
enter_room:
    clr.b OFF_COMMIT(%a5)
    clr.b OFF_ROOM_LIT(%a5)             | a room is dark when he comes in (if it is one)
    clr.b OFF_INV_CLOCK(%a5)            | the clock lasts until he leaves the screen (ResetPlayerState)
    moveq #0, %d0
    move.b OFF_ROOM_ID(%a5), %d0
    movea.l OFF_BG_CUR(%a5), %a1
    tst.b OFF_LEVEL(%a5)
    bne 1f
    bsr render_room
    bra 2f
1:  bsr uw_render_current_far
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
    bsr cave_setup_far
    bsr cave_redraw
    bsr cave_dress_far
    clr.b OFF_ERASE_VALID(%a5)
    bsr draw_link
    rts

| Draw the cave room with its bonfires; the person and the rupee tag are sprites (caves.s).
cave_redraw:
    movem.l %d0-%d2, -(%sp)
    movea.l OFF_BG_CUR(%a5), %a1
    bsr render_cave_room
    bsr show_background
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
    move.w OFF_CAVE_TEXT_IDXW(%a5), %d0
    moveq #0, %d4
    move.b 0(%a0, %d0.w), %d4
    addq.w #1, OFF_CAVE_TEXT_IDXW(%a5)
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
    bsr draw_hud_tile_far
    move.l OFF_SCREEN_PTR(%a5), -(%sp)  | and into the clean room, to survive Link's erasing
    move.l OFF_BG_CUR(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile_far
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
    tst.b OFF_DBL_ACTIVE(%a5)
    beq 21f
    move.l OFF_SCREEN_PTR(%a5), -(%sp)  | in a dungeon room the other buffer needs the letter too
    move.l OFF_BG_NEXT(%a5), OFF_SCREEN_PTR(%a5)
    bsr draw_hud_tile_far
    move.l (%sp)+, OFF_SCREEN_PTR(%a5)
21:
    tst.b OFF_CAVE_TEXT_PEACE(%a5)
    beq 22f
    cmp.w #0x24, %d3                    | the last words make no blip on a space
    beq 23f
22: sfx SFX_HEART                       | the text blip
23: addq.b #1, OFF_CAVE_TEXT_COL(%a5)
    move.b #CAVE_TEXT_DELAY, OFF_CAVE_TEXT_TIMER(%a5)
    tst.b OFF_CAVE_TEXT_PEACE(%a5)
    beq 24f
    move.b #8, OFF_CAVE_TEXT_TIMER(%a5) | UpdatePeaceTextbox: a letter every 8 frames
24: and.w #0xc0, %d4
    beq 9f
    tst.b OFF_CAVE_TEXT_PEACE(%a5)
    beq 25f
    cmp.w #0xc0, %d4
    beq 4f
    move.b #8, OFF_CAVE_TEXT_COL(%a5)   | PeaceTextboxCharAddrsLo: the second line starts at ($22E4), the third at ($2346)
    move.b #18, OFF_CAVE_TEXT_ROW(%a5)
    cmp.w #0x80, %d4
    beq 9f
    move.b #10, OFF_CAVE_TEXT_COL(%a5)
    move.b #21, OFF_CAVE_TEXT_ROW(%a5)
    bra 9f
25: move.b #CAVE_TEXT_COL0, OFF_CAVE_TEXT_COL(%a5)
    cmp.w #0x80, %d4
    bne 3f
    move.b #(CAVE_TEXT_ROW0 + 1), OFF_CAVE_TEXT_ROW(%a5)
    bra 9f
3:  cmp.w #0x40, %d4
    bne 4f
    move.b #(CAVE_TEXT_ROW0 + 2), OFF_CAVE_TEXT_ROW(%a5)
    bra 9f
4:  clr.b OFF_CAVE_TEXT_ON(%a5)     | the last line: he has finished
    clr.b OFF_CAVE_TEXT_PEACE(%a5)
9:  movem.l (%sp)+, %d0-%d4/%a0-%a1
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
    move.w #(\count - 1), %d0
1:  move.b (%a0), %d1
    move.b (%a1), (%a0)+
    move.b %d1, (%a1)+
    dbra %d0, 1b
    .endm

    .macro clear_state name, count
    lea OFF_\name(%a5), %a0
    move.w #(\count - 1), %d0
1:  clr.b (%a0)+
    dbra %d0, 1b
    .endm

| What the sprites erased this frame are is what was drawn two frames ago.
swap_erase_state:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    xchg_state ENEMY_ERASE_VALID, OLD_ENEMY_ERASE_VALID, MAX_ENEMIES
    xchg_state ENEMY_ERASE_OFFSETS, OLD_ENEMY_ERASE_OFFSETS, MAX_ENEMIES * 4
    xchg_state ENEMY_ERASE2_OFFSETS, OLD_ENEMY_ERASE2_OFFSETS, MAX_ENEMIES * 4
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
    xchg_state FX_VALID, OLD_FX_VALID, 36
    xchg_state FX_ERASE_OFFSETS, OLD_FX_ERASE_OFFSETS, 144
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rts

clear_old_erase_state:
    movem.l %d0/%a0, -(%sp)
    clear_state OLD_ENEMY_ERASE_VALID, MAX_ENEMIES
    clear_state OLD_PROJ_ERASE_VALID, 8
    clear_state OLD_ITEM_ERASE_VALID, 3
    clr.b OFF_OLD_SWORD_VALID(%a5)
    clr.b OFF_OLD_BOMB_VALID(%a5)
    clr.b OFF_OLD_ERASE_VALID(%a5)
    clr.b OFF_OLD_BEAM_VALID(%a5)
    clear_state OLD_FX_VALID, 36
    movem.l (%sp)+, %d0/%a0
    rts

clear_erase_state:
    movem.l %d0/%a0, -(%sp)
    bsr clear_old_erase_state
    clear_state ENEMY_ERASE_VALID, MAX_ENEMIES
    clear_state PROJ_ERASE_VALID, 8
    clear_state ITEM_ERASE_VALID, 3
    clr.b OFF_SWORD_VALID(%a5)
    clr.b OFF_BOMB_VALID(%a5)
    clr.b OFF_ERASE_VALID(%a5)
    clr.b OFF_BEAM_VALID(%a5)
    clear_state FX_VALID, 36
    movem.l (%sp)+, %d0/%a0
    rts

update_play:
    tst.b OFF_SKIP_DRAW(%a5)
    bne 5f                   | a catch-up pass: nothing is on the screen to take away
    bsr erase_beam
    bsr erase_effects
    bsr erase_bomb
    bsr erase_sword
    bsr erase_items
    bsr erase_enemies
    bsr erase_projectiles
    bsr erase_sprite
5:  bsr menu_check_open_far
    tst.b OFF_GAME_MODE(%a5)
    bne 4f                   | the inventory screen is up
    bsr sword_input
    bsr b_item_input
    bsr link_update
    moveq #0, %d0
    move.b OFF_GAME_MODE(%a5), %d0
    beq 3f
    bsr dbl_end
    tst.b OFF_SKIP_DRAW(%a5)
    bne 4f                   | a catch-up pass leaves the transition to the main loop
    cmp.b #MODE_SCROLL, %d0
    beq update_scroll_far   | a room transition started this frame
    rts                      | cave entry already redrew the new background
4:  rts
3:
    bsr uw_person_update_far
    bsr items_update
    bsr boss_misc_f
    bsr chase_target_update
    bsr update_enemies
    bsr room_item_follow
    bsr update_combat
    bsr update_projectiles
    tst.b OFF_SKIP_DRAW(%a5)
    beq 6f
    clr.b OFF_BP_COUNT(%a5)  | the pieces the bosses put in the pool are not drawn this time
    rts
6:  bsr draw_items
    bsr draw_bomb
    bsr draw_enemies
    bsr draw_projectiles
    bsr draw_link_blink
    bsr draw_beam
    bsr draw_effects
    bsr boss_draw_f                     | Gleeok's body and necks
    bsr draw_sword
    bra present_frame


    | input.s, music.s and video.s reach .data (in front of the code) by PC-relative displacements, so
    | they come first; the rest only uses a5 and may grow without limit but the 16-bit branches.
    .include "input.s"
    .include "music.s"
    .include "video.s"
    .include "sprite.s"
    .include "ai.s"
    .include "movers.s"
    .include "enemy.s"
    .include "combat.s"
    .include "items.s"
    .include "dmon.s"

    | The code has outgrown what one 16-bit branch spans, so the modules at the end reach main.s's frame routines
    | through these stubs in the middle.
clear_erase_state_far:
    bra clear_erase_state
enemy_init_special_far:
    bra enemy_init_special
show_background_far:
    bra show_background
draw_hud_far:
    bra draw_hud
update_menu_far:
    bra update_menu
minimap_tick_far:
    bra minimap_tick
music_play_far:
    bra music_play
uw_light_room_far:
    bra uw_light_room

enter_room_far:
    bra enter_room
intro_start_far:
    bra intro_start
swap_screens_far:
    bra swap_screens
present_frame_far:
    bra present_frame
set_video_base_far:
    bra set_video_base
music_event_far:
    bra music_event
music_stop_far:
    bra music_stop
cur_palette_far:
    bra cur_palette
update_intro_far:
    bra update_intro
dbl_end_far:
    bra dbl_end
draw_hud_tile_far:
    bra draw_hud_tile
draw_hud_tile_ptr_far:
    bra draw_hud_tile_ptr
menu_check_open_far:
    bra menu_check_open
cave_talk_far:
    bra cave_talk
debug_keys_far:
    bra debug_keys
    .if DEV_AUTOPLAY
autoplay_far:
    bra autoplay
    .endif
update_scroll_far:
    bra update_scroll
update_cave_far:
    bra update_cave
uw_render_current_far:
    bra uw_render_current
enter_cave_far:
    bra enter_cave
erase_cave_fires_far:
    bra erase_cave_fires
cave_setup_far:
    bra cave_setup
start_cave_entry_far:
    bra start_cave_entry
cave_dress_far:
    bra cave_dress
menu_check_open_cave_far:           | after start_cave_entry_far: the dev start's bsr to that one has 1 byte to spare
    bra menu_check_open_cave
erase_at_far:
    bra erase_at
draw_sprite_far:
    bra draw_sprite
sprite_offset_far:
    bra sprite_offset
cave_update_far:
    bra cave_update
cave_sprites_erase_far:
    bra cave_sprites_erase
cave_sprites_draw_far:
    bra cave_sprites_draw
cave_stairs_far:
    bra cave_stairs
rupee_drip_far:
    bra rupee_drip
draw_cave_fires_far:
    bra draw_cave_fires
ow_bomb_secret_far:
    bra ow_bomb_secret
ow_fire_secret_far:
    bra ow_fire_secret
ow_secret_undo_far:
    bra ow_secret_undo
render_room_far:
    bra render_room
ow_maze_far:
    bra ow_maze
owspec_room_start_far:
    bra owspec_room_start
owspec_update_far:
    bra owspec_update
ow_ladder_ok_far:
    bra ow_ladder_ok
ow_armos_touch_far:
    bra ow_armos_touch
owspec_recorder_far:
    bra owspec_recorder
goriya_ai_far:
    bra goriya_ai
owspec_init_far:
    bra owspec_init
uw_person_update_far:
    bra uw_person_update
    farstub quest_apply_far, quest_apply
    farstub update_death_far, update_death
    farstub death_begin_far, death_begin
    farstub update_quit_far, update_quit
    farstub restore_ikbd_far, restore_ikbd
draw_link_far:
    bra draw_link
erase_sprite_far:
    bra erase_sprite
blit_rect_far:
    bra blit_rect
enemy_shove_snap_far:                   | last, so that it moves none of the stubs the 16-bit reach of begin_game needs
    bra enemy_shove_snap
    farstub uw_spawn_begin_far, uw_spawn_begin
    farstub uw_remaining_far, uw_remaining

    .include "autoplay.s"           | (dev builds only) right behind the far stubs, where the 16-bit reach is
    .include "link.s"
    .include "uw.s"
    .include "secrets.s"
    .include "caves.s"
    .include "owspec.s"
    .include "hud.s"
    .include "menu.s"
    .include "bosses.s"
    .include "intro.s"
    .include "credits.s"
    .include "filesel.s"
    .include "death.s"
    .include "quit.s"
    .include "save.s"
    .include "exit.s"
    .include "loader.s"

    | The anchor is this address plus a 32-bit link-time distance (a PC-relative relocation), so the routine may sit
    | anywhere. (It used to sit in the middle of the code with a 16-bit `lea room_palette(%pc)`, which limited the
    | whole code to about 64 KB: the object file keeps that displacement in 16 bits.)
init_anchor:
    lea 1f(%pc), %a6
1:  adda.l #(table_anchor - 1b), %a6
    rts

| ---------------------------------------------------------------------------

    .section .rodata
    .align 2
uw_door_cells:
    .incbin "uw_door_cells.bin"
    .align 2
item_sprites:
    .incbin "item_sprites.bin"
    .align 2
hud_tiles:
    .incbin "hud_tiles.bin"
link_sprites:
    .incbin "link_sprites.bin"
metatile_tiles:
    .incbin "metatile_tiles.bin"
    .align 2
sword_sprites:
    .incbin "sword_sprites.bin"
beam_sprites:
    .incbin "beam_sprites.bin"
table_anchor:
    | Every table is reached from here by a signed 16-bit displacement, so the
    | anchor sits in the middle of them. tools/check_reach.py fails the build when a table
    | is out of reach (the assembler would not notice a table 32768 to 65535 bytes ahead).
fx_sprites:
    .incbin "fx_sprites.bin"
proj_sprites:
    .incbin "proj_sprites.bin"
hud_items:
    .incbin "hud_items.bin"
mon_table:
    .incbin "mon_table.bin"
mon_mask:
    .incbin "mon_mask.bin"
mon_cloud:
    .incbin "mon_cloud.bin"
    .align 2
mon_art:
    .incbin "mon_art.bin"
ow_room_info:
    .incbin "ow_room_info.bin"
room_secrets:
    .incbin "room_secrets.bin"
item_index:
    .incbin "item_index.bin"
drop_table:
    .incbin "drop_table.bin"
drop_rates:
    .incbin "drop_rates.bin"
cave_map:
    .incbin "cave_map.bin"
cave_text:
    .incbin "cave_text.bin"
text_glyphs:
    .incbin "text_glyphs.bin"
    .align 2
cave_sprites:
    .incbin "cave_sprites.bin"
    .align 2
cave_table:
    .incbin "cave_table.bin"
cave_shortcuts:
    .incbin "cave_shortcuts.bin"
    .align 2
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
    .align 2
mon_sprites:
    .incbin "mon_sprites.bin"
    | The title, the story, the credits and the file menu (tools/intro.py, tools/filesel.py) are not here: they are INTRO.DAT.
    | The inventory screen (tools/submenu.py).
    .align 2
menu_tiles:
    .incbin "menu_tiles.bin"
menu_cells:
    .incbin "menu_cells.bin"
menu_glyphs:
    .incbin "menu_glyphs.bin"
menu_sprites:
    .incbin "menu_sprites.bin"
    | Link's death (tools/gameover.py).
    .align 2
death_sprites:
    .incbin "death_sprites.bin"
death_maps:
    .incbin "death_maps.bin"
    | level_table (generated): each dungeon's start data and the name of its file. The tables themselves are read
    | from LEVEL<n>[Q].DAT into the level buffer by uw_select_level (loader.s) and reached through pointers.
    .align 2
    .include "levels.inc"

    .section .data
    .align 2
    | .data is the first thing in the image (link.ld), so code reaches it with PC-relative
    | displacements as long as it lies within 32 KB of it. The stack is only used by _start, so it
    | goes first; what the rest of the code touches by PC (ikbd_state, music_old_vbl, the digidrum
    | engine) goes after it, nearest to the code.
stack_bottom:
    .space STACK_BYTES
stack_top:
    .align 2
    | Lets the test harness locate the variable block in a RAM dump.
globals_marker:
    .ascii "ZELDAST1"
globals:
    .space GLOBALS_BYTES
    .align 2
music_old_vbl:
    .long 0
    | head, tail, then the ring the IKBD interrupt fills (see ikbd_isr)
ikbd_state:
    .space 258
    | The digidrum engine writes to itself, so it has to live in RAM.
    .align 2
ymdrum_code:
    .incbin "music_engine.bin"
