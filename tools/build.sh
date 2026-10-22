#!/usr/bin/env bash
# Bouw het draagbare spel met Free Pascal.
# Gebruik: tools/build.sh [unit-of-programma.pas ...]   (standaard: src/game/Ros.dpr)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/fpc"
mkdir -p "$out"
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=("$root/src/game/Ros.dpr")
for t in "${targets[@]}"; do
  fpc -Mdelphi -g -gl -O1 \
      -Fi"$root/src" -Fu"$root/src/game" -Fu"$root/src/compat" -Fu"$root/src/compat/sdl3" -Fu"$root/src/tests" \
      -FU"$out" -FE"$out" -vewn "$t"
done
