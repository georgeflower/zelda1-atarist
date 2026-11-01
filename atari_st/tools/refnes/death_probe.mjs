// How long does a monster's death spark last in the ROM?  node death_probe.mjs LEVEL ROOM [SLOT] [QUEST]
// Waits until the room's monsters are out of their clouds, then sets metastate $10 on one of them, which is all
// UpdateDeadDummy does, and prints per frame its type and metastate ($405+slot) until it is gone.
import {newGame} from "./nes.mjs";
const [level, room, slot, quest] = [Number(process.argv[2]), Number(process.argv[3]), Number(process.argv[4] || 1), Number(process.argv[5] || 1)];
const z = newGame(quest);
const wr = (a, v) => z.wr(a, v);
wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) wr(0xEB, room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
z.run(150);
console.log("type", z.rd(0x34F + slot).toString(16), "metastate", z.rd(0x405 + slot));
wr(0x405 + slot, 0x10);
let last = "";
for (let f = 0; f < 60; f++) {
  const now = `t${z.rd(0x34F + slot).toString(16)} m${z.rd(0x405 + slot).toString(16)}`;
  if (now !== last) { console.log(f, now); last = now; }
  z.run(1);
}
