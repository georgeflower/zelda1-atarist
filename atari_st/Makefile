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
	@printf '%s|%s|%s|%s|%s|%s|%s\n' '$(ZELDA_START_UW)' '$(ZELDA_START_ROOM)' '$(ZELDA_START_LEVEL)' '$(ZELDA_START_CAVE)' '$(ZELDA_SKIP_INTRO)' '$(ZELDA_QUEST)' '$(ZELDA_AUTOPLAY)' | cmp -s - $@ 2>/dev/null || printf '%s|%s|%s|%s|%s|%s|%s\n' '$(ZELDA_START_UW)' '$(ZELDA_START_ROOM)' '$(ZELDA_START_LEVEL)' '$(ZELDA_START_CAVE)' '$(ZELDA_SKIP_INTRO)' '$(ZELDA_QUEST)' '$(ZELDA_AUTOPLAY)' > $@
SRC_DIR := src
TOOLS_DIR := tools
ASSET_INPUTS := $(ROOT_DIR)/src/bins.xml $(ROOT_DIR)/src/Z_05.asm $(ROOT_DIR)/src/Z_06.asm \
	$(TOOLS_DIR)/underworld.py $(TOOLS_DIR)/actors.py $(TOOLS_DIR)/intro.py $(TOOLS_DIR)/credits.py $(TOOLS_DIR)/filesel.py $(TOOLS_DIR)/gameover.py $(TOOLS_DIR)/submenu.py $(ROOT_DIR)/src/Z_01.asm $(ROOT_DIR)/src/Z_02.asm \
	$(wildcard $(ROOT_DIR)/bin/dat/CommonBackgroundPatterns.dat $(ROOT_DIR)/ext/Original.nes)
TOOLCHAIN_PREFIX ?= m68k-linux-gnu-
AS := $(TOOLCHAIN_PREFIX)as
LD := $(TOOLCHAIN_PREFIX)ld
OBJCOPY := $(TOOLCHAIN_PREFIX)objcopy
NM := $(TOOLCHAIN_PREFIX)nm
PYTHON ?= python3

ASFLAGS := -m68000 -I $(GENERATED_DIR) -I $(SRC_DIR)
LDFLAGS := -T link.ld -nostdlib -e _start

ELF := $(BUILD_DIR)/zelda_st.elf
BIN := $(BUILD_DIR)/zelda_st.bin
PRG := $(BUILD_DIR)/ZELDAST.PRG
OBJ := $(BUILD_DIR)/zelda_st.o
LISTING := $(BUILD_DIR)/zelda_st.lst
# The dungeons the assets are built for (tools/build_assets.py UW_LEVELS says the same) and the tables each has.
UW_LEVELS := 1 2 3 4 5 6 7 8 9
UW_KEYS := $(UW_LEVELS) $(addsuffix q2,$(UW_LEVELS))
UW_LEVEL_TABLES := room_index rooms doors tiles tile_nes room_info cellar_maps cellar_info mon_art quads
# What the game reads from disk for a dungeon: LEVEL<n>.DAT (First Quest) and LEVEL<n>Q.DAT (Second Quest), kept next to the PRG.
LEVEL_FILES := $(foreach l,$(UW_LEVELS),LEVEL$(l).DAT LEVEL$(l)Q.DAT)
# What the program reads from beside itself: the dungeons' files and INTRO.DAT (the title, story, credits and file menu).
DATA_FILES := INTRO.DAT $(LEVEL_FILES)
MAIN_SRC := $(SRC_DIR)/main.s
SOURCES := $(wildcard $(SRC_DIR)/*.s)
# main.s .includes the other modules, so one assembler run covers them all.
GENERATED := $(GENERATED_DIR)/assets.inc $(GENERATED_DIR)/metatiles.bin \
	$(GENERATED_DIR)/metatile_tiles.bin $(GENERATED_DIR)/room_maps.bin \
	$(GENERATED_DIR)/link_sprites.bin $(GENERATED_DIR)/hud_tiles.bin \
	$(foreach l,$(UW_KEYS),$(foreach t,$(UW_LEVEL_TABLES),$(GENERATED_DIR)/uw$(l)_$(t).bin)) \
	$(GENERATED_DIR)/levels.inc $(GENERATED_DIR)/level_buffer.inc $(addprefix $(GENERATED_DIR)/,$(DATA_FILES)) $(GENERATED_DIR)/uw_door_cells.bin \
	$(GENERATED_DIR)/mon_sprites.bin $(GENERATED_DIR)/mon_table.bin $(GENERATED_DIR)/mon_mask.bin $(GENERATED_DIR)/mon_cloud.bin \
	$(GENERATED_DIR)/mon_index.bin $(GENERATED_DIR)/item_sprites.bin \
	$(GENERATED_DIR)/item_index.bin $(GENERATED_DIR)/drop_table.bin \
	$(GENERATED_DIR)/drop_rates.bin $(GENERATED_DIR)/sword_sprites.bin \
	$(GENERATED_DIR)/proj_sprites.bin $(GENERATED_DIR)/hud_items.bin \
	$(GENERATED_DIR)/beam_sprites.bin $(GENERATED_DIR)/fx_sprites.bin \
	$(GENERATED_DIR)/mon_art.bin \
	$(foreach f,title_tiles title_cells story_tiles story_rows story_map intro_sprites intro_spawns credits_tiles credits_rows credits_map credits_rows2 credits_map2 credits_glyphs file_tiles file_cells file_glyphs file_sprites death_sprites death_maps menu_tiles menu_cells menu_glyphs menu_sprites,$(GENERATED_DIR)/$(f).bin) \
	$(GENERATED_DIR)/ow_room_info.bin $(GENERATED_DIR)/room_secrets.bin $(GENERATED_DIR)/quest_patch.bin \
	$(GENERATED_DIR)/cave_table.bin $(GENERATED_DIR)/cave_shortcuts.bin \
	$(GENERATED_DIR)/asset_manifest.txt
MUSIC_PLAYER := music/ymplay.h
MUSIC_GENERATED := $(GENERATED_DIR)/music_engine.bin
# The bank the game plays: every track ripped from the ROM's own sound engine. Without the ROM or py65 the bank is
# empty and the game is silent.
MUSIC_ROM := $(wildcard $(ROOT_DIR)/ext/Original.nes)
MUSIC_PACKED := $(GENERATED_DIR)/music_bank.bin $(GENERATED_DIR)/music_drum_table.bin \
	$(GENERATED_DIR)/music_ids.inc

.PHONY: all assets check clean run screenshot golden-update dist disk

all: $(PRG)

assets: $(GENERATED)

$(GENERATED) &: $(TOOLS_DIR)/build_assets.py $(ASSET_INPUTS) $(DEV_STAMP)
	@mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(TOOLS_DIR)/build_assets.py --source-root $(ROOT_DIR) --out-dir $(GENERATED_DIR)

$(MUSIC_GENERATED) &: $(TOOLS_DIR)/ym_convert.py $(MUSIC_PLAYER)
	@mkdir -p $(GENERATED_DIR)
	$(PYTHON) $(TOOLS_DIR)/ym_convert.py --player $(MUSIC_PLAYER) --out-dir $(GENERATED_DIR)

MUSIC_CAPABILITY_STAMP := $(BUILD_DIR)/music_capability.stamp
.PHONY: FORCE_MUSIC_CAPABILITY_STAMP
FORCE_MUSIC_CAPABILITY_STAMP:

$(MUSIC_CAPABILITY_STAMP): FORCE_MUSIC_CAPABILITY_STAMP
	@mkdir -p $(BUILD_DIR)
	@available=$$($(PYTHON) -c "import py65" >/dev/null 2>&1 && printf yes || printf no); \
	printf '%s\n' "$$available" | cmp -s - $@ 2>/dev/null || printf '%s\n' "$$available" > $@

$(MUSIC_PACKED) &: $(TOOLS_DIR)/music_pack.py $(TOOLS_DIR)/nes_music_rip.py $(MUSIC_GENERATED) $(MUSIC_ROM) $(MUSIC_CAPABILITY_STAMP)
	$(PYTHON) $(TOOLS_DIR)/music_pack.py $(if $(MUSIC_ROM),--rom $(MUSIC_ROM)) --out-dir $(GENERATED_DIR)

$(OBJ): $(SOURCES) $(GENERATED) $(MUSIC_GENERATED) $(MUSIC_PACKED)
	@mkdir -p $(BUILD_DIR)
	$(AS) $(ASFLAGS) -al=$(LISTING) -o $@ $(MAIN_SRC)

$(ELF): $(OBJ) link.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJ)
	$(PYTHON) $(TOOLS_DIR)/check_reach.py --nm $(NM) --listing $(LISTING) $@ $(SOURCES)

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(PRG): $(BIN) $(TOOLS_DIR)/make_prg.py
	$(PYTHON) $(TOOLS_DIR)/make_prg.py $< $@

# The folder to run from: the PRG and the dungeons' files it reads, side by side.
DIST_DIR := $(BUILD_DIR)/dist
dist: all
	@mkdir -p $(DIST_DIR)
	cp $(PRG) $(DIST_DIR)/
	cp $(addprefix $(GENERATED_DIR)/,$(DATA_FILES)) $(DIST_DIR)/

# A 720 KB floppy image with the game on it, for a real drive, a Gotek or an emulator (the 18 files and the PRG fit with room to spare).
DISK := $(BUILD_DIR)/ZELDA.st
disk: all
	$(PYTHON) tools/make_disk.py $(DISK) $(PRG) $(addprefix $(GENERATED_DIR)/,$(DATA_FILES))

check: all
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py'
	$(PYTHON) $(TOOLS_DIR)/build_assets.py --source-root $(ROOT_DIR) --out-dir $(GENERATED_DIR) --verify-only
	$(PYTHON) $(TOOLS_DIR)/make_prg.py --check $(PRG)
	$(PYTHON) $(TOOLS_DIR)/golden.py

# Accept what the golden scenes show now (after looking at build/golden/*.png).
golden-update:
	$(PYTHON) $(TOOLS_DIR)/golden.py --update

# Headless Hatari run that renders the framebuffer to a PNG. TOS=<path to a
# TOS image> is required; see tools/screenshot.py --help for the other options.
screenshot: all
	$(PYTHON) $(TOOLS_DIR)/screenshot.py --prg $(PRG) --out $(BUILD_DIR)/screen.png

clean:
	rm -rf $(BUILD_DIR)
