// The ROM side of the bot: jsnes driven over stdin/stdout, one JSON command a line.
//   {"op":"step","buttons":["UP","A"],"n":1,"read":[[addr,len],...]}  -> {"frame":N,"mem":["hex",...]}
//   {"op":"poke","addr":A,"bytes":[..]}                                -> {"ok":true}
//   {"op":"ppm","path":"file.ppm"}                                     -> {"ok":true}
import {Zelda, BTN} from "../refnes/nes.mjs";
import fs from "fs";
import readline from "readline";

const z = new Zelda();
let held = new Set();
const rl = readline.createInterface({input: process.stdin});
const out = (o) => process.stdout.write(JSON.stringify(o) + "\n");
const hex = (a, n) => { let s = ""; for (let i = 0; i < n; i++) s += (z.mem[a + i] & 0xff).toString(16).padStart(2, "0"); return s; };
rl.on("line", (line) => {
  const c = JSON.parse(line);
  if (c.op === "step") {
    const want = new Set(c.buttons || []);
    for (const b of held) if (!want.has(b)) z.nes.buttonUp(1, BTN[b]);
    for (const b of want) if (!held.has(b)) z.nes.buttonDown(1, BTN[b]);
    held = want;
    z.run(c.n || 1);
    out({frame: z.frames, mem: (c.read || []).map(([a, n]) => hex(a, n))});
  } else if (c.op === "poke") {
    c.bytes.forEach((v, i) => z.wr(c.addr + i, v));
    out({ok: true});
  } else if (c.op === "ppm") {
    const b = z.pixels, buf = Buffer.alloc(256 * 240 * 3);
    for (let i = 0; i < 256 * 240; i++) { const p = b[i]; buf[i * 3] = p & 0xff; buf[i * 3 + 1] = (p >> 8) & 0xff; buf[i * 3 + 2] = (p >> 16) & 0xff; }
    fs.writeFileSync(c.path, Buffer.concat([Buffer.from("P6\n256 240\n255\n"), buf]));
    out({ok: true});
  } else if (c.op === "warp") {          // a development shortcut: load a level and put Link in one of its rooms
    z.wr(0x10, c.level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
    z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 900); z.run(30);
    z.wr(0x6B7E + 47, c.room); z.wr(0xEB, c.room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
    for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, c.room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
    z.run(30);
    out({ok: true});
  } else if (c.op === "quit") process.exit(0);
});
