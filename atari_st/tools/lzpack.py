"""An LZ4 block packer for the dungeon files (LEVEL<n>[Q].DAT), and the same decoder in Python.

The format is LZ4's block format, which the 68000 decodes in a few dozen instructions (`lz_unpack` in src/loader.s):

    sequence = token, [literal length extension], literals, [offset (2 bytes, little endian), [match length extension]]

The token's high nibble is the literal count and its low nibble the match length minus 4; a nibble of 15 is followed by
bytes added to it until one is not 255. The block always ends with a sequence that has literals only (possibly none):
the decoder stops when the packed data runs out after the literals.

The game reads the packed data into the *end* of the level buffer and unpacks it from the front, over itself.
`margin` is how far the output may run ahead of the input at any point; the buffer must hold the packed data plus that.
"""
from __future__ import annotations

MIN_MATCH = 4
MAX_OFFSET = 65535
CHAIN = 256          # how many earlier places with the same four bytes are tried


def _length_extension(out: bytearray, value: int) -> None:
    while value >= 255:
        out.append(255)
        value -= 255
    out.append(value)


def _sequence(out: bytearray, literals: bytes, offset: int = 0, length: int = 0) -> None:
    lit = len(literals)
    token = min(lit, 15) << 4
    if length:
        token |= min(length - MIN_MATCH, 15)
    out.append(token)
    if lit >= 15:
        _length_extension(out, lit - 15)
    out.extend(literals)
    if length:
        out.extend(offset.to_bytes(2, "little"))
        if length - MIN_MATCH >= 15:
            _length_extension(out, length - MIN_MATCH - 15)


def pack(data: bytes) -> bytes:
    """`data` as one LZ4 block (greedy with one step of lazy matching)."""
    n = len(data)
    table: dict[bytes, list[int]] = {}
    out = bytearray()

    def add(at: int) -> None:
        if at + MIN_MATCH <= n:
            table.setdefault(data[at : at + MIN_MATCH], []).append(at)

    def find(at: int) -> tuple[int, int]:
        """(length, offset) of the longest earlier match at `at`, (0, 0) if none."""
        if at + MIN_MATCH > n:
            return 0, 0
        best, best_offset = 0, 0
        places = table.get(data[at : at + MIN_MATCH], ())
        for k in range(len(places) - 1, max(len(places) - CHAIN, 0) - 1, -1):
            far = places[k]
            if at - far > MAX_OFFSET:
                break
            length = MIN_MATCH
            while at + length < n and data[far + length] == data[at + length]:
                length += 1
            if length > best:
                best, best_offset = length, at - far
        return best, best_offset

    anchor = 0
    i = 0
    while i < n:
        length, offset = find(i)
        if length < MIN_MATCH:
            add(i)
            i += 1
            continue
        add(i)
        later, later_offset = find(i + 1)       # a longer match one byte on beats this one
        if later > length + 1:
            i += 1
            continue
        _sequence(out, data[anchor:i], offset, length)
        for k in range(i + 1, i + length):
            add(k)
        i += length
        anchor = i
    _sequence(out, data[anchor:])
    return bytes(out)


def _walk(packed: bytes):
    """Yield (literal start, literal count, offset, match length, packed bytes consumed so far) per sequence."""
    pos = 0
    end = len(packed)
    while True:
        token = packed[pos]
        pos += 1
        lit = token >> 4
        if lit == 15:
            while True:
                byte = packed[pos]
                pos += 1
                lit += byte
                if byte != 255:
                    break
        start = pos
        pos += lit
        if pos >= end:
            yield start, lit, 0, 0, pos
            return
        offset = packed[pos] | (packed[pos + 1] << 8)
        pos += 2
        length = token & 15
        if length == 15:
            while True:
                byte = packed[pos]
                pos += 1
                length += byte
                if byte != 255:
                    break
        length += MIN_MATCH
        yield start, lit, offset, length, pos


def unpack(packed: bytes) -> bytes:
    """Decode a block made by `pack` (what src/loader.s does)."""
    out = bytearray()
    for start, lit, offset, length, _ in _walk(packed):
        out.extend(packed[start : start + lit])
        for _ in range(length):
            out.append(out[-offset])
    return bytes(out)


def margin(packed: bytes) -> int:
    """The most the output is ever ahead of the packed data read so far, counted when a sequence is complete.

    Unpacking in place with the packed data starting `m` bytes behind the output's start is safe when `m >= margin`: the
    bytes written never reach bytes not read yet.
    """
    produced = 0
    worst = 0
    for _, lit, _, length, consumed in _walk(packed):
        produced += lit + length
        worst = max(worst, produced - consumed)
    return worst
