"""The bot's routes: what to do, task by task. Each task is a function of one Side and runs the same way on both.
The Gathering follows zeldadungeon.net's walkthrough (sword, bombs, hearts, money, letter, candle, white sword,
shield, arrows, potions, blue ring), with the places read from the ROM's level block and the port's cave and
secret tables (owinfo.py). Development tooling only."""
from __future__ import annotations

from functools import partial

import state as ST
from brain import DIRBIT, DOWN, LEFT, RIGHT, UP, Side, Stuck
import owinfo
from owmap import OWGraph

_graph = None
_info = None
MAZES = (0x61, 0x1B)
# SecretArmosRoomIds and the X of the armos over the stairs (row 4), as owspec.s has them
ARMOS = {0x24: 0xE0, 0x0B: 0xB0, 0x1C: 0xB0, 0x22: 0x30, 0x34: 0x40, 0x3D: 0x90, 0x4E: 0xA0}      # the Lost Woods and the Lost Hills loop back on themselves


def graph() -> OWGraph:
    global _graph
    if _graph is None:
        _graph = OWGraph(1)
    return _graph


def info(side: Side) -> dict:
    global _info
    if _info is None:
        if side.name == "NES":
            attrs = side.drv.read(ST.R_ATTRS, 768)
        else:       # the port's copies of the same tables (A, B and F are the ones used)
            d = side.drv
            attrs = bytearray(768)
            for i, t in ((0, "a"), (1, "b"), (5, "f")):
                attrs[i * 128:(i + 1) * 128] = d.peek_mem(d.base + d.sym[f"room_attr_{t}"], 128)
            attrs = bytes(attrs)
        _info = owinfo.load(attrs)
    return _info


def sq_node(row: int, col: int):
    return (col * 16, row * 16 + 0x3D)


# -- getting about the overworld ----------------------------------------------------------------------------------
# the mazes (CheckMazes): the moves that lead through, and the way out that is always open
MAZE_SEQ = {0x61: (UP, LEFT, DOWN, LEFT), 0x1B: (UP, UP, UP, UP)}
MAZE_OPEN = {0x61: RIGHT, 0x1B: LEFT}


def maze_allow(room: int, d: str) -> bool:
    return room not in MAZE_SEQ or d in (MAZE_SEQ[room][-1], MAZE_OPEN[room])


def walk_maze(side: Side, room: int) -> None:
    """Leave the maze screen in each of its four directions: three bring Link back into it, the fourth lets him out."""
    for d in MAZE_SEQ[room]:
        side.wait_play()
        if side.s.room != room:
            return
        side.log(f"{side.name}: maze {room:02X}: {d}")
        side.leave(d)


DOCKS = {0x55: 0x80, 0x3F: 0x60, 0x45: 0x80, 0x2F: 0x60}


def ride_raft(side: Side, room: int) -> None:
    """Stand on the dock and walk on: the raft carries Link up across the water (or, from the far side, down to it)."""
    if not side.s.items[9]:
        raise Stuck(f"{side.name}: the raft is needed at {room:02X}")
    x = DOCKS[room]
    before = side.s.room
    if room in (0x55, 0x3F):
        side.walk_to(x, 0x85, limit=3000)
        side.hold_until({UP}, lambda st: st.room != before, 600)
    else:
        side.walk_to(x, 0xDD, limit=3000)
        side.hold_until({DOWN}, lambda st: st.room != before, 600)
    side.log(f"{side.name}: raft from {before:02X} to {side.s.room:02X}")
    side.wait_play(1200)


def goto_screen(side: Side, target: int, tries: int = 6) -> None:
    g = graph()
    avoid = ()
    for _ in range(tries * 8):
        side.step((), 2)
        if side.s.mode == ST.CAVE and side.s.level == 0:
            # walked onto the stairs of a cave or a secret on the way: out again, and keep off that square
            room, node = side.s.room, (side.s.x & ~7, ((side.s.y - 5) & ~7) + 5)
            cave_leave(side)
            try:
                ex, ey = entrance(side, room)
            except Exception:       # noqa: BLE001
                ex, ey = node
            for dy in (-8, 0, 8):
                side.avoid.add((0, room, (ex, ey + dy)))
            side.log(f"{side.name}: walked into a cave in {room:02X} on the way; out again")
        side.wait_play()
        s = side.s
        if s.level == 0 and s.room == target and s.mode == ST.PLAY:
            return
        if s.level:
            raise Stuck(f"{side.name}: in a dungeon, not on the overworld")
        route = g.route(s.room, s.x, s.y, target, avoid,
                        lambda r, d: maze_allow(r, d) and (d != "RAFT" or bool(side.s.items[9])))
        if not route:
            raise Stuck(f"{side.name}: no route from {s.room:02X} to {target:02X}")
        room, d, want = route[0]
        if d == "RAFT":
            ride_raft(side, s.room)
            continue
        if s.room in MAZE_SEQ and d == MAZE_SEQ[s.room][-1]:
            walk_maze(side, s.room)
            continue
        here = g.component(s.room, s.x, s.y)
        x0, x1, y0, y1 = side.bounds()
        nodes = set()
        for (r, n), c in g.comp.items():
            if r != s.room or c != here[1]:
                continue
            if (d == UP and n[1] == y0) or (d == DOWN and n[1] == y1) or (d == LEFT and n[0] == x0) or (
                    d == RIGHT and n[0] == x1):
                other = {UP: (n[0], y1), DOWN: (n[0], y0), LEFT: (x1, n[1]), RIGHT: (x0, n[1])}[d]
                if g.comp.get((want[0], other)) == want[1]:
                    nodes.add(n)
        before = s.room
        side.walk(nodes, limit=3000)
        side.hold_until({d}, lambda st: st.room != before or st.mode != ST.PLAY, 200)
        side.wait_play()
    raise Stuck(f"{side.name}: did not reach screen {target:02X}")


# -- caves ----------------------------------------------------------------------------------------------------------
WARE_X = (0x58, 0x78, 0x98)


def entrance(side: Side, room: int):
    if room in ARMOS:
        return sq_node(4, ARMOS[room] >> 4)
    i = info(side)[room]
    if "stairs" in i:
        return sq_node(*divmod(i["stairs"], 16))
    return i["entrance"]


def enter_cave(side: Side, room: int) -> None:
    ex, ey = entrance(side, room)
    side.get_tiles(force=True)
    # stand on the square below the doorway, then walk up into it
    # a doorway in a wall is walked into from below; stairs are stepped on from any side
    side.walk({(ex, ey + 16), (ex, ey + 8), (ex, ey)}, limit=3000)
    side.log(f"{side.name}: at the doorway of {room:02X}: ({side.s.x},{side.s.y}) {side.s.mode} room {side.s.room:02X}")
    side.hold_until({UP}, lambda s: s.mode != ST.PLAY or s.room != room, 240)
    side.hold_until((), lambda s: s.mode in (ST.CAVE, ST.PLAY) and s.raw_mode not in (0x10,), 400)
    if side.s.mode != ST.CAVE:
        raise Stuck(f"{side.name}: did not go into the cave of {room:02X} (now {side.s.mode} in {side.s.room:02X})")
    side.step((), 10)


def cave_take(side: Side, index: int, wait: int = 260) -> None:
    """In a cave: let the person talk, then walk to ware 0, 1 or 2 and on to it."""
    side.step((), wait)
    tx = WARE_X[index]
    if side.s.x != tx:      # the doorway is narrow: up into the room first, then across
        side.hold_until({UP}, lambda s: s.y <= 0xAD, 200)
        side.hold_until({RIGHT} if side.s.x < tx else {LEFT}, lambda s: abs(s.x - tx) <= 1, 200)
    before = (side.s.items, side.s.rupees, side.s.containers)
    side.hold_until({UP}, lambda s: (s.items, s.rupees, s.containers) != before or s.y <= 0x98, 200)
    # rupees are paid or counted out one at a time: wait until they stop changing
    last, calm = side.s.rupees, 0
    for _ in range(600):
        side.step((), 1)
        calm = calm + 1 if side.s.rupees == last else 0
        last = side.s.rupees
        if calm > 60:
            break


def cave_leave(side: Side) -> None:
    # walk back to the middle and down out of the cave
    if side.s.x != 0x70:
        side.hold_until({DOWN}, lambda s: s.y >= 0xAD, 200)
        side.hold_until({LEFT} if side.s.x > 0x70 else {RIGHT}, lambda s: abs(s.x - 0x70) <= 1, 200)
    side.hold_until({DOWN}, lambda s: s.mode != ST.CAVE, 400)
    side.wait_play()
    side.step((), 20)


def visit_cave(side: Side, room: int, take: int | None = None, money: int = 0, show_letter: bool = False) -> None:
    goto_screen(side, room)
    reveal(side, room)
    if money:
        side.give("rupees", max(side.s.rupees, money))
    enter_cave(side, room)
    if show_letter:
        side.step((), 200)
        side.select_b("letter")
        side.press("B", 2, 120)
    if take is not None:
        cave_take(side, take)
    else:
        side.step((), 300)
    cave_leave(side)


# -- hidden spots ---------------------------------------------------------------------------------------------------
def reveal(side: Side, room: int) -> None:
    if room in ARMOS:
        stand = sq_node(5, ARMOS[room] >> 4)
        side.walk({stand}, limit=3000)
        side.hold_until({UP}, lambda s: False, 30)
        side.hold_until({DOWN}, lambda s: False, 12)
        side.step((), 90)          # it rises, and leaves the stairs
        side.get_tiles(force=True)
        return
    sec = info(side)[room].get("secret")
    if not sec:
        return
    kind, square = sec
    row, col = divmod(square, 16)
    side.get_tiles(force=True)
    if kind == "bomb":
        if side.s.items[1] == 0:
            side.give("bombs", 4)
        side.select_b("bomb")
        stand = sq_node(row + 1, col)
        side.approach(stand, UP)
        side.press("B", 2, 4)
        side.hold_until({DOWN}, lambda s: s.y >= stand[1] + 24, 40)
        side.step((), 90)
    elif kind == "burn":
        if side.s.items[4] == 0:
            raise Stuck(f"{side.name}: no candle to burn the bush in {room:02X}")
        side.select_b("candle")
        # the flame lands 16 pixels ahead and creeps 16 more: it burns what it stops on, two squares ahead
        for (dr, dc, d) in ((2, 0, UP), (-2, 0, DOWN), (0, -2, RIGHT), (0, 2, LEFT)):
            stand = sq_node(row + dr, col + dc)
            if side.node_free(*stand) and side.path({stand}) is not None:
                side.approach(stand, d)
                side.log(f"{side.name}: burning from {stand} facing {d}, Link at ({side.s.x},{side.s.y}) dir {side.s.dir}")
                side.press("B", 2, 100)
                t = side.get_tiles(force=True)
                side.log(f"{side.name}: the bush square is now tile {t[row * 2][col * 2]:02X}")
                break
        else:
            raise Stuck(f"{side.name}: no place to stand by the bush in {room:02X}")
    elif kind in ("push", "armos"):
        for (dr, dc, d) in ((1, 0, UP), (-1, 0, DOWN), (0, -1, RIGHT), (0, 1, LEFT)):
            stand = sq_node(row + dr, col + dc)
            if side.node_free(*stand) and side.path({stand}) is not None:
                side.walk({stand}, limit=3000)
                side.hold_until({d}, lambda s: False, 40)
                side.step((), 80)
                break
    side.get_tiles(force=True)


# -- tasks -----------------------------------------------------------------------------------------------------------
def T(name, fn):
    return (name, fn)


GATHERING = [
    T("wooden sword (cave of the start screen, $77)", partial(visit_cave, room=0x77, take=1)),
    T("bombs ($6F shop)", partial(visit_cave, room=0x6F, take=1, money=40)),
    T("heart container (bombed wall, $7B)", partial(visit_cave, room=0x7B, take=2)),
    T("10 rupees (armos, $4E)", partial(visit_cave, room=0x4E, take=1)),
    T("30 rupees (armos, $3D)", partial(visit_cave, room=0x3D, take=1)),
    T("30 rupees (bombed wall, $2D)", partial(visit_cave, room=0x2D, take=1)),
    T("heart container (bombed rock, $2C)", partial(visit_cave, room=0x2C, take=2)),
    T("letter ($0E)", partial(visit_cave, room=0x0E, take=1)),
    T("blue candle ($0C shop)", partial(visit_cave, room=0x0C, take=2, money=80)),
    T("white sword ($0A, five hearts)", partial(visit_cave, room=0x0A, take=1)),
    T("30 rupees (burnt bush, $28)", partial(visit_cave, room=0x28, take=1)),
    T("30 rupees (burnt bush, $48)", partial(visit_cave, room=0x48, take=1)),
    T("heart container (burnt bush, $47)", partial(visit_cave, room=0x47, take=2)),
    T("magic shield (burnt bush, $46 shop)", partial(visit_cave, room=0x46, take=0, money=100)),
    T("10 rupees (burnt bush, $56)", partial(visit_cave, room=0x56, take=1)),
    T("arrows ($4A shop)", partial(visit_cave, room=0x4A, take=2, money=100)),
    T("10 rupees (burnt bush, $5B)", partial(visit_cave, room=0x5B, take=1)),
    T("100 rupees (burnt bush, $6B)", partial(visit_cave, room=0x6B, take=1)),
    T("30 rupees (bombed wall, $67)", partial(visit_cave, room=0x67, take=1)),
    T("potion shop, letter shown ($64)", partial(visit_cave, room=0x64, take=2, money=80, show_letter=True)),
    T("30 rupees (bombed wall, $71)", partial(visit_cave, room=0x71, take=1)),
    T("100 rupees (burnt bush, $62)", partial(visit_cave, room=0x62, take=1)),
    T("10 rupees (burnt bush, $51)", partial(visit_cave, room=0x51, take=1)),
    T("blue ring ($34 shop)", partial(visit_cave, room=0x34, take=1, money=255)),
]

ROUTES = {"gathering": GATHERING}


# -- dungeons ------------------------------------------------------------------------------------------------------------
LEVEL_SCREENS = {1: 0x37, 2: 0x3C, 3: 0x74, 4: 0x45, 5: 0x0B, 6: 0x22, 7: 0x42, 8: 0x6D, 9: 0x05}


def enter_level(side: Side, n: int) -> None:
    room = LEVEL_SCREENS[n]
    goto_screen(side, room)
    if n == 7:
        # the pond of Level 7 dries up at the recorder's tune and shows the stairs
        if not side.s.items[5]:
            raise Stuck(f"{side.name}: the recorder is needed for Level 7")
        side.walk_to(0x78, 0xBD, limit=3000)
        side.select_b("flute")
        side.press("B", 2, 400)
        side.wait_play(1200)
        side.walk_extra[room] = set(range(0x8D, 0x99))   # the dry bed of the pond
    reveal(side, room)
    ex, ey = entrance(side, room)
    t = side.get_tiles(force=True)
    stairs = [(c * 8, r * 8 + 0x40 - 0x0B + 8) for r in range(21) for c in range(31)
              if t[r][c] == 0x70 and t[r][c + 1] == 0x72 and t[r + 1][c] == 0x71]
    if stairs and not any(abs(ex - x) < 16 and abs(ey - y) < 16 for x, y in stairs):
        ex, ey = stairs[0]                  # stairs on show that the attributes do not place (the pond of Level 7)
        side.log(f"{side.name}: the stairs of level {n} are at ({ex},{ey})")
    side.get_tiles(force=True)
    side.walk({(ex, ey + 16), (ex, ey + 8), (ex, ey)}, limit=3000)
    side.hold_until({UP}, lambda s: s.level == n, 400)
    side.wait_play(600)
    if side.s.level != n:
        raise Stuck(f"{side.name}: did not get into level {n}")


def play_level(side: Side, n: int) -> None:
    import dungeon
    if side.s.level != n:
        enter_level(side, n)
    dungeon.explore(side)
    if getattr(side, "won", False):
        return                                  # Zelda's thanks and the credits: the game is over
    if side.s.level and (n == 9 or not side.s.triforce & (1 << (n - 1))):
        side.log(f"{side.name}: level {n} is not finished; leaving it")
        dungeon.leave_level(side)
    if side.s.triforce & (1 << (n - 1)) and n < 9:
        # the end of the level: the piece held up, the flash, the hearts, the curtain, then the overworld
        side.hold_until((), lambda s: s.level == 0, 4000)
    side.wait_play(2000)


def cheat_kit(side: Side) -> None:
    """For trying a level on its own: a white sword, bombs, five hearts."""
    if side.name == "NES":
        side.drv.poke(ST.R_ITEMS, [2, 8])
        side.drv.poke(ST.R_HEARTS, 0x44)
    else:
        side.drv.poke("ITEMS", 2, 0)
        side.drv.poke("ITEMS", 8, 1)
        side.drv.poke("HEART_CONTAINERS", 5)
    side.step((), 2)


ROUTES["level1"] = [T("kit", cheat_kit), T("Level 1", partial(play_level, n=1))]
ROUTES["levels12"] = ROUTES["level1"] + [T("Level 2", partial(play_level, n=2))]
ROUTES["levels123"] = ROUTES["levels12"] + [T("Level 3", partial(play_level, n=3))]
ROUTES["levels"] = [T("kit", cheat_kit)] + [T(f"Level {n}", partial(play_level, n=n)) for n in range(1, 10)]
def cheat_all(side: Side) -> None:
    """For trying Level 9 on its own: what the first eight levels and the Gathering give (a cheat)."""
    # ROM slots: 0 sword 3 (magic), 1 bombs, 2 arrows 2 (silver), 3 bow, 4 candle 2 (red), 5 recorder, 6 food,
    # 7 potion 2, 8 rod, 9 raft, 10 book, 11 ring 2 (red), 12 ladder, 13 magic key, 14 bracelet, 16-17 compass/map
    slots = {0: 3, 1: 8, 2: 2, 3: 1, 4: 2, 5: 1, 6: 1, 7: 2, 8: 1, 9: 1, 10: 1, 11: 2, 12: 1, 13: 1, 14: 1}
    if side.name == "NES":
        for i, val in slots.items():
            side.drv.poke(ST.R_ITEMS + i, val)
        side.drv.poke(ST.R_HEARTS, 0xFF)
        side.drv.poke(ST.R_TRIFORCE, 0xFF)
        side.drv.poke(ST.R_RUPEES, 200)
    else:
        for i, val in slots.items():
            side.drv.poke("ITEMS", val, i)
        side.drv.poke("HEART_CONTAINERS", 16)
        side.drv.poke("TRIFORCE_PIECES", 0xFF)
        side.drv.poke("INV_RUPEES", 200)
    side.log(f"{side.name}: cheat: everything the first eight levels give")
    side.step((), 2)


ROUTES["level9"] = [T("everything", cheat_all), T("Level 9", partial(play_level, n=9))]
ROUTES["all"] = ROUTES["gathering"] + [T(f"Level {n}", partial(play_level, n=n)) for n in range(1, 10)]
for _n in range(1, 10):     # one level on its own, with everything in hand (a cheat): "only4"
    ROUTES[f"only{_n}"] = [T("everything", cheat_all), T(f"Level {_n}", partial(play_level, n=_n))]
