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

    .equ PKT_NONE, 0
    .equ PKT_JOY0, 1
    .equ PKT_JOY1, 2
    .equ PKT_SKIP2, 3
    .equ PKT_SKIP1, 4

poll_keyboard:
    movem.l %d0-%d1/%a0, -(%sp)
1:  movea.l #IKBD_ACIA_STATUS, %a0
    move.b (%a0), %d0
    btst #0, %d0
    beq 9f

    moveq #0, %d0
    movea.l #IKBD_ACIA_DATA, %a0
    move.b (%a0), %d0

    move.b OFF_IKBD_PKT(%a5), %d1
    beq 4f
    clr.b OFF_IKBD_PKT(%a5)
    cmp.b #PKT_JOY0, %d1
    bne 2f
    move.b %d0, OFF_JOY0(%a5)
    bra 1b
2:  cmp.b #PKT_JOY1, %d1
    bne 3f
    move.b %d0, OFF_JOY1(%a5)
    bra 1b
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
    bne 1b
    move.b #1, OFF_EXIT_REQUESTED(%a5)
    bra 1b

3:  andi.w #0x007f, %d0
    lea OFF_KEY_STATES(%a5), %a0
    clr.b 0(%a0, %d0.w)
    bra 1b

9:  movem.l (%sp)+, %d0-%d1/%a0
    rts
