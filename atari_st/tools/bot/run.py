"""Run the bot on both sides: the ROM in jsnes and the port in Hatari, task by task, and compare after each task.

    python3 run.py [--tasks gathering] [--out DIR] [--only NES|ST]

Development tooling only (tools/bot); needs ext/Original.nes, Hatari and $TOS."""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))

import state as ST  # noqa: E402
from brain import Side, Stuck  # noqa: E402
from nes_driver import Nes  # noqa: E402
from port_driver import Port  # noqa: E402
import routes  # noqa: E402

PROJECT = HERE.parent.parent
COMPARE_SLOTS = [i for i in range(32) if i not in range(22, 29)]   # 22-28 are rupees, keys, hearts, triforce... in the ROM


def build_port(out: Path, start: tuple[int, int] | None = None) -> Path:
    """The port as it ships, or (start = level, room) a build that begins in that dungeon room."""
    import subprocess
    env = dict(os.environ)
    for var in ("ZELDA_START_ROOM", "ZELDA_START_UW", "ZELDA_START_LEVEL", "ZELDA_START_CAVE", "ZELDA_SKIP_INTRO",
                "ZELDA_QUEST", "ZELDA_AUTOPLAY"):
        env.pop(var, None)
    if start:
        env["ZELDA_START_LEVEL"], env["ZELDA_START_UW"] = str(start[0]), f"0x{start[1]:02X}"
    subprocess.run(["make", "-C", str(PROJECT), f"BUILD_DIR={out}", f"{out}/ZELDAST.PRG"], check=True, env=env,
                   stdout=subprocess.DEVNULL)
    return out / "ZELDAST.PRG"


def new_game(side: Side) -> None:
    """Title, register a name (one letter), start: the same NES buttons on both sides."""
    side.cheat = False
    side.step((), 120)
    for b in ["START", None, "START", None, "A", None, "SELECT", None, "SELECT", None, "SELECT", None, "START", None,
              "START"]:
        side.step({b} if b else (), 2 if b else 40)
    side.wait_play(600)
    side.step((), 30)
    side.cheat = True


KIT_RE = r"(NES|ST): \S+ L\d+ room [0-9A-F]+ \(\d+,\d+\) items ([0-9a-f]{64}) rupees (\d+) keys (\d+) hearts (\d+) tri ([0-9a-f]{2})"


def last_kits(log: Path) -> dict:
    """What each side carried at the last state the log shows of it: items, rupees, keys, heart containers, triforce."""
    import re
    kits = {}
    for m in re.finditer(KIT_RE, log.read_text(errors="replace")):
        kits[m.group(1)] = (bytes.fromhex(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)),
                            int(m.group(6), 16))
    return kits


def load_kit(side: Side, kit) -> None:
    """Give a side the equipment of an earlier run (a cheat, to start again near where a run stopped)."""
    items, rupees, keys, hearts, tri = kit
    if side.name == "NES":
        side.drv.poke(ST.R_ITEMS, list(items))
        side.drv.poke(ST.R_RUPEES, rupees)
        side.drv.poke(ST.R_KEYS, keys)
        side.drv.poke(ST.R_HEARTS, ((hearts - 1) << 4) | (hearts - 1))
        side.drv.poke(ST.R_TRIFORCE, tri)
    else:
        for i, val in enumerate(items):
            if i not in (0x10, 0x11):
                side.drv.poke("ITEMS", val, i)
        side.drv.poke("INV_COMPASS", items[0x10])
        side.drv.poke("INV_MAP", items[0x11])
        side.drv.poke("INV_RUPEES", rupees)
        side.drv.poke("INV_KEYS", keys)
        side.drv.poke("HEART_CONTAINERS", hearts)
        side.drv.poke("HP_HALVES", hearts * 2)
        side.drv.poke("TRIFORCE_PIECES", tri)
        lvl = side.s.level
        if lvl and tri & (1 << (lvl - 1)):
            side.drv.poke("TRIFORCE", 1)
    side.step((), 2)
    side.log(f"{side.name}: kit loaded; {side.s.summary()}")


def compare(a: ST.State, b: ST.State) -> list[str]:
    diffs = []
    if abs(a.rupees - b.rupees) > 30:       # small differences come from the monsters' random drops
        diffs.append(f"rupees: NES {a.rupees} ST {b.rupees}")
    for f in ("mode", "level", "room", "keys", "containers", "triforce"):
        if getattr(a, f) != getattr(b, f):
            diffs.append(f"{f}: NES {getattr(a, f)} ST {getattr(b, f)}")
    for i in COMPARE_SLOTS:
        if a.items[i] != b.items[i]:
            diffs.append(f"item slot {i:#04x}: NES {a.items[i]} ST {b.items[i]}")
    return diffs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tasks", default="gathering")
    ap.add_argument("--out", type=Path, default=PROJECT / "build" / "botrun")
    ap.add_argument("--only", choices=["NES", "ST"])
    ap.add_argument("--from-task", type=int, default=0)
    ap.add_argument("--stop-on-diff", action="store_true")
    ap.add_argument("--resume", help="L:RR: start in room RR of level L with the equipment of --kit, then play on")
    ap.add_argument("--kit", type=Path, help="the log of the run that stopped: its last items, rupees, keys, hearts")
    args = ap.parse_args()
    start = None
    if args.resume:
        lv, rm = args.resume.split(":")
        start = (int(lv), int(rm, 16))
        kits = last_kits(args.kit)
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    logf = open(args.out / "log.txt", "w")

    def log(msg: str) -> None:
        line = f"{time.strftime('%H:%M:%S')} {msg}"
        print(line, flush=True)
        logf.write(line + "\n")
        logf.flush()

    sides = []
    if args.only != "ST":
        sides.append(Side("NES", Nes(), log=log))
    if args.only != "NES":
        prg = build_port(PROJECT / "build" / ("bot_resume" if start else "bot"), start)
        tos = Path(os.environ["TOS"])
        port = Port(args.out / "hatari", prg, tos)
        sides.append(Side("ST", port, ST.PortTables(prg.parent / "generated"), log=log))
    if start and args.only == "ST":
        # the level's map comes from the ROM: read it on a NES that is then put away
        import dungeon
        ns = Side("NES", Nes(), log=log)
        new_game(ns)
        ns.drv.warp(*start)
        ns.wait_play(600)
        dungeon.load_level(ns)
        ns.drv.close()
    for side in sides:
        if start and side.name == "ST":
            side.step((), 60)           # the build begins in the room, past the title
            side.wait_play(600)
            side.cheat = True
        else:
            new_game(side)
            if start:
                side.drv.warp(*start)
                side.wait_play(600)
        if start:
            load_kit(side, kits[side.name])
        log(side.s.summary())

    def watchdog() -> None:
        # a bot that thinks without stepping a frame for minutes is in a loop of its own: say where, and end the run
        import threading
        last = [sum(x.frames for x in sides), time.time()]
        def run() -> None:
            while True:
                time.sleep(30)
                now = sum(x.frames for x in sides)
                if now != last[0]:
                    last[:] = [now, time.time()]
                elif time.time() - last[1] > 300:
                    frames = sys._current_frames()
                    for tid, fr in frames.items():
                        log("WATCHDOG: no frame stepped for 5 minutes; stack:\n" + "".join(traceback.format_stack(fr)))
                    os._exit(3)
        threading.Thread(target=run, daemon=True).start()

    watchdog()
    tasks = routes.ROUTES[args.tasks]
    if start:
        # from the level it starts in to the end of the route
        tasks = [t for t in tasks if t[0].startswith("Level ") and int(t[0].split()[1]) >= start[0]]
    results = []
    for k, (name, fn) in enumerate(tasks):
        if k < args.from_task:
            continue
        log(f"== task {k}: {name}")
        outcome = {}
        for side in sides:
            t0 = side.frames
            try:
                fn(side)
                outcome[side.name] = "ok"
            except Stuck as e:
                outcome[side.name] = f"stuck: {e}"
            except Exception as e:      # noqa: BLE001
                outcome[side.name] = f"error: {e!r}"
                log(traceback.format_exc())
            log(f"   {side.name}: {outcome[side.name]} in {side.frames - t0} frames; {side.s.summary()}")
            if outcome[side.name] != "ok":
                side.drv.snapshot(args.out / f"task{k:02d}_{side.name}.png")
                try:
                    t = side.get_tiles(force=True)
                    (args.out / f"task{k:02d}_{side.name}_tiles.txt").write_text(
                        "\n".join("".join(f"{v:02x}" for v in row) for row in t))
                except Exception:      # noqa: BLE001
                    pass
            if side.name == "ST" and side.drv.crashed():
                log("   ST: the emulator reported an exception: see hatari.log")
        diffs = compare(sides[0].s, sides[1].s) if len(sides) == 2 else []
        if len(sides) == 2 and all(getattr(x, "won", False) for x in sides):
            # both are in the ending: the NES keeps the inventory until Start, the port has saved and cleared it
            diffs = [d for d in diffs if d.startswith("level") or d.startswith("room")]
            log("   both: Zelda saved, the ending is running")
        for d in diffs:
            log(f"   DIFF {d}")
        results.append({"task": name, "outcome": outcome, "diffs": diffs,
                        "states": {s.name: s.s.summary() for s in sides}})
        (args.out / "results.json").write_text(json.dumps(results, indent=1))
        if diffs and args.stop_on_diff:
            break
        if any(v != "ok" for v in outcome.values()) and args.stop_on_diff:
            break
    for side in sides:
        side.drv.close()


if __name__ == "__main__":
    main()
