// The intro's loop against its song on the NES. node intro_loop_probe.mjs [FRAMES]
// Logs, from power-on, the frame of every change of DemoPhase ($42C) / DemoSubphase ($42D) and every time the song's
// phrase index ($6C) goes back to 0 or the playing song ($609) changes, so the length of the intro's cycle and the
// moment the title song starts again (requested, or looping by itself) can be set side by side.
import {Zelda} from "./nes.mjs";
const frames = Number(process.argv[2] || 9000);
const z = new Zelda();
let ph = -1, sub = -1, phr = -1, song = -1;
for (let f = 0; f < frames; f++) {
  z.run(1);
  const p = z.rd(0x42C), s = z.rd(0x42D), r = z.rd(0x6C), g = z.rd(0x609);
  if (p !== ph || s !== sub) { console.log(f, "demo phase", p, "sub", s); ph = p; sub = s; }
  if (g !== song) { console.log(f, "song", g.toString(16)); song = g; }
  if (r !== phr) { if (r === 0 || r < phr) console.log(f, "phrase back to", r, "from", phr); phr = r; }
}
