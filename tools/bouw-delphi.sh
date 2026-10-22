#!/usr/bin/env bash
# Bouw ROS.exe met de originele Delphi 5-compiler (dcc32) onder Wine: de matchende build.
#
# Gebruik: tools/bouw-delphi.sh [--droog] [extra dcc32-opties ...]
#   --droog   alleen de controles doen en het dcc32-commando tonen, niet uitvoeren
# Omgeving: ZM_TOOLCHAIN=<map>   een andere toolchain-map dan toolchain/
#           ZM_UNITPADEN=<map:map> extra unitmappen vóór src/game (bijv. build/stubs voor de
#                                  bootstrap met tools/maak-stubs.py)
# Uitvoer: build/delphi/ROS.exe en build/delphi/ROS.map (gedetailleerd, -GD), plus de .dcu's
#          in build/delphi/dcu. Vergelijk daarna met:
#            python3 tools/diff.py orig/game-1.1/ROS.exe build/delphi/ROS.exe --map build/delphi/ROS.map
#            python3 tools/progress.py orig/game-1.1/ROS.exe build/delphi/ROS.exe --map build/delphi/ROS.map
#
# Verwacht een (door git genegeerde) toolchain/ met de Delphi 5-installatie:
#   toolchain/bin/dcc32.exe       de commandoregelcompiler
#   toolchain/lib/                de vooraf gecompileerde RTL/VCL-.dcu's en .res-bestanden
#   toolchain/schakelaars.cfg     (optioneel) de compilerschakelaars, één of meer per regel;
#                                 '#' begint commentaar
# Zonder schakelaars.cfg worden de schakelaars uit docs/SCHAKELAARS.md gehaald: de inhoud van
# het eerste codeblok met als taal `dcc32` of `schakelaars` (```dcc32 … ```), of anders elke vorm `-$X+`,
# `-$X-` of `-$Xn` die in het document voorkomt.
#
# Dit script is nog nooit gedraaid: er is (nog) geen Delphi 5-compiler. Zie docs/MATCHEN.md.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tc="${ZM_TOOLCHAIN:-$root/toolchain}"
droog=0
if [ "${1:-}" = --droog ]; then droog=1; shift; fi
uit="$root/build/delphi"

if [ ! -d "$tc" ]; then
  cat >&2 <<EOF
fout: $tc ontbreekt.
De matchende build heeft Borland Delphi 5 nodig (dcc32.exe met de RTL/VCL-.dcu's). Die is niet
vrij beschikbaar en zit daarom niet in de repository. Zet een Delphi 5-installatie in toolchain/
(bin/dcc32.exe, lib/*.dcu, lib/*.res); die map wordt nooit gecommit. Zie docs/MATCHEN.md.
EOF
  exit 2
fi
dcc32="$tc/bin/dcc32.exe"
if [ ! -f "$dcc32" ]; then
  echo "fout: $dcc32 ontbreekt (toolchain/ is er wel, maar zonder de compiler)." >&2
  exit 2
fi
if [ ! -d "$tc/lib" ]; then
  echo "fout: $tc/lib ontbreekt; dcc32 heeft de Delphi 5-.dcu's van de RTL/VCL nodig." >&2
  exit 2
fi

# Compilerschakelaars.
schakelaars=()
if [ -f "$tc/schakelaars.cfg" ]; then
  bron="toolchain/schakelaars.cfg"
  while read -r -a woorden; do
    for w in "${woorden[@]}"; do
      [[ "$w" == \#* ]] && break
      schakelaars+=("$w")
    done
  done < "$tc/schakelaars.cfg"
elif [ -f "$root/docs/SCHAKELAARS.md" ]; then
  bron="docs/SCHAKELAARS.md"
  blok="$(awk '/^```(schakelaars|dcc32)[[:space:]]*$/{binnen=1;next} /^```/{if(binnen)exit} binnen' "$root/docs/SCHAKELAARS.md" | sed 's/#.*//')"
  if [ -z "${blok//[[:space:]]/}" ]; then
    blok="$(grep -oE -- '-\$[A-Z]([+-]|[0-9]+)' "$root/docs/SCHAKELAARS.md" | awk '!gezien[$0]++')"
  fi
  read -r -a schakelaars <<< "$(tr '\n' ' ' <<< "$blok")"
else
  echo "fout: geen compilerschakelaars: maak toolchain/schakelaars.cfg of docs/SCHAKELAARS.md." >&2
  exit 2
fi
if [ ${#schakelaars[@]} -eq 0 ]; then
  echo "fout: geen schakelaars gevonden in $bron." >&2
  exit 2
fi
echo "schakelaars uit $bron: ${schakelaars[*]}"

# Wine-omgeving zoals in tools/run-orig.sh. Unix-paden worden Z:\-paden.
export WINEPREFIX="$root/.wine" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
win() { echo "Z:${1//\//\\}"; }

# -B alles bouwen, -GD gedetailleerd map, -Q stil; -E exe/map-map, -N dcu-map,
# -U/-I/-R zoekpaden voor units, include-bestanden (zm.inc in src/) en resources.
extra=""
IFS=: read -r -a mappen <<< "${ZM_UNITPADEN:-}"
for m in "${mappen[@]}"; do
  [ -n "$m" ] && extra+="$(win "$(cd "$root" && realpath -m "$m")");"
done
commando=(wine "$dcc32" -B -GD -Q
  "${schakelaars[@]}"
  -E"$(win "$uit")" -N"$(win "$uit/dcu")"
  -U"$(win "$tc/lib");$extra$(win "$root/src/game")"
  -I"$(win "$root/src")"
  -R"$(win "$tc/lib");$(win "$root/src/game")"
  "$@"
  Ros.dpr)
if [ "$droog" = 1 ]; then
  echo "(droog) in src/game: ${commando[*]}"
  exit 0
fi
[ -d "$WINEPREFIX" ] || { wineboot -i >/dev/null 2>&1; wineserver -w; }
mkdir -p "$uit/dcu"
cd "$root/src/game"
"${commando[@]}"

# dcc32 noemt de uitvoer naar het project (Ros.exe/Ros.map); het origineel heet ROS.exe.
for ext in exe map; do
  if [ -f "$uit/Ros.$ext" ]; then mv -f "$uit/Ros.$ext" "$uit/ROS.$ext"; fi
done
[ -f "$uit/ROS.exe" ] || { echo "fout: dcc32 leverde geen $uit/ROS.exe op." >&2; exit 1; }
sha256sum "$uit/ROS.exe"
echo "verwacht (v1.1): $(awk '/game-1.1\/ROS.exe/{print $1}' "$root/orig.sha256")"
