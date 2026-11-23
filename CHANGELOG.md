# Changelog

What changed between versions of the Atari ST port, for players. The author sets the
version numbers; the newest is at the top.

## 1.04

From krs's second report (the 1.02 beta at 60 Hz on his 1040 STFM). Not yet tried on real
hardware.

- A like-like that has swallowed Link no longer keeps taking a heart from him every
  moment. On the NES it bites once and then waits while he hacks his way out; on the ST
  it went on biting, which with the wooden sword meant certain death.
- Link is no longer invisible at the top of the screen after scrolling down: the part of
  him inside the play area is drawn.
- Link carries his shield when facing down, and the magic shield shows from the front and
  the side, as on the NES.
- A dungeon shutter Link walks in through stands open until he is in the room and then
  shuts behind him. In a room already cleared it shuts and opens again, as the NES does.
- A pushed block slides without jumping back to where it started for a moment, and Link
  stays behind it instead of walking into it.
- The key a skeleton carries no longer lies on its own spot before the skeleton appears:
  it is on the skeleton's puff of smoke.
- Hitting a monster without killing it makes the "hit" sound.
- Dying in a room and continuing no longer leaves that room's last monsters missing.
- A zol hit after the boomerang stunned it runs from the blow at once.
- The bomb icon on the status bar is blue, as on the NES.
- The last pause of the story, before the title comes back, is as long as on the European
  NES (2.4 seconds instead of 1.1; the American cartridge has the short one). The intro
  now takes as long as on the NES, so the title song plays the same stretch of its loop
  before it starts again.

As on the NES (not changed): Level 4's gels and like-likes never drop anything; a vire
with one of its keese killed stays away; an armos frozen by the clock cannot be hit;
the ladder does not work over the water at the white sword's screen.

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
