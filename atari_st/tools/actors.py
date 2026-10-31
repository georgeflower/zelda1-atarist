"""Monsters, floor items and room contents for the underworld.

Everything is read from the disassembly tables the 6502 uses, so the ST only
has to look values up: sprite frames (ObjAnimations / ObjAnimFrameHeap /
ObjAnimAttrHeap), hit points (ObjectTypeToHpPairs), drops (DropItemTable) and
item art (Anim_ItemFrameOffsets / Anim_ItemFrameTiles).
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import build_assets as B

# Monsters this port draws and moves so far (Level 1's repertoire). Others in a
# room (traps, and the monsters of later levels) are left out for now.
MONSTER_TYPES = (0x06, 0x15, 0x1B, 0x28, 0x2A, 0x27, 0x3D, 0x49,
                 0x01, 0x02, 0x03, 0x04, 0x07, 0x08, 0x09, 0x0A,
                 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x1A, 0x1F, 0x20, 0x21,
                 # Level 2: the blue goriya, the two Dodongos and Moldorm
                 0x05, 0x31, 0x32, 0x41,
                 # Levels 3 to 8, the ones that walk: red and blue darknuts, vire, zol, pols voice, like-like,
                 # the wizzrobes, bubbles (flashing, blue and red) and gibdos
                 0x0B, 0x0C, 0x12, 0x13, 0x16, 0x17, 0x23, 0x24, 0x2B, 0x2C, 0x2D, 0x30,
                 # the red keese a vire leaves behind, and the black keese of the Second Quest's Level 4
                 0x1C, 0x1D,
                 # Manhandla (one object per hand and a base)
                 0x3C,
                 # Gohma, blue and red, and the two pairs of legs the game puts down beside its eye (not ROM types)
                 0x33, 0x34, 0xFD, 0xFC,
                 # Digdogger: the big one, the one that splits into one child instead of three (the ROM's $39), and
                 # the little ones
                 0x38, 0xFB, 0x18,
                 # Gleeok with two, three and four necks, the head on one of them (not a ROM type) and the flying head a
                 # neck turns into when it is cut off
                 0x43, 0x44, 0x45, 0xF9, 0x46,
                 # Level 9: Lanmola, blue (one pixel a frame) and red (two)
                 0x3A, 0x3B,
                 # Patra, the eye the two kinds of room have, and its children (the ROM gives them types of their own)
                 0x47, 0x48, 0x25, 0x26,
                 # Ganon, and the room where Zelda waits with the four fires that guard her
                 0x3E, 0x37, 0x3F,
                 # the overworld's own: the armos that wakes when Link pushes it, the whirlwind of the recorder and
                 # the fairy of the ponds
                 0x1E, 0x2E, 0x2F,
                 # the flying ghini a touched gravestone lets out (InitArmosOrFlyingGhini)
                 0x22)
# Pieces of a boss that the ROM draws as part of it but this port makes monsters of: (the type whose art they use, the
# first frame of that art). Gohma's legs are frames 4 and 5 of its own animation.
SYNTHETIC_TYPES = {0xFD: (0x33, 4), 0xFC: (0x34, 4), 0xFB: (0x38, 0), 0xF9: (0x43, 0)}
# The hit points the ROM sets by hand: every neck of a Gleeok has $A0.
SYNTHETIC_HP = {0xF9: 10}
# Bosses that leave nothing behind but the room's own item
NO_DROP_BOSSES = (0x2E, 0x2F, 0x43, 0x44, 0x45, 0xF9, 0x46, 0x38, 0xFB, 0x47, 0x48, 0x25, 0x26, 0x3E, 0x37, 0x3F)
# The ones of them that live on the overworld: lynels (blue, red), moblins (blue, red) and octoroks
# (red slow, red fast, blue slow, blue fast). Their art comes from the overworld's sprite pattern table.
OVERWORLD_MONSTERS = (0x01, 0x02, 0x03, 0x04, 0x07, 0x08, 0x09, 0x0A,
                      0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x1A, 0x1F, 0x20, 0x21)
# Armos, flying ghinis and the whirlwind are drawn with the overworld's sprite patterns too but no room lists them (armos
# and flying ghinis wake from the map, the whirlwind from the recorder); the fairy is a screen's only monster in the two ponds ($39 and $43) and takes
# the common patterns, as the items do.
OVERWORLD_ART = OVERWORLD_MONSTERS + (0x1E, 0x2E, 0x22)
OVERWORLD_LISTED = OVERWORLD_MONSTERS + (0x2F,)
FAIRY_TILES = (0x50, 0x52)       # the two frames of the fairy item (Anim_ItemFrameTiles at the fairy's offset)
# Zoras are not in any room's list: a screen whose attribute A has bit 3 makes one in the water (CheckZora).
# Frames between one-pixel steps: the 6502's quarter-speed $20 is half a pixel
# a frame; keese are quicker and wallmasters slower. A gel walks a pixel a frame (quarter-speed
# $40) but rests at the edge of every square. Aquamentus moves a
# pixel every eighth frame.
# A period of PERIOD_PATTERN + n steps on the frames set in STEP_PATTERNS[n] (a pixel on each bit set of eight frames):
# 0 is three in eight ($18), 1 five in eight ($28), 2 six in eight ($30).
PERIOD_PATTERN = 0x80
MONSTER_PERIOD = {0x06: 2, 0x15: 1, 0x1B: 1, 0x28: 2, 0x2A: 2, 0x27: 3, 0x3D: 8, 0x49: 1,
                  # lynels and moblins walk at quarter-speed $20; octoroks too, the fast ones at $30 (InitFastOctorock:
                  # 0.75 pixels a frame, six in eight)
                  0x01: 2, 0x02: 2, 0x03: 2, 0x04: 2, 0x07: 2, 0x08: PERIOD_PATTERN + 2, 0x09: 2, 0x0A: PERIOD_PATTERN + 2,
                  # ghinis walk at $20; the others move by their own rules (the period is not used)
                  0x0D: 1, 0x0E: 1, 0x0F: 2, 0x10: 2, 0x11: 1, 0x1A: 1, 0x1F: 1, 0x20: 1, 0x21: 2,
                  # blue goriya like the red; Dodongo walks at the default quarter-speed; Moldorm moves itself
                  0x05: 2, 0x31: 2, 0x32: 2, 0x41: 1,
                  # a red darknut walks at quarter-speed $20 (one pixel every other frame), a blue one at $28
                  # (five pixels in eight frames), a zol at $18 (three in eight): STEP_PATTERNS in enemy.s;
                  # a bubble at $40; the vire and gibdo at the default $20; pols voice, the like-like and
                  # the wizzrobes move by their own rules
                  0x0B: 2, 0x0C: PERIOD_PATTERN + 1, 0x12: 2, 0x13: PERIOD_PATTERN, 0x16: 2, 0x17: 2,
                  0x23: 1, 0x24: 1, 0x2B: 1, 0x2C: 1, 0x2D: 1, 0x30: 2, 0x1C: 1, 0x1D: 1, 0x3C: 1, 0x33: 1, 0x34: 1, 0xFD: 1, 0xFC: 1,
                  0x38: 1, 0xFB: 1, 0x18: 1, 0x43: 1, 0x44: 1, 0x45: 1, 0xF9: 1, 0x46: 1, 0x3A: 1, 0x3B: 1,
                  0x47: 1, 0x48: 1, 0x25: 1, 0x26: 1, 0x3E: 1, 0x37: 1, 0x3F: 1,
                  # armos at quarter-speed $20; the whirlwind two pixels a frame and the fairy move themselves
                  0x1E: 2, 0x2E: 1, 0x2F: 1, 0x22: 1}
# The q-speed (a 64th of a pixel a frame) each walking monster is given, as the ROM's Init and Update routines set it:
# InitObject's default $20 for lynels, moblins, goriyas, slow octoroks, red darknuts, the vire, rope (which charges at
# $60), stalfos and gibdos; $30 for fast octoroks; $28 for blue darknuts; $18 for a zol; $40 for gels and bubbles.
# tests/test_actors.py holds MONSTER_PERIOD to this: the two must give the same pixels per frame.
# The armos walks like a goriya (UpdateArmos calls UpdateGoriya) at $20 or $60, picked at random when it has risen; the flying ghini flies up to $A0.
ROM_QSPEED = {0x01: 0x20, 0x02: 0x20, 0x03: 0x20, 0x04: 0x20, 0x05: 0x20, 0x06: 0x20,
              0x07: 0x20, 0x08: 0x30, 0x09: 0x20, 0x0A: 0x30, 0x0B: 0x20, 0x0C: 0x28,
              0x12: 0x20, 0x13: 0x18, 0x15: 0x40, 0x28: 0x20, 0x2A: 0x20, 0x2B: 0x40, 0x2C: 0x40, 0x2D: 0x40, 0x30: 0x20,
              }
# Half-hearts of damage on contact (ObjTypeToDamagePoints: $80 is half a heart).
MONSTER_DAMAGE = {0x06: 1, 0x15: 1, 0x1B: 1, 0x28: 1, 0x2A: 1, 0x27: 1, 0x3D: 2, 0x49: 2,
                  # ObjTypeToDamagePoints: blue lynel $02 (two hearts), red lynel $01, the rest $80
                  0x01: 4, 0x02: 2, 0x03: 1, 0x04: 1, 0x07: 1, 0x08: 1, 0x09: 1, 0x0A: 1,
                  # tektites $80, the blue leever one heart ($01), the red leever, the zora and the peahat
                  # $80, boulders $80, a ghini one heart (ObjTypeToDamagePoints)
                  0x0D: 1, 0x0E: 1, 0x0F: 2, 0x10: 1, 0x11: 1, 0x1A: 1, 0x1F: 0, 0x20: 1, 0x21: 2,
                  # blue goriya $01 (a heart), Dodongo $01, Moldorm $80
                  0x05: 2, 0x31: 2, 0x32: 2, 0x41: 1,
                  # ObjTypeToDamagePoints: darknuts $01 and $02, vire and zol $01, pols voice $02, like-like $01,
                  # blue wizzrobe $02 and red $01, a bubble none, gibdo $02
                  0x0B: 2, 0x0C: 4, 0x12: 2, 0x13: 2, 0x16: 4, 0x17: 2, 0x23: 4, 0x24: 2, 0x2B: 0, 0x2C: 0, 0x2D: 0, 0x30: 4, 0x1C: 1, 0x1D: 1,
                  # Manhandla $01
                  0x3C: 2,
                  # Gohma and its legs: two hearts
                  0x33: 4, 0x34: 4, 0xFD: 4, 0xFC: 4,
                  # Digdogger and its young: two hearts
                  0x38: 4, 0xFB: 4, 0x18: 4,
                  # Gleeok's body and heads: one heart (ObjTypeToDamagePoints $01)
                  0x43: 2, 0x44: 2, 0x45: 2, 0xF9: 2, 0x46: 2,
                  # Lanmola: two hearts
                  0x3A: 4, 0x3B: 4,
                  # Patra and its children: $02, two hearts
                  0x47: 4, 0x48: 4, 0x25: 4, 0x26: 4,
                  # Ganon: $04, four hearts; Zelda touches nobody; a guard fire $80
                  0x3E: 8, 0x37: 0, 0x3F: 1,
                  # armos $01 (a heart), the whirlwind and the fairy $00
                  0x1E: 2, 0x2E: 0, 0x2F: 0, 0x22: 2}
# What hurts a monster: the bits of the original's damage types ($01 sword, $02 boomerang (it stuns), $04 arrow,
# $08 bomb, $10 magic, $20 fire) that its ObjInvincibilityMask leaves, and bit 7 for the darknuts' shield, which
# turns a sword aside when the two face each other. Anything not listed is hurt by all six.
HURT_ALL = 0x3F
HURT_SHIELD = 0x80
MONSTER_HURT = {
    0x0B: 0x09 | HURT_SHIELD, 0x0C: 0x09 | HURT_SHIELD,    # InitDarknut: $F6
    0x16: 0x45,         # pols voice: $FE, but an arrow kills it
    0x23: 0x09, 0x24: 0x09,                                 # wizzrobes: $F6
    0x3D: 0x1D,         # Aquamentus: $E2, no boomerang or fire
    0x33: 0x04, 0x34: 0x04,                                 # Gohma: $FB, arrows only (dmon_hit_filter checks the eye)
    0xFD: 0x00, 0xFC: 0x00,                                 # its legs take nothing
    0x38: 0x00, 0xFB: 0x00,                                 # a big Digdogger takes nothing: the recorder splits it
    0x43: 0x00, 0x44: 0x00, 0x45: 0x00, 0x46: 0x00,         # Gleeok's body and flying heads take nothing
    0xF9: 0x01,                                             # a head on its neck: $FE, the sword only
    0x47: 0x01, 0x48: 0x01, 0x25: 0x01, 0x26: 0x01,         # Patra and its children: InitPatra sets $FE, the sword only
    0x37: 0x00,         # Zelda takes nothing (UpdateZelda never calls CheckMonsterCollisions)
    0x3E: 0x05,         # Ganon: InitGanon sets $FA, the sword and the arrow (dmon_hit_filter does the rest)
    0x3C: 0x1D,         # Manhandla's hands: $E2 too (the base is made proof against everything in dmon.s)
    0x2E: 0x00, 0x2F: 0x00,     # the whirlwind and the fairy take nothing
}
# Keese ignore walls and blocks and are only held in by the room edges.
MONSTER_FLYERS = (0x1B, 0x1A, 0x1C, 0x1D, 0x3C, 0x38, 0xFB, 0x18, 0x43, 0x44, 0x45, 0xF9, 0x46, 0x47, 0x48, 0x25, 0x26, 0x3E, 0x2E, 0x2F, 0x22)

# What the game does with a monster every frame, besides drawing it.
(BEHAVIOUR_WANDER, BEHAVIOUR_ROPE, BEHAVIOUR_GORIYA, BEHAVIOUR_WALLMASTER, BEHAVIOUR_BOSS,
 BEHAVIOUR_KEESE, BEHAVIOUR_TRAP, BEHAVIOUR_GEL, BEHAVIOUR_OCTOROK, BEHAVIOUR_MOBLIN,
 BEHAVIOUR_LYNEL, BEHAVIOUR_OCTOROK_BLUE, BEHAVIOUR_TEKTITE, BEHAVIOUR_LEEVER, BEHAVIOUR_ZORA,
 BEHAVIOUR_PEAHAT, BEHAVIOUR_GHINI, BEHAVIOUR_BOULDER, BEHAVIOUR_BOULDER_SET,
 BEHAVIOUR_DODONGO, BEHAVIOUR_MOLDORM, BEHAVIOUR_POLS, BEHAVIOUR_WIZZROBE, BEHAVIOUR_BUBBLE,
 BEHAVIOUR_MANHANDLA, BEHAVIOUR_GOHMA, BEHAVIOUR_DIGDOGGER, BEHAVIOUR_GLEEOK, BEHAVIOUR_GLEEOK_HEAD,
 BEHAVIOUR_GLEEOK_FLYER, BEHAVIOUR_LANMOLA, BEHAVIOUR_PATRA, BEHAVIOUR_PATRA_CHILD, BEHAVIOUR_GANON, BEHAVIOUR_ZELDA, BEHAVIOUR_FIRE,
 BEHAVIOUR_ARMOS, BEHAVIOUR_WHIRLWIND, BEHAVIOUR_FAIRY) = range(39)
MONSTER_BEHAVIOUR = {0x28: BEHAVIOUR_ROPE, 0x06: BEHAVIOUR_GORIYA, 0x1B: BEHAVIOUR_KEESE,
                      0x27: BEHAVIOUR_WALLMASTER, 0x3D: BEHAVIOUR_BOSS, 0x49: BEHAVIOUR_TRAP,
                      0x15: BEHAVIOUR_GEL, 0x01: BEHAVIOUR_LYNEL, 0x02: BEHAVIOUR_LYNEL,
                      0x03: BEHAVIOUR_MOBLIN, 0x04: BEHAVIOUR_MOBLIN, 0x07: BEHAVIOUR_OCTOROK,
                      0x08: BEHAVIOUR_OCTOROK, 0x09: BEHAVIOUR_OCTOROK_BLUE, 0x0A: BEHAVIOUR_OCTOROK_BLUE,
                      0x0D: BEHAVIOUR_TEKTITE, 0x0E: BEHAVIOUR_TEKTITE, 0x0F: BEHAVIOUR_LEEVER,
                      0x10: BEHAVIOUR_LEEVER, 0x11: BEHAVIOUR_ZORA, 0x1A: BEHAVIOUR_PEAHAT,
                      0x21: BEHAVIOUR_GHINI, 0x20: BEHAVIOUR_BOULDER, 0x1F: BEHAVIOUR_BOULDER_SET,
                      0x05: BEHAVIOUR_GORIYA, 0x31: BEHAVIOUR_DODONGO, 0x32: BEHAVIOUR_DODONGO,
                      0x41: BEHAVIOUR_MOLDORM, 0x16: BEHAVIOUR_POLS, 0x23: BEHAVIOUR_WIZZROBE,
                      0x24: BEHAVIOUR_WIZZROBE, 0x2B: BEHAVIOUR_BUBBLE, 0x2C: BEHAVIOUR_BUBBLE, 0x2D: BEHAVIOUR_BUBBLE, 0x3C: BEHAVIOUR_MANHANDLA,
                      0x33: BEHAVIOUR_GOHMA, 0x34: BEHAVIOUR_GOHMA, 0xFD: BEHAVIOUR_GOHMA, 0xFC: BEHAVIOUR_GOHMA,
                      0x38: BEHAVIOUR_DIGDOGGER, 0xFB: BEHAVIOUR_DIGDOGGER, 0x18: BEHAVIOUR_DIGDOGGER,
                      0x43: BEHAVIOUR_GLEEOK, 0x44: BEHAVIOUR_GLEEOK, 0x45: BEHAVIOUR_GLEEOK,
                      0xF9: BEHAVIOUR_GLEEOK_HEAD, 0x46: BEHAVIOUR_GLEEOK_FLYER,
                      0x3A: BEHAVIOUR_LANMOLA, 0x3B: BEHAVIOUR_LANMOLA,
                      0x47: BEHAVIOUR_PATRA, 0x48: BEHAVIOUR_PATRA,
                      0x25: BEHAVIOUR_PATRA_CHILD, 0x26: BEHAVIOUR_PATRA_CHILD, 0x3E: BEHAVIOUR_GANON,
                      0x37: BEHAVIOUR_ZELDA, 0x3F: BEHAVIOUR_FIRE,
                      0x1E: BEHAVIOUR_ARMOS, 0x22: BEHAVIOUR_ARMOS, 0x2E: BEHAVIOUR_WHIRLWIND, 0x2F: BEHAVIOUR_FAIRY,
                      # the darknuts, gibdo, vire, zol and like-like walk like a stalfos (turn rate $80) or a gel
                      0x13: BEHAVIOUR_GEL, 0x1C: BEHAVIOUR_KEESE, 0x1D: BEHAVIOUR_KEESE}

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
MODE_OCTOROK = 8    # six images: side, front, back, each in two animation sets
# The modes from here on keep every frame of the monster's animation, in the ROM's order, and the game
# picks the frame (ai.s mover_frame): tektite 2, leever 10, zora 10, peahat 2, ghini 2, boulder 2.
MODE_TEKTITE = 9
MODE_LEEVER = 10
MODE_ZORA = 11
MODE_PEAHAT = 12
MODE_GHINI = 13
MODE_BOULDER = 14
MODE_NONE = 15      # the boulder set that makes the boulders is never seen
MODE_DODONGO = 16   # ten images (two squares wide, or one when it faces up or down), picked by dodongo_frame in enemy.s
MODE_MOLDORM = 17   # one picture, a fireball tile in the red row
MODE_DARKNUT = 18   # six images: side, down, up, then the same for the second step (dmon.s dmon_frame)
MODE_VIRE = 19      # four images: two steps, and two for facing up
MODE_ZOL = 20       # two images, swapped every eight frames
MODE_LIKELIKE = 21  # four images, one every eight frames
MODE_WIZZROBE = 22  # side/down in two steps, then up in two
MODE_BUBBLE = 23    # one picture in each of the four sprite palette rows, a new row every frame
MODE_MANHANDLA = 24  # eight images: hand up (2), hand to the side (2), the body (2), hand down (2)
MODE_GOHMA = 25      # four images of the eye: shut (2), half open, open
MODE_GOHMA_LEG = 26  # two images, a pair of legs
MODE_DIGDOGGER = 27  # a little Digdogger: two pictures
MODE_DIGBIG = 28     # a quarter of a big one, as four images (plain, turned right-left, upside down, both)
MODE_GLEEOK = 29     # the body: drawn by the boss sprite pool (gleeok_pool), never as a monster
MODE_GLEEOK_HEAD = 30  # a head on its neck: one picture
MODE_LANMOLA = 31      # two images: a head and a body segment, narrow
MODE_PATRA = 32        # the eye: two images, swapped every few frames
MODE_PATRA_CHILD = 33  # a child: two images, not drawn until it has come out
MODE_GANON = 34        # 21 images (ten pictures blue, ten brown, the ashes; each stored plain and mirrored), drawn by the boss sprite pool
MODE_ARMOS = 35        # four images: front and back, each in two steps (owspec.s armos_frame)
MODE_FAIRY = 36        # two images: wings up and down
ROPE_PALETTES = 4      # the rope: two walk frames in each of the four sprite palette rows, image = frame + 2 * row (the Second Quest flashes through them)
ROPE_RED_ROW = 2       # UpdateRope: Anim_SetSpriteDescriptorAttributes with the red sprite palette
FRAME_MODES = (MODE_ROPE, MODE_ARMOS, MODE_FAIRY, MODE_PATRA, MODE_PATRA_CHILD, MODE_GANON, MODE_MANHANDLA, MODE_GOHMA, MODE_GOHMA_LEG, MODE_DIGDOGGER, MODE_DIGBIG, MODE_GLEEOK, MODE_GLEEOK_HEAD, MODE_LANMOLA, MODE_TEKTITE, MODE_LEEVER, MODE_ZORA, MODE_PEAHAT, MODE_GHINI, MODE_BOULDER, MODE_DODONGO,
               MODE_DARKNUT, MODE_VIRE, MODE_ZOL, MODE_LIKELIKE, MODE_WIZZROBE, MODE_BUBBLE)
MONSTER_DRAW = {
    0x06: ("wide", 4, MODE_WALKER),
    0x15: ("narrow", 2, MODE_GEL),
    0x1B: ("mirror", 2, MODE_KEESE),
    0x28: ("wide", 2 * ROPE_PALETTES, MODE_ROPE),
    0x2A: ("wide", 1, MODE_STALFOS),
    0x27: ("wide", 2, MODE_WALLMASTER),
    0x3D: ("wide", 1, MODE_BOSS),
    0x49: ("mirror", 1, MODE_STATIC),
    0x01: ("wide", 4, MODE_WALKER),
    0x02: ("wide", 4, MODE_WALKER),
    0x03: ("wide", 4, MODE_WALKER),
    0x04: ("wide", 4, MODE_WALKER),
    0x07: ("octorok", 6, MODE_OCTOROK),
    0x08: ("octorok", 6, MODE_OCTOROK),
    0x09: ("octorok", 6, MODE_OCTOROK),
    0x0A: ("octorok", 6, MODE_OCTOROK),
    0x0D: ("mirror", 2, MODE_TEKTITE),
    0x0E: ("mirror", 2, MODE_TEKTITE),
    0x0F: ("mirror", 10, MODE_LEEVER),
    0x10: ("mirror", 10, MODE_LEEVER),
    0x11: ("mirror", 10, MODE_ZORA),
    0x1A: ("mirror", 2, MODE_PEAHAT),
    0x1F: ("wide", 1, MODE_NONE),
    0x20: ("wide", 2, MODE_BOULDER),
    0x21: ("wide", 2, MODE_GHINI),
    0x22: ("wide", 2, MODE_GHINI),         # a flying ghini draws like a ghini
    0x05: ("wide", 4, MODE_WALKER),
    0x31: ("wide", 10, MODE_DODONGO),
    0x32: ("wide", 10, MODE_DODONGO),
    0x41: ("mirror", 1, MODE_MOLDORM),
    0x0B: ("wide", 6, MODE_DARKNUT),
    0x0C: ("wide", 6, MODE_DARKNUT),
    0x12: ("mirror", 4, MODE_VIRE),
    0x13: ("mirror", 2, MODE_ZOL),
    0x16: ("mirror", 2, MODE_ZOL),
    0x17: ("mirror", 4, MODE_LIKELIKE),
    0x23: (("wide", "wide", "mirror", "mirror"), 4, MODE_WIZZROBE),
    0x24: (("wide", "wide", "mirror", "mirror"), 4, MODE_WIZZROBE),
    0x2B: ("wide", 4, MODE_BUBBLE),
    0x2C: ("wide", 4, MODE_BUBBLE),         # the blue bubble: UpdateBubble draws it in palette row 1
    0x2D: ("wide", 4, MODE_BUBBLE),         # the red one in row 2; the flashing $2B cycles through all four
    0x30: ("wide", 1, MODE_STALFOS),
    0x1C: ("mirror", 2, MODE_KEESE),
    0x1D: ("mirror", 2, MODE_KEESE),
    0x3C: (("mirror", "mirror", "wide", "wide", "mirror", "mirror"), 8, MODE_MANHANDLA),
    0x33: ("mirror", 4, MODE_GOHMA),
    0x34: ("mirror", 4, MODE_GOHMA),
    0xFD: ("wide", 2, MODE_GOHMA_LEG),
    0xFC: ("wide", 2, MODE_GOHMA_LEG),
    0x18: ("mirror", 2, MODE_DIGDOGGER),
    0x38: ("wide", 1, MODE_DIGBIG),
    0xFB: ("wide", 1, MODE_DIGBIG),
    0x43: ("wide", 14, MODE_GLEEOK),
    0x44: ("wide", 14, MODE_GLEEOK),
    0x45: ("wide", 14, MODE_GLEEOK),
    0xF9: ("left", 1, MODE_GLEEOK_HEAD),
    0x46: ("mirror", 2, MODE_KEESE),
    0x3A: ("narrow", 2, MODE_LANMOLA),
    0x3B: ("narrow", 2, MODE_LANMOLA),
    0x47: ("wide", 2, MODE_PATRA),
    0x48: ("wide", 2, MODE_PATRA),
    0x25: ("mirror", 2, MODE_PATRA_CHILD),
    0x26: ("mirror", 2, MODE_PATRA_CHILD),
    0x3E: ("wide", 1, MODE_GANON),
    0x37: ("mirror", 1, MODE_STATIC),
    0x3F: ("wide", 1, MODE_STALFOS),
    0x1E: ("wide", 4, MODE_ARMOS),
    0x2E: ("wide", 4, MODE_BUBBLE),         # DrawWhirlwind: one picture, a new palette row every frame
    0x2F: ("narrow", 2, MODE_FAIRY),
}
# UpdateMoldorm draws every segment as the fireball tile $44 in palette row 2, and Dodongo_Draw uses row 3.
# Gohma_SetSpriteAttributes: the red one (and its legs) use palette row 2, the blue one row 1.
MONSTER_TILE_ROW = {0x31: (None, 3), 0x32: (None, 3), 0x41: (0x44, 2), 0x34: (None, 2), 0xFC: (None, 2),
                    0x38: (None, 3), 0xFB: (None, 3),
                    0x25: (None, 2), 0x26: (None, 2), 0x37: (None, 2)}   # PatraChild_Draw: Anim_SetSpriteDescriptorRedPaletteRow   # DigdoggerSpriteAttrs: palette row 3
# Dodongo images 7 and 9 (bloated, facing up or down) are one half drawn twice, mirrored.
DODONGO_MIRRORED_IMAGES = (7, 9)
# InitMode5Play looks at the first monster of a dungeon room (SpecialBossPaletteObjTypes) and, for the Dodongos ($31, $32) and
# the Digdoggers ($38, $39), cues OrangeBossPaletteRow7TransferBuf: sprite palette row 3 becomes $17 $27 $30 (brown, light
# orange, white) whatever the level's own row 3 is (Level 2's is blue). The ST palette holds the level's colours in the three
# slots of row 3, which the walls may share, so the art is baked with those three colours, which every level keeps in Link's
# and the shield's rows: $17 and $27 in Link's row (pixel 3, 2), $30 in the second row (pixel 3).
ORANGE_BOSS_TYPES = (0x31, 0x32, 0x38, 0xFB, 0x18)
ORANGE_BOSS_COLOURS = ((4, 3), (4, 2), (5, 3))
# Gleeok has the same kind of palette: $2A $1A $0C (green, dark green, dark blue-grey). The slots below hold the nearest ST colours
# in every level: 10 is Link's tunic green (0x460), 7 the dark green (0x050, exactly $1A), 11 a dark blue (0x005).
GLEEOK_TYPES = (0x43, 0x44, 0x45, 0xF9, 0x46)
GLEEOK_SLOTS = (10, 7, 11)
LANMOLA_SEGMENTS = 8        # two worms of four (ten of five each in the original)
GANON_IMAGES = 10            # GanonFrameImages names ten 16x16 pictures (heap entries 0-9 of its animation) and the ashes (11)
GANON_ASHES = 11
GANON_COLOURINGS = (        # blue and brown, as the ROM recolours palette row 7 by transfer records ($16 $2C $3C, $07 $17 $30): the
    ((6, 1), (5, 2), (5, 3)),   # nearest colours of Level 9's own sprite rows (row, pixel): red, blue, white
    ((6, 1), (4, 3), (5, 3)),   # brown $07 $17 $30: the level has no $07, so red $16 stands in for it, then brown $17 and white
)
GANON_RAYS = (              # GanonBurstDirs / GanonBurstTiles / GanonBurstSpriteAttrs, by ray: right, left, down, down-right,
    (0xEE, True, False), (0xEE, False, False), (0xE8, False, True), (0x30, True, True),     # down-left, up, up-right, up-left
    (0x30, False, True), (0xE8, False, False), (0x30, True, False), (0x30, False, False))
GANON_ASH_COLOURS = ((4, 2), (4, 3), (6, 1))      # the triforce colours $27 $06 $16: orange, brown for the dark red, red
PATRA_CHILDREN = 7          # eight in the original, which has ten object slots; here the eye and seven
PATRA_CHILD_OF = {0x47: 0x25, 0x48: 0x26}      # InitPatra: type $47 goes with child $25, $48 with $26
MOLDORM_SEGMENTS = 8        # two worms of four (the original has five each, but there are only eight monster slots)
MONSTER_IMAGES = 4          # image slots of an ordinary monster, each stored plain and flipped
OCTOROK_IMAGES = 6          # side, front and back, in two animation sets (mon_art says where each art starts)
# Octorok frames in ObjAnimFrameHeap order: side, back, front for set one, then the same for set two. The back
# is the front turned upside down (attribute bit 7); the game draws sideways ones plain and mirrors the others.
OCTOROK_FRAME_ORDER = (0, 3, 2, 5, 1, 4)    # image 0 side A, 1 side B, 2 front A, 3 front B, 4 back A, 5 back B
FRAME_BYTES = B.SPRITE_FRAME_BYTES
NO_DROP_ROW = 0xFF
ROOM_INFO_BYTES = 16
NO_PERSON = 0xFFFF            # a record's last word: where the room's old man starts speaking in the cave text
PERSON_LIST_FIRST = 0x4B      # Person1..Person8 in the monster lists
PERSON_LIST_LAST = 0x52
PERSON_MORE_BOMBS = 0x4F      # in the dungeons whose people are table A this one and the next do more than talk
PERSON_LIFE_OR_MONEY = 0x51
LIFE_OR_MONEY_SELECTOR = 0x36
PERSON_KIND_BOMBS = 1          # record byte 13: sells room for four more bombs for 100 rupees
PERSON_KIND_MONEY = 2          # a heart container or 50 rupees
RUPEE_STASH = 0x35           # ten rupees on the floor (trigger bit 6)
GRUMBLE = 0x36               # the moblin who wants food (trigger bit 5); his text is selector $24
GRUMBLE_SELECTOR = 0x24
# CurLevel -> which of the two selector tables (InitUnderworldPerson_Full_JumpTable); 9 has a third
PERSON_SELECTOR_LABELS = {1: "A", 2: "A", 3: "B", 4: "B", 5: "A", 6: "B", 7: "A", 8: "B", 9: "C"}

# 0x3F is not an item: it is Link with both arms up (tile $78, a mirrored pair, from
# Anim_ItemFrameTiles) that DrawLinkLiftingItem shows while he holds the triforce piece.
LINK_LIFT_ID = 0x3F
LINK_LIFT_TILE = 0x78
ITEM_COUNT = 0x24             # every item id of the game: bombs to the fairy
ITEM_IDS = tuple(range(ITEM_COUNT)) + (LINK_LIFT_ID,)
BOOMERANG_ITEM = 0x1D
POWER_TRIFORCE_ID = 0x0E
TRIFORCE_PIECE = 0x1B          # a level's triforce piece
FIRE_ANIM_INDEX = 0x41
# The status bar and inventory pictures, two 8x8 tiles each. menu.s and hud.s index them: 0-3 are the B item codes
# of the first four B items (sword, bomb, boomerang, candle), then compass, map and bow, then the rest.
HUD_ITEM_IDS = (0x01, 0x00, BOOMERANG_ITEM, 0x06, 0x16, 0x17, 0x0A,
                0x05, 0x04, 0x1F, 0x20, 0x10,         # 7 recorder, 8 food, 9 blue potion, 10 red potion, 11 rod
                0x1E, 0x07, 0x02, 0x03,               # 12 magic boomerang, 13 red candle, 14 white sword, 15 magic sword
                0x08, 0x09, 0x0C, 0x11, 0x12, 0x13,   # 16 arrow, 17 silver arrow, 18 raft, 19 book, 20 blue ring, 21 red ring
                0x0D, 0x0B, 0x14, 0x1C, 0x15)         # 22 ladder, 23 magic key, 24 bracelet, 25 magic shield, 26 letter

UW_SP_COMMON = "dat/CommonSpritePatterns.dat"
UW_SP_DEMO = "dat/DemoSpritePatterns.dat"
UW_SP_DEMO_FIRST = 0x70
UW_SP_BLOCK = ("dat/PatternBlockUWSP.dat", 0x8E)
# LevelPatternBlockSrcAddrs and BossPatternBlockSrcAddrs (Z_03): the sprite patterns each dungeon adds at tile $9E and $C0.
# The names say which levels share a block: 127 is Levels 1, 2 and 7, 358 is 3, 5 and 8, 469 is 4, 6 and 9.
UW_SP_LEVEL_BLOCKS = {1: "dat/PatternBlockUWSP127.dat", 2: "dat/PatternBlockUWSP127.dat",
                      3: "dat/PatternBlockUWSP358.dat", 4: "dat/PatternBlockUWSP469.dat",
                      5: "dat/PatternBlockUWSP358.dat", 6: "dat/PatternBlockUWSP469.dat",
                      7: "dat/PatternBlockUWSP127.dat", 8: "dat/PatternBlockUWSP358.dat",
                      9: "dat/PatternBlockUWSP469.dat"}
UW_SP_LEVEL_FIRST = 0x9E
UW_SP_BOSS_BLOCKS = {1: "dat/PatternBlockUWSPBoss1257.dat", 2: "dat/PatternBlockUWSPBoss1257.dat",
                     3: "dat/PatternBlockUWSPBoss3468.dat", 4: "dat/PatternBlockUWSPBoss3468.dat",
                     5: "dat/PatternBlockUWSPBoss1257.dat", 6: "dat/PatternBlockUWSPBoss3468.dat",
                     7: "dat/PatternBlockUWSPBoss1257.dat", 8: "dat/PatternBlockUWSPBoss3468.dat",
                     9: "dat/PatternBlockUWSPBoss9.dat"}
UW_SP_BOSS_FIRST = 0xC0


@dataclass(frozen=True)
class ActorData:
    mon_sprites: bytes        # monster, frame, flip -> one masked 16x16 frame
    mon_table: bytes          # 8 bytes per monster: type, hp, period, damage, drop row, flies, draw mode, behaviour
    mon_art: bytes            # per monster, a big-endian word: the number of its first frame in mon_sprites
    mon_index: bytes          # NES object type -> monster index, 0xFF for none
    item_sprites: bytes       # one masked 16x16 frame per item
    item_index: bytes         # item id (0..63) -> item index, 0xFF for none
    drop_table: bytes
    drop_rates: bytes
    sword_sprites: bytes      # up, down, left, right for the wooden, white and magic sword, then the rod
    beam_sprites: bytes       # the sword's shot: up, down, left, right, each in four palette rows
    fx_sprites: bytes         # two bomb clouds, four spark corners in four palette rows each, two fires, a third cloud
    proj_sprites: bytes       # 8 boomerang turns and a spark, 4 fireball frames (the 4 sprite palettes), then 4 pieces for each Aquamentus image
    hud_items: bytes          # sword, bomb, boomerang, candle, compass, map, bow as two status bar tiles each, top then bottom
    room_info: list[bytes]    # ROOM_INFO_BYTES per stored room
    keese_index: int = 0      # monster index of the keese the cellars are full of
    item_slot: bytes = b""    # ItemIdToSlot: the Items byte an item id goes into
    item_desc: bytes = b""    # ItemIdToDescriptor: class in the high nibble (0 own, 1 amount, 2 grade), value in the low
    person_text: bytes = b""  # the speeches of the level's dungeon people, appended to the first cave's text
    mon_mask: bytes = b""     # per monster, which weapons hurt it (MONSTER_HURT)
    monster_arts: tuple = ()  # per monster index, the frames of its art (what mon_art points at in mon_sprites)
    mon_cloud: bytes = b""    # per monster: 0 appears at once, 1 comes out of a spawn cloud, 2 out of a long one (octoroks)


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


class _RemappedPalette:
    """A palette whose colours 1-3 are other entries of the real one, for art the ROM recolours while it plays."""

    def __init__(self, palette, colours):
        self.palette = palette
        self.colours = colours

    def index(self, row: int, pixel: int) -> int:
        source_row, source_pixel = self.colours[pixel - 1]
        return self.palette.index(source_row, source_pixel)


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
    if layout == "left":
        return [r[:8] + [-1] * 8 for r in left]
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
SPAWN_CLOUD_LAST_TILE = 0x74    # the bomb item's frame 3: the spawn cloud runs through $70, $72 and $74
SPARK_CORNER_FLIPS = (("h",), ("h", "v"), ("v",), ())    # SwordShotSpreadBaseAttr, by loop index


def _flip_rows(rows: list[list[int]], h: bool, v: bool) -> list[list[int]]:
    if v:
        rows = rows[::-1]
    return [r[::-1] for r in rows] if h else rows


def _weapon_rows(sp_tiles, bg_tiles, palette, direction: str, row: int,
                 tiles: tuple[int, int] = (SWORD_TILE_VERTICAL, SWORD_TILE_HORIZONTAL)) -> list[list[int]]:
    """The sword (and the shot that copies it) for one direction, as UpdateSwordOrRod flips it."""
    vertical = direction in ("up", "down")
    tile = tiles[0] if vertical else tiles[1]
    rows = _item_rows(sp_tiles, bg_tiles, palette, tile, row)
    return _flip_rows(rows, h=direction == "left", v=direction == "down")


WEAPON_DIRECTIONS = ("up", "down", "left", "right")
ROD_TILES = (0x4A, 0x8A)          # the rod's two pictures, Anim_ItemFrameTiles from Anim_ItemFrameOffsets[8]
SWORD_SETS = 4                    # wooden, white and magic sword, then the rod


def _sword_frames(sp_tiles, bg_tiles, palette) -> bytes:
    """Link's sword facing up, down, left, right: one set a grade (the palette row is the grade - 1, as
    UpdateSwordOrRod adds it), then the magic rod (its base attribute with bit 0 set: row 5)."""
    rows = [(B.LINK_PALETTE_ROW, None), (B.LINK_PALETTE_ROW + 1, None), (B.LINK_PALETTE_ROW + 2, None),
            (B.LINK_PALETTE_ROW + 1, ROD_TILES)]

    def frame(row, tiles, d):
        # The swords keep the ROM's colours: the white one and the magic one have a white blade. What kept it in view on a real
        # screen was the overworld's ground, which build_assets.OW_GROUND_ST makes a little darker.
        return _pack_masked(_weapon_rows(sp_tiles, bg_tiles, palette, d, row, tiles or (SWORD_TILE_VERTICAL, SWORD_TILE_HORIZONTAL)))

    return b"".join(frame(row, tiles, d) for row, tiles in rows for d in WEAPON_DIRECTIONS)


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
    """Two bomb clouds, four spark corners in four palette rows each, the candle fire and its mirror, then the third
    picture of the spawn cloud (the first two are the bomb's)."""
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
    frames.append(_pack_masked(_item_rows(sp_tiles, bg_tiles, palette, SPAWN_CLOUD_LAST_TILE, B.LINK_PALETTE_ROW + 1)))
    return b"".join(frames)


def _octorok_images(tiles, palette, anim_base: int, heap, attr_heap) -> list[list[list[int]]]:
    """The six octorok images in the order the draw code uses: side A and B, front A and B, back A and B."""
    images = []
    for frame in OCTOROK_FRAME_ORDER:
        tile = heap[anim_base + frame]
        attr = attr_heap[anim_base + frame]
        row = B.LINK_PALETTE_ROW + (attr & 3)
        layout = "wide" if frame in (0, 3) else "mirror"
        rows = _monster_image(tiles, palette, row, tile, layout)
        if attr & 0x80:
            rows = rows[::-1]           # the back view is the front turned upside down
        images.append(rows)
    return images


GLEEOK_BODY_TILES = ((0xC0, 0xC4, 0xC8, 0xC2, 0xC6, 0xCA), (0xCC, 0xC4, 0xCE, 0xC2, 0xC6, 0xD0),
                     (0xD2, 0xD6, 0xD8, 0xD4, 0xC6, 0xD0))     # GleeokBodyTiles0..2: three columns, two rows
GLEEOK_NECK_TILE = 0xDA
GLEEOK_SEGMENT_IMAGE = 12     # the images after the body's twelve pieces: a neck segment and a head
GLEEOK_HEAD_IMAGE = 13
GLEEOK_HEAD_TILE = 0xDC
LANMOLA_HEAD_TILE = 0x9E     # UpdateLamnola: the head is tile $9E, a body segment $A0, in sprite palette row 2 (blue) or 1 (red)
LANMOLA_BODY_TILE = 0xA0


def _gleeok_images(tiles, palette) -> list:
    """The body's three pictures as four 16x16 pieces each (top left, top right, bottom left, bottom right; the body is
    24 wide, so a right piece is half empty), then a neck segment."""
    row = B.LINK_PALETTE_ROW + 3
    images = []
    for picture in GLEEOK_BODY_TILES:
        canvas = _blank(32) + _blank(32)
        for slot, tile in enumerate(picture):
            x, y = (slot % 3) * 8, (slot // 3) * 16
            for dy, pixels in enumerate(_tile_rows(tiles, palette, row, tile)):
                canvas[y + dy][x : x + 8] = pixels
        for top, left in ((0, 0), (0, 16), (16, 0), (16, 16)):
            images.append([canvas[top + r][left : left + 16] for r in range(16)])
    images.append(_monster_image(tiles, palette, row, GLEEOK_NECK_TILE, "left"))
    images.append(_monster_image(tiles, palette, row, GLEEOK_HEAD_TILE, "left"))
    return images


def _preshift_narrow(rows: list[list[int]]) -> bytes:
    """The left eight columns of a 16x16 image, shifted right by every 0..15 pixels and cut at the 16-pixel groups it
    lands on: per shift 16 rows of two groups, each four plane words and the inverted mask (20 bytes a row, 5120 bytes a
    shift table). The blitter then needs no shifting at all, which is what lets four necks and heads fit a frame."""
    out = bytearray()
    for shift in range(16):
        for row in rows:
            line = [-1] * 32
            line[shift : shift + 8] = row[:8]
            for group in (line[:16], line[16:]):
                out.extend(B.pack_st_row(max(p, 0) for p in group))
                mask = 0
                for x, pixel in enumerate(group):
                    if pixel >= 0:
                        mask |= 1 << (15 - x)
                out.extend((~mask & 0xFFFF).to_bytes(2, "big"))
    return bytes(out)


def _manhandla_images(tiles, palette, base, heap, attr_heap, layouts) -> list:
    """Frames 0-5 of Manhandla's animation (hand up, hand to the side, the body, two each), then the up hand turned
    over for the hand below."""
    images = []
    for frame in range(6):
        row = B.LINK_PALETTE_ROW + (attr_heap[base + frame] & 3)
        images.append(_monster_image(tiles, palette, row, heap[base + frame], layouts[frame]))
    images.extend(images[0:2][i][::-1] for i in range(2))
    return images


def build_actors(source_root: Path, level: int, bg_tiles, palette, room_ids, attrs, info, ow_sp_tiles=None,
                 text_base: int | None = None) -> ActorData:
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

    person_blob, person_offsets = dungeon_people(
        source_root, level, room_ids, attrs, B.PERSON_TEXT_BYTES if text_base is None else text_base)

    sp_tiles = _sprite_table(source_root, level)
    sprites = bytearray()
    arts: dict[bytes, int] = {}         # identical art (the slow and fast octorok) is stored once
    mon_art = bytearray()
    monster_arts: list[bytes] = []
    table = bytearray()
    hurt = bytearray()
    mon_index = bytearray([0xFF]) * 256
    for index, nes_type in enumerate(MONSTER_TYPES):
        mon_index[nes_type] = index
        if nes_type in SYNTHETIC_TYPES:
            source, first = SYNTHETIC_TYPES[nes_type]
            base = anim[source + 1] + first
        else:
            base = anim[nes_type + 1]
        layout, image_count, mode = MONSTER_DRAW[nes_type]
        tiles = sp_tiles
        if nes_type in OVERWORLD_ART:
            if ow_sp_tiles is None:
                raise SystemExit("The overworld sprite patterns are needed to draw the overworld monsters")
            tiles = ow_sp_tiles
        if mode == MODE_OCTOROK:
            images = _octorok_images(tiles, palette, base, heap, attr_heap)
        elif mode == MODE_MANHANDLA:
            images = _manhandla_images(tiles, palette, base, heap, attr_heap, layout)
        elif mode == MODE_GLEEOK:
            images = _gleeok_images(tiles, _FixedPalette(GLEEOK_SLOTS))
        elif nes_type == 0xF9:
            images = [_monster_image(tiles, _FixedPalette(GLEEOK_SLOTS), B.LINK_PALETTE_ROW + 3, GLEEOK_HEAD_TILE, "left")]
        elif mode == MODE_FAIRY:
            images = [_monster_image(tiles, palette, B.LINK_PALETTE_ROW + 2, tile, "narrow") for tile in FAIRY_TILES]
        elif mode == MODE_GANON:
            if level != 9:
                images = [_blank(16)]            # only Level 9 has him; the others' tiles at $C0 are other bosses' art
            else:
                images = []
                for colours in GANON_COLOURINGS:
                    view = _RemappedPalette(palette, colours)
                    for part in range(GANON_IMAGES):
                        images.append(_monster_image(tiles, view, B.LINK_PALETTE_ROW + 3, heap[base + part], "wide"))
                view = _RemappedPalette(palette, GANON_ASH_COLOURS)
                images.append(_monster_image(tiles, view, B.LINK_PALETTE_ROW + 3, heap[base + GANON_ASHES], "wide"))
                # The burst Ganon_DrawBurst makes at his death: the two clouds (heap entries 12 and 13, sprite row 3, which
                # the ROM has just recoloured to the triforce colours), then each of the eight rays in the four palette
                # rows its attributes cycle through (the flash). Image 23 + 4 * ray + step; the pool picture is
                # BP_GANON + 2 * image, since every image is stored plain and mirrored (the mirror is not used).
                for tile in (heap[base + 12], heap[base + 13]):
                    images.append(_monster_image(tiles, view, B.LINK_PALETTE_ROW + 3, tile, "mirror"))
                for tile, h, v in GANON_RAYS:
                    for step in range(4):
                        ray_view = view if step == 3 else palette           # row 7 is the ashes' by then
                        rows = _monster_image(tiles, ray_view, B.LINK_PALETTE_ROW + step, tile, "left")
                        if h:
                            rows = [r[7::-1] + r[8:] for r in rows]
                        images.append(_flip_rows(rows, False, v))
        elif mode == MODE_LANMOLA:
            row = B.LINK_PALETTE_ROW + (2 if nes_type == 0x3A else 1)
            images = [_monster_image(tiles, palette, row, LANMOLA_HEAD_TILE, "narrow"),
                      _monster_image(tiles, palette, row, LANMOLA_BODY_TILE, "narrow")]
        elif mode == MODE_DIGBIG:
            # one picture, put four times in the corners: plain, flipped right-left, upside down, both (the part
            # attributes $03, $03, $83, $83 and the horizontal flip of the odd parts)
            row = B.LINK_PALETTE_ROW + MONSTER_TILE_ROW[nes_type][1]
            view = _RemappedPalette(palette, ORANGE_BOSS_COLOURS) if row == B.LINK_PALETTE_ROW + 3 else palette
            plain = _monster_image(tiles, view, row, heap[base], "wide")
            images = [plain, _flip_rows(plain, True, False), _flip_rows(plain, False, True), _flip_rows(plain, True, True)]
        else:
            images = []
            for image in range(image_count if mode in FRAME_MODES else MONSTER_IMAGES):
                frame = (image & 1) if mode == MODE_ROPE else min(image, image_count - 1)
                tile = heap[base + (0 if mode == MODE_BUBBLE else frame)]
                row = B.LINK_PALETTE_ROW + (image if mode == MODE_BUBBLE else image >> 1 if mode == MODE_ROPE
                                            else attr_heap[base + frame] & 3)
                if nes_type in MONSTER_TILE_ROW:
                    override_tile, override_row = MONSTER_TILE_ROW[nes_type]
                    tile = tile if override_tile is None else override_tile
                    row = B.LINK_PALETTE_ROW + override_row
                view = palette
                if nes_type in ORANGE_BOSS_TYPES and row == B.LINK_PALETTE_ROW + 3:
                    view = _RemappedPalette(palette, ORANGE_BOSS_COLOURS)
                if nes_type in GLEEOK_TYPES and row == B.LINK_PALETTE_ROW + 3:
                    view = _FixedPalette(GLEEOK_SLOTS)
                image_layout = layout[frame] if isinstance(layout, tuple) else layout
                if mode == MODE_DODONGO and image in DODONGO_MIRRORED_IMAGES:
                    image_layout = "mirror"
                if mode == MODE_BOSS:
                    images.append(_blank(16))
                elif mode == MODE_WALLMASTER and frame == 1:
                    # The closed hand reuses Keese art on the left; the game patches it to the open hand's.
                    left = _tile_rows(tiles, palette, row, heap[base])
                    right = _tile_rows(tiles, palette, row, tile + 2)
                    images.append(_join(left, right))
                else:
                    images.append(_monster_image(tiles, view, row, tile, image_layout))
        art = bytearray()
        for rows in images:
            art.extend(_pack_masked(rows))
            art.extend(_pack_masked([r[::-1] for r in rows]))
        if mode == MODE_GLEEOK:
            art.extend(_preshift_narrow(images[GLEEOK_SEGMENT_IMAGE]))     # frames 28..59 and 60..91
            art.extend(_preshift_narrow(images[GLEEOK_HEAD_IMAGE]))
        key = bytes(art)
        monster_arts.append(key)
        if key not in arts:
            arts[key] = len(sprites) // FRAME_BYTES
            sprites.extend(art)
        mon_art.extend(arts[key].to_bytes(2, "big"))
        hp = 0
        if nes_type in SYNTHETIC_HP:
            hp = SYNTHETIC_HP[nes_type]
        elif nes_type not in SYNTHETIC_TYPES:
            hp_byte = hp_pairs[nes_type >> 1]
            hp = (hp_byte >> 4) if nes_type % 2 == 0 else (hp_byte & 0x0F)
        drop_row = NO_DROP_ROW
        if nes_type not in no_drop and nes_type not in SYNTHETIC_TYPES and nes_type not in NO_DROP_BOSSES:
            drop_row = 3
            for row_number, members in enumerate(drop_types):
                if nes_type in members:
                    drop_row = row_number
                    break
        table.extend((nes_type, hp, MONSTER_PERIOD[nes_type], MONSTER_DAMAGE[nes_type],
                      drop_row, 1 if nes_type in MONSTER_FLYERS else 0, mode,
                      MONSTER_BEHAVIOUR.get(nes_type, BEHAVIOUR_WANDER)))
        hurt.append(MONSTER_HURT.get(nes_type, HURT_ALL))

    item_index = bytearray([0xFF]) * 64
    items = bytearray()
    for index, item_id in enumerate(ITEM_IDS):
        item_index[item_id] = index
        if item_id == LINK_LIFT_ID:
            items.extend(_pack_masked(_item_rows(sp_tiles, bg_tiles, palette, LINK_LIFT_TILE, B.LINK_PALETTE_ROW)))
        else:
            # The Triforce of Power is drawn with two of the boss block's tiles, and that block is Level 9's own: the
            # item pictures are baked once, from Level 1's table, so this one comes from Level 9's.
            tiles = _sprite_table(source_root, 9) if item_id == POWER_TRIFORCE_ID else sp_tiles
            items.extend(_item_frame(code, tiles, bg_tiles, palette, item_id))

    foe_counts = list(info[B.LEVEL_INFO_FOE_COUNTS : B.LEVEL_INFO_FOE_COUNTS + 4])
    lists = overworld_monster_lists(source_root)
    return ActorData(
        mon_sprites=bytes(sprites),
        mon_table=bytes(table),
        mon_mask=bytes(hurt),
        mon_art=bytes(mon_art),
        mon_cloud=monster_cloud_table(source_root),
        mon_index=bytes(mon_index),
        item_sprites=bytes(items),
        item_index=bytes(item_index),
        drop_table=bytes(drop_table),
        drop_rates=bytes(drop_rates),
        sword_sprites=_sword_frames(sp_tiles, bg_tiles, palette),
        beam_sprites=_beam_frames(sp_tiles, bg_tiles, palette),
        fx_sprites=_effect_frames(sp_tiles, bg_tiles, palette, _fire_rows(anim, heap, attr_heap, sp_tiles, palette)),
        proj_sprites=_projectile_sprites(code, sp_tiles, bg_tiles, palette, ow_sp_tiles or sp_tiles, heap, attr_heap, anim),
        hud_items=_hud_items(code, sp_tiles, bg_tiles, palette),
        room_info=[_room_info(r, attrs, foe_counts, info, person_offsets.get(r, NO_PERSON), lists, level) for r in room_ids],
        person_text=person_blob,
        monster_arts=tuple(monster_arts),
        keese_index=MONSTER_TYPES.index(0x1B),
        item_slot=bytes(code["slot"][:ITEM_COUNT]),
        item_desc=bytes(code["descriptor"][:ITEM_COUNT]),
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


ROCK_TYPE = 0x53            # the octorok's flying rock
FIREBALL_TYPE = 0x55        # Aquamentus' and the zora's fireball (type $56 is the unblockable one, drawn the same)
FIREBALL_FRAMES = 4         # one per sprite palette
ARROW_SLOT = 2              # the item slot of the arrow (Anim_ItemFrameOffsets)
MONSTER_ARROW_ROW = 2       # a monster's arrow adds 2 to the base attribute: palette row 6


def _rock_frame(heap, attr_heap, anim, ow_sp_tiles, palette) -> bytes:
    """The flying rock: image 0 of its animation, always palette row 0, drawn four pixels in (8 wide)."""
    base = anim[ROCK_TYPE + 1]
    rows = _monster_image(ow_sp_tiles, palette, B.LINK_PALETTE_ROW, heap[base], "narrow")
    return _pack_masked(rows)


def _arrow_frames(code, sp_tiles, bg_tiles, palette) -> bytes:
    """A monster's arrow flying up, down, left and right (frame 0 is vertical, frame 1 sideways)."""
    first = code["offsets"][ARROW_SLOT]
    row = B.LINK_PALETTE_ROW + MONSTER_ARROW_ROW
    frames = []
    for direction in WEAPON_DIRECTIONS:
        tile = code["tiles"][first + (0 if direction in ("up", "down") else 1)]
        rows = _item_rows(sp_tiles, bg_tiles, palette, tile, row)
        frames.append(_pack_masked(_flip_rows(rows, h=direction == "left", v=direction == "down")))
    return b"".join(frames)


def _projectile_sprites(code, sp_tiles, bg_tiles, palette, ow_sp_tiles, heap, attr_heap, anim) -> bytes:
    """Eight boomerang images and its spark, the fireball in the four sprite palettes, the Aquamentus pieces, a rock, four arrows."""
    frames = _boomerang_frames(code, sp_tiles, bg_tiles, palette)
    # L_DrawShot: the fireball (type $55, half-width: ObjectTypeToAttributes $E3) is image 0 of its animation, and its
    # sprite attributes are FrameCounter & 3, so it flashes through the four sprite palettes, one a frame.
    tile = heap[anim[FIREBALL_TYPE + 1]]
    for phase in range(FIREBALL_FRAMES):
        rows = _monster_image(sp_tiles, palette, B.LINK_PALETTE_ROW + phase, tile, "narrow")
        frames.append(_pack_masked(rows))
    return (b"".join(frames) + b"".join(_boss_pieces(sp_tiles, palette))
            + _rock_frame(heap, attr_heap, anim, ow_sp_tiles, palette)
            + _arrow_frames(code, sp_tiles, bg_tiles, palette))


def dungeon_people(source_root: Path, level: int, room_ids, attrs, first_text_bytes: int):
    """The speeches of the old men (and women) a level's rooms hold.

    Returns (blob, {room: offset}): the offsets count from the start of the cave text, which the blob
    is appended to, so cave_talk can type them out as it does the first cave's. Selectors come from
    UnderworldPersonTextSelectorsA/B and index PersonTextAddrs; the two people that do more than
    talk are left out.
    """
    label = PERSON_SELECTOR_LABELS.get(level)
    if label is None:
        return b"", {}
    asm = (source_root / "src" / "Z_01.asm").read_text(encoding="utf-8", errors="replace")
    selectors = B.parse_asm_byte_table(asm, f"UnderworldPersonTextSelectors{label}")
    texts = B.require_binary(source_root, B.PERSON_TEXT_NAME)
    addrs_inc = (source_root / "src" / "dat" / "PersonTextAddrs.inc").read_text(encoding="utf-8", errors="replace")
    starts = [int(m) for m in re.findall(r"PersonText\+(\d+)", addrs_inc)]
    attr_c, attr_d = attrs[0], attrs[1]
    blob = bytearray()
    offsets: dict[int, int] = {}
    placed: dict[int, int] = {}
    for room in room_ids:
        list_id = (attr_c[room] & 0x3F) | (0x40 if attr_d[room] & 0x80 else 0)
        if list_id == GRUMBLE:
            selector = GRUMBLE_SELECTOR
        else:
            if not PERSON_LIST_FIRST <= list_id <= PERSON_LIST_LAST:
                continue
            if list_id == PERSON_LIFE_OR_MONEY:
                selector = LIFE_OR_MONEY_SELECTOR       # InitUnderworldPersonLifeOrMoney_Full: the same words in every level
            else:
                selector = selectors[list_id - PERSON_LIST_FIRST]
        if selector not in placed:
            entry = selector // 2
            end = starts[entry + 1] if entry + 1 < len(starts) else len(texts)
            placed[selector] = first_text_bytes + len(blob)
            blob.extend(texts[starts[entry] : end])
        offsets[room] = placed[selector]
    if first_text_bytes + len(blob) > 0xFFFE:
        raise SystemExit("The dungeon people's speeches no longer fit the text index")
    return bytes(blob), offsets


def _room_info(room: int, attrs, foe_counts, info, person: int = NO_PERSON, lists=(), level: int = 0) -> bytes:
    """count, secret trigger (bit 7: the room has a push block, 6 a rupee stash, 5 Grumble, 4 the man at Level 9's door), item id, item X, item Y,
    unsupported (bit 7: a dark room, bits 5-6: which boss roar the room can hear, attribute E's sound index),
    eight monsters, then where the person's speech starts in the cave text (0xFF: nobody talks here)."""
    attr_c, attr_d, attr_e, attr_f = attrs
    list_id = (attr_c[room] & 0x3F) | (0x40 if attr_d[room] & 0x80 else 0)
    count = foe_counts[attr_c[room] >> 6]
    if 0x32 <= list_id < 0x62:
        count = 1
    types = [list_id] * count if 0 < list_id < 0x62 else []
    if list_id >= 0x62 and list_id - 0x62 < len(lists):
        types = [t for t in listed_types(lists, list_id, count) if t]     # a mixed group; empty slots belong to the traps
    expanded = []
    for t in types:
        if t in (0x49, 0x4A):
            expanded.extend([0x49] * (6 if t == 0x49 else 4))       # InitTrap_Full makes six or four traps
        elif t == 0x41:
            expanded.append(0x41)
        elif t in (0x3A, 0x3B):
            expanded.append(t)
        elif t == 0x39:
            expanded.append(0xFB)                                  # InitDigdogger2: a big one with one child
        else:
            expanded.append(t)
    types = expanded
    if types.count(0x41) == 1:
        types = [t for t in types if t != 0x41] + [0x41] * MOLDORM_SEGMENTS   # InitMoldorm makes the worms' segments
    if types == [0x37]:
        types = [0x37] + [0x3F] * 4                       # InitZelda: Zelda and the four fires that guard her
    if len(types) == 1 and types[0] in PATRA_CHILD_OF:
        types = types + [PATRA_CHILD_OF[types[0]]] * PATRA_CHILDREN
    if len(types) == 1 and types[0] in (0x3A, 0x3B):
        types = types * LANMOLA_SEGMENTS                  # InitLamnola makes two worms (here of four segments each)
    monsters = [MONSTER_TYPES.index(t) for t in types if t in MONSTER_TYPES][:8]
    # CheckHasLivingMonsters ignores bubbles ($2B-$2D) and everything from $49 up,
    # which includes the traps; any other monster has to be killed before the room clears.
    unsupported = sum(
        1 for t in types if t not in MONSTER_TYPES and not (0x2B <= t <= 0x2D) and t < 0x49
        and t not in (RUPEE_STASH, GRUMBLE)
    )

    item = attr_e[room] & 0x1F
    positions = info[B.LEVEL_INFO_ITEM_POSITIONS : B.LEVEL_INFO_ITEM_POSITIONS + 4]
    pos = positions[(attr_f[room] & 0x30) >> 4]
    item_id = 0xFF if item == 3 else item
    # FindAndCreatePushBlockObject runs for every room whose attribute D has $40, whatever its secret trigger
    trigger = (attr_f[room] & 7) | (0x80 if attr_d[room] & 0x40 else 0)
    if 0x3E in types:
        trigger = (trigger & ~7) | 7        # Ganon's room item stays hidden until he is ashes (Ganon_ActivateRoomItem)
    trigger |= (0x40 if RUPEE_STASH in types else 0) | (0x20 if GRUMBLE in types else 0)   # not monsters: the room's own things
    if level == 9 and list_id == PERSON_LIST_FIRST:
        trigger |= 0x10                                 # the man who lets Link in once he holds all eight pieces
    dark = 0x80 if attr_e[room] & 0x80 else 0           # attribute E bit 7: a dark room (until the candle is lit)
    roar = (attr_e[room] >> 5) & 3                      # CheckBossSoundEffectUW: 0 none, 1 $10, 2 $20, 3 $40
    if unsupported > 0x1F:
        raise SystemExit(f"room {room:#x}: {unsupported} unsupported monsters leave no room for the roar bits")
    item_x = (pos & 0xF0) - (8 if item_id == TRIFORCE_PIECE else 0)   # the ROM moves a triforce piece 8 pixels left (@StoreLocation), onto the room's middle
    record = bytearray([len(monsters), trigger, item_id, item_x, (pos & 0x0F) << 4, unsupported | roar << 5 | dark])
    record.extend(monsters)
    record.extend([0xFF] * (ROOM_INFO_BYTES - 2 - len(record)))
    if person != NO_PERSON and not monsters:
        # the people that do more than talk: byte 13, which a room without monsters does not use, says which
        if list_id == PERSON_LIFE_OR_MONEY:
            record[13] = PERSON_KIND_MONEY
        elif list_id == PERSON_MORE_BOMBS and PERSON_SELECTOR_LABELS.get(level) == "A":
            record[13] = PERSON_KIND_BOMBS
    record.extend(person.to_bytes(2, "big"))
    return bytes(record)


OW_ROOM_INFO_BYTES = 16
OW_ROOM_EDGE_SPAWN = 1         # flags bit 0: the monsters come in from the screen edge (attribute F bit 3)
OW_ROOM_ZORAS = 2              # flags bit 1: a Zora lives in the water (attribute A bit 3)
OW_MAX_MONSTERS = 6            # the biggest foe count of the overworld (LevelInfo foe counts are 1, 4, 5, 6)


SPAWN_CLOUD_NONE, SPAWN_CLOUD_SHORT, SPAWN_CLOUD_LONG = 0, 1, 2
# InitSlowOctorockOrGhini and InitFastOctorock set ObjTimer to (slot + 1) * $10 where the other monsters keep the slot
# number: "Octorock spawn clouds last longer than other monsters".
LONG_CLOUD_INITS = ("InitSlowOctorockOrGhini", "InitFastOctorock")
# InitArmosOrFlyingGhini keeps its own fade-in on ObjTimer and takes the metastate away only after it (it branches to
# L_EndInitFlyingGhini), so it has no spawn cloud either.
OWN_FADE_INITS = ("InitArmosOrFlyingGhini",)
INIT_TABLE_LABEL = "InitObject_JumpTable:"
RESET_METASTATE = ("ResetObjMetastate", "ResetObjMetastateAndTimer")


def _rom_routines(source_root: Path) -> tuple[dict[str, list[str]], dict[str, str | None]]:
    """Every routine of the banks that hold the object initialisers: its lines, and the routine that follows it."""
    routines: dict[str, list[str]] = {}
    order: list[tuple[str, str]] = []
    for name in ("Z_01.asm", "Z_04.asm", "Z_05.asm", "Z_07.asm"):
        current = None
        for line in (source_root / "src" / name).read_text(encoding="utf-8", errors="replace").splitlines():
            code = line.split(";")[0].rstrip()
            label = re.match(r"^(@?[A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", code)
            if label and not label.group(1).startswith("@"):
                current = label.group(1)
                routines.setdefault(current, [])
                order.append((name, current))
                code = label.group(2)
            if current:
                routines[current].append(code)
    following = {n: (order[i + 1][1] if order[i + 1][0] == f else None) for i, (f, n) in enumerate(order[:-1])}
    return routines, following


def _clears_metastate(name: str, routines, following, seen=None) -> bool:
    """Whether an initialiser ends up in ResetObjMetastate: the monster then starts at once, with no spawn cloud
    (InitObject gives every object metastate 1, the first cloud state, and only these initialisers take it away)."""
    seen = set() if seen is None else seen
    if name in seen or name not in routines:
        return False
    seen.add(name)
    if name in RESET_METASTATE:
        return True
    ends = False
    for code in routines[name]:
        call = re.search(r"\b(?:JSR|JMP)\s+(\w+)", code)
        if call and _clears_metastate(call.group(1), routines, following, seen):
            return True
        if re.search(r"\b(?:RTS|RTI|JMP)\b", code) and "JSR" not in code:
            ends = True
    return not ends and following.get(name) is not None and _clears_metastate(following[name], routines, following, seen)


def rom_spawn_clouds(source_root: Path) -> dict[int, int]:
    """NES object type -> SPAWN_CLOUD_*, read from the ROM's InitObject_JumpTable and the routines it names."""
    routines, following = _rom_routines(source_root)
    table = []
    text = (source_root / "src" / "Z_07.asm").read_text(encoding="utf-8", errors="replace").splitlines()
    start = next(i for i, line in enumerate(text) if line.startswith(INIT_TABLE_LABEL))
    for line in text[start + 1 :]:
        match = re.match(r"\s*\.ADDR (\w+)", line.split(";")[0])
        if not match:
            break
        table.append(match.group(1))
    clouds = {}
    for nes_type, init in enumerate(table):
        if init in OWN_FADE_INITS or _clears_metastate(init, routines, following):
            clouds[nes_type] = SPAWN_CLOUD_NONE
        else:
            clouds[nes_type] = SPAWN_CLOUD_LONG if init in LONG_CLOUD_INITS else SPAWN_CLOUD_SHORT
    return clouds


def monster_cloud_table(source_root: Path) -> bytes:
    """One byte per monster: the spawn cloud it comes out of. Only the overworld puts monsters down in clouds for
    now (the dungeons' monsters appear at once, as they did before), so the other types get 0."""
    clouds = rom_spawn_clouds(source_root)
    return bytes(clouds.get(t, SPAWN_CLOUD_NONE) if t in OVERWORLD_MONSTERS else SPAWN_CLOUD_NONE
                 for t in MONSTER_TYPES)


def overworld_monster_lists(source_root: Path) -> list[list[int]]:
    """ObjLists: the monster types of each list id from $62 up."""
    blob = B.require_binary(source_root, "dat/ObjLists.dat")
    inc = (source_root / "src" / "dat" / "ObjListAddrs.inc").read_text(encoding="utf-8", errors="replace")
    starts = [int(m) for m in re.findall(r"ObjLists\+(\d+)", inc)]
    ends = starts[1:] + [len(blob)]
    return [list(blob[a:b]) for a, b in zip(starts, ends)]


def listed_types(lists: list[list[int]], list_id: int, count: int) -> list[int]:
    """The first `count` bytes of list `list_id` as InitMode_EnterRoom reads them: straight on through ObjLists, so a count longer
    than the list takes the first types of the next one (list $68 has five entries and the screens $38 and $49 want six)."""
    flat = [t for one in lists for t in one]
    start = sum(len(one) for one in lists[:list_id - 0x62])
    return flat[start:start + count]


def overworld_room_types(lists, attr_c: int, attr_d: int, foe_counts) -> list[int]:
    """The NES monster types RoomObjCount x ObjType holds for a screen (before the room history trims them)."""
    list_id = (attr_c & 0x3F) | (0x40 if attr_d & 0x80 else 0)
    count = foe_counts[attr_c >> 6]
    if 0x32 <= list_id < 0x62:
        count = 1                       # bosses and other things that do not come back
    if list_id == 0:
        return []
    if list_id < 0x62:
        return [list_id] * count
    return listed_types(lists, list_id, count)


def overworld_room_info(source_root: Path, attrs_a, attrs_c, attrs_d, attrs_f, foe_counts) -> bytes:
    """128 records of OW_ROOM_INFO_BYTES: count, flags, then the monster indices from byte 6 (as uw_room_info).

    Only the types this port can draw and move are kept; armos, gravestones and flying ghinis are left out
    until the room-tile patch overlay exists. The count is the foe count the game would place.
    """
    lists = overworld_monster_lists(source_root)
    records = bytearray()
    for room in range(len(attrs_c)):
        types = overworld_room_types(lists, attrs_c[room], attrs_d[room], foe_counts)
        monsters = [MONSTER_TYPES.index(t) for t in types if t in OVERWORLD_LISTED][:OW_MAX_MONSTERS]
        flags = (OW_ROOM_EDGE_SPAWN if attrs_f[room] & 8 else 0) | (OW_ROOM_ZORAS if attrs_a[room] & 8 else 0)
        record = bytearray([len(monsters), flags, 0xFF, 0, 0, 0])
        record.extend(monsters)
        record.extend([0xFF] * (OW_ROOM_INFO_BYTES - len(record)))
        records.extend(record)
    return bytes(records)
