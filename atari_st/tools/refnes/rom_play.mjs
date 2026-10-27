// Phase 2 of the playthrough audit: PLAY every room of a dungeon in the original ROM (jsnes) with a scripted player and
// record what happens, as facts the port can be compared with (see port_play.py).
//
//   node rom_play.mjs [out.json] [--quest 1|2] [--level N] [--rooms 0x74,0x73] [--frames 1500]
//
// The player (the same policy as the port's autoplay) is invincible, holds the magic sword and walks
// in from the bottom door at the nearest monster and swings when it is in reach. It comes in at the bottom door like in play (the port's autoplay build starts Link there too: the monsters are placed away from him). It never uses a second item, so rooms that need
// bombs, the recorder or food stay uncleared on both sides, which is itself a fact to compare.
import {newGame, BTN} from "./nes.mjs";
import fs from "fs";
import path from "path";

const args = process.argv.slice(2);
const opt = (name, def = null) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : def; };
const out = args.find((a, i) => !a.startsWith("--") && !(i > 0 && args[i - 1].startsWith("--"))) || "../../build/refnes/rom_play.json";
const quests = opt("--quest") ? [Number(opt("--quest"))] : [1];
const levels = opt("--level") !== null ? opt("--level").split(",").map(Number) : [1];
const wanted = opt("--rooms") ? opt("--rooms").split(",").map(Number) : null;
const FRAMES = Number(opt("--frames", 1500));
const IDLE = args.includes("--idle");   // the player stands still (and cannot be hurt): to watch the monsters
const AFTER = 240;                 // frames to play on after the room is cleared
const SAMPLE = 10;                 // frames between two samples of the monsters

const START_ROOM_OFFSET = 47;
const ATTR_BASE = 0x687E, ATTR_SIZE = 0x80;
const snapshot = (z) => JSON.stringify(z.nes.toJSON());
const restore = (z, s) => z.nes.fromJSON(JSON.parse(s));

function loadLevel(z, level) {
  z.wr(0x10, level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
  if (!z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600)) throw new Error("level " + level + " did not load: " + z.state());
  z.run(30);
}

// Enter a room and stop on the first frame of play (monsters just made).
function enterRoom(z, room) {
  z.wr(0x6B7E + START_ROOM_OFFSET, room);
  z.wr(0xEB, room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
  for (let i = 0; i < 900; i++) {
    z.run(1);
    if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, room);
    if (z.rd(0x12) === 5 && z.rd(0x11)) return true;
  }
  return false;
}

const objs = (z) => {
  const list = [];
  for (let s = 1; s < 20; s++) {
    const t = z.rd(0x34F + s);
    if (t) list.push({slot: s, type: t, x: z.rd(0x70 + s), y: z.rd(0x84 + s), hp: z.rd(0x485 + s), state: z.rd(0xAC + s)});
  }
  return list;
};
const tiles = (z) => {
  const t = [];
  for (let i = 0; i < 32 * 22; i++) t.push(z.rd(0x6530 + i));
  return t;
};

// Types the player does not try to kill: bubbles, the rupee stash, Grumble, blade traps, statues and the like, and shots.
const NO_TARGET = new Set([0x2B, 0x2C, 0x2D, 0x35, 0x36, 0x40, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F]);

// One frame of the player. Returns the buttons it holds.
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
  // line up on the shorter axis first when it is further than a sword's width, else close in on the longer one
  let dir;
  if (Math.abs(dx) > 8 && Math.abs(dy) > 8) dir = Math.abs(dx) < Math.abs(dy) ? (dx > 0 ? "RIGHT" : "LEFT") : (dy > 0 ? "DOWN" : "UP");
  else if (Math.abs(dx) <= 8) dir = dy > 0 ? "DOWN" : "UP";
  else dir = dx > 0 ? "RIGHT" : "LEFT";
  const a = Math.abs(dx) + Math.abs(dy) < 26 && (frame % 16) < 8;      // the sword wants a fresh press for every swing
  return {dir, a};
}

function press(z, held, want) {
  for (const b of ["UP", "DOWN", "LEFT", "RIGHT", "A"]) {
    const on = b === "A" ? want.a : want.dir === b;
    if (on && !held.has(b)) { z.nes.buttonDown(1, BTN[b]); held.add(b); }
    if (!on && held.has(b)) { z.nes.buttonUp(1, BTN[b]); held.delete(b); }
  }
}

function playRoom(z, room) {
  z.wr(0x657, 3);                                   // the magic sword
  z.wr(0x84, 0xBD);                                 // inside the door, where the game's walk-in ends (and where the port puts Link)
  const initial = objs(z);
  const targets = initial.filter(o => !NO_TARGET.has(o.type) && o.slot < 12).map(o => o.slot);
  const tilesBefore = tiles(z);
  const samples = [];
  const held = new Set();
  let clearedAt = null;
  const items = [];
  let frame = 0;
  const doorsAt0 = z.rd(0xEE);
  const hits = {};                                  // per target slot: its first hit points and every drop of them
  const lastHp = {};
  for (; frame < FRAMES; frame++) {
    z.wr(0x4F0, 0xF0);                              // Link cannot be hurt
    if (z.rd(0x12) !== 5) break;                    // left the room
    const want = clearedAt === null && !IDLE ? player(z, targets, frame) : {dir: null, a: false};
    press(z, held, want);
    z.run(1);
    for (const slot of targets) {
      const hp = z.rd(0x485 + slot), type = z.rd(0x34F + slot);
      if (type === 0) continue;
      const h = hits[slot] || (hits[slot] = {type, hp0: null, drops: []});
      if (h.hp0 === null && hp > 0) { h.hp0 = hp; lastHp[slot] = hp; }
      if (lastHp[slot] !== undefined && hp < lastHp[slot] && hp < 0x80) { h.drops.push([frame, lastHp[slot] - hp]); }
      if (lastHp[slot] !== undefined) lastHp[slot] = hp;
    }
    if (frame === 4) {                              // a boss that is several objects (Manhandla's hands, Gohma, Patra...) makes the rest in its first updates
      for (const o of objs(z)) if (!NO_TARGET.has(o.type) && o.slot < 12 && !targets.includes(o.slot)) { targets.push(o.slot); initial.push(o); }
    }
    if (frame % SAMPLE === 0) samples.push({f: frame, l: [z.rd(0x70), z.rd(0x84), z.rd(0x98)], i: [z.rd(0x34F + 19), z.rd(0x70 + 19), z.rd(0x84 + 19), z.rd(0xAC + 19), z.rd(0xAB)], o: objs(z).map(o => [o.slot, o.type, o.x, o.y, o.state])});
    if (!IDLE && clearedAt === null && targets.length && targets.every(s => z.rd(0x34F + s) === 0 || z.rd(0x34F + s) !== initial.find(o => o.slot === s).type)) clearedAt = frame;
    if (clearedAt !== null && frame >= clearedAt + AFTER) break;   // long enough for a boss's death and the shutters
  }
  for (const b of [...held]) { z.nes.buttonUp(1, BTN[b]); }
  const after = objs(z);
  const tilesAfter = tiles(z);
  const changed = [];
  for (let i = 0; i < tilesAfter.length; i++) if (tilesAfter[i] !== tilesBefore[i]) changed.push(i);
  return {
    room, frames: frame, cleared: clearedAt, targets, initial, samples, hits, after,
    doors0: doorsAt0, doors: z.rd(0xEE), roomItem: {id: z.rd(0xAB), state: z.rd(0xAC + 19), x: z.rd(0x70 + 19), y: z.rd(0x84 + 19)},
    tilesChanged: changed.length, tilesChangedAt: changed.slice(0, 64),
    linkRoom: z.rd(0xEB), mode: z.rd(0x12),
    attrs: [0, 1, 2, 3, 4, 5].map(i => z.rd(ATTR_BASE + i * ATTR_SIZE + room)),
  };
}

const result = {};
for (const quest of quests) {
  const base = newGame(quest === 2);
  const baseSnap = snapshot(base);
  for (const level of levels) {
    restore(base, baseSnap);
    if (level) loadLevel(base, level);
    const snap = snapshot(base);
    const rooms = [];
    for (let room = 0; room < 128; room++) {
      if (wanted && !wanted.includes(room)) continue;
      restore(base, snap);
      if (!enterRoom(base, room)) { rooms.push({room, ok: false}); continue; }
      const info = playRoom(base, room);
      if (info.initial.length === 0) continue;       // an empty (or unused) room has nothing to play
      rooms.push(info);
    }
    result[`q${quest}_l${level}`] = {quest, level, rooms};
    console.error(`quest ${quest} level ${level}: ${rooms.length} rooms with monsters`);
  }
}
fs.mkdirSync(path.dirname(out), {recursive: true});
fs.writeFileSync(out, JSON.stringify(result));
console.error("wrote", out);
