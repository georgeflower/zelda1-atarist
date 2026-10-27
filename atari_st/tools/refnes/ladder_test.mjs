// How far does the ROM let Link walk over a moat with the ladder? Level N, room R, Link put at X,Y, one direction held.
//   node ladder_test.mjs LEVEL ROOM X Y DIR [FRAMES]
import {newGame, BTN} from "./nes.mjs";
const [level, room, x, y, dir, frames = 300] = process.argv.slice(2);
const z = newGame(false);
z.wr(0x10, +level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
z.wr(0x6B7E + 47, +room); z.wr(0xEB, +room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, +room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
z.run(60);
z.wr(0x663, 1);                      // the ladder
z.wr(0x4F0, 0xF0);
const row = (r) => { let s = ""; for (let c = 0; c < 32; c++) s += z.rd(0x6530 + c * 22 + r) === 0xF4 ? "~" : "."; return s; };
for (let r = 0; r < 22; r++) console.log(row(r));
z.wr(0x70, +x); z.wr(0x84, +y); z.wr(0x98, {UP: 8, DOWN: 4, LEFT: 2, RIGHT: 1}[dir]);
z.nes.buttonDown(1, BTN[dir]);
let last = "";
for (let f = 0; f < +frames; f++) {
  z.wr(0x4F0, 0xF0); z.run(1);
  const sl = z.rd(0x64), s = `${z.rd(0x70)},${z.rd(0x84)} slot=${sl}${sl ? " ladder@" + z.rd(0x70 + sl) + "," + z.rd(0x84 + sl) + " st=" + z.rd(0xAC + sl) : ""}`;
  if (s !== last && f % 4 === 0) { console.log(f, s); last = s; }
}
