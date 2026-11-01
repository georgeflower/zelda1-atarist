// Which monster types start in a spawn cloud (metastate 1) in the ROM's dungeons, and for how long?
//   node cloud_types.mjs [--quest 1|2] [--level 1,2,..]   -> prints one line per type: NES type, rooms seen, cloud yes/no, frames
import {newGame} from "./nes.mjs";
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const quest = Number(opt("--quest", 1));
const levels = opt("--level", "1,2,3,4,5,6,7,8,9").split(",").map(Number);
const base = newGame(quest === 2);
const snap0 = JSON.stringify(base.nes.toJSON());
const seen = {};
for (const level of levels) {
  base.nes.fromJSON(JSON.parse(snap0));
  base.wr(0x10, level); base.wr(0x12, 2); base.wr(0x13, 0); base.wr(0x11, 0);
  base.runUntil(() => base.rd(0x12) === 5 && base.rd(0x11) === 1, 600); base.run(30);
  const snap = JSON.stringify(base.nes.toJSON());
  for (let room = 0; room < 128; room++) {
    base.nes.fromJSON(JSON.parse(snap));
    base.wr(0x6B7E + 47, room); base.wr(0xEB, room); base.wr(0x12, 3); base.wr(0x13, 0); base.wr(0x11, 0);
    let ok = false;
    for (let i = 0; i < 900; i++) { base.run(1); if (base.rd(0x12) === 3 && base.rd(0x11)) base.wr(0xEB, room); if (base.rd(0x12) === 5 && base.rd(0x11)) { ok = true; break; } }
    if (!ok) continue;
    const first = {};
    for (let s = 1; s <= 11; s++) { const t = base.rd(0x34F + s); if (t && t < 0x53) first[s] = {t, m: base.rd(0x405 + s), f: -1}; }
    for (let f = 0; f < 90; f++) {
      base.run(1);
      for (const s in first) if (first[s].f < 0 && base.rd(0x405 + Number(s)) === 0) first[s].f = f + 1;
    }
    for (const s in first) {
      const e = first[s]; const k = `${e.t.toString(16).padStart(2, "0")}`;
      const r = seen[k] ||= {rooms: 0, cloud: 0, frames: []};
      r.rooms++; if (e.m) { r.cloud++; r.frames.push(e.f); }
    }
  }
  console.error(`level ${level} done`);
}
for (const k of Object.keys(seen).sort()) {
  const r = seen[k];
  console.log(`type 0x${k}: seen ${r.rooms}, in a cloud ${r.cloud}${r.frames.length ? `, frames ${Math.min(...r.frames)}-${Math.max(...r.frames)}` : ""}`);
}
