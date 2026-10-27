#!/bin/sh
# Phase 2 for one dungeon: play it in the ROM and in the port (fight, then idle), then compare.
#   run_phase2.sh LEVEL [QUEST]            needs ext/Original.nes, npm install in this folder, TOS
set -e
LEVEL=${1:?level}; QUEST=${2:-1}
HERE=$(cd "$(dirname "$0")" && pwd); OUT="$HERE/../../build/refnes"; mkdir -p "$OUT"
cd "$HERE"
ROOMS=$(python3 -c "import sys;sys.path.insert(0,'.');import port_play as p;print(','.join(str(r) for r in p.rooms_of($QUEST,$LEVEL)))")
for MODE in fight idle; do
  if [ $MODE = idle ]; then FLAG=--idle; SUF=_idle; FRAMES=600; else FLAG=; SUF=; FRAMES=1500; fi
  node rom_play.mjs "$OUT/rom_play$SUF.$QUEST.$LEVEL.json" --quest "$QUEST" --level "$LEVEL" --rooms "$ROOMS" --frames $FRAMES $FLAG
  python3 port_play.py "$OUT/port_play$SUF.$QUEST.$LEVEL.json" --quest "$QUEST" --level "$LEVEL" --frames $FRAMES $FLAG
done
