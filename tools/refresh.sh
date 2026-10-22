#!/usr/bin/env bash
# Genereer symbolen, klassencatalogus en de Ghidra-export opnieuw nadat er namen zijn toegevoegd onder
# symbols/names/.  Gebruik: tools/refresh.sh [1.1] [export]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ver="${1:-1.1}"
exe="$root/orig/game-$ver/ROS.exe"
cd "$root"
mkdir -p build
python tools/merge_names.py symbols/names build/names.tsv build/fields.tsv
python tools/units.py "$exe" orig/kb/kb5.bin "symbols/unit-names-$ver.json" > "symbols/units-$ver.json"
python tools/symbols.py "$exe" orig/kb/kb5.bin "symbols/units-$ver.json" build/names.tsv > "symbols/ros-$ver.tsv"
python tools/classes.py "$exe" "symbols/units-$ver.json" "symbols/ros-$ver.tsv" > "symbols/classes-$ver.md"
python tools/vclslots.py "$exe" orig/kb/kb5.bin > symbols/vcl-vmt-slots.md
python tools/ghidra_types.py "$exe" build/fields.tsv orig/kb/kb5.bin > "build/ghidra-types-$ver.tsv"
grep '^## ' "symbols/classes-$ver.md" | sed 's/^## \([A-Za-z0-9_]*\).*/\1/' > "build/project-classes-$ver.txt"
python - "$ver" <<'PY'
import json, sys
ver = sys.argv[1]
d = json.load(open('symbols/units-%s.json' % ver))
with open('symbols/project-ranges-%s.txt' % ver, 'w') as f:
    for u in d['units']:
        if not u['library']:
            f.write('%s %x %x\n' % (u['name'] or 'Unit%d' % u['init_order'], u['start'], u['end']))
PY
tools/ghidra/analyze.sh "$ver" ${2:-} > build/ghidra.log 2>&1
grep -E 'ERROR|Applied' build/ghidra.log || true
python tools/compat_surface.py "build/decomp-$ver" "symbols/units-$ver.json" "build/project-classes-$ver.txt" > symbols/compat-surface.md
