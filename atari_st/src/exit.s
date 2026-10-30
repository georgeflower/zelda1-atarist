| Leaving the game: what has to be put back for the desktop that the other files do not already do.

| Hand the keyboard back to TOS. The vector alone is not enough on a real machine: both ACIAs share one interrupt
| line to the MFP, which only notices it going low, so a byte left in either one (a key or mouse byte that came in
| as the game quit, a MIDI byte) keeps the line low and TOS would never be interrupted again: the desktop comes
| back with a dead keyboard and mouse. So the interrupt is masked while the vector changes, both ACIAs are emptied,
| a pending or in-service mark of the interrupt is cleared and only then is it unmasked. The mouse is put back in
| relative mode, which is what TOS has (the game only switched the joysticks to events, which is TOS' own
| default too).
restore_ikbd:
    move.w %sr, %d0
    ori.w #0x0700, %sr
    bclr #6, MFP_IMRB
    move.l OFF_OLD_IKBD_VEC(%a5), IKBD_VECTOR
    movea.l #IKBD_ACIA_STATUS, %a0
    move.w #255, %d1
1:  btst #0, (%a0)
    beq 2f
    tst.b 2(%a0)
    dbra %d1, 1b
2:  movea.l #MIDI_ACIA_STATUS, %a0
    move.w #255, %d1
3:  btst #0, (%a0)
    beq 4f
    tst.b 2(%a0)
    dbra %d1, 3b
4:  movea.l #IKBD_ACIA_STATUS, %a0
    move.w #0x7fff, %d1
5:  btst #1, (%a0)                  | the transmitter is ready
    dbne %d1, 5b
    move.b #0x08, 2(%a0)            | the mouse reports its moves again
    move.b #0xbf, MFP_IPRB          | a zero clears a mark, a one leaves it: only the keyboard's goes
    move.b #0xbf, MFP_ISRB
    bset #6, MFP_IMRB
    move.w %d0, %sr
    rts
