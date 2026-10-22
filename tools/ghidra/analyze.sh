#!/usr/bin/env bash
# Import ROS.exe into a headless Ghidra project, apply Delphi symbols and export
# decompiled C / disassembly for every project unit.
# Usage: tools/ghidra/analyze.sh <version> [export]   (e.g. 1.1)
#   export: only re-run the export on the already analyzed project
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
ver="${1:-1.1}"
exe="$root/orig/game-$ver/ROS.exe"
[ "$ver" = 1.0 ] && exe="$root/orig/game/ROS.exe"
ghidra_home="$(dirname "$(readlink -f "$(command -v ghidra)")")"

rm -rf "$root/build/decomp-$ver"
mkdir -p "$root/build/ghidra" "$root/build/decomp-$ver"
awk '(strtonum("0x"$3)-strtonum("0x"$2))>112' "$root/symbols/project-ranges-$ver.txt" > "$root/build/export-ranges-$ver.txt"
if [ "${2:-}" = export ]; then
    # Re-export from the existing analyzed project without re-importing.
    src=(-process ROS.exe -noanalysis)
else
    src=(-import "$exe" -overwrite -preScript ImportDelphi.java "$root/symbols/ros-$ver.tsv")
fi
"$ghidra_home/support/analyzeHeadless" "$root/build/ghidra" "ros-$ver" \
    "${src[@]}" -scriptPath "$root/tools/ghidra" \
    -postScript ApplyTypes.java "$root/build/ghidra-types-$ver.tsv" "$root/build/project-classes-$ver.txt" \
    -postScript ExportDecomp.java "$root/build/export-ranges-$ver.txt" "$root/build/decomp-$ver"
