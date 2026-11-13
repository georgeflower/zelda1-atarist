"""What every overworld screen holds, from the ROM's level block (read in jsnes) and the port's cave and secret
tables: the entrance, the cave's wares, the hidden spot. Development tooling only (tools/bot)."""
from __future__ import annotations
from pathlib import Path
HERE = Path(__file__).resolve().parent
GEN = HERE.parent.parent / "build" / "bot" / "generated"
ITEM = {0: "bombs", 1: "wood sword", 2: "white sword", 3: "magic sword", 4: "food", 5: "recorder", 6: "blue candle",
        7: "red candle", 8: "arrow", 9: "silver arrow", 0xA: "bow", 0xB: "magic key", 0xC: "raft", 0xD: "ladder",
        0xF: "5 rupees", 0x10: "red potion", 0x11: "book", 0x12: "blue ring", 0x13: "red ring", 0x14: "bracelet",
        0x15: "letter", 0x18: "rupee", 0x19: "key", 0x1A: "heart container", 0x1C: "magic shield", 0x1D: "boomerang",
        0x1F: "blue potion", 0x20: "red potion", 0x22: "heart", 0x3F: "-"}
SECRET = {0: "-", 1: "bomb", 2: "burn", 3: "rock", 4: "grave"}


def load(attrs: bytes):
    """attrs: the six 128-byte tables A..F of the overworld level block."""
    caves = (GEN / "cave_table.bin").read_bytes()
    secrets = (GEN / "room_secrets.bin").read_bytes()
    out = {}
    for r in range(128):
        A, B, F = attrs[r], attrs[128 + r], attrs[640 + r]
        b = B & 0xFC
        info = {"entrance": (A & 0xF0, (F & 7) * 16 + 0x4D), "kind": None}
        if b and b < 0x40:
            info["kind"] = f"level {b >> 2}"
        elif b >= 0x40:
            idx = (b - 0x40) >> 2
            rec = caves[idx * 16: idx * 16 + 16]
            info["kind"] = f"cave {idx}"
            info["wares"] = [ITEM.get(i, f"{i:02x}") for i in rec[2:5]]
            info["prices"] = list(rec[5:8])
        s = secrets[r * 8: r * 8 + 8]
        if s[0]:
            info["secret"] = (SECRET.get(s[0], s[0]), s[1])
            info["stairs"] = s[1] if s[0] in (1, 2) else s[3]   # the square that becomes the way in
        out[r] = info
    return out
