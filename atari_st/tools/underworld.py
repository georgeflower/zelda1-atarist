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
CELLAR_ARRAY_LENGTH = 6
CELLAR_UNIQUE_IDS = (0x3E, 0x3F)   # tunnel, treasure room
CELLAR_PALETTE_ROW = 2             # CellarAttrsTransferBuf makes every attribute $AA
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
    actors: object = None
    cellar_maps: tuple = ()   # UW_ROOM_BYTES row-major bank ids per cellar
    cellar_info: tuple = ()   # CELLAR_INFO_BYTES per cellar


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


def palette_lookup(ow_palette: bytes, ow_map: "B.PaletteMap", uw_palette: bytes):
    """Express the level's palette rows in the overworld's shared ST palette."""
    known = {}
    for row in range(B.PALETTE_ROWS):
        for pixel in range(B.PALETTE_ROW_COLORS):
            nes = ow_palette[0] if pixel == 0 else ow_palette[row * 4 + pixel]
            known[nes] = ow_map.table[row][pixel]
    table = []
    for row in range(B.PALETTE_ROWS):
        entries = []
        for pixel in range(B.PALETTE_ROW_COLORS):
            nes = uw_palette[0] if pixel == 0 else uw_palette[row * 4 + pixel]
            if nes not in known:
                raise SystemExit(f"Underworld colour {nes:#04x} is missing from the shared ST palette")
            entries.append(known[nes])
        table.append(tuple(entries))
    return table


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


def build_level(source_root: Path, level: int, bg_tiles, ow_palette_bytes: bytes, ow_map) -> UwData:
    asm = (source_root / "src" / "Z_05.asm").read_text(encoding="utf-8", errors="replace")
    heap, starts = parse_heaps(asm)
    primary = B.parse_asm_byte_table(asm, "PrimarySquaresUW")
    wall_list = B.parse_asm_byte_table(asm, "WallTileList")
    faces = [B.parse_asm_byte_table(asm, label) for label in DOOR_FACE_LABELS]
    layouts = B.require_binary(source_root, UW_LAYOUTS_NAME)

    quest_block = "UW1Q1" if level <= 6 else "UW2Q1"
    block = B.require_binary(source_root, f"dat/LevelBlock{quest_block}.dat")
    info = B.require_binary(source_root, f"dat/LevelInfoUW{level}.dat")
    size = B.LEVEL_BLOCK_TABLE_SIZE
    attrs = [block[i * size : (i + 1) * size] for i in range(6)]
    attrs_a, attrs_b, attrs_d = attrs[0], attrs[1], attrs[3]

    start_room = info[B.LEVEL_INFO_START_ROOM_ID]
    start_y = info[B.LEVEL_INFO_START_Y]
    uw_palette = info[B.LEVEL_INFO_PALETTE_OFFSET : B.LEVEL_INFO_PALETTE_OFFSET + 32]
    pal_table = palette_lookup(ow_palette_bytes, ow_map, uw_palette)

    stored = reachable_rooms(start_room, attrs_a, attrs_b)
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
        actors=actors.build_actors(
            source_root, level, bg_tiles, ow_map, stored, (attrs[2], attrs_d, attrs[4], attrs[5]), info
        ),
        cellar_maps=tuple(cellar_maps),
        cellar_info=tuple(cellar_info),
    )


def build_placeholder() -> UwData:
    """One brick-bordered room, so the ST target still assembles without a ROM."""
    grid = bytearray()
    for row in range(UW_ROWS):
        for col in range(UW_COLS):
            edge = row in (0, UW_ROWS - 1) or col in (0, UW_COLS - 1)
            grid.append(1 if edge else 0)
    bank = bytearray()
    for tile in range(2):
        for _ in range(8):
            bank.extend(B.pack_hud_row([1 + tile * 2] * 8))
    room_index = [0xFF] * 128
    room_index[0x73] = 0
    return UwData(
        tile_bank=bytes(bank),
        tile_nes=bytes((0x24, 0xF6)),
        rooms=[bytes(grid)],
        room_index=room_index,
        door_types=[(DOOR_WALL, DOOR_WALL, DOOR_OPEN, DOOR_WALL)],
        open_faces=[[[0] * DOOR_TILE_COUNT for _ in range(4)]],
        door_cells=[[0] * DOOR_TILE_COUNT for _ in range(4)],
        start_room=0x73,
        start_y=0xDD,
        level=1,
        actors=actors.build_placeholder(),
    )
