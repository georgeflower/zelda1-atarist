"""Drive the ROM (jsnes, nes_server.mjs) one frame at a time from Python. Development tooling only (tools/bot)."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent


class Nes:
    # RAM the bot reads every frame: zero page and the stack page area, objects, items
    READS = [(0x0000, 0x100), (0x0300, 0x300), (0x0600, 0x100)]

    def __init__(self):
        self.p = subprocess.Popen(["node", str(HERE / "nes_server.mjs")], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  text=True, bufsize=1, cwd=HERE)
        self.mem = bytearray(0x10000)
        self.frame = 0
        self.step(set(), 1)

    def _call(self, c: dict) -> dict:
        self.p.stdin.write(json.dumps(c) + "\n")
        return json.loads(self.p.stdout.readline())

    def step(self, buttons: set[str], frames: int = 1, extra: list | None = None) -> None:
        reads = self.READS + (extra or [])
        r = self._call({"op": "step", "buttons": sorted(buttons), "n": frames, "read": reads})
        self.frame = r["frame"]
        for (a, n), h in zip(reads, r["mem"]):
            self.mem[a:a + n] = bytes.fromhex(h)

    def read(self, addr: int, n: int) -> bytes:
        r = self._call({"op": "step", "buttons": [], "n": 0, "read": [[addr, n]]})
        return bytes.fromhex(r["mem"][0])

    def rd(self, a: int) -> int:
        return self.mem[a]

    def poke(self, addr: int, values) -> None:
        if isinstance(values, int):
            values = [values]
        self._call({"op": "poke", "addr": addr, "bytes": list(values)})
        for i, v in enumerate(values):
            self.mem[addr + i] = v & 0xff

    def warp(self, level: int, room: int) -> None:
        self._call({"op": "warp", "level": level, "room": room})
        self.step(set(), 1)

    def ppm(self, path: str) -> None:
        self._call({"op": "ppm", "path": path})

    def snapshot(self, path: Path) -> None:
        from PIL import Image
        path = Path(path).resolve()
        ppm = str(path) + ".ppm"
        self.ppm(ppm)
        Image.open(ppm).save(path)
        Path(ppm).unlink()

    def close(self) -> None:
        try:
            self.p.stdin.write(json.dumps({"op": "quit"}) + "\n")
            self.p.wait(2)
        except Exception:
            self.p.kill()
