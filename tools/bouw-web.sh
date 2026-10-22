#!/usr/bin/env bash
# Bouw de webversie (WebAssembly) in build/web/: zoetermeer.wasm (met Asyncify),
# index.html, zoetermeer.js en het datapakket.
# Gebruik: tools/bouw-web.sh [speelmap] [ROS.exe v1.1]   (standaard: orig/game, orig/game-1.1/ROS.exe)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
speelmap="${1:-$root/orig/game}"
exe="${2:-$root/orig/game-1.1/ROS.exe}"
uit="$root/build/web"
tmp="$root/build/wasm"
mkdir -p "$uit" "$tmp"

fpc-wasm -Mdelphi -O2 -dZM_NO_SDL3 \
  -Fi"$root/src" -Fu"$root/src/game" -Fu"$root/src/compat" -Fu"$root/src/web" \
  -FU"$tmp" -FE"$tmp" -vewn "$root/src/web/RosWeb.dpr"

# Asyncify: deze imports mogen de stack opschorten (wachten, slapen, en af en toe
# teruggeven aan de browser tijdens polling-lussen; zie web/zoetermeer.js).
wasm-opt --enable-reference-types --enable-bulk-memory --enable-bulk-memory-opt \
  --enable-mutable-globals --enable-sign-ext --enable-nontrapping-float-to-int \
  --enable-multivalue -O2 --asyncify \
  --pass-arg=asyncify-imports@zm.wait,zm.delay,zm.poll_event,zm.ticks,wasi_snapshot_preview1.poll_oneoff,wasi_snapshot_preview1.clock_time_get \
  "$tmp/RosWeb.wasm" -o "$uit/zoetermeer.wasm"

cp "$root/web/index.html" "$root/web/zoetermeer.js" "$uit/"
python "$root/tools/maak-datapakket.py" "$speelmap" "$exe" "$uit/data"
ls -la "$uit"
