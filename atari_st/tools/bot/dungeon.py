"""Dungeons for the bot: the level's map from the ROM's level block (read from the NES side's RAM on the way in and
kept for the ST side), fighting, doors (open, false, key, bombable, shutter), the room item, push blocks, stairs and
cellars, and an explorer that walks every room of a level, takes every item and the triforce last.
Development tooling only (tools/bot)."""
from __future__ import annotations

import collections
import os
from pathlib import Path

import state as ST
from brain import DELTA, DIRBIT, DOWN, LEFT, RIGHT, UP, Side, Stuck

E, W, S, N = 0, 1, 2, 3                       # door order of the ROM's attributes (underworld.door_type)
DOOR_DIR = {E: RIGHT, W: LEFT, S: DOWN, N: UP}
STEP = {E: 1, W: -1, S: 16, N: -16}
OPPOSITE = {E: W, W: E, S: N, N: S}
OPEN, WALL, FALSE1, FALSE2, BOMB, KEY1, KEY2, SHUTTER = range(8)
DOOR_NODE = {N: (0x78, 0x5D), S: (0x78, 0xBD), W: (0x20, 0x8D), E: (0xD0, 0x8D)}
NO_ITEM = 0x03
DEBUG = bool(os.environ.get("BOT_DEBUG"))
TRIFORCE = 0x1B
# monsters the bot does not try to kill: blade traps, bubbles, the statues' and the old man's fire
UNKILLABLE = {0x49, 0x4A, 0x2B, 0x2C, 0x2D, 0x40, 0x36, 0x37}   # 0x36: Grumble, fed, not fought; 0x37: Zelda
GRUMBLE = 0x36

LEVELS: dict[int, "Level"] = {}


class Level:
    def __init__(self, number: int, attrs: bytes, info: bytes):
        self.number = number
        self.a, self.b = attrs[0:128], attrs[128:256]
        self.c, self.d, self.e, self.f = attrs[256:384], attrs[384:512], attrs[512:640], attrs[640:768]
        self.start = info[0x2F]
        self.triforce = info[0x30]
        self.item_pos = info[0x29:0x2D]
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        import underworld
        # the listed cellars and, as the ROM's unbounded scan finds it, Level 3's raft cellar
        self.cellars = underworld.cellar_rooms(bytes(info), bytes(self.d), bytes(self.a), bytes(self.b), self.start)

    def door(self, room: int, d: int) -> int:
        a, b = self.a[room], self.b[room]
        return ((b >> 2) & 7, (b >> 5) & 7, (a >> 2) & 7, (a >> 5) & 7)[d]

    def item(self, room: int) -> int:
        return self.e[room] & 0x1F

    def item_xy(self, room: int):
        v = self.item_pos[(self.f[room] >> 4) & 3]
        x, y = v & 0xF0, ((v & 0x0F) << 4) + 0x3D
        if self.item(room) == TRIFORCE:
            x -= 8
        return x, y

    def stairs_to(self, room: int):
        """The cellar a room's stairs lead to, if any."""
        for c in self.cellars:
            if room in (self.a[c], self.b[c]):
                return c
        return None

    def is_cellar(self, room: int) -> bool:
        return (self.d[room] & 0x3F) in (0x3E, 0x3F)


def load_level(side: Side) -> Level:
    lv = side.s.level
    if lv not in LEVELS:
        if side.name != "NES":
            raise RuntimeError("the level's map is read on the NES side first")
        LEVELS[lv] = Level(lv, side.drv.read(ST.R_ATTRS, 768), side.drv.read(0x6B7E, 0x100))
    return LEVELS[lv]


# -- reading the room -----------------------------------------------------------------------------------------------
def foes(side: Side):
    f = [e for e in side.s.enemies if e.ntype not in UNKILLABLE]
    if any(e.ntype == 0x3E for e in f) and room_item(side):
        f = [e for e in f if e.ntype != 0x3E]       # Ganon burning: his ashes and the Triforce of Power are down
    return f


def room_item(side: Side):
    """(x, y) of the room's item lying on the floor, or None."""
    if side.name == "NES":
        m = side.drv.mem
        if m[0xAC + 0x13] == 0 and m[0x34F + 0x13] == 0 and m[0xAB] not in (0xFF, NO_ITEM):
            return (m[0x70 + 0x13], m[0x84 + 0x13])
        return None
    d = side.drv
    for i in range(3):
        if d.v("ITEM_ACTIVE", i) == 2:
            return (d.v("ITEM_X", i), d.v("ITEM_Y", i))
    return None


def stairs_node(side: Side):
    t = side.get_tiles(force=True)
    for r in range(22):
        for c in range(31):
            if t[r][c] == 0x70 and t[r][c + 1] in (0x72, 0x71):
                return (c * 8, r * 8 + 0x40 - 3)
    return None


# -- fighting --------------------------------------------------------------------------------------------------------
GANON = 0x3E
GANON_DOORS = frozenset({(0x52, N), (0x41, E), (0x43, W), (0x32, S)})   # the ways into $42, Ganon's room


def rescue_zelda(side: Side) -> bool:
    """Her guard fires are out: step up to her (X $70-$80, Y $95) and let the ending run (the thanks, the credits)."""
    side.log(f"{side.name}: to Zelda")
    try:
        side.walk({(0x78, 0x95)}, limit=1500)
        side.hold_until({UP}, lambda st: st.mode != ST.PLAY, 60)
    except Stuck:
        pass                                # her scene began on the way: the walk stops there
    side.step((), 600)
    if side.s.mode == ST.PLAY and side.s.level == 9:
        side.log(f"{side.name}: Zelda did not speak")
        return False
    side.won = True
    side.log(f"{side.name}: Zelda is saved (mode {side.s.raw_mode:#x})")
    return True


def ganon_brown(side: Side, e) -> int:
    """Ganon's brown count (the ROM's ObjState; the port's ENEMY_STATE): above 0 the silver arrow kills him."""
    if side.name == "NES":
        return side.drv.mem[0xAC + e.slot]
    return side.drv.v("ENEMY_STATE", e.slot)


def fight_ganon(side: Side, limit: int = 6000) -> bool:
    """Ganon is 32 px wide, his middle at +$10,+$10. Hidden, he is struck by the sword where he walks; when the blows
    have used up his hit points he turns brown and stands: then a silver arrow."""
    spent = 0
    room = (side.s.level, side.s.room)
    while spent < limit:
        if (side.s.level, side.s.room) != room or side.s.mode != ST.PLAY:
            return False
        g = [e for e in side.s.enemies if e.ntype == GANON]
        if not g or room_item(side):
            return True
        e = g[0]
        cx, cy = e.x + 8, e.y + 8          # where Link stands to be level with his middle
        brown = ganon_brown(side, e)
        s = side.s
        dx, dy = cx - s.x, cy - s.y
        if abs(dx) < 6 and 0x10 < abs(dy) < 0x70:
            d = DOWN if dy > 0 else UP
        elif abs(dy) < 6 and 0x10 < abs(dx) < 0x70:
            d = RIGHT if dx > 0 else LEFT
        else:
            d = None
        if d and brown:
            side.face(d)
            if side.s.rupees < 10:
                side.give("rupees", 100)
            side.select_b("bow")
            side.press("B", 2, 12)
            spent += 20
            continue
        if not brown and abs(dx) < 0x18 and abs(dy) < 0x18:
            # close: swing towards him
            d = (RIGHT if dx > 0 else LEFT) if abs(dx) >= abs(dy) else (DOWN if dy > 0 else UP)
            side.face(d)
            side.step({"A"}, 2)
            side.step((), 6)
            spent += 10
            continue
        if brown:
            goal = lambda n: (abs(n[0] - cx) < 6 and 0x10 < abs(n[1] - cy) < 0x60) or (
                abs(n[1] - cy) < 6 and 0x10 < abs(n[0] - cx) < 0x60)
        else:
            goal = lambda n: abs(n[0] - cx) < 0x10 and abs(n[1] - cy) < 0x10
        moves = side.path(goal)
        if moves:
            side.step({moves[0]}, 4)
            spent += 4
        else:
            side.step({"A"}, 2)
            side.step((), 4)
            spent += 6
    return not [e for e in side.s.enemies if e.ntype == GANON] or room_item(side) is not None


def at_door_edge(side: Side, d: str) -> bool:
    """Link in a dungeon on the edge of the room by a doorway, d pointing out through it."""
    s = side.s
    if not s.level:
        return False
    return ((d == LEFT and s.x <= 0x20 and s.y == 0x8D) or (d == RIGHT and s.x >= 0xD0 and s.y == 0x8D)
            or (d == UP and s.y <= 0x5D and s.x == 0x78) or (d == DOWN and s.y >= 0xBD and s.x == 0x78))


def fight(side: Side, limit: int = 2400, keep_going=lambda s: True) -> bool:
    """Kill the room's monsters: line up with the nearest one and swing (with full hearts the sword shoots).
    Returns True when none is left."""
    spent = 0
    room = (side.s.level, side.s.room)
    fluted = -1000
    while spent < limit:
        if any(e.ntype in DIGDOGGER for e in side.s.enemies) and side.s.items[5] and spent - fluted > 300:
            # Digdogger shrinks at the recorder's tune (and splits); only then does the sword hurt it
            side.select_b("flute")
            side.press("B", 2, 120)
            spent += 122
            fluted = spent
            side.log(f"{side.name}: played the recorder at Digdogger")
        if (side.s.level, side.s.room) != room or side.s.mode != ST.PLAY:
            return False
        targets = foes(side)
        if any(e.ntype == GANON for e in targets):
            return fight_ganon(side, max(limit - spent, 3000))
        if not targets and side.s.spawning and spent < limit - 20:
            side.step((), 10)                # more on the way (spawn clouds, Digdogger splitting at the tune)
            spent += 10
            continue
        if not targets or not keep_going(side.s):
            return not targets
        s = side.s
        t = min(targets, key=lambda e: abs(e.x - s.x) + abs(e.y - s.y))
        dx, dy = t.x - s.x, t.y - s.y
        below_only = t.ntype in GOHMA                 # Gohma's eye looks down: arrows from above hit his shell
        if abs(dx) < 8 and abs(dy) < 0x60 and not (below_only and dy > 0):
            d = DOWN if dy > 0 else UP
        elif abs(dy) < 8 and abs(dx) < 0x60 and not below_only:
            d = RIGHT if dx > 0 else LEFT
        else:
            d = None
        if d and at_door_edge(side, d):
            d = None            # a tap that way would walk him out through the doorway (the port leaves the room at once)
        if d:
            if s.dir != DIRBIT[d]:
                side.step({d}, 1)
                spent += 1
            spent += strike(side, t, d)
            continue
        # walk to a node level with it, on the axis that is nearer
        if below_only:
            goal = lambda n, t=t: abs(n[0] - t.x) < 8 and 0x18 < n[1] - t.y < 0x50
        else:
            goal = lambda n, t=t: (abs(n[0] - t.x) < 8 and abs(n[1] - t.y) < 0x50) or (
                abs(n[1] - t.y) < 8 and abs(n[0] - t.x) < 0x50)
        moves = side.path(goal)
        if moves is not None and not moves and ((s.y - 5) % 8 or s.x % 8):
            # at a goal square but between grid lines (a level line 8 px off): step onto the line
            if (s.y - 5) % 8:
                side.step({UP if (s.y - 5) % 8 < 4 else DOWN}, 1)
            else:
                side.step({LEFT if s.x % 8 < 4 else RIGHT}, 1)
            spent += 1
            continue
        if not moves:
            side.step({"A"}, 2)
            side.step((), 6)
            spent += 8
            continue
        for _ in range(6):          # one grid step, no further: past a node by the doorway he would walk out
            if at_door_edge(side, moves[0]):
                break
            p0 = (side.s.x, side.s.y)
            side.step({moves[0]}, 1)
            spent += 1
            if (side.s.x, side.s.y) != p0 and side.s.x % 8 == 0 and (side.s.y - 5) % 8 == 0:
                break
        if at_door_edge(side, moves[0]):
            side.step((), 1)
            spent += 1
    return not foes(side)


DODONGO = (0x31, 0x32)
DIGDOGGER = (0x38, 0x39)
GOHMA = (0x33, 0x34)
POLS_VOICE = (0x2E,)


def weapon(ntype: int) -> str:
    """What hurts it: the sword for most, bombs for a Dodongo, arrows for Gohma and Pols Voice."""
    if ntype in DODONGO:
        return "bomb"
    if ntype in GOHMA + POLS_VOICE:
        return "bow"
    if ntype == 0x3E:
        return "ganon"
    return "A"


def strike(side: Side, t, d: str) -> int:
    """One blow at t, already lined up and facing d. Returns the frames spent."""
    w = weapon(t.ntype)
    dist = abs(t.x - side.s.x) + abs(t.y - side.s.y)
    if w == "bomb":
        if dist > 0x38:
            side.step((), 4)              # let it come closer
            return 4
        if side.s.items[1] < 2:
            side.give("bombs", 8)
        side.select_b("bomb")
        side.press("B", 2, 2)
        back = {UP: DOWN, DOWN: UP, LEFT: RIGHT, RIGHT: LEFT}[d]
        side.step({back}, 20)
        side.step((), 50)                 # the bomb goes off; a stunned Dodongo falls to the sword
        side.step({d}, 1)
        for _ in range(3):
            side.step({"A"}, 2)
            side.step((), 6)
        return 100
    if w == "ganon":
        side.step({"A"}, 2)
        side.step((), 6)
        if side.s.items[3] and side.s.items[2] >= 2:      # the silver arrow finishes him once a blow has turned him brown
            if side.s.rupees < 10:
                side.give("rupees", 100)
            side.select_b("bow")
            side.press("B", 2, 10)
        return 20
    if w == "bow" and side.s.items[3]:
        if side.s.rupees < 10:
            side.give("rupees", 100)
        side.select_b("bow")
        side.press("B", 2, 10)
        return 12
    side.step({"A"}, 2)
    side.step((), 6)
    return 8


# -- doors -------------------------------------------------------------------------------------------------------------
def go_through(side: Side, lvl: Level, d: int) -> bool:
    s = side.s
    room = s.room
    kind = lvl.door(room, d)
    node = DOOR_NODE[d]
    dd = DOOR_DIR[d]
    if kind == WALL:
        raise Stuck(f"{side.name}: no door {dd} in room {room:02X}")
    if kind == SHUTTER and foes(side):
        fight(side)
    if kind == SHUTTER and (lvl.d[room] & 0x40) and not foes(side):
        push_block(side)                 # trigger 4: the shutters open when the block is pushed (no-op once it has been)
    if kind in (KEY1, KEY2) and side.s.keys == 0 and not side.s.items[13]:
        side.give("keys", 1)
    side.align()
    if side.path({node}) is None:
        side.log(f"{side.name}: no way to the {dd} door of room {room:02X} from ({side.s.x},{side.s.y})")
        return None                                  # this part of the room does not reach that door
    side.walk({node}, limit=3000)
    if kind == BOMB:
        if side.s.items[1] == 0:
            side.give("bombs", 4)
        side.select_b("bomb")
        side.face(dd)
        side.press("B", 2, 2)
        back = {UP: DOWN, DOWN: UP, LEFT: RIGHT, RIGHT: LEFT}[dd]
        side.step({back}, 24)
        side.step((), 90)
        side.walk({node}, limit=600)
    before = (side.s.level, side.s.room)
    side.hold_until({dd}, lambda st: (st.level, st.room) != before, 400)
    side.wait_play()
    if DEBUG and (side.s.level, side.s.room) == before:
        side.log(f"{side.name}: held {dd} at the door: Link at ({side.s.x},{side.s.y}) hearts {side.s.containers}; foes "
                 + " ".join(f"{e.ntype:02X}@{e.x},{e.y}" for e in side.s.enemies))
        side.drv.snapshot(Path(os.environ.get("BOT_SHOTS", "/tmp")) / f"{side.name}_{room:02X}_{dd}.png")
    return (side.s.level, side.s.room) != before


# -- the explorer --------------------------------------------------------------------------------------------------
def take_item(side: Side) -> bool:
    xy = room_item(side)
    if not xy:
        return False
    x, y = xy
    before = (side.s.items, side.s.keys, side.s.containers, side.s.triforce)
    goal = lambda n: abs(n[0] - x) <= 8 and abs(n[1] - y) <= 8
    side.walk(goal, limit=1500)
    side.step((), 4)
    took = (side.s.items, side.s.keys, side.s.containers, side.s.triforce) != before or room_item(side) is None
    side.step((), 140 if took else 1)          # some items are held up for a while
    return took


def push_block(side: Side) -> bool:
    """Push the room's block ($B0 tiles): from each side in turn until the map changes."""
    t = side.get_tiles(force=True)
    blocks = [(c, r) for r in range(22) for c in range(31) if t[r][c] == 0xB0]
    if not blocks:
        return False
    before = [row[:] for row in t]
    for (c, r) in blocks:
        bx, by = c * 8, r * 8 + 0x40 - 3
        for d, (sx, sy) in ((UP, (bx, by + 16)), (LEFT, (bx + 16, by)), (RIGHT, (bx - 16, by)), (DOWN, (bx, by - 16))):
            if not side.node_free(sx, sy) or side.path({(sx, sy)}) is None:
                continue
            if DEBUG:
                side.log(f"{side.name}: push {d} from ({sx},{sy}); Link at ({side.s.x},{side.s.y}); foes "
                         + " ".join(f"{e.ntype:02X}@{e.x},{e.y}" for e in side.s.enemies))
            side.approach((sx, sy), d)
            side.hold_until({d}, lambda s: False, 40)
            side.step((), 30)
            if side.get_tiles(force=True) != before:
                side.log(f"{side.name}: pushed the block at ({bx},{by}) {d} in room {side.s.room:02X}")
                return True
    return False


def _hold_until_still(side: Side, d: str, limit: int = 300) -> None:
    room, still, last = side.s.room, 0, (side.s.x, side.s.y)
    for _ in range(limit):
        side.step({d}, 1)
        if side.s.room != room or side.s.mode != ST.PLAY:
            return
        still = still + 1 if (side.s.x, side.s.y) == last else 0
        last = (side.s.x, side.s.y)
        if still >= 8:
            return


def _move_x(side: Side, x: int, limit: int = 400) -> None:
    room = side.s.room
    for _ in range(limit):
        if abs(side.s.x - x) <= 1 or side.s.room != room:
            return
        side.step({RIGHT} if side.s.x < x else {LEFT}, 1)


def cellar(side: Side, lvl: Level) -> None:
    """A cellar is seen from the side: ladders (tile $6F) and floors. The ladders that reach the top row are the ways
    out; a treasure cellar has one, and a short ladder up to the shelf where its item lies. Take the item, then climb
    out by the other way out (a tunnel) or the one he came down (a treasure cellar)."""
    room = side.s.room
    side.wait_play(900)
    side.log(f"{side.name}: cellar {room:02X}: mode {side.s.mode} ({side.s.raw_mode:#x})")
    side.step((), 4)
    t = side.get_tiles(force=True)
    exits = [c * 8 for c in range(31) if t[2][c] == 0x6F and t[2][c + 1] == 0x6F]
    shelf = [c * 8 for c in range(31) if t[12][c] == 0x6F and t[12][c + 1] == 0x6F and t[2][c] != 0x6F]
    came = min(exits, key=lambda x: abs(x - side.s.x)) if exits else side.s.x
    side.log(f"{side.name}: cellar {room:02X}: in at ({side.s.x},{side.s.y}), ladders out {exits}, to the shelf {shelf}")
    _hold_until_still(side, DOWN)
    xy = room_item(side)
    for attempt in range(3):            # a keese in the way can spoil a try: up to three
        xy = room_item(side)
        if not (xy and shelf) or side.s.room != room:
            break
        before = side.s.items
        _move_x(side, shelf[0])
        _hold_until_still(side, UP)
        for _ in range(300):
            if side.s.items != before or side.s.room != room:
                break
            side.step({RIGHT} if side.s.x < xy[0] else {LEFT}, 1)
        side.step((), 150)
        _move_x(side, shelf[0])
        _hold_until_still(side, DOWN)
        if side.s.items != before:
            break
        side.log(f"{side.name}: cellar {room:02X}: the item is still there (try {attempt + 1})")
    out = [x for x in exits if x != came] or [came]
    _move_x(side, out[0])
    _hold_until_still(side, UP, 600)
    side.wait_play()
    side.log(f"{side.name}: out of cellar {room:02X} into {side.s.room:02X}; {side.s.summary()}")


def explore(side: Side, limit_rooms: int = 300) -> None:
    """Walk the whole level: every room, every item, the cellars, and the triforce last."""
    lvl = load_level(side)
    visited, used_stairs, taken, pushed = set(), set(), set(), set()
    stair_uses = collections.Counter()    # a tunnel taken back and forth: after three trips it is left alone
    fails, bad = collections.Counter(), set()   # doors that would not open: tried three times, then left alone
    cut = set()             # (room, door, side he came in by): blocks or water keep that part of the room from the door
    retries = 0
    done_all = set()        # nothing else can be reached: the triforce now, though rooms are left unseen
    arrival, last_room = 0, None
    for _ in range(limit_rooms):
        side.wait_play()
        s = side.s
        if s.level != lvl.number:
            return                                  # the triforce took him out
        room = s.room
        if lvl.is_cellar(room):
            visited.add(room)
            cellar(side, lvl)
            continue
        visited.add(room)
        for _ in range(40):         # still walking in through the doorway: let him finish before planning
            if 0x20 <= side.s.x <= 0xD0 and 0x5D <= side.s.y <= 0xBD:
                break
            side.step((), 2)
        else:
            # held in the doorway by water just inside: walk on in, the ladder carries him over one square
            s = side.s
            inward = DOWN if s.y < 0x5D else UP if s.y > 0xBD else RIGHT if s.x < 0x20 else LEFT
            side.log(f"{side.name}: room {room:02X}: in the doorway at ({s.x},{s.y}); walking {inward}")
            side.hold_until({inward}, lambda st: 0x20 <= st.x <= 0xD0 and 0x5D <= st.y <= 0xBD, 60)
            side.step({inward}, 16)
        entry = min(range(4), key=lambda d: abs(DOOR_NODE[d][0] - side.s.x) + abs(DOOR_NODE[d][1] - side.s.y))
        if any(e.ntype == GRUMBLE for e in side.s.enemies):
            try:
                feed_grumble(side)
            except Stuck as e:
                side.log(f"{side.name}: {e} (feeding Grumble)")
        if foes(side):
            if DEBUG:
                side.log(f"{side.name}: room {room:02X}: fighting " + " ".join(f"{e.ntype:02X}@{e.x},{e.y}" for e in foes(side)))
            try:
                fight(side, limit=2000)
            except Stuck as e:
                side.log(f"{side.name}: {e} (fighting)")
            if DEBUG:
                side.log(f"{side.name}: room {room:02X}: after the fight " + " ".join(f"{e.ntype:02X}@{e.x},{e.y}" for e in foes(side)))
            if (lvl.item(room) & 0x1F) != (NO_ITEM & 0x1F) and room not in taken and not foes(side):
                for _ in range(60):     # a boss's heart comes out after the dying flash: wait for it
                    if room_item(side):
                        break
                    side.step((), 2)
        if lvl.number == 9 and room == lvl.triforce and side.s.mode != ST.PLAY:
            side.won = True     # he stepped up to her in the fight: her scene has begun, a fire or two still standing
            side.log(f"{side.name}: Zelda is saved (mode {side.s.raw_mode:#x}), in the fight")
            side.step((), 600)
            return
        if lvl.number == 9 and room == lvl.triforce and not foes(side):
            if rescue_zelda(side):
                return
        if room != last_room:
            arrival += 1                    # the room is laid out afresh on each visit: the block is back, the shutters shut
            last_room = room
        opened = False
        if (lvl.d[room] & 0x40) and (room, arrival) not in pushed and not foes(side):
            if push_block(side):
                pushed.add((room, arrival))
                opened = lvl.stairs_to(room) is not None and room not in used_stairs
        if room_item(side) and (lvl.item(room) != TRIFORCE or done_but_triforce(lvl, visited, taken) or lvl.number in done_all):
            try:
                took = take_item(side)
            except Stuck as e:
                side.log(f"{side.name}: {e} (taking the item)")
                took = False
            if took:
                taken.add(room)
                side.log(f"{side.name}: took the item of room {room:02X}")
                if side.s.level != lvl.number:
                    return
        avoid = bad | {(r, d) for (r, d, e) in cut if r == room and e == entry}
        if lvl.number == 9 and side.s.items[2] < 2:
            avoid = avoid | GANON_DOORS            # no silver arrow yet: Ganon cannot be killed, keep out of his room
        worn = {r for r, k in stair_uses.items() if k >= 4}
        nxt = plan(lvl, room, visited, used_stairs, taken, avoid, worn, cut)
        if opened and room not in worn and stair_uses[room] < 2 and stairs_node(side) is not None:
            nxt = ("stairs", room)             # the block has just opened the way to them: they will be shut next time
        if nxt is None and (bad or cut or stair_uses or used_stairs) and retries < 3 and not side.s.triforce & (1 << (lvl.number - 1)):
            # things found since (the ladder, a key, a block pushed) may open what was closed: try it all again
            retries += 1
            side.log(f"{side.name}: level {lvl.number}: trying the closed doors again ({retries})")
            bad.clear(), cut.clear(), fails.clear(), stair_uses.clear(), used_stairs.clear()
            continue
        if nxt is None and room == lvl.triforce and room_item(side) and lvl.number not in done_all:
            side.log(f"{side.name}: level {lvl.number}: nothing else to reach; the triforce")
            done_all.add(lvl.number)
            continue
        if nxt is None:
            left = sorted(r for r in level_rooms(lvl) if r not in visited)
            side.log(f"{side.name}: level {lvl.number}: nothing left to do from room {room:02X}; not seen "
                     + " ".join(f"{r:02X}" for r in left) + "; bad " + " ".join(f"{r:02X}{d}" for r, d in sorted(bad))
                     + "; cut " + " ".join(f"{r:02X}{d}/{e}" for r, d, e in sorted(cut))
                     + "; worn " + " ".join(f"{r:02X}" for r in sorted(worn)))
            return
        kind, arg = nxt
        side.log(f"{side.name}: room {room:02X}: {kind} {arg}" + (f" at ({side.s.x},{side.s.y}) entry {entry}" if DEBUG else ""))
        if kind == "door":
            try:
                went = go_through(side, lvl, arg)
            except Stuck as e:
                side.log(f"{side.name}: {e} (going {DOOR_DIR[arg]})")
                went = None
            if went is None:
                cut.add((room, arg, entry))
            elif not went:
                side.log(f"{side.name}: could not go {DOOR_DIR[arg]} from room {room:02X}")
                fails[(room, arg)] += 1
                if fails[(room, arg)] >= 3:
                    bad.add((room, arg))
        else:
            node = stairs_node(side)
            if node is not None and side.path({node}) is None:
                # the stairs sit inside a ring of blocks ($22 of Level 1, $64 of Level 5): the room must be clear first
                try:
                    fight(side, limit=5000)
                    push_block(side)
                except Stuck as e:
                    side.log(f"{side.name}: {e} (opening the ring)")
                node = stairs_node(side)
                if node is not None and side.path({node}) is None:
                    # a cheat: put Link on the stairs (the same on both sides), so a ring that will not open again
                    # does not cut the level in two
                    side.log(f"{side.name}: the stairs of room {room:02X} are shut in: cheat, Link onto them")
                    used_stairs.add(room)
                    stair_uses[room] += 1
                    place(side, node[0], node[1])
                    side.hold_until({DOWN}, lambda st: st.room != room, 120)
                    continue
            if node is None and (lvl.d[room] & 0x40):
                try:                      # a push block uncovers them (trigger 5), once the room is clear
                    fight(side, limit=2000)
                    push_block(side)
                except Stuck as e:
                    side.log(f"{side.name}: {e} (uncovering the stairs)")
                node = stairs_node(side)
            if node is None:
                side.log(f"{side.name}: no stairs on show in room {room:02X}")
                used_stairs.add(room)
                continue
            used_stairs.add(room)
            stair_uses[room] += 1
            try:
                side.walk({node}, limit=2000)
            except Stuck as e:
                side.log(f"{side.name}: {e} (to the stairs)")
                continue
            side.hold_until((), lambda st: st.room != room, 300)


def done_but_triforce(lvl: Level, visited, taken) -> bool:
    for r in visited:
        if lvl.item(r) not in (NO_ITEM, TRIFORCE) and r not in taken and not lvl.is_cellar(r):
            pass
    return all(r in visited for r in level_rooms(lvl))


def level_rooms(lvl: Level):
    seen = {lvl.start}
    q = [lvl.start]
    while q:
        r = q.pop()
        for d in (E, W, S, N):
            if lvl.door(r, d) == WALL:
                continue
            t = r + STEP[d]
            if not 0 <= t < 128 or (d in (E, W) and t // 16 != r // 16):
                continue
            if r == lvl.start and d == S:
                continue
            if t not in seen:
                seen.add(t)
                q.append(t)
        c = lvl.stairs_to(r)
        if c is not None:
            for t in (lvl.a[c], lvl.b[c]):
                if t < 128 and t not in seen:
                    seen.add(t)
                    q.append(t)
    return seen


def plan(lvl: Level, room: int, visited, used_stairs, taken, bad=frozenset(), worn=frozenset(), cut=frozenset()):
    """The first move towards the nearest room not yet seen (the triforce room last). A search over (room, the door
    he came in by): water or blocks may part a room, so a door cut off from one doorway (cut) may be open from another.
    Coming up stairs, every door cut off from any doorway is left out."""
    rooms = level_rooms(lvl)
    tri = lvl.triforce
    def wanted(r):
        return r not in visited and r != tri
    def shut(r, d, e):
        if (r, d) in bad and r == room:
            return True
        if e is None:
            return any((r, d) == (cr, cd) for cr, cd, ce in cut)
        return (r, d, e) in cut
    start = (room, "here")
    prev = {start: None}
    q = collections.deque([start])
    found = None
    while q:
        st = q.popleft()
        r, e = st
        if r != room and wanted(r):
            found = st
            break
        moves = []
        for d in (N, E, W, S) if not lvl.is_cellar(r) else ():     # a cellar has no doors, only its ladders
            if lvl.door(r, d) == WALL or (r, d) in bad or (e != "here" and shut(r, d, e)):
                continue
            t = r + STEP[d]
            if t not in rooms or (d in (E, W) and t // 16 != r // 16):
                continue
            moves.append(((t, OPPOSITE[d]), ("door", d)))
        c = lvl.stairs_to(r)
        if c is not None and r not in worn and (r not in used_stairs or (c in visited and lvl.a[c] != lvl.b[c])):
            moves.append(((c, None), ("stairs", r)))
        if lvl.is_cellar(r) and lvl.a[r] != lvl.b[r] and not {lvl.a[r], lvl.b[r]} & set(worn):
            for t in (lvl.a[r], lvl.b[r]):          # a tunnel comes up in both its rooms
                moves.append(((t, None), ("stairs", r)))
        for nst, mv in moves:
            if nst not in prev:
                prev[nst] = (st, mv)
                q.append(nst)
    if found is None:
        cands = [k for k in prev if k[0] == tri]
        if tri != room and tri not in taken and cands:   # seen early and left for last: go back for it
            found = cands[0]
        else:
            return None
    st = found
    while prev[st][0] != start:
        st = prev[st][0]
    return prev[st][1]


def leave_level(side: Side) -> None:
    """Back to the level's first room and out by its south door (a level not finished, or the ninth)."""
    lvl = load_level(side)
    closed = set()
    for _ in range(80):
        side.wait_play()
        if not side.s.level:
            return
        room = side.s.room
        if lvl.is_cellar(room):
            cellar(side, lvl)
            continue
        if room == lvl.start:
            side.walk({DOOR_NODE[S]}, limit=2000)
            side.hold_until({DOWN}, lambda st: st.level == 0, 400)
            continue
        nxt = plan_to(lvl, room, lvl.start, closed)
        if nxt is None:
            raise Stuck(f"{side.name}: no way back to the start of level {lvl.number} from {room:02X}")
        kind, arg = nxt
        if kind == "door":
            try:
                went = go_through(side, lvl, arg)
            except Stuck:
                went = None
            if not went and side.s.room == room:
                closed.add((room, arg))
        else:
            node = stairs_node(side)
            try:
                if node is None:
                    raise Stuck(f"{side.name}: the stairs of {room:02X} are not on show")
                side.walk({node}, limit=2000)
            except Stuck as e:
                side.log(f"{side.name}: {e} (leaving)")
                closed.add((room, "stairs"))
                continue
            side.hold_until((), lambda st: st.room != room, 300)
    raise Stuck(f"{side.name}: did not get out of level {lvl.number}")


def plan_to(lvl: Level, room: int, target: int, closed=frozenset()):
    """The first move on the shortest way from room to target, through doors and stairs."""
    rooms = level_rooms(lvl)
    prev = {room: None}
    q = collections.deque([room])
    while q:
        r = q.popleft()
        if r == target:
            break
        moves = []
        for d in (N, E, W, S) if not lvl.is_cellar(r) else ():
            if lvl.door(r, d) == WALL or (r, d) in closed:
                continue
            t = r + STEP[d]
            if t not in rooms or (d in (E, W) and t // 16 != r // 16):
                continue
            moves.append((t, ("door", d)))
        c = lvl.stairs_to(r)
        if c is not None and (r, "stairs") not in closed:
            moves.append((c, ("stairs", r)))
        if lvl.is_cellar(r):
            for t in (lvl.a[r], lvl.b[r]):
                moves.append((t, ("stairs", r)))
        for t, mv in moves:
            if t not in prev:
                prev[t] = (r, mv)
                q.append(t)
    if target not in prev or target == room:
        return None
    r = target
    while prev[r][0] != room:
        r = prev[r][0]
    return prev[r][1]


def feed_grumble(side: Side) -> None:
    """Grumble stands in the doorway until he is given food (the bait): put it down just in front of him."""
    g = next(e for e in side.s.enemies if e.ntype == GRUMBLE)
    if not side.s.items[6]:
        (side.drv.poke(ST.R_ITEMS + 6, 1) if side.name == "NES" else side.drv.poke("ITEMS", 1, 6))
        side.log(f"{side.name}: cheat food = 1")
        side.step((), 1)
    side.get_tiles()
    stand = (g.x & ~7, ((g.y + 32 - 5) & ~7) + 5)
    side.approach(stand, UP)
    side.select_b("food")
    side.press("B", 2, 200)
    side.log(f"{side.name}: fed Grumble from {stand}; he is {'gone' if not any(e.ntype == GRUMBLE for e in side.s.enemies) else 'still there'}")


def place(side: Side, x: int, y: int) -> None:
    """A cheat: set Link's position."""
    if side.name == "NES":
        side.drv.poke(0x70, x)
        side.drv.poke(0x84, y)
    else:
        side.drv.poke("LINK_X", x)
        side.drv.poke("LINK_Y", y)
    side.step((), 2)
