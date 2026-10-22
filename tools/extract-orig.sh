#!/usr/bin/env bash
# Unpack the original "Virtueel Zoetermeer.zip" into orig/ and verify checksums.
# Usage: tools/extract-orig.sh [path/to/Virtueel Zoetermeer.zip]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
zip="${1:-$root/Virtueel Zoetermeer.zip}"
out="$root/orig"

rm -rf "$out"
mkdir -p "$out/zip" "$out/game"
unzip -q -o "$zip" -d "$out/zip"
7z x -y -o"$out/game" "$out/zip/installatie.exe" >/dev/null
rm -rf "$out/game/\$PLUGINSDIR" "$out/game/Uninstall.exe"

mkdir -p "$out/game-1.1"
python -I "$root/tools/wise-extract.py" "$out/zip/update.exe" "$out/game-1.1/ROS.exe"

cd "$out"
sha256sum -c "$root/orig.sha256"
