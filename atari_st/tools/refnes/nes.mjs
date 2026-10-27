// Headless NES reference: boots ext/Original.nes in jsnes, drives the controller, reads RAM.
import {NES, Controller} from "jsnes";
import fs from "fs";
import path from "path";
import {fileURLToPath} from "url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const ROM = path.resolve(here, "../../../ext/Original.nes");
export const BTN = {A: Controller.BUTTON_A, B: Controller.BUTTON_B, SELECT: Controller.BUTTON_SELECT,
  START: Controller.BUTTON_START, UP: Controller.BUTTON_UP, DOWN: Controller.BUTTON_DOWN,
  LEFT: Controller.BUTTON_LEFT, RIGHT: Controller.BUTTON_RIGHT};

export class Zelda {
  constructor() {
    this.pixels = null;
    this.nes = new NES({onFrame: (buf) => { this.pixels = buf; }, onAudioSample() {}});
    this.nes.loadROM(fs.readFileSync(ROM).toString("binary"));
    this.frames = 0;
  }
  get mem() { return this.nes.cpu.mem; }
  rd(a) { return this.nes.cpu.mem[a]; }
  wr(a, v) { this.nes.cpu.mem[a] = v & 0xff; }
  run(n = 1) { for (let i = 0; i < n; i++) { this.nes.frame(); this.frames++; } }
  hold(btn, n = 2) { this.nes.buttonDown(1, btn); this.run(n); this.nes.buttonUp(1, btn); }
  tap(btn, gap = 6) { this.hold(btn, 2); this.run(gap); }
  state() { return `mode=${this.rd(0x12).toString(16)} sub=${this.rd(0x13).toString(16)} level=${this.rd(0x10)} room=${this.rd(0xEB).toString(16)}`; }
  runUntil(pred, max = 6000) { for (let i = 0; i < max; i++) { if (pred()) return true; this.run(1); } return false; }
}

// A game in play on the overworld (First Quest, or the Second with the name ZELDA).
const NAME_A = ["DOWN","A","A","A"]; // placeholder, replaced below
export function newGame(quest2 = false) {
  const z = new Zelda();
  z.run(120); z.tap(BTN.START); z.run(60);
  z.tap(BTN.START); z.run(30);                       // REGISTER YOUR NAME
  if (quest2) {
    const seq = ["DOWN","DOWN","RIGHT","RIGHT","RIGHT","A","UP","UP","RIGHT","A","DOWN","LEFT","LEFT","LEFT","LEFT","A",
                 "UP","RIGHT","RIGHT","RIGHT","A","LEFT","LEFT","LEFT","A"];     // Z E L D A
    for (const b of seq) z.tap(BTN[b]);
  } else {
    z.tap(BTN.A);                                      // one letter, "A" at the board's first cell
  }
  for (let i = 0; i < 3; i++) z.tap(BTN.SELECT);       // on to END
  z.tap(BTN.START); z.run(60);
  z.tap(BTN.START); z.run(120);
  if (z.rd(0x12) !== 5) throw new Error("did not reach play: " + z.state());
  return z;
}
