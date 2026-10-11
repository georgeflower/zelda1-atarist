#!/bin/bash
# Dev helper: build with a start room, run headless Hatari and capture a PNG.
# usage: dev_run.sh <start-room> <out.png> <vbls> "<key events>"   (needs $TOS)
cd "$(dirname "$0")/.." || exit 1
export TOS="${TOS:-/mnt/g/OneDrive/Download Saved/Nostalgia/hatari-2.6.1_windows64/TOSes/ST/104_us.img}"
export ZELDA_START_ROOM="$1"
touch tools/build_assets.py
make all > build/make.log 2>&1 || { echo MAKE FAILED; tail -30 build/make.log; exit 1; }
python3 tools/screenshot.py --vbls "$3" --keys "$4" --out "build/$2" > build/dev_run.log 2>&1
cat build/dev_run.log
