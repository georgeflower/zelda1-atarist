# Zelda 1 for Atari ST - what is left

Work in progress. Both quests are in. The `.PRG` is about 300 KB and each dungeon's data is a file next to it (`LEVEL<n>[Q].DAT`), but with the screens and the biggest file it still needs more than 512 KB. This file is the short list of what is left and what I want to do next, with the data tables at the end. How the code works is in `AGENTS.md` / `CLAUDE.md`, how to build is in `README.md`.

## What is left

| # | What | Why |
| --- | --- | --- |
| 1 | More play-testing, Levels 4 to 9 most of all, then the Second Quest | they are built from the ROM but have had little play |
| 2 | Run it on a real ST | speed with a full room at 8 MHz, PAL at 50 Hz and the disk write for `ZELDA.SAV` are only seen in Hatari so far |
| 3 | Fit 512 KB machines (my 520 STFM): the dungeons' files are done; still to do: compress the files (they are 630 KB together, more than a disk holds), read the title and credits pictures from a file, pack the drum samples, use the screen TOS already has, a 512 KB test | about 460 KB used now, 388 KB free on a 512 KB EmuTOS |
| 4 | Closer to the original in a few places | the Moldorm is two worms of four, not one of ten; the Dodongo and Moldorm have no death cloud; the dungeons' monsters appear at once; "save and exit" from the Tab menu is not in the original either |

Not planned: anything that needs the NES hardware itself (the PPU, the DPCM channel) rather than its data.

## Next

1 first, then 2, then 3 if someone wants a 512 KB version.

## Reference data

The appendices below are tables decoded from the ROM (the PAL, Europe, Rev 1 image): hidden spots, cave entrances, every overworld screen with its monsters, the 20 cave types, all nine dungeons room by room, and the ROM's texts. They come from `tools/dump_tables.py`, which writes the same tables for any build.

## Appendix: method

- ROM: `Legend_of_Zelda_The_Europe_Rev_1`, PAL, 131,088 bytes.
- Offsets come from `src/bins.xml` (relative to PRG start). The decoder imports the repo's own `build_assets.py` and `underworld.py`, so these tables use the same column, square and door decoding as the port.
- HP and damage come from `ObjectTypeToHpPairs` and `ObjTypeToDamagePoints` in the disassembly, not the ROM; HP is in wooden-sword hits.
- Screens are named column letter A to P and row 1 to 8 (A1 = room `$00`, P8 = `$7F`, H8 = start `$77`).
- Dungeon room sets: every room reachable from the start room through non-wall doors, plus rooms reached through stair rooms. A room not listed there is not in that level.

## Appendix A1: all hidden marker squares (bomb wall, tree, rock, gravestone)

Pixel y includes the `$40` offset of the playfield. Leads-to is attribute B of the screen. "item/none" means the screen has no destination (a plain secret object).

| Screen | ROM id | Kind | Tile col,row | Pixel x,y | Leads to | Quest | Stairs-pos idx |
|---|---|---|---|---|---|---|---|
| A1 | $00 | rock wall (bomb) | 10,4 | 160,128 | Level 9 | Q2 | 0 |
| B1 | $01 | rock wall (bomb) | 9,1 | 144,80 | cave idx 7 (type $71) | both | 0 |
| C1 | $02 | rock wall (bomb) | 6,4 | 96,128 | cave idx 10 (type $74) | Q2 | 0 |
| D1 | $03 | rock wall (bomb) | 7,4 | 112,128 | cave idx 7 (type $71) | both | 0 |
| F1 | $05 | rock wall (bomb) | 5,6 | 80,160 | Level 9 | Q1 | 0 |
| H1 | $07 | rock wall (bomb) | 10,4 | 160,128 | cave idx 7 (type $71) | both | 0 |
| J1 | $09 | rock (Power Bracelet) | 4,5 | 64,144 | cave idx 3 (type $6D) | Q2 | 2 |
| N1 | $0D | rock wall (bomb) | 9,1 | 144,80 | cave idx 10 (type $74) | both | 0 |
| A2 | $10 | rock wall (bomb) | 9,1 | 144,80 | cave idx 6 (type $70) | both | 0 |
| B2 | $11 | rock (Power Bracelet) | 8,5 | 128,144 | cave idx 8 (type $72) | Q2 | 2 |
| C2 | $12 | rock wall (bomb) | 8,1 | 128,80 | cave idx 15 (type $79) | both | 0 |
| D2 | $13 | rock wall (bomb) | 2,1 | 32,80 | cave idx 17 (type $7B) | both | 0 |
| E2 | $14 | rock wall (bomb) | 12,1 | 192,80 | cave idx 7 (type $71) | both | 0 |
| F2 | $15 | rock wall (bomb) | 12,1 | 192,80 | cave idx 14 (type $78) | Q2 | 0 |
| G2 | $16 | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| I2 | $18 | rock wall (bomb) | 12,3 | 192,112 | cave idx 10 (type $74) | Q2 | 0 |
| J2 | $19 | rock wall (bomb) | 4,3 | 64,112 | Level 7 | Q2 | 0 |
| L2 | $1B | rock (Power Bracelet) | 12,5 | 192,144 | Level 5 | Q2 | 2 |
| N2 | $1D | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 0 |
| O2 | $1E | rock wall (bomb) | 12,1 | 192,80 | cave idx 7 (type $71) | both | 0 |
| A3 | $20 | gravestone (push) | 6,5 | 96,144 | cave idx 1 (type $6B) | Q2 | 3 |
| B3 | $21 | gravestone (push) | 9,5 | 144,144 | cave idx 3 (type $6D) | Q1 | 2 |
| D3 | $23 | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 1 |
| G3 | $26 | rock wall (bomb) | 3,1 | 48,80 | cave idx 15 (type $79) | both | 0 |
| H3 | $27 | rock wall (bomb) | 14,1 | 224,80 | cave idx 10 (type $74) | Q1 | 0 |
| I3 | $28 | tree (candle fire) | 13,6 | 208,160 | cave idx 17 (type $7B) | both | 0 |
| M3 | $2C | rock wall (bomb) | 9,6 | 144,160 | cave idx 1 (type $6B) | Q1 | 0 |
| N3 | $2D | rock wall (bomb) | 5,1 | 80,80 | cave idx 17 (type $7B) | both | 0 |
| D4 | $33 | rock wall (bomb) | 10,1 | 160,80 | cave idx 10 (type $74) | both | 0 |
| G5 | $46 | tree (candle fire) | 9,7 | 144,176 | cave idx 15 (type $79) | both | 0 |
| H5 | $47 | tree (candle fire) | 11,7 | 176,176 | cave idx 1 (type $6B) | Q1 | 0 |
| I5 | $48 | tree (candle fire) | 13,2 | 208,96 | cave idx 17 (type $7B) | both | 0 |
| J5 | $49 | rock (Power Bracelet) | 3,5 | 48,144 | cave idx 4 (type $6E) (take-any-road) | both | 0 |
| L5 | $4B | tree (candle fire) | 11,2 | 176,96 | cave idx 10 (type $74) | both | 0 |
| N5 | $4D | tree (candle fire) | 13,6 | 208,160 | cave idx 15 (type $79) | both | 0 |
| B6 | $51 | tree (candle fire) | 9,6 | 144,160 | cave idx 19 (type $7D) | both | 0 |
| D6 | $53 | tree (candle fire) | 6,6 | 96,160 | cave idx 18 (type $7C) | Q2 | 0 |
| G6 | $56 | tree (candle fire) | 10,6 | 160,160 | cave idx 19 (type $7D) | both | 0 |
| L6 | $5B | tree (candle fire) | 2,6 | 32,160 | cave idx 19 (type $7D) | both | 0 |
| C7 | $62 | tree (candle fire) | 8,2 | 128,96 | cave idx 18 (type $7C) | Q1 | 0 |
| D7 | $63 | tree (candle fire) | 6,6 | 96,160 | cave idx 7 (type $71) | both | 0 |
| H7 | $67 | rock wall (bomb) | 7,1 | 112,80 | cave idx 17 (type $7B) | Q1 | 0 |
| I7 | $68 | tree (candle fire) | 2,6 | 32,160 | cave idx 7 (type $71) | both | 0 |
| K7 | $6A | tree (candle fire) | 12,6 | 192,160 | cave idx 7 (type $71) | both | 0 |
| L7 | $6B | tree (candle fire) | 8,6 | 128,160 | cave idx 18 (type $7C) | Q1 | 0 |
| M7 | $6C | tree (candle fire) | 5,2 | 80,96 | Level 8 | Q2 | 0 |
| N7 | $6D | tree (candle fire) | 10,2 | 160,96 | Level 8 | Q1 | 0 |
| B8 | $71 | rock wall (bomb) | 5,1 | 80,80 | cave idx 17 (type $7B) | Q1 | 0 |
| G8 | $76 | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| I8 | $78 | tree (candle fire) | 4,6 | 64,160 | cave idx 10 (type $74) | both | 0 |
| J8 | $79 | rock (Power Bracelet) | 8,5 | 128,144 | cave idx 4 (type $6E) (take-any-road) | both | 2 |
| L8 | $7B | rock wall (bomb) | 9,1 | 144,80 | cave idx 1 (type $6B) | Q1 | 0 |
| M8 | $7C | rock wall (bomb) | 6,1 | 96,80 | cave idx 6 (type $70) | both | 0 |
| N8 | $7D | rock wall (bomb) | 6,1 | 96,80 | cave idx 7 (type $71) | both | 0 |

(54 hidden marker squares in total.)

## Appendix A2: screens with a visible cave or dungeon entrance (square idx 12)

| Screen | ROM id | Leads to | Entrance square (col,row) | Quest tag |
|---|---|---|---|---|
| E1 | $04 | cave idx 10 (type $74) | 12,1 | both |
| K1 | $0A | cave idx 2 (type $6C) | 2,1 | both |
| L1 | $0B | Level 5 | 7,4 | both |
| M1 | $0C | cave idx 14 (type $78) | 8,1 | both |
| O1 | $0E | cave idx 8 (type $72) | 5,4 | both |
| P1 | $0F | cave idx 18 (type $7C) | 8,4 | both |
| P2 | $1F | cave idx 6 (type $70) | 6,4 | both |
| C3 | $22 | Level 6 | 7,4, 8,4 | both |
| F3 | $25 | cave idx 13 (type $77) | 10,1 | both |
| P3 | $2F | cave idx 1 (type $6B) | 6,4 | both |
| H4 | $37 | Level 1 | 7,4 | both |
| M4 | $3C | Level 2 | 7,4 | both |
| E5 | $44 | cave idx 13 (type $77) | 4,1 | both |
| F5 | $45 | Level 4 | 8,4 | both |
| K5 | $4A | cave idx 13 (type $77) | 11,1 | both |
| O6 | $5E | cave idx 14 (type $78) | 7,1 | both |
| E7 | $64 | cave idx 10 (type $74) | 7,1 | both |
| G7 | $66 | cave idx 14 (type $78) | 7,1 | both |
| P7 | $6F | cave idx 13 (type $77) | 3,1 | both |
| A8 | $70 | cave idx 12 (type $76) | 11,1 | both |
| E8 | $74 | Level 3 | 8,4 | both |
| F8 | $75 | cave idx 9 (type $73) | 2,1 | both |
| H8 | $77 | cave idx 0 (type $6A) | 4,1 | both |

## Appendix A3: screens with a destination but nothing drawn for it

| Screen | ROM id | Leads to | Why it is not drawn | Quest tag |
|---|---|---|---|---|
| G1 | $06 | cave idx 1 (type $6B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| K2 | $1A | cave idx 11 (type $75) | waterfall column (idx 54) at col 6; walk into it | both |
| M2 | $1C | cave idx 5 (type $6F) | touch the armos at the listed spot (see 4.2) | both |
| J3 | $29 | cave idx 10 (type $74) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| L3 | $2B | cave idx 19 (type $7D) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| A4 | $30 | Level 6 | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| E4 | $34 | cave idx 16 (type $7A) | touch the armos at the listed spot (see 4.2) | both |
| K4 | $3A | cave idx 1 (type $6B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| N4 | $3D | cave idx 17 (type $7B) | touch the armos at the listed spot (see 4.2) | both |
| C5 | $42 | Level 7 | play the Recorder at the pond edge; stairs rise at col 6, row 9 | both |
| O5 | $4E | cave idx 19 (type $7D) | touch the armos at the listed spot (see 4.2) | both |
| I6 | $58 | cave idx 17 (type $7B) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| A7 | $60 | cave idx 6 (type $70) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| O7 | $6E | cave idx 19 (type $7D) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |
| C8 | $72 | cave idx 7 (type $71) | Second Quest only; the Recorder opens it there (in Quest 1 the same screen summons the whirlwind) | Q2 |

## Appendix B1: every overworld screen, its enemies and flags

Counts are before the room-history reduction. "enemies enter from screen edge" means no initial placement (section 5.1).

| Screen | ROM id | Monsters (count x type) | Notes |
|---|---|---|---|
| A1 | $00 | none | - |
| B1 | $01 | 4x Lynel (red) | - |
| C1 | $02 | 4x Lynel (red) | - |
| D1 | $03 | Boulder set | - |
| E1 | $04 | 6x Lynel (blue) | - |
| F1 | $05 | 2x Lynel (blue), Leever (blue), 2x Lynel (red), Leever (red) | - |
| G1 | $06 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| H1 | $07 | Lynel (red) | - |
| I1 | $08 | Boulder set | - |
| J1 | $09 | none | - |
| K1 | $0A | Lynel (blue) | Zoras in water |
| L1 | $0B | Leever (red) | 8 armos |
| M1 | $0C | 6x Tektite (red) | - |
| N1 | $0D | 6x Tektite (red) | - |
| O1 | $0E | none | enemies enter from screen edge; sea sound |
| P1 | $0F | none | sea sound |
| A2 | $10 | 4x Lynel (blue) | - |
| B2 | $11 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| C2 | $12 | 6x Lynel (blue) | - |
| D2 | $13 | 2x Lynel (blue), 2x Lynel (red) | - |
| E2 | $14 | 4x Lynel (red) | 8 armos |
| F2 | $15 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| G2 | $16 | Boulder set | - |
| H2 | $17 | Boulder set | Zoras in water |
| I2 | $18 | Boulder set | Zoras in water |
| J2 | $19 | Boulder set | Zoras in water |
| K2 | $1A | 6x Tektite (red) | Zoras in water |
| L2 | $1B | none | - |
| M2 | $1C | none | 8 armos |
| N2 | $1D | 6x Peahat | sea sound |
| O2 | $1E | 6x Tektite (red) | Zoras in water; sea sound |
| P2 | $1F | 6x Peahat | sea sound |
| A3 | $20 | Ghini | - |
| B3 | $21 | Ghini | - |
| C3 | $22 | Lynel (red) | 12 armos |
| D3 | $23 | 4x Lynel (red) | - |
| E3 | $24 | none | 10 armos |
| F3 | $25 | 4x Peahat | 8 armos |
| G3 | $26 | 6x Peahat | Zoras in water |
| H3 | $27 | 6x Peahat | Zoras in water |
| I3 | $28 | 6x Peahat | Zoras in water |
| J3 | $29 | 4x Leever (red) | - |
| K3 | $2A | 6x Leever (blue) | - |
| L3 | $2B | 2x Leever (blue), 3x Peahat, Leever (red) | - |
| M3 | $2C | 4x Tektite (red) | - |
| N3 | $2D | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| O3 | $2E | 4x Octorok (blue, slow) | Zoras in water; sea sound |
| P3 | $2F | none | - |
| A4 | $30 | Ghini | - |
| B4 | $31 | Ghini | - |
| C4 | $32 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| D4 | $33 | none | 10 armos |
| E4 | $34 | 4x Leever (blue) | 6 armos |
| F4 | $35 | none | Zoras in water |
| G4 | $36 | none | Zoras in water |
| H4 | $37 | Octorok (red, fast) | - |
| I4 | $38 | Octorok (blue, slow), 5x Octorok (red, fast) | Zoras in water |
| J4 | $39 | Pond fairy | - |
| K4 | $3A | 2x Leever (blue), 3x Peahat, Leever (red) | - |
| L4 | $3B | 4x Leever (blue) | - |
| M4 | $3C | Octorok (blue, fast) | 8 armos |
| N4 | $3D | 4x Moblin (blue) | 2 armos |
| O4 | $3E | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| P4 | $3F | Octorok (blue, slow) | Zoras in water; sea sound |
| A5 | $40 | Ghini | - |
| B5 | $41 | Ghini | - |
| C5 | $42 | Moblin (red) | - |
| D5 | $43 | Pond fairy | - |
| E5 | $44 | 4x Octorok (red, slow) | Zoras in water |
| F5 | $45 | Peahat | - |
| G5 | $46 | none | Zoras in water |
| H5 | $47 | none | Zoras in water |
| I5 | $48 | 4x Leever (red) | Zoras in water |
| J5 | $49 | Octorok (blue, slow), 5x Octorok (red, fast) | - |
| K5 | $4A | 6x Tektite (blue) | - |
| L5 | $4B | 6x Moblin (red) | enemies enter from screen edge |
| M5 | $4C | 3x Octorok (red, fast), 2x Octorok (blue, slow) | - |
| N5 | $4D | 4x Moblin (blue) | enemies enter from screen edge |
| O5 | $4E | 4x Moblin (blue) | enemies enter from screen edge; 2 armos |
| P5 | $4F | 2x Octorok (blue, fast), 3x Octorok (red, slow) | Zoras in water; sea sound |
| A6 | $50 | 5x Lynel (red) | - |
| B6 | $51 | 5x Moblin (blue) | - |
| C6 | $52 | 2x Moblin (blue), 2x Moblin (red) | enemies enter from screen edge |
| D6 | $53 | 3x Moblin (blue), 2x Moblin (red) | - |
| E6 | $54 | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| F6 | $55 | Octorok (red, slow) | Zoras in water |
| G6 | $56 | 4x Octorok (red, slow) | Zoras in water |
| H6 | $57 | 2x Octorok (red, fast), 2x Octorok (red, slow) | enemies enter from screen edge |
| I6 | $58 | 2x Octorok (red, fast), 2x Octorok (red, slow) | enemies enter from screen edge |
| J6 | $59 | 4x Peahat | Zoras in water |
| K6 | $5A | 4x Octorok (red, slow) | Zoras in water |
| L6 | $5B | 2x Moblin (blue), 2x Moblin (red) | enemies enter from screen edge |
| M6 | $5C | 4x Moblin (blue) | enemies enter from screen edge |
| N6 | $5D | 4x Moblin (blue) | enemies enter from screen edge |
| O6 | $5E | 5x Moblin (blue) | - |
| P6 | $5F | 3x Octorok (red, fast), 2x Octorok (blue, slow) | Zoras in water; sea sound |
| A7 | $60 | 2x Peahat, 2x Lynel (red), 2x Lynel (blue) | - |
| B7 | $61 | 5x Moblin (blue) | enemies enter from screen edge |
| C7 | $62 | 5x Moblin (blue) | enemies enter from screen edge |
| D7 | $63 | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | - |
| E7 | $64 | 3x Octorok (red, fast), 2x Octorok (blue, slow) | - |
| F7 | $65 | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| G7 | $66 | 2x Octorok (red, fast), 2x Octorok (red, slow) | - |
| H7 | $67 | 4x Octorok (red, slow) | - |
| I7 | $68 | 4x Octorok (red, slow) | enemies enter from screen edge |
| J7 | $69 | 4x Octorok (red, slow) | Zoras in water |
| K7 | $6A | 2x Octorok (red, fast), 2x Octorok (red, slow) | Zoras in water |
| L7 | $6B | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | enemies enter from screen edge |
| M7 | $6C | 4x Moblin (red) | enemies enter from screen edge |
| N7 | $6D | 4x Moblin (red) | enemies enter from screen edge |
| O7 | $6E | Moblin (blue), 2x Octorok (blue, fast), 3x Moblin (red) | - |
| P7 | $6F | Octorok (blue, slow), 4x Octorok (red, fast) | Zoras in water; sea sound |
| A8 | $70 | 4x Peahat | - |
| B8 | $71 | 5x Moblin (blue) | enemies enter from screen edge |
| C8 | $72 | 3x Moblin (blue), Moblin (red) | enemies enter from screen edge |
| D8 | $73 | 4x Moblin (blue) | enemies enter from screen edge |
| E8 | $74 | Tektite (red) | 8 armos |
| F8 | $75 | 2x Leever (blue), 3x Peahat, Leever (red) | Zoras in water |
| G8 | $76 | 4x Tektite (red) | - |
| H8 | $77 | none | - |
| I8 | $78 | 4x Octorok (red, slow) | enemies enter from screen edge |
| J8 | $79 | 5x Tektite (blue) | - |
| K8 | $7A | 4x Tektite (blue) | - |
| L8 | $7B | 6x Leever (red) | Zoras in water; sea sound |
| M8 | $7C | 6x Leever (red) | Zoras in water; sea sound |
| N8 | $7D | 4x Octorok (blue, slow) | Zoras in water; sea sound |
| O8 | $7E | 4x Octorok (red, fast) | Zoras in water; sea sound |
| P8 | $7F | Octorok (blue, slow) | Zoras in water; sea sound |

## Appendix B2: overworld enemies by type

| Type | Name | HP (sword hits) | Damage | Screens (count) |
|---|---|---|---|---|
| $01 | Lynel (blue) | 6 | 2 hearts | E1 (6), F1 (2), G1 (2), K1, A2 (4), B2 (2), C2 (6), D2 (2), F2 (2), C4 (2), A7 (2) |
| $02 | Lynel (red) | 4 | 1 heart | B1 (4), C1 (4), F1 (2), G1 (2), H1, B2 (2), D2 (2), E2 (4), F2 (2), C3, D3 (4), C4 (2), A6 (5), A7 (2) |
| $03 | Moblin (blue) | 3 | half heart | N4 (4), N5 (4), O5 (4), B6 (5), C6 (2), D6 (3), L6 (2), M6 (4), N6 (4), O6 (5), B7 (5), C7 (5), D7, L7, O7, B8 (5), C8 (3), D8 (4) |
| $04 | Moblin (red) | 2 | half heart | C5, L5 (6), C6 (2), D6 (2), L6 (2), D7 (3), L7 (3), M7 (4), N7 (4), O7 (3), C8 |
| $07 | Octorok (red, slow) | 1 | half heart | E5 (4), P5 (3), E6 (2), F6, G6 (4), H6 (2), I6 (2), K6 (4), F7 (2), G7 (2), H7 (4), I7 (4), J7 (4), K7 (2), I8 (4) |
| $08 | Octorok (red, fast) | 1 | half heart | N3 (3), H4, I4 (5), O4 (3), J5 (5), M5 (3), E6 (2), H6 (2), I6 (2), P6 (3), E7 (3), F7 (2), G7 (2), K7 (2), P7 (4), O8 (4) |
| $09 | Octorok (blue, slow) | 2 | half heart | N3 (2), O3 (4), I4, O4 (2), P4, J5, M5 (2), P6 (2), E7 (2), P7, N8 (4), P8 |
| $0A | Octorok (blue, fast) | 2 | half heart | M4, P5 (2), D7 (2), L7 (2), O7 (2) |
| $0D | Tektite (blue) | 1 | half heart | K5 (6), J8 (5), K8 (4) |
| $0E | Tektite (red) | 1 | half heart | M1 (6), N1 (6), K2 (6), O2 (6), M3 (4), E8, G8 (4) |
| $0F | Leever (blue) | 4 | 1 heart | F1, K3 (6), L3 (2), E4 (4), K4 (2), L4 (4), F8 (2) |
| $10 | Leever (red) | 2 | half heart | F1, L1, J3 (4), L3, K4, I5 (4), F8, L8 (6), M8 (6) |
| $1A | Peahat | 2 | half heart | G1 (2), B2 (2), F2 (2), N2 (6), P2 (6), F3 (4), G3 (6), H3 (6), I3 (6), L3 (3), C4 (2), K4 (3), F5, J6 (4), A7 (2), A8 (4), F8 (3) |
| $1F | Boulder set | 15 | half heart | D1, I1, G2, H2, I2, J2 |
| $21 | Ghini | 9 | 1 heart | A3, B3, A4, B4, A5, B5 |
| $2F | Pond fairy | 15 | none | J4, D5 |

Zora screens (water enemy, not in the monster list): K1, H2, I2, J2, K2, O2, G3, H3, I3, N3, O3, F4, G4, I4, O4, P4, E5, G5, H5, I5, P5, E6, F6, G6, J6, K6, P6, F7, J7, K7, P7, F8, L8, M8, N8, O8, P8

Edge-spawn screens: O1, L5, N5, O5, C6, H6, I6, L6, M6, N6, B7, C7, I7, L7, M7, N7, B8, C8, D8, I8

## Appendix C: all 20 cave types

Items are listed left / middle / right. "(none)" means an empty slot. Prices are in rupees. Screens are tagged [Q1] or [Q2] when the secret that leads to them applies to one quest only.

| Idx | Type | Text | Items (left / middle / right) | Prices | Used by (screen, ROM id) |
|---|---|---|---|---|---|
| 0 | $6A | "IT'S DANGEROUS TO GO / ALONE! TAKE THIS." | (none) / Wooden Sword / (none) | 0/0/0 | H8(77) |
| 1 | $6B | "TAKE ANY ONE YOU WANT." | Red (2nd) Potion / (none) / Heart Container | 0/0/0 | G1(06) [Q2], A3(20) [Q2], M3(2C) [Q1], P3(2F), K4(3A) [Q2], H5(47) [Q1], L8(7B) [Q1] |
| 2 | $6C | "MASTER USING IT AND / YOU CAN HAVE THIS." | (none) / White Sword / (none) | 0/0/0 | K1(0A) |
| 3 | $6D | "MASTER USING IT AND / YOU CAN HAVE THIS." | (none) / Magical Sword / (none) | 0/0/0 | J1(09) [Q2], B3(21) [Q1] |
| 4 | $6E | "TAKE ANY ROAD YOU WANT." | (none) / (none) / (none) | 0/0/0 | N2(1D), D3(23), J5(49), J8(79) |
| 5 | $6F | "SECRET IS IN THE TREE / AT THE DEAD-END." | (none) / (none) / (none) | 0/0/0 | M2(1C) |
| 6 | $70 | "LET'S PLAY MONEY / MAKING GAME." | Rupee / Rupee / Rupee | 10/10/10 | A2(10), G2(16), P2(1F), A7(60) [Q2], G8(76), M8(7C) |
| 7 | $71 | "PAY ME FOR THE DOOR / REPAIR CHARGE." | (none) / (none) / (none) | 0/0/0 | B1(01), D1(03), H1(07), E2(14), O2(1E), D7(63), I7(68), K7(6A), C8(72) [Q2], N8(7D) |
| 8 | $72 | "SHOW THIS TO THE / OLD WOMAN." | (none) / Letter / (none) | 0/0/0 | O1(0E), B2(11) [Q2] |
| 9 | $73 | "MEET THE OLD MAN / AT THE GRAVE." | (none) / (none) / (none) | 0/0/0 | F8(75) |
| 10 | $74 | "BUY MEDICINE BEFORE / YOU GO." | Blue (Life) Potion / (none) / Red (2nd) Potion | 40/0/68 | C1(02) [Q2], E1(04), N1(0D), I2(18) [Q2], H3(27) [Q1], J3(29) [Q2], D4(33), L5(4B), E7(64), I8(78) |
| 11 | $75 | "PAY ME AND I'LL TALK." | Rupee / Rupee / Rupee | 5/10/20 | K2(1A) |
| 12 | $76 | "PAY ME AND I'LL TALK." | Rupee / Rupee / Rupee | 10/30/50 | A8(70) |
| 13 | $77 | "BUY SOMETHIN' WILL YA!" | Magical Shield / Bombs / Arrow | 130/20/80 | F3(25), E5(44), K5(4A), P7(6F) |
| 14 | $78 | "BUY SOMETHIN' WILL YA!" | Magical Shield / Key / Blue Candle | 160/100/60 | M1(0C), F2(15) [Q2], O6(5E), G7(66) |
| 15 | $79 | "BOY, THIS IS / REALLY EXPENSIVE!" | Magical Shield / Bait / Small Heart | 90/100/10 | C2(12), G3(26), G5(46), N5(4D) |
| 16 | $7A | "BOY, THIS IS / REALLY EXPENSIVE!" | Key / Blue Ring / Bait | 80/250/60 | E4(34) |
| 17 | $7B | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/30/0 | D2(13), I3(28), N3(2D), N4(3D), I5(48), I6(58) [Q2], H7(67) [Q1], B8(71) [Q1] |
| 18 | $7C | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/100/0 | P1(0F), D6(53) [Q2], C7(62) [Q1], L7(6B) [Q1] |
| 19 | $7D | "IT'S A SECRET / TO EVERYBODY." | (none) / Rupee / (none) | 0/10/0 | L3(2B) [Q2], O5(4E), B6(51), G6(56), L6(5B), O7(6E) [Q2] |

## Appendix D: all nine dungeons

Dark = attribute E bit 7. Secret trigger = attribute F bits 0-2. Room items come from attribute E bits 0-4 (3 = nothing).

#### Level 1

Start room $73; triforce room $36; boss room $35; stair rooms $7F; 17 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $22 | (none) | - |  | Trap (4) |
| $23 | Key | kill all, item appears |  | 3x Goriya (red) |
| $33 | Key | - |  | 3x Stalfos |
| $35 | Heart Container | kill all, item appears |  | Aquamentus |
| $36 | Triforce piece | - |  | - |
| $41 | (none) | - |  | old man: "EASTMOST PENNINSULA / IS THE SECRET." |
| $42 | (none) | push block, door opens |  | 3x Gel |
| $43 | Map | - |  | 5x Gel |
| $44 | Boomerang | kill all, item appears |  | 3x Goriya (red) |
| $45 | Key | - |  | 8x Wallmaster |
| $52 | (none) | kill all, shutters open |  | 6x Keese (blue) |
| $53 | Key | kill all, item appears |  | 5x Stalfos |
| $54 | Compass | - |  | 8x Keese (blue) |
| $63 | (none) | - |  | 3x Stalfos |
| $72 | Key | kill all, item appears |  | 3x Keese (blue) |
| $73 | (none) | - |  | - |
| $74 | Key | - |  | 5x Stalfos |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $7F | 63 | Bow | $22 / $22 |

#### Level 2

Start room $7D; triforce room $0D; boss room $0E; stair rooms none; 18 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $0D | Triforce piece | - |  | - |
| $0E | Heart Container | kill all, item appears |  | Dodongo (2) |
| $1E | Bombs | kill all, item appears |  | 5x Goriya (red) |
| $1F | (none) | - |  | old man: "DODONGO DISLIKES SMOKE." |
| $2E | (none) | kill all, shutters open |  | 8x Rope |
| $2F | 5 Rupees | kill all, item appears |  | 5x Gel |
| $3E | Key | kill all, item appears |  | Moldorm |
| $3F | Bombs | - |  | Trap (4), 4x Keese (blue) |
| $4E | Key | kill all, item appears |  | 5x Rope |
| $4F | Magical Boomerang | kill all, item appears |  | 3x Goriya (blue) |
| $5E | (none) | kill the ringleader, shutters open |  | 5x Goriya (red) |
| $5F | Map | - |  | 5x Gel |
| $6C | Key | - |  | 6x Rope |
| $6D | (none) | kill all, shutters open |  | 5x Rope |
| $6E | (none) | - |  | 3x Rope |
| $6F | Compass | - |  | 6x Gel |
| $7D | (none) | - |  | - |
| $7E | Key | kill all, item appears |  | 5x Rope |

#### Level 3

Start room $7C; triforce room $3D; boss room $4D; stair rooms $0F; 18 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $2A | Key | kill all, shutters open |  | 8x Keese (blue) |
| $2B | (none) | - |  | old man: "DID YOU GET THE SWORD / FROM THE OLD MAN ON / TOP OF THE WATERFALL?" |
| $3B | (none) | push block, door opens |  | Trap (4), 2x Zol |
| $3D | Triforce piece | - |  | - |
| $49 | Key | - |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $4A | Bombs | kill all, item appears |  | 5x Keese (blue) |
| $4B | Key | kill all, item appears |  | 3x Zol |
| $4C | Map | - |  | Trap (4), 2x Zol |
| $4D | Heart Container | kill all, item appears |  | Manhandla |
| $59 | (none) | kill all, shutters open |  | 5x Darknut (red) |
| $5A | Compass | - |  | Trap (4), 4x Keese (blue) |
| $5B | Bombs | kill all, item appears |  | 3x Darknut (red) |
| $5C | (none) | kill all, shutters open |  | 3x Darknut (red) |
| $5D | 5 Rupees | kill all, item appears |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $69 | Bombs | kill all, item appears |  | 8x Darknut (red) |
| $6B | Key | kill all, item appears |  | 5x Zol |
| $7B | Key | - |  | 6x Zol |
| $7C | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $0F | 63 | Raft | $69 / $69 |

#### Level 4

Start room $71; triforce room $03; boss room $13; stair rooms $60; 20 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $00 | (none) | - |  | old man: "WALK INTO THE / WATERFALL." |
| $01 | Key | - | yes | 8x Keese (blue) |
| $02 | (none) | - | yes | Trap (6) |
| $03 | Triforce piece | - |  | - |
| $10 | (none) | kill all, shutters open |  | Manhandla |
| $11 | (none) | - |  | Rupee stash |
| $12 | (none) | push block, door opens |  | 5x Vire |
| $13 | Heart Container | kill all, item appears |  | Gleeok (3 heads) |
| $20 | (none) | - |  | 5x Vire |
| $21 | Map | - | yes | 5x Gel |
| $30 | (none) | - | yes | 2x Bubble (black), 3x Vire |
| $31 | (none) | kill all, shutters open |  | 5x Vire |
| $32 | (none) | push block, stairs open |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $40 | Key | - | yes | 5x Zol |
| $50 | (none) | - | yes | 5x Vire |
| $51 | Key | - |  | 8x Keese (blue) |
| $61 | (none) | - |  | 3x Vire |
| $62 | Compass | - | yes | 5x Vire |
| $70 | Key | kill all, item appears |  | 8x Keese (blue) |
| $71 | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $60 | 63 | Stepladder | $32 / $32 |

#### Level 5

Start room $76; triforce room $14; boss room $24; stair rooms $04, $07; 23 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $05 | (none) | push block, stairs open |  | 6x Darknut (blue) |
| $06 | (none) | - |  | - |
| $14 | Triforce piece | - |  | - |
| $15 | (none) | - |  | old man: "SECRET POWER IS SAID / TO BE IN THE ARROW." |
| $16 | Key | - |  | 8x Keese (blue) |
| $17 | (none) | - |  | old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS." |
| $24 | Heart Container | kill all, item appears |  | Digdogger (2) |
| $25 | (none) | - |  | 5x Pols Voice |
| $26 | Key | kill all, item appears |  | 5x Gibdo |
| $27 | Key | - | yes | 2x Pols Voice, 2x Gibdo, 2x Keese (blue) |
| $34 | (none) | kill all, shutters open |  | 6x Gibdo |
| $37 | Compass | kill all, item appears | yes | 3x Darknut (red) |
| $46 | Map | - | yes | - |
| $47 | Key | kill all, item appears |  | 5x Gibdo |
| $55 | Key | kill all, item appears |  | 5x Zol |
| $56 | Bombs | kill all, item appears |  | 3x Dodongo (1) |
| $57 | 5 Rupees | kill all, item appears | yes | 5x Zol |
| $64 | (none) | - |  | 5x Darknut (blue) |
| $65 | Bombs | - |  | 5x Gibdo |
| $66 | Key | kill all, shutters open | yes | 3x Gibdo |
| $67 | (none) | - |  | old man: "DIGDOGGER HATES / CERTAIN KIND OF SOUND." |
| $76 | (none) | - |  | - |
| $77 | Key | kill all, item appears |  | 5x Pols Voice |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $04 | 63 | Recorder | $05 / $05 |
| $07 | 62 | (none) | $64 / $06 |

#### Level 6

Start room $79; triforce room $0C; boss room $1C; stair rooms $08, $75; 25 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $09 | (none) | push block, stairs open |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $0A | (none) | kill all, shutters open |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $0B | (none) | - |  | old man: "THERE ARE SECRETS WHERE / FAIRIES DON'T LIVE." |
| $0C | Triforce piece | - |  | - |
| $18 | (none) | kill all, shutters open |  | Gleeok (4 heads) |
| $19 | Map | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $1A | Key | - | yes | 6x Wizzrobe (red) |
| $1B | (none) | kill all, shutters open |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $1C | Heart Container | kill all, item appears |  | Gohma (blue) |
| $1D | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $28 | 5 Rupees | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $29 | Key | - | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $2C | (none) | - |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $2D | Key | kill all, item appears | yes | 2x Bubble (black), 3x Vire |
| $38 | (none) | push block, door opens |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $39 | (none) | kill all, shutters open | yes | 5x Vire |
| $3A | (none) | push block, stairs open |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $3C | Bombs | kill all, item appears | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $48 | (none) | - |  | Trap (6) |
| $58 | Key | kill all, item appears |  | 8x Keese (blue) |
| $68 | Compass | kill all, item appears |  | 5x Zol |
| $6A | (none) | - |  | old man: "AIM AT THE EYES / OF GOHMA." |
| $78 | (none) | kill the ringleader, shutters open |  | 5x Wizzrobe (red) |
| $79 | (none) | - |  | - |
| $7A | Key | kill all, item appears | yes | 5x Wizzrobe (red) |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $08 | 62 | (none) | $3A / $1D |
| $75 | 63 | Magical Rod | $09 / $09 |

#### Level 7

Start room $79; triforce room $2B; boss room $2A; stair rooms $4A, $7B; 33 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $08 | (none) | - |  | Rupee stash |
| $09 | 5 Rupees | kill all, item appears |  | 3x Goriya (blue), 3x Goriya (red) |
| $0A | Key | kill all, shutters open |  | 5x Goriya (blue) |
| $0B | Bombs | kill all, item appears |  | Moldorm |
| $0C | Bombs | kill all, item appears |  | 3x Dodongo (1) |
| $0D | (none) | push block, stairs open |  | 3x Bubble (black), 5x Wallmaster |
| $18 | Map | kill all, shutters open | yes | 2x Bubble (black), 3x Goriya (blue), 3x Keese (blue) |
| $19 | (none) | kill all, shutters open |  | 6x Goriya (blue) |
| $1A | (none) | - |  | 3x Goriya (blue), 3x Goriya (red) |
| $1B | Bombs | kill all, item appears |  | 6x Goriya (blue) |
| $1C | (none) | kill all, shutters open |  | Digdogger (1) |
| $28 | (none) | - |  | Grumble (the 'Grumble, grumble' man) |
| $29 | (none) | - |  | 3x Goriya (blue), 3x Goriya (red) |
| $2A | Heart Container | kill all, item appears |  | Aquamentus |
| $2B | Triforce piece | - |  | - |
| $38 | 5 Rupees | kill all, item appears |  | 3x Goriya (blue), 3x Goriya (red) |
| $39 | (none) | - |  | Digdogger (1) |
| $3A | Key | kill all, item appears |  | Moldorm |
| $48 | (none) | - |  | old man: "I BET YOU'D LIKE / TO HAVE MORE BOMBS." |
| $49 | (none) | kill all, shutters open |  | 2x Bubble (black), 3x Goriya (blue), 3x Keese (blue) |
| $58 | 5 Rupees | kill all, item appears |  | 3x Dodongo (1) |
| $59 | (none) | kill all, shutters open |  | 3x Goriya (blue), 3x Goriya (red) |
| $5A | Compass | - | yes | 8x Stalfos |
| $5B | (none) | - |  | old man: "THERE'S A SECRET IN / THE TIP OF THE NOSE." |
| $68 | Bombs | kill all, item appears |  | Trap (4), 4x Keese (blue) |
| $69 | Bombs | kill all, item appears |  | 5x Goriya (blue) |
| $6A | (none) | kill the ringleader, shutters open | yes | 8x Keese (blue) |
| $6B | (none) | kill all, shutters open |  | 6x Goriya (blue) |
| $6C | Bombs | kill all, item appears |  | Digdogger (2) |
| $6D | Key | - |  | 8x Stalfos |
| $78 | Key | - |  | 5x Rope |
| $79 | (none) | - |  | - |
| $7A | Bombs | kill all, item appears |  | Moldorm |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $4A | 63 | Red Candle | $1A / $1A |
| $7B | 62 | (none) | $29 / $0D |

#### Level 8

Start room $7E; triforce room $2C; boss room $3C; stair rooms $0F, $2F, $6F; 25 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $0E | Bombs | kill all, item appears |  | 5x Darknut (red) |
| $1D | Bombs | kill all, item appears |  | 5x Pols Voice |
| $1E | (none) | kill all, shutters open |  | Gohma (red) |
| $1F | (none) | kill all, shutters open |  | 2x Pols Voice, 2x Darknut (blue), 2x Darknut (red) |
| $2C | Triforce piece | - |  | - |
| $2D | (none) | - |  | Rupee stash |
| $2E | Map | kill all, item appears |  | Manhandla |
| $3B | (none) | - |  | old man: "10TH ENEMY HAS THE BOMB." |
| $3C | Heart Container | kill all, item appears |  | Gleeok (1 head) |
| $3D | (none) | - |  | old man: "SPECTACLE ROCK IS / AN ENTRANCE TO DEATH." |
| $3E | (none) | kill all, shutters open |  | 6x Darknut (blue) |
| $3F | Bombs | kill all, item appears |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $4B | Key | kill all, shutters open | yes | 6x Darknut (red) |
| $4C | Key | kill all, shutters open |  | 8x Pols Voice |
| $4D | (none) | kill all, shutters open |  | Gohma (red) |
| $4E | 5 Rupees | kill all, item appears |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $5C | Key | kill all, item appears |  | 3x Darknut (red) |
| $5D | Key | - | yes | 2x Pols Voice, 2x Gibdo, 2x Keese (blue) |
| $5E | Key | kill all, item appears |  | 5x Darknut (blue) |
| $5F | Compass | - | yes | 8x Pols Voice |
| $6E | 5 Rupees | kill all, item appears |  | Manhandla |
| $7C | (none) | - |  | 2x Bubble (black), Darknut (blue), 2x Darknut (red), 3x Gibdo |
| $7D | 5 Rupees | kill all, item appears |  | Manhandla |
| $7E | (none) | - |  | - |
| $7F | Key | - | yes | 3x Bubble (black), 2x Zol, 3x Keese (blue) |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $0F | 63 | Magical Key | $1F / $1F |
| $2F | 62 | (none) | $4C / $3F |
| $6F | 63 | Book of Magic | $7C / $7C |

#### Level 9

Start room $76; triforce room $32; boss room $42; stair rooms $00, $4F, $60, $67, $70, $72, $75, $77; 57 rooms reached through doors; monster group sizes (by count class) [3, 5, 6, 8].

| Room | Item | Secret trigger | Dark | Monsters / person |
|---|---|---|---|---|
| $01 | (none) | - | yes | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $02 | (none) | - |  | old man: "EYES OF SKULL / HAS A SECRET." |
| $03 | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $04 | (none) | - |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $05 | (none) | push block, stairs open |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $06 | (none) | - |  | old man: "GO TO THE NEXT ROOM." |
| $07 | (none) | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $10 | (none) | push block, stairs open |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $11 | Bombs | kill all, item appears |  | Lanmola (blue) |
| $12 | 5 Rupees | kill all, item appears |  | Lanmola (red) |
| $13 | (none) | - | yes | 2x Bubble (black), 2x Zol, 2x Like Like |
| $14 | (none) | - |  | 5x Like Like |
| $15 | 5 Rupees | kill all, item appears | yes | 3x Wizzrobe (blue) |
| $16 | Bombs | kill all, item appears |  | Patra (2) |
| $17 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $20 | (none) | - |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $21 | (none) | - |  | Patra (1) |
| $22 | (none) | - |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $23 | Bombs | - |  | 8x Gel |
| $24 | (none) | - | yes | 5x Vire |
| $25 | Bombs | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $26 | 5 Rupees | kill all, item appears |  | 8x Gel |
| $27 | Map | kill all, item appears |  | Patra (2) |
| $30 | (none) | push block, stairs open |  | Trap (4), 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $31 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $32 | (none) | kill all, shutters open |  | Zelda |
| $33 | (none) | - | yes | 8x Gel |
| $34 | 5 Rupees | kill all, item appears |  | 8x Keese (blue) |
| $35 | Compass | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $36 | (none) | - |  | 3x Bubble (black), 2x Zol, 3x Keese (blue) |
| $37 | Bombs | kill all, item appears |  | 6x Vire |
| $40 | 5 Rupees | kill all, item appears |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $41 | (none) | - | yes | Trap (4), 4x Like Like |
| $42 | Triforce of Power | last boss | yes | Ganon |
| $43 | (none) | - |  | old man: "PATRA HAS THE MAP." |
| $44 | 5 Rupees | kill all, item appears |  | 6x Wizzrobe (red) |
| $45 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $46 | (none) | - |  | 6x Wizzrobe (blue) |
| $47 | Key | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $50 | (none) | kill all, shutters open | yes | 5x Zol |
| $51 | (none) | kill all, shutters open |  | 6x Like Like |
| $52 | (none) | kill all, shutters open |  | Patra (1) |
| $53 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $54 | (none) | - |  | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $55 | (none) | - |  | Lanmola (red) |
| $56 | Key | kill all, item appears |  | 2x Bubble (black), 2x Zol, 2x Like Like |
| $57 | Key | kill all, item appears | yes | 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $61 | Key | - |  | Patra (1) |
| $62 | 5 Rupees | kill all, item appears |  | 8x Keese (blue) |
| $63 | (none) | - |  | 5x Zol |
| $64 | (none) | - |  | Bubble (black), 3x Like Like, 2x Wizzrobe (blue), 2x Wizzrobe (red) |
| $65 | (none) | - | yes | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $66 | (none) | - |  | old man: "ONES WHO DOES NOT HAVE / TRIFORCE CAN'T GO IN." |
| $71 | (none) | - |  | - |
| $73 | (none) | - |  | 3x Bubble (black), 3x Wizzrobe (blue), 2x Wizzrobe (red) |
| $74 | (none) | - |  | Lanmola (blue) |
| $76 | (none) | - |  | - |

Stair rooms (layout 62 = stairs joining two dungeon rooms; layout 63 = item cellar with 4 blue keese):

| Room | Layout | Item | Joins |
|---|---|---|---|
| $00 | 63 | Red Ring | $07 / $07 |
| $4F | 63 | Silver Arrow | $10 / $10 |
| $60 | 62 | (none) | $14 / $55 |
| $67 | 62 | (none) | $30 / $04 |
| $70 | 62 | (none) | $63 / $05 |
| $72 | 62 | (none) | $71 / $74 |
| $75 | 62 | (none) | $20 / $61 |
| $77 | 62 | (none) | $52 / $03 |

## Appendix E: the 38 ROM texts

| Index | Selector (x2) | Text |
|---|---|---|
| 0 | $00 | IT'S DANGEROUS TO GO / ALONE! TAKE THIS.|
| 1 | $02 | MASTER USING IT AND / YOU CAN HAVE THIS.|
| 2 | $04 | TAKE ANY ROAD YOU WANT.|
| 3 | $06 | SECRET IS IN THE TREE / AT THE DEAD-END.|
| 4 | $08 | LET'S PLAY MONEY / MAKING GAME.|
| 5 | $0A | PAY ME FOR THE DOOR / REPAIR CHARGE.|
| 6 | $0C | SHOW THIS TO THE / OLD WOMAN.|
| 7 | $0E | MEET THE OLD MAN / AT THE GRAVE.|
| 8 | $10 | BUY MEDICINE BEFORE / YOU GO.|
| 9 | $12 | PAY ME AND I'LL TALK.|
| 10 | $14 | THIS AIN'T ENOUGH / TO TALK.|
| 11 | $16 | GO UP,UP, / THE MOUNTAIN AHEAD.|
| 12 | $18 | GO NORTH,WEST,SOUTH, / WEST TO THE FOREST / OF MAZE.|
| 13 | $1A | BOY, YOU'RE RICH!|
| 14 | $1C | BUY SOMETHIN' WILL YA!|
| 15 | $1E | BOY, THIS IS / REALLY EXPENSIVE!|
| 16 | $20 | TAKE ANY ONE YOU WANT.|
| 17 | $22 | IT'S A SECRET / TO EVERYBODY.|
| 18 | $24 | GRUMBLE,GRUMBLE...|
| 19 | $26 | EASTMOST PENNINSULA / IS THE SECRET.|
| 20 | $28 | DODONGO DISLIKES SMOKE.|
| 21 | $2A | DID YOU GET THE SWORD / FROM THE OLD MAN ON / TOP OF THE WATERFALL?|
| 22 | $2C | WALK INTO THE / WATERFALL.|
| 23 | $2E | SECRET POWER IS SAID / TO BE IN THE ARROW.|
| 24 | $30 | DIGDOGGER HATES / CERTAIN KIND OF SOUND.|
| 25 | $32 | I BET YOU'D LIKE / TO HAVE MORE BOMBS.|
| 26 | $34 | IF YOU GO IN THE / DIRECTION OF THE ARROW.|
| 27 | $36 | LEAVE YOUR LIFE / OR MONEY.|
| 28 | $38 | THERE ARE SECRETS WHERE / FAIRIES DON'T LIVE.|
| 29 | $3A | AIM AT THE EYES / OF GOHMA.|
| 30 | $3C | SOUTH OF ARROW MARK / HIDES A SECRET.|
| 31 | $3E | THERE'S A SECRET IN / THE TIP OF THE NOSE.|
| 32 | $40 | SPECTACLE ROCK IS / AN ENTRANCE TO DEATH.|
| 33 | $42 | 10TH ENEMY HAS THE BOMB.|
| 34 | $44 | ONES WHO DOES NOT HAVE / TRIFORCE CAN'T GO IN.|
| 35 | $46 | PATRA HAS THE MAP.|
| 36 | $48 | GO TO THE NEXT ROOM.|
| 37 | $4A | EYES OF SKULL / HAS A SECRET.|
