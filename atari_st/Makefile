ROOT_DIR := ..
BUILD_DIR := build
GENERATED_DIR := $(BUILD_DIR)/generated
# The dev-start env vars are baked into assets.inc, so they are an input of the
# asset step: the stamp is rewritten only when they change, which makes make
# regenerate the assets exactly then (in either direction, also back to default).
DEV_STAMP := $(BUILD_DIR)/dev_start.stamp
.DEFAULT_GOAL := all
.PHONY: FORCE_DEV_STAMP
FORCE_DEV_STAMP:

$(DEV_STAMP): FORCE_DEV_STAMP
	@mkdir -p $(BUILD_DIR)
	@printf '%s|%s\n' '$(ZELDA_START_UW)' '$(ZELDA_START_ROOM)' | cmp -s - $@ 2>/dev/null || printf '%s|%s\n' '$(ZELDA_START_UW)' '$(ZELDA_START_ROOM)' > $@
SRC_DIR := src
TOOLS_DIR := tools
ASSET_INPUTS := $(ROOT_DIR)/src/bins.xml $(ROOT_DIR)/src/Z_05.asm $(ROOT_DIR)/src/Z_06.asm \
	$(TOOLS_DIR)/underworld.py $(TOOLS_DIR)/actors.py \
	$(wildcard $(ROOT_DIR)/bin/dat/CommonBackgroundPatterns.dat $(ROOT_DIR)/ext/Original.nes)
TOOLCHAIN_PREFIX ?= m68k-linux-gnu-
AS := $(TOOLCHAIN_PREFIX)as
LD := $(TOOLCHAIN_PREFIX)ld
OBJCOPY := $(TOOLCHAIN_PREFIX)objcopy
PYTHON ?= python3

ASFLAGS := -m68000 -I $(GENERATED_DIR) -I $(SRC_DIR)
LDFLAGS := -T link.ld -nostdlib -e _start

ELF := $(BUILD_DIR)/zelda_st.elf
BIN := $(BUILD_DIR)/zelda_st.bin
PRG := $(BUILD_DIR)/ZELDAST.PRG
OBJ := $(BUILD_DIR)/zelda_st.o
MAIN_SRC := $(SRC_DIR)/main.s
SOURCES := $(wildcard $(SRC_DIR)/*.s)
# main.s .includes the other modules, so one assembler run covers them all.
GENERATED := $(GENERATED_DIR)/assets.inc $(GENERATED_DIR)/metatiles.bin \
	$(GENERATED_DIR)/metatile_tiles.bin $(GENERATED_DIR)/room_maps.bin \
	$(GENERATED_DIR)/link_sprites.bin $(GENERATED_DIR)/hud_tiles.bin \
	$(GENERATED_DIR)/uw_tiles.bin $(GENERATED_DIR)/uw_tile_nes.bin \
	$(GENERATED_DIR)/uw_rooms.bin $(GENERATED_DIR)/uw_room_index.bin \
	$(GENERATED_DIR)/uw_doors.bin $(GENERATED_DIR)/uw_door_cells.bin \
	$(GENERATED_DIR)/mon_sprites.bin $(GENERATED_DIR)/mon_table.bin \
	$(GENERATED_DIR)/mon_index.bin $(GENERATED_DIR)/item_sprites.bin \
	$(GENERATED_DIR)/item_index.bin $(GENERATED_DIR)/drop_table.bin \
	$(GENERATED_DIR)/drop_rates.bin $(GENERATED_DIR)/sword_sprites.bin \
	$(GENERATED_DIR)/proj_sprites.bin $(GENERATED_DIR)/hud_items.bin \
	$(GENERATED_DIR)/beam_sprites.bin $(GENERATED_DIR)/fx_sprites.bin \
	$(GENERATED_DIR)/uw_room_info.bin \
	$(GENERATED_DIR)/asset_manifest.txt
MUSIC_SRC := music/zelda_intro_by_qum.h
MUSIC_PLAYER := music/ymplay.h
MUSIC_GENERATED := $(GENERATED_DIR)/music.inc $(GENERATED_DIR)/music_data.bin \
	$(GENERATED_DIR)/music_drums.bin $(GENERATED_DIR)/music_engine.bin
# The bank the game plays: the shipped overworld song plus every other track ripped from the ROM
# (just the overworld song when there is no ROM or py65).
MUSIC_ROM := $(wildcard $(ROOT_DIR)/ext/Original.nes)
MUSIC_PACKED := $(GENERATED_DIR)/music_bank.bin $(GENERATED_DIR)/music_drum_table.bin \
	$(GENERATED_DIR)/music_ids.inc

.PHONY: all assets check clean run screenshot

all: $(PRG)

assets: $(GENERATED)

$(GENERATED) &: $(TOOLS_DIR)/build_assets.py $(ASSET_INPUTS) $(DEV_STAMP)
	@mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(TOOLS_DIR)/build_assets.py --source-root $(ROOT_DIR) --out-dir $(GENERATED_DIR)

$(MUSIC_GENERATED) &: $(TOOLS_DIR)/ym_convert.py $(MUSIC_SRC) $(MUSIC_PLAYER)
	@mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(TOOLS_DIR)/ym_convert.py --song $(MUSIC_SRC) --player $(MUSIC_PLAYER) --out-dir $(GENERATED_DIR)

$(MUSIC_PACKED) &: $(TOOLS_DIR)/music_pack.py $(TOOLS_DIR)/nes_music_rip.py $(MUSIC_GENERATED) $(MUSIC_ROM)
	$(PYTHON) $(TOOLS_DIR)/music_pack.py $(if $(MUSIC_ROM),--rom $(MUSIC_ROM)) --song-dir $(GENERATED_DIR) --out-dir $(GENERATED_DIR)

$(OBJ): $(SOURCES) $(GENERATED) $(MUSIC_GENERATED) $(MUSIC_PACKED)
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS) -o $@ $(MAIN_SRC)

$(ELF): $(OBJ) link.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJ)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(PRG): $(BIN) $(TOOLS_DIR)/make_prg.py
	$(PYTHON) $(TOOLS_DIR)/make_prg.py $< $@

check: all
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'
	$(PYTHON) $(TOOLS_DIR)/build_assets.py --source-root $(ROOT_DIR) --out-dir $(GENERATED_DIR) --verify-only
	$(PYTHON) $(TOOLS_DIR)/make_prg.py --check $(PRG)

# Headless Hatari run that renders the framebuffer to a PNG. TOS=<path to a
# TOS image> is required; see tools/screenshot.py --help for the other options.
screenshot: all
	$(PYTHON) $(TOOLS_DIR)/screenshot.py --prg $(PRG) --out $(BUILD_DIR)/screen.png

clean:
	rm -rf $(BUILD_DIR)
