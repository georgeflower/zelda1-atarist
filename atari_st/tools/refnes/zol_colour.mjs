// The colours of a monster in a dungeon room, in the ROM: node zol_colour.mjs LEVEL ROOM TYPE
import {newGame} from "./nes.mjs";
const [level, room, type] = process.argv.slice(2).map(Number);
const z = newGame(false);
z.wr(0x10, level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600); z.run(30);
z.wr(0x6B7E + 47, room); z.wr(0xEB, room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
for (let i = 0; i < 900; i++) { z.run(1); if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, room); if (z.rd(0x12) === 5 && z.rd(0x11)) break; }
z.wr(0x4F0, 0xF0); z.run(90);
const pal = []; for (let i = 0; i < 32; i++) pal.push(z.nes.ppu.vramMem[0x3F00 + i].toString(16).padStart(2, "0"));
console.log("PPU palette bg:", pal.slice(0, 16).join(" "), " sprite:", pal.slice(16).join(" "));
for (let s = 1; s < 12; s++) {
  if (z.rd(0x34F + s) !== type) continue;
  const x = z.rd(0x70 + s), y = z.rd(0x84 + s);
  const cols = new Map();
  for (let py = y - 8; py < y + 8; py++) for (let px = x; px < x + 16; px++) {
    const c = z.pixels[(py + 0) * 256 + px]; cols.set(c.toString(16), (cols.get(c.toString(16)) || 0) + 1);
  }
  console.log("slot", s, "at", x, y, "attr", z.rd(0x3F0 + s), [...cols.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5));
}
// sprites in OAM near the monster
const oam = z.nes.ppu.spriteMem; const out = [];
for (let i = 0; i < 64; i++) { const sy = oam[i * 4], t = oam[i * 4 + 1], a = oam[i * 4 + 2], sx = oam[i * 4 + 3]; if (sy < 0xF0) out.push(`${t.toString(16)}:${a.toString(16)}@${sx},${sy}`); }
console.log("OAM:", out.join(" "));
import fs from "fs";
const buf = Buffer.alloc(256 * 240 * 3);
for (let i = 0; i < 256 * 240; i++) { const c = z.pixels[i]; buf[i * 3] = c & 255; buf[i * 3 + 1] = (c >> 8) & 255; buf[i * 3 + 2] = (c >> 16) & 255; }
fs.writeFileSync(process.env.PPM || "/tmp/zol.ppm", Buffer.concat([Buffer.from("P6\n256 240\n255\n"), buf]));
