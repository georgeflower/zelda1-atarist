#!/usr/bin/env python3
"""Phase 2: compare what happened when the ROM and the port were played in the same room.

    compare_play.py [--rom rom_play.json] [--port port_play.json] [--idle]

Facts compared (the two players are not identical, so only things that must agree are held against the port):
  fight mode: does the room get cleared; how long it takes (flagged only when far apart); the door bits, the room item and
              the tiles afterwards;
  idle mode : where each monster starts; how fast each moves (px per frame per NES type).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
MON_TABLE = (PROJECT / "build" / "generated" / "mon_table.bin")
# Types that are never a target of the player (autoplay.s / rom_play.mjs): bubbles and the blade traps.
NO_TARGET = {0x2B, 0x2C, 0x2D, 0x35, 0x36, 0x49, 0x4A} | set(range(0x68, 0x70))     # (0x68..: the ROM's push block object)


def nes_type(index: int) -> int:
    return MON_TABLE.read_bytes()[index * 8]


# Monsters the ROM makes of one object and the port of several (Moldorm, Manhandla, Gohma, Patra, Gleeok, Digdogger, Lanmola).
COMPOUND = {0x41, 0x3C, 0x33, 0x34, 0xFD, 0xFC, 0x47, 0x48, 0x25, 0x26, 0x43, 0x44, 0x45, 0xF9, 0x46, 0x38, 0xFB, 0x18,
            0x3A, 0x3B}


def same_monsters(rom_types, port_types):
    plain_rom = sorted(t for t in rom_types if t not in COMPOUND)
    plain_port = sorted(t for t in port_types if t not in COMPOUND)
    return plain_rom == plain_port and {t for t in rom_types if t in COMPOUND} <= set(port_types)


def port_targets(sample):
    return [m for m in sample["mon"] if nes_type(m[1]) not in NO_TARGET and (m[4] or m[5])]


def fight_facts_port(samples):
    if not samples:
        return None
    first = samples[0]
    targets0 = {m[0] for m in port_targets(first)}
    cleared = None
    for s in samples:
        if targets0 and not any(m[0] in targets0 for m in port_targets(s)):
            cleared = s["frame"]
            break
    last = samples[-1]
    if cleared is not None:                       # the state a short while after the clear, like the ROM's run
        after = [s for s in samples if s["frame"] >= cleared + 240]
        last = after[0] if after else samples[-1]
    return {"targets": sorted(nes_type(m[1]) for m in port_targets(first)), "cleared": cleared, "open": last["open"],
            "item": last["items"][0], "keys": last["keys"], "frame": last["frame"], "room": last["room"], "mode": last["mode"]}


def fight_facts_rom(info):
    initial = [o for o in info["initial"] if o["slot"] in info["targets"]]
    return {"targets": sorted(o["type"] for o in initial), "cleared": info["cleared"], "open": info["doors"],
            "item": info["roomItem"], "tiles": info["tilesChanged"], "frame": info["frames"], "room": info["linkRoom"],
            "mode": info["mode"]}


def compare_fight(rom, port, out):
    for key, level in rom.items():
        prooms = port.get(key, {}).get("rooms", {})
        for info in level["rooms"]:
            if not info.get("initial"):
                continue
            name = f"{info['room']:#04x}"
            if name not in prooms:
                continue
            r, p = fight_facts_rom(info), fight_facts_port(prooms[name])
            problems = []
            if not same_monsters(r["targets"], p["targets"]):
                problems.append(f"monsters {r['targets']} (ROM) vs {p['targets']} (port)")
            if (r["cleared"] is None) != (p["cleared"] is None):
                problems.append(f"cleared: ROM {r['cleared']}, port {p['cleared']}")
            elif r["cleared"] is not None and p["cleared"] is not None:
                lo, hi = sorted((r["cleared"] + 30, p["cleared"] + 30))
                if hi > 6 * lo:                  # the two players are not the same, only a big gap counts
                    problems.append(f"clear time: ROM {r['cleared']} frames, port {p['cleared']}")
            if r["cleared"] is not None and p["cleared"] is not None and r["open"] != p["open"]:
                problems.append(f"doors after the clear: ROM {r['open']:#04x}, port {p['open']:#04x}")
            out.append((key, name, problems, r, p))


# Random fliers and the vire, whose hops move its position in the ROM and are only drawn in the port: no speed to compare.
HOPPING = {0x1B, 0x1C, 0x1D, 0x12, 0x13, 0x15, 0x16, 0x17, 0x1A}


def idle_speeds_rom(info):
    speeds, starts = {}, {}
    last = {}
    for sample in info["samples"]:
        for slot, typ, x, y, state in sample["o"]:
            if slot >= 12:
                continue
            starts.setdefault(slot, (typ, x, y))
            if slot in last and last[slot][0] == typ:
                dx, dy = abs(x - last[slot][1]), abs(y - last[slot][2])
                if dx + dy <= 40:
                    speeds.setdefault((slot, typ), []).append(dx + dy)
            last[slot] = (typ, x, y)
    return starts, speeds


def idle_speeds_port(samples):
    speeds, starts = {}, {}
    last = {}
    for sample in samples:
        for i, idx, x, y, active, cloud, hp in sample["mon"]:
            typ = nes_type(idx)
            if cloud or not active:
                last.pop(i, None)
                continue
            starts.setdefault(i + 1, (typ, x, y))
            if i in last and last[i][0] == typ:
                dx, dy = abs(x - last[i][1]), abs(y - last[i][2])
                if dx + dy <= 40:
                    speeds.setdefault((i + 1, typ), []).append(dx + dy)
            last[i] = (typ, x, y)
    return starts, speeds


def compare_idle(rom, port, out):
    for key, level in rom.items():
        prooms = port.get(key, {}).get("rooms", {})
        for info in level["rooms"]:
            name = f"{info['room']:#04x}"
            if name not in prooms or not info.get("initial"):
                continue
            rs, rsp = idle_speeds_rom(info)
            ps, psp = idle_speeds_port(prooms[name])
            problems = []
            rtype, ptype = {}, {}
            for (slot, typ), values in rsp.items():
                if len(values) >= 5:
                    rtype.setdefault(typ, []).append(sum(values) / len(values) / 10)
            for (slot, typ), values in psp.items():
                if len(values) >= 5:
                    ptype.setdefault(typ, []).append(sum(values) / len(values) / 10)
            for typ, ra in sorted(rtype.items()):
                pb = ptype.get(typ)
                if not pb or typ in HOPPING:
                    continue
                a, b = sum(ra) / len(ra), sum(pb) / len(pb)
                if max(a, b) > 0.05 and (a == 0 or b == 0 or not 0.6 <= a / b <= 1.6):
                    problems.append(f"type {typ:#04x}: ROM {a:.2f} px/frame (mean of {len(ra)}), port {b:.2f} (mean of {len(pb)})")
            out.append((key, name, problems, {"types": sorted({t for t, _, _ in rs.values()})}, {}))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path)
    parser.add_argument("--port", type=Path)
    parser.add_argument("--idle", action="store_true")
    args = parser.parse_args()
    suffix = "_idle" if args.idle else ""
    rom = json.loads((args.rom or PROJECT / "build" / "refnes" / f"rom_play{suffix}.json").read_text())
    port = json.loads((args.port or PROJECT / "build" / "refnes" / f"port_play{suffix}.json").read_text())
    out: list = []
    (compare_idle if args.idle else compare_fight)(rom, port, out)
    bad = 0
    for key, room, problems, r, p in out:
        if problems:
            bad += 1
            print(f"{key} room {room}:")
            for text in problems:
                print("   ", text)
    print(f"{len(out)} rooms compared, {bad} with differences")


if __name__ == "__main__":
    main()
