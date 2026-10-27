// Ask the ROM itself, running in jsnes, what every room holds: the attribute bytes the game copied to RAM, the monsters
// its own room-setup code made, the room item. Writes JSON (default ../../build/refnes/rom_rooms.json).
//   node rom_rooms.mjs [out.json] [--quest 1|2] [--level N]
import {newGame} from "./nes.mjs";
import fs from "fs";
import path from "path";

const args = process.argv.slice(2);
const opt = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };
const out = args.find((a, i) => !a.startsWith("--") && !(i > 0 && args[i - 1].startsWith("--"))) || "../../build/refnes/rom_rooms.json";
const quests = opt("--quest") ? [Number(opt("--quest"))] : [1, 2];
const levels = opt("--level") !== null ? [Number(opt("--level"))] : [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

const START_ROOM_OFFSET = 47;
const ATTR_BASE = 0x687E, ATTR_SIZE = 0x80;
const snapshot = (z) => JSON.stringify(z.nes.toJSON());
const restore = (z, s) => z.nes.fromJSON(JSON.parse(s));

function loadLevel(z, level) {
  z.wr(0x10, level); z.wr(0x12, 2); z.wr(0x13, 0); z.wr(0x11, 0);
  if (!z.runUntil(() => z.rd(0x12) === 5 && z.rd(0x11) === 1, 600)) throw new Error("level " + level + " did not load: " + z.state());
  z.run(30);
}

// Enter a room the way the game does after loading a level: game mode 3 (the unfurl) lays out RoomId, mode 4 makes its objects.
function enterRoom(z, room) {
  // The unfurl lays out the level's start room, so make the room asked for the start room (LevelInfo $2F) before it runs.
  z.wr(0x6B7E + START_ROOM_OFFSET, room);
  z.wr(0xEB, room); z.wr(0x12, 3); z.wr(0x13, 0); z.wr(0x11, 0);
  for (let i = 0; i < 900; i++) {
    z.run(1);
    if (z.rd(0x12) === 3 && z.rd(0x11)) z.wr(0xEB, room);        // the level's start room is put back by the load
    if (z.rd(0x12) === 5 && z.rd(0x11)) {
      // the room item as the room set it up, before a Stalfos, Gibdo or Like-Like in slot 1 carries it off
      z.item0 = {id: z.rd(0xAB), state: z.rd(0xAC + 19), x: z.rd(0x70 + 19), y: z.rd(0x84 + 19)};
      z.run(100); return true;
    }
  }
  return false;
}

// The 32x22 tiles of the room as LayOutRoom left them in PlayAreaTiles ($6530, a column of 22 after another):
// one hex string per row.
function playfield(z) {
  const rows = [];
  for (let row = 0; row < 22; row++) {
    let s = "";
    for (let col = 0; col < 32; col++) s += z.rd(0x6530 + col * 22 + row).toString(16).padStart(2, "0");
    rows.push(s);
  }
  return rows;
}

function describe(z, room) {
  const attrs = []; for (let i = 0; i < 6; i++) attrs.push(z.rd(ATTR_BASE + i * ATTR_SIZE + room));
  const objs = [];
  for (let s = 1; s < 20; s++) {
    const t = z.rd(0x34F + s);
    if (t) objs.push({slot: s, type: t, x: z.rd(0x70 + s), y: z.rd(0x84 + s), hp: z.rd(0x485 + s), state: z.rd(0xAC + s)});
  }
  return {room, ok: true, attrs, count: z.rd(0x34E), template: z.rd(0x35F + 1), objs,
          item: z.item0, itemLater: {id: z.rd(0xAB), state: z.rd(0xAC + 19), x: z.rd(0x70 + 19), y: z.rd(0x84 + 19)},
          mode: z.rd(0x12), level: z.rd(0x10), roomId: z.rd(0xEB), tiles: playfield(z),
          doors: z.rd(0xEE)};
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
      restore(base, snap);
      if (!enterRoom(base, room)) { rooms.push({room, ok: false}); continue; }
      rooms.push(describe(base, room));
    }
    result[`q${quest}_l${level}`] = {quest, level, rooms, quest_byte: base.rd(0x62D + base.rd(0x16))};
    console.error(`quest ${quest} level ${level}: ${rooms.filter(r => r.ok).length}/128 rooms`);
  }
}
fs.mkdirSync(path.dirname(out), {recursive: true});
fs.writeFileSync(out, JSON.stringify(result));
console.error("wrote", out);
