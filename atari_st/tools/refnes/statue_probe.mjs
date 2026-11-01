// Statue fireballs and the free monster slots in the ROM.  node statue_probe.mjs LEVEL ROOM [FRAMES]
// Enters the room, then each frame notes how many of the monster slots 1..11 hold an object, which slot FindEmptyMonsterSlot
// would return (the highest free one) and when the statue timers ($4E..) tick.
import {newGame} from "./nes.mjs";
const [level, room, frames] = [Number(process.argv[2]), Number(process.argv[3]), Number(process.argv[4] || 1500)];
const z = newGame(false);
const wr = (a, v) => z.wr(a, v);
wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) wr(0xEB, room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
let maxOcc = 0, minHigh = 99, shots = 0, last = [];
for (let f = 0; f < frames; f++) {
  z.run(1);
  wr(0x66F, 0xff); wr(0x670, 0xff);                      // hearts (keeps Link alive; harmless if the addresses are something else)
  const occ = []; for (let s = 1; s <= 11; s++) if (z.rd(0x34F + s)) occ.push(s);
  const high = [1,2,3,4,5,6,7,8,9,10,11].filter(s => !occ.includes(s)).pop() || 0;
  maxOcc = Math.max(maxOcc, occ.length); if (high) minHigh = Math.min(minHigh, high);
  if (f % 100 === 0) console.log(f, "occupied", occ.map(s => s + ":" + z.rd(0x34F + s).toString(16)).join(" "), "highest free", high);
}
console.log("max occupied", maxOcc, "lowest 'highest free slot' seen", minHigh);
