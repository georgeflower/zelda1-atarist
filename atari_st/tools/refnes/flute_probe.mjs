// The recorder in the ROM: node flute_probe.mjs ROOM DIR [BLOWS] [TRIFORCE_MASK] [QUEST] -- Link put in an overworld room, the flute blown BLOWS times.
import {newGame, BTN} from "./nes.mjs";
const [room, dir = "DOWN", blows = 3, mask = 0xff, quest = 1] = process.argv.slice(2);
const z = newGame(+quest === 2);
z.wr(0x10, 0); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 900); z.run(30);
z.wr(0x6BAD, +room); z.wr(0xEB, +room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, +room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
z.run(60);
console.log("in", z.state());
z.wr(0x65C, 1); z.wr(0x656, 5); z.wr(0x671, +mask);
z.wr(0x98, {UP: 8, DOWN: 4, LEFT: 2, RIGHT: 1}[dir]);
const snap = () => `tele=${z.rd(0x523)} state=${z.rd(0x522)} summoned=${z.rd(0x508)} cycle=${z.rd(0x51A)} timer=${z.rd(0x3C)} room=${z.rd(0xEB).toString(16)} types=${[1,2,3,4,5,6,7,8,9].map(i => z.rd(0x34 + i).toString(16)).join(",")} link=${z.rd(0x70)},${z.rd(0x84)} mode=${z.rd(0x12)}`;
for (let b = 0; b < +blows; b++) {
  z.wr(0x98, {UP: 8, DOWN: 4, LEFT: 2, RIGHT: 1}[dir]);
  z.hold(BTN.B, 2);
  for (let f = 0; f < 5; f++) z.run(1);
  console.log("blow", b + 1, "immediately:", snap());
  z.run(200);
  console.log("   200 frames later:", snap());
}
