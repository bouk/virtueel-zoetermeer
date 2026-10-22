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

# INI-bestanden en de schrijfbare overlay, met een eigen synthetische datamap
# (de echte spelbestanden worden hier niet gebruikt en nooit beschreven).
t=test_ini
tmp="$out/ini"
rm -rf "$tmp"; mkdir -p "$tmp/data/images" "$tmp/save" "$tmp/shadow"
printf '[General]\r\n; commentaar\r\nNaam = Waarde\r\nGetal=12\r\nQuoted="  met spaties  "\r\nHex=0x1F\r\n\r\n[Level1]\r\nDuration=180\r\n; einde\r\n' > "$tmp/data/Test.ini"
chmod -R a-w "$tmp/data"
if fpc -Mdelphi -g -gl -O1 -Fi"$root/src" -Fu"$root/src/compat" -Fu"$root/src/compat/sdl3" \
    -FU"$out/units" -FE"$out" -vew "$root/src/compat/tests/$t.dpr" > "$out/$t.log" 2>&1; then
  ZM_DATA="$tmp/data" ZM_EXE= ZM_SAVE="$tmp/save" ZM_SHADOW="$tmp/shadow" "$out/$t" || status=1
else
  echo "BUILD FAILED: $t (see $out/$t.log)"; status=1
fi
chmod -R u+w "$tmp/data"
exit $status
