"""The bot's policy, the same for both sides: walking on the 8-pixel grid with a breadth-first search over the live
tile map, leaving a screen, going into caves, fighting, and using the B items. Each side is wrapped in a Side, which
reads a State every frame and turns the policy's NES buttons into that side's input. Development tooling only."""
from __future__ import annotations

import collections
from pathlib import Path

import state as ST

OW_WALKABLE = {0x8D, 0x91, 0x9C, 0xAC, 0xAD, 0xCC, 0xD2, 0xD5, 0xDF}
UP, DOWN, LEFT, RIGHT = "UP", "DOWN", "LEFT", "RIGHT"
DELTA = {UP: (0, -8), DOWN: (0, 8), LEFT: (-8, 0), RIGHT: (8, 0)}
DIRBIT = {RIGHT: 1, LEFT: 2, DOWN: 4, UP: 8}
# B items: the ROM's SelectedItemSlot and the port's B_ITEM code
B_SLOTS = {"boomerang": (0, 2), "bomb": (1, 1), "bow": (2, 4), "candle": (4, 3), "flute": (5, 5), "food": (6, 6),
           "potion": (7, 7), "rod": (8, 8), "letter": (0x0F, 9)}


class Stuck(Exception):
    pass


class Side:
    """One emulator and what the bot knows about it."""

    def __init__(self, name: str, drv, tables=None, log=None):
        self.name, self.drv, self.tables = name, drv, tables
        self.log = log or (lambda s: None)
        self.s: ST.State | None = None
        self.blocked: dict = {}             # (level, room, node, dir) -> frame it was found blocked by walking into it
        self.tiles_key = None
        self.tiles = None
        self.cheat = True
        self.walk_extra: dict = {}          # overworld screen -> tiles that can be walked on there now (a dried pond)
        self.avoid: set = set()             # (level, room, node): stairs he walked into by chance, kept off later
        self.frames = 0
        self.refresh()

    # -- reading and stepping ------------------------------------------------------------------------------------
    def refresh(self) -> ST.State:
        self.s = ST.nes_state(self.drv) if self.name == "NES" else ST.port_state(self.drv, self.tables)
        return self.s

    def get_tiles(self, force: bool = False):
        key = (self.s.level, self.s.room, self.s.mode)
        if force or key != self.tiles_key:
            self.tiles = ST.nes_tiles(self.drv) if self.name == "NES" else ST.port_tiles(self.drv)
            self.tiles_key = key
        return self.tiles

    def step(self, buttons=(), frames: int = 1) -> ST.State:
        for _ in range(frames):
            self.drv.step(set(buttons), 1)
            self.frames += 1
            self.refresh()
            if self.cheat:
                self.keep_alive()
        return self.s

    def keep_alive(self) -> None:
        """Cheats: Link cannot be hurt and keeps full hearts."""
        s = self.s
        if s.mode != ST.PLAY:
            return
        if self.name == "NES":
            if self.drv.mem[ST.R_INVINC] < 0x10:
                self.drv.poke(ST.R_INVINC, 0x30)
            full = (self.drv.mem[ST.R_HEARTS] & 0xF0) | ((self.drv.mem[ST.R_HEARTS] >> 4) & 0x0F)
            if self.drv.mem[ST.R_HEARTS] != full or self.drv.mem[ST.R_PARTIAL] != 0xFF:
                self.drv.poke(ST.R_HEARTS, [full, 0xFF])
        else:
            if self.drv.v("LINK_HURT") < 0x10:
                self.drv.poke("LINK_HURT", 0x60)
            full = self.s.containers * 2
            if self.drv.v("HP_HALVES") != full:
                self.drv.poke("HP_HALVES", full)
                self.drv.poke("HP_FRAC", 0)

    def give(self, what: str, value: int) -> None:
        """Set an inventory value on this side (a cheat, logged)."""
        if what == "rupees":
            (self.drv.poke(ST.R_RUPEES, value) if self.name == "NES" else self.drv.poke("INV_RUPEES", value))
        elif what == "keys":
            (self.drv.poke(ST.R_KEYS, value) if self.name == "NES" else self.drv.poke("INV_KEYS", value))
        elif what == "bombs":
            (self.drv.poke(ST.R_ITEMS + 1, value) if self.name == "NES" else self.drv.poke("ITEMS", value, 1))
        self.log(f"{self.name}: cheat {what} = {value}")
        self.step((), 1)

    def select_b(self, item: str) -> None:
        rom, port = B_SLOTS[item]
        if self.name == "NES":
            self.drv.poke(ST.R_SELECTED, rom)
        else:
            self.drv.poke("B_ITEM", port)
        self.step((), 1)

    # -- the map ---------------------------------------------------------------------------------------------------
    def walkable(self, t: int) -> bool:
        if self.s.level:
            return t < 0x78
        return t < 0x89 or t in OW_WALKABLE or t in self.walk_extra.get(self.s.room, ())

    def node_free(self, x: int, y: int) -> bool:
        if not (0 <= x <= 0xF0 and 0x3D <= y <= 0xDD):
            return False
        if (self.s.level, self.s.room, (x, y)) in self.avoid:
            return False
        if self.s.level and not (0x20 <= x <= 0xD0 and 0x5D <= y <= 0xBD):
            return False             # a dungeon room: Link stays on the floor ($20-$D0 x $5D-$BD); a doorway only as a goal
                                     # (the port leaves the room at the edge, the NES walks him into the door frame)
        tiles = self.tiles
        row = (y + 0x0B - 0x40) >> 3
        if not 0 <= row < 22:
            return False
        c = x >> 3
        if self.s.level and x % 16 == 0 and y % 16 == 13 and 0x70 <= tiles[row][c] <= 0x73:
            return False             # the stairs square itself takes him down (check_warps): only as a goal
        return self.walkable(tiles[row][c]) and self.walkable(tiles[row][min(c + 1, 31)])

    def bounds(self):
        """The nodes Link can stand on: x in 0..$F0 step 8, y = 5 mod 8."""
        if self.s.level:
            return (0x10, 0xE0, 0x4D, 0xCD)       # the floor is $20-$D0 x $5D-$BD; the doorways lie beyond it
        return (0x00, 0xF0, 0x3D, 0xDD)

    @staticmethod
    def _inward(n, m) -> bool:
        """m is closer than n to the middle of a dungeon room, along the doorway's line."""
        cx, cy = 0x78, 0x8D
        if n[0] == m[0]:
            return n[0] == cx and abs(m[1] - cy) < abs(n[1] - cy)
        return n[1] == cy and abs(m[0] - cx) < abs(n[0] - cx)

    def path(self, goal, avoid_edges=True):
        """Breadth-first search from Link's node to any node in goal (a set or a predicate); returns the list of moves."""
        self.get_tiles()
        x0, x1, y0, y1 = self.bounds()
        sx, sy = self.s.x & ~7, ((self.s.y - 5) & ~7) + 5
        start = (sx, sy)
        isgoal = goal if callable(goal) else (lambda n: n in goal)
        prev = {start: None}
        q = collections.deque([start])
        while q:
            n = q.popleft()
            if isgoal(n):
                moves = []
                while prev[n] is not None:
                    n, d, k = prev[n]
                    moves.extend([d] * k)
                return moves[::-1]
            for d, (dx, dy) in DELTA.items():
                m = (n[0] + dx, n[1] + dy)
                if m in prev or not (x0 <= m[0] <= x1 and y0 <= m[1] <= y1):
                    continue
                when = self.blocked.get((self.s.level, self.s.room, n, d))
                if when is not None and self.frames - when < 400:
                    continue
                if not self.node_free(*m) and not isgoal(m):
                    # in a dungeon doorway the door tiles count as wall: let Link step out of it towards the middle;
                    # standing on the ladder over the moat he may step on along it or off it
                    on_moat = (self.s.level and not self.node_free(*n) and self._moat(*n)
                               and abs(n[0] - start[0]) + abs(n[1] - start[1]) <= 24)
                    if not (self.s.level and not self.node_free(*n) and self._inward(n, m)) and not (
                            on_moat and self._moat(*m)):
                        continue
                prev[m] = (n, d, 1)
                q.append(m)
            if self.s.level and len(self.s.items) > 12 and self.s.items[12] and self.node_free(*n):
                # the ladder (CheckLadder) carries Link over one square of moat: from a free node across moat to a free
                # node at most 32 pixels on
                for d, (dx, dy) in DELTA.items():
                    if not self._moat(n[0] + dx, n[1] + dy):
                        continue
                    for k in (2, 3, 4):
                        m = (n[0] + dx * k, n[1] + dy * k)
                        if not (x0 <= m[0] <= x1 and y0 <= m[1] <= y1):
                            break
                        if self.node_free(*m):
                            if m not in prev:
                                prev[m] = (n, d, k)
                                q.append(m)
                            break
                        if not self._moat(*m):
                            break
        return None

    def _moat(self, x: int, y: int) -> bool:
        """The node's feet are on moat (tile $F4) and nothing worse."""
        row = (y + 0x0B - 0x40) >> 3
        if not 0 <= row < 22:
            return False
        c = x >> 3
        pair = (self.tiles[row][c], self.tiles[row][min(c + 1, 31)])
        return 0xF4 in pair and all(t == 0xF4 or self.walkable(t) for t in pair)

    # -- moving ----------------------------------------------------------------------------------------------------
    def align(self) -> None:
        """Get Link onto the grid (x mod 8 = 0, y mod 8 = 5) before following a path."""
        for _ in range(16):
            s = self.s
            if s.x % 8 == 0 and s.y % 8 == 5:
                return
            if s.x % 8:
                d = LEFT if s.x % 8 < 4 else RIGHT
                if s.x < 0x28:
                    d = RIGHT                 # never align out of the screen through a doorway
                elif s.x > 0xC8:
                    d = LEFT
                if s.dir in (DIRBIT[UP], DIRBIT[DOWN]):
                    d = UP if s.dir == DIRBIT[UP] else DOWN
            else:
                d = UP if (s.y - 5) % 8 < 4 else DOWN
                if s.y < 0x65:
                    d = DOWN
                elif s.y > 0xB5:
                    d = UP
                if s.dir in (DIRBIT[LEFT], DIRBIT[RIGHT]):
                    d = LEFT if s.dir == DIRBIT[LEFT] else RIGHT
            was = (s.x, s.y)
            self.step({d}, 1)
            if (self.s.x, self.s.y) == was and self.s.mode == ST.PLAY:
                return                        # against a wall: plan from the nearest node and let the game snap him

    def walk(self, goal, limit: int = 3000, extra=None) -> bool:
        """Walk to a node in goal. extra(side) is called every frame and may return buttons to press instead."""
        start_room = (self.s.level, self.s.room)
        spent = 0
        while spent < limit:
            if self.s.mode != ST.PLAY or (self.s.level, self.s.room) != start_room:
                return False
            self.align()
            moves = self.path(goal)
            mine = [k for k in self.blocked if k[:2] == (self.s.level, self.s.room)]
            if moves is None and mine and spent < limit - 200:
                # what blocked him may have been passing (a monster, an old man talking): forget it, wait, plan again
                for k in mine:
                    del self.blocked[k]
                self.step((), 60)
                spent += 60
                continue
            if moves is None:
                # off the grid or pushed somewhere odd: try a short step each way and plan again
                for d in (LEFT, RIGHT, UP, DOWN):
                    self.step({d}, 6)
                    self.align()
                    moves = self.path(goal)
                    if moves is not None:
                        break
                spent += 24
            if moves is None:
                raise Stuck(f"{self.name}: no path in room {self.s.room:02X} from ({self.s.x},{self.s.y})")
            if not moves:
                return True
            d = moves[0]
            node = (self.s.x & ~7, ((self.s.y - 5) & ~7) + 5)
            tx, ty = node[0] + DELTA[d][0], node[1] + DELTA[d][1]
            if not self.node_free(tx, ty):
                # a ladder crossing (or a doorway): keep going until the far side, where the plan can start again
                run = 1
                while run < len(moves) and moves[run] == d:
                    run += 1
                tx, ty = node[0] + DELTA[d][0] * run, node[1] + DELTA[d][1] * run
            same = 0
            last = (self.s.x, self.s.y)
            def arrived(st, d=d, tx=tx, ty=ty):
                return {UP: st.y <= ty, DOWN: st.y >= ty, LEFT: st.x <= tx, RIGHT: st.x >= tx}[d]
            while not arrived(self.s) and spent < limit:
                b = extra(self) if extra else None
                self.step(b if b else {d}, 1)
                spent += 1
                if self.s.mode != ST.PLAY or (self.s.level, self.s.room) != start_room:
                    return False
                if (self.s.x, self.s.y) == last:
                    same += 1
                    if same > 12:
                        self.blocked[(self.s.level, self.s.room, node, d)] = self.frames
                        self.log(f"{self.name}: blocked at {node} going {d} in room {self.s.room:02X}")
                        break
                else:
                    same = 0
                    last = (self.s.x, self.s.y)
        return False

    def walk_to(self, x: int, y: int, **kw) -> bool:
        return self.walk({(x, y)}, **kw)

    def hold_until(self, buttons, pred, limit: int = 600) -> bool:
        for _ in range(limit):
            if pred(self.s):
                return True
            self.step(buttons, 1)
        return pred(self.s)

    def wait_play(self, limit: int = 2000, calm: int = 3) -> bool:
        """Wait until the game is in play mode for a few frames running (a scroll can begin a frame after the room
        number changes)."""
        run = 0
        for i in range(limit):
            # also let the spawn clouds clear (at most 200 frames: a burrowed leever may count as one for ever)
            run = run + 1 if self.s.mode == ST.PLAY and (not self.s.spawning or i > 200) else 0
            if run >= calm:
                return True
            self.step((), 1)
        return False

    def leave(self, d: str, limit: int = 4000) -> bool:
        """Walk to the edge of the screen on side d and on into the next screen."""
        room = (self.s.level, self.s.room)
        x0, x1, y0, y1 = self.bounds()
        edge = {UP: lambda n: n[1] == y0, DOWN: lambda n: n[1] == y1,
                LEFT: lambda n: n[0] == x0, RIGHT: lambda n: n[0] == x1}[d]
        if self.s.level:     # dungeon doors are in the middle of a wall
            mid = {UP: (0x78, y0), DOWN: (0x78, y1), LEFT: (x0, 0x8D), RIGHT: (x1, 0x8D)}[d]
            edge = (lambda m: (lambda n: n == m))(mid)
        self.walk(edge, limit)
        self.hold_until({d}, lambda s: (s.level, s.room) != room or s.mode != ST.PLAY, 300)
        self.wait_play()
        return (self.s.level, self.s.room) != room

    def approach(self, node, d: str, limit: int = 3000) -> bool:
        """Walk to node arriving in direction d, so Link faces d there without a turning tap (a tap moves the port's
        Link on to the next grid line, the ROM's by a pixel or two)."""
        back = (node[0] - DELTA[d][0], node[1] - DELTA[d][1])
        if self.node_free(*back) and self.path({back}) is not None:
            self.walk({back}, limit)
        self.walk({node}, limit)
        if self.s.dir != DIRBIT[d]:
            self.face(d)
        return (self.s.x, self.s.y) == node

    def face(self, d: str) -> None:
        if self.s.dir != DIRBIT[d]:
            # a tap turns Link without stepping far
            self.step({d}, 1)

    def press(self, button: str, hold: int = 1, after: int = 8) -> None:
        self.step({button}, hold)
        self.step((), after)
