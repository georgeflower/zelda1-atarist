// Where do the two gels of a split zol go in the ROM?  node zol_split_probe.mjs LEVEL ROOM [QUEST]
// Enters the room, finds a zol, waits until it stands on its lane, then puts it in state 2 (UpdateZolState2_Split, what a
// blow that did not kill it leads to when it is not shoved along its way) and prints the zol and both gels for 40 frames.
import {newGame} from "./nes.mjs";
const [level, room, quest] = [Number(process.argv[2]), Number(process.argv[3]), Number(process.argv[4] || 0)];
const z = newGame(quest);
const wr = (a, v) => z.wr(a, v), rd = (a) => z.rd(a);
wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
z.runUntil(() => rd(0x12) === 5 && rd(0x11) === 1, 600); z.run(30);
wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (rd(0x12) === 3 && rd(0x11)) wr(0xEB, room); if (rd(0x12) === 5 && rd(0x11)) break; }
z.run(150);
const hex = (v) => v.toString(16).padStart(2, "0");
const slots = () => [...Array(12).keys()].slice(1).map((s) => `${s}:t${hex(rd(0x34F + s))}`).join(" ");
console.log("level", rd(0x10), "room", hex(rd(0xEB)), "objects", slots());
let zol = -1;
for (let s = 1; s < 12; s++) if (rd(0x34F + s) === 0x13 || rd(0x34F + s) === 0x12) { zol = s; break; }
if (zol < 0) { console.log("no zol"); process.exit(0); }
wr(0x70, 0x20); wr(0x84, 0xDD);                    // Link out of the way, bottom left
for (let i = 0; i < 400; i++) { z.run(1); if ((rd(0x84 + zol) & 15) === 13 && (rd(0x70 + zol) & 15) === 0) break; }
console.log(`zol slot ${zol} at x${hex(rd(0x70 + zol))} y${hex(rd(0x84 + zol))} dir ${rd(0x98 + zol)}`);
wr(0xAC + zol, 2);
for (let f = 0; f < 60; f++) {
  z.run(1);
  const out = [];
  for (let s = 1; s < 12; s++) { const t = rd(0x34F + s); if (t === 0x14) out.push(`gel${s} x${hex(rd(0x70 + s))} y${hex(rd(0x84 + s))} d${rd(0x98 + s)} st${rd(0xAC + s)} m${hex(rd(0x405 + s))}`); }
  if (f >= 18 && f < 40 || f % 10 === 0) console.log(f, out.join("  "));
}
