#!/usr/bin/env python3
"""Run the ST build headlessly in Hatari and render what it put on screen.

Hatari is driven through its debugger: a breakpoint on a VBL count dumps RAM
and the video registers, and this script decodes the four-bitplane framebuffer
into a PNG. Keys can be held down for a run so movement and room transitions
can be checked without a human at the keyboard.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path

RAM_DUMP = "ram.bin"
MARKER = b"ZELDAST1"
SCREEN_BYTES = 32000
SCREEN_STRIDE = 160
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200
VBL_MARGIN = 60

# Offsets into the variable block, mirroring src/globals.s. Only the few the
# harness reports on are listed.
OFF_KEY_STATES = None  # resolved from the generated assets at runtime

SCANCODES = {
    "up": 0x48,
    "down": 0x50,
    "left": 0x4B,
    "right": 0x4D,
    "w": 0x11,
    "a": 0x1E,
    "s": 0x1F,
    "d": 0x20,
    "k": 0x25,
    "b": 0x30,
    "space": 0x39,
    "tab": 0x0F,
    "return": 0x1C,
    "ctrl": 0x1D,
    "alt": 0x38,
}


def parse_globals_layout(globals_source: Path) -> dict[str, int]:
    """Replay the gvar macro in src/globals.s to recover the variable offsets."""
    offsets: dict[str, int] = {}
    offset = 0
    for line in globals_source.read_text(encoding="utf-8").splitlines():
        # '|' starts an assembler comment, and most gvar lines carry one.
        stripped = line.split("|", 1)[0].strip()
        match = re.match(r"^gvar\s+(\w+)\s*(?:,\s*(\d+))?$", stripped)
        if match:
            offsets[match.group(1)] = offset
            offset += int(match.group(2) or 1)
        elif (alias := re.match(r"^\.equ\s+OFF_(\w+),\s*OFF_(\w+)\s*\+\s*(\d+)$", stripped)):
            offsets[alias.group(1)] = offsets[alias.group(2)] + int(alias.group(3))
        elif stripped == "galign":
            offset = ((offset + 1) // 2) * 2
    if "KEY_STATES" not in offsets:
        raise SystemExit("Failed to parse src/globals.s; the gvar layout did not resolve")
    offsets["__size__"] = offset
    return offsets


# Files put on the emulated hard drive next to the PRG (--hd-file NAME=PATH), e.g. a ZELDA.SAV to load.
HD_FILES: list[tuple[str, Path]] = []


def run_hatari(
    hatari: str,
    tos: Path,
    prg: Path,
    work: Path,
    vbls: int,
    debug_script: str,
    trace: str | None = None,
) -> str:
    hd = work / "hd"
    if hd.exists():
        shutil.rmtree(hd)
    hd.mkdir(parents=True)
    shutil.copy(prg, hd / "ZELDAST.PRG")
    for name, source in HD_FILES:
        shutil.copy(source, hd / name)

    script_path = work / "dbg.ini"
    script_path.write_text(debug_script, encoding="utf-8")

    command = [
        hatari,
        "--tos", str(tos),
        "--machine", "st",
        "--memsize", "1",
        "--cpu-exact", "true",
        "--compatible", "true",
        "--fast-boot", "true",
        "--fast-forward", "true",
        "--sound", "off",
        "--disable-video", "true",
        "--harddrive", str(hd),
        "--auto", "C:\\ZELDAST.PRG",
        "--parse", str(script_path),
        "--log-level", "info",
        # Emulation has to outlive the last breakpoint, or it stops before the
        # condition is ever evaluated.
        "--run-vbls", str(vbls + VBL_MARGIN),
    ]
    if trace:
        command += ["--trace", trace]

    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    result = subprocess.run(
        command, capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL, timeout=600
    )
    return result.stdout + result.stderr


def find_globals(ram: bytes) -> int:
    index = ram.find(MARKER)
    if index < 0:
        raise SystemExit("Could not find the globals marker in RAM; did the program start?")
    if ram.find(MARKER, index + 1) >= 0:
        raise SystemExit("Found the globals marker more than once in RAM")
    return index + len(MARKER)


def video_base(log: str) -> int:
    """Read $FF8201/$FF8203 out of a debugger memory dump line."""
    match = re.search(
        r"^00FF8200: ([0-9a-fA-F]{2}) ([0-9a-fA-F]{2}) ([0-9a-fA-F]{2}) ([0-9a-fA-F]{2})",
        log,
        re.M,
    )
    if not match:
        raise SystemExit("Could not read the video base registers from the Hatari log")
    # The dump starts at $FF8200, so the high and mid base bytes are the
    # second and fourth values.
    return (int(match.group(2), 16) << 16) | (int(match.group(4), 16) << 8)


def write_png(path: Path, pixels: list[list[int]], palette: list[tuple[int, int, int]]) -> None:
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for index in row:
            raw.extend(palette[index])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", len(pixels[0]), len(pixels), 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def decode_screen(ram: bytes, base: int, palette_words: list[int]) -> tuple[list[list[int]], list]:
    screen = ram[base : base + SCREEN_BYTES]
    if len(screen) < SCREEN_BYTES:
        raise SystemExit(f"Video base {base:#08x} is outside the RAM dump")
    palette = [
        (((word >> 8) & 7) * 36, ((word >> 4) & 7) * 36, (word & 7) * 36) for word in palette_words
    ]
    rows = []
    for y in range(SCREEN_HEIGHT):
        offset = y * SCREEN_STRIDE
        row = []
        for group in range(SCREEN_WIDTH // 16):
            planes = struct.unpack(">4H", screen[offset + group * 8 : offset + group * 8 + 8])
            for bit in range(15, -1, -1):
                row.append(sum(((planes[p] >> bit) & 1) << p for p in range(4)))
        rows.append(row)
    return rows, palette


def read_palette(log: str) -> list[int]:
    values: list[int] = []
    for line_base in (0xFF8240, 0xFF8250):
        match = re.search(rf"^00{line_base:04X}: ((?:[0-9a-fA-F]{{2}} ){{16}})", log, re.M)
        if not match:
            raise SystemExit("Could not read the palette from the Hatari log")
        values += [int(token, 16) for token in match.group(1).split()]
    return [(values[i] << 8) | values[i + 1] for i in range(0, 32, 2)]


def parse_key_schedule(spec: str) -> dict[int, list[tuple[str, int]]]:
    """Parse "620:+right,712:-right,712:+up" into {vbl: [(key, state), ...]}."""
    schedule: dict[int, list[tuple[str, int]]] = {}
    for entry in spec.split(","):
        entry = entry.strip()
        if not entry:
            continue
        when, _, action = entry.partition(":")
        action = action.strip()
        if action[:1] == "=":
            # "700:=ENEMY_X.1=100" pokes byte 1 of the variable ENEMY_X.
            target, _, value = action[1:].partition("=")
            schedule.setdefault(int(when), []).append(("=" + target.strip(), int(value, 0)))
            continue
        if action[:1] not in "+-":
            raise SystemExit(f"Key event '{entry}' must start with + or -, e.g. 620:+right")
        key = action[1:].strip().lower()
        if key not in SCANCODES:
            raise SystemExit(f"Unknown key '{key}'; known keys: {', '.join(sorted(SCANCODES))}")
        schedule.setdefault(int(when), []).append((key, 1 if action[0] == "+" else 0))
    return schedule


def build_dev(project: Path, room: int | None, uw: int | None, level: int, cave: bool = False, quest: int = 1) -> Path:
    """Build a PRG that starts where asked (the ZELDA_START_* switches of the Makefile) into build/dev, so the
    normal build is left alone."""
    out = project / "build" / "dev"
    env = dict(os.environ)
    for name in ("ZELDA_START_ROOM", "ZELDA_START_UW", "ZELDA_START_LEVEL", "ZELDA_START_CAVE", "ZELDA_SKIP_INTRO", "ZELDA_QUEST"):
        env.pop(name, None)
    env["ZELDA_SKIP_INTRO"] = "1"           # a scene starts where it says, not at the title
    env["ZELDA_QUEST"] = str(quest)
    if room is not None:
        env["ZELDA_START_ROOM"] = f"{room:#x}"
    if cave:
        env["ZELDA_START_CAVE"] = "1"
    if uw is not None:
        env["ZELDA_START_UW"] = f"{uw:#x}"
        env["ZELDA_START_LEVEL"] = str(level)
    subprocess.run(["make", "-C", str(project), f"BUILD_DIR={out}", f"{out}/ZELDAST.PRG"], check=True, env=env,
                   stdout=subprocess.DEVNULL)
    return out / "ZELDAST.PRG"


def frame_hash(rows: list[list[int]], palette_words: list[int]) -> str:
    """A fingerprint of what is on screen: every pixel's palette index and the 16 colours, so a golden check does
    not depend on a PNG encoder."""
    digest = hashlib.sha256()
    for row in rows:
        digest.update(bytes(row))
    digest.update(struct.pack(">16H", *palette_words))
    return digest.hexdigest()


def main() -> None:
    here = Path(__file__).resolve().parent
    project = here.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prg", type=Path, default=project / "build" / "ZELDAST.PRG")
    parser.add_argument("--out", type=Path, default=project / "build" / "screen.png")
    parser.add_argument("--tos", type=Path, default=Path(os.environ.get("TOS", "")))
    parser.add_argument("--hatari", default=os.environ.get("HATARI", "hatari"))
    parser.add_argument("--vbls", type=int, default=900, help="frame to capture at")
    parser.add_argument(
        "--keys",
        default="",
        help='key events as "<vbl>:+<key>" / "<vbl>:-<key>", comma separated, '
        'e.g. "620:+right,712:-right,712:+up"',
    )
    parser.add_argument(
        "--hold",
        default="",
        help="shorthand for holding keys from --press-at onwards",
    )
    parser.add_argument("--press-at", type=int, default=620)
    parser.add_argument("--hd-file", action="append", default=[], metavar="NAME=PATH",
                        help="copy PATH to the emulated hard drive as NAME before the run (a saved game, say)")
    parser.add_argument("--work", type=Path, default=project / "build" / "shots")
    parser.add_argument("--room", type=lambda v: int(v, 0), help="start on this overworld screen (a dev build in build/dev)")
    parser.add_argument("--uw", type=lambda v: int(v, 0), help="start in this dungeon room, with a sword (a dev build)")
    parser.add_argument("--level", type=int, default=1, help="the dungeon --uw means (default 1)")
    parser.add_argument("--quest", type=int, default=1, choices=(1, 2), help="the quest a --room/--uw build plays (default 1)")
    parser.add_argument("--cave", action="store_true", help="with --room: start inside the cave behind that screen")
    parser.add_argument(
        "--trace",
        default="",
        help="Hatari trace flags for the capture run, e.g. os_base,cpu_exception",
    )
    args = parser.parse_args()
    for item in args.hd_file:
        name, _, source = item.partition("=")
        if not source:
            raise SystemExit("--hd-file wants NAME=PATH")
        HD_FILES.append((name, Path(source)))

    if not str(args.tos) or not args.tos.is_file():
        raise SystemExit("Pass --tos <tos.img> or set the TOS environment variable")
    if args.room is not None or args.uw is not None:
        args.prg = build_dev(project, args.room, args.uw, args.level, args.cave, args.quest)

    schedule = parse_key_schedule(args.keys)
    for key in (name.strip() for name in args.hold.split(",")):
        if key:
            schedule.setdefault(args.press_at, []).append((key.lower(), 1))

    args.work.mkdir(parents=True, exist_ok=True)
    ram_path = args.work / RAM_DUMP
    dump = f"m $ff8200-$ff8204\nm $ff8240-$ff8260\nsavebin {ram_path} 0 $100000\ncont\n"
    capture_script = args.work / "capture.ini"
    capture_script.write_text(dump, encoding="utf-8")

    script = ""
    if schedule:
        # Two passes: the first locates the variable block, the second replays
        # the run and pokes the key-state table on schedule. The program only
        # clears a key slot when a release code arrives and TOS' IKBD handler
        # is masked off, so a poke stays held until another poke clears it.
        first = min(schedule)
        run_hatari(
            args.hatari,
            args.tos,
            args.prg,
            args.work,
            first,
            f"b VBL > {first - 1} :once :file {capture_script}\n",
        )
        globals_addr = find_globals(ram_path.read_bytes())
        layout = parse_globals_layout(project / "src" / "globals.s")
        keys_addr = globals_addr + layout["KEY_STATES"]
        print(f"globals at {globals_addr:#08x}, KEY_STATES at {keys_addr:#08x}")

        for index, (vbl, events) in enumerate(sorted(schedule.items())):
            step = args.work / f"keys{index}.ini"
            pokes = []
            for key, state in events:
                if key.startswith("="):
                    name, _, index = key[1:].partition(".")
                    address = globals_addr + layout[name] + int(index or 0)
                    pokes.append(f"w {address:#x} {state}")
                else:
                    pokes.append(f"w {keys_addr + SCANCODES[key]:#x} {state}")
            step.write_text("\n".join(pokes) + "\ncont\n", encoding="utf-8")
            script += f"b VBL > {vbl - 1} :once :file {step}\n"

    script += f"b VBL > {args.vbls - 1} :once :file {capture_script}\n"
    log = run_hatari(
        args.hatari, args.tos, args.prg, args.work, args.vbls, script, trace=args.trace or None
    )
    (args.work / "hatari.log").write_text(log, encoding="utf-8")

    if "Pterm0()" in log:
        print("WARNING: the program terminated during the run", file=sys.stderr)
    faults = sorted(
        {
            match.group(1)
            for match in re.finditer(r"^cpu exception [23] currpc (\w+)", log, re.M)
            # $FC0EE2 is the TOS boot-time blitter probe, present on every boot.
            if match.group(1) != "fc0ee2"
        }
    )
    if faults:
        print(f"WARNING: bus/address errors at {', '.join(faults)}", file=sys.stderr)

    ram = ram_path.read_bytes()
    base = video_base(log)
    palette_words = read_palette(log)
    rows, palette = decode_screen(ram, base, palette_words)
    write_png(args.out, rows, palette)
    print("PALETTE " + " ".join(f"{word:03x}" for word in palette_words))
    print("FRAMEHASH " + frame_hash(rows, palette_words))

    globals_addr = find_globals(ram)
    layout = parse_globals_layout(project / "src" / "globals.s")
    report = {
        name: ram[globals_addr + layout[name]]
        for name in ("ROOM_ID", "LINK_X", "LINK_Y", "LINK_DIR", "GAME_MODE", "LEVEL", "HOTSPOT_TILE", "COMMIT", "EXIT_GUARD",
                     "HP_HALVES", "ENEMY_COUNT", "ENEMY_X", "ENEMY_Y", "ENEMY_DIR", "ENEMY_TYPE", "ENEMY_HP", "ENEMY_ACTIVE", "ITEM_ACTIVE", "ITEM_ID", "ITEM_X", "ITEM_Y", "IN_CELLAR", "HAS_SWORD", "BEAM_ACTIVE", "BEAM_X", "BEAM_Y", "INV_KEYS", "INV_RUPEES", "INV_BOMBS", "ATTACK", "LINK_HURT", "PROJ_KIND", "PROJ_X", "PROJ_Y", "LINK_HELD", "TRIFORCE", "ENEMY_STATE", "ENEMY_TIMER", "CLOUD_TIMER", "SPARK_K", "FLASH_ON", "WORLD_KILLS", "HELP_COUNT", "BOMB_TIMER", "B_ITEM", "INV_BOOMERANG", "INV_CANDLE", "FIRE_STATE", "FIRE_X", "BLOCK_STATE", "BLOCK_X", "BLOCK_Y", "MENU_KEYS", "ENEMY_STUN", "ENDING_PHASE", "ENDING_STEP", "ENDING_TIMER", "INV_MAP", "INV_COMPASS", "PROJ_KIND",
                     "ROOM_KILLS", "ROOM_OBJ", "SPAWNED_ROOM", "EDGE_PENDING", "HP_FRAC", "INV_CLOCK", "INV_RING", "INV_MAGIC_SHIELD", "INV_ARROW", "INV_POTION", "HEART_CONTAINERS", "HEART_FILL", "FOOD_TIMER", "FLUTE_TIMER", "CHASE_X", "CHASE_Y", "ATTACK_ROD", "HIT_DAMAGE", "MAZE_STEP", "ENEMY_CLOUD", "ENEMY_CLOUD_T")
    }
    print(f"video base {base:#08x}, wrote {args.out}")
    print(" ".join(f"{k}={v:#04x}" for k, v in report.items()))
    hist = ram[globals_addr + layout["ROOM_HIST"]:][:6]
    print("ROOM_HIST " + " ".join(f"{b:02x}" for b in hist) +
          "  OW_KILLS(nonzero) " + " ".join(
              f"{i:02x}:{ram[globals_addr + layout['OW_KILLS'] + i]:#04x}" for i in range(128)
              if ram[globals_addr + layout['OW_KILLS'] + i]))
    print("ITEMS " + " ".join(
        f"[{i}: a={ram[globals_addr + layout['ITEM_ACTIVE'] + i]} id={ram[globals_addr + layout['ITEM_ID'] + i]:#04x} "
        f"({ram[globals_addr + layout['ITEM_X'] + i]:#04x},{ram[globals_addr + layout['ITEM_Y'] + i]:#04x})]" for i in range(3)))
    count = ram[globals_addr + layout["ENEMY_COUNT"]]
    def enemy_byte(name, i):
        return ram[globals_addr + layout[name] + i]

    print("ENEMIES " + " ".join(
        f"[{i}:({enemy_byte('ENEMY_X', i):#04x},{enemy_byte('ENEMY_Y', i):#04x}) t={enemy_byte('ENEMY_TYPE', i):02x} "
        f"s={enemy_byte('ENEMY_STATE', i):02x} tm={enemy_byte('ENEMY_TIMER', i):02x} hp={enemy_byte('ENEMY_HP', i):02x} "
        f"a={enemy_byte('ENEMY_ACTIVE', i)} d={enemy_byte('ENEMY_DIR', i):x} turn={enemy_byte('ENEMY_TURN', i)} dist={enemy_byte('ENEMY_DIST', i)} step={enemy_byte('ENEMY_STEP', i)}]"
        for i in range(count)))
    if "ZORA_ACTIVE" in layout:
        print(f"ZORA_ACTIVE={ram[globals_addr + layout['ZORA_ACTIVE']]} BOULDERS={ram[globals_addr + layout['BOULDERS']]}")
    # Opened door masks of the rooms either side of the first locked door of Level 1.
    print(f"UW_OPEN[0x73]={ram[globals_addr + layout['UW_OPEN'] + 0x73]:#04x} "
          f"UW_OPEN[0x63]={ram[globals_addr + layout['UW_OPEN'] + 0x63]:#04x}")
    # A loop that keeps pace with the VBL advances this once per frame.
    frames = int.from_bytes(ram[globals_addr + layout["FRAME_COUNTER"] :][:2], "big")
    late = int.from_bytes(ram[globals_addr + layout["LATE_FRAMES"] :][:2], "big")
    print(f"FRAME_COUNTER={frames} after {args.vbls} VBLs LATE_FRAMES={late}")
    sync = re.search(r"^00FF8200: ((?:[0-9a-fA-F]{2} ){16})", log, re.M)
    if sync:
        # $FF820A bit 1 set = 50 Hz (PAL), clear = 60 Hz
        mode = int(sync.group(1).split()[10], 16)
        print(f"SYNC_MODE={mode:#04x} ({'50' if mode & 2 else '60'} Hz) MUS_SKIP={ram[globals_addr + layout['MUS_SKIP']]}")


if __name__ == "__main__":
    main()
