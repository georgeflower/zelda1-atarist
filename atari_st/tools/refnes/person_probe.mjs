// Which of Link's weapons set the old man's flames off in the ROM?  node person_probe.mjs LEVEL ROOM
// For each weapon: enter the room, wait for the man to finish speaking, put Link below him facing up, use the weapon and
// read PersonFireballsEnabled ($4CC) for a while.
import {newGame, BTN} from "./nes.mjs";
const [level, room] = [Number(process.argv[1 + 1]), Number(process.argv[1 + 2])];
const weapons = {
  sword:      {},
  boomerang:  {inv: {0x674: 1}, slot: 0x1D, b: true},
  bomb:       {inv: {0x658: 8, 0x67C: 8}, slot: 1, b: true, dy: 0x10},
  arrow:      {inv: {0x659: 1, 0x65A: 1, 0x66D: 50}, slot: 2, b: true},
  arrow3:     {inv: {0x659: 1, 0x65A: 1, 0x66D: 50}, slot: 3, b: true},
  candle:     {inv: {0x65B: 2}, slot: 4, b: true},
  rod:        {inv: {0x65F: 1}, slot: 8, b: true},
};
for (const [name, w] of Object.entries(weapons)) {
  const z = newGame(false);
  const wr = (a, v) => z.wr(a, v);
  wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
  z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
  wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
  for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) wr(0xEB, room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
  z.run(300);                                           // the man says his piece
  wr(0x657, 1);                                         // a sword
  for (const [a, v] of Object.entries(w.inv || {})) wr(Number(a), v);
  if (w.slot !== undefined) wr(0x656, w.slot);
  const personY = z.rd(0x85);
  wr(0x70, 0x78); wr(0x84, personY + 0x20 - (w.dy || 0)); wr(0x98, 8); wr(0x99, 8);   // Link below him, facing up (ObjDir)
  const before = z.rd(0x4CC);
  z.run(2);
  if (w.b) z.tap(BTN.B, 4); else z.tap(BTN.A, 4);
  let fired = 0; let shot = [];
  for (let f = 0; f < 150; f++) { z.run(1); if (f < 30) { const t = z.rd(0x34F + 0x12); if (t && !shot.length) shot.push(`weapon slot $12 type ${t.toString(16)} at frame ${f}`); } if (z.rd(0x4CC)) { fired = f; break; } }
  console.log(name.padEnd(10), "person type", z.rd(0x350).toString(16), "y", personY.toString(16), "fireballs", before, "->", z.rd(0x4CC), fired ? `after ${fired} frames` : "", shot.join(""));
}
