"""One view of the game for the bot, read from either side: the ROM in jsnes (Nes) or the port in Hatari (Port).
Both keep NES coordinates and the ROM's item slots, so most fields are the same numbers read from different places.
Development tooling only (tools/bot)."""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

PLAY, SCROLL, CAVE, MENU, INTRO, DEATH, OTHER = "play", "scroll", "cave", "menu", "intro", "death", "other"

# NES RAM (src/Variables.inc)
R_LEVEL, R_MODE, R_SUB = 0x10, 0x12, 0x13
R_X, R_Y, R_DIR, R_TYPE, R_META, R_HP, R_INVINC = 0x70, 0x84, 0x98, 0x34F, 0x405, 0x485, 0x4F0
R_ROOM = 0xEB
R_ITEMS = 0x657
R_RUPEES, R_KEYS, R_HEARTS, R_PARTIAL = 0x66D, 0x66E, 0x66F, 0x670
R_TRIFORCE = 0x671
R_TILES = 0x6530
R_ATTRS = 0x687E          # six tables of 128: A B C D E F
R_SELECTED = 0x656


@dataclass
class Enemy:
    slot: int
    x: int
    y: int
    ntype: int            # NES object type
    hp: int = 0


@dataclass
class State:
    side: str
    frame: int = 0
    mode: str = OTHER
    level: int = 0
    room: int = 0
    x: int = 0
    y: int = 0
    dir: int = 0
    items: bytes = b""
    rupees: int = 0
    keys: int = 0
    containers: int = 0
    hp_halves: int = 0
    triforce: int = 0
    enemies: list[Enemy] = field(default_factory=list)
    raw_mode: int = 0
    spawning: int = 0       # monsters still in their spawn clouds

    @property
    def sword(self) -> int:
        return self.items[0] if self.items else 0

    def summary(self) -> str:
        return (f"{self.side}: {self.mode}/{self.raw_mode:x} L{self.level} room {self.room:02X} ({self.x},{self.y}) items "
                f"{self.items.hex()} rupees {self.rupees} keys {self.keys} hearts {self.containers} tri {self.triforce:02x}")


# -- the ROM ------------------------------------------------------------------------------------------------------
def nes_state(n) -> State:
    m = n.mem
    mode = m[R_MODE]
    s = State("NES", n.frame)
    s.raw_mode = mode
    s.mode = {5: PLAY, 7: SCROLL, 0xB: CAVE, 0x11: DEATH, 0: INTRO, 1: INTRO, 0xE: INTRO, 0xF: INTRO}.get(mode, OTHER)
    if mode == 9 and m[0x11] == 1:
        s.mode = PLAY             # mode 9 is a cellar; once it is set up Link walks there as in mode 5
    if mode == 5 and m[R_SUB] != 0:
        s.mode = MENU if m[R_SUB] in range(1, 0x20) else OTHER
    s.level, s.room = m[R_LEVEL], m[R_ROOM]
    s.x, s.y, s.dir = m[R_X], m[R_Y], m[R_DIR]
    s.items = bytes(m[R_ITEMS:R_ITEMS + 32])
    s.rupees, s.keys = m[R_RUPEES], m[R_KEYS]
    s.containers = (m[R_HEARTS] >> 4) + 1
    s.hp_halves = (m[R_HEARTS] & 0x0F) * 2 + (2 if m[R_PARTIAL] >= 0x80 else (1 if m[R_PARTIAL] else 0))
    s.triforce = m[R_TRIFORCE]
    for i in range(1, 12):
        t = m[R_TYPE + i]
        if 0 < t < 0x4B and m[R_META + i] == 0:
            s.enemies.append(Enemy(i, m[R_X + i], m[R_Y + i], t, m[R_HP + i]))
        elif 0 < t < 0x4B and m[R_META + i] in (1, 2, 3):
            s.spawning += 1
    return s


def nes_tiles(n) -> list[list[int]]:
    t = n.read(R_TILES, 704)
    return [[t[c * 22 + r] for c in range(32)] for r in range(22)]


# -- the port -----------------------------------------------------------------------------------------------------
class PortTables:
    def __init__(self, gen: Path):
        self.mon_table = (gen / "mon_table.bin").read_bytes()

    def ntype(self, index: int) -> int:
        t = self.mon_table[index * 8] if index * 8 < len(self.mon_table) else 0
        return SYNTHETIC.get(t, t)


# the port's own monster types for a boss with fewer parts (actors.SYNTHETIC_TYPES): the NES type they stand for
SYNTHETIC = {0xFD: 0x33, 0xFC: 0x34, 0xFB: 0x38, 0xF9: 0x43}


def port_state(p, tables: PortTables) -> State:
    v = p.v
    mode = v("GAME_MODE")
    s = State("ST", p.frame)
    s.raw_mode = mode
    s.mode = {0: PLAY, 1: SCROLL, 2: CAVE, 3: MENU, 4: INTRO, 5: DEATH, 6: OTHER}.get(mode, OTHER)
    s.level, s.room = v("LEVEL"), v("ROOM_ID")
    if s.level and v("IN_CELLAR"):
        s.room = v("CELLAR_ROOM")          # the port keeps the room above in ROOM_ID; the ROM's RoomId is the cellar's
    s.x, s.y, s.dir = v("LINK_X"), v("LINK_Y"), v("LINK_DIR")
    o = p.layout["ITEMS"]
    items = bytearray(p.g[o:o + 32])
    items[0x10], items[0x11] = v("INV_COMPASS"), v("INV_MAP")   # the ROM's InvCompass/InvMap slots; the port keeps them apart
    s.items = bytes(items)
    s.rupees, s.keys = v("INV_RUPEES"), v("INV_KEYS")
    s.containers = v("HEART_CONTAINERS")
    s.hp_halves = v("HP_HALVES")
    s.triforce = v("TRIFORCE_PIECES")
    for i in range(v("ENEMY_COUNT")):
        if v("ENEMY_ACTIVE", i) == 1 and v("ENEMY_CLOUD", i) == 0:
            s.enemies.append(Enemy(i, v("ENEMY_X", i), v("ENEMY_Y", i), tables.ntype(v("ENEMY_TYPE", i)), v("ENEMY_HP", i)))
        elif v("ENEMY_CLOUD", i) in (1, 2, 3):
            s.spawning += 1
    return s


def port_tiles(p) -> list[list[int]]:
    """The live tile map, as NES tiles, 22 rows of 32."""
    if p.v("LEVEL"):
        o = p.layout["UW_MAP"]
        ids = p.g[o:o + 704]
        ptr = int.from_bytes(p.g[p.layout["UWP_TILE_NES"]:p.layout["UWP_TILE_NES"] + 4], "big")
        nes = p.peek_mem(ptr, 256)
        return [[nes[ids[r * 32 + c]] for c in range(32)] for r in range(22)]
    room = p.v("ROOM_ID")
    squares = p.peek_mem(p.base + p.sym["room_maps"] + room * 176, 176)
    meta = p.peek_mem(p.base + p.sym["metatile_tiles"], 4 * 256)
    out = [[0] * 32 for _ in range(22)]
    for i, sq in enumerate(squares):
        r, c = divmod(i, 16)
        q = meta[sq * 4: sq * 4 + 4]
        out[r * 2][c * 2], out[r * 2][c * 2 + 1], out[r * 2 + 1][c * 2], out[r * 2 + 1][c * 2 + 1] = q
    return out
