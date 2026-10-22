#!/usr/bin/env bash
# Import ROS.exe into a headless Ghidra project, apply Delphi symbols and export
# decompiled C / disassembly for every project unit.
# Usage: tools/ghidra/analyze.sh <version>   (e.g. 1.1)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
ver="${1:-1.1}"
exe="$root/orig/game-$ver/ROS.exe"
[ "$ver" = 1.0 ] && exe="$root/orig/game/ROS.exe"
ghidra_home="$(dirname "$(readlink -f "$(command -v ghidra)")")"

mkdir -p "$root/build/ghidra" "$root/build/decomp-$ver"
awk '(strtonum("0x"$3)-strtonum("0x"$2))>112' "$root/symbols/project-ranges-$ver.txt" > "$root/build/export-ranges-$ver.txt"
"$ghidra_home/support/analyzeHeadless" "$root/build/ghidra" "ros-$ver" \
    -import "$exe" -overwrite \
    -scriptPath "$root/tools/ghidra" \
    -preScript ImportDelphi.java "$root/symbols/ros-$ver.tsv" \
    -postScript ExportDecomp.java "$root/build/export-ranges-$ver.txt" "$root/build/decomp-$ver"
