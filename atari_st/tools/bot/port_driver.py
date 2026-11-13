"""Drive the port in Hatari one frame at a time: the debugger stops at debug_keys_far (right after poll_keyboard in
main_loop) every frame, the variable block is read with savebin and the key table is written with w, then it runs on.
Development tooling only (tools/bot)."""
from __future__ import annotations

import os
import re
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))
import screenshot as SS  # noqa: E402

PROJECT = TOOLS.parent
# NES buttons to ST keys: Start = Return, Select = Tab, A = Ctrl, B = Space
KEYS = {"UP": 0x48, "DOWN": 0x50, "LEFT": 0x4B, "RIGHT": 0x4D, "A": 0x1D, "B": 0x39, "START": 0x1C, "SELECT": 0x0F}


def symbols(elf: Path) -> dict[str, int]:
    out = subprocess.run(["m68k-linux-gnu-nm", str(elf)], capture_output=True, text=True, check=True).stdout
    table = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3:
            table[parts[2]] = int(parts[0], 16)
    return table


class PortHung(RuntimeError):
    """The game stopped reaching its frame stop: a hang or a crash."""


class Port:
    def __init__(self, work: Path, prg: Path, tos: Path, hd_files: dict[str, Path] | None = None):
        self.work = work
        self.work.mkdir(parents=True, exist_ok=True)
        self.layout = SS.parse_globals_layout(PROJECT / "src" / "globals.s")
        self.size = self.layout["__size__"]
        self.sym = symbols(prg.parent / "zelda_st.elf")
        hd = work / "hd"
        if hd.exists():
            shutil.rmtree(hd)
        hd.mkdir()
        shutil.copy(prg, hd / "ZELDAST.PRG")
        for data in sorted((prg.parent / "generated").glob("*.DAT")):
            shutil.copy(data, hd / data.name)
        for name, path in (hd_files or {}).items():
            shutil.copy(path, hd / name)
        self.ram = work / "ram.bin"
        self.glob = work / "glob.bin"
        dbg = work / "dbg.ini"
        dbg.write_text("b VBL > 260 :once\n", encoding="utf-8")
        cmd = [os.environ.get("HATARI", "hatari"), "--tos", str(tos), "--machine", "st", "--memsize", "1",
               "--cpu-exact", "true", "--compatible", "true", "--fast-boot", "true", "--fast-forward", "true",
               "--sound", "off", "--disable-video", "true", "--harddrive", str(hd), "--auto", "C:\\ZELDAST.PRG",
               "--parse", str(dbg), "--log-level", "warn"]
        env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
        self.p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  env=env, bufsize=0, cwd=work)
        self.buf = ""
        self.log = open(work / "hatari.log", "w")
        self.wait_prompt(120)
        # find the variable block, then stop at debug_keys_far every frame from here on
        self.cmd(f"savebin {self.ram} 0 $100000")
        data = self.ram.read_bytes()
        self.gaddr = SS.find_globals(data)
        self.base = self.gaddr - self.sym["globals"]
        self.hook = self.base + self.sym["debug_keys_far"]
        self.cmd(f"b pc = ${self.hook:x}")
        self.held: dict[int, int] = {}
        self.exceptions = 0
        self.frame = 0
        self.g = b""
        self.cont()

    # -- the pipe ------------------------------------------------------------------------------------------------
    def wait_prompt(self, timeout: float = 30) -> str:
        end = time.time() + timeout
        while time.time() < end:
            i = self.buf.find("\n> ")
            if i < 0 and self.buf.endswith("> ") and (self.buf == "> " or self.buf.endswith("\n> ")):
                i = len(self.buf) - 3
            if self.buf.endswith("\n> ") or self.buf == "> ":
                out, self.buf = self.buf, ""
                self.log.write(out)
                return out
            r, _, _ = select.select([self.p.stdout], [], [], 0.5)
            if r:
                d = os.read(self.p.stdout.fileno(), 1 << 16)
                if not d:
                    raise RuntimeError("Hatari ended:\n" + self.buf[-2000:])
                self.buf += d.decode(errors="replace")
        raise TimeoutError("no debugger prompt:\n" + self.buf[-2000:])

    def cmd(self, line: str) -> str:
        self.p.stdin.write((line + "\n").encode())
        return self.wait_prompt()

    def cont(self) -> None:
        """Run to the next frame's stop and read the variable block."""
        try:
            out = self.cmd("c")
        except TimeoutError:
            # no frame for 30 s: the game is caught in a loop (or crashed). Break into the debugger and say where.
            import signal
            where = ""
            try:
                self.p.send_signal(signal.SIGINT)
                where = self.wait_prompt(10)
                where += self.cmd("r") + self.cmd("d pc")
            except Exception as e:      # noqa: BLE001
                where += f" (no debugger: {e!r})"
            self.log.write("\n!!! HUNG\n" + where)
            raise PortHung("the port ran 30 s without reaching the next frame:\n" + where[-3000:])
        if "Bus Error" in out or "Address Error" in out or "Exception" in out or "exception" in out:
            self.log.write("\n!!! " + out)
            self.exceptions += 1
        self.cmd(f"savebin {self.glob} ${self.gaddr:x} {self.size}")
        self.g = self.glob.read_bytes()
        self.frame += 1

    # -- the game ------------------------------------------------------------------------------------------------
    def v(self, name: str, index: int = 0) -> int:
        return self.g[self.layout[name] + index]

    def vw(self, name: str, index: int = 0) -> int:
        o = self.layout[name] + index
        return (self.g[o] << 8) | self.g[o + 1]

    def poke(self, name: str, value: int, index: int = 0) -> None:
        self.cmd(f"w ${self.gaddr + self.layout[name] + index:x} {value & 0xff}")

    def peek_mem(self, addr: int, n: int) -> bytes:
        self.cmd(f"savebin {self.ram} ${addr:x} {n}")
        return self.ram.read_bytes()

    def step(self, buttons: set[str], frames: int = 1) -> None:
        """Hold these NES buttons (mapped to ST keys) for the given number of game frames."""
        for _ in range(frames):
            kaddr = self.gaddr + self.layout["KEY_STATES"]
            for b, code in KEYS.items():
                want = 1 if b in buttons else 0
                if self.held.get(code, 0) != want:
                    self.cmd(f"w ${kaddr + code:x} {want}")
                    self.held[code] = want
            self.cont()

    def snapshot(self, path: Path) -> None:
        """The screen on show, as a PNG."""
        out = self.cmd("m $ff8200 4")
        base = SS.video_base(out)
        pal = self.peek_mem(0xFF8240, 32)
        words = [(pal[i] << 8) | pal[i + 1] for i in range(0, 32, 2)]
        screen = self.peek_mem(base, 32000)
        rows, palette = SS.decode_screen(b"\0" * base + screen, base, words)
        SS.write_png(Path(path), rows, palette)

    def crashed(self) -> bool:
        return self.exceptions > 0

    def close(self) -> None:
        try:
            self.p.kill()
        except Exception:
            pass
