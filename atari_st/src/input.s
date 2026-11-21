| IKBD input: keys and the joystick.
|
| TOS' own handler is masked off in init_video, so the bytes are read straight
| from the ACIA. Most are scan codes, tracked in a key-state table the game
| logic samples. The IKBD also reports joystick events as a header byte ($FE
| for port 0, $FF for port 1) and a state byte (bits 0-3 up, down, left,
| right; bit 7 fire), and mouse movement as a $F8-$FB header and two more
| bytes; those must not be mistaken for scan codes.

    .equ SCAN_ESC, 0x01
    .equ SCAN_W, 0x11
    .equ SCAN_A, 0x1e
    .equ SCAN_S, 0x1f
    .equ SCAN_D, 0x20
    .equ SCAN_UP, 0x48
    .equ SCAN_LEFT, 0x4b
    .equ SCAN_RIGHT, 0x4d
    .equ SCAN_DOWN, 0x50
    .equ SCAN_RELEASE_BIT, 0x80
    .equ SCAN_CONTROL, 0x1d
    .equ SCAN_LSHIFT, 0x2a
    .equ SCAN_RSHIFT, 0x36
    .equ SCAN_HELP, 0x62

    .equ PKT_NONE, 0
    .equ PKT_JOY0, 1
    .equ PKT_JOY1, 2
    .equ PKT_SKIP2, 3
    .equ PKT_SKIP1, 4

poll_keyboard:
    movem.l %d0-%d2/%a0-%a1, -(%sp)
    lea ikbd_state(%pc), %a1
1:  moveq #0, %d2
    move.b 1(%a1), %d2          | tail: the next byte the interrupt left for us
    cmp.b (%a1), %d2
    beq 9f
    moveq #0, %d0
    move.b 2(%a1, %d2.w), %d0
    addq.b #1, %d2
    move.b %d2, 1(%a1)

    move.b OFF_IKBD_PKT(%a5), %d1
    beq 4f
    clr.b OFF_IKBD_PKT(%a5)
    cmp.b #PKT_JOY0, %d1
    bne 2f
    bra 1b                      | port 0 is the mouse port: moving the mouse would walk Link (and its button swing the sword)
2:  cmp.b #PKT_JOY1, %d1
    bne 3f
    move.b %d0, OFF_JOY1(%a5)
    bpl 1b                      | (bit 7: the fire button, which names the A box FIRE)
    moveq #0, %d1
    bra 10f
3:  cmp.b #PKT_SKIP2, %d1
    bne 1b
    move.b #PKT_SKIP1, OFF_IKBD_PKT(%a5)
    bra 1b

4:  cmp.b #0xff, %d0
    bne 5f
    move.b #PKT_JOY1, OFF_IKBD_PKT(%a5)
    bra 1b
5:  cmp.b #0xfe, %d0
    bne 6f
    move.b #PKT_JOY0, OFF_IKBD_PKT(%a5)
    bra 1b
6:  cmp.b #0xf8, %d0
    blo 7f
    cmp.b #0xfb, %d0
    bhi 7f
    move.b #PKT_SKIP2, OFF_IKBD_PKT(%a5)
    bra 1b

7:  cmpi.b #SCAN_RELEASE_BIT, %d0
    bcc 3f

    lea OFF_KEY_STATES(%a5), %a0
    move.b #1, 0(%a0, %d0.w)
    cmpi.b #SCAN_ESC, %d0
    bne 11f
    move.b #1, OFF_EXIT_REQUESTED(%a5)
    bra 1b
11: cmpi.b #SCAN_HELP, %d0
    bne 12f
    move.b #1, OFF_HELP_REQUESTED(%a5)
    bra 1b
12: moveq #1, %d1               | Control: the A box says CTRL
    cmpi.b #SCAN_CONTROL, %d0
    bne 13f
    move.b %d1, OFF_CTRL_RAW(%a5)
    bra 10f
13: moveq #2, %d1               | either Shift: SHFT, and Control's byte as well (Shift swings the sword as Control does)
    cmpi.b #SCAN_LSHIFT, %d0
    beq 14f
    cmpi.b #SCAN_RSHIFT, %d0
    bne 1b
14: move.b #1, SCAN_CONTROL(%a0)
10: cmp.b OFF_FIRE_LAST(%a5), %d1
    beq 1b
    move.b %d1, OFF_FIRE_LAST(%a5)
    move.b #1, OFF_HUD_DIRTY(%a5)
    bra 1b

3:  andi.w #0x007f, %d0
    lea OFF_KEY_STATES(%a5), %a0
    clr.b 0(%a0, %d0.w)
    cmpi.b #SCAN_CONTROL, %d0
    bne 15f
    clr.b OFF_CTRL_RAW(%a5)
    bra 16f
15: cmpi.b #SCAN_LSHIFT, %d0
    beq 16f
    cmpi.b #SCAN_RSHIFT, %d0
    bne 1b
16: move.b OFF_CTRL_RAW(%a5), %d0  | Control's byte stays down while any of the three is
    or.b SCAN_LSHIFT(%a0), %d0
    or.b SCAN_RSHIFT(%a0), %d0
    move.b %d0, SCAN_CONTROL(%a0)
    bra 1b

9:  movem.l (%sp)+, %d0-%d2/%a0-%a1
    rts

| The IKBD interrupt. The ACIA holds a single byte, and the game only looks at
| it once a frame, so two keys changing within a frame lost a byte -- a missed
| key release left Link walking by himself. Every byte is queued here instead,
| in a 256-byte ring: ikbd_state holds the head, the tail, then the ring.
ikbd_isr:
    movem.l %d0-%d1/%a0, -(%sp)
    lea ikbd_state(%pc), %a0
1:  move.b IKBD_ACIA_STATUS, %d0
    btst #0, %d0
    beq 3f
    move.b IKBD_ACIA_DATA, %d0
    moveq #0, %d1
    move.b (%a0), %d1
    move.b %d0, 2(%a0, %d1.w)
    addq.b #1, %d1
    move.b %d1, (%a0)
    bra 1b
3:  btst #0, MIDI_ACIA_STATUS   | the MIDI port shares the interrupt: empty it too
    beq 4f
    tst.b MIDI_ACIA_DATA
4:  bclr #6, MFP_ISRB
    movem.l (%sp)+, %d0-%d1/%a0
    rte
