# The Legend of Zelda for Atari ST

A port of Zelda 1 to the Atari ST. It's written in 68000 assembly and runs as a normal TOS `.PRG` on an ST with 1 MB of RAM (320x200, 16 colours). I run it in Hatari.

There is no game data in this repo. You have to bring your own ROM and put it in `ext/Original.nes`. The graphics, rooms, music and texts are all read from it when you build. The ROM is gitignored and should never be committed.

I'm making this together with an AI (Claude, from Anthropic). I decide what to build and what to fix, Claude writes most of the code and the tools. The behaviour follows aldonunez's disassembly of the original, which is in `src/`.

## Status

Work in progress. Both quests are in: the whole overworld, all nine dungeons up to Ganon and Zelda, every item, title and story, file select, death and continue, saving to `ZELDA.SAV`, the credits and the music. Expect bugs. There is a short list of what is left in [`atari_st/PLAN.md`](atari_st/PLAN.md).

The Second Quest starts when you make a file called ZELDA (like the original), or when you finish the game. Both quests are in one `.PRG` of about 700 KB, so you need 1 MB of RAM. It fits on a 720 KB disk together with the save file.

## Controls

| Key | Action |
| --- | --- |
| arrow keys, `W` `A` `S` `D`, joystick | walk |
| `Ctrl`, joystick fire | sword (A) |
| `Space`, `Alternate` or `B` | B item: bombs, boomerang, candle, bow, recorder, food, potion or rod |
| `Tab` | inventory screen (Left/Right to choose the B item) |
| `K` | debug: a key, four bombs and the candle |
| `T` | debug: show the room id (`RM-37`, or `CL-xx` in a cellar) on the ribbon |
| `Esc` | quit |

## Build

The output is `atari_st/build/ZELDAST.PRG`. You build it on Linux, or on Windows through WSL (there is no native Windows `make` or m68k toolchain, and I have not tested one). Pick your platform below, then do the ROM steps.

### What you need

| | needed | what for |
| --- | --- | --- |
| Python 3 | yes | the tools that turn the ROM into ST data |
| `make` | yes | runs the build |
| GNU m68k binutils (`m68k-linux-gnu-as`, `ld`, `objcopy`, `nm`) | yes | assembles and links the 68000 code |
| Your ROM at `ext/Original.nes` | yes, for a `.PRG` | every picture, room, text and sound comes from it |
| `pip install py65` | no | without it the game is silent (the sound bank is ripped from the ROM's own sound engine) |
| Hatari and a TOS image (EmuTOS 1.4 512k, or TOS 1.04) | no, only to run it | an emulator to play it, and `make check` uses them for the golden frames |
| `pip install machine68k` | no | extra tests of the music player |

The ROM I build and test with is *The Legend of Zelda (Europe) (Rev 1)*: 131,088 bytes, SHA-1 `4a29a5157f1948b2b8c25978ce6d9ff7a3c14708`. I don't know how other dumps behave. You are responsible for being allowed to have the ROM.

### Linux (Debian / Ubuntu)

1. Install the tools:
   ```sh
   sudo apt-get install git make python3 python3-pip binutils-m68k-linux-gnu
   ```
   On other distributions look for a `binutils` package for the target `m68k-linux-gnu` (it must provide `m68k-linux-gnu-as`). The `m68k-atari-mint` binutils are not a substitute, the old 2.30 in them rejects the `.section` lines in the source.
2. Optional, for the sound bank: `pip install --break-system-packages py65` (or use a virtual environment).
3. Get the code: `git clone https://github.com/georgeflower/zelda1-atarist.git` and `cd zelda1-atarist`.
4. Continue with [With the ROM](#with-the-rom) or [Without the ROM](#without-the-rom).

### Windows with WSL (manual, in a terminal)

The build itself runs in Linux inside WSL; Windows only supplies the terminal and, if you like, the emulator.

1. Install WSL with Ubuntu, once. In PowerShell run as administrator:
   ```powershell
   wsl --install -d Ubuntu
   ```
   Restart if it asks, and make the Ubuntu user it asks for. Open the "Ubuntu" app (or `wsl` in PowerShell) for the steps below.
2. In Ubuntu, install the tools, same as on Linux:
   ```sh
   sudo apt-get update
   sudo apt-get install git make python3 python3-pip binutils-m68k-linux-gnu
   ```
3. Clone the repository **inside** WSL, in your Linux home (`~/zelda1-atarist`), not under `/mnt/c/...`:
   ```sh
   cd ~
   git clone https://github.com/georgeflower/zelda1-atarist.git
   cd zelda1-atarist
   ```
   It is much faster there, and the shell scripts keep their Unix line endings. If you did clone with Windows git, `bash` stops on `\r` errors; either clone again inside WSL, or run `git config core.autocrlf false` and check out the files again.
4. Optional: `pip install --break-system-packages py65`.
5. Put the ROM in place (see [With the ROM](#with-the-rom)). From Windows Explorer you can open `\\wsl$\Ubuntu\home\<you>\zelda1-atarist\ext` and drop it there, or copy it from the Windows side: `mkdir -p ext && cp /mnt/c/Users/<you>/Downloads/zelda.nes ext/Original.nes`.
6. Build as in [With the ROM](#with-the-rom), then play with the Windows version of Hatari (see [Running it](#running-it)): the file is at `\\wsl$\Ubuntu\home\<you>\zelda1-atarist\atari_st\build\ZELDAST.PRG`.

The tests of the Python tools (not the build) also run with a plain Windows Python 3 from PowerShell: `py -m unittest discover -s atari_st\tests`.

### Windows with Visual Studio Code (or Visual Studio) and WSL

This is the setup I use. The editor is only a window onto the same WSL toolchain, so you need steps 1-2 of the previous section first (WSL, Ubuntu, `make`, `python3`, `binutils-m68k-linux-gnu`). The compiler is not Visual Studio's, and MSVC/MSBuild can not build this: it is 68000 assembly with GNU binutils.

1. Install [Visual Studio Code](https://code.visualstudio.com/) and its **WSL** extension (`ms-vscode-remote.remote-wsl`). Optional: the Python extension.
2. In Ubuntu: clone the repository into your Linux home as in step 3 above.
3. Open the folder in VS Code from the Ubuntu terminal: `code ~/zelda1-atarist`. The bottom left corner now says "WSL: Ubuntu".
4. Put the ROM at `ext/Original.nes` (drag it into the `ext` folder in the Explorer pane, or use `cp`).
5. Open a terminal in VS Code (`` Ctrl+` ``). It is a Linux shell in the repository, so the commands below are the same as on Linux.

Full Visual Studio 2022 works the same way, as an editor: open the folder over `\\wsl$\Ubuntu\...` and use a WSL terminal for `make`. It adds nothing to the build, and I have not tried it, so use VS Code if you can.

### With the ROM

1. Put your ROM at `ext/Original.nes` in the repository root (make the `ext` folder if it isn't there). `ext/` and `*.nes` are gitignored, it never goes into git. Check it:
   ```sh
   ls -l ext/Original.nes       # 131088 bytes
   sha1sum ext/Original.nes     # 4a29a5157f1948b2b8c25978ce6d9ff7a3c14708
   ```
   (Windows PowerShell: `Get-FileHash -Algorithm SHA1 ext\Original.nes`.) The same data can instead be given as the extracted blocks in `bin/`; the file is the easy way.
2. Build the game:
   ```sh
   make -C atari_st all
   ```
   It reads the ROM, builds the data in `atari_st/build/generated/`, assembles, links, checks that every branch reaches its target and writes `atari_st/build/ZELDAST.PRG` (about 700 KB). A rebuild only redoes what changed. `make -C atari_st clean` removes `atari_st/build`.
3. Optional, to check your work: `make -C atari_st check` runs the unit tests, verifies the generated data, checks the `.PRG` header and runs the golden frames. The golden frames need Hatari, an EmuTOS image in the `TOS` environment variable and the ROM; without them they are skipped.

If a tool has another name or lives somewhere else, give it to make: `make -C atari_st all TOOLCHAIN_PREFIX=m68k-elf- PYTHON=python`.

### Running it

You need an emulator with 1 MB of RAM (an STFM; real hardware is not tested) and a TOS image: [EmuTOS](https://emutos.sourceforge.io/) 1.4 (the 512k version) is free. Hatari is on [hatari-emu.org](https://hatari-emu.org/) (also as a Windows build) or `sudo apt-get install hatari`.

```sh
mkdir -p ~/zelda-disk && cp atari_st/build/ZELDAST.PRG ~/zelda-disk/
hatari --tos /path/to/etos512us.img --machine st --memsize 1 --harddrive ~/zelda-disk --auto 'C:\ZELDAST.PRG'
```

The save file `ZELDA.SAV` is written to that folder. The same thing can be done from the Hatari menus (F12): set the TOS image, 1 MB, a GEMDOS drive folder, and double-click `ZELDAST.PRG`. On Windows give the paths in Windows form, for example `--harddrive C:\zelda-disk`.

### Without the ROM

You can not build the game without it: all the graphics, rooms, music and texts are read from the ROM, and there is no stand-in art. `make -C atari_st all` stops at the first step with

```
No ROM found. Put the NES ROM at ../ext/Original.nes (or extract its blocks into ../bin): ...
```

and writes no `.PRG`. What you can do:

1. Install the tools as above (only Python 3 is really needed).
2. Run the tests of the tools:
   ```sh
   python3 -m unittest discover -s atari_st/tests
   ```
   The tests that need the ROM (about 100 of them) are skipped and say so, the rest runs, so you can check that a change to the Python side doesn't break anything. `make -C atari_st check` can not be used, it builds first.
3. Read and change the 68000 source in `atari_st/src/`. To see the result you need the ROM for the assembly step.

If you only want to play, the way is: get the ROM, follow [With the ROM](#with-the-rom). There is no ready-made `.PRG` in the repository, since it would contain the game's data.

`atari_st/README.md` has more on the tools, the test harness and how the build works inside. The `build.ps1` and `util.ps1` in the root belong to the original disassembly (they rebuild the NES ROM with ca65), not to the Atari ST port.

## Layout

- `atari_st/` - the port: 68000 source, the tools that turn the ROM into ST data, tests and a headless Hatari harness
- `src/` - the original Zelda 1 disassembly, used as the reference
- `ext/` - where your ROM goes (gitignored)
- `AGENTS.md` / `CLAUDE.md` - notes for AI assistants working on the project (same file twice)

## Credits

Based on aldonunez's labelled Zelda 1 disassembly and camthesaxman's zeldasource. The zeldadungeon.net walkthrough was used for checking levels and items. Zelda is Nintendo's; this is a fan project and has nothing to do with them.
