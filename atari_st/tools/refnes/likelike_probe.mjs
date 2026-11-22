// A like-like that has Link, and Link mashing the sword (wooden). node likelike_probe.mjs [GAP]
// Enters Level 4 room $32, leaves only the like-like, puts it on Link so it takes him, then presses A every GAP frames and
// prints the like-like's HP and Link's hearts every 50 frames, to compare with the port.
import {newGame, BTN} from "./nes.mjs";
const gap = Number(process.argv[2] || 14);
const z = newGame(0);
const wr = (a, v) => z.wr(a, v), rd = a => z.rd(a);
const level = 4, room = 0x32;
wr(0x10, level); wr(0x12, 2); wr(0x13, 0); wr(0x11, 0);
z.runUntil(() => rd(0x12) === 5 && rd(0x11) === 1, 600); z.run(30);
wr(0x6B7E + 47, room); wr(0xEB, room); wr(0x12, 3); wr(0x13, 0); wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (rd(0x12) === 3 && rd(0x11)) wr(0xEB, room); if (rd(0x12) === 5 && rd(0x11)) break; }
z.run(120);
wr(0x657, 1);                               // wooden sword
wr(0x66F, 0x77); wr(0x670, 0xff);           // eight hearts, all full
let ll = -1;
for (let s = 1; s <= 11; s++) { if (rd(0x34F + s) === 0x17 && ll < 0) ll = s; else if (rd(0x34F + s)) wr(0x34F + s, 0); }
console.log("like-like slot", ll, "hp", rd(0x485 + ll).toString(16));
wr(0x70 + ll, rd(0x70)); wr(0x84 + ll, rd(0x84));
for (let f = 0; f < 800; f += gap) {
  z.hold(BTN.A, 2); z.run(gap - 2);
  if ((f / gap | 0) % 4 === 0)
    console.log(f, "ll hp", rd(0x485 + ll).toString(16), "type", rd(0x34F + ll).toString(16), "capture", rd(0x42C + ll), "paralyzed", rd(0x512), "hearts", rd(0x66F).toString(16), rd(0x670).toString(16));
  if (rd(0x34F + ll) !== 0x17) { console.log(f, "like-like gone, hearts", rd(0x66F).toString(16), rd(0x670).toString(16)); break; }
}
