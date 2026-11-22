# Changelog

What changed between versions of the Atari ST port, for players. The author sets the
version numbers; the newest is at the top.

## 1.03

- The item box on the status bar is as wide as the sword box: its lines stand as far apart
  as the ones under CTRL, centred under the word SPACE.
- In a dungeon, Link goes in under the outer wall when he walks out through a doorway.
  Before, he was drawn on top of the bricks.

## 1.02

Mostly from players' reports: two comments on Reddit, and krs's test of the beta at 60 Hz
on a 1040 STFM. The fixes in the second list have not yet been tried on real hardware.

### Controls and screens

- Either Shift swings the sword, as well as Control and the joystick button. The sword
  and an item can now be used with one hand on the keyboard (W A S D, Shift and Space).
- The status bar names the ST's keys instead of the NES's buttons: SPACE over the item
  box and FIRE, CTRL or SHFT (whichever you pressed last) over the sword box.
- A How to play page lists the keys. The Help key opens it, and a newly registered
  character sees it once before the first screen.
- The Esc page lists the keys above the quit question.
- The inventory screen says USE SPACE FOR THIS instead of USE B BUTTON.
- CONTROLS.TXT, the keys as plain text, is on the disk and in `make dist`.

### Fixes

- Link is knocked back the moment he is hit. Before, he stayed put until you walked again,
  sometimes straight into another monster.
- The title music no longer drifts out of step with the pictures when the intro is left
  running. It starts again each time the intro comes back to the title, as on the NES.
- Zols split as they do on the NES. A blow along their path sends them running until
  they hit something, and the two gels come out of a puff of smoke and slide apart.
  Walls stop the slide. Before, both landed on the square below at once, often on Link.
- The outline of the Triforce on the inventory screen has no gaps.
- How to play no longer appears on every load of a game saved before the first sword.
- Link no longer vanishes when he stands on the rupees in the money making game. Caves
  are now drawn off-screen first, as the rest of the game is.
- The room number (the T key) has moved under LEVEL-n, so it no longer runs into SHFT.
- A desk accessory's screen saver (XCONTROL's, for one) can no longer black out the
  game in the middle of play, or leave the game's colours on the desktop afterwards.
  The game switches off the accessories' per-frame routines while it runs and gives
  them back when you quit.

### Building

- The NTSC build (`NTSC=1`) switches a PAL ST to 60 Hz while the game runs and back
  again on the way out.
- The Makefile finds Arch Linux's `m68k-elf-` binutils as well as Debian's and Ubuntu's
  `m68k-linux-gnu-`.
- `make dist NTSC=1` on its own builds everything. `make dist` or `make disk` without
  `NTSC=1` after an NTSC build now warns that it is about to rebuild the PAL version.

### As on the NES (not changed)

- An armos statue hurts Link while it is waking up.
- A zol's gels end up one row lower than where it split, sometimes inside a block.
