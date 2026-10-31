// Respawn probe: what the ROM (jsnes) does with the monsters of a room Link has cleared, once he leaves and comes back.
// It plays the real game: kills a room with the scripted sword player, goes through the doors (Link is put at the door's side of the
// room and walks out, so the ROM's own scroll code runs, SaveKillCount included) and prints the room history ($621), the room's
// world flags and kill count ($560+room), and the monsters made on re-entry.
//
//   node respawn_probe.mjs [dungeon|partial|boss|reenter|overworld|all]
//
// Facts it shows (Level 2 rooms $6D five ropes, $3E Moldorm; overworld $67):
//   dungeon    a cleared room is empty while it is among the last six rooms entered, and its monsters come back once it is not
//   partial    kills of a room that was not cleared are kept: leave with 3 of 5 left, come back (even after the history dropped it): 3
//   boss       a room of a single big monster (object list $32-$48 but not $3A/$3B: Moldorm, Dodongo, Gleeok...) stays dead
//   reenter    leaving the dungeon (mode 2) clears the history and the level's kill counts; the flags stay, so entering again brings every
//              regular monster back (and resets the room's flags)
//   overworld  a cleared screen is empty while in the history, full again after six other screens
import {newGame, BTN} from "./nes.mjs";
const snapshot = (z) => JSON.stringify(z.nes.toJSON());
const restore = (z, s) => z.nes.fromJSON(JSON.parse(s));
function loadLevel(z, level) {
  z.wr(0x10, level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
  if (!z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600)) throw new Error("level " + level + " did not load: " + z.state());
  z.run(30);
}
const objs = (z) => { const l = []; for (let s = 1; s < 20; s++) { const t = z.rd(0x34F + s); if (t) l.push({slot: s, type: t, x: z.rd(0x70 + s), y: z.rd(0x84 + s), hp: z.rd(0x485 + s)}); } return l; };
const hist = (z) => [0,1,2,3,4,5].map(i => z.rd(0x621 + i).toString(16)).join(" ") + " idx=" + z.rd(0x620);
const NO_TARGET = new Set([0x2B, 0x2C, 0x2D, 0x35, 0x36, 0x40, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F]);
function player(z, targets, frame) {
  const lx = z.rd(0x70), ly = z.rd(0x84);
  let best = null, bd = 1e9;
  for (const s of targets) {
    if (z.rd(0x34F + s) === 0) continue;
    const dx = z.rd(0x70 + s) - lx, dy = z.rd(0x84 + s) - ly;
    const d = Math.abs(dx) + Math.abs(dy);
    if (d < bd) { bd = d; best = {dx, dy, s}; }
  }
  if (!best) return {dir: null, a: false};
  const {dx, dy} = best;
  let dir;
  if (Math.abs(dx) > 8 && Math.abs(dy) > 8) dir = Math.abs(dx) < Math.abs(dy) ? (dx > 0 ? "RIGHT" : "LEFT") : (dy > 0 ? "DOWN" : "UP");
  else if (Math.abs(dx) <= 8) dir = dy > 0 ? "DOWN" : "UP";
  else dir = dx > 0 ? "RIGHT" : "LEFT";
  const a = Math.abs(dx) + Math.abs(dy) < 26 && (frame % 16) < 8;
  return {dir, a};
}
function killAll(z, maxFrames = 3000) {
  z.wr(0x657, 3);
  const held = new Set();
  const press = (want) => { for (const b of ["UP","DOWN","LEFT","RIGHT","A"]) { const on = b === "A" ? want.a : want.dir === b; if (on && !held.has(b)) { z.nes.buttonDown(1, BTN[b]); held.add(b); } if (!on && held.has(b)) { z.nes.buttonUp(1, BTN[b]); held.delete(b); } } };
  const targets = () => objs(z).filter(o => !NO_TARGET.has(o.type) && o.slot < 12).map(o => o.slot);
  let f = 0;
  for (; f < maxFrames; f++) {
    z.wr(0x4F0, 0xF0);
    const t = targets();
    if (z.rd(0x12) !== 5 || t.length === 0) break;
    press(player(z, t, f)); z.run(1);
  }
  press({dir: null, a: false}); z.run(60);
  return {frames: f, left: targets().length};
}
const SPOT = {RIGHT:[0xd0,0x8d], LEFT:[0x20,0x8d], UP:[0x78,0x5d], DOWN:[0x78,0xbd]};
function leave(z, dir) {       // put Link at the door's side of the room and go through it
  z.wr(0x70, SPOT[dir][0]); z.wr(0x84, SPOT[dir][1]); z.run(2);
  z.nes.buttonDown(1, BTN[dir]);
  let moved = false;
  for (let i = 0; i < 400; i++) { z.wr(0x4F0, 0xF0); z.run(1); if (z.rd(0x12) !== 5) moved = true; if (moved && z.rd(0x12) === 5 && z.rd(0x11)) break; }
  z.nes.buttonUp(1, BTN[dir]); z.run(5);
  return z.rd(0xEB);
}
const flagsAddr = (z) => z.rd(0x6BAF) | (z.rd(0x6BB0) << 8);
const flag = (z, room) => z.rd(flagsAddr(z) + room);
const sig = (z, room) => `room=${z.rd(0xEB).toString(16)} lvl=${z.rd(0x10)} objs=${objs(z).filter(o=>o.slot<12).length} types=[${objs(z).filter(o=>o.slot<12).map(o=>o.type.toString(16)).join(",")}] hist=[${hist(z)}] flags[${room.toString(16)}]=${flag(z,room).toString(16)} kc[${room.toString(16)}]=${z.rd(0x560+room)}`;
function killDown(z, remaining, maxFrames = 3000) {      // kill until `remaining` monsters are left
  z.wr(0x657, 3);
  const held = new Set();
  const press = (want) => { for (const b of ["UP","DOWN","LEFT","RIGHT","A"]) { const on = b === "A" ? want.a : want.dir === b; if (on && !held.has(b)) { z.nes.buttonDown(1, BTN[b]); held.add(b); } if (!on && held.has(b)) { z.nes.buttonUp(1, BTN[b]); held.delete(b); } } };
  const alive = () => objs(z).filter(o => !NO_TARGET.has(o.type) && o.slot < 12).map(o => o.slot);
  let f = 0;
  for (; f < maxFrames; f++) {
    z.wr(0x4F0, 0xF0);
    const t = alive();
    if (z.rd(0x12) !== 5 || t.length <= remaining) break;
    press(player(z, t, f)); z.run(1);
  }
  press({dir: null, a: false}); z.run(30);
  return {frames: f, left: alive().length};
}

const OPP = {UP: "DOWN", DOWN: "UP", LEFT: "RIGHT", RIGHT: "LEFT"};
const which = process.argv[2] || "all";
const want = (n) => which === "all" || which === n;
const fresh = (level) => { const z = newGame(false); if (level) loadLevel(z, level); return z; };

if (want("dungeon")) {
  console.log("== dungeon: clear the five ropes of Level 2 room $6D, go six rooms away, come back");
  const z = fresh(2);
  leave(z, "UP"); z.run(60);
  console.log("entered 6D:", sig(z, 0x6d));
  console.log("killed:", JSON.stringify(killAll(z)), sig(z, 0x6d));
  for (const d of ["DOWN", "RIGHT", "UP", "UP", "UP", "UP"]) { leave(z, d); z.run(30); console.log("  hop", d, sig(z, 0x6d)); }
  for (const d of ["DOWN", "DOWN", "DOWN", "DOWN", "LEFT", "UP"]) { leave(z, d); z.run(30); console.log("  back", d, sig(z, 0x6d)); }
}
if (want("partial")) {
  console.log("== partial: kill 2 of the 5 ropes of $6D, leave, come back at once, and after the history dropped it");
  const z = fresh(2);
  leave(z, "UP"); z.run(60);
  console.log("killed 2:", JSON.stringify(killDown(z, 3)), sig(z, 0x6d));
  leave(z, "DOWN"); z.run(30); console.log("left:", sig(z, 0x6d));
  leave(z, "UP"); z.run(30); console.log("back at once:", sig(z, 0x6d));
  leave(z, "DOWN"); z.run(10);
  for (const d of ["RIGHT", "UP", "UP", "UP", "UP", "UP"]) { leave(z, d); z.run(10); }
  for (const d of ["DOWN", "DOWN", "DOWN", "DOWN", "DOWN", "LEFT", "UP"]) { leave(z, d); z.run(30); }
  console.log("returned after the history dropped it:", sig(z, 0x6d));
}
if (want("boss")) {
  console.log("== boss: kill the Moldorm of $3E, wander off until $3E has left the history, come back");
  const z = fresh(2);
  for (const d of ["RIGHT", "UP", "UP", "UP", "UP"]) { leave(z, d); z.run(10); }
  console.log("kill:", JSON.stringify(killAll(z, 9000)), sig(z, 0x3e));
  const route = []; const visited = new Set([0x3e]);
  for (let guard = 0; guard < 40; guard++) {
    if (![0, 1, 2, 3, 4, 5].map(i => z.rd(0x621 + i)).includes(0x3e)) break;
    const here = z.rd(0xEB); let moved = false;
    for (const d of ["DOWN", "UP", "LEFT", "RIGHT"]) {
      if (here === 0x7d && d === "DOWN") continue;          // that is the way out
      const r = leave(z, d);
      if (r !== here && !visited.has(r)) { route.push(d); visited.add(r); moved = true; z.run(10); break; }
      else if (r !== here) leave(z, OPP[d]);
    }
    if (!moved) { const d = OPP[route.pop()]; if (!d) break; leave(z, d); }
  }
  console.log("out of the history:", ![0, 1, 2, 3, 4, 5].map(i => z.rd(0x621 + i)).includes(0x3e), `hist=[${hist(z)}]`);
  while (route.length) { leave(z, OPP[route.pop()]); z.run(10); }
  console.log("back at 3E:", sig(z, 0x3e));
}
if (want("reenter")) {
  console.log("== reenter: clear $6D, leave the dungeon, go in again");
  const z = fresh(2);
  leave(z, "UP"); z.run(60);
  console.log("killed:", JSON.stringify(killAll(z)), sig(z, 0x6d));
  leave(z, "DOWN"); z.run(20); leave(z, "DOWN"); z.run(200);
  console.log("out: level", z.rd(0x10), "hist", hist(z), "flags6d", z.rd(0x6FF + 0x6d).toString(16), "kill count", z.rd(0x560 + 0x6d));
  loadLevel(z, 2); leave(z, "UP"); z.run(60);
  console.log("6D again:", sig(z, 0x6d));
}
if (want("overworld")) {
  console.log("== overworld: kill the monsters of $67, leave, come back at once, then after six other screens");
  const z = newGame(false);
  const flags = (r) => { const a = z.rd(0x6BAF) | (z.rd(0x6BB0) << 8); return z.rd(a + r).toString(16); };
  const info = () => `room=${z.rd(0xEB).toString(16)} objs=${objs(z).filter(o => o.slot < 12).length} hist=[${hist(z)}] flags67=${flags(0x67)}`;
  const settle = (n) => { for (let i = 0; i < n; i++) { z.wr(0x4F0, 0xF0); z.run(1); } };
  const EDGE = {UP: (t) => [t, 0x44], DOWN: (t) => [t, 0xdd], LEFT: (t) => [0x04, t], RIGHT: (t) => [0xf0, t]};
  const hop = (dir) => {                                  // try columns/rows along the edge until a way out is free
    const from = z.rd(0xEB), snap = snapshot(z);
    const ts = dir === "UP" || dir === "DOWN" ? [0x78, 0x68, 0x88, 0x58, 0x98, 0x48, 0xa8, 0x38, 0xb8] : [0x8d, 0x7d, 0x9d, 0x6d, 0xad, 0x5d, 0xbd];
    for (const t of ts) {
      restore(z, snap);
      const [x, y] = EDGE[dir](t); z.wr(0x70, x); z.wr(0x84, y); z.run(1);
      z.nes.buttonDown(1, BTN[dir]);
      let moved = false;
      for (let i = 0; i < 200; i++) { z.wr(0x4F0, 0xF0); z.run(1); if (z.rd(0xEB) !== from) moved = true; if (moved && z.rd(0x12) === 5) break; }
      z.nes.buttonUp(1, BTN[dir]);
      if (moved) { settle(30); return true; }
    }
    return false;
  };
  hop("UP"); z.wr(0x70, 0x78); z.wr(0x84, 0x8d); settle(20);
  console.log("killed:", JSON.stringify(killAll(z, 4000)), info());
  hop("DOWN"); console.log("  hop DOWN", info());
  hop("UP"); console.log("  back at once", info());
  hop("DOWN"); const back = [];
  for (const d of ["LEFT", "LEFT", "LEFT", "LEFT", "LEFT", "LEFT"]) if (hop(d)) { back.push(OPP[d]); console.log("  hop", d, info()); }
  for (const d of back.reverse()) hop(d);
  hop("UP");
  console.log("after six other screens:", info());
}
