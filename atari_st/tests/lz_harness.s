| Test image for lz.s: the decoder alone. The test puts the packed data, its end and the output address in a0, a2 and a1,
| runs h_unpack and reads the output; the routine ends in a branch to itself.

    .text
    bra.w h_unpack
h_unpack:
    bsr lz_unpack
    bra.s .                     | the test stops here

    .include "lz.s"
