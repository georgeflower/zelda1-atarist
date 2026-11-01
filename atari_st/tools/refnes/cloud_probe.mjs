// How long do dungeon monsters stay in their spawn cloud in the ROM?  node cloud_probe.mjs LEVEL ROOM [QUEST]
// Prints, per frame after the room opens, each monster slot's type, metastate ($405+slot) and x,y.
import {newGame} from "./nes.mjs";
const [level, room, quest] = [Number(process.argv[2]), Number(process.argv[3]), Number(process.argv[4] || 1)];
const z = newGame(quest);
const wr = (a, v) => z.wr(a, v);
wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) wr(0xEB, room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
for (let f = 0; f < 80; f++) {
  const row = [];
  for (let s = 1; s <= 11; s++) { const t = z.rd(0x34F + s); if (t) row.push(`${s}:t${t.toString(16)} m${z.rd(0x405 + s).toString(16)} ${z.rd(0x70 + s)},${z.rd(0x84 + s)}`); }
  console.log(f, row.join(" | "));
  z.run(1);
}
