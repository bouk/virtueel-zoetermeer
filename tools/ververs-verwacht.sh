#!/usr/bin/env bash
# Ververs tests/verwacht/: de verwachte speltoestanden voor de CI-check (flake-check 'difftest'),
# gemaakt door het ORIGINELE ROS.exe (v1.1) onder Wine met tools/orig_probe.py.
#
# Gebruik: tools/ververs-verwacht.sh [script.zms ...]   (standaard: alle tests/scripts/*.zms)
#
# De scripts draaien na elkaar (nooit tegelijk: ze delen de Wine-prefix en de X-server is per run,
# maar de timing van het origineel lijdt onder een drukke machine), elk in een verse kopie van de
# spelbestanden uit de Nix-package spel-data. Elk script duurt 1 tot 3 minuten.
# Controleer daarna met de port (zie docs/DIFFTEST.md) of de nieuwe bestanden overeenkomen, en
# bekijk 'git diff tests/verwacht' voordat je ze commit.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Buiten de dev-shell: start opnieuw erin (Wine, xvfb-run, xdotool, Python).
if ! command -v wine >/dev/null 2>&1 || ! command -v xdotool >/dev/null 2>&1; then
  exec nix develop "$root" --command "$0" "$@"
fi

scripts=("$@")
[ ${#scripts[@]} -eq 0 ] && scripts=(tests/scripts/*.zms)

data="$(nix build --no-link --print-out-paths "$root#spel-data")"
export WINEPREFIX="$root/.wine" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
werk="$root/build/verwacht"
mkdir -p "$werk"

for script in "${scripts[@]}"; do
  naam="$(basename "$script" .zms)"
  echo "== $naam"
  run="$werk/run-$naam"
  uit="$werk/uit-$naam"
  rm -rf "$run" "$uit"
  mkdir -p "$run"
  cp -r "$data/game/." "$run/"
  cp "$data/ROS.exe" "$run/ROS.exe"
  chmod -R u+w "$run"
  xvfb-run -a -s "-screen 0 1280x1024x24" python tools/orig_probe.py "$run" "$script" "$uit"
  doel="tests/verwacht/$naam"
  rm -rf "$doel"
  mkdir -p "$doel"
  n=0
  for s in "$uit"/*.state; do
    [ -e "$s" ] || continue
    cp "$s" "$doel/"
    n=$((n + 1))
  done
  echo "   $n toestand(en) naar $doel"
done
