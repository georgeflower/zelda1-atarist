"""Rebuild the underworld rooms the 6502 lays out at run time.

LayOutRoom (Z_05.asm) fills a 32x22 tile map with brick, writes the walls with
FillWalls, the doors with LayOutDoors and the floor with LayoutUWFloor. This
module repeats those steps at build time, so the ST only has to draw tiles.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import build_assets as B
import actors

UW_COLS = 32
UW_ROWS = 22
UW_ROOM_BYTES = UW_COLS * UW_ROWS
UW_FILL_TILE = 0xF6
UW_FIRST_UNWALKABLE_TILE = 0x78
UW_ROOM_BOUNDS = (0x21, 0xD0, 0x5E, 0xBD)

UW_BG_BLOCK_NAME = "dat/PatternBlockUWBG.dat"
UW_BG_BLOCK_FIRST_TILE = 0x70  # PatternBlockPpuAddrs: $1700
UW_LAYOUTS_NAME = "dat/RoomLayoutsUW.dat"
UW_COLUMNS_PER_ROOM = 12
UW_FLOOR_ROWS = 7
UW_FLOOR_ORIGIN = 0x5C  # $658C - PlayAreaTiles: column 4, row 4
UW_WALL_LIST_LENGTH = 0x4E

# Direction index as the door code uses it: 0 E, 1 W, 2 S, 3 N.
DOOR_BITS = (0x01, 0x02, 0x04, 0x08)
DOOR_DEST = (0x271, 0x1F, 0x146, 0x135)
DOOR_SECOND_HALF = (0x02, 0x02, 0x2C, 0x2C)
DOOR_COLUMNS = (3, 3, 2, 2)
DOOR_ROWS_MINUS_ONE = (1, 1, 2, 2)
DOOR_NEXT_TILE = (0x14, 0x01, 0x01)
DOOR_FACE_LABELS = ("DoorFaceTilesE", "DoorFaceTilesW", "DoorFaceTilesS", "DoorFaceTilesN")
DOOR_FACE_BYTES = 12
DOOR_TILE_COUNT = 12
ROOM_ID_STEP = (1, -1, 16, -16)

DOOR_OPEN, DOOR_WALL = 0, 1
DOOR_SHUTTER = 7

# LevelInfo_CellarRoomIdArray: six room ids, $FF where unused.
CELLAR_ARRAY_OFFSET = 0x6BB2 - B.LEVEL_INFO_BASE
CELLAR_ARRAY_LENGTH = 10
CELLAR_UNIQUE_IDS = (0x3E, 0x3F)   # tunnel, treasure room
CELLAR_PALETTE_ROW = 2             # CellarAttrsTransferBuf makes every attribute $AA
STAIRS_TILE = 0x70                 # the stairs a trigger-5 push block uncovers (four tiles, column-major)
STAIRS_PALETTE_ROW = 2             # every room with such a block has attribute A and B = 2
# room A, room B, position in the destination, item, item X, item Y, room id, kind
CELLAR_INFO_BYTES = 8


@dataclass(frozen=True)
class UwData:
    tile_bank: bytes          # 8x8 planar tiles, 32 bytes each
    tile_nes: bytes           # raw NES tile index behind each bank entry
    rooms: list[bytes]        # UW_ROOM_BYTES row-major bank ids per stored room
    room_index: list[int]     # room id -> stored room, 0xFF when absent
    door_types: list[tuple[int, int, int, int]]  # E, W, S, N
    open_faces: list[list[list[int]]]            # [room][dir] -> 12 bank ids
    door_cells: list[list[int]]                  # [dir] -> 12 row-major map offsets
    start_room: int
    start_y: int
    level: int
    triforce_room: int = 0    # LevelInfo_TriforceRoomId: where the compass marker points
    boss_room: int = 0        # LevelInfo_BossRoomId: the room whose clearing ends the boss's ambient roar
    map_col0: int = 0         # room column drawn in the minimap's first column
    actors: object = None
    cellar_maps: tuple = ()   # UW_ROOM_BYTES row-major bank ids per cellar
    cellar_info: tuple = ()   # CELLAR_INFO_BYTES per cellar
    stairs_first: int = 0     # bank id of the four stairs tiles ($70-$73, column-major) a trigger-5 push block uncovers; 0 = none
    quest: int = 0            # 0 the First Quest's dungeon, 1 the Second Quest's (LevelBlockUW*Q2 and the LevelInfo replacements)

    @property
    def key(self) -> str:
        """What names the dungeon's tables: "3" for the First Quest's Level 3, "3q2" for the Second Quest's."""
        return level_key(self.level, self.quest)


def level_key(level: int, quest: int = 0) -> str:
    return f"{level}q2" if quest else f"{level}"


QUEST_INFO_FIRST = 0x6BA7 - B.LEVEL_INFO_BASE      # LevelInfo_ShortcutOrItemPosArray: where UpdateMode2Load_Full copies the replacements


def level_info(source_root: Path, level: int, quest: int = 0) -> bytes:
    """LevelInfoUW<level> as the game has it in RAM: in the Second Quest UpdateMode2Load_Full copies LevelInfoUWQ2Replacements<level>
    (item positions, map rotation, start and triforce rooms, cellar array, boss room, map mask, the map's transfer buffer) over it."""
    info = bytearray(B.require_binary(source_root, f"dat/LevelInfoUW{level}.dat"))
    if quest:
        asm = (source_root / "src" / "Z_06.asm").read_text(encoding="utf-8", errors="replace")
        replacement = B.parse_asm_byte_table(asm, f"LevelInfoUWQ2Replacements{level}")
        info[QUEST_INFO_FIRST : QUEST_INFO_FIRST + len(replacement)] = bytes(replacement)
    return bytes(info)


def level_block(source_root: Path, level: int, quest: int = 0) -> bytes:
    name = ("UW1" if level <= 6 else "UW2") + ("Q2" if quest else "Q1")
    return B.require_binary(source_root, f"dat/LevelBlock{name}.dat")


MINIMAP_COLUMNS = 8
UW_SQUARE_COLS, UW_SQUARE_ROWS = 16, 11
UW_PACKED_BYTES = UW_SQUARE_COLS * UW_SQUARE_ROWS


def pack_squares(grids) -> tuple[bytes, list[bytes]]:
    """Rooms (and cellars) as squares: the quad table of 4 bank ids each distinct 2x2 block of cells is made of, and per room
    one quad number for each of its 16x11 squares. Every room of the game is laid out in squares, so a level needs about a
    hundred quads and a room shrinks from 704 bytes to 176. A quad is top-left, top-right, bottom-left, bottom-right."""
    quads: dict[tuple[int, int, int, int], int] = {}
    packed = []
    for grid in grids:
        out = bytearray()
        for sy in range(UW_SQUARE_ROWS):
            for sx in range(UW_SQUARE_COLS):
                top = (2 * sy) * UW_COLS + 2 * sx
                key = (grid[top], grid[top + 1], grid[top + UW_COLS], grid[top + UW_COLS + 1])
                out.append(quads.setdefault(key, len(quads)))
        packed.append(bytes(out))
    if len(quads) > 256:
        raise SystemExit(f"A level needs {len(quads)} square patterns; a byte index allows 256")
    return b"".join(bytes(key) for key in quads), packed


def unpack_squares(table: bytes, packed: bytes) -> bytes:
    """What uw_unpack_room does: the 704 cells of a packed room."""
    grid = bytearray(UW_COLS * UW_ROWS)
    for index, quad in enumerate(packed):
        sy, sx = divmod(index, UW_SQUARE_COLS)
        top = (2 * sy) * UW_COLS + 2 * sx
        a, b, c, d = table[quad * 4 : quad * 4 + 4]
        grid[top], grid[top + 1], grid[top + UW_COLS], grid[top + UW_COLS + 1] = a, b, c, d
    return bytes(grid)


def minimap_first_column(rooms) -> int:
    """The first of the eight room columns the status-bar map shows.

    A level is at most eight columns wide, but it may wrap past column 15 (level 2 does), so the
    window is circular. The level is centred in it, as LevelInfo_StatusBarMapXOffset does.
    """
    columns = sorted({room & 15 for room in rooms})
    best = None
    for start in range(16):
        span = max(((column - start) & 15) for column in columns) + 1
        if span <= MINIMAP_COLUMNS and (best is None or span < best[0]):
            best = (span, start)
    if best is None:
        raise SystemExit("A level wider than the eight columns of the status-bar map")
    span, start = best
    return (start - (MINIMAP_COLUMNS - span) // 2) & 15


def _col_major_to_cell(index: int) -> int:
    col, row = divmod(index, UW_ROWS)
    return row * UW_COLS + col


def parse_heaps(asm_text: str) -> tuple[list[int], list[int]]:
    """The heaps are contiguous in ROM and a column may run on into the next one."""
    blob: list[int] = []
    starts: list[int] = []
    for digit in range(10):
        starts.append(len(blob))
        blob.extend(B.parse_asm_byte_table(asm_text, f"ColumnHeapUW{digit}"))
    blob.extend(B.parse_asm_byte_table(asm_text, "RoomLayoutUWCellar0"))
    return blob, starts


def _write_square(tm: bytearray, col: int, row: int, primary: int) -> None:
    base = col * UW_ROWS + row
    if 0x70 <= primary < 0xF3:
        tm[base] = primary
        tm[base + 1] = primary + 1
        tm[base + UW_ROWS] = primary + 2
        tm[base + UW_ROWS + 1] = primary + 3
    else:
        tm[base] = tm[base + 1] = tm[base + UW_ROWS] = tm[base + UW_ROWS + 1] = primary


def _find_column(heap: list[int], start: int, column_index: int) -> int:
    remaining = column_index
    for pos in range(start, len(heap)):
        if heap[pos] & 0x80:
            remaining -= 1
            if remaining < 0:
                return pos
    raise SystemExit(f"UW column {column_index} is past the end of its heap")


def layout_floor(
    tm: bytearray, descriptors: bytes, heap: list[int], starts: list[int], primary: list[int]
) -> None:
    for column, descriptor in enumerate(descriptors):
        pos = _find_column(heap, starts[descriptor >> 4], descriptor & 0x0F)
        repeat = 0
        for row in range(UW_FLOOR_ROWS):
            square = heap[pos]
            _write_square(tm, 4 + column * 2, 4 + row * 2, primary[square & 7])
            if ((square >> 4) & 7) == repeat:
                repeat = 0
                pos += 1
            else:
                repeat += 1


def fill_walls(tm: bytearray, wall_list: list[int]) -> None:
    top, bottom, count = 0x17, 0x2A, 10
    for tile in wall_list[:UW_WALL_LIST_LENGTH]:
        if tile == 0:
            count = 0x13
            top += 0x13
            bottom += 0x19
            continue
        tm[top] = tile
        tm[bottom] = tile if tile == 0xDE or tile >= 0xE2 else tile + 1
        count -= 1
        if count:
            top += 1
            bottom -= 1
        else:
            count = 10
            top += 0x0D
            bottom += 0x1F

    # The right half is the left half turned through 180 degrees.
    for source in range(UW_ROOM_BYTES // 2):
        tile = tm[source]
        dest = UW_ROOM_BYTES - 1 - source
        if tile == 0xDD:
            tm[dest] = 0xDC
        elif tile >= 0xE0:
            tm[dest] = tile
        elif tile >= 0xDC:
            tm[dest] = tile + 1
        else:
            tm[dest] = tile + 2


def door_type(attr_a: int, attr_b: int, direction: int) -> int:
    return ((attr_b >> 2) & 7, (attr_b >> 5) & 7, (attr_a >> 2) & 7, (attr_a >> 5) & 7)[direction]


def door_cells(direction: int) -> list[int]:
    """Column-major map offsets of the 12 tiles a door face covers, in source order."""
    cells = []
    for half in (1, 0):
        dest = DOOR_DEST[direction] + (0 if half else DOOR_SECOND_HALF[direction])
        for _ in range(DOOR_COLUMNS[direction]):
            for x in range(DOOR_ROWS_MINUS_ONE[direction], -1, -1):
                cells.append(dest)
                dest += DOOR_NEXT_TILE[x]
                if x == 0 and direction < 2:
                    dest += 1
    return cells


def lay_out_doors(tm: bytearray, attr_a: int, attr_b: int, opened: int, faces: list[list[int]]) -> None:
    for direction in (3, 2, 1, 0):
        bit = DOOR_BITS[direction]
        kind = door_type(attr_a, attr_b, direction)
        mask = opened
        if kind >= 5:
            face = kind
        elif kind == 4:
            face = 8
        else:
            mask &= ~bit
            face = 4 if kind == 0 else kind
        if mask & bit:
            face = 4 if face == 7 else (9 if face == 8 else 4)
        if face < 4:
            continue
        index = face - 3
        if index >= 3:
            index -= 1
        source = faces[direction][(index - 1) * DOOR_FACE_BYTES : index * DOOR_FACE_BYTES]
        for cell, tile in zip(door_cells(direction), source):
            tm[cell] = tile


def build_room(
    unique_id: int,
    attr_a: int,
    attr_b: int,
    opened: int,
    layouts: bytes,
    heap: list[int],
    starts: list[int],
    primary: list[int],
    wall_list: list[int],
    faces: list[list[int]],
) -> bytearray:
    tm = bytearray([UW_FILL_TILE]) * UW_ROOM_BYTES
    fill_walls(tm, wall_list)
    lay_out_doors(tm, attr_a, attr_b, opened, faces)
    base = unique_id * UW_COLUMNS_PER_ROOM
    layout_floor(tm, layouts[base : base + UW_COLUMNS_PER_ROOM], heap, starts, primary)
    return tm


def reachable_rooms(start: int, attrs_a: bytes, attrs_b: bytes) -> list[int]:
    seen = {start}
    todo = [start]
    while todo:
        room = todo.pop()
        for direction in range(4):
            if door_type(attrs_a[room], attrs_b[room], direction) == DOOR_WALL:
                continue
            target = room + ROOM_ID_STEP[direction]
            if not 0 <= target < 128 or target in seen:
                continue
            if direction < 2 and target // 16 != room // 16:
                continue
            seen.add(target)
            todo.append(target)
    return sorted(seen)


def cellar_rooms(info: bytes, attrs_d: bytes) -> list[int]:
    """The ids LevelInfo_CellarRoomIdArray lists that really are cellars (tunnel $3E or treasure room $3F)."""
    listed = info[CELLAR_ARRAY_OFFSET : CELLAR_ARRAY_OFFSET + CELLAR_ARRAY_LENGTH]
    return [room for room in dict.fromkeys(listed) if room < 128 and (attrs_d[room] & 0x3F) in CELLAR_UNIQUE_IDS]


def level_rooms(start: int, info: bytes, attrs_a: bytes, attrs_b: bytes, attrs_d: bytes) -> list[int]:
    """Every room of a dungeon: those reachable through doors from the start room, and those that tunnels lead to.

    A tunnel ($3E) is a cellar whose attributes A and B are the rooms its two stairs come out in; levels 4 to 9
    have rooms that can only be reached that way (the triforce room of Levels 6 to 8 does). The cellar ids
    themselves are not rooms of the grid, so they are left out.
    """
    cellars = cellar_rooms(info, attrs_d)
    seen = set(reachable_rooms(start, attrs_a, attrs_b))
    changed = True
    while changed:
        changed = False
        for cellar in cellars:
            ends = [room for room in (attrs_a[cellar], attrs_b[cellar]) if room < 128]
            if not any(room in seen for room in ends):
                continue                                    # nobody can get down these stairs yet
            for room in ends:
                if room not in seen:
                    seen.update(reachable_rooms(room, attrs_a, attrs_b))
                    changed = True
    return sorted(seen - set(cellars))


# Palette rows of the shared overworld table whose slots no level may repurpose: Link's own row
# (his sprite is baked once, for every level) and the cave wall row the cellars use.
PROTECTED_ROWS = (B.LINK_PALETTE_ROW, B.CAVE_WALL_ROW, B.HUD_TEXT_ROW, B.HUD_ACCENT_ROW)
# Slots the 68000 code names directly: the minimap colours (MM_* in hud.s; tests keep the two in step).
PROTECTED_SLOTS = (1, 2, 4, 7, 9)


def palette_lookup(ow_palette: bytes, ow_map: "B.PaletteMap", uw_palette: bytes):
    """Express a level's palette rows in a 16-colour ST palette that keeps the overworld's slot numbers.

    Everything baked once for all modes (Link, items, effects, the HUD, the cellar walls) names a colour by
    its slot in the overworld's table, so a slot must keep meaning "that colour" wherever it is shown.
    Colours the level shares with the overworld therefore keep their slot. The few colours the overworld
    lacks (levels 3-9 have up to three) take over slots whose overworld colour the level does not use and
    that nothing baked relies on, background-only colours first. Returns (table, st_colors): table[row][pixel]
    is the slot a CHR pixel takes in this level and st_colors the 16 ST words to load while inside it.
    """
    known: dict[int, int] = {}
    slot_colour: dict[int, int] = {}
    for row in range(B.PALETTE_ROWS):
        for pixel in range(B.PALETTE_ROW_COLORS):
            nes = ow_palette[0] if pixel == 0 else ow_palette[row * 4 + pixel]
            known[nes] = ow_map.table[row][pixel]
            slot_colour[ow_map.table[row][pixel]] = nes

    wanted = [uw_palette[0]]
    for row in range(B.PALETTE_ROWS):
        wanted.extend(uw_palette[row * 4 + pixel] for pixel in range(1, B.PALETTE_ROW_COLORS))
    wanted = list(dict.fromkeys(wanted))
    if uw_palette[0] != ow_palette[0]:
        raise SystemExit("A level's backdrop differs from the overworld's; slot 0 would change meaning")

    protected = {ow_map.table[row][pixel] for row in PROTECTED_ROWS if row < len(ow_map.table)
                 for pixel in range(B.PALETTE_ROW_COLORS)} | set(PROTECTED_SLOTS)
    sprite_slots = {ow_map.table[row][pixel] for row in range(4, 8) for pixel in range(B.PALETTE_ROW_COLORS)}
    keep = {known[nes] for nes in wanted if nes in known}
    spare = sorted((slot for slot in slot_colour if slot not in keep and slot not in protected),
                   key=lambda slot: (slot in sprite_slots, slot))

    slot_of = {nes: known[nes] for nes in wanted if nes in known}
    st_colors = list(ow_map.st_colors)
    for nes in wanted:
        if nes in slot_of:
            continue
        if not spare:
            raise SystemExit(f"Level colour {nes:#04x} has no free slot in the shared ST palette")
        slot = spare.pop(0)
        slot_of[nes] = slot
        st_colors[slot] = B.nes_color_to_st(nes)

    table = []
    for row in range(B.PALETTE_ROWS):
        table.append(tuple(slot_of[uw_palette[0] if pixel == 0 else uw_palette[row * 4 + pixel]]
                           for pixel in range(B.PALETTE_ROW_COLORS)))
    return table, tuple(st_colors)


def level_palettes(source_root: Path, ow_palette: bytes, ow_map) -> list[tuple[int, ...]]:
    """The 16 ST colours to show inside each of the nine levels (slot-compatible with the overworld)."""
    result = []
    for level in range(1, 10):
        info = B.require_binary(source_root, f"dat/LevelInfoUW{level}.dat")
        uw_palette = info[B.LEVEL_INFO_PALETTE_OFFSET : B.LEVEL_INFO_PALETTE_OFFSET + 32]
        result.append(palette_lookup(ow_palette, ow_map, uw_palette)[1])
    return result


def build_cellars(asm: str, info: bytes, attrs, bank_id) -> tuple[list[bytes], list[bytes]]:
    """Stairs lead to cellar rooms, which are laid out like overworld caves."""
    attrs_a, attrs_b, attrs_c, attrs_d, attrs_e, attrs_f = attrs
    primary = B.parse_asm_byte_table(asm, "PrimarySquaresOW")
    secondary = B.parse_asm_byte_table(asm, "SecondarySquaresOW")
    heap = B.parse_asm_byte_table(asm, "ColumnHeapUWCellar")
    layouts = [B.parse_asm_byte_table(asm, f"RoomLayoutUWCellar{kind}") for kind in (0, 1)]
    positions = info[B.LEVEL_INFO_ITEM_POSITIONS : B.LEVEL_INFO_ITEM_POSITIONS + 4]

    maps: list[bytes] = []
    records: list[bytes] = []
    listed = info[CELLAR_ARRAY_OFFSET : CELLAR_ARRAY_OFFSET + CELLAR_ARRAY_LENGTH]
    for room in dict.fromkeys(listed):
        if room >= 128 or (attrs_d[room] & 0x3F) not in CELLAR_UNIQUE_IDS:
            continue
        kind = attrs_d[room] & 1
        columns = [B.decode_column(heap, 0, d & 0x0F) for d in layouts[kind]]
        grid = bytearray(UW_ROOM_BYTES)
        for row in range(B.OW_ROOM_ROWS):
            for col in range(B.OW_ROOM_COLS):
                quad = B.square_to_tiles(columns[col][row], primary, secondary)
                for index, tile in enumerate(quad):
                    cell = (row * 2 + index // 2) * UW_COLS + col * 2 + index % 2
                    grid[cell] = bank_id(tile, CELLAR_PALETTE_ROW)
        maps.append(bytes(grid))

        item = attrs_e[room] & 0x1F
        position = positions[(attrs_f[room] & 0x30) >> 4]
        records.append(bytes((
            attrs_a[room], attrs_b[room], attrs_c[room], 0xFF if item == 3 else item,
            position & 0xF0, (position & 0x0F) << 4, room, kind,
        )))
    return maps, records


def build_level(source_root: Path, level: int, bg_tiles, ow_palette_bytes: bytes, ow_map, ow_sprite_tiles=None,
                text_base: int | None = None, quest: int = 0) -> UwData:
    asm = (source_root / "src" / "Z_05.asm").read_text(encoding="utf-8", errors="replace")
    heap, starts = parse_heaps(asm)
    primary = B.parse_asm_byte_table(asm, "PrimarySquaresUW")
    wall_list = B.parse_asm_byte_table(asm, "WallTileList")
    faces = [B.parse_asm_byte_table(asm, label) for label in DOOR_FACE_LABELS]
    layouts = B.require_binary(source_root, UW_LAYOUTS_NAME)

    block = level_block(source_root, level, quest)
    info = level_info(source_root, level, quest)
    size = B.LEVEL_BLOCK_TABLE_SIZE
    attrs = [block[i * size : (i + 1) * size] for i in range(6)]
    attrs_a, attrs_b, attrs_d = attrs[0], attrs[1], attrs[3]

    start_room = info[B.LEVEL_INFO_START_ROOM_ID]
    start_y = info[B.LEVEL_INFO_START_Y]
    uw_palette = info[B.LEVEL_INFO_PALETTE_OFFSET : B.LEVEL_INFO_PALETTE_OFFSET + 32]
    pal_table, _ = palette_lookup(ow_palette_bytes, ow_map, uw_palette)

    stored = level_rooms(start_room, info, attrs_a, attrs_b, attrs_d)
    room_index = [0xFF] * 128
    for index, room in enumerate(stored):
        room_index[room] = index

    bank_ids: dict[tuple[int, int], int] = {}
    bank_keys: list[tuple[int, int]] = []

    def bank_id(tile: int, row: int) -> int:
        key = (tile, row)
        if key not in bank_ids:
            bank_ids[key] = len(bank_keys)
            bank_keys.append(key)
        return bank_ids[key]

    def palette_row(cell_col: int, cell_row: int, outer: int, inner: int) -> int:
        in_inner = (cell_col >> 1) in range(2, 14) and (cell_row >> 1) in range(2, 9)
        return inner if in_inner else outer

    cells = [[_col_major_to_cell(c) for c in door_cells(d)] for d in range(4)]
    rooms: list[bytes] = []
    types: list[tuple[int, int, int, int]] = []
    open_faces: list[list[list[int]]] = []
    for room in stored:
        a, b = attrs_a[room], attrs_b[room]
        outer, inner = a & 3, b & 3
        closed = build_room(attrs_d[room] & 0x3F, a, b, 0, layouts, heap, starts, primary, wall_list, faces)
        grid = bytearray(UW_ROOM_BYTES)
        for index, tile in enumerate(closed):
            col, row = divmod(index, UW_ROWS)
            grid[row * UW_COLS + col] = bank_id(tile, palette_row(col, row, outer, inner))
        rooms.append(bytes(grid))
        types.append(tuple(door_type(a, b, d) for d in range(4)))
        per_dir = []
        for d in range(4):
            opened = build_room(
                attrs_d[room] & 0x3F, a, b, DOOR_BITS[d], layouts, heap, starts, primary, wall_list, faces
            )
            ids = []
            for cell in door_cells(d):
                col, row = divmod(cell, UW_ROWS)
                ids.append(bank_id(opened[cell], palette_row(col, row, outer, inner)))
            per_dir.append(ids)
        open_faces.append(per_dir)

    cellar_maps, cellar_info = build_cellars(asm, info, attrs, bank_id)

    # CheckSecretTriggerBlockStairs: pushing the block of a trigger-5 room puts the stairs tile ($70) at ($D0, $60). The four
    # tiles go in as the last four bank entries, in palette row 2 like every room that has such a block.
    stairs_first = 0
    if any((attrs[5][room] & 7) == 5 and attrs_d[room] & 0x40 for room in stored):
        stairs_first = len(bank_keys)
        bank_keys.extend((tile, STAIRS_PALETTE_ROW) for tile in range(STAIRS_TILE, STAIRS_TILE + 4))

    if len(bank_keys) > 256:
        raise SystemExit(f"Level {level} needs {len(bank_keys)} tiles; a byte index allows 256")

    bank = bytearray()
    for tile, row in bank_keys:
        for y in range(8):
            bank.extend(B.pack_hud_row([pal_table[row][value] for value in bg_tiles[tile][y]]))

    return UwData(
        tile_bank=bytes(bank),
        tile_nes=bytes(tile for tile, _ in bank_keys),
        rooms=rooms,
        room_index=room_index,
        door_types=types,
        open_faces=open_faces,
        door_cells=cells,
        start_room=start_room,
        start_y=start_y,
        level=level,
        triforce_room=info[B.LEVEL_INFO_TRIFORCE_ROOM_ID],
        boss_room=info[B.LEVEL_INFO_BOSS_ROOM_ID],
        map_col0=minimap_first_column(stored),
        actors=actors.build_actors(
            source_root, level, bg_tiles, ow_map, stored, (attrs[2], attrs_d, attrs[4], attrs[5]), info, ow_sprite_tiles,
            text_base=text_base,
        ),
        cellar_maps=tuple(cellar_maps),
        cellar_info=tuple(cellar_info),
        stairs_first=stairs_first,
        quest=quest,
    )
