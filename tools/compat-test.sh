#!/usr/bin/env bash
# Build and run the compat layer tests headless; screenshots go to build/compat-tests/.
# Needs the user's game files: ZM_DATA (data dir) and optionally ZM_EXE (ROS.exe v1.1).
# Usage: nix develop --command tools/compat-test.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/compat-tests"
mkdir -p "$out/units"
export ZM_HEADLESS=1
export ZM_DATA="${ZM_DATA:-$root/orig/game}"
export ZM_EXE="${ZM_EXE:-$root/orig/game-1.1/ROS.exe}"
status=0
for t in test_controls test_bitmap test_dfm; do
  fpc -Mdelphi -g -gl -O1 -Fi"$root/src" -Fu"$root/src/compat" -Fu"$root/src/compat/sdl3" \
      -FU"$out/units" -FE"$out" -vew "$root/src/compat/tests/$t.dpr" > "$out/$t.log" 2>&1 \
    || { echo "BUILD FAILED: $t (see $out/$t.log)"; status=1; continue; }
  "$out/$t" "$out/$t.png" || status=1
done
exit $status
