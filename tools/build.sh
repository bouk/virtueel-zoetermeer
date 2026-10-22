#!/usr/bin/env bash
# Build the portable game with Free Pascal.
# Usage: tools/build.sh [unit-or-program.pas ...]   (default: src/game/Ros.dpr)
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
