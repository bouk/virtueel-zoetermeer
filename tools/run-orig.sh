#!/usr/bin/env bash
# Draai het originele spel onder Wine op een X-server zonder beeldscherm en maak een schermafdruk.
# Gebruik: tools/run-orig.sh [1.0|1.1] [seconden] [schermafdruk.png]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ver="${1:-1.1}"; secs="${2:-30}"; shot="${3:-$root/build/orig-$ver.png}"
run="$root/build/run-$ver"
rm -rf "$run"; mkdir -p "$run"
cp -r "$root/orig/game/." "$run/"
[ "$ver" = 1.1 ] && cp "$root/orig/game-1.1/ROS.exe" "$run/ROS.exe"

export WINEPREFIX="$root/.wine" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
cd "$run"
xvfb-run -a -s "-screen 0 1280x1024x24" bash -c "
  [ -d '$WINEPREFIX' ] || { wineboot -i >/dev/null 2>&1; wineserver -w; }
  wine ROS.exe & sleep $secs
  import -window root '$shot'
  wineserver -k"
echo "$shot"
