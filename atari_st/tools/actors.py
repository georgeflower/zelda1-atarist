"""Monsters, floor items and room contents for the underworld.

Everything is read from the disassembly tables the 6502 uses, so the ST only
has to look values up: sprite frames (ObjAnimations / ObjAnimFrameHeap /
ObjAnimAttrHeap), hit points (ObjectTypeToHpPairs), drops (DropItemTable) and
item art (Anim_ItemFrameOffsets / Anim_ItemFrameTiles).
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import build_assets as B

# Monsters this port draws and moves so far (Level 1's repertoire). Others in a
# room (traps, and the monsters of later levels) are left out for now.
MONSTER_TYPES = (0x06, 0x15, 0x1B, 0x28, 0x2A, 0x27, 0x3D, 0x49)
# Frames between one-pixel steps: the 6502's quarter-speed $20 is half a pixel
# a frame; keese are quicker, gels and wallmasters slower. Aquamentus moves a
# pixel every eighth frame.
MONSTER_PERIOD = {0x06: 2, 0x15: 3, 0x1B: 1, 0x28: 2, 0x2A: 2, 0x27: 3, 0x3D: 8, 0x49: 1}
# Half-hearts of damage on contact (ObjTypeToDamagePoints: $80 is half a heart).
MONSTER_DAMAGE = {0x06: 1, 0x15: 1, 0x1B: 1, 0x28: 1, 0x2A: 1, 0x27: 1, 0x3D: 2, 0x49: 2}
# Keese ignore walls and blocks and are only held in by the room edges.
MONSTER_FLYERS = (0x1B,)

# What the game does with a monster every frame, besides drawing it.
BEHAVIOUR_WANDER, BEHAVIOUR_ROPE, BEHAVIOUR_GORIYA, BEHAVIOUR_WALLMASTER, BEHAVIOUR_BOSS, BEHAVIOUR_KEESE, BEHAVIOUR_TRAP = range(7)
MONSTER_BEHAVIOUR = {0x28: BEHAVIOUR_ROPE, 0x06: BEHAVIOUR_GORIYA, 0x1B: BEHAVIOUR_KEESE,
                      0x27: BEHAVIOUR_WALLMASTER, 0x3D: BEHAVIOUR_BOSS, 0x49: BEHAVIOUR_TRAP}

# How each monster is drawn: (sprite layout, images, mode). The layout says how
# the two 8x16 halves of an image are put together; the mode tells the game
# which image and mirroring to pick every frame, as the original's update
# routines do.
MODE_WALKER = 0     # right/left: walk frame, flipped to face left; down and up: flip alternates
MODE_STALFOS = 1    # one image whose flip alternates
MODE_ROPE = 2       # walk frame, flipped to face left
MODE_GEL = 3        # two narrow images, swapped every two frames
MODE_KEESE = 4      # two mirrored images, wings beating
MODE_WALLMASTER = 5  # open and closed hand, swapped every eight frames
MODE_BOSS = 6       # drawn from the boss pieces instead
MODE_STATIC = 7     # one picture, never mirrored: the blade trap
MONSTER_DRAW = {
    0x06: ("wide", 4, MODE_WALKER),
    0x15: ("narrow", 2, MODE_GEL),
    0x1B: ("mirror", 2, MODE_KEESE),
    0x28: ("wide", 2, MODE_ROPE),
    0x2A: ("wide", 1, MODE_STALFOS),
    0x27: ("wide", 2, MODE_WALLMASTER),
    0x3D: ("wide", 1, MODE_BOSS),
    0x49: ("mirror", 1, MODE_STATIC),
}
MONSTER_IMAGES = 4          # image slots per monster, each stored plain and flipped
FRAME_BYTES = B.SPRITE_FRAME_BYTES
NO_DROP_ROW = 0xFF
ROOM_INFO_BYTES = 14

ITEM_IDS = (0x00, 0x01, 0x0A, 0x0F, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1D, 0x22, 0x06)
BOOMERANG_ITEM = 0x1D
FIRE_ANIM_INDEX = 0x41
HUD_ITEM_IDS = (0x01, 0x00, BOOMERANG_ITEM, 0x06)    # sword, bomb, boomerang, candle

UW_SP_COMMON = "dat/CommonSpritePatterns.dat"
UW_SP_DEMO = "dat/DemoSpritePatterns.dat"
UW_SP_DEMO_FIRST = 0x70
UW_SP_BLOCK = ("dat/PatternBlockUWSP.dat", 0x8E)
UW_SP_LEVEL_BLOCKS = {1: "dat/PatternBlockUWSP127.dat", 2: "dat/PatternBlockUWSP127.dat",
                      7: "dat/PatternBlockUWSP127.dat"}
UW_SP_LEVEL_FIRST = 0x9E
UW_SP_BOSS_BLOCKS = {1: "dat/PatternBlockUWSPBoss1257.dat", 2: "dat/PatternBlockUWSPBoss1257.dat",
                     5: "dat/PatternBlockUWSPBoss1257.dat", 7: "dat/PatternBlockUWSPBoss1257.dat"}
UW_SP_BOSS_FIRST = 0xC0


@dataclass(frozen=True)
class ActorData:
    mon_sprites: bytes        # monster, frame, flip -> one masked 16x16 frame
    mon_table: bytes          # 8 bytes per monster: type, hp, period, damage, drop row, flies, draw mode, behaviour
    mon_index: bytes          # NES object type -> monster index, 0xFF for none
    item_sprites: bytes       # one masked 16x16 frame per item
    item_index: bytes         # item id (0..63) -> item index, 0xFF for none
    drop_table: bytes
    drop_rates: bytes
    sword_sprites: bytes      # up, down, left, right
    beam_sprites: bytes       # the sword's shot: up, down, left, right, each in four palette rows
    fx_sprites: bytes         # two bomb clouds, then four spark corners in four palette rows each
    proj_sprites: bytes       # 4 boomerang turns, 2 fireball frames, then 4 pieces for each Aquamentus image
    hud_items: bytes          # sword, bomb, boomerang, candle as two status bar tiles each, top then bottom
    room_info: list[bytes]    # 16 bytes per stored room
    keese_index: int = 0      # monster index of the keese the cellars are full of


def _pack_masked(rows: list[list[int]]) -> bytes:
    """16 rows of 16 palette indices (-1 transparent) -> four planes and a mask per row."""
    packed = bytearray()
    for row in rows:
        packed.extend(B.pack_st_row(max(p, 0) for p in row))
        mask = 0
        for x, pixel in enumerate(row):
            if pixel >= 0:
                mask |= 1 << (15 - x)
        packed.extend(mask.to_bytes(2, "big"))
    return bytes(packed)


def _tile_rows(tiles, palette, row: int, tile: int, flip: bool = False) -> list[list[int]]:
    """An 8x16 NES sprite (tile on top, tile+1 below) as palette indices, -1 transparent."""
    rows = []
    for y in range(16):
        pixels = list(tiles[tile + (1 if y >= 8 else 0)][y % 8])
        if flip:
            pixels.reverse()
        rows.append([-1 if p == 0 else palette.index(row, p) for p in pixels])
    return rows


def _join(left: list[list[int]], right: list[list[int]]) -> list[list[int]]:
    return [a + b for a, b in zip(left, right)]


def _monster_image(tiles, palette, row: int, tile: int, layout: str) -> list[list[int]]:
    """One monster image: left tile, then the right half as the layout dictates."""
    left = _tile_rows(tiles, palette, row, tile)
    if layout == "narrow":
        return [[-1] * 4 + r[:8] + [-1] * 4 for r in left]
    if layout == "mirror":
        return _join(left, _tile_rows(tiles, palette, row, tile, flip=True))
    return _join(left, _tile_rows(tiles, palette, row, tile + 2))


def _blank(width: int) -> list[list[int]]:
    return [[-1] * width for _ in range(16)]


def _sprite_table(source_root: Path, level: int):
    # Tiles $70-$8D (the sword's sideways blade, the bomb cloud) are never loaded
    # by the level code: they are what the title demo left at $0700 in CHR RAM.
    demo = B.require_binary(source_root, UW_SP_DEMO)[: UW_SP_BLOCK[1] * 16 - UW_SP_DEMO_FIRST * 16]
    parts = [(0, B.require_binary(source_root, UW_SP_COMMON)),
             (UW_SP_DEMO_FIRST, demo),
             (UW_SP_BLOCK[1], B.require_binary(source_root, UW_SP_BLOCK[0]))]
    if level in UW_SP_LEVEL_BLOCKS:
        parts.append((UW_SP_LEVEL_FIRST, B.require_binary(source_root, UW_SP_LEVEL_BLOCKS[level])))
    if level in UW_SP_BOSS_BLOCKS:
        parts.append((UW_SP_BOSS_FIRST, B.require_binary(source_root, UW_SP_BOSS_BLOCKS[level])))
    return B.assemble_pattern_table(parts)


def _item_rows(sp_tiles, bg_tiles, palette, tile: int, row: int) -> list[list[int]]:
    """The 16x16 picture Anim_WriteSpecificItemSprites makes of an item tile."""
    # Odd tile numbers select the second pattern table, which holds the misc tiles.
    tiles = bg_tiles if tile & 1 else sp_tiles
    top = tile & 0xFE
    narrow = tile == 0xF3 or 0x20 <= tile < 0x62
    left = _tile_rows(tiles, palette, row, top)
    if narrow:
        return [[-1] * 4 + r[:8] + [-1] * 4 for r in left]
    if tile < 0x7C:
        right = _tile_rows(tiles, palette, row, top, flip=True)
    else:
        right = _tile_rows(tiles, palette, row, top + 2)
    return _join(left, right)


def _item_frame(code, sp_tiles, bg_tiles, palette, item_id: int):
    """One floor item, laid out the way Anim_WriteSpecificItemSprites does."""
    slot = code["slot"][item_id]
    tile = code["tiles"][code["offsets"][slot]]
    descriptor = code["descriptor"][item_id]
    base = code["palette"][slot]
    attr = (base + (descriptor & 0x0F)) if slot in (0, 2, 4, 7, 0x0B) else base
    return _pack_masked(_item_rows(sp_tiles, bg_tiles, palette, tile, 4 + (attr & 3)))


def _hud_item(code, sp_tiles, bg_tiles, palette, item_id: int) -> bytes:
    """An item as the two 8x8 status bar tiles that hold its 8x16 picture."""
    slot = code["slot"][item_id]
    tile = code["tiles"][code["offsets"][slot]]
    base = code["palette"][slot]
    attr = (base + (code["descriptor"][item_id] & 0x0F)) if slot in (0, 2, 4, 7, 0x0B) else base
    row = 4 + (attr & 3)
    tiles = bg_tiles if tile & 1 else sp_tiles
    backdrop = palette.index(row, 0)
    packed = bytearray()
    for pixels in _tile_rows(tiles, palette, row, tile & 0xFE):
        packed.extend(B.pack_hud_row([backdrop if p < 0 else p for p in pixels[:8]]))
    return bytes(packed)


def _hud_items(code, sp_tiles, bg_tiles, palette) -> bytes:
    return b"".join(_hud_item(code, sp_tiles, bg_tiles, palette, i) for i in HUD_ITEM_IDS)


def _boomerang_frames(code, sp_tiles, bg_tiles, palette) -> list[bytes]:
    """Eight spinning images (BoomerangFrameCycle with its attribute cycle) and the spark."""
    slot = code["slot"][BOOMERANG_ITEM]
    first = code["offsets"][slot]
    row = B.LINK_PALETTE_ROW + (code["palette"][slot] & 3)
    images = [_item_rows(sp_tiles, bg_tiles, palette, code["tiles"][first + n], row) for n in range(4)]
    cycle = ((0, False, False), (1, False, False), (2, False, False), (1, True, False),
             (0, True, False), (1, True, True), (2, False, True), (1, False, True))
    frames = [_pack_masked(_flip_rows(images[n], h, v)) for n, h, v in cycle]
    frames.append(_pack_masked(images[3]))
    return frames


SWORD_TILE_VERTICAL = 0x20        # RDirectionToWeaponFrame: frame 0 for up and down ...
SWORD_TILE_HORIZONTAL = 0x82      # ... frame 1 for left and right (Anim_ItemFrameTiles)
SPARK_TILE = 0x30
CLOUD_TILES = (0x70, 0x72)
SPARK_CORNER_FLIPS = (("h",), ("h", "v"), ("v",), ())    # SwordShotSpreadBaseAttr, by loop index


def _flip_rows(rows: list[list[int]], h: bool, v: bool) -> list[list[int]]:
    if v:
        rows = rows[::-1]
    return [r[::-1] for r in rows] if h else rows


def _weapon_rows(sp_tiles, bg_tiles, palette, direction: str, row: int) -> list[list[int]]:
    """The sword (and the shot that copies it) for one direction, as UpdateSwordOrRod flips it."""
    vertical = direction in ("up", "down")
    tile = SWORD_TILE_VERTICAL if vertical else SWORD_TILE_HORIZONTAL
    rows = _item_rows(sp_tiles, bg_tiles, palette, tile, row)
    return _flip_rows(rows, h=direction == "left", v=direction == "down")


WEAPON_DIRECTIONS = ("up", "down", "left", "right")


def _sword_frames(sp_tiles, bg_tiles, palette) -> bytes:
    """Link's wooden sword (palette row 0 of the sprites) facing up, down, left, right."""
    return b"".join(
        _pack_masked(_weapon_rows(sp_tiles, bg_tiles, palette, d, B.LINK_PALETTE_ROW))
        for d in WEAPON_DIRECTIONS
    )


def _beam_frames(sp_tiles, bg_tiles, palette) -> bytes:
    """The sword's shot: the same picture, cycling through all four palette rows (direction, row)."""
    return b"".join(
        _pack_masked(_weapon_rows(sp_tiles, bg_tiles, palette, d, B.LINK_PALETTE_ROW + step))
        for d in WEAPON_DIRECTIONS
        for step in range(4)
    )


def _fire_rows(anim, heap, attr_heap, sp_tiles, palette) -> list[list[int]]:
    base = anim[FIRE_ANIM_INDEX]
    row = B.LINK_PALETTE_ROW + (attr_heap[base] & 3)
    return _monster_image(sp_tiles, palette, row, heap[base], "wide")


def _effect_frames(sp_tiles, bg_tiles, palette, fire_rows) -> bytes:
    """Two bomb clouds, four spark corners in four palette rows each, then the candle fire and its mirror."""
    frames = [
        _pack_masked(_item_rows(sp_tiles, bg_tiles, palette, tile, B.LINK_PALETTE_ROW + 1))
        for tile in CLOUD_TILES
    ]
    for flips in SPARK_CORNER_FLIPS:
        for step in range(4):
            rows = _item_rows(sp_tiles, bg_tiles, palette, SPARK_TILE, B.LINK_PALETTE_ROW + step)
            frames.append(_pack_masked(_flip_rows(rows, h="h" in flips, v="v" in flips)))
    frames.append(_pack_masked(fire_rows))
    frames.append(_pack_masked([r[::-1] for r in fire_rows]))
    return b"".join(frames)


def build_actors(source_root: Path, level: int, bg_tiles, palette, room_ids, attrs, info) -> ActorData:
    asm1 = (source_root / "src" / "Z_01.asm").read_text(encoding="utf-8", errors="replace")
    asm4 = (source_root / "src" / "Z_04.asm").read_text(encoding="utf-8", errors="replace")
    asm7 = (source_root / "src" / "Z_07.asm").read_text(encoding="utf-8", errors="replace")
    anim = B.parse_asm_byte_table(asm1, "ObjAnimations")
    heap = B.parse_asm_byte_table(asm1, "ObjAnimFrameHeap")
    attr_heap = B.parse_asm_byte_table(asm1, "ObjAnimAttrHeap")
    hp_pairs = B.parse_asm_byte_table(asm7, "ObjectTypeToHpPairs")
    no_drop = B.parse_asm_byte_table(asm4, "NoDropMonsterTypes")
    drop_types = [B.parse_asm_byte_table(asm4, f"DropItemMonsterTypes{i}") for i in range(3)]
    drop_table = B.parse_asm_byte_table(asm4, "DropItemTable")
    drop_rates = B.parse_asm_byte_table(asm4, "DropItemRates")
    code = {
        "slot": B.parse_asm_byte_table(asm1, "ItemIdToSlot"),
        "descriptor": B.parse_asm_byte_table(asm1, "ItemIdToDescriptor"),
        "offsets": B.parse_asm_byte_table(asm1, "Anim_ItemFrameOffsets"),
        "tiles": B.parse_asm_byte_table(asm1, "Anim_ItemFrameTiles"),
        "palette": B.parse_asm_byte_table(asm1, "ItemSlotToPaletteOffsetsOrValues"),
    }

    sp_tiles = _sprite_table(source_root, level)
    sprites = bytearray()
    table = bytearray()
    mon_index = bytearray([0xFF]) * 256
    for index, nes_type in enumerate(MONSTER_TYPES):
        mon_index[nes_type] = index
        base = anim[nes_type + 1]
        layout, image_count, mode = MONSTER_DRAW[nes_type]
        images = []
        for image in range(MONSTER_IMAGES):
            frame = min(image, image_count - 1)
            tile = heap[base + frame]
            row = B.LINK_PALETTE_ROW + (attr_heap[base + frame] & 3)
            if mode == MODE_BOSS:
                images.append(_blank(16))
            elif mode == MODE_WALLMASTER and frame == 1:
                # The closed hand reuses Keese art on the left; the game patches it to the open hand's.
                left = _tile_rows(sp_tiles, palette, row, heap[base])
                right = _tile_rows(sp_tiles, palette, row, tile + 2)
                images.append(_join(left, right))
            else:
                images.append(_monster_image(sp_tiles, palette, row, tile, layout))
        for rows in images:
            sprites.extend(_pack_masked(rows))
            sprites.extend(_pack_masked([r[::-1] for r in rows]))
        hp_byte = hp_pairs[nes_type >> 1]
        hp = (hp_byte >> 4) if nes_type % 2 == 0 else (hp_byte & 0x0F)
        drop_row = NO_DROP_ROW
        if nes_type not in no_drop:
            drop_row = 3
            for row_number, members in enumerate(drop_types):
                if nes_type in members:
                    drop_row = row_number
                    break
        table.extend((nes_type, hp, MONSTER_PERIOD[nes_type], MONSTER_DAMAGE[nes_type],
                      drop_row, 1 if nes_type in MONSTER_FLYERS else 0, mode,
                      MONSTER_BEHAVIOUR.get(nes_type, BEHAVIOUR_WANDER)))

    item_index = bytearray([0xFF]) * 64
    items = bytearray()
    for index, item_id in enumerate(ITEM_IDS):
        item_index[item_id] = index
        items.extend(_item_frame(code, sp_tiles, bg_tiles, palette, item_id))

    foe_counts = list(info[B.LEVEL_INFO_FOE_COUNTS : B.LEVEL_INFO_FOE_COUNTS + 4])
    return ActorData(
        mon_sprites=bytes(sprites),
        mon_table=bytes(table),
        mon_index=bytes(mon_index),
        item_sprites=bytes(items),
        item_index=bytes(item_index),
        drop_table=bytes(drop_table),
        drop_rates=bytes(drop_rates),
        sword_sprites=_sword_frames(sp_tiles, bg_tiles, palette),
        beam_sprites=_beam_frames(sp_tiles, bg_tiles, palette),
        fx_sprites=_effect_frames(sp_tiles, bg_tiles, palette, _fire_rows(anim, heap, attr_heap, sp_tiles, palette)),
        proj_sprites=_projectile_sprites(code, sp_tiles, bg_tiles, palette),
        hud_items=_hud_items(code, sp_tiles, bg_tiles, palette),
        room_info=[_room_info(r, attrs, foe_counts, info) for r in room_ids],
        keese_index=MONSTER_TYPES.index(0x1B),
    )


# Aquamentus is three 8x16 sprites wide and two high; the 16x16 blitter takes it in four pieces.
AQUAMENTUS_TILES = ((0xCC, 0xC4, 0xC8, 0xC2, 0xC6, 0xCA), (0xCC, 0xC4, 0xC8, 0xCE, 0xD0, 0xD2))
AQUAMENTUS_OPEN_MOUTH = 0xC0
AQUAMENTUS_OFFSETS = ((0, 0), (8, 0), (16, 0), (0, 16), (8, 16), (16, 16))
# AquamentusPaletteRow7TransferBuf: the boss swaps in its own three greens.
AQUAMENTUS_COLORS = (0x0A, 0x29, 0x30)


class _FixedPalette:
    """Maps the three CHR pixel values straight to chosen ST colours, whatever the row."""

    def __init__(self, indices):
        self.indices = indices

    def index(self, row: int, pixel: int) -> int:
        return self.indices[pixel - 1]


def _nearest_st_color(palette, nes_color: int) -> int:
    """The entry of the shared ST palette closest to a NES colour."""
    target = B.nes_color_to_st(nes_color)

    def distance(entry: int) -> int:
        return sum(abs(((entry >> shift) & 7) - ((target >> shift) & 7)) for shift in (8, 4, 0))

    return min(range(len(palette.st_colors)), key=lambda i: distance(palette.st_colors[i]))


def _boss_pieces(sp_tiles, palette) -> list[bytes]:
    """Per image (animation frame, mouth shut or open): top-left, top-right, bottom-left, bottom-right."""
    row = B.LINK_PALETTE_ROW + 3
    greens = _FixedPalette([_nearest_st_color(palette, c) for c in AQUAMENTUS_COLORS])
    frames = []
    for tiles in AQUAMENTUS_TILES:
        for mouth_open in (False, True):
            canvas = _blank(32) + _blank(32)
            for slot, (x, y) in enumerate(AQUAMENTUS_OFFSETS):
                tile = AQUAMENTUS_OPEN_MOUTH if (slot == 0 and mouth_open) else tiles[slot]
                for dy, pixels in enumerate(_tile_rows(sp_tiles, greens, row, tile)):
                    canvas[y + dy][x : x + 8] = pixels
            for top, left in ((0, 0), (0, 16), (16, 0), (16, 16)):
                frames.append(_pack_masked([canvas[top + r][left : left + 16] for r in range(16)]))
    return frames


def _projectile_sprites(code, sp_tiles, bg_tiles, palette) -> bytes:
    """Eight boomerang images and its spark, two fireball frames, then the Aquamentus pieces."""
    fire = palette.index(B.LINK_PALETTE_ROW + 2, 3)
    fire_dark = palette.index(B.LINK_PALETTE_ROW + 2, 2)
    frames = _boomerang_frames(code, sp_tiles, bg_tiles, palette)
    for phase in range(2):
        rows = _blank(16)
        for y in range(8):
            for x in range(8):
                distance = (2 * x - 7) ** 2 + (2 * y - 7) ** 2
                if distance <= 36:
                    rows[4 + y][4 + x] = fire if (distance <= 16) == (phase == 0) else fire_dark
        frames.append(_pack_masked(rows))
    return b"".join(frames) + b"".join(_boss_pieces(sp_tiles, palette))


def _room_info(room: int, attrs, foe_counts, info) -> bytes:
    """count, secret trigger (bit 7: the room has a push block), item id, item X, item Y, unsupported,
    then eight monsters."""
    attr_c, attr_d, attr_e, attr_f = attrs
    list_id = (attr_c[room] & 0x3F) | (0x40 if attr_d[room] & 0x80 else 0)
    count = foe_counts[attr_c[room] >> 6]
    if 0x32 <= list_id < 0x62:
        count = 1
    types = [list_id] * count if 0 < list_id < 0x62 else []
    if list_id in (0x49, 0x4A):
        types = [0x49] * (6 if list_id == 0x49 else 4)    # InitTrap_Full makes six or four traps
    monsters = [MONSTER_TYPES.index(t) for t in types if t in MONSTER_TYPES][:8]
    # CheckHasLivingMonsters ignores bubbles ($2B-$2D) and everything from $49 up,
    # which includes the traps; any other monster has to be killed before the room clears.
    unsupported = sum(
        1 for t in types if t not in MONSTER_TYPES and not (0x2B <= t <= 0x2D) and t < 0x49
    )

    item = attr_e[room] & 0x1F
    positions = info[B.LEVEL_INFO_ITEM_POSITIONS : B.LEVEL_INFO_ITEM_POSITIONS + 4]
    pos = positions[(attr_f[room] & 0x30) >> 4]
    item_id = 0xFF if item == 3 else item
    # FindAndCreatePushBlockObject runs for every room whose attribute D has $40, whatever its secret trigger
    trigger = (attr_f[room] & 7) | (0x80 if attr_d[room] & 0x40 else 0)
    record = bytearray([len(monsters), trigger, item_id, pos & 0xF0, (pos & 0x0F) << 4, unsupported])
    record.extend(monsters)
    record.extend([0xFF] * (ROOM_INFO_BYTES - len(record)))
    return bytes(record)


def build_placeholder() -> ActorData:
    frame = _pack_masked([[1] * 16 for _ in range(16)])
    return ActorData(
        mon_sprites=frame * (MONSTER_IMAGES * 2),
        mon_table=bytes((0x2A, 2, 2, 1, 0, 0, 0, 0)),
        mon_index=bytes([0xFF]) * 256,
        item_sprites=frame,
        item_index=bytes([0xFF]) * 64,
        drop_table=bytes(40),
        drop_rates=bytes(4),
        sword_sprites=frame * 4,
        beam_sprites=frame * 16,
        fx_sprites=frame * 20,
        proj_sprites=frame * 27,
        hud_items=bytes(256),
        room_info=[bytes([0, 0, 0xFF, 0, 0, 0] + [0xFF] * 8)],
    )
